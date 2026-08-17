extends RefCounted

## Les preferences du joueur, sur disque.
##
## Un seul reglage aujourd'hui — la langue — mais le fichier existe des
## maintenant parce que le menu en aura d'autres, et parce qu'un reglage qui ne
## survit pas a la fermeture du jeu n'est pas un reglage : c'est une bascule.
##
## `user://` et non `res://` : le dossier du projet est en lecture seule dans un
## jeu exporte. Sous Windows le fichier atterrit dans
## `%APPDATA%\Godot\app_userdata\<nom du projet>\settings.cfg`.
##
## ⚠️ Rien ici ne leve ni ne bloque. Un fichier absent (premier lancement),
## illisible ou ecrit par une version anterieure doit donner un jeu qui demarre
## avec ses valeurs par defaut — pas un jeu qui refuse de s'ouvrir.

const Locale := preload("res://scripts/systems/locale.gd")

const PATH := "user://settings.cfg"
const SECTION := "jeu"


## Charge les preferences et les applique. A appeler AVANT que quoi que ce soit
## n'affiche du texte.
##
## Au tout premier lancement il n'y a pas de fichier : on prend alors la langue
## du systeme. Un joueur anglophone qui lance le jeu doit tomber sur l'anglais
## sans avoir a chercher le menu — c'est le seul moment ou le jeu peut deviner,
## et il ne devine qu'une fois. Dès qu'il a choisi, le fichier fait foi.
static func load_settings() -> void:
	var config := ConfigFile.new()

	if config.load(PATH) != OK:
		Locale.set_language(_system_language())
		return

	Locale.set_language(String(config.get_value(SECTION, "language", _system_language())))


static func save_settings() -> void:
	var config := ConfigFile.new()
	# On relit avant d'ecrire : sinon, le jour ou un reglage sera pose ailleurs
	# dans le code, sauvegarder la langue l'effacerait.
	config.load(PATH)
	config.set_value(SECTION, "language", Locale.language())
	config.save(PATH)


## La langue du systeme, ramenee a une de celles qu'on parle.
##
## `get_locale_language` rend le code court ("fr" pour "fr_CH"), donc il n'y a
## rien a decouper ici.
static func _system_language() -> String:
	var code := OS.get_locale_language()
	return code if code in Locale.LANGUAGES else "en"
