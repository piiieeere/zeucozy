"""Construit la TABLE BASSE — le 1er objet PROJETE du projet (2026-08-21).

    "<blender>" --background --factory-startup \
        --python tools/build_coffee_table.py -- --save [--texture] [--gabarit]

C'est le premier meuble qui ne se MODELISE pas : son volume ne porte que la
silhouette, l'assise au sol et une surface pour l'ombre portee ; tout le dessin
— le fil du bois, les plis, l'usure, l'ombre propre — arrive PEINT dans une
texture projetee. "Visual Art Direction" §2quater pour le style, "Pipeline 3D"
§1→§6 pour le transit, "Convention Blender" §12.1→§12.6 pour les gestes.

Ce que le script produit :

  * UN objet `MSH_table_basse`, 2 coques (plateau + socle), 12 quads, en
    shade_FLAT. Le projete est le SEUL endroit du projet ou `shade_flat` est le
    bon reglage (§12.1) : l'aplat vient de l'image, pas de la normale.
  * UNE UV0 calculee — deux produits scalaires, aucun modificateur (§12.2).
  * `Attr_Style` : R peint (le trait sert toujours), G a 0,5 et B a 0,0 — il
    n'y a plus de cluster a biaiser ni d'accent a masquer (§12.4).
  * en option, le GABARIT (`maquettes/`) et une illustration PLACEHOLDER
    (`assets/textures/`), toutes deux rendues par la MEME projection que l'UV :
    elles se superposent au maillage par construction, ce que le test de §4.8
    exige et ne peut, autrement, que constater apres coup.

⛔ AUCUN NŒUD IMAGE DANS LE MATERIAU BLENDER, ET C'EST DELIBERE. Un Image
Texture branche serait EMBARQUE dans le .glb par l'exporteur, alors que
"Pipeline 3D" §2 veut la texture DEHORS — sinon Godot ne peut plus regler sa
compression, et le piege n°3 (Detect 3D casse le trait) devient inevitable. Le
.blend perd donc son viewport jugeable, contrairement au canape ; c'est Godot
qui juge le projete, et c'est de toute facon lui la reference.

PROPORTIONS. L'emprise 3,0 x 1,6 est celle que `arena.PROPS` posait deja pour
la boite pastel : la changer aurait deplace le meuble en meme temps qu'on
change sa nature, et on n'aurait plus su lequel des deux on jugeait. La
HAUTEUR, elle, monte de 0,8 a 1,0 — l'assise du canape est a 1,6, une table
basse se lit contre elle, et le chat (1,86) la depasse encore de 0,86.
"""

import math
import struct
import sys
import zlib
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/prop_table_basse_v1.blend")
TEXTURE = ROOT / "assets" / "textures" / "prop_table_basse.png"
GABARIT = ROOT / "maquettes" / "table_basse_gabarit.png"

COLLECTION = "prop_table_basse"
MESH_OBJECT = "MSH_table_basse"
ATTRIBUTE = "Attr_Style"

# UN SEUL materiau, la ou "Convention Blender" §12.5 donne `PAINT_table` ET
# `PAINT_flanc` en exemple. L'ecart est assume : un ilot de FLANC est une
# affaire d'UV, pas de matiere — les deux zones echantillonnent la meme image,
# avec le meme shader et le meme trait. Les separer couterait une surface de
# plus, donc un draw call de plus ET un `next_pass` de contour de plus, sur un
# meuble que l'arene pose par dizaines. C'est exactement le calcul que
# `cel_prop.FACES` a deja fait en retirant les coques d'yeux des ennemis.
MATERIAL = "PAINT_table"

# ---------------------------------------------------------------- dimensions

LENGTH = 3.0          # X — l'emprise que `arena.PROPS` declare deja
DEPTH = 1.6           # Y — la table regarde -Y (convention du chat)
HEIGHT = 1.0          # dessus du plateau

