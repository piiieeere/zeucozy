extends "res://scripts/skills/active_skill.gd"

## La morsure — la PREMIERE competence active du jeu (2026-08-17).
##
## Clic gauche par defaut (slot 1). C'est le premier moment ou Zeucozy demande au
## joueur de choisir un INSTANT : jusqu'ici il choisissait ou se placer et ou
## viser, deux decisions continues. Mordre au bon moment en est une troisieme,
## ponctuelle — c'est exactement ce que "Gameplay et Progression" §2.4 attend des
## actifs.
##
## ─── CE QUI LA DISTINGUE DE LA GRIFFURE, ET POURQUOI ELLES COHABITENT ───
##
## | | Griffure | Morsure |
## |---|---|---|
## | Declenchement | cadence automatique | **le joueur, sur une touche** |
## | Cibles | tout l'arc | **UNE seule, la plus proche** |
## | Portee | 5,2 m | **3,6 m** — de pres |
## | Degats | 3 | **7** — une brute de depart d'un coup |
##
## La griffure est un metronome qu'on oriente ; la morsure est une carte qu'on
## garde en main. Elles ne se remplacent pas : l'une nettoie, l'autre execute.
##
## ⚠️ ELLE PORTE MOINS LOIN QUE LA GRIFFURE, et c'est le prix de ses degats. C'est
## la meme logique que l'haleine puante — ce qui frappe fort se paye en distance,
## jamais en cooldown seul. La portee a ete allongee le 2026-08-17 pour que le
## dessin puisse porter une denture lisible ; le rapport de rang est intact, la
## marge de risque a fondu. Voir `skill_definitions.gd`.
##
## ─── UNE SEULE CIBLE, CHOISIE A L'INSTANT DU CLIC ───
##
## Pas d'Area3D, pas de recouvrement : un balayage sur les ennemis, et on garde le
## plus proche DANS L'ARC. Meme raison que l'haleine puante — une sphere de
## collision ajouterait le rayon de la hurtbox (0,75 m) a la portee reelle, et la
## morsure mordrait plus loin qu'elle ne se dessine.

const BITE_SCENE := preload("res://scenes/fx/bite.tscn")

## Ouverture de l'arc de morsure, en degres. Plus SERRE que la griffure (120°) :
## un croc pique, il ne balaie pas. C'est ce qui empeche la morsure d'attraper un
## ennemi qu'on n'avait pas l'intention de viser.
##
## ⚠️ IL A FAIT L'ALLER-RETOUR 70° → 90° → 70° DANS LA MEME JOURNEE, et les deux
## fois c'est le DESSIN qui a decide — jamais l'equilibrage. Ca vaut d'etre garde,
## parce que le premier mouvement s'etait trompe de dimension :
##
##   • 70° → 90° : la gueule etait trop petite a taille de jeu. Vers l'avant elle
##     ne peut pas grandir (le bord du quad d'un cote, le chat de l'autre), donc
##     on l'a fait grandir en LARGEUR — et l'arc a du suivre, une gueule plus
##     large que son arc de degats montrant une portee qu'elle n'a pas.
##   • 90° → 70° : la vraie dimension libre etait l'INTERIEUR de la gueule. Des
##     dents qui poussent vers le centre n'ont aucune borne, et elles ont rendu au
##     dessin toute la lisibilite qu'on etait alle chercher en largeur. A 90° la
##     gueule faisait cinq fois la hauteur du chat et se lisait comme une bouche
##     autonome ; l'arc peut donc revenir a ce que la competence voulait dire.
##
## Les deux restent lies par une seule egalite, a verifier si l'un des deux bouge :
##   corde de l'arc    = 2 × portee × sin(ARC/2)
##   corde du dessin   = 2 × `bite.jaw_half_width` × portee
## soit `jaw_half_width` = sin(ARC/2) = 0,574 pour 70°.
##
## ⚠️ La PORTEE n'entre pas dans cette egalite — elle se simplifie des deux cotes.
## C'est ce qui lui a permis de passer de 2,6 a 3,6 m sans qu'aucun des deux
## chiffres bouge.
const ARC_DEGREES := 70.0


## Le coup part : on choisit la cible MAINTENANT, et le dessin la garde.
##
## ⚠️ La cible est fixee au declenchement, pas au claquement. Deux poses passent
## entre les deux (~67 ms) et un chaser court a 3,7 m/s : il parcourt 25 cm. La
## rechercher au claquement ferait mordre un ennemi qui n'etait pas celui que le
## joueur visait — la morsure doit toucher ce qu'elle MONTRE.
func _fire() -> void:
	if player == null:
		return

	var reach := float(values["range"])
	var aim: Vector3 = player.aim_direction

	var fx = BITE_SCENE.instantiate()
	player.add_child(fx)
	fx.setup(aim, reach)
	# Sans ca, l'interpolation physique fait partir le decalque de l'origine du
	# monde sur sa premiere frame — et sa premiere frame est un cinquieme de sa vie.
	fx.reset_physics_interpolation()

	# CHOMP — au claquement, jamais au clic. Voir `active_skill.shout()`.
	#
	# ⚠️ Il part meme quand la morsure mord dans le vide, et c'est volontaire :
	# le bruit dit que la competence est PARTIE, pas qu'elle a touche. Le joueur
	# qui vient de gaspiller six secondes de recharge doit le voir aussi
	# clairement que celui qui a croque une brute.
	fx.snapped.connect(shout)

	var target := _pick_target(aim, reach)

	if target == null:
		# La morsure part dans le vide, et elle se VOIT quand meme : le cooldown
		# est deja parti, le joueur doit comprendre qu'il l'a depensee pour rien.
		return

	# Le degat tombe sur la pose ou les machoires claquent, pas au clic — le
	# dessin et le degat sur la meme frame, comme la morsure de l'haleine puante.
	var id := target.get_instance_id()
	var damage := int(values["damage"])
	fx.snapped.connect(func() -> void: _apply_damage(id, damage))


func _apply_damage(target_id: int, damage: int) -> void:
	var target := instance_from_id(target_id)

	# L'ennemi a pu mourir sous une griffure ou un souffle pendant les deux poses.
	if target == null or not is_instance_valid(target) or not target.has_method("take_damage"):
		return

	target.take_damage(damage)


## L'ennemi le plus proche DANS l'arc de visee. `null` si la morsure part a vide.
func _pick_target(aim: Vector3, reach: float) -> Node3D:
	var cos_half := cos(deg_to_rad(ARC_DEGREES * 0.5))
	var here: Vector3 = player.global_position
	var best: Node3D = null
	var best_distance := INF

	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D

		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue

		var to_enemy := enemy.global_position - here
		# Tout le jeu vit dans le plan XZ : la hauteur ne doit pas rogner la portee.
		to_enemy.y = 0.0
		var distance := to_enemy.length()

		if distance > reach or distance < 0.001:
			continue

		# La portee donne les candidats, l'angle donne le camp — sans lui, la
		# morsure attraperait aussi dans le dos et la visee ne servirait a rien.
		if to_enemy.normalized().dot(aim) < cos_half:
			continue

		if distance < best_distance:
			best_distance = distance
			best = enemy

	return best
