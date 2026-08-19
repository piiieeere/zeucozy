"""Construit la SOURIS (le premier ennemi modelise), geometrie ET Attr_Style.

    "<blender>" --background --factory-startup \
        --python tools/build_mouse.py -- --save

Meme moule que `build_couch.py`, `build_kibble.py` et `build_hairball.py` — un
.blend REGENERE, jamais edite a la main, parce que la geometrie et sa peinture
`Attr_Style` ont la meme source. Les separer rejouerait le decalage que le chat
a paye cher : une peinture calee sur une version du maillage qui n'existe plus.

La chaine de materiau toon et les deux helpers de couleur sont RECOPIES de
`build_kibble.py` plutot que factorises, pour les deux raisons deja notees
la-bas (un script `--python` de Blender n'importe pas son voisin sans bricoler
`sys.path`, et ces valeurs ne servent qu'au viewport Blender — Godot repose sa
propre palette au chargement, dans `cel_prop.gd`).

CE QU'ELLE REMPLACE. Le `chaser` — la capsule rose `#FFADAD` de
`scenes/enemies/chaser.tscn`, l'ennemi rapide qui apparait des la premiere
seconde et qu'on croise le plus. C'est donc le modele le plus multiplie du jeu,
et §11 est explicite : "Ennemis | a reduire nettement".

FORME — la goutte, tranchee le 2026-08-19.
Une souris n'a pas de cou : tete et corps sont UNE SEULE MASSE qui va en
s'effilant vers le museau. Le corps est donc un BALAYAGE — une section
circulaire dont le rayon et la hauteur suivent deux profils le long de l'axe
nez/croupe. C'est ce qui le separe du moule de la boule de poils : la, la
modulation etait AUTOUR de l'axe et ne se voyait pas de flanc (§11) ; ici elle
est LE LONG de l'axe, donc elle EST la silhouette de flanc.

Trois coques s'y ajoutent, et chacune est un morceau de silhouette, pas un
detail : les deux OREILLES (des disques, la signature de la souris), la QUEUE
(une arche qui allonge la lecture), et les deux YEUX (des lentilles a peine
emergees). Tout est rond, aucun angle vif nulle part (§3).

⚠️ LA TETE EST PLUS HAUTE QUE LA CROUPE, ET CE N'EST PAS DE L'ANATOMIE.
Une vraie souris porte la tete bas. Sous la plongee a 45°, c'est exactement ce
qui avait fait lire le chat comme un CADENAS quand la camera etait a 60° (§11) :
la croupe passe au-dessus de la tete et avale ce qui depasse. Le dos monte donc
du bassin vers le crane, et les oreilles culminent au-dessus de tout.

COULEUR — un gris CHAUD, jamais neutre (§17 l'interdit explicitement).
`#A89684` est un taupe : hue ~30°, saturation 21 %. Deux contraintes le bornent
des deux cotes, et aucune n'est un gout :

  * PAR LE HAUT, le parquet. `#F5ECD8` a `#E8D4A8`, soit 0,93 a 0,96 de valeur.
    Le placeholder du projectile a deja paye ce mur : sous 0,10 d'ecart, un objet
    ne se detache pas du sol. Le taupe est a 0,66 — 0,27 d'ecart au plus juste ;
  * PAR LE BAS, le chat. Son pelage est a 0,29 : une souris sombre serait une
    petite tache de la meme matiere que le personnage, et dans un survivor le
    joueur trie a la valeur avant de trier a la forme (§15).

Les deux autres matieres sont des ZONES, pas des objets : le rose poudre
`#E8B8A8` de §4 pour le museau et l'interieur des oreilles — la peau nue d'une
souris — et le brun `#3D2B1A` que §2bis impose aux pupilles a la place du noir.

⚠️ LA QUEUE EST EN PELAGE, PAS EN ROSE, et c'est la mesure qui a tranche. Une
queue de souris est rose nu ; a `#E8B8A8` (0,91 de valeur) sur un parquet a 0,93
elle DISPARAIT — le meme calcul que le projectile jaune pale. Le seul endroit ou
le rose tient est celui ou il est cerne de pelage : l'interieur d'une oreille et
le bout du museau.

BUDGET GEOMETRIE — §11 : "Ennemis | a reduire nettement".
Vise ~1 100 tris, coque inversee non comprise, soit 8 % du chat (13 028). La
densite penche du cote des MERIDIENS sur le corps (22 x 12) : la silhouette qui
compte est celle du dos vu de trois quarts, dessinee par les sections.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/enemy_souris_v1.blend")

COLLECTION = "enemy_souris"
MESH_OBJECT = "MSH_souris"
ATTRIBUTE = "Attr_Style"

# ---------------------------------------------------------------- dimensions

# Longueur du corps seul, du bout du museau a la croupe. La queue s'y ajoute.
#
# Le gabarit est celui que `chaser.tscn` porte deja : cylindre de collision
# r = 0,65 / h = 1,3, hurtbox spherique r = 0,75. Le modele doit tenir dedans,
# sinon remplacer la capsule deviendrait un changement d'equilibrage deguise —
# un ennemi qu'on touche avant de le voir, ou l'inverse.
LENGTH = 1.30

# Facteur applique au maillage ENTIER, en toute derniere etape.
#
# ⚠️ IL EXISTE PARCE QUE LA HURTBOX EXISTE DEJA, pas par gout. `chaser.tscn`
# porte une sphere de degats et une hurtbox de 0,75 de rayon — soit 1,5 m de
# diametre — heritees de la capsule placeholder. Rendu a l'echelle nominale, le
# corps de la souris faisait 0,73 de large : le joueur l'aurait touchee (et
# aurait ete touche) a une bonne demi-longueur de ce qu'il voit. Le defaut est
# muet, il ne se lit qu'a la manette.
#
# Remonter le modele plutot que descendre la hurtbox est deliberatif : baisser la
# hurtbox rendrait le chaser plus dur a toucher, donc changerait l'equilibrage
# sous couvert de remplacer un placeholder. Un remplacement visuel ne doit rien
# deplacer d'autre.
#
# ⚠️ Il s'applique APRES la peinture des zones et le calcul des normales : une
# homothetie ne change ni les unes ni les autres, mais elle changerait les seuils
# si on la posait avant.
SCALE = 1.20

# Le rayon de la section, le long de l'axe. t = 0 au museau, t = 1 a la croupe.
#
# ⚠️ LE MAXIMUM EST A LA HANCHE (t = 0,70), PAS AU MILIEU. Une masse centree
# donne un cochon d'inde ; ce qui fait lire "souris" est la goutte — lourde
# derriere, effilee devant.
RADIUS_KEYS = [
	(0.00, 0.000),  # bout du museau, un point
	(0.05, 0.078),
	(0.13, 0.148),
	(0.24, 0.250),
	(0.34, 0.315),  # le crane, le plus large de l'avant
	# ⚠️ LE CREUX DE LA NUQUE EST CE QUI SEPARE LA TETE DU CORPS, et le premier
	# jet le posait a 0,264 pour un crane de 0,300 — 12 % de pincement, invisible
	# en capture : la bete sortait en manatee. A 0,232 le pincement fait 26 %, et
	# la tete redevient une masse a part. §3 veut une tete legerement
	# surdimensionnee : le crane monte donc en meme temps que la hanche descend.
	(0.44, 0.232),
	(0.56, 0.292),
	(0.70, 0.340),  # la hanche
	(0.84, 0.318),
	# La croupe se ferme en ROND, pas en cone. A une seule cle a 0,94 le rayon
	# tombait de 0,20 a 0 sur 0,078 de long, soit un cone a 69° — et il sortait
	# en FACETTE PLATE sur la silhouette de flanc, la ou §3 ne veut aucun angle.
	(0.94, 0.170),
	(0.98, 0.082),
	(1.00, 0.000),  # la croupe, un point
]

# La hauteur du CENTRE de la section. C'est ce profil-la qui redresse la tete
# au-dessus de la croupe — voir l'en-tete.
HEIGHT_KEYS = [
	(0.00, 0.270),
	(0.05, 0.272),
	(0.13, 0.290),
	(0.24, 0.335),
	(0.34, 0.372),
	(0.44, 0.345),
	(0.56, 0.318),
	(0.70, 0.305),
	(0.84, 0.300),
	(0.94, 0.282),
	(0.98, 0.272),
	(1.00, 0.265),
]

# Ecrasement vertical de la section : la souris est un peu plus large que haute,
# ce qui la pose au sol au lieu de la faire tenir en boule.
Z_SQUASH = 0.92

# Aplatissement du ventre. Une bete posee au sol n'y touche pas par une tangente
# de cercle. Multiplicateur DOUX (pas de troncature) : §3 n'admet aucun angle.
BELLY_FLAT = 0.12

# Les sections, en t. NON UNIFORMES, resserrees vers l'avant : c'est la que le
# profil tourne vite (museau, crane, nuque). Un pas constant y facettait le
# dessus du crane, le seul endroit que la camera regarde vraiment.
SECTIONS = [0.045, 0.10, 0.17, 0.25, 0.33, 0.41, 0.49, 0.58, 0.68, 0.78, 0.87, 0.94, 0.98]
N_U = 22

# Le museau : toutes les faces sous ce t partent en peau rose. Le bout du
# balayage est un POLE, donc la zone y est ronde par construction — pas
# d'escalier de colonnes a craindre, le piege que les meches de la boule de
# poils ont paye.
NOSE_T = 0.062

# ─── LES OREILLES ─────────────────────────────────────────────────────────────
#
# C'est LA signature. Une souris se reconnait a ses oreilles avant sa queue et
# bien avant son museau — ce sont deux disques, et un disque est ce qu'une
# silhouette lit le plus vite (§3 : lisible en une seconde).
#
# Ce sont des ELLIPSOIDES TRES APLATIS dont l'axe POLAIRE est l'epaisseur. Deux
# consequences, et la seconde est la vraie raison du choix :
#
#   * la silhouette du disque est son equateur, donc elle est dessinee par les
#     meridiens — 16 suffisent pour un bord rond a cette taille ;
#   * l'interieur rose est la CALOTTE POLAIRE. Une calotte autour d'un pole est
#     ronde dans la parametrisation elle-meme : sa frontiere suit les paralleles,
#     jamais un escalier de colonnes. C'est exactement le defaut que les meches
#     de la boule de poils ont paye — un bord de calotte pose sur une grille
#     grossiere se lit comme un eclat dans la matiere.
# ⚠️ MESUREES SUR LE CRANE, PAS DANS L'ABSOLU. Le premier jet donnait 0,300 de
# demi-axe pour un crane de 0,300 de rayon : le disque faisait donc le DIAMETRE
# de la tete, et en capture il l'avalait entierement — de profil on ne voyait
# plus qu'une oreille, la tete avait disparu dessous. A 0,215 l'oreille fait
# ~0,7 fois le diametre du crane : elle reste la plus grande chose de la
# silhouette (c'est la signature) sans manger ce qu'elle coiffe.
EAR_A = 0.215   # demi-axe "vertical" du disque
EAR_B = 0.185   # demi-axe "horizontal"
EAR_H = 0.052   # demi-epaisseur
EAR_N_U = 16
EAR_N_V = 5

# Ou l'oreille s'accroche sur le crane (t, angle de section en degres depuis le
# dos), de combien elle sort le long de la normale, de combien on la remonte.
EAR_T = 0.355
EAR_SIDE_DEG = 40.0
EAR_PUSH = 0.02
EAR_LIFT = 0.235

# L'axe de l'oreille — la direction vers laquelle sa face rose regarde.
# DEHORS + DEVANT + LE CIEL, en parts a peu pres egales.
#
# ⚠️ La part de ciel n'est pas decorative : sous une plongee a 45°, un disque
# vertical se voit PAR LA TRANCHE et l'oreille disparait — avec elle, tout ce
# qui fait lire "souris". Le rose doit regarder la camera, donc le haut.
EAR_AXIS = (0.62, 0.34, 0.71)

# La frontiere de la calotte rose, en cosinus d'angle polaire. 0,55 laisse un
# ourlet de pelage sur le bord : sans lui, le rose atteint la silhouette et
# l'oreille se lit comme un disque rose pose sur la tete, pas comme une oreille.
EAR_PINK_COS = 0.55

# ─── LES YEUX ─────────────────────────────────────────────────────────────────
#
# ⚠️ §2bis DIT "PEINTS, JAMAIS MODELISES", ET C'EST UNE ENTORSE ASSUMEE.
# La regle vient d'une mesure : des yeux SPHERIQUES debordent de la silhouette
# vue de cote et deviennent des taches qui enveloppent le crane. Ce que le chat
# a paye, ce n'est pas la geometrie — c'est le VOLUME.
#
# Ici l'oeil est une LENTILLE : 0,030 de demi-epaisseur, enfoncee de facon a
# n'emerger que de 0,020, soit un quinzieme du rayon du crane. Sa tangente
# epouse la surface, donc de profil elle ne peut pas depasser. La verification
# 8 directions de §16 etape 7 est faite pour trancher ca, et elle tranchera.
#
# La voie orthodoxe reste ouverte : un shader de visage, comme
# `cel_face.gdshader`. Elle est ecartee pour l'instant parce que le chat en a eu
# besoin d'un a cause du SKINNING (`rest_undo`, piege n°5) — une souris n'a pas
# de squelette, donc rien ne glisse — mais ca reste un shader de plus a ecrire,
# a regler et a tenir, pour deux points sombres de ~3 px a taille de jeu.
EYE_R = 0.066
EYE_H = 0.030
EYE_OUT = 0.020
EYE_T = 0.195
# ⚠️ 66° ET NON 62° : l'angle se compte depuis le DOS, donc l'augmenter fait
# descendre l'oeil sur le flanc — et c'est l'oeil ELOIGNE qui decide. Voir le
# piege de la coque d'encre, juste sous `paint()`.
EYE_SIDE_DEG = 66.0
EYE_N_U = 10
EYE_N_V = 3

# ─── LA QUEUE ─────────────────────────────────────────────────────────────────
#
# ⛔ DEUX ARCHES VERTICALES ONT ETE RENDUES ET JETEES AVANT CELLE-CI, et la
# raison vaut pour tout appendice allonge a venir (la trompe de l'aspirateur, la
# laisse du chien) :
#
#   UNE COURBE QUI MONTE NE SE VOIT PAS SOUS UNE CAMERA QUI PLONGE. A 45°, une
#   arche verticale se projette DANS le corps qui la porte : les deux tiers de sa
#   longueur se superposent au dos, et il ne reste a l'ecran qu'un moignon
#   recourbe. Les deux versions sont sorties en POIGNEE accrochee a la croupe —
#   la seconde etait pourtant 40 % plus longue que la premiere, et se lisait
#   exactement pareil. Ce n'etait donc pas une question de longueur.
#
# Ce que la camera voit en vraie grandeur, c'est le PLAN DU SOL. La queue y court
# donc en S, et c'est la que sa longueur devient lisible.
#
# ⚠️ Mais elle ne touche pas le sol pour autant. A plat, sa coque inversee passe
# SOUS le maillage, le parquet se peint par-dessus, et il reste un lisere
# parchemin entre l'aplat et le trait (mesure sur la croquette posee au banc).
# Elle court donc a ~0,25 m : assez bas pour se lire a plat, assez haut pour que
# l'encre (0,034) et le tube (0,076) passent au-dessus du parquet.
#
# La pointe se releve sur la fin — un dernier mouvement, ce que §3 appelle
# "l'ame" d'un objet, et accessoirement ce qui la sort du plan du sol la ou elle
# est la plus fine.
#
# Le premier point est DANS la croupe, pas dessus : la coque doit s'y enfoncer,
# sinon on voit le joint.
TAIL_PATH = [
	(0.000, -0.520, 0.300),
	(0.075, -0.790, 0.252),
	(0.190, -1.000, 0.238),
	(0.320, -1.150, 0.272),
	(0.455, -1.235, 0.372),
]

# ⚠️ LE RAYON EST BORNE PAR L'ENCRE, pas par le dessin. La coque inversee fait
# ~0,034 en unites monde et elle deborde de chaque cote : un tube de rayon `r`
# sort a l'ecran en `r + 0,034`, dont le coeur en pelage ne fait que
# `r / (r + 0,034)` de la largeur. A 0,045 il en reste 57 %, soit ~3 px de pelage
# au cadrage de jeu — le tube se lit encore comme un objet cerne. En dessous, il
# passe en encre pleine et le trait cesse d'etre un trait pour devenir l'objet.
# C'est la meme borne que les creux de la croquette et de la boule de poils,
# prise par l'autre bout.
#
# ⚠️ ET LE PROFIL DE TAPER N'EST PAS LINEAIRE. En lineaire, la queue restait
# grasse sur toute sa partie visible et sortait en MOIGNON — a 45° elle se lisait
# comme une poignee accrochee a la croupe, pas comme une queue. L'exposant amincit
# tot : ce qui fait lire "queue" est la finesse au DEPART de l'arc, pas au bout.
TAIL_R0 = 0.070
TAIL_R1 = 0.045
TAIL_TAPER_POW = 0.55
TAIL_N_U = 10
TAIL_N_V = 11

# ─── LES TROIS MATIERES ───────────────────────────────────────────────────────
PELAGE = "#A89684"
PEAU = "#E8B8A8"
OEIL = "#3D2B1A"

# Memes reglages que les uniforms de cel_toon.gdshader : le ton d'ombre de
# Blender est celui de Godot, et non un second reglage a la main.
SHADOW_HUE_SHIFT = -0.02
SHADOW_SATURATION = 1.15
SHADOW_VALUE = 0.65

RAMP_SPLIT = 0.52

MAT_PELAGE, MAT_PEAU, MAT_OEIL = 0, 1, 2


# ------------------------------------------------------------------- couleurs

def srgb_to_linear(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return ((value + 0.055) / 1.055) ** 2.4


def hex_to_linear(code: str) -> tuple:
	code = code.lstrip("#")
	return tuple(srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def hex_value(code: str) -> float:
	"""La VALEUR au sens TSV, en sRGB — celle sur laquelle se lit un contraste.

	Le projet compare des valeurs a longueur de decisions (le projectile contre
	le parquet, le canape contre les lames claires) : autant que le script qui
	pose la couleur sache dire ou elle tombe.
	"""
	code = code.lstrip("#")
	return max(int(code[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


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
	la ou la forme tourne (museau, crane, nuque, hanche). Un Catmull-Rom uniforme
	lu sur des cles serrees produit des tangentes trop fortes, donc un ventre
	bombe entre deux cles rapprochees.
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

	Et non sur le maillage : les oreilles et les yeux se posent avant que le
	maillage existe, et une normale relue apres coup dependrait de la densite
	des sections — donc changerait de reponse si on retouchait `SECTIONS`.
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
	nose = b.vert(body_point(0.0, 0.0), {"shell": "corps", "t": 0.0, "a": 0.0})
	rings = []

	for t in SECTIONS:
		ring = []

		for i in range(N_U):
			a = math.tau * i / float(N_U)
			ring.append(b.vert(body_point(t, a), {"shell": "corps", "t": t, "a": a}))

		rings.append(ring)

	rump = b.vert(body_point(1.0, 0.0), {"shell": "corps", "t": 1.0, "a": 0.0})

	# Le materiau se decide sur le t du CENTRE de la face, jamais sur la moyenne
	# de ses sommets : `a` boucle a 2*pi et une face a cheval sur la couture
	# rendrait pi au lieu de 0 (le piege releve sur les meches de la boule de
	# poils). Ici seul `t` decide, mais la regle vaut d'etre tenue partout.
	def mat(t_mid: float) -> int:
		return MAT_PEAU if t_mid < NOSE_T else MAT_PELAGE

	for i in range(N_U):
		nxt = (i + 1) % N_U
		b.face((nose, rings[0][nxt], rings[0][i]), mat(SECTIONS[0] * 0.5))
		b.face((rump, rings[-1][i], rings[-1][nxt]), MAT_PELAGE)

	for j, (lower, upper) in enumerate(zip(rings, rings[1:])):
		t_mid = (SECTIONS[j] + SECTIONS[j + 1]) * 0.5

		for i in range(N_U):
			nxt = (i + 1) % N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), mat(t_mid))


def build_ear(b: Builder, side: float) -> None:
	"""Un disque epais, pose sur le crane, sa calotte polaire en rose."""
	a = math.radians(EAR_SIDE_DEG) * side
	base = body_point(EAR_T, a)
	normal = body_normal(EAR_T, a)
	axis = Vector((EAR_AXIS[0] * side, EAR_AXIS[1], EAR_AXIS[2])).normalized()
	center = base + normal * EAR_PUSH + Vector((0.0, 0.0, EAR_LIFT))

	u, v, n = frame(axis)

	def point(phi: float, th: float) -> Vector:
		return (center
				+ u * (EAR_A * math.sin(phi) * math.cos(th))
				+ v * (EAR_B * math.sin(phi) * math.sin(th) * side)
				+ n * (EAR_H * math.cos(phi)))

	back = b.vert(point(math.pi, 0.0), {"shell": "oreille", "cos": -1.0, "side": side})
	rings = []

	for j in range(1, EAR_N_V + 1):
		phi = math.pi * j / float(EAR_N_V + 1)
		ring = []

		for i in range(EAR_N_U):
			th = math.tau * i / float(EAR_N_U)
			ring.append(b.vert(point(phi, th), {
				"shell": "oreille", "cos": math.cos(phi), "side": side,
			}))

		rings.append(ring)

	front = b.vert(point(0.0, 0.0), {"shell": "oreille", "cos": 1.0, "side": side})

	cos_ring = [math.cos(math.pi * j / float(EAR_N_V + 1)) for j in range(EAR_N_V + 2)]

	def mat(cos_mid: float) -> int:
		return MAT_PEAU if cos_mid > EAR_PINK_COS else MAT_PELAGE

	# ⚠️ `rings[0]` est le plus PROCHE du pole +n (phi croit avec j), donc c'est
	# `front` qui s'y raccorde. La premiere version avait les deux poles croises :
	# l'eventail du pole rose traversait toute l'oreille et sortait en BAGUE —
	# un anneau rose autour d'un disque de pelage. Le maillage restait ferme et
	# le rapport de style ne signalait rien : ca ne s'est vu qu'en capture.
	for i in range(EAR_N_U):
		nxt = (i + 1) % EAR_N_U
		b.face((front, rings[0][nxt], rings[0][i]), mat((1.0 + cos_ring[1]) * 0.5))
		b.face((back, rings[-1][i], rings[-1][nxt]), MAT_PELAGE)

	for j, (lower, upper) in enumerate(zip(rings, rings[1:])):
		cos_mid = (cos_ring[j + 1] + cos_ring[j + 2]) * 0.5

		for i in range(EAR_N_U):
			nxt = (i + 1) % EAR_N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), mat(cos_mid))


def build_eye(b: Builder, side: float) -> None:
	"""Une lentille tangente au crane, emergee de EYE_OUT et pas d'un micron de plus."""
	a = math.radians(EYE_SIDE_DEG) * side
	surface = body_point(EYE_T, a)
	normal = body_normal(EYE_T, a)
	center = surface - normal * (EYE_H - EYE_OUT)

	u, v, n = frame(normal)

	def point(phi: float, th: float) -> Vector:
		return (center
				+ u * (EYE_R * math.sin(phi) * math.cos(th))
				+ v * (EYE_R * math.sin(phi) * math.sin(th))
				+ n * (EYE_H * math.cos(phi)))

	back = b.vert(point(math.pi, 0.0), {"shell": "oeil", "cos": -1.0, "side": side})
	rings = []

	for j in range(1, EYE_N_V + 1):
		phi = math.pi * j / float(EYE_N_V + 1)
		ring = []

		for i in range(EYE_N_U):
			th = math.tau * i / float(EYE_N_U)
			ring.append(b.vert(point(phi, th), {
				"shell": "oeil", "cos": math.cos(phi), "side": side,
			}))

		rings.append(ring)

	front = b.vert(point(0.0, 0.0), {"shell": "oeil", "cos": 1.0, "side": side})

	# Meme raccordement que l'oreille — voir le piege des poles croises la-bas.
	for i in range(EYE_N_U):
		nxt = (i + 1) % EYE_N_U
		b.face((front, rings[0][nxt], rings[0][i]), MAT_OEIL)
		b.face((back, rings[-1][i], rings[-1][nxt]), MAT_OEIL)

	for lower, upper in zip(rings, rings[1:]):
		for i in range(EYE_N_U):
			nxt = (i + 1) % EYE_N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), MAT_OEIL)


