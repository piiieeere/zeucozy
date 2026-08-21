extends Node3D

## Banc de test des MODELES SANS SQUELETTE — pendant statique de cel_test.gd.
##
## Un banc separe, et pas une option de celui du chat : cel_test.gd est
## entierement bati sur ce qu'un meuble n'a pas — bascule du visage, sondes de
## skinning, mesure de cadence sur un os. L'y greffer aurait ajoute des branches
## mortes dans le seul fichier qui doit rester lisible pour juger le chat.
##
## Ce que ce banc juge, et que le tour de camera du chat ne pouvait pas :
##
##   1. la SILHOUETTE du modele sur 8 azimuts — §16 etape 7, non optionnelle ;
##   2. le RAPPORT DE TAILLE au chat, qui est tout l'enjeu du canape : la
##      hauteur du dossier a ete decidee pour que le chat pose sur l'assise le
##      depasse. Ca ne se verifie pas au chiffre, ca se regarde ;
##   3. le modele AU CADRAGE DE JEU (§16 demande de juger a taille de jeu),
##      pose sur le vrai parquet et non sur un fond neutre.
##
## ⚠️ IL NE JUGE PLUS SEULEMENT LE CANAPE (2026-08-19). Le cadrage se deduit de la
## boite englobante du modele, et les faits propres a chaque asset vivent dans
## `MODELS`. Le tour 8 directions n'est pas optionnel : le laisser cable sur un
## seul modele revenait a ne pas l'avoir pour les suivants.
##
##   "C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" \
##       --path . res://scenes/tests/prop_test.tscn -- --capture
##   ... -- --capture --model=res://assets/models/xp_croquette.glb

const RenderQuality := preload("res://scripts/systems/render_quality.gd")
const CelProp := preload("res://scripts/systems/cel_prop.gd")
const CelStyle := preload("res://scripts/systems/cel_style.gd")

const COUCH := "res://assets/models/prop_canape.glb"
const KIBBLE := "res://assets/models/xp_croquette.glb"
const HAIRBALL := "res://assets/models/projectile_boule_poils.glb"
const MOUSE := "res://assets/models/enemy_souris.glb"
const DOG := "res://assets/models/enemy_chien.glb"
const TABLE := "res://assets/models/prop_table_basse.glb"

