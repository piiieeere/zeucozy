"""Exporte un meuble en glTF avec Attr_Style intact.

    "<blender>" --background prop_canape_v1.blend --python tools/export_prop.py \
        -- --mesh MSH_canape --out prop_canape.glb

Meme parade que `export_cat.py`, et pour la meme raison : l'exporteur glTF de
Blender 5.2 ne remplit `COLOR_0` que sur la PREMIERE primitive d'un maillage
multi-materiaux (piege n°6 de "Pipeline 3D"). Ici le canape en a deux, `tissu`
et `coussin` : sans correction, `coussin` sortirait en blanc pur, donc G = 1,0,
donc les six coussins en pleine lumiere permanente — un defaut qui ne ressemble
pas a un probleme d'export.

Deux scripts plutot qu'un, et c'est deliberatif :

  * `export_cat.py` reste INTOUCHE. C'est le seul chemin d'export du chat, il
    est prouve bout en bout, et il porte un squelette et des animations dont la
    cadence en pas meurt au moindre reglage de travers. Le refactoriser pour
    factoriser une centaine de lignes echangerait un risque nul contre un
    risque reel ;
  * celui-ci est GENERIQUE et prend son maillage en argument : les prochains
    meubles (table basse, plante) n'auront pas de nouveau script a ecrire.

L'appariement se fait par POSITION, pas par index : l'exporteur reordonne et
dedouble les sommets (frontieres de materiau), mais il ne deplace jamais un
sommet. La seule transformation est la conversion Y-up du glTF, Blender
(x, y, z) -> glTF (x, z, -y). Le script echoue bruyamment si un sommet ne
retrouve pas son origine.
"""

import json
import math
import struct
import sys
from collections import defaultdict
from pathlib import Path

import bpy

ATTRIBUTE = "Attr_Style"
MODELS = Path(__file__).resolve().parent.parent / "assets" / "models"

GLTF_JSON_CHUNK = 0x4E4F534A
GLTF_BIN_CHUNK = 0x004E4942


def argument(name: str, default: str = "") -> str:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    flag = "--%s=" % name

    for i, arg in enumerate(argv):
        if arg.startswith(flag):
            return arg[len(flag):]
        if arg == "--%s" % name and i + 1 < len(argv):
            return argv[i + 1]

    return default


def f32(value: float) -> float:
    """Arrondit comme le fera le fichier : l'exporteur ecrit du float32."""
    return struct.unpack("<f", struct.pack("<f", value))[0]


def export(obj, path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_materials="EXPORT",
        # Cree un COLOR_0 sur toutes les primitives — meme si une seule est
        # remplie. C'est ce qu'on vient reecrire juste apres.
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_active_vertex_color_when_no_material=True,
        # Un meuble n'a ni squelette ni animation : ne rien embarquer d'inutile.
        export_skins=False,
        export_animations=False,
    )


def read_painted_style(obj) -> dict:
    """{position glTF -> (r, g, b)} depuis l'attribut peint dans Blender."""
    mesh = obj.data
    attr = mesh.color_attributes.get(ATTRIBUTE)

    if attr is None:
        sys.exit("ECHEC : attribut '%s' absent de '%s'" % (ATTRIBUTE, obj.name))
    if attr.domain != "POINT":
        sys.exit("ECHEC : '%s' doit etre sur le domaine POINT (trouve : %s)"
                 % (ATTRIBUTE, attr.domain))

    table = {}

    for index, vertex in enumerate(mesh.vertices):
        co = vertex.co
        table[(f32(co.x), f32(co.z), f32(-co.y))] = tuple(attr.data[index].color[:3])

    return table


def split_glb(data: bytes):
    if data[:4] != b"glTF":
        sys.exit("ECHEC : ce n'est pas un .glb")

    chunks, offset = [], 12

    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        chunks.append((kind, offset + 8, length))
        offset += 8 + length

    return chunks


