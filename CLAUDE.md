# CLAUDE.md — Zeucozy

Guide de référence pour Claude Code sur ce projet. Lire les docs listés ci-dessous avant toute tâche non triviale.

---

## Projet

**Zeucozy** est un jeu action-roguelite cozy à thème chat, de type survivor. Le joueur contrôle un chat qui survit à des vagues d'ennemis (aspirateur, chien, concombre), collecte des croquettes (XP) et choisit des améliorations à chaque niveau.

- **Moteur :** Godot 4.7.1-stable — GDScript idiomatique Godot 4
- **Physique :** Jolt Physics
- **Plateforme cible :** Windows (DirectX 12), dev sous VS Code
- **Dépôt :** `https://github.com/piiieeere/zeucozy.git`
- **Branche principale :** `master` — branche de travail : `dev`

---

## ⚠️ Pivot graphique : 2D → 3D (2026-08-15)

Le projet **abandonne les sprites 2D** au profit de **modèles Blender 3D cel-shadés**.

- Tous les assets sprites et l'outillage de découpe ont été **supprimés** du dépôt le 2026-08-16.
  Ils restent récupérables dans l'historique git (`git show dcc3fff:assets/sprites/...`).
- Le joueur est le chat cel-shadé ; les ennemis restent des **primitives 3D** placeholders
  (capsule, sphère) en attendant l'aspirateur, le chien et le concombre.
- **Rien de 3D n'est encore dans le dépôt.** Le modèle en cours vit hors projet :
  `C:\Users\tibo\Documents\zeucozy_3d\chat_style_v1.blend`
- **Style arrêté :** variante **A** — 2 tons de cluster, contour épais (×1,75).
  Lisibilité maximale, très cartoon. Voir §2bis de `Visual Art Direction.md`.

### Précision de style : rétro anime 80–90 (2026-08-16)

Le rendu et l'animation se calent sur l'**anime TV des années 80–90**, d'après *Orbitals*
(Shapefarm / Kepler) — une 3D qui se fait passer pour du cellulo dessiné à la main.
**Ghibli garde** le ton cozy, la palette et les formes ; **le rétro anime apporte** la
technique. L'univers sci-fi d'*Orbitals* n'est **pas** repris.

- **Trait d'encre** — épaisseur variable (canal R des couleurs de sommet), couleur teintée
  vers la couleur locale, dépassements peints
- **Ombre = forme dessinée** — biais peint (canal G) ajouté au seuil, pas subi de l'éclairage
- **Animation en pas** — squelette sur 3s (~20 fps), **position et caméra lisses à 60**.
  Rien à changer dans `player.gd` / `enemy.gd` : la cadence vit dans les fichiers d'animation.
  ⚠️ *« Position »* inclut le **rebond de marche** : voir « La fluidité » plus bas
- **Post-process léger et permanent** — **le grain, et rien d'autre** (3–5 %, *rafraîchi
  sur 3s*). Pas de tremblement d'image ni de saignement chroma (écartés).
  ⚠️ **La halation a été retirée le 2026-08-16, la vignette chaude le 2026-08-17** — les
  deux marchaient, les deux chargeaient l'image sans que le jeu y gagne (§15 :
  lisibilité > détail). Le test à appliquer à un effet de post n'est pas son rendu isolé :
  **il doit se remarquer quand on le COUPE.** Leurs réglages sont conservés en commentaire
  dans `retro_post.gdshader`, et le diagnostic de la halation dans `Pipeline 3D.md` : si on
  la rebranche, elle ne peut **pas** se seuiller sur la luminance absolue, la palette
  parchemin étant déjà à ~0,93.
  🔍 **La vignette a été mesurée avant d'être coupée** : soupçonnée de fabriquer des lignes
  parasites, elle donnait en fait une rampe **parfaitement lisse**, sans un contour de
  banding, sur les deux coins bas des frames du jeu. **Des lignes parasites ne se cherchent
  pas dans le post** — il ne reste qu'un bruit par cellule de 1,5 px

> Toute la donnée de style traverse le glTF via **un seul attribut de couleur de sommet
> `Attr_Style`** (R = épaisseur du trait, G = biais d'ombre peinte, B = masque d'accent).
> ✅ Peint et opérationnel depuis le 2026-08-16. Détail dans `Convention Blender.md`.

> ⚠️ **Le chat ne s'exporte QUE par `tools/export_cat.py`.** L'exporteur glTF de
> Blender 5.2 ne sait pas sortir `Attr_Style` sur ce maillage — voir le piège n°6 plus bas.
> Un export par le menu Fichier → Export produit un asset silencieusement cassé.

### ✅ Le risque principal est levé (2026-08-16)

Le chat est exporté (`assets/models/player_cat.glb`), importé, et **le cel-shading + le
contour sont reproduits en shader Godot**. Le style tient hors de Blender.

- `shaders/cel_toon.gdshader` — cluster 2 tons, `unshaded`, ombre dérivée en **TSV**
  depuis la couleur locale (le gris multiplié est structurellement impossible)
- `shaders/cel_outline.gdshader` — coque inversée, à brancher en **`next_pass`**
  avec `render_mode cull_front`
- `shaders/cel_face.gdshader` — **visage peint** : yeux, nez, bouche en ω, moustaches.
  Espace facial projeté + SDF, appliqué aux surfaces `visage` et `museau_peint`.
  Rien n'est modelisé (§2bis)
- `shaders/cel_core.gdshaderinc` — fonctions partagées (TSV, SDF 2D)
- `scenes/tests/cel_test.tscn` — banc de test isolé du gameplay 2D : instancie le `.glb`,
  applique les shaders, fait le tour de caméra 8 directions et enregistre 8 PNG

**Restes connus :** liseré d'œil qui dépasse de profil ; Blender et Godot ont divergé
(le `.blend` ignore le visage peint et l'oreille peinte).

> ✅ **La plongée caméra est passée de 60° à 45°** (2026-08-16), après comparaison à taille
> de jeu sur 45/50/55/60. À 60° la croupe passait **au-dessus** de la tête et avalait les
> oreilles : le chat se lisait comme un cadenas. À 45° la tête redevient un disque net, les
> oreilles se détachent sur le fond, les pattes avant reposent le personnage au sol.
>
> ⚠️ **Mais l'attribution était trop large.** Sur les trois problèmes imputés à la plongée,
> **un seul** disparaît. Le liseré d'œil de profil et l'oreille éloignée projetée dans le
> crâne sont **identiques à 45° et à 60°** : ce sont des problèmes de peinture et de modèle,
> pas de cadrage. Ne pas les rechercher du côté de la caméra.
>
> 🔍 **Diagnostic repris le 2026-08-16, et les deux étiquettes étaient fausses :**
> - Le **liseré d'œil n'est pas dans le `.blend` du tout.** Les yeux — cerne compris — sont
>   dessinés par `cel_face.gdshader` seul ; Blender ne peint aucun visage. C'est un réglage
>   de shader (`face_front_min` contre `eye_pos + eye_size + eye_border`), corrigible à
>   tout moment sans rouvrir Blender. **Toujours ouvert.**
> - L'amande de la joue n'est **ni un trou, ni une normale retournée, ni la base du cône
>   qui perce** — la base est 0,09 à 0,18 *dans* la paroi, mesuré. C'est **l'oreille
>   PROCHE, pas l'éloignée**, et c'est sa partie légitimement émergée : sous 45° de
>   plongée, l'oreille proche se projette plus bas que l'éloignée et atterrit au milieu du
>   disque de la tête, où sa propre coque inversée la referme en tache autonome.
>   *Méthode qui a tranché : teinter la surface en magenta, puis rendre en Workbench
>   `MATERIAL` + backface culling, puis lancer un rayon caméra à travers le pixel.*
>
> Effet de bord à connaître : à 45° **le décor occulte pour de bon** — un ennemi derrière un
> meuble disparaît, ce qui n'arrivait pas à 60°.

### Chat tuxedo — noir et blanc (2026-08-16)

Le chat n'est plus roux ambre. **Noir et blanc**, avec le blanc aux extrémités des
pattes, au bout de la queue, sur le poitrail et sur le bas du visage jusqu'au museau.
Les yeux restent verts. Deux règles de la DA survivent intactes et contraignent tout :
jamais de `#000000` (§2bis), jamais de blanc froid (§5) — le noir est donc un brun très
sombre `#4A4038`, le blanc un crème chaud `#F7EFE0`, choisi plus clair que le parquet
`#E8D4A8` pour que le chat ne s'y fonde pas.

Le blanc arrive par **trois chemins différents**, et ce n'est pas de la dispersion :
chaque zone est d'une nature différente et un seul chemin ne pouvait pas les couvrir.

| Zone | Chemin | Pourquoi celui-là |
|---|---|---|
| Bouts de pattes, bout de queue | **Matériau** `fourrure_blanche`, créé dans Blender par `tools/paint_tuxedo.py` | Un masque en shader y glissait : Godot applique le skinning avant `vertex()` (piège n°5), et `rest_undo` ne savait défaire que **deux** os par surface — il en faut cinq ici. ⚠️ **Cette limite est tombée le 2026-08-16** (voir « Les griffes ») ; le blanc reste néanmoins un matériau, il n'y a aucune raison de le refaire |
| Bas du visage + museau | **Dessiné** par `cel_face.gdshader` en espace facial (`BIB` dans `cel_model.gd`) | Le bas du visage n'est pas une coque à part, c'est la moitié basse de la sphère de tête. Même méthode que les yeux (§2bis) |
| Poitrail | **Calotte peinte** sur `corps_peint`, avec `paint_shaded` | Voir juste en dessous |

> ⚠️ **La surface `ventre` est invisible.** Son nom promet le plastron ; en fait sa sphère
> est enfermée dans celle du dos et ne dépasse que de **0,03** sur l'avant. Mesuré le
> 2026-08-16 en la peignant en magenta et en faisant le tour de caméra : ~0,02 % de
> l'image, sur trois vues de profil seulement. **Ne pas y peindre quoi que ce soit
> d'important.** Le poitrail visible appartient à `corps_peint`, qui tient sur un seul
> os (`dos`) — donc `rest_undo` suffit à l'ancrer, comme le visage sur `tete`.

Deux réglages ont dû suivre le changement de valeur, et pour la même raison de fond —
**un mélange se juge sur ce qu'il mélange** :

- `accent_strength` **0,35 → 0,12**. L'accent est un mélange vers le crème. Sur l'ambre
  il montait la valeur de 0,85 à 0,89 ; sur le noir il l'aurait portée de 0,29 à 0,52 et
  le dessus du chat aurait viré au gris — un 3ᵉ ton de cluster, contre §5.5.
- **Trait plus sombre sur le noir** (`#1A120C` au lieu de `#3D2B1A`) et **teinte réduite
  sur le blanc** (0,06 au lieu de 0,20). Le trait doit rester plus sombre que l'aplat
  *et* que son ombre. Sur le noir, `#3D2B1A` repassait au-dessus du ton d'ombre ; sur le
  blanc, les 20 % de §5.4 — mélangés en **linéaire** — délavaient le trait à `#82796F`.

### La fluidité — pourquoi le jeu paraissait à 20 fps (2026-08-16)

Le déplacement donnait des à-coups et l'image entière semblait tourner à 20 fps.
**Elle tenait 60,0 fps sans un dixième de milliseconde d'écart** — mesuré sur 70 frames,
`dt` min = moy = max = 16,67 ms. Ce n'était pas une question de performance, et aucun
profileur ne l'aurait montré.

C'est le défaut le plus traître du style : **la cadence en pas est voulue, donc on ne peut
pas la juger à l'œil** — on ne sait pas dire si ce qu'on voit est le style ou un accident.
D'où `scenes/tests/motion_probe.tscn`, qui mesure le **battement** : de combien l'image
change d'une frame à la suivante, regroupé par phase modulo 3. À 1,0 rien ne saccade.

Deux causes, aucune des deux devinable, toutes deux corrigées :

| Cause | Avant | Après |
|---|---|---|
| **Le grain battait en bloc.** `floor(TIME * 20.0)` était global : *tous* les pixels changeaient au même instant, 20 fois par seconde. Le grain était la seule chose de l'image à battre — et il y faisait battre tout le reste avec lui | `img` **×1,87** | `img` **×1,04** |
| **Le rebond de marche sautait.** `racine.ty` est une translation de tout le corps, mais il vivait côté squelette, donc en pas : la silhouette montait de 2,5 px d'un coup toutes les 3 frames et restait figée entre — pendant que le sol défilait à chaque frame | `chat` **×6,52** | `chat` **×3,02** |

- **Le grain garde ses 20 Hz**, ce que demande §7 : c'est la **phase** qui est tirée de la
  cellule (`grain_stagger`). Localement il bout toujours sur 3s, globalement plus rien ne
  clignote d'un bloc. C'est d'ailleurs ce que fait la pellicule — le dessin est sur 3s, le
  grain du support est neuf à chaque photogramme.
- **Le rebond suit la règle que §7 posait déjà** : *« la position du personnage dans
  l'arène n'est pas en pas »*. Il y échappait par accident d'implémentation, pas par
  décision. Corrigé côté Godot dans `cel_model.gd`, sans toucher au `.blend`.
  ⚠️ **Changer l'interpolation ne suffit pas** : l'importateur réechantillonne à 60 fps,
  donc interpoler entre deux clés égales rend la même valeur et la courbe reste clouée à
  son escalier. Il faut **dédoublonner d'abord**. Et **LINEAR, pas CUBIC** — sur quatre
  échantillons par rebond la cubique passe *sous* zéro (mesuré : −0,0125) et le chat
  s'enfonce dans le parquet.
- **Les rotations n'ont pas bougé** : `bras_L` change toujours de pose aux frames
  0, 3, 6 … 24. La cadence en pas est intacte, et `animation_report()` la surveille —
  il surveille désormais **aussi l'inverse** sur la racine (une translation revenue en pas
  est une régression).

> 🔍 **Deux méthodes de mesure fausses, gardées ici parce qu'elles rendaient des chiffres
> parfaitement plausibles :**
> - **Caler la boîte de mesure avec `unproject_position` sans corriger l'échelle.** Elle
>   rend des coordonnées de *viewport*, l'image est à la résolution de la *fenêtre*, et le
>   stretch `canvas_items` les sépare. La boîte s'est posée sur l'ATH : on a mesuré pendant
>   trois runs la cadence du **texte du HUD**.
> - **Comparer les frames de pose aux autres.** Le grain battait sur 3 frames *lui aussi*,
>   mais décalé d'une frame : comparé aux poses il ressortait à **×0,72**, le chiffre le
>   plus rassurant de toute l'enquête, sur le pire cas mesuré. **Un battement se cherche
>   par sa période, jamais par un alignement supposé.**

> 🅿️ **Reste connu, mesuré, non traité : les pattes patinent d'un facteur 8,3.** La patte
> avant parcourt **0,36 m** par cycle quand le chat en couvre **3,0** (7,5 m/s × 0,4 s).
> Aucune cadence ne rattrape ça — il faudrait un cycle de 0,05 s. C'est l'**amplitude** de
> balancement qu'il faut ouvrir, dans Blender. Piste conforme à §7 (4 à 8 poses) : un
> **galop de 4 poses sur 12 frames** (0,2 s), soit 1,5 m par cycle — l'ordre de grandeur
> de la foulée réelle d'un chat lancé. À décider avant de rouvrir le `.blend`.

### Pièges connus (appris à la dure, ne pas les reperdre)

1. **Le contour ne survit pas à l'export glTF.** Dans Blender il est fait en *coque inversée*
   (solidify + normales retournées + backface culling) — c'est du setup Blender, pas de la
   géométrie exportable. ✅ *Résolu le 2026-08-16* : refait dans `cel_outline.gdshader`.
   ⚠️ *Et l'aller-retour a coûté le contour Blender* : la fusion des 21 objets en `MSH_cat`
   a emporté leurs 21 Solidify, et personne ne l'avait noté — le viewport montrait un chat
   **sans contour**. `tools/build_outline.py` le repose, en prenant **Godot pour référence**
   (épaisseur 0,041 × `Attr_Style.R`, une encre par surface). Vérifié : le `.glb` réexporté
   est **md5-identique**, le contour ne part pas avec.
2. **Deux objets qui s'interpénètrent produisent un trait parasite** à leur intersection.
   ⚠️ *La parade documentée est insuffisante* : fusionner 21 objets en un seul **objet** ne
   fusionne pas la **géométrie** — le maillage garde 21 coques fermées, chacune génère sa
   propre coque inversée. En pratique les traits restants sont discrets et se lisent comme
   des traits dessinés : **on les garde**.
3. **Les poids automatiques déchirent ce modèle.** Le rig utilise des **poids rigides**
   (1 objet = 1 os), sauf la **queue** qui a un dégradé sur 3 os.
4. ✅ **Vérifié le 2026-08-16, et le piège n'était pas là où on l'attendait.** *Always Sample
   Animations* décoché suffit : le glTF sort bien en `STEP`, jamais rebaké en `LINEAR`.
   Mais la cadence mourait **deux fois ailleurs**, silencieusement :
   - **`animation/fps=30` dans le `.import` de Godot.** L'importateur rééchantillonne à
     30 fps, donc une pose toutes les 2 frames : sur 13 poses posées, 7 seulement
     retombaient sur la grille de 3. **À laisser à 60.**
   - **Deux canaux d'un même os avec des temps de clés différents.** Les trois `r*`
     fusionnent en UN quaternion glTF ; si leurs frames divergent, l'exporteur
     rééchantillonne **cet os** à 60 fps en LINEAR — sans erreur ni avertissement, et sur
     lui seul. Constaté sur `tete` dans `idle` (rx toutes les 12 frames, rz toutes les 24) :
     145 clés LINEAR à l'arrivée. `tools/build_animations.py` refuse désormais de construire
     une action qui viole cette règle.
   - Godot n'importe pas non plus le **mode de boucle** : tout arrive en `LOOP_NONE`, et
     `cel_model.gd` le repasse en `LOOP_LINEAR` au chargement.
5. **Godot applique le skinning AVANT `vertex()`** *(vérifié le 2026-08-16, en animation)*.
   `VERTEX` arrive déformé : tout masque peint calculé dessus **glisse sur la géométrie** dès
   qu'un os bouge. Parade dans les shaders : `rest_undo`, l'inverse du delta repos→pose de
   l'os porteur, remis à jour chaque frame. **Exact grâce aux poids rigides du piège n°3.**
   Pour une paire symétrique sur deux os (les oreilles), deux matrices, choisies par le
   signe de `x`. Ne jamais laisser une `mat4` d'uniform à sa valeur par défaut.
   ✅ **Le « choisi par le signe de `x` » n'est plus la seule voie** *(2026-08-16)* :
   `BONE_INDICES` et `BONE_WEIGHTS` **sont lisibles** dans le vertex shader de Godot 4
   (vérifié en compilant sur 4.7.1). On peut donc choisir la matrice **par sommet, d'après
   son os porteur** — c'est ce que font les griffes, sur une surface à cinq os. Le signe de
   coordonnée reste bon pour deux coques qui ne se croisent jamais ; au-delà, il devine.
6. **L'exporteur glTF ne sait pas sortir `Attr_Style`** *(2026-08-16)*. Sur ce maillage les
   trois modes échouent : `MATERIAL` n'exporte **rien** (la détection d'usage ne suit que
   les chemins PBR, pas notre `Shader to RGB` → `Color Ramp`) ; `ACTIVE` et `NAME` ne
   remplissent que **la 1ʳᵉ primitive sur 6** — les cinq autres sortent en blanc pur, donc
   G = 1,0, donc en pleine lumière permanente. Le domaine (POINT/CORNER) n'y change rien.
   Parade : `tools/export_cat.py` réinjecte `COLOR_0` **par position** après export
   (7 867 sommets, 100 % exacts). ✅ *Aucune conversion sRGB sur le trajet — vérifié bout
   en bout, un G peint à 0,47 arrive à 0,47 dans le shader.*

### ✅ Décision tranchée : nœuds 3D (2026-08-16)

