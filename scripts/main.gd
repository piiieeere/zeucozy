extends Node2D

const ARENA_SIZE := Vector2(1152.0, 648.0)
const CHASER_SCENE := preload("res://scenes/enemies/chaser.tscn")
const BRUTE_SCENE := preload("res://scenes/enemies/brute.tscn")
const XP_ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

var elapsed_time := 0.0
var spawn_timer := 0.0
var run_paused := false
var game_over := false
var current_upgrade_choices: Array[Dictionary] = []

@onready var player = $Player
@onready var enemies_container: Node2D = $Enemies
@onready var projectiles_container: Node2D = $Projectiles
@onready var pickups_container: Node2D = $Pickups
@onready var time_label: Label = $CanvasLayer/TimeLabel
@onready var health_label: Label = $CanvasLayer/HealthLabel
@onready var xp_label: Label = $CanvasLayer/XPLabel
@onready var stats_label: Label = $CanvasLayer/StatsLabel
@onready var objective_label: Label = $CanvasLayer/ObjectiveLabel
@onready var upgrade_panel: PanelContainer = $CanvasLayer/UpgradePanel
@onready var upgrade_title_label: Label = $CanvasLayer/UpgradePanel/MarginContainer/VBoxContainer/TitleLabel
@onready var upgrade_subtitle_label: Label = $CanvasLayer/UpgradePanel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var upgrade_buttons: Array[Button] = [
	$CanvasLayer/UpgradePanel/MarginContainer/VBoxContainer/ChoiceButton1,
	$CanvasLayer/UpgradePanel/MarginContainer/VBoxContainer/ChoiceButton2,
	$CanvasLayer/UpgradePanel/MarginContainer/VBoxContainer/ChoiceButton3,
]
@onready var game_over_panel: PanelContainer = $CanvasLayer/GameOverPanel
@onready var game_over_summary_label: Label = $CanvasLayer/GameOverPanel/MarginContainer/VBoxContainer/SummaryLabel
@onready var restart_button: Button = $CanvasLayer/GameOverPanel/MarginContainer/VBoxContainer/RestartButton


func _ready() -> void:
	randomize()
	add_to_group("game_root")

	player.health_changed.connect(_on_player_health_changed)
	player.xp_changed.connect(_on_player_xp_changed)
	player.level_up_requested.connect(_on_player_level_up_requested)
	player.stats_changed.connect(_on_player_stats_changed)
	player.died.connect(_on_player_died)

	for index in range(upgrade_buttons.size()):
		upgrade_buttons[index].pressed.connect(_on_upgrade_button_pressed.bind(index))

	restart_button.pressed.connect(_on_restart_button_pressed)

	_on_player_health_changed(player.health, player.max_health)
	_on_player_xp_changed(player.current_xp, player.xp_to_next, player.level)
	_on_player_stats_changed(player.build_stats_text())
	_update_objective_text()
	_update_time_label()


func _process(delta: float) -> void:
	if game_over:
		return

	if run_paused:
		_update_time_label()
		return

	elapsed_time += delta
	spawn_timer -= delta

	if spawn_timer <= 0.0:
		spawn_timer = _get_spawn_interval()
		_spawn_wave()

	_update_time_label()
	_update_objective_text()


func is_run_paused() -> bool:
	return run_paused or game_over


func get_arena_rect() -> Rect2:
	return Rect2(-ARENA_SIZE * 0.5, ARENA_SIZE)


func clamp_to_arena(world_position: Vector2, padding: Vector2 = Vector2(20.0, 20.0)) -> Vector2:
	var arena_rect := get_arena_rect()
	return Vector2(
		clamp(world_position.x, arena_rect.position.x + padding.x, arena_rect.end.x - padding.x),
		clamp(world_position.y, arena_rect.position.y + padding.y, arena_rect.end.y - padding.y)
	)


