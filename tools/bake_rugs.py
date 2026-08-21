"""Cuit les TAPIS peints a la main en textures de sol (2026-08-21).

    python tools/bake_rugs.py [--force] [--long-side 768] [--only blue]

Meme metier que `bake_illustration.py`, sur la branche la plus simple du PEINT :
un tapis est PLAT et POSE AU SOL, donc son illustration vue de dessus EST sa
texture. Il n'y a ni volume a projeter, ni UV a cuire, ni gabarit a recaler —
la projection a 44,02° d'une face horizontale n'est qu'un ecrasement uniforme
en profondeur, que la camera refait toute seule. C'est le seul objet du decor
ou l'image se pose directement.

Ce que le script fait, et pourquoi chaque geste est la :

  1. LE RECADRAGE SUR L'ALPHA. Les quatre planches arrivent en 1402 x 1122 avec
     une marge transparente inegale (18 a 37 px selon la planche). Cadrer sur la
     boite englobante de l'alpha est ce qui rend la texture SUPERPOSABLE a son
     rectangle de monde : sans ca, un tapis serait pose plus petit que son
     emprise, et pas du meme facteur d'une couleur a l'autre.
     ⚠️ On regarde l'ALPHA et jamais la couleur : le fond de ces planches est un
     noir transparent (0,0,0,0), et un test de couleur y verrait de l'encre.

  2. LA REDUCTION, PONDEREE PAR L'ALPHA. Le RGB des pixels transparents est du
     NOIR PUR — une moyenne naive le melangerait au bord et cernerait le tapis
     d'un liseré noir qui n'est pas dans le dessin. La moyenne est donc pesee
     par l'alpha, et l'alpha, lui, est moyenne a plat : c'est lui qui porte le
     bord doux du trait, et c'est ce bord que `alpha_to_coverage` transforme en
     silhouette antialiasee.

  3. LE REMPLISSAGE DU FOND. ⚠️ Le geste qu'on oublie, et il est muet. Bilineaire
     et mipmaps vont chercher des texels AU-DELA du bord du tapis ; avec du noir
     derriere, le trait brun sortirait sali de l'exterieur, de plus en plus loin
     a mesure que le tapis s'eloigne. Le remplissage va donc jusqu'au BOUT du
     cadre, pour la meme raison qu'en §3 de `bake_illustration.py`.

⭐ LA TAILLE DE SORTIE EST LE SEUL REGLAGE, et elle se justifie en une ligne :
le jeu montre 40,1 px/m au sol, ecrases a ~29 px/m en profondeur par la plongee.
A 768 px de grand cote, le plus grand tapis du decor (16 m) rend 48 px/m — au-
dessus de ce que l'ecran demande, et sans payer les 96 px/m de §2quater, qui
sont la densite d'un MEUBLE vu de pres. Les petits tapis montent a 85 px/m par
simple effet de bord : ils partagent la meme planche.

⭐ ET AUCUN CHIFFRE DE MONDE N'ENTRE ICI. Le script ne sait pas quelle taille
fera un tapis dans l'arene — c'est `arena.gd` qui deduit sa PROFONDEUR du
rapport de la texture, precisement pour que ces deux fichiers ne puissent pas
diverger. Reposer une planche d'un autre format et relancer suffit.

⛔ AUCUNE DEPENDANCE. `zlib` et `struct`, comme partout ailleurs dans `tools/`.

⚠️ APRES CE SCRIPT : `--headless --import`, PUIS verifier les `.import`. Godot y
ecrit `detect_3d/compress_to=2` au premier usage 3D, ce qui bascule la texture
en VRAM Compressed et fait BAVER le trait. Les trois valeurs justes :
compress/mode=0, mipmaps/generate=true, detect_3d/compress_to=0.
"""

import argparse
import struct
import zlib
from pathlib import Path

# Les quatre planches deposees dans `maquettes/`. La liste est ici et pas en
# argument : ce sont les tapis DU JEU, pas un lot d'images quelconque, et
# `arena.gd` les nomme un par un.
RUGS = ("blue", "green", "pink", "violet")

# Au-dessous de ce seuil, un pixel n'est pas de la matiere. 8 sur 255 : les
# planches sortent du generateur avec un alpha de corps a 253 et un fond a 0,
# la frontiere n'a rien d'ambigu.
ALPHA_MIN = 8

# Marge transparente laissee AUTOUR du tapis dans la texture, en pixels de
# sortie. Sans elle la silhouette affleure le bord du cadre, et le bord du cadre
# est justement l'endroit ou le filtrage n'a plus de voisin a aller chercher.
# 2 px valent 0,04 m sur le plus grand tapis — sous le texel d'ecran.
PAD = 2

# Grand cote de la texture de sortie. Voir le bandeau : 48 px/m sur le plus
# grand tapis, contre 40,1 affiches.
LONG_SIDE = 768

# Le remplissage n'a pas de rayon : il va jusqu'au bout. Meme raison qu'en §3 de
# `bake_illustration.py` — la chaine de mipmaps descend jusqu'a 1 px, et chaque
# niveau double la distance a laquelle un texel de fond peut remonter.
BLEED_LIMIT = 4096