L'alternative — pré-rendre les modèles en sprites pour garder le code 2D — est **écartée**.
Tout le gameplay est passé en nœuds 3D (`CharacterBody3D`, `Camera3D`, `MeshInstance3D`),
conformément à la 3D temps réel de §2bis. Le chat est branché dans `scenes/main.tscn`.

**Ce que la migration a changé, et rien d'autre :** les `Vector2` sont devenues des
`Vector3` dans le plan **XZ** (`y` 2D → `z` 3D), et les réglages sont passés du pixel au
mètre (**1 m ≈ 20 px** d'avant). La logique de run — vagues, difficulté, XP, upgrades,
Game Over — n'a pas bougé d'une ligne.

Deux ajouts qu'impose la vue plongeante, et qui n'existaient pas en 2D :

- **un carrelage au sol** — sans lui, traverser un sol uni ne se voit pas, on se croit
  immobile ;
- **une ombre de contact** sous chaque personnage — sinon tout flotte. C'est le **seul
  matériau non-cel du jeu**, et c'est assumé : c'est la seule chose qui doit se *mélanger*
  au sol, dont la couleur change d'un tapis à l'autre.

⚠️ **Le décor se dimensionne en mètres, jamais en fraction d'arène.** Un canapé
proportionnel à une arène de 160 m serait un mur de 20 m : à l'échelle du chat
(1,74 unité) plus rien ne se lirait. Le motif de décor se **répète par cellules** de
40 × 28 m — corollaire du même constat : sept meubles à taille réelle dans 160 × 90 m, on
n'en croiserait jamais un.

---

## Outils locaux

| Outil | Chemin |
|---|---|
| **Godot 4.7.1** | `C:\Users\tibo\Games\Godot\Godot_v4.7.1-stable_win64.exe` (+ `..._console.exe`) |
| Blender | 5.2.0 LTS — fichiers de travail dans `C:\Users\tibo\Documents\zeucozy_3d\` |
| Vault Obsidian | `C:\Users\tibo\ThibsVault\02 — Projets\jeu-video-godot\` |

Godot n'est **pas dans le `PATH`** — toujours l'appeler par son chemin complet.

```bash
# Reconstruire idle/walk dans le .blend, puis exporter le chat
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
  "C:/Users/tibo/Documents/zeucozy_3d/chat_style_v3.blend" \
  --python tools/build_animations.py -- --save
# Repeindre le pelage tuxedo (sans --save : essai a blanc, rien n'est ecrit)
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
  "C:/Users/tibo/Documents/zeucozy_3d/chat_style_v3.blend" \
  --python tools/paint_tuxedo.py -- --save
# Reposer le contour Blender — epaisseur pilotee par Attr_Style.R, une encre par surface
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
  "C:/Users/tibo/Documents/zeucozy_3d/chat_style_v3.blend" \
  --python tools/build_outline.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
  "C:/Users/tibo/Documents/zeucozy_3d/chat_style_v3.blend" --python tools/export_cat.py
# Réimporter les assets sans ouvrir l'éditeur
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --headless --import --path .
# Recuperer les polices d'UI (rejouable, idempotent) — puis reimporter
powershell -ExecutionPolicy Bypass -File tools/fetch_fonts.ps1
# Banc de test du cel-shading — mode interactif (orbite souris, touches O/P/A)
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/cel_test.tscn
# Banc de test — mode capture : 8 directions + sondes de skinning, puis quitte
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/cel_test.tscn -- --capture
# Reconstruire puis exporter le canape (le .blend est REGENERE, jamais edite a la main)
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
  --python tools/build_couch.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
  "C:/Users/tibo/Documents/zeucozy_3d/prop_canape_v1.blend" \
  --python tools/export_prop.py -- --mesh MSH_canape --out prop_canape.glb
# Banc des meubles — 8 directions + le chat a cote et sur l'assise, au cadrage de jeu
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/prop_test.tscn -- --capture
# Banc de PAUSE — ce qui se fige, ce qui vit, ce qui repart (18 verdicts)
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . \
  res://scenes/tests/pause_probe.tscn
# Banc de FLUIDITE — le chat marche, on mesure le battement de l'image sur 3 frames
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . --fixed-fps 60 \
  res://scenes/tests/motion_probe.tscn -- --frames=64
#   --nograin   grain coupe          --oldgrain  grain en phase (l'etat d'avant)
#   --root-step rebond en escalier   --shots     vignettes du chat, frame par frame
# Le jeu, en enregistrant des PNG puis en quittant — pour juger le rendu sans y jouer
# ⚠️ --aim= est OBLIGATOIRE des qu'on compare deux captures : sans lui le curseur
#    physique donne un cap au chat, et les deux images ne sont pas comparables.
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . \
  --write-movie <dossier>/game.png --fixed-fps 30 --quit-after 200 -- --aim=135
# Comparer l'ANTIALIASING de la silhouette, sans editer project.godot
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . \
  --write-movie <dossier>/g.png --fixed-fps 60 --quit-after 40 -- --aim=135 --msaa=0
#   --msaa=0|2|4|8   la couverture de geometrie — la silhouette. 4 est le reglage du jeu
#   --ssaa=2.0       la resolution interne de la 3D — TOUS les bords, cluster compris
#   --aim=<degres>   cloue la visee : c'est ce qui rend deux captures comparables
```

> Le banc de test **et** le jeu partagent le même rendu, via `scripts/systems/cel_model.gd` :
> un réglage corrigé d'un côté profite à l'autre sans recopie. Le banc reste l'endroit où
> **juger** le chat (tour de caméra, bascules, sondes de skinning) ; le jeu, l'endroit où le
> voir **à taille de jeu**, ce que demande §16.

---

## Documentation de référence

> ⚠️ La doc **ne vit plus dans `docs/`** (dossier supprimé au commit `bd66724`).
> Elle est dans le vault Obsidian : `C:\Users\tibo\ThibsVault\02 — Projets\jeu-video-godot\`

Lire ces fichiers avant toute tâche concernant le domaine correspondant :

| Fichier (vault) | Contenu |
|--------|---------|
| `00 - Index.md` | Map of content — pitch, état actuel, stack |
| `01 - Game Design/Game Manifest.md` | Manifeste — boucle de gameplay, ennemis, upgrades, équilibre |
| `03 - Production/Contexte IA.md` | Contraintes de développement, préférences, à lire EN PRIORITÉ |
| `02 - Direction Artistique/Visual Art Direction.md` | **Doc clé** — §2bis = règles Ghibli traduites en 3D, §2ter = vocabulaire rétro anime, §7 = cadence en pas, §8bis = post-process |
| `02 - Direction Artistique/Convention Blender.md` | Les gestes dans Blender — nœuds toon, couleurs de sommet, cadences, réglages d'export |
| `02 - Direction Artistique/Pipeline 3D.md` | Pipeline Blender → glTF → Godot, + la liste de ce qui reste à écrire en shader |
| `04 - Roadmap/Critères MVP.md` | Critères de succès du prototype |
| `04 - Roadmap/Todo.md` | Suivi des features en cours |

> 📦 **Archivés** (pipeline 2D abandonné, conservés pour référence historique) :
> `Pipeline Sprites.md`, `Convention de Nommage Sprites.md`, `Prompts de Génération.md`,
> `Template Intégration Assets.md`.

### Le manuel Godot, en local (2026-08-17)

Les **398 pages** de `https://docs.godotengine.org/en/latest/tutorials/` sont converties en
Markdown dans le vault : `05 - Godot Docs/`, index racine `Tutorials.md`, **25 sections**
(2D, 3D, Animation, Physics, Shaders, Scripting, UI, Performance, Navigation, Export…).

**À consulter AVANT d'implémenter, pas seulement quand on est bloqué.** C'est là que vivent
les bonnes pratiques du moteur, les pièges d'API et les raisons derrière une signature.
Chercher coûte une commande ; se tromper de nœud coûte une refonte.

```bash
# Chercher dans tout le manuel (le dossier a un espace : garder les guillemets)
grep -rn "move_and_slide" "C:/Users/tibo/ThibsVault/02 — Projets/jeu-video-godot/05 - Godot Docs"
```

- Chaque note porte en frontmatter son `source` — l'URL d'origine, pour citer ou vérifier.
- Les **admonitions sont des callouts** (`> [!WARNING]`, `> [!NOTE]`) : le manuel y range ses
  pièges. Ce sont les premières lignes à lire d'une page, pas les dernières.
- Les blocs de code sont **étiquetés GDScript / C#** — ne pas recopier le C# par distraction.

> ⚠️ **LA RÉFÉRENCE DE CLASSES N'Y EST PAS.** `classes/` — l'API proprement dite (`Node2D`,
> `CharacterBody3D`, la liste des méthodes, propriétés et signaux) — n'a pas été récupérée,
> soit ~4 000 pages générées. Les renvois vers une classe sont donc des **URL externes** vers
> docs.godotengine.org. **Ne pas conclure d'une recherche infructueuse que le manuel ne
> couvre pas le sujet** : la réponse est peut-être dans l'API, qui est en ligne.

> ⚠️ **Les images ne sont pas copiées**, elles pointent en lien distant. Une page se lit hors
> ligne, ses captures non.

> ⚠️ **C'est la doc de `latest`, donc de la version EN DÉVELOPPEMENT** (branche `master` de
> `godotengine/godot-docs`, récupérée le 2026-08-17), pas de la 4.7.1 stable du projet.
> L'écart est mince, mais c'est sur une API récente qu'il se loge — en cas de doute sur une
> fonction fraîche, vérifier dans Godot avant de s'y fier.

---

## Architecture

```
zeucozy/
├── scenes/           # Scènes Godot (.tscn) — tout en nœuds 3D
│   ├── main.tscn     # Scène principale (environnement, arène, caméra, UI, game manager)
│   ├── player.tscn   # CharacterBody3D + CelModel (le chat) + ombre de contact
│   ├── claw_slash.tscn # ⚔️ La griffure — l'attaque auto (Area3D + décalque dessiné)
│   ├── projectile.tscn # 💤 En sommeil — gardé entier pour un usage futur
│   ├── xp_orb.tscn
│   ├── enemies/
│   │   ├── chaser.tscn   # Ennemi rapide (spawn dès le début) — capsule placeholder
│   │   └── brute.tscn    # Ennemi costaud (spawn après 22s) — sphère placeholder
│   └── tests/
│       ├── cel_test.tscn  # Banc de test du cel-shading du chat, isolé du gameplay
│       ├── prop_test.tscn # Banc de test du mobilier
│       ├── motion_probe.tscn # ⏱️ Banc de fluidité — mesure le battement de l'image
│       └── pause_probe.tscn  # ⏸️ Banc de PAUSE — ce qui se fige, ce qui vit, ce qui repart
├── scripts/          # Logique GDScript
│   ├── main.gd       # Directeur de jeu, spawn, difficulté, UI
│   ├── player.gd     # Le CORPS du chat : mouvement, visée, vie, XP — plus aucune arme
│   ├── enemy.gd      # Comportement ennemi de base (follow, dégâts)
│   ├── claw_slash.gd # ⚔️ Griffure : 6 poses + dégâts sur les 3 premières
│   ├── projectile.gd # 💤 Projectile (direction, portée, collision) — débranché
│   ├── xp_orb.gd     # Croquette d'XP (magnétisme, collecte)
│   ├── arena.gd      # Décor : sol, tapis, mobilier, mur de bordure
│   ├── camera_rig.gd # Vue plongeante 45°, suit le joueur, bornée à l'arène
│   ├── skills/       # ⭐ LES COMPÉTENCES — une par fichier, toutes au même contrat
│   │   ├── skill.gd         # Le contrat : setup / set_tier / tick. Aucune n'a de _process
│   │   ├── active_skill.gd  # Le socle des ACTIFS — cooldown, garde à froid, charge
│   │   ├── claw_skill.gd    # ⚔️ La griffure — slot AUTO n°1, l'arme DIRIGÉE
│   │   ├── hairball_skill.gd # 🌀 La boule de poils — AUTO à distance, auto-visée
│   │   ├── dust_skill.gd    # 🌫️ Les moutons — AUTO semé derrière, récompense de BOUGER
│   │   ├── bite_skill.gd    # 🦷 La morsure — le 1ᵉʳ ACTIF, cible unique
│   │   ├── hiss_skill.gd    # 💢 Le feulement — ACTIF de RECUL, ne compte pas en dégâts
│   │   └── breath_skill.gd  # 💨 L'haleine puante — pilote l'aura, pas son dessin
│   ├── systems/
│   │   ├── skill_definitions.gd    # ⭐ LE catalogue — types, paliers, poids de tirage
│   │   ├── skill_set.gd            # ⭐ Ce que le chat PORTE — build + horloge des compétences
│   │   ├── cel_style.gd            # Matériaux cel des primitives, du sol + ombre de contact
│   │   ├── cel_model.gd            # ⭐ Le style du chat — partagé jeu ↔ banc de test
│   │   ├── cel_prop.gd             # ⭐ Le style des meubles — .glb sans squelette
│   │   ├── fx_cadence.gd           # ⭐ Les 3 durées de pose des FX (§7) — source unique
│   │   ├── render_quality.gd       # 🪞 L'AA de la 3D — MSAA 4×, + `--msaa=` / `--ssaa=`
│   │   ├── driven_fx.gd            # ⭐ `class_name DrivenFx` — les FX dont l'horloge vient
│   │   │                           #    de DEHORS (aura, mouton, onde). Une méthode :
│   │   │                           #    `advance(delta)`. Les FX autonomes n'en sont pas
│   │   ├── breath_aura.gd          # 💨 L'haleine puante — aura lootable, poses + morsure
│   │   ├── bite_fx.gd              # 🦷 Les mâchoires de la morsure — 8 poses, crocs dessinés
│   │   ├── shout_fx.gd             # 💥 L'onomatopée des ACTIFS — CHOMP, en pas, dans le monde
│   │   ├── hiss_ring.gd            # 💢 L'onde du feulement — 6 poses, pousse par le FRONT
│   │   ├── dust_bunny.gd           # 🌫️ Une touffe — naissance / repos / pouf, 3 cadences
│   │   ├── skill_thumb.gd          # 🖼️ La vignette d'une compétence — le VRAI FX en SubViewport
│   │   ├── ui_style.gd             # ⭐ Le style de l'interface — palette, polices, cadence
│   │   ├── locale.gd               # ⭐ TOUS les textes du jeu — français + anglais
│   │   ├── settings_store.gd       # Préférences du joueur sur disque (user://settings.cfg)
│   │   ├── impact_frame.gd         # 💤 Flash ambré plein cadre — DÉBRANCHÉ, gardé entier
│   │   └── hit_burst.gd            # 💥 Éclat de collision — étoile de manga, 6 poses
│   ├── ui/
│   │   └── hud.gd       # 🖥️ Le HUD + les cartons, construits EN CODE depuis ui_style
│   └── tests/
│       ├── cel_test.gd  # Cadrage, bascules et captures du banc du chat
│       ├── prop_test.gd # Banc des meubles : 8 directions + rapport de taille au chat
│       ├── motion_probe.gd # ⏱️ Fluidité : temps de frame + battement sur 3 frames
│       └── pause_probe.gd  # ⏸️ Pause : 18 verdicts sur `get_tree().paused` + process_mode
├── shaders/          # cel_toon, cel_outline, cel_face, cel_paws, retro_post
│                     # ui_frame (plaque grise, angles droits, repères d'angle,
│                     #           + le RELIEF : biseau, facette, ombre portée dure)
│                     # ui_speedlines (lignes de vitesse)
│                     # bite (la morsure — gencives rouges + crocs de chat qui s'engrènent)
                     # hiss_ring (le feulement — onde crème/encre, le seul FX sans chroma)
                     # dust_bunny (le mouton de poussière — touffe cernée posée au sol)
│                     # cel_paws (bouts de pattes + les 3 griffes dessinées)
│                     # cel_ground (parquet peint), cel_rug (tapis)
│                     # hit_burst (éclat de collision), impact_frame (flash, en sommeil)
│                     # claw_slash (la griffure — 3 traits cernés, billboard dirigé)
│                     # breath_aura (l'haleine puante — volutes cernées, décalque AU SOL)
│                     # cel_core + cel_floor (includes, fonctions pures)
├── tools/
│   ├── setup_input_map.gd  # ⌨️ La carte d'entrées (WASD + clics), rejouable
│   ├── export_cat.py       # ⚠️ LE SEUL chemin d'export du chat (voir piège n°6)
│   ├── build_animations.py # Construit idle/walk posées en pas, dans le .blend
│   ├── paint_tuxedo.py     # Pelage noir/blanc : matériau des extrémités + couleurs
│   ├── build_outline.py    # Contour Blender : épaisseur × Attr_Style.R, 1 encre / surface
│   ├── build_couch.py      # Canapé : géométrie ET Attr_Style, dans un .blend neuf
│   ├── export_prop.py      # Export générique d'un meuble, même réinjection COLOR_0
│   ├── fetch_fonts.ps1     # Récupère les polices d'UI en sous-ensembles (rejouable)
│   └── dump_paws.gd        # Relève os porteurs + boîtes de repos — source des PAWS
└── assets/
    ├── models/       # player_cat.glb, prop_canape.glb
    └── fonts/        # Dela Gothic One + Zen Kaku Gothic New, sous-ensembles + OFL
```

> **`cel_model.gd` est le point d'entrée du style.** Palette par matériau, visage peint,
> calottes, griffes, `rest_undo` : tout ce que le glTF ne transporte pas y est reconstruit,
> une fois.
> Ne jamais recopier ces constantes ailleurs — c'est ce qui ferait diverger jeu et banc,
> exactement comme Blender et Godot ont divergé.

---

## Systèmes clés

### Difficulté (main.gd)
- Scale temporelle : `1.0 + elapsed_time / 90.0`
- Intervalle de spawn : 0.95–1.35s, décroissant avec le temps
- Nombre d'ennemis par vague : 1 au début → 5 vers 140s

### Échelle du monde
**1 mètre ≈ 20 px** de l'ancienne version 2D. Le chat mesure **1,74 unité**. L'arène fait
**160 × 90 m**, le cadre en montre ~29 m de large et ~25 m de profondeur au sol (16 m
devant le point visé, 9 m derrière) — soit un chat à ~11 % de la hauteur d'écran.
Le réglage à bouger en premier si le chat paraît trop petit est `distance` dans
`camera_rig.gd` (38 m), pas le FOV.

### Joueur — stats de base

**Le corps** (`player.gd`) : Speed 7,5 m/s | **Vie 100 points** | Pickup radius 2,5 m

**Les armes** (`skill_definitions.gd`, jamais sur le chat) — valeurs par palier :

| | T1 | T2 | T3 |
|---|---|---|---|
| **Griffure** *(dégât / cadence / portée)* | 3 · 1,10 s · 5,2 m | 4 · 0,94 s · 5,65 m | 5 · 0,80 s · 6,1 m |
| **Boule de poils** *(dégât / cadence / portée)* | 2 · 1,60 s · 11 m | 3 · 1,35 s · 13 m | 4 · 1,10 s · 15 m |
| **Morsure** *(dégât / portée / recharge)* | 7 · 3,6 m · 6,0 s | 10 · 4,0 m · 5,0 s | 14 · 4,4 m · 4,2 s |
| **Haleine** *(rayon / dégât par morsure)* | 2,8 m · 1 | 3,35 m · 2 | 3,9 m · 3 |
| **Moutons** *(dégât / cadence / vie / rayon)* | 3 · 0,55 s · 3,5 s · 0,75 m | 4 · 0,46 s · 4,4 s · 0,85 m | 6 · 0,42 s · 5,0 s · 0,95 m |
| **Feulement** *(rayon / dégât / recharge)* | 3,6 m · 1 · 11,0 s | 4,3 m · 2 · 9,5 s | 5,0 m · 3 · 8,0 s |

Arc frontal de griffure **120°, à tous les paliers** — l'ancienne description promettait un
balayage « plus large », le code ne l'a jamais fait.