SLAB_BOTTOM = 0.82    # dessous du plateau : 0,18 d'epaisseur
PLINTH_LENGTH = 2.10  # le socle plein, en retrait des quatre cotes
PLINTH_DEPTH = 0.80

# ------------------------------------------------------------------ la projection
#
# "Convention Blender" §12.2 — six lignes, aucun modificateur, aucun etat dans
# le .blend. L'axe est celui de la camera de jeu, `look_height` comprise :
#   atan2(38*sin(45) - 0,9 ; 38*cos(45)) = 44,02°.
#
# ⚠️ 44,02 et non 45 : projeter a 45 decalerait TOUT le decor du meme cran,
# donc de facon coherente, donc invisible en comparaison, et faux partout.

PITCH = math.radians(44.02)
VIEW = Vector((0.0, math.cos(PITCH), -math.sin(PITCH)))
RIGHT = Vector((1.0, 0.0, 0.0))
UP = RIGHT.cross(VIEW)

# Au-dela de 2x d'etirement une face part a l'aplat uni — `dot >= 0,5`, soit
# 60° entre sa normale et l'axe. Ici ca sort exactement les quatre flancs
# (normale ±X, etirement infini) et les quatre faces qu'aucun regard ne voit,
# le dos et le dessous.
FACING_MIN = 0.5

# Marge autour de la silhouette projetee, en metres. Elle n'est pas cosmetique :
# le filtrage bilineaire et les mipmaps vont chercher des texels au-dela du bord
# de la face, et sans marge ils ramenent le fond.
FRAME_MARGIN = 0.08

# Densite de peinture. §2quater : le jeu n'en affiche que 40,1 px/m ; 96 garde
# la marge de deux qu'exigent l'etirement de 1,41x et `--ssaa=2.0`.
DENSITY = 96.0

# La BANDE D'APLAT UNI reservee en bas de l'image — la cible de l'ilot de flanc
# (§12.3). En bas et non dans un coin : un coin oblige a trouver une zone que la
# projection ne touche pas, ce qui depend de la silhouette ; une bande ajoutee
# SOUS le cadre n'en depend pas, et laisse les six lignes de §12.2 intactes —
# elle se contente d'agrandir `frame_h`.
BAND_PIXELS = 24

# ------------------------------------------------------------------- palette
#
# Deux tons, et deux seulement (§4.8, contrainte 4) : l'illustration EST
# l'aplat, le moteur n'ajoute aucun cluster par-dessus. `#D4A860` est l'ambre
# Ghibli de §4 — le seul bois de la palette. Il tombe a 0,70 de luma contre
# 0,91 a 0,96 pour le parquet : la table s'en detache, ce qui est la borne que
# le projectile jaune pale avait payee.
WOOD = "#D4A860"
WOOD_SHADOW = "#A87840"
INK = "#3D2B1A"
# Le flanc : la couleur du volume, assombrie d'un cran (§12.3).
FLANK = "#8A6034"


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

def add_box(bm, center, size) -> None:
    """Une coque, six quads, sans le moindre bevel.

    §12.1 : le volume ne porte que la silhouette. Un bevel serait de la
    geometrie mise au service du dessin — or le dessin est dans l'image.
    """
    result = bmesh.ops.create_cube(bm, size=1.0)
    verts = result["verts"]
    bmesh.ops.scale(bm, vec=Vector(size), verts=verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=verts)


