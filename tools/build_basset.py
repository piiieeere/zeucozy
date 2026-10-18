"""Construit le BASSET (la BRUTE), geometrie ET Attr_Style.

    "<blender>" --background --factory-startup \
        --python tools/build_basset.py -- --save

Meme moule que `build_dog.py`, dont il reprend la chaine de materiau, les
helpers de profil et les gardes — un .blend REGENERE, jamais edite a la main.
Les helpers sont RECOPIES et non importes, pour la raison deja notee dans
`build_mouse.py` : un script `--python` de Blender n'importe pas son voisin
sans bricoler `sys.path`, et ces valeurs ne servent qu'au viewport Blender.

CE QU'IL REMPLACE. Le chien trapu de `build_dog.py` (2026-08-19) dans
`scenes/enemies/brute.tscn`. Le role ne change pas : c'est toujours la brute
— 30 de degat au contact, 7 PV, 2,6 m/s, apparition a 22 s. Seul le dessin
change, d'apres `maquettes/Chubby Basset Dog Turnaround Sheet.png` (2026-10-18).
L'ancien `enemy_chien.glb` reste dans le depot, comme `player_cat.glb` apres
le chat tuxedo : plus charge, rechargeable au banc par `--model=`.

TAILLE — LE MODELE SE PLIE A LA HURTBOX, PAS A LA PLANCHE (tranche le
2026-10-18). Sur la planche, le basset fait 1,25 fois le chat : ~2,3 m de haut
et ~3,3 m de long a l'echelle du jeu. La hurtbox de la brute fait 2,00 m de
diametre, et l'agrandir changerait l'equilibrage sous couvert de remplacer un
modele — la regle heritee de la souris et du chien. On garde donc les
PROPORTIONS de la planche, a l'echelle du gabarit : 0,00426 m par pixel du
profil, soit truffe->croupe = 2,00 m et crane a 1,38 m.

FORME — ce qui separe un basset du chien trapu qu'il remplace, et rien d'autre :

  * le VENTRE TRAINE. 0,29 m a mi-tronc contre 0,52 au chien d'avant : un
    basset est un tronc pose sur des moignons. Les pattes ne sont plus ce qui
    pose la bete — elles depassent a peine —, ce sont les PIEDS, enormes et
    clairs, qui la posent ;
  * la TETE EST UNE COQUE A PART, plus petite que le tronc (0,62 de large
    contre 1,0). Le chien d'avant avait un crane plus gros que le poitrail ; ici
    la masse est le tronc, et la tete s'y plante sans cou. Le trait parasite a
    l'intersection (piege n°2) est VOULU : c'est la ligne de bajoue que la
    planche dessine sous la machoire ;
  * le MUSEAU est un BLOC, presque aussi haut que long (0,36 x 0,34), section
    en super-ellipse : le basset a les babines carrees, pas un chanfrein ;
  * les OREILLES descendent sous la machoire — 0,62 m de long, dans le ton
    d'ombre du pelage. C'est LA signature, et la planche les peint plus sombres
    que le corps : le canal G les tient en ombre permanente, sans 3e matiere
    (donc sans 3e surface ni 2 draw calls de plus) ;
  * la QUEUE EN SABRE, haute et droite, comme sur la planche — voir le piege
    plus bas.

Tout est rond, aucun angle vif nulle part (§3).

⛔ NI LES YEUX NI LA TRUFFE NE SONT MODELISES (§2bis). Ils sont dessines par
`shaders/cel_creature_face.gdshader`, reglages dans `FACES["basset"]` de
`cel_prop.gd` — le meme chemin que le chien et la souris.

COULEUR — celle de la planche, et les bornes sont imprimees a chaque build.
`#965A31` est le pelage releve sur la planche, tel quel : valeur 0,59,
saturation 67 %. Il reste borne par le parquet en haut, le chat en bas, et la
souris au milieu (0,66 — l'ecart de valeur tombe a 0,07, mais la saturation
fait 67 % contre 21 % et le gabarit le double). Les MARQUES ne sont PAS celles
de la planche : `#D9A668` y est a 0,85, soit 0,06 seulement sous le parquet
fonce — sous le seuil de 0,10 ou un objet cesse de se detacher du sol, et les
pieds TOUCHENT le sol. Meme teinte, valeur ramenee a 0,80 : `#CC9C62`.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/enemy_basset_v1.blend")

COLLECTION = "enemy_basset"
MESH_OBJECT = "MSH_basset"
ATTRIBUTE = "Attr_Style"

# Metres par pixel du PROFIL de la planche (truffe x 330 -> croupe x 800, sol
# y 354). Toutes les cotes ci-dessous en sont deduites ; la colonne de gauche des
# commentaires donne le pixel d'origine quand il y en a un.
PX = 2.00 / 470.0

# ─── LE TRONC ─────────────────────────────────────────────────────────────────
#
# Un BALAYAGE le long de Y (avant = +Y, la truffe), comme le chien d'avant —
# mais la section est une ELLIPSE a trois profils independants (dessus, dessous,
# demi-largeur) au lieu d'un cercle a un rayon. Un basset est 1,5 fois plus
# large que haut au ventre ; un rayon unique l'aurait rendu en tube.
#
# Les profils sont ecrits en Y MONDE, releves colonne par colonne sur le profil
# de la planche, plutot qu'en t abstrait : chaque ligne se relit a cote d'elle.
#
# Le tronc commence DANS la tete (Y 0,50) : sa pointe avant est enfouie, et ce
# qui en sort sous la machoire est le poitrail.
BODY_PROFILE = [
	# Y       dessus  dessous  demi-largeur
	(0.50,    0.95,   0.95,    0.000),  # pointe avant, dans le crane
	(0.44,    1.12,   0.60,    0.230),
	(0.32,    1.19,   0.33,    0.390),  # le poitrail, sous la machoire
	(0.16,    1.16,   0.25,    0.460),  # px 565 : dos 1,07 — ventre 0,29
	(-0.02,   1.07,   0.25,    0.480),
	(-0.20,   0.99,   0.28,    0.455),  # px 625 : le creux du dos, 0,98
	(-0.38,   1.00,   0.36,    0.440),  # px 665 : le ventre remonte, 0,40
	(-0.56,   1.02,   0.40,    0.460),  # la hanche
	(-0.74,   1.03,   0.45,    0.450),  # px 765 : la croupe, 1,05
	(-0.88,   0.98,   0.53,    0.370),
	(-0.955,  0.90,   0.62,    0.240),
	(-1.00,   0.76,   0.76,    0.000),  # pointe arriere
]
BODY_Y_FRONT = BODY_PROFILE[0][0]
BODY_Y_BACK = BODY_PROFILE[-1][0]

# Aplatissement du ventre — multiplicateur DOUX, comme le chien d'avant.
BELLY_FLAT = 0.10

# Les sections, en Y. Resserrees aux deux bouts, ou le profil tourne vite.
BODY_SECTIONS = [0.47, 0.42, 0.36, 0.28, 0.18, 0.06, -0.08, -0.22, -0.36, -0.50,
		-0.64, -0.76, -0.86, -0.925, -0.97]
BODY_N_U = 20

# ─── LA TETE ──────────────────────────────────────────────────────────────────
#
# Un ellipsoide, plus large en bas qu'en haut : la planche de face dessine une
# tete en POIRE, les bajoues tirant les joues vers l'exterieur. Le front sur la
# planche est a px 400 (Y 0,70), l'occiput a px 530 (Y 0,15), le crane a px 29
# (z 1,38).
HEAD_CENTER = Vector((0.0, 0.43, 1.10))
HEAD_RADIUS = Vector((0.30, 0.28, 0.28))
# Elargissement des joues, applique a la moitie basse seulement.
HEAD_JOWL = 0.14
HEAD_N_U = 18
HEAD_N_V = 10

# ─── LE MUSEAU ────────────────────────────────────────────────────────────────
#
# Un BLOC, pas un chanfrein. La planche de profil : babines de z 0,79 a 1,16,
# truffe a px 330. Section en SUPER-ELLIPSE (exposant < 1 = plus carre) : c'est
# ce qui separe des babines de basset du museau conique du chien d'avant.
#
# ⚠️ SON DESSUS EST BORNE PAR LES YEUX, PAS PAR LE PROFIL. La planche de face pose
# les yeux a z 1,17, juste au-dessus des coins du museau, et le brun du crane
# descend en V jusqu'a la truffe. Au premier jet le museau affleurait a 1,18 :
# il aurait mange les yeux peints. Il s'arrete a 1,12.
MUZZLE_START = Vector((0.0, 0.58, 0.96))   # la racine, ENFOUIE dans le crane
MUZZLE_END = Vector((0.0, 1.00, 0.94))     # la truffe
MUZZLE_HALF_W = 0.215
MUZZLE_HALF_H = 0.170
MUZZLE_POW = 0.72
# Rayon relatif le long du museau ; il ne s'effile presque pas — un bloc.
MUZZLE_SCALE_KEYS = [(0.00, 1.00), (0.45, 1.00), (0.75, 0.95), (1.00, 0.84)]
MUZZLE_CAP_START = 0.70
MUZZLE_N_U = 16
MUZZLE_N_V = 6

# ─── LES OREILLES ─────────────────────────────────────────────────────────────
#
# Accrochees haut sur les cotes du crane, elles pendent JUSQU'A z 0,62 — sous la
# machoire, ce que la planche montre sur les quatre vues. Meme geste que le
# chien d'avant : le PLAN TOURNE le long de la longueur, la face large regarde
# le ciel a la racine et dehors au bout, sinon une camera qui plonge les voit
# par la tranche.
EAR_ANCHOR_DIR = Vector((0.80, -0.05, 0.62))  # sur l'ellipsoide de la tete
EAR_SINK = 0.05
EAR_PATH = [
	(0.000, 0.000, 0.000),
	(0.090, 0.000, -0.070),
	(0.165, 0.010, -0.230),
	(0.195, 0.020, -0.430),
	(0.165, 0.030, -0.610),
]
EAR_FACE_BASE = (0.35, 0.10, 0.93)
EAR_FACE_TIP = (0.96, 0.04, 0.28)
EAR_WIDTH_KEYS = [(0.00, 0.085), (0.20, 0.150), (0.50, 0.172), (0.80, 0.150),
		(1.00, 0.075)]
EAR_THICK_KEYS = [(0.00, 0.050), (0.40, 0.050), (1.00, 0.030)]
EAR_N_U = 10
EAR_N_V = 6

# ─── LES PATTES ET LES PIEDS ──────────────────────────────────────────────────
#
# ⚠️ LES PIEDS SONT DES COQUES A PART, et c'est ce qui fait le basset. La
# planche les dessine ENORMES — 0,31 m de large, plus larges que la patte qui
# les porte — et clairs. Un tube qui s'evase sortirait en pied d'elephant ; un
# ellipsoide pose au bout donne la masse ronde, et l'intersection avec la patte
# trace la ligne de cheville que la planche dessine.
#
# Front a px 440-545 (Y 0,30), arriere a px 685-800 (Y -0,72). Les arrieres
# ont une CUISSE : la planche de dos montre une croupe large qui descend en
# deux masses.
LEGS = [
	# Y      x      cuisse  bas     derive
	(0.30,  0.270,  0.205,  0.165,  0.040),   # avant
	(-0.70, 0.275,  0.270,  0.165,  0.010),   # arriere
]
# Le haut de la patte est un DOME enfoui dans le tronc, pas un eventail plat :
# a plat il ressortait sur le flanc en RECTANGLE, la cuisse etant plus large que
# le tronc a cette hauteur.
LEG_TOP_Z = 0.78
LEG_DOME = 0.30
LEG_N_U = 9
LEG_N_V = 5

# ⚠️ LE PIED S'ARRETE A 0,045 ET NON A ZERO — la regle du chien d'avant : pose a
# plat, il se ferait trancher son encre par le plan du parquet.
FOOT_RADIUS = Vector((0.170, 0.210, 0.110))
FOOT_FORWARD = 0.05
FOOT_BOTTOM_Z = 0.045
FOOT_N_U = 10
FOOT_N_V = 5

# ─── LA QUEUE ─────────────────────────────────────────────────────────────────
#
# EN SABRE, haute, comme la planche — et c'est a rebours de la lecon de la
# souris ("une courbe qui monte ne se voit pas sous une camera qui plonge"). Le
# pari est qu'elle part en ARRIERE autant qu'elle monte : une diagonale ne se
# projette pas dans le dos qui la porte. A juger au banc, sur les 8 directions.
TAIL_PATH = [
	(0.000, -0.840, 0.930),
	(0.000, -1.000, 1.030),
	(0.000, -1.120, 1.190),
	(0.000, -1.170, 1.370),
	(0.000, -1.140, 1.510),
]
TAIL_R0 = 0.100
TAIL_R1 = 0.055
TAIL_TAPER_POW = 0.70
TAIL_N_U = 9
TAIL_N_V = 8

# ─── LES MATIERES ─────────────────────────────────────────────────────────────
PELAGE = "#965A31"
MARQUES = "#CC9C62"

REFERENCES = [
	("parquet clair", "#F5ECD8"),
	("parquet fonce", "#E8D4A8"),
	("souris", "#A89684"),
	("chat", "#4A4038"),
	("encre", "#3D2B1A"),
]
INK = "#3D2B1A"

SHADOW_HUE_SHIFT = -0.02
SHADOW_SATURATION = 1.15
SHADOW_VALUE = 0.65

RAMP_SPLIT = 0.52

MAT_PELAGE, MAT_MARQUES = 0, 1

# Le gabarit de collision de brute.tscn — pour que le rapport et les gardes
# disent si le modele y tient. JAMAIS pour le modifier.
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
	"""Le `warm_shadow()` de cel_core.gdshaderinc, en Python."""
	import colorsys

	h, s, v = colorsys.rgb_to_hsv(*rgb)
	h = (h + SHADOW_HUE_SHIFT) % 1.0
	s = min(1.0, s * SHADOW_SATURATION)
	return colorsys.hsv_to_rgb(h, s, v * SHADOW_VALUE)


# -------------------------------------------------------------------- profils

def spline(keys, t: float) -> float:
	"""Catmull-Rom NON UNIFORME sur une liste de (t, valeur) — voir build_dog.py."""
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


# Les trois profils du tronc, cles en -Y pour que le parametre CROISSE.
_TOP = [(-y, top) for y, top, _, _ in BODY_PROFILE]
_BOTTOM = [(-y, bottom) for y, _, bottom, _ in BODY_PROFILE]
_HALF_W = [(-y, w) for y, _, _, w in BODY_PROFILE]


def path_point(path, s: float) -> Vector:
	"""Catmull-Rom sur une liste de triplets, parametree par s dans [0, 1]."""
	n = len(path) - 1.0
	return Vector([
		spline([(i / n, p[k]) for i, p in enumerate(path)], s)
		for k in range(3)
	])


def signed_pow(x: float, p: float) -> float:
	return math.copysign(abs(x) ** p, x)


def body_section(y: float):
	"""(centre z, demi-hauteur, demi-largeur) du tronc en Y."""
	top = spline(_TOP, -y)
	bottom = spline(_BOTTOM, -y)
	return (top + bottom) * 0.5, max(0.0, (top - bottom) * 0.5), max(0.0, spline(_HALF_W, -y))


def body_point(y: float, a: float) -> Vector:
	"""Un point du tronc. `a` = 0 sur le dos, +-pi/2 sur les flancs, pi au ventre."""
	cz, hh, hw = body_section(y)
	up = math.cos(a)
	flat = 1.0 - BELLY_FLAT * max(0.0, -up)

	return Vector((hw * math.sin(a), y, cz + hh * up * flat))


def head_point(polar: float, azimuth: float) -> Vector:
	"""Un point de la tete. `polar` = 0 au sommet, pi dessous ; azimut 0 = +Y."""
	sp = math.sin(polar)
	cp = math.cos(polar)
	jowl = 1.0 + HEAD_JOWL * max(0.0, -cp)

	return HEAD_CENTER + Vector((
		HEAD_RADIUS.x * sp * math.sin(azimuth) * jowl,
		HEAD_RADIUS.y * sp * math.cos(azimuth),
		HEAD_RADIUS.z * cp,
	))


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
	"""Repere a TRANSPORT PARALLELE le long d'une polyligne — jamais Frenet."""
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
	"""Fermeture ARRONDIE sur la fin d'un tube — un quart de cercle, pas un cone."""
	if k <= start:
		return 1.0

	x = (k - start) / (1.0 - start)
	return math.sqrt(max(0.0, 1.0 - x * x))


