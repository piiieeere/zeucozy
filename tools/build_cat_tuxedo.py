"""Construit LE CHAT TUXEDO — geometrie, rig, poids et Attr_Style, d'un bloc.

    "<blender>" --background --factory-startup \
        --python tools/build_cat_tuxedo.py -- --save

D'apres `maquettes/CatTuxedo.png` (7 vues, aplats francs, marques comptables).
Meme moule que `build_mouse.py` / `build_dog.py` — un .blend REGENERE, jamais
edite a la main. C'est la premiere fois que ce moule sert pour un modele a
SQUELETTE : le rig et les poids sont poses ici aussi, sinon la geometrie et son
rig auraient deux sources et divergeraient (ce que le premier chat a paye —
voir "Le chat" dans le journal, le .blend retrouve reenregistre sans sa passe
tuxedo).

CE QU'IL REMPLACE. `assets/models/player_cat.glb`, le chat de 2026-08-16 :
13 028 tris, 21 coques spheriques fusionnees, tete de 1,00 de large sur 1,86
de haut (54 % de la hauteur). Il reste dans le depot, il n'est plus charge.

────────────────────────────────────────────────────────────────────────────
CE QUE LA MAQUETTE DECIDE (et rien d'autre — "Prompts de Generation" §0)
────────────────────────────────────────────────────────────────────────────
  * les MASSES, comptables : 1 corps, 1 tete, 2 oreilles, 4 pattes, 1 queue,
    et les marques blanches (bavette, 4 chaussettes, bout de queue) ;
  * les PROPORTIONS : chat elance, tete ronde d'environ 1/3 de la hauteur,
    oreilles TRES hautes et pointues (0,42 — les deux tiers du diametre du
    crane), queue longue ;
  * ce qui est PEINT : yeux, truffe, bouche, moustaches. Rien de tout ca n'est
    modelise, c'est §2bis et c'est aussi la demande explicite.

Les COULEURS, elles, ne sortent pas des pixels de l'image mais de la DA §4 :
noir chaud #4A4038 (jamais #000000), creme #F7EFE0 (jamais un blanc froid),
rose poudre #E8B8A8. Le vert des yeux est dessine par `cel_face.gdshader` et
n'apparait donc nulle part ici.

────────────────────────────────────────────────────────────────────────────
LES SEPT COQUES, ET POURQUOI PAS UNE DE PLUS
────────────────────────────────────────────────────────────────────────────
`corps` (balayage), `tete` (ellipsoide + museau), 2 x `oreille`, 4 x `patte`,
4 x `chausson`, `queue` + `bout_queue`, `plastron`.

⚠️ UNE MARQUE BLANCHE EST UNE COQUE, PAS UNE ZONE DE MATIERE. C'est le seul
endroit ou ce modele depense de la geometrie sans y etre force, et la raison
est mesuree :

  * une ZONE de matiere sur une grille de balayage a sa frontiere posee sur
    les meridiens. Elle sort donc en ESCALIER des que la frontiere n'est pas
    parallele a la grille — le defaut que les meches de la boule de poils ont
    paye, et que la souris n'a evite qu'en posant ses zones sur des paralleles.
    La bavette d'un tuxedo est justement une forme qui s'evase : elle croiserait
    la grille en biais sur toute sa longueur ;
  * une COQUE fermee porte sa propre coque inversee, donc sa propre ENCRE. La
    maquette montre precisement ca : un trait sombre cerne la bavette, les
    chaussettes et le bout de queue. Le trait n'est pas un effet de bord, c'est
    le dessin.

Le prix est de ~700 tris sur 3 800. Les zones de matiere restent utilisees la
ou la frontiere SUIT la grille : le visage et le museau sur la tete (calottes
polaires autour de l'axe du museau), le rose a l'interieur de l'oreille (une
bande d'angle constant, donc deux droites du bord a la pointe).

⚠️ ET LE ROSE D'OREILLE N'EST PLUS UNE CALOTTE PROJETEE. Sur le chat de
2026-08-16 il l'etait (`PAINTED` dans cel_model.gd), et le tour de camera le
montre pour ce que c'est : deux grandes taches roses posees SUR LE CRANE, en
noeud papillon, parce qu'une calotte ne connait pas la frontiere de l'oreille.
Ici le rose est de la matiere sur la coque de l'oreille : il s'arrete ou
l'oreille s'arrete, par construction.

────────────────────────────────────────────────────────────────────────────
LES CINQ MATIERES — ce sont les noms que `cel_model.gd` reconnait
────────────────────────────────────────────────────────────────────────────
  fourrure         noir       corps, tete (arriere), pattes, queue, oreilles
  visage           noir       la calotte avant du crane — meme couleur que la
                              fourrure : la frontiere est INVISIBLE, seul le
                              shader change (yeux, truffe, bouche, moustaches)
  museau_peint     creme      la calotte du museau, sous la bavette DESSINEE
  fourrure_blanche creme      chaussettes, bout de queue, plastron
  oreille_rose     rose       l'interieur du pavillon

`fourrure_blanche` porte `cel_paws.gdshader`, donc les griffes. Le plastron et
le bout de queue partagent ce materiau et n'en recoivent aucune : le shader
choisit sa matrice PAR SOMMET d'apres l'os porteur, et ces deux-la n'ont pas
d'os de patte. C'est deja le cas du bout de queue depuis 2026-08-16, on ne fait
que s'appuyer dessus.

⛔ PAS DE `corps_peint`. Le premier chat avait un dos d'un cran plus sombre
pour detacher la tete du corps en vue plongeante. Ce chat-ci a un COU (creux de
nuque a 0,175 pour un crane a 0,325, soit 46 % de pincement) et une ombre
peinte a la nuque : la separation est faite par la forme, pas par une seconde
teinte de noir. Une surface de moins, deux draw calls de moins.

────────────────────────────────────────────────────────────────────────────
LE RIG — memes 29 os, memes noms, memes axes que le chat de 2026-08-16
────────────────────────────────────────────────────────────────────────────
Ce n'est pas de la nostalgie : `tools/build_animations.py` nomme ses os en dur
(`racine`, `dos`, `thorax`, `cou`, `tete`, `oreille_*`, `queue_1..3`, `bras_*`,
`avantbras_*`, `cuisse_*`, `jambe_*`) et `cel_model.PAWS` nomme les quatre os
de patte. Garder les noms, c'est garder idle et walk sans les rejouer a la
main, et garder les griffes.

⚠️ LES AXES LOCAUX SE POSENT, ILS NE SE DEVINENT PAS. `build_animations.py`
suppose que `rx` est un tangage sagittal : il faut donc que l'axe X local de
chaque os soit l'axe X du monde. Blender ne le donne pas tout seul (le roll par
defaut depend de l'orientation de l'os), d'ou `align_roll()` sur chaque os.
Et `dos` garde son X local INVERSE (-1, 0, 0), comme sur le premier rig :
`idle` y pose -1,8° contre +2,6° au thorax, soit une paire qui s'oppose. Poser
un X droit ici retournerait la respiration sans que rien ne previenne.

⚠️ LES POIDS NE SONT PAS TOUS RIGIDES, ET C'EST UN CHANGEMENT ASSUME.
"Pipeline 3D" piege n°3 dit "poids rigides (1 objet = 1 os)" — c'etait la regle
d'un modele fait de 21 coques separees, ou chaque coque etait un os. Ici le
corps est UNE coque continue : des poids rigides y poseraient une cassure
franche a chaque frontiere d'os. Les poids sont donc degrades le long des
chaines (colonne, pattes, queue).

Ce que la regle protegeait reste protege, et c'est ca qui compte :
`rest_undo` doit etre EXACT sur les surfaces PEINTES. Elles le sont toutes :

  * `visage` et `museau_peint` sont sur la coque `tete`, a poids 1 sur l'os
    `tete` — le rapport final le verifie et refuse d'ecrire sinon ;
  * les griffes lisent l'os PAR SOMMET (`BONE_INDICES`), et la partie basse du
    chausson — celle qui porte la boite de griffes — est a poids 1 sur son os
    de patte. Meme verification.

────────────────────────────────────────────────────────────────────────────
BUDGET — ~3 800 tris, contre 13 028
────────────────────────────────────────────────────────────────────────────
§11 accorde au joueur "~13 k tris assumes", et la demande est explicitement
d'y faire attention. Les 13 k du premier chat n'etaient pas un choix de
densite : c'etaient 21 spheres UV a 512 faces, dont une sphere `ventre`
entierement enfermee dans une autre (mesuree invisible en 2026-08-16). Ici la
densite est mise la ou la silhouette se joue — les meridiens du corps et de la
tete, le bord des oreilles — et nulle part ailleurs.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/chat_tuxedo_v1.blend")

COLLECTION = "chat_tuxedo"
MESH_OBJECT = "MSH_chat_tuxedo"
ARMATURE_OBJECT = "squelette"
ATTRIBUTE = "Attr_Style"

# ─── LES MATIERES ─────────────────────────────────────────────────────────────
NOIR = "#4A4038"
CREME = "#F7EFE0"
ROSE = "#E8B8A8"

MATERIALS = [
	("fourrure", NOIR),
	("visage", NOIR),
	("museau_peint", CREME),
	("fourrure_blanche", CREME),
	("oreille_rose", ROSE),
]
MAT_FOURRURE, MAT_VISAGE, MAT_MUSEAU, MAT_BLANC, MAT_ROSE = range(5)

# Memes reglages que les uniforms de cel_toon.gdshader : le ton d'ombre de
# Blender est celui de Godot, et non un second reglage a la main.
SHADOW_HUE_SHIFT = -0.02
SHADOW_SATURATION = 1.15
SHADOW_VALUE = 0.65
RAMP_SPLIT = 0.52

# ─── LE CORPS ─────────────────────────────────────────────────────────────────
#
# Un BALAYAGE, comme la souris : une section elliptique qui suit un axe, du
# croupion (t = 0) au haut du cou (t = 1). Le chat regarde -Y.
#
# ⛔ LA TETE N'EST PAS DANS LE BALAYAGE, ET L'ESSAYER EST UNE PERTE DE TEMPS.
# Sur la souris, tete et corps sont une seule masse effilee : le balayage les
# porte. Un chat a un COU, donc l'axe tourne de ~90° entre la nuque et le
# museau. Une section de rayon 0,32 posee sur un virage de rayon ~0,15 se
# retourne sur elle-meme du cote interieur — la gorge sortirait pincee et
# auto-intersectee. La tete est donc une coque a part (voir plus bas), et le
# joint tete/cou produit le trait parasite du piege n°2, qui se lit ici comme
# la ligne de machoire. On le garde.
BODY_Y = [
	(0.00, 0.60), (0.08, 0.52), (0.20, 0.36), (0.35, 0.14), (0.50, -0.10),
	(0.65, -0.32), (0.78, -0.50), (0.88, -0.60), (1.00, -0.68),
]
BODY_Z = [
	(0.00, 0.80), (0.08, 0.83), (0.20, 0.85), (0.35, 0.85), (0.50, 0.85),
	(0.65, 0.86), (0.78, 0.92), (0.88, 1.02), (1.00, 1.14),
]
# Le rayon "vertical" de la section. La largeur en derive (BODY_W).
#
# ⚠️ LE CREUX EST AU COU, PAS A LA TAILLE. Un chat de dessin anime se lit par
# deux masses : la croupe pleine et la tete ronde, separees par un cou fin. Le
# pincement fait 46 % (0,175 contre 0,325 au crane) la ou la souris n'osait que
# 26 % — mais elle n'avait pas de cou du tout, elle en simulait un.
BODY_R = [
	(0.00, 0.000),  # le croupion, un point
	(0.03, 0.122),
	(0.07, 0.196),
	(0.13, 0.252),
	(0.22, 0.294),
	(0.35, 0.304),  # la hanche
	(0.48, 0.306),  # la cage thoracique
	(0.60, 0.298),
	(0.70, 0.272),
	(0.80, 0.234),
	(0.88, 0.205),
	(0.94, 0.188),
	(1.00, 0.178),  # le haut du cou, ENFOUI dans la tete
]
# Largeur / hauteur de la section. Un chat est plus haut que large : la cage
# thoracique est profonde, pas ronde. C'est aussi ce qui laisse la tete (0,65
# de large) etre la masse la plus large du personnage, comme sur la maquette.
BODY_W = [(0.00, 0.96), (0.25, 0.98), (0.50, 0.96), (0.70, 0.92), (1.00, 0.92)]

# Aplatissement du ventre — meme role que sur la souris : une bete posee au sol
# n'y touche pas par une tangente de cercle. Multiplicateur DOUX, §3 n'admet
# aucun angle vif.
BODY_BELLY_FLAT = 0.10

# Sections resserrees vers l'avant : c'est la que le profil tourne (cage,
# epaule, cou). Un pas constant facetterait le cou, la seule courbe serree.
BODY_T = [0.03, 0.07, 0.13, 0.20, 0.28, 0.36, 0.44, 0.52, 0.60, 0.68,
		  0.76, 0.83, 0.89, 0.94, 0.98]
BODY_N_U = 24

# ─── LA TETE ──────────────────────────────────────────────────────────────────
#
# Un ellipsoide dont l'AXE POLAIRE EST CELUI DU MUSEAU, et ce choix fait tout :
#
#   * le museau devient une CALOTTE POLAIRE, donc une zone bornee par des
#     paralleles — ronde dans la parametrisation elle-meme, jamais un escalier
#     de colonnes (la lecon de l'oreille de souris) ;
#   * le visage devient la calotte polaire large, meme benefice ;
#   * les meridiens se resserrent naturellement la ou le regard se pose.
#
# ⚠️ L'AXE DU MUSEAU POINTE VERS LE HAUT DE 16°, ET CE N'EST PAS DE L'ANATOMIE.
# `cel_face.gdshader` dessine dans un repere BASCULE de `face_pitch_deg` = 26°
# vers le haut, parce que la camera plonge de 45° (§11). La truffe dessinee
# tombe donc a ~21° au-dessus de l'horizontale. Un museau modelise a plat
# sortirait 21° sous la truffe qu'on peint dessus. Le premier chat avait deja
# ce compromis, a 13,5° — mesure sur son .blend, jamais ecrit nulle part.
HEAD_CENTER = Vector((0.0, -0.80, 1.30))
# ⚠️ RELEVEE DE 8 % LE 2026-08-20, APRES CAPTURE A TAILLE DE JEU, ET C'EST §15
# QUI TRANCHE (lisibilite > detail). Le premier jet suivait la maquette au plus
# pres : un chat elance, 0,65 de tete. A l'ecran, sous la plongee a 45°, il
# pesait la meme masse qu'une SOURIS — meme valeur sombre, meme empreinte au
# sol — et dans un survivor le joueur doit retrouver son chat sans le chercher.
# §3 le disait deja autrement : "tete legerement surdimensionnee".
HEAD_R = Vector((0.360, 0.340, 0.325))
MUZZLE_AXIS = Vector((0.0, -0.961, 0.276)).normalized()

# Le museau : un renflement radial gaussien autour de l'axe polaire. Le rayon
# vaut R x (1 + bump x exp(-(phi/sigma)^2)).
#
# ⚠️ Un renflement, pas un cone. §3 : "formes simples et rondes, pas d'angles
# vifs" — et un museau conique attrape une arete franche sur la silhouette de
# profil, exactement ce que la croupe de la souris avait paye.
MUZZLE_BUMP = 0.22
MUZZLE_SIGMA = math.radians(28.0)

# ─── LA JOUE ET LE MENTON (2026-08-20) ────────────────────────────────────────
#
# Un ellipsoide nu ne fait pas cette tete-la. Deux corrections, relevees sur la
# maquette :
#
#   * VUE DE FACE, la tete est PLUS LARGE EN BAS qu'en haut — le crane se
#     resserre au-dessus des yeux, les joues (les coussinets a moustaches) sont
#     la partie la plus large. C'est le contraire d'un ellipsoide, qui est le
#     plus large a mi-hauteur et se resserre symetriquement.
#   * DE PROFIL, le museau et le menton forment UNE MASSE qui descend en avant.
#     Le nez est a la pointe haute de cette masse, pas a son centre : sous le
#     nez, le dessin continue vers le bas-avant jusqu'au menton.
#
# Les deux sont des modulations DOUCES du rayon — §3 n'admet aucun angle vif, et
# la coque inversee transformerait le moindre pli en tache d'encre.
CHEEK_FLARE = 0.16
CHIN_AXIS = Vector((0.0, -0.72, -0.69)).normalized()
CHIN_BUMP = 0.10
CHIN_SIGMA = math.radians(34.0)

# Les deux calottes, en angle polaire depuis l'axe du museau.
#   * `visage` doit couvrir LARGEMENT le cone de `face_front_min` (0,46, soit
#     ±62,6° autour d'un axe deja bascule de 26°). A 78° la marge tient meme
#     quand la tete tourne de quelques degres en animation ;
#   * `museau_peint` est creme et se pose SOUS la bavette dessinee : sa
#     frontiere est donc invisible, blanc sur blanc. Elle existe pour que le
#     museau reste creme meme si le dessin de la bavette bougeait.
FACE_CAP_DEG = 78.0
MUZZLE_CAP_DEG = 21.0

HEAD_N_U = 24
HEAD_N_V = 13

# ─── LES OREILLES ─────────────────────────────────────────────────────────────
#
# LA signature du chat sur la maquette : deux triangles TRES hauts (0,42 pour
# un crane de 0,65 de large), pointus, l'interieur rose.
#
# Chacune est un cone tres aplati : des sections elliptiques (largeur x
# epaisseur) le long d'un axe. La pointe se ferme en quart de cercle, jamais en
# angle (§3).
#
# ⚠️ LA BASE EST ENFOUIE DANS LE CRANE. Posee dessus, elle laisserait voir son
# disque de fermeture des que la tete tourne — et la coque inversee de l'oreille
# cernerait ce disque, ce qui se lit comme une entaille.
EAR_BASE = Vector((0.158, -0.83, 1.49))
EAR_AXIS = Vector((0.362, -0.121, 0.925)).normalized()
# La normale de l'oreille — la direction que regarde sa face rose.
#
# ⚠️ DEHORS + DEVANT + LE CIEL. La part de ciel n'est pas decorative : sous une
# plongee a 45°, une oreille strictement verticale se voit PAR LA TRANCHE et son
# rose disparait. C'est le meme calcul que sur la souris.
EAR_NORMAL = Vector((0.34, -0.85, 0.40)).normalized()
EAR_LENGTH = 0.42
EAR_W0 = 0.155   # demi-largeur a la base
EAR_H0 = 0.055   # demi-epaisseur a la base
EAR_TAPER_W = 0.75
EAR_TAPER_H = 0.85
EAR_N_U = 16
EAR_N_V = 7
# La bande rose : |angle a la face avant| < 50°, et pas jusqu'a la pointe.
# La frontiere suit deux MERIDIENS (donc deux droites de la base a la pointe) et
# une SECTION (donc un bord net) : aucune diagonale sur la grille, aucun
# escalier. L'ourlet de pelage qui reste sur le pourtour est ce qui empeche le
# rose d'atteindre la silhouette — sans lui, l'oreille se lit comme un triangle
# rose pose sur la tete.
EAR_PINK_DEG = 42.0
EAR_PINK_S = 0.86

# ⛔ LA TOUFFE BLANCHE DE L'OREILLE A ETE POSEE PUIS RETIREE (2026-08-20).
# La maquette la dessine sur ses sept vues, et c'est un bouquet de poils —
# effiloche, irregulier, plus large en haut. Rendue en zone de matiere sur la
# grille de l'oreille (16 meridiens), elle sortait en RECTANGLE BLANC franc.
# C'est le meme mur que l'accent du dos et que les meches de la boule de poils :
# UNE ZONE POSEE SUR UNE GRILLE NE PEUT PAS ETRE PLUS FINE QU'UNE FACE, et une
# touffe de poils est par nature plus fine que ca.
# Le jour ou elle reviendra, ce sera par un shader d'oreille (comme le visage et
# les griffes), pas par de la matiere.

# ─── LES PATTES ───────────────────────────────────────────────────────────────
#
# Quatre tubes a sections circulaires, sur un chemin en zigzag doux. Les
# rayons sont bornes par L'ENCRE et non par le dessin : la coque inversee fait
# ~0,035 en unites monde et deborde de chaque cote, donc un tube de rayon r
# sort a l'ecran avec r / (r + 0,035) de coeur en pelage. A 0,075 il en reste
# 68 % — le membre se lit comme un objet cerne. (La queue de la souris avait
# pris la meme borne par l'autre bout, a 57 %.)
#
# Le haut est ENFOUI dans le corps : le tube doit s'y enfoncer franchement,
# sinon le joint se voit des que la patte balance.
FRONT_LEG = {
	"x": 0.20,
	"path": [(-0.34, 0.84), (-0.33, 0.62), (-0.32, 0.44), (-0.36, 0.29),
			 (-0.40, 0.195), (-0.46, 0.105)],
	"radius": [0.105, 0.092, 0.084, 0.079, 0.077, 0.070],
}
HIND_LEG = {
	"x": 0.225,
	"path": [(0.30, 0.84), (0.24, 0.62), (0.14, 0.45), (0.26, 0.32),
			 (0.32, 0.215), (0.24, 0.125), (0.13, 0.085)],
	"radius": [0.150, 0.143, 0.104, 0.081, 0.074, 0.073, 0.068],
}
LEG_N_U = 12
LEG_N_V = 14

# Les CHAUSSONS — les quatre marques blanches des pattes.
#
# Une coque a part (voir l'en-tete), posee par-dessus le tube de la patte avec
# 0,012 de jeu. Ce jeu est ce qui rend le trait : la coque inversee du chausson
# cerne son bord, et le petit gradin de 0,012 au poignet se lit comme le revers
# d'une chaussette — c'est le trait que la maquette dessine a cet endroit.
#
# La maquette met le blanc plus haut devant (une botte) que derriere (un
# chausson) : le rapport est de 0,45 contre 0,30 de la longueur de la patte.
SOCK_GAP = 0.012
SOCK_FRONT_S = 0.55   # part du chemin (0 = epaule) a partir de laquelle c'est blanc
SOCK_HIND_S = 0.71
SOCK_N_V = 6

# ─── LA QUEUE ─────────────────────────────────────────────────────────────────
#
# Longue, relevee, la pointe qui revient vers l'avant — le point d'interrogation
# de la maquette.
#
# ⚠️ ELLE RESTE DANS LE PLAN SAGITTAL (x <= 0,10). Le premier chat avait sa
# pointe a x = 0,52, et `build_animations.tail()` en a tire une regle : une
# queue deja couchee en X ne peut plus balayer lateralement sans se coucher
# dans l'axe de la camera de profil. Le balancement du jeu est sagittal ; une
# queue sagittale au repos le montre en entier sous n'importe quel lacet.
#
# ⚠️ ELLE SE PORTE A LA VERTICALE, ET C'EST LA MAQUETTE QUI L'A TRANCHE.
# `maquettes/CatTuxedoWalk.png` montre le chat en marche sur six poses : la
# queue y est DROITE, au-dessus de la croupe, la pointe blanche a hauteur
# d'oreille. Trois formes ont ete rendues avant celle-la :
#
#   * une queue courte et crochue (pointe ramenee vers l'avant) — elle sortait
#     en ANNEAU au banc : sous la plongee, le crochet se referme sur lui-meme et
#     la pointe blanche se voit par le bout, donc en disque ;
#   * une queue longue couchee vers l'arriere (y jusqu'a 1,32) — lisible, mais
#     ce n'est pas ce chat-la : couchee, elle raconte un chat qui traque, pas un
#     chat qui trotte ;
#   * celle-ci, qui part vers l'arriere sur le premier tiers puis monte droit.
#
# Le premier tiers couche n'est pas decoratif : c'est ce qui reste lisible sous
# la plongee a 45°, ou une verticale se raccourcit (la lecon des deux arches de
# souris). La pointe monte a 1,62, juste sous les oreilles (1,87).
TAIL_PATH = [
	(0.00, 0.56, 0.80),
	(0.02, 0.82, 0.90),
	(0.05, 1.00, 1.12),
	(0.08, 1.06, 1.38),
	(0.10, 1.03, 1.62),
]
TAIL_R0 = 0.075
TAIL_R1 = 0.046
TAIL_N_U = 12
TAIL_N_V = 12
# Le bout blanc : meme principe que les chaussons, meme jeu de 0,012.
TAIL_TIP_S = 0.66

# ─── LE PLASTRON ──────────────────────────────────────────────────────────────
#
# La bavette du tuxedo, du haut de la gorge au bas du ventre.
#
# C'est un MORCEAU DE LA SURFACE DU CORPS decolle de 0,012 vers l'exterieur et
# referme par une seconde nappe rentree de 0,006. Consequences, et c'est pour
# elles qu'il est construit comme ca :
#
#   * il epouse le corps exactement, donc aucun z-fighting et aucun jour ;
#   * sa frontiere est ANALYTIQUE (une demi-largeur angulaire fonction de t),
#     donc lisse — c'est tout l'objet de l'exercice ;
#   * ferme, il porte sa propre encre : le trait qui cerne la bavette sur la
#     maquette.
#
# ⚠️ IL NE DOIT PAS ATTEINDRE LE FLANC, ET LA BORNE EST MESUREE.
# A 74° de demi-largeur (premier jet), le blanc remontait assez haut pour se
# voir DE TROIS QUARTS ARRIERE : un liseré clair courait le long du flanc, et il
# ne se lisait pas comme du pelage mais comme un jour entre deux pieces. A 64°
# il s'arrete avant, et la vue de dos redevient tout noire — ce que la maquette
# montre aussi.
# La raison de fond tient au bord : l'encre du corps fait 0,035 et le plastron ne
# depasse que de 0,012, donc pres de la silhouette c'est l'encre qui gagne et le
# blanc sort hache.
BIB_T0 = 0.44
BIB_T1 = 0.99
BIB_LIFT = 0.012
BIB_SINK = 0.006
BIB_N_U = 12
BIB_N_V = 11
# Demi-largeur angulaire, en degres depuis le ventre (a = pi). La forme du
# tuxedo : etroite a la gorge, large au poitrail, pointue au ventre.
BIB_WIDTH = [
	(0.00, 24.0),   # bas du ventre — la pointe du V
	(0.20, 40.0),
	(0.42, 55.0),
	(0.62, 64.0),   # le poitrail, le plus large
	(0.80, 64.0),
	(0.92, 58.0),
	(1.00, 50.0),   # le devant du poitrail, sous la machoire
]

# ─── LE RIG ───────────────────────────────────────────────────────────────────
#
# (nom, parent, tete, queue, axe X local voulu)
#
# L'axe X local doit etre l'axe X du monde partout : `build_animations.py` pose
# ses `rx` comme des tangages sagittaux. `dos` est l'exception historique, il
# garde son X inverse — voir l'en-tete.
X_PLUS = (1.0, 0.0, 0.0)
X_MOINS = (-1.0, 0.0, 0.0)

BONES = [
	("racine", None, (0.0, 0.20, 0.00), (0.0, 0.20, 0.30), X_PLUS),
	("hanches", "racine", (0.0, 0.35, 0.83), (0.0, 0.10, 0.85), X_PLUS),
	("dos", "hanches", (0.0, 0.10, 0.85), (0.0, -0.22, 0.85), X_MOINS),
	("thorax", "dos", (0.0, -0.22, 0.85), (0.0, -0.50, 0.87), X_PLUS),
	("cou", "thorax", (0.0, -0.50, 0.87), (0.0, -0.66, 1.08), X_PLUS),
	("tete", "cou", (0.0, -0.66, 1.08), (0.0, -0.80, 1.62), X_PLUS),
	("epaule_L", "thorax", (0.0, -0.42, 0.86), (-0.20, -0.34, 0.84), X_PLUS),
	("epaule_R", "thorax", (0.0, -0.42, 0.86), (0.20, -0.34, 0.84), X_PLUS),
	("bassin_L", "hanches", (0.0, 0.32, 0.85), (-0.225, 0.30, 0.84), X_PLUS),
	("bassin_R", "hanches", (0.0, 0.32, 0.85), (0.225, 0.30, 0.84), X_PLUS),
]

# ⭐ LES OS DES MEMBRES ET DE LA QUEUE SE DEDUISENT DE LEUR CHEMIN.
#
# Ils sont posés aux ARTICULATIONS, et une articulation est deja un point de
# controle du chemin qui dessine le membre. Les reecrire a la main ferait vivre
# la meme courbe a deux endroits — le defaut exact que ce projet a paye sur
# l'aimant a croquettes ("un chiffre porte a deux endroits, c'est le plus fort
# qui gagne"). Ici la divergence serait pire que muette : l'os passerait a cote
# du tube, et la patte se tordrait autour d'un pivot qui n'est plus dedans.
#
# (nom de l'os, index du point de depart dans le chemin, index d'arrivee)
FRONT_JOINTS = [("bras", 0, 2), ("avantbras", 2, 4), ("pattavant", 4, 5)]
HIND_JOINTS = [("cuisse", 0, 2), ("jambe", 2, 4), ("tibia", 4, 5), ("piedar", 5, 6)]

# La queue n'a pas d'articulation : ses trois os se prennent aux memes abscisses
# que les stations de poids, sinon l'os et le degrade qu'il pilote ne parlent
# pas de la meme portion de courbe.
TAIL_JOINTS = [0.0, 0.34, 0.72, 1.0]

# Les stations de melange des poids, le long de chaque chaine. Le scalaire
# compare est indique par le constructeur de la coque (y pour la colonne, la
# part de chemin pour un membre).
#
# `PLATEAU` est la part de l'intervalle qui reste RIGIDE autour de chaque
# station ; le reste est la transition. A 0,45, un sommet a mi-chemin de deux os
# est a 50/50 et un sommet a un quart de chemin est deja a 100 % du plus proche.
PLATEAU = 0.45

SPINE_STATIONS = [
	(0.60, "hanches"), (0.10, "dos"), (-0.22, "thorax"),
	(-0.50, "cou"), (-0.66, "tete"),
]


# ------------------------------------------------------------------- couleurs

def srgb_to_linear(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return ((value + 0.055) / 1.055) ** 2.4


def hex_to_linear(code: str) -> tuple:
	code = code.lstrip("#")
	return tuple(srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def warm_shadow(rgb: tuple) -> tuple:
	"""Le `warm_shadow()` de cel_core.gdshaderinc, en Python.

	Une ombre Ghibli est plus CHAUDE et plus SATUREE que sa lumiere, jamais un
	gris multiplie ("Convention Blender" §5.1).
	"""
	import colorsys

	h, s, v = colorsys.rgb_to_hsv(*rgb)
	h = (h + SHADOW_HUE_SHIFT) % 1.0
	s = min(1.0, s * SHADOW_SATURATION)
	return colorsys.hsv_to_rgb(h, s, v * SHADOW_VALUE)


# --------------------------------------------------------------------- courbes

def spline(keys, t: float) -> float:
	"""Catmull-Rom NON UNIFORME sur une liste de (t, valeur).

	Recopiee de `build_mouse.py` — non uniforme parce que les cles sont posees
	la ou la forme tourne, pas a intervalles reguliers.
	"""
	if t <= keys[0][0]:
		return keys[0][1]
	if t >= keys[-1][0]:
		return keys[-1][1]

	i = 0
	while i < len(keys) - 2 and keys[i + 1][0] < t:
		i += 1

	t0, v0 = keys[i]
	t1, v1 = keys[i + 1]
	h = t1 - t0
	s = (t - t0) / h

	tm, vm = keys[i - 1] if i > 0 else (t0 - h, v0 - (v1 - v0))
	tp, vp = keys[i + 2] if i + 2 < len(keys) else (t1 + h, v1 + (v1 - v0))

	m0 = (v1 - vm) / (t1 - tm)
	m1 = (vp - v0) / (tp - t0)

	s2 = s * s
	s3 = s2 * s

	return ((2.0 * s3 - 3.0 * s2 + 1.0) * v0
			+ (s3 - 2.0 * s2 + s) * h * m0
			+ (-2.0 * s3 + 3.0 * s2) * v1
			+ (s3 - s2) * h * m1)


def poly_point(points, s: float) -> Vector:
	"""Catmull-Rom sur une polyligne 3D, parametree par s dans [0, 1]."""
	n = len(points) - 1.0
	return Vector([
		spline([(i / n, p[k]) for i, p in enumerate(points)], s)
		for k in range(3)
	])


def poly_scalar(values, s: float) -> float:
	n = len(values) - 1.0
	return spline([(i / n, v) for i, v in enumerate(values)], s)


def transport(points):
	"""Reperes a TRANSPORT PARALLELE le long d'une polyligne.

	Jamais un repere de Frenet : il se retourne des que la courbure s'annule, et
	le zigzag d'une patte arriere a deux points d'inflexion. Le tube se
	vrillerait d'un demi-tour sur une section — invisible sur un tube rond, mais
	ca tord la peinture qu'on y pose.
	"""
	tangents = []
	for j in range(len(points)):
		lo = points[max(0, j - 1)]
		hi = points[min(len(points) - 1, j + 1)]
		tangents.append((hi - lo).normalized())

	ref = Vector((1.0, 0.0, 0.0))
	if abs(ref.dot(tangents[0])) > 0.95:
		ref = Vector((0.0, 1.0, 0.0))
	ref = (ref - tangents[0] * ref.dot(tangents[0])).normalized()

	frames = []
	for tangent in tangents:
		ref = (ref - tangent * ref.dot(tangent)).normalized()
		frames.append((ref.copy(), tangent.cross(ref).normalized(), tangent))

	return frames


def _limb_bones() -> list:
	"""Les os des quatre membres et de la queue, pris sur leurs chemins."""
	bones = []

	for spec, joints, parent, side_parent in (
			(FRONT_LEG, FRONT_JOINTS, "epaule", None),
			(HIND_LEG, HIND_JOINTS, "bassin", None)):
		for side, suffix in ((-1.0, "_L"), (1.0, "_R")):
			x = spec["x"] * side
			previous = parent + suffix

			for name, i0, i1 in joints:
				head = (x, spec["path"][i0][0], spec["path"][i0][1])
				tail = (x, spec["path"][i1][0], spec["path"][i1][1])
				bones.append((name + suffix, previous, head, tail, X_PLUS))
				previous = name + suffix

	# Les oreilles : meme raison, meme geste. L'os va de la base au bout du
	# pavillon, c'est-a-dire exactement le segment que la coque parcourt.
	for side, suffix in ((-1.0, "_L"), (1.0, "_R")):
		base = Vector((EAR_BASE.x * side, EAR_BASE.y, EAR_BASE.z))
		axis = Vector((EAR_AXIS.x * side, EAR_AXIS.y, EAR_AXIS.z)).normalized()
		bones.append(("oreille" + suffix, "tete", tuple(base),
				tuple(base + axis * EAR_LENGTH), X_PLUS))

	previous = "hanches"
	points = [Vector(p) for p in TAIL_PATH]

	for index in range(3):
		name = "queue_%d" % (index + 1)
		head = tuple(poly_point(points, TAIL_JOINTS[index]))
		tail = tuple(poly_point(points, TAIL_JOINTS[index + 1]))
		bones.append((name, previous, head, tail, X_PLUS))
		previous = name

	return bones


def all_bones() -> list:
	"""Le rig complet : le tronc pose a la main, les membres pris sur leurs chemins."""
	return BONES + _limb_bones()


# ----------------------------------------------------------------------- poids

def chain_weights(value: float, stations, band: float = PLATEAU) -> dict:
	"""Poids degrades le long d'une chaine d'os.

	`stations` = [(scalaire, nom d'os)] dans l'ordre de la chaine. Autour de
	chaque station le poids est RIGIDE (c'est le plateau) ; entre deux, il passe
	de l'une a l'autre en smoothstep.

	⚠️ C'est ici que se joue l'exactitude de `rest_undo`. Une surface peinte doit
	tomber DANS un plateau, sinon la matrice de son os ne defait pas exactement
	sa deformation et le dessin glisse. Le rapport final le verifie.
	"""
	values = [s[0] for s in stations]
	ascending = values[-1] > values[0]

	if (ascending and value <= values[0]) or (not ascending and value >= values[0]):
		return {stations[0][1]: 1.0}
	if (ascending and value >= values[-1]) or (not ascending and value <= values[-1]):
		return {stations[-1][1]: 1.0}

	for i in range(len(stations) - 1):
		lo, hi = values[i], values[i + 1]
		if (value - lo) * (value - hi) > 0.0:
			continue

		u = (value - lo) / (hi - lo)
		half = (1.0 - band) * 0.5
		if u <= half:
			return {stations[i][1]: 1.0}
		if u >= 1.0 - half:
			return {stations[i + 1][1]: 1.0}

		k = (u - half) / max(1e-6, 1.0 - 2.0 * half)
		k = k * k * (3.0 - 2.0 * k)
		return {stations[i][1]: 1.0 - k, stations[i + 1][1]: k}

	return {stations[-1][1]: 1.0}


def mirror_weights(weights: dict, side: float) -> dict:
	"""`side` = -1 pour le cote L (x negatif), +1 pour R. Voir BONES."""
	suffix = "_L" if side < 0.0 else "_R"
	return {name + suffix: w for name, w in weights.items()}


# ------------------------------------------------------------------- geometrie

class Builder:
	"""Un bmesh + la liste parallele des infos de peinture et de poids.

	L'ordre d'ajout des sommets est celui du maillage final (bmesh le conserve),
	comme dans `build_mouse.py`. `info` porte la coque, ses parametres de
	peinture et les poids — jamais une position monde, qui deviendrait fausse le
	jour ou on recentrerait le maillage.
	"""

	def __init__(self):
		self.bm = bmesh.new()
		self.info = []

	def vert(self, position: Vector, data: dict):
		self.info.append(data)
		return self.bm.verts.new(position)

	def face(self, verts, material: int):
		f = self.bm.faces.new(verts)
		f.material_index = material
		return f

	def tube(self, rings, material, cap_lo=None, cap_hi=None):
		"""Coud une pile d'anneaux, avec ses deux fermetures."""
		n = len(rings[0])

		for lower, upper in zip(rings, rings[1:]):
			for i in range(n):
				nxt = (i + 1) % n
				self.face((lower[i], lower[nxt], upper[nxt], upper[i]), material)

		if cap_lo is not None:
			for i in range(n):
				nxt = (i + 1) % n
				self.face((cap_lo, rings[0][nxt], rings[0][i]), material)

		if cap_hi is not None:
			for i in range(n):
				nxt = (i + 1) % n
				self.face((cap_hi, rings[-1][i], rings[-1][nxt]), material)


# ------------------------------------------------------------------- le corps

def body_center(t: float) -> Vector:
	return Vector((0.0, spline(BODY_Y, t), spline(BODY_Z, t)))


def body_frame(t: float):
	"""(u, v) de la section : u = X du monde, v dans le plan sagittal.

	Pas de transport parallele ici, et c'est deliberatif : le chemin du corps
	reste dans le plan YZ, donc "l'axe X du monde" est un repere valable partout
	le long de la courbe. Il garantit en plus que le haut de la section est
	exactement le dos — ce dont depend toute la peinture d'ombre.
	"""
	e = 1.0e-3
	tangent = (body_center(min(1.0, t + e)) - body_center(max(0.0, t - e))).normalized()
	u = Vector((1.0, 0.0, 0.0))
	v = tangent.cross(u).normalized()

	return u, v, tangent


def body_point(t: float, a: float) -> Vector:
	"""`a` = 0 sur le dos, ±pi/2 sur les flancs, pi au ventre."""
	r = max(0.0, spline(BODY_R, t))
	w = spline(BODY_W, t)
	u, v, _ = body_frame(t)

	up = math.cos(a)
	flat = 1.0 - BODY_BELLY_FLAT * max(0.0, -up)

	return body_center(t) + v * (r * up * flat) + u * (r * w * math.sin(a))


def body_normal(t: float, a: float) -> Vector:
	"""Normale prise en differences finies sur la PARAMETRISATION.

	Et non sur le maillage : le plastron se pose avant que le maillage existe, et
	une normale relue apres coup dependrait de la densite des sections.
	"""
	e = 1.0e-3
	dt = body_point(min(1.0, t + e), a) - body_point(max(0.0, t - e), a)
	da = body_point(t, a + e) - body_point(t, a - e)
	n = da.cross(dt)

	if n.length < 1.0e-9:
		return Vector((0.0, 0.0, 1.0))

	n.normalize()
	if n.dot(body_point(t, a) - body_center(t)) < 0.0:
		n = -n

	return n


def build_body(b: Builder) -> None:
	def data(t, a):
		return {
			"shell": "corps", "t": t, "a": a,
			"w": chain_weights(spline(BODY_Y, t), SPINE_STATIONS),
		}

	rump = b.vert(body_point(0.0, 0.0), data(0.0, 0.0))
	rings = []

	for t in BODY_T:
		ring = []
		for i in range(BODY_N_U):
			a = math.tau * i / float(BODY_N_U)
			ring.append(b.vert(body_point(t, a), data(t, a)))
		rings.append(ring)

	# Le haut du cou est ENFOUI dans la tete : on le ferme quand meme, une coque
	# ouverte laisserait voir son interieur des que la coque inversee passe.
	neck = b.vert(body_point(1.0, 0.0), data(1.0, 0.0))

	b.tube(rings, MAT_FOURRURE, cap_lo=rump, cap_hi=neck)


# -------------------------------------------------------------------- la tete

def head_point(phi: float, theta: float) -> Vector:
	"""Un point de la tete. `phi` = angle polaire depuis l'axe du museau."""
	u, v, n = head_frame()
	dir = (n * math.cos(phi)
			+ u * (math.sin(phi) * math.cos(theta))
			+ v * (math.sin(phi) * math.sin(theta)))

	bump = 1.0 + MUZZLE_BUMP * math.exp(-(phi / MUZZLE_SIGMA) ** 2)

	# Le menton : une seconde bosse, vers l'avant-bas. Elle prolonge le museau
	# au lieu de l'elargir — les deux gaussiennes se recouvrent, et c'est ce
	# recouvrement qui fait la masse museau/menton d'un seul tenant.
	chin_angle = math.acos(max(-1.0, min(1.0, dir.dot(CHIN_AXIS))))
	bump += CHIN_BUMP * math.exp(-(chin_angle / CHIN_SIGMA) ** 2)

	offset = Vector((dir.x * HEAD_R.x, dir.y * HEAD_R.y, dir.z * HEAD_R.z)) * bump

	# La joue : la largeur seule s'evase vers le bas. Appliquee APRES la bosse,
	# elle emporte le museau avec elle — un museau qui resterait etroit sur des
	# joues larges ferait un bec.
	offset.x *= 1.0 + CHEEK_FLARE * max(0.0, -dir.z) ** 1.3

	return HEAD_CENTER + offset


def head_frame():
	"""Repere de la tete : n = axe du museau, u = vers la gauche, v = vers le haut."""
	n = MUZZLE_AXIS
	u = Vector((1.0, 0.0, 0.0))
	u = (u - n * n.dot(u)).normalized()
	v = n.cross(u).normalized()

	return u, v, n


def build_head(b: Builder) -> None:
	face_cap = math.radians(FACE_CAP_DEG)
	muzzle_cap = math.radians(MUZZLE_CAP_DEG)

	def material(phi_mid: float) -> int:
		if phi_mid < muzzle_cap:
			return MAT_MUSEAU
		if phi_mid < face_cap:
			return MAT_VISAGE
		return MAT_FOURRURE

	def data(phi, theta):
		return {"shell": "tete", "phi": phi, "theta": theta, "w": {"tete": 1.0}}

	nose = b.vert(head_point(0.0, 0.0), data(0.0, 0.0))
	rings = []
	phis = [math.pi * j / float(HEAD_N_V + 1) for j in range(HEAD_N_V + 2)]

	for phi in phis[1:-1]:
		ring = []
		for i in range(HEAD_N_U):
			theta = math.tau * i / float(HEAD_N_U)
			ring.append(b.vert(head_point(phi, theta), data(phi, theta)))
		rings.append(ring)

	back = b.vert(head_point(math.pi, 0.0), data(math.pi, 0.0))

	for i in range(HEAD_N_U):
		nxt = (i + 1) % HEAD_N_U
		b.face((nose, rings[0][nxt], rings[0][i]), material(phis[1] * 0.5))
		b.face((back, rings[-1][i], rings[-1][nxt]), MAT_FOURRURE)

	for j, (lower, upper) in enumerate(zip(rings, rings[1:])):
		mat = material((phis[j + 1] + phis[j + 2]) * 0.5)
		for i in range(HEAD_N_U):
			nxt = (i + 1) % HEAD_N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), mat)


# ---------------------------------------------------------------- les oreilles

def build_ear(b: Builder, side: float) -> None:
	"""Un cone tres aplati, sa bande centrale en rose."""
	axis = Vector((EAR_AXIS.x * side, EAR_AXIS.y, EAR_AXIS.z)).normalized()
	normal = Vector((EAR_NORMAL.x * side, EAR_NORMAL.y, EAR_NORMAL.z))
	base = Vector((EAR_BASE.x * side, EAR_BASE.y, EAR_BASE.z))

	# Le repere de l'oreille : `n` regarde devant (la face rose), `u` traverse
	# le pavillon. Les deux sont redresses contre l'axe pour rester orthonormes.
	n = (normal - axis * normal.dot(axis)).normalized()
	u = axis.cross(n).normalized()

	bone = "oreille_L" if side < 0.0 else "oreille_R"
	pink = math.radians(EAR_PINK_DEG)

	def profile(s: float):
		w = EAR_W0 * (1.0 - s) ** EAR_TAPER_W
		h = EAR_H0 * (1.0 - s) ** EAR_TAPER_H

		# La pointe se ferme en quart de cercle : un cone finirait par un angle,
		# ce que §3 refuse — et la coque inversee transformerait cet angle en
		# tache d'encre.
		if s > 0.86:
			k = (s - 0.86) / 0.14
			round_off = math.sqrt(max(0.0, 1.0 - k * k))
			w *= round_off
			h *= round_off

		return w, h

	# La base plonge sous le crane (s negatif), la pointe est a s = 1.
	samples = [-0.14 + 1.14 * j / float(EAR_N_V) for j in range(EAR_N_V + 1)]
	rings = []

	for s in samples:
		w, h = profile(max(0.0, s))
		# Sous le crane la section garde sa taille de base : elle sert de
		# bouchon, pas de dessin.
		if s < 0.0:
			w, h = EAR_W0, EAR_H0

		center = base + axis * (EAR_LENGTH * s)
		ring = []

		for i in range(EAR_N_U):
			th = math.tau * i / float(EAR_N_U)
			ring.append(b.vert(
				center + u * (w * math.cos(th)) + n * (h * math.sin(th)),
				{"shell": "oreille", "s": s, "th": th, "side": side,
				 "w": {bone: 1.0}},
			))

		rings.append(ring)

	root = b.vert(base + axis * (EAR_LENGTH * samples[0]),
			{"shell": "oreille", "s": samples[0], "th": 0.0, "side": side,
			 "w": {bone: 1.0}})
	tip = b.vert(base + axis * EAR_LENGTH,
			{"shell": "oreille", "s": 1.0, "th": 0.0, "side": side,
			 "w": {bone: 1.0}})

	# La matiere se decide sur le MILIEU de la face, jamais sur la moyenne de
	# ses sommets : `th` boucle a 2*pi et une face a cheval sur la couture
	# rendrait pi au lieu de 0.
	def material(s_mid: float, th_mid: float) -> int:
		if s_mid <= 0.02 or s_mid >= EAR_PINK_S:
			return MAT_FOURRURE
		return MAT_ROSE if abs(th_mid - math.pi * 0.5) < pink else MAT_FOURRURE

	for j, (lower, upper) in enumerate(zip(rings, rings[1:])):
		s_mid = (samples[j] + samples[j + 1]) * 0.5
		for i in range(EAR_N_U):
			nxt = (i + 1) % EAR_N_U
			th_mid = math.tau * (i + 0.5) / float(EAR_N_U)
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]),
					material(s_mid, th_mid))

	for i in range(EAR_N_U):
		nxt = (i + 1) % EAR_N_U
		b.face((root, rings[0][nxt], rings[0][i]), MAT_FOURRURE)
		b.face((tip, rings[-1][i], rings[-1][nxt]), MAT_FOURRURE)


