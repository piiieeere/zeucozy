"""Construit le canape club rebondi, geometrie ET Attr_Style, dans un .blend neuf.

    "<blender>" --background --factory-startup \
        --python tools/build_couch.py -- --save

Pourquoi tout est ici, et pas reparti en trois scripts comme pour le chat.
Le chat a ete modelise a la main : sa geometrie est une donnee d'entree, et
`paint_tuxedo.py` doit repeindre PAR-DESSUS un maillage qu'il n'a pas fait.
Le canape, lui, est entierement procedural — sa geometrie et sa peinture ont
la meme source. Les separer creerait exactement le decalage que le chat a paye
cher : une peinture calee sur une version du maillage qui n'existe plus.

Ce que le script produit :

  * UN objet `MSH_canape`, 12 coques fusionnees, normales unifiees, tout en
    shade_smooth. Les coques s'interpenetrent volontairement — la coque
    inversee de Godot y dessinera les COUTURES du capitonnage. C'est le
    piege n°2 de "Pipeline 3D" retourne en decor.
  * DEUX materiaux, `tissu` et `coussin`, chacun avec la chaine toon complete
    de "Convention Blender" §5.1 (Shader to RGB -> Color Ramp CONSTANT 2 tons),
    Attr_Style.G cable dedans. Le .blend est donc jugeable dans son viewport,
    ce que le chat n'a longtemps pas ete.
  * `Attr_Style` peint (Byte Color, domaine POINT) : R = epaisseur du trait,
    G = forme des ombres, B = masque d'accent.

Aucun Solidify : le contour ne s'exporte pas (piege n°1) et Godot le refait.

PROPORTIONS — decision du 2026-08-16, option "semi-realiste".
L'emprise au sol (6,4 x 2,6 m) est deja juste : ~4 longueurs de chat, le
rapport reel chat/canape. C'est la VERTICALE qui ment, et volontairement.
Un vrai canape vu par un chat de 1,86 unite culminerait a 6,3 m ; a 45° de
plongee, 6,3 m occultent un pan d'arene entier (§15, lisibilite > detail).
Le dossier s'arrete donc a 3,2 m — assez pour que le chat pose sur l'assise
(1,6 + 1,86 = 3,46) le DEPASSE de 0,26 et reste lisible dessus.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/prop_canape_v1.blend")

COLLECTION = "prop_canape"
MESH_OBJECT = "MSH_canape"
ATTRIBUTE = "Attr_Style"

# ---------------------------------------------------------------- dimensions

LENGTH = 6.4          # X — l'emprise qu'arena.gd pose deja
DEPTH = 2.6           # Y — le canape regarde -Y (convention du chat)
SEAT_TOP = 1.6        # hauteur d'assise : ce sur quoi le chat saute
BACK_TOP = 3.2        # haut du dossier

BASE_TOP = 1.15       # le socle, sous les coussins
ROLL_RADIUS = 0.50    # accoudoir roule
ARM_INNER = 2.275     # bord interieur de l'accoudoir, en |x|

# Trois travees : trois coussins d'assise, trois bosses de dossier.
BAY_X = (-1.53, 0.0, 1.53)
BAY_WIDTH = 1.48

# "Meubles avec personnalite, legerement tordus" (§12). Deterministe : le decor
# doit etre identique d'une run a l'autre, sinon on ne peut plus juger un
# changement de rendu par comparaison.
# Les ecarts ne montent JAMAIS : BACK_TOP est une promesse de cadrage (le chat
# assis doit le depasser), pas une moyenne. Le dossier s'affaisse donc au
# milieu, ce qui est de toute facon ce que fait un vieux canape.
BAY_TILT = (1.4, -0.8, 1.9)      # degres, autour de Z
BAY_NUDGE = (0.03, -0.02, 0.04)  # metres, en Y
BAY_RISE = (0.0, -0.07, -0.03)   # metres, hauteur du dossier

# Materiaux. Deux seulement — §5 veut UNE couleur principale par objet, et le
# coussin n'est pas une seconde couleur : c'est la meme, d'un cran plus claire,
# pour que le capitonnage se detache du bati sans ajouter de teinte.
#
# Ces valeurs ne servent qu'au viewport Blender. Godot repose sa propre palette
# au chargement (cel_prop.gd), exactement comme pour le chat.
TISSU = "#8FBAC9"     # bleu ciel Ghibli §4, assombri d'un cran
COUSSIN = "#A0C8D8"   # le bleu ciel Ghibli lui-meme

MAT_TISSU = 0
MAT_COUSSIN = 1

# Memes reglages que les uniforms de cel_toon.gdshader : le ton d'ombre de
# Blender est celui de Godot, et non un second reglage a la main.
SHADOW_HUE_SHIFT = -0.02
SHADOW_SATURATION = 1.15
SHADOW_VALUE = 0.65

RAMP_SPLIT = 0.52


# ------------------------------------------------------------------- couleurs

def srgb_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def hex_to_linear(code: str) -> tuple:
    code = code.lstrip("#")
    return tuple(srgb_to_linear(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


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


# ------------------------------------------------------------------ geometrie

def bevel(bm, verts, offset: float, segments: int, angle_min: float = 20.0) -> None:
    """Arrondit les aretes vives d'une partie. §3 : aucun angle vif, nulle part.

    Le filtre d'angle est ce qui rend la fonction utilisable sur un cylindre
    comme sur une boite : sur la boite les 12 aretes passent, sur le rouleau
    d'accoudoir seuls les deux cercles de bord passent — les aretes qui courent
    le long du tube sont plates et resteraient chargees de geometrie pour rien.
    """
    edges = {e for v in verts for e in v.link_edges}
    faces = {f for v in verts for f in v.link_faces}
    sharp = [e for e in edges
             if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(angle_min)]

    bmesh.ops.bevel(
        bm,
        geom=list(verts) + sharp + list(faces),
        offset=offset,
        offset_type="OFFSET",
        segments=segments,
        profile=0.5,
        affect="EDGES",
        clamp_overlap=True,
    )


def add_part(bm, parts: dict, name: str, material: int, maker) -> None:
    """Ajoute une coque au maillage commun et retient a qui appartient chaque sommet.

    Le passage par un bmesh temporaire n'est pas un detour : `from_mesh` ajoute
    en fin de tableau, ce qui donne gratuitement la tranche de sommets de la
    partie. Beveler directement dans le bmesh commun brouillerait ce reperage,
    le bevel creant et detruisant des elements.
    """
    temp = bmesh.new()
    maker(temp)
    mesh = bpy.data.meshes.new("__tmp")
    temp.to_mesh(mesh)
    temp.free()

    first_vert = len(bm.verts)
    first_face = len(bm.faces)
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)

    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()

    # Numeroter par le RANG dans la tranche, jamais par `vertex.index` : celui-ci
    # n'est mis a jour qu'a la demande, et s'il est perime toutes les coques
    # ecrasent la meme entree. Le rang, lui, est exact par construction, et
    # `to_mesh` conservera cet ordre.
    for offset, vertex in enumerate(bm.verts[first_vert:]):
        parts[first_vert + offset] = name

    for face in bm.faces[first_face:]:
        face.material_index = material


def box(center, size, offset: float, segments: int, tilt_deg: float = 0.0):
    def make(bm):
        result = bmesh.ops.create_cube(bm, size=1.0)
        verts = result["verts"]
        bmesh.ops.scale(bm, vec=Vector(size), verts=verts)

        if tilt_deg:
            bmesh.ops.rotate(
                bm, cent=(0.0, 0.0, 0.0), verts=verts,
                matrix=Matrix.Rotation(math.radians(tilt_deg), 3, "Z"),
            )

        bmesh.ops.translate(bm, vec=Vector(center), verts=verts)
        bevel(bm, verts, offset, segments)

    return make


def roll(center, radius: float, length: float):
    """Accoudoir roule — un tube couche dans l'axe avant/arriere, bords arrondis."""

    def make(bm):
        try:
            result = bmesh.ops.create_cone(
                bm, cap_ends=True, cap_tris=False, segments=16,
                radius1=radius, radius2=radius, depth=length,
            )
        except TypeError:
            result = bmesh.ops.create_cone(
                bm, cap_ends=True, cap_tris=False, segments=16,
                diameter1=radius, diameter2=radius, depth=length,
            )

        verts = result["verts"]
        # Cree debout (axe Z), il faut le coucher dans l'axe Y.
        bmesh.ops.rotate(
            bm, cent=(0.0, 0.0, 0.0), verts=verts,
            matrix=Matrix.Rotation(math.radians(90.0), 3, "X"),
        )
        bmesh.ops.translate(bm, vec=Vector(center), verts=verts)
        bevel(bm, verts, radius * 0.34, 3, angle_min=45.0)

    return make


