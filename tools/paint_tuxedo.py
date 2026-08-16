"""Repeint le chat en tuxedo (noir et blanc) dans le .blend ouvert.

    "<blender>" --background chat_style_v3.blend --python tools/paint_tuxedo.py -- --save

Deux gestes, et un seul est indispensable.

1. LE MATERIAU BLANC DES EXTREMITES (indispensable)
   Les chaussettes et le bout de queue vivent dans la surface `fourrure`, qui
   porte aussi tout le reste du corps. Godot ne sait colorer qu'a la surface :
   sans nouveau materiau, il n'existe aucun moyen de peindre ces zones-la
   depuis `cel_model.gd`.

   Un masque en shader ne s'y substitue pas. Godot applique le skinning AVANT
   `vertex()` ("Pipeline 3D", piege n°5) : un masque calcule sur la position
   deformee glisserait des que la patte bouge, et le contre-poison (`rest_undo`)
   ne connait que DEUX os par surface — il en faudrait cinq ici (quatre pattes
   plus la queue). Une assignation de materiau, elle, est portee par la
   geometrie : elle ne glisse jamais.

   Le decoupage est mesure, pas devine : les quatre bouts de patte sont des
   coques rigides a poids 1 ("Pipeline 3D", piege n°3), donc `poids >= 0,999`
   les selectionne exactement. La queue, seule chaine a poids degrades, garde
   ce meme seuil : il isole la part strictement rigide de `queue_3`, soit la
   derniere boucle du point d'interrogation.

2. LES COULEURS COTE BLENDER (confort)
   Godot n'en lit aucune — `cel_model.gd` remplace tous les materiaux au
   chargement. On les repose quand meme pour que le .blend ne reste pas roux
   pendant que le jeu est noir et blanc.

   La divergence demeure sur le VISAGE : la bavette blanche du bas du museau
   est dessinee par `cel_face.gdshader`, en espace facial, et rien ne la
   represente ici — exactement comme les yeux, le nez et la bouche, que Blender
   ne peint pas non plus.
"""

import sys

import bpy

MESH_OBJECT = "MSH_cat"
SOURCE_MATERIAL = "fourrure"
WHITE_MATERIAL = "fourrure_blanche"

# Bouts de patte : quatre coques rigides, un os chacune.
SOCK_GROUPS = ("pattavant_L", "pattavant_R", "piedar_L", "piedar_R")
# Bout de queue : la part de `queue_3` que le degrade ne touche plus.
TAIL_GROUP = "queue_3"
RIGID_WEIGHT = 0.999

# Palette tuxedo — "Visual Art Direction" §4. Jamais de #000000 ni de blanc
# froid : le noir est un brun tres sombre, le blanc un creme chaud.
PALETTE = {
    "fourrure": "#4A4038",
    "corps_peint": "#40372F",
    "visage": "#4A4038",
    "oreille_peinte": "#4A4038",
    "ventre": "#F7EFE0",
    "museau_peint": "#F7EFE0",
    WHITE_MATERIAL: "#F7EFE0",
}

# Memes reglages que les uniforms de cel_toon.gdshader, pour que le ton d'ombre
# de Blender soit celui de Godot et non un second reglage a la main.
SHADOW_HUE_SHIFT = -0.02
SHADOW_SATURATION = 1.15
SHADOW_VALUE = 0.65