def build_mesh():
    bm = bmesh.new()

    # 1. Le plateau — il donne l'emprise declaree par `arena.PROPS`.
    add_box(bm, (0.0, 0.0, (SLAB_BOTTOM + HEIGHT) * 0.5),
            (LENGTH, DEPTH, HEIGHT - SLAB_BOTTOM))

    # 2. Le socle plein. PAS quatre pieds : quatre pieds coutent 24 quads, soit
    #    le double du budget de §12.1, et surtout ils ne se PEIGNENT pas — le
    #    contour d'encre cerne la geometrie, donc des pieds dessines sur un
    #    socle plein feraient cerner du vide (le test de rejet de §4.8).
    add_box(bm, (0.0, 0.0, SLAB_BOTTOM * 0.5),
            (PLINTH_LENGTH, PLINTH_DEPTH, SLAB_BOTTOM))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    # ⚠️ shade_FLAT, l'unique exception du projet (§12.1). Sur un volume a douze
    # quads, le lissage sortirait en degrade de normales — exactement le 3e ton
    # que la variante A refuse.
    for face in bm.faces:
        face.smooth = False

    mesh = bpy.data.meshes.new(MESH_OBJECT)
    bm.to_mesh(mesh)
    bm.free()

    return mesh


# ------------------------------------------------------------------ projection

def project(point) -> tuple:
    """Les deux produits scalaires de §12.2, en metres."""
    return (point.dot(RIGHT), point.dot(UP))


def frame_of(mesh) -> dict:
    """Le cadre de l'illustration, en metres ET en pixels.

    C'est la SEULE donnee que le build doit noter a cote des dimensions
    (§12.2) : c'est elle qui fait le lien entre l'image et le monde.

    Le cadre se prend sur TOUS les sommets, pas seulement sur ceux des faces
    projetees : la silhouette vue dans l'axe est celle du volume entier, et
    l'arete haute du dos monte plus haut en projection que le dessus vu de
    face. Un cadre pris sur les seules faces visibles couperait le dessin.
    """
    points = [project(v.co) for v in mesh.vertices]
    lo_u = min(p[0] for p in points)
    hi_u = max(p[0] for p in points)
    lo_v = min(p[1] for p in points)
    hi_v = max(p[1] for p in points)

    # Arrondi a 4 px pres, puis le cadre metre se REDEDUIT des pixels : la
    # densite reste exacte, et c'est le cadre qui grandit, jamais l'inverse.
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
        # Hauteur d'UV de la bande reservee, mesuree depuis v = 0. En convention
        # BLENDER : v = 0 est le BAS de l'image, et c'est l'exporteur glTF qui
        # retourne le V. On ne compense donc rien a la main (§12.6).
        "band_v": BAND_PIXELS / height,
    }


def unwrap(mesh, frame: dict) -> dict:
    """Ecrit l'UV0 : projection pour ce que la camera voit, aplat uni sinon.

    L'assignation est par FACE et non par ilot, contrairement a §12.7 — sur un
    volume a douze quads plans il n'y a pas d'ilot a former : chaque face EST
    son ilot, et le damier de coutures que §12.7 redoute vient du bruit de
    normale sur une surface presque plane, qui n'existe pas ici.
    """
    layer = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")

    # Le carre d'aplat uni, au milieu de la bande. Il n'est pas degenere
    # (les quatre coins ne se confondent pas) : une UV degeneree donne des
    # derivees nulles, donc un choix de mipmap arbitraire.
    swatch = (
        (0.30, frame["band_v"] * 0.25),
        (0.70, frame["band_v"] * 0.75),
    )

    counts = {"projete": 0, "aplat": 0}

    for face in mesh.polygons:
        facing = face.normal.dot(-VIEW)
        projected = facing >= FACING_MIN

        for loop_index in face.loop_indices:
            vertex = mesh.vertices[mesh.loops[loop_index].vertex_index]

            if projected:
                u, v = project(vertex.co)
                layer.data[loop_index].uv = (
                    (u - frame["x0"]) / frame["w"],
                    (v - frame["y0"]) / frame["h"],
                )
            else:
                # Les quatre coins du carre, dans l'ordre du quad : la face
                # recoit un aplat uni sans etirement de derivees.
                corner = face.loop_indices.index(loop_index)
                layer.data[loop_index].uv = (
                    swatch[0][0] if corner in (0, 3) else swatch[1][0],
                    swatch[0][1] if corner in (0, 1) else swatch[1][1],
                )

        counts["projete" if projected else "aplat"] += 1

    return counts


