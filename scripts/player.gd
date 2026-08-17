extends CharacterBody3D

## Le joueur — le chat.
##
## Passe en nodes 3D avec le pivot graphique. La logique est celle d'avant :
## seules les Vector2 sont devenues des Vector3 dans le plan XZ, et les
## valeurs de reglage sont passees du pixel au metre (1 m ≈ 20 px d'avant).
## Voir "Pipeline 3D", section "2D ou 3D cote nodes Godot".
##
## LA VISEE EST DISSOCIEE DU DEPLACEMENT (2026-08-16). Marcher vers le bas en
## griffant vers le haut est desormais possible, et c'est tout l'interet : la
## fuite cesse d'etre passive. Le modele regarde la VISEE, pas la marche —
## sinon la griffure partirait de cote, et une griffure est un geste du corps.
##
## ─── LE CHAT NE PORTE PLUS SES ARMES, IL PORTE UN BUILD (2026-08-17) ───
##
## La griffure etait un compteur en dur dans `_process` et l'haleine puante un
## cas particulier de `apply_upgrade`. Elles sont devenues deux COMPETENCES parmi
## celles que le chat peut porter (voir `systems/skill_set.gd` et `skills/`), et
## ce fichier n'en connait plus que trois choses : leur horloge (`skills.tick`),
## leur visee (`aim_direction`, qu'elles lisent), et les chiffres de CORPS que
## les passifs y ecrivent.
##
## ⚠️ CE QUI RESTE ICI EST LE CORPS DU CHAT, jamais une arme : vitesse, vie,
## rayon d'aimant, visee, animation. C'est la ligne de partage, et elle explique
## pourquoi les trois passifs survivants (`move_speed`, `max_health`,
## `pickup_radius`) sont exactement ceux qui ne touchent aucune arme.
##
## Le projectile n'a pas ete supprime — scene, script et `spawn_projectile` sont
## intacts, et `_fire_at_nearest_enemy` plus bas reste pret a resservir. Il est
## simplement debranche. Le jour ou il revient, il revient en COMPETENCE, pas en
## methode du chat.

const CelStyle := preload("res://scripts/systems/cel_style.gd")
const CelModel := preload("res://scripts/systems/cel_model.gd")
const SkillDefinitions := preload("res://scripts/systems/skill_definitions.gd")
const SkillSet := preload("res://scripts/systems/skill_set.gd")
const BreathAura := preload("res://scripts/systems/breath_aura.gd")
const Locale := preload("res://scripts/systems/locale.gd")

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

## ⛔ MODE TEST — LE CHAT NE PEUT PAS MOURIR. À REPASSER À `false`.
##
## Posé le 2026-08-17 pour pouvoir juger les FX, les compétences et la montée en
## difficulté sans que la run s'arrête. **C'est un état temporaire**, pas une
## option de jeu : il n'y a ni réglage, ni argument de ligne de commande, et
## c'est délibéré — un mode de triche qu'on peut activer est un mode qu'on
## oublie d'éteindre. Ici il n'y a qu'une constante, et elle est fausse ou vraie.
##
## ⚠️ IL N'EST PAS SILENCIEUX, et il ne doit jamais le devenir. `_ready` lève un
## avertissement au lancement, et la barre de vie reste clouée à 100/100 : c'est
## la seule chose qui empêchera de croire à un équilibrage qui tient alors que
## rien ne peut tuer. Le précédent est dans ce fichier même — la montée des
## dégâts de contact était morte pendant des mois sans que rien ne le dise.
const IMMORTAL := true

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
## ennemi tireur) : sa scene, son script et `spawn_projectile` sont intacts.
##
## ⚠️ Ses chiffres NE SUIVENT PLUS AUCUNE UPGRADE depuis le passage aux
## competences. L'ancien `apply_upgrade` montait `projectile_damage` en meme
## temps que la griffure, pour qu'il ne se reveille pas perime ; c'est desormais
## sans objet — le jour ou il revient, il revient en COMPETENCE, avec ses propres
## paliers, et ces trois valeurs ne seront plus que son T1.
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
var invulnerability_timer := 0.0

## Ce que le chat porte — armes ET passifs. Cree en `_ready`, jamais exporte :
## un build est un etat de RUN, il n'a rien a faire dans la scene.
var skills: SkillSet

## Les chiffres de CORPS avant tout passif. Les valeurs de palier etant absolues
## (voir `skill_definitions.gd`), on ne peut pas les empiler sur la valeur
## courante : il faut savoir d'ou l'on part pour pouvoir tout recalculer a
## chaque prise. C'est ce qui rend `_apply_passives` idempotent — et un
## recalcul idempotent est le prerequis du retrait de competence a venir.
## `--autofire` : les deux slots d'ACTIF partent des qu'elles sont pretes.
##
## Sans ca, une competence active est INCAPTURABLE : elle attend un clic, et
## dans un `--write-movie` la souris ne clique jamais. On jugerait donc la
## premiere competence active du jeu sans l'avoir vue une seule fois — ce que ce
## projet a deja paye cher sur la griffure et l'haleine.
var _autofire := false

