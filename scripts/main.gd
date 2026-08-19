class_name GameRoot
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
const Locale := preload("res://scripts/systems/locale.gd")
const SettingsStore := preload("res://scripts/systems/settings_store.gd")
const SkillDefinitions := preload("res://scripts/systems/skill_definitions.gd")
const RenderQuality := preload("res://scripts/systems/render_quality.gd")

## Aire de jeu, en metres. Environ 4 largeurs d'ecran de large — le meme
## rapport qu'avant entre l'arene et le cadre.
const ARENA_SIZE := Vector2(160.0, 90.0)

## Les ennemis apparaissent juste au-dela du cadre (~16 m de haut, ~29 de large).
const SPAWN_DISTANCE := Vector2(11.0, 17.0)

var elapsed_time := 0.0
var spawn_timer := 0.0
var game_over := false
var current_upgrade_choices: Array[Dictionary] = []
## La competence choisie qui attend qu'on lui fasse de la place (§2.3). Vide
## quand aucun echange n'est en cours.
##
## ⚠️ `current_upgrade_choices` N'EST PAS VIDEE PENDANT CE TEMPS, et c'est ce qui
## rend le bouton de retour possible : le carton de niveau se rouvre sur LES
## MEMES trois cartes. Rejouer un tirage ferait du retour une seconde chance
## deguisee — on cliquerait la carte la plus chere expres, pour en obtenir trois
## nouvelles.
var pending_replacement := ""
var arena_rect := Rect2(-ARENA_SIZE * 0.5, ARENA_SIZE)

@onready var player: Player = $Player
@onready var arena: Arena = $Arena
@onready var camera_rig: CameraRig = $CameraRig
# 💤 Plus appele depuis le 2026-08-17 — le flash plein cadre est debranche
# (voir `_on_player_hit`). Garde pour que le rebrancher tienne en une ligne.
@onready var impact_frame: ImpactFrame = $ImpactFrame
@onready var enemies_container: Node3D = $Enemies
@onready var projectiles_container: Node3D = $Projectiles
@onready var pickups_container: Node3D = $Pickups
@onready var _fx_container: Node3D = $Fx
## Toute l'interface passe par la. main.gd ne connait plus AUCUN Label ni aucun
## offset : il envoie des valeurs de jeu, le HUD decide comment elles se
## dessinent. C'est ce qui a permis de supprimer `_update_ui_layout()` et sa
## trentaine de decalages en dur, qui refaisaient a la main le travail des
## ancrages de Godot.
@onready var hud: Hud = $HudLayer/Hud


func _ready() -> void:
	randomize()

	# L'AA de la 3D. Le niveau retenu vit dans `project.godot` et s'applique
	# tout seul ; cet appel n'existe que pour les surcharges de comparaison
	# (`--msaa=`, `--ssaa=`), posees a l'execution plutot qu'editees entre
	# deux captures.
	RenderQuality.apply_cmdline_overrides(get_viewport())

	# AVANT tout affichage. Le HUD est un enfant, donc son `_ready` a deja
	# construit ses labels quand on arrive ici — dans la langue par defaut. C'est
	# `_refresh_text()` en fin de methode qui les remet dans la bonne, et ce
	# detour est VOULU : il fait passer chaque lancement par le chemin du
	# changement de langue, celui qui casserait sans qu'on s'en aperçoive s'il ne
	# servait qu'au menu.
	SettingsStore.load_settings()
	_apply_language_override()

	player.health_changed.connect(_on_player_health_changed)
	player.xp_changed.connect(_on_player_xp_changed)
	player.level_up_requested.connect(_on_player_level_up_requested)
	player.stats_changed.connect(_on_player_stats_changed)
	player.hit.connect(_on_player_hit)
	player.died.connect(_on_player_died)

	hud.choice_selected.connect(_on_upgrade_button_pressed)
	hud.replace_selected.connect(_on_replacement_chosen)
	hud.replace_cancelled.connect(_on_replacement_cancelled)
	hud.restart_pressed.connect(_on_restart_button_pressed)
	hud.language_selected.connect(_on_language_selected)
	hud.settings_close_requested.connect(_close_settings)

	# ⚠️ L'INJECTION AVANT TOUT USAGE — P3 de la revue de code.
	#
	# `main` est le seul node qui connait tout le monde : il instancie l'arene,
	# le chat, la camera et les ennemis. Il n'a donc RIEN a chercher, et
	# personne n'a a le chercher non plus. Avant, six sites appelaient
	# `get_first_node_in_group("game_root")` — une variable globale deguisee :
	# repetee a chaque frame, non typee, declaree nulle part, et impossible a
	# tracer quand elle rend `null`.
	#
	# ⚠️ CE `setup()` PASSE APRES LE `_ready()` DES ENFANTS, et c'est ce qui le
	# rend sur : Godot appelle `_ready` de bas en haut. `player` et `camera_rig`
	# ne peuvent donc pas lire `game` dans leur propre `_ready` — ils ne s'en
	# servent qu'a partir de leur premiere frame, ce qui est vrai des deux.
	player.setup(self)
	camera_rig.setup(self)

	arena.build(arena_rect)
	player.global_position = Vector3(arena_rect.get_center().x, 0.0, arena_rect.get_center().y)
	player.reset_physics_interpolation()
	# Le rectangle de jeu n'existe qu'ici : la camera ne pouvait pas se cadrer
	# toute seule dans son propre _ready.
	camera_rig.snap_to_target()

	_refresh_text()
	_apply_ui_preview()