# ------------------------------------------------------------------ PNG (lecture)

def read_png(path):
    """Decode un PNG RGBA8 non entrelace. Retourne des octets RGBA.

    ⚠️ Contrairement a `bake_illustration.read_png`, l'alpha est CONSERVE : ici
    c'est lui qui porte la silhouette, il n'y a pas d'autre pochoir.
    """
    data = path.read_bytes()

    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("%s : ce n'est pas un PNG" % path)

    offset = 8
    header = None
    idat = bytearray()

    while offset < len(data):
        length, kind = struct.unpack(">I4s", data[offset:offset + 8])
        payload = data[offset + 8:offset + 8 + length]
        offset += 12 + length

        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            idat += payload
        elif kind == b"IEND":
            break

    width, height, depth, color, _, _, interlace = header

    if depth != 8 or color != 6 or interlace != 0:
        raise SystemExit(
            "%s : seul le RGBA8 non entrelace est gere "
            "(depth=%d color=%d interlace=%d)" % (path, depth, color, interlace))

    stride = width * 4
    raw = zlib.decompress(bytes(idat))

    out = bytearray(stride * height)
    previous = bytes(stride)
    cursor = 0

    for y in range(height):
        method = raw[cursor]
        cursor += 1
        line = bytearray(raw[cursor:cursor + stride])
        cursor += stride

        if method == 0:
            pass
        elif method == 1:                                 # Sub
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 0xFF
        elif method == 2:                                 # Up
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif method == 3:                                 # Average
            for i in range(stride):
                left = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif method == 4:                                 # Paeth
            for i in range(stride):
                left = line[i - 4] if i >= 4 else 0
                up = previous[i]
                upleft = previous[i - 4] if i >= 4 else 0
                estimate = left + up - upleft
                da, db, dc = (abs(estimate - left), abs(estimate - up),
                              abs(estimate - upleft))
                if da <= db and da <= dc:
                    predictor = left
                elif db <= dc:
                    predictor = up
                else:
                    predictor = upleft
                line[i] = (line[i] + predictor) & 0xFF
        else:
            raise SystemExit("%s : filtre PNG inconnu (%d)" % (path, method))

        out[y * stride:(y + 1) * stride] = line
        previous = line

    return {"w": width, "h": height, "px": out}


# ------------------------------------------------------------------ PNG (ecriture)

def write_png(path, width, height, pixels):
    """RGBA8, filtre None."""

    def chunk(kind, payload):
        return (struct.pack(">I", len(payload)) + kind + payload
                + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))

    raw = bytearray()

    for row in range(height):
        raw.append(0)
        raw += pixels[row * width * 4:(row + 1) * width * 4]

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


# ------------------------------------------------------------------ le cadrage

def alpha_bounds(image):
    """Boite englobante de la matiere, sur l'ALPHA.

    C'est ce rectangle-la, et pas le cadre de la planche, qui correspond a
    l'emprise du tapis dans le monde.
    """
    width, height, px = image["w"], image["h"], image["px"]
    x0, y0, x1, y1 = width, height, -1, -1

    for y in range(height):
        row = y * width
        for x in range(width):
            if px[(row + x) * 4 + 3] < ALPHA_MIN:
                continue
            if x < x0:
                x0 = x
            if x > x1:
                x1 = x
            if y < y0:
                y0 = y
            if y > y1:
                y1 = y

    if x1 < 0:
        raise SystemExit("planche entierement transparente")

    return x0, y0, x1 + 1, y1 + 1


# ------------------------------------------------------------------ la reduction

