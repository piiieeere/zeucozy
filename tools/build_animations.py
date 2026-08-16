"""Construit les actions du chat, posees en pas, dans le .blend ouvert.

    "<blender>" --background chat_style_v3.blend --python tools/build_animations.py -- --save
    (ou execute dans la session Blender en cours, puis Ctrl+S)

Pourquoi un script et pas des cles posees a la main — "Convention Blender" §6.2
demande de poser DIRECTEMENT sur les multiples de 3, jamais de poser librement
puis de reechantillonner. Une table de poses garantit ca par construction : il
n'existe aucune cle hors grille, et l'interpolation CONSTANT est appliquee a
toutes les cles sans en oublier une.

CONVENTIONS DU RIG (relevees, pas supposees)
--------------------------------------------
  * Le chat regarde **-Y**, Z est vers le haut, la scene est a 60 fps.
  * Tous les os sont en euler **XYZ**.
  * L'axe local X de la plupart des os est l'axe X du monde : `rx` est donc un
    tangage dans le plan sagittal. Sur `tete`, `rx` positif = hocher vers
    l'avant. Sur les membres, `rx` positif = balancer vers l'avant.
  * Exceptions a garder en tete : `dos` a son X local inverse (-1, 0, 0), et
    les os de queue / d'oreille ont des axes obliques.

LE CANARI
---------
`canari` n'est pas une animation de jeu : c'est un instrument de mesure. Elle
fait monter `tete.rx` de -30 a +30 par paliers de 3 frames. Deux lectures
possibles a l'arrivee dans Godot, et elles ne se confondent pas :

  * escalier de 13 marches -> la cadence en pas a survecu au pont glTF ;
  * rampe continue -> l'exporteur a rebake en LINEAR (piege n°4), et il faut
    forcer INTERPOLATION_NEAREST a l'import cote moteur.

A supprimer une fois la mesure faite.
"""

import math
import sys

import bpy
from mathutils import Vector

ARMATURE_OBJECT = "squelette"

# "Visual Art Direction" §7 : joueur et ennemis sur 3s. Une pose toutes les
# 3 frames a 60 fps, soit ~20 fps percus.
STEP = 3


def deg(value: float) -> float:
    return math.radians(value)


def clear_action(name: str) -> None:
    existing = bpy.data.actions.get(name)
    if existing is not None:
        existing.use_fake_user = False
        bpy.data.actions.remove(existing)


def build(name: str, channels: dict, length: int) -> tuple:
    """Cree une action posee en pas. Rend (action, courbes creees).

    `channels` : {nom d'os: {canal: {frame: valeur}}}, ou `canal` vaut
    rx / ry / rz (degres) ou tx / ty / tz (unites Blender). Toutes les frames
    doivent tomber sur un multiple de STEP — le script echoue sinon, plutot
    que de produire une cadence silencieusement fausse.

    `length` est la duree de la boucle : la valeur de la frame 0 est reposee a
    `length` pour que le raccord soit franc, comme toutes les autres.

    Blender 5.2 : les actions sont *slottees*. `Action.fcurves` n'existe plus,
    les courbes vivent dans calque -> bande -> sac de canaux. On passe par
    `fcurve_ensure_for_datablock`, qui cree tout ce chemin et assigne le slot.
    """
    armature = bpy.data.objects[ARMATURE_OBJECT]

    if armature.animation_data is None:
        armature.animation_data_create()

    clear_action(name)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    armature.animation_data.action = action

    # Repos partout : sans ca, une action heritee de la precedente laisserait
    # des os dans une pose qui n'appartient a personne.
    for pose_bone in armature.pose.bones:
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)

    axis = {"rx": 0, "ry": 1, "rz": 2, "tx": 0, "ty": 1, "tz": 2}
    curves = []
    times = {}

    for bone_name, tracks in channels.items():
        if bone_name not in armature.pose.bones:
            sys.exit("ECHEC : os '%s' absent du rig" % bone_name)

        for channel, keys in tracks.items():
            if channel not in axis:
                sys.exit("ECHEC : canal '%s' inconnu (rx/ry/rz/tx/ty/tz)" % channel)

            path = "rotation_euler" if channel[0] == "r" else "location"
            data_path = 'pose.bones["%s"].%s' % (bone_name, path)
            curve = action.fcurve_ensure_for_datablock(
                armature, data_path, index=axis[channel], group_name=bone_name
            )

            keys = dict(keys)

            # Raccord de boucle : la derniere pose reprend la premiere.
            if length not in keys and 0 in keys:
                keys[length] = keys[0]

            for frame in sorted(keys):
                if frame % STEP != 0:
                    sys.exit("ECHEC : '%s.%s' pose a la frame %d, hors grille de %d"
                             % (bone_name, channel, frame, STEP))

                value = deg(keys[frame]) if channel[0] == "r" else keys[frame]
                point = curve.keyframe_points.insert(float(frame), value)
                # §6.2 : les courbes doivent etre en escalier, pas en pente.
                point.interpolation = "CONSTANT"

            curve.update()
            curves.append(curve)

            # Un os = un canal glTF par chemin : les trois `r*` fusionnent en
            # UN quaternion, les trois `t*` en UNE translation. Si les courbes
            # d'un meme chemin ne partagent pas leurs temps de cles,
            # l'exporteur ne sait pas les fusionner et REECHANTILLONNE l'os
            # entier a 60 fps en LINEAR — la cadence en pas meurt sur cet os
            # seulement, sans erreur ni avertissement.
            #
            # Constate le 2026-08-16 sur `tete` dans idle (rx toutes les 12
            # frames, rz toutes les 24) : 145 cles LINEAR a l'arrivee.
            slot = (bone_name, path)
            frames = frozenset(keys)

            if slot in times and times[slot] != frames:
                sys.exit(
                    "ECHEC : '%s' a des temps de cles differents entre ses canaux %s.\n"
                    "        %s\n"
                    "        Tous les canaux d'un meme os doivent partager leurs frames,\n"
                    "        sinon l'export glTF reechantillonne cet os en LINEAR."
                    % (bone_name, path, sorted(frames ^ times[slot]))
                )

            times[slot] = frames

    action.use_frame_range = True
    action.frame_start = 0.0
    action.frame_end = float(length)

    return action, curves


