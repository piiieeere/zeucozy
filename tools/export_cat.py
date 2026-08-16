"""Exporte le chat en glTF avec Attr_Style intact.

    "<blender>" --background chat_style_v3.blend --python tools/export_cat.py

Pourquoi ce script existe — l'exporteur glTF de Blender 5.2 n'arrive pas a
sortir `COLOR_0` sur ce maillage, et les trois modes echouent differemment :

  * `export_vertex_color='MATERIAL'` -> **rien**. La detection d'usage ne suit
    que les chemins PBR standards ; nos materiaux toon passent par
    `Shader to RGB` -> facteur de `Color Ramp` -> `Emission`, qu'elle ignore.
    Blender previent : *"The active Vertex Color will not be exported, as it
    is not used in the node tree of the material"*.
  * `export_vertex_color='ACTIVE'` ou `'NAME'` -> **la premiere primitive
    seulement**. Les cinq autres sortent en blanc pur (1,1,1). Le maillage
    porte 6 materiaux donc 6 primitives ; seule celle d'indice 0 est remplie.
    Le domaine de l'attribut (POINT ou CORNER) n'y change rien.

Sans correction, `visage`, `museau_peint`, `corps_peint`, `ventre` et
`oreille_peinte` arriveraient dans Godot avec G = 1,0 — un biais d'ombre
maximal, donc ces surfaces toujours en pleine lumiere.

La parade : on exporte en mode ACTIVE (qui cree bien un `COLOR_0` de la bonne
taille sur les 6 primitives), puis on **reecrit les octets** de ces accesseurs
depuis les valeurs peintes dans Blender. On ne touche ni au JSON ni a la
structure du binaire — seulement au contenu des accesseurs `COLOR_0`.

L'appariement se fait par **position**, pas par index : l'exporteur reordonne
et dedouble les sommets (coutures UV), mais il ne deplace jamais un sommet. La
seule transformation est la conversion Y-up du glTF, Blender (x, y, z) ->
glTF (x, z, -y). Le script verifie que 100 % des positions retrouvent leur
sommet d'origine et echoue bruyamment sinon.
"""

import json
import math
import struct
import sys
from collections import defaultdict
from pathlib import Path

import bpy

MESH_OBJECT = "MSH_cat"
ARMATURE_OBJECT = "squelette"
ATTRIBUTE = "Attr_Style"
OUTPUT = Path(__file__).resolve().parent.parent / "assets" / "models" / "player_cat.glb"

GLTF_JSON_CHUNK = 0x4E4F534A
GLTF_BIN_CHUNK = 0x004E4942

# Ecart tolere entre une position du .glb et son sommet d'origine. L'exporteur
# reordonne et dedouble les sommets mais n'en DEPLACE jamais un : l'ecart doit
# rester nul. Une valeur non nulle signifie qu'un modificateur a ete applique —
# typiquement le `contour` (Solidify) de `tools/build_outline.py`, dont la coque
# arriverait a `thickness x R` de son sommet. Le contour ne doit pas s'exporter
# ("Pipeline 3D", piege n°1) : mieux vaut echouer que sortir un asset a deux
# coques, que rien ne signalerait ensuite.
MAX_DISTANCE = 1e-5


def f32(value: float) -> float:
    """Arrondit comme le fera le fichier : l'exporteur ecrit du float32."""
    return struct.unpack("<f", struct.pack("<f", value))[0]


def export(path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for name in (MESH_OBJECT, ARMATURE_OBJECT):
        bpy.data.objects[name].select_set(True)
    bpy.context.view_layer.objects.active = bpy.data.objects[MESH_OBJECT]

    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_skins=True,
        export_materials="EXPORT",
        # Explicite, et pas par confiance dans le defaut : applique, le
        # `contour` de `tools/build_outline.py` doublerait le maillage d'une
        # coque inversee, et l'`Armature` cuirait la pose de repos.
        export_apply=False,
        # Cree un COLOR_0 sur les 6 primitives — meme si une seule est remplie.
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_active_vertex_color_when_no_material=True,
        # Piege n°4 : cochee, elle rebake toute animation en LINEAR et detruit
        # la cadence en pas. A laisser decochee.
        export_force_sampling=False,
        export_animations=True,
    )


def read_painted_style() -> dict:
    """{position glTF -> (r, g, b)} depuis l'attribut peint dans Blender."""
    mesh = bpy.data.objects[MESH_OBJECT].data
    attr = mesh.color_attributes.get(ATTRIBUTE)
    if attr is None:
        sys.exit("ECHEC : attribut '%s' absent du maillage" % ATTRIBUTE)
    if attr.domain != "POINT":
        sys.exit("ECHEC : '%s' doit etre sur le domaine POINT (trouve : %s)"
                 % (ATTRIBUTE, attr.domain))

    table = {}
    for index, vertex in enumerate(mesh.vertices):
        co = vertex.co
        key = (f32(co.x), f32(co.z), f32(-co.y))
        table[key] = tuple(attr.data[index].color[:3])
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
    chunks = split_glb(data)

    gltf = None
    bin_offset = None
    for kind, start, length in chunks:
        if kind == GLTF_JSON_CHUNK:
            gltf = json.loads(bytes(data[start:start + length]))
        elif kind == GLTF_BIN_CHUNK:
            bin_offset = start
    if gltf is None or bin_offset is None:
        sys.exit("ECHEC : chunks glTF introuvables")

    # Grille de repli : un sommet dont la position ne tombe pas au bit pres.
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

    for primitive in gltf["meshes"][0]["primitives"]:
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
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    export(OUTPUT)
    report = inject(OUTPUT, read_painted_style())

    print("\n[export_cat] %s" % OUTPUT)
    for name, stats in report["surfaces"].items():
        print("  %-15s %5d sommets  exact %5d  approche %3d"
              % (name, stats["vertices"], stats["exact"], stats["approx"]))
    print("  total exact %d / approche %d / ecart max %.6f"
          % (report["exact"], report["approx"], report["worst_distance"]))

    if report["worst_distance"] > MAX_DISTANCE:
        sys.exit("ECHEC : ecart max %.6f > %.6f — un modificateur a-t-il ete "
                 "applique ? Le contour ne doit pas s'exporter."
                 % (report["worst_distance"], MAX_DISTANCE))


main()
