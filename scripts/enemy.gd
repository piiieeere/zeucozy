extends CharacterBody2D

signal defeated(world_position: Vector2, xp_value: int)

@export var base_speed: float = 110.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var xp_drop: int = 1

@onready var damage_area: Area2D = $DamageArea

var current_health := 0
var target: Node2D
var damage_cooldown := 0.0


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health


func setup(new_target: Node2D, difficulty_scale: float) -> void:
	target = new_target
	max_health = max(1, int(round(max_health * difficulty_scale)))
	current_health = max_health
	base_speed *= 1.0 + (difficulty_scale - 1.0) * 0.35
	contact_damage = max(1, int(round(contact_damage * (1.0 + (difficulty_scale - 1.0) * 0.2))))


func _physics_process(delta: float) -> void:
	if _is_run_paused():
		velocity = Vector2.ZERO
		return

	if damage_cooldown > 0.0:
		damage_cooldown -= delta

	if is_instance_valid(target):
		velocity = global_position.direction_to(target.global_position) * base_speed
	else:
		velocity = Vector2.ZERO

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