# ------------------------------------------------------------------ les pattes

def leg_geometry(spec: dict, side: float):
	"""(points, rayons) echantillonnes le long du chemin de la patte."""
	x = spec["x"] * side
	points = [Vector((x, y, z)) for y, z in spec["path"]]
	radii = spec["radius"]

	samples = [j / float(LEG_N_V) for j in range(LEG_N_V + 1)]
	fine = [poly_point(points, s) for s in samples]
	fine_r = [poly_scalar(radii, s) for s in samples]

	return samples, fine, fine_r


def build_leg(b: Builder, spec: dict, side: float, stations, shell: str) -> None:
	samples, points, radii = leg_geometry(spec, side)
	frames = transport(points)
	rings = []

	for j, s in enumerate(samples):
		u, v, _ = frames[j]
		r = radii[j]
		ring = []

		for i in range(LEG_N_U):
			th = math.tau * i / float(LEG_N_U)
			ring.append(b.vert(
				points[j] + u * (r * math.cos(th)) + v * (r * math.sin(th)),
				{"shell": shell, "s": s, "th": th, "side": side,
				 "w": mirror_weights(chain_weights(s, stations), side)},
			))

		rings.append(ring)

	top = b.vert(points[0], {"shell": shell, "s": 0.0, "th": 0.0, "side": side,
			"w": mirror_weights(chain_weights(0.0, stations), side)})
	toe = b.vert(points[-1], {"shell": shell, "s": 1.0, "th": 0.0, "side": side,
			"w": mirror_weights(chain_weights(1.0, stations), side)})

	b.tube(rings, MAT_FOURRURE, cap_lo=top, cap_hi=toe)


