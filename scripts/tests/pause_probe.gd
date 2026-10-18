extends Node

## ⏸️ Banc de PAUSE — ce qui s'arrete, ce qui continue, et ce qui repart.
##
## La pause est celle du moteur depuis le 2026-08-18 (P1 de la revue de code) :
## `get_tree().paused`, `Main` en PROCESS_MODE_ALWAYS, tout le monde en
## PROCESS_MODE_PAUSABLE. Elle ne tient donc plus a une garde qu'on lit dans un
## fichier, mais a un `process_mode` pose dans main.tscn — et un
## `process_mode` OUBLIE NE SE VOIT NULLE PART. Ajouter un node de gameplay sous
## `Main` sans lui poser `process_mode = 1` le fait tourner derriere les cartons,
## sans erreur, sans warning, sans rien a l'ecran.
##
## C'est exactement le defaut que P1 a corrige : `claw_slash._process` n'avait
## aucune garde, ses six poses defilaient pendant le carton de niveau et sa
## fenetre de degats etait sautee. Personne ne l'a jamais vu en jouant.
##
##   godot --headless --path . res://scenes/tests/pause_probe.tscn
##
## Le banc mesure les deux sens, et les deux comptent autant : le monde doit se
## FIGER (temps, chat, ennemis, poses de FX) et l'interface doit VIVRE (le carton
## s'ouvre en 4 poses, Échap est recu pendant la pause).

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _game: GameRoot
var _rows: Array[String] = []


func _ready() -> void:
	# ⚠️ Sans ca la sonde se met en pause AVEC le jeu et ne mesure plus rien.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_game = MAIN_SCENE.instantiate() as GameRoot
	add_child(_game)
	await get_tree().process_frame
	await _run()
	get_tree().quit()


