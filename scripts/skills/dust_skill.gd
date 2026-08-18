extends Skill

## Les moutons de poussiere — l'arme AUTO qui recompense de BOUGER.
##
## Le chat seme une touffe derriere lui a intervalle regulier. Le premier ennemi
## qui la traverse la fait pouf et prend le coup ; au bout de CINQ SECONDES, elle
## disparait toute seule — meme duree a tous les paliers, voir la note de `life`
## dans `skill_definitions.gd`.
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
## l'equilibrage". Depuis que `life` vaut 5,0 partout, la duree de vie divisee par
## l'intervalle donne 9,1 / 10,9 / 11,9 : le plafond mord des le T2, et c'est LUI
## qui decide du nombre a l'ecran. Au-dela de dix le sol cesse d'etre lisible et
## le joueur ne sait plus ou il peut passer. La plus ancienne part la premiere —
## un semis, c'est une trainee, et une trainee s'efface par la queue. Corollaire :
## en course continue, une touffe peut partir AVANT ses cinq secondes.
const MAX_BUNNIES := 10

## `bunny` -> secondes de vie restantes. Un Dictionary et non un tableau parallele :
## une touffe consommee doit disparaitre des deux d'un seul geste.
var _bunnies: Dictionary[DustBunny, float] = {}
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


## ⛔ POURQUOI LES TOUFFES RESTAIENT AU SOL — deux defauts, une seule cause.
##
## `_bunnies` est LA SEULE CHOSE AU MONDE qui appelle `advance()` sur une touffe.
## Un `DustBunny` est un `DrivenFx` : il n'a pas de `_process`, c'est tout l'objet
## de ce type. Une touffe qui sort du dictionnaire cesse donc d'exister pour
## l'horloge — mais pas pour l'ecran. Elle reste plantee au sol, pour toujours,
## puisque le `queue_free()` est au bout d'`advance()`.
##
##   1. LA SORTIE AU MOMENT DU POUF. `consume()` puis `erase()` dans la meme
##      passe : la touffe se figeait sur sa PREMIERE POSE DE POUF. C'est le
##      defaut d'origine, et il etait silencieux — cette pose vaut `puff` 1,28
##      contre ~1,00 au repos, donc on lisait une touffe qui n'expire pas, pas
##      une animation coincee.
##   2. LA CLE LIBEREE. Un node libere en cle de Dictionary ne casse pas
##      seulement `erase()` : il INTERROMPT L'ITERATION. Mesure du 2026-08-18 —
##      une seule cle morte et la boucle rendait 1 entree sur 10, les neuf autres
##      sortaient du semis sans etre detruites. Le compte de nodes `DustBunny`
##      sous `$Fx` montait tout droit : 47 apres 23 s, aucun libere.
##
## D'ou les trois regles que cette fonction tient :
##
##   * une touffe consommee RESTE dans `_bunnies` jusqu'a sa liberation.
##     `is_spent()` est la ligne de partage : elle ne compte plus dans le jeu (ni
##     degats, ni decompte de vie, ni plafond), elle est encore dans l'image ;
##   * `is_queued_for_deletion()` la laisse partir a la bonne frame.
##     `queue_free()` ne libere qu'a la FIN de la frame : au retour d'`advance()`
##     la touffe est encore valide et se recopierait sans broncher, pour n'etre
##     plus qu'une cle morte a la frame suivante ;
##   * le semis se RECONSTRUIT au lieu de s'effacer. Un dictionnaire neuf ne
##     demande aucune cle valide, et il conserve l'ordre de ponte dont depend
##     "la plus ancienne part la premiere".
##
## ✅ Mesure apres correction : une touffe non touchee vit 5,10 s (5,00 de vie +
## 0,10 de pouf), et le compte se stabilise a 9 nodes au T1, 10 au T3.
func _age(delta: float) -> void:
	var kept: Dictionary[DustBunny, float] = {}

	for bunny in _bunnies:
		if not is_instance_valid(bunny) or bunny.is_queued_for_deletion():
			continue

		bunny.advance(delta)

		# Derniere pose du pouf : `advance()` vient de la liberer.
		if bunny.is_queued_for_deletion():
			continue

		if bunny.is_spent():
			kept[bunny] = 0.0
			continue

		var left: float = _bunnies[bunny] - delta

		if left <= 0.0:
			# Elle n'a rien touche : elle part par le pouf comme les autres. Une
			# touffe qui disparaitrait d'un coup se lirait comme un bug.
			bunny.consume()
			left = 0.0

		kept[bunny] = left

	_bunnies = kept


## Le semis. Rien ne tombe si le chat n'a pas assez avance : voir `MIN_SPACING`.
func _drop() -> void:
	if player == null:
		return

	var here: Vector3 = player.global_position

	if _last_drop.is_finite() and here.distance_to(_last_drop) < MIN_SPACING:
		return

	var root := game()

	if root == null:
		return

	# ⚠️ La touffe est plantee DANS LE MONDE, pas sous le chat. C'est toute la
	# difference avec l'aura de l'haleine : celle-ci est un souffle et suit son
	# porteur, celle-la est un objet tombe par terre et y reste.
	#
	# Elle passe par `add_fx()` et non par `game.fx_container` : le conteneur de
	# FX est une affaire interne de `main` (P3). Cette ligne atteignait un node
	# ENFANT d'un autre script en le nommant — renommer `$Fx` dans main.tscn
	# cassait cette arme, en silence.
	var bunny := DUST_BUNNY_SCENE.instantiate() as DustBunny
	root.add_fx(bunny, Vector3(here.x, 0.0, here.z))
	bunny.setup(float(values["radius"]))

	_bunnies[bunny] = float(values["life"])
	_last_drop = here

	# ⚠️ Le plafond ne compte que les touffes VIVANTES. Celles qui jouent leur
	# pouf ne piegent plus le sol et vont partir d'elles-memes ; les compter
	# ferait pouffer une touffe encore active a chaque semis.
	var live: Array[DustBunny] = []

	for other in _bunnies:
		if is_instance_valid(other) and not other.is_spent():
			live.append(other)

	# La plus ancienne part la premiere — un semis, c'est une trainee, et une
	# trainee s'efface par la queue. On la POUFFE sans la sortir du dictionnaire :
	# voir `_age`, c'est lui qui la fait disparaitre pour de bon.
	for i in maxi(0, live.size() - MAX_BUNNIES):
		live[i].consume()