def resample(image, box, width, height):
    """Moyenne de boite, le RGB PONDERE PAR L'ALPHA et l'alpha moyenne a plat.

    ⚠️ Les deux ponderations different, et c'est le coeur de la fonction. Le RGB
    des pixels transparents est du noir pur : le peser par l'alpha est ce qui
    l'empeche de saigner sur le trait. L'alpha, lui, doit compter les pixels
    vides — c'est leur proportion dans la boite qui donne la couverture du texel,
    donc le bord doux.

    Retourne les pixels ET la couverture (les texels qui ont vu de la matiere).
    """
    sw, sh, px = image["w"], image["h"], image["px"]
    bx0, by0, bx1, by1 = box
    span_x = bx1 - bx0
    span_y = by1 - by0

    out = bytearray(width * height * 4)
    covered = bytearray(width * height)

    for y in range(height):
        # Le cadre de sortie porte PAD px de marge sur chaque bord : la boite
        # source se calcule donc sur la partie utile, pas sur toute la largeur.
        sy0 = by0 + ((y - PAD) * span_y) // (height - 2 * PAD)
        sy1 = by0 + ((y - PAD + 1) * span_y) // (height - 2 * PAD)
        sy0 = min(max(sy0, 0), sh)
        sy1 = min(max(sy1, sy0 + 1), sh)

        for x in range(width):
            sx0 = bx0 + ((x - PAD) * span_x) // (width - 2 * PAD)
            sx1 = bx0 + ((x - PAD + 1) * span_x) // (width - 2 * PAD)
            sx0 = min(max(sx0, 0), sw)
            sx1 = min(max(sx1, sx0 + 1), sw)

            r = g = b = 0
            weight = 0
            alpha = 0
            count = 0

            for sy in range(sy0, sy1):
                base = sy * sw
                for sx in range(sx0, sx1):
                    i = (base + sx) * 4
                    a = px[i + 3]
                    alpha += a
                    count += 1
                    if a < ALPHA_MIN:
                        continue
                    r += px[i] * a
                    g += px[i + 1] * a
                    b += px[i + 2] * a
                    weight += a

            index = (y * width + x) * 4

            if weight:
                out[index] = (r + weight // 2) // weight
                out[index + 1] = (g + weight // 2) // weight
                out[index + 2] = (b + weight // 2) // weight
                covered[y * width + x] = 1

            out[index + 3] = (alpha + count // 2) // count if count else 0

    return out, covered


def bleed(pixels, covered, width, height):
    """Comble le RGB des texels vides par dilatation, du bord vers l'exterieur.

    Front d'onde : chaque texel n'est visite qu'une fois, donc le remplissage
    peut aller jusqu'au bout du cadre sans que le cout explose. Voisinage a 8 —
    a 4, les diagonales restent vides et font apparaitre un damier dans les
    mipmaps.

    ⚠️ L'ALPHA N'EST PAS TOUCHE. On remplit une couleur pour que le filtrage ait
    quelque chose de propre a aller chercher ; la silhouette, elle, reste
    exactement celle que la planche a dessinee.
    """
    frontier = [i for i in range(width * height) if covered[i]]
    filled = 0

    for _ in range(BLEED_LIMIT):
        seen = {}

        for index in frontier:
            y, x = divmod(index, width)
            for dy in (-1, 0, 1):
                ny = y + dy
                if ny < 0 or ny >= height:
                    continue
                for dx in (-1, 0, 1):
                    nx = x + dx
                    if nx < 0 or nx >= width or (dx == 0 and dy == 0):
                        continue
                    neighbour = ny * width + nx
                    if covered[neighbour]:
                        continue
                    total = seen.get(neighbour)
                    if total is None:
                        total = seen[neighbour] = [0, 0, 0, 0]
                    total[0] += pixels[index * 4]
                    total[1] += pixels[index * 4 + 1]
                    total[2] += pixels[index * 4 + 2]
                    total[3] += 1

        if not seen:
            break

        for neighbour, (r, g, b, n) in seen.items():
            pixels[neighbour * 4:neighbour * 4 + 3] = bytes((r // n, g // n, b // n))
            covered[neighbour] = 1

        frontier = list(seen)
        filled += len(seen)

    return filled


# ------------------------------------------------------------------ main

def bake(name, source_dir, out_dir, long_side, force):
    source = source_dir / ("rug_%s.png" % name)
    target = out_dir / ("rug_%s.png" % name)

    if not source.exists():
        raise SystemExit("%s : planche introuvable" % source)

    if target.exists() and not force:
        raise SystemExit("%s existe deja — relancer avec --force" % target)

    image = read_png(source)
    box = alpha_bounds(image)
    span_x = box[2] - box[0]
    span_y = box[3] - box[1]

    # Le grand cote fixe l'echelle, l'autre suit : le rapport de la planche est
    # ce qui donnera sa PROFONDEUR au tapis dans l'arene, il ne se corrige pas.
    if span_x >= span_y:
        inner_x = long_side - 2 * PAD
        inner_y = max(1, int(round(inner_x * span_y / span_x)))
    else:
        inner_y = long_side - 2 * PAD
        inner_x = max(1, int(round(inner_y * span_x / span_y)))

    width = inner_x + 2 * PAD
    height = inner_y + 2 * PAD

    pixels, covered = resample(image, box, width, height)
    empty = len(covered) - sum(covered)
    filled = bleed(pixels, covered, width, height)
    left = len(covered) - sum(covered)

    write_png(target, width, height, pixels)

    print("%-7s %4d x %4d de planche -> %3d x %3d  rapport %.4f  "
          "fond %d comble, %d restant  (%d octets)"
          % (name, span_x, span_y, width, height, inner_x / inner_y,
             filled, left, target.stat().st_size))

    if left:
        raise SystemExit("%s : %d texels sans couleur — le fond remontera "
                         "par les mipmaps" % (target, left))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--maquettes", default="maquettes",
                        help="dossier des planches peintes")
    parser.add_argument("--out", default="assets/textures",
                        help="dossier des textures du jeu")
    parser.add_argument("--long-side", type=int, default=LONG_SIDE,
                        help="grand cote de la texture, en pixels")
    parser.add_argument("--only", choices=RUGS, action="append",
                        help="ne cuire qu'un tapis (repetable)")
    parser.add_argument("--force", action="store_true",
                        help="ecraser une texture deja en place")
    args = parser.parse_args()

    for name in (args.only or RUGS):
        bake(name, Path(args.maquettes), Path(args.out), args.long_side,
             args.force)


if __name__ == "__main__":
    main()
