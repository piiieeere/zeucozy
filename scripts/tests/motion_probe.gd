extends Node

## Banc de fluidite — mesure ce qui bat a l'ecran, et a quelle cadence.
##
##   ... --path . --fixed-fps 60 res://scenes/tests/motion_probe.tscn -- --frames=64
##   ... (idem) -- --frames=64 --nograin      grain coupe, pour l'isoler
##   ... (idem) -- --frames=64 --shots        enregistre les vignettes du chat
##
## POURQUOI CE BANC EXISTE
## -----------------------
## Le jeu a paru tourner "a 20 fps" alors qu'il tenait 60,0 fps sans un
## dixieme de milliseconde d'ecart. C'est le defaut le plus traitre du style :
## la cadence en pas (§7) est VOULUE, donc on ne peut pas la juger a l'oeil —
## on ne sait pas dire si ce qu'on voit est le style ou un accident. Il faut
## separer les deux, et pour ca il faut mesurer.
##
## Le principe : un battement, c'est une image qui change BEAUCOUP toutes les
## 3 frames et presque pas entre. On mesure donc l'ecart d'une frame a la
## suivante, et on compare les frames de POSE aux autres. Le rapport des deux
## est le battement. Plus il est haut, plus l'image saccade.
##
## Les colonnes, et ce que chacune isole :
##   * `dt`      temps de frame reel — repond a "est-ce VRAIMENT lent ?"
##   * `img`     ecart plein cadre. Le grain y pese, il couvre tous les pixels
##   * `struct`  le meme, sur une image reduite a 1/8 : le grain y a disparu,
##               il ne reste que les formes. L'ecart img/struct EST le grain
##   * `chat`    ecart borne a une boite autour du chat — son animation seule,
##               sans le sol qui defile
##   * `silh_y`  centroide vertical de sa silhouette, en pixels. Mesure le
##               rebond du corps directement dans l'image
##
## ⚠️ La boite du chat se cale sur `unproject_position`, qui rend des
## coordonnees de VIEWPORT, alors que l'image rendue est a la resolution de la
## fenetre. Avec le stretch "canvas_items" du projet les deux different : sans
## le rapport applique plus bas, la boite se pose sur l'ATH et on mesure la
## cadence du TEXTE. Erreur commise, et elle passe inapercue — les chiffres
## sortent parfaitement plausibles.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SHOT_DIR := "user://motion_probe"

## Demi-boite autour du chat, en pixels d'image. Assez large pour le contenir
## en entier, assez serree pour que le sol qui defile n'y pese pas.
const CAT_BOX := Vector2i(45, 60)

## Frames ecartees du verdict, le temps que la camera rattrape le chat. Elle
## le suit en lissage exponentiel (`follow_speed` 6,0) : au demarrage elle part
## de loin, et ce rattrapage change l'image bien plus que la marche.
const SETTLE_FRAMES := 18

var _frames := 64
var _nograin := false
var _oldgrain := false
var _shots := false

var _game: GameRoot
var _player: Player
var _prev_full: Image
var _prev_blur: Image
var _prev_paw := INF
var _rows: Array[String] = []

# Par frame : [pose ?, img, struct, chat]. Sert au verdict.
var _samples: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
		elif arg == "--nograin":
			_nograin = true
		elif arg == "--oldgrain":
			_oldgrain = true
		elif arg == "--shots":
			_shots = true
			DirAccess.make_dir_recursive_absolute(SHOT_DIR)

	_game = MAIN_SCENE.instantiate() as GameRoot
	add_child(_game)
	await get_tree().process_frame
	_player = _game.player

	var grain := (_game.get_node("RetroPost/Screen") as ColorRect).material as ShaderMaterial

	if _nograin:
		grain.set_shader_parameter("grain_amount", 0.0)
	elif _oldgrain:
		# Toutes les cellules de grain reviennent en phase, comme avant le
		# 2026-08-16 : c'est la comparaison qui prouve que le dephasage sert.
		grain.set_shader_parameter("grain_stagger", 0.0)

	# Le chat marche en ligne droite pendant toute la mesure. Sans deplacement
	# il resterait en `idle`, et c'est `walk` qu'on vient juger.
	Input.action_press("ui_right")

	await _run()
	get_tree().quit()


