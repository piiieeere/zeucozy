extends Area2D

@export var speed: float = 560.0
@export var damage: int = 1
@export var max_distance: float = 360.0

var direction := Vector2.RIGHT
var travelled_distance := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func setup(new_direction: Vector2, new_damage: int, new_speed: float, new_max_distance: float) -> void:
	if new_direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	else:
		direction = new_direction.normalized()

	damage = new_damage
	speed = new_speed
	max_distance = new_max_distance
	rotation = direction.angle()


func _process(delta: float) -> void:
	if _is_run_paused():
		return

	var step := direction * speed * delta
	global_position += step
	travelled_distance += step.length()

	if travelled_distance >= max_distance:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()

	if enemy != null and enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		queue_free()


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _is_run_paused() -> bool:
	var game = _get_game()
	return game != null and game.is_run_paused()