# ------------------------------------------------------------------ geometrie

class Builder:
	"""Un bmesh + la liste parallele des infos de peinture (voir build_dog.py)."""

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

	def tube(self, rings, first, last, material_of, cap_first: int, cap_last: int):
		"""Relie des anneaux de meme taille et ferme les deux bouts en eventail."""
		n = len(rings[0])

		for i in range(n):
			nxt = (i + 1) % n
			self.face((first, rings[0][nxt], rings[0][i]), cap_first)
			self.face((last, rings[-1][i], rings[-1][nxt]), cap_last)

		for j, (lower, upper) in enumerate(zip(rings, rings[1:])):
			material = material_of(j)

			for i in range(n):
				nxt = (i + 1) % n
				self.face((lower[i], lower[nxt], upper[nxt], upper[i]), material)


def build_body(b: Builder) -> None:
	front = b.vert(body_point(BODY_Y_FRONT, 0.0), {"shell": "corps", "y": BODY_Y_FRONT, "a": 0.0})
	rings = []

	for y in BODY_SECTIONS:
		rings.append([
			b.vert(body_point(y, a), {"shell": "corps", "y": y, "a": a})
			for a in (math.tau * i / float(BODY_N_U) for i in range(BODY_N_U))
		])

	rump = b.vert(body_point(BODY_Y_BACK, 0.0), {"shell": "corps", "y": BODY_Y_BACK, "a": 0.0})
	b.tube(rings, front, rump, lambda j: MAT_PELAGE, MAT_PELAGE, MAT_PELAGE)


