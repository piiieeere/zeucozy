"""Construit la PLANTE EN POT depuis le modele Tripo — la BRANCHE E (2026-10-18).

    "<blender>" --background --factory-startup \
        --python tools/build_plant_tripo.py -- --save [--texture [--force]]

« Intégration Assets 3D » §7 laissait la question ouverte : un maillage GENERE
peut-il entrer dans le jeu ? Reponse retenue ici : oui, a condition de passer par
un script REJOUABLE, comme tout le reste. La source est
`maquettes/potted plant 3d model.glb` (Tripo, allege a 3 208 tris) ; elle reste
dans `maquettes/` et n'est jamais chargee par le jeu. Ce script en tire :

  * `MSH_plante`, en metres, pose au sol, centre sur sa boite englobante ;
  * des feuilles EPAISSES (voir plus bas) ;
  * UN materiau `PAINT_plante`, sans nœud image — `cel_prop` lui monte
    `cel_painted`, exactement comme a la table basse ;
  * `Attr_Style` : R peint, G 0,5, B 0,0 (§12.4 de "Convention Blender") ;
  * avec `--texture`, `assets/textures/prop_plante.png` : la texture de COULEUR
    de Tripo, reduite a 1024 px et debarrassee de son fond noir.

⭐ LA TEXTURE DE COULEUR DE TRIPO DEVIENT L'« ILLUSTRATION ». `cel_painted` ne
sait pas que l'UV de la table etait projetee : il lit une image par l'UV, en
aplat, avec le contour du mobilier et l'ombre portee de `cel_sun`. L'UV de Tripo
y entre telle quelle. Pas de cluster par-dessus — c'est la regle du peint, et la
texture porte deja ses valeurs.

⛔ LES DEUX AUTRES CARTES DE TRIPO NE PASSENT PAS : la carte de NORMALES et la
carte METAL/RUGOSITE (`rm`). Elles ne servent qu'a un eclairage physique, que le
cel-shading du projet n'a pas — et §11 de "Convention Blender" interdit
explicitement metal et rugosite. Elles restent dans le .glb source.

⛔ LES FEUILLES DE TRIPO SONT DES SURFACES SANS EPAISSEUR (438 coques, 3 414
aretes de bord). Deux choses cassent sur une surface ouverte :
  * `cel_painted` est en `cull_back` : vue de dessous, une feuille disparait ;
  * le contour est une COQUE INVERSEE (piege n°1) : elle suppose un volume
    ferme. Sur un plan, elle peint l'envers de la feuille tout entier a l'encre.
D'ou `bmesh.ops.solidify` sur les SEULES coques ouvertes, a 2 cm. Les coques
deja fermees n'en recoivent pas : une seconde peau a epaisseur nulle
z-fighterait avec la premiere.

⚠️ LA REDUCTION DE TEXTURE IGNORE LE FOND NOIR — meme piege que les tapis
(`bake_rugs.py`). L'atlas de Tripo pose ses ilots sur du noir pur ; une
moyenne naive le melangerait au bord de chaque ilot, et les mipmaps le
remonteraient en liseré noir sur chaque COUTURE d'UV — visible sur le pot, ou
les coutures ne tombent pas sur une arete. La moyenne est donc ponderee par la
couverture, puis le fond est comble par dilatation.
"""

import math
import struct
import sys
import zlib
from array import array
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "maquettes" / "potted plant 3d model.glb"
OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/prop_plante_v2.blend")
TEXTURE = ROOT / "assets" / "textures" / "prop_plante.png"

COLLECTION = "prop_plante"
MESH_OBJECT = "MSH_plante"
ATTRIBUTE = "Attr_Style"
MATERIAL = "PAINT_plante"

# La hauteur des boites pastel qu'elle remplace. L'emprise, elle, n'est PAS
# choisie : elle sort des proportions du modele (le feuillage deborde du pot),
# et `arena.PROPS` doit recopier celle que le build imprime — `_add_blocker`
# previent si les deux s'ecartent de plus d'un centimetre.
HEIGHT = 2.6

# Epaisseur donnee aux feuilles. Assez pour que la coque inversee ait un
# volume a cerner, assez peu pour ne pas se lire comme du carton : le trait du
# mobilier en fait deja 2,25 cm.
LEAF_THICKNESS = 0.02

# 1024 et pas 4096 : le jeu montre 40 px/m, et une texture peinte est reglee en
# Lossless (pas de compression VRAM, sinon le trait bave — piege n°3 de
# "Pipeline 3D"). En 4096, ce serait 64 Mo de VRAM pour une plante.
TEXTURE_SIZE = 1024

# Un pixel source est du FOND s'il est quasiment noir. Le terreau le plus
# sombre de l'atlas reste tres au-dessus.
BACKGROUND_MAX = 0.025

# Rayon de la dilatation, en pixels de sortie. 16 couvre la chaine de mipmaps
# jusqu'a 64 px — au-dela, la plante fait moins d'un pixel a l'ecran.
BLEED_PASSES = 16

