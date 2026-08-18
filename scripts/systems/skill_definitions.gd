extends RefCounted

## ⭐ LE catalogue des competences — types, paliers, poids de tirage.
##
## Remplace `upgrade_definitions.gd`, qui ne portait qu'une liste d'`id`. Le
## systeme vient de "Gameplay et Progression" §2 ; ce fichier en est la donnee,
## et rien d'autre : il ne sait ni jouer une competence, ni la dessiner.
##
## ─── Les trois types (§2.1) ───
##
##   AUTO    une ARME qui agit seule. Occupe une slot ET se dessine a l'ecran.
##   ACTIF   se declenche sur une touche, a un cooldown. Aucun n'existe encore.
##   PASSIF  un modificateur de chiffre, jamais dessine. Ne coute ni slot ni
##           pixel — c'est ce qui justifie qu'il soit illimite en nombre.
##
## ⚠️ La difference AUTO / PASSIF n'est pas du vocabulaire : elle decide de
## `MAX_AUTO_SLOTS` d'un cote et de l'absence de plafond de l'autre.
##
## ─── Les paliers (§2.2) ───
##
## Un palier est une PROFONDEUR, pas une rarete : toutes les competences sont
## tirables des le premier niveau, c'est leur T2 et leur T3 qui se gagnent.
## T1 debloque, T2 et T3 renforcent, T4 TRANSFORME et se choisit entre deux
## ultimes exclusifs.
##
## 🅿️ `ultimates` est vide partout aujourd'hui, et c'est VOULU : le T4 est du
## contenu de jeu, il n'est ecrit nulle part. La structure le porte, le tirage le
## sait (voir `max_tier`), et une competence sans ultime plafonne proprement a
## T3. Le jour ou deux ultimes sont ecrits, ils se posent ici sans toucher au
## code.
##
## ─── LES VALEURS DE PALIER SONT ABSOLUES, JAMAIS DES INCREMENTS ───
##
## C'est le point qui a decide de toute la forme du fichier. L'ancien
## `apply_upgrade` faisait `claw_damage += 1` : une mutation EN PLACE, donc
## irreversible. Trois choses de §2 y devenaient impossibles — remplacer une
## arme (il faudrait defaire ses paliers), un T4 qui transforme (il faudrait
## recalculer, pas empiler), et relire un etat de build sans rejouer son
## historique.
##
## Ici, appliquer un palier c'est ECRIRE des valeurs. Le reappliquer deux fois
## donne le meme resultat, et une competence retiree ne laisse rien derriere.
##
## ─── Ce que ce fichier a REMPLACE (decision du 2026-08-17) ───
##
## `damage`, `attack_speed` et `claw_range` etaient des passifs qui reglaient la
## griffure. La griffure ayant desormais ses propres paliers, les laisser
## coexister ferait COMPTER DEUX FOIS la meme montee (§2.9). Ils sont donc
## supprimes et leur effet est replie dans les paliers T2 et T3 de `claw`.
##
## ⚠️ Consequence a connaitre : il ne reste que TROIS passifs. Le poids ×1 de
## §2.6 n'a pas grand-chose a peser tant que d'autres ne sont pas ecrits.

enum Kind { AUTO, ACTIVE, PASSIVE }

## Les slots du chat — §2.3. Le remplacement quand c'est plein n'existe pas
## encore (c'est le chantier 2) : en attendant, `roll` cesse simplement de
## proposer des competences NEUVES du type sature, et continue d'en proposer les
## paliers. Sans ce garde-fou, le jeu offrirait une 7e arme qu'il ne saurait pas
## faire porter.
const MAX_AUTO_SLOTS := 6
const MAX_ACTIVE_SLOTS := 2

## Un PASSIF plafonne a T3 et n'a pas d'ultime — §2.5. Ce n'est pas une economie
## d'ecriture : le T4 est le moment fort de la run, le donner aussi aux
## modificateurs de chiffres le banaliserait. Et un passif epuise SORT du pool,
## ce qui libere la place — c'est le defaut exact des 7 upgrades d'avant, dont le
## cumul infini finissait par ne plus proposer que du deja-vu.
const PASSIVE_MAX_TIER := 3

## Le tirage penche du cote des armes — §2.6. Un poids et non une garantie : une
## garantie ("au moins 1 auto par tirage") est une regle que le joueur finit par
## sentir comme mecanique, et elle interdit les tirages de trois passifs qui, de
## temps en temps, font une vraie decision. Un poids se regle en continu.
##
## 🚧 Le poids d'un PALIER contre celui d'une competence NEUVE reste a trancher
## (§2.6). Aujourd'hui les deux pesent pareil.
const WEIGHTS := {
	Kind.AUTO: 3,
	Kind.ACTIVE: 2,
	Kind.PASSIVE: 1,
}

