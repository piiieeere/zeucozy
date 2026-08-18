class_name ClawSlash
extends Area3D

## La griffure — l'attaque au corps a corps du chat.
##
## Remplace le projectile comme attaque automatique. Trois differences de fond
## avec lui, et elles vont ensemble :
##
##   * elle ne cherche personne. Le projectile visait l'ennemi le plus proche ;
##     la griffure part dans la direction que le JOUEUR pointe — a la souris,
##     independamment de la marche depuis le 2026-08-16. Reculer en griffant
##     devant soi est donc un mouvement possible ;
##   * elle porte court (~3 m) mais frappe fort, et elle touche TOUT ce qui est
##     dans son arc, pas une seule cible ;
##   * elle est enfant du chat. Un projectile est plante dans le monde et le
##     quitte ; une griffure est un GESTE — la laisser au sol la detacherait du
##     chat des la premiere frame (il avance de 1,5 m pendant les six poses).
##
## Ce script fait deux choses et pas une de plus : avancer les poses, et
## distribuer les degats pendant les premieres. Toute la FORME est dans
## claw_slash.gdshader, qui, lui, ne sait rien du temps.
##
## Rien ici ne touche a l'animation du chat : le squelette continue de jouer
## idle/walk, la griffure est un decalque pose devant lui.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## La griffure, pose par pose. Poses TENUES, puis une coupe franche : §8 dit que
## les FX "tiennent puis disparaissent d'un coup". Rien n'est interpole d'une
## pose a la suivante — c'est du dessin, pas une courbe.
##
## Le sens de lecture est celui d'un coup de patte : la griffe MORD (court,
## epais, ramasse d'un cote), s'ouvre en balayant, puis file et s'affine
## jusqu'a n'etre plus qu'un cheveu, et la elle n'est plus la.
##
## La dissipation se fait par la FORME (`thick` qui tombe, `taper` qui monte),
## jamais par l'alpha : §8 interdit le fondu.
##
## SIX poses, soit 12 frames a la cadence de §7 (~200 ms) — bien en dessous de
## l'intervalle d'attaque (0,55 s), sinon deux griffures se chevaucheraient.
## `roll` descend de +0,38 a −0,32 rad : c'est le balayage, ~40° d'arc.
##
## `thick` plafonne a 0,115 et non 0,15 : au-dela, les trois traits se touchent
## (ils ne sont ecartes que de 0,175) et la premiere pose se lit comme une
## banane creme, pas comme une patte. Mesure sur les frames du jeu.
const POSES := [
	{"reach": 0.74, "span": 0.55, "thick": 0.115, "taper": 1.4, "roll": 0.38},
	{"reach": 0.90, "span": 0.98, "thick": 0.108, "taper": 1.7, "roll": 0.16},
	{"reach": 0.99, "span": 1.24, "thick": 0.104, "taper": 2.0, "roll": -0.02},
	{"reach": 1.03, "span": 1.36, "thick": 0.076, "taper": 2.4, "roll": -0.15},
	{"reach": 1.06, "span": 1.44, "thick": 0.048, "taper": 3.0, "roll": -0.25},
	{"reach": 1.08, "span": 1.50, "thick": 0.026, "taper": 3.8, "roll": -0.32},
]

## La griffure ne blesse que pendant ses premieres poses — 6 frames, ~100 ms.
## Elle ne doit pas rester une zone de degats pendant que son dessin se dissipe :
## ce qui reste a l'ecran est la TRACE du coup, plus le coup.
const DAMAGE_POSES := 3

## Hauteur de la boite de degats et du dessin, en metres. Le chat fait 1,86 : on
## griffe a mi-corps, pas au sol.
const HIT_HEIGHT := 0.7
const DRAW_HEIGHT := 0.9

## Taille du decalque, en fraction de la portee — une upgrade d'allonge doit
## SE VOIR.
##
## Le dessin est ancre au CENTRE du chat et non devant lui, et c'est voulu :
## c'est un billboard, son arc se place tout seul a `arc_radius` de l'ancre DANS
## LE PLAN DE L'ECRAN. Un decalage monde en plus se ferait ecraser par la
## plongee a 45° (1 m au sol ne vaut que 0,7 m a l'ecran) et la griffure
## remonterait sur le dos du chat des qu'on frappe vers la camera.
const DRAW_SIZE := 1.6

