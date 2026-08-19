"""Construit la BOULE DE POILS (le projectile), geometrie ET Attr_Style.

    "<blender>" --background --factory-startup \
        --python tools/build_hairball.py -- --save

Meme moule que `tools/build_couch.py` et `tools/build_kibble.py` — un .blend
REGENERE, jamais edite a la main, parce que la geometrie et sa peinture
`Attr_Style` ont la meme source. Les separer rejouerait le decalage que le chat
a paye cher : une peinture calee sur une version du maillage qui n'existe plus.

La chaine de materiau toon et les deux helpers de couleur sont RECOPIES de
`build_kibble.py` plutot que factorises, pour les deux raisons deja notees
la-bas (un script `--python` de Blender n'importe pas son voisin sans bricoler
`sys.path`, et ces valeurs ne servent qu'au viewport Blender — Godot repose sa
propre palette au chargement, dans `cel_prop.gd`).

FORME — l'amas de poils, tranche le 2026-08-19.
Une boule de poils de chat n'est pas une boule : c'est un amas allonge, roule
dans la gorge, plus gros a un bout qu'a l'autre. La forme est donc un
ELLIPSOIDE ALLONGE sur son axe de vol, herisse de SIX TOUFFES posees a des
endroits precis. Voir `TUFTS` : deux autres formes ont ete essayees et rendues
avant celle-la, et la raison de leur echec y est gardee — elle vaut pour tout
modele allonge a venir.

Tout est rond, aucun angle vif nulle part (§3).

L'AXE LONG EST Y DANS BLENDER. La conversion Y-up du glTF envoie Blender
(x, y, z) sur (x, z, -y), donc Blender +Y devient Godot -Z — et `projectile.gd`
oriente le node de facon que son -Z local suive la trajectoire. Le boudin part
donc dans le sens de son vol sans qu'aucun node n'ait a le tourner, alors que la
capsule placeholder avait besoin d'une matrice posee dans la scene.

COULEUR — c'est la fourrure DU CHAT, pas une couleur de plus.
`#4A4038`, le brun tres sombre que `cel_model.NOIR` pose sur le pelage tuxedo.
Deux raisons, et aucune n'est esthetique :

  * une boule de poils est faite des poils du chat. Lui donner une teinte a elle
    en ferait un objet du decor, pas quelque chose que le chat a crache ;
  * le placeholder etait `#FDD166`, un jaune pale, sur un parquet `#F5ECD8` a
    `#E8D4A8` : moins de 0,10 d'ecart de valeur, soit SOUS le seuil de lecture
    releve sur le canape. Le projectile ne se detachait pas du sol. Un brun a
    0,29 contre un parquet a 0,96 donne 0,67 d'ecart.

⚠️ Consequence : PAS D'ACCENT DE BRILLANCE (canal B a zero partout). Le chat a
deja paye ce reglage — sur son pelage noir, `accent_strength` a du tomber de
0,35 a 0,12 parce qu'un melange vers le creme remontait la valeur de 0,29 a
0,52, soit un TROISIEME ton de cluster (contre §5.5). Sur un objet de ~24 px qui
traverse l'ecran, ce troisieme ton ne se lirait pas comme une brillance.

BUDGET GEOMETRIE — §11 : "Pickups, projectiles | minimal".
22 meridiens x 8 paralleles = 156 sommets, 308 tris — l'ordre de la croquette
(300). La coque inversee double le compte a 616 tris dessines, contre 26 056
pour le chat ; et il n'y a jamais qu'une poignee de boules en vol, la ou une
vague morte seme des dizaines de croquettes.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

OUTPUT = Path("C:/Users/tibo/Documents/zeucozy_3d/projectile_boule_poils_v1.blend")

COLLECTION = "projectile_boule_poils"
MESH_OBJECT = "MSH_boule_poils"
ATTRIBUTE = "Attr_Style"

# ---------------------------------------------------------------- dimensions

# Demi-longueur sur l'axe de vol (Y Blender -> Z Godot) et demi-largeur de
# l'ellipsoide de BASE, avant les touffes. Emprise finale mesuree :
# 0,77 x 0,41 x 0,35 m, soit ~22 x 14 px au cadrage de jeu — l'ordre de grandeur
# de la croquette (0,51 m). L'ALLONGEMENT est ce qui le separe d'elle au premier
# coup d'oeil : un ramassable est rond et attend, un projectile est oriente et
# file.
HALF_LENGTH = 0.34
RADIUS = 0.155

# ─── LES TOUFFES ──────────────────────────────────────────────────────────────
#
# ⚠️ DEUX FORMES ONT ETE ESSAYEES ET RENDUES AVANT CELLE-CI. Les deux sont
# sorties en GALET au banc, et la raison est la meme — elle vaut d'etre gardee,
# parce qu'elle vaut pour tout modele allonge a venir (l'aspirateur, le
# concombre) :
#
#   ⛔ DES BOURRELETS CIRCULAIRES NE SE VOIENT PAS SUR LA SILHOUETTE D'UN CORPS
#      ALLONGE. Un rayon module seulement en `u` (autour de l'axe) reste un
#      corps de revolution deforme : vu de flanc, sa silhouette est le rayon
#      MAXIMUM, et ce maximum est le meme a chaque hauteur. On obtient un ovale
#      lisse, quelle que soit la profondeur des sillons.
#   ⛔ ET LE VRILLAGE AGGRAVE LE DEFAUT AU LIEU DE LE CORRIGER. L'helice a l'air
#      d'etre la parade — "aucun bourrelet ne reste parallele a la silhouette" —
#      mais elle fait exactement l'inverse : en faisant tourner les cretes, elle
#      garantit qu'une crete passe par la silhouette a CHAQUE hauteur. Elle lisse
#      l'enveloppe au lieu de la creuser.
#
# La sortie n'est pas un reglage, c'est un changement de forme : des TOUFFES
# DISCRETES, posees a des endroits precis de la sphere. Le corps cesse d'etre un
# corps de revolution, donc sa silhouette change avec l'azimut et n'est plus
# convexe. C'est la seule chose qui fasse lire "amas de poils" a 22 px — une
# silhouette IRREGULIERE, pas une surface texturee.
#
# ✅ Elles sont aussi bien plus douces pour l'encre. Le creux d'une sinusoide a
# n bosses a un rayon de courbure en R(1-d)^2 / |(1-d) - d n^2| : le n^2 ecrase
# tout, et des 4 bosses il tombe sous l'epaisseur de la coque inversee
# (0,036 m), qui referme alors le sillon. Entre deux touffes discretes, le
# "creux" est simplement la surface de base — convexe, de rayon 0,18 m, cinq
# fois l'encre. On peut donc les faire HAUTES.
TUFTS = 6

# Hauteur de chaque touffe, EN METRES.
#
# ⚠️ EN METRES, ET PAS EN FRACTION DU RAYON — le premier jet de touffes le
# faisait, et il est ressorti en galet lui aussi. Le rayon local d'un ellipsoide
# s'effondre vers les poles (`profile`), donc une touffe exprimee en fraction y
# devient minuscule ; la spirale de Fibonacci en pose justement deux pres des
# bouts. Mesure : l'emprise transverse sortait a 0,370 m pour un diametre de
# base de 0,350 — 0,02 m de relief en tout, sur un objet qui en fait 0,68 de
# long. Une touffe est une MASSE DE POILS : elle a la meme taille ou qu'elle
# soit sur le corps.
#
# Les positions sont en SPIRALE DE FIBONACCI sur la sphere plutot qu'a des
# angles ronds : des touffes regulierement reparties redonnent une symetrie,
# donc un objet manufacture — le defaut que `WOBBLE` corrige sur la croquette.
# La spirale ne repete jamais le meme ecart.
#
# ⚠️ Ecrites en dur et non tirees au hasard : la forme doit etre la MEME d'un
# tir a l'autre et d'une capture a l'autre, sinon plus aucune comparaison
# d'image n'a de sens (la lecon de `--aim=`).
TUFT_HEIGHTS = [0.085, 0.058, 0.076, 0.051, 0.082, 0.064]

# Demi-angle d'une touffe, en radians. 0,66 rad ≈ 38° : a 22 meridiens (16° le
# segment), la touffe en couvre ~5, donc elle est ronde et non facettee.
# Plus large, les six se recouvrent et l'objet redevient une sphere ; plus
# etroite, chacune devient un picot — et §3 ne veut aucune pointe.
TUFT_WIDTH = 0.66

# Le boudin est plus gros d'un bout que de l'autre. Positif = le bout AVANT
# (Y+ Blender, donc Z- Godot, donc le sens du vol) est le plus gros : c'est la
# masse qui part devant, pas la queue.
TAPER = 0.17

# La densite : 22 meridiens x 8 paralleles = 156 sommets, 308 tris.
#
# Le partage penche du cote des PARALLELES, a l'inverse de la croquette (30 x 6).
# Ce n'est pas une preference : l'amas est deux fois plus long que large, et
# c'est sa silhouette de FLANC qu'on voit presque toujours — elle est dessinee
# par les anneaux, pas par les meridiens. A 7 paralleles, le profil sortait
# facette sur toute sa longueur.
N_U = 22
N_V = 8

# Materiau. UN seul — §5 : une couleur principale par objet. C'est le pelage du
# chat (`cel_model.NOIR`), pas une couleur de plus dans le jeu.
POILS = "#4A4038"

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

def profile(v: float) -> float:
    """Le rayon transversal a la hauteur `v`, avant les touffes.

    `cos(v)` ferme la forme aux deux poles ; le terme de `TAPER` gonfle le bout
    avant. Il est BORNE a 0,5 : au-dela le profil repasserait par zero avant le
    pole et le maillage se retournerait — un defaut qui ne leve pas, il produit
    juste une pointe inversee que seul le rendu montre.
    """
    return math.cos(v) * (1.0 + min(0.5, TAPER) * math.sin(v))


def tuft_directions() -> list:
    """Les centres des touffes, en directions unitaires — spirale de Fibonacci.

    Les touffes se posent sur la SPHERE de parametrage, pas sur l'ellipsoide
    fini : leur ecartement se pense en angles, pas en metres, sinon celles des
    poles se chevaucheraient et celles de l'equateur s'espaceraient.

    ⚠️ Aucun pole de la spirale ne tombe sur un pole du maillage : une touffe
    posee sur le sommet unique du bout ferait pointer le boudin, alors que §3
    interdit la pointe et que la coque inversee y accumule son epaisseur.
    D'ou le `+ 0.5` de l'echantillonnage — c'est la forme standard, et c'est
    aussi ce qui evite le cas degenere.
    """
    golden = math.pi * (3.0 - math.sqrt(5.0))
    directions = []

    for k in range(TUFTS):
        # `sin(v)` de la touffe : reparti uniformement en HAUTEUR, ce qui est
        # ce qui repartit uniformement en AIRE sur une sphere.
        h = 1.0 - 2.0 * (k + 0.5) / float(TUFTS)
        radius = math.sqrt(max(0.0, 1.0 - h * h))
        angle = golden * k
        directions.append((radius * math.cos(angle), h, radius * math.sin(angle)))

    return directions


TUFT_DIRECTIONS = tuft_directions()


def tuft_rise(u: float, v: float) -> float:
    """La somme des touffes a ce point, EN METRES.

    Le poids est un `smoothstep` du bord vers le centre de la touffe.

    ⚠️ PAS un `x^2`, essaye et rendu : sa derivee vaut 2 au sommet, donc la
    bosse s'y termine en POINTE. L'amas est sorti en coin, avec des aretes
    franches — exactement l'angle vif que §3 interdit, et sur un objet dont
    toute la DA dit qu'il doit etre rond. `smoothstep` a une derivee nulle aux
    DEUX bouts : pied fondu dans la surface, sommet arrondi.
    """
    sx = math.cos(v) * math.cos(u)
    sy = math.sin(v)
    sz = math.cos(v) * math.sin(u)

    edge = math.cos(TUFT_WIDTH)
    rise = 0.0

    for (dx, dy, dz), height in zip(TUFT_DIRECTIONS, TUFT_HEIGHTS):
        aligned = sx * dx + sy * dy + sz * dz

        if aligned <= edge:
            continue

        t = (aligned - edge) / (1.0 - edge)
        rise += height * t * t * (3.0 - 2.0 * t)

    return rise


def surface_point(u: float, v: float) -> Vector:
    """Un point de la surface : l'ellipsoide de base, plus les touffes.

    La touffe est poussee LE LONG DE LA DIRECTION SORTANTE, en metres. C'est ce
    qui lui donne la meme taille partout sur le corps — au milieu comme au bout,
    ou le rayon de base ne vaut plus grand-chose.
    """
    r = RADIUS * profile(v)
    base = Vector((r * math.cos(u), HALF_LENGTH * math.sin(v), r * math.sin(u)))

    return base + base.normalized() * tuft_rise(u, v)


def build_mesh():
    """Un ellipsoide allonge herisse de touffes — rien de plus.

    Pas de bevel, pas de solidify, aucun operateur : la surface est lisse et
    fermee par construction, ce qui est exactement le budget que §11 accorde a
    un projectile. Les poles sont des sommets uniques, donc la surface s'y
    referme toute seule et l'amas reste arrondi aux deux bouts.
    """
    bm = bmesh.new()
    coords = {}  # index -> (u, v)

    # Les poles portent la touffe eux aussi : la spirale de Fibonacci en pose
    # pres des bouts, et les oublier aurait aplati les deux extremites — les
    # seules que la camera voit en enfilade quand la boule part vers elle.
    back = bm.verts.new(surface_point(0.0, -math.pi * 0.5))
    coords[0] = (0.0, -math.pi * 0.5)

    rings = []

    for j in range(1, N_V):
        v = -math.pi * 0.5 + math.pi * j / float(N_V)
        ring = []

        for i in range(N_U):
            u = math.tau * i / float(N_U)
            vertex = bm.verts.new(surface_point(u, v))
            coords[len(coords)] = (u, v)
            ring.append(vertex)

        rings.append(ring)

    front = bm.verts.new(surface_point(0.0, math.pi * 0.5))
    coords[len(coords)] = (0.0, math.pi * 0.5)

    bm.verts.ensure_lookup_table()

    for i in range(N_U):
        nxt = (i + 1) % N_U
        bm.faces.new((back, rings[0][i], rings[0][nxt]))
        bm.faces.new((front, rings[-1][nxt], rings[-1][i]))

    for lower, upper in zip(rings, rings[1:]):
        for i in range(N_U):
            nxt = (i + 1) % N_U
            bm.faces.new((lower[i], upper[i], upper[nxt], lower[nxt]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    # RECENTRAGE sur les deux axes TRANSVERSES (X et Z), pour la raison mesuree
    # sur la croquette : les touffes ne sont pas symetriques, elles decalent le
    # centre de l'emprise, et le projectile TOURNE sur son axe de vol. Un
    # maillage excentre ne tourne pas sur lui-meme, il DECRIT UN CERCLE — l'amas
    # aurait l'air pousse par autre chose. L'axe de vol (Y) n'est PAS recentre :
    # le `TAPER` y est voulu, et c'est le milieu de l'amas qui doit coincider
    # avec le point de tir.
    lo_x = min(w.co.x for w in bm.verts)
    hi_x = max(w.co.x for w in bm.verts)
    lo_z = min(w.co.z for w in bm.verts)
    hi_z = max(w.co.z for w in bm.verts)
    bmesh.ops.translate(
        bm, verts=bm.verts,
        vec=Vector((-(lo_x + hi_x) * 0.5, 0.0, -(lo_z + hi_z) * 0.5)),
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
    l'eclairage : le projectile tourne sur son axe de vol, et une forme peinte
    doit etre ancree a ce qui la porte.
    """
    attr = mesh.color_attributes.get(ATTRIBUTE)

    if attr is None:
        attr = mesh.color_attributes.new(name=ATTRIBUTE, type="BYTE_COLOR", domain="POINT")

    stats = {"r": [2.0, -1.0], "g": [2.0, -1.0], "b": [2.0, -1.0]}

    for i, vertex in enumerate(mesh.vertices):
        u, v = coords[i]
        n = vertex.normal

        # Ou l'on se trouve : sur la CRETE d'une touffe, ou dans le CREUX qui
        # en separe deux. Relu de la geometrie elle-meme (`tuft_rise`), jamais
        # reecrit — c'est la meme regle que le maillage, et deux formules pour
        # une seule forme finissent toujours par diverger.
        #
        # `crest` est normalise sur la touffe la plus haute : sans ca, une
        # touffe basse porterait moins de peinture qu'une haute pour la seule
        # raison qu'elle est basse, alors que c'est la MEME matiere.
        crest = min(1.0, tuft_rise(u, v) / max(TUFT_HEIGHTS))
        valley = 1.0 - crest

        # ---- R : epaisseur du trait -------------------------------------
        # Le trait s'allege sur les faces tournees vers le ciel, s'alourdit sous
        # le volume, et s'EPAISSIT ENTRE LES TOUFFES : c'est lui qui les separe,
        # et c'est lui qui fait lire "amas" plutot que "caillou".
        #
        # La base part a 0,86 et non a 1,0 pour la raison mesuree sur la
        # croquette : le canal est borne a 1, donc partir de 1 revient a peindre
        # un trait uniforme et a laisser la borne manger le relief. Le defaut
        # est silencieux — les statistiques affichent bien "1,00".
        #
        # ⚠️ L'allegement du dessus reste borne a 0,70 de canal, soit ~1,0 px au
        # cadrage de jeu. Sous le pixel, un trait ne se lit plus comme un trait
        # mais comme de la salissure (la lecon d'antialiasing du visage). Ici il
        # ne PORTE pourtant pas la separation d'avec le sol — le pelage est a
        # 0,29 de valeur contre 0,96 pour le parquet, la ou la croquette doree
        # n'avait que 0,085 — mais un trait qui clignote d'une frame a l'autre
        # se remarque, meme quand il ne sert a rien.
        r = 0.86 - 0.16 * max(0.0, n.z)
        r += 0.10 * max(0.0, -n.z)
        r += 0.18 * valley

        # ---- G : la forme des ombres ------------------------------------
        # Amplitude volontairement petite : le shader applique
        # `biais = (G - 0,5) x 2`, donc G = 0,32 vaut deja -0,36 de seuil.
        g = 0.52
        g -= 0.12 * max(0.0, -n.z)         # tout dessous de volume
        g -= 0.13 * valley                 # l'ombre entre deux touffes
        g += 0.04 * crest * max(0.0, n.z)  # le dessus des touffes prend le jour

        # ---- B : masque d'accent ----------------------------------------
        # ZERO PARTOUT, et c'est une decision, pas un oubli. Voir l'en-tete :
        # sur un aplat a 0,29 de valeur, un melange vers le creme fabrique un
        # troisieme ton de cluster (§5.5). `accent_strength` n'a donc rien a
        # mordre, et il n'y a aucun reglage a ajouter a `cel_prop.gd` pour ca.
        b = 0.0

        r = min(1.0, max(0.70, r))
        g = min(0.56, max(0.32, g))

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
    mesh.materials.append(toon_material("poils", POILS))
    stats = paint(mesh, coords)

    obj = bpy.data.objects.new(MESH_OBJECT, mesh)

    collection = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(collection)
    collection.objects.link(obj)

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    lo = Vector((min(w.co[i] for w in mesh.vertices) for i in range(3)))
    hi = Vector((max(w.co[i] for w in mesh.vertices) for i in range(3)))

    print("\n[build_hairball] %s" % MESH_OBJECT)
    print("  %d sommets, %d faces, %d tris  (croquette = 300, chat = 13 028)"
          % (len(mesh.vertices), len(mesh.polygons), tris))
    print("  emprise  X %.3f a %.3f   Y %.3f a %.3f   Z %.3f a %.3f"
          % (lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))
    print("  %d touffes de %.0f°, hauteurs %.3f a %.3f m  ->  rayon %.3f a %.3f"
          % (TUFTS, math.degrees(TUFT_WIDTH), min(TUFT_HEIGHTS), max(TUFT_HEIGHTS),
             RADIUS, RADIUS + max(TUFT_HEIGHTS)))
    print("  Attr_Style  R %.2f-%.2f   G %.2f-%.2f   B %.2f-%.2f  (aucun accent, voulu)"
          % (stats["r"][0], stats["r"][1], stats["g"][0], stats["g"][1],
             stats["b"][0], stats["b"][1]))

    if "--save" in sys.argv:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT))
        print("  ecrit dans %s" % OUTPUT)
    else:
        print("  (essai a blanc — ajouter -- --save pour ecrire le .blend)")


main()