def build_mesh():
    bm = bmesh.new()
    parts: dict = {}

    arm_x = LENGTH * 0.5 - ROLL_RADIUS
    arm_width = arm_x + ROLL_RADIUS - ARM_INNER

    # 1. Le socle — il porte tout et descend jusqu'au sol.
    add_part(bm, parts, "socle", MAT_TISSU,
             box((0.0, 0.0, BASE_TOP * 0.5), (LENGTH, DEPTH, BASE_TOP), 0.16, 2))

    # 2. Le panneau arriere. Il ferme la silhouette de dos, la ou les bosses de
    #    dossier laisseraient trois trous.
    add_part(bm, parts, "panneau", MAT_TISSU,
             box((0.0, 1.16, 2.0), (LENGTH, 0.28, 2.0), 0.10, 2))

    # 3. Les accoudoirs : un support, un rouleau pose dessus.
    for side, sign in (("L", -1.0), ("R", 1.0)):
        add_part(bm, parts, "accoudoir_%s" % side, MAT_TISSU,
                 box((sign * (ARM_INNER + arm_width * 0.5), 0.0, 1.0),
                     (arm_width, DEPTH, 2.0), 0.18, 2))
        add_part(bm, parts, "rouleau_%s" % side, MAT_TISSU,
                 roll((sign * arm_x, 0.0, 2.0), ROLL_RADIUS, DEPTH))

    # 4. Les trois coussins d'assise — la plateforme sur laquelle le chat saute.
    for i, x in enumerate(BAY_X):
        add_part(bm, parts, "assise_%d" % i, MAT_COUSSIN,
                 box((x, -0.35 + BAY_NUDGE[i], (1.10 + SEAT_TOP) * 0.5),
                     (BAY_WIDTH, 1.80, SEAT_TOP - 1.10), 0.20, 3, BAY_TILT[i]))

    # 5. Les trois bosses du dossier.
    for i, x in enumerate(BAY_X):
        top = BACK_TOP + BAY_RISE[i]
        add_part(bm, parts, "dossier_%d" % i, MAT_COUSSIN,
                 box((x, 0.79 + BAY_NUDGE[i] * 0.5, (1.30 + top) * 0.5),
                     (BAY_WIDTH, 0.85, top - 1.30), 0.24, 3, -BAY_TILT[i] * 0.6))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    for face in bm.faces:
        face.smooth = True

    mesh = bpy.data.meshes.new(MESH_OBJECT)
    bm.to_mesh(mesh)
    bm.free()

    return mesh, parts


