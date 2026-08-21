"""Cuit une ILLUSTRATION peinte a la main en texture projetee (2026-08-21).

    python tools/bake_illustration.py \
        --illustration maquettes/table_basse_illustration.png \
        --gabarit      maquettes/table_basse_gabarit.png \
        --out          assets/textures/prop_table_basse.png [--force]

C'est le dernier metre du pipeline du PEINT ("Pipeline 3D" §1->§6). Le volume
est un script (`build_coffee_table.py`), l'UV est cuite au build, le shader est
`cel_painted` — mais l'IMAGE, elle, est peinte a la main. §2quater le dit : la
technique plie la doctrine du depot d'un cran, et une seule fois.

⭐ CE SCRIPT EXISTE POUR QUE LE CRAN RESTE D'UN CRAN. Ce qui n'est pas rejouable,
c'est le DESSIN ; le recadrage, la reduction et le remplissage de fond, eux, le
redeviennent. Reposer une nouvelle illustration au meme chemin et relancer cette
commande suffit — aucune mesure a refaire a la main, aucun reglage a retrouver.

LES TROIS GESTES, ET AUCUN N'EST COSMETIQUE :

  1. LE RECALAGE. Le generateur ne rend pas au pixel pres le cadre qu'on lui
     donne : `table_basse_illustration.png` sort en 1577 x 997 la ou le gabarit
     fait 912 x 576 — soit un rapport de 1,729 en X et 1,731 en Y, et un
     decalage de quelques pixels. Posee telle quelle, l'image serait desalignee
     de ~0,9 px de texture : sur une tranche de plateau qui en fait 12, ca se
     voit.
     Le GABARIT est la reference — c'est le blockout RENDU par la meme
     projection que l'UV (§4.9), donc superposable au maillage par construction.
     On ajuste donc l'illustration SUR LUI, par moindres carres, sur des reperes
     detectes des DEUX cotes par le meme code (les biais s'annulent).

  2. LA REDUCTION. §2quater fixe la densite de peinture a 80-100 px/m et le
     build a retenu 96 (le jeu n'en affiche que 40,1 ; la marge de deux paye
     l'etirement de 1,41x et `--ssaa=2.0`). Le gabarit etant rendu a 3x, la
     taille de sortie s'en deduit : elle n'est pas un parametre a retenir.

  3. LE REMPLISSAGE DU FOND. ⚠️ C'est le geste qu'on oublie, et il est muet.
     Le fond de l'illustration est un gris neutre ; le filtrage bilineaire et
     les mipmaps vont chercher des texels AU-DELA du bord de la face, et
     ramenent donc ce gris SUR la silhouette. Le placeholder de
     `build_coffee_table.py` s'en protegeait en remplissant son cadre de bois ;
     une image peinte, elle, arrive avec son fond.
     Parade en deux temps : le fond est retire AVANT la reduction (moyenne
     ponderee par la couverture, donc un bord de silhouette qui ne se salit
     pas), puis les pixels restes vides sont combles par dilatation.

⛔ AUCUNE DEPENDANCE. Ni PIL ni numpy : `zlib` et `struct` suffisent, et c'est
la meme regle que partout ailleurs dans `tools/`. Le PNG se decode et se
reencode a la main, en RGB8 — le format que `cel_prop.gd` charge et que le
`.import` regle en Lossless.

⚠️ APRES CE SCRIPT, VERIFIER `assets/textures/*.png.import` : Godot y ecrit
`detect_3d/compress_to=2` au premier usage 3D, ce qui bascule la texture en
VRAM Compressed et fait BAVER le trait (le piege n°3 de "Pipeline 3D").
Les trois valeurs justes : compress/mode=0, mipmaps/generate=true,
detect_3d/compress_to=0.
"""

import argparse
import struct
import zlib
from pathlib import Path

# Echelle a laquelle `build_coffee_table.render_gabarit` rend le blockout. La
# taille de sortie s'en deduit, elle ne se saisit pas : un gabarit et une
# texture qui ne parlent pas de la meme grille, c'est le desalignement de §1
# reintroduit par la porte d'a cote.
GABARIT_SCALE = 3