## Ouvre un carton au lancement, pour le JUGER a l'image sans avoir a jouer
## jusqu'au level-up ou jusqu'a la mort.
##
##   --ui-card=level      le carton de niveau et ses 3 choix
##   --ui-card=replace    le carton "quoi remplacer ?" — demande un build dont
##                        une famille de slots est pleine (voir plus bas)
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
				get_tree().paused = true
				# Le tirage passe par le joueur : il DEPEND du build (une
				# competence a son palier max en sort, une neuve n'y entre pas si
				# ses slots sont pleines). Un tirage tire du catalogue seul
				# montrerait des cartes que le jeu refuserait ensuite.
				current_upgrade_choices = _forced_choices()
				if current_upgrade_choices.is_empty():
					current_upgrade_choices = player.roll_skill_choices(3)
				hud.show_level_card(3, current_upgrade_choices)
			"replace":
				# ⚠️ IL FAUT UN BUILD POUR LE VOIR : ce carton n'existe que quand une
				# famille de slots est pleine. `--skill=bite:1 --skill=hiss:1` la
				# sature, et `--ui-choices=purr:1` dit ce qui frappe a la porte.
				get_tree().paused = true
				var forced := _forced_choices()
				_open_replacement(String(forced[0]["id"]) if not forced.is_empty() else "purr")
			"gameover":
				game_over = true
				get_tree().paused = true
				hud.show_game_over(96.0, 4)
			"settings":
				_open_settings()


## `--ui-choices=claw:2,bite:1,toughness:1` impose les trois cartes du carton de
## niveau, au lieu de les tirer.
##
## ⚠️ CE N'EST PAS UN CONFORT, c'est le pendant de `--autofire` et de `--walk`.
## Le tirage est pondere (AUTO x3, ACTIF x2, PASSIF x1) : une capture au hasard
## sort trois AUTO une fois sur deux, et le code couleur de type — dont TOUT
## l'objet est de separer les trois familles — serait juge sur une image ou une
## seule famille est presente. Une carte de passif n'a par ailleurs pas de
## vignette, donc c'est aussi la seule facon de voir la carte SANS fenetre a cote
## de deux qui en ont.
##
## Une competence inconnue leve, comme partout ailleurs : une faute de frappe
## dans un id doit se voir tout de suite, pas se traduire par une carte manquante.
func _forced_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []

	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--ui-choices="):
			continue

		for token in argument.trim_prefix("--ui-choices=").split(",", false):
			var parts := token.split(":")
			var id := parts[0].strip_edges()
			SkillDefinitions.find(id)
			choices.append({
				"id": id,
				"tier": int(parts[1]) if parts.size() > 1 else 1,
			})

	return choices


## `--lang=en` force la langue au lancement, SANS toucher au fichier de
## preferences : c'est une capture, pas un choix du joueur. Sans ce garde-fou,
## faire une image de la version anglaise reglerait le jeu en anglais pour de
## bon sur la machine.
func _apply_language_override() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--lang="):
			Locale.set_language(argument.trim_prefix("--lang="))