def tail_point(s: float) -> Vector:
	"""Catmull-Rom sur `TAIL_PATH`, parametre par s dans [0, 1]."""
	n = len(TAIL_PATH) - 1.0
	return Vector([
		spline([(i / n, p[k]) for i, p in enumerate(TAIL_PATH)], s)
		for k in range(3)
	])


def build_tail(b: Builder) -> None:
	"""Un tube a TRANSPORT PARALLELE, jamais un repere de Frenet.

	Le repere de Frenet se retourne des que la courbure s'annule, et l'arche de
	la queue a un point d'inflexion. Le tube se vrillerait d'un demi-tour sur une
	section : invisible sur un tube rond, mais ca tord la peinture qu'on y pose.
	"""
	samples = [j / float(TAIL_N_V) for j in range(TAIL_N_V + 1)]
	points = [tail_point(s) for s in samples]

	tangents = []
	for j in range(len(points)):
		lo = points[max(0, j - 1)]
		hi = points[min(len(points) - 1, j + 1)]
		tangents.append((hi - lo).normalized())

	ref = Vector((1.0, 0.0, 0.0))
	ref = (ref - tangents[0] * ref.dot(tangents[0])).normalized()
	frames = []

	for j, tangent in enumerate(tangents):
		if j > 0:
			ref = (ref - tangent * ref.dot(tangent)).normalized()
		frames.append((ref.copy(), tangent.cross(ref).normalized()))

	def radius(s: float) -> float:
		r = TAIL_R0 + (TAIL_R1 - TAIL_R0) * (s ** TAIL_TAPER_POW)

		# La calotte du bout : un quart de cercle sur les 12 derniers %, donc une
		# pointe ARRONDIE. Un cone se terminerait par un angle, ce que §3 refuse.
		if s > 0.88:
			k = (s - 0.88) / 0.12
			r *= math.sqrt(max(0.0, 1.0 - k * k))

		return r

	rings = []

	for j, s in enumerate(samples):
		u, v = frames[j]
		r = radius(s)
		ring = []

		for i in range(TAIL_N_U):
			th = math.tau * i / float(TAIL_N_U)
			ring.append(b.vert(
				points[j] + u * (r * math.cos(th)) + v * (r * math.sin(th)),
				{"shell": "queue", "s": s, "th": th},
			))

		rings.append(ring)

	# La base est ENFOUIE dans la croupe : on la ferme quand meme, une coque
	# ouverte laisserait voir son interieur des que la coque inversee passe.
	root = b.vert(points[0], {"shell": "queue", "s": 0.0, "th": 0.0})
	tip = b.vert(points[-1], {"shell": "queue", "s": 1.0, "th": 0.0})

	for i in range(TAIL_N_U):
		nxt = (i + 1) % TAIL_N_U
		b.face((root, rings[0][nxt], rings[0][i]), MAT_PELAGE)
		b.face((tip, rings[-1][i], rings[-1][nxt]), MAT_PELAGE)

	for lower, upper in zip(rings, rings[1:]):
		for i in range(TAIL_N_U):
			nxt = (i + 1) % TAIL_N_U
			b.face((lower[i], lower[nxt], upper[nxt], upper[i]), MAT_PELAGE)


