extends Node3D

## Banc de test des MEUBLES — pendant statique de cel_test.gd.
##
## Un banc separe, et pas une option de celui du chat : cel_test.gd est
## entierement bati sur ce qu'un meuble n'a pas — bascule du visage, sondes de
## skinning, mesure de cadence sur un os. L'y greffer aurait ajoute des branches
## mortes dans le seul fichier qui doit rester lisible pour juger le chat.
##
## Ce que ce banc juge, et que le tour de camera du chat ne pouvait pas :
##
##   1. la SILHOUETTE du meuble sur 8 azimuts — §16 etape 7, non optionnelle ;
##   2. le RAPPORT DE TAILLE au chat, qui est tout l'enjeu du canape : la
##      hauteur du dossier a ete decidee pour que le chat pose sur l'assise le
##      depasse. Ca ne se verifie pas au chiffre, ca se regarde ;
##   3. le meuble AU CADRAGE DE JEU (§16 demande de juger a taille de jeu),
##      pose sur le vrai parquet et non sur un fond neutre.
##
##   "C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" \
##       --path . res://scenes/tests/prop_test.tscn -- --capture

const CelProp := preload("res://scripts/systems/cel_prop.gd")
const CelModel := preload("res://scripts/systems/cel_model.gd")
const CelStyle := preload("res://scripts/systems/cel_style.gd")

const MODEL := "res://assets/models/prop_canape.glb"
const CAPTURE_DIR := "C:/Users/tibo/AppData/Local/Temp/claude/c--Users-tibo-Games-zeucozy/42e46b8e-306f-4ae8-91c9-344ef69f4749/scratchpad"
const CAPTURE_SIZE := Vector2i(720, 720)
const WINDOW_SIZE := Vector2i(1100, 820)

const ANGLES := [0, 45, 90, 135, 180, 225, 270, 315]

# Meme cadrage que la camera de jeu (camera_rig.gd) : plongee 45°, FOV 24°.
# Juger un meuble sous une autre plongee que celle du jeu n'apprend rien —
# c'est precisement l'angle qui avait fait passer le chat pour un cadenas.
const CAM_PITCH_DEG := 45.0
const CAM_FOV_DEG := 24.0

## Distance du tour de camera. Assez pres pour lire le capitonnage.
const TURN_DISTANCE := 22.0

## Distance de jeu, reprise telle quelle de camera_rig.gd. A 38 m et 24° de FOV
## le cadre montre ~16 m de haut, soit un chat a ~11 % de la hauteur d'ecran :
## c'est la seule echelle a laquelle un jugement de lisibilite vaut quelque chose.
const GAME_DISTANCE := 38.0

const TURN_TARGET := Vector3(0.0, 1.6, 0.0)

# Le canape regarde +Z apres la conversion Y-up du glTF : son avant est -Y dans
# Blender, comme celui du chat.
const SEAT_TOP := 1.6
const SEAT_CENTER_Z := 0.35

var _camera: Camera3D
var _pivot: Node3D
var _couch: Node3D
var _cat: Node3D

var _yaw := 0.0
var _pitch := CAM_PITCH_DEG
var _distance := TURN_DISTANCE
var _target := TURN_TARGET
var _dragging := false

var _capture_mode := false
var _capture_dir := CAPTURE_DIR

## Trait du meuble. Par defaut celui du jeu — un banc qui juge le canape sous un
## autre trait que celui qu'il aura en jeu n'apprend rien, exactement comme il
## le jugerait sous une autre plongee. `--decor-outline=` sert a COMPARER.
var _outline_scale := CelProp.OUTLINE_SCALE


func _ready() -> void:
	_capture_mode = "--capture" in OS.get_cmdline_user_args()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pitch="):
			_pitch = float(arg.trim_prefix("--pitch="))
		elif arg.begins_with("--out="):
			_capture_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--decor-outline="):
			_outline_scale = float(arg.trim_prefix("--decor-outline="))

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(CAPTURE_SIZE if _capture_mode else WINDOW_SIZE)

	_setup_environment()
	_setup_camera()
	_setup_ground()
	_setup_couch()
	_setup_cat()

	if _couch == null:
		_log("ECHEC : %s introuvable" % MODEL)
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
	_camera.set_perspective(CAM_FOV_DEG, 0.5, 400.0)
	_pivot.add_child(_camera)
	_update_camera()