var _base_speed := 0.0
var _base_max_health := 0
var _base_pickup_radius := 0.0

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

## La direction visee : celle des armes dirigees, et celle que le modele regarde.
## Vers la camera au depart : on ouvre sur le visage du chat, pas sur son dos.
##
## ⚠️ Les competences la LISENT, elles ne l'ecrivent pas. C'est ce qui garde une
## seule visee pour toutes les armes : deux armes dirigees qui tiendraient chacune
## leur cap partiraient dans deux directions differentes sur la meme frame.
var aim_direction := Vector3.BACK


func _ready() -> void:
	add_to_group("player")
	health = max_health

	if IMMORTAL:
		push_warning("MODE TEST : le chat est IMMORTEL (player.gd, const IMMORTAL).")

	_base_speed = speed
	_base_max_health = max_health
	_base_pickup_radius = pickup_radius

	skills = SkillSet.new()
	skills.name = "Skills"
	add_child(skills)
	skills.setup(self)

	# Le chat commence arme. La griffure est la slot AUTO n°1 — la slot "arme
	# DIRIGEE" de §2.3 — et elle est prise a T1 des le depart : c'est ce qui la
	# fait apparaitre dans le pool a partir de son T2, comme n'importe quelle
	# autre competence deja prise.
	for definition in SkillDefinitions.DEFINITIONS:
		if definition.get("starting", false):
			skills.take(definition["id"])

	CelStyle.apply_contact_shadow($Shadow)
	_sync_pickup_radius()
	_apply_skill_preview()
	_emit_all_state()
	_report_build()


## Ouvre des competences au lancement, pour les JUGER a l'image sans avoir a
## jouer jusqu'au level-up qui les propose :
##
##   --breath=1   l'haleine puante au premier palier
##   --breath=3   au troisieme (3,9 m) — pour verifier que le trait ne grossit
##                PAS avec la zone
##   --skill=claw:3   n'importe quelle competence a n'importe quel palier
##
## Meme convention d'arguments utilisateur que `--ui-card=`, `--pitch=` et
## `--decor-outline=` : tout ce projet dit qu'un reglage qu'on ne peut pas
## capturer est un reglage fait a l'aveugle.
##
## `--breath=` est garde tel quel — il est ecrit dans CLAUDE.md et sert deja aux
## captures ; `--skill=` le generalise pour les competences a venir.
func _apply_skill_preview() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--autofire":
			_autofire = true
		elif argument.begins_with("--breath="):
			_preview_skill("breath", int(argument.trim_prefix("--breath=")))
		elif argument.begins_with("--skill="):
			var parts := argument.trim_prefix("--skill=").split(":")
			_preview_skill(parts[0], int(parts[1]) if parts.size() > 1 else 1)


func _preview_skill(id: String, tier: int) -> void:
	for _step in range(maxi(tier - skills.tier_of(id), 0)):
		take_skill(id)


## `--build-report` : ce que le chat porte, en clair, a la sortie standard.
##
## Meme role que `cel_model.animation_report()` pour la cadence en pas — un etat
## qu'on ne peut pas VOIR se verifie par une sonde, jamais a l'oeil. Un palier
## applique de travers ne casse rien et ne se signale pas : le chat frappe
## simplement un peu moins fort qu'il ne devrait, ce que personne ne remarque en
## jouant.
##
## Trois choses qu'il faut lire ensemble, parce qu'un ecart entre elles est
## exactement le defaut qu'on cherche : les paliers pris, les chiffres de corps
## recalcules depuis la base, et le releve d'ATH — qui est ce que le JOUEUR voit.
func _report_build() -> void:
	if not OS.get_cmdline_user_args().has("--build-report"):
		return

	print("── BUILD ──────────────────────────────────────────────")

	for definition in SkillDefinitions.DEFINITIONS:
		var id: String = definition["id"]
		var tier := skills.tier_of(id)
		var kind: String = ["AUTO", "ACTIF", "PASSIF"][definition["kind"]]
		var state := "—" if tier == 0 else "T%d/%d %s" % [
			tier, SkillDefinitions.max_tier(id), skills.values_of(id)
		]
		print("  %-14s %-7s %s" % [id, kind, state])

	print("  slots auto   %d / %d" % [
		skills.used_slots(SkillDefinitions.Kind.AUTO), SkillDefinitions.MAX_AUTO_SLOTS
	])
	print("  slots actifs %d / %d" % [
		skills.used_slots(SkillDefinitions.Kind.ACTIVE), SkillDefinitions.MAX_ACTIVE_SLOTS
	])
	print("  corps        vitesse %.2f · vie %d/%d · aimant %.2f" % [
		speed, health, max_health, pickup_radius
	])
	print("  ATH          %s" % build_stats_text())
	print("  tirage x8 :")

	for _draw in range(8):
		print("    %s" % str(skills.roll(3)))


