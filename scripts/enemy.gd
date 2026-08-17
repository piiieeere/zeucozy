extends CharacterBody3D

## Ennemi de base — suit le joueur et lui fait mal au contact.
##
## Le modele reste un placeholder : l'aspirateur, le chien et le concombre ne
## sont pas modelises ("Pipeline 3D"). La forme est une primitive cel-shadee,
## histoire que la scene se lise dans le meme registre que le chat.

signal defeated(world_position: Vector3, xp_value: int)

@export var base_speed: float = 3.7
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var xp_drop: int = 1

@export var body_color: Color = Color("#FFADAD")
## Epaisseur du contour, en unites monde — proportionnelle a la taille de la
## forme, sinon le placeholder parait sur-cerne ("Visual Art Direction" §11).
@export var outline_thickness: float = 0.03

const CelStyle := preload("res://scripts/systems/cel_style.gd")

@onready var damage_area: Area3D = $DamageArea
@onready var body: MeshInstance3D = $Body
@onready var shadow: MeshInstance3D = $Shadow

var current_health := 0
var target: Node3D
var damage_cooldown := 0.0

## Le RECUL — vitesse imposee de l'exterieur, qui remplace la poursuite tant
## qu'elle n'est pas retombee. Posee par `push()`, freinee par `_knockback_drag`.
##
## ⚠️ Elle REMPLACE la poursuite au lieu de s'y ajouter, et c'est ce qui la rend
## lisible : additionnee, une poussee de 15 m/s contre une course de 3,7 m/s
## donne 11,3 m/s, soit le meme mouvement en un peu moins fort — le joueur ne
## verrait pas le recul, il verrait un ennemi qui rame. Remplacee, l'ennemi part
## en arriere pour de bon, puis reprend sa marche : deux etats nets plutot qu'un
## melange, ce qui est la meme regle que les poses tenues de §7.
var _knockback := Vector3.ZERO
var _knockback_drag := 32.0


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	CelStyle.apply_outlined(body, body_color, outline_thickness)
	CelStyle.apply_contact_shadow(shadow)


func setup(new_target: Node3D, difficulty_scale: float) -> void:
	target = new_target
	max_health = max(1, int(round(max_health * difficulty_scale)))
	current_health = max_health
	base_speed *= 1.0 + (difficulty_scale - 1.0) * 0.35

	# ⚠️ CETTE LIGNE NE FAISAIT RIEN AVANT LE 2026-08-16, et personne ne pouvait
	# le voir : `contact_damage` valait 1 pour le chaser, donc `round(1 * 1,2)`
	# rendait 1. Il fallait un facteur de 1,5 — soit 225 s de run — pour que le
	# degat passe enfin a 2, c'est-a-dire DOUBLE d'un coup.
	#
	# Le passage de la vie du joueur en points (6 → 100) a remis les degats a
	# l'echelle (1 → 15, 2 → 30), et l'arrondi cesse de tout ecraser : le chaser
	# monte desormais de 15 a ~21 en continu sur une run. C'est un EFFET DE BORD
	# du changement d'echelle, pas une decision d'equilibrage — la montee en
	# difficulte fait enfin ce que cette ligne dit depuis le debut, et la fin de
	# run est donc plus dure qu'avant.
	contact_damage = max(1, int(round(contact_damage * (1.0 + (difficulty_scale - 1.0) * 0.2))))


func _physics_process(delta: float) -> void:
	if _is_run_paused():
		velocity = Vector3.ZERO
		return

	if damage_cooldown > 0.0:
		damage_cooldown -= delta

	if _knockback.length_squared() > 0.01:
		# Repousse : la poursuite attend. Voir `_knockback`.
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector3.ZERO, _knockback_drag * delta)
	elif is_instance_valid(target):
		# Poursuite a plat : tout le jeu vit dans le plan XZ.
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		velocity = to_target.normalized() * base_speed
	else:
		velocity = Vector3.ZERO

	move_and_slide()

	if damage_cooldown > 0.0:
		return

	for area in damage_area.get_overlapping_areas():
		var actor := area.get_parent()

		if actor != null and actor.has_method("take_damage"):
			# La position sert a placer l'eclat de collision, pas a calculer le
			# degat : c'est le chat qui decide ou tombe le point de contact.
			actor.take_damage(contact_damage, global_position)
			damage_cooldown = 0.7
			break


## Repousse. `direction` est la direction DU CHAT VERS L'ENNEMI, deja normalisee
## par l'appelant : c'est lui qui sait d'ou vient l'onde, pas nous.
##
## ⚠️ La composante verticale est ecrasee. Tout le jeu vit dans le plan XZ, et un
## ennemi qui decollerait ne retomberait jamais — rien ici n'a de gravite.
func push(direction: Vector3, speed: float, drag: float) -> void:
	direction.y = 0.0

	if direction.length_squared() < 1e-6:
		return

	# La plus forte gagne, elle ne s'ajoute pas : deux ondes coup sur coup ne
	# doivent pas envoyer un ennemi a l'autre bout de l'arene.
	var wanted := direction.normalized() * speed

	if wanted.length() >= _knockback.length():
		_knockback = wanted
		_knockback_drag = maxf(1.0, drag)


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - max(1, amount))

	if current_health <= 0:
		defeated.emit(global_position, xp_drop)
		queue_free()


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _is_run_paused() -> bool:
	var game = _get_game()
	return game != null and game.is_run_paused()