def build_sock(b: Builder, spec: dict, side: float, s0: float, stations,
		bone: str) -> None:
	"""Le chausson blanc : la meme surface que la patte, decollee de SOCK_GAP."""
	samples, points, radii = leg_geometry(spec, side)
	frames = transport(points)

	# Le chausson a sa propre grille : sa frontiere haute doit tomber ou on la
	# veut, pas sur la section la plus proche.
	sock_s = [s0 + (1.0 - s0) * j / float(SOCK_N_V) for j in range(SOCK_N_V + 1)]
	rings = []

	for s in sock_s:
		point = poly_point([Vector(p) for p in points], (s - samples[0])
				/ (samples[-1] - samples[0]))
		radius = poly_scalar(radii, s) + SOCK_GAP
		# Le repere se relit sur la grille de la patte, au plus proche : un
		# transport parallele recalcule sur une autre grille ne donnerait pas
		# exactement le meme roulis, et le chausson vrillerait sur la patte.
		j = min(range(len(samples)), key=lambda k: abs(samples[k] - s))
		u, v, _ = frames[j]
		ring = []

		for i in range(LEG_N_U):
			th = math.tau * i / float(LEG_N_U)
			ring.append(b.vert(
				point + u * (radius * math.cos(th)) + v * (radius * math.sin(th)),
				{"shell": "chausson", "s": s, "th": th, "side": side,
				 "w": mirror_weights(chain_weights(s, stations), side)},
			))

		rings.append(ring)

	cuff = b.vert(poly_point([Vector(p) for p in points], sock_s[0]),
			{"shell": "chausson", "s": sock_s[0], "th": 0.0, "side": side,
			 "w": mirror_weights(chain_weights(sock_s[0], stations), side)})
	toe = b.vert(poly_point([Vector(p) for p in points], 1.0),
			{"shell": "chausson", "s": 1.0, "th": 0.0, "side": side,
			 "w": {bone + ("_L" if side < 0.0 else "_R"): 1.0}})

	b.tube(rings, MAT_BLANC, cap_lo=cuff, cap_hi=toe)