def srgb_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def hex_to_linear(code: str) -> tuple:
    code = code.lstrip("#")
    return tuple(srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def warm_shadow(rgb: tuple) -> tuple:
    """Le `warm_shadow()` de cel_core.gdshaderinc, en Python.

    Godot convertit `base_color` en lineaire avant d'y toucher (hint
    `source_color`) : le decalage TSV s'applique donc sur du lineaire, et on
    fait pareil ici pour obtenir le meme ton.
    """
    import colorsys

    h, s, v = colorsys.rgb_to_hsv(*rgb)
    h = (h + SHADOW_HUE_SHIFT) % 1.0
    s = min(1.0, s * SHADOW_SATURATION)
    v = v * SHADOW_VALUE
    return colorsys.hsv_to_rgb(h, s, v)


def color_ramp(material) -> "bpy.types.ShaderNodeValToRGB":
    if material.node_tree is None:
        sys.exit("ECHEC : le materiau '%s' n'a pas de node tree" % material.name)

    for node in material.node_tree.nodes:
        if node.bl_idname == "ShaderNodeValToRGB":
            return node

    sys.exit("ECHEC : aucun Color Ramp dans '%s'" % material.name)


def recolor(material, code: str) -> None:
    """Repose les deux tons du cluster. L'ombre est DERIVEE, jamais saisie."""
    ramp = color_ramp(material)

    if len(ramp.color_ramp.elements) != 2:
        sys.exit("ECHEC : '%s' n'est pas un cluster 2 tons (%d arrets)"
                 % (material.name, len(ramp.color_ramp.elements)))

    light = hex_to_linear(code)
    shadow = warm_shadow(light)
    # Position 0 = l'ombre, position haute = la lumiere.
    elements = sorted(ramp.color_ramp.elements, key=lambda e: e.position)
    elements[0].color = shadow + (1.0,)
    elements[1].color = light + (1.0,)


def ensure_white_material(obj):
    """Cree le materiau blanc par COPIE de `fourrure`.

    Une copie, et pas un materiau neuf : le node tree toon (Shader to RGB ->
    Color Ramp CONSTANT + les canaux d'Attr_Style) fait une trentaine de nodes
    qu'il n'y a aucune raison de reconstruire — seuls les deux tons changent.
    """
    existing = obj.data.materials.get(WHITE_MATERIAL)

    if existing is not None:
        return obj.data.materials.find(WHITE_MATERIAL)

    source = bpy.data.materials.get(SOURCE_MATERIAL)

    if source is None:
        sys.exit("ECHEC : materiau '%s' introuvable" % SOURCE_MATERIAL)

    white = source.copy()
    white.name = WHITE_MATERIAL
    obj.data.materials.append(white)
    return obj.data.materials.find(WHITE_MATERIAL)


def white_vertices(obj) -> set:
    groups = {g.name: g.index for g in obj.vertex_groups}

    for name in SOCK_GROUPS + (TAIL_GROUP,):
        if name not in groups:
            sys.exit("ECHEC : groupe de sommets '%s' absent" % name)

    wanted = {groups[name] for name in SOCK_GROUPS + (TAIL_GROUP,)}
    selected = set()

    for vertex in obj.data.vertices:
        for group in vertex.groups:
            if group.group in wanted and group.weight >= RIGID_WEIGHT:
                selected.add(vertex.index)
                break

    return selected


def assign(obj, white_index: int, selected: set) -> dict:
    """Assigne face par face. Une face est blanche si TOUS ses sommets le sont.

    La frontiere suit donc une boucle d'aretes existante — aucune face n'est
    coupee en deux, et le bord tombe la ou le maillage a deja une arete.
    """
    fur_index = obj.data.materials.find(SOURCE_MATERIAL)

    if fur_index < 0:
        sys.exit("ECHEC : materiau '%s' absent de l'objet" % SOURCE_MATERIAL)

    counts = {"blanches": 0, "rendues": 0}

    for polygon in obj.data.polygons:
        is_white = all(v in selected for v in polygon.vertices)

        if is_white:
            polygon.material_index = white_index
            counts["blanches"] += 1
        elif polygon.material_index == white_index:
            # Rejouable : une face qui ne remplit plus le critere revient au noir.
            polygon.material_index = fur_index
            counts["rendues"] += 1

    return counts


def main() -> None:
    obj = bpy.data.objects.get(MESH_OBJECT)

    if obj is None:
        sys.exit("ECHEC : objet '%s' introuvable" % MESH_OBJECT)

    white_index = ensure_white_material(obj)
    counts = assign(obj, white_index, white_vertices(obj))

    for name, code in PALETTE.items():
        material = obj.data.materials.get(name)

        if material is None:
            sys.exit("ECHEC : materiau '%s' absent de l'objet" % name)

        recolor(material, code)

    print("\n[paint_tuxedo] %s" % MESH_OBJECT)
    print("  %d faces blanches (pattes + bout de queue), %d rendues au noir"
          % (counts["blanches"], counts["rendues"]))
    for name, code in PALETTE.items():
        print("  %-18s %s" % (name, code))

    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("  .blend enregistre")
    else:
        print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
