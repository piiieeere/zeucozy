extends Node3D

## Camera de jeu — vue plongeante qui suit le joueur.
##
## Cadrage tire de "Visual Art Direction" §11 : plongee 45°, longue focale
## (peu de distorsion, profondeur ecrasee — c'est ce qui fait tenir la lecture
## en aplats). La contrepartie est une camera tres loin ; la scene est petite,
## ca ne coute rien.
##
## La camera n'est PAS enfant du joueur : le joueur pivote pour regarder ou il
## va, la camera doit garder son azimut. Elle le suit en position seulement.
##
## Interpolation physique desactivee sur le rig : il bouge dans _process, pas
## dans _physics_process. La laisser active ferait interpoler une position deja
## lissee, donc trainer la camera d'une frame.

@export var target_path: NodePath = NodePath("../Player")

## Plongee, en degres au-dessus de l'horizon.
##
## Abaissee de 60° a 45° le 2026-08-16, apres comparaison a taille de jeu.
## A 60° la croupe passe AU-DESSUS de la tete et avale les oreilles : le chat
## se lit comme un cadenas, pas comme un chat. A 45° la tete redevient un
## disque net, les oreilles se detachent sur le fond et les pattes avant
## reapparaissent — c'est ce qui pose le personnage au sol.
@export var pitch_deg: float = 45.0

## FOV vertical. 24° ≈ un 85 mm — la "focale ~72 mm" de §11 a une frame pres.
@export var fov_deg: float = 24.0

## Distance camera -> point vise. Fixe la taille du chat a l'ecran : a 38 m et
## 24° de FOV, le cadre montre ~16 m de haut, soit un chat a ~11 % de la
## hauteur d'ecran. C'est le reglage a bouger en premier si le chat parait
## trop petit pour juger son rendu.
@export var distance: float = 38.0

## Hauteur du point vise : on cadre le chat, pas ses pattes.
@export var look_height: float = 0.9

@export var follow_speed: float = 6.0

## Marge gardee entre le point vise et le bord de l'arene, pour que le mur
## reste au bord de l'ecran et non en plein milieu.
##
## Le Z depend de la plongee : a 60° le cadre montrait 11 m devant le point
## vise, a 45° il en montre 16. Garder 11 laisserait le mur du fond entrer
## dans l'image avant que la camera ne s'arrete.
@export var arena_margin: Vector2 = Vector2(17.0, 16.0)

@onready var camera: Camera3D = $Camera3D

var _target: Node3D
# Non type : on lui demande get_arena_rect(), qui n'existe que sur son script.
var _game


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_read_cmdline_overrides()
	_target = get_node_or_null(target_path) as Node3D
	_place_camera()


## Cadrage passable en ligne de commande, pour comparer plusieurs plongees
## sans rouvrir l'editeur :
##     ... --path . -- --pitch=50 --distance=38
func _read_cmdline_overrides() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pitch="):
			pitch_deg = float(arg.trim_prefix("--pitch="))
		elif arg.begins_with("--distance="):
			distance = float(arg.trim_prefix("--distance="))
		elif arg.begins_with("--fov="):
			fov_deg = float(arg.trim_prefix("--fov="))


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return

	var wanted := _focus_point(_target.get_global_transform_interpolated().origin)
	# Lissage independant du framerate.
	global_position = global_position.lerp(wanted, 1.0 - exp(-follow_speed * delta))


## Recale la camera sans transition. A appeler apres la mise en place de
## l'arene : au premier ready le rectangle de jeu n'est pas encore connu.
func snap_to_target() -> void:
	if not is_instance_valid(_target):
		return

	global_position = _focus_point(_target.global_position)


func _place_camera() -> void:
	var pitch := deg_to_rad(pitch_deg)
	var height := distance * sin(pitch)
	var back := distance * cos(pitch)

	camera.position = Vector3(0.0, height, back)
	# Pas de look_at : l'orientation est constante par rapport au rig, la
	# recalculer a chaque deplacement ne servirait a rien.
	camera.rotation = Vector3(-atan2(height - look_height, back), 0.0, 0.0)
	camera.fov = fov_deg
	camera.near = 1.0
	camera.far = 400.0


func _focus_point(world_position: Vector3) -> Vector3:
	var focus := Vector3(world_position.x, 0.0, world_position.z)

	if not is_instance_valid(_game):
		_game = get_tree().get_first_node_in_group("game_root")

	if _game == null:
		return focus

	var bounds: Rect2 = _game.get_arena_rect().grow_individual(
		-arena_margin.x, -arena_margin.y, -arena_margin.x, -arena_margin.y
	)

	# Arene plus petite que le cadre : on reste centre plutot que de coincer.
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector3(_game.get_arena_rect().get_center().x, 0.0, _game.get_arena_rect().get_center().y)

	focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
	focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)
	return focus