# ------------------------------------------------------------------- la queue

def tail_geometry():
	points = [Vector(p) for p in TAIL_PATH]
	samples = [j / float(TAIL_N_V) for j in range(TAIL_N_V + 1)]
	fine = [poly_point(points, s) for s in samples]

	return samples, fine


def tail_radius(s: float) -> float:
	r = TAIL_R0 + (TAIL_R1 - TAIL_R0) * (s ** 0.7)

	if s > 0.90:
		k = (s - 0.90) / 0.10
		r *= math.sqrt(max(0.0, 1.0 - k * k))

	return r


TAIL_STATIONS = [(0.0, "queue_1"), (0.34, "queue_2"), (0.72, "queue_3")]


def build_tail(b: Builder) -> None:
	samples, points = tail_geometry()
	frames = transport(points)
	rings = []

	# ⚠️ La queue est la seule chaine a poids VRAIMENT degrades sur toute sa
	# longueur (plateau reduit) : c'est le seul suivi souple qu'autorise
	# "Convention Blender" §6.3, et c'est ce qui donne son overlap a l'idle.
	def data(s, th):
		return {"shell": "queue", "s": s, "th": th,
				"w": chain_weights(s, TAIL_STATIONS, band=0.95)}

	for j, s in enumerate(samples):
		u, v, _ = frames[j]
		r = tail_radius(s)
		ring = []

		for i in range(TAIL_N_U):
			th = math.tau * i / float(TAIL_N_U)
			ring.append(b.vert(
				points[j] + u * (r * math.cos(th)) + v * (r * math.sin(th)),
				data(s, th),
			))

		rings.append(ring)

	root = b.vert(points[0], data(0.0, 0.0))
	tip = b.vert(points[-1], data(1.0, 0.0))

	b.tube(rings, MAT_FOURRURE, cap_lo=root, cap_hi=tip)