func _run() -> void:
	var dts: Array[float] = []

	for i in _frames:
		await RenderingServer.frame_post_draw

		var dt := get_process_delta_time()
		dts.append(dt)

		var full := get_viewport().get_texture().get_image()
		var blur := full.duplicate() as Image
		# 1/8 de resolution : le grain (1,5 px) y disparait, la silhouette non.
		blur.resize(maxi(1, int(full.get_width() * 0.125)),
				maxi(1, int(full.get_height() * 0.125)), Image.INTERPOLATE_LANCZOS)

		var crop := _cat_box(full)
		var d_full := _mad(full, _prev_full)
		var d_blur := _mad(blur, _prev_blur)
		var d_cat := _mad(full, _prev_full, crop)
		var silhouette := _silhouette_centroid(full, crop)

		_prev_full = full
		_prev_blur = blur

		if _shots:
			var shot := full.get_region(crop)
			shot.resize(shot.get_width() * 4, shot.get_height() * 4, Image.INTERPOLATE_NEAREST)
			shot.save_png("%s/chat_%02d.png" % [SHOT_DIR, i])

		# Une frame de POSE est celle ou le squelette change de pose. On la
		# reconnait a la patte avant, pas a une horloge : c'est la pose
		# reellement appliquee a l'os qui fait foi, et elle seule.
		var paw := _paw_position()
		var is_pose: bool = _prev_paw != INF and not is_equal_approx(paw, _prev_paw)
		_prev_paw = paw

		# Les deux premieres frames s'ecartent : la camera se recale encore et
		# le premier ecart d'image n'a pas de precedent.
		if i >= 2:
			_samples.append([is_pose, d_full, d_blur, d_cat])
			_rows.append("%3d %s dt %6.2f ms  img %7.4f  struct %7.4f  chat %7.4f  silh_y %7.2f px  %s"
					% [i, "*" if is_pose else " ", dt * 1000.0,
					d_full, d_blur, d_cat, silhouette, _anim_state()])

	_report(dts)


## Ecart moyen absolu entre deux images, sur le canal vert. 0 = identiques.
## Bornee a `box` quand on en donne une, pour isoler le chat du sol.
func _mad(a: Image, b: Image, box := Rect2i()) -> float:
	if b == null or a.get_size() != b.get_size():
		return -1.0

	var zone := box if box.has_area() else Rect2i(Vector2i.ZERO, a.get_size())
	# Plein cadre on echantillonne une colonne sur deux — c'est 4x moins de
	# lectures pour la meme moyenne. Sur la boite du chat, tout est lu : elle
	# est petite, et c'est la que se joue la mesure fine.
	var stride := 1 if box.has_area() else 2
	var total := 0.0
	var count := 0

	for y in range(zone.position.y, zone.end.y, stride):
		for x in range(zone.position.x, zone.end.x, stride):
			total += absf(a.get_pixel(x, y).g - b.get_pixel(x, y).g)
			count += 1

	return total / maxf(1.0, float(count))


## La boite qui contient le chat, en pixels d'IMAGE — voir l'avertissement en
## tete de fichier sur l'ecart viewport / image.
func _cat_box(image: Image) -> Rect2i:
	var camera := get_viewport().get_camera_3d()

	if camera == null or not is_instance_valid(_player):
		return Rect2i(Vector2i.ZERO, image.get_size())

	var viewport_pos := camera.unproject_position(
		_player.get_global_transform_interpolated().origin + Vector3(0.0, 0.9, 0.0)
	)
	var scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var centre := Vector2i(viewport_pos * scale)

	return Rect2i(centre - CAT_BOX, CAT_BOX * 2).intersection(
		Rect2i(Vector2i.ZERO, image.get_size())
	)


