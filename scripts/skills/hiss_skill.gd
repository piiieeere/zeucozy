extends ActiveSkill

## Le feulement — le 2e ACTIF, et la premiere competence qui ne compte pas en
## degats.
##
## Une onde qui s'ouvre au sol et REPOUSSE tout ce qu'elle traverse. Elle blesse
## a peine ; ce qu'elle rend, c'est de la PLACE.
##
## ─── POURQUOI DU RECUL, ET PAS UN 3e GROS COUP ───
##
## Le chat avait deja de quoi tuer : la griffure nettoie, la morsure execute, la
## boule de poils harcele, l'haleine grignote. Ce qu'il n'avait pas, c'est un
## moyen de se sortir d'un encerclement — la seule reponse etait de courir, et
## courir ne repousse rien. Un survivor sans bouton de panique n'a qu'une seule
## fin possible.
##
## ⚠️ ELLE FAIT DONC UNE DECISION NOUVELLE, pas une decision de plus. La morsure
## demande "lequel je tue maintenant ?" ; le feulement demande "est-ce que je
## depense ma sortie tout de suite ou est-ce que je tiens encore une seconde ?".
## C'est exactement ce que "Gameplay et Progression" §2.4 attend d'un actif.
##
## ─── LE FRONT EST L'AGENT, ET C'EST LA MEME LEÇON QUE LA MORSURE ───
##
## L'onde pousse les ennemis A MESURE QU'ELLE LES ATTEINT, pose par pose. Une
## poussee instantanee sur tout le rayon aurait projete un ennemi du bord avant
## que le dessin ne soit arrive sur lui : c'est le defaut exact de la morsure qui
## cherchait sa cible au claquement, et §2.10 le tranche — un effet doit se
## dessiner LA OU il agit.
##
## D'ou le suivi des ennemis deja pousses : sans lui, chaque pose repousserait de
## nouveau tout le monde et l'onde ferait six poussees au lieu d'une.

const HISS_RING_SCENE := preload("res://scenes/fx/hiss_ring.tscn")

## Vitesse de la poussee, en m/s, et sa deceleration en m/s². Elles vivent ici et
## non dans les paliers : c'est la SENSATION du recul, elle doit etre la meme a
## tous les paliers. Ce qu'un palier fait grandir, c'est le rayon et les degats.
##
## A 15 m/s freines a 32 m/s², l'ennemi recule ~3,5 m en ~0,47 s. Il faut donc
## qu'il refasse la moitie du chemin du chat pour revenir au contact — assez pour
## respirer, pas assez pour annuler la vague.
const PUSH_SPEED := 15.0
const PUSH_DRAG := 32.0


## Le feulement part. Le cri est immediat, contrairement a la morsure : un
## feulement EST le bruit, il n'a pas de temps de frappe a attendre.
func _fire() -> void:
	if player == null:
		return

	var radius := float(values["radius"])
	var damage := int(values["damage"])

	var ring := HISS_RING_SCENE.instantiate() as HissRing
	# ⚠️ Enfant de la COMPETENCE, donc petite-fille du chat, et surtout pas
	# enfant du modele : le node `Player` ne tourne pas, seul `$Model` tourne. Un
	# anneau accroche au modele pivoterait des que le joueur vise ailleurs, et un
	# cercle qui tourne sur lui-meme n'est pas un cercle, c'est un defaut.
	add_child(ring)
	ring.setup(radius)
	# Sans ca, l'interpolation physique fait partir l'anneau de l'origine du monde
	# sur sa premiere frame — et sa premiere frame est le debut du geste.
	ring.reset_physics_interpolation()

	var pushed := {}
	ring.swept.connect(
		func(reach: float) -> void: _sweep(reach, radius, damage, pushed)
	)

	shout()


## L'horloge de l'onde vient d'ici, comme celle de l'aura de l'haleine : une
## competence n'a pas de `_process`, et ce qu'elle porte n'en a pas davantage.
## C'est ce qui garantit que rien ne pousse pendant un carton de niveau.
func tick(delta: float) -> void:
	super.tick(delta)

	for child in get_children():
		if child is DrivenFx:
			(child as DrivenFx).advance(delta)


## Le front vient d'atteindre `reach` : on pousse ce qu'il a rattrape.
##
## ⚠️ Pas d'Area3D, un test de distance — la meme raison que l'haleine puante et
## la morsure : une sphere de collision ajouterait le rayon de la hurtbox ennemie
## (0,75 m) a la portee reelle, et l'onde repousserait plus loin qu'elle ne se
## dessine.
func _sweep(reach: float, radius: float, damage: int, pushed: Dictionary) -> void:
	if player == null:
		return

	var here: Vector3 = player.global_position

	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy

		if not is_instance_valid(enemy):
			continue

		var id := enemy.get_instance_id()

		if pushed.has(id):
			continue

		var away := enemy.global_position - here
		# Tout le jeu vit dans le plan XZ : la hauteur ne doit pas rogner la
		# portee, et la poussee ne doit pas decoller l'ennemi du sol.
		away.y = 0.0
		var distance := away.length()

		# Au-dela du front, l'onde ne l'a pas encore atteint. Au-dela du rayon
		# elle ne l'atteindra jamais — mais on ne le marque pas pour autant,
		# puisqu'il peut entrer dans la zone entre deux poses.
		if distance > reach or distance < 0.001:
			continue

		pushed[id] = true
		enemy.push(away / distance, PUSH_SPEED, PUSH_DRAG)

		if damage > 0:
			enemy.take_damage(damage)
