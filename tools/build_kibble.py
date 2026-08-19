"""Construit la croquette d'XP, geometrie ET Attr_Style, dans un .blend neuf.

    "<blender>" --background --factory-startup \
        --python tools/build_kibble.py -- --save

Meme moule que `tools/build_couch.py` — un .blend REGENERE, jamais edite a la
main, parce que la geometrie et sa peinture `Attr_Style` ont la meme source. Les
separer rejouerait le decalage que le chat a paye cher : une peinture calee sur
une version du maillage qui n'existe plus.

La chaine de materiau toon et les deux helpers de couleur sont RECOPIES de
`build_couch.py` plutot que factorises. Deux raisons, et ce n'est pas de la
paresse : un script `--python` de Blender n'importe pas son voisin sans bricoler
`sys.path`, et surtout ces valeurs **ne servent qu'au viewport Blender** — Godot
repose sa propre palette au chargement (`cel_prop.gd`). Une divergence entre les
deux scripts ne peut donc rien casser en jeu.

FORME — le trefle a 3 lobes, tranche le 2026-08-19.
Une croquette pour chat, c'est un petit palet lobe. Trois lobes plutot que
quatre : a taille de jeu la croquette pese ~17 px de large, et pour un meme
rayon un trefle creuse des encoches deux fois plus profondes qu'un
quatre-feuilles — la silhouette survit a la reduction, ce qui est tout ce qu'on
lui demande (§3 : lisible en une seconde). Tout est rond, aucun angle vif nulle
part (§3).

Le palet est COUCHE : son axe est Z dans Blender, donc Y dans Godot apres la
conversion Y-up. Les lobes vivent dans le plan du sol, la camera qui plonge a
45° les voit ecrases a 71 % — un trefle reste un trefle — et la rotation du
ramassable tourne le dessin dans son propre plan au lieu de le mettre de chant.

BUDGET GEOMETRIE — §11 : "Pickups, projectiles | minimal".
30 meridiens x 6 paralleles = 152 sommets, 300 tris. La coque inversee double le
compte a 600 tris dessines par croquette, contre 26 056 pour le chat : une
croquette coute 2,3 % du chat, et une vague morte en seme des dizaines.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/xp_croquette_v1.blend")

COLLECTION = "xp_croquette"
MESH_OBJECT = "MSH_croquette"
ATTRIBUTE = "Attr_Style"

# ---------------------------------------------------------------- dimensions

RADIUS = 0.23         # rayon moyen, avant modulation des lobes
HEIGHT = 0.105        # demi-epaisseur du palet
LOBES = 3

# Amplitude des lobes, en fraction du rayon. 0,30 et non 0,20 : le premier jet
# est sorti en POMME DE TERRE au banc comme a taille de jeu — a 0,20 les
# encoches ne creusent que 18 % du diametre, ce qui donne un triangle arrondi,
# pas un trefle. La borne haute n'est pas esthetique : au-dela de ~0,34 le rayon
# de courbure du creux (0,042 m) passe sous l'epaisseur de la coque inversee, et
# l'encre se referme sur elle-meme jusqu'a remplir l'encoche.
LOBE_DEPTH = 0.30

# "Legerement tordu" (§12) : une modulation basse frequence qui rend UN lobe
# plus dodu que les deux autres. Sans elle, trois lobes identiques se lisent
# comme un rouage, pas comme une croquette. Deterministe — le decor et les
# ramassables doivent etre identiques d'une run a l'autre, sinon on ne peut
# plus juger un changement de rendu par comparaison.
WOBBLE = 0.045
WOBBLE_PHASE = -0.7

# La densite. 30 meridiens = 10 segments par lobe : c'est le creux qui la fixe,
# pas le lobe — a 0,30 d'amplitude la courbe tourne vite au fond de l'encoche, et
# 8 segments l'y facettaient visiblement. 6 paralleles placent un anneau PILE sur
# l'equateur, la ou passe la silhouette vue de cote.
N_THETA = 30
N_PHI = 6

# Materiau. UN seul — §5 veut une couleur principale par objet, et une croquette
# n'a pas de seconde matiere. `#E8C040` est l'or chaud que §4 range explicitement
# en "Croquettes / XP".
CROQUETTE = "#E8C040"

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

def lobe_radius(theta: float) -> float:
    return RADIUS * (
        1.0
        + LOBE_DEPTH * math.cos(LOBES * theta)
        + WOBBLE * math.cos(theta + WOBBLE_PHASE)
    )


def build_mesh():
    """Un ellipsoide dont le rayon est module par l'angle — rien de plus.

    Pas de bevel, pas de solidify, aucun operateur : la surface est lisse et
    fermee par construction, ce qui est exactement le budget que §11 accorde a
    un ramassable. Les poles sont des sommets uniques, donc les lobes s'y
    resorbent tout seuls et le palet reste bombe.
    """
    bm = bmesh.new()
    coords = {}  # index -> (theta, phi)

    bottom = bm.verts.new((0.0, 0.0, -HEIGHT))
    coords[0] = (0.0, -math.pi * 0.5)

    rings = []

    for j in range(1, N_PHI):
        phi = -math.pi * 0.5 + math.pi * j / float(N_PHI)
        ring = []

        for i in range(N_THETA):
            theta = math.tau * i / float(N_THETA)
            r = lobe_radius(theta) * math.cos(phi)
            vertex = bm.verts.new((r * math.cos(theta), r * math.sin(theta),
                                   HEIGHT * math.sin(phi)))
            coords[len(coords)] = (theta, phi)
            ring.append(vertex)

        rings.append(ring)

    top = bm.verts.new((0.0, 0.0, HEIGHT))
    coords[len(coords)] = (0.0, math.pi * 0.5)

    bm.verts.ensure_lookup_table()

    for i in range(N_THETA):
        nxt = (i + 1) % N_THETA
        bm.faces.new((bottom, rings[0][nxt], rings[0][i]))
        bm.faces.new((top, rings[-1][i], rings[-1][nxt]))

    for lower, upper in zip(rings, rings[1:]):
        for i in range(N_THETA):
            nxt = (i + 1) % N_THETA
            bm.faces.new((lower[i], lower[nxt], upper[nxt], upper[i]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    # RECENTRAGE en X/Y, et il n'est pas cosmetique : `WOBBLE` decale le centre
    # de l'emprise de ~0,04 m, et la croquette TOURNE sur son axe une fois en
    # jeu. Un maillage excentre ne tournerait pas sur lui-meme, il DECRIRAIT UN
    # CERCLE — le ramassable aurait l'air pousse par autre chose. Le lobe dodu
    # reste dodu, c'est l'axe qui revient au milieu.
    lo_x = min(v.co.x for v in bm.verts)
    hi_x = max(v.co.x for v in bm.verts)
    lo_y = min(v.co.y for v in bm.verts)
    hi_y = max(v.co.y for v in bm.verts)
    bmesh.ops.translate(
        bm, verts=bm.verts,
        vec=Vector((-(lo_x + hi_x) * 0.5, -(lo_y + hi_y) * 0.5, 0.0)),
    )

    for face in bm.faces:
        face.smooth = True

    mesh = bpy.data.meshes.new(MESH_OBJECT)
    bm.to_mesh(mesh)
    bm.free()

    return mesh, coords


# -------------------------------------------------------------- Attr_Style

def paint(mesh, coords):
    """Peint R, G et B. Contrat des canaux : "Convention Blender" §4.

    Tout se decide sur la position PARAMETRIQUE et la normale, jamais sur
    l'eclairage. La croquette TOURNE sur elle-meme : une forme peinte tourne
    avec elle, ce qui est exactement la regle que la flaque de soleil au sol a
    fait payer — une forme peinte doit etre ancree a ce qui la porte.
    """
    attr = mesh.color_attributes.get(ATTRIBUTE)

    if attr is None:
        attr = mesh.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="POINT")

    stats = {"r": [2.0, -1.0], "g": [2.0, -1.0], "b": [2.0, -1.0]}
    accent = 0

    for i, vertex in enumerate(mesh.vertices):
        theta, phi = coords[i]
        n = vertex.normal

        # Combien ce sommet est au CREUX entre deux lobes, ou sur la CRETE d'un
        # lobe. Les poles portent theta = 0 par convention, mais leur facteur
        # est ecrase par `fade` : a la pointe du palet, il n'y a plus de lobe
        # du tout, et il ne doit donc rien s'y peindre qui les evoque.
        fade = math.cos(phi) ** 2
        valley = max(0.0, -math.cos(LOBES * theta)) * fade
        crest = max(0.0, math.cos(LOBES * theta)) * fade

        # ---- R : epaisseur du trait -------------------------------------
        # Le trait s'allege sur les faces franchement tournees vers le ciel (un
        # trait gras y ferait de la bavure), s'alourdit sous le volume, et
        # s'epaissit dans les ENCOCHES : c'est le trait qui separe les lobes,
        # et c'est lui qui fait lire "croquette" plutot que "caillou".
        # La BASE est a 0,84 et non a 1,0, et c'est la seule facon d'avoir une
        # epaisseur reellement variable : l'encoche doit etre l'endroit le plus
        # charge du modele, or le canal est borne a 1. Partir de 1 revient a
        # peindre un trait uniforme sur toute la moitie basse, le surplus etant
        # mange par la borne — defaut silencieux, le fichier ayant l'air juste.
        #
        # ⚠️ L'ALLEGEMENT DU DESSUS EST BORNE PAR LE PIXEL, pas par le gout.
        # A -0,24 le trait tombait a 0,68 px sur le bord haut au cadrage de jeu,
        # et il y DISPARAISSAIT : ne restait que le saut de valeur or/parquet,
        # 0,085, sous le seuil de lecture de 0,10 releve sur le canape. La borne
        # basse utile est celle qui garde ~1 px, soit 0,68 de canal ici. Meme
        # famille que le reglage d'antialiasing du visage : un reglage juste au
        # banc peut ne rien valoir a taille de jeu.
        r = 0.84 - 0.16 * max(0.0, n.z)
        r += 0.10 * max(0.0, -n.z)
        r += 0.20 * valley

        # ---- G : la forme des ombres ------------------------------------
        # Amplitude volontairement petite : le shader applique
        # `biais = (G - 0,5) x 2`, donc G = 0,30 vaut deja -0,40 de seuil.
        g = 0.52
        g -= 0.13 * max(0.0, -n.z)         # tout dessous de volume
        g -= 0.12 * valley                 # l'ombre au fond de l'encoche
        g += 0.04 * crest * max(0.0, n.z)  # le dessus des lobes prend le jour

        # ---- B : masque d'accent ----------------------------------------
        # UN SEUL accent, sur l'epaule du lobe le plus dodu.
        #
        # ⚠️ Mesure du 2026-08-19 : trois accents, un par lobe, sortaient en
        # TROIS TACHES PALES qui couvraient ~15 % du ramassable a taille de jeu
        # (22 x 18 px releves). A cette taille elles ne se lisaient pas comme
        # une brillance mais comme de la salissure — le defaut exact que
        # l'antialiasing du visage avait deja fait payer sur les moustaches.
        # Reste un point unique de ~3 px : un eclat, ce qu'un petit volume rond
        # porte au manga.
        #
        # Le seuil porte sur la crete BRUTE, pas sur `crest` : `fade` vaut deja
        # 0,75 a ce parallele, et le composer deux fois eteindrait l'accent.
        # `cos(theta) > 0.5` choisit LE lobe — celui que `WOBBLE` engraisse.
        b = 0.0

        if (math.cos(LOBES * theta) > 0.85 and math.cos(theta) > 0.5
                and 0.30 < math.sin(phi) < 0.70):
            b = 1.0
            accent += 1

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

    stats["accent"] = accent
    return stats


# -------------------------------------------------------------- materiaux

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


# ------------------------------------------------------------------- scene

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

    mesh, coords = build_mesh()
    mesh.materials.append(toon_material("croquette", CROQUETTE))
    stats = paint(mesh, coords)

    obj = bpy.data.objects.new(MESH_OBJECT, mesh)

    collection = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    collection.objects.link(obj)

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    lo = Vector((min(v.co[i] for v in mesh.vertices) for i in range(3)))
    hi = Vector((max(v.co[i] for v in mesh.vertices) for i in range(3)))

    print("\n[build_kibble] %s" % MESH_OBJECT)
    print("  %d sommets, %d faces, %d tris  (chat = 13 028)"
          % (len(mesh.vertices), len(mesh.polygons), tris))
    print("  emprise  X %.3f a %.3f   Y %.3f a %.3f   Z %.3f a %.3f"
          % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    print("  %d lobes, creux a %.3f / bosse a %.3f"
          % (LOBES, RADIUS * (1.0 - LOBE_DEPTH), RADIUS * (1.0 + LOBE_DEPTH)))
    print("  Attr_Style  R %.2f-%.2f   G %.2f-%.2f   B %.2f-%.2f  (%d sommets d'accent)"
          % (stats["r"][0], stats["r"][1], stats["g"][0], stats["g"][1],
             stats["b"][0], stats["b"][1], stats["accent"]))

    if "--save" in sys.argv:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
        print("  ecrit dans %s" % OUTPUT)
    else:
        print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