const DEFINITIONS: Array[Dictionary] = [
	# ── AUTO ──────────────────────────────────────────────────────────────────
	{
		"id": "claw",
		"kind": Kind.AUTO,
		# La slot AUTO n°1 est la slot "arme DIRIGEE" (§2.3) : le chat garde
		# toujours une arme sous le curseur, il peut seulement en changer. La
		# visee souris est ce que le jeu a de plus singulier — un build qui
		# abandonnerait toute arme dirigee ferait retomber Zeucozy dans le
		# survivor pur, ou le joueur ne decide que de sa position.
		"directed": true,
		# La seule competence que le chat porte DES LE DEPART, a T1.
		"starting": true,
		"script": "res://scripts/skills/claw_skill.gd",
		# ⚠️ T2 et T3 replient les trois passifs supprimes (+1 degat, cadence
		# ×0,85, portee +0,45), pris une fois chacun et etales sur deux paliers.
		# C'est une TRANSCRIPTION de l'equilibrage d'avant, pas un reequilibrage :
		# la montee de la griffure sur une run est la meme, elle passe simplement
		# par elle-meme au lieu de passer par trois cartes separees.
		#
		# L'arc ne bouge PAS. L'ancienne description promettait un balayage "plus
		# large", le code ne l'a jamais fait — §2.10 : une competence qui
		# n'ameliore rien de visible est un mensonge a l'ecran, et une qui annonce
		# ce qu'elle ne fait pas en est un aussi.
		"tiers": [
			{"damage": 3, "interval": 1.10, "range": 5.20, "arc": 120.0},
			{"damage": 4, "interval": 0.94, "range": 5.65, "arc": 120.0},
			{"damage": 5, "interval": 0.80, "range": 6.10, "arc": 120.0},
		],
		"ultimates": [],
	},
	{
		# La boule de poils REVEILLE le projectile, en sommeil depuis le passage a
		# la griffure. Elle rouvre la fantasy "chat sniper" que le manifeste §11
		# notait sans support, et pour un cout proche de zero : scene, script et
		# `spawn_projectile` etaient restes entiers.
		#
		# Elle ne se vise PAS — la slot n°1 est reservee a l'arme dirigee (§2.3),
		# et deux armes qui obeissent au meme curseur ne feraient qu'une arme.
		"id": "hairball",
		"kind": Kind.AUTO,
		"script": "res://scripts/skills/hairball_skill.gd",
		# Peu de degats sur UNE cible, mais a 11 m — le double de la griffure.
		# Elle porte loin, elle ne nettoie pas.
		"tiers": [
			{"damage": 2, "interval": 1.60, "speed": 17.5, "range": 11.0},
			{"damage": 3, "interval": 1.35, "speed": 19.0, "range": 13.0},
			{"damage": 4, "interval": 1.10, "speed": 21.0, "range": 15.0},
		],
		"ultimates": [],
	},
	{
		"id": "breath",
		"kind": Kind.AUTO,
		"script": "res://scripts/skills/breath_skill.gd",
		# Transcription EXACTE des trois paliers deja en jeu — 2,8 / 3,35 / 3,9 m
		# et 1 / 2 / 3 degats par morsure. C'est la competence qui a valide
		# T1→T3 (§2.2), il n'y avait rien a redecider.
		"tiers": [
			{"radius": 2.80, "damage": 1},
			{"radius": 3.35, "damage": 2},
			{"radius": 3.90, "damage": 3},
		],
		"ultimates": [],
	},

	{
		"id": "dust",
		"kind": Kind.AUTO,
		"script": "res://scripts/skills/dust_skill.gd",
		# Les moutons de poussiere — l'arme qui recompense de BOUGER, l'exact
		# inverse de l'haleine puante. Voir `dust_skill.gd` : c'est ce contraste
		# qui la justifie, pas ses chiffres.
		#
		# ⚠️ `life / interval` DECIDE DU NOMBRE DE TOUFFES A L'ECRAN, et c'est la
		# vraie contrainte de ces chiffres. Au T3 le rapport donne douze, plafonne
		# a dix par `dust_skill.MAX_BUNNIES` — §2.3 previent que la lisibilite
		# sera le premier mur, avant l'equilibrage. Baisser `interval` sans
		# baisser `life` remplit le sol, pas la feuille de degats.
		#
		# ⚠️ `life` VAUT 5,0 A TOUS LES PALIERS (2026-08-18, demande directe) : une
		# touffe dure cinq secondes, un point c'est tout. C'est le seul chiffre du
		# semis que le joueur doit pouvoir tenir de tete — il seme derriere lui et
		# repasse dessus, donc il a besoin de savoir combien de temps le sol reste
		# piege, pas d'un nombre qui bouge a chaque reprise.
		#   * La montee de palier passe donc entierement par `damage`, `interval`
		#     et `radius` — elle n'a rien perdu, la duree n'etait que le 4e axe ;
		#   * consequence a connaitre : le rapport `life / interval` passe a 9,1 /
		#     10,9 / 11,9. Des le T2 le plafond de `MAX_BUNNIES` mord, et c'est
		#     LUI qui decide du nombre a l'ecran, plus la duree de vie. Le semis
		#     s'efface donc par la queue au lieu d'expirer — voulu, mais ca veut
		#     dire qu'une touffe peut partir AVANT ses cinq secondes si le chat
		#     court sans s'arreter.
		"tiers": [
			{"damage": 3, "interval": 0.55, "life": 5.0, "radius": 0.75},
			{"damage": 4, "interval": 0.46, "life": 5.0, "radius": 0.85},
			{"damage": 6, "interval": 0.42, "life": 5.0, "radius": 0.95},
		],
		"ultimates": [],
	},

	# ── ACTIF ─────────────────────────────────────────────────────────────────
	#
	# Le seul type qui ajoute une DECISION a la boucle moment-to-moment (§2.4) :
	# le placement et la visee sont continus, un actif est ponctuel. Le joueur
	# choisit un INSTANT.
	{
		"id": "bite",
		"kind": Kind.ACTIVE,
		"script": "res://scripts/skills/bite_skill.gd",
		# ⚠️ Elle porte MOINS LOIN que la griffure et frappe deux fois plus fort :
		# un croc se paye en distance, pas seulement en cooldown. L'ordre tient a
		# TOUS les paliers — la morsure T3 (4,4 m) reste sous la griffure T1
		# (5,2 m), ce qui est la seule facon de garantir que le rang ne s'inverse
		# jamais au fil d'une run.
		#
		# ⚠️ ALLONGEE le 2026-08-17 (2,6 / 2,9 / 3,2 → 3,6 / 4,0 / 4,4), et c'est
		# le DESSIN qui l'a demande, pas l'equilibrage. La gueule se dimensionne
		# sur la portee (`bite_fx.DRAW_SIZE`) : a 2,6 m elle etait trop petite
		# pour qu'on y lise des dents, et la portee et le dessin ne peuvent pas
		# diverger. Grandir le dessin seul aurait promis une portee inexistante.
		#
		# Ce que ca coute, et c'est assume : la marge au-dessus de la distance de
		# contact ennemi (~1,55 m) passe de 1,05 m a 2,05 m. Mordre reste plus
		# risque que griffer, mais nettement moins qu'avant.
		#
		# 7 degats au T1, soit exactement la vie d'une brute de depart : la
		# competence a un effet LISIBLE des sa premiere prise. Plus tard dans la
		# run les brutes montent a 21, et elle redevient un gros coup parmi
		# d'autres — c'est la courbe voulue pour un outil d'execution.
		"tiers": [
			{"damage": 7, "range": 3.60, "cooldown": 6.0},
			{"damage": 10, "range": 4.00, "cooldown": 5.0},
			{"damage": 14, "range": 4.40, "cooldown": 4.2},
		],
		"ultimates": [],
	},

	{
		"id": "hiss",
		"kind": Kind.ACTIVE,
		"script": "res://scripts/skills/hiss_skill.gd",
		# ⚠️ SES DEGATS SONT DERISOIRES, ET C'EST LE POINT. Elle ne rend pas de la
		# puissance, elle rend de la PLACE — c'est la premiere competence dont la
		# valeur ne se compte pas en points de vie enleves. Lui donner des degats
		# comparables a la morsure en aurait fait une morsure de zone, et le chat
		# aurait eu deux boutons pour le meme probleme.
		#
		# Le rayon PORTE PLUS LOIN que tout le reste (3,6 m contre 5,2 m de
		# griffure, mais sur 360°) : c'est ce qui la rend utile quand on est
		# encercle, cas ou toutes les autres armes ne repondent que d'un cote.
		#
		# La recharge est LA PLUS LONGUE du jeu. Une sortie de secours qui revient
		# vite n'est plus une decision, c'est une touche a marteler.
		"tiers": [
			{"radius": 3.60, "damage": 1, "cooldown": 11.0},
			{"radius": 4.30, "damage": 2, "cooldown": 9.5},
			{"radius": 5.00, "damage": 3, "cooldown": 8.0},
		],
		"ultimates": [],
	},

	# ── PASSIF ────────────────────────────────────────────────────────────────
	#
	# Ils ont tous un point commun : ils reglent le CORPS du chat, jamais une
	# arme. C'est ce qui les rend compatibles avec des armes qui portent
	# desormais leurs propres paliers — aucune montee n'est comptee deux fois.
	# La ligne de partage n'est pas negociable : un passif qui reglerait un degat
	# recreerait le double comptage que §2.9 a fait supprimer.
	{
		"id": "move_speed",
		"kind": Kind.PASSIVE,
		"tiers": [
			{"speed": 8.40},
			{"speed": 9.30},
			{"speed": 10.20},
		],
	},
	{
		"id": "max_health",
		"kind": Kind.PASSIVE,
		# `heal` est un EVENEMENT, pas un etat : il se joue a la prise du palier
		# et ne se rejoue pas. D'ou une cle a part, que `skill_set` ne fusionne
		# pas avec les valeurs permanentes.
		#
		# +30 sur 100, soit la meme proportion que le +2 sur 6 d'avant. Une
		# upgrade se dose en FRACTION de la barre, jamais en points absolus :
		# +2 sur 100 ne se verrait pas.
		"tiers": [
			{"max_health": 130, "heal": 30},
			{"max_health": 160, "heal": 30},
			{"max_health": 190, "heal": 30},
		],
	},
	{
		"id": "pickup_radius",
		"kind": Kind.PASSIVE,
		"tiers": [
			{"pickup_radius": 3.35},
			{"pickup_radius": 4.20},
			{"pickup_radius": 5.05},
		],
	},
	{
		"id": "xp_gain",
		"kind": Kind.PASSIVE,
		# La croquette rapporte plus. C'est le seul passif qui n'agit ni sur le
		# combat ni sur la survie mais sur la COURBE : il ne rend pas la run plus
		# facile, il la rend plus rapide, donc plus dense en decisions.
		#
		# ⚠️ Il se multiplie a la SOURCE, dans `player.collect_xp`, et pas sur le
		# seuil de niveau. Reduire `xp_to_next` aurait donne le meme resultat en
		# apparence et un tout autre comportement : le seuil grandit de 35 % par
		# niveau, donc un rabais dessus vaudrait de plus en plus cher a mesure
		# que la run avance. Un multiplicateur a la source vaut le meme facteur du
		# debut a la fin.
		"tiers": [
			{"xp_gain": 1.30},
			{"xp_gain": 1.60},
			{"xp_gain": 2.00},
		],
	},
	{
		"id": "toughness",
		"kind": Kind.PASSIVE,
		# Le pelage epais : une FRACTION des degats en moins, jamais un forfait.
		#
		# ⚠️ Une reduction forfaitaire ("−5 par coup") aurait rendu le chat
		# invulnerable aux petits coups en debut de run et inutile a la fin, quand
		# le chaser tape a 21. Une fraction garde la meme valeur sur toute la
		# courbe — c'est exactement l'argument qui avait fait passer la vie a 100
		# points, ou l'arrondi ecrasait tout.
		#
		# Il complete `max_health` au lieu de le doubler : l'un allonge la barre,
		# l'autre ralentit sa descente. Pris ensemble ils se multiplient, ce qui
		# est la premiere synergie de build du jeu (§11, "chat tank").
		"tiers": [
			{"damage_reduction": 0.15},
			{"damage_reduction": 0.27},
			{"damage_reduction": 0.38},
		],
	},
]