# -------------------------------------------------------------- Attr_Style

def paint(mesh) -> dict:
    """R seul est peint. G reste a 0,5 et B a 0,0 — §12.4.

    ⚠️ Les trois canaux sont renseignes QUAND MEME. Un `Attr_Style` absent fait
    valoir `COLOR` (1,1,1,1) au shader : R a 1,0 donne le trait le plus epais
    partout, et le jour ou ce meuble repasserait par `cel_toon`, un G a 1,0 le
    mettrait en pleine lumiere permanente.
    """
    attr = mesh.color_attributes.get(ATTRIBUTE)

    if attr is None:
        attr = mesh.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="POINT")

    stats = {"r": [2.0, -1.0]}

    for i, vertex in enumerate(mesh.vertices):
        z = vertex.co.z

        # Le trait s'alourdit vers le bas, comme sous un objet pose, et
        # s'epaissit a la jointure plateau / socle. Meme profil que le canape,
        # a une borne basse pres : 0,60 tient 0,60 px a l'ecran au facteur
        # mobilier, la ou le canape descend a 0,55.
        r = 1.0 - 0.34 * min(1.0, z / HEIGHT)

        if abs(z - SLAB_BOTTOM) < 0.001:
            r += 0.14

        r = min(1.0, max(0.60, r))
        attr.data[i].color = (r, 0.5, 0.0, 1.0)

        stats["r"][0] = min(stats["r"][0], r)
        stats["r"][1] = max(stats["r"][1], r)

    # `active` designe l'attribut qu'edite l'outil de peinture, `default_color`
    # celui que l'exporteur sort en COLOR_0. Les deux doivent pointer sur
    # Attr_Style, sinon l'export part sur autre chose — ou sur rien.
    mesh.color_attributes.active_color_name = ATTRIBUTE
    mesh.color_attributes.default_color_name = ATTRIBUTE

    return stats


# -------------------------------------------------------------- materiau

def paint_material(name: str, code: str):
    """Un aplat d'emission, sans nœud image — voir le bandeau du fichier.

    Le prefixe `PAINT_` n'est pas decoratif : c'est lui qui dit a `cel_prop.gd`
    de monter `cel_painted` et non `cel_toon` (§12.5).
    """
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
    """PNG RGB8, sans dependance. Zeucozy n'en prend pas (regles de dev)."""

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    raw = bytearray()

    for row in range(height):
        raw.append(0)                                    # filtre None
        raw += pixels[row * width * 3:(row + 1) * width * 3]

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


# ---- un rasteriseur minuscule, dans l'espace de la TEXTURE ------------------
#
# Il ne sert pas a "faire joli" : il rend le GABARIT et le PLACEHOLDER par la
# MEME projection que l'UV, a partir des MEMES sommets. C'est ce qui rend le
# test de rejet de §4.8 — superposer l'image au blockout — vrai par
# construction au lieu d'etre verifie a l'œil apres coup.