def build_tail_tip(b: Builder) -> None:
	"""Le bout blanc — meme geste que les chaussons."""
	_, points = tail_geometry()
	base = [Vector(p) for p in points]
	frames = transport(base)

	tip_s = [TAIL_TIP_S + (1.0 - TAIL_TIP_S) * j / float(SOCK_N_V)
			 for j in range(SOCK_N_V + 1)]
	rings = []

	for s in tip_s:
		point = poly_point(base, s)
		radius = tail_radius(s) + SOCK_GAP
		j = min(range(len(base)), key=lambda k: abs(k / float(TAIL_N_V) - s))
		u, v, _ = frames[j]
		ring = []

		for i in range(TAIL_N_U):
			th = math.tau * i / float(TAIL_N_U)
			ring.append(b.vert(
				point + u * (radius * math.cos(th)) + v * (radius * math.sin(th)),
				{"shell": "bout_queue", "s": s, "th": th,
				 "w": chain_weights(s, TAIL_STATIONS, band=0.95)},
			))

		rings.append(ring)

	cuff = b.vert(poly_point(base, tip_s[0]),
			{"shell": "bout_queue", "s": tip_s[0], "th": 0.0,
			 "w": chain_weights(tip_s[0], TAIL_STATIONS, band=0.95)})
	end = b.vert(poly_point(base, 1.0),
			{"shell": "bout_queue", "s": 1.0, "th": 0.0, "w": {"queue_3": 1.0}})

	b.tube(rings, MAT_BLANC, cap_lo=cuff, cap_hi=end)