## Échap ouvre et ferme les reglages.
##
## Ils ne s'ouvrent pas par-dessus un autre carton. Pendant le carton de niveau,
## Échap ne fait rien : ce carton attend une decision, et deux cartons empiles
## sur un voile a moitie transparent ne se lisent plus. Pendant le K.O. non plus
## — il n'offre qu'une action, et elle relance le jeu.
##
## ⚠️ LA CONDITION PORTE SUR LES CARTONS AFFICHES, PAS SUR L'ETAT DE PAUSE, et
## c'est une correction : l'ancien `run_paused` etait a la fois l'etat de pause
## et le droit d'ouvrir les reglages. Le jour ou les deux ont divergé — un bouton
## qui fermait la plaque sans relancer le jeu — Échap ne pouvait plus RIEN : rien
## d'ouvert a fermer, et la pause interdisait d'ouvrir. Le jeu etait bloque sans
## issue.
##
## Ici la pause n'est qu'une CONSEQUENCE de ce qui est a l'ecran. Un
## `get_tree().paused` reste a true par erreur ne piege donc plus personne :
## Échap ouvre les reglages, et les refermer relance le jeu.
##
## ⚠️ CETTE METHODE N'EST APPELEE PENDANT LA PAUSE QUE PARCE QUE `Main` EST EN
## PROCESS_MODE_ALWAYS (voir main.tscn). Un node en pause ne recoit plus ni
## `_input` ni `_unhandled_input` : sans ce mode, Échap n'aurait plus jamais
## rouvert les reglages une fois le jeu en pause.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if hud.is_settings_card_open():
		_close_settings()
	elif game_over or hud.is_level_card_open() or hud.is_replace_card_open():
		return
	else:
		_open_settings()

	get_viewport().set_input_as_handled()


func _open_settings() -> void:
	get_tree().paused = true
	hud.show_settings_card()


func _close_settings() -> void:
	hud.close_settings_card()
	get_tree().paused = false


## Le joueur a change de langue. Trois choses, dans cet ordre : on l'applique, on
## l'ecrit sur le disque, on redessine tout le texte a l'ecran.
##
## La sauvegarde est IMMEDIATE et non differee a la fermeture du jeu : une run de
## survivor se termine souvent par un alt-F4, et un reglage perdu la ou le joueur
## croit l'avoir pose est pire que pas de reglage du tout.
func _on_language_selected(code: String) -> void:
	Locale.set_language(code)
	SettingsStore.save_settings()
	_refresh_text()


## Tout le texte de l'ecran, reconstruit. Le HUD reecrit ce qu'il tient lui-meme
## (titres de cartons, libelles de reglages) ; les valeurs de jeu, c'est ICI
## qu'elles vivent, donc c'est d'ici qu'on les repousse.
##
## ⚠️ Rien ne se met a jour tout seul : le HUD n'a pas de source a observer, il
## n'a que ce que main lui a envoye la derniere fois. Une valeur oubliee ici
## resterait affichee dans l'ancienne langue jusqu'a son prochain changement —
## la telemetrie, par exemple, ne bouge qu'au level-up.
func _refresh_text() -> void:
	hud.apply_language()
	_on_player_health_changed(player.health, player.max_health)
	_on_player_xp_changed(player.current_xp, player.xp_to_next, player.level)
	_on_player_stats_changed(player.build_stats_text())
	_update_objective_text()
	_update_time_label()


## ⚠️ CE `_process` TOURNE AUSSI PENDANT LA PAUSE, et c'est a lui de s'arreter.
##
## `Main` est en PROCESS_MODE_ALWAYS pour qu'Échap et les cartons survivent a la
## pause (voir `_unhandled_input`) ; le prix est que le moteur ne l'arrete plus.
## C'est le SEUL node du jeu dans ce cas — tout le reste du monde est en
## PROCESS_MODE_PAUSABLE et n'a plus une seule ligne de garde.
func _process(delta: float) -> void:
	# `game_over` met aussi le jeu en pause : ce test les couvre tous les deux.
	if get_tree().paused:
		return

	elapsed_time += delta
	spawn_timer -= delta

	if spawn_timer <= 0.0:
		spawn_timer = _get_spawn_interval()
		_spawn_wave()

	_update_time_label()
	_update_objective_text()
	# Poussee a chaque frame, contrairement au reste de l'ATH : un cooldown est
	# la seule valeur du jeu qui change en continu sans qu'aucun evenement ne le
	# signale. Le HUD, lui, la QUANTIFIE en crans — le decoupage en pas est une
	# decision de dessin, pas de jeu.
	hud.set_charges(player.skills.charge_report())


