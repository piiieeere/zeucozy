"""Construit la PLANTE EN POT — le 2e objet PROJETE du projet (2026-10-18).

    "<blender>" --background --factory-startup \
        --python tools/build_plant.py -- --save [--gabarit] [--texture [--force]]

D'apres `maquettes/plante_maquette.png` : un pot terracotta a bourrelet et UNE
masse de feuillage en œuf, posee dedans. Meme moule que la table basse
(`build_coffee_table.py`) — volume grossier, UV cuite a 44,02°, `Attr_Style`
R peint / G 0,5 / B 0,0, et le dessin dans une texture projetee.
"Visual Art Direction" §2quater, "Pipeline 3D" §1→§6, "Convention Blender" §12.

Elle remplace les DEUX boites pastel « plante » d'`arena.PROPS`, dans leur
emprise exacte : 1,4 x 1,4 m au sol, 2,6 m de haut. On ne change pas la place
d'un meuble en meme temps que sa nature — c'est la regle posee avec la table.

⭐ LES FEUILLES NE SONT PAS MODELISEES, ET C'EST LA REGLE (§12.1). Le volume ne
porte que la silhouette : un œuf a facettes et un pot. Les feuilles vivent dans
la peinture. ⚠️ Corollaire, et c'est ce qui a fait jeter la 1re planche : une
feuille PEINTE ne peut pas depasser du volume — le contour d'encre de Godot cerne
la GEOMETRIE, donc une pointe de feuille hors de l'œuf serait coupee net, et le
creux entre deux pointes rempli de vert par la cuisson.

⚠️ CE QUI CHANGE PAR RAPPORT A LA TABLE : L'OBJET EST ROND.

  * SECTION OCTOGONALE, a plat face a la camera — la meme que §12.7 retient
    pour les objets qui pivotent, et pour la meme raison : c'est le moins de
    facettes dont la silhouette reste ronde a taille de jeu (1,1 px pres).
    L'apotheme vaut la demi-emprise, donc la boite englobante fait EXACTEMENT
    1,4 x 1,4 m — ce que `arena._add_blocker` verifie a 0,01 pres.
  * 60 FACES AU LIEU DE 5 A 15 (§12.1). L'ecart est force par la rondeur : un
    œuf a 8 facettes de tour en a 34, un pot 26. Ce que §12.1 borne — ce que
    l'image doit couvrir — tient, lui : voir le compte « projetees » imprime au
    build.
  * DES FACETTES VISIBLES MAIS RASANTES. Sur une boite, les faces exclues du
    placage (§12.3) sont exactement de profil, donc d'epaisseur nulle a
    l'image. Sur un œuf, un anneau de facettes a 60-90° de l'axe reste visible
    au bord de la silhouette. Il part a l'aplat uni comme un flanc — ~13 % du
    rayon, soit ~4 px a taille de jeu.
  * DONC L'OCCULTATION SE RESOUT AU PIXEL. La table se peignait du plus
    lointain au plus proche ; ici l'œuf plonge DANS le pot, et le tri par
    centre de face se trompe a la jointure. Le gabarit et le placeholder sont
    rendus avec un tampon de profondeur.
  * DEUX CARRES D'APLAT dans la bande du bas, un par masse : le feuillage a
    gauche, le pot a droite. UN seul materiau quand meme — le calcul de la
    table tient toujours (une surface de plus = un draw call et un contour de
    plus, sur un meuble pose par dizaines).

⛔ AUCUN NŒUD IMAGE DANS LE MATERIAU BLENDER — voir `build_coffee_table.py` :
la texture reste HORS du .glb ("Pipeline 3D" §2).
"""

import math
import random
import struct
import sys
import zlib
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/prop_plante_v1.blend")
# ⚠️ PLUS LA PLANTE DU JEU depuis le 2026-10-18, le jour meme : c'est le modele
# Tripo retravaille par `build_plant_tripo.py` qui porte `prop_plante.glb` et
# `prop_plante.png`. Celle-ci est gardee, comme `build_dog.py` — d'ou les noms
# `_oeuf`, qui l'empechent d'ecraser la plante du jeu si on la rejoue.
# Export : `export_prop.py -- --mesh MSH_plante --out prop_plante_oeuf.glb`.
TEXTURE = ROOT / "assets" / "textures" / "prop_plante_oeuf.png"
GABARIT = ROOT / "maquettes" / "plante_gabarit.png"

