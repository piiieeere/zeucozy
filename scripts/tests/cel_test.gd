extends Node3D

## Banc de test du pivot 3D — isole du gameplay.
##
## But : juger le cel-shading, le contour en coque inversee et les details
## peints sur player_cat.glb, hors de toute logique de jeu.
##
## Le style lui-meme n'est PLUS ecrit ici : il vit dans
## scripts/systems/cel_model.gd, partage avec le jeu. Le banc n'apporte que le
## cadrage, les bascules et les captures — un reglage corrige ici profite
## directement a la scene principale.
##
## DEUX MODES
##
## 1. Interactif (par defaut) — pour regarder et juger a la main.
##    Depuis l'editeur : ouvrir cette scene et F6.
##    En ligne de commande :
##      "C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/cel_test.tscn
##
## 2. Capture — tour de camera 8 directions + sondes de skinning, puis quitte.
##      ... res://scenes/tests/cel_test.tscn -- --capture

const CelModel := preload("res://scripts/systems/cel_model.gd")

const CAPTURE_DIR := "C:/Users/tibo/AppData/Local/Temp/claude/c--Users-tibo-Games-zeucozy/e5b98d13-5f39-461b-a336-1f8fdf50a087/scratchpad"
const CAPTURE_SIZE := Vector2i(720, 720)
const WINDOW_SIZE := Vector2i(1100, 820)

# Tour de camera obligatoire avant validation — "Visual Art Direction" §16.
# 0° = de face : le banc garde l'orientation brute du glTF (le chat regarde
# +Z), la ou le jeu applique yaw_offset_deg = 180 pour que -Z soit l'avant.
const ANGLES := [0, 45, 90, 135, 180, 225, 270, 315]

# Cadrage de reference — "Visual Art Direction" §11.
const CAM_PITCH_DEG := 60.0   # plongee
const CAM_FOV_DEG := 19.0     # ~72 mm sur capteur 36 mm, en FOV vertical
const CAM_DISTANCE := 7.2
const CAM_TARGET := Vector3(0.0, 0.85, 0.0)

const ORBIT_SPEED := 0.35
const ZOOM_STEP := 0.6
const PITCH_LIMITS := Vector2(-10.0, 89.0)

var _camera: Camera3D
var _pivot: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _hud: Label

var _yaw := 0.0
var _pitch := CAM_PITCH_DEG
var _distance := CAM_DISTANCE
var _dragging := false

var _show_outline := true
var _show_paint := true

# Clip joue par [A] : on fait defiler idle -> walk -> arret. Ce sont les vrais
# clips du .glb, plus le balancement code en dur d'avant — juger le style sur
# une animation improvisee n'apprend rien sur celle qui ira dans le jeu.
const CLIPS := ["idle", "walk", ""]
var _clip := 0

var _capture_mode := false
var _capture_dir := CAPTURE_DIR


func _ready() -> void:
	_capture_mode = "--capture" in OS.get_cmdline_user_args()

	# Plongee et dossier de sortie surchargeables, pour comparer plusieurs
	# cadrages d'affilee. `--pitch=` porte le meme nom que dans le jeu
	# (camera_rig.gd), `--face-pitch=` est lu par cel_model.gd lui-meme.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pitch="):
			_pitch = float(arg.trim_prefix("--pitch="))
		elif arg.begins_with("--out="):
			_capture_dir = arg.trim_prefix("--out=")

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(CAPTURE_SIZE if _capture_mode else WINDOW_SIZE)

	_setup_environment()
	_setup_camera()
	_setup_model()

	if _model.mesh_instance == null:
		_log("ECHEC : aucun MeshInstance3D trouve dans %s" % _model.model_path)
		if _capture_mode:
			_finish()
		return

	if _capture_mode:
		# Le tour de camera juge la SILHOUETTE : il lui faut la pose de repos.
		# cel_model lance `idle` des le chargement, sinon les huit vues
		# tomberaient chacune sur une pose differente et ne seraient plus
		# comparables d'une session a l'autre.
		_clip = CLIPS.find("")
		_apply_clip()
		await _capture_turntable()
		await _capture_skinning_probe()
		await _capture_cadence()
		_finish()
	else:
		_setup_hud()
		_apply_clip()
		set_process_unhandled_input(true)


# ---------------------------------------------------------------- mise en place

func _setup_environment() -> void:
	# Fond parchemin chaud (§4) — sert a juger la silhouette, pas le decor.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#F5ECD8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR  # equivalent du "Standard" Blender

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _setup_camera() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	_camera = Camera3D.new()
	_camera.set_perspective(CAM_FOV_DEG, 0.05, 100.0)
	# add_child AVANT tout look_at : hors de l'arbre, look_at echoue.
	_pivot.add_child(_camera)

	_update_camera()


