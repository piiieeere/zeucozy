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
##   * elle ne cherche personne toute seule. Le projectile partait vers l'ennemi
##     le plus proche ; la griffure part la ou le JOUEUR vise — a la souris
##     depuis le 2026-08-16, au deplacement tant que la souris n'a pas bouge ;
##   * elle porte court mais frappe fort, et elle touche tout son arc ;
##   * elle ne coute rien a l'animation du chat : c'est un decalque dessine pose
##     devant lui, le squelette continue de jouer idle/walk sans le savoir.
##
## LA VISEE EST DISSOCIEE DU DEPLACEMENT (2026-08-16). Marcher vers le bas en
## griffant vers le haut est desormais possible, et c'est tout l'interet : la
## fuite cesse d'etre passive. Le modele regarde la VISEE, pas la marche —
## sinon la griffure partirait de cote, et une griffure est un geste du corps.

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

## La vie est en POINTS depuis le 2026-08-16 — 100, et non plus 6.
##
## Ce n'est pas un changement d'affichage : sur 6 points, un objet qui rend de
## la vie ne peut rendre que 1 (17 % de la barre) ou 0. Toute la famille des
## objets a petit effet continu — vol de vie sur griffure, regeneration lente,
## soin par croquette — etait mecaniquement impossible. Sur 100, un vol de vie
## de 2 par coup est un vrai reglage.
##
## ⚠️ Les degats des ennemis ont ete remis a l'echelle DU MEME FACTEUR (chaser
## 1 → 15, brute 2 → 30, dans leurs .tscn). La survivabilite est donc quasi
## inchangee : 6,7 coups de chaser au lieu de 6, 3,3 coups de brute au lieu
## de 3. Changer l'un sans l'autre rendrait le chat immortel.
@export var max_health: int = 100
## Une griffure toutes les 1,1 s — la cadence a ete DIVISEE PAR DEUX en meme
## temps que la portee doublait (2026-08-16). Les deux vont ensemble : un arc
## de 5,2 m qui balaie deux fois par seconde nettoierait l'ecran sans que le
## joueur ait a se placer, et le placement est tout ce que la griffure a
## apporte.
@export var attack_interval: float = 1.1

## Degats de la griffure. TRES au-dessus du projectile (1), et c'est la
## contrepartie assumee : la griffure ne porte qu'a 3 m et ne se dirige pas
## toute seule. Un chaser de depart tombe donc en un coup, mais il faut aller
## le chercher et lui faire face.
@export var claw_damage: int = 3
## Portee de la griffure, en metres. Le chat fait 1,86 : c'est presque trois
## longueurs de chat devant lui.
##
## DOUBLEE de 2,6 a 5,2 le 2026-08-16. Le dessin suit tout seul — `claw_slash`
## dimensionne son decalque sur cette valeur (voir DRAW_SIZE), justement pour
## que la portee et ce qu'on en voit ne puissent pas diverger.
@export var claw_range: float = 5.2
## Ouverture de l'arc griffe, en degres. Large — une patte balaie, elle ne
## pique pas — mais franchement frontal : c'est ce qui fait de la direction
## visee une vraie visee, et non une decoration.
@export var claw_arc_degrees: float = 120.0

## Hauteur du plan de visee, en metres au-dessus des pattes du chat.
##
## Le curseur est un point 2D : pour en tirer un point du MONDE il faut un
## plan a intersecter. Ce n'est pas le sol — sous 45° de plongee, un metre de
## hauteur decale le point d'un bon demi-metre a l'ecran. On prend la hauteur
## ou la griffure MORD (`claw_slash.HIT_HEIGHT`, 0,7), qui est aussi celle des
## hurtbox ennemies (0,65 sur le chaser, 0,80 sur la brute) : poser le curseur
## sur le corps d'un ennemi donne donc la direction qui le touche vraiment.
@export var aim_height: float = 0.7

## En deca de cette distance, le curseur est POSE SUR le chat : la direction y
## bascule d'un cap a l'autre au moindre pixel de souris. On garde alors la
## derniere visee valable, plutot que de faire pivoter le chat au hasard.
@export var aim_dead_zone: float = 0.8

## Le projectile, en sommeil. Conserve pour un usage futur (arme secondaire,
## upgrade, ennemi tireur) : ses reglages continuent donc d'exister et de
## profiter des upgrades, pour qu'il ne se reveille pas perime.
@export var projectile_damage: int = 1
@export var projectile_speed: float = 17.5
@export var projectile_range: float = 10.0

@export var pickup_radius: float = 2.5

## Vitesse de rotation du modele vers la direction VISEE. Le chat ne claque
## pas d'un cap a l'autre, il tourne — d'autant plus necessaire depuis que la
## souris peut retourner la visee de 180° en une frame.
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

## D'ou vient la visee. La MANETTE viendra s'ajouter ici : une source de plus,
## qui prend la main tant que le stick droit est pousse, exactement comme la
## souris prend la main des qu'elle bouge.
enum AimSource { MOVEMENT, MOUSE }

## On demarre au deplacement, PAS a la souris, et ce n'est pas un detail : le
## curseur est quelque part au lancement sans que le joueur l'y ait mis, et
## dans les captures `--write-movie` il ne bougera jamais. Sans cette bascule,
## le chat prendrait un cap arbitraire des la premiere frame. La souris prend
## la visee au premier mouvement reel — voir `_input`.
var aim_source := AimSource.MOVEMENT