## Ce que le banc ne peut PAS deduire d'une boite englobante. Une entree par
## modele, et rien de plus que ce qui lui est propre.
##
## `seat` est la hauteur sur laquelle poser le chat, ou -1 quand il n'y a rien
## a escalader. Ce n'est pas un reglage de banc, c'est un fait du meuble : le
## canape existe pour qu'on saute dessus, une croquette non.
##
## `hover` est la hauteur a laquelle l'objet vit EN JEU. ⚠️ Elle n'est pas
## decorative : pose a plat sur le sol, un ramassable se fait TRANCHER SON ENCRE
## par le plan du parquet — la coque inversee descend sous le maillage, le sol
## se peint par-dessus, et il reste un liseré parchemin entre l'aplat et le
## trait. C'est un artefact de BANC, pas du modele : la croquette flotte a
## 0,35 m en jeu (`xp_orb.hover_height`) et n'y touche jamais le sol. Le canape,
## lui, pose bel et bien — son encre est tranchee en jeu aussi, et le banc doit
## montrer ca.
const MODELS := {
	COUCH: {"variant": "bleu", "family": CelProp.MEUBLE, "seat": 1.6, "hover": 0.0,
			"prefix": "prop"},
	KIBBLE: {"variant": "croquette", "family": CelProp.PICKUP, "seat": -1.0,
			"hover": 0.35, "prefix": "kibble"},
	# La boule de poils. `hover` = `player.muzzle_height` : elle ne se pose
	# jamais, elle vole a hauteur de museau du depart a l'impact. Le banc doit
	# donc la montrer en l'air, faute de quoi il jugerait une encre tranchee par
	# le parquet que le jeu ne produit pas.
	HAIRBALL: {"variant": "boule_poils", "family": CelProp.PICKUP, "seat": -1.0,
			"hover": 0.70, "prefix": "hairball"},
	# La souris. `hover` = 0 : elle POSE, comme le canape — le banc doit donc
	# montrer son encre tranchee par le parquet, puisque le jeu la tranchera
	# aussi. `CREATURE` est l'alias de `PICKUP` : voir cel_prop.gd, les trois
	# nombres sont les memes et c'est voulu.
	MOUSE: {"variant": "souris", "family": CelProp.CREATURE, "seat": -1.0,
			"hover": 0.0, "prefix": "souris"},
	# Le chien — la brute. Meme famille et meme `hover` que la souris : il POSE,
	# et sur ses quatre pattes plutot que sur son ventre. Le banc doit donc
	# montrer son encre tranchee par le parquet, puisque le jeu la tranchera
	# aussi — sauf que ses pieds s'arretent a 0,045 exactement pour que la coque
	# inversee reste au-dessus du sol (voir `LEG_FOOT_Z` dans build_dog.py).
	DOG: {"variant": "chien", "family": CelProp.CREATURE, "seat": -1.0,
			"hover": 0.0, "prefix": "chien"},
	# La TABLE BASSE — le 1er meuble PEINT. `PEINT` et non `MEUBLE` : le tour de
	# camera est exactement ce qui doit la juger, puisqu'une illustration
	# projetee depuis UN axe n'est juste que dans cet axe. Les huit directions
	# montrent donc, et c'est voulu, ce que la technique COUTE hors axe.
	#
	# `seat` = 1,0 : le plateau est une plateforme, comme l'assise du canape —
	# le chat y saute, et le banc doit montrer s'il s'y lit.
	TABLE: {"variant": "table_basse", "family": CelProp.PEINT, "seat": 1.0,
			"hover": 0.0, "prefix": "table"},
}

const CAPTURE_DIR := "C:/Users/tibo/AppData/Local/Temp/claude/c--Users-tibo-Games-zeucozy/42e46b8e-306f-4ae8-91c9-344ef69f4749/scratchpad"
const CAPTURE_SIZE := Vector2i(720, 720)
const WINDOW_SIZE := Vector2i(1100, 820)

const ANGLES := [0, 45, 90, 135, 180, 225, 270, 315]

# Meme cadrage que la camera de jeu (camera_rig.gd) : plongee 45°, FOV 24°.
# Juger un modele sous une autre plongee que celle du jeu n'apprend rien —
# c'est precisement l'angle qui avait fait passer le chat pour un cadenas.
const CAM_PITCH_DEG := 45.0
const CAM_FOV_DEG := 24.0

## Distance du tour de camera, en multiples de la plus grande dimension du
## modele. 3,44 est la valeur qui redonne au canape les 22 m auxquels il a ete
## juge : un banc qui change de cadrage en devenant generique ne serait plus
## comparable a ses propres captures d'avant.
const TURN_FILL := 3.44

## Distance de jeu, reprise telle quelle de camera_rig.gd. A 38 m et 24° de FOV
## le cadre montre ~16 m de haut, soit un chat a ~11 % de la hauteur d'ecran :
## c'est la seule echelle a laquelle un jugement de lisibilite vaut quelque chose.
const GAME_DISTANCE := 38.0

## Ecart entre le bord du modele et le chat, sur la vue d'echelle.
const CAT_CLEARANCE := 1.6

var _camera: Camera3D
var _pivot: Node3D
var _prop: Node3D
var _cat: CelModel

var _model := COUCH
var _variant := ""
var _family := ""
var _seat := 0.0
var _hover := 0.0
var _prefix := ""

var _yaw := 0.0
var _pitch := CAM_PITCH_DEG
var _distance := 22.0
var _turn_distance := 22.0
var _target := Vector3.ZERO
var _bounds := AABB()
var _dragging := false

var _capture_mode := false
var _capture_dir := CAPTURE_DIR