def build_head(b: Builder) -> None:
	top = b.vert(head_point(0.0, 0.0), {"shell": "tete", "polar": 0.0})
	rings = []

	for j in range(1, HEAD_N_V):
		polar = math.pi * j / float(HEAD_N_V)
		rings.append([
			b.vert(head_point(polar, math.tau * i / float(HEAD_N_U)), {"shell": "tete", "polar": polar})
			for i in range(HEAD_N_U)
		])

	bottom = b.vert(head_point(math.pi, 0.0), {"shell": "tete", "polar": math.pi})
	b.tube(rings, top, bottom, lambda j: MAT_PELAGE, MAT_PELAGE, MAT_PELAGE)


def build_muzzle(b: Builder) -> None:
	"""Un bloc a section super-elliptique, enfoui dans le crane, ferme en rond."""
	axis = MUZZLE_END - MUZZLE_START
	u, v, _ = frame(axis)
	samples = [j / float(MUZZLE_N_V) for j in range(1, MUZZLE_N_V + 1)]
	rings = []

	for s in samples:
		k = spline(MUZZLE_SCALE_KEYS, s) * round_cap(s, MUZZLE_CAP_START)
		ring = []

		for i in range(MUZZLE_N_U):
			th = math.tau * i / float(MUZZLE_N_U)
			ring.append(b.vert(
				MUZZLE_START + axis * s
				+ u * (MUZZLE_HALF_W * k * signed_pow(math.cos(th), MUZZLE_POW))
				+ v * (MUZZLE_HALF_H * k * signed_pow(math.sin(th), MUZZLE_POW)),
				{"shell": "museau", "s": s},
			))

		rings.append(ring)

	root = b.vert(MUZZLE_START, {"shell": "museau", "s": 0.0})
	tip = b.vert(MUZZLE_END, {"shell": "museau", "s": 1.0})
	b.tube(rings, root, tip, lambda j: MAT_MARQUES, MAT_MARQUES, MAT_MARQUES)