func _physics_process(delta: float) -> void:
	if _is_run_paused():
		velocity = Vector3.ZERO
		# Choix d'upgrade ou Game Over : le chat s'arrete de marcher, sinon il
		# pietine sur place derriere le panneau.
		_sync_animation(false)
		return

	# "up" pousse vers le fond de l'ecran : -Z, l'avant de Godot.
	#
	# ⚠️ `move_*` et non `ui_*` depuis le 2026-08-17 : le jeu est passe aux
	# touches WASD, posees en code PHYSIQUE (voir `tools/setup_input_map.gd`).
	# Les fleches restent branchees en second. Garder `ui_*` aurait fait deux
	# problemes : le clavier ne serait jamais passe a WASD, et `ui_accept`
	# (Espace) aurait continue d'activer les boutons de l'UI dans le dos du jeu.
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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


## Les deux slots d'ACTIF (§2.4) — clic gauche, clic droit.
##
## ⚠️ DANS `_unhandled_input`, ET C'EST LA TOUT L'INTERET — pas dans `_process`
## par sondage, comme une premiere version le faisait.
##
## Le clic gauche sert AUSSI aux boutons de l'interface : les trois cartes
## d'upgrade, RELANCER, les pastilles de langue. Un sondage de `Input` ne sait
## rien de ce qui a deja consomme le clic ; il aurait donc lu le meme clic deux
## fois, et choisir une amelioration aurait depense la morsure dans la foulee —
## sur la frame ou la run reprend, la garde de pause ne protege plus. Un cooldown
## de 6 s perdu a chaque level-up, sans que rien ne le signale.
##
## Un Control en MOUSE_FILTER_STOP — c'est le cas des cartons — CONSOMME
## l'evenement, et `_unhandled_input` ne le voit jamais. Le partage du clic gauche
## est donc regle par Godot, pas par une condition qu'on aurait pu oublier.
##
## ⚠️ Le HUD permanent, lui, ne consomme rien : sa racine et ses labels sont en
## MOUSE_FILTER_IGNORE. Un actif part donc meme quand le curseur survole l'ATH —
## c'est-a-dire precisement quand on regarde ses pastilles de cooldown.
func _unhandled_input(event: InputEvent) -> void:
	if _is_run_paused():
		return

	if event.is_action_pressed("skill_slot_1"):
		skills.trigger_slot(0)
	elif event.is_action_pressed("skill_slot_2"):
		skills.trigger_slot(1)


## L'HORLOGE DE TOUTES LES COMPETENCES, et le seul endroit ou la pause se teste.
##
## Chaque competence avait la sienne : un compteur en dur ici pour la griffure,
## un `_process` prive avec son propre test de pause pour l'aura d'haleine. A
## seize competences (§2.3), c'est seize endroits ou oublier de s'arreter
## derriere un carton de niveau — un defaut qui ne se VOIT pas, il se constate a
## la barre de vie d'un ennemi.
func _process(delta: float) -> void:
	if _is_run_paused():
		return

	skills.tick(delta)

	# Le declenchement des actifs, lui, est dans `_unhandled_input` — voir plus
	# bas. Ici il n'y a que le mode capture.
	if _autofire:
		skills.trigger_slot(0)
		skills.trigger_slot(1)


