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
##   ACTIF   se declenche sur une touche, a un cooldown. Il y en a TROIS depuis
##           le 2026-08-19 — `bite`, `hiss` et `purr` — pour DEUX slots.
##           ⚠️ C'est le point de cette derniere entree, et il vaut plus que la
##           competence elle-meme : tant qu'il n'y avait que deux actifs, la
##           famille etait saturee des qu'on les avait pris, mais `roll` n'avait
##           rien a proposer en remplacement — le carton "quoi remplacer ?"
##           (chantier 2 de §2.9) ne pouvait donc JAMAIS s'ouvrir, meme une fois
##           ecrit. A trois, il devient exercable en jeu.
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

## Les slots du chat — §2.3.
##
## ⚠️ QUAND C'EST PLEIN, ON REMPLACE (2026-08-19, chantier 2 de §2.9). Jusqu'a
## ce jour, `roll` cessait simplement de proposer des competences NEUVES du type
## sature : le jeu n'aurait pas su faire porter une 7e arme. Il sait desormais —
## une neuve reste tirable tant qu'au moins une des competences portees peut lui
## ceder sa place, et le carton "quoi remplacer ?" ouvre derriere le choix.
##
## ⚠️ "AU MOINS UNE PEUT LUI CEDER SA PLACE" N'EST PAS "LA FAMILLE EST PLEINE",
## et c'est la slot AUTO n°1 qui fait la difference : une arme DIRIGEE ne se
## remplace que par une autre arme dirigee (voir `is_directed`). Une neuve dont
## la liste de candidates serait vide ne doit donc pas sortir du tirage — d'ou
## un seul et meme calcul pour le tirage et pour le carton
## (`skill_set.replacement_candidates`). Deux filtres separes, c'est une carte
## qu'on propose et qu'on ne peut pas prendre.
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
		#
		# ⚠️ RALENTIE DEUX FOIS LE 2026-08-19 : 17,5 / 19 / 21, puis 10 / 12 / 14,
		# enfin 7 / 8,5 / 10 m/s (demande directe). Le premier pas venait du
		# passage de la capsule au modele — a 17,5 m/s la boule parcourait 0,29 m
		# par frame a 60 fps pour 0,77 m de long, sautait la moitie de sa propre
		# longueur d'une frame a l'autre, et n'apparaissait que deux ou trois fois
		# sur tout son trajet dans une capture a 30 fps. Modeliser un objet qu'on
		# ne voit pas passer n'aurait rien montre.
		#
		# A 7 m/s elle avance de 0,12 m par frame, soit un sixieme de sa longueur.
		# Elle se recouvre largement d'une frame a la suivante : l'oeil SUIT une
		# trajectoire au lieu de constater une trainee de fantomes.
		#
		# ⚠️ C'EST LA VITESSE DU CHAT (7,5 m/s), ET C'EST LA VRAIE BORNE BASSE.
		# En dessous, le chat rattraperait ses propres boules — un projectile
		# qu'on double ne se lit plus comme un tir. Elle reste au-dessus du chaser
		# de depart (3,7 m/s) et le rejoint vers 180 s de run, quand la difficulte
		# le pousse a ~6,3 : a ce moment-la seul un ennemi qui COUPE la
		# trajectoire echappe encore a la boule, ceux qui foncent sur le chat lui
		# rentrent dedans. C'est exactement la ou `projectile_speed` prend sa
		# valeur.
		#
		# ⚠️ VITESSE ET PORTEE MONTENT ENSEMBLE, et c'est ce qui garde le temps de
		# vol constant : 1,57 / 1,53 / 1,50 s aux trois paliers. Un palier qui
		# n'aurait allonge que la portee aurait rendu l'arme PLUS LENTE a
		# atteindre sa cible a mesure qu'on la renforce.
		"tiers": [
			{"damage": 2, "interval": 1.60, "speed": 7.0, "range": 11.0},
			{"damage": 3, "interval": 1.35, "speed": 8.5, "range": 13.0},
			{"damage": 4, "interval": 1.10, "speed": 10.0, "range": 15.0},
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
		# La recharge est longue. Une sortie de secours qui revient vite n'est
		# plus une decision, c'est une touche a marteler.
		#
		# ⚠️ Elle etait LA PLUS LONGUE du jeu jusqu'au 2026-08-19 ; le ronron lui
		# a pris ce titre (14 s), et pour une raison qui vaut d'etre notee :
		# le feulement rend de la PLACE, qui se reperd des que les ennemis
		# reviennent, alors que le ronron rend de la VIE, qui reste acquise. Ce
		# qu'une competence laisse derriere elle se paye en recharge.
		"tiers": [
			{"radius": 3.60, "damage": 1, "cooldown": 11.0},
			{"radius": 4.30, "damage": 2, "cooldown": 9.5},
			{"radius": 5.00, "damage": 3, "cooldown": 8.0},
		],
		"ultimates": [],
	},

	{
		"id": "purr",
		"kind": Kind.ACTIVE,
		"script": "res://scripts/skills/purr_skill.gd",
		# Le ronron — le 3e ACTIF, et le premier SOIN du jeu (2026-08-19).
		#
		# ⚠️ IL RENDRAIT TROP VITE S'IL RENDAIT D'UN COUP, et ce n'est pas une
		# question de quantite : c'est ce qui decide qu'il y ait une decision. Le
		# soin tombe en QUATRE bouffees sur deux secondes (`purr_halo.PULSES`),
		# donc un ronron lance trop tard ne sauve pas — sa quatrieme bouffee
		# arrive apres le coup fatal. Un soin instantane se presse quand la barre
		# est basse et ne demande rien a personne ; celui-ci demande d'anticiper.
		# Voir `purr_skill.gd`.
		#
		# ─── L'ECHELLE DES CHIFFRES ───
		#
		# Le chaser tape a 15 au contact, la brute a 30, et un ennemi colle frappe
		# toutes les 0,7 s — soit ~21 points de vie par seconde. Le ronron T1
		# rend 1,3 par seconde : il ne tient PAS un chat au contact, et c'est
		# voulu. C'est un outil d'entre-deux-vagues, pas un bouclier. Au T3 il
		# rend 40, soit un peu plus qu'un coup de brute : de quoi effacer une
		# erreur, jamais de quoi en faire une strategie.
		#
		# ⚠️ LA RECHARGE EST LA PLUS LONGUE DU JEU (14 s au T1), devant le
		# feulement. Ce qu'une competence laisse derriere elle se paye en
		# recharge : la place rendue par le feulement se reperd, la vie rendue par
		# le ronron est acquise.
		#
		# ⚠️ `heal` EST BIEN UNE VALEUR DE PALIER ORDINAIRE ICI, a ne pas
		# confondre avec la cle `heal` de `max_health`. La-bas c'est un EVENEMENT
		# de prise, que `skill_set.passive_values` exclut expressement pour ne pas
		# resoigner le chat a chaque recalcul ; ici c'est la feuille de soin d'un
		# actif, lue au declenchement par `purr_skill._fire`. Les deux ne se
		# croisent jamais — `passive_values` ne regarde que les PASSIFS.
		"tiers": [
			{"heal": 18, "cooldown": 14.0},
			{"heal": 28, "cooldown": 12.0},
			{"heal": 40, "cooldown": 10.0},
		],
		"ultimates": [],
	},

	# ── PASSIF ────────────────────────────────────────────────────────────────
	#
	# Ils reglent presque tous le CORPS du chat, jamais une arme. C'est ce qui
	# les rend compatibles avec des armes qui portent desormais leurs propres
	# paliers — aucune montee n'est comptee deux fois.
	#
	# ⚠️ CE QUI N'EST PAS NEGOCIABLE, C'EST LE DEGAT, pas le mot « arme ». La
	# regle existe pour empecher le double comptage de §2.9 : un passif qui
	# reglerait un degat le recreerait aussitot. `projectile_speed` (2026-08-19)
	# est la premiere exception, et elle est argumentee sur sa propre entree —
	# elle ne touche aucun degat, elle multiplie une base absolue au lieu de s'y
	# ajouter, et elle vaut pour tout projectile plutot que pour une arme.
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
		"id": "projectile_speed",
		"kind": Kind.PASSIVE,
		# ⚠️ LE SEUL PASSIF QUI TOUCHE UNE ARME, ET IL FAUT DIRE POURQUOI.
		#
		# La ligne de partage posee plus haut (« un passif regle le CORPS du
		# chat, jamais une arme ») n'est pas une regle de vocabulaire : elle
		# existe pour empecher le DOUBLE COMPTAGE de §2.9, ou une meme montee
		# etait payee deux fois — par le palier de l'arme et par une carte a
		# part. Trois choses la tiennent ici :
		#
		#   * ce n'est pas un degat. La feuille de degats de la boule de poils
		#     ne bouge pas d'un point ; ce qui change est la PROBABILITE qu'elle
		#     atteigne une cible qui se deplace, donc la sensation de visee ;
		#   * c'est un MULTIPLICATEUR pose sur une base absolue, pas une seconde
		#     source de la meme valeur. Il compose avec le palier comme
		#     `toughness` compose avec `max_health` — la premiere synergie du
		#     jeu — au lieu de s'y additionner ;
		#   * il vaut pour TOUT projectile, pas pour la boule de poils. C'est
		#     une propriete du crachat du chat, et la prochaine arme a
		#     projectile en heritera sans qu'on ecrive une ligne.
		#
		# ⚠️ Il avait deja existe, et il a ete SORTI DU POOL le 2026-08-16 avec
		# une raison qui n'est plus vraie : le projectile venait d'etre debranche
		# au profit de la griffure, donc l'upgrade n'ameliorait plus rien de
		# visible — « un mensonge a l'ecran ». La boule de poils l'a rallume, et
		# le ralentissement du 2026-08-19 rend l'amelioration franchement
		# lisible : a 10 m/s on VOIT la boule mettre du temps a arriver.
		#
		# La courbe est celle de `xp_gain`, volontairement : deux multiplicateurs
		# a la source, deux fois la meme forme a retenir. Au T3 sur une boule T3,
		# 14 x 2,0 = 28 m/s — plus vif que les 21 m/s d'avant le ralentissement,
		# donc le build « chat sniper » recupere l'instantaneite d'antan comme
		# une RECOMPENSE et non comme reglage par defaut. C'est exactement ce que
		# l'aimant a croquettes a fait de ses 5 m.
		"tiers": [
			{"projectile_speed": 1.30},
			{"projectile_speed": 1.60},
			{"projectile_speed": 2.00},
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


## L'arme DIRIGEE — celle qui obeit au curseur. La griffure est la seule
## aujourd'hui, et c'est la slot AUTO n°1 de §2.3.
##
## ⚠️ CE DRAPEAU EST UNE REGLE DE REMPLACEMENT, pas une etiquette. §2.3 : le chat
## garde TOUJOURS une arme sous le curseur, il peut seulement en changer. La
## visee souris est ce que le jeu a de plus singulier — un build qui
## l'abandonnerait ferait retomber Zeucozy dans le survivor pur, ou le joueur ne
## decide que de sa position. Une arme dirigee ne peut donc ceder sa place qu'a
## une autre arme dirigee.
##
## 🅿️ Question restee ouverte, et elle ne se pose pas encore : DEUX armes
## dirigees a la fois. `claw` etant la seule du catalogue, le cas est
## inatteignable ; le jour ou une seconde sera ecrite, il faudra trancher si
## elles coexistent (deux armes sur le meme curseur "ne font qu'une arme",
## dit-on de la boule de poils) ou si la slot n°1 est exclusive.
static func is_directed(id: String) -> bool:
	return find(id).get("directed", false)


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