# ------------------------------------------------------------------- le canari

CANARI_LENGTH = 36


def canari() -> tuple:
    # Rampe reguliere : -30° a +30° en 13 paliers de 3 frames. Une rampe est
    # le pire cas pour la mesure, et donc le meilleur : c'est la seule forme
    # ou "en escalier" et "lisse" ne peuvent pas etre confondus a l'oeil.
    keys = {}
    steps = CANARI_LENGTH // STEP  # 12 intervalles, 13 poses

    for i in range(steps + 1):
        keys[i * STEP] = -30.0 + 60.0 * (i / steps)

    return build("canari", {"tete": {"rx": keys}}, CANARI_LENGTH)


# --------------------------------------------------------------- outils de pose

def wave(length: int, every: int, amplitude: float, phase: float = 0.0,
         cycles: float = 1.0, offset: float = 0.0) -> dict:
    """Echantillonne une sinusoide DIRECTEMENT sur la grille de poses.

    §6.2 interdit de poser librement puis de reechantillonner — ici la courbe
    n'est jamais evaluee ailleurs que sur la grille, et rien ne l'interpole
    entre deux marches. C'est bien du "poser sur les multiples de 3", pas du
    rebake.

    `every` est l'ecart entre deux poses, en frames. STEP donne la cadence
    pleine (sur 3s) ; un multiple de STEP produit des POSES TENUES, ce que
    §6.3 demande pour tout ce qui doit respirer plutot que vibrer.
    """
    if every % STEP != 0:
        sys.exit("ECHEC : ecart de %d frames, hors grille de %d" % (every, STEP))

    keys = {}
    for frame in range(0, length, every):
        t = frame / float(length)
        keys[frame] = offset + amplitude * math.sin(2.0 * math.pi * (cycles * t + phase))
    return keys


def swing(length: int, every: int, amplitude: float, phase: float = 0.0) -> dict:
    """Balancement d'un membre : avant a la phase 0, arriere a la phase 0,5.

    Sur ce rig, `rx` positif envoie la patte vers l'ARRIERE (le chat regarde
    -Y), aussi bien pour `bras_*` que pour `cuisse_*` — verifie sur les axes
    locaux, pas suppose.
    """
    keys = {}
    for frame in range(0, length, every):
        t = frame / float(length)
        keys[frame] = -amplitude * math.cos(2.0 * math.pi * (t + phase))
    return keys


def sweep_channel(bone_name: str, world_dir=(0.0, 1.0, 0.0)):
    """Quel canal fait balayer cet os dans `world_dir` ? Rend (canal, signe).

    Quand on tourne un os autour de son axe local A, sa pointe part dans la
    direction A x Y, Y etant l'axe de l'os. Sur un os aligne sur le monde le
    canal se devine ; sur la queue, dont les trois os ont des axes obliques,
    il ne se devine pas :

      * `rz` balaie bien lateralement `queue_1` et `queue_2` ;
      * sur `queue_3` le meme `rz` fait MONTER la pointe (A x Y vaut alors
        (-0,25, 0,46, 0,85), donc surtout +Z).

    Le resultat est une queue qui se plaque le long du dos au lieu de balayer
    — invisible dans les chiffres, evident sur une image. D'ou ce calcul,
    plutot qu'une convention supposee.
    """
    bone = bpy.data.objects[ARMATURE_OBJECT].data.bones[bone_name]
    matrix = bone.matrix_local
    along = Vector(matrix.col[1][:3])
    wanted = Vector(world_dir).normalized()

    best, best_score, best_sign = None, -1.0, 1.0

    for channel, column in (("rx", 0), ("ry", 1), ("rz", 2)):
        motion = Vector(matrix.col[column][:3]).cross(along)

        if motion.length < 1e-6:
            continue

        aligned = motion.normalized().dot(wanted)

        if abs(aligned) > best_score:
            best, best_score = channel, abs(aligned)
            best_sign = 1.0 if aligned > 0.0 else -1.0

    if best is None:
        sys.exit("ECHEC : aucun canal de balayage pour '%s'" % bone_name)

    return best, best_sign