def build_ear(b: Builder, side: float) -> None:
	"""Un volet tombant dont le PLAN TOURNE le long de sa longueur."""
	d = EAR_ANCHOR_DIR.normalized()
	d = Vector((d.x * side, d.y, d.z))
	surface = HEAD_CENTER + Vector((d.x * HEAD_RADIUS.x, d.y * HEAD_RADIUS.y, d.z * HEAD_RADIUS.z))
	anchor = surface - d * EAR_SINK

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
		face_dir = Vector([EAR_FACE_BASE[k] + (EAR_FACE_TIP[k] - EAR_FACE_BASE[k]) * s for k in range(3)])
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
	b.tube(rings, root, tip, lambda j: MAT_PELAGE, MAT_PELAGE, MAT_PELAGE)


def foot_center(y: float, x: float, drift: float) -> Vector:
	return Vector((x + drift, y + FOOT_FORWARD, FOOT_BOTTOM_Z + FOOT_RADIUS.z))


def build_leg(b: Builder, side: float, y: float, x: float, r_top: float, r_low: float,
		drift: float) -> None:
	"""Un moignon enfonce dans le ventre, qui finit DANS le pied."""
	foot = foot_center(y, x, drift)
	start = Vector((x * side, y, LEG_TOP_Z))
	end = Vector((foot.x * side, y, foot.z))

	samples = [j / float(LEG_N_V) for j in range(LEG_N_V + 1)]
	points = [start.lerp(end, k) for k in samples]
	frames = parallel_frames(points)
	rings = []

	for j, k in enumerate(samples):
		u, v, _ = frames[j]
		r = r_top + (r_low - r_top) * min(1.0, max(0.0, k - LEG_DOME) / 0.45)
		r *= round_cap(1.0 - k, 1.0 - LEG_DOME)
		rings.append([
			b.vert(points[j] + u * (r * math.cos(th)) + v * (r * math.sin(th)),
					{"shell": "patte", "k": k, "side": side})
			for th in (math.tau * i / float(LEG_N_U) for i in range(LEG_N_U))
		])

	top = b.vert(points[0], {"shell": "patte", "k": 0.0, "side": side})
	bottom = b.vert(points[-1], {"shell": "patte", "k": 1.0, "side": side})
	b.tube(rings, top, bottom, lambda j: MAT_PELAGE, MAT_PELAGE, MAT_PELAGE)