# ---------------------------------------------------------------- le plastron

def build_bib(b: Builder) -> None:
	"""Deux nappes collees a la surface du corps, cousues par leur bord."""
	def sheet(lift: float, flip: bool):
		rows = []
		for j in range(BIB_N_V + 1):
			k = j / float(BIB_N_V)
			t = BIB_T0 + (BIB_T1 - BIB_T0) * k
			half = math.radians(spline(BIB_WIDTH, k))
			row = []

			for i in range(BIB_N_U + 1):
				# `a` = pi au ventre ; on s'ecarte de +-half.
				a = math.pi + half * (2.0 * i / float(BIB_N_U) - 1.0)
				position = body_point(t, a) + body_normal(t, a) * lift
				row.append(b.vert(position, {
					"shell": "plastron", "t": t, "a": a, "k": k, "lift": lift,
					"w": chain_weights(spline(BODY_Y, t), SPINE_STATIONS),
				}))

			rows.append(row)

		for lower, upper in zip(rows, rows[1:]):
			for i in range(BIB_N_U):
				quad = (lower[i], lower[i + 1], upper[i + 1], upper[i])
				b.face(tuple(reversed(quad)) if flip else quad, MAT_BLANC)

		return rows

	front = sheet(BIB_LIFT, False)
	back = sheet(-BIB_SINK, True)

	# Le bord : une bande qui referme les deux nappes. C'est lui qui porte le
	# trait — sans lui la coque serait ouverte et n'aurait pas d'encre.
	border = []
	border += [(front[0][i], back[0][i]) for i in range(BIB_N_U + 1)]
	border += [(front[j][BIB_N_U], back[j][BIB_N_U]) for j in range(BIB_N_V + 1)]
	border += [(front[BIB_N_V][i], back[BIB_N_V][i]) for i in range(BIB_N_U, -1, -1)]
	border += [(front[j][0], back[j][0]) for j in range(BIB_N_V, -1, -1)]

	for (f0, k0), (f1, k1) in zip(border, border[1:]):
		if f0 == f1 or k0 == k1:
			continue
		b.face((f0, f1, k1, k0), MAT_BLANC)


# ------------------------------------------------------------------- assemblage

FRONT_STATIONS = [(0.00, "bras"), (0.55, "avantbras"), (0.86, "pattavant")]
HIND_STATIONS = [(0.00, "cuisse"), (0.36, "jambe"), (0.66, "tibia"), (0.86, "piedar")]


def build_mesh():
	b = Builder()

	build_body(b)
	build_head(b)
	build_ear(b, -1.0)
	build_ear(b, 1.0)

	for side in (-1.0, 1.0):
		build_leg(b, FRONT_LEG, side, FRONT_STATIONS, "patte_avant")
		build_sock(b, FRONT_LEG, side, SOCK_FRONT_S, FRONT_STATIONS, "pattavant")
		build_leg(b, HIND_LEG, side, HIND_STATIONS, "patte_arriere")
		build_sock(b, HIND_LEG, side, SOCK_HIND_S, HIND_STATIONS, "piedar")

	build_tail(b)
	build_tail_tip(b)
	build_bib(b)

	bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces)

	for face in b.bm.faces:
		face.smooth = True

	mesh = bpy.data.meshes.new(MESH_OBJECT)
	b.bm.to_mesh(mesh)
	b.bm.free()

	return mesh, b.info


# --------------------------------------------------------------- Attr_Style

