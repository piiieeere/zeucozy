"""Construit le CHIEN (la BRUTE), geometrie ET Attr_Style.

    "<blender>" --background --factory-startup \
        --python tools/build_dog.py -- --save

Meme moule que `build_couch.py`, `build_kibble.py`, `build_hairball.py` et
`build_mouse.py` — un .blend REGENERE, jamais edite a la main, parce que la
geometrie et sa peinture `Attr_Style` ont la meme source. Les separer rejouerait
le decalage que le chat a paye cher : une peinture calee sur une version du
maillage qui n'existe plus.

La chaine de materiau toon et les helpers de couleur sont RECOPIES de
`build_mouse.py` plutot que factorises, pour les deux raisons deja notees
la-bas (un script `--python` de Blender n'importe pas son voisin sans bricoler
`sys.path`, et ces valeurs ne servent qu'au viewport Blender — Godot repose sa
propre palette au chargement, dans `cel_prop.gd`).

CE QU'IL REMPLACE. La BRUTE — la sphere lavande `#BDB2FF` de
`scenes/enemies/brute.tscn`, l'ennemi costaud qui apparait a 22 s. C'etait le
DERNIER placeholder de primitive du gameplay, et accessoirement le modele le
plus lourd du jeu apres le chat : une `SphereMesh` de Godot sort a
`radial_segments = 64`, soit 4 224 tris pour une boule lisse.

DEUX ENTREES DE ROADMAP EN UNE, et c'est une decision, pas un raccourci. La
Todo listait separement "Chien" (ennemi thematique du pitch, §2 du Game
Manifest) et "la brute (sphere lavande)". Les fusionner evite un ennemi de plus
a equilibrer : la brute a deja ses chiffres (30 de degat au contact, 7 PV,
2,6 m/s), et un chien lent et costaud est exactement ce que ces chiffres
racontent. Le chien N'EST DONC PAS un ennemi de plus — c'est la brute qui cesse
d'etre une sphere.

FORME — "Compacte + oreilles" (§3), tranchee le 2026-08-19.
Le corps est un BALAYAGE, comme la souris : une section dont le rayon et la
hauteur suivent deux profils le long de l'axe crane/croupe. Ce qui le separe de
la souris n'est pas la technique, c'est le PROFIL — la souris est une goutte
lourde derriere ; le chien est lourd DEVANT (poitrail profond), pince a la
taille, et il a un COU, donc un creux de nuque deux fois plus marque.

Quatre coques s'y ajoutent, et chacune est un morceau de silhouette, pas un
detail :

  * le MUSEAU, une coque a part et non un effilement du corps. Un chien a un
    stop — le decrochement entre le front et le museau — et c'est lui qui separe
    un chien d'une souris vue de loin ;
  * les deux OREILLES TOMBANTES. C'est LA signature, et c'est ce qui les separe
    des disques dresses de la souris : elles se replient sur le crane puis
    pendent le long de la joue ;
  * les quatre PATTES. La souris n'en a pas et s'en passe (son ventre frole le
    sol) ; un chien a le ventre a 0,52 m, donc sans pattes il FLOTTE ;
  * la QUEUE, dans le plan du sol — voir le piege plus bas.

Tout est rond, aucun angle vif nulle part (§3).

⛔ NI LES YEUX NI LA TRUFFE NE SONT MODELISES, et la premiere version les avait
tous les deux en coques. §2bis est explicite — "les yeux sont PEINTS, jamais
modelises" — et la souris avait deja pris la meme entorse, en la justifiant de
la meme facon : une LENTILLE tangente ne deborde pas comme une sphere. C'etait
vrai de la lentille et faux de ce qu'on peint autour, sa coque d'encre ajoutant
0,036 dans toutes les directions contre 0,004 de debord reel.

Ils sont donc DESSINES par `shaders/cel_creature_face.gdshader`, dans un espace
facial projete, avec leurs reglages dans `FACES` de cel_prop.gd. Ce que ca rend :
la matiere sombre n'ayant plus aucune face, le modele tombe de 3 surfaces a 2 —
et le contour etant un `next_pass` PAR SURFACE, de 6 draw calls a 4.

⚠️ LA TETE RESTE PLUS HAUTE QUE LA CROUPE. Regle heritee de la souris, et de la
lecture en "cadenas" du chat a 60° (§11) : sous une plongee a 45°, une croupe
plus haute que le crane avale la tete et ce qui depasse. Le rapport imprime
l'ecart a chaque construction — c'est la seule mesure du fichier qui garde une
forme lisible.

⛔ LA QUEUE COURT DANS LE PLAN DU SOL, ET LA DA L'ANNONCAIT POUR CE MODELE-CI.
§3 de "Visual Art Direction", au sujet des deux queues verticales rendues et
jetees sur la souris : "UNE COURBE QUI MONTE NE SE VOIT PAS SOUS UNE CAMERA QUI
PLONGE (...) Vaut pour la trompe de l'aspirateur et la laisse du chien." Une
queue de chien enroulee sur le dos — le reflexe shiba — se projetterait DANS le
dos qui la porte et sortirait en poignee. Elle part donc en arriere, s'incurve
sur le cote et ne se releve qu'au bout.

COULEUR — "Brun/beige naturel" (§3), et les deux bornes sont mesurees.
`#8A5A38` est un chataigne : hue 25°, saturation 59 %, valeur 0,54. Trois
contraintes le tiennent, et aucune n'est un gout :

  * PAR LE HAUT, le parquet (0,91 a 0,96). Sous 0,10 d'ecart un objet ne se
    detache pas du sol — le mur que le projectile jaune pale a paye. Ici 0,39 ;
  * PAR LE BAS, le chat (0,29). Un ennemi de la valeur du personnage se perd
    dans la melee, le joueur triant a la valeur avant la forme (§15). Ici 0,25 ;
  * PAR LE MILIEU, LA SOURIS (0,66), et c'est la borne neuve. Les deux ennemis
    sont a l'ecran en meme temps et l'un tape le double de l'autre : ils doivent
    se distinguer AVANT d'etre identifies. 0,12 d'ecart de valeur, mais surtout
    59 % de saturation contre 21 % — la souris est un taupe delave, le chien un
    brun franc — et le double du gabarit.

⚠️ ET LE TRAIT RESTE `CelStyle.INK`, VERIFIE PLUTOT QUE SUPPOSE. Un trait doit
rester plus sombre que l'aplat qu'il cerne ET que son ton d'ombre. L'ombre du
chataigne tombe a 0,54 x 0,65 = 0,35 ; `#3D2B1A` est a 0,24. La marge (0,11) est
la plus mince du projet — le canape a 0,30, la souris 0,19 — mais elle est du
bon cote. C'est la ou le chat avait bascule (pelage a 0,29, ombre a 0,19, SOUS
l'encre) et avait du passer a `INK_SOMBRE` ; ici ce n'est pas necessaire, et le
rapport imprime les trois valeurs pour qu'on n'ait pas a s'en souvenir.

Les MARQUES `#C9A87C` sont le "beige" de §3 : museau, bouts de pattes, bout de
queue — le patron classique d'un chien, et les trois seuls endroits ou une zone
claire se lit sous une plongee a 45°. Elles sont a 0,79, soit 0,13 sous le
parquet (donc lisibles meme la ou elles touchent la silhouette, ce que le rose
de la souris ne pouvait pas) et 0,25 au-dessus du pelage (donc franches sans
couper l'objet en deux — la boule de poils a mesure qu'a 0,68 la trace devient
le sujet).

BUDGET GEOMETRIE — §11 : "Ennemis | a reduire nettement".
Vise ~1 850 tris, coque inversee non comprise. C'est plus que la souris (1 252)
et c'est assume : le chien est deux fois plus grand a l'ecran, il porte quatre
pattes qu'elle n'a pas, et il apparait a partir de 22 s au lieu de la premiere
seconde. Le compte a battre n'est de toute facon pas celui de la souris, c'est
celui du placeholder — 4 224 tris pour une sphere.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/enemy_chien_v1.blend")

COLLECTION = "enemy_chien"
MESH_OBJECT = "MSH_chien"
ATTRIBUTE = "Attr_Style"

# ---------------------------------------------------------------- dimensions

# Longueur du BALAYAGE seul, du pole avant du crane a la croupe. Le museau
# s'ajoute devant, la queue derriere.
#
# ⚠️ IL N'Y A PAS DE `SCALE` ICI, CONTRAIREMENT A LA SOURIS, et c'est deliberatif.
# Elle avait ete dessinee "en petit" puis remontee d'un facteur 1,20 pour tenir
# dans une hurtbox qui existait deja ; le facteur trainait ensuite dans tous les
# raisonnements. Le gabarit de la brute etant connu d'avance, tout est ecrit
# directement en unites de jeu — et le rapport imprime l'ecart au gabarit a
# chaque construction plutot que de le laisser dans un commentaire.
#
# LE GABARIT A TENIR (scenes/enemies/brute.tscn, inchange) : cylindre de
# collision r = 0,90 / h = 1,60, hurtbox et zone de degats spheriques r = 1,00
# centrees a y = 0,90. Comme pour la souris, C'EST LE MODELE QUI SE PLIE A LA
# HURTBOX, jamais l'inverse : baisser la hurtbox rendrait la brute plus dure a
# toucher, donc changerait l'equilibrage sous couvert de remplacer un
# placeholder. Un remplacement visuel ne doit rien deplacer d'autre.
LENGTH = 1.68

# Le rayon de la section, le long de l'axe. t = 0 au pole avant du crane
# (enfoui dans le museau), t = 1 a la croupe.
#
# ⚠️ LE MAXIMUM EST AU POITRAIL (t = 0,57), PAS A LA HANCHE. C'est l'inverse
# exact de la souris, et c'est ce qui separe les deux betes de dessus : une
# masse arriere donne un rongeur, une masse AVANT donne un chien. La taille se
# pince ensuite, la hanche remonte un peu.
RADIUS_KEYS = [
	(0.000, 0.000),  # pole avant du crane, un point
	(0.035, 0.155),
	(0.090, 0.300),
	(0.170, 0.388),
	# ⚠️ LE CRANE EST LA PLUS GROSSE MASSE DU MODELE, POITRAIL COMPRIS, et le
	# premier jet le mettait SOUS le poitrail (0,400 contre 0,420). De profil la
	# bete sortait alors en PAIN — un long dos regulier avec une tete au bout —
	# et §3 demande l'inverse : "tete legerement surdimensionnee". L'ecart est
	# mince (0,415 contre 0,392) et il suffit : c'est un rapport, pas une taille.
	(0.250, 0.415),
	# ⚠️ LE CREUX DE LA NUQUE EST DEUX FOIS PLUS PROFOND QUE SUR LA SOURIS —
	# 27,5 % contre 26 % annonces, mais surtout il est SUIVI d'un poitrail plus
	# large que le crane, ce que la souris n'a pas. Une souris n'a pas de cou et
	# le pincement ne sert qu'a poser la tete ; un chien en a un, et c'est ce
	# creux qui dit "quadrupede" avant meme que les pattes se voient.
	(0.340, 0.285),
	(0.440, 0.370),  # l'epaule
	(0.570, 0.392),  # le poitrail, le plus large du TRONC
	(0.720, 0.352),  # la taille
	(0.860, 0.345),  # la hanche
	# La croupe se ferme en ROND, pas en cone — la lecon de la souris : a une
	# seule cle le rayon tombait trop vite et sortait en FACETTE PLATE sur la
	# silhouette de flanc, la ou §3 ne veut aucun angle.
	(0.940, 0.245),
	(0.978, 0.120),
	(1.000, 0.000),  # la croupe, un point
]

# La hauteur du CENTRE de la section. C'est ce profil-la qui tient le crane
# au-dessus de la hanche — voir l'en-tete.
#
# ⚠️ LE TRONC A ETE REMONTE DE 0,10 APRES CAPTURE, ET CE N'ETAIT PAS UN PROBLEME
# DE PATTES. Au premier jet le ventre tombait a 0,40 pour un pied a 0,045 : les
# quatre membres existaient, mais il n'en emergeait que 0,12 sous la masse du
# corps et ils sortaient en MOIGNONS — de profil la bete se lisait comme un pain
# pose au sol. Allonger les pattes n'y pouvait rien, c'est le VENTRE qui les
# mangeait. Remonte, le ventre est a 0,52 et il emerge 0,48 de patte, soit un
# tiers de la hauteur — la proportion d'un chien trapu.
HEIGHT_KEYS = [
	(0.000, 0.955),
	(0.035, 0.962),
	(0.090, 0.978),
	(0.170, 0.996),
	(0.250, 1.005),
	(0.340, 0.950),
	(0.440, 0.892),
	(0.570, 0.860),
	(0.720, 0.850),
	(0.860, 0.855),
	(0.940, 0.848),
	(0.978, 0.840),
	(1.000, 0.835),
]

# Section presque circulaire : un chien est aussi profond que large au
# poitrail. La souris etait ecrasee a 0,92 pour se poser au sol — ici ce sont
# les pattes qui la posent.
Z_SQUASH = 0.98

# Aplatissement du ventre. Multiplicateur DOUX (pas de troncature) : §3
# n'admet aucun angle.
BELLY_FLAT = 0.12

# Les sections, en t. NON UNIFORMES, resserrees a l'avant : c'est la que le
# profil tourne vite (crane, nuque, epaule). ⚠️ UNE CLE TOMBE EXACTEMENT SUR LE
# CREUX DE NUQUE (0,340). Sans elle, la spline serait echantillonnee de part et
# d'autre du minimum et le pincement — la seule chose qui dit "cou" — sortirait
# de moitie.
SECTIONS = [0.035, 0.10, 0.17, 0.25, 0.34, 0.43, 0.52, 0.62, 0.72, 0.81, 0.89, 0.945, 0.978]
N_U = 20

# ─── LE MUSEAU ────────────────────────────────────────────────────────────────
#
# Une COQUE A PART, et non un effilement du balayage comme le museau de la
# souris. Deux raisons, et la seconde est la vraie :
#
#   * un chien a un STOP — le decrochement entre le front et le chanfrein. Un
#     balayage continu ne sait pas le produire : il rendrait un cone, donc un
#     museau de rongeur ;
#   * l'intersection des deux coques produit un trait parasite (piege n°2), et
#     ICI ON LE VEUT. C'est exactement la ligne qu'un dessin met a cet endroit.
#
# Il est ENTIEREMENT en `marques`. Le premier reflexe — pelage sur le chanfrein,
# beige sous la machoire — mettait le clair la ou la camera ne regarde pas : a
# 45° on voit le DESSUS du museau. Une marque invisible ne compte pas (§15, la
# lecon des griffes du chat, qui pesent 5 px et vivent au banc).
MUZZLE_Y0 = 0.60    # la racine, ENFOUIE dans le crane
MUZZLE_Y1 = 1.16
MUZZLE_Z0 = 0.925
MUZZLE_Z1 = 0.880   # le chanfrein plonge legerement
# Aplatissement vertical : un museau est plus large que haut. Il reste doux —
# a 0,80 le dessus se facettait sous la coque inversee.
MUZZLE_SQUASH = 0.90
MUZZLE_N_U = 16
# ⚠️ LE RAYON DE RACINE EST BORNE PAR LE CRANE, PAS PAR LE DESSIN. A 0,30 la
# couronne de racine ressortait de 0,006 hors de la sphere du crane et laissait
# voir un anneau de couture — le meme defaut que les coussins du canape qui
# depassaient de 0,014 par l'arriere du dossier. Verifie : a 0,255 le point le
# plus expose de la racine est a 0,58 du bord (en coordonnees normalisees de la
# section du crane), donc franchement dedans.
#
# ⚠️ ET SON PROFIL DOIT S'EFFILER FRANCHEMENT. Le premier jet allait de 0,255 a
# 0,212 sur la partie emergee — 17 % de perte —, donc un TUBE : de profil le
# museau sortait en bouchon de liege plante dans la tete, avec un bord droit et
# un bout plat. Un museau est un CONE arrondi ; il perd desormais 44 % sur la
# meme longueur, et sa calotte se ferme des 0,80 au lieu de 0,86.
MUZZLE_RADIUS_KEYS = [
	(0.00, 0.270),
	(0.30, 0.240),
	(0.60, 0.203),
	(0.82, 0.170),
	(1.00, 0.115),
]
MUZZLE_CAP_START = 0.80

# ─── LES OREILLES ─────────────────────────────────────────────────────────────
#
# TOMBANTES, et c'est tout le sujet. Les oreilles de la souris sont deux disques
# DRESSES sur le dessus du crane ; celles-ci se replient sur le crane puis
# pendent le long de la joue. Deux betes brunes de meme famille de forme ne se
# distinguent que par la, sous une plongee, a 40 px de tete.
#
# ⚠️ UN VOLET VERTICAL SE VOIT PAR LA TRANCHE SOUS UNE CAMERA QUI PLONGE — c'est
# la lecon des oreilles de la souris, et elle condamne l'oreille tombante naive.
# La parade n'est pas de l'incliner en bloc (elle cesserait de tomber), c'est de
# faire TOURNER SON PLAN le long de sa longueur : a la racine la face regarde le
# CIEL (l'oreille est repliee a plat sur le crane, ce que fait une vraie oreille
# tombante), au bout elle regarde DEHORS. La camera voit donc la face large a la
# racine et la tranche au bout, exactement comme un dessin le montre.
EAR_T = 0.275
EAR_SIDE_DEG = 52.0
# De combien la racine s'enfonce dans le crane. Sans elle, la couronne de racine
# se pose SUR la surface et on voit l'anneau de couture.
EAR_SINK = 0.07
# Le trajet, en offsets depuis le point d'accroche. Il part DEHORS (le repli sur
# le crane) puis BAS (la pente le long de la joue).
EAR_PATH = [
	(0.000, 0.020, 0.020),
	(0.100, -0.020, -0.020),
	(0.190, -0.060, -0.140),
	(0.245, -0.100, -0.300),
	(0.255, -0.145, -0.470),
]
# La direction de l'EPAISSEUR — donc celle que la face large regarde — a la
# racine et au bout. Voir le paragraphe ci-dessus : c'est la rotation entre les
# deux qui fait exister l'oreille sous la plongee.
EAR_FACE_BASE = (0.18, 0.10, 0.98)
EAR_FACE_TIP = (0.95, 0.05, 0.30)
# Largeur (fore-aft) et epaisseur, le long du trajet. La goutte s'evase au tiers
# puis s'arrondit : une bande de largeur constante sortirait en lanière.
EAR_WIDTH_KEYS = [(0.00, 0.090), (0.20, 0.158), (0.45, 0.210), (0.72, 0.194),
		(0.90, 0.136), (1.00, 0.062)]
EAR_THICK_KEYS = [(0.00, 0.050), (0.35, 0.058), (0.75, 0.046), (1.00, 0.024)]
EAR_N_U = 12
EAR_N_V = 6

# ─── LES PATTES ───────────────────────────────────────────────────────────────
#
# ⚠️ ELLES NE SONT PAS UN DETAIL D'ANATOMIE, ELLES SONT CE QUI POSE LA BETE. La
# souris s'en passe parce que son ventre frole le sol ; le ventre du chien est a
# 0,40 m, et sans pattes il FLOTTE — le defaut que les ombres de contact ont ete
# ajoutees pour eviter, en pire, puisqu'ici il y a un vide a combler.
#
# ⚠️ ET LEUR RAYON EST BORNE PAR L'ENCRE, comme la queue de la souris. La coque
# inversee fait 0,036 en unites monde et deborde de chaque cote : un membre de
# rayon r sort a l'ecran en r + 0,036, dont le coeur ne fait que r / (r + 0,036).
# A 0,135 il en reste 79 % — la patte se lit comme un objet cerne. En dessous de
# ~0,09 elle passerait en encre pleine et le trait cesserait d'etre un trait
# pour devenir l'objet.
#
# Courtes et epaisses : 0,47 de long pour 0,30 de large. §3 demande "compacte",
# et un chien trapu se lit mieux de dessus qu'un chien haut sur pattes, dont les
# membres disparaissent sous le corps.
LEG_FRONT_T = 0.44
LEG_REAR_T = 0.86
LEG_SIDE_RAD = 0.62   # ecart angulaire depuis le ventre
LEG_SINK = 0.10       # de combien le haut de la patte s'enfonce dans le corps
LEG_SPLAY = 0.075     # derive vers l'exterieur, du haut au pied
LEG_REAR_LEAN = -0.05  # les posterieurs partent legerement en arriere
# ⚠️ LE PIED S'ARRETE A 0,045 ET NON A ZERO. Pose a plat, il se ferait TRANCHER
# SON ENCRE par le plan du parquet — la coque inversee descend sous le maillage,
# le sol se peint par-dessus, et il reste un lisere parchemin entre l'aplat et le
# trait (mesure sur la croquette posee au banc). A 0,045 la coque s'arrete a
# 0,009 au-dessus du sol : rien n'est tranche, et 0,045 m fait 2 px au cadrage de
# jeu — l'ombre de contact couvre le reste.
LEG_FOOT_Z = 0.045
LEG_RADIUS_KEYS = [(0.00, 0.190), (0.30, 0.148), (0.70, 0.138), (0.88, 0.155),
		(1.00, 0.130)]
# La fraction basse en `marques` — les bouts de pattes clairs. Frontiere sur un
# ANNEAU, donc franche : c'est le cas propre releve sur les meches de la boule de
# poils (une bande qui suit les colonnes se lit comme un trait peint, une
# calotte posee sur une grille grossiere sort en escalier).
LEG_PAW_K = 0.72
LEG_N_U = 9
LEG_N_V = 5

# ─── LA QUEUE ─────────────────────────────────────────────────────────────────
#
# Dans le PLAN DU SOL — voir l'en-tete, la DA l'ecrit noir sur blanc pour ce
# modele. Elle part de la croupe, s'incurve sur un cote et ne se releve qu'au
# bout : un dernier mouvement, ce que §3 appelle "l'ame" d'un objet.
#
# Le premier point est DANS la croupe, pas dessus : la coque doit s'y enfoncer,
# sinon on voit le joint.
#
# Elle court a ~0,78 de haut et non a ras de terre, contrairement a celle de la
# souris (0,25) : la croupe du chien est plus haute, et une queue qui partirait
# du sol se lirait comme une cinquieme patte.
#
# ⛔ ET ELLE SORTAIT EN CINQUIEME PATTE, ce qu'aucun raisonnement n'annoncait.
# A 0,77 de haut elle finissait dans la meme bande d'altitude que les membres,
# a la meme distance de l'axe, avec un BOUT CLAIR au bout — soit exactement la
# signature d'une patte et de son pied. De dos, la bete en avait cinq. Deux
# corrections ensemble, parce qu'aucune ne suffisait seule : elle court 0,15
# plus haut (au-dessus de la bande des pattes) et elle s'ecarte de moitie en
# plus sur le cote (0,54 au lieu de 0,50, mais surtout plus tot). Garder le bout
# clair : de profil c'est lui qui donne sa longueur a la queue.
TAIL_PATH = [
	(0.000, -0.720, 0.880),
	(0.070, -1.020, 0.930),
	(0.210, -1.270, 0.940),
	(0.380, -1.430, 0.975),
	(0.540, -1.480, 1.060),
]
TAIL_R0 = 0.115
TAIL_R1 = 0.062
# ⚠️ EXPONENT < 1 : l'amincissement est PRECOCE. En lineaire, la queue de la
# souris restait grasse sur toute sa partie visible et sortait en MOIGNON. Ce
# qui fait lire "queue" est la finesse au DEPART de l'arc, pas au bout.
TAIL_TAPER_POW = 0.60
# Le bout clair, en fraction du trajet. Meme frontiere en anneau que les pieds.
TAIL_TIP_K = 0.78
TAIL_N_U = 9
TAIL_N_V = 8

# ─── LES TROIS MATIERES ───────────────────────────────────────────────────────
PELAGE = "#8A5A38"
MARQUES = "#C9A87C"

# Les valeurs contre lesquelles le pelage se juge — imprimees par le rapport
# plutot que laissees dans un commentaire, parce que c'est la seule facon de
# s'apercevoir qu'une retouche de couleur a franchi une borne.
REFERENCES = [
	("parquet clair", "#F5ECD8"),
	("parquet fonce", "#E8D4A8"),
	("souris", "#A89684"),
	("chat", "#4A4038"),
	("encre", "#3D2B1A"),
]

# Memes reglages que les uniforms de cel_toon.gdshader : le ton d'ombre de
# Blender est celui de Godot, et non un second reglage a la main.
SHADOW_HUE_SHIFT = -0.02
SHADOW_SATURATION = 1.15
SHADOW_VALUE = 0.65

RAMP_SPLIT = 0.52

MAT_PELAGE, MAT_MARQUES = 0, 1

# Le gabarit de collision de brute.tscn, repris ici pour que le rapport puisse
# dire si le modele y tient. JAMAIS pour le modifier — voir `LENGTH`.
HURTBOX_RADIUS = 1.00
HURTBOX_CENTER_Z = 0.90
BODY_CYLINDER_RADIUS = 0.90
BODY_CYLINDER_HEIGHT = 1.60


# ------------------------------------------------------------------- couleurs

def srgb_to_linear(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return ((value + 0.055) / 1.055) ** 2.4


def hex_to_linear(code: str) -> tuple:
	code = code.lstrip("#")
	return tuple(srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def hex_value(code: str) -> float:
	"""La VALEUR au sens TSV, en sRGB — celle sur laquelle se lit un contraste."""
	code = code.lstrip("#")
	return max(int(code[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def hex_saturation(code: str) -> float:
	code = code.lstrip("#")
	channels = [int(code[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
	high = max(channels)

	if high <= 0.0:
		return 0.0

	return (high - min(channels)) / high


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


# -------------------------------------------------------------------- profils

def spline(keys, t: float) -> float:
	"""Catmull-Rom NON UNIFORME sur une liste de (t, valeur).

	Non uniforme parce que les cles ne sont pas equidistantes : elles sont posees
	la ou la forme tourne (crane, nuque, poitrail). Un Catmull-Rom uniforme lu
	sur des cles serrees produit des tangentes trop fortes, donc un ventre bombe
	entre deux cles rapprochees.
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