COLLECTION = "prop_plante"
MESH_OBJECT = "MSH_plante"
ATTRIBUTE = "Attr_Style"
MATERIAL = "PAINT_plante"

CROWN = "feuillage"
POT = "pot"

# ---------------------------------------------------------------- dimensions
#
# Relevees sur la maquette, a l'echelle de ses propres cotes : 2,6 m en tout,
# pot 0,9 x 1,0, feuillage 1,7 x 1,4.

FOOTPRINT = 1.4       # X et Y — l'emprise que `arena.PROPS` declare deja
HEIGHT = 2.6
SIDES = 8

# Le feuillage : (hauteur, apotheme). Un œuf plus large au tiers bas, comme la
# maquette, qui PLONGE dans le pot — sa base (0,85) est sous le bord (0,90).
# C'est l'interpenetration du piege n°2, et elle est voulue : la coque inversee
# y pose un trait, et ce trait est la ligne ou le feuillage sort du pot.
CROWN_RINGS = [
    (0.85, 0.44),
    (1.20, 0.63),
    (1.65, FOOTPRINT * 0.5),
    (2.20, 0.58),
    (HEIGHT, 0.28),
]

# Le pot : le bourrelet (0,90 → 0,74), un retrait vers l'interieur, puis le
# corps qui s'evase vers le haut. Le galbe en bol de la maquette n'est PAS
# modelise : il se peint, comme les feuilles.
POT_TOP = 0.90
RIM_BOTTOM = 0.74
RIM_APOTHEM = 0.50
BODY_TOP_APOTHEM = 0.46
BASE_APOTHEM = 0.35

# ------------------------------------------------------------------ la projection
#
# Copie conforme de `build_coffee_table.py` — "Convention Blender" §12.2.
# atan2(38*sin(45) - 0,9 ; 38*cos(45)) = 44,02°, `look_height` comprise.

PITCH = math.radians(44.02)
VIEW = Vector((0.0, math.cos(PITCH), -math.sin(PITCH)))
RIGHT = Vector((1.0, 0.0, 0.0))
UP = RIGHT.cross(VIEW)

# Au-dela de 2x d'etirement, une face part a l'aplat uni (§12.3).
FACING_MIN = 0.5

FRAME_MARGIN = 0.08
DENSITY = 96.0
BAND_PIXELS = 24

# Les deux carres d'aplat, en fraction de largeur : feuillage a gauche, pot a
# droite. Le milieu de la bande (la ou `bake_illustration` cherche ses reperes)
# reste de la matiere des deux cotes.
SWATCH_U = {CROWN: (0.08, 0.42), POT: (0.58, 0.92)}

# ------------------------------------------------------------------- palette
#
# Deux tons par masse (§4.8, contrainte 4).
#
# ⚠️ LE FEUILLAGE N'EST PAS EN SAUGE #C8E4B8, alors que les deux prompts le
# demandaient. La sauge tombe a 0,86 de luma — celle du parquet (0,85-0,91) :
# la plante se serait fondue dans le sol, exactement le defaut que la table
# basse avait evite en prenant l'ambre. Le vert foret de §4 (#88B888, 0,67)
# s'en detache, et c'est aussi le ton que la maquette donne a ses feuilles.
LEAF = "#88B888"
LEAF_SHADOW = "#5E8A55"     # vert foret assombri, tire vers le jaune (ombre chaude)
POT_BASE = "#D46858"        # terracotta de §4
POT_SHADOW = "#B85649"      # celui de la maquette
SOIL = "#6B4A32"            # le liseré de terreau entre le bord et le feuillage
INK = "#3D2B1A"


# ------------------------------------------------------------------ couleurs

def srgb_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def hex_to_bytes(code: str) -> tuple:
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4))


def hex_to_linear(code: str) -> tuple:
    return tuple(srgb_to_linear(c / 255.0) for c in hex_to_bytes(code))


# ------------------------------------------------------------------ geometrie

