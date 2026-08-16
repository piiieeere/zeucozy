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
	contact_damage = max(1, int(round(contact_damage * (1.0 + (difficulty_scale - 1.0) * 0.2))))


func _physics_process(delta: float) -> void:
	if _is_run_paused():
		velocity = Vector3.ZERO
		return

	if damage_cooldown > 0.0:
		damage_cooldown -= delta

	if is_instance_valid(target):
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
			actor.take_damage(contact_damage)
			damage_cooldown = 0.7
			break


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