def inject(path: Path, style: dict) -> dict:
    data = bytearray(path.read_bytes())
    gltf = None
    bin_offset = None

    for kind, start, length in split_glb(data):
        if kind == GLTF_JSON_CHUNK:
            gltf = json.loads(bytes(data[start:start + length]))
        elif kind == GLTF_BIN_CHUNK:
            bin_offset = start

    if gltf is None or bin_offset is None:
        sys.exit("ECHEC : chunks glTF introuvables")

    # Grille de repli, pour un sommet dont la position ne tombe pas au bit pres.
    grid = defaultdict(list)

    for key in style:
        grid[tuple(int(math.floor(c * 100.0)) for c in key)].append(key)

    def nearest(position):
        cell = tuple(int(math.floor(c * 100.0)) for c in position)
        best, best_d = None, float("inf")

        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for key in grid.get((cell[0] + dx, cell[1] + dy, cell[2] + dz), ()):
                        d = sum((key[i] - position[i]) ** 2 for i in range(3))

                        if d < best_d:
                            best, best_d = key, d

        return best, math.sqrt(best_d) if best else None

    materials = [m.get("name") for m in gltf.get("materials", [])]
    report = {"surfaces": {}, "exact": 0, "approx": 0, "worst_distance": 0.0}

    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            name = materials[primitive["material"]] if "material" in primitive else "?"

            if "COLOR_0" not in primitive["attributes"]:
                sys.exit("ECHEC : COLOR_0 absent de la primitive '%s'" % name)

            pos_accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
            col_accessor = gltf["accessors"][primitive["attributes"]["COLOR_0"]]

            if col_accessor["componentType"] != 5123 or col_accessor["type"] != "VEC4":
                sys.exit("ECHEC : COLOR_0 attendu en VEC4/UNSIGNED_SHORT sur '%s'" % name)
            if pos_accessor["count"] != col_accessor["count"]:
                sys.exit("ECHEC : POSITION et COLOR_0 desaccordes sur '%s'" % name)

            pos_view = gltf["bufferViews"][pos_accessor["bufferView"]]
            col_view = gltf["bufferViews"][col_accessor["bufferView"]]
            pos_base = bin_offset + pos_view.get("byteOffset", 0) + pos_accessor.get("byteOffset", 0)
            col_base = bin_offset + col_view.get("byteOffset", 0) + col_accessor.get("byteOffset", 0)
            pos_stride = pos_view.get("byteStride") or 12
            col_stride = col_view.get("byteStride") or 8

            exact = approx = 0

            for i in range(pos_accessor["count"]):
                position = struct.unpack_from("<fff", data, pos_base + i * pos_stride)
                painted = style.get(position)

                if painted is not None:
                    exact += 1
                else:
                    key, distance = nearest(position)

                    if key is None:
                        sys.exit("ECHEC : position %r introuvable sur '%s'" % (position, name))

                    painted = style[key]
                    report["worst_distance"] = max(report["worst_distance"], distance)
                    approx += 1

                struct.pack_into(
                    "<HHHH", data, col_base + i * col_stride,
                    *(min(65535, max(0, int(round(c * 65535.0)))) for c in painted), 65535,
                )

            report["surfaces"][name] = {"vertices": pos_accessor["count"],
                                        "exact": exact, "approx": approx}
            report["exact"] += exact
            report["approx"] += approx

    path.write_bytes(bytes(data))
    return report


def main() -> None:
    mesh_name = argument("mesh")
    out_name = argument("out")

    if not mesh_name or not out_name:
        sys.exit("ECHEC : usage -- --mesh MSH_xxx --out prop_xxx.glb")

    obj = bpy.data.objects.get(mesh_name)

    if obj is None:
        sys.exit("ECHEC : objet '%s' introuvable" % mesh_name)

    output = MODELS / out_name
    output.parent.mkdir(parents=True, exist_ok=True)

    export(obj, output)
    report = inject(output, read_painted_style(obj))

    print("\n[export_prop] %s" % output)

    for name, stats in report["surfaces"].items():
        print("  %-15s %5d sommets  exact %5d  approche %3d"
              % (name, stats["vertices"], stats["exact"], stats["approx"]))

    print("  total exact %d / approche %d / ecart max %.6f"
          % (report["exact"], report["approx"], report["worst_distance"]))


main()