class Canvas:
    def __init__(self, frame: dict):
        self.w = frame["px_w"]
        self.h = frame["px_h"]
        self.frame = frame
        self.data = bytearray(self.w * self.h * 3)

    def fill(self, color, y0: int = 0, y1: int = -1) -> None:
        y1 = self.h if y1 < 0 else y1
        row = bytes(color) * self.w

        for y in range(max(0, y0), min(self.h, y1)):
            self.data[y * self.w * 3:(y + 1) * self.w * 3] = row

    def put(self, x: int, y: int, color) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            offset = (y * self.w + x) * 3
            self.data[offset:offset + 3] = bytes(color)

    def to_pixels(self, point: tuple) -> tuple:
        """Metres projetes -> pixels. Le PNG a sa ligne 0 EN HAUT, la convention
        UV de Blender a son v = 0 EN BAS : d'ou le retournement, ici et ici
        seulement. Rien n'est retourne dans l'UV (§12.6)."""
        u = (point[0] - self.frame["x0"]) / self.frame["w"]
        v = (point[1] - self.frame["y0"]) / self.frame["h"]
        return (u * self.w, (1.0 - v) * self.h)

    def polygon(self, points, color) -> None:
        """Remplit un convexe. Une demi-diagonale de dilatation : deux faces
        adjacentes doivent se toucher sans laisser de trou d'un pixel."""
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        cx = sum(xs) / len(xs)
        cy = sum(ys) / len(ys)
        grown = [(x + (0.75 if x > cx else -0.75), y + (0.75 if y > cy else -0.75))
                 for x, y in points]

        area = 0.0
        n = len(grown)

        for i in range(n):
            x0, y0 = grown[i]
            x1, y1 = grown[(i + 1) % n]
            area += x0 * y1 - x1 * y0

        sign = 1.0 if area >= 0.0 else -1.0

        for y in range(max(0, int(min(p[1] for p in grown))),
                       min(self.h, int(max(p[1] for p in grown)) + 2)):
            for x in range(max(0, int(min(p[0] for p in grown))),
                           min(self.w, int(max(p[0] for p in grown)) + 2)):
                px, py = x + 0.5, y + 0.5
                inside = True

                for i in range(n):
                    x0, y0 = grown[i]
                    x1, y1 = grown[(i + 1) % n]

                    if sign * ((x1 - x0) * (py - y0) - (y1 - y0) * (px - x0)) < 0.0:
                        inside = False
                        break

                if inside:
                    self.put(x, y, color)

    def segment(self, a: tuple, b: tuple, color, weight: float = 1.6) -> None:
        """Un trait d'encre, en pixels. Interieur seulement — jamais la
        silhouette, que la coque inversee de Godot dessine deja (§4.8, n°5)."""
        steps = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
        radius = weight * 0.5

        for i in range(steps + 1):
            t = i / steps
            cx = a[0] + (b[0] - a[0]) * t
            cy = a[1] + (b[1] - a[1]) * t

            for dy in range(-int(radius) - 1, int(radius) + 2):
                for dx in range(-int(radius) - 1, int(radius) + 2):
                    if dx * dx + dy * dy <= radius * radius + 0.25:
                        self.put(int(cx) + dx, int(cy) + dy, color)


# 3 x 5, uniquement pour numeroter les faces du gabarit.
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


def visible_faces(mesh):
    """Les faces que la camera voit, de la PLUS LOINTAINE a la plus proche.

    `p.dot(VIEW)` croit avec l'eloignement, VIEW etant la direction dans
    laquelle la camera regarde. Peindre dans cet ordre suffit a ce que le
    plateau recouvre le dessus du socle, qu'il cache en jeu.
    """
    faces = []

    for face in mesh.polygons:
        if face.normal.dot(-VIEW) < FACING_MIN:
            continue

        points = [project(mesh.vertices[mesh.loops[i].vertex_index].co)
                  for i in face.loop_indices]
        faces.append((face.center.dot(VIEW), face.index, points, face.normal.copy()))

    faces.sort(key=lambda item: -item[0])
    return faces