## La direction visee : celle de la griffure, et celle que le modele regarde.
## Vers la camera au depart : on ouvre sur le visage du chat, pas sur son dos.
var aim_direction := Vector3.BACK
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

	velocity = input_direction * speed
	move_and_slide()
	_sync_animation(input_direction != Vector3.ZERO)

	var game = _get_game()

	if game != null:
		global_position = game.clamp_to_arena(global_position)

	# La visee se lit APRES le deplacement : le curseur designe un point du
	# monde, et c'est depuis la position d'arrivee du chat qu'on regarde vers
	# lui. La lire avant ferait viser depuis la case d'avant.
	aim_direction = _read_aim_direction(input_direction)
	_face_direction(delta)

	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta


## La souris prend la visee des qu'elle BOUGE, jamais avant — et ne la rend
## plus. Un simple booleen suffirait aujourd'hui ; l'enum existe parce que la
## manette sera une troisieme source et qu'elle, elle rend la main (stick
## relache = plus de visee au stick).
##
## `_input` et non `_unhandled_input` : un Control en MOUSE_FILTER_STOP — le
## panneau d'upgrade, le HUD — avale les mouvements de souris qui le survolent,
## et le joueur perdrait la visee pour avoir passe le curseur sur son ATH.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		aim_source = AimSource.MOUSE


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
			# +30 % de la vie de depart, et le soin suit — la meme proportion
			# que le +2 sur 6 d'avant. Une upgrade se dose en FRACTION de la
			# barre, jamais en points absolus : +2 sur 100 ne se verrait pas.
			max_health += 30
			health = min(max_health, health + 30)
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
	# Le releve de build, en bas d'ecran. Les separateurs en point median plutot
	# qu'en double espace : a 12 px et en creme assourdi, deux espaces ne
	# separent plus rien et la ligne se lit comme une seule bouillie.
	return "GRIFFURE %d · CADENCE %.2f s · PORTÉE %.1f m · VITESSE %.1f m/s · AIMANT %.1f m" % [
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


## La visee de la frame. Deux sources aujourd'hui, et l'ordre entre elles n'est
## pas negociable : des que la souris a servi, elle garde la visee meme quand
## le chat marche. L'inverse — le deplacement reprenant la main des qu'on
## marche — annulerait exactement la mecanique qu'on vient d'ajouter.
##
## Toute source qui ne sait pas repondre rend la DERNIERE visee, jamais zero :
## une visee qui s'annule ferait pivoter le chat vers un cap arbitraire pendant
## une frame, et la griffure part sur cette frame-la.
func _read_aim_direction(move_direction: Vector3) -> Vector3:
	if aim_source == AimSource.MOUSE:
		var pointed := _mouse_aim_direction()
		return pointed if pointed != Vector3.ZERO else aim_direction

	if move_direction != Vector3.ZERO:
		return move_direction.normalized()

	return aim_direction


## Le curseur -> une direction dans le monde. On tire le rayon de la camera qui
## passe par le pixel du curseur, et on l'intersecte avec le plan horizontal de
## visee (voir `aim_height`).
##
## La camera est prise au viewport et non au rig : le joueur n'a pas a savoir
## qui le filme. Rend ZERO — "je ne sais pas viser cette frame" — dans les
## trois cas ou la reponse ne voudrait rien dire : pas de camera, rayon
## parallele au plan, curseur pose sur le chat.
func _mouse_aim_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()

	if camera == null:
		return Vector3.ZERO

	# `get_mouse_position` rend des coordonnees de viewport, et
	# `project_ray_*` les attend : l'etirement "canvas_items" du projet est
	# defait des deux cotes par Godot, il n'y a rien a compenser ici.
	var screen := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(screen)
	var ray := camera.project_ray_normal(screen)

	if absf(ray.y) < 0.0001:
		return Vector3.ZERO

	var travel := (global_position.y + aim_height - ray_origin.y) / ray.y

	# Le plan est DERRIERE la camera : elle regarde le ciel, ou le curseur est
	# au-dessus de la ligne d'horizon. Le point d'intersection existe encore
	# mathematiquement, mais il est dans le dos du joueur.
	if travel <= 0.0:
		return Vector3.ZERO

	var to_target := ray_origin + ray * travel - global_position
	to_target.y = 0.0

	if to_target.length() < aim_dead_zone:
		return Vector3.ZERO

	return to_target.normalized()


## Oriente le modele vers la VISEE, pas vers la marche. C'est ce qui permet au
## chat de reculer en griffant devant lui, et c'est aussi ce qui garde la
## griffure devant son corps : une patte qui partirait de cote pendant que le
## chat regarde ailleurs ne se lirait plus comme un geste.
##
## Contrepartie assumee : le chat peut desormais marcher a reculons, et il n'a
## qu'un `walk` — le cycle de pattes se lit alors a l'envers.
##
## Un objet Godot tourne de rotation.y regarde (-sin y, 0, -cos y) : d'ou
## l'atan2 sur les composantes negatives.
func _face_direction(delta: float) -> void:
	var wanted := atan2(-aim_direction.x, -aim_direction.z)
	model.rotation.y = lerp_angle(model.rotation.y, wanted, 1.0 - exp(-turn_speed * delta))


## La griffure part dans la direction VISEE — jamais vers un ennemi choisi pour
## le joueur. C'est la difference de fond avec le projectile : ici, c'est le
## joueur qui pointe.
##
## Enfant du CHAT, et c'est le point : une griffure est un geste, pas un objet
## lache dans le monde. Plantee au sol elle se detacherait du chat des la
## premiere frame — a 7,5 m/s il avance de 1,5 m pendant les six poses.
func _slash_forward() -> void:
	var slash = CLAW_SLASH_SCENE.instantiate()
	add_child(slash)
	slash.setup(aim_direction, claw_damage, claw_range, claw_arc_degrees, claw_side)
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
	var direction := aim_direction
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