## Le contact. Test de distance et non Area3D — meme raison que l'haleine puante
## et le feulement : une sphere de collision ajouterait le rayon de la hurtbox
## ennemie (0,75 m) au rayon reel, et la touffe mordrait bien au-dela de ce
## qu'elle montre.
##
## ─── UNE TOUFFE BLESSE TOUT CE QUI EST DESSUS (2026-08-18) ───
##
## Elle ne frappait qu'UN ennemi, le premier trouve, puis disparaissait. Dix
## ennemis sur la meme touffe, un seul prenait le coup — donc l'arme rendait le
## dixieme de ce qu'elle promet exactement quand le joueur regarde ses degats,
## c'est-a-dire en pack.
##
## ⚠️ "Une touffe = UN coup" (voir l'en-tete) n'a PAS change : la touffe meurt
## toujours d'un seul geste, elle ne grignote toujours pas. Ce qui change, c'est
## qui encaisse ce coup — une mine molle n'a aucune raison d'epargner neuf
## ennemis sur dix qui lui marchent dessus.
##
## Le releve qui l'a decide (110 s, `--walk`, paliers figes) : moutons 216 degats
## au T1 et 534 au T3, contre 144 et 360 a la boule de poils. L'arme sortait DEJA
## le plus gros total du jeu ; ce qui manquait, c'est qu'elle rende ce total la
## ou le joueur peut le voir.
##
## ⚠️ ET LE GAIN EST ENTIEREMENT ADOSSE A LA DENSITE — mesure, pas suppose. Sur
## une run T3 de 240 s : ZERO pouf multiple avant ~130 s (les ennemis chassent en
## file, pas en grappe), puis 13 a 160 s et 46 a 240 s, soit 11,6 % des poufs et
## 1,17 ennemi par pouf en moyenne. Ce changement ne rend donc rien en debut de
## run et ~+17 % quand ca se bouscule, ce qui est exactement le moment vise.
##
## 🅿️ Le plafond de ce levier est `radius` : a 0,95 m au T3, il faut deux ennemis
## dans un cercle de 1,9 m pour que la touffe en attrape deux, alors qu'une
## hurtbox en fait deja 0,75. C'est `radius` qu'il faudra ouvrir si le pouf
## multiple doit devenir la norme plutot que l'exception.
##
## ─── ELLE EST ARMEE DE SA NAISSANCE A SA MORT ───
##
## Aucune phase inerte : `consume()` ne regarde que `_spent`, jamais la pose. Une
## touffe mord donc pendant sa naissance (3 poses, ~0,10 s) comme pendant son
## repos. C'est la garantie que ce fichier doit tenir, et il n'y a qu'un seul
## endroit ou elle pourrait se perdre — une condition de phase ajoutee ici ou
## dans `dust_bunny.consume()`.
##
## ⚠️ Seul le POUF n'est plus armee, et c'est le contraire d'une fenetre morte :
## `is_spent()` marque une touffe deja consommee, qui n'est plus qu'un dessin en
## train de finir. La rearmer serait la faire compter deux fois.
func _bite() -> void:
	if player == null or _bunnies.is_empty():
		return

	var damage := int(values["damage"])
	var radius := float(values["radius"])
	# Un INSTANTANE : `take_damage` peut liberer un ennemi, et on reparcourt cette
	# liste pour chaque touffe. D'ou le `is_instance_valid` dans la boucle.
	var living := enemies()

	# ⚠️ UNE TOUFFE PAR ENNEMI ET PAR FRAME, la regle d'origine, qui survit telle
	# quelle : marcher sur un semis entier d'un coup transformerait l'arme en pic
	# de degats invisible. Elle se dit juste par ennemi au lieu de par boucle —
	# une 2e touffe pouffe quand meme, pour les ennemis qu'elle est seule a tenir.
	var struck := {}

	for bunny in _bunnies:
		# Une touffe deja consommee n'est plus qu'un pouf en cours : elle ne doit
		# ni blesser, ni arreter l'ennemi qui la traverse.
		if not is_instance_valid(bunny) or bunny.is_spent():
			continue

		var caught: Array[Enemy] = []

		for enemy in living:
			if not is_instance_valid(enemy) or struck.has(enemy.get_instance_id()):
				continue

			var gap: Vector3 = enemy.global_position - bunny.global_position
			# Tout le jeu vit dans le plan XZ.
			gap.y = 0.0

			if gap.length() <= radius:
				caught.append(enemy)

		if caught.is_empty():
			continue

		if not bunny.consume():
			continue

		for enemy in caught:
			struck[enemy.get_instance_id()] = true
			enemy.take_damage(damage)