def render_gabarit(mesh, frame: dict, path: Path, scale: int = 3) -> None:
    """Le BLOCKOUT, dans le cadre exact de l'illustration.

    C'est la piece a donner au generateur — §4.9 a tranche que le blockout se
    RENDAIT au lieu de se dessiner, et la raison vaut deja a une vue : la
    compatibilite illustration / modele cesse d'etre un vœu, elle devient la
    donnee d'entree.
    """
    big = dict(frame)
    big["px_w"] = frame["px_w"] * scale
    big["px_h"] = frame["px_h"] * scale

    canvas = Canvas(big)
    canvas.fill((236, 232, 224))
    canvas.fill((150, 146, 140), big["px_h"] - BAND_PIXELS * scale, big["px_h"])

    tones = [(196, 190, 180), (168, 162, 152), (140, 134, 124), (120, 114, 106)]

    for order, (_, index, points, _) in enumerate(visible_faces(mesh)):
        pixels = [canvas.to_pixels(p) for p in points]
        canvas.polygon(pixels, tones[order % len(tones)])

        for i in range(len(pixels)):
            canvas.segment(pixels[i], pixels[(i + 1) % len(pixels)], (60, 56, 50), 2.0)

        cx = sum(p[0] for p in pixels) / len(pixels)
        cy = sum(p[1] for p in pixels) / len(pixels)
        # Une face mince n'a pas la place d'un chiffre en son centre : le
        # numero part alors sur son bord gauche, sinon il chevauche le voisin.
        if max(p[1] for p in pixels) - min(p[1] for p in pixels) < 60.0:
            cx = min(p[0] for p in pixels) + 24.0

        stamp(canvas, str(index), int(cx) - 6, int(cy) - 8, (40, 36, 32), 3)

    write_png(path, big["px_w"], big["px_h"], canvas.data)


def render_placeholder(mesh, frame: dict, path: Path) -> None:
    """Une illustration PROVISOIRE, peinte par le script.

    ⚠️ Ce n'est PAS l'asset final : §2quater fait entrer une image peinte a la
    main dans `assets/`, et c'est tout l'interet de la technique — le fil du
    bois, l'usure, les reflets ne se scriptent pas. Celle-ci existe pour que le
    pont soit verifiable AUJOURD'HUI, bout en bout, avec le bon cadre et la
    bonne orientation. La vraie illustration se depose au meme chemin.

    Elle respecte quand meme les cinq contraintes de §4.8 : projection a 44,02°
    (par construction — c'est la meme fonction que l'UV), 2 tons, ombre peinte
    en forme decidee, rien sur les flancs, aucun contour de silhouette.
    """
    canvas = Canvas(frame)
    wood = hex_to_bytes(WOOD)
    shadow = hex_to_bytes(WOOD_SHADOW)
    ink = hex_to_bytes(INK)

    # Le fond du cadre prend deja le ton du bois : au bord de la silhouette, le
    # filtrage ira chercher un texel voisin, et il vaut mieux qu'il y trouve du
    # bois qu'un fond neutre.
    canvas.fill(wood)
    canvas.fill(hex_to_bytes(FLANK), frame["px_h"] - BAND_PIXELS, frame["px_h"])

    # ⚠️ UN SEUL PARCOURS, DU PLUS LOINTAIN AU PLUS PROCHE, aplats ET traits
    # melanges. C'est ce qui donne l'occultation gratuitement : le pli haut du
    # socle passe DERRIERE le plateau, donc il doit etre pose avant lui. En deux
    # passes — tous les aplats, puis tous les traits — ce meme pli se retrouvait
    # peint EN TRAVERS du dessus de la table, et rien dans l'image ne disait
    # d'ou venait cette barre.
    for _, _, points, normal in visible_faces(mesh):
        pixels = [canvas.to_pixels(p) for p in points]

        if normal.z > 0.5:
            # Le dessus regarde le ciel : ton clair, plus le fil du bois. Le fil
            # est en 2e ton, jamais en encre — c'est de la matiere, pas un trait.
            canvas.polygon(pixels, wood)

            lo_x = min(p[0] for p in pixels)
            hi_x = max(p[0] for p in pixels)
            lo_y = min(p[1] for p in pixels)
            hi_y = max(p[1] for p in pixels)

            for i in range(1, 5):
                y = lo_y + (hi_y - lo_y) * (i / 5.0)
                wobble = 2.0 if i % 2 else -2.0
                canvas.segment((lo_x + 10.0, y), (hi_x - 10.0, y + wobble), shadow, 1.4)
        else:
            # Une face verticale regarde le spectateur, pas le ciel : 2e ton.
            # C'est une ombre DECIDEE, pas un `dot(N, L)` — le meme geste que le
            # canal G du canape, mais peint dans l'image.
            canvas.polygon(pixels, shadow)

            # Son arete HAUTE est le pli avec le dessus : trait INTERIEUR, et
            # c'est lui qui fait lire l'epaisseur du plateau (§2ter.A).
            top_edge = sorted(pixels, key=lambda pixel: pixel[1])[:2]
            canvas.segment(top_edge[0], top_edge[1], ink, 2.0)

    # ---- le pli plateau / socle --------------------------------------------
    #
    # ⚠️ CLIPPE SUR L'EMPRISE DU SOCLE, et ce n'est pas un detail de dessin :
    # au-dela, le dessous du plateau est une SILHOUETTE (il n'y a plus rien
    # derriere), et §4.8 interdit de peindre un contour de silhouette — la coque
    # inversee de Godot le pose deja, les deux se superposeraient au bord.
    seam_v = -DEPTH * 0.5 * math.sin(PITCH) + SLAB_BOTTOM * math.cos(PITCH)
    left = canvas.to_pixels((-PLINTH_LENGTH * 0.5, seam_v))
    right = canvas.to_pixels((PLINTH_LENGTH * 0.5, seam_v))
    canvas.segment(left, right, ink, 2.0)

    write_png(path, frame["px_w"], frame["px_h"], canvas.data)