Projectile *(en sommeil, plus branché à aucune upgrade)* : damage 1 | Speed 17,5 m/s | Range 10 m

### L'attaque — la griffure (2026-08-16)
L'auto-attaque est passée du **projectile** au **corps à corps**. Le projectile n'est pas
supprimé : scène, script, `spawn_projectile` et `_fire_at_nearest_enemy` sont intacts. Il
est **débranché**, rien de plus — et depuis le 2026-08-17 il ne suit plus aucune upgrade,
le jour où il revient il revient en **compétence**.

> ⚠️ **Le code de la griffure a quitté `player.gd` le 2026-08-17** pour
> `skills/claw_skill.gd` — voir « Les compétences ». Son comportement n'a pas bougé d'une
> frame ; ce qui a changé, c'est qu'elle est devenue une compétence parmi d'autres, avec
> des paliers et une slot. Tout ce qui suit reste vrai.

- **Elle part sur `aim_direction`** — la visée, plus la marche depuis le 2026-08-16.
  Voir « La visée » juste en dessous.
- **La sphère donne la portée, l'angle donne le camp.** Sans le test d'angle, l'attaque
  toucherait aussi derrière et la direction ne servirait plus qu'à décorer.
- **Elle est enfant du chat**, et c'est le point : une griffure est un *geste*. Plantée
  dans le monde, elle s'en détacherait — à 7,5 m/s il avance de 1,5 m pendant ses 6 poses.
- **Portée et dessin ne peuvent pas diverger** : `claw_slash` dimensionne son décalque sur
  `claw_range` (`DRAW_SIZE`). Doubler la portée double le dessin, sans rien toucher d'autre.
- ⚠️ **Rien de tout ça ne touche à l'animation du chat.** Le squelette continue idle/walk ;
  la griffure est un décalque posé devant lui.

> ⚠️ **Le Y de l'UV d'un `QuadMesh` descend quand son Y local monte.** Le `UV * 2 - 1`
> habituel **retourne le dessin** — la griffure partait en arrière du chat. Et **un
> décalage monde vers l'avant se fait écraser par la plongée à 45°** : le décalque est donc
> ancré au centre du chat, c'est son rayon d'arc *dans le plan de l'écran* qui le place
> devant. Les deux ont été trouvés en **regardant les frames**, pas en raisonnant.

### L'antialiasing — un réglage calibré au banc, inerte en jeu (2026-08-18)

`feature_aa` valait `0,004` (visage) et `0,012` (pattes) : une largeur en **unités d'espace
objet**, pas en pixels. L'espace facial étant normalisé, la bande de lissage faisait
**~2,7 px au banc** et **~0,25 px à taille de jeu** — sous le pixel, donc le `smoothstep`
redevenait un `step`. Les deux shaders la mesurent désormais par `fwidth` sur les
coordonnées de leur repère, comme le `ps` des six shaders de FX.

- ✅ **Mesuré, pas supposé** : points isolés sur le visage en jeu (pixel bien plus sombre que
  ses 4 voisins) **52 → 31**. Sur une ligne de pixels, la moustache qui croisait la bavette
  valait **70** sur un fond à ~200 — un point noir en tout-ou-rien ; elle vaut **142**, sa
  vraie couverture. Un trait sub-pixel rendu en tout-ou-rien ne se lit pas comme un trait,
  **il se lit comme de la saleté**.
- ✅ Le banc ne bouge que de **0,8 %** de son image, et dans le bon sens : les moustaches y
  étaient légèrement floues, elles y sont franches. La valeur fixe n'était pas fausse, elle
  était **juste à un seul endroit**.
- ⚠️ **Dérivées prises sur les coordonnées SIGNÉES, et hors de tout branchement.** `uv.x`
  passe par `abs()` : sa dérivée exploserait sur la colonne de pixels de l'axe de symétrie,
  **pile là où passent le philtrum et le nez**. Et une dérivée dans un branchement non
  uniforme est **indéfinie en GLSL** — les pixels voisins du quad n'ont pas forcément pris
  la même branche (`in_face`, `v_paw >= 0`).
- ⚠️ **La bande est passée de `0..aa` à `-aa..+aa`** : posée à l'extérieur du contour elle
  épaissit chaque forme d'une demi-bande, invisible à un quart de pixel, visible à un et demi.
- 🅿️ Contrepartie assumée : **les moustaches sont plus pâles en jeu**. C'est correct — un
  trait qui couvre 40 % d'un pixel doit peser 40 % — et c'est déjà la doctrine du sol, dont
  `ink_line()` **éteint** une ligne passée sous le pixel. Le levier si elles sont trop
  discrètes est `whisker_weight`, **pas** la bande d'AA.

> ⚠️ **LA LEÇON DÉPASSE L'ANTIALIASING.** Un réglage réglé au banc n'est vérifié qu'au banc.
> Tout ce qui s'exprime en **unités d'objet** alors qu'il devrait s'exprimer en **pixels** est
> candidat au même défaut, et il est silencieux des deux côtés puisque chacun a l'air correct
> chez lui. Même famille que le `.blend` retrouvé réenregistré sur un état antérieur.

> ✅ **Le MSAA sur la silhouette est fait le 2026-08-19** — voir juste en dessous. 🅿️ Il
> reste **le bord du cluster** (`step()` brut dans `cel_toon`/`cel_face`), que MSAA ne
> touche pas — c'est du fragment — et qui **ne se juge pas à l'œil** puisque `edge_noise`
> le rend volontairement irrégulier.

### L'antialiasing de la SILHOUETTE — MSAA 4× (2026-08-19)

`[rendering]` de `project.godot` ne contenait que le driver : **aucun réglage d'AA**. Les
six shaders de FX, le sol, puis le visage et les pattes lissent déjà leurs bords à un pixel
près — mais tout ça est du **fragment**. Le trait du chat et des meubles est une **coque
inversée**, donc un vrai bord de **géométrie**, et c'était la dernière famille de bords du
jeu à être restée brute. `project.godot` porte désormais `anti_aliasing/quality/msaa_3d=2`
(4×), et `scripts/systems/render_quality.gd` pose les surcharges de comparaison.

**Mesuré sur la silhouette du chat à taille de jeu**, contre une référence supersamplée
(`--msaa=8 --ssaa=2.0`), sur les 534 pixels de bord de géométrie à fort contraste :

| | sans AA | 2× | **4×** | 8× | référence |
|---|---|---|---|---|---|
| Erreur au bord (moyenne) | 14,9/255 | 8,6 | **4,9** | 3,4 | 0 |
| Pire pixel | 87/255 | 75 | **54** | 58 | 0 |
| Pixels à couverture partielle | 36,0 % | 44,6 % | **46,4 %** | 48,3 % | 47,8 % |

- **4× et pas 8×.** 4× reprend **les deux tiers** de l'erreur et arrive à 1,4 point de la
  référence sur la couverture partielle ; 8× achète le dernier dixième. Le manuel tranche
  pareil : *« sticking to 2× or 4× MSAA is highly recommended as 8× MSAA is usually too
  demanding »*.
- ⛔ **TAA reste disqualifié** — il accumule sur plusieurs frames alors que le squelette
  change de pose d'un coup toutes les 3 frames : il lisserait exactement la discontinuité
  que la cadence existe pour créer, et tenterait de faire converger un grain bruité
  **exprès** à 20 Hz déphasé. ❌ **FXAA / SMAA** : écran-espace, ils floutent, et ils
  floutent **le trait d'encre** — contre le « bord franc » de §6.
- **MSAA 2D reste à 0** : l'interface est faite d'aplats à **angles droits** (§9), il n'y a
  pas une diagonale à lisser.
- 🅿️ **Le coût n'a PAS pu être mesuré**, et il faut le dire plutôt que l'inventer : chaque
  chemin de mesure disponible (temps GPU du `--write-movie`, `motion_probe`) est **dominé
  par la relecture de frame**, qui coûte dix fois le rendu. Trois tours entrelacés
  0×/4×/8× rendent 6,0 ms partout, au centième près — c'est l'enregistreur qu'on mesure.

> ⛔ **LA 3D NE REND PAS À LA RÉSOLUTION DE LA FENÊTRE, ET C'EST MESURÉ.** La note de la
> Todo affirmait que `stretch/mode="canvas_items"` ne touche que la 2D. **Faux** : le
> viewport racine garde la taille de base du projet, tout y est rendu — 3D comprise — puis
> l'image est étirée à la fenêtre. Relevé : **viewport 1175 × 648 pour une fenêtre
> 2560 × 1411**, soit un facteur **2,18**. Trois conséquences :
> - chaque marche d'escalier de silhouette est **agrandie 2,18 fois** avant d'atteindre
>   l'œil du joueur — c'est ce qui rend cette passe payante ;
> - le coût de MSAA est **borné une fois pour toutes** : il ne dépend pas de l'écran ;
> - `--ssaa=2.0` n'est donc pas du supersampling, c'est **rendre la 3D à la résolution de
>   l'écran**. À reprendre quand on tranchera le bord du cluster.
>
> `RenderQuality.report()` imprime les trois chiffres dès qu'on passe `--msaa=` ou
> `--ssaa=` : une mesure d'antialiasing qui ne sait pas à quelle résolution elle regarde ne
> mesure rien.