def ring(bm, z: float, apothem: float) -> list:
    """Huit sommets, une FACETTE a plat face a -Y — la camera regarde +Y.

    Les sommets sont a 22,5° + k·45° : la facette avant est alors centree sur
    -90°, perpendiculaire a l'axe, et la boite englobante vaut 2 x apotheme.
    """
    radius = apothem / math.cos(math.pi / SIDES)
    verts = []

    for k in range(SIDES):
        angle = math.pi / SIDES + k * 2.0 * math.pi / SIDES
        verts.append(bm.verts.new((radius * math.cos(angle), radius * math.sin(angle), z)))

    return verts


def loft(bm, rings: list, parts: list, part: str) -> None:
    """Relie les anneaux en bandes de quads, et ferme les deux bouts."""
    for lower, upper in zip(rings, rings[1:]):
        for k in range(SIDES):
            bm.faces.new((lower[k], lower[(k + 1) % SIDES], upper[(k + 1) % SIDES], upper[k]))
            parts.append(part)

    bm.faces.new(list(reversed(rings[0])))
    parts.append(part)
    bm.faces.new(rings[-1])
    parts.append(part)


def build_mesh():
    """Deux coques fermees, en shade_FLAT (§12.1). Rend aussi la masse de
    chaque face, dans l'ordre de creation — que `to_mesh` conserve."""
    bm = bmesh.new()
    parts = []

    pot = [
        ring(bm, 0.0, BASE_APOTHEM),
        ring(bm, RIM_BOTTOM, BODY_TOP_APOTHEM),
        ring(bm, RIM_BOTTOM, RIM_APOTHEM),
        ring(bm, POT_TOP, RIM_APOTHEM),
    ]
    loft(bm, pot, parts, POT)

    crown = [ring(bm, z, a) for z, a in CROWN_RINGS]
    loft(bm, crown, parts, CROWN)

    # Les anneaux sont crees dans un sens constant : les quads sortent tous
    # orientes pareil, les deux bouchons ont ete retournes en consequence. On
    # recalcule quand meme — c'est gratuit et ca ne se discute plus.
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    for face in bm.faces:
        face.smooth = False

    mesh = bpy.data.meshes.new(MESH_OBJECT)
    bm.to_mesh(mesh)
    bm.free()

    return mesh, parts


# ------------------------------------------------------------------ projection

def project(point) -> tuple:
    """Les deux produits scalaires de §12.2, en metres."""
    return (point.dot(RIGHT), point.dot(UP))


def facing(face) -> float:
    return face.normal.dot(-VIEW)


def frame_of(mesh) -> dict:
    """Le cadre de l'illustration — meme calcul que la table, sur tous les
    sommets (la silhouette est celle du volume entier)."""
    points = [project(v.co) for v in mesh.vertices]
    lo_u = min(p[0] for p in points)
    hi_u = max(p[0] for p in points)
    lo_v = min(p[1] for p in points)
    hi_v = max(p[1] for p in points)

    art_w = int(math.ceil((hi_u - lo_u + 2.0 * FRAME_MARGIN) * DENSITY / 4.0)) * 4
    art_h = int(math.ceil((hi_v - lo_v + 2.0 * FRAME_MARGIN) * DENSITY / 4.0)) * 4

    width = art_w
    height = art_h + BAND_PIXELS

    frame_w = width / DENSITY
    frame_h = height / DENSITY

    return {
        "x0": (lo_u + hi_u) * 0.5 - frame_w * 0.5,
        "y0": lo_v - FRAME_MARGIN - BAND_PIXELS / DENSITY,
        "w": frame_w,
        "h": frame_h,
        "px_w": width,
        "px_h": height,
        # En convention BLENDER (v = 0 en bas) ; l'exporteur retourne le V.
        "band_v": BAND_PIXELS / height,
    }


