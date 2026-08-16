"""Reconstruit le contour du chat dans Blender, epaisseur pilotee par Attr_Style.R.

    "<blender>" --background chat_style_v3.blend --python tools/build_outline.py -- --save

Pourquoi ce script existe — il y avait DEUX contours, et ils ont divergé.

`chat_style_v1.blend` (le fichier de look) porte 21 objets, chacun avec son
propre Solidify a epaisseur CONSTANTE, reglee a la main et proportionnelle a
la taille de l'objet (0,049 sur la tete, 0,035 sur un tibia). En fusionnant
les 21 objets en `MSH_cat` pour l'export, le Solidify a ete retire : depuis,
`chat_style_v3.blend` n'a plus de contour du tout, et le viewport Blender ne
montre plus ce que le jeu affiche.

Cote Godot, `cel_outline.gdshader` fait `VERTEX += NORMAL * thickness * COLOR.r`
depuis la passe retro anime : l'epaisseur y est VARIABLE, portee par le canal R
d'`Attr_Style`. C'est cette version-la qui fait foi. Le script la rejoue ici, a
l'identique, sur le maillage fusionne.

TROIS GESTES

1. LE GROUPE DE SOMMETS `Attr_Style_R`
   Le champ *Thickness · Vertex Group* du Solidify ne lit pas une couleur de
   sommet, il lit un groupe de sommets. On transvase donc le canal R dans un
   groupe de meme valeur. Avec `thickness_vertex_group = 0` (facteur a poids
   nul), l'epaisseur devient `thickness x R` — la formule exacte du shader.

   Le groupe ne porte AUCUN nom d'os : ni l'`Armature` ni l'exporteur glTF ne
   le regardent (tous deux apparient les groupes par nom d'os). Il ne cree
   donc pas un 30e joint.

2. UN MATERIAU D'ENCRE PAR SURFACE
   Le Solidify ne sait decaler l'index de materiau que d'une CONSTANTE. Sur un
   maillage a N surfaces on pose donc les N encres en queue de liste, dans le
   meme ordre que les surfaces, et `material_offset = N` apparie chaque coque
   interne a son encre. C'est ce qui permet de reproduire le trait par
   materiau de `cel_model.gd` — le trait sombre `#1A120C` sur le pelage noir,
   la teinte reduite sur les surfaces claires (voir INKS / TINTS).

   La couleur locale n'est pas recopiee ici : elle est LUE dans le Color Ramp
   de chaque materiau, pose par `tools/paint_tuxedo.py`. Deux tables de palette
   qui doivent rester d'accord, c'est exactement le genre de divergence qu'on
   paye ensuite.

3. LE MODIFICATEUR `contour`
   Apres l'`Armature`, jamais avant : la coque doit suivre la deformation.

⚠️ Le contour NE DOIT PAS s'exporter (piege n°1 de "Pipeline 3D"). Il ne le
fait pas : `tools/export_cat.py` exporte sans appliquer les modificateurs, et
verifie que chaque position du .glb retombe sur un sommet du maillage de base.
Une coque solidifiee arriverait a 0,041 du sien et ferait echouer l'export.
"""

import sys

import bpy

MESH_OBJECT = "MSH_cat"
ATTRIBUTE = "Attr_Style"
MODIFIER = "contour"
THICKNESS_GROUP = "Attr_Style_R"
INK_PREFIX = "INK_"

# `outline_thickness` de cel_model.gd. Relevee de 0,035 a 0,041 quand le canal
# R est arrive : R vaut ~0,85 en moyenne, donc 0,041 x 0,85 ~ 0,035, l'ancienne
# epaisseur constante. Les deux cotes doivent porter la MEME valeur.
THICKNESS = 0.041

# Encres de cel_model.gd. Le trait doit rester plus sombre que l'aplat qu'il
# cerne ET que son ton d'ombre : sur le pelage noir, `#3D2B1A` repasse au-dessus
# du ton d'ombre et se lit comme une lumiere.
INK = "#3D2B1A"
INK_SOMBRE = "#1A120C"
INKS = {
    "fourrure": INK_SOMBRE,
    "corps_peint": INK_SOMBRE,
    "visage": INK_SOMBRE,
    "oreille_peinte": INK_SOMBRE,
}

# Trait colore (色トレス) : melange vers la couleur locale, en LINEAIRE comme le
# fait le shader. Vers un creme a 0,93 de luminance lineaire, 20 % delavent le
# trait a un gris ; les surfaces claires gardent donc l'ecart PERCU, pas la dose.
TINT = 0.2
TINT_CLAIR = 0.06
MATERIAUX_CLAIRS = ("ventre", "museau_peint", "fourrure_blanche")