# ------------------------------------------------------------------- scene

def setup_scene() -> None:
    scene = bpy.context.scene

    for candidate in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = candidate
            break
        except TypeError:
            continue

    # Un tonemap filmique delave tous les aplats et annule le travail de
    # palette ("Convention Blender" §1).
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

    mesh = build_mesh()
    mesh.materials.append(paint_material(MATERIAL, WOOD))

    frame = frame_of(mesh)
    counts = unwrap(mesh, frame)
    stats = paint(mesh)

    obj = bpy.data.objects.new(MESH_OBJECT, mesh)

    collection = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    collection.objects.link(obj)

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    lo = Vector((min(v.co[i] for v in mesh.vertices) for i in range(3)))
    hi = Vector((max(v.co[i] for v in mesh.vertices) for i in range(3)))

    print("\n[build_coffee_table] %s" % MESH_OBJECT)
    print("  %d sommets, %d faces, %d tris"
          % (len(mesh.vertices), len(mesh.polygons), tris))
    print("  emprise  X %.2f a %.2f   Y %.2f a %.2f   Z %.2f a %.2f"
          % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    print("  plateau a %.2f   socle %.2f x %.2f   (chat = 1.86, assise canape = 1.60)"
          % (HEIGHT, PLINTH_LENGTH, PLINTH_DEPTH))
    print("  projection  plongee %.2f deg, lacet nul" % math.degrees(PITCH))
    print("  faces  %d projetees, %d a l'aplat uni (flancs, dos, dessous)"
          % (counts["projete"], counts["aplat"]))
    print("  cadre   %.4f x %.4f m   depuis (%.4f, %.4f)"
          % (frame["w"], frame["h"], frame["x0"], frame["y0"]))
    print("  texture %d x %d px  (%.1f px/m, bande d'aplat = %d px en bas)"
          % (frame["px_w"], frame["px_h"], DENSITY, BAND_PIXELS))
    print("  Attr_Style  R %.2f-%.2f   G 0.50   B 0.00"
          % (stats["r"][0], stats["r"][1]))

    if "--gabarit" in sys.argv:
        render_gabarit(mesh, frame, GABARIT)
        print("  gabarit  -> %s" % GABARIT)

    if "--texture" in sys.argv:
        if TEXTURE.exists() and "--force" not in sys.argv:
            print("  texture  DEJA LA, rien ecrit — ajouter --force pour l'ECRASER")
        else:
            render_placeholder(mesh, frame, TEXTURE)
            print("  texture  -> %s   (PLACEHOLDER)" % TEXTURE)

    if "--save" in sys.argv:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
        print("  ecrit dans %s" % OUTPUT)
    else:
        print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