def unwrap(mesh, parts: list, frame: dict) -> dict:
    """UV0 : projection pour ce que la camera voit de face, aplat uni sinon.

    Une face envoyee a l'aplat recoit un petit polygone REGULIER au milieu du
    carre de sa masse — non degenere, sinon ses derivees d'UV seraient nulles
    et le niveau de mipmap arbitraire. Les bouchons sont des octogones : la
    numerotation par coin de quad de la table ne s'applique pas.
    """
    layer = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    counts = {"projete": 0, "aplat": 0, "visible": 0}

    for face in mesh.polygons:
        projected = facing(face) >= FACING_MIN
        loops = list(face.loop_indices)

        if projected:
            for loop_index in loops:
                u, v = project(mesh.vertices[mesh.loops[loop_index].vertex_index].co)
                layer.data[loop_index].uv = (
                    (u - frame["x0"]) / frame["w"],
                    (v - frame["y0"]) / frame["h"],
                )
        else:
            lo, hi = SWATCH_U[parts[face.index]]
            cu = (lo + hi) * 0.5
            cv = frame["band_v"] * 0.5
            ru = (hi - lo) * 0.25
            rv = frame["band_v"] * 0.25

            for corner, loop_index in enumerate(loops):
                angle = 2.0 * math.pi * corner / len(loops)
                layer.data[loop_index].uv = (cu + ru * math.cos(angle), cv + rv * math.sin(angle))

        counts["projete" if projected else "aplat"] += 1
        if facing(face) > 0.0:
            counts["visible"] += 1

    return counts


# -------------------------------------------------------------- Attr_Style

def paint(mesh) -> dict:
    """R seul est peint ; G a 0,5, B a 0,0 (§12.4) — les trois renseignes
    quand meme, voir `build_coffee_table.paint`.

    Meme profil que la table et le canape : le trait s'alourdit vers le bas,
    et s'epaissit a la jointure pot / feuillage, ou la plante se lit posee.
    """
    attr = mesh.color_attributes.get(ATTRIBUTE)

    if attr is None:
        attr = mesh.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="POINT")

    stats = {"r": [2.0, -1.0]}

    for i, vertex in enumerate(mesh.vertices):
        z = vertex.co.z
        r = 1.0 - 0.34 * min(1.0, z / HEIGHT)

        if RIM_BOTTOM - 0.001 <= z <= CROWN_RINGS[0][0] + 0.06:
            r += 0.14

        r = min(1.0, max(0.60, r))
        attr.data[i].color = (r, 0.5, 0.0, 1.0)

        stats["r"][0] = min(stats["r"][0], r)
        stats["r"][1] = max(stats["r"][1], r)

    mesh.color_attributes.active_color_name = ATTRIBUTE
    mesh.color_attributes.default_color_name = ATTRIBUTE

    return stats


# -------------------------------------------------------------- materiau

def paint_material(name: str, code: str):
    """Un aplat d'emission, sans nœud image. Le prefixe `PAINT_` dit a
    `cel_prop.gd` de monter `cel_painted` (§12.5)."""
    material = bpy.data.materials.new(name)

    if material.node_tree is None:
        material.use_nodes = True

    tree = material.node_tree
    tree.nodes.clear()

    emission = tree.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = hex_to_linear(code) + (1.0,)
    emission.location = (0, 0)

    output = tree.nodes.new("ShaderNodeOutputMaterial")
    output.location = (200, 0)

    tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    return material


# ------------------------------------------------------------------ PNG

def write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    """PNG RGB8, sans dependance."""

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    raw = bytearray()

    for row in range(height):
        raw.append(0)
        raw += pixels[row * width * 3:(row + 1) * width * 3]

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


# ---- le rasteriseur, AVEC tampon de profondeur ------------------------------
#
# Meme role que celui de la table : rendre gabarit et placeholder par la MEME
# projection que l'UV, depuis les MEMES sommets. Le tampon de profondeur est
# ce qu'il y a en plus — voir le bandeau, « l'occultation se resout au pixel ».
# Profondeur = p·VIEW : plus petite = plus proche.