def srgb_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def hex_to_linear(code: str) -> tuple:
    code = code.lstrip("#")
    return tuple(srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def linear_to_hex(rgb: tuple) -> str:
    def encode(value: float) -> int:
        if value <= 0.0031308:
            srgb = value * 12.92
        else:
            srgb = 1.055 * (value ** (1.0 / 2.4)) - 0.055
        return int(round(min(1.0, max(0.0, srgb)) * 255.0))

    return "#%02X%02X%02X" % tuple(encode(c) for c in rgb)


def local_color(material) -> tuple:
    """La couleur locale = l'arret de LUMIERE du cluster 2 tons."""
    if material.node_tree is None:
        sys.exit("ECHEC : le materiau '%s' n'a pas de node tree" % material.name)

    for node in material.node_tree.nodes:
        if node.bl_idname == "ShaderNodeValToRGB":
            elements = sorted(node.color_ramp.elements, key=lambda e: e.position)
            return tuple(elements[-1].color[:3])

    sys.exit("ECHEC : aucun Color Ramp dans '%s'" % material.name)


def ink_color(material) -> tuple:
    """L'encre de cette surface, calculee comme `cel_outline.gdshader` la calcule."""
    base = hex_to_linear(INKS.get(material.name, INK))
    target = local_color(material)
    amount = TINT_CLAIR if material.name in MATERIAUX_CLAIRS else TINT
    return tuple(base[i] + (target[i] - base[i]) * amount for i in range(3))


def build_thickness_group(obj) -> dict:
    """Transvase Attr_Style.R dans un groupe de sommets de meme valeur.

    On lit `.color`, comme le fait `tools/export_cat.py` — c'est cette valeur-la
    qui part dans `COLOR_0` et arrive telle quelle dans le shader. Passer par
    `.color_srgb` decalerait Blender de Godot.
    """
    mesh = obj.data
    attr = mesh.color_attributes.get(ATTRIBUTE)

    if attr is None:
        sys.exit("ECHEC : attribut '%s' absent du maillage" % ATTRIBUTE)
    if attr.domain != "POINT":
        sys.exit("ECHEC : '%s' doit etre sur le domaine POINT (trouve : %s)"
                 % (ATTRIBUTE, attr.domain))

    group = obj.vertex_groups.get(THICKNESS_GROUP)

    if group is None:
        group = obj.vertex_groups.new(name=THICKNESS_GROUP)

    # Byte Color : au plus 256 valeurs distinctes. On assigne par paquets
    # plutot qu'un appel par sommet.
    buckets = {}
    for index in range(len(mesh.vertices)):
        buckets.setdefault(attr.data[index].color[0], []).append(index)

    for weight, indices in buckets.items():
        group.add(indices, weight, "REPLACE")

    values = sorted(buckets)
    return {"paliers": len(buckets), "min": values[0], "max": values[-1],
            "moyenne": sum(w * len(i) for w, i in buckets.items()) / len(mesh.vertices)}


def base_material_count(obj) -> int:
    """Les slots d'encre vivent toujours en QUEUE de liste, apres les surfaces."""
    names = [m.name if m else "" for m in obj.data.materials]
    count = len(names)

    while count > 0 and names[count - 1].startswith(INK_PREFIX):
        count -= 1

    for polygon in obj.data.polygons:
        if polygon.material_index >= count:
            sys.exit("ECHEC : une face pointe le slot %d, hors des %d surfaces"
                     % (polygon.material_index, count))

    return count


def build_ink_materials(obj) -> list:
    """Pose une encre par surface, dans le MEME ORDRE que les surfaces."""
    count = base_material_count(obj)
    bases = [obj.data.materials[i] for i in range(count)]

    # Rejouable : on repart des surfaces seules, les encres sont reconstruites.
    while len(obj.data.materials) > count:
        obj.data.materials.pop()

    report = []
    for base in bases:
        name = INK_PREFIX + base.name
        material = bpy.data.materials.get(name)

        if material is None:
            material = bpy.data.materials.new(name=name)

        material.use_nodes = True
        material.use_backface_culling = True
        nodes = material.node_tree.nodes
        nodes.clear()

        color = ink_color(base)
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Color"].default_value = color + (1.0,)
        output = nodes.new("ShaderNodeOutputMaterial")
        material.node_tree.links.new(emission.outputs["Emission"],
                                     output.inputs["Surface"])

        obj.data.materials.append(material)
        report.append((base.name, name, linear_to_hex(color)))

    return report


def build_modifier(obj, base_count: int):
    modifier = obj.modifiers.get(MODIFIER)

    if modifier is None:
        modifier = obj.modifiers.new(name=MODIFIER, type="SOLIDIFY")

    if modifier.type != "SOLIDIFY":
        sys.exit("ECHEC : le modificateur '%s' n'est pas un Solidify" % MODIFIER)

    # Apres l'Armature : la coque doit suivre la deformation, pas la precéder.
    index = list(obj.modifiers).index(modifier)
    while index < len(obj.modifiers) - 1:
        obj.modifiers.move(index, index + 1)
        index += 1

    modifier.solidify_mode = "EXTRUDE"
    modifier.thickness = THICKNESS
    # offset 1 = la coque part entierement vers l'exterieur, comme le
    # `VERTEX += NORMAL * w` du shader. Centree (0), elle rentrerait de moitie.
    modifier.offset = 1.0
    modifier.use_even_offset = False
    modifier.use_flip_normals = True
    modifier.use_rim = False
    modifier.material_offset = base_count
    modifier.material_offset_rim = base_count
    modifier.vertex_group = THICKNESS_GROUP
    modifier.invert_vertex_group = False
    # Facteur a poids nul. A 0, l'epaisseur vaut `thickness x poids`, donc
    # `thickness x R` : la formule du shader, au bit pres.
    modifier.thickness_vertex_group = 0.0
    return modifier


def verify(obj) -> dict:
    """Mesure la coque REELLE, plutot que de croire les reglages.

    Le Solidify sort les sommets de coque a la suite des originaux, dans le
    meme ordre : le sommet `n + i` est le double du sommet `i`. On en deduit
    l'epaisseur effective sommet par sommet, et l'appariement des encres.
    """
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()

    source = obj.data
    count = len(source.vertices)

    if len(mesh.vertices) != 2 * count:
        evaluated.to_mesh_clear()
        sys.exit("ECHEC : coque attendue a %d sommets, obtenue a %d"
                 % (2 * count, len(mesh.vertices)))

    attr = source.color_attributes[ATTRIBUTE]
    worst = 0.0
    thin = float("inf")
    thick = 0.0

    for index in range(count):
        offset = mesh.vertices[count + index].co - mesh.vertices[index].co
        measured = offset.length
        expected = THICKNESS * attr.data[index].color[0]
        worst = max(worst, abs(measured - expected))
        thin = min(thin, measured)
        thick = max(thick, measured)

    base_count = base_material_count(obj)
    pairing = {}
    for polygon in mesh.polygons:
        first = mesh.loops[polygon.loop_start].vertex_index
        side = "surface" if first < count else "encre"
        pairing.setdefault((side, polygon.material_index), 0)
        pairing[(side, polygon.material_index)] += 1

    evaluated.to_mesh_clear()

    mismatched = [key for key in pairing
                  if (key[0] == "encre") != (key[1] >= base_count)]

    return {"ecart_max": worst, "mince": thin, "epais": thick,
            "rapport": thick / thin if thin else 0.0, "mismatched": mismatched}


def main() -> None:
    obj = bpy.data.objects.get(MESH_OBJECT)

    if obj is None:
        sys.exit("ECHEC : objet '%s' introuvable" % MESH_OBJECT)

    weights = build_thickness_group(obj)
    inks = build_ink_materials(obj)
    build_modifier(obj, len(inks))
    measured = verify(obj)

    print("\n[build_outline] %s" % MESH_OBJECT)
    print("  groupe '%s' : %d paliers, R de %.3f a %.3f (moyenne %.3f)"
          % (THICKNESS_GROUP, weights["paliers"], weights["min"], weights["max"],
             weights["moyenne"]))
    print("  epaisseur de base %.3f -> coque reelle de %.4f a %.4f (x%.2f)"
          % (THICKNESS, measured["mince"], measured["epais"], measured["rapport"]))
    print("  ecart max a `thickness x R` : %.6f" % measured["ecart_max"])

    if measured["ecart_max"] > 1e-5:
        sys.exit("ECHEC : la coque ne suit pas le canal R")
    if measured["mismatched"]:
        sys.exit("ECHEC : encres mal appariees %r" % measured["mismatched"])

    for base, ink, code in inks:
        print("    %-18s -> %-22s %s" % (base, ink, code))

    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("  .blend enregistre")
    else:
        print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
