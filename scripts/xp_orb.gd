extends Area3D

## Croquette d'XP — attiree par le joueur quand il approche.
##
## Deplacee dans _physics_process pour la meme raison que le projectile :
## l'interpolation physique est active sur le projet. Le flottement, lui, est
## purement decoratif et vit sur le node enfant, pour ne pas se battre avec
## l'aimantation qui pilote la position du parent.

const CelStyle := preload("res://scripts/systems/cel_style.gd")

@export var xp_value: int = 1
@export var attraction_speed: float = 7.0
@export var magnet_radius: float = 5.0
@export var body_color: Color = Color("#FFD166")
@export var outline_thickness: float = 0.02

@export var hover_height: float = 0.35
@export var hover_amplitude: float = 0.08
@export var spin_speed: float = 1.6

@onready var body: MeshInstance3D = $Body

var player: Node3D

var _time := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	CelStyle.apply_outlined(body, body_color, outline_thickness)
	# Desynchronise le flottement d'une croquette a l'autre.
	_time = randf() * TAU


func _physics_process(delta: float) -> void:
	if _is_run_paused():
		return

	_time += delta
	body.position.y = hover_height + sin(_time * 3.0) * hover_amplitude
	body.rotate_y(spin_speed * delta)

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	if not is_instance_valid(player):
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	if distance <= magnet_radius:
		var pull_speed := attraction_speed * (1.0 + (magnet_radius - distance) / 3.0)
		global_position = global_position.move_toward(
			global_position + to_player, pull_speed * delta
		)


func _on_area_entered(area: Area3D) -> void:
	var actor = area.get_parent()

	if actor != null and actor.has_method("collect_xp"):
		actor.collect_xp(xp_value)
		queue_free()


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _is_run_paused() -> bool:
	var game = _get_game()
	return game != null and game.is_run_paused()
