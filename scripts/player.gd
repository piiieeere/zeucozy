extends CharacterBody3D

## Le joueur — le chat.
##
## Passe en nodes 3D avec le pivot graphique. La logique est celle d'avant :
## seules les Vector2 sont devenues des Vector3 dans le plan XZ, et les
## valeurs de reglage sont passees du pixel au metre (1 m ≈ 20 px d'avant).
## Voir "Pipeline 3D", section "2D ou 3D cote nodes Godot".

const UpgradeDefinitions = preload("res://scripts/systems/upgrade_definitions.gd")
const CelStyle := preload("res://scripts/systems/cel_style.gd")

signal health_changed(current_health: int, max_health: int)
signal xp_changed(current_xp: int, xp_required: int, level: int)
signal level_up_requested(choices)
signal stats_changed(stats_text: String)
signal died

@export var speed: float = 7.5
@export var max_health: int = 6
@export var attack_interval: float = 0.55
@export var projectile_damage: int = 1
@export var projectile_speed: float = 17.5
@export var projectile_range: float = 10.0
@export var pickup_radius: float = 2.5

## Vitesse de rotation du modele vers la direction de marche. Le chat ne
## claque pas d'un cap a l'autre, il tourne.
@export var turn_speed: float = 12.0

## Hauteur de depart des projectiles — a hauteur de museau, pas des pattes.
@export var muzzle_height: float = 0.7

@onready var model: Node3D = $Model
@onready var pickup_collision: CollisionShape3D = $PickupArea/CollisionShape3D

var health: int
var level := 1
var current_xp := 0
var xp_to_next := 5
var attack_cooldown := 0.0
var invulnerability_timer := 0.0
## Vers la camera au depart : on ouvre sur le visage du chat, pas sur son dos.
var facing_direction := Vector3.BACK


func _ready() -> void:
	add_to_group("player")
	health = max_health
	CelStyle.apply_contact_shadow($Shadow)
	_sync_pickup_radius()
	_emit_all_state()


func _physics_process(delta: float) -> void:
	if _is_run_paused():
		velocity = Vector3.ZERO
		return

	# "up" pousse vers le fond de l'ecran : -Z, l'avant de Godot.
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_direction := Vector3(input.x, 0.0, input.y)

	if input_direction != Vector3.ZERO:
		facing_direction = input_direction.normalized()

	velocity = input_direction * speed
	move_and_slide()

	var game = _get_game()

	if game != null:
		global_position = game.clamp_to_arena(global_position)

	_face_direction(delta)

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
			speed += 0.9
		"max_health":
			max_health += 2
			health = min(max_health, health + 2)
		"pickup_radius":
			pickup_radius += 0.85
			_sync_pickup_radius()
		"projectile_speed":
			projectile_speed += 2.5
			projectile_range += 1.1

	_emit_all_state()


func build_stats_text() -> String:
	return "Degats: %d  Cadence: %.2fs  Vitesse: %.1f  Pickup: %.1f" % [
		projectile_damage,
		attack_interval,
		speed,
		pickup_radius
	]


## Oriente le modele vers la marche. Un objet Godot tourne de rotation.y regarde
## (-sin y, 0, -cos y) : d'ou l'atan2 sur les composantes negatives.
func _face_direction(delta: float) -> void:
	var wanted := atan2(-facing_direction.x, -facing_direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, wanted, 1.0 - exp(-turn_speed * delta))


func _fire_at_nearest_enemy() -> void:
	var game = _get_game()

	if game == null:
		return

	var origin := global_position + Vector3(0.0, muzzle_height, 0.0)
	var direction := facing_direction
	var best_distance := INF

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D

		if not is_instance_valid(enemy):
			continue

		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()

		if distance < best_distance and distance > 0.0:
			best_distance = distance
			direction = to_enemy / distance

	game.spawn_projectile(origin, direction, projectile_damage, projectile_speed, projectile_range)


func _sync_pickup_radius() -> void:
	var sphere := pickup_collision.shape as SphereShape3D

	if sphere != null:
		sphere.radius = pickup_radius


func _emit_all_state() -> void:
	health_changed.emit(health, max_health)
	xp_changed.emit(current_xp, xp_to_next, level)
	stats_changed.emit(build_stats_text())


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _is_run_paused() -> bool:
	var game = _get_game()
	return game != null and game.is_run_paused()