# Le trait du mobilier, comme la table : plus lourd en bas, la ou l'objet pose.
R_TOP = 0.66


# ------------------------------------------------------------------ source

def import_source():
    """Importe le .glb Tripo, rend l'objet maillage et l'image de COULEUR."""
    if not SOURCE.exists():
        raise SystemExit("source introuvable : %s" % SOURCE)

    bpy.ops.import_scene.gltf(filepath=str(SOURCE))

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if len(meshes) != 1:
        raise SystemExit("il faut UN maillage dans la source, il y en a %d" % len(meshes))

    obj = meshes[0]
    image = None

    for slot in obj.material_slots:
        tree = slot.material.node_tree if slot.material else None
        for node in (tree.nodes if tree else []):
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            # La couleur est l'image branchee (directement ou non) sur
            # « Base Color » ; Tripo la nomme toujours `*_basecolor`.
            if "basecolor" in node.image.name.lower():
                image = node.image

    if image is None:
        raise SystemExit("aucune texture *_basecolor dans la source")

    return obj, image


def normalize(obj) -> dict:
    """Cuit la transformation dans le maillage : metres, au sol, centre.

    La source sort a 0,97 unite de haut, sous un nœud racine. On cuit tout dans
    les sommets — un objet a l'echelle 2,68 serait un piege pour le contour,
    dont l'epaisseur est donnee en metres monde.
    """
    mesh = obj.data
    mesh.transform(obj.matrix_world)
    obj.parent = None
    obj.matrix_world = Matrix.Identity(4)

    lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
    scale = HEIGHT / (hi.z - lo.z)
    center = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))

    mesh.transform(Matrix.Scale(scale, 4) @ Matrix.Translation(-center))

    for other in list(bpy.data.objects):
        if other != obj:
            bpy.data.objects.remove(other, do_unlink=True)

    return {"scale": scale}


# ------------------------------------------------------------------ epaisseur

def thicken(mesh) -> dict:
    """Donne une epaisseur aux seules coques OUVERTES — voir le bandeau."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()

    seen = set()
    open_faces = []
    shells = {"ouvertes": 0, "fermees": 0}

    for start in bm.faces:
        if start.index in seen:
            continue

        shell = []
        stack = [start]
        is_open = False

        while stack:
            face = stack.pop()
            if face.index in seen:
                continue
            seen.add(face.index)
            shell.append(face)

            for edge in face.edges:
                if edge.is_boundary:
                    is_open = True
                for other in edge.link_faces:
                    if other.index not in seen:
                        stack.append(other)

        shells["ouvertes" if is_open else "fermees"] += 1
        if is_open:
            open_faces += shell

    bmesh.ops.solidify(bm, geom=open_faces, thickness=LEAF_THICKNESS)

    for face in bm.faces:
        face.smooth = True

    bm.to_mesh(mesh)
    bm.free()

    shells["bords_restants"] = _boundary_count(mesh)
    return shells


def _boundary_count(mesh) -> int:
    bm = bmesh.new()
    bm.from_mesh(mesh)
    count = sum(1 for e in bm.edges if e.is_boundary)
    bm.free()
    return count


# -------------------------------------------------------------- Attr_Style

def paint(mesh) -> dict:
    """R seul est peint ; G a 0,5 et B a 0,0, renseignes quand meme (§12.4)."""
    attr = mesh.color_attributes.get(ATTRIBUTE)

    if attr is None:
        attr = mesh.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="POINT")

    lo, hi = 2.0, -1.0

    for i, vertex in enumerate(mesh.vertices):
        r = 1.0 - (1.0 - R_TOP) * min(1.0, max(0.0, vertex.co.z / HEIGHT))
        attr.data[i].color = (r, 0.5, 0.0, 1.0)
        lo, hi = min(lo, r), max(hi, r)

    mesh.color_attributes.active_color_name = ATTRIBUTE
    mesh.color_attributes.default_color_name = ATTRIBUTE

    return {"r": (lo, hi)}


def paint_material(name: str):
    """Un aplat d'emission, sans nœud image — la texture reste hors du .glb
    ("Pipeline 3D" §2). Le prefixe `PAINT_` fait monter `cel_painted`."""
    material = bpy.data.materials.new(name)

    if material.node_tree is None:
        material.use_nodes = True

    tree = material.node_tree
    tree.nodes.clear()
    emission = tree.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.25, 0.48, 0.25, 1.0)
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    output.location = (200, 0)
    tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    return material


# ------------------------------------------------------------------ texture

def bake_texture(image, path: Path) -> dict:
    """Reduit la couleur a TEXTURE_SIZE, fond noir exclu, puis dilate."""
    sw, sh = image.size
    source = array("f", [0.0]) * (sw * sh * 4)
    image.pixels.foreach_get(source)

    size = TEXTURE_SIZE
    step_x = sw // size
    step_y = sh // size
    rgb = [0.0] * (size * size * 3)
    covered = bytearray(size * size)

    # ⚠️ `image.pixels` range ses lignes DE BAS EN HAUT. La sortie est ecrite
    # de haut en bas (PNG) : on retourne donc ici, et nulle part ailleurs.
    for y in range(size):
        out_row = (size - 1 - y) * size

        for x in range(size):
            r = g = b = 0.0
            n = 0

            for sy in range(y * step_y, (y + 1) * step_y):
                base = (sy * sw + x * step_x) * 4

                for k in range(step_x):
                    i = base + k * 4
                    pr, pg, pb = source[i], source[i + 1], source[i + 2]

                    if pr > BACKGROUND_MAX or pg > BACKGROUND_MAX or pb > BACKGROUND_MAX:
                        r += pr
                        g += pg
                        b += pb
                        n += 1

            if n:
                index = out_row + x
                rgb[index * 3] = r / n
                rgb[index * 3 + 1] = g / n
                rgb[index * 3 + 2] = b / n
                covered[index] = 1

    filled = sum(covered)
    _bleed(rgb, covered, size)

    pixels = bytearray(size * size * 3)
    for i, value in enumerate(rgb):
        pixels[i] = max(0, min(255, int(round(value * 255.0))))

    write_png(path, size, size, pixels)
    return {"source": (sw, sh), "couverture": filled / float(size * size)}


def _bleed(rgb: list, covered: bytearray, size: int) -> None:
    """Comble le fond par anneaux successifs : chaque pixel vide qui touche de
    la matiere prend la moyenne de ses voisins couverts. Seul le FRONT est
    parcouru, pas l'image entiere a chaque passe."""
    front = set()

    for index in range(size * size):
        if covered[index]:
            continue
        x, y = index % size, index // size
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < size and 0 <= ny < size and covered[ny * size + nx]:
                front.add(index)
                break

    for _ in range(BLEED_PASSES):
        if not front:
            break

        updates = []

        for index in front:
            x, y = index % size, index // size
            r = g = b = 0.0
            n = 0

            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < size and 0 <= ny < size:
                        j = ny * size + nx
                        if covered[j]:
                            r += rgb[j * 3]
                            g += rgb[j * 3 + 1]
                            b += rgb[j * 3 + 2]
                            n += 1

            if n:
                updates.append((index, r / n, g / n, b / n))

        next_front = set()

        for index, r, g, b in updates:
            rgb[index * 3:index * 3 + 3] = [r, g, b]
            covered[index] = 1

        for index, _, _, _ in updates:
            x, y = index % size, index // size
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < size and 0 <= ny < size and not covered[ny * size + nx]:
                    next_front.add(ny * size + nx)

        front = next_front


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