# Tolerance de classement du fond, par canal. Le fond des illustrations est un
# gris neutre pose par le generateur ; les aplats du dessin sont des bruns
# franchement satures. 16 laisse passer le bruit de compression sans jamais
# attraper de matiere.
BG_TOLERANCE = 16

# Un pixel n'est du fond que s'il est aussi NEUTRE. Sans ce second test, un bois
# tres desature (une ombre grisee) tomberait dans le meme panier.
BG_CHROMA_MAX = 14

# De combien on rogne la matiere du gabarit avant de s'en servir de pochoir.
# 2 px de gabarit (0,67 px de texture) couvrent le debord de son rendu : une
# demi-diagonale de dilatation de polygone, plus la moitie d'un trait de 2 px.
GABARIT_EROSION = 2

# Le remplissage va jusqu'au BOUT du cadre, il ne s'arrete pas a une distance
# choisie. La raison est la chaine de mipmaps : a 304 px de large elle descend
# jusqu'a 1 px, et chaque niveau double la distance a laquelle un texel de fond
# peut remonter sur la silhouette. Un rayon fini laisserait donc du fond dans
# les derniers niveaux — c'est-a-dire de loin, la ou le meuble est le plus
# petit et le defaut le moins imputable a la texture.
BLEED_LIMIT = 4096


# ------------------------------------------------------------------ PNG (lecture)

def read_png(path):
    """Decode un PNG RGB8 ou RGBA8, non entrelace. Retourne des octets RGB."""
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

    if depth != 8 or color not in (2, 6) or interlace != 0:
        raise SystemExit(
            "%s : seul le RGB8/RGBA8 non entrelace est gere "
            "(depth=%d color=%d interlace=%d)" % (path, depth, color, interlace))

    channels = 3 if color == 2 else 4
    stride = width * channels
    raw = zlib.decompress(bytes(idat))

    # Defiltrage PNG, les cinq filtres. `previous` est la ligne reconstruite.
    out = bytearray(stride * height)
    previous = bytearray(stride)
    cursor = 0

    for y in range(height):
        method = raw[cursor]
        cursor += 1
        line = bytearray(raw[cursor:cursor + stride])
        cursor += stride

        if method == 1:                                   # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif method == 2:                                 # Up
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif method == 3:                                 # Average
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif method == 4:                                 # Paeth
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                up = previous[i]
                upleft = previous[i - channels] if i >= channels else 0
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
        elif method != 0:
            raise SystemExit("%s : filtre PNG inconnu (%d)" % (path, method))

        out[y * stride:(y + 1) * stride] = line
        previous = line

    if channels == 4:                                     # on jette l'alpha
        rgb = bytearray(width * height * 3)
        for i in range(width * height):
            rgb[i * 3:i * 3 + 3] = out[i * 4:i * 4 + 3]
        out = rgb

    return {"w": width, "h": height, "px": out}


# ------------------------------------------------------------------ PNG (ecriture)

def write_png(path, width, height, pixels):
    """RGB8, filtre None. Meme fonction que `build_coffee_table.write_png`."""

    def chunk(kind, payload):
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


# ------------------------------------------------------------------ le fond

def background_mask(image):
    """Marque le fond : proche de la couleur du coin haut-gauche, ET neutre.

    Le coin haut-gauche est le seul point garanti hors dessin dans les deux
    images — le gabarit y pose sa creme, l'illustration son gris. Les coins BAS,
    eux, tombent dans la bande d'aplat uni, qui est de la matiere.
    """
    px = image["px"]
    reference = (px[0], px[1], px[2])
    mask = bytearray(image["w"] * image["h"])
    count = 0

    for i in range(image["w"] * image["h"]):
        r, g, b = px[i * 3], px[i * 3 + 1], px[i * 3 + 2]

        if (abs(r - reference[0]) <= BG_TOLERANCE
                and abs(g - reference[1]) <= BG_TOLERANCE
                and abs(b - reference[2]) <= BG_TOLERANCE
                and max(r, g, b) - min(r, g, b) <= BG_CHROMA_MAX):
            mask[i] = 1
            count += 1

    return mask, reference, count