func spawn_projectile(origin: Vector2, direction: Vector2, damage: int, speed: float, max_distance: float) -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectiles_container.add_child(projectile)
	projectile.global_position = origin
	projectile.setup(direction, damage, speed, max_distance)


func _get_spawn_interval() -> float:
	return max(0.35, 1.2 - elapsed_time * 0.015)


func _spawn_wave() -> void:
	var enemy_count := 1 + int(elapsed_time / 18.0)

	if elapsed_time >= 45.0:
		enemy_count += 1

	for _index in range(enemy_count):
		var enemy_scene := _pick_enemy_scene()
		var enemy = enemy_scene.instantiate()
		var difficulty_scale := 1.0 + elapsed_time / 90.0

		enemies_container.add_child(enemy)
		enemy.global_position = _get_enemy_spawn_position()
		enemy.setup(player, difficulty_scale)
		enemy.defeated.connect(_on_enemy_defeated)


func _pick_enemy_scene() -> PackedScene:
	if elapsed_time < 22.0:
		return CHASER_SCENE

	if randf() < 0.65:
		return CHASER_SCENE

	return BRUTE_SCENE


func _get_enemy_spawn_position() -> Vector2:
	var arena_rect := get_arena_rect()
	var margin := 54.0
	var side := randi() % 4

	match side:
		0:
			return Vector2(randf_range(arena_rect.position.x, arena_rect.end.x), arena_rect.position.y - margin)
		1:
			return Vector2(arena_rect.end.x + margin, randf_range(arena_rect.position.y, arena_rect.end.y))
		2:
			return Vector2(randf_range(arena_rect.position.x, arena_rect.end.x), arena_rect.end.y + margin)
		_:
			return Vector2(arena_rect.position.x - margin, randf_range(arena_rect.position.y, arena_rect.end.y))


func _on_enemy_defeated(world_position: Vector2, xp_value: int) -> void:
	var orb = XP_ORB_SCENE.instantiate()
	pickups_container.add_child(orb)
	orb.global_position = world_position
	orb.xp_value = xp_value


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_label.text = "Vie: %d / %d" % [current_health, max_health]


func _on_player_xp_changed(current_xp: int, xp_required: int, level: int) -> void:
	xp_label.text = "Niveau %d  XP: %d / %d" % [level, current_xp, xp_required]


func _on_player_stats_changed(stats_text: String) -> void:
	stats_label.text = stats_text


func _on_player_level_up_requested(choices: Array[Dictionary]) -> void:
	run_paused = true
	current_upgrade_choices = choices
	upgrade_panel.visible = true
	upgrade_title_label.text = "Niveau %d atteint" % player.level
	upgrade_subtitle_label.text = "Choisis une amelioration pour continuer la run."

	for index in range(upgrade_buttons.size()):
		var button := upgrade_buttons[index]

		if index < current_upgrade_choices.size():
			var choice: Dictionary = current_upgrade_choices[index]
			button.visible = true
			button.text = "%s\n%s" % [choice["title"], choice["description"]]
		else:
			button.visible = false


func _on_upgrade_button_pressed(index: int) -> void:
	if index >= current_upgrade_choices.size():
		return

	player.apply_upgrade(current_upgrade_choices[index]["id"])
	current_upgrade_choices.clear()
	upgrade_panel.visible = false
	run_paused = false
	_update_objective_text()


func _on_player_died() -> void:
	game_over = true
	run_paused = true
	game_over_panel.visible = true
	game_over_summary_label.text = "Survie: %.1f s\nNiveau atteint: %d" % [elapsed_time, player.level]


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()


func _update_time_label() -> void:
	time_label.text = "Temps: %.1f s" % elapsed_time


func _update_objective_text() -> void:
	var next_enemy_text := "Brutes en approche" if elapsed_time >= 22.0 else "Survis et monte en puissance"
	objective_label.text = "%s\nEnnemis actifs: %d" % [next_enemy_text, enemies_container.get_child_count()]