def path_point(path, s: float) -> Vector:
	"""Catmull-Rom sur une liste de triplets, parametree par s dans [0, 1]."""
	n = len(path) - 1.0
	return Vector([
		spline([(i / n, p[k]) for i, p in enumerate(path)], s)
		for k in range(3)
	])


def body_point(t: float, a: float) -> Vector:
	"""Un point du corps. `a` = 0 sur le dos, +-pi/2 sur les flancs, pi au ventre."""
	r = max(0.0, spline(RADIUS_KEYS, t))
	cz = spline(HEIGHT_KEYS, t)
	up = math.cos(a)
	flat = 1.0 - BELLY_FLAT * max(0.0, -up)

	return Vector((
		r * math.sin(a),
		LENGTH * (0.5 - t),
		cz + r * up * Z_SQUASH * flat,
	))


def body_normal(t: float, a: float) -> Vector:
	"""La normale, prise en differences finies sur la PARAMETRISATION.

	Et non sur le maillage : les oreilles, les yeux et les pattes se posent avant
	que le maillage existe, et une normale relue apres coup dependrait de la
	densite des sections — donc changerait de reponse si on retouchait
	`SECTIONS`.
	"""
	e = 1.0e-3
	dt = body_point(min(1.0, t + e), a) - body_point(max(0.0, t - e), a)
	da = body_point(t, a + e) - body_point(t, a - e)
	n = da.cross(dt)

	if n.length < 1.0e-9:
		return Vector((0.0, 0.0, 1.0))

	n.normalize()
	axis = Vector((0.0, LENGTH * (0.5 - t), spline(HEIGHT_KEYS, t)))

	if n.dot(body_point(t, a) - axis) < 0.0:
		n = -n

	return n