> ⚠️ **UNE CAPTURE DU JEU N'ÉTAIT PAS REPRODUCTIBLE, ET PERSONNE NE LE SAVAIT.**
> `player.gd` affirmait en commentaire que *« dans les captures `--write-movie` la souris ne
> bougera jamais »*. Faux : le curseur **physique** est quelque part quand la fenêtre s'ouvre
> dessous, Windows envoie un mouvement, et `aim_source` bascule sur MOUSE. Deux
> `--write-movie` identiques lancés à la suite ont sorti le chat **de dos** dans l'un et
> **de profil** dans l'autre — ~3 500 pixels d'écart sur le chat seul, sur une comparaison
> qui n'en cherchait que 600.
>
> D'où **`--aim=<degrés>`**, qui cloue la visée et rend la souris muette. Avec lui, deux
> captures du chat sont **bit à bit identiques** (0 pixel d'écart, vérifié) — sans lui,
> aucune mesure de bord n'a de sens. ⚠️ **Ça vaut pour toute capture comparative du dépôt** :
> `--pitch=`, `--decor-outline=`, un réglage de shader — l'écart qu'on croit lire entre deux
> images peut n'être qu'un cap de chat.

### Les griffes — 3 traits par patte (2026-08-16)

Trois traits de griffe **dessinés** sur chaque bout de patte, dans le registre exact des
moustaches : segments SDF dans un espace local projeté, rien de modélisé (§2bis).
`shaders/cel_paws.gdshader` + `CLAWS` / `PAWS` dans `cel_model.gd`.

- **Ce qui bloquait n'était pas le dessin, c'était l'ancrage.** Le visage tient sur **un**
  os, les oreilles sur deux que le signe de `x` sépare. Les extrémités crème en portent
  **cinq** (4 pattes + bout de queue) — c'est exactement ce qui avait fait renoncer à
  peindre le blanc en shader.
- ✅ **La sortie : `BONE_INDICES` est lisible dans le vertex shader** (piège n°5). On choisit
  la matrice **par sommet, d'après son os porteur**, au lieu de la deviner d'après un signe
  de coordonnée. Le bout de queue ne trouve pas son os dans la liste et ressort sans
  griffes — voulu, pas oublié.
- **Une matrice fait tout le trajet d'un coup** : défaire l'os, recentrer sur la patte,
  diviser par ses demi-axes. Le shader reçoit une position déjà normalisée. Les mesures
  restent dans `cel_model.gd`, relevées par `tools/dump_paws.gd` — **jamais estimées**.
- **Sonde permanente au banc** (`cel_paw_probe.png`) : une patte tordue à 45°, l'autre
  témoin. Le glissement est un défaut *silencieux*, et les griffes sont le premier masque
  ancré par os — une erreur d'appariement mettrait les griffes d'une patte sur une autre,
  ce qui reste plausible à l'œil.

> ⚠️ **Elles ne se voient pas à taille de jeu, et aucun réglage n'y changera rien.**
> Mesuré : **5 pixels** de griffe sur l'image entière. La patte visible fait ~6 × 4 px sous
> la plongée à 45°, et le corps cache les deux pattes arrière. Doubler l'épaisseur ne
> monte qu'à **9 px** tout en cassant le registre du trait secondaire (§5.4) — la limite
> est la taille de la patte à l'écran, pas le trait. Elles vivent donc au banc, et dans
> tout cadrage rapproché à venir (portrait, menu, écran de mort).

### L'haleine puante — la 1ʳᵉ compétence lootable (2026-08-17)

Une **aura circulaire posée au sol** autour du chat, qui blesse en continu tout ennemi
entré dedans. Les six upgrades d'origine règlent toutes un chiffre qui existe déjà ;
celle-ci **débloque une arme** que le chat n'a pas au départ, et se cumule.

| Palier | Rayon | Dégâts / morsure | Dégâts / s |
|---|---|---|---|
| 1 | 2,8 m | 1 | 1,5 |
| 2 | 3,35 m | 2 | 3,0 |
| 3 | 3,9 m | 3 | 4,5 |

- **Elle mord par à-coups** — une morsure toutes les ~0,67 s, et la couronne gonfle
  exactement sur cette pose-là. Des dégâts étalés frame par frame seraient invisibles :
  le joueur ne saurait jamais *quand* il gagne du terrain. Le cycle de poses **EST**
  l'intervalle de dégâts, il n'y a pas deux horloges.
- **Elle cohabite avec la griffure au lieu de la remplacer** : 5,2 m visés qui frappent 3
  d'un coup, contre 2,8 m qui ne se visent pas et grignotent sans arrêt. ⚠️ Son rayon est
  **sous** la portée de griffure et à peine au-dessus du contact ennemi (~1,55 m) — un
  mètre de répit, pas plus. C'est la première mécanique du jeu qui récompense de **rester**
  au contact.
- **Pas d'Area3D : un test de distance au centre.** Une sphère de collision aurait ajouté
  le rayon de la hurtbox ennemie (0,75 m) à la portée réelle — le souffle aurait mordu
  **27 % plus loin que ce qu'il montre**. Même principe que l'arc de la griffure : la
  géométrie donne les candidats, un test explicite donne la vérité.
- **Elle est enfant du chat** (c'est son souffle, il ne reste pas en arrière), mais le node
  `Player` ne tourne pas — seul `$Model` tourne — donc la couronne garde son orientation
  monde et ne pivote pas quand on vise ailleurs.

> ⚠️ **Elle a introduit une 3ᵉ cadence, et c'est une règle de DA, pas un réglage.**
> `FxCadence.AMBIENT_POSE` (5 frames) : la cadence de FX (2 frames) donne un clignotement
> à ~4 Hz sur une aura toujours affichée — exactement ce que §8bis a écarté en refusant le
> tremblement du signal. **La cadence se choisit sur la durée de vie de l'élément, pas sur
> sa catégorie.** §7 a été élargi dans la foulée.

> ⚠️ **C'est le seul FX posé À PLAT AU SOL, et le seul OCCULTÉ.** Les deux vont ensemble et
> aucun n'est un choix esthétique : un cercle en billboard resterait un cercle parfait à
> l'écran alors que les ennemis vivent dans le plan du sol — le dessin mentirait sur la
> portée. Et le test de profondeur ne peut **pas** être coupé comme sur la griffure :
> l'arc arrière de la couronne se projette ~1,8 m plus haut à l'écran, soit la taille du
> chat, et se peindrait par-dessus lui.

> 🔍 **Trois passes de réglage, toutes mesurées sur les frames, aucune devinable** — et
> elles disent la même chose : *une couronne régulière n'est pas un dessin, c'est un
> indicateur de portée.* (1) 11 volutes de 0,24 ne se recouvraient que de 0,03, la marge
> exacte que l'encre mange → collier de perles ; c'est l'**écartement des centres** qui
> décide, pas le nombre. (2) Le hasard seul ne défait pas la régularité : il faut une
> **modulation basse fréquence** (3 bosses sur le tour). (3) Un accent crème centré est un
> pois — il ne se lit comme un accent de brillance (§6) qu'une fois **rogné en croissant**
> par le bord de sa volute. Détail chiffré dans la DA, §8.

> ⚠️ **Le trait est exprimé en MÈTRES**, converti en unités de quad à l'affichage. La zone
> grandit à chaque palier : en fraction du quad, le trait grossirait avec elle. Et il se
> cale sur la taille de la **forme cernée** (~0,55 m de bouffée), pas sur celle du décalque
> — la griffure, qui fait plusieurs mètres, porte un trait bien plus épais.

### La visée — dissociée du déplacement (2026-08-16)

La griffure partait dans la direction de marche. Elle part désormais **là où le joueur
pointe**, à la souris. Marcher vers le bas en griffant vers le haut est un mouvement
possible, et c'est tout l'objet du changement : **la fuite cesse d'être passive.**

- **Le curseur est un point 2D, il faut un plan pour en faire un point du monde.**
  Pas le sol : sous 45° de plongée, un mètre de hauteur décale le point d'un bon demi-mètre
  à l'écran. Le plan est à `aim_height` = **0,7 m**, la hauteur où la griffure *mord*
  (`claw_slash.HIT_HEIGHT`) et celle des hurtbox ennemies (0,65 chaser, 0,80 brute) — poser
  le curseur sur le corps d'un ennemi donne donc la direction qui le touche vraiment.
- ✅ **Projection vérifiée, pas supposée** : aller-retour sur 16 directions
  (direction → `unproject_position` → rayon → plan → direction), écart max **0,0000°**.
- **Il n'y a rien à compenser pour l'étirement `canvas_items`.** `get_mouse_position()`
  rend des coordonnées de viewport et `project_ray_*` les attend : Godot défait le stretch
  des deux côtés. (`unproject_position` est dans le même espace — c'est ce qui rend
  l'aller-retour ci-dessus valable.)
- **Le modèle regarde la VISÉE, pas la marche.** Sinon la griffure partirait de côté
  pendant que le chat regarde ailleurs, et une griffure est un *geste du corps*.
  ⚠️ Contrepartie assumée : le chat peut marcher à reculons et il n'a qu'un `walk` — le
  cycle de pattes se lit alors à l'envers.
- **La souris prend la visée quand elle BOUGE, jamais avant** (`aim_source`, qui démarre
  sur `MOVEMENT`). Sans cette bascule, un curseur posé au hasard au lancement — ou immobile
  dans une capture `--write-movie`, où il ne bougera **jamais** — imposerait un cap au chat
  dès la première frame. Le clavier seul garde donc l'ancien comportement.
- **Toute source qui ne sait pas répondre rend la DERNIÈRE visée, jamais zéro.** Trois cas
  la rendent muette : pas de caméra, rayon parallèle au plan, curseur posé *sur* le chat
  (`aim_dead_zone` 0,8 m — en deçà, la direction bascule d'un cap à l'autre au pixel près).
  Une visée qui s'annulerait ferait pivoter le chat au hasard pendant une frame, **et la
  griffure part sur cette frame-là**.
- **La visée se lit APRÈS `move_and_slide`** : le curseur désigne un point du monde, on
  regarde vers lui depuis la position d'arrivée.
- 🅿️ **La manette viendra s'ajouter dans `aim_source`** — une source de plus, prioritaire
  tant que le stick droit est poussé. À la différence de la souris, elle **rend** la main
  quand le stick revient au centre.

### Les compétences — le socle, posé le 2026-08-17

Les 7 upgrades à plat ont cédé la place au système de `Gameplay et Progression` §2.
**Seul le socle est fait** — types, paliers, slots, tirage pondéré, et les deux armes
existantes ramenées au même contrat. Le contenu (§2.9 chantier 3) et le carton de
remplacement (chantier 2) ne sont **pas** écrits.

| Fichier | Ce qu'il porte |
|---|---|
| `systems/skill_definitions.gd` | **Le catalogue** : type, paliers, poids, slots |
| `systems/skill_set.gd` | **Le build d'une run** : `id → palier`, + l'horloge des compétences |
| `skills/skill.gd` | **Le contrat** : `setup` / `set_tier` / `tick` |

- **Trois types :** `AUTO` (une arme qui agit seule — occupe une slot **et** se dessine),
  `ACTIF` (touche + cooldown — **aucun n'existe encore**), `PASSIF` (un chiffre, jamais
  dessiné — donc illimité en nombre, mais plafonné à **T3** sans ultime).
- **Slots : 6 AUTO · 2 ACTIFS · ∞ passifs.** Quand une famille est pleine, `roll` cesse
  de proposer des compétences **neuves** de ce type et continue d'en proposer les paliers.
  Le carton « quoi remplacer ? » n'existe pas — proposer une 7ᵉ arme serait proposer
  quelque chose que le jeu ne sait pas faire.
- **Tirage pondéré** AUTO ×3 · ACTIF ×2 · PASSIF ×1, sans doublon dans le tirage.
- **Le catalogue actuel — 11 entrées** : `claw` (AUTO dirigé, de départ) · `hairball`
  (AUTO auto-visé) · `breath` (AUTO de zone) · `dust` (AUTO semé) · `bite` (ACTIF) ·
  `hiss` (ACTIF de recul) · `move_speed` · `max_health` · `pickup_radius` · `xp_gain` ·
  `toughness`. Voir « Quatre compétences de plus » plus bas.
- **La carte de choix porte un marqueur de palier** — `NOUVEAU` / `PALIER 2` / `ULTIME`, en
  légende de 10 px au-dessus d'un titre de 17 (le contraste d'échelle de DA §9.3 règle 5,
  pas une nuance de gris de plus). Il reste en crème assourdi **même au survol** : l'ambre
  est l'unique accent saturé de l'écran et il désigne la carte survolée, pas un marqueur
  qui ne désigne rien. ⚠️ Sans lui, reprendre une compétence affiche **exactement la même
  carte** qu'à sa première prise, et rien ne dit au joueur s'il débloque ou s'il renforce.

> ⚠️ **LES VALEURS DE PALIER SONT ABSOLUES, JAMAIS DES INCRÉMENTS**, et c'est le choix qui
> a décidé de toute la forme. L'ancien `apply_upgrade` faisait `claw_damage += 1` : une
> mutation **en place**, donc irréversible. Trois choses de §2 y étaient impossibles —
> remplacer une arme (il faudrait défaire ses paliers), un T4 qui *transforme* (il faudrait
> recalculer, pas empiler), et relire un build sans rejouer son historique. Ici appliquer
> un palier c'est **écrire** des valeurs : le refaire deux fois ne change rien.

> ⚠️ **`damage`, `attack_speed` et `claw_range` ont été SUPPRIMÉS** (décision du
> 2026-08-17). La griffure ayant ses propres paliers, les laisser coexister ferait
> **compter deux fois la même montée** (§2.9). Leur effet est replié dans les T2/T3 de
> `claw` — transcription de l'équilibrage d'avant, pas rééquilibrage. Il ne reste donc que
> **trois passifs**, et ils ont un point commun : ils règlent le **corps** du chat
> (`move_speed`, `max_health`, `pickup_radius`), jamais une arme. C'est la ligne de partage.

> ⚠️ **AUCUNE COMPÉTENCE N'A DE `_process`.** L'horloge vient de `player._process` →
> `skills.tick(delta)` — et le chat étant en `PROCESS_MODE_PAUSABLE`, c'est **le moteur**
> qui arrête les seize horloges d'un coup derrière un carton (voir « La pause »). Chaque
> compétence testait la pause elle-même — `breath_aura.gd` avait son `_get_game()` et son
> `_is_run_paused()` privés. À seize compétences, c'est seize endroits où oublier de
> s'arrêter derrière un carton, et le défaut est **invisible** : une aura qui continue de
> mordre pendant qu'on choisit une upgrade ne se voit pas, elle se constate à la barre de
> vie d'un ennemi.

> ⚠️ **LE POOL PEUT DÉSORMAIS ÊTRE VIDE, et il ne pouvait pas l'être avant.** Les 7
> upgrades se reprenaient à l'infini ; les compétences plafonnent. Trouvé **par la sonde**,
> pas en jouant : un level-up sans carte à proposer ouvrait un carton vide, qui mettait le
> jeu en pause sans rien offrir pour le relancer — plus rien à cliquer, et Échap ne fait
> rien pendant un carton de niveau. Le niveau monte donc, mais aucun carton ne s'ouvre.
> 🅿️ À ~16 compétences, il vaudra mieux rendre autre chose (soin, XP) que rien.

> 🅿️ **`ultimates` est vide partout, et c'est voulu.** Le T4 est du contenu de jeu, il
> n'est écrit nulle part. La structure le porte, `max_tier` le sait, et une compétence sans
> ultime plafonne proprement à T3.

**La sonde de build** — un palier appliqué de travers ne casse rien et ne se signale pas :
le chat frappe simplement un peu moins fort qu'il ne devrait.

```bash
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . \
  --quit-after 5 -- --build-report --skill=claw:3 --breath=3
#   --build-report      paliers + chiffres de corps + relevé d'ATH + 8 tirages
#   --skill=<id>:<n>    n'importe quelle compétence à n'importe quel palier
#   --breath=<n>        gardé tel quel — il sert déjà aux captures
#   --autofire          les 2 slots d'ACTIF partent dès qu'elles sont prêtes
#   --walk              le chat marche en rond tout seul, à vitesse pleine
```

> ⚠️ **`--walk` n'est pas un confort, c'est le pendant exact de `--autofire`.** Dans un
> `--write-movie` **aucune touche n'est pressée** : le chat reste planté, poussé seulement
> par les ennemis qui le bousculent. Toute compétence dont l'effet dépend du **déplacement**
> est donc strictement incapturable — les moutons de poussière sont le cas qui l'a imposé,
> puisqu'ils ne tombent qu'à `MIN_SPACING` d'écart. Sans lui on aurait jugé l'arme sur une
> seule touffe posée sous le chat.
>
> Un **cercle** et non une ligne : il repasse dans le cadre, fait varier la direction sur
> 360° (donc le cycle de pattes et l'orientation du modèle) et ne finit pas dans un mur.
> ⚠️ Il pilote **l'entrée**, pas la position : poser `global_position` court-circuiterait
> `move_and_slide`, donc les collisions, le clamp d'arène et la bascule idle/walk — et la
> capture montrerait un chat qui glisse.

> ⚠️ **`--autofire` n'est pas un confort.** Une compétence active attend un clic, et dans
> un `--write-movie` **la souris ne clique jamais** : sans lui, la première compétence
> active du jeu serait strictement incapturable, donc jugée sans avoir été vue.

### Quatre compétences de plus — le 1ᵉʳ lot de contenu (2026-08-17)

Le catalogue passe de **7 à 11 entrées**. C'est le chantier 3 de `Gameplay et Progression`
§2.9, dont l'objet n'est pas d'ajouter des chiffres mais de faire exister des **builds**.

| id | Type | Ce qu'elle apporte que rien d'autre n'apportait |
|---|---|---|
| `hiss` — **Feulement** | ACTIF | du **recul**. La 1ʳᵉ compétence dont la valeur ne se compte pas en dégâts |
| `dust` — **Moutons de poussière** | AUTO | récompense de **bouger** — l'exact inverse de l'haleine |
| `xp_gain` — **Gourmandise** | PASSIF | agit sur la **courbe**, pas sur le combat |
| `toughness` — **Pelage épais** | PASSIF | la 1ʳᵉ **synergie** : il multiplie `max_health` au lieu de s'y ajouter |

- ⚠️ **Le feulement rend de la PLACE, pas de la puissance.** Le chat avait déjà quatre
  façons de tuer et **aucune** de sortir d'un encerclement : la seule réponse était de
  courir, et courir ne repousse rien. Ses dégâts sont dérisoires **exprès** — lui en donner
  autant qu'à la morsure en aurait fait une morsure de zone, et le chat aurait eu deux
  boutons pour le même problème. Sa recharge est **la plus longue du jeu** (11 s) : une
  sortie de secours qui revient vite n'est plus une décision, c'est une touche à marteler.
- ⚠️ **Le front est l'AGENT, pas un commentaire.** L'onde pousse les ennemis **à mesure
  qu'elle les atteint**, pose par pose. Une poussée instantanée sur tout le rayon aurait
  projeté un ennemi du bord avant que le dessin ne soit arrivé sur lui — le défaut exact de
  la morsure qui cherchait sa cible au claquement.
  ✅ **Mesuré, pas supposé** : trois ennemis collés au chat (0,01 · 0,03 · 0,05 m) sont à
  **3,65 m** 0,45 s plus tard, soit **+3,63 m** — la valeur que la conception annonçait.
- **Les moutons donnent au jeu son 2ᵉ comportement récompensé.** Tant que l'haleine était
  seule à demander quelque chose au placement, « bien jouer » restait **un** comportement.
  Deux armes qui demandent l'inverse l'une de l'autre, c'est le début d'un build.
- **Une touffe = un coup, puis elle n'est plus là.** Pas de zone qui grignote : §2.10 veut
  qu'un effet continu **batte**, et une touffe consommée d'un coup est le battement le plus
  lisible qui soit — elle disparaît. Dix zones qui grignotent seraient dix décomptes à
  suivre, et §2.3 prévient que la lisibilité est le premier mur.
- ⚠️ **`life / interval` décide du nombre de touffes à l'écran**, pas de la feuille de
  dégâts. Au T3 le rapport donne douze, plafonné à **dix** (`dust_skill.MAX_BUNNIES`).
  Baisser `interval` sans baisser `life` remplit le sol.
- **`xp_gain` se multiplie à la SOURCE**, jamais sur le seuil de niveau. Le seuil grandit
  de 35 % par niveau : un rabais dessus vaudrait de plus en plus cher à mesure que la run
  avance, un multiplicateur à la source vaut le même facteur du début à la fin.
- **`toughness` est une FRACTION, jamais un forfait.** Un « −5 par coup » rendrait le chat
  invulnérable en début de run et inutile à la fin, quand le chaser tape à 21 — c'est
  exactement l'argument qui avait fait passer la vie à 100 points.

> ⚠️ **LES SLOTS ACTIVES SONT PLEINES À DEUX**, et c'est ce que ce lot débloque vraiment.
> Avec `bite` + `hiss`, la famille ACTIF est **saturée** : `roll` cesse de proposer des
> actifs neufs. Le chantier 2 (le carton « quoi remplacer ? ») devient donc **atteignable
> en jeu** — il ne l'était pas avec un seul actif. ⚠️ Mais pour l'**exercer** il faudra un
> **3ᵉ** actif à proposer en remplacement : tant qu'il n'y en a que deux, `roll` n'a rien à
> offrir et le carton ne s'ouvrira jamais.

> 🔍 **Trois défauts, tous trouvés en CAPTURE, aucun en lisant le code :**
> - **`vertex()` oublié dans les deux shaders.** Un `QuadMesh` fait **1 × 1** : sans
>   `VERTEX.xy *= size`, le décalque garde un mètre de côté quel que soit `size`. L'anneau
>   du feulement — dont le rayon vaut une unité de quad — sortait en **quatre croissants**
>   tangents aux bords, entièrement mangés par l'encre. Ni erreur, ni avertissement : juste
>   un dessin qui n'a plus rien à voir avec sa portée.
> - **`band` est bornée par `front`.** L'épaisseur se prend des **deux** côtés du front :
>   dès que `band > front`, le bord intérieur passe sous zéro et l'anneau devient un
>   **disque plein**. Les deux premières poses sortaient en assiette crème posée sous le
>   chat. Règle : `band ≤ front × 0,35`.
> - **L'accent du mouton sortait en dégradé d'aérographe** — la seule zone lissée de toute
>   l'image. Les deux seuils étaient des rampes larges (0,24 et 0,67) ; ils sont désormais
>   francs à un pixel près. **Un cluster 2 tons se lit à son BORD** (§2bis) : étalé, il n'y
>   a plus deux tons, il y en a cent.

> ⚠️ **Le recul REMPLACE la poursuite, il ne s'y ajoute pas.** Additionnée, une poussée de
> 15 m/s contre une course de 3,7 donne 11,3 — le joueur ne verrait pas un recul, il verrait
> un ennemi qui rame. Remplacée, l'ennemi part en arrière pour de bon **puis** reprend sa
> marche : deux états nets plutôt qu'un mélange, ce qui est la règle des poses tenues de §7
> appliquée au déplacement.

> 🅿️ **Effet de bord connu :** au T3 le feulement fait 3 dégâts, soit exactement la vie
> d'un chaser de départ — il en tue donc en début de run, alors que sa fiche dit « ça ne
> tue pas ». Ça se corrige tout seul dès que la difficulté monte ; à revoir seulement si un
> jour on peut avoir un T3 très tôt.

### Les contrôles — WASD + les deux clics (2026-08-17)

Premier changement de contrôles du projet. `tools/setup_input_map.gd` pose la carte
d'entrées, et il est **rejouable** : une carte d'entrées est un geste de conception, pas
un binaire tombé du ciel.

| Action | Touche |
|---|---|
| Déplacement | **W A S D** (+ flèches en second) |
| Visée | souris |
| ACTIF slot 1 | **clic gauche** |
| ACTIF slot 2 | **clic droit** |
| Réglages | Échap |

- **Les touches sont posées en code PHYSIQUE**, pas logique. Godot les résout par leur
  **position** : sur l'AZERTY de ce projet, les mêmes trois touches sous les doigts
  s'appellent Z, Q, S, D et marchent sans qu'on déclare quoi que ce soit. Un `keycode`
  logique aurait demandé deux cartes.
- **`move_*` remplace `ui_*` dans `player.gd`.** Garder `ui_*` laissait aussi `ui_accept`
  (Espace) activer les boutons de l'UI dans le dos du jeu.

> ⚠️ **LE CLIC GAUCHE EST PARTAGÉ avec les boutons de l'interface** — cartes d'upgrade,
> RELANCER, pastilles de langue. Le déclenchement des actifs est donc dans
> **`_unhandled_input`**, jamais en sondage de `Input` : un Control en `MOUSE_FILTER_STOP`
> (les cartons) **consomme** l'événement, et l'actif ne le voit jamais. Godot règle le
> partage, pas une condition qu'on aurait pu oublier.
>
> Une première version sondait `Input` dans `_process`. Elle aurait lu le même clic
> **deux fois** : choisir une amélioration aurait dépensé la morsure dans la foulée, sur
> la frame où la run reprend et où la garde de pause ne protège plus. **6 s de cooldown
> perdues à chaque level-up, sans que rien ne le signale.**
>
> ⚠️ Le HUD permanent, lui, ne consomme rien (racine et labels en `MOUSE_FILTER_IGNORE`) :
> un actif part même quand le curseur survole l'ATH — c'est-à-dire précisément quand on
> regarde ses pastilles de cooldown.

### Les ACTIFS — la décision d'instant (2026-08-17)

Le troisième type existe enfin. C'est le seul qui ajoute une **décision** à la boucle
moment-to-moment : le placement et la visée sont continus, un actif est ponctuel.

- **`active_skill.gd` porte le cooldown**, pas chaque compétence. Six décomptes séparés,
  ce sont six façons pour une pastille de mentir sur ce qui est prêt.
- **Le cooldown est une valeur de palier** comme le reste — absolue, donc rien à soustraire.
- **Chaque actif porte une ONOMATOPÉE** — voir « Les onomatopées » plus bas. C'est le
  socle qui la déclenche, pas chaque compétence, et elle est réservée aux actifs.
- **Deux pastilles au HUD, en bas à droite**, et **aucune** tant que le chat n'a pas de
  compétence active : une pastille éteinte annoncerait une touche qui ne fait rien.
  Elles se remplissent **en 5 crans**, jamais en continu — un remplissage lisse serait le
  seul élément lisse de l'image. Le filet passe à l'**ambre** à pleine charge : l'accent
  désigne ce sur quoi le joueur peut agir, comme le survol d'une carte.
- ⚠️ **C'est le HUD qui quantifie, pas le jeu.** `main` pousse une valeur continue à chaque
  frame ; le découpage en pas est une décision de **dessin**.

### La morsure — le 1ᵉʳ ACTIF, et la boule de poils

| | Morsure (ACTIF) | Boule de poils (AUTO) |
|---|---|---|
| Déclenchement | **clic gauche** | cadence automatique |
| Visée | le joueur | **automatique, plus proche** |
| Cibles | **une seule** | une seule |
| Arc | **70°** frontal | — |
| Portée T1→T3 | 3,6 / 4,0 / 4,4 m | 11 / 13 / 15 m |
| Dégâts T1→T3 | **7 / 10 / 14** | 2 / 3 / 4 |
| Recharge | 6 / 5 / 4,2 s | 1,6 / 1,35 / 1,1 s |

- **La morsure porte MOINS LOIN que la griffure** (5,2 m) et frappe deux fois plus fort :
  un croc se paye en distance, pas seulement en cooldown. L'ordre tient à **tous** les
  paliers — morsure T3 (4,4 m) sous griffure T1 (5,2 m). 7 dégâts au T1 = exactement la
  vie d'une brute de départ, donc un effet lisible dès la première prise.
- **La cible est fixée au déclenchement, pas au claquement.** Quatre crans passent entre
  les deux (~133 ms) : la chercher au claquement ferait mordre un ennemi que le joueur ne
  visait pas. Une morsure doit toucher ce qu'elle **montre**.
- **La boule de poils réveille le projectile**, en sommeil depuis la griffure, et rouvre la
  fantasy « chat sniper » que le manifeste §11 notait sans support. Coût proche de zéro :
  scène, script et `spawn_projectile` étaient restés entiers.
- **Elle ne se vise PAS**, délibérément : la slot n°1 est réservée à l'arme dirigée, et
  deux armes qui obéissent au même curseur ne font qu'une arme.

> ⚠️ **Quatre défauts du dessin de la morsure, tous trouvés en AGRANDISSANT les frames —
> aucun visible à taille de jeu, aucun en lisant le code :**
> - **Les mâchoires n'avaient pas de masse.** À `thick` 0,07 elles sortaient en traits de
>   1 à 2 px et se lisaient comme un **coup de ciseaux**. Une mâchoire est une masse ;
>   c'est son épaisseur qui la sépare d'une griffure, pas sa courbure. Doublée.
> - **Le cluster 2 tons n'existait que dans le fichier.** À `core_w` = ink + 0,26 × thick,
>   le crème n'apparaissait **pas une seule frame** — l'encre et le brun se rejoignaient.
>   Passé à 0,40.
> - **La gueule avalait le chat.** `jaw_offset` (0,30) était plus petit que la demi-ouverture :
>   la mâchoire supérieure passait derrière le centre du chat. ⚠️ Et le décalage est
>   **plafonné par le quad** — `jaw_offset + gape + thick` doit rester sous 1,0, sinon le
>   haut est tranché net par le bord du décalque.
> - **Les dents sortaient en dents de scie.** `abs(sin)` a un point de rebroussement à
>   chaque zéro — un V, donc un angle vif, ce que §3 interdit. Remplacé par `sin²`, lisse
>   partout : les creux deviennent des vallées, les dents des bosses.
>
> 🔍 **La leçon commune :** à taille de jeu, la morsure et la griffure se ressemblaient
> assez pour qu'on les croie correctes toutes les deux. **Un FX se règle en agrandissant
> la frame, pas en la regardant.**

> ⚠️ **Puis elle était TROP PETITE et TROP BRÈVE** (retour direct, 2026-08-17). Deux
> problèmes distincts, deux leviers distincts, et les fausses pistes valent d'être gardées :
>
> **La taille — elle ne pouvait PAS grandir vers l'avant.** Le décalque est pris en
> tenaille : le bord du quad d'un côté, le chat de l'autre. Agrandir `DRAW_SIZE` seul a
> aussitôt fait **rentrer le chat dans la gueule** ; reculer l'ouverture pour l'en sortir
> l'a rendue **plate**. La sortie était de grandir **en largeur** — rien ne l'y borne que
> la portée qu'elle promet. L'arc de dégâts a donc été **ouvert de 70° à 90°** dans le même
> mouvement, pour que la corde du dessin (3,74 m) soit exactement celle de l'arc à sa
> portée. *C'est le dessin qui a fait bouger l'équilibrage, pas l'inverse.*
>
> ⚠️ **Et le dégagement se calcule À L'ÉCRAN, pas au sol.** Le décalque est un billboard :
> son décalage vers l'avant vit dans le plan de l'image, où le chat occupe ~0,5 m de rayon.
> Raisonner en mètres de terrain — l'erreur de la deuxième tentative — donne un chiffre
> plausible et faux. D'où l'encadrement qui fixe désormais toutes les poses :
> `0,19 ≤ jaw_offset ± (gape + thick) ≤ 0,98`.
>
> **La durée — deux leviers étaient interdits, le troisième était dans §7 depuis le début.**
> Ralentir la cadence est exclu (§8 : les FX doivent être *plus rapides* que les
> personnages) ; ajouter des poses plafonne à 8, et on y était. La réponse est que **chaque
> pose a sa propre durée** : §7 demande *« des poses tenues coupées par des transitions
> rapides »*, et une cadence uniforme est un métronome, pas de l'animation posée. Le
> claquement tient **4 crans** contre 1 pour l'ouverture — le geste passe de 267 à
> **500 ms** sans qu'une pose s'ajoute ni que la cadence de base bouge.
> ✅ Mesuré sur les frames : visible 30 frames à 60 fps, avec un plateau plat au milieu.
> ⚠️ `MARGIN` n'est rendue qu'**une** fois par pose, pas une par cran — c'est une tolérance
> de seuil, pas une durée.

### La morsure refaite — une vraie gueule de chat (2026-08-17)

Le dessin ne convenait toujours pas. Il est repris en entier : **plus de portée**, un geste
**deux fois plus long**, des **dents de chat** et un **rouge** à la place du brun. Le
squelette du shader (billboard dirigé, SDF, cluster 2 tons + encre) n'a pas bougé.

| | Avant | Après |
|---|---|---|
| Portée T1→T3 | 2,6 / 2,9 / 3,2 m | **3,6 / 4,0 / 4,4 m** |
| Arc | 90° | **70°** |
| Durée du geste | ~500 ms | **867 ms**, mesurées |
| Dents | feston creusé dans le bord | **crocs unis à la gencive** |
| Cluster 2 tons | brun + éclat crème | **gencive rouge + émail crème** |

- ⚠️ **LES DEUX TONS SONT DEVENUS DEUX MATIÈRES.** Avant, le crème était un reflet posé au
  milieu d'une mâchoire brune — il ne désignait rien. Maintenant c'est la gencive contre
  l'émail : le 2ᵉ ton n'est plus un ornement, c'est la forme qui se sépare. §2bis est tenu,
  et pour une raison.
- **Les dents sont de la FORME, plus un creux.** La denture en feston (`sin²` sur le bord
  intérieur) ne se lisait pas à taille de jeu : on voyait deux bandes qui se rapprochaient.
  Les crocs sont maintenant des cônes **unis** à l'arc (`min` de deux champs), la rangée du
  bas décalée d'une **demi-dent** pour qu'elle **s'engrène** au lieu de se cogner bout à
  bout. Le zigzag de la gueule fermée est ce qui dit « morsure ».
- **UNE DENTURE DE CHAT : deux grandes canines, de petites dents entre elles.** Une rangée
  régulière est une **scie**, quelle que soit la forme de chaque dent prise à part — ce qui
  fait lire « chat » est le **contraste d'échelle dans la rangée**, exactement le geste que
  §9.3 applique au texte des cartons. Les dents restent sur une grille régulière : chez un
  chat aussi, ce qui varie d'une dent à l'autre est la taille, pas l'écartement.
- **La canine est repérée par un RANG, pas par une position.** Exprimée en fraction de
  corde, elle tombait entre deux dents dès qu'on changeait leur nombre : deux dents à demi
  grandies au lieu d'un croc. ⚠️ Et le **décalage d'une demi-dent déplace aussi la canine
  du bas** — reprendre la position du haut telle quelle donnait deux demi-canines en bas.
- **Le rouge est assumé même s'il ressemble à l'éclat de collision.** L'argument d'origine
  (« le terracotta est à deux points du rose de hit feedback ») reste vrai ; ce qui a
  tranché est que le brun était la couleur du **décor** (parquet, encre, bois), et qu'une
  gueule ne peut pas être de la même famille que le sol sur lequel elle se peint. ✅ L'éclat
  a été retravaillé le 2026-08-17. Le trait a suivi (`#3D2B1A` → `#3A1410`) : un aplat qui change
  de teinte force son encre à se teinter vers lui, sinon le trait cesse d'appartenir à
  l'objet — la règle déjà payée sur le chat tuxedo.
- **L'arc est revenu à 70°, et c'est encore le dessin qui décide.** Le 90° avait été ouvert
  la veille pour donner de la place à un dessin qui ne tenait pas, la largeur étant alors
  la seule dimension libre. Les dents ayant repris ce travail **vers l'intérieur**, l'arc
  peut revenir à ce que la compétence voulait dire — *un croc pique, il ne balaie pas*.

> ⚠️ **Ce que la portée coûte, et qui n'est pas un détail :** la marge au-dessus de la
> distance de contact ennemi (~1,55 m) passe de **1,05 m à 2,05 m**. Mordre reste plus
> risqué que griffer, nettement moins qu'avant. C'est le **dessin** qui l'a demandé — la
> gueule se dimensionne sur la portée, et à 2,6 m elle était trop petite pour y lire des
> dents. Agrandir le dessin seul aurait promis une portée inexistante.

> 🔍 **Trois défauts, tous trouvés en AGRANDISSANT les frames, aucun en lisant le code — et
> les trois disent la même chose : ce qui casse un croc n'est pas sa pointe.**
> - **Les crocs sortaient en CLOUS.** Le trajet d'une dent commence *dans* la gencive, où
>   son champ est le plus large et où la boîte qui le borne se termine **à plat**. La
>   silhouette n'en montrait rien — l'union avec la gencive la recouvre — mais **l'émail se
>   peignait dessus** : tête plate et large, puis tige fine. L'émail est donc borné à la
>   partie **émergée**. Ce n'est pas un correctif de dessin, c'est ce que fait une dent.
> - **Les dents sortaient en DENTS DE SCIE.** Non par leur pointe, mais par leur **base** :
>   à 0,34 d'écartement elles faisaient 0,164 de large pour 0,175 de long — des triangles
>   quasi équilatéraux, donc une gueule de requin. Un croc se reconnaît à son élancement,
>   il lui faut au moins 1,7 fois plus long que large.
> - **Le nombre de dents est borné par le TRAIT.** À six par mâchoire, l'écart entre une
>   dent du haut et sa voisine du bas tombait sous *deux fois* l'épaisseur du cerne pendant
>   l'engrenement : les deux traits se rejoignaient, le rouge disparaissait, la denture
>   sortait en **treillis sombre**. Même borne que sur le petit texte de l'ATH (§9) — un
>   cerne se dose sur ce qu'il cerne, jamais en valeur partagée.
>
> ⚠️ **Et `thick` a dû MAIGRIR pour que les dents grandissent.** Gencive et crocs se
> disputent la même borne (`gape + thick ≤ 0,395`, et la pointe doit atteindre la médiane) :
> une gencive épaisse mange l'ouverture, donc raccourcit les dents, donc les rend trapues.
> C'est ainsi que la première capture avait sorti des dents de scie.

> ✅ **L'éclat de collision a été refait le 2026-08-17** — la condition posée en acceptant
> que la morsure prenne le rouge est levée. Voir « L'éclat refait » plus bas. Les deux
> rouges se distinguent toujours : la gueule est un `#C4382E` de gencive, l'éclat le
> rose-rouge `#D45870` que §4 range en *hit feedback*.

**Passe de réglage, même jour :** gencives **plus fines** (0,095 → **0,075** au claquement)
et canines **plus longues** (+16 %). ⚠️ La pointe de la canine, elle, **n'a pas bougé** :
elle croise toujours la médiane de 0,023. Ce que le croc gagne, il le gagne du côté de la
**racine**, la gencive ayant reculé — c'est ce qui permet d'allonger les crocs sans jamais
toucher à l'engrenement, le seul chiffre que le geste doit tenir. Et `incisor_len` est
descendu de 0,42 à 0,36 dans le même mouvement : **le rapport et la longueur se règlent
ensemble**, sinon allonger les canines allonge aussi les incisives et la denture reste la
même, juste plus grande.

### Les onomatopées — le bruit des ACTIFS, écrit dans l'image (2026-08-17)

Chaque compétence **active** porte une onomatopée : le bruit du coup en grosses lettres
posées dans le cadre, à la manière de l'anime TV 80–90 et du manga. **`CHOMP`** pour la
morsure. `scripts/systems/shout_fx.gd` + la clé `skill.<id>.shout` dans `locale.gd`.

- ⚠️ **C'est le socle qui le porte** (`active_skill.shout()`), pas la morsure. Toute
  compétence active à venir criera sans avoir une ligne à écrire pour ça, et la clé se
  déduit de l'`id` — rien à tenir synchronisé à la main, comme les titres et descriptions.
- ⚠️ **RÉSERVÉE AUX ACTIFS, jamais aux AUTO.** Un actif est le seul type qui soit une
  décision d'**instant** (§2.4), et l'onomatopée est ce qui rend cet instant lisible. Six
  armes automatiques qui crient à leur propre cadence rempliraient l'écran de texte en
  permanence, et le mot cesserait d'annoncer quoi que ce soit. Même partage que les
  pastilles de cooldown du HUD.
- ⚠️ **Elle N'EST PAS appelée par `trigger()`, et c'est le seul travail que ce socle laisse
  à la sous-classe.** *« Quand le coup part »* et *« quand le coup fait du bruit »* ne sont
  pas le même instant : la morsure claque **4 crans après le clic**, et un CHOMP sur des
  mâchoires encore grandes ouvertes est un contresens qu'aucun réglage ne rattrape. Le
  socle ne peut pas deviner ce moment — il appartient au geste.
- **Le mot part même quand la morsure mord dans le vide** : le bruit dit que la compétence
  est **partie**, pas qu'elle a touché. Six secondes de recharge gaspillées doivent se voir
  aussi clairement qu'une brute croquée.
- **C'est un `Label3D` billboard planté dans le MONDE**, pas un `Control` en `CanvasLayer` :
  il passe donc **sous `RetroPost`** et reçoit le grain (§8bis) — même
  argument que le HUD (layer −2) et l'impact frame (−1). Au-dessus, il se lirait comme un
  calque d'UI collé sur le film.
- **Il prend la police et les couleurs de `ui_style`** sans être de l'interface : `ui_style`
  est la source unique du crème et de l'encre du projet, et en fabriquer un second jeu pour
  l'onomatopée serait fabriquer exactement la divergence de constantes que ce projet passe
  son temps à réparer.
- **Inclinaison et dérive tirées au hasard** à chaque cri, comme le `seed` des shaders :
  posée d'aplomb, une onomatopée redevient un sous-titre, et deux CHOMP de suite ne doivent
  pas être le même tampon.
- **6 poses, ~440 ms**, calées pour tenir **sous** le geste qui l'a déclenchée (867 ms) : le
  bruit finit avant le mouvement, jamais l'inverse. Elle arrive **trop grande** (×1,42),
  rebondit sous sa taille, revient — le squash/stretch de §7 appliqué à un mot. ⚠️ Elle
  grandit depuis son **pied** : centrée, la pose de dépassement lui ferait écraser le chat.

> ⚠️ **Elle est dans `locale.gd` bien que « CHOMP » s'écrive pareil dans les deux langues.**
> Une onomatopée est un **son transcrit**, et sa transcription change d'une langue à
> l'autre — le chat français fait *miaou*, l'anglais *meow*. Le jour où l'une divergera, la
> place existe déjà ; l'écrire en dur aujourd'hui, c'est garantir qu'on ne la retrouvera pas.

> ⚠️ **Trop petite à la première capture, et l'erreur était de raisonner en unités d'UI.**
> À 0,52 m le mot faisait ~21 px de capitale, soit exactement le corps d'un **titre de
> carte** (§9.3) — donc la taille d'un élément d'interface. Une onomatopée n'est pas une
> légende, c'est un **événement** : au manga elle occupe une part du cadre. À 0,80 m elle
> pèse autant que la tête du chat, ce qui est le rapport de la référence.

> **Elle recouvre parfois la gueule, et c'est voulu.** Au manga l'onomatopée se peint
> **par-dessus** l'action — c'est précisément à ça que sert son gros cerne d'encre. Ne pas
> aller lui chercher un placement qui évite le décalque : ce serait de la complexité pour un
> non-problème, et le mot cesserait d'être dans l'image.

> ⚠️ **Ne pas confondre morsure et BOND.** Le bond a d'abord été écrit comme attaque
> (dash + traînée de lignes de vitesse), puis **retiré le 2026-08-17** : il sera un
> **déplacement vertical**, pas une attaque. `shaders/pounce_trail.gdshader` et son script
> ont été supprimés — ne pas les reprendre pour une arme.

### XP (xp_orb.gd)
- Magnétisme déclenché à < 5 m du joueur
- Vitesse d'attraction proportionnelle à la proximité

### Interpolation physique
`common/physics_interpolation=true` dans `project.godot`. Deux conséquences à ne pas
reperdre :
- ce qui bouge doit bouger **dans `_physics_process`** — projectiles et croquettes ont été
  déplacés de `_process` pour cette raison ;
- après avoir placé un nœud fraîchement instancié, appeler **`reset_physics_interpolation()`**,
  sinon il part en traînée depuis l'origine du monde sur sa première frame.

Le rig de caméra fait exception : il bouge dans `_process`, donc son interpolation est
**désactivée** et il lit la position du joueur via `get_global_transform_interpolated()`.

### La pause — celle du moteur (2026-08-18, P1 de la revue de code)

Treize scripts portaient la même paire de méthodes privées (`_get_game()` +
`_is_run_paused()`) recopiée à l'identique, et `main.gd` un `run_paused` maison. Tout est
remplacé par **`get_tree().paused`**, ce que la doc Godot fournit et documente
(*Scripting / Pausing games and process mode*).

**Le réglage est dans `main.tscn`, plus dans le code :**

| Node | `process_mode` | Pourquoi |
|---|---|---|
| `Main` | **ALWAYS** | Échap et les cartons doivent survivre à la pause |
| `Arena` · `Enemies` · `Projectiles` · `Pickups` · `Fx` · `Player` · `CameraRig` · `ImpactFrame` | **PAUSABLE** | c'est le monde |
| `HudLayer` · `RetroPost` · `WorldEnvironment` | *Inherit* | héritent d'ALWAYS ; l'UI doit vivre, les deux autres ne calculent rien |

> ⚠️ **UN `process_mode` EXPLICITE SE PROPAGE AUX ENFANTS EN *INHERIT*.** C'est pour ça
> que le monde doit être marqué à la main : `Main` étant ALWAYS, tout ce qui est en
> *Inherit* sous lui l'est aussi. **Ajouter un nœud de gameplay sous `Main` sans lui poser
> `process_mode = 1`, c'est le faire tourner derrière les cartons** — ni erreur, ni
> avertissement, ni rien à l'écran. C'est exactement le défaut que P1 corrige, et le seul
> chemin par lequel il peut revenir.

- **Le bug que les gardes recopiées laissaient passer :** `claw_slash._process` n'en avait
  aucune (`_physics_process` si). Une griffure en cours quand le carton s'ouvrait défilait
  ses six poses derrière le panneau, se libérait ~200 ms plus tard et **ne distribuait
  aucun dégât** — sa fenêtre active était sautée. `hit_burst` avait le même trou.
- ⚠️ **`reload_current_scene()` NE LÈVE PAS LA PAUSE** — `paused` appartient au `SceneTree`,
  pas à la scène. Or son seul appelant est RELANCER, sur le carton de K.O., le seul écran
  où le jeu est en pause : la run repartait figée, sans rien à cliquer.
  `_on_restart_button_pressed` la lève avant de recharger.
- **Le chat se fige au lieu de repasser en `idle`.** Godot met l'`AnimationPlayer` en pause
  avec le nœud. La pause lit désormais comme un arrêt sur image, ennemis et FX compris.
- **Ce qui vit pendant la pause :** le carton s'ouvre en 4 poses grâce au
  `create_timer(FX_POSE, true, false, true)` de `hud._open_card` — le drapeau
  `process_always`, qui était déjà là.

**Un `process_mode` oublié ne se voit nulle part** — d'où un banc, `pause_probe`, qui
mesure les deux sens :

```bash
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . \
  res://scenes/tests/pause_probe.tscn
#   18 verdicts. Le monde se FIGE (temps, chat, ennemis, poses d'une griffure en vol)
#   et l'interface VIT (le carton s'ouvre, Échap est recu PENDANT la pause).
```

### Qui connaît qui — on injecte, on ne cherche pas (2026-08-18, P3 de la revue)

Le jeu n'a délibérément aucun autoload, mais six nœuds appelaient
`get_first_node_in_group("game_root")` — ce qui rétablit tous les inconvénients d'une
globale sans aucun de ses avantages : répété à chaque frame, non typé, déclaré nulle part.
**Les groupes `game_root` et `player` n'existent plus.** `main` est le seul nœud qui
connaisse tout le monde, donc c'est lui qui **distribue** ce qu'il sait.

| Ce qu'on cherchait | Par où ça passe désormais |
|---|---|
| le jeu, depuis le chat et la caméra | `player.setup(self)` · `camera_rig.setup(self)` dans `main._ready()` |
| le chat, depuis une croquette | `orb.setup(player, xp_value)` à la ponte |
| le jeu, depuis une compétence | **`player.game`** — `Skill.game()` et `Skill.enemies()` |
| le conteneur de FX (`$Fx`) | **`GameRoot.add_fx(node, position)`** |
| tous les ennemis | **`GameRoot.enemies() -> Array[Enemy]`** |

- ⚠️ **`main.setup()` PASSE APRÈS LE `_ready()` DES ENFANTS.** Godot appelle `_ready` de
  bas en haut : `player.game` est **`null` pendant tout le `_ready` du chat**. Aucun usage
  actuel n'en a besoin avant sa première frame — mais une nouveauté qui lirait `game` dans
  un `_ready` trouverait `null`, et rien ne le signalerait. C'est le seul piège que la
  passe introduit ; il est écrit dans les trois fichiers concernés.
- ⚠️ **Le conteneur de FX est redevenu privé (`_fx_container`), et c'est le point.**
  `dust_skill` faisait `game.fx_container.add_child(bunny)` : une compétence atteignait un
  **nœud enfant** d'un autre script en le nommant — renommer `$Fx` dans `main.tscn` cassait
  une arme, en silence. `add_fx()` porte aussi le `reset_physics_interpolation()`, qui était
  recopié à chaque site de ponte et dont l'oubli ne lève pas : il fait juste partir le FX en
  traînée depuis l'origine du monde, sur sa première frame — soit souvent un quart de sa vie.
- ⚠️ **Le groupe `enemies`, lui, RESTE, et ce n'est pas une exception concédée.** Un
  singleton déguisé et un **ensemble** ne sont pas la même chose : « le directeur de jeu »
  est un objet unique qu'on peut injecter, « tous les ennemis vivants » est une population
  qui change à chaque vague — le groupe est l'outil que la doc prévoit pour ça. Ce qui a
  changé, c'est qu'il n'a plus **qu'un seul lecteur** (`GameRoot.enemies()`) au lieu de six,
  et que ce lecteur rend un tableau **typé**. Les six boucles ont perdu leur préambule
  identique — recherche de groupe, `as Enemy`, `is_instance_valid`. Six copies d'un
  préambule, c'est six endroits où en oublier un morceau, **et l'oubli ne lève pas** : il
  rend une liste un peu plus courte que la vérité, donc une arme qui rate silencieusement.

> ⚠️ **Vérifier cette passe demande `--walk` ET `--autofire`.** Sans eux, un run de capture
> laisse le chat planté et muet : `dust_skill._drop()` n'atteint jamais son `MIN_SPACING`,
> donc `add_fx()` — le site le plus couplé du dépôt — **n'est pas exécuté une seule fois**,
> et la vérification passe au vert sans avoir rien vérifié.
>
> ```bash
> "C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . \
>   --fixed-fps 60 --quit-after 900 -- --skill=dust:3 --skill=hairball:3 --breath=3 \
>   --autofire --walk
> ```

---

## Règles de développement

> Tiré de `03 - Production/Contexte IA.md` dans le vault — ces règles priment sur les instincts par défaut.

- **Fournir des scripts complets** lors de modifications, jamais des extraits partiels.
- **Ne pas complexifier** — architecture simple et modulaire, pas d'abstractions spéculatives.
- **Lire ce que dit la doc Godot avant de coder** — le manuel est en local, dans
  `05 - Godot Docs/` du vault (voir « Le manuel Godot, en local »). Sur une API, un cycle de
  vie de nœud, une question de perf ou un choix de nœud, on **vérifie au lieu de supposer** ;
  et quand le manuel recommande une façon de faire, c'est elle qu'on suit — les pièges de ce
  projet montrent assez ce que coûte un comportement du moteur découvert après coup.
- **Respecter l'arborescence** : `scenes/`, `scripts/`, `assets/`.
- **Tout script de NŒUD porte un `class_name`, et on s'en sert** (depuis le 2026-08-18 —
  P2 de la revue de code). Il y en a 21 : `Player`, `Enemy`, `GameRoot`, `Skill`,
  `ActiveSkill`, `SkillSet`, `DrivenFx`, `Arena`, `CameraRig`, `Hud`, `CelModel`… Un nœud
  qu'on récupère se **type** (`area.get_parent() as Player`, `child is DrivenFx`) — plus
  jamais un `has_method("…")`, qui ne vérifie pas l'arité et laisse l'erreur tomber en
  pleine frame de jeu.
  ⚠️ **Deux exceptions, toutes deux voulues :** les **fabriques statiques** (`Locale`,
  `UiStyle`, `CelStyle`, `SkillDefinitions`, `FxCadence`, `SettingsStore`, `CelProp`,
  `SkillThumb`) restent des `RefCounted` préchargés en `const` — un `class_name` en ferait
  des noms globaux, soit l'accès de partout que ce projet refuse aux autoloads ; et les
  deux `Variant` de `cel_model._keep_only_real_poses`, où la clé d'animation vaut
  `Vector3` ou `Quaternion` selon la piste.
  ⚠️ Poser un `class_name` **oblige à supprimer le `const … := preload(…)` du même nom**,
  et il faut relancer `--headless --import` pour que le cache de classes globales le voie
  — sans quoi tous les fichiers sortent en « Could not find type », ce qui ressemble à
  une dépendance cyclique et n'en est pas.
- **Langue UI : français ET anglais depuis le 2026-08-17.** Le français reste la langue
  d'écriture — on rédige en français, on traduit ensuite. ⚠️ **Aucun texte affichable ne
  s'écrit en dur** : tout passe par `scripts/systems/locale.gd`, avec les deux langues
  côte à côte sous la même clé.
- **Pas de dépendances externes** sans demande explicite.
- **Itérations rapides et testables** — les changements doivent être vérifiables immédiatement dans Godot.
- **Nord étoile :** *"Rendre le jeu plus fun, plus mignon, sans complexifier."*

---

## Conventions d'assets

- **Modèles 3D :** `assets/models/{catégorie}_{nom}.glb` ex. `player_cat.glb`
- **Catégories valides :** `player`, `enemy`, `xp`, `projectile`, `boss`, `pickup`, `ui`, `fx`,
  `prop` *(ajoutée le 2026-08-16 avec le canapé — le mobilier n'entrait dans aucune)*
- **Travail en cours :** hors dépôt, dans `C:\Users\tibo\Documents\zeucozy_3d\` (`.blend` versionnés `_v01`, `_v02`…)
- Seuls les **exports validés** entrent dans `assets/models/`.

---

## État actuel

> ⛔ **MODE TEST ACTIF — LE CHAT EST IMMORTEL** (`player.gd`, `const IMMORTAL := true`,
> posé le 2026-08-17 à la demande). **À repasser à `false`.** Tant qu'il est là, aucun
> chiffre d'équilibrage ni aucune courbe de difficulté ne veut dire quoi que ce soit.
>
> - **Il n'a ni réglage ni argument de ligne de commande**, et c'est délibéré : un mode de
>   triche qu'on peut activer est un mode qu'on oublie d'éteindre. Une constante, vraie ou
>   fausse, qu'on croise en lisant le fichier.
> - **La coupure est DANS `take_damage`, après le garde**, pas avant : l'éclat de collision,
>   l'impact frame et l'invulnérabilité de 0,45 s partent quand même. Sortir plus tôt
>   rendrait le chat **intouchable** au lieu d'immortel — plus aucun retour de collision à
>   l'écran, donc plus moyen de juger un FX de hit ni de voir qu'on traverse un ennemi.
> - **Il n'est pas silencieux** : `push_warning` au lancement, et la barre reste clouée à
>   100/100. ✅ Vérifié en capture sur 8 s de run avec ennemis au contact.

**Systèmes en place :** mouvement 8 directions, **visée souris indépendante**, spawn
ennemis, **attaque de griffure au corps à corps**, **aura d'haleine puante**, XP/niveaux,
**système de compétences à paliers**, scaling difficulté, HUD complet, Game Over/restart,
arène large. Toute la logique de gameplay tourne — le passage en 3D ne l'a pas touchée.

**La silhouette est antialiasée depuis le 2026-08-19** — MSAA 4× dans `project.godot`,
voir « L'antialiasing de la SILHOUETTE ». Le trait est une coque inversée, donc un bord de
géométrie : c'était la dernière famille de bords à n'être traitée par rien. L'erreur au
bord tombe de 14,9/255 à 4,9 sur la silhouette du chat, à taille de jeu. La passe a sorti
deux choses au passage : **la 3D ne rend PAS à la résolution de la fenêtre** (1175 × 648
pour 2560 × 1411, facteur 2,18), et **une capture du jeu n'était pas reproductible** tant
que la souris pouvait prendre la visée — d'où `--aim=`.

**La pause est passée au moteur le 2026-08-18** (P1 de la revue de code) — voir « La
pause » plus haut. Treize copies de `_is_run_paused()` et le `run_paused` maison ont cédé
la place à `get_tree().paused` + les `process_mode` de `main.tscn`. Ça corrige au passage
deux FX qui jouaient derrière les cartons — dont une griffure qui **perdait ses dégâts** —
et ça remplace treize gardes illisibles par un banc, `pause_probe`.

**Les nœuds ne se cherchent plus, on les leur donne — le 2026-08-18** (P3 de la revue de
code) — voir « Qui connaît qui » plus haut. Les groupes `game_root` et `player` ont
disparu : `main` injecte au `setup()`, `GameRoot` expose `add_fx()` et `enemies()`, et une
compétence atteint le monde par **`player.game`**, le seul chemin typé. À volume de code
constant (+55 / −54 lignes hors commentaires) : six recherches globales et deux couplages
silencieux en moins, rien de gagné en lignes.

**Le socle des compétences est posé le 2026-08-17** — voir « Les compétences » plus haut.
Les 7 upgrades à plat ont cédé la place aux trois types (AUTO / ACTIF / PASSIF), aux
paliers T1→T3, aux slots et au tirage pondéré de `Gameplay et Progression` §2. La griffure
et l'haleine sont devenues **deux instances du même contrat**.

**Et les trois types sont jouables depuis le même jour.** Le runtime des ACTIFS existe
(deux slots, deux clics, cooldown, pastilles au HUD en pas), et deux compétences témoins
l'éprouvent : la **morsure** (le 1ᵉʳ actif) et la **boule de poils** (1ᵉʳ AUTO auto-visé,
qui réveille le projectile). Les contrôles sont passés à **WASD + les deux clics**.

**Le 1ᵉʳ lot de contenu est posé le 2026-08-17** — le catalogue passe de 7 à **11 entrées**
(voir « Quatre compétences de plus »). Les slots ACTIVES sont désormais **saturables**,
donc le chantier 2 devient atteignable en jeu.

**Restent à faire :** un **3ᵉ actif**, sans quoi le carton de remplacement n'a rien à
proposer et ne s'ouvrira jamais ; puis le carton lui-même (chantier 2), les ultimes T4, et
le reste du contenu (~6 auto, ~3 actifs de plus).

**Le jeu est bilingue depuis le 2026-08-17** — voir « Le jeu est bilingue » plus haut.
Français et anglais, un carton de réglages ouvert par Échap, et le choix conservé d'une
session à l'autre. Tout le texte affichable a quitté le code pour `locale.gd`, y compris
les titres et descriptions d'upgrades que le pool portait jusque-là.

**La première compétence lootable est arrivée le 2026-08-17** — voir « L'haleine puante »
plus haut. Le pool d'upgrades ne savait jusque-là que régler des chiffres existants ; il
peut désormais **débloquer une arme**, et celle-ci pousse à rester au contact là où tout
le reste du jeu pousse à l'esquive.

**L'attaque a changé de nature le 2026-08-16** — voir « L'attaque » plus haut. Le projectile
auto-visé cède la place à une griffure dirigée par le joueur : c'est la première fois
que le jeu demande au joueur autre chose que d'esquiver. On peut désormais se faire toucher
dans le dos, et c'est la contrepartie assumée de dégâts trois fois plus élevés.

**La visée s'est détachée du déplacement le même jour** — voir « La visée » plus haut.
Elle était portée par la direction de marche ; elle est désormais à la **souris**, ce qui
ouvre le jeu de jambes que le survivor demande : reculer en frappant devant soi. La manette
reste à faire, et sa place est déjà prévue (`aim_source`).

**L'éclat de collision a été refait le 2026-08-17** — voir « L'éclat refait » plus haut.
C'est le seul retour de dégât depuis que le flash plein cadre est débranché, et il était
noté inachevé depuis le 2026-08-16 : il se lisait comme une **fleur**. Il est désormais une
**étoile de manga** — polygone à segments droits, tessons projetés, et une 1ʳᵉ pose crème
qui récupère ce que l'impact frame faisait, à la taille du coup au lieu de l'écran.

**L'interface a été refaite le 2026-08-16** — voir « L'interface » plus haut. Elle est
passée du placeholder Godot (police par défaut, panneaux arrondis, textes de debug) au
registre anime TV 80–90, **d'après un relevé image d'*Orbitals*** et non de mémoire : HUD
nu et minuscule dans un coin, cartons qui s'ouvrent en pas, deux polices
gothiques japonaises sous-ensemblées. §9 de la DA a été réécrit dans la foulée.
Les kana décoratifs, eux, ont été retirés le 2026-08-17.

**Puis refaite une SECONDE fois le 2026-08-17** — voir « L'interface en gris » plus bas.
*Orbitals* garde la **place** de l'UI ; ***Cowboy Bebop* et *Evangelion*** prennent sa
**couleur**, sa **matière** et sa **composition**. Rien n'est plus translucide, les
plaques sont en gris neutre hors palette du monde, et les coins coupés cèdent la place à
des angles droits à repères. §9 de la DA a été réécrit **une deuxième fois**.

**Visuels :** le **chat est dans le jeu**, cel-shadé, contour, visage peint et **griffes
dessinées** compris, et il se lit à taille de jeu — désormais en **tuxedo noir et blanc**,
qui se détache mieux du
parquet que l'ambre d'avant. Les **canapés sont modélisés** et posés dans l'arène en deux
variantes (bleu ciel, vert sauge). Le reste est placeholder : ennemis en primitives 3D,
tables / plantes / coussins en boîtes pastel, croquettes en cubes.

**Passe rétro anime — faite le 2026-08-16.** `Attr_Style` peint et câblé, trait à
épaisseur variable **des deux côtés du pont** (Godot par `cel_outline.gdshader`, Blender par
`tools/build_outline.py`), ombres peintes, bord de cluster irrégulier, accent de brillance,
et le post-process §8bis (le grain sur 3s, seul restant) dans `shaders/retro_post.gdshader`.

> ⚠️ **Le `.blend` du chat est une SOURCE, sans garde-fou.** Il a été retrouvé le
> 2026-08-16 réenregistré sur un état antérieur à la passe tuxedo — matériau
> `fourrure_blanche` disparu, palette revenue à l'ambre — alors que le `.glb` du dépôt était
> bon. Le jeu ne montrait donc rien ; seul un réexport aurait révélé la régression, **en la
> propageant**. Ce qui a permis de la réparer sans perte, c'est que chaque geste de style
> soit un script rejouable. Avant tout réexport du chat, relancer `paint_tuxedo.py` et
> `build_outline.py` — ils sont idempotents et ne coûtent rien.

**Animation — faite le 2026-08-16.** `idle` (2,4 s : respiration, queue, frisson d'oreille)
et `walk` (0,4 s : rebond + pattes alternées) sont construites par
`tools/build_animations.py`, exportées, et jouées par `cel_model.gd` — le jeu bascule sur
la vitesse du joueur, **sans fondu** (un fondu interpolerait les deux poses, soit
exactement le glissement que la cadence existe pour supprimer).

> ✅ **La cadence en pas est prouvée de bout en bout, mesurée et non supposée.** Le banc
> lit la pose réellement appliquée à `bras_L`, frame par frame : elle change aux frames
> 0, 3, 6… 24, écarts tous à 3. Deux rapports le surveillent en permanence —
> `cel_model.animation_report()` (les pistes) et `_capture_cadence()` du banc (l'os).
> Le déplacement, lui, reste lisse à 60 : `move_and_slide` n'a pas été touché.

**Oreilles remontées de 0,12** (2026-08-16, géométrie **et** os, du même vecteur). Le
dégagement au-dessus du crâne passe de 0,19 à 0,30. **Résultat mitigé, assumé :** de face
les oreilles se lisent enfin à taille de jeu (§3) ; de profil l'amande a *grossi*, puisque
l'oreille proche émerge davantage. Conséquences à connaître : le chat mesure désormais
**1,858** (contre 1,738), et `PAINTED.center` dans `cel_model.gd` a suivi.

### FX de collision — faits le 2026-08-16

> ⛔ **LE FLASH PLEIN CADRE EST DÉBRANCHÉ DEPUIS LE 2026-08-17** (demande directe) —
> deux frames d'ambre sur toute l'image se lisaient comme un à-coup d'affichage, pas comme
> un coup encaissé. `impact_frame.gd`, sa scène, son shader et le nœud `$ImpactFrame` sont
> gardés **entiers**, sur le modèle du projectile : seul l'appel a disparu de
> `_on_player_hit`. Le rebrancher tient en une ligne.

Le chat touché par un ennemi déclenchait **deux** effets, et §8 les demandait ensemble
(*« hit → petites étoiles chaudes + flash ambre »*). Ils se partageaient le travail au lieu
de se doubler : **l'éclat dit OÙ ça a cogné, l'impact frame disait que c'était un coup.**
C'est ce partage qui rend le débranchement tenable — **c'est la couche globale qui part,
celle qui porte l'information qui reste.**

| Effet | Portée | Durée | Couleur |
|---|---|---|---|
| **Éclat** `hit_burst` | local, planté au point de contact | 6 poses, 7 crans (~233 ms) | rose-rouge `#D45870` + crème `#F7EFE0` |
| ~~**Impact frame** `impact_frame`~~ 💤 | plein cadre | 2 frames, coupe franche | ambre `#D4A860` |

- Déclenchés par `player.hit(contact_position)`. L'ennemi passe sa position à
  `take_damage`, le **chat** en déduit le point de contact — l'éclat doit se lire comme
  posé sur lui, pas sur l'agresseur.
- L'impact frame est en **layer −1**, donc *sous* `RetroPost` : c'était une frame de
  l'**image**, le grain de §8bis devait passer par-dessus. Au-dessus,
  elle se serait lue comme un calque d'UI collé sur le film. *(L'argument reste vrai le
  jour où on la rebranche — le nœud n'a pas bougé de layer.)*
- **Rallonger un FX se fait en ajoutant des POSES, jamais en ralentissant la cadence** —
  §8 veut les FX *plus rapides* que les personnages, c'est ce qui leur donne du claquant.

### L'éclat refait — un impact de manga (2026-08-17)

L'éclat était noté inachevé depuis le 2026-08-16 (*« il recouvre le chat et se lit comme
une fleur »*). Il est repris **en entier**, à la demande, en registre manga / anime rétro.
Détail complet et journal des pièges dans la DA, **§8ter**.

| | Avant | Après |
|---|---|---|
| Forme | profil `pow(abs(cos))`, 7 lobes | **polygone à 7 pointes, segments DROITS** |
| 2ᵉ ton | disque crème centré | **copie réduite de l'étoile** |
| Tessons | — | **4 échardes projetées** |
| Flash | *(l'impact frame, débranchée)* | **1ʳᵉ pose entièrement crème**, à la taille du coup |
| Poses | 8, durées égales | **6, à durées propres** (1·1·2·1·1·1 crans) |
| Largeur | ~3,0 m — plus large que le chat | **~1,9 m**, tessons compris ~2,3 m |

- ⚠️ **AUCUNE DES TROIS CAUSES N'ÉTAIT UN RÉGLAGE.** `pow(abs(cos(a·n)), sharp)` ne sait
  produire que des **lobes tangents** — monter l'exposant amincit les pétales, ça n'en fait
  pas des pointes ; un rond pâle au centre d'une forme à pointes est un **pistil** ; et
  l'ancienne animation **grandissait** de bout en bout, ce qui est le geste d'une corolle
  qui s'ouvre. Un choc est déjà à son maximum, puis il tombe.
- ⚠️ **§3 interdit les angles vifs — c'est une règle sur les OBJETS DU MONDE**, pas sur
  l'encre jetée par-dessus. La DA a été corrigée dans le même mouvement : sa grammaire
  d'époque rangeait *« la poussière **et les impacts** »* dans les volutes rondes, et c'est
  cette phrase qui avait produit la fleur.
- **Les tessons sont composités à part de l'étoile** : dix fois plus petits, ils ont besoin
  de leur propre borne d'encre. *Un cerne se dose sur ce qu'il cerne* — 4ᵉ fois que la règle
  se paie (ATH, haleine, dents de la morsure, ici).

> ⚠️ **`ink` et `valley` SE DISPUTENT LA MÊME PLACE.** Le trait à 0,038 faisait **1,7 px** et
> l'étoile se lisait sans cerne ; à 0,085 il **mangeait les pointes en entier** et le cluster
> 2 tons retombait à un seul ton (le défaut déjà mesuré sur le corps de la griffure). Un
> creux profond veut un trait fin, un trait épais veut une étoile trapue. Final : `valley`
> 0,40, `ink` 0,065 (~2,9 px, l'ordre du trait du chat).

> ⚠️ **La modulation basse fréquence de l'haleine se dose aussi.** Appliquée trop fort
> (`0,40 + 0,60 × slow`), la moitié des pointes tombait au plancher et l'étoile sortait en
> **flèche**. Un éclat est radial : c'est la LONGUEUR qui varie, pas le nombre de côtés qui
> en ont une.

> 🔍 **LE PIÈGE LE PLUS COÛTEUX EST DE LA PRÉCISION, ET L'ALGORITHME ÉTAIT JUSTE.** Le signe
> d'un polygone se prend d'ordinaire par **parité de traversées d'un rayon horizontal** (la
> formule d'iq). Elle est exacte — vérifiée en **float64 sur 400 graines**, y compris sur les
> rangées passant pile par un sommet, zéro erreur — et elle **casse en float32** : une arête
> quasi horizontale ne sélectionne qu'**une rangée de pixels**, et sur cette rangée le test de
> côté compare deux produits presque égaux dès qu'on s'éloigne horizontalement. Ça sort en
> **ligne rose de 1 px, pleine, sans encre, en travers du décalque** — invisible pendant deux
> passes de réglage, sortie en agrandissant la frame ×8. **Un portage numpy ne peut pas la
> reproduire, puisque le défaut EST la précision.**
>
> La sortie : ne plus avoir besoin du test. Le polygone est **étoilé par rapport à son
> centre**, donc il se pave par ses 14 triangles `(0, v[j], v[i])` — un point est dedans s'il
> est dans l'un d'eux, et chaque test est un produit vectoriel entre vecteurs franchement
> séparés. 🅿️ **À ressortir le jour où un autre FX dessinera un polygone.**

> ✅ **La distance est une VRAIE distance au segment**, ce qui supprime au passage le défaut
> d'encre que l'ancienne version *corrigeait* : la distance radiale (`r − radius`) vaut
> plusieurs fois la vraie sur le flanc d'une pique, donc le trait ne cernait que les pointes.
> Il fait désormais le tour, même épaisseur partout, **y compris au fond des creux**.

**Juger l'éclat sans jouer** — il part tout seul, les ennemis viennent au contact :

```bash
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . \
  --write-movie <dossier>/g.png --fixed-fps 60 --quit-after 300
# ⚠️ --fixed-fps 60, PAS 30 : une pose de FX tient 2 frames a 60. A 30 fps
#    d'enregistrement on echantillonne une pose sur deux et la sequence
#    devient illisible — on juge alors une animation qu'on n'a pas vue.
```

### L'interface — refaite le 2026-08-16, d'après l'image

L'UI était du placeholder : police Godot par défaut, `StyleBoxFlat` arrondis, et des
textes de debug (`Vie: 6 / 6`, `Griffure: 3  Cadence: 0.55s…`). Elle est refaite en
registre **anime TV 80–90**.

> 🔍 **§9 de la DA a été RÉÉCRIT à partir de l'image**, pas de souvenirs : 4 min de
> gameplay d'*Orbitals* en 720p60 + 5 captures éditeur en 4K. L'ancien §9 (*« arrondi ·
> chaud · livre illustré Ghibli · fenêtres en bois ou parchemin »*) appliquait à
> l'interface le registre du **décor** et n'avait jamais été confronté à la référence.

**Ce que le relevé donne** — et qui contredit l'intuition sur trois points :

- **Le HUD d'*Orbitals* n'a AUCUN contenant.** Ni plaque, ni cadre, ni équerre : du texte
  posé nu sur l'image, en capitales, à ~2 % de la hauteur d'écran, crème avec une **ombre
  décalée rouge** (de la désynchronisation vidéo, pas une ombre portée).
- **Aucun chiffre nulle part**, et la vie est en **cœurs**. On garde la forme (pastilles,
  barre) mais **pas** le zéro-chiffre : un survivor se joue sur des lectures constantes.
- **Il n'y a aucune mincho dans *Orbitals*.** Son HUD est une grotesque techno carrée, son
  logo une **gothique lourde angulaire**. Une mincho avait été choisie ici par réflexe
  « carton d'anime », puis retirée le jour même.

**Le partage, et c'est tout le dispositif :**

| | HUD permanent | Cartons (niveau, K.O.) |
|---|---|---|
| Contenant | **aucun** — texte cerné d'encre, posé sur le jeu | plaque sombre, filet, coins **coupés** |
| Place | un coin, jamais un bandeau | plein cadre, voile + lignes de vitesse |
| Entrée | — | **en pas**, 4 poses (`fx_cadence.FX_POSE`) |

C'est leur **contraste** qui fabrique l'événement, pas la taille des cartons.

- **Polices : Dela Gothic One** (moments) + **Zen Kaku Gothic New** (information), OFL,
  sous-ensembles `latin` + `latin-ext` — **~67 Ko au total**. Récupérées par
  `tools/fetch_fonts.ps1`, **rejouable** : une police est un geste de style, pas un
  binaire tombé du ciel.
- ⚠️ **Les kana décoratifs ont été RETIRÉS le 2026-08-17** (demande directe). Il n'y a
  plus de sous-ensemble `kana`, plus de dictionnaire `KANA`, plus de `make_kana_label()` :
  rien dans l'UI ne demande de glyphe japonais. Ce que les cartons perdent est le petit
  accent d'époque qui coiffait leur titre ; ce qu'ils gardent est la **gothique lourde**,
  qui porte à elle seule le registre anime TV — c'est la *lettre* qui datait l'image, pas
  l'alphabet.
- **Le HUD est en `layer = -2`**, donc *sous* l'impact frame (−1) et *sous* `RetroPost` (0) :
  il fait partie de l'**image** et reçoit le grain. Même argument que
  l'impact frame — au-dessus, il se lirait comme un calque d'UI collé sur le film.
- **La plaque est SOMBRE**, à l'inverse de l'ancien §9. Pas un goût : le sol est en
  parchemin `#F5ECD8` et en blé `#E8D4A8`, une plaque parchemin ne s'y lit pas.
- **`main.gd` ne connaît plus aucun `Label` ni aucun offset** — il envoie des valeurs, le
  HUD décide du dessin. C'est ce qui a supprimé `_update_ui_layout()` et sa trentaine de
  décalages en dur, qui refaisaient à la main le travail des ancrages.

> ⚠️ **Quatre pièges, tous trouvés en REGARDANT les frames, aucun en lisant le code :**
> - **Un `HBoxContainer` étire ses enfants à la hauteur de la rangée.** La piste d'XP
>   sortait en dalle de 20 px malgré ses 9 px déclarés — `custom_minimum_size` est un
>   minimum, il ne plafonne rien. Parade : `SIZE_SHRINK_CENTER`.
> - **Un uniform `rect_size` recâblé sur `resized` arrive en retard**, et d'un facteur
>   *différent par plaque* — donc aucune plaque juste pour servir de témoin. Les shaders
>   déduisent désormais leurs pixels de **`fwidth(UV)`** et ne dépendent plus de rien.
> - **2 px de cerne sur un glyphe de 12 px le remplissent.** Le petit texte sortait en bouillie.
>   Un cerne se dose en fraction de la hauteur d'x, jamais en valeur absolue partagée.
> - **Le volet d'entrée est dans le shader de la plaque, donc il ne coupe pas ses
>   enfants.** Le texte s'affichait entier pendant que la plaque s'ouvrait encore —
>   l'inverse d'un carton d'anime. Le contenu est masqué jusqu'à la dernière pose.

> ✅ **L'ouverture en pas est vérifiée par sonde, pas supposée** : les 4 poses tombent une
> par frame à 30 fps. ⚠️ La première sonde mesurait `Engine.get_frames_drawn()` — qui reste
> à **0 en headless**, puisque rien n'est dessiné. Elle rendait « tout sur la frame 0 »,
> un résultat parfaitement plausible et entièrement faux.

### L'interface en gris — refaite une 2ᵉ fois le 2026-08-17

La référence d'interface passe d'*Orbitals* à ***Cowboy Bebop* + *Neon Genesis
Evangelion***. Ce n'est pas un raffinement, c'est un changement de famille — demandé après
avoir joué la version précédente. **Ce qu'*Orbitals* disait de la PLACE reste intact** :
HUD nu dans un coin, texte minuscule en capitales, ombre décalée, entrée en pas, aucune
mincho. Ce sont la **couleur**, la **matière** et la **composition** qui changent. DA §9,
réécrit une deuxième fois.

| | v2 (*Orbitals*) | v3 (Bebop / Eva) | La raison |
|---|---|---|---|
| Plaques | brun quasi noir `#241A11` | **gris ardoise** `#3A3A38` | Le brun ramenait l'UI dans la palette du décor. Une interface est **hors-diégèse** |
| Opacité | 8 à 92 % | **100 %, partout** | Voir ci-dessous — c'était le défaut n°1 |
| Coins | chanfrein 12 px | **angles droits + repères d'angle** | Bebop et Eva sont carrés sans exception |
| Hiérarchie | valeur du texte | **contraste d'échelle** (44 px / 10 px) | Le geste d'Eva : un mot énorme, une légende minuscule |
| Titres | centrés | **calés à gauche** | Rien n'est centré sauf le carton lui-même |

⛔ **Le défaut n°1 : l'UI était translucide.** Les cartes de choix étaient à **8 %
d'opacité** — ce n'était pas une carte, c'était un voile posé sur un autre voile, et le
joueur choisissait entre trois fantômes. Ni Bebop ni Eva n'ont un seul élément d'UI
translucide : leurs aplats opaques sont précisément ce qui les fait lire comme du **papier
posé sur l'image** plutôt que comme un calque de logiciel.

- **Une opacité partielle est TOUJOURS la solution de facilité au même problème** — « cet
  élément est trop présent ». La vraie réponse est de le rendre plus **petit**, plus
  **sombre**, ou de le **supprimer**. Jamais fantôme.
- **Seul le voile de fond garde un alpha** (80 %), et il **assombrit** au lieu de teinter.
  À 55 % d'encre brune il repeignait le sol, le chat et les ennemis en sépia.
- **Le survol ne peut plus se dire par l'opacité** — c'était le signal (8 % → 26 %). Il
  passe au **filet ambre + titre ambre**, le même dispositif que la pastille de langue
  active : deux façons de dire « c'est celui-là » obligeraient à apprendre l'UI deux fois.
- **Le gris est QUASI NEUTRE** (2 % de saturation), pas le gunmetal bleuté de Bebop.
  Précédent mesuré : le corps de la griffure a dû passer de `#383E42` à `#37393B` parce
  qu'un gris bleuté se lit comme une tache **froide** sur un sol parchemin. L'UI est posée
  sur ce même sol, elle hérite de la contrainte.
- **Le crème du texte ne change PAS** (`#F7EFE0`), alors qu'un crème neutre serait plus
  Bebop : c'est déjà le blanc du pelage tuxedo, le cœur de la griffure et le crème de
  l'haleine. En fabriquer un second pour l'UI seule, c'est fabriquer exactement la
  divergence de constantes que ce projet passe son temps à réparer.
- **Le cerne d'encre disparaît DANS les cartons**, et nulle part ailleurs. Il existe pour
  détacher un texte qui flotte sur le jeu ; sur une plaque opaque plus rien ne flotte, et
  un brun chaud sur du gris neutre y serait une 4ᵉ valeur. Le HUD permanent le garde
  intégralement — c'est tout ce qui le tient.

> ⚠️ **Deux défauts trouvés EN CAPTURE, aucun visible en lisant le code, et tous deux
> causés par le passage à l'opaque :**
> - **Les lignes de vitesse ont avalé l'image.** Passées opaques dans le gris de filet
>   (`#8E8E88`, luma 0,56) sur une scène voilée à ~0,25, elles sont devenues le **sujet du
>   cadre**. La tentation immédiate est de leur redonner un alpha ; la bonne réponse est de
>   les rendre **plus sombres** — `#1A1A19`, où elles se lisent comme de l'encre, ce qu'est
>   d'ailleurs un trait de vitesse au manga. *Un élément d'UI n'a pas à être clair pour
>   être opaque.*
> - **Les deux jauges du HUD n'étaient pas alignées.** `LEVEL 1` étant plus large que `85`,
>   la rangée de vie était plus étroite — et **centrée**, donc indentée de 20 px. Le défaut
>   existait **depuis toujours** : personne ne peut aligner à l'œil deux barres à 22 %
>   d'encre. Corrigé en `ALIGNMENT_BEGIN`.
>
> 🔍 **Ce que les deux disent ensemble :** rendre une UI opaque ne la rend pas seulement
> visible, ça rend visibles **ses défauts de composition**. En attendre d'autres au
> prochain élément ajouté.

### Les cartes de choix — volume, type, vignette (2026-08-17)

La carte de choix porte désormais un **onglet de type**, une **fenêtre** sur le FX de la
compétence, puis le marqueur de palier, le titre et la description. Détail complet et
journal des pièges dans la DA, §9.9.

| | Ce qui a changé | La contrainte de DA qu'il a fallu tenir |
|---|---|---|
| **Volume** | biseau 3 px + facette de dessus + ombre portée **dure** | §9.1 r.2 interdit le dégradé — tout est à **bord franc**, comme le cluster 2 tons de §2bis |
| **Type** | onglet sauge (AUTO) / brique (ACTIF) / **sans teinte** (PASSIF) + le mot | §9.1 r.4 — un seul accent saturé. Les deux teintes sont **sous** l'ambre, qui garde le survol |
| **Vignette** | une pose du **vrai shader** du FX, en `SubViewport` + caméra ortho | Zéro divergence : une vignette redessinée en UI serait un 2ᵉ jeu de couleurs à synchroniser |

> ⛔ **C'EST LA VALEUR QUI DÉCIDE DU RELIEF, PAS LE BISEAU.** Les cartes étaient en
> `PLATE_LOW` (0,16) sur un carton à 0,23 — plus sombres que ce qui les porte, donc lues
> comme des **trous**, biseau ou pas. D'où `PLATE_RAISED` `#504F4B`, et la règle qui en
> sort : **dans un carton, ce qu'on peut prendre est plus clair que son fond, ce qui reçoit
> est plus sombre.** Les jauges et les pastilles de cooldown restent plates et sombres —
> `relief` est **`false` par défaut** dans `make_plate`.

> ⛔ **LE FOND DE LA VIGNETTE EST CLAIR.** Sur le registre bas des cartons (0,13), la
> griffure sortait en **trois fentes lumineuses** : son corps anthracite (0,22) et son encre
> (0,08) disparaissaient ensemble. Ces six FX sont dosés pour se lire sur le **parquet**
> (~0,84) et contre aucun autre fond — d'où un blé assourdi `#C4B594`, la seule couleur
> chaude admise dans un carton. Ce n'est pas de l'UI, c'est le **monde vu au travers**.

> ⚠️ **Le `size` de la vignette est celui du JEU.** Trois FX expriment leur trait **en
> mètres** : réduire `size` pour « faire tenir » le dessin épaissirait son cerne en
> proportion. C'est la **caméra** qui cadre (`frame`, en mètres).

> ⚠️ **`return` est interdit dans `fragment()`**, et l'échec est presque muet : la plaque
> retombe sur le shader canvas par défaut, qui rend le `modulate` du `ColorRect` — blanc.
> **Toute l'interface est sortie en blanc pur**, cartons compris.

> ⚠️ **Un `VBoxContainer` à court de place écrase ses enfants SOUS leur
> `custom_minimum_size`**, sans rien signaler : la fenêtre carrée est sortie en 86 × 65.
> Même piège que la piste d'XP, vu par l'autre bout. **Toute retouche de `CHOICE_SIZE` se
> revérifie en capture.**

**Juger l'UI sans jouer** — les cartons n'apparaissent pas dans une capture passive :

```bash
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . \
  --write-movie <dossier>/c.png --fixed-fps 30 --quit-after 30 -- --ui-card=level
#   --ui-card=level      le carton de niveau et ses 3 choix
#   --ui-card=gameover   le carton de K.O.
#   --ui-card=settings   le carton de réglages (langue)
#   --ui-choices=claw:2,hiss:1,toughness:1
#                        impose les 3 cartes. ⚠️ PAS un confort : le tirage est
#                        pondéré (AUTO x3), une capture au hasard sort trois AUTO
#                        une fois sur deux — et le code couleur de type serait
#                        jugé sur une image où une seule famille est présente
#   --lang=en            force la langue de la capture, SANS toucher au fichier
#                        de préférences — une image n'est pas un choix du joueur
```

**Juger l'haleine puante sans jouer** — l'aura n'existe pas tant qu'on n'a pas pris
l'upgrade, donc une capture passive ne la montre jamais :

```bash
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . \
  --write-movie <dossier>/g.png --fixed-fps 30 --quit-after 34 -- --breath=1
#   --breath=1   la competence au premier palier (2,8 m)
#   --breath=3   trois reprises cumulees (3,9 m) — pour verifier que le trait
#                ne grossit PAS avec la zone
```

### Le jeu est bilingue — fait le 2026-08-17

Français et anglais, avec un **carton de réglages** ouvert par **Échap**. La langue est le
premier réglage ; le carton est fait pour en recevoir d'autres.

- **`locale.gd` est la source unique des textes**, sur le modèle de `ui_style.gd`. Un
  texte écrit en dur dans un écran est un texte qui ne sera jamais traduit, et rien dans
  le code ne le signalera.
- **Une entrée par clé, les deux langues CÔTE À CÔTE.** Deux dictionnaires séparés (un par
  langue) laissent une clé non traduite passer inaperçue ; ici le trou se voit en lisant
  le fichier.
- **Les clés portent des PHRASES ENTIÈRES**, jamais des morceaux à recoller. `"PORTÉE
  %.1f m"` est une clé ; `"PORTÉE"` + `"%.1f"` + `"m"` en ferait trois, et l'ordre des
  mots change d'une langue à l'autre.
- **Le catalogue de compétences ne porte aucun texte** : `skill_definitions.gd` n'a que des
  `id` et des chiffres, et les clés `skill.<id>.title` / `.t<N>.desc` s'en déduisent. Rien
  à tenir synchronisé à la main.
  ⚠️ **Le titre est unique, la description est PAR PALIER** — un palier qui renommerait la
  compétence casserait la lecture, le joueur suit une carte de run par son nom. Une
  compétence dont tous les paliers disent la même chose n'écrit qu'un `.desc` :
  `skill_description` y retombe, ce qui évite d'écrire trois fois la même phrase et de
  devoir ensuite les tenir synchronisées.
- **Le nom d'une langue est écrit DANS cette langue** (`FRANÇAIS` / `ENGLISH`) — un joueur
  perdu cherche « English », pas « Anglais ». C'est la seule chaîne qui ne se traduit pas.

> ⚠️ **Ce n'est PAS `tr()` + un CSV, et c'est délibéré.** Un CSV doit être réimporté à
> chaque édition de texte, ce qui ajoute une étape à chaque retouche ; et `tr()` sur une
> clé absente rend **la clé**, en silence — on verrait `card.level_sub` à l'écran sans
> qu'aucune erreur ne soit levée. Ici une clé inconnue **lève** (faute de code) et une
> traduction manquante retombe sur le français (donnée manquante). Toute l'UI étant déjà
> construite en code, le rattrapage automatique des `Control` par `tr()` n'apportait rien.

> ⚠️ **Rien ne se met à jour tout seul.** Le HUD n'observe aucune source : il n'a que ce
> que `main.gd` lui a envoyé la dernière fois. `_refresh_text()` repousse donc **toutes**
> les valeurs après un changement de langue — une oubliée resterait dans l'ancienne langue
> jusqu'à son prochain changement, et la télémétrie, elle, ne bouge qu'au level-up.

> ⚠️ **Le chemin de changement de langue est emprunté À CHAQUE LANCEMENT**, et c'est
> voulu : le HUD est un enfant de `main`, donc ses labels sont déjà construits (en langue
> par défaut) quand `main._ready()` s'exécute. C'est `_refresh_text()` qui les remet dans
> la bonne. Un chemin qui ne servirait qu'au menu casserait sans qu'on s'en aperçoive.

> 🔍 **Leçon gardée du kana, retiré depuis** (voir §9.4) : le garde-fou de
> `fetch_fonts.ps1` — « un kana absent de `$Kana` sort en carré vide » — **était déjà
> contourné sans que personne le sache**. `レベルアップ` s'affichait depuis toujours alors
> que `ア`, `ッ` et `プ` n'avaient **jamais** été demandés : Google Fonts renvoie sur
> `text=` un morceau de sous-ensemble plus large que la liste. Si un glyphe non latin
> revient un jour, ne pas se fier à la liste pour savoir ce que le fichier porte.
> ⚠️ Et `FontFile.has_char()` **ne répond pas** sur ces woff2 (faux partout, y compris pour
> un glyphe qui s'affiche) : la seule vérification qui vaut est de **regarder la frame**.

**Réglages : où ils s'ouvrent, et où ils ne s'ouvrent pas.** Pendant le carton de niveau
Échap ne fait rien — ce carton attend une décision, et deux cartons empilés sur un voile à
moitié transparent ne se lisent plus. Pendant le K.O. non plus : il n'offre qu'une action,
et elle relance le jeu.

> ⚠️ **Un bouton d'UI ne touche JAMAIS à l'état de jeu, il le demande.** Le bouton
> REPRENDRE a d'abord été câblé sur `hud.close_settings_card()` — qui ne cache que la
> plaque. `main.gd` n'en savait rien, `run_paused` restait à `true`, **et le jeu se
> bloquait pour de bon** : plus de carton à l'écran, chat et ennemis figés, temps arrêté.
> Le bouton passe donc par `settings_close_requested`, comme `restart_pressed` et
> `choice_selected` avant lui.
>
> ⚠️ **Et la cause profonde était ailleurs : `run_paused` servait à la fois d'état de pause
> ET de droit d'ouvrir les réglages.** Une fois les deux désynchronisés, Échap ne pouvait
> plus rien — rien d'ouvert à fermer, et la pause interdisait d'ouvrir. La condition porte
> désormais sur **les cartons affichés**, et la pause n'en est qu'une conséquence : un
> `run_paused` resté à `true` par erreur ne piège plus personne.
>
> ✅ Les trois chemins sont vérifiés par sonde, pas supposés : clic sur REPRENDRE, Échap
> pour ouvrir, Échap pour fermer — et `elapsed_time` n'avance que sur les fenêtres non
> pausées (0 → 0,40 → 0,80).

**La sauvegarde est immédiate**, pas différée à la fermeture : une run de survivor se
termine souvent par un alt-F4, et un réglage perdu là où le joueur croit l'avoir posé est
pire que pas de réglage du tout. Au tout premier lancement — pas de fichier — le jeu prend
la **langue du système**, une fois ; dès qu'il y a un choix, le fichier fait foi.

### La vie en points — faite le 2026-08-16

La vie est passée de **6 points à 100**, et l'affichage de **pastilles à barre**.
Détail dans la DA, §9.6.

**Ce n'est pas une décision d'affichage.** Sur 6 points, un objet qui rend de la vie ne
peut rendre que 1 — soit 17 % de la barre — ou rien. Toute la famille des effets petits et
continus (**vol de vie** sur griffure, régénération, soin par croquette) était
*mécaniquement* impossible à doser. Sur 100, un vol de vie de 2 par coup est un vrai
réglage. C'est le point de départ de ces objets, pas leur implémentation.

| | Valeur | Note |
|---|---|---|
| Vie du chat | **100** | `player.max_health` |
| Chaser | **15** de contact | 6,7 coups (c'était 6) |
| Brute | **30** de contact | 3,3 coups (c'était 3) |
| Upgrade « Réserve de vie » | **+30**, soigne 30 | même proportion que le +2 sur 6 |

- **Une échelle de points se remet à l'échelle des DEUX côtés.** Changer la vie sans
  changer les dégâts rendrait le chat immortel.
- **Une upgrade se dose en fraction de la barre**, jamais en points absolus : +2 sur 100
  ne se verrait pas.
- **La barre de vie est plus épaisse que celle d'XP** (14 px contre 8) et **porte son
  nombre**, contrairement à l'XP. La forme reste le premier niveau de lecture ; le nombre
  dit ce que la forme ne peut pas — de combien ce coup a coûté, de combien ce vol de vie
  a rendu. Sous **30 %** la barre bascule au rose de blessure.

> 🔍 **Effet de bord mesuré, non voulu, à connaître : la montée en difficulté des dégâts de
> contact était SILENCIEUSEMENT MORTE.** `round(1 × 1,2)` rend 1 — il fallait 225 s de run
> pour que le dégât du chaser passe à 2, c'est-à-dire *double* d'un coup. À l'échelle des
> points l'arrondi cesse de tout écraser et le chaser monte de 15 à ~21 en continu.
> **La fin de run est donc plus dure qu'avant, sans qu'on ait rééquilibré quoi que ce
> soit.** À retester avant de toucher aux courbes de `main.gd`.

### Mobilier 3D — le canapé, fait le 2026-08-16

Premier meuble modélisé : `assets/models/prop_canape.glb`, **2 064 tris**, 12 coques,
2 matériaux (`tissu`, `coussin`). **Club rebondi** — accoudoirs roulés, 3 coussins bombés,
dossier en 3 bosses — la forme la plus ronde, donc la plus conforme à §3 et §12.

> ⚠️ **Le `.blend` est REGÉNÉRÉ par `tools/build_couch.py`, jamais édité à la main.**
> Contrairement au chat, la géométrie du canapé est procédurale : elle et sa peinture
> `Attr_Style` ont la même source. Les séparer rejouerait le décalage que le chat a payé
> cher — une peinture calée sur une version du maillage qui n'existe plus.

**La hauteur ment, et c'est la seule chose qui ment.** L'emprise au sol (6,4 × 2,6 m) est
déjà juste : ≈4 longueurs de chat, le rapport réel chat/canapé. Mais un vrai canapé vu par
un chat de 1,86 unité culminerait à **6,3 m**, et à 45° de plongée ça occulte un pan
d'arène entier. Le dossier s'arrête donc à **3,2 m**, l'assise à **1,6 m** — assez pour que
le chat posé dessus (1,6 + 1,86 = 3,46) **dépasse le dossier de 0,26** et reste lisible.
C'est vérifié en image par le banc, pas déduit.

Quatre réglages n'ont pu se décider qu'en **regardant les rendus**, aucun en raisonnant :

| Défaut mesuré | Cause | Parade |
|---|---|---|
| Grande selle pâle sur les accoudoirs | `n.z > 0,90` laisse passer 42 % du diamètre d'un tube à 16 pans | Bande d'accent calée sur la **position**, pas la normale — 0,26 m quel que soit le nombre de pans |
| Barres claires en travers du dossier, de dos | Les coussins de dossier ressortaient de 0,014 par la face arrière du panneau (la **rotation** de « légèrement tordu » repousse les coins) | Coussins avancés de 0,065 |
| Canapé plat, un seul aplat | La lumière vient d'en haut : un meuble n'offre à la caméra **que** des faces vers le ciel, toutes du côté éclairé | `shadow_bias_strength` **1,5** (§4 le dit : le bouton est là, pas dans l'amplitude peinte) **+ 2 ombres portées peintes** — dossier sur l'assise, accoudoirs sur ses bords |
| Canapé délavé à taille de jeu | `#A0C8D8` plein tombe dans la plage de valeurs des lames claires du parquet | Bâti descendu à `#8FBAC9` ; la couleur de palette reste sur le coussin |

Trois fabriques de style coexistent désormais, et le découpage n'est pas arbitraire :
`cel_style.gd` (primitives sans modèle) · `cel_prop.gd` (.glb **sans squelette**) ·
`cel_model.gd` (le chat : squelette, `rest_undo`, visage peint).

> **Reste connu :** de profil strict (90°), l'accoudoir éloigné pointe au-dessus du dossier
> comme une fine antenne. Quelques pixels au cadrage de jeu — non traité.

### Le canapé bloque — la 1ʳᵉ collision du jeu (2026-08-18)

Le mobilier était **purement visuel** : on traversait un canapé. Il est désormais un
**obstacle plein** pour le chat comme pour les ennemis. C'est le premier pas du chantier
« le meuble comme terrain de jeu » ; le saut sur l'assise et le ralentissement des ennemis
viendront après, et le blocage franc leur cédera la place.

> ⚠️ **AVANT CE JOUR, RIEN NE COLLISIONNAIT — ET DEUX COMMENTAIRES DU DÉPÔT DISAIENT
> L'INVERSE.** Tous les `CharacterBody3D` étaient en `collision_mask = 0` et le projet
> n'avait **aucun `StaticBody3D`** : `move_and_slide()` ne résolvait jamais rien, et c'est
> `clamp_to_arena()` qui tenait lieu de mur. C'est le P4 de la revue de code, qui demandait
> de trancher ce point *avant* ce chantier — partir avec une couche physique qu'on croit
> branchée fait chercher le bug du mauvais côté.
> **Le mur de bordure n'a pas changé** : il reste un `MeshInstance3D` nu, et c'est toujours
> le clamp qui l'applique. Seul le mobilier collisionne.

| | Choix | Pourquoi celui-là |
|---|---|---|
| Corps | **`StaticBody3D`** enfant du modèle | Ce que le manuel prescrit pour un décor immobile (*Physics introduction* : « walls and other obstacles ») |
| Forme | `BoxShape3D` relevée sur l'**AABB du maillage** | Un `"height"` écrit à la main serait un 2ᵉ nombre à tenir synchronisé avec Blender |
| Couche | bit 3, `decor_bloquant` | Les neuf couches du projet sont **nommées** dans `project.godot` — le manuel prévient que les suivre devient vite impossible |
| Masque du meuble | **0** | Un corps statique n'a rien à scruter ; ce sont le chat et les ennemis qui l'ajoutent à leur masque |

- ⚠️ **Le corps est ENFANT du modèle, jamais son frère.** Il hérite ainsi du `yaw` du
  meuble sans avoir à le refaire : un canapé tourné d'un quart de tour emmène sa collision
  avec lui, et les deux **ne peuvent pas** diverger.
- **Les attaques, elles, traversent le mobilier.** Griffure, morsure et projectile sont sur
  la couche des hitbox (bit 7) et ne masquent pas le décor. C'est délibéré pour l'instant :
  un canapé qui arrête une griffure demanderait un test de ligne de vue par ennemi, et
  §15 (lisibilité > détail) ne le réclame pas tant que le meuble n'est pas franchissable.
- 🅿️ **Un ennemi peut naître DANS un canapé** — `main._get_enemy_spawn_position()` tire un
  point au hasard sur un anneau autour du chat, sans rien savoir du mobilier. ✅ Mesuré, et
  ça se résout tout seul : posé pile au centre d'un canapé, un chaser en ressort et
  rejoint sa cible (0,04 m du but après 5 s). La dépénétration de Godot fait le travail.

### Les canapés sur les deux axes (2026-08-18)

Les deux canapés d'une cellule étaient couchés dans le même sens (`yaw` 0 et 180). Le
second passe à **90°** : sur les 24 canapés de l'arène, **12 dans l'axe X, 12 dans l'axe Z**.

- **Le quart de tour dit ce que le demi-tour ne disait pas.** À 45° de plongée, un canapé
  retourné garde exactement la même silhouette au sol — l'argument « deux exemplaires dans
  le même sens se lisent comme du papier peint » ne tenait qu'à moitié.
- **Et ce n'est pas qu'une question de lecture.** Tant que tout obstacle barre l'arène dans
  le même sens, le contourner est toujours le même mouvement. Il en faut sur les **deux
  axes** pour que le placement du chat devienne une décision.

> ⚠️ **L'emprise déclarée dans `arena.PROPS` est celle du MODÈLE** (6,4 × 2,6, mesurée sur
> son AABB), donc un quart de tour l'**échange**. `arena._footprint()` applique la rotation
> avant le test de placement — sans quoi un canapé vertical serait jugé sur l'emprise de
> l'horizontal, soit 3,8 m de trop d'un côté. Le défaut serait **silencieux** (un meuble
> accepté qui déborde du mur, ou écarté à tort), et il est devenu un vrai bug le jour même,
> puisque c'est cette emprise que la collision reprend.

> ✅ **Tout est vérifié par sonde, rien n'est supposé.** 24 canapés posés, 0 hors arène,
> 0 sur le point d'apparition, **0 chevauchement** sur les 90 emprises de mobilier ; un
> rayon physique sur le masque 4 touche **24 / 24** ; et chat, chaser et brute poussés sur
> le grand côté s'arrêtent tous les trois **au centimètre attendu** (1,30 m de demi-canapé
> + leur rayon), sur les deux orientations.
>
> ⚠️ **`--walk` ne suffit PAS à vérifier une collision, et son verdict est rassurant et
> vide.** Le cercle de marche fait 9 m et ne croise aucun canapé : 1 200 frames physiques
> rendent **0 collision**, exactement le même chiffre qu'un mobilier resté fantôme. Une
> collision se vérifie en **poussant un corps dessus**, pas en laissant le jeu tourner.

### Le trait du décor — moitié moins, tranché le 2026-08-16

Le mobilier — canapés **et** boîtes pastel — est cerné à **la moitié** du trait des
personnages (`cel_prop.OUTLINE_SCALE = 0.5`). §2ter.A de la DA : dans la référence, les
personnages sont cernés, **le décor ne l'est presque pas** ; les grandes masses de fond se
séparent par la **valeur**, pas par la ligne. Zeucozy cernait tout de la même encre.

**Réduit et non supprimé, et c'est la mesure qui l'a imposé.** Sur la silhouette du canapé
contre le parquet, le saut de valeur qui reste sans le trait : médian **0,33** à 100 %,
**0,39** à 50 %, **0,12** à 0 % — et à 0 %, **28,7 %** du contour passe sous le seuil de
lecture, contre 0,3 % à 50 %. À 50 % l'encre tombe de **41 %** sans qu'un pixel de
silhouette lâche.

> ⚠️ **À 0 % le meuble perd son ASSISE, et ce n'est pas la crainte qu'on avait notée.**
> On redoutait qu'il se fonde dans le parquet clair : le bleu et le blé ne se confondent
> pas. Ce qui lâche, c'est que **le mobilier n'a pas d'ombre de contact** — elle est
> réservée aux personnages — donc son trait est la seule chose qui le pose au sol.
>
> ⚠️ **Ne pas étendre au chat ni aux ennemis** : le relevé dit l'inverse pour eux. Ni au
> **mur de bordure**, qui n'est pas du décor mais la limite de jeu.
>
> ⚠️ **Une épaisseur nulle ne suffit pas à retirer un contour** : une coque inversée
> d'épaisseur nulle tombe exactement sur la surface qu'elle double et se dispute le
> z-buffer avec elle, ce qui marbre l'aplat. `cel_style.make_outlined()` retire donc le
> `next_pass` sous 0 — et `cel_prop` ne suppose plus qu'il existe.

### Le rai de soleil au sol — retiré le 2026-08-17

Le parquet et les tapis portaient une **flaque de lumière peinte** : un champ anisotrope
étiré à 30°, seuillé franc, partagé par `cel_ground` et `cel_rug` via `cel_floor.gdshaderinc`.
Elle est **retirée** — sol et tapis sont désormais éclairés **uniformément**, chacun sur sa
couleur de palette.

> ⛔ **CE QUI L'A TUÉE EST SON ANCRAGE, PAS SON DESSIN.** §2ter·2 veut une lumière
> *dessinée* sur un sol plat, puisqu'une normale constante n'en produit aucune. Mais une
> ombre peinte sur un **personnage** voyage avec lui, alors qu'une lumière peinte sur le
> **sol** est ancrée au monde — et la caméra suit le chat. Elle **défilait** donc à
> l'écran dès qu'on marchait : une grande bande claire en diagonale sur toute la largeur
> du cadre, qui se lisait comme un **artefact d'affichage** et non comme du soleil.
>
> ⚠️ **Aucun réglage ne rattrapait ça** — agrandir `pool_scale` ne fait qu'allonger la
> bande, et la seule façon de l'empêcher de défiler serait de l'ancrer à la **caméra**,
> soit une tache de soleil qui suit le chat. C'est ce qui en fait une règle et non un
> retour en arrière : **une forme peinte doit être ancrée à ce qui la porte.** Les petites
> formes tiennent quand même — les joints du parquet ne posent aucun problème.

- **`light_pool()` reste dans `cel_floor.gdshaderinc`, non appelée**, et c'est délibéré :
  si la lumière peinte revient, elle doit revenir **à un seul endroit** partagé par le sol
  et les tapis. Deux réimplémentations divergentes sont exactement le défaut que cet
  include existe pour empêcher — la supprimer, c'est les garantir.
- **`CelStyle.POOL` et `_apply_pool()` ont disparu** avec elle. Ce qu'elles disaient reste
  vrai de toute lumière de sol à venir : une seule source, recopiée telle quelle des deux
  côtés, sinon le bord de la flaque saute au passage d'un tapis.
- ✅ **Identifié en A/B, pas en lisant le code** : la bande n'était attribuable ni au
  post-process ni aux lignes de vitesse du carton (qui sont enfants du carton et
  disparaissent avec lui). Une capture avec `pool_level` poussé hors de portée l'a fait
  disparaître d'un coup — c'est ce qui a tranché.

**Prochaines priorités :**
0. 🅿️ **Le squash du `hit`** — l'impact frame est débranchée, mais §7 demande aussi un
   squash/stretch franc sur le squelette quand le chat encaisse. C'est du travail
   Blender (`tools/build_animations.py`), pas du shader.
1. **Le meuble comme terrain de jeu** — le chat saute sur le canapé, en redescend en
   sautant, et les ennemis sont **fortement ralentis** pour le franchir. ✅ **La collision
   est faite** (2026-08-18, voir « Le canapé bloque »), donc le canapé est déjà un
   obstacle plein. Restent le **saut** — un déplacement vertical, ce que le bond retiré le
   2026-08-17 devait devenir — et le **ralentissement** des ennemis, qui remplacera le
   blocage franc. Les deux touchent le déplacement du joueur, celui des ennemis et la
   caméra (un chat sur un meuble est plus haut que tout le reste) : à spécifier dans le
   Game Manifest avant d'être codés.
2. Modéliser l'aspirateur, le chien et le concombre — budget géométrie **serré** (§11) :
   ils se multiplient à l'écran et la coque inversée double le compte.
3. Les meubles restants — table basse, plante, coussin — encore en boîtes pastel.
   `tools/build_couch.py` et `tools/export_prop.py` donnent le moule.
4. 🅿️ **Liseré d'œil de profil — reporté**, yeux et cadrage conviennent en l'état. C'est
   l'**œil éloigné** qui déborde, `abs()` peignant les deux yeux sur la sphère sans rien
   savoir de la caméra. Ni `face_pitch` ni `face_front_min` ne peuvent le corriger — voir
   la Todo, les deux fausses pistes y sont mesurées.
5. Peindre 3 à 5 **dépassements de trait** — vrai travail à la main, à ne pas générer.
   ⚠️ Ce sera le **premier geste de style que rien ne saura rejouer** : à faire dans un
   `.blend` versionné à part, ou à réduire à des données que `build_outline.py` repose.
6. **Redresser la queue dans Blender**, si on veut qu'elle pointe vraiment vers l'arrière.
   Sa pose de repos est un point d'interrogation propre, mais la pointe revient vers
   l'avant ; l'ouvrir demanderait **111°** sur `queue_3`, ce que des poids dégradés ne
   supportent pas — le tube ondule en S. C'est du modèle, pas de l'animation.

**Comparer un cadrage sans rouvrir l'éditeur.** `camera_rig.gd`, `cel_model.gd` et le banc
lisent `--pitch=`, `--face-pitch=`, `--distance=`, `--fov=` et `--out=` en arguments
utilisateur (après le `--`). Le jeu et le banc partagent les mêmes noms.

**Comparer le trait du décor.** `--decor-outline=<facteur>`, lu par `arena.gd` **et** par
le banc des meubles — 1.0 rend l'ancien trait plein, 0.0 le retire. C'est par là que
100 / 50 / 0 % ont été comparés à l'image avant de trancher, sans éditer une constante
entre deux captures.

```bash
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . \
  --write-movie <dossier>/g.png --fixed-fps 30 --quit-after 12 -- --decor-outline=1.0
```

**Comparer l'antialiasing.** `--msaa=0|2|4|8` et `--ssaa=<facteur>`, lus par
`render_quality.gd` dans le jeu **et** dans les deux bancs. Le réglage du jeu est MSAA 4× ;
ces arguments servent à **mesurer**, jamais à capturer autrement que ce que le joueur voit
— supersampler les seules captures reviendrait à juger une image qui n'existe pas, soit la
divergence banc/jeu, encore.

**Rendre une capture reproductible.** `--aim=<degrés>` cloue la visée du chat et rend la
souris muette. ⚠️ **Sans lui, deux captures du même build ne sont pas comparables** : le
curseur physique se trouve quelque part quand la fenêtre s'ouvre dessous, et le chat part
dans cette direction-là. Avec lui, deux captures sont bit à bit identiques.