# -------------------------------------------------------------- Attr_Style

def paint(mesh, parts: dict) -> dict:
    """Peint R, G et B. Voir "Convention Blender" §4 pour le contrat des canaux.

    Tout se decide sur la POSITION et la NORMALE, jamais sur l'eclairage : dans
    un anime, l'ombre sous un coussin est la parce que le dessinateur l'a
    voulue, et elle ne bouge pas quand la piece tourne (§2ter·2).
    """
    attr = mesh.color_attributes.get(ATTRIBUTE)

    if attr is None:
        attr = mesh.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="POINT")

    stats = {"r": [2.0, -1.0], "g": [2.0, -1.0], "b": [2.0, -1.0]}

    for i, vertex in enumerate(mesh.vertices):
        x, y, z = vertex.co
        n = vertex.normal
        part = parts.get(i, "")

        # ---- R : epaisseur du trait -------------------------------------
        # Le trait s'alourdit vers le bas, comme sous un objet pose. Puis il
        # s'epaissit aux jointures (le pli assise/dossier, le dessous des
        # accoudoirs) et s'allege sur les faces franchement exposees au ciel,
        # ou un trait gras ferait de la bavure.
        r = 1.0 - 0.40 * min(1.0, z / BACK_TOP)

        if 1.30 < z < 1.95 and 0.20 < y < 1.05:      # le pli assise / dossier
            r += 0.16
        if part.startswith("rouleau") and n.z < -0.25:  # dessous du roule
            r += 0.12
        if n.z > 0.80:
            r -= 0.10

        # ---- G : la forme des ombres ------------------------------------
        # Amplitude volontairement petite : le shader applique
        # `biais = (G - 0,5) x 2`, donc G = 0,30 vaut deja -0,40 de seuil.
        # Peindre jusqu'a 0 figerait la surface en ombre permanente.
        g = 0.52

        if n.z < -0.20:                              # tout dessous de volume
            g -= 0.10 * min(1.0, -n.z * 1.6)
        if z < 0.55:                                 # la plinthe, au ras du sol
            g -= 0.10 * (1.0 - z / 0.55)
        if 1.25 < z < 2.05 and 0.15 < y < 1.05:      # le creux du dossier
            g -= 0.16
        if part.startswith("assise") and y < -0.75 and z < 1.35:  # sous la lippe
            g -= 0.12
        if part.startswith("accoudoir") and z > 1.5 and abs(x) < LENGTH * 0.5 - 0.9:
            g -= 0.08                                # flanc interieur, a l'ombre du roule

        # LES DEUX OMBRES PORTEES, et ce sont elles qui font lire le canape de
        # dessus. Sans elles, une camera qui plonge ne voit que des faces
        # tournees vers le ciel : tout tombe du meme cote du cluster et le
        # meuble s'aplatit en un seul aplat. Rien ne les calcule — c'est le
        # dessinateur qui decide ou l'ombre tombe (§2ter·2).
        if part.startswith("assise"):
            # Le dossier se projette sur l'arriere de l'assise.
            g -= 0.16 * min(1.0, max(0.0, (y + 0.25) / 0.50))
            # Les accoudoirs se projettent sur les bords de l'assise.
            g -= 0.10 * min(1.0, max(0.0, (abs(x) - 1.85) / 0.35))

        if part.startswith("dossier") and n.z > 0.70 and z > BACK_TOP - 0.55:
            g += 0.04                                # les bosses prennent le jour
        if part.startswith("rouleau") and n.z > 0.70:
            g += 0.04

        # ---- B : masque d'accent ----------------------------------------
        # Une BANDE, pas une calotte ("Convention Blender" §4) : seuil de
        # normale serre, et une porte en hauteur pour que l'accent ne tombe
        # que sur ce que la lumiere frappe vraiment de plein fouet.
        b = 0.0

        if part.startswith("rouleau"):
            # Cale sur la POSITION, pas sur la normale. Sur un tube a 16 pans,
            # `n.z > 0,90` laisse passer un arc de 25° de part et d'autre, soit
            # 42 % du diametre : la "grande selle pale" contre laquelle
            # "Convention Blender" §4 met en garde, et qu'on a bien obtenue au
            # premier jet. Une bande en x fait exactement 0,26 m, quel que soit
            # le nombre de pans.
            if abs(abs(x) - (LENGTH * 0.5 - ROLL_RADIUS)) < 0.13 and n.z > 0.5:
                b = 1.0
        elif part.startswith("dossier") and n.z > 0.85 and z > BACK_TOP - 0.30:
            b = 1.0

        r = min(1.0, max(0.55, r))
        g = min(0.56, max(0.30, g))

        attr.data[i].color = (r, g, b, 1.0)

        for key, value in (("r", r), ("g", g), ("b", b)):
            stats[key][0] = min(stats[key][0], value)
            stats[key][1] = max(stats[key][1], value)

    # `active` designe l'attribut qu'edite l'outil de peinture, `default_color`
    # celui que l'exporteur glTF sort en `COLOR_0`. Les deux doivent pointer sur
    # Attr_Style, sinon l'export part sur un autre attribut — ou sur rien.
    mesh.color_attributes.active_color_name = ATTRIBUTE
    mesh.color_attributes.default_color_name = ATTRIBUTE

    return stats