def build_foot(b: Builder, side: float, y: float, x: float, drift: float) -> None:
	"""Un pied : ellipsoide clair, plus long que large, pose a 0,045 du sol."""
	c = foot_center(y, x, drift)
	c.x *= side

	def point(polar, azimuth):
		return c + Vector((
			FOOT_RADIUS.x * math.sin(polar) * math.sin(azimuth),
			FOOT_RADIUS.y * math.sin(polar) * math.cos(azimuth),
			FOOT_RADIUS.z * math.cos(polar),
		))

	top = b.vert(point(0.0, 0.0), {"shell": "pied", "polar": 0.0})
	rings = []

	for j in range(1, FOOT_N_V):
		polar = math.pi * j / float(FOOT_N_V)
		rings.append([
			b.vert(point(polar, math.tau * i / float(FOOT_N_U)), {"shell": "pied", "polar": polar})
			for i in range(FOOT_N_U)
		])

	bottom = b.vert(point(math.pi, 0.0), {"shell": "pied", "polar": math.pi})
	b.tube(rings, top, bottom, lambda j: MAT_MARQUES, MAT_MARQUES, MAT_MARQUES)


def build_tail(b: Builder) -> None:
	samples = [j / float(TAIL_N_V) for j in range(TAIL_N_V + 1)]
	points = [path_point(TAIL_PATH, s) for s in samples]
	frames = parallel_frames(points)
	rings = []

	for j, s in enumerate(samples):
		u, v, _ = frames[j]
		r = (TAIL_R0 + (TAIL_R1 - TAIL_R0) * (s ** TAIL_TAPER_POW)) * round_cap(s, 0.86)
		rings.append([
			b.vert(points[j] + u * (r * math.cos(th)) + v * (r * math.sin(th)),
					{"shell": "queue", "s": s})
			for th in (math.tau * i / float(TAIL_N_U) for i in range(TAIL_N_U))
		])

	root = b.vert(points[0], {"shell": "queue", "s": 0.0})
	tip = b.vert(points[-1], {"shell": "queue", "s": 1.0})
	b.tube(rings, root, tip, lambda j: MAT_PELAGE, MAT_PELAGE, MAT_PELAGE)