@onready var hitbox: CollisionShape3D = $Hitbox
@onready var blade: MeshInstance3D = $Blade

var direction := Vector3.FORWARD
var damage := 3
var reach := 3.0
var half_angle := deg_to_rad(60.0)

var _material: ShaderMaterial
var _sweep := 1.0
var _pose := -1
var _held := 0.0
## Les ennemis deja touches par CE coup, par identifiant : une griffure ne
## repasse pas deux fois sur la meme cible pendant ses trois poses actives.
## Par id et non par reference — `take_damage` peut liberer l'ennemi.
var _hit_ids: Array[int] = []


func _ready() -> void:
	# Materiau propre a ce coup : `seed` et les poses sont individuels, les
	# partager ferait clignoter toutes les griffures a l'unisson.
	_material = (blade.material_override as ShaderMaterial).duplicate()
	blade.material_override = _material


## `sweep_side` vaut +1 ou -1 : le sens du balayage. Une patte puis l'autre —
## c'est ce qui empeche deux griffures de suite de se lire comme un tampon.
func setup(
	new_direction: Vector3,
	new_damage: int,
	new_reach: float,
	arc_degrees: float,
	sweep_side: float
) -> void:
	direction = Vector3.FORWARD if new_direction == Vector3.ZERO else new_direction.normalized()
	damage = max(1, new_damage)
	reach = maxf(0.5, new_reach)
	half_angle = deg_to_rad(clampf(arc_degrees, 20.0, 340.0) * 0.5)
	_sweep = -1.0 if sweep_side < 0.0 else 1.0

	# Oriente comme le projectile : -Z local = la direction visee.
	rotation.y = atan2(-direction.x, -direction.z)

	# La sphere vient de la scene, donc partagee entre toutes les instances : la
	# dupliquer, sinon une upgrade de portee redimensionnerait aussi les coups
	# deja en vol.
	var sphere := (hitbox.shape as SphereShape3D).duplicate() as SphereShape3D
	sphere.radius = reach * 0.5
	hitbox.shape = sphere
	# Centree a mi-portee : la zone va du chat jusqu'a `reach` devant lui.
	hitbox.position = Vector3(0.0, HIT_HEIGHT, -reach * 0.5)

	blade.position = Vector3(0.0, DRAW_HEIGHT, 0.0)
	_material.set_shader_parameter("size", reach * DRAW_SIZE)
	_material.set_shader_parameter("aim", direction)
	_material.set_shader_parameter("seed", randf())

	_show(0)


func _process(delta: float) -> void:
	if _pose < 0:
		return

	_held += delta

	if _held < FxCadence.FX_POSE:
		return

	_held = 0.0
	_show(_pose + 1)


## Les degats sont distribues dans le tick physique : c'est le seul endroit ou
## les recouvrements d'Area3D sont a jour.
func _physics_process(_delta: float) -> void:
	if _pose < 0 or _pose >= DAMAGE_POSES or _is_run_paused():
		return

	for area in get_overlapping_areas():
		var enemy := area.get_parent() as Enemy

		if enemy == null:
			continue

		var id := enemy.get_instance_id()

		if _hit_ids.has(id):
			continue

		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0

		# La sphere donne la PORTEE, l'angle donne le CAMP. Sans lui la griffure
		# toucherait aussi bien derriere le chat, et la direction — tout
		# l'interet de l'attaque — ne servirait plus qu'a decorer.
		if to_enemy.length() > 0.001 and to_enemy.normalized().dot(direction) < cos(half_angle):
			continue

		_hit_ids.append(id)
		enemy.take_damage(damage)


func _show(pose: int) -> void:
	# Fin de la sequence : la griffure ne s'estompe pas, elle n'est plus la.
	if pose >= POSES.size():
		queue_free()
		return

	_pose = pose
	var values: Dictionary = POSES[pose]
	_material.set_shader_parameter("reach", values["reach"])
	_material.set_shader_parameter("span", values["span"])
	_material.set_shader_parameter("thick", values["thick"])
	_material.set_shader_parameter("taper", values["taper"])
	_material.set_shader_parameter("roll", float(values["roll"]) * _sweep)


func _get_game() -> GameRoot:
	return get_tree().get_first_node_in_group("game_root") as GameRoot


func _is_run_paused() -> bool:
	var game := _get_game()
	return game != null and game.is_run_paused()