class Canvas:
    def __init__(self, frame: dict):
        self.w = frame["px_w"]
        self.h = frame["px_h"]
        self.frame = frame
        self.data = bytearray(self.w * self.h * 3)
        self.depth = [math.inf] * (self.w * self.h)
        self.owner = [-1] * (self.w * self.h)

    def fill(self, color, y0: int = 0, y1: int = -1, x0: int = 0, x1: int = -1) -> None:
        y1 = self.h if y1 < 0 else y1
        x1 = self.w if x1 < 0 else x1

        for y in range(max(0, y0), min(self.h, y1)):
            for x in range(max(0, x0), min(self.w, x1)):
                offset = (y * self.w + x) * 3
                self.data[offset:offset + 3] = bytes(color)

    def put(self, x: int, y: int, color) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            offset = (y * self.w + x) * 3
            self.data[offset:offset + 3] = bytes(color)

    def to_pixels(self, point: tuple) -> tuple:
        """Metres projetes -> pixels, ligne 0 EN HAUT (le seul retournement)."""
        u = (point[0] - self.frame["x0"]) / self.frame["w"]
        v = (point[1] - self.frame["y0"]) / self.frame["h"]
        return (u * self.w, (1.0 - v) * self.h)

    def face(self, pixels: list, depths: list, color, owner: int) -> None:
        """Remplit un convexe avec test de profondeur.

        La profondeur d'une face plane est AFFINE en pixels : on resout son
        plan sur trois sommets, et on l'evalue partout. La dilatation d'une
        demi-diagonale (pour que deux faces voisines se touchent sans trou)
        extrapole ce meme plan, ce qui est exact pour une face plane.
        """
        plane = _depth_plane(pixels, depths)

        if plane is None:
            return

        a, b, c = plane
        xs = [p[0] for p in pixels]
        ys = [p[1] for p in pixels]
        cx = sum(xs) / len(xs)
        cy = sum(ys) / len(ys)
        grown = [(x + (0.75 if x > cx else -0.75), y + (0.75 if y > cy else -0.75))
                 for x, y in pixels]

        area = 0.0
        n = len(grown)

        for i in range(n):
            x0, y0 = grown[i]
            x1, y1 = grown[(i + 1) % n]
            area += x0 * y1 - x1 * y0

        sign = 1.0 if area >= 0.0 else -1.0
        color = bytes(color)

        for y in range(max(0, int(min(ys)) - 1), min(self.h, int(max(ys)) + 3)):
            for x in range(max(0, int(min(xs)) - 1), min(self.w, int(max(xs)) + 3)):
                px, py = x + 0.5, y + 0.5
                inside = True

                for i in range(n):
                    x0, y0 = grown[i]
                    x1, y1 = grown[(i + 1) % n]

                    if sign * ((x1 - x0) * (py - y0) - (y1 - y0) * (px - x0)) < 0.0:
                        inside = False
                        break

                if not inside:
                    continue

                index = y * self.w + x
                d = a * px + b * py + c

                if d < self.depth[index]:
                    self.depth[index] = d
                    self.owner[index] = owner
                    self.data[index * 3:index * 3 + 3] = color

    def segment(self, a: tuple, b: tuple, color, weight: float = 1.6,
                depths: tuple = None, owners: set = None) -> None:
        """Un trait. Avec `depths`, il ne passe que la ou il n'est pas cache ;
        avec `owners`, que sur les faces nommees (un trait INTERIEUR ne doit
        jamais deborder sur une autre masse)."""
        steps = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
        radius = weight * 0.5

        for i in range(steps + 1):
            t = i / steps
            cx = a[0] + (b[0] - a[0]) * t
            cy = a[1] + (b[1] - a[1]) * t

            if depths is not None:
                index = int(cy) * self.w + int(cx)
                if not (0 <= int(cx) < self.w and 0 <= int(cy) < self.h):
                    continue
                if depths[0] + (depths[1] - depths[0]) * t > self.depth[index] + 0.03:
                    continue

            for dy in range(-int(radius) - 1, int(radius) + 2):
                for dx in range(-int(radius) - 1, int(radius) + 2):
                    if dx * dx + dy * dy > radius * radius + 0.25:
                        continue

                    x, y = int(cx) + dx, int(cy) + dy

                    if owners is not None:
                        if not (0 <= x < self.w and 0 <= y < self.h):
                            continue
                        if self.owner[y * self.w + x] not in owners:
                            continue

                    self.put(x, y, color)


