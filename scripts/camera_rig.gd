class_name CameraRig
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
##
## ⚠️ DESCENDUE DE (17, 16) A (14, 13) LE 2026-08-20, AVEC LES BAIES — et dans
## le sens inverse de celui qu'annoncait §4.7, qui prevoyait qu'un mur plus
## haut devrait faire MONTER la marge. La geometrie dit le contraire, et c'est
## verifiable sur les nombres du rig : le cadre montre 16,1 m devant le point
## vise, donc a 16 de marge le PIED du mur affleure deja le bord haut et toute
## sa hauteur est au-dessus du cadre. Ce n'est pas « le mur reste au bord »,
## c'est « le mur n'est jamais dans l'image » — vrai a 1,2 m, sans consequence
## tant qu'il n'y avait rien dessus.
##
## A 13, le pied du mur tombe a ~34° sous l'horizon pour un cadre qui va de 32°
## a 56° : le mur occupe la bande haute, coupe par le haut, et les rais de ses
## baies (1,95 a 4,0 m du mur) tombent en pleine image. C'est le seul reglage
## qui rend les fenetres visibles, et il ne se compense pas ailleurs — la
## hauteur du mur et cette marge ne peuvent pas etre decidees separement.
@export var arena_margin: Vector2 = Vector2(14.0, 13.0)

## Le cadrage de la fin de run — "Visual Art Direction" §7bis.4. DISTANCE ET
## HAUTEUR DE VISEE, rien d'autre.
##
## ⛔ `pitch_deg` NE BOUGE PAS, et c'est contre-intuitif : un portrait demande
## une camera plus basse, mais tout le decor peint est projete a 44,02° (§2quater)
## et son UV est CUITE a cet angle. Changer la plongee ferait glisser
## l'illustration de chaque meuble encore au cadre, a 268 px/m.
##
## `REST_SHIFT_X` decale le point vise a droite du chat, donc le chat a GAUCHE
## du cadre — au tiers, pour laisser la droite au carton. Ca ne marche que parce
## que le rig n'a pas de lacet : le +X monde est le +X ecran.
##
## ⚠️ 6,4 m ET 1,15 m, PAS LES 5,7 / 0,72 DE §7bis.4 — et c'est la capture qui
## l'a dit. Le chiffre de la DA comptait un chat replie de 1,10 m apparent ; le
## chat tuxedo en pain s'allonge sur ~1,8 m avec sa queue, et il REGARDE VERS
## LE CARTON (`main.REST_YAW`) : sa tete est le bord droit de sa silhouette. A
## 5,7 / 0,72 le carton recouvrait l'oeil droit. A 6,4 m le cadre fait 2,72 m
## de haut, le chat en prend encore ~40 %.
const REST_DISTANCE := 6.4
const REST_LOOK_HEIGHT := 0.35
const REST_SHIFT_X := 1.15
## Le zoom est LISSE (la camera est rangee avec le deplacement, §7) :
## cubique, ease-out.
const REST_ZOOM_TIME := 0.90

@onready var camera: Camera3D = $Camera3D

var _target: Node3D
## Le directeur de jeu — INJECTE par `main._ready()`, plus cherche par groupe a
## la premiere frame (P3 de la revue de code). Ce rig etait le seul des six
## sites a mettre le resultat en cache ; il n'a plus rien a mettre en cache.
var _game: GameRoot

# Le zoom de fin de run : d'ou il part, depuis quand. -1 tant qu'il n'a pas
# commence. Une fois lance, la camera ne suit plus personne — le chat dort.
var _zoom_time := -1.0
var _zoom_from_position := Vector3.ZERO
var _zoom_from_distance := 0.0
var _zoom_from_look := 0.0


## Qui dirige la run. Appelee une fois, par `main._ready()` — avant
## `snap_to_target()`, qui a besoin du rectangle d'arene.
func setup(game_root: GameRoot) -> void:
	_game = game_root


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

	if _zoom_time >= 0.0:
		_advance_zoom(delta)
		return

	var wanted := _focus_point(_target.get_global_transform_interpolated().origin)
	# Lissage independant du framerate.
	global_position = global_position.lerp(wanted, 1.0 - exp(-follow_speed * delta))


## Descend sur le chat — la fin de run, §7bis.4.
##
## ⚠️ LE RIG DOIT TOURNER PENDANT LA PAUSE : c'est a l'appelant de le passer en
## PROCESS_MODE_ALWAYS, comme le modele du chat.
##
## ⛔ LE CLAMP D'ARENE EST COUPE, ET AVANT DE PARTIR. `_focus_point()` tient le
## point vise a `arena_margin` (14, 13) m du bord, une marge faite pour qu'a
## 38 m le mur reste en haut de l'image. Le cadre de fin fait 4,31 m de large :
## un chat endormi pres d'un mur serait tenu jusqu'a 14 m hors du cadre. Le zoom
## part donc de la position COURANTE du rig (bornee) vers le point non borne —
## pas de saut, et une arrivee juste.
func zoom_to_rest() -> void:
	_zoom_time = 0.0
	_zoom_from_position = global_position
	_zoom_from_distance = distance
	_zoom_from_look = look_height


## Le meme cadrage, sans le trajet : la fin de run coupee par le joueur.
func snap_to_rest() -> void:
	if _zoom_time < 0.0:
		zoom_to_rest()
	_zoom_time = REST_ZOOM_TIME
	_advance_zoom(0.0)


func _advance_zoom(delta: float) -> void:
	_zoom_time = minf(_zoom_time + delta, REST_ZOOM_TIME)
	var t := _zoom_time / REST_ZOOM_TIME
	var k := 1.0 - pow(1.0 - t, 3.0)

	var cat := _target.global_position
	var rest_focus := Vector3(cat.x + REST_SHIFT_X, 0.0, cat.z)
	global_position = _zoom_from_position.lerp(rest_focus, k)
	distance = lerpf(_zoom_from_distance, REST_DISTANCE, k)
	look_height = lerpf(_zoom_from_look, REST_LOOK_HEIGHT, k)

	# ⚠️ A CHAQUE FRAME : la position et l'orientation de la camera sont DERIVEES
	# de `distance` et `look_height`, et ne se calculent qu'ici. Animer les deux
	# reglages sans rappeler `_place_camera()` ne bougerait rien.
	_place_camera()


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
		return focus

	var bounds := _game.get_arena_rect().grow_individual(
		-arena_margin.x, -arena_margin.y, -arena_margin.x, -arena_margin.y
	)

	# Arene plus petite que le cadre : on reste centre plutot que de coincer.
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector3(_game.get_arena_rect().get_center().x, 0.0, _game.get_arena_rect().get_center().y)

	focus.x = clampf(focus.x, bounds.position.x, bounds.end.x)
	focus.z = clampf(focus.z, bounds.position.y, bounds.end.y)
	return focus
