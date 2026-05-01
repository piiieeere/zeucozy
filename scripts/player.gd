extends CharacterBody2D

const UpgradeDefinitions = preload("res://scripts/systems/upgrade_definitions.gd")

signal health_changed(current_health: int, max_health: int)
signal xp_changed(current_xp: int, xp_required: int, level: int)
signal level_up_requested(choices)
signal stats_changed(stats_text: String)
signal died

@export var speed: float = 240.0
@export var max_health: int = 6
@export var attack_interval: float = 0.55
@export var projectile_damage: int = 1
@export var projectile_speed: float = 560.0
@export var projectile_range: float = 360.0
@export var pickup_radius: float = 72.0

@onready var pickup_collision: CollisionShape2D = $PickupArea/CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var health: int
var level := 1
var current_xp := 0
var xp_to_next := 5
var attack_cooldown := 0.0
var invulnerability_timer := 0.0
var facing_direction := Vector2.RIGHT


func _ready() -> void:
	add_to_group("player")
	health = max_health
	_sync_pickup_radius()
	_emit_all_state()


func _physics_process(delta: float) -> void:
	if _is_run_paused():
		velocity = Vector2.ZERO
		_play_anim(&"idle")
		return

	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if input_direction != Vector2.ZERO:
		facing_direction = input_direction.normalized()

	velocity = input_direction * speed
	move_and_slide()
	_update_animation(input_direction)

	var game = _get_game()

	if game != null:
		global_position = game.clamp_to_arena(global_position)

	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta


func _process(delta: float) -> void:
	if _is_run_paused():
		return

	attack_cooldown -= delta

	if attack_cooldown <= 0.0:
		attack_cooldown = attack_interval
		_fire_at_nearest_enemy()


func take_damage(amount: int) -> void:
	if invulnerability_timer > 0.0 or health <= 0:
		return

	health = max(0, health - max(1, amount))
	invulnerability_timer = 0.45
	health_changed.emit(health, max_health)

	if health <= 0:
		died.emit()


func collect_xp(amount: int) -> void:
	if amount <= 0:
		return

	current_xp += amount

	if current_xp < xp_to_next:
		xp_changed.emit(current_xp, xp_to_next, level)
		return

	current_xp -= xp_to_next
	level += 1
	xp_to_next = int(round(float(xp_to_next) * 1.35)) + 2
	xp_changed.emit(current_xp, xp_to_next, level)
	level_up_requested.emit(UpgradeDefinitions.roll_choices(3))


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"damage":
			projectile_damage += 1
		"attack_speed":
			attack_interval = max(0.18, attack_interval * 0.85)
		"move_speed":
			speed += 28.0
		"max_health":
			max_health += 2
			health = min(max_health, health + 2)
		"pickup_radius":
			pickup_radius += 24.0
			_sync_pickup_radius()
		"projectile_speed":
			projectile_speed += 80.0
			projectile_range += 35.0

	_emit_all_state()


func build_stats_text() -> String:
	return "Degats: %d  Cadence: %.2fs  Vitesse: %.0f  Pickup: %.0f" % [
		projectile_damage,
		attack_interval,
		speed,
		pickup_radius
	]


func _fire_at_nearest_enemy() -> void:
	var game = _get_game()

	if game == null:
		return

	var direction := facing_direction
	var best_distance := INF

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		var distance := global_position.distance_to(enemy.global_position)

		if distance < best_distance:
			best_distance = distance
			direction = global_position.direction_to(enemy.global_position)

	game.spawn_projectile(global_position, direction, projectile_damage, projectile_speed, projectile_range)


func _sync_pickup_radius() -> void:
	var circle_shape := pickup_collision.shape as CircleShape2D

	if circle_shape != null:
		circle_shape.radius = pickup_radius


func _emit_all_state() -> void:
	health_changed.emit(health, max_health)
	xp_changed.emit(current_xp, xp_to_next, level)
	stats_changed.emit(build_stats_text())


func _update_animation(input_dir: Vector2) -> void:
	if input_dir == Vector2.ZERO:
		_play_anim(&"idle")
		return

	var dx := input_dir.x
	var dy := input_dir.y
	var diagonal: bool = abs(dx) > 0.35 and abs(dy) > 0.35

	if diagonal:
		if dx > 0 and dy > 0:
			_play_anim(&"walk_down_right")
		elif dx < 0 and dy > 0:
			_play_anim(&"walk_down_left")
		elif dx > 0 and dy < 0:
			_play_anim(&"walk_up_right")
		else:
			_play_anim(&"walk_up_left")
	elif abs(dx) >= abs(dy):
		_play_anim(&"walk_right" if dx > 0 else &"walk_left")
	else:
		_play_anim(&"walk_down" if dy > 0 else &"walk_up")


func _play_anim(anim: StringName) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _is_run_paused() -> bool:
	var game = _get_game()
	return game != null and game.is_run_paused()