def build_mesh():
	b = Builder()

	build_body(b)
	build_head(b)
	build_muzzle(b)
	build_ear(b, 1.0)
	build_ear(b, -1.0)

	for y, x, r_top, r_low, drift in LEGS:
		for side in (1.0, -1.0):
			build_leg(b, side, y, x, r_top, r_low, drift)
			build_foot(b, side, y, x, drift)

	build_tail(b)

	bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces)

	for face in b.bm.faces:
		face.smooth = True

	mesh = bpy.data.meshes.new(MESH_OBJECT)
	b.bm.to_mesh(mesh)
	b.bm.free()

	return mesh, b.info


# --------------------------------------------------------------- Attr_Style

# Le plancher du canal G, PAR COQUE. 0,30 partout (la regle du chien d'avant),
# SAUF l'oreille, qui descend a 0 : c'est ce qui la tient en ombre permanente.
G_FLOOR = {"oreille": 0.0}


def paint(mesh, info):
	"""Peint R, G et B. Contrat des canaux : "Convention Blender" §4.

	Tout se decide sur la position PARAMETRIQUE et la normale, jamais sur
	l'eclairage : le basset tourne pour suivre sa cible.
	"""
	attr = mesh.color_attributes.get(ATTRIBUTE)

	if attr is None:
		attr = mesh.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="POINT")

	stats = {"r": [2.0, -1.0], "g": [2.0, -1.0], "b": [2.0, -1.0]}

	for i, vertex in enumerate(mesh.vertices):
		data = info[i]
		shell = data["shell"]
		n = vertex.normal

		# La base sous 1,0 partout — la lecon de la croquette (voir build_dog.py).
		r = 0.84 - 0.16 * max(0.0, n.z) + 0.10 * max(0.0, -n.z)
		g = 0.52 - 0.13 * max(0.0, -n.z) + 0.04 * max(0.0, n.z)
		b = 0.0

		if shell == "corps":
			up = math.cos(data["a"])
			# L'OMBRE DU FLANC — une forme DESSINEE (§2ter.2). Sur un ventre qui
			# traine, c'est elle qui separe le tronc du sol bien plus que l'ombre
			# de contact, que le ventre couvre presque entiere.
			g -= 0.14 * max(0.0, -up - 0.10) / 0.90
			# La cassure d'epaule, au-dessus des pattes avant.
			g -= 0.07 * math.exp(-((data["y"] - 0.20) / 0.10) ** 2) * max(0.0, -up + 0.3)

		elif shell == "tete":
			# La bajoue est dans l'ombre du crane, quelle que soit la lumiere.
			g -= 0.10 * max(0.0, -math.cos(data["polar"]))

		elif shell == "museau":
			# Le STOP : le trait appuie la racine, et le front y porte son ombre.
			r += 0.14 * max(0.0, 1.0 - data["s"] / 0.30)
			g -= 0.09 * max(0.0, 1.0 - data["s"] / 0.40)

		elif shell == "oreille":
			# ⭐ L'OREILLE EST EN OMBRE PERMANENTE : la planche la peint plus
			# sombre que le pelage. G = 0 donne un biais de -1, que N.L ne
			# depasse jamais — l'oreille sort dans le ton d'ombre chaud du pelage,
			# et c'est une matiere de moins (2 draw calls de moins par bete).
			g = 0.0
			r += 0.18 * data["edge"] + 0.10 * data["s"]

		elif shell == "patte":
			r = 0.90
			g = 0.48 - 0.14 * max(0.0, -n.x * data["side"]) - 0.10 * max(0.0, -n.z)

		elif shell == "pied":
			# Le dessous du pied est dans l'ombre, le dessus en lumiere : la
			# frontiere tombe sur le flanc, la ou la planche dessine les doigts.
			r = 0.92
			g = 0.52 - 0.18 * max(0.0, -math.cos(data["polar"]))

		elif shell == "queue":
			r = 0.88 + 0.10 * data["s"]
			g = 0.48 - 0.10 * max(0.0, -n.z)

		# Le plancher de R a 0,68 partout — sous lui le trait tombe sous 1 px.
		r = min(1.0, max(0.68, r))
		g = min(0.58, max(G_FLOOR.get(shell, 0.30), g))

		attr.data[i].color = (r, g, b, 1.0)

		for key, value in (("r", r), ("g", g), ("b", b)):
			stats[key][0] = min(stats[key][0], value)
			stats[key][1] = max(stats[key][1], value)

	mesh.color_attributes.active_color_name = ATTRIBUTE
	mesh.color_attributes.default_color_name = ATTRIBUTE

	return stats