def _depth_plane(pixels: list, depths: list):
    """d = a·x + b·y + c, resolu sur les trois premiers sommets non alignes."""
    n = len(pixels)

    for i in range(n):
        for j in range(i + 1, n):
            for k in range(j + 1, n):
                (x0, y0), (x1, y1), (x2, y2) = pixels[i], pixels[j], pixels[k]
                det = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)

                if abs(det) < 1e-6:
                    continue

                d0, d1, d2 = depths[i], depths[j], depths[k]
                a = ((d1 - d0) * (y2 - y0) - (d2 - d0) * (y1 - y0)) / det
                b = ((x1 - x0) * (d2 - d0) - (x2 - x0) * (d1 - d0)) / det
                return (a, b, d0 - a * x0 - b * y0)

    return None


DIGITS = {
    "0": ("111", "101", "101", "101", "111"),
    "1": ("010", "110", "010", "010", "111"),
    "2": ("111", "001", "111", "100", "111"),
    "3": ("111", "001", "111", "001", "111"),
    "4": ("101", "101", "111", "001", "001"),
    "5": ("111", "100", "111", "001", "111"),
    "6": ("111", "100", "111", "101", "111"),
    "7": ("111", "001", "010", "010", "010"),
    "8": ("111", "101", "111", "101", "111"),
    "9": ("111", "101", "111", "001", "111"),
}


def stamp(canvas: Canvas, text: str, x: int, y: int, color, scale: int = 2) -> None:
    for index, char in enumerate(text):
        glyph = DIGITS.get(char)

        if glyph is None:
            continue

        for row, line in enumerate(glyph):
            for column, bit in enumerate(line):
                if bit == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            canvas.put(x + (index * 4 + column) * scale + sx,
                                       y + row * scale + sy, color)


def visible_faces(mesh, parts: list) -> list:
    """Toutes les faces tournees vers la camera, projetees OU a l'aplat : le
    tampon de profondeur decide de ce qui se voit, plus l'ordre."""
    faces = []

    for face in mesh.polygons:
        if facing(face) <= 0.0:
            continue

        corners = [mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices]
        faces.append({
            "index": face.index,
            "part": parts[face.index],
            "points": [project(p) for p in corners],
            "depths": [p.dot(VIEW) for p in corners],
            "normal": face.normal.copy(),
            "projected": facing(face) >= FACING_MIN,
        })

    return faces