func _setup_model() -> void:
	_model = CelModel.new()
	_model.name = "CelModel"
	add_child(_model)

	if _model.mesh_instance != null:
		_skeleton = _model.skeleton
		_log("Maillage : %s — %d surfaces" % [
			_model.mesh_instance.name,
			_model.mesh_instance.mesh.get_surface_count(),
		])
		_log("Attr_Style (min/moy/max) — neutre attendu : R 1.0, G 0.5, B 0.0")
		for line in _model.style_report():
			_log(line)
		_log("Animations — attendu : NEAREST partout (la cadence en pas, §7)")
		for line in _model.animation_report():
			_log(line)


func _update_camera() -> void:
	_pivot.rotation_degrees.y = _yaw
	var pitch := deg_to_rad(_pitch)
	_camera.position = CAM_TARGET + Vector3(
		0.0,
		_distance * sin(pitch),
		_distance * cos(pitch),
	)
	_camera.look_at(CAM_TARGET, Vector3.UP)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.17, 0.10, 0.82)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	_hud = Label.new()
	_hud.add_theme_color_override("font_color", Color("#F5ECD8"))
	_hud.add_theme_font_size_override("font_size", 15)
	panel.add_child(_hud)

	_refresh_hud()


func _refresh_hud() -> void:
	if _hud == null:
		return
	_hud.text = "\n".join([
		"Glisser souris  orbiter        Molette  zoom",
		"",
		"[O]  contour ............. %s" % _on_off(_show_outline),
		"[P]  visage + oreilles ... %s" % _on_off(_show_paint),
		"[A]  clip ................ %s" % _clip_label(),
		"[Haut/Bas]  bascule du visage ... %d°" % int(_model.face_pitch_deg),
		"[R]  recadrer     [1-8]  vues fixes     [Echap]  quitter",
		"",
		"vue %d°   plongee %d°   distance %.1f" % [int(_yaw) % 360, int(_pitch), _distance],
	])


func _on_off(v: bool) -> String:
	return "ON" if v else "off"


func _clip_label() -> String:
	return CLIPS[_clip] if CLIPS[_clip] != "" else "arrete"


# ------------------------------------------------------------------ interactif

func _unhandled_input(event: InputEvent) -> void:
	if _capture_mode:
		return

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_distance = maxf(1.5, _distance - ZOOM_STEP)
				_update_camera()
				_refresh_hud()
			MOUSE_BUTTON_WHEEL_DOWN:
				_distance = minf(30.0, _distance + ZOOM_STEP)
				_update_camera()
				_refresh_hud()

	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * ORBIT_SPEED
		_pitch = clampf(_pitch + event.relative.y * ORBIT_SPEED, PITCH_LIMITS.x, PITCH_LIMITS.y)
		_update_camera()
		_refresh_hud()

	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_O:
				_show_outline = not _show_outline
				_model.set_outline_enabled(_show_outline)
				_refresh_hud()
			KEY_P:
				_show_paint = not _show_paint
				_model.set_paint_enabled(_show_paint)
				_refresh_hud()
			KEY_A:
				_clip = (_clip + 1) % CLIPS.size()
				_apply_clip()
				_refresh_hud()
			KEY_R:
				_yaw = 0.0
				_pitch = CAM_PITCH_DEG
				_distance = CAM_DISTANCE
				_update_camera()
				_refresh_hud()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				_yaw = float(ANGLES[event.keycode - KEY_1])
				_update_camera()
				_refresh_hud()
			KEY_UP:
				_set_face_pitch(_model.face_pitch_deg + 2.0)
			KEY_DOWN:
				_set_face_pitch(_model.face_pitch_deg - 2.0)


## Bascule du visage sur la tete. Compromis a arbitrer a l'oeil : trop bas, le
## visage passe sous l'horizon sous une camera qui plonge a 60° ; trop haut, il
## reste visible de dos. Voir "Pipeline 3D".
func _set_face_pitch(value: float) -> void:
	_model.set_face_pitch(value)
	_refresh_hud()


## Joue le clip choisi par [A]. C'est ce qui permet de juger deux choses qu'un
## rendu fixe ne montre pas : le contour tient-il sous deformation, et la
## peinture reste-t-elle accrochee au visage et a l'oreille ?
func _apply_clip() -> void:
	var player: AnimationPlayer = _model.animation_player

	if player == null:
		return

	if CLIPS[_clip] == "":
		player.stop()
		_reset_pose()
	else:
		player.play(CLIPS[_clip])


func _pose_bone(bone_name: String, axis: Vector3, degrees: float) -> void:
	var bone := _skeleton.find_bone(bone_name)
	if bone == -1:
		return
	var rest := _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(bone, rest * Quaternion(axis, deg_to_rad(degrees)))