## Centre de gravite vertical des pixels SOMBRES de la boite — le chat tuxedo
## est le seul objet sombre du cadre. Mesure le rebond du corps directement
## dans l'image, sans passer par le squelette.
func _silhouette_centroid(image: Image, box: Rect2i) -> float:
	var weighted := 0.0
	var mass := 0.0

	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			# La lame de parquet la plus sombre reste au-dessus de 0,45 en
			# vert ; la fourrure noire du chat est a ~0,10.
			var dark := maxf(0.0, 0.35 - image.get_pixel(x, y).g)
			weighted += dark * float(y)
			mass += dark

	return weighted / maxf(0.0001, mass)


## Avancee de la patte avant, dans le repere du squelette. Lire l'OS et pas la
## piste : c'est la seule mesure qui prouve que la pose arrive au maillage.
## Et lire une POSITION plutot qu'un euler tire du quaternion, qui melangerait
## les axes des que l'os a une orientation de repos.
func _paw_position() -> float:
	var skeleton := _player.model.skeleton

	if skeleton == null:
		return INF

	var paw := skeleton.find_bone("pattavant_L")
	return skeleton.get_bone_global_pose(paw).origin.z if paw != -1 else INF


func _anim_state() -> String:
	var model := _player.model
	var player := model.animation_player
	var skeleton := model.skeleton

	if player == null or skeleton == null:
		return "pas d'anim"

	var root := skeleton.find_bone("racine")
	var r := skeleton.get_bone_global_pose(root).origin if root != -1 else Vector3.ZERO

	return "%-5s t=%5.3f  patte z%+.4f  racine y%+.4f" % [
		player.current_animation,
		player.current_animation_position,
		_paw_position(),
		r.y,
	]


func _report(dts: Array[float]) -> void:
	var etat := "coupe" if _nograin else ("en phase (ancien)" if _oldgrain else "dephase")
	print("\n=== BANC DE FLUIDITE ===  grain %s" % etat)

	for row in _rows:
		print(row)

	var lo := INF
	var hi := -INF
	var sum := 0.0

	for i in range(2, dts.size()):
		lo = minf(lo, dts[i])
		hi = maxf(hi, dts[i])
		sum += dts[i]

	var mean := sum / maxf(1.0, float(dts.size() - 2))
	print("\ndt      : min %.2f ms  moy %.2f ms (%.1f fps)  max %.2f ms"
			% [lo * 1000.0, mean * 1000.0, 1.0 / mean, hi * 1000.0])

	# LE VERDICT — le battement sur 3 frames, quelle que soit sa PHASE.
	#
	# On regroupe les frames par reste modulo 3 et on compare les trois
	# moyennes. Un battement de 1,0 veut dire que l'image change autant a
	# chaque frame : rien ne saccade. Plus il monte, plus l'image se fige puis
	# rattrape d'un coup — ce que l'oeil lit comme un a-coup, et comme un
	# framerate bas.
	#
	# ⚠️ Surtout ne pas comparer aux seules frames de POSE, comme une premiere
	# version le faisait. Le grain battait sur 3 frames lui aussi, mais DECALE
	# d'une frame par rapport aux poses : compare aux poses il ressortait a
	# x0,72 — un chiffre rassurant pour le pire des cas mesures. Un battement
	# se cherche par sa periode, jamais par un alignement suppose.
	print("battement sur 3 frames (max/min des 3 phases) :")

	for column in [[1, "img   "], [2, "struct"], [3, "chat  "]]:
		var index: int = column[0]
		var sums := [0.0, 0.0, 0.0]
		var counts := [0, 0, 0]

		for i in _samples.size():
			# Les premieres frames sont ecartees : la camera s'y recale encore,
			# et son rattrapage pese plus que tout ce qu'on cherche a mesurer.
			if i < SETTLE_FRAMES or _samples[i][index] < 0.0:
				continue

			sums[i % 3] += _samples[i][index]
			counts[i % 3] += 1

		var means: Array[float] = []

		for phase in 3:
			if counts[phase] == 0:
				break

			means.append(sums[phase] / float(counts[phase]))

		if means.size() < 3:
			continue

		var lo_phase: float = means.min()
		var hi_phase: float = means.max()
		print("  %s  phases %7.4f %7.4f %7.4f   -> x%.2f"
				% [column[1], means[0], means[1], means[2], hi_phase / maxf(1e-9, lo_phase)])
