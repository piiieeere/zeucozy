class_name XpOrb
extends Area3D

## Croquette d'XP — attiree par le joueur quand il approche.
##
## Deplacee dans _physics_process pour la meme raison que le projectile :
## l'interpolation physique est active sur le projet. Le flottement, lui, est
## purement decoratif et vit sur le node enfant, pour ne pas se battre avec
## l'aimantation qui pilote la position du parent.

const CelProp := preload("res://scripts/systems/cel_prop.gd")

## Le trefle a 3 lobes, modelise le 2026-08-19 (`tools/build_kibble.py`).
## 300 tris, 152 sommets — §11 : "Pickups, projectiles | minimal". Avant, c'etait
## un cube de 12 tris ; le budget geometrie n'est donc pas ce qui a change, c'est
## qu'une croquette se lit desormais comme une croquette.
const MODEL := "res://assets/models/xp_croquette.glb"
const VARIANT := "croquette"

@export var xp_value: int = 1
@export var attraction_speed: float = 7.0

@export var hover_height: float = 0.35
@export var hover_amplitude: float = 0.08
@export var spin_speed: float = 1.6

@onready var body: MeshInstance3D = $Body

## Le chat. INJECTE par `main._spawn_xp_orb()` — P3 de la revue de code.
##
## Avant, la croquette le cherchait par groupe A CHAQUE FRAME PHYSIQUE tant
## qu'elle ne l'avait pas ; au pire moment, donc, puisqu'une vague morte en
## seme des dizaines d'un coup.
var player: Player

var _time := 0.0


## Qui l'attire, et ce qu'elle vaut. Appelee par `main` juste apres l'avoir
## posee, avant sa premiere frame.
func setup(new_player: Player, new_xp_value: int) -> void:
	player = new_player
	xp_value = new_xp_value


func _ready() -> void:
	area_entered.connect(_on_area_entered)

	# Maillage ET materiaux viennent du cache de `cel_prop` : une vague morte
	# seme des dizaines de croquettes, et chacune fabriquant les siens on aurait
	# des dizaines de ShaderMaterial pour une seule apparence. C'est le P6 de la
	# revue de code, regle ici par le passage au modele.
	CelProp.dress(body, MODEL, VARIANT, CelProp.PICKUP)

	# Desynchronise le flottement d'une croquette a l'autre.
	_time = randf() * TAU
	# Et son cap. Le cube etait a peu pres le meme sous tous les angles ; un
	# trefle ne l'est pas, et vingt croquettes posees au meme cap se liraient
	# comme une formation, pas comme des miettes tombees par terre.
	body.rotate_y(randf() * TAU)


func _physics_process(delta: float) -> void:
	_time += delta
	body.position.y = hover_height + sin(_time * 3.0) * hover_amplitude
	# Autour du Y du PARENT, pas de l'axe du palet : le modele est couche a plat
	# puis penche dans la scene, et tourner autour du monde le fait vaciller
	# comme une piece lancee — la silhouette change au lieu de defiler.
	body.rotate_y(spin_speed * delta)

	if not is_instance_valid(player):
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	# ⚠️ LE RAYON VIENT DU CHAT, pas d'ici — corrige le 2026-08-19.
	#
	# La croquette portait un `magnet_radius` a elle, constante a 5,0 m. Il
	# etait AU-DESSUS des trois paliers du passif `pickup_radius`
	# (3,35 / 4,20 / 5,05) : la distance de ramasse reelle valait donc 5 m du
	# debut a la fin d'une run, le chat aspirait tout ce qui passait sans avoir
	# a s'en approcher, et prendre le passif ne changeait rien avant son T3.
	# Un chiffre de gameplay porte a deux endroits, c'est le plus fort qui
	# gagne — et ce n'est jamais celui qu'on regle.
	#
	# Relu a chaque frame et non capture au `setup()` : une croquette deja au
	# sol quand le joueur prend l'aimant doit se mettre a venir, sinon la moitie
	# de l'ecran garde l'ancienne portee.
	var magnet := player.pickup_radius

	if distance <= magnet:
		var pull_speed := attraction_speed * (1.0 + (magnet - distance) / 3.0)
		global_position = global_position.move_toward(
			global_position + to_player, pull_speed * delta
		)


func _on_area_entered(area: Area3D) -> void:
	var actor := area.get_parent() as Player

	if actor != null:
		actor.collect_xp(xp_value)
		queue_free()