# ---------------------------------------------------------------- materiaux

def toon_material(name, code):
	"""La chaine de "Convention Blender" §5.1, montee au node pres."""
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


def build_object(name: str = MESH_OBJECT):
	"""Maillage + materiaux + peinture, SANS toucher a la scene.

	C'est ce que l'atelier (le Blender ouvert, via le MCP) appelle : tout ce qui
	precede `main()` est sans effet de bord sur ce qui existe deja.
	"""
	mesh, info = build_mesh()

	for mat_name, code in (("pelage", PELAGE), ("marques", MARQUES)):
		mesh.materials.append(toon_material(mat_name, code))

	stats = paint(mesh, info)
	return bpy.data.objects.new(name, mesh), info, stats


# ------------------------------------------------------------------- mesures

def measure(mesh, info, stats) -> dict:
	tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
	lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
	hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])

	faces = {}
	for polygon in mesh.polygons:
		faces[polygon.material_index] = faces.get(polygon.material_index, 0) + 1

	shells = {}
	for data in info:
		shells[data["shell"]] = shells.get(data["shell"], 0) + 1

	attr = mesh.color_attributes.get(ATTRIBUTE)
	head_top = HEAD_CENTER.z + HEAD_RADIUS.z
	hip = body_section(-0.74)
	nose_to_rump = MUZZLE_END.y - BODY_Y_BACK

	return {
		"verts": len(mesh.vertices),
		"faces": len(mesh.polygons),
		"tris": tris,
		"lo": tuple(round(c, 3) for c in lo),
		"hi": tuple(round(c, 3) for c in hi),
		"shells": shells,
		"faces_per_material": [faces.get(0, 0), faces.get(1, 0)],
		"attr_domain": attr.domain if attr else None,
		"attr_count": len(attr.data) if attr else 0,
		"r": stats["r"], "g": stats["g"], "b": stats["b"],
		"head_top": head_top,
		"hip_top": hip[0] + hip[1],
		"belly": body_section(-0.02)[0] - body_section(-0.02)[1] * (1.0 - BELLY_FLAT),
		"nose_to_rump": nose_to_rump,
	}


def guards(m: dict) -> list:
	"""Les refus chiffres. Une liste vide = le .blend peut s'ecrire."""
	fails = []

	if m["attr_domain"] != "POINT":
		fails.append("Attr_Style n'est pas sur le domaine POINT (%s)" % m["attr_domain"])
	if m["attr_count"] != m["verts"]:
		fails.append("Attr_Style couvre %d sommets sur %d" % (m["attr_count"], m["verts"]))
	if m["head_top"] <= m["hip_top"]:
		fails.append("le crane (%.3f) n'est pas au-dessus de la croupe (%.3f)"
				% (m["head_top"], m["hip_top"]))
	if m["nose_to_rump"] > HURTBOX_RADIUS * 2.0 * 1.05:
		fails.append("truffe->croupe %.3f deborde la hurtbox (diametre %.2f)"
				% (m["nose_to_rump"], HURTBOX_RADIUS * 2.0))
	if m["lo"][2] < FOOT_BOTTOM_Z - 1.0e-3:
		fails.append("le modele descend a %.3f, sous le plancher des pieds (%.3f)"
				% (m["lo"][2], FOOT_BOTTOM_Z))
	if m["hi"][2] > BODY_CYLINDER_HEIGHT:
		fails.append("hauteur %.3f au-dessus du cylindre de collision (%.2f)"
				% (m["hi"][2], BODY_CYLINDER_HEIGHT))
	if m["r"][0] < 0.68 - 1.0e-6:
		fails.append("canal R sous le plancher de 0,68 (%.2f)" % m["r"][0])
	if m["b"][1] > 0.0:
		fails.append("canal B non nul (%.2f) — aucun accent sur un ennemi" % m["b"][1])

	return fails