def erode(mask, width, height, steps):
    """Retire `steps` pixels de matiere au bord du gabarit, PAS a celui du cadre.

    Le gabarit est un rendu, pas un masque : `render_gabarit` dilate ses
    polygones d'une demi-diagonale (pour que deux faces voisines se touchent) et
    pose par-dessus un trait de 2 px CENTRE sur l'arete. Sa matiere deborde donc
    la geometrie vraie d'environ 1,75 px, et prise telle quelle elle laisserait
    passer le halo antialiase de l'illustration — un liseré neutre que la
    dilatation irait ensuite etaler en gris sur tout le fond.

    ⚠️ Le bord du CADRE ne s'erode pas : la bande d'aplat uni touche le bas de
    l'image, et l'eroder la rognerait de deux pixels a chaque appel.
    """
    for _ in range(steps):
        eaten = bytearray(mask)

        for y in range(height):
            for x in range(width):
                if mask[y * width + x]:
                    continue

                for dy in (-1, 0, 1):
                    ny = y + dy
                    if ny < 0 or ny >= height:
                        continue
                    for dx in (-1, 0, 1):
                        nx = x + dx
                        if 0 <= nx < width and mask[ny * width + nx]:
                            eaten[y * width + x] = 1

        mask = eaten

    return mask


def gate_on_silhouette(art, art_mask, blockout_mask, bw, bh, fit_x, fit_y):
    """Ajoute au fond de l'illustration tout ce qui tombe HORS du blockout.

    ⭐ C'est le gabarit qui dit ce qu'est l'objet, jamais la couleur. Le test de
    couleur seul ne voit que le fond PLAT ; il laisse passer le halo antialiase
    que le generateur pose autour de sa silhouette — des gris neutres de tous
    niveaux, trop loin du fond plat pour etre reconnus, et que la dilatation
    prend alors pour de la matiere et etale en coins gris.

    Le recalage vient d'etre mesure : on peut donc remonter chaque pixel de
    l'illustration dans le repere du gabarit et lui demander s'il est dedans.
    """
    scale_x, offset_x = fit_x
    scale_y, offset_y = fit_y
    w, h = art["w"], art["h"]
    added = 0

    for y in range(h):
        gy = int((y - offset_y) / scale_y)
        row = gy * bw if 0 <= gy < bh else -1

        for x in range(w):
            index = y * w + x

            if art_mask[index]:
                continue

            gx = int((x - offset_x) / scale_x)

            if row < 0 or not 0 <= gx < bw or blockout_mask[row + gx]:
                art_mask[index] = 1
                added += 1

    return added


# ------------------------------------------------------------------ les reperes