def tail(length: int, every: int, amplitudes, phases, bias: float = 0.25) -> dict:
    """Balancement de la queue dans le plan sagittal, avec overlap.

    Amplitude croissante et phase retardee de segment en segment : c'est le
    seul suivi souple que §6.3 autorise, et la queue est aussi le seul os a
    poids degrades (piege n°3).

    POURQUOI EN AVANT/ARRIERE ET PAS LATERALEMENT
    ---------------------------------------------
    Le balayage lateral est le geste iconique du chat, mais il ne marche pas
    sur CE modele : au repos la queue penche deja en X (la pointe est a
    x = 0,52). La faire balayer davantage en X la couche dans l'axe de la
    camera de profil, ou son arc se raccourcit en projection et se confond
    avec le dos — c'est le "repliee sur le corps" qu'on voyait en marche.
    Augmenter l'amplitude ne faisait qu'aggraver le probleme.

    Dans le plan sagittal, l'arc reste de profil quel que soit le lacet, et
    la plongee de 45° le montre toujours en entier.

    `bias` decale le balancement vers l'ARRIERE : a 0, la queue passe autant
    de temps enroulee vers l'avant que tendue vers l'arriere. Il ne faut pas
    le pousser : les amplitudes des trois os se CUMULENT, et au-dela d'une
    trentaine de degres vers l'arriere la queue se TEND completement — elle
    perd sa boucle et se lit comme un fouet. Essaye a 0,6 le 2026-08-16 : a
    la frame 6 de `walk`, ~42° cumules, queue droite et hors cadre.

    ⚠️ Ne pas croire pouvoir DEPLIER la queue par la pose. Sa forme de repos
    est un arc en point d'interrogation, et viser `queue_3` vers l'arriere
    demande **111°** sur une jointure a poids degrades : le tube ondule en S,
    quel que soit le chemin choisi (mesure du 2026-08-16). Redresser la queue
    est un travail de MODELE, pas d'animation.
    """
    tracks = {}

    for index, (amplitude, phase) in enumerate(zip(amplitudes, phases), start=1):
        bone_name = "queue_%d" % index
        channel, sign = sweep_channel(bone_name)
        tracks[bone_name] = {channel: wave(
            length, every, sign * amplitude, phase=phase,
            offset=sign * amplitude * bias,
        )}

    return tracks


def bounce(length: int, every: int, height: float) -> dict:
    """Rebond vertical : deux appuis par cycle de marche, jamais sous zero."""
    keys = {}
    for frame in range(0, length, every):
        t = frame / float(length)
        keys[frame] = height * (0.5 - 0.5 * math.cos(4.0 * math.pi * t))
    return keys


# ------------------------------------------------------------------------ idle

IDLE_LENGTH = 144   # 2,4 s a 60 fps


def idle() -> tuple:
    """Respiration + queue qui balaie — "Convention Blender" §6.4.

    Poses tenues sur 12 frames pour la respiration : au rythme plein (3s) une
    respiration lente ne se lit pas comme une cadence, elle se lit comme du
    bruit. Les 3s sont reserves a ce qui bouge vraiment — la queue, l'oreille.

    Overlap : les trois os de queue sont dephases et d'amplitude croissante.
    C'est le seul endroit du rig ou §6.3 autorise du suivi souple (la queue
    est aussi le seul os a poids degrades, piege n°3).
    """
    tracks = {
        # Respiration : le tronc se gonfle, le corps monte d'un cheveu.
        # `racine` a son Y local le long de +Z monde : `ty` est donc vertical.
        "racine": {"ty": wave(IDLE_LENGTH, 12, 0.016, phase=-0.25, offset=0.016)},
        "thorax": {"rx": wave(IDLE_LENGTH, 12, 2.6, phase=-0.25)},
        "dos": {"rx": wave(IDLE_LENGTH, 12, -1.8, phase=-0.25)},
        # La tete suit la respiration avec un temps de retard. Amplitudes
        # basses a dessein : c'est la queue qui doit porter le mouvement, une
        # tete qui dodeline autant se lit comme du flottement.
        "cou": {"rx": wave(IDLE_LENGTH, 12, -1.0, phase=-0.18)},
        # rx et rz sur les MEMES frames : voir le garde-fou dans build().
        "tete": {"rx": wave(IDLE_LENGTH, 12, 0.7, phase=-0.12),
                 "rz": wave(IDLE_LENGTH, 12, 1.4, cycles=0.5)},
        # Frisson d'oreille : deux poses tenues, franches, et c'est tout.
        # §6.3 — "les objets ont une vie interieure".
        "oreille_L": {"rx": {0: 0.0, 60: -13.0, 66: 4.0, 72: 0.0}},
        "oreille_R": {"rx": {0: 0.0, 108: -10.0, 114: 3.0, 120: 0.0}},
    }
    # Amplitudes larges, possibles depuis que le balancement est sagittal :
    # elles se cumulent le long de la chaine sans jamais coucher la queue sur
    # le dos. C'est elle qui porte l'idle.
    tracks.update(tail(IDLE_LENGTH, 6, (5.0, 9.0, 12.0), (0.0, -0.09, -0.18)))

    return build("idle", tracks, IDLE_LENGTH)