# -------------------------------------------------------------------- scene

def setup_scene():
	scene = bpy.context.scene

	for candidate in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
		try:
			scene.render.engine = candidate
			break
		except TypeError:
			continue

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


def report(m: dict) -> None:
	print("\n[build_basset] %s" % MESH_OBJECT)
	print("  %d sommets, %d faces, %d tris  (chien d'avant 1 610, souris 1 132, chat 5 404)"
			% (m["verts"], m["faces"], m["tris"]))
	print("  emprise  X %.3f a %.3f   Y %.3f a %.3f   Z %.3f a %.3f"
			% (m["lo"][0], m["hi"][0], m["lo"][1], m["hi"][1], m["lo"][2], m["hi"][2]))
	print("  hauteur %.3f   longueur %.3f   largeur %.3f"
			% (m["hi"][2], m["hi"][1] - m["lo"][1], m["hi"][0] - m["lo"][0]))
	print("  sommets par coque : %s" % m["shells"])
	print("  faces par matiere : pelage %d, marques %d  (2 surfaces = 4 draw calls)"
			% tuple(m["faces_per_material"]))
	print("  Attr_Style  R %.2f-%.2f   G %.2f-%.2f   B %.2f-%.2f"
			% (m["r"][0], m["r"][1], m["g"][0], m["g"][1], m["b"][0], m["b"][1]))

	print("  couleurs sRGB (valeur TSV / saturation)")
	for name, code in (("pelage", PELAGE), ("marques", MARQUES)):
		print("    %-8s %s  V %.2f  S %2d %%"
				% (name, code, hex_value(code), round(hex_saturation(code) * 100)))
	print("    ecarts au pelage : %s"
			% "  ".join("%s %+.2f" % (name, hex_value(code) - hex_value(PELAGE))
					for name, code in REFERENCES))
	print("    marques vs parquet fonce %+.2f  (doit rester sous -0,10)"
			% (hex_value(MARQUES) - hex_value("#E8D4A8")))
	shadow_value = hex_value(PELAGE) * SHADOW_VALUE
	print("    ombre du pelage (= l'oreille) %.2f  vs  encre %.2f  (ecart %+.2f, l'encre "
			"doit rester SOUS)" % (shadow_value, hex_value(INK), shadow_value - hex_value(INK)))

	print("  crane %.3f  vs  croupe %.3f  (ecart %+.3f, doit rester > 0)"
			% (m["head_top"], m["hip_top"], m["head_top"] - m["hip_top"]))
	print("  ventre a %.3f   pied a %.3f" % (m["belly"], FOOT_BOTTOM_Z))
	print("  gabarit de brute.tscn — le modele s'y plie, jamais l'inverse")
	print("    truffe->croupe %.3f  vs hurtbox diam %.2f  (%+.0f %%)"
			% (m["nose_to_rump"], HURTBOX_RADIUS * 2.0,
			   m["nose_to_rump"] / (HURTBOX_RADIUS * 2.0) * 100.0 - 100.0))
	print("    largeur %.3f         vs cylindre diam %.2f"
			% (m["hi"][0] - m["lo"][0], BODY_CYLINDER_RADIUS * 2.0))
	print("    hauteur %.3f         vs cylindre h %.2f  (hurtbox centree a %.2f)"
			% (m["hi"][2], BODY_CYLINDER_HEIGHT, HURTBOX_CENTER_Z))


def main():
	clear_scene()
	setup_scene()

	obj, info, stats = build_object()

	collection = bpy.data.collections.new(COLLECTION)
	bpy.context.scene.collection.children.link(collection)
	collection.objects.link(obj)

	m = measure(obj.data, info, stats)
	report(m)
	fails = guards(m)

	if fails:
		sys.exit("ECHEC : " + " ; ".join(fails))

	if "--save" in sys.argv:
		OUTPUT.parent.mkdir(parents=True, exist_ok=True)
		bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
		print("  ecrit dans %s" % OUTPUT)
	else:
		print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


# Garde : l'atelier execute ce fichier sous un autre nom pour appeler
# `build_object()` SANS `clear_scene()` — voir "Integration Assets 3D" §3.
if __name__ == "__main__":
	main()