## Trait du meuble. Par defaut celui de sa famille — un banc qui juge le canape
## sous un autre trait que celui qu'il aura en jeu n'apprend rien, exactement
## comme il le jugerait sous une autre plongee. `--decor-outline=` sert a
## COMPARER ; -1 veut dire "celui de la famille".
var _outline_scale := -1.0


func _ready() -> void:
	_capture_mode = "--capture" in OS.get_cmdline_user_args()

	# Le banc rend sous le MEME AA que le jeu : c'est tout l'objet d'un banc.
	RenderQuality.apply_cmdline_overrides(get_viewport())

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pitch="):
			_pitch = float(arg.trim_prefix("--pitch="))
		elif arg.begins_with("--out="):
			_capture_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--decor-outline="):
			_outline_scale = float(arg.trim_prefix("--decor-outline="))
		elif arg.begins_with("--model="):
			_model = arg.trim_prefix("--model=")
		elif arg.begins_with("--variant="):
			_variant = arg.trim_prefix("--variant=")

	var facts: Dictionary = MODELS.get(_model, {})
	_variant = _variant if _variant != "" else facts.get("variant", "")
	_family = facts.get("family", CelProp.MEUBLE)
	_seat = facts.get("seat", -1.0)
	_hover = facts.get("hover", 0.0)
	_prefix = facts.get("prefix", "prop")

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(CAPTURE_SIZE if _capture_mode else WINDOW_SIZE)

	_setup_environment()
	_setup_camera()
	_setup_ground()
	_setup_prop()
	_setup_cat()

	if _prop == null:
		_log("ECHEC : %s introuvable" % _model)
		_finish()
		return

	if _capture_mode:
		await _capture_turntable()
		await _capture_scale()
		_finish()
	else:
		set_process_unhandled_input(true)


# ---------------------------------------------------------------- mise en place

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#F5ECD8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _setup_camera() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_camera = Camera3D.new()
	_camera.set_perspective(CAM_FOV_DEG, 0.05, 400.0)
	_pivot.add_child(_camera)
	_update_camera()


## Le vrai parquet du jeu, pas un damier de banc : un modele se juge sur le sol
## sur lequel il sera pose, sa couleur devant s'en detacher.
func _setup_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(120.0, 120.0)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = CelStyle.make_ground()
	add_child(node)


func _setup_prop() -> void:
	_prop = CelProp.spawn(_model, _variant, _outline_scale, _family)

	if _prop == null:
		return

	add_child(_prop)

	var mesh_instance := CelProp.find_mesh(_prop)

	if mesh_instance == null:
		return

	var mesh: Mesh = mesh_instance.mesh
	_bounds = mesh.get_aabb()

	# Un ramassable sort de Blender CENTRE sur son origine, un meuble pose sur
	# ses pieds : sans correction, la moitie de la croquette passerait sous le
	# parquet. On la remonte donc a son ras du sol, puis a sa hauteur de vol.
	if _bounds.position.y < -0.001:
		_prop.position.y = -_bounds.position.y

	_prop.position.y += _hover

	var span := maxf(_bounds.size.x, maxf(_bounds.size.y, _bounds.size.z))
	_turn_distance = maxf(span * TURN_FILL, 0.6)
	_distance = _turn_distance
	_target = _prop.position + _bounds.get_center()
	_update_camera()

	_log("%s — %d surfaces, %d tris, emprise %.3f x %.3f x %.3f" % [
		_model.get_file(), mesh.get_surface_count(), _triangles(mesh),
		_bounds.size.x, _bounds.size.y, _bounds.size.z,
	])
	_log("famille %s, tour de camera a %.2f m" % [_family, _turn_distance])
	_log("Attr_Style (min/moy/max) — neutre : R 1.0, G 0.5, B 0.0")
	for line in CelProp.style_report(mesh):
		_log(line)