def paint(mesh, info):
	"""Peint R, G et B. Contrat des canaux : "Convention Blender" §4.

	R = epaisseur du trait, G = biais d'ombre PEINTE, B = masque d'accent.
	Tout se decide sur la position PARAMETRIQUE et la normale, jamais sur
	l'eclairage : le chat tourne en permanence, et une forme peinte doit etre
	ancree a ce qui la porte.
	"""
	attr = mesh.color_attributes.get(ATTRIBUTE)

	if attr is None:
		attr = mesh.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="POINT")

	stats = {"r": [2.0, -1.0], "g": [2.0, -1.0], "b": [2.0, -1.0]}
	accent = 0

	for i, vertex in enumerate(mesh.vertices):
		data = info[i]
		shell = data["shell"]
		n = vertex.normal

		# ⛔ LE CANAL B RESTE A ZERO PARTOUT, ET C'EST UNE DECISION PRISE EN
		# CAPTURE. Deux accents ont ete peints puis jetes le 2026-08-20 — une
		# bande sur la ligne du dos, une calotte sur le crane — et les deux
		# sortaient en RECTANGLE GRIS PALE, exactement le mot que la souris
		# avait employe pour le sien ("une salissure sur un dos").
		#
		# La raison n'est pas le reglage, elle est structurelle et elle vaut
		# pour tout ce moule : le masque est peint PAR SOMMET puis seuille a
		# 0,55 dans le shader, donc sa frontiere ne peut jamais etre plus fine
		# qu'une face. Sur une grille de 24 meridiens, l'accent le plus petit
		# possible est un quad — un rectangle. Un eclat de brillance est rond.
		#
		# Et le calcul de §5.5 le condamne de toute facon : le pelage noir est a
		# 0,29 de valeur, `accent_strength` a 0,12 le porte a 0,37, soit un
		# TROISIEME ton de cluster sur un modele qui n'en admet que deux.
		#
		# Le premier chat en portait — c'est le grand aplat gris qu'on voit sur
		# son dos et son crane dans le tour de camera du 2026-08-16. Il n'y a
		# aucune raison de le reconduire.

		# La BASE part sous 1,0 partout : le canal est borne a 1, donc partir de
		# 1 revient a peindre un trait uniforme et a laisser la borne manger le
		# relief. Defaut silencieux — les statistiques affichent bien "1,00".
		r = 0.84 - 0.14 * max(0.0, n.z) + 0.10 * max(0.0, -n.z)
		g = 0.52 - 0.13 * max(0.0, -n.z) + 0.04 * max(0.0, n.z)
		b = 0.0

		if shell == "corps":
			t = data["t"]
			up = math.cos(data["a"])

			# LE CREUX DE LA NUQUE. C'est lui qui separe la tete du corps, et
			# c'est lui qui remplace le dos plus sombre du premier chat : le
			# trait s'y epaissit, l'ombre s'y creuse.
			neck = math.exp(-((t - 0.86) / 0.09) ** 2)
			r += 0.16 * neck
			g -= 0.12 * neck

			# L'OMBRE DU FLANC — une forme DESSINEE, pas un calcul (§2ter·2).
			# Elle prend le bas des flancs sur toute la longueur, franchement, et
			# c'est elle qui pose la bete au sol quand le contour ne suffit pas.
			g -= 0.13 * max(0.0, -up - 0.15) / 0.85

		elif shell == "tete":
			phi = data["phi"]

			# Le trait s'affine sur le visage : c'est la que se pose le dessin
			# (yeux, truffe, moustaches), et une encre trop grasse autour lui
			# mange sa place.
			r -= 0.10 * math.exp(-(phi / math.radians(60.0)) ** 2)

			# L'ombre sous la machoire — la tete se pose sur le poitrail.
			# `v` est l'axe "haut" du repere de la tete.
			#
			# ⚠️ ELLE A ETE REDUITE DE MOITIE ET REPOUSSEE VERS LE BAS le
			# 2026-08-20 : a 0,14 des 0,25 de plongee, elle mordait sur le BAS
			# DE LA BAVETTE, et le menton du chat sortait gris la ou la maquette
			# le veut blanc. Une ombre peinte doit border le blanc, pas l'avaler.
			_, v, _ = head_frame()
			down = -Vector(n).dot(v)
			g -= 0.08 * max(0.0, down - 0.45) / 0.55

		elif shell == "oreille":
			s = max(0.0, data["s"])
			th = data["th"]

			# Le trait s'epaissit sur la TRANCHE : c'est le bord qui porte la
			# silhouette de l'oreille, et une oreille mal cernee se confond avec
			# le crane des que la bete se tourne.
			r += 0.16 * abs(math.cos(th))
			# Et il s'epaissit encore vers la pointe, la ou l'oreille devient
			# plus mince que l'encre elle-meme.
			r += 0.10 * s

			# L'interieur d'une oreille est un CREUX : il est dans l'ombre quelle
			# que soit la lumiere. Encore une forme dessinee, pas un calcul.
			if abs(th - math.pi * 0.5) < math.radians(EAR_PINK_DEG):
				g -= 0.13

		elif shell in ("patte_avant", "patte_arriere"):
			s = data["s"]
			# Un membre est fin : son trait porte a lui seul la lecture.
			r = 0.90 + 0.06 * s
			# L'ombre de l'aine et du dessous de la patte.
			g = 0.50 - 0.12 * max(0.0, -n.z) - 0.06 * max(0.0, 1.0 - s * 3.0)

		elif shell == "chausson":
			r = 0.88
			g = 0.50 - 0.12 * max(0.0, -n.z)

		elif shell == "queue":
			# Une queue est fine : son trait porte a lui seul la lecture, et il
			# s'epaissit vers la pointe, la ou le tube devient plus mince que
			# l'encre elle-meme.
			r = 0.88 + 0.10 * data["s"]
			g = 0.50 - 0.10 * max(0.0, -n.z)

		elif shell == "bout_queue":
			# ⚠️ ET LA POINTE BLANCHE FAIT EXACTEMENT L'INVERSE. Elle a herite du
			# trait de la queue au premier jet (0,98, le plus gras du modele) et
			# elle sortait en ANNEAU : sous une queue portee droite, la camera
			# voit la pointe PAR LE BOUT, donc un disque de ~14 px cercle par
			# 2 x 5 px d'encre. Le blanc devenait le trou d'un beignet.
			#
			# C'est la meme regle que le plastron : une MARQUE n'a pas besoin du
			# trait d'une SILHOUETTE. 0,76 laisse un bord net et rend la pointe
			# a la tache blanche qu'elle doit etre.
			r = 0.76
			g = 0.50 - 0.10 * max(0.0, -n.z)

		elif shell == "plastron":
			# ⚠️ LE TRAIT DU PLASTRON EST LE PLUS FIN DU MODELE, et c'est mesure
			# a l'oeil sur le premier chat : une marque blanche cernee aussi fort
			# que la silhouette se lit comme un objet POSE sur le chat (un
			# bavoir), pas comme du pelage. Le trait doit dire "changement de
			# pelage", pas "changement d'objet".
			r = 0.72
			g = 0.52 - 0.14 * max(0.0, -n.z)
			# La nappe rentree ne se voit jamais : rien a peindre dessus.
			if data["lift"] < 0.0:
				r = 0.68

		# Le PLANCHER du canal R est de 0,68 PARTOUT. La regle vient du pixel :
		# sous ~0,68 de canal, le trait tombe sous 1 px au cadrage de jeu et ne
		# se lit plus comme un trait mais comme de la salete.
		r = min(1.0, max(0.68, r))
		g = min(0.58, max(0.30, g))
		b = min(1.0, max(0.0, b))

		if b > 0.55:
			accent += 1

		attr.data[i].color = (r, g, b, 1.0)

		for key, value in (("r", r), ("g", g), ("b", b)):
			stats[key][0] = min(stats[key][0], value)
			stats[key][1] = max(stats[key][1], value)

	# `active` designe l'attribut qu'edite l'outil de peinture, `default_color`
	# celui que l'exporteur glTF sort en `COLOR_0`. Les deux doivent pointer sur
	# Attr_Style, sinon l'export part sur un autre attribut — ou sur rien.
	mesh.color_attributes.active_color_name = ATTRIBUTE
	mesh.color_attributes.default_color_name = ATTRIBUTE

	stats["accent"] = accent
	return stats


# ---------------------------------------------------------------- materiaux

def toon_material(name, code):
	"""La chaine de "Convention Blender" §5.1, montee au node pres.

	Recopiee de `build_mouse.py` plutot que factorisee, pour les deux raisons
	deja notees la-bas : un script `--python` de Blender n'importe pas son voisin
	sans bricoler `sys.path`, et ces valeurs ne servent qu'au viewport Blender —
	Godot repose sa propre palette au chargement, dans `cel_model.gd`.
	"""
	material = bpy.data.materials.new(name)

	if material.node_tree is None:
		material.use_nodes = True

	tree = material.node_tree
	tree.nodes.clear()

	diffuse = tree.nodes.new("ShaderNodeBsdfDiffuse")
	diffuse.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
	diffuse.location = (-900, 0)

	to_rgb = tree.nodes.new("ShaderNodeShaderToRGB")
	to_rgb.location = (-700, 0)

	split_light = tree.nodes.new("ShaderNodeSeparateColor")
	split_light.location = (-520, 0)

	attribute = tree.nodes.new("ShaderNodeAttribute")
	attribute.attribute_type = "GEOMETRY"
	attribute.attribute_name = ATTRIBUTE
	attribute.location = (-900, -260)

	split_style = tree.nodes.new("ShaderNodeSeparateColor")
	split_style.location = (-700, -260)

	centre = tree.nodes.new("ShaderNodeMath")
	centre.operation = "SUBTRACT"
	centre.inputs[1].default_value = 0.5
	centre.location = (-520, -260)

	amplify = tree.nodes.new("ShaderNodeMath")
	amplify.operation = "MULTIPLY"
	amplify.inputs[1].default_value = 2.0
	amplify.location = (-340, -260)

	biased = tree.nodes.new("ShaderNodeMath")
	biased.operation = "ADD"
	biased.location = (-160, 0)

	ramp = tree.nodes.new("ShaderNodeValToRGB")
	ramp.location = (20, 0)
	# Le seul reglage qui separe un aplat cellulo d'un degrade 3D.
	ramp.color_ramp.interpolation = "CONSTANT"

	light = hex_to_linear(code)
	shadow = warm_shadow(light)
	elements = sorted(ramp.color_ramp.elements, key=lambda e: e.position)
	elements[0].position = 0.0
	elements[0].color = shadow + (1.0,)
	elements[1].position = RAMP_SPLIT
	elements[1].color = light + (1.0,)

	emission = tree.nodes.new("ShaderNodeEmission")
	emission.location = (340, 0)

	output = tree.nodes.new("ShaderNodeOutputMaterial")
	output.location = (520, 0)

	link = tree.links.new
	link(diffuse.outputs["BSDF"], to_rgb.inputs["Shader"])
	link(to_rgb.outputs["Color"], split_light.inputs["Color"])
	link(attribute.outputs["Color"], split_style.inputs["Color"])
	link(split_style.outputs["Green"], centre.inputs[0])
	link(centre.outputs["Value"], amplify.inputs[0])
	link(split_light.outputs["Red"], biased.inputs[0])
	link(amplify.outputs["Value"], biased.inputs[1])
	link(biased.outputs["Value"], ramp.inputs["Fac"])
	link(ramp.outputs["Color"], emission.inputs["Color"])
	link(emission.outputs["Emission"], output.inputs["Surface"])

	return material