func _reset_pose() -> void:
	for bone_name in ["tete", "cou", "oreille_L", "queue_2"]:
		_pose_bone(bone_name, Vector3.RIGHT, 0.0)


# --------------------------------------------------------------------- capture

func _capture_turntable() -> void:
	if not DirAccess.dir_exists_absolute(_capture_dir):
		DirAccess.make_dir_recursive_absolute(_capture_dir)

	for angle in ANGLES:
		_yaw = float(angle)
		_update_camera()
		# Deux frames : une pour appliquer la rotation, une pour la dessiner.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		var image := get_viewport().get_texture().get_image()
		var path := "%s/cel_%03d.png" % [_capture_dir, angle]
		var err := image.save_png(path)
		_log("capture %03d° -> %s (err %d)" % [angle, path, err])


## Deux inconnues du pivot se testent en posant un os :
##  1. la coque inversee suit-elle la deformation, ou le contour se decolle-t-il ?
##  2. les calottes peintes suivent-elles, ou la peinture glisse-t-elle ?
##
## Les deux dependent de la meme question : Godot applique-t-il le skinning
## AVANT ou APRES vertex() ? C'est AVANT — d'ou rest_undo dans cel_model.gd.
func _capture_skinning_probe() -> void:
	if _skeleton == null:
		_log("sonde skinning : pas de Skeleton3D, ignoree")
		return

	_yaw = 0.0
	_update_camera()
	_pose_bone("tete", Vector3.RIGHT, 35.0)
	_model.update_rest_undo()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var path := "%s/cel_skin_probe.png" % _capture_dir
	get_viewport().get_texture().get_image().save_png(path)
	_log("sonde skinning (os 'tete' a 35°) -> %s" % path)

	# Deuxieme sonde, pour les calottes : on ne tord QU'UNE oreille.
	# L'autre reste temoin. Si le rose glisse sur l'oreille tordue et pas sur
	# le temoin, c'est que le masque se calcule sur la position deformee.
	_pose_bone("tete", Vector3.RIGHT, 0.0)
	_pose_bone("oreille_L", Vector3.RIGHT, 70.0)
	_model.update_rest_undo()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var ear_path := "%s/cel_ear_probe.png" % _capture_dir
	get_viewport().get_texture().get_image().save_png(ear_path)
	_log("sonde calotte (os 'oreille_L' a 70°, oreille_R temoin) -> %s" % ear_path)


## Mesure la cadence en pas la ou elle se decide vraiment : sur la POSE
## appliquee a l'os, frame par frame.
##
## `animation_report()` de cel_model lit les PISTES ; ce test-ci lit le
## resultat, et couvre donc tout ce que Godot fait entre la piste et l'os.
## §7 demande une pose toutes les 3 frames : les ecarts doivent etre des 3,
## et rien d'autre.
func _capture_cadence() -> void:
	var player: AnimationPlayer = _model.animation_player

	if player == null or _skeleton == null:
		_log("cadence : pas d'AnimationPlayer, mesure ignoree")
		return

	var bone := _skeleton.find_bone("bras_L")

	if bone == -1 or not player.has_animation("walk"):
		_log("cadence : 'walk' ou l'os 'bras_L' introuvable")
		return

	# Une marche se juge de profil : de face, le balancement des pattes se
	# projette sur rien et on ne voit plus que le rebond.
	_yaw = 90.0
	_update_camera()

	player.play("walk")
	player.pause()

	var previous := Quaternion.IDENTITY
	var poses: Array[int] = []

	for frame in 25:
		player.seek(frame / 60.0, true)
		await RenderingServer.frame_post_draw

		var current := _skeleton.get_bone_pose_rotation(bone)

		if frame == 0 or current.angle_to(previous) > 0.0005:
			poses.append(frame)
			get_viewport().get_texture().get_image().save_png(
				"%s/cel_walk_%02d.png" % [_capture_dir, frame]
			)

		previous = current

	var gaps: Array[int] = []

	for i in range(1, poses.size()):
		gaps.append(poses[i] - poses[i - 1])

	_log("cadence de 'walk' — 'bras_L' change de pose aux frames %s" % str(poses))
	_log("           ecarts : %s" % str(gaps))
	_log("           %s" % ("sur 3s, conforme a §7" if gaps.all(func(g): return g == 3)
			else "⚠ ECART NON CONFORME — la cadence n'est pas sur 3s"))

	player.stop()


func _log(line: String) -> void:
	print("[cel_test] ", line)


func _finish() -> void:
	print("[cel_test] ---- fin ----")
	get_tree().quit()
