extends CharacterBody3D

## Le joueur — le chat.
##
## Passe en nodes 3D avec le pivot graphique. La logique est celle d'avant :
## seules les Vector2 sont devenues des Vector3 dans le plan XZ, et les
## valeurs de reglage sont passees du pixel au metre (1 m ≈ 20 px d'avant).
## Voir "Pipeline 3D", section "2D ou 3D cote nodes Godot".
##
## L'attaque automatique est une GRIFFURE au corps a corps (scenes/claw_slash).
## Le projectile n'a pas ete supprime — scene, script et `spawn_projectile` sont
## intacts, et `_fire_at_nearest_enemy` plus bas reste pret a resservir. Il est
## simplement debranche de l'auto-attaque.
##
## Trois choses distinguent la griffure du projectile, et elles vont ensemble :
##   * elle ne vise PAS. Le projectile partait vers l'ennemi le plus proche ; la
##     griffure part dans la direction ou le chat se deplace. Le joueur vise en
##     marchant, ce qui donne au deplacement un second role ;
##   * elle porte court mais frappe fort, et elle touche tout son arc ;
##   * elle ne coute rien a l'animation du chat : c'est un decalque dessine pose
##     devant lui, le squelette continue de jouer idle/walk sans le savoir.

const UpgradeDefinitions = preload("res://scripts/systems/upgrade_definitions.gd")
const CelStyle := preload("res://scripts/systems/cel_style.gd")
const CelModel := preload("res://scripts/systems/cel_model.gd")
const CLAW_SLASH_SCENE := preload("res://scenes/claw_slash.tscn")

signal health_changed(current_health: int, max_health: int)
## Le chat vient d'encaisser un coup — pas l'inverse. C'est ce qu'ecoutent les
## FX de collision ("Visual Art Direction" §8) ; les touches sur les ennemis
## passent par `enemy.take_damage` et ne concernent pas ce signal.
## La position est celle du CONTACT, pas celle du chat : l'eclat se plante la
## ou ca cogne.
signal hit(contact_position: Vector3)
signal xp_changed(current_xp: int, xp_required: int, level: int)
signal level_up_requested(choices)
signal stats_changed(stats_text: String)
signal died

@export var speed: float = 7.5
@export var max_health: int = 6
@export var attack_interval: float = 0.55

## Degats de la griffure. TRES au-dessus du projectile (1), et c'est la
## contrepartie assumee : la griffure ne porte qu'a 3 m et ne se dirige pas
## toute seule. Un chaser de depart tombe donc en un coup, mais il faut aller
## le chercher et lui faire face.
@export var claw_damage: int = 3
## Portee de la griffure, en metres. Le chat fait 1,86 : c'est un peu plus
## d'une longueur de chat devant lui.
##
## Descendue de 3,0 a 2,6 apres lecture des frames : a 3,0 la boite de degats
## portait visiblement plus loin que le dessin ne le laissait croire, et une
## zone d'attaque qui ment est pire qu'une zone courte.
@export var claw_range: float = 2.6
## Ouverture de l'arc griffe, en degres. Large — une patte balaie, elle ne
## pique pas — mais franchement frontal : c'est ce qui fait que la direction
## de marche est une vraie visee.
@export var claw_arc_degrees: float = 120.0

## Le projectile, en sommeil. Conserve pour un usage futur (arme secondaire,
## upgrade, ennemi tireur) : ses reglages continuent donc d'exister et de
## profiter des upgrades, pour qu'il ne se reveille pas perime.
@export var projectile_damage: int = 1
@export var projectile_speed: float = 17.5
@export var projectile_range: float = 10.0

@export var pickup_radius: float = 2.5

## Vitesse de rotation du modele vers la direction de marche. Le chat ne
## claque pas d'un cap a l'autre, il tourne.
@export var turn_speed: float = 12.0

## Hauteur de depart des projectiles — a hauteur de museau, pas des pattes.
@export var muzzle_height: float = 0.7

## Ou se plante l'eclat de collision : a mi-hauteur du chat (il en fait 1,86),
## et decale vers l'agresseur pour ne pas etre a moitie cache derriere lui.
@export var hit_height: float = 0.95
@export var hit_offset: float = 0.55

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
## Une patte puis l'autre. Le balayage de la griffure change de sens a chaque
## coup — sans quoi deux griffures de suite se liraient comme un tampon
## recycle, exactement ce que le `spin` tire au hasard evite a l'eclat.
var claw_side := 1.0


func _ready() -> void:
	add_to_group("player")
	health = max_health
	CelStyle.apply_contact_shadow($Shadow)
	_sync_pickup_radius()
	_emit_all_state()