# ------------------------------------------------------------------- scene

def setup_scene() -> None:
    scene = bpy.context.scene
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

    obj, image = import_source()
    source_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    norm = normalize(obj)
    shells = thicken(obj.data)

    mesh = obj.data
    mesh.name = MESH_OBJECT
    obj.name = MESH_OBJECT
    mesh.materials.clear()
    mesh.materials.append(paint_material(MATERIAL))
    for polygon in mesh.polygons:
        polygon.material_index = 0

    stats = paint(mesh)

    collection = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    for user in list(obj.users_collection):
        user.objects.unlink(obj)
    collection.objects.link(obj)

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])

    print("\n[build_plant_tripo] %s  (source : %s)" % (MESH_OBJECT, SOURCE.name))
    print("  echelle x%.4f   %d tris source -> %d tris" % (norm["scale"], source_tris, tris))
    print("  coques  %d ouvertes epaissies a %.3f m, %d deja fermees ; %d aretes de bord restantes"
          % (shells["ouvertes"], LEAF_THICKNESS, shells["fermees"], shells["bords_restants"]))
    print("  emprise  X %.3f a %.3f   Y %.3f a %.3f   Z %.3f a %.3f"
          % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    print("  -> arena.PROPS : \"size\": Vector2(%.2f, %.2f)" % (hi.x - lo.x, hi.y - lo.y))
    print("  Attr_Style  R %.2f-%.2f   G 0.50   B 0.00" % stats["r"])

    if "--texture" in sys.argv:
        if TEXTURE.exists() and "--force" not in sys.argv:
            print("  texture  DEJA LA, rien ecrit — ajouter --force pour l'ECRASER")
        else:
            info = bake_texture(image, TEXTURE)
            print("  texture  %dx%d -> %dx%d, %.0f %% couverte avant dilatation -> %s"
                  % (info["source"][0], info["source"][1], TEXTURE_SIZE, TEXTURE_SIZE,
                     info["couverture"] * 100.0, TEXTURE))

    # Les images de la source ne doivent pas partir dans le .blend : elles
    # pesent 7 Mo et n'ont plus aucun utilisateur.
    for leftover in list(bpy.data.images):
        if leftover.users == 0 or leftover == image:
            bpy.data.images.remove(leftover)

    if "--save" in sys.argv:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
        print("  ecrit dans %s" % OUTPUT)
    else:
        print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