def landmarks(image, mask):
    """Les reperes de recalage, detectes par le MEME code dans les deux images.

    Trois en vertical, quatre en horizontal, tous pris sur la frontiere
    fond / matiere — la seule chose que le gabarit et l'illustration ont
    litteralement en commun.

    En vertical, le long de la colonne centrale, la matiere forme DEUX blocs :
    le meuble, puis la bande d'aplat uni reservee en bas du cadre. On releve le
    haut du meuble, son bas, et le haut de la bande. Le bas de la bande est le
    bord de l'image dans les deux cas : il ne contraint rien, on ne le prend pas.

    En horizontal, on releve les bords gauche et droit du meuble a deux hauteurs
    prises EN FRACTION de sa propre etendue verticale — donc au meme endroit du
    dessin dans les deux images, quelle que soit leur resolution.
    """
    w, h = image["w"], image["h"]
    column = w // 2

    runs = []
    start = None

    for y in range(h):
        solid = mask[y * w + column] == 0

        if solid and start is None:
            start = y
        elif not solid and start is not None:
            runs.append((start, y))
            start = None

    if start is not None:
        runs.append((start, h))

    runs = [run for run in runs if run[1] - run[0] > h // 40]

    if len(runs) < 2:
        raise SystemExit(
            "recalage impossible : %d bloc(s) de matiere sur la colonne "
            "centrale, il en faut 2 (le meuble, puis la bande)" % len(runs))

    body, band = runs[0], runs[-1]
    vertical = [float(body[0]), float(body[1]), float(band[0])]

    horizontal = []

    for fraction in (0.30, 0.75):
        y = int(body[0] + (body[1] - body[0]) * fraction)
        row = [x for x in range(w) if mask[y * w + x] == 0]

        if not row:
            raise SystemExit("recalage impossible : ligne %d vide" % y)

        horizontal += [float(row[0]), float(row[-1])]

    return {"v": vertical, "h": horizontal, "body": body}


def fit(source, target):
    """Moindres carres sur une droite `target = scale * source + offset`."""
    n = len(source)
    mx = sum(source) / n
    my = sum(target) / n
    num = sum((a - mx) * (b - my) for a, b in zip(source, target))
    den = sum((a - mx) ** 2 for a in source)
    scale = num / den
    return scale, my - scale * mx


# ------------------------------------------------------------------ la reduction

def resample(image, mask, width, height, fit_x, fit_y):
    """Moyenne de boite, PONDEREE PAR LA COUVERTURE.

    ⚠️ La ponderation n'est pas un raffinement : un bord de silhouette couvre
    une boite a moitie, et une moyenne naive y melangerait le fond a la matiere.
    Le trait d'encre du bord sortirait delave d'un cote et le fond gris
    remonterait de l'autre — exactement ce que le remplissage cherche a eviter,
    reintroduit une etape plus tot.

    Retourne les pixels ET la couverture, pour que le remplissage sache quels
    pixels de sortie n'ont vu QUE du fond.
    """
    sw, sh = image["w"], image["h"]
    px = image["px"]
    scale_x, offset_x = fit_x
    scale_y, offset_y = fit_y

    out = bytearray(width * height * 3)
    covered = bytearray(width * height)

    for y in range(height):
        # Bornes de la boite source, en coordonnees de GABARIT puis d'image.
        sy0 = max(0, int(round(y * GABARIT_SCALE * scale_y + offset_y)))
        sy1 = min(sh, max(sy0 + 1,
                          int(round((y + 1) * GABARIT_SCALE * scale_y + offset_y))))

        for x in range(width):
            sx0 = max(0, int(round(x * GABARIT_SCALE * scale_x + offset_x)))
            sx1 = min(sw, max(sx0 + 1,
                              int(round((x + 1) * GABARIT_SCALE * scale_x + offset_x))))

            r = g = b = 0
            weight = 0

            for sy in range(sy0, sy1):
                base = sy * sw
                for sx in range(sx0, sx1):
                    if mask[base + sx]:
                        continue
                    i = (base + sx) * 3
                    r += px[i]
                    g += px[i + 1]
                    b += px[i + 2]
                    weight += 1

            index = y * width + x

            if weight:
                out[index * 3] = (r + weight // 2) // weight
                out[index * 3 + 1] = (g + weight // 2) // weight
                out[index * 3 + 2] = (b + weight // 2) // weight
                covered[index] = 1

    return out, covered


def bleed(pixels, covered, width, height):
    """Comble les pixels vides par dilatation, du bord vers l'exterieur.

    Le voisinage est a 8 : une dilatation a 4 laisse des diagonales vides et
    fait apparaitre un damier au bord des mipmaps.
    """
    filled = 0

    for _ in range(BLEED_LIMIT):
        front = []

        for y in range(height):
            for x in range(width):
                index = y * width + x

                if covered[index]:
                    continue

                r = g = b = n = 0

                for dy in (-1, 0, 1):
                    ny = y + dy
                    if ny < 0 or ny >= height:
                        continue
                    for dx in (-1, 0, 1):
                        nx = x + dx
                        if nx < 0 or nx >= width or (dx == 0 and dy == 0):
                            continue
                        neighbour = ny * width + nx
                        if not covered[neighbour]:
                            continue
                        r += pixels[neighbour * 3]
                        g += pixels[neighbour * 3 + 1]
                        b += pixels[neighbour * 3 + 2]
                        n += 1

                if n:
                    front.append((index, r // n, g // n, b // n))

        if not front:
            break

        for index, r, g, b in front:
            pixels[index * 3:index * 3 + 3] = bytes((r, g, b))
            covered[index] = 1

        filled += len(front)

    return filled


# ------------------------------------------------------------------ main

def main():
    parser = argparse.ArgumentParser(description="Cuit une illustration peinte "
                                                 "en texture projetee.")
    parser.add_argument("--illustration", required=True,
                        help="l'image peinte, pleine resolution (maquettes/)")
    parser.add_argument("--gabarit", required=True,
                        help="le blockout rendu par le build — la reference de cadre")
    parser.add_argument("--out", required=True,
                        help="la texture a ecrire (assets/textures/)")
    parser.add_argument("--force", action="store_true",
                        help="ecraser une texture deja en place")
    args = parser.parse_args()

    out = Path(args.out)

    if out.exists() and not args.force:
        raise SystemExit("%s existe deja - ajouter --force pour l'ECRASER" % out)

    art = read_png(Path(args.illustration))
    blockout = read_png(Path(args.gabarit))

    if blockout["w"] % GABARIT_SCALE or blockout["h"] % GABARIT_SCALE:
        raise SystemExit("le gabarit (%d x %d) n'est pas un multiple de %d"
                         % (blockout["w"], blockout["h"], GABARIT_SCALE))

    width = blockout["w"] // GABARIT_SCALE
    height = blockout["h"] // GABARIT_SCALE

    art_mask, art_bg, art_count = background_mask(art)
    blockout_mask, blockout_bg, _ = background_mask(blockout)

    art_marks = landmarks(art, art_mask)
    blockout_marks = landmarks(blockout, blockout_mask)

    fit_x = fit(blockout_marks["h"], art_marks["h"])
    fit_y = fit(blockout_marks["v"], art_marks["v"])

    residual_x = max(abs(a * fit_x[0] + fit_x[1] - b)
                     for a, b in zip(blockout_marks["h"], art_marks["h"]))
    residual_y = max(abs(a * fit_y[0] + fit_y[1] - b)
                     for a, b in zip(blockout_marks["v"], art_marks["v"]))

    print("\n[bake_illustration] %s" % out.name)
    print("  illustration  %d x %d   fond %s, %.1f %% de l'image"
          % (art["w"], art["h"], art_bg, 100.0 * art_count / (art["w"] * art["h"])))
    print("  gabarit       %d x %d   fond %s   (rendu a %dx)"
          % (blockout["w"], blockout["h"], blockout_bg, GABARIT_SCALE))
    print("  reperes   X  gabarit %s" % [round(v, 1) for v in blockout_marks["h"]])
    print("               illu    %s" % [round(v, 1) for v in art_marks["h"]])
    print("  reperes   Y  gabarit %s" % [round(v, 1) for v in blockout_marks["v"]])
    print("               illu    %s" % [round(v, 1) for v in art_marks["v"]])
    print("  recalage  X  x%.5f %+.2f px   ecart max %.2f px de gabarit "
          "(%.2f de texture)"
          % (fit_x[0], fit_x[1], residual_x, residual_x / fit_x[0] / GABARIT_SCALE))
    print("  recalage  Y  x%.5f %+.2f px   ecart max %.2f px de gabarit "
          "(%.2f de texture)"
          % (fit_y[0], fit_y[1], residual_y, residual_y / fit_y[0] / GABARIT_SCALE))

    # Le pochoir n'entre en jeu qu'ICI : il lui fallait le recalage, et le
    # recalage se mesure sur les masques de couleur.
    stencil = erode(blockout_mask, blockout["w"], blockout["h"], GABARIT_EROSION)
    gated = gate_on_silhouette(art, art_mask, stencil,
                               blockout["w"], blockout["h"], fit_x, fit_y)

    print("  pochoir       %d pixels d'illustration rejetes hors blockout "
          "(halo antialiase)" % gated)

    pixels, covered = resample(art, art_mask, width, height, fit_x, fit_y)
    empty = sum(1 for value in covered if not value)
    filled = bleed(pixels, covered, width, height)

    print("  texture       %d x %d px   (%d pixels de fond, %d combles par "
          "dilatation)" % (width, height, empty, filled))

    if empty - filled:
        print("  ATTENTION : %d pixels n'ont PAS ete combles"
              % (empty - filled))

    write_png(out, width, height, pixels)
    print("  ecrit -> %s  (%d octets)" % (out, out.stat().st_size))
    # ASCII pur, et ce n'est pas de la coquetterie : la console Windows sort en
    # cp1252, et un pictogramme ici ferait planter le script APRES l'ecriture de
    # la texture — la pire place possible pour une erreur.
    print("  A VERIFIER dans %s.import : compress/mode=0, mipmaps/generate=true,"
          % out.name)
    print("     detect_3d/compress_to=0   (le piege n.3 de \"Pipeline 3D\")\n")


main()