func _physics_process(delta: float) -> void:
	if _is_run_paused():
		velocity = Vector3.ZERO
		# Choix d'upgrade ou Game Over : le chat s'arrete de marcher, sinon il
		# pietine sur place derriere le panneau.
		_sync_animation(false)
		return

	# "up" pousse vers le fond de l'ecran : -Z, l'avant de Godot.
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_direction := Vector3(input.x, 0.0, input.y)

	if input_direction != Vector3.ZERO:
		facing_direction = input_direction.normalized()

	velocity = input_direction * speed
	move_and_slide()
	_sync_animation(input_direction != Vector3.ZERO)

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
		_slash_forward()


## `attacker_position` est optionnelle : elle sert uniquement a placer l'eclat
## de collision. Sans elle, l'eclat retombe au centre du chat — un degat qui
## ne viendrait d'aucun corps (il n'y en a pas encore) resterait donc lisible.
func take_damage(amount: int, attacker_position: Vector3 = Vector3.INF) -> void:
	if invulnerability_timer > 0.0 or health <= 0:
		return

	health = max(0, health - max(1, amount))
	invulnerability_timer = 0.45
	health_changed.emit(health, max_health)
	# Emis meme sur le coup fatal : un impact sur la derniere touche est
	# precisement le moment ou on veut le voir.
	hit.emit(_contact_point(attacker_position))

	if health <= 0:
		died.emit()


## Le point de contact : entre le chat et ce qui le touche, a mi-hauteur de
## corps. Pas au centre du chat — l'eclat y serait a moitie cache derriere lui
## — et pas sur l'ennemi non plus : c'est le CHAT qui encaisse, le decalque
## doit se lire comme pose sur lui.
func _contact_point(attacker_position: Vector3) -> Vector3:
	var contact := global_position + Vector3(0.0, hit_height, 0.0)

	if attacker_position == Vector3.INF:
		return contact

	var to_attacker := attacker_position - global_position
	to_attacker.y = 0.0

	if to_attacker.length() < 0.001:
		return contact

	return contact + to_attacker.normalized() * hit_offset


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
			claw_damage += 1
			# Le projectile dort, il ne doit pas se reveiller perime : il suit
			# la meme upgrade, sans etre tire pour autant.
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
		"claw_range":
			# Le decalque se dimensionne sur la portee : l'upgrade SE VOIT.
			claw_range += 0.45
		"projectile_speed":
			# Retiree du tirage tant que le projectile dort. Gardee ici pour
			# qu'y revenir soit une ligne dans upgrade_definitions.gd.
			projectile_speed += 2.5
			projectile_range += 1.1

	_emit_all_state()


func build_stats_text() -> String:
	return "Griffure: %d  Cadence: %.2fs  Portee: %.1f  Vitesse: %.1f  Pickup: %.1f" % [
		claw_damage,
		attack_interval,
		claw_range,
		speed,
		pickup_radius
	]


## Le squelette claque sur 3s pendant que la position, elle, reste lisse a 60 :
## c'est le dispositif de "Visual Art Direction" §7, et il ne demande aucun code.
## `move_and_slide` continue de deplacer le chat au metre pres a chaque tick,
## l'AnimationPlayer ne touche qu'aux os. Rien ici n'echantillonne la
## translation — dans un survivor, l'esquive se joue au pixel.
func _sync_animation(moving: bool) -> void:
	model.play(CelModel.ANIM_WALK if moving else CelModel.ANIM_IDLE)


## Oriente le modele vers la marche. Un objet Godot tourne de rotation.y regarde
## (-sin y, 0, -cos y) : d'ou l'atan2 sur les composantes negatives.
func _face_direction(delta: float) -> void:
	var wanted := atan2(-facing_direction.x, -facing_direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, wanted, 1.0 - exp(-turn_speed * delta))


## La griffure part dans la direction de marche — jamais vers un ennemi choisi
## pour le joueur. C'est la difference de fond avec le projectile : ici, se
## deplacer, c'est viser.
##
## Enfant du CHAT, et c'est le point : une griffure est un geste, pas un objet
## lache dans le monde. Plantee au sol elle se detacherait du chat des la
## premiere frame — a 7,5 m/s il avance de 1,5 m pendant les six poses.
func _slash_forward() -> void:
	var slash = CLAW_SLASH_SCENE.instantiate()
	add_child(slash)
	slash.setup(facing_direction, claw_damage, claw_range, claw_arc_degrees, claw_side)
	# Sans ca, l'interpolation physique fait partir le decalque de l'origine du
	# monde sur sa premiere frame — et sa premiere frame est un sixieme de sa vie.
	slash.reset_physics_interpolation()
	claw_side = -claw_side


## EN SOMMEIL — le projectile n'est plus l'attaque automatique. Conserve tel
## quel pour un usage futur : la scene, `projectile.gd` et `spawn_projectile`
## dans main.gd n'ont pas bouge non plus. Le rebrancher tient en une ligne dans
## `_process`.
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
