extends Node3D

## Directeur de jeu — spawn, difficulte, UI.
##
## Passe en nodes 3D avec le pivot graphique. La logique de run n'a pas bouge :
## le plan de jeu est XZ, et les reglages sont passes du pixel au metre
## (1 m ≈ 20 px d'avant). L'arene a une taille FIXE : elle n'a plus de raison
## de dependre de la taille de fenetre maintenant que la camera est une focale
## et non un cadre en pixels.

const CHASER_SCENE := preload("res://scenes/enemies/chaser.tscn")
const BRUTE_SCENE := preload("res://scenes/enemies/brute.tscn")
const XP_ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const HIT_BURST_SCENE := preload("res://scenes/fx/hit_burst.tscn")
const UpgradeDefinitions = preload("res://scripts/systems/upgrade_definitions.gd")

## Aire de jeu, en metres. Environ 4 largeurs d'ecran de large — le meme
## rapport qu'avant entre l'arene et le cadre.
const ARENA_SIZE := Vector2(160.0, 90.0)

## Les ennemis apparaissent juste au-dela du cadre (~16 m de haut, ~29 de large).
const SPAWN_DISTANCE := Vector2(11.0, 17.0)

var elapsed_time := 0.0
var spawn_timer := 0.0
var run_paused := false
var game_over := false
var current_upgrade_choices: Array[Dictionary] = []
var arena_rect := Rect2(-ARENA_SIZE * 0.5, ARENA_SIZE)

@onready var player = $Player
# Non types : ils portent un script et on appelle leurs methodes a eux.
@onready var arena = $Arena
@onready var camera_rig = $CameraRig
@onready var impact_frame = $ImpactFrame
@onready var enemies_container: Node3D = $Enemies
@onready var projectiles_container: Node3D = $Projectiles
@onready var pickups_container: Node3D = $Pickups
@onready var fx_container: Node3D = $Fx
## Toute l'interface passe par la. main.gd ne connait plus AUCUN Label ni aucun
## offset : il envoie des valeurs de jeu, le HUD decide comment elles se
## dessinent. C'est ce qui a permis de supprimer `_update_ui_layout()` et sa
## trentaine de decalages en dur, qui refaisaient a la main le travail des
## ancrages de Godot.
@onready var hud = $HudLayer/Hud


func _ready() -> void:
	randomize()
	add_to_group("game_root")

	player.health_changed.connect(_on_player_health_changed)
	player.xp_changed.connect(_on_player_xp_changed)
	player.level_up_requested.connect(_on_player_level_up_requested)
	player.stats_changed.connect(_on_player_stats_changed)
	player.hit.connect(_on_player_hit)
	player.died.connect(_on_player_died)

	hud.choice_selected.connect(_on_upgrade_button_pressed)
	hud.restart_pressed.connect(_on_restart_button_pressed)

	arena.build(arena_rect)
	player.global_position = Vector3(arena_rect.get_center().x, 0.0, arena_rect.get_center().y)
	player.reset_physics_interpolation()
	# Le rectangle de jeu n'existe qu'ici : la camera ne pouvait pas se cadrer
	# toute seule dans son propre _ready.
	camera_rig.snap_to_target()

	_on_player_health_changed(player.health, player.max_health)
	_on_player_xp_changed(player.current_xp, player.xp_to_next, player.level)
	_on_player_stats_changed(player.build_stats_text())
	_update_objective_text()
	_update_time_label()
	_apply_ui_preview()


## Ouvre un carton au lancement, pour le JUGER a l'image sans avoir a jouer
## jusqu'au level-up ou jusqu'a la mort.
##
##   --ui-card=level      le carton de niveau et ses 3 choix
##   --ui-card=gameover   le carton de K.O.
##
## Meme convention d'arguments utilisateur que `--pitch=` et `--capture` des
## bancs de test : un carton qu'on ne peut pas capturer est un carton qu'on
## regle a l'aveugle, et tout ce projet dit que ca ne marche pas.
func _apply_ui_preview() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--ui-card="):
			continue

		match argument.trim_prefix("--ui-card="):
			"level":
				run_paused = true
				current_upgrade_choices = UpgradeDefinitions.roll_choices(3)
				hud.show_level_card(3, current_upgrade_choices)
			"gameover":
				game_over = true
				run_paused = true
				hud.show_game_over(96.0, 4)


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


## Rectangle de jeu dans le plan XZ : x -> x, y -> z.
func get_arena_rect() -> Rect2:
	return arena_rect