def frame(axis: Vector):
	"""Un repere orthonorme dont le 3e vecteur est `axis`, le 1er tire vers le haut."""
	n = axis.normalized()
	up = Vector((0.0, 0.0, 1.0))

	if abs(n.dot(up)) > 0.97:
		up = Vector((0.0, 1.0, 0.0))

	u = (up - n * n.dot(up)).normalized()
	v = n.cross(u)

	return u, v, n


def parallel_frames(points):
	"""Repere a TRANSPORT PARALLELE le long d'une polyligne.

	Jamais un repere de Frenet : il se retourne des que la courbure s'annule, et
	la queue comme les pattes ont un point d'inflexion. Le tube se vrillerait
	d'un demi-tour sur une section — invisible sur un tube rond, mais ca tord la
	peinture qu'on y pose et la frontiere des `marques` avec elle.
	"""
	tangents = []

	for j in range(len(points)):
		lo = points[max(0, j - 1)]
		hi = points[min(len(points) - 1, j + 1)]
		tangents.append((hi - lo).normalized())

	ref = Vector((1.0, 0.0, 0.0))

	if abs(ref.dot(tangents[0])) > 0.9:
		ref = Vector((0.0, 0.0, 1.0))

	ref = (ref - tangents[0] * ref.dot(tangents[0])).normalized()
	frames = []

	for j, tangent in enumerate(tangents):
		if j > 0:
			ref = (ref - tangent * ref.dot(tangent)).normalized()
		frames.append((ref.copy(), tangent.cross(ref).normalized(), tangent.copy()))

	return frames