static func find(id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if definition["id"] == id:
			return definition

	assert(false, "Competence inconnue : " + id)
	return {}


static func kind_of(id: String) -> Kind:
	return find(id)["kind"]


## Le dernier palier atteignable. Les ultimes n'etant ecrits nulle part, toute
## competence plafonne aujourd'hui a sa derniere entree de `tiers` — et un passif
## y plafonne de toute facon (§2.5).
static func max_tier(id: String) -> int:
	var definition := find(id)
	var tiers: Array = definition["tiers"]

	if definition["kind"] == Kind.PASSIVE:
		return mini(tiers.size(), PASSIVE_MAX_TIER)

	return tiers.size() + (1 if definition.get("ultimates", []).size() > 0 else 0)


## Les valeurs d'un palier. `tier` est 1-base — T1 est le premier, pas le zeroe :
## un palier 0 signifie "le chat n'a pas cette competence".
static func tier_values(id: String, tier: int) -> Dictionary:
	var tiers: Array = find(id)["tiers"]
	return tiers[clampi(tier - 1, 0, tiers.size() - 1)]


static func slot_limit(kind: Kind) -> int:
	match kind:
		Kind.AUTO:
			return MAX_AUTO_SLOTS
		Kind.ACTIVE:
			return MAX_ACTIVE_SLOTS

	# Les passifs ne coutent rien a l'ecran : rien ne justifierait de les
	# plafonner en nombre (§2.5).
	return 0x7FFFFFFF
