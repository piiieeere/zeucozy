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
## | Portee | 5,2 m | **2,6 m** — au contact |
## | Degats | 3 | **7** — une brute de depart d'un coup |
##
## La griffure est un metronome qu'on oriente ; la morsure est une carte qu'on
## garde en main. Elles ne se remplacent pas : l'une nettoie, l'autre execute.
##
## ⚠️ ELLE PORTE MOINS LOIN QUE LA GRIFFURE, et c'est le prix de ses degats. Mordre
## demande d'entrer dans la bande ou l'ennemi mord aussi (contact a ~1,55 m) :
## 1 m de marge. C'est la meme logique que l'haleine puante — ce qui frappe fort
## se paye en distance, jamais en cooldown seul.
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
## ⚠️ OUVERT de 70° a 90° le 2026-08-17, et c'est le DESSIN qui l'a impose. La
## gueule etait trop petite a taille de jeu ; vers l'avant elle ne peut pas
## grandir (le quad d'un cote, le chat de l'autre), donc elle a grandi en
## largeur — et une gueule plus large que son arc de degats montrerait une portee
## qu'elle n'a pas. Les deux se suivent : 2 × 2,6 × sin 45° = 3,74 m, la corde
## exacte du dessin.
const ARC_DEGREES := 90.0


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