# -------------------------------------------------------------------- le rig

def build_armature(collection):
	armature = bpy.data.armatures.new(ARMATURE_OBJECT)
	obj = bpy.data.objects.new(ARMATURE_OBJECT, armature)
	collection.objects.link(obj)

	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.mode_set(mode="EDIT")

	for name, parent, head, tail, x_axis in all_bones():
		bone = armature.edit_bones.new(name)
		bone.head = Vector(head)
		bone.tail = Vector(tail)
		bone.use_connect = False

		if parent is not None:
			bone.parent = armature.edit_bones[parent]

		# align_roll() aligne l'axe Z LOCAL sur le vecteur donne. On veut poser
		# l'axe X : dans un repere direct, Z = X x Y, et Y est l'axe de l'os.
		along = (bone.tail - bone.head).normalized()
		bone.align_roll(Vector(x_axis).cross(along))

	bpy.ops.object.mode_set(mode="OBJECT")

	# Tous les os en euler XYZ : `build_animations.py` ecrit dans
	# `rotation_euler`, et le defaut de Blender est le quaternion.
	for pose_bone in obj.pose.bones:
		pose_bone.rotation_mode = "XYZ"

	return obj


def skin(mesh_object, armature_object, info) -> dict:
	"""Groupes de sommets + modificateur Armature. Rend un rapport de controle."""
	groups = {}

	for name, _, _, _, _ in all_bones():
		groups[name] = mesh_object.vertex_groups.new(name=name)

	unknown = set()

	for index, data in enumerate(info):
		for bone, weight in data["w"].items():
			if bone not in groups:
				unknown.add(bone)
				continue
			if weight > 0.0:
				groups[bone].add([index], weight, "REPLACE")

	if unknown:
		sys.exit("ECHEC : poids sur des os inexistants : %s" % sorted(unknown))

	mesh_object.parent = armature_object
	modifier = mesh_object.modifiers.new("Armature", "ARMATURE")
	modifier.object = armature_object

	return {"unknown": unknown}


# --------------------------------------------------------------------- scene

def setup_scene():
	scene = bpy.context.scene

	for candidate in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
		try:
			scene.render.engine = candidate
			break
		except TypeError:
			continue

	# Le piege n°1 du toon shading : un tonemap filmique delave tous les aplats
	# et annule le travail de palette ("Convention Blender" §1).
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	# 60 fps : la cadence en pas se pose sur des multiples de 3 frames a 60.
	scene.render.fps = 60
	scene.unit_settings.scale_length = 1.0


def clear_scene():
	for obj in list(bpy.data.objects):
		bpy.data.objects.remove(obj, do_unlink=True)
	for mesh in list(bpy.data.meshes):
		bpy.data.meshes.remove(mesh, do_unlink=True)
	for armature in list(bpy.data.armatures):
		bpy.data.armatures.remove(armature, do_unlink=True)
	for material in list(bpy.data.materials):
		bpy.data.materials.remove(material, do_unlink=True)


# ------------------------------------------------------------------- rapport

def godot(vector) -> tuple:
	"""Blender (x, y, z) -> Godot Y-up (x, z, -y). La seule conversion du pont."""
	return (vector[0], vector[2], -vector[1])


def report(mesh, obj, info, stats) -> None:
	tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
	lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
	hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])

	counts = {}
	for polygon in mesh.polygons:
		counts[polygon.material_index] = counts.get(polygon.material_index, 0) + 1

	shells = {}
	for data in info:
		shells[data["shell"]] = shells.get(data["shell"], 0) + 1

	print("\n[build_cat_tuxedo] %s" % MESH_OBJECT)
	print("  %d sommets, %d faces, %d tris  (premier chat = 13 028)"
			% (len(mesh.vertices), len(mesh.polygons), tris))
	print("  emprise  X %.3f a %.3f   Y %.3f a %.3f   Z %.3f a %.3f"
			% (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
	print("  hauteur %.3f   longueur %.3f   largeur %.3f"
			% (hi.z - lo.z, hi.y - lo.y, hi.x - lo.x))
	print("  sommets par coque : %s" % shells)
	print("  faces par matiere : %s" % {
		MATERIALS[i][0]: counts.get(i, 0) for i in range(len(MATERIALS))})
	print("  Attr_Style  R %.2f-%.2f   G %.2f-%.2f   B %.2f-%.2f  (%d sommets d'accent)"
			% (stats["r"][0], stats["r"][1], stats["g"][0], stats["g"][1],
			   stats["b"][0], stats["b"][1], stats["accent"]))

	# ── Les deux lectures qui decident sous une plongee a 45° ────────────────
	head_top = HEAD_CENTER.z + HEAD_R.z
	croup = spline(BODY_Z, 0.22) + spline(BODY_R, 0.22)
	print("  dessus du crane %.3f  vs  croupe %.3f  (ecart %+.3f, doit rester > 0)"
			% (head_top, croup, head_top - croup))
	belly = spline(BODY_Z, 0.45) - spline(BODY_R, 0.45) * (1.0 - BODY_BELLY_FLAT)
	print("  garde au sol sous le ventre %.3f" % belly)

	# ── Le controle qui remplace le piege n°3 ───────────────────────────────
	# Les poids ne sont plus rigides partout ; ce qui doit l'etre, c'est ce que
	# `rest_undo` ancre. On le VERIFIE au lieu de l'affirmer.
	rigid_faces = {"visage": True, "museau_peint": True}
	names = [m[0] for m in MATERIALS]
	bad = []

	for polygon in mesh.polygons:
		name = names[polygon.material_index]
		if name not in rigid_faces:
			continue
		for vertex in polygon.vertices:
			w = info[vertex]["w"]
			if len(w) != 1 or "tete" not in w or abs(w["tete"] - 1.0) > 1e-6:
				bad.append((name, vertex))

	if bad:
		sys.exit("ECHEC : %d sommets de visage/museau ne sont pas a poids 1 sur "
				 "`tete` — rest_undo serait faux et le dessin glisserait." % len(bad))

	print("  visage + museau : 100 %% sur l'os `tete` (rest_undo exact)")

	# ── Les boites de griffes, mesurees et non estimees ──────────────────────
	# Ce que `tools/dump_paws.gd` relevait sur le .glb du premier chat. Le
	# construire ici evite l'aller-retour : les chiffres sortent de la source.
	print("\n  PAWS pour cel_model.gd (espace Godot, Y-up) :")
	for bone in ("pattavant_L", "pattavant_R", "piedar_L", "piedar_R"):
		selected = [i for i, data in enumerate(info)
				if data["shell"] == "chausson" and data["w"].get(bone, 0.0) > 0.999]
		if not selected:
			sys.exit("ECHEC : aucun sommet rigide pour '%s'" % bone)

		lo = Vector([min(mesh.vertices[i].co[k] for i in selected) for k in range(3)])
		hi = Vector([max(mesh.vertices[i].co[k] for i in selected) for k in range(3)])
		center = godot((lo + hi) * 0.5)
		radius = [abs(v) for v in godot((hi - lo) * 0.5)]
		print('    {"bone": "%s", "center": Vector3(%.3f, %.3f, %.3f), '
				'"radius": Vector3(%.3f, %.3f, %.3f)},'
				% (bone, center[0], center[1], center[2],
				   radius[0], radius[1], radius[2]))

	# ── Le repere du visage ─────────────────────────────────────────────────
	# `cel_face.gdshader` projette sur CET ellipsoide. Le premier chat s'en
	# remettait aux valeurs par defaut du shader — muet le jour ou le modele
	# change. Elles se posent desormais explicitement, depuis cette mesure.
	center = godot(HEAD_CENTER)
	radius = [abs(v) for v in godot(HEAD_R)]
	print("\n  repere facial pour cel_model.gd (espace Godot) :")
	print('    "face_center": Vector3(%.4f, %.4f, %.4f),' % center)
	print('    "face_radius": Vector3(%.4f, %.4f, %.4f),' % tuple(radius))

	nose = head_point(0.0, 0.0)
	print("    bout du museau %s  (monte de %.1f° sur l'horizontale)"
			% (tuple(round(v, 3) for v in nose),
			   math.degrees(math.asin(MUZZLE_AXIS.z))))


def main():
	clear_scene()
	setup_scene()

	mesh, info = build_mesh()

	for name, code in MATERIALS:
		mesh.materials.append(toon_material(name, code))

	stats = paint(mesh, info)

	obj = bpy.data.objects.new(MESH_OBJECT, mesh)
	collection = bpy.data.collections.new(COLLECTION)
	bpy.context.scene.collection.children.link(collection)
	collection.objects.link(obj)

	armature = build_armature(collection)
	skin(obj, armature, info)

	report(mesh, obj, info, stats)

	if "--save" in sys.argv:
		OUTPUT.parent.mkdir(parents=True, exist_ok=True)
		bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
		print("\n  ecrit dans %s" % OUTPUT)
	else:
		print("\n  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