## `attacker_position` est optionnelle : elle sert uniquement a placer l'eclat
## de collision. Sans elle, l'eclat retombe au centre du chat — un degat qui
## ne viendrait d'aucun corps (il n'y en a pas encore) resterait donc lisible.
func take_damage(amount: int, attacker_position: Vector3 = Vector3.INF) -> void:
	if invulnerability_timer > 0.0 or health <= 0:
		return

	# ⛔ MODE TEST : le chat encaisse le COUP mais pas les DEGATS. Voir `IMMORTAL`.
	#
	# La coupure est posee ICI et non au-dessus du garde, et c'est tout ce qui
	# separe un mode de test utilisable d'un mode de test trompeur : l'eclat de
	# collision, l'impact frame et l'invulnerabilite de 0,45 s partent quand meme.
	# Sortir plus tot rendrait le chat INTOUCHABLE au lieu d'immortel — plus aucun
	# retour de collision a l'ecran, donc plus moyen de juger un FX de hit, ni de
	# voir qu'on vient de traverser un ennemi.
	var toll: int = 0 if IMMORTAL else max(1, amount)
	health = max(0, health - toll)
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

	var choices := roll_skill_choices(3)

	# ⚠️ LE POOL PEUT ETRE VIDE, ET IL NE POUVAIT PAS L'ETRE AVANT. Les sept
	# upgrades d'origine se reprenaient a l'infini ; les competences plafonnent
	# (§2.2, §2.5), donc une run assez longue finit par tout epuiser — cinq
	# competences aujourd'hui, ca arrive vite.
	#
	# Le niveau monte quand meme, mais AUCUN carton ne s'ouvre : un carton vide
	# mettrait le jeu en pause sans offrir de quoi le relancer — plus rien a
	# cliquer, et Échap ne fait rien pendant un carton de niveau. Le jeu serait
	# bloque pour de bon, exactement comme le bouton REPRENDRE l'avait fait le
	# 2026-08-17.
	#
	# 🅿️ Ce silence est la BONNE reponse tant que le pool est petit ; quand il y
	# aura ~16 competences, il vaudra mieux que le level-up rende autre chose
	# (soin, XP) plutot que rien.
	if not choices.is_empty():
		level_up_requested.emit(choices)


## Le tirage du level-up. Il passe par le build parce qu'il en DEPEND : une
## competence a son palier maximum en sort, une competence neuve n'y entre pas si
## sa famille de slots est pleine. Voir `skill_set.roll`.
func roll_skill_choices(count: int) -> Array[Dictionary]:
	return skills.roll(count)


## Le joueur a choisi une carte. Deux choses seulement, et l'ordre compte :
## le build enregistre le palier, puis le chat en relit ce qui le concerne.
##
## ⚠️ Le chat ne touche a AUCUNE valeur d'arme. Les degats, la cadence et la
## portee de la griffure vivent dans son palier, pas ici — c'est ce qui a fait
## disparaitre l'ancien `apply_upgrade` et ses sept cas particuliers.
func take_skill(id: String) -> void:
	var gained := skills.take(id)

	_apply_passives()

	# Le soin de "Reserve de vie" est un EVENEMENT du palier, pas un etat : il se
	# joue une fois, a la prise. Fusionne aux valeurs permanentes, il resoignerait
	# le chat a chaque recalcul.
	if gained.has("heal"):
		health = mini(max_health, health + int(gained["heal"]))

	_emit_all_state()


## Les chiffres de CORPS, recalcules depuis la base a chaque fois.
##
## Les valeurs de palier etant absolues, il n'y a rien a empiler et rien a
## defaire : un passif absent laisse simplement sa valeur de base. C'est ce qui
## rend cette methode rejouable autant de fois qu'on veut — le prerequis du
## retrait de competence, et du T4 qui transforme au lieu d'ajouter.
func _apply_passives() -> void:
	var values := skills.passive_values()

	speed = float(values.get("speed", _base_speed))
	max_health = int(values.get("max_health", _base_max_health))
	pickup_radius = float(values.get("pickup_radius", _base_pickup_radius))

	health = mini(health, max_health)
	_sync_pickup_radius()


func build_stats_text() -> String:
	# Le releve de build, en bas d'ecran. Les separateurs en point median plutot
	# qu'en double espace : a 12 px et en creme assourdi, deux espaces ne
	# separent plus rien et la ligne se lit comme une seule bouillie.
	#
	# Les chiffres d'arme sont LUS DANS LE BUILD, jamais recopies sur le chat :
	# une valeur recopiee est une valeur qui finit par diverger de sa source,
	# exactement ce qui est arrive entre Blender et Godot sur le visage du chat.
	var claw := skills.values_of("claw")

	var line: String = Locale.t("stats.line") % [
		claw["damage"],
		claw["interval"],
		claw["range"],
		speed,
		pickup_radius
	]

	# Chaque competence n'apparait que si le chat l'a. Une ligne d'ATH qui
	# annoncerait une arme absente serait le pendant exact du mensonge que
	# `projectile_speed` faisait a l'ecran — voir `skill_definitions.gd`.
	if skills.has("hairball"):
		var hairball := skills.values_of("hairball")
		line += Locale.t("stats.hairball") % [hairball["damage"], hairball["range"]]

	if skills.has("bite"):
		var bite := skills.values_of("bite")
		line += Locale.t("stats.bite") % [bite["damage"], bite["cooldown"]]

	if skills.has("breath"):
		var breath := skills.values_of("breath")
		line += Locale.t("stats.breath") % [
			BreathAura.damage_per_second(breath["damage"]),
			breath["radius"]
		]

	return line


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