func _triangles(mesh: Mesh) -> int:
	var total := 0

	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var corners := (indices.size() if not indices.is_empty()
				else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		# Un maillage triangule : la division tombe juste par construction.
		@warning_ignore("integer_division")
		total += corners / 3

	return total


func _setup_cat() -> void:
	_cat = CelModel.new()
	_cat.name = "CelModel"
	# Convention du jeu : le chat sort du glTF en regardant +Z, l'avant de Godot
	# est -Z. Le banc du chat garde 0, celui-ci prend celle du jeu.
	_cat.yaw_offset_deg = 180.0
	add_child(_cat)
	_place_cat_beside()


## Debout a cote du modele, tourne vers la camera de face.
func _place_cat_beside() -> void:
	_cat.position = Vector3(_bounds.size.x * 0.5 + CAT_CLEARANCE, 0.0, _bounds.size.z * 0.5)
	_cat.rotation_degrees.y = 0.0


## Assis sur l'assise — la posture que la mecanique de saut vise.
func _place_cat_on_seat() -> void:
	_cat.position = Vector3(0.0, _seat, _bounds.get_center().z)
	_cat.rotation_degrees.y = 0.0


func _update_camera() -> void:
	_pivot.rotation_degrees.y = _yaw
	var pitch := deg_to_rad(_pitch)
	_camera.position = _target + Vector3(0.0, _distance * sin(pitch), _distance * cos(pitch))
	_camera.look_at(_target, Vector3.UP)


# ------------------------------------------------------------------ interactif

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_distance = maxf(0.3, _distance - _turn_distance * 0.08)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_distance = minf(80.0, _distance + _turn_distance * 0.08)
				_update_camera()

	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.35
		_pitch = clampf(_pitch + event.relative.y * 0.35, -10.0, 89.0)
		_update_camera()

	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_C:
				if _seat >= 0.0:
					_place_cat_on_seat()
			KEY_V:
				_place_cat_beside()
			KEY_G:
				_distance = GAME_DISTANCE
				_update_camera()
			KEY_R:
				_yaw = 0.0
				_pitch = CAM_PITCH_DEG
				_distance = _turn_distance
				_update_camera()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				_yaw = float(ANGLES[event.keycode - KEY_1])
				_update_camera()


# --------------------------------------------------------------------- capture

func _capture_turntable() -> void:
	if not DirAccess.dir_exists_absolute(_capture_dir):
		DirAccess.make_dir_recursive_absolute(_capture_dir)

	# Le chat s'ecarte du cadre : ce tour-ci juge la silhouette du MODELE, et un
	# chat plante a cote la masquerait a un azimut sur deux.
	_cat.position = Vector3(0.0, 0.0, 200.0)
	_distance = _turn_distance

	for angle in ANGLES:
		_yaw = float(angle)
		_update_camera()
		await _shot("%s_%03d" % [_prefix, angle])

	_log("tour de camera 8 directions -> %s_*.png" % _prefix)


## Les seules images qui tranchent la question de la taille.
func _capture_scale() -> void:
	_distance = GAME_DISTANCE
	_yaw = 0.0

	_place_cat_beside()
	_update_camera()
	await _shot("%s_echelle_a_cote" % _prefix)

	if _seat >= 0.0:
		_place_cat_on_seat()
		_update_camera()
		await _shot("%s_echelle_sur_assise" % _prefix)

	# De trois quarts arriere : c'est la que le dossier peut avaler le chat, et
	# c'est le cas d'occultation que la Todo signale depuis le passage a 45°.
	_yaw = 180.0
	_update_camera()
	await _shot("%s_echelle_de_dos" % _prefix)

	_log("echelle au cadrage de jeu (%.0f m, FOV %.0f) -> %s_echelle_*.png"
			% [GAME_DISTANCE, CAM_FOV_DEG, _prefix])


func _shot(name: String) -> void:
	# Deux frames : une pour appliquer la transformation, une pour la dessiner.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_capture_dir, name]
	var err := get_viewport().get_texture().get_image().save_png(path)

	if err != OK:
		_log("ECHEC capture %s (err %d)" % [path, err])


func _log(line: String) -> void:
	print("[prop_test] ", line)


func _finish() -> void:
	print("[prop_test] ---- fin ----")
	get_tree().quit()
