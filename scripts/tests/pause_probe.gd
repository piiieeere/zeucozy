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

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy_positions.append((enemy as Enemy).global_position)

	await _wait(15)

	_check("le temps ne monte pas", is_equal_approx(t_paused, _game.elapsed_time),
		"%.3f -> %.3f" % [t_paused, _game.elapsed_time])
	_check("le chat ne bouge pas", pos_paused.is_equal_approx(player.global_position),
		"%s" % player.global_position)

	var moved := 0
	var index := 0

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if index < enemy_positions.size() \
				and not enemy_positions[index].is_equal_approx((enemy as Enemy).global_position):
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

	var failed := _rows.filter(func(r: String) -> bool: return r.contains("FAIL"))
	var verdicts := _rows.filter(
		func(r: String) -> bool: return r.contains("OK ") or r.contains("FAIL"))
	_say("──────────────────────────────────────────────────────")
	_say("%d verdicts, %d FAIL" % [verdicts.size(), failed.size()])
