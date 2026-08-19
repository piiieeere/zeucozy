class_name Skill
extends Node3D

## ⭐ LE contrat commun a toutes les competences jouees — AUTO et ACTIF.
##
## Avant ce fichier, le jeu avait deux armes ecrites de deux facons differentes :
## la griffure etait un compteur en dur dans `player._process`, l'haleine puante
## un node avec son horloge a elle. Deux armes, deux mecaniques d'horloge, zero
## denominateur commun. A 6 AUTO + 2 ACTIFS (§2.3), `player.gd` aurait recu huit
## compteurs et huit cas particuliers.
##
## Une competence est donc un NODE, enfant du `SkillSet`, qui repond a trois
## questions et pas une de plus :
##
##   • `setup(player, id)`        qui je sers
##   • `set_tier(tier, values)`   a quel palier je suis, et avec quels chiffres
##   • `tick(delta)`              avance d'une frame
##   • `release()`                je quitte le build (voir tout en bas)
##
## ─── L'HORLOGE VIENT DE DEHORS, ET C'EST LE POINT ───
##
## Aucune competence n'a de `_process`. C'est le `SkillSet` qui les avance depuis
## `player._process` — et le chat etant en PROCESS_MODE_PAUSABLE, c'est le MOTEUR
## qui arrete les seize horloges d'un coup pendant un carton (voir main.tscn).
##
## Sans ce point unique, chaque competence reimplemente son propre test de pause
## — c'est ce que faisait `breath_aura.gd`, avec son `_get_game()` et son
## `_is_run_paused()` a lui. Multiplie par seize competences, c'est seize
## endroits ou oublier de s'arreter pendant un carton de niveau, et le defaut
## serait invisible : une aura qui continue de mordre derriere un panneau ne se
## voit pas, elle se constate a la barre de vie d'un ennemi.
##
## ─── Ce que le contrat NE DIT PAS, volontairement ───
##
## Ni la forme, ni la cadence, ni la portee. Une griffure est un geste billboard
## sur `FX_POSE` ; l'haleine est une zone posee au sol sur `AMBIENT_POSE`. La DA
## §7 le tranche : la cadence se choisit sur la DUREE DE VIE de l'element, pas
## sur sa categorie — donc elle appartient a chaque competence, jamais au socle.

const SkillDefinitions := preload("res://scripts/systems/skill_definitions.gd")

## Le chat. Type depuis le 2026-08-18 : `player.gd` porte `class_name Player`,
## donc `aim_direction`, `global_position` et `muzzle_height` — que toutes les
## competences lisent — sont verifies a la compilation au lieu de partir en
## appel dynamique.
var player: Player = null

var id := ""
## 1-base, comme dans "Gameplay et Progression" §2.2. Zero n'existe pas ici :
## une competence sans palier n'a pas de node du tout.
var tier := 0
## Les valeurs du palier courant — ABSOLUES (voir `skill_definitions.gd`).
var values := {}


func setup(new_player: Player, new_id: String) -> void:
	player = new_player
	id = new_id


## Appelee a CHAQUE prise, la premiere comme les suivantes. Les valeurs etant
## absolues, la reappliquer deux fois donne le meme resultat — c'est ce qui
## permettra a un T4 de transformer une competence au lieu de s'empiler dessus.
func set_tier(new_tier: int, new_values: Dictionary) -> void:
	tier = new_tier
	values = new_values
	_on_tier_changed()


## Une frame de jeu, run vivante. Jamais appelee en pause.
func tick(_delta: float) -> void:
	pass


## Le crochet des sous-classes : la competence vient de changer de palier.
func _on_tier_changed() -> void:
	pass


## La competence quitte le build — elle vient d'etre remplacee (§2.3). Son node
## va etre libere juste apres ; ce crochet n'existe que pour ce qu'elle a laisse
## AILLEURS.
##
## ⚠️ NE RIEN FAIRE EST LE BON DEFAUT, ET C'EST CE QUI REND L'OUBLI DANGEREUX.
## Un dessin enfant de la competence part avec elle sans une ligne de code —
## l'aura de l'haleine, l'onde du feulement, le halo du ronron. Une competence
## qui plante ses FX DANS LE MONDE (`GameRoot.add_fx`) est le cas contraire, et
## le defaut est muet : ces FX sont des `DrivenFx`, ils n'ont pas de `_process`,
## donc la competence liberee est la seule chose au monde qui les avancait. Ils
## resteraient au sol pour toujours, armes, sans que rien ne le signale.
##
## La question a se poser en ecrivant une competence est donc : "est-ce que j'ai
## mis quelque chose ailleurs que sous moi ?"
func release() -> void:
	pass


## Le directeur de jeu, vu depuis une competence. `null` tant que le chat n'est
## pas dans une run — c'est le cas dans les vignettes de carte, qui instancient
## un FX seul dans un SubViewport.
##
## ⚠️ IL SE LIT A TRAVERS LE CHAT, ET C'EST LE POINT — P3 de la revue de code.
## Quatre competences appelaient `get_first_node_in_group("game_root")` : une
## variable globale deguisee, que rien ne declare et que rien ne type. Le chat,
## lui, est la seule chose qu'une competence connaisse par construction
## (`setup`), et `main` lui a injecte le jeu. Un chemin, pas une recherche.
func game() -> GameRoot:
	if player == null:
		return null

	return player.game


## Les ennemis vivants. Vide s'il n'y a pas de run.
##
## Six competences repetaient la meme boucle — recherche de groupe, `as Enemy`,
## `is_instance_valid`. Le preambule vit desormais une seule fois, dans
## `GameRoot.enemies()`.
func enemies() -> Array[Enemy]:
	var root := game()

	if root == null:
		return []

	return root.enemies()
