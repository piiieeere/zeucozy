extends Area2D

@export var xp_value: int = 1
@export var attraction_speed: float = 220.0

var player: Node2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if _is_run_paused():
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	if not is_instance_valid(player):
		return

	var distance := global_position.distance_to(player.global_position)

	if distance <= 170.0:
		var pull_speed := attraction_speed * (1.0 + (170.0 - distance) / 100.0)
		global_position = global_position.move_toward(player.global_position, pull_speed * delta)


func _on_area_entered(area: Area2D) -> void:
	var actor = area.get_parent()

	if actor != null and actor.has_method("collect_xp"):
		actor.collect_xp(xp_value)
		queue_free()


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _is_run_paused() -> bool:
	var game = _get_game()
	return game != null and game.is_run_paused()
