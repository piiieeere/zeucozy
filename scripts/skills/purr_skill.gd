extends ActiveSkill

## Le ronron — le 3e ACTIF, et le premier SOIN du jeu (2026-08-19).
##
## Le chat se met a ronronner : quatre bouffees sur deux secondes, chacune lui
## rend une poignee de points de vie. Il ne s'arrete pas de courir, il ne frappe
## pas, il ne repousse rien.
##
## ─── IL SOIGNE LENTEMENT, ET C'EST TOUTE LA COMPETENCE ───
##
## Un soin instantane n'aurait pose aucune decision : on le presse quand la barre
## est basse, et il n'y a rien a choisir. Etale sur quatre bouffees, il cesse
## d'etre une reponse a une urgence et devient une ANTICIPATION — un ronron lance
## a 15 points de vie avec une souris sur le dos ne sauve personne, parce que la
## quatrieme bouffee arrive deux secondes trop tard.
##
## C'est ce qui le range bien dans le type ACTIF au sens de §2.4 : la question
## qu'il pose est *quand*, et elle a une vraie mauvaise reponse. La morsure
## demande "lequel je tue maintenant ?", le feulement "est-ce que je depense ma
## sortie ?", le ronron "est-ce que je peux me permettre les deux prochaines
## secondes ?".
##
## ⚠️ IL NE ROOTE PAS LE CHAT, et ce n'est pas un oubli. Un canal qui cloue sur
## place serait une mecanique neuve — et dans un survivor ou tout le jeu consiste
## a ne pas se laisser enfermer, elle transformerait un soin en suicide. Le
## ronron est un ETAT, pas une posture. Ce qu'il coute est sa recharge et le
## temps qu'il met a rendre, rien d'autre.
##
## ─── LES TROIS AUTRES CHOSES QU'IL FAIT EXISTER ───
##
##   * la premiere valeur de build qui ne soit ni des degats ni du placement.
##     `toughness` ralentit la descente de la barre, `max_health` l'allonge ; le
##     ronron est le seul a la faire REMONTER. C'est la fantasy "chat tank" de
##     [[Game Manifest]] §11, qui n'avait jusqu'ici aucune piece active ;
##   * la raison d'etre du passage de la vie a 100 points (2026-08-16). Sur six
##     points, un soin ne pouvait rendre que 1 — soit 17 % de la barre — ou rien.
##     Cette competence est exactement ce que ce changement rendait possible ;
##   * la troisieme compétence active, donc la premiere fois que `roll` a de quoi
##     PROPOSER un remplacement (§2.3) : a deux, la famille etait saturee sans
##     que le carton de remplacement puisse jamais s'ouvrir, faute de candidat.
##
## ⚠️ IL EST INVISIBLE TANT QUE `player.IMMORTAL` VAUT `true`. La barre reste
## clouee a 100/100, donc les quatre bouffees ne rendent rien et le halo ment.
## C'est le seul FX du jeu que le mode de test rend intestable.

const PURR_HALO_SCENE := preload("res://scenes/fx/purr_halo.tscn")


## Le ronron part. Le cri est immediat, comme celui du feulement et contrairement
## a celui de la morsure : un ronron EST le bruit, il n'a pas de temps de frappe
## a attendre.
func _fire() -> void:
	if player == null:
		return

	var pulses := _split(int(values["heal"]))

	var halo := PURR_HALO_SCENE.instantiate() as PurrHalo
	# ⚠️ Enfant de la COMPETENCE, donc petite-fille du chat, et surtout pas enfant
	# du modele : le node `Player` ne tourne pas, seul `$Model` tourne. Un halo
	# accroche au modele pivoterait des que le joueur vise ailleurs — sans
	# consequence sur un billboard, mais le jour ou il cesserait de l'etre le
	# defaut serait a chercher tres loin d'ici. Meme ancrage que l'aura de
	# l'haleine et l'onde du feulement.
	add_child(halo)
	# Sans ca, l'interpolation physique fait partir le halo de l'origine du monde
	# sur sa premiere frame — et sa premiere frame est celle ou il soigne.
	halo.reset_physics_interpolation()

	# ⚠️ CONNECTER AVANT `start()`, jamais apres : c'est `start()` qui emet la
	# premiere bouffee, et c'est la plus importante des quatre. Voir le
	# commentaire de `PurrHalo.start`, ou le voisin `hiss_ring` montre ce que
	# l'ordre inverse coute.
	halo.pulsed.connect(func(index: int) -> void: _heal(pulses, index))
	halo.start()

	shout()


## L'horloge du halo vient d'ici, comme celle de l'aura de l'haleine et celle de
## l'onde du feulement : une competence n'a pas de `_process`, et ce qu'elle
## porte n'en a pas davantage. C'est ce qui garantit qu'aucune bouffee ne tombe
## pendant un carton de niveau.
func tick(delta: float) -> void:
	super.tick(delta)

	for child in get_children():
		if child is DrivenFx:
			(child as DrivenFx).advance(delta)


func _heal(pulses: Array[int], index: int) -> void:
	if player == null or index >= pulses.size():
		return

	player.heal(pulses[index])


## Le total du palier, reparti sur les bouffees. Le reste est mis DEVANT : la
## premiere bouffee est celle qui compte, c'est la seule dont le joueur est sur
## de profiter s'il doit repartir en courant.
##
## ⚠️ La repartition se calcule UNE FOIS, au declenchement, et pas a chaque
## bouffee. Un palier pris pendant que le ronron tourne — c'est possible, un
## carton de niveau peut s'ouvrir entre deux bouffees — ne doit pas changer le
## soin en cours de route : la competence rend ce qu'elle a promis en partant.
func _split(total: int) -> Array[int]:
	var count := PurrHalo.PULSES
	var base := total / count
	var rest := total % count
	var pulses: Array[int] = []

	for index in range(count):
		pulses.append(base + (1 if index < rest else 0))

	return pulses