# -------------------------------------------------------------- materiaux

def toon_material(name: str, code: str):
    """La chaine de "Convention Blender" §5.1, montee au node pres.

    Attr_Style.G est CABLE ici, pas seulement peint. C'est la lecon du chat :
    peint mais non branche, le viewport Blender est aveugle aux ombres et on
    passe la soiree a deplacer un soleil.
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


# ------------------------------------------------------------------- scene

def setup_scene() -> None:
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
    mesh.materials.append(toon_material("tissu", TISSU))
    mesh.materials.append(toon_material("coussin", COUSSIN))
    stats = paint(mesh, parts)

    obj = bpy.data.objects.new(MESH_OBJECT, mesh)

    collection = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    collection.objects.link(obj)

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    lo = Vector((min(v.co[i] for v in mesh.vertices) for i in range(3)))
    hi = Vector((max(v.co[i] for v in mesh.vertices) for i in range(3)))

    print("\n[build_couch] %s" % MESH_OBJECT)
    print("  %d sommets, %d faces, %d tris" % (len(mesh.vertices), len(mesh.polygons), tris))
    print("  emprise  X %.2f a %.2f   Y %.2f a %.2f   Z %.2f a %.2f"
          % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    print("  assise a %.2f   dossier a %.2f   (chat = 1.86)" % (SEAT_TOP, BACK_TOP))
    print("  %d coques : %s" % (len(set(parts.values())), ", ".join(sorted(set(parts.values())))))
    print("  Attr_Style  R %.2f-%.2f   G %.2f-%.2f   B %.2f-%.2f"
          % (stats["r"][0], stats["r"][1], stats["g"][0], stats["g"][1],
             stats["b"][0], stats["b"][1]))

    if "--save" in sys.argv:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
        print("  ecrit dans %s" % OUTPUT)
    else:
        print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