def render_gabarit(mesh, parts: list, frame: dict, path: Path, scale: int = 3) -> None:
    """Le BLOCKOUT, dans le cadre exact de l'illustration — a donner au
    generateur (§4.9 : le blockout se REND, il ne se dessine pas).

    ⚠️ `scale` doit rester egal a `bake_illustration.GABARIT_SCALE` (3).

    Les facettes RASANTES — visibles mais parties a l'aplat — sont rendues
    plus sombres et sans numero : le generateur peut y peindre, rien de ce
    qu'il y mettra ne sera lu.
    """
    big = dict(frame)
    big["px_w"] = frame["px_w"] * scale
    big["px_h"] = frame["px_h"] * scale

    canvas = Canvas(big)
    canvas.fill((236, 232, 224))
    band_top = big["px_h"] - BAND_PIXELS * scale
    canvas.fill((120, 140, 112), band_top, big["px_h"], 0, big["px_w"] // 2)
    canvas.fill((150, 112, 100), band_top, big["px_h"], big["px_w"] // 2, big["px_w"])

    tones = [(196, 190, 180), (178, 172, 162), (160, 154, 144), (186, 180, 170)]
    faces = visible_faces(mesh, parts)

    for order, face in enumerate(faces):
        pixels = [canvas.to_pixels(p) for p in face["points"]]
        tone = tones[order % len(tones)] if face["projected"] else (120, 114, 106)
        canvas.face(pixels, face["depths"], tone, face["index"])

    for face in faces:
        pixels = [canvas.to_pixels(p) for p in face["points"]]
        n = len(pixels)

        for i in range(n):
            canvas.segment(pixels[i], pixels[(i + 1) % n], (60, 56, 50), 2.0,
                           depths=(face["depths"][i], face["depths"][(i + 1) % n]))

    number = 1

    for face in faces:
        if not face["projected"]:
            continue

        pixels = [canvas.to_pixels(p) for p in face["points"]]
        cx = int(sum(p[0] for p in pixels) / len(pixels))
        cy = int(sum(p[1] for p in pixels) / len(pixels))

        if 0 <= cx < canvas.w and 0 <= cy < canvas.h and canvas.owner[cy * canvas.w + cx] == face["index"]:
            stamp(canvas, str(number), cx - 6, cy - 8, (40, 36, 32), 3)
            number += 1

    write_png(path, big["px_w"], big["px_h"], canvas.data)


def render_placeholder(mesh, parts: list, frame: dict, path: Path) -> None:
    """Une illustration PROVISOIRE, peinte par le script — pour que le pont
    soit verifiable aujourd'hui, bout en bout. La vraie se depose au meme
    chemin, cuite par `bake_illustration.py`.

    Elle tient les contraintes de §4.8 : 44,02° par construction, deux tons
    par masse, ombre en forme decidee, aucun contour de silhouette. Les
    feuilles sont des amandes en 2e ton, DECOUPEES par le pochoir du
    feuillage : aucune ne deborde de l'œuf.
    """
    canvas = Canvas(frame)
    leaf = hex_to_bytes(LEAF)
    leaf_shadow = hex_to_bytes(LEAF_SHADOW)
    pot = hex_to_bytes(POT_BASE)
    pot_shadow = hex_to_bytes(POT_SHADOW)
    soil = hex_to_bytes(SOIL)
    ink = hex_to_bytes(INK)

    # Le fond du cadre prend deja la couleur de la masse voisine : au bord de
    # la silhouette, le filtrage ira y chercher un texel.
    rim_row = int(canvas.to_pixels((0.0, -RIM_APOTHEM * math.sin(PITCH)
                                    + POT_TOP * math.cos(PITCH)))[1])
    canvas.fill(leaf, 0, rim_row)
    canvas.fill(pot, rim_row, frame["px_h"])

    band_top = frame["px_h"] - BAND_PIXELS
    canvas.fill(leaf_shadow, band_top, frame["px_h"], 0, frame["px_w"] // 2)
    canvas.fill(pot_shadow, band_top, frame["px_h"], frame["px_w"] // 2, frame["px_w"])

    faces = visible_faces(mesh, parts)
    crown_faces = set()
    pot_faces = set()

    for face in faces:
        pixels = [canvas.to_pixels(p) for p in face["points"]]
        normal = face["normal"]

        if face["part"] == CROWN:
            crown_faces.add(face["index"])
            # Meme lumiere que le pot — d'en haut, un peu de face et de la
            # gauche : le dessous et le flanc droit passent au 2e ton.
            tone = leaf_shadow if normal.z < -0.2 or normal.x > 0.5 else leaf
        else:
            pot_faces.add(face["index"])
            if normal.z > 0.9:
                tone = soil                     # le dessus : terreau au bord
            elif normal.x > 0.35:
                tone = pot_shadow               # le flanc droit, a l'ombre
            else:
                tone = pot

        canvas.face(pixels, face["depths"], tone, face["index"])

    # ---- les feuilles : des amandes, deux tons, sur le feuillage seul -------
    rng = random.Random(20261018)
    lo_y = min(i // canvas.w for i, o in enumerate(canvas.owner) if o in crown_faces)
    hi_y = max(i // canvas.w for i, o in enumerate(canvas.owner) if o in crown_faces)
    length = 0.32 * DENSITY
    width = 0.20 * DENSITY

    for row in range(9):
        y = lo_y + (hi_y - lo_y) * (row + 0.5) / 9.0

        for column in range(6):
            x = canvas.w * (column + 0.5 + rng.uniform(-0.3, 0.3)) / 6.0
            # Les feuilles retombent, et s'ecartent du centre en descendant.
            lean = (x - canvas.w * 0.5) / (canvas.w * 0.5)
            angle = math.pi * 0.5 + lean * 0.9 + rng.uniform(-0.25, 0.25)
            _leaf(canvas, x, y + rng.uniform(-4.0, 4.0), angle, length, width,
                  leaf, leaf_shadow, crown_faces)

    # ---- le trait interieur : les deux aretes du bourrelet ------------------
    #
    # ⛔ Jamais la silhouette (§4.8, n°5) — le trait ne passe que sur les faces
    # du pot, donc il s'arrete de lui-meme au bord de l'objet.
    for face in faces:
        if face["part"] != POT or face["normal"].z > 0.9:
            continue

        corners = [mesh.vertices[mesh.loops[i].vertex_index].co
                   for i in mesh.polygons[face["index"]].loop_indices]
        pixels = [canvas.to_pixels(p) for p in face["points"]]

        for i in range(len(corners)):
            j = (i + 1) % len(corners)
            z = corners[i].z

            if abs(z - corners[j].z) < 1e-4 and abs(z - RIM_BOTTOM) < 1e-4:
                canvas.segment(pixels[i], pixels[j], ink, 1.8,
                               depths=(face["depths"][i], face["depths"][j]),
                               owners=pot_faces)

    write_png(path, frame["px_w"], frame["px_h"], canvas.data)


def _leaf(canvas, x, y, angle, length, width, light, shadow, owners) -> None:
    """Une amande en ton clair, bordee d'un croissant de 2e ton du cote de
    l'ombre, plus sa nervure. C'est le croissant qui la decoupe de la feuille
    d'en dessous. Pas d'encre — a 40 px/m, une encre par feuille fait du
    bruit."""
    ca, sa = math.cos(angle), math.sin(angle)
    reach = int(length * 0.5) + 2

    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            px, py = int(x) + dx, int(y) + dy

            if not (0 <= px < canvas.w and 0 <= py < canvas.h):
                continue
            if canvas.owner[py * canvas.w + px] not in owners:
                continue

            along = dx * ca + dy * sa
            across = -dx * sa + dy * ca
            t = along / (length * 0.5)

            if abs(t) > 1.0:
                continue

            half = width * 0.5 * (1.0 - t * t) ** 0.8

            if abs(across) > half:
                continue

            crescent = across > half * 0.45
            midrib = abs(across) < 0.6 and -0.7 < t < 0.6
            canvas.put(px, py, shadow if crescent or midrib else light)


# ------------------------------------------------------------------- scene

def setup_scene() -> None:
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


def clear_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh, do_unlink=True)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material, do_unlink=True)


def main() -> None:
    clear_scene()
    setup_scene()

    mesh, parts = build_mesh()
    mesh.materials.append(paint_material(MATERIAL, LEAF))

    frame = frame_of(mesh)
    counts = unwrap(mesh, parts, frame)
    stats = paint(mesh)

    obj = bpy.data.objects.new(MESH_OBJECT, mesh)

    collection = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    collection.objects.link(obj)

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    lo = Vector((min(v.co[i] for v in mesh.vertices) for i in range(3)))
    hi = Vector((max(v.co[i] for v in mesh.vertices) for i in range(3)))

    print("\n[build_plant] %s" % MESH_OBJECT)
    print("  %d sommets, %d faces, %d tris"
          % (len(mesh.vertices), len(mesh.polygons), tris))
    print("  emprise  X %.3f a %.3f   Y %.3f a %.3f   Z %.2f a %.2f"
          % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    print("  projection  plongee %.2f deg, lacet nul" % math.degrees(PITCH))
    print("  faces  %d tournees vers la camera, dont %d projetees ; %d a l'aplat uni"
          % (counts["visible"], counts["projete"], counts["aplat"]))
    print("  cadre   %.4f x %.4f m   depuis (%.4f, %.4f)"
          % (frame["w"], frame["h"], frame["x0"], frame["y0"]))
    print("  texture %d x %d px  (%.1f px/m, bande d'aplat = %d px en bas)"
          % (frame["px_w"], frame["px_h"], DENSITY, BAND_PIXELS))
    print("  Attr_Style  R %.2f-%.2f   G 0.50   B 0.00"
          % (stats["r"][0], stats["r"][1]))

    if "--gabarit" in sys.argv:
        render_gabarit(mesh, parts, frame, GABARIT)
        print("  gabarit  -> %s" % GABARIT)

    if "--texture" in sys.argv:
        if TEXTURE.exists() and "--force" not in sys.argv:
            print("  texture  DEJA LA, rien ecrit — ajouter --force pour l'ECRASER")
        else:
            render_placeholder(mesh, parts, frame, TEXTURE)
            print("  texture  -> %s   (PLACEHOLDER)" % TEXTURE)

    if "--save" in sys.argv:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
        print("  ecrit dans %s" % OUTPUT)
    else:
        print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
