extends SceneTree

## Pose la carte d'entrees du jeu dans project.godot — REJOUABLE.
##
## Ecrit en script plutot qu'a la main dans le .godot pour la meme raison que
## `fetch_fonts.ps1` : la serialisation d'un InputEvent par Godot est verbeuse et
## fragile, et une carte d'entrees est un geste de conception, pas un binaire
## tombe du ciel. Relancer ce fichier remet la carte exactement en etat.
##
## ─── WASD, et POURQUOI EN CODE PHYSIQUE ───
##
## Les touches sont posees en `physical_keycode` : Godot les resout par leur
## POSITION sur le clavier, pas par leur etiquette. Sur un AZERTY — le clavier de
## ce projet — les memes trois touches sous les doigts s'appellent Z, Q, S, D et
## fonctionnent sans qu'on ait rien a declarer. Un `keycode` logique aurait
## demande deux cartes, ou aurait envoye le joueur francais chercher un W qui
## n'est pas la ou il croit.
##
## Les fleches restent branchees en second : elles ne genent personne, et les
## retirer serait une regression pour zero benefice.
##
## ─── LES DEUX ACTIFS SONT SUR LES CLICS ───
##
## Clic gauche = slot 1, clic droit = slot 2. La main droite tient deja la visee
## (§9 du manifeste) : un actif se declenche donc sans quitter le curseur des
## yeux ni lacher une direction.
##
## ⚠️ Le clic gauche sert AUSSI aux boutons d'UI. Ce n'est pas un conflit : les
## cartons mettent la run en pause, et `player._process` rend la main avant de
## lire la moindre touche. Un clic sur une carte d'upgrade ne peut donc pas
## declencher une competence en meme temps.
##
## Usage :
##   Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tools/setup_input_map.gd

const KEY_W := 87
const KEY_A := 65
const KEY_S := 83
const KEY_D := 68

const KEY_UP := 4194320
const KEY_DOWN := 4194322
const KEY_LEFT := 4194319
const KEY_RIGHT := 4194321

const MOUSE_LEFT := 1
const MOUSE_RIGHT := 2

const ACTIONS := {
	"move_up": {"keys": [KEY_W, KEY_UP], "buttons": []},
	"move_down": {"keys": [KEY_S, KEY_DOWN], "buttons": []},
	"move_left": {"keys": [KEY_A, KEY_LEFT], "buttons": []},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": []},
	# Les deux slots d'ACTIF de "Gameplay et Progression" §2.4.
	"skill_slot_1": {"keys": [], "buttons": [MOUSE_LEFT]},
	"skill_slot_2": {"keys": [], "buttons": [MOUSE_RIGHT]},
}


func _init() -> void:
	for name in ACTIONS:
		var events: Array[InputEvent] = []

		for physical in ACTIONS[name]["keys"]:
			var key := InputEventKey.new()
			key.physical_keycode = physical
			events.append(key)

		for button in ACTIONS[name]["buttons"]:
			var click := InputEventMouseButton.new()
			click.button_index = button
			events.append(click)

		ProjectSettings.set_setting("input/" + name, {
			"deadzone": 0.2,
			"events": events,
		})
		print("  %-14s %d evenement(s)" % [name, events.size()])

	var status := ProjectSettings.save()
	print("project.godot : %s" % ("ecrit" if status == OK else "ECHEC %d" % status))
	quit(0 if status == OK else 1)