## Le vrai parquet du jeu, pas un damier de banc : un meuble se juge sur le sol
## sur lequel il sera pose, sa couleur devant s'en detacher.
func _setup_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(120.0, 120.0)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = CelStyle.make_ground()
	add_child(node)


func _setup_couch() -> void:
	_couch = CelProp.spawn(MODEL, "bleu", _outline_scale)

	if _couch == null:
		return

	add_child(_couch)

	var mesh_instance := _find_mesh(_couch)

	if mesh_instance != null:
		var mesh: Mesh = mesh_instance.mesh
		var aabb := mesh.get_aabb()
		_log("Canape — %d surfaces, emprise %.2f x %.2f x %.2f" % [
			mesh.get_surface_count(), aabb.size.x, aabb.size.y, aabb.size.z,
		])
		_log("Attr_Style (min/moy/max) — neutre : R 1.0, G 0.5, B 0.0")
		for line in CelProp.style_report(mesh):
			_log(line)


func _setup_cat() -> void:
	_cat = CelModel.new()
	_cat.name = "CelModel"
	# Convention du jeu : le chat sort du glTF en regardant +Z, l'avant de Godot
	# est -Z. Le banc du chat garde 0, celui-ci prend celle du jeu.
	_cat.yaw_offset_deg = 180.0
	add_child(_cat)
	_place_cat_beside()


## Debout a cote du canape, tourne vers la camera de face.
func _place_cat_beside() -> void:
	_cat.position = Vector3(4.6, 0.0, 1.8)
	_cat.rotation_degrees.y = 0.0


## Assis sur l'assise centrale — la posture que la mecanique de saut vise.
func _place_cat_on_seat() -> void:
	_cat.position = Vector3(0.0, SEAT_TOP, SEAT_CENTER_Z)
	_cat.rotation_degrees.y = 0.0


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var found := _find_mesh(child)

		if found != null:
			return found

	return null


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
				_distance = maxf(4.0, _distance - 1.5)
				_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_distance = minf(80.0, _distance + 1.5)
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
				_place_cat_on_seat()
			KEY_V:
				_place_cat_beside()
			KEY_G:
				_distance = GAME_DISTANCE
				_update_camera()
			KEY_R:
				_yaw = 0.0
				_pitch = CAM_PITCH_DEG
				_distance = TURN_DISTANCE
				_update_camera()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				_yaw = float(ANGLES[event.keycode - KEY_1])
				_update_camera()


# --------------------------------------------------------------------- capture

func _capture_turntable() -> void:
	if not DirAccess.dir_exists_absolute(_capture_dir):
		DirAccess.make_dir_recursive_absolute(_capture_dir)

	# Le chat s'ecarte du cadre : ce tour-ci juge la silhouette du MEUBLE, et un
	# chat plante a cote la masquerait a un azimut sur deux.
	_cat.position = Vector3(0.0, 0.0, 200.0)

	for angle in ANGLES:
		_yaw = float(angle)
		_update_camera()
		await _shot("prop_%03d" % angle)

	_log("tour de camera 8 directions -> prop_*.png")


## Les trois seules images qui tranchent la question de la hauteur.
func _capture_scale() -> void:
	_distance = GAME_DISTANCE
	_yaw = 0.0

	_place_cat_beside()
	_update_camera()
	await _shot("prop_echelle_a_cote")

	_place_cat_on_seat()
	_update_camera()
	await _shot("prop_echelle_sur_assise")

	# De trois quarts arriere : c'est la que le dossier peut avaler le chat, et
	# c'est le cas d'occultation que la Todo signale depuis le passage a 45°.
	_yaw = 180.0
	_update_camera()
	await _shot("prop_echelle_de_dos")

	_log("echelle au cadrage de jeu (%.0f m, FOV %.0f) -> prop_echelle_*.png"
			% [GAME_DISTANCE, CAM_FOV_DEG])


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