func clamp_to_arena(world_position: Vector3, padding: Vector2 = Vector2(1.0, 1.0)) -> Vector3:
	return Vector3(
		clamp(world_position.x, arena_rect.position.x + padding.x, arena_rect.end.x - padding.x),
		world_position.y,
		clamp(world_position.z, arena_rect.position.y + padding.y, arena_rect.end.y - padding.y)
	)


func spawn_projectile(origin: Vector3, direction: Vector3, damage: int, speed: float, max_distance: float) -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectiles_container.add_child(projectile)
	projectile.global_position = origin
	# Sans ca, l'interpolation physique fait partir la croquette de l'origine
	# du monde sur sa premiere frame.
	projectile.reset_physics_interpolation()
	projectile.setup(direction, damage, speed, max_distance)


func _get_spawn_interval() -> float:
	return max(0.95, 1.35 - elapsed_time * 0.003)


func _spawn_wave() -> void:
	var enemy_count := _get_enemy_count_for_time()

	for _index in range(enemy_count):
		var enemy_scene := _pick_enemy_scene()
		var enemy = enemy_scene.instantiate()
		var difficulty_scale := 1.0 + elapsed_time / 90.0

		enemies_container.add_child(enemy)
		enemy.global_position = _get_enemy_spawn_position()
		enemy.reset_physics_interpolation()
		enemy.setup(player, difficulty_scale)
		enemy.defeated.connect(_on_enemy_defeated)


func _get_enemy_count_for_time() -> int:
	if elapsed_time < 35.0:
		return 1
	if elapsed_time < 70.0:
		return 2
	if elapsed_time < 105.0:
		return 3
	if elapsed_time < 140.0:
		return 4
	return 5


func _pick_enemy_scene() -> PackedScene:
	if elapsed_time < 22.0:
		return CHASER_SCENE

	if randf() < 0.65:
		return CHASER_SCENE

	return BRUTE_SCENE


func _get_enemy_spawn_position() -> Vector3:
	var center := Vector3(arena_rect.get_center().x, 0.0, arena_rect.get_center().y)

	if player == null:
		return center

	var angle := randf() * TAU
	var distance := randf_range(SPAWN_DISTANCE.x, SPAWN_DISTANCE.y)
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * distance
	return clamp_to_arena(player.global_position + offset, Vector2(2.5, 2.5))


func _on_enemy_defeated(world_position: Vector3, xp_value: int) -> void:
	call_deferred("_spawn_xp_orb", world_position, xp_value)


func _spawn_xp_orb(world_position: Vector3, xp_value: int) -> void:
	var orb = XP_ORB_SCENE.instantiate()
	pickups_container.add_child(orb)
	orb.global_position = Vector3(world_position.x, 0.0, world_position.z)
	orb.reset_physics_interpolation()
	orb.xp_value = xp_value


## Le chat encaisse — "Visual Art Direction" §8. Deux effets, et c'est voulu :
## l'eclat DIT ou ca a cogne, l'impact frame dit que c'etait un coup. §8 les
## demande ensemble ("hit → petites etoiles chaudes + flash ambre"), et ils se
## repartissent le travail au lieu de se doubler — l'un est local et tient
## 8 frames, l'autre est plein cadre et n'en tient que 2.
func _on_player_hit(contact_position: Vector3) -> void:
	impact_frame.flash()

	var burst = HIT_BURST_SCENE.instantiate()
	fx_container.add_child(burst)
	burst.global_position = contact_position
	# Sans ca, l'interpolation physique fait partir l'eclat de l'origine du
	# monde sur sa premiere frame — et sa premiere frame est un quart de sa vie.
	burst.reset_physics_interpolation()


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	hud.set_health(current_health, max_health)


func _on_player_xp_changed(current_xp: int, xp_required: int, level: int) -> void:
	hud.set_xp(current_xp, xp_required, level)


func _on_player_stats_changed(stats_text: String) -> void:
	hud.set_telemetry(stats_text)


func _on_player_level_up_requested(choices: Array[Dictionary]) -> void:
	run_paused = true
	current_upgrade_choices = choices
	hud.show_level_card(player.level, choices)


func _on_upgrade_button_pressed(index: int) -> void:
	if index >= current_upgrade_choices.size():
		return

	player.apply_upgrade(current_upgrade_choices[index]["id"])
	current_upgrade_choices.clear()
	hud.hide_level_card()
	run_paused = false
	_update_objective_text()


func _on_player_died() -> void:
	game_over = true
	run_paused = true
	hud.show_game_over(elapsed_time, player.level)


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()


func _update_time_label() -> void:
	hud.set_time(elapsed_time)


func _update_objective_text() -> void:
	var objective := "Brutes en approche" if elapsed_time >= 22.0 else "Survis"
	hud.set_objective(objective, enemies_container.get_child_count())