# ------------------------------------------------------------------------ walk

WALK_LENGTH = 24    # 0,4 s — 8 poses sur la grille, ce que demande §6.4


def walk() -> tuple:
    """Marche : rebond vertical + pattes alternees, 8 poses.

    Allure diagonale : avant-gauche avec arriere-droite, l'autre paire a
    l'oppose. Tout est a la cadence pleine (3s) — c'est l'animation ou le
    corps doit claquer.
    """
    front, back = 22.0, 19.0
    tracks = {
        "racine": {"ty": bounce(WALK_LENGTH, STEP, 0.075)},
        # Le tronc se souleve avec l'appui, la tete contre-bouge : sans ca la
        # tete monte et descend comme un bouchon.
        "dos": {"rx": wave(WALK_LENGTH, STEP, 2.5, cycles=2.0)},
        "cou": {"rx": wave(WALK_LENGTH, STEP, -1.5, cycles=2.0, phase=-0.12)},
        "tete": {"rx": wave(WALK_LENGTH, STEP, 1.0, cycles=2.0, phase=-0.25)},
    }
    # Queue : un balancement par cycle, toujours avec overlap.
    tracks.update(tail(WALK_LENGTH, STEP, (6.0, 10.0, 13.0), (0.0, -0.12, -0.24)))

    # Les quatre membres, chacun avec son avant-bras / sa jambe en retard.
    for bone, amp, ph in (("bras_L", front, 0.0), ("bras_R", front, 0.5),
                          ("cuisse_L", back, 0.5), ("cuisse_R", back, 0.0)):
        tracks[bone] = {"rx": swing(WALK_LENGTH, STEP, amp, ph)}

    for bone, amp, ph in (("avantbras_L", 12.0, 0.12), ("avantbras_R", 12.0, 0.62),
                          ("jambe_L", 11.0, 0.62), ("jambe_R", 11.0, 0.12)):
        tracks[bone] = {"rx": swing(WALK_LENGTH, STEP, amp, ph)}

    return build("walk", tracks, WALK_LENGTH)


# ------------------------------------------------------------------------ sortie

def describe(name: str, action, curves, length: int) -> None:
    frames = sorted({int(k.co[0]) for c in curves for k in c.keyframe_points})
    interps = sorted({k.interpolation for c in curves for k in c.keyframe_points})
    keys = sum(len(c.keyframe_points) for c in curves)
    hors = [f for f in frames if f % STEP != 0]

    print("  %-8s %6.2fs  %2d courbes  %3d cles  poses %2d  %s  hors grille %d"
          % (name, length / 60.0, len(curves), keys, len(frames), interps, len(hors)))


def main() -> None:
    scene = bpy.context.scene
    scene.frame_start = 0
    scene.frame_end = max(IDLE_LENGTH, WALK_LENGTH)

    print("\n[build_animations] scene a %d fps, cadence sur %ds" % (scene.render.fps, STEP))

    built = [("idle", idle(), IDLE_LENGTH), ("walk", walk(), WALK_LENGTH)]

    if "--canari" in sys.argv:
        built.append(("canari", canari(), CANARI_LENGTH))
    else:
        # Le canari a servi : il a prouve que STEP traverse le pont glTF.
        # Le garder ferait un troisieme clip inutile dans le .glb.
        clear_action("canari")

    for name, (action, curves), length in built:
        describe(name, action, curves, length)

    # C'est `idle` qui doit rester assignee : c'est elle qu'on voit en ouvrant
    # le fichier, et c'est la pose de reference du personnage.
    armature = bpy.data.objects[ARMATURE_OBJECT]
    armature.animation_data.action = bpy.data.actions["idle"]

    if "--save" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("  .blend enregistre")


main()