## Rectangle de jeu dans le plan XZ : x -> x, y -> z.
func get_arena_rect() -> Rect2:
	return arena_rect


func clamp_to_arena(world_position: Vector3, padding: Vector2 = Vector2(1.0, 1.0)) -> Vector3:
	return Vector3(
		clamp(world_position.x, arena_rect.position.x + padding.x, arena_rect.end.x - padding.x),
		world_position.y,
		clamp(world_position.z, arena_rect.position.y + padding.y, arena_rect.end.y - padding.y)
	)


## Plante un FX dans le monde — l'eclat de collision, une touffe de poussiere.
##
## ⚠️ UNE METHODE, PAS UN ACCES A `$Fx` — P3 de la revue de code. Avant,
## `dust_skill` faisait `game.fx_container.add_child(bunny)` : une competence
## atteignait un node ENFANT d'un autre script, en le nommant. Renommer `$Fx`
## dans main.tscn cassait une arme, en silence, et rien dans la scene ne le
## signalait. Ici le conteneur redevient une affaire interne de `main`.
##
## Le `reset_physics_interpolation()` est fait ICI parce qu'il ne se voit pas
## quand on l'oublie : l'interpolation physique etant active sur le projet, un
## node fraichement place part en trainee depuis l'origine du monde sur sa
## premiere frame — et la premiere frame d'un FX est souvent un quart de sa vie.
func add_fx(node: Node3D, world_position: Vector3) -> void:
	_fx_container.add_child(node)
	node.global_position = world_position
	node.reset_physics_interpolation()


## Les ennemis vivants, TYPES.
##
## ⚠️ Le compte des sites de `get_nodes_in_group("enemies")` est passe de six a
## un — P3. Six competences repetaient la meme boucle : la recherche de groupe,
## le `as Enemy`, le `is_instance_valid`. Six copies d'un preambule, c'est six
## endroits ou en oublier un morceau, et l'oubli ne leve pas : il rend une liste
## un peu plus courte que la verite.
##
## La liste est un INSTANTANE et non un iterateur vif : `take_damage` peut
## liberer un ennemi au milieu de la boucle de l'appelant.
func enemies() -> Array[Enemy]:
	var living: Array[Enemy] = []

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy

		if enemy != null and is_instance_valid(enemy):
			living.append(enemy)

	return living


func spawn_projectile(origin: Vector3, direction: Vector3, damage: int, speed: float, max_distance: float) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
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
		var enemy := enemy_scene.instantiate() as Enemy
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
	var orb := XP_ORB_SCENE.instantiate() as XpOrb
	pickups_container.add_child(orb)
	orb.global_position = Vector3(world_position.x, 0.0, world_position.z)
	orb.reset_physics_interpolation()
	# La croquette cherchait le chat par groupe, a chaque frame physique, tant
	# qu'elle ne l'avait pas trouve. C'est `main` qui la pose : il sait qui elle
	# doit suivre. Meme injection que `enemy.setup(player, ...)` juste au-dessus.
	orb.setup(player, xp_value)


## Le chat encaisse — "Visual Art Direction" §8.
##
## UN seul effet depuis le 2026-08-17 : l'eclat, local, plante au point de
## contact. §8 en demandait deux ("hit → petites etoiles chaudes + flash
## ambre") et ils se repartissaient le travail — l'eclat DIT ou ca a cogne,
## l'impact frame disait que c'etait un coup.
##
## ⚠️ LE FLASH PLEIN CADRE EST DEBRANCHE, a la demande : deux frames d'ambre
## sur toute l'image se lisaient comme un a-coup d'affichage. C'est la couche
## GLOBALE qui part ; celle qui porte l'information reste. Le noeud
## `$ImpactFrame` et son script sont gardes entiers — rebrancher tient a
## reecrire `impact_frame.flash()` ici (voir impact_frame.gd).
func _on_player_hit(contact_position: Vector3) -> void:
	add_fx(HIT_BURST_SCENE.instantiate() as HitBurst, contact_position)


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	hud.set_health(current_health, max_health)


func _on_player_xp_changed(current_xp: int, xp_required: int, level: int) -> void:
	hud.set_xp(current_xp, xp_required, level)


func _on_player_stats_changed(stats_text: String) -> void:
	hud.set_telemetry(stats_text)


