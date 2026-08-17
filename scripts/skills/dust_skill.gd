extends "res://scripts/skills/skill.gd"

## Les moutons de poussiere — l'arme AUTO qui recompense de BOUGER.
##
## Le chat seme une touffe derriere lui a intervalle regulier. Le premier ennemi
## qui la traverse la fait pouf et prend le coup ; passe quelques secondes, elle
## disparait toute seule.
##
## ─── LE 4e REGISTRE, ET IL EST L'INVERSE DE L'HALEINE ───
##
## | | Griffure | Boule de poils | Haleine | Moutons |
## |---|---|---|---|---|
## | Visee | le joueur | auto | aucune | **aucune** |
## | Ou ca frappe | devant | au loin | autour | **derriere** |
## | Ce que ca recompense | viser | rien | **rester** | **bouger** |
##
## ⚠️ C'est ce dernier point qui justifie la competence. L'haleine puante a ete
## la premiere mecanique qui recompensait de rester au contact ; tant qu'elle
## etait seule de son espece, "bien jouer" restait un seul comportement. Deux
## armes qui demandent l'inverse l'une de l'autre, c'est le debut d'un BUILD —
## et §2.9 dit que remplacer ne devient un choix qu'a partir de la.
##
## Et c'est un objet d'appartement que tout proprietaire de chat reconnait
## (§5.5), pas une rune de jeu vidéo posee au sol.
##
## ─── UNE TOUFFE = UN COUP, PUIS ELLE N'EST PLUS LA ───
##
## Pas de degats periodiques, pas de zone qui grignote : le mouton est une MINE
## MOLLE. Deux raisons, et la seconde est la vraie :
##
##   * §2.10 veut qu'un effet continu BATTE, sinon le joueur ne sait jamais quand
##     il gagne du terrain. Une touffe consommee d'un coup est le battement le
##     plus lisible qui soit — elle disparait ;
##   * dix zones qui grignotent en meme temps, c'est dix decomptes a suivre a
##     l'ecran. Le pitch dit "chaos felin MAITRISE" (§2.3) et la lisibilite est
##     le premier mur, avant l'equilibrage.

const DUST_BUNNY_SCENE := preload("res://scenes/fx/dust_bunny.tscn")

## Distance minimale entre deux touffes, en metres. Sans elle, un chat immobile
## empilerait tout son semis sur un seul point : le joueur verrait UNE touffe et
## en aurait pose dix, ce qui est le contraire de "l'effet se dessine la ou il
## agit" (§2.10). C'est aussi ce qui fait que l'arme ne rend rien a l'arret.
const MIN_SPACING := 1.1

## Plafond de touffes simultanees.
##
## ⚠️ Ce n'est pas une optimisation, c'est la contrainte de §2.3 : jusqu'a huit
## sources de degats a l'ecran, "la lisibilite sera le premier mur, avant
## l'equilibrage". Au T3 la duree de vie divisee par l'intervalle donnerait douze
## touffes ; au-dela de dix le sol cesse d'etre lisible et le joueur ne sait plus
## ou il peut passer. La plus ancienne part la premiere — un semis, c'est une
## trainee, et une trainee s'efface par la queue.
const MAX_BUNNIES := 10

## `bunny` -> secondes de vie restantes. Un Dictionary et non un tableau parallele :
## une touffe consommee doit disparaitre des deux d'un seul geste.
var _bunnies := {}
var _cooldown := 0.0
var _last_drop := Vector3.INF


## L'horloge de toutes les touffes vient d'ici — elles n'ont pas de `_process`,
## comme rien dans ce dossier. C'est ce qui garantit que le semis s'arrete
## derriere un carton de niveau, degats compris.
func tick(delta: float) -> void:
	_age(delta)
	_bite()

	_cooldown -= delta

	if _cooldown > 0.0:
		return

	_cooldown = float(values["interval"])
	_drop()


func _age(delta: float) -> void:
	for bunny in _bunnies.keys():
		if not is_instance_valid(bunny):
			_bunnies.erase(bunny)
			continue

		bunny.advance(delta)

		# Une touffe consommee joue encore son pouf : elle n'est plus dans le jeu,
		# elle est encore dans l'image. On la sort du semis sans la detruire.
		if bunny.is_spent():
			_bunnies.erase(bunny)
			continue

		_bunnies[bunny] -= delta

		if _bunnies[bunny] <= 0.0:
			# Elle n'a rien touche : elle part par le pouf comme les autres. Une
			# touffe qui disparaitrait d'un coup se lirait comme un bug.
			bunny.consume()
			_bunnies.erase(bunny)


## Le semis. Rien ne tombe si le chat n'a pas assez avance : voir `MIN_SPACING`.
func _drop() -> void:
	if player == null:
		return

	var here: Vector3 = player.global_position

	if _last_drop.is_finite() and here.distance_to(_last_drop) < MIN_SPACING:
		return

	var game = player.get_tree().get_first_node_in_group("game_root")

	if game == null:
		return

	# ⚠️ La touffe est plantee DANS LE MONDE, pas sous le chat. C'est toute la
	# difference avec l'aura de l'haleine : celle-ci est un souffle et suit son
	# porteur, celle-la est un objet tombe par terre et y reste.
	var bunny = DUST_BUNNY_SCENE.instantiate()
	game.fx_container.add_child(bunny)
	bunny.global_position = Vector3(here.x, 0.0, here.z)
	# Sans ca, l'interpolation physique fait partir la touffe de l'origine du
	# monde sur sa premiere frame.
	bunny.reset_physics_interpolation()
	bunny.setup(float(values["radius"]))

	_bunnies[bunny] = float(values["life"])
	_last_drop = here

	while _bunnies.size() > MAX_BUNNIES:
		var oldest = _bunnies.keys()[0]
		_bunnies.erase(oldest)

		if is_instance_valid(oldest):
			oldest.consume()


## Le contact. Test de distance et non Area3D — meme raison que l'haleine puante
## et le feulement : une sphere de collision ajouterait le rayon de la hurtbox
## ennemie (0,75 m) au rayon reel, et la touffe mordrait bien au-dela de ce
## qu'elle montre.
func _bite() -> void:
	if player == null or _bunnies.is_empty():
		return

	var damage := int(values["damage"])
	var radius := float(values["radius"])

	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D

		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue

		for bunny in _bunnies.keys():
			if not is_instance_valid(bunny):
				continue

			var gap: Vector3 = enemy.global_position - bunny.global_position
			# Tout le jeu vit dans le plan XZ.
			gap.y = 0.0

			if gap.length() > radius:
				continue

			if bunny.consume():
				enemy.take_damage(damage)
				_bunnies.erase(bunny)

			# Une touffe par ennemi et par frame : marcher sur un semis entier
			# d'un coup transformerait l'arme en pic de degats invisible.
			break