func _wait(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


## Attendre en TEMPS, pas en frames : en `--headless` les frames ne sont pas
## cadencees, et la fin de run est une sequence au dixieme de seconde.
## `process_always` et `ignore_time_scale` : le timer doit courir pendant la pause.
func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout


func _say(line: String) -> void:
	_rows.append(line)
	print(line)


func _check(label: String, ok: bool, detail: String) -> void:
	_say("  %s %-46s %s" % ["OK  " if ok else "FAIL", label, detail])


func _escape() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame


func _run() -> void:
	var player := _game.player
	_say("── PAUSE ──────────────────────────────────────────────")

	# ── 1. La run tourne ────────────────────────────────────────────────
	await _wait(6)
	var t_before := _game.elapsed_time
	_check("le temps avance hors pause", t_before > 0.0, "elapsed = %.3f" % t_before)

	# ── 2. Une griffure en vol, puis le carton s'ouvre dessus ───────────
	# C'est le bug que la revue documente : `claw_slash._process` n'avait
	# aucune garde, ses six poses defilaient derriere le panneau et sa fenetre
	# de degats etait sautee.
	player.skills.tick(10.0)
	await get_tree().process_frame
	var slash: ClawSlash = null

	for child in player.get_children():
		if child is ClawSlash:
			slash = child

	if slash == null:
		_check("une griffure est en vol", false, "aucune ClawSlash sous le chat")
	else:
		var pose_before: int = slash._pose
		player.collect_xp(999)
		await _wait(12)
		_check("la griffure ne defile pas derriere le carton",
			is_instance_valid(slash) and slash._pose == pose_before,
			"pose %d -> %s" % [pose_before,
				str(slash._pose) if is_instance_valid(slash) else "liberee"])

	if not _game.get_tree().paused:
		player.collect_xp(999)
		await _wait(4)

	# ── 3. Le monde est fige ────────────────────────────────────────────
	_check("l'arbre est en pause", get_tree().paused, "paused = %s" % get_tree().paused)
	_check("le carton de niveau est ouvert", _game.hud.is_level_card_open(), "")

	var t_paused := _game.elapsed_time
	var pos_paused := player.global_position
	var enemy_positions: Array[Vector3] = []

	for enemy in _game.enemies():
		enemy_positions.append(enemy.global_position)

	await _wait(15)

	_check("le temps ne monte pas", is_equal_approx(t_paused, _game.elapsed_time),
		"%.3f -> %.3f" % [t_paused, _game.elapsed_time])
	_check("le chat ne bouge pas", pos_paused.is_equal_approx(player.global_position),
		"%s" % player.global_position)

	var moved := 0
	var index := 0

	for enemy in _game.enemies():
		if index < enemy_positions.size() \
				and not enemy_positions[index].is_equal_approx(enemy.global_position):
			moved += 1
		index += 1

	_check("aucun ennemi n'avance", moved == 0, "%d / %d bougent" % [moved, index])

	# ── 4. Ce qui DOIT vivre pendant la pause ──────────────────────────
	# Le carton s'ouvre en 4 poses sur un timer `process_always` : si le HUD
	# etait en pause lui aussi, il resterait bloque sur sa premiere pose.
	var content: Control = _game.hud._level_card.get_meta("content")
	_check("le carton a fini de s'ouvrir", content.visible,
		"contenu visible = %s" % content.visible)

	# Échap ne doit RIEN faire pendant un carton de niveau.
	await _escape()
	_check("Échap n'ouvre pas les reglages sur un carton de niveau",
		not _game.hud.is_settings_card_open(), "")

	# ── 5. Le choix relance la run ──────────────────────────────────────
	_game._on_upgrade_button_pressed(0)
	var t_resume := _game.elapsed_time
	await _wait(8)
	_check("le temps repart apres le choix", _game.elapsed_time > t_resume,
		"%.3f -> %.3f" % [t_resume, _game.elapsed_time])
	_check("l'arbre n'est plus en pause", not get_tree().paused, "")

	# ── 6. Échap ouvre et referme les reglages ─────────────────────────
	await _escape()
	_check("Échap met en pause et ouvre les reglages",
		get_tree().paused and _game.hud.is_settings_card_open(), "")

	# Le deuxieme Échap est le test qui compte : il est recu ALORS QUE LE JEU
	# EST EN PAUSE. Il ne passe que parce que `Main` est en PROCESS_MODE_ALWAYS.
	await _escape()
	_check("Échap referme et relance, RECU PENDANT LA PAUSE",
		not get_tree().paused and not _game.hud.is_settings_card_open(), "")

	var t_settings := _game.elapsed_time
	await _wait(6)
	_check("le temps repart apres les reglages", _game.elapsed_time > t_settings,
		"%.3f -> %.3f" % [t_settings, _game.elapsed_time])

	# ── 6bis. Le K.O. met aussi en pause ───────────────────────────────
	# `IMMORTAL` empeche de mourir en jouant : on appelle le handler.
	_game._on_player_died()
	var t_dead := _game.elapsed_time
	await _wait(8)
	_check("le K.O. met le jeu en pause", get_tree().paused, "")
	_check("et le temps s'arrete", is_equal_approx(t_dead, _game.elapsed_time),
		"%.3f -> %.3f" % [t_dead, _game.elapsed_time])

	# ── 6ter. La fin de run : le chat se repose (§7bis.5) ───────────────
	# Tout est fige SAUF le modele du chat et la camera, et seulement apres le
	# temps mort de 0,20 s. Le corps du chat, lui, reste fige : en ALWAYS il
	# lirait les entrees et marcherait en dormant.
	var anim := player.model.animation_player
	_check("la derniere image tient (pas d'assise avant 0,20 s)",
		anim.current_animation != CelModel.ANIM_ASSISE
			and player.model.process_mode != Node.PROCESS_MODE_ALWAYS,
		"clip = %s" % anim.current_animation)

	await _seconds(0.5)
	var body_rest := player.global_position
	var enemies_rest: Array[Vector3] = []
	for enemy in _game.enemies():
		enemies_rest.append(enemy.global_position)
	var clip_time := anim.current_animation_position
	await _seconds(0.15)

	_check("le modele du chat tourne pendant la pause",
		anim.current_animation_position != clip_time,
		"%s %.3f -> %.3f" % [anim.current_animation, clip_time,
			anim.current_animation_position])
	_check("le corps du chat, lui, ne bouge pas",
		body_rest.is_equal_approx(player.global_position), "")
	var drifted := 0
	for i in mini(enemies_rest.size(), _game.enemies().size()):
		if not enemies_rest[i].is_equal_approx(_game.enemies()[i].global_position):
			drifted += 1
	_check("les ennemis restent figes", drifted == 0,
		"%d / %d bougent" % [drifted, enemies_rest.size()])

	await _seconds(1.0)
	_check("le carton de fin est ouvert, sur `repos`",
		_game.hud.is_game_over_card_open() and anim.current_animation == CelModel.ANIM_REPOS,
		"clip = %s" % anim.current_animation)
	_check("la camera est descendue sur le chat",
		is_equal_approx(_game.camera_rig.distance, CameraRig.REST_DISTANCE),
		"distance = %.2f" % _game.camera_rig.distance)

	# ── 7. La pause SURVIT au rechargement de scene ────────────────────
	# C'est ce qui oblige `_on_restart_button_pressed` a la lever : sinon la
	# run relancee depuis le carton de K.O. demarrerait figee.
	get_tree().paused = true
	_game.queue_free()
	await get_tree().process_frame
	var fresh := MAIN_SCENE.instantiate() as GameRoot
	add_child(fresh)
	await _wait(4)
	_check("une scene neuve herite de la pause de l'arbre", get_tree().paused,
		"elapsed = %.3f" % fresh.elapsed_time)
	_check("et elle est bien figee", is_equal_approx(fresh.elapsed_time, 0.0), "")
	get_tree().paused = false

	# ── 8. La fin de run se COUPE (§7bis.2) ───────────────────────────
	# Une touche a partir de 0,40 s saute a l'etat final : camera collee,
	# `repos` en cours, carton ouvert — sans attendre 1,25 s.
	await _wait(4)
	fresh._on_player_died()
	await _seconds(0.45)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("une touche saute a l'etat final",
		fresh.hud.is_game_over_card_open()
			and fresh.player.model.animation_player.current_animation == CelModel.ANIM_REPOS
			and is_equal_approx(fresh.camera_rig.distance, CameraRig.REST_DISTANCE),
		"t = %.2f, clip = %s" % [fresh._end_time,
			fresh.player.model.animation_player.current_animation])
	get_tree().paused = false

	var failed := _rows.filter(func(r: String) -> bool: return r.contains("FAIL"))
	var verdicts := _rows.filter(
		func(r: String) -> bool: return r.contains("OK ") or r.contains("FAIL"))
	_say("──────────────────────────────────────────────────────")
	_say("%d verdicts, %d FAIL" % [verdicts.size(), failed.size()])