func _on_player_level_up_requested(choices: Array[Dictionary]) -> void:
	get_tree().paused = true
	current_upgrade_choices = choices
	hud.show_level_card(player.level, choices)


## Le joueur a choisi une carte.
##
## ⚠️ DEUX SORTIES DEPUIS LE 2026-08-19, et la seconde est le chantier 2 de §2.9 :
## si la competence est NEUVE et que sa famille de slots est pleine, on ne la
## prend pas encore — le carton de niveau s'efface et celui de "quoi remplacer ?"
## prend sa place. Le jeu reste en pause pendant tout l'echange : c'est une seule
## decision en deux temps, pas deux decisions.
func _on_upgrade_button_pressed(index: int) -> void:
	if index >= current_upgrade_choices.size():
		return

	var id := String(current_upgrade_choices[index]["id"])

	if player.skill_needs_replacement(id):
		_open_replacement(id)
		return

	player.take_skill(id)
	current_upgrade_choices.clear()
	hud.hide_level_card()
	get_tree().paused = false
	_update_objective_text()


## Le carton "quoi remplacer ?" — les competences portees qui peuvent ceder leur
## place, avec le palier auquel le joueur les a montees.
##
## ⚠️ LE PALIER VIENT D'ICI ET NON DU HUD, comme tout le reste : le HUD ne sait
## pas ce que le chat porte, il dessine ce qu'on lui envoie. Sans lui, une carte
## a abandonner ne dirait pas ce qu'elle coute — abandonner un T3 et abandonner
## un T1 sont deux decisions differentes.
func _open_replacement(new_id: String) -> void:
	var candidates: Array[Dictionary] = []

	for id in player.skill_replacement_candidates(new_id):
		candidates.append({"id": id, "tier": player.skills.tier_of(id)})

	# ⚠️ Garde-fou, jamais atteint : `skill_set.roll` ne propose une neuve de
	# famille pleine que s'il existe au moins une candidate — un seul et meme
	# calcul des deux cotes. Si la liste sortait vide malgre tout, le carton
	# n'offrirait rien a cliquer et le jeu serait bloque en pause, exactement comme
	# l'a deja fait un pool epuise. On prend alors la carte comme avant.
	if candidates.is_empty():
		push_warning("Remplacement sans candidate pour « %s » : prise directe." % new_id)
		player.take_skill(new_id)
		current_upgrade_choices.clear()
		hud.hide_level_card()
		get_tree().paused = false
		_update_objective_text()
		return

	pending_replacement = new_id
	hud.hide_level_card()
	hud.show_replace_card(new_id, candidates)


## Le joueur a designe la competence qui cede sa place.
func _on_replacement_chosen(old_id: String) -> void:
	if pending_replacement == "":
		return

	player.replace_skill(old_id, pending_replacement)
	pending_replacement = ""
	current_upgrade_choices.clear()
	hud.hide_replace_card()
	get_tree().paused = false
	_update_objective_text()


## Le joueur renonce a l'echange : on lui rend SES TROIS CARTES, pas un nouveau
## tirage. Le carton de niveau se rouvre en pas, comme la premiere fois.
func _on_replacement_cancelled() -> void:
	pending_replacement = ""
	hud.hide_replace_card()

	# La partie ne peut pas reprendre : le level-up n'a toujours pas ete depense.
	if current_upgrade_choices.is_empty():
		get_tree().paused = false
		return

	hud.show_level_card(player.level, current_upgrade_choices)


func _on_player_died() -> void:
	game_over = true
	get_tree().paused = true
	hud.show_game_over(elapsed_time, player.level)


## ⚠️ LA PAUSE SURVIT AU RECHARGEMENT DE SCENE, ET IL FAUT LA LEVER ICI.
##
## `paused` appartient au SceneTree, pas a la scene : recharger depuis le carton
## de K.O. — qui est justement l'ecran ou le jeu est en pause — ferait demarrer
## la nouvelle run figee, sans un carton a l'ecran pour la relancer. Exactement
## le blocage sans issue qu'avait deja produit le bouton REPRENDRE.
func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _update_time_label() -> void:
	hud.set_time(elapsed_time)


func _update_objective_text() -> void:
	var key := "hud.objective_brutes" if elapsed_time >= 22.0 else "hud.objective_survive"
	hud.set_objective(Locale.t(key), enemies_container.get_child_count())