def build_mesh():
	b = Builder()

	build_body(b)
	build_ear(b, 1.0)
	build_ear(b, -1.0)
	build_eye(b, 1.0)
	build_eye(b, -1.0)
	build_tail(b)

	bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces)
	bmesh.ops.scale(b.bm, verts=b.bm.verts, vec=Vector((SCALE, SCALE, SCALE)))

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
	l'eclairage — et la souris TOURNE pour suivre sa cible, donc une forme peinte
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

			# Le creux de la nuque : c'est le trait qui separe la tete du corps
			# sur une bete qui n'en a pas. Sans lui, la souris est une goutte.
			neck = math.exp(-((t - 0.45) / 0.09) ** 2)
			r += 0.16 * neck
			g -= 0.10 * neck

			# L'OMBRE DU FLANC — une forme DESSINEE, pas un calcul (§2ter.2).
			# Elle prend le bas des flancs sur toute la longueur, franchement,
			# et c'est elle qui pose la bete au sol quand le contour ne suffit
			# pas. Le seuil porte sur la parametrisation, donc l'ombre ne bouge
			# pas quand la souris tourne pour suivre le chat.
			g -= 0.12 * max(0.0, -up - 0.15) / 0.85

			# ---- B : masque d'accent ------------------------------------
			# ⛔ ZERO PARTOUT, et c'est une decision prise EN CAPTURE, pas un
			# oubli. Deux tailles ont ete rendues et jetees ; les deux sortaient
			# en TACHE, et la raison n'est pas leur taille :
			#
			#   * la grille du dos fait 22 meridiens sur 13 sections. Le plus
			#     petit accent possible y est UN QUAD, donc un rectangle. Un
			#     eclat de brillance est rond ; un rectangle pale pose sur un dos
			#     se lit comme une salissure. C'est le meme mur que les meches de
			#     la boule de poils — un bord de zone pose sur une grille
			#     grossiere ne peut pas etre autre chose qu'un escalier ;
			#   * le pelage est a 0,66 de valeur et `accent_strength` vaut 0,30 :
			#     le melange vers le creme le porte a 0,75, soit un TROISIEME ton
			#     de cluster (contre §5.5). Le chat a deja paye ce reglage sur son
			#     pelage noir, la boule de poils l'a coupe pour la meme raison.
			#
			# Le jour ou il faudra une brillance sur un ennemi, elle passera par
			# la ou passe celle du chat : un masque de SHADER, pas une grille.

		elif shell == "oreille":
			cos = data["cos"]

			# Le trait s'epaissit sur la TRANCHE du disque : c'est le bord qui
			# porte la silhouette de l'oreille, et une oreille mal cernee se
			# confond avec le crane des que la bete se tourne.
			r += 0.18 * (1.0 - abs(cos))

			# L'interieur d'une oreille est un creux : il est dans l'ombre quelle
			# que soit la lumiere. Encore une forme dessinee, pas un calcul.
			if cos > EAR_PINK_COS:
				g -= 0.14

		elif shell == "oeil":
			# ⛔ LE TRAIT LE PLUS FIN DU MODELE, ET C'EST L'INVERSE DE CE QUE LE
			# PREMIER JET FAISAIT. A R = 0,98 — le plus charge, "parce qu'un oeil
			# est ce qu'un dessin cerne le plus" — l'oeil ELOIGNE PERCAIT LA
			# SILHOUETTE DU CRANE de profil : une encoche sombre sur le dessus de
			# la tete, sur les vues 90 et 270.
			#
			# Et ce qui debordait n'etait pas la lentille, c'etait SA COQUE
			# INVERSEE. La lentille elle-meme depasse de 0,004 de la surface a son
			# bord ; l'encre, elle, ajoute 0,036 dans TOUTES les directions. C'est
			# donc §2bis qui avait raison sur le fond ("les yeux debordent de la
			# silhouette vue de cote") et le diagnostic qui etait a cote : ce n'est
			# pas le volume de l'oeil qui deborde, c'est ce qu'on peint autour.
			#
			# La sortie ne coute rien : UN OEIL N'A PAS BESOIN D'ETRE CERNE, il
			# EST de l'encre. `#3D2B1A` est exactement la couleur que §4 donne au
			# contour principal. On garde juste de quoi ne pas retomber sur une
			# coque d'epaisseur nulle, qui z-fighte avec la surface qu'elle double.
			r = 0.30
			g = 0.32

		elif shell == "queue":
			# Une queue est fine : son trait porte a lui seul la lecture, et le
			# canal R decide de son epaisseur en jeu. Il monte vers la pointe, la
			# ou le tube devient plus mince que l'encre.
			r = 0.88 + 0.10 * data["s"]
			g = 0.48 - 0.10 * max(0.0, -n.z)

		# Le PLANCHER du canal R est de 0,68 partout, sauf sur l'oeil. La regle
		# generale vient du pixel : sous ~0,68 de canal, le trait tombe sous 1 px
		# au cadrage de jeu et ne se lit plus comme un trait mais comme de la
		# saleté (la lecon d'antialiasing du visage du chat). L'oeil est
		# l'exception voulue — il n'a pas de trait a lire, il EST le trait — et
		# sans cette ligne le plancher ecrasait silencieusement son 0,30, ce qui
		# est exactement le genre de bug qu'un rapport de statistiques rassurant
		# ("R 0,68-1,00") laisse passer.
		r = min(1.0, max(0.28 if shell == "oeil" else 0.68, r))
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

	for name, code in (("pelage", PELAGE), ("peau", PEAU), ("oeil", OEIL)):
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

	print("\n[build_mouse] %s" % MESH_OBJECT)
	print("  %d sommets, %d faces, %d tris  (chat = 13 028)"
			% (len(mesh.vertices), len(mesh.polygons), tris))
	print("  emprise  X %.3f a %.3f   Y %.3f a %.3f   Z %.3f a %.3f"
			% (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
	print("  hauteur %.3f   longueur %.3f   largeur %.3f"
			% (hi.z - lo.z, hi.y - lo.y, hi.x - lo.x))
	print("  sommets par coque : %s" % shells)
	print("  faces par matiere : pelage %d, peau %d, oeil %d"
			% (counts.get(0, 0), counts.get(1, 0), counts.get(2, 0)))
	print("  valeurs sRGB — pelage %.2f, peau %.2f, oeil %.2f  (parquet 0,91-0,96)"
			% (hex_value(PELAGE), hex_value(PEAU), hex_value(OEIL)))
	print("  Attr_Style  R %.2f-%.2f   G %.2f-%.2f   B %.2f-%.2f  (%d sommets d'accent)"
			% (stats["r"][0], stats["r"][1], stats["g"][0], stats["g"][1],
			   stats["b"][0], stats["b"][1], stats["accent"]))

	# Les deux mesures qui decident de la lecture sous une plongee a 45°, et
	# qu'aucune boite englobante ne dit : le dessus du crane doit rester
	# au-dessus de la hanche, et le ventre doit fraiser le sol sans y entrer.
	head = (spline(HEIGHT_KEYS, 0.34) + spline(RADIUS_KEYS, 0.34) * Z_SQUASH) * SCALE
	hip = (spline(HEIGHT_KEYS, 0.70) + spline(RADIUS_KEYS, 0.70) * Z_SQUASH) * SCALE
	belly = (spline(HEIGHT_KEYS, 0.70)
			- spline(RADIUS_KEYS, 0.70) * Z_SQUASH * (1.0 - BELLY_FLAT)) * SCALE
	print("  dessus du crane %.3f  vs  hanche %.3f  (ecart %+.3f, doit rester > 0)"
			% (head, hip, head - hip))
	print("  garde au sol sous la hanche %.3f" % belly)

	if "--save" in sys.argv:
		OUTPUT.parent.mkdir(parents=True, exist_ok=True)
		bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
		print("  ecrit dans %s" % OUTPUT)
	else:
		print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