def round_cap(k: float, start: float) -> float:
	"""Facteur de fermeture ARRONDIE sur la fin d'un tube.

	Un quart de cercle sur les derniers pourcents, donc une pointe arrondie. Un
	cone se terminerait par un angle, ce que §3 refuse.
	"""
	if k <= start:
		return 1.0

	x = (k - start) / (1.0 - start)
	return math.sqrt(max(0.0, 1.0 - x * x))


# ------------------------------------------------------------------ geometrie

class Builder:
	"""Un bmesh + la liste parallele des infos de peinture.

	L'ordre d'ajout des sommets est celui du maillage final (bmesh le conserve),
	exactement comme le `coords` de `build_kibble.py`. `info` porte la coque et
	ce qu'il faut pour peindre — jamais une position monde, qui deviendrait
	fausse le jour ou on recentrerait le maillage.
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


def build_body(b: Builder) -> None:
	front = b.vert(body_point(0.0, 0.0), {"shell": "corps", "t": 0.0, "a": 0.0})
	rings = []

	for t in SECTIONS:
		ring = []

		for i in range(N_U):
			a = math.tau * i / float(N_U)
			ring.append(b.vert(body_point(t, a), {"shell": "corps", "t": t, "a": a}))

		rings.append(ring)

	rump = b.vert(body_point(1.0, 0.0), {"shell": "corps", "t": 1.0, "a": 0.0})

	for i in range(N_U):
		nxt = (i + 1) % N_U
		b.face((front, rings[0][nxt], rings[0][i]), MAT_PELAGE)
		b.face((rump, rings[-1][i], rings[-1][nxt]), MAT_PELAGE)

	for lower, upper in zip(rings, rings[1:]):
		for i in range(N_U):
			nxt = (i + 1) % N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), MAT_PELAGE)


def build_muzzle(b: Builder) -> None:
	"""Un tube droit aplati, enfoui dans le crane, ferme en rond au bout."""
	start = Vector((0.0, MUZZLE_Y0, MUZZLE_Z0))
	end = Vector((0.0, MUZZLE_Y1, MUZZLE_Z1))
	axis = (end - start).normalized()
	u, v, _ = frame(axis)

	# `u` est horizontal par construction (frame tire le 1er vecteur vers le
	# haut puis prend le produit vectoriel) : c'est donc `v` qui porte
	# l'aplatissement vertical.
	samples = [j / 5.0 for j in range(1, 6)]
	rings = []

	for s in samples:
		r = spline(MUZZLE_RADIUS_KEYS, s) * round_cap(s, MUZZLE_CAP_START)
		ring = []

		for i in range(MUZZLE_N_U):
			th = math.tau * i / float(MUZZLE_N_U)
			ring.append(b.vert(
				start + axis * ((end - start).length * s)
				+ u * (r * math.cos(th))
				+ v * (r * MUZZLE_SQUASH * math.sin(th)),
				{"shell": "museau", "s": s, "th": th},
			))

		rings.append(ring)

	root = b.vert(start, {"shell": "museau", "s": 0.0, "th": 0.0})
	tip = b.vert(end, {"shell": "museau", "s": 1.0, "th": 0.0})

	for i in range(MUZZLE_N_U):
		nxt = (i + 1) % MUZZLE_N_U
		b.face((root, rings[0][nxt], rings[0][i]), MAT_MARQUES)
		b.face((tip, rings[-1][i], rings[-1][nxt]), MAT_MARQUES)

	for lower, upper in zip(rings, rings[1:]):
		for i in range(MUZZLE_N_U):
			nxt = (i + 1) % MUZZLE_N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), MAT_MARQUES)


def build_ear(b: Builder, side: float) -> None:
	"""Un volet tombant dont le PLAN TOURNE le long de sa longueur.

	Voir le bloc EAR_* : c'est cette rotation, et rien d'autre, qui fait qu'une
	oreille tombante existe encore sous une camera a 45°.
	"""
	a = math.radians(EAR_SIDE_DEG) * side
	anchor = body_point(EAR_T, a) - body_normal(EAR_T, a) * EAR_SINK

	samples = [j / float(EAR_N_V) for j in range(EAR_N_V + 1)]
	points = []

	for s in samples:
		offset = path_point(EAR_PATH, s)
		points.append(anchor + Vector((offset.x * side, offset.y, offset.z)))

	tangents = []

	for j in range(len(points)):
		lo = points[max(0, j - 1)]
		hi = points[min(len(points) - 1, j + 1)]
		tangents.append((hi - lo).normalized())

	rings = []

	for j, s in enumerate(samples):
		face_dir = Vector((
			EAR_FACE_BASE[0] + (EAR_FACE_TIP[0] - EAR_FACE_BASE[0]) * s,
			EAR_FACE_BASE[1] + (EAR_FACE_TIP[1] - EAR_FACE_BASE[1]) * s,
			EAR_FACE_BASE[2] + (EAR_FACE_TIP[2] - EAR_FACE_BASE[2]) * s,
		))
		face_dir.x *= side

		tangent = tangents[j]
		n = (face_dir - tangent * face_dir.dot(tangent)).normalized()
		u = tangent.cross(n).normalized()

		w = spline(EAR_WIDTH_KEYS, s)
		h = spline(EAR_THICK_KEYS, s)
		ring = []

		for i in range(EAR_N_U):
			th = math.tau * i / float(EAR_N_U)
			ring.append(b.vert(
				points[j] + u * (w * math.cos(th)) + n * (h * math.sin(th)),
				{"shell": "oreille", "s": s, "edge": abs(math.cos(th))},
			))

		rings.append(ring)

	root = b.vert(points[0], {"shell": "oreille", "s": 0.0, "edge": 0.0})
	tip = b.vert(points[-1], {"shell": "oreille", "s": 1.0, "edge": 0.0})

	for i in range(EAR_N_U):
		nxt = (i + 1) % EAR_N_U
		b.face((root, rings[0][nxt], rings[0][i]), MAT_PELAGE)
		b.face((tip, rings[-1][i], rings[-1][nxt]), MAT_PELAGE)

	for lower, upper in zip(rings, rings[1:]):
		for i in range(EAR_N_U):
			nxt = (i + 1) % EAR_N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), MAT_PELAGE)


def build_leg(b: Builder, side: float, t: float, lean: float) -> None:
	"""Un membre court et epais, enfonce dans le ventre, ferme en pied arrondi."""
	a = math.pi - LEG_SIDE_RAD * side
	anchor = body_point(t, a)
	top = anchor.z + LEG_SINK
	span = top - LEG_FOOT_Z

	samples = [j / float(LEG_N_V) for j in range(LEG_N_V + 1)]
	points = []

	for k in samples:
		points.append(Vector((
			anchor.x + LEG_SPLAY * k * side,
			anchor.y + lean * k,
			top - span * k,
		)))

	frames = parallel_frames(points)
	rings = []

	for j, k in enumerate(samples):
		u, v, _ = frames[j]
		r = spline(LEG_RADIUS_KEYS, k) * round_cap(k, 0.88)
		ring = []

		for i in range(LEG_N_U):
			th = math.tau * i / float(LEG_N_U)
			ring.append(b.vert(
				points[j] + u * (r * math.cos(th)) + v * (r * math.sin(th)),
				{"shell": "patte", "k": k, "side": side},
			))

		rings.append(ring)

	root = b.vert(points[0], {"shell": "patte", "k": 0.0, "side": side})
	foot = b.vert(points[-1], {"shell": "patte", "k": 1.0, "side": side})

	def mat(k_mid: float) -> int:
		return MAT_MARQUES if k_mid > LEG_PAW_K else MAT_PELAGE

	for i in range(LEG_N_U):
		nxt = (i + 1) % LEG_N_U
		b.face((root, rings[0][nxt], rings[0][i]), MAT_PELAGE)
		b.face((foot, rings[-1][i], rings[-1][nxt]), MAT_MARQUES)

	for j, (lower, upper) in enumerate(zip(rings, rings[1:])):
		k_mid = (samples[j] + samples[j + 1]) * 0.5

		for i in range(LEG_N_U):
			nxt = (i + 1) % LEG_N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), mat(k_mid))


def build_tail(b: Builder) -> None:
	samples = [j / float(TAIL_N_V) for j in range(TAIL_N_V + 1)]
	points = [path_point(TAIL_PATH, s) for s in samples]
	frames = parallel_frames(points)
	rings = []

	for j, s in enumerate(samples):
		u, v, _ = frames[j]
		r = (TAIL_R0 + (TAIL_R1 - TAIL_R0) * (s ** TAIL_TAPER_POW)) * round_cap(s, 0.88)
		ring = []

		for i in range(TAIL_N_U):
			th = math.tau * i / float(TAIL_N_U)
			ring.append(b.vert(
				points[j] + u * (r * math.cos(th)) + v * (r * math.sin(th)),
				{"shell": "queue", "s": s},
			))

		rings.append(ring)

	# La base est ENFOUIE dans la croupe : on la ferme quand meme, une coque
	# ouverte laisserait voir son interieur des que la coque inversee passe.
	root = b.vert(points[0], {"shell": "queue", "s": 0.0})
	tip = b.vert(points[-1], {"shell": "queue", "s": 1.0})

	def mat(s_mid: float) -> int:
		return MAT_MARQUES if s_mid > TAIL_TIP_K else MAT_PELAGE

	for i in range(TAIL_N_U):
		nxt = (i + 1) % TAIL_N_U
		b.face((root, rings[0][nxt], rings[0][i]), MAT_PELAGE)
		b.face((tip, rings[-1][i], rings[-1][nxt]), MAT_MARQUES)

	for j, (lower, upper) in enumerate(zip(rings, rings[1:])):
		s_mid = (samples[j] + samples[j + 1]) * 0.5

		for i in range(TAIL_N_U):
			nxt = (i + 1) % TAIL_N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), mat(s_mid))


def build_mesh():
	b = Builder()

	build_body(b)
	build_muzzle(b)
	build_ear(b, 1.0)
	build_ear(b, -1.0)
	build_leg(b, 1.0, LEG_FRONT_T, 0.0)
	build_leg(b, -1.0, LEG_FRONT_T, 0.0)
	build_leg(b, 1.0, LEG_REAR_T, LEG_REAR_LEAN)
	build_leg(b, -1.0, LEG_REAR_T, LEG_REAR_LEAN)
	build_tail(b)

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

	Tout se decide sur la position PARAMETRIQUE et la normale, jamais sur
	l'eclairage — et le chien TOURNE pour suivre sa cible, donc une forme peinte
	doit etre ancree a ce qui la porte (la lecon du rai de soleil au sol).
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

		# La BASE part sous 1,0 partout, pour la raison mesuree sur la croquette :
		# le canal est borne a 1, donc partir de 1 revient a peindre un trait
		# uniforme et a laisser la borne manger le relief. Defaut silencieux — les
		# statistiques affichent bien "1,00".
		r = 0.84 - 0.16 * max(0.0, n.z) + 0.10 * max(0.0, -n.z)
		g = 0.52 - 0.13 * max(0.0, -n.z) + 0.04 * max(0.0, n.z)
		b = 0.0

		if shell == "corps":
			t = data["t"]
			up = math.cos(data["a"])

			# LE COU. Le creux geometrique donne la forme, ce trait-la donne la
			# LIGNE : c'est ce qui separe la tete du corps sur une silhouette de
			# 80 px, ou le creux lui-meme ne pese que deux pixels.
			neck = math.exp(-((t - 0.34) / 0.075) ** 2)
			r += 0.17 * neck
			g -= 0.11 * neck

			# LA CASSURE D'EPAULE — propre au quadrupede, et absente de la souris.
			# Sans elle, le poitrail et la taille forment une seule masse et les
			# pattes avant paraissent plantees au hasard dedans.
			shoulder = math.exp(-((t - 0.47) / 0.070) ** 2)
			g -= 0.07 * shoulder

			# L'OMBRE DU FLANC — une forme DESSINEE, pas un calcul (§2ter.2).
			# Elle prend le bas des flancs sur toute la longueur, franchement, et
			# c'est elle qui creuse le poitrail. Le seuil porte sur la
			# parametrisation, donc l'ombre ne bouge pas quand le chien tourne
			# pour suivre le chat.
			g -= 0.13 * max(0.0, -up - 0.10) / 0.90

			# ---- B : masque d'accent ------------------------------------
			# ⛔ ZERO PARTOUT, et c'est la meme decision que la souris et la boule
			# de poils, prise pour les deux memes raisons :
			#
			#   * la grille du dos fait 20 meridiens sur 13 sections. Le plus
			#     petit accent possible y est UN QUAD, donc un rectangle pale
			#     pose sur un dos — soit une salissure, pas un eclat. Le meme mur
			#     que les meches de la boule de poils ;
			#   * le pelage est a 0,54 de valeur et `accent_strength` vaut 0,30 :
			#     le melange vers le creme le porterait a ~0,68, soit un
			#     TROISIEME ton de cluster (contre §5.5).
			#
			# Le jour ou il faudra une brillance sur un ennemi, elle passera par
			# la ou passe celle du chat : un masque de SHADER, pas une grille.

		elif shell == "museau":
			s = data["s"]

			# Le STOP — la marche entre le front et le chanfrein. La geometrie la
			# produit deja (deux coques qui se croisent, donc deux contours), ce
			# trait-la l'appuie du cote du museau.
			r += 0.14 * max(0.0, 1.0 - s / 0.30)
			# Et l'ombre que le front porte sur le museau : c'est elle qui empeche
			# le beige de flotter devant la tete comme un masque.
			g -= 0.09 * max(0.0, 1.0 - s / 0.40)

		elif shell == "oreille":
			# Le trait s'epaissit sur la TRANCHE du volet : c'est le bord qui
			# porte la silhouette de l'oreille, et une oreille mal cernee se
			# confond avec la joue des que la bete se tourne.
			r += 0.18 * data["edge"]
			# Et il monte vers le BOUT, ou le volet devient plus mince que
			# l'encre — meme raison que la pointe de la queue.
			r += 0.10 * data["s"]
			# La partie pendante est dans l'ombre du crane, quelle que soit la
			# lumiere. Encore une forme dessinee, pas un calcul.
			g -= 0.10 * data["s"]

		elif shell == "patte":
			# Un membre fin : son trait porte a lui seul la lecture, et le canal R
			# decide de son epaisseur en jeu.
			r = 0.90 + 0.06 * data["k"]
			# L'INTERIEUR de la patte est dans l'ombre du corps. C'est ce qui
			# separe les deux pattes d'un meme cote quand elles se recouvrent —
			# sans quoi elles sortent en un seul bloc sombre sous le ventre.
			g = 0.50 - 0.14 * max(0.0, -n.x * data["side"]) - 0.10 * max(0.0, -n.z)

		elif shell == "queue":
			# Elle s'affine vers le bout, la ou le tube devient plus mince que
			# l'encre.
			r = 0.88 + 0.10 * data["s"]
			g = 0.48 - 0.10 * max(0.0, -n.z)

		# Le PLANCHER du canal R est de 0,68 PARTOUT, et il n'a plus d'exception
		# depuis que les yeux et la truffe sont peints. La regle vient du pixel :
		# sous ~0,68 de canal, le trait tombe sous 1 px au cadrage de jeu et ne se
		# lit plus comme un trait mais comme de la salete (la lecon
		# d'antialiasing du visage du chat).
		#
		# ⚠️ LES DEUX EXCEPTIONS QUI VIVAIENT ICI ONT DISPARU AVEC LEURS COQUES,
		# et c'est le meilleur signe que le passage en peinture etait le bon
		# geste : elles existaient uniquement pour empecher une coque d'encre de
		# percer la silhouette du crane. Une forme dessinee n'a pas de coque, donc
		# rien a percer, donc rien a border.
		r = min(1.0, max(0.68, r))
		g = min(0.58, max(0.30, g))

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

	Attr_Style.G est CABLE ici, pas seulement peint : peint mais non branche, le
	viewport Blender est aveugle aux ombres et on passe la soiree a deplacer un
	soleil.
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


# -------------------------------------------------------------------- scene

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
	scene.render.fps = 60
	scene.unit_settings.scale_length = 1.0


def clear_scene():
	for obj in list(bpy.data.objects):
		bpy.data.objects.remove(obj, do_unlink=True)
	for mesh in list(bpy.data.meshes):
		bpy.data.meshes.remove(mesh, do_unlink=True)
	for material in list(bpy.data.materials):
		bpy.data.materials.remove(material, do_unlink=True)


def main():
	clear_scene()
	setup_scene()

	mesh, info = build_mesh()

	for name, code in (("pelage", PELAGE), ("marques", MARQUES)):
		mesh.materials.append(toon_material(name, code))

	stats = paint(mesh, info)

	obj = bpy.data.objects.new(MESH_OBJECT, mesh)

	collection = bpy.data.collections.new(COLLECTION)
	bpy.context.scene.collection.children.link(collection)
	collection.objects.link(obj)

	tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
	lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
	hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])

	counts = {}
	for polygon in mesh.polygons:
		counts[polygon.material_index] = counts.get(polygon.material_index, 0) + 1

	shells = {}
	for data in info:
		shells[data["shell"]] = shells.get(data["shell"], 0) + 1

	print("\n[build_dog] %s" % MESH_OBJECT)
	print("  %d sommets, %d faces, %d tris  (chat 13 028, souris 1 252, sphere 4 224)"
			% (len(mesh.vertices), len(mesh.polygons), tris))
	print("  emprise  X %.3f a %.3f   Y %.3f a %.3f   Z %.3f a %.3f"
			% (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
	print("  hauteur %.3f   emprise Y %.3f   largeur %.3f"
			% (hi.z - lo.z, hi.y - lo.y, hi.x - lo.x))
	print("  sommets par coque : %s" % shells)
	print("  faces par matiere : pelage %d, marques %d  (2 surfaces = 4 draw calls,"
			" contour compris)" % (counts.get(0, 0), counts.get(1, 0)))
	print("  Attr_Style  R %.2f-%.2f   G %.2f-%.2f   B %.2f-%.2f  (%d sommets d'accent)"
			% (stats["r"][0], stats["r"][1], stats["g"][0], stats["g"][1],
			   stats["b"][0], stats["b"][1], stats["accent"]))

	# ── LES COULEURS, ET CE CONTRE QUOI ELLES SE JUGENT ───────────────────────
	# Imprimees plutot que commentees : c'est la seule facon de s'apercevoir
	# qu'une retouche a franchi une borne (parquet par le haut, chat par le bas,
	# souris par le milieu).
	print("  couleurs sRGB (valeur TSV / saturation)")
	for name, code in (("pelage", PELAGE), ("marques", MARQUES)):
		print("    %-8s %s  V %.2f  S %2d %%"
				% (name, code, hex_value(code), round(hex_saturation(code) * 100)))
	print("    ecarts au pelage : %s"
			% "  ".join("%s %+.2f" % (name, hex_value(code) - hex_value(PELAGE))
					for name, code in REFERENCES))
	shadow_value = hex_value(PELAGE) * SHADOW_VALUE
	print("    ombre du pelage %.2f  vs  encre %.2f  (ecart %+.2f, l'encre doit rester "
			"SOUS)" % (shadow_value, hex_value("#3D2B1A"), shadow_value - hex_value("#3D2B1A")))

	# ── LES MESURES QUI DECIDENT DE LA LECTURE, ET QU'AUCUNE BOITE NE DIT ─────
	head = spline(HEIGHT_KEYS, 0.25) + spline(RADIUS_KEYS, 0.25) * Z_SQUASH
	hip = spline(HEIGHT_KEYS, 0.86) + spline(RADIUS_KEYS, 0.86) * Z_SQUASH
	belly = (spline(HEIGHT_KEYS, 0.57)
			- spline(RADIUS_KEYS, 0.57) * Z_SQUASH * (1.0 - BELLY_FLAT))
	neck = spline(RADIUS_KEYS, 0.34) / spline(RADIUS_KEYS, 0.25)
	print("  dessus du crane %.3f  vs  hanche %.3f  (ecart %+.3f, doit rester > 0)"
			% (head, hip, head - hip))
	print("  pincement de nuque %.0f %%   ventre a %.3f   pied a %.3f"
			% ((1.0 - neck) * 100.0, belly, LEG_FOOT_Z))

	# ── LE GABARIT DE COLLISION (brute.tscn), QUE LE MODELE DOIT TENIR ────────
	nose = MUZZLE_Y1
	rump = LENGTH * -0.5
	print("  gabarit de brute.tscn — le modele s'y plie, jamais l'inverse")
	print("    museau->croupe %.3f   vs hurtbox diam %.2f  (%+.0f %%)"
			% (nose - rump, HURTBOX_RADIUS * 2.0,
			   (nose - rump) / (HURTBOX_RADIUS * 2.0) * 100.0 - 100.0))
	print("    largeur %.3f          vs cylindre diam %.2f"
			% (hi.x - lo.x, BODY_CYLINDER_RADIUS * 2.0))
	print("    hauteur %.3f          vs cylindre h %.2f  (hurtbox centree a %.2f)"
			% (hi.z, BODY_CYLINDER_HEIGHT, HURTBOX_CENTER_Z))

	if "--save" in sys.argv:
		OUTPUT.parent.mkdir(parents=True, exist_ok=True)
		bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
		print("  ecrit dans %s" % OUTPUT)
	else:
		print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
