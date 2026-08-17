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
- **Post-process léger et permanent** — grain 3–5 % *rafraîchi sur 3s* et vignette chaude.
  Pas de tremblement d'image ni de saignement chroma (écartés).
  ⚠️ **La halation a été retirée le 2026-08-16** — elle marchait, mais elle chargeait
  l'image sans que le jeu y gagne (§15 : lisibilité > détail). Son diagnostic est conservé
  dans `Pipeline 3D.md` : si on la rebranche, elle ne peut **pas** se seuiller sur la
  luminance absolue, la palette parchemin étant déjà à ~0,93

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
# Banc de FLUIDITE — le chat marche, on mesure le battement de l'image sur 3 frames
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . --fixed-fps 60 \
  res://scenes/tests/motion_probe.tscn -- --frames=64
#   --nograin   grain coupe          --oldgrain  grain en phase (l'etat d'avant)
#   --root-step rebond en escalier   --shots     vignettes du chat, frame par frame
# Le jeu, en enregistrant des PNG puis en quittant — pour juger le rendu sans y jouer
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . \
  --write-movie <dossier>/game.png --fixed-fps 30 --quit-after 200
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
│       └── motion_probe.tscn # ⏱️ Banc de fluidité — mesure le battement de l'image
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
│   │   ├── bite_skill.gd    # 🦷 La morsure — le 1ᵉʳ ACTIF, cible unique
│   │   └── breath_skill.gd  # 💨 L'haleine puante — pilote l'aura, pas son dessin
│   ├── systems/
│   │   ├── skill_definitions.gd    # ⭐ LE catalogue — types, paliers, poids de tirage
│   │   ├── skill_set.gd            # ⭐ Ce que le chat PORTE — build + horloge des compétences
│   │   ├── cel_style.gd            # Matériaux cel des primitives, du sol + ombre de contact
│   │   ├── cel_model.gd            # ⭐ Le style du chat — partagé jeu ↔ banc de test
│   │   ├── cel_prop.gd             # ⭐ Le style des meubles — .glb sans squelette
│   │   ├── fx_cadence.gd           # ⭐ Les 3 durées de pose des FX (§7) — source unique
│   │   ├── breath_aura.gd          # 💨 L'haleine puante — aura lootable, poses + morsure
│   │   ├── bite_fx.gd              # 🦷 Les mâchoires de la morsure — 5 poses, dents dessinées
│   │   ├── ui_style.gd             # ⭐ Le style de l'interface — palette, polices, cadence
│   │   ├── locale.gd               # ⭐ TOUS les textes du jeu — français + anglais
│   │   ├── settings_store.gd       # Préférences du joueur sur disque (user://settings.cfg)
│   │   ├── impact_frame.gd         # Flash ambré plein cadre, 2 frames
│   │   └── hit_burst.gd            # Éclat de collision, 8 poses
│   ├── ui/
│   │   └── hud.gd       # 🖥️ Le HUD + les cartons, construits EN CODE depuis ui_style
│   └── tests/
│       ├── cel_test.gd  # Cadrage, bascules et captures du banc du chat
│       ├── prop_test.gd # Banc des meubles : 8 directions + rapport de taille au chat
│       └── motion_probe.gd # ⏱️ Fluidité : temps de frame + battement sur 3 frames
├── shaders/          # cel_toon, cel_outline, cel_face, cel_paws, retro_post
│                     # ui_frame (plaque grise, angles droits + repères d'angle)
│                     # ui_speedlines (lignes de vitesse)
│                     # bite (la morsure — 2 mâchoires dentées qui claquent)
│                     # cel_paws (bouts de pattes + les 3 griffes dessinées)
│                     # cel_ground (parquet peint), cel_rug (tapis)
│                     # hit_burst (éclat de collision), impact_frame (flash)
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
| **Morsure** *(dégât / portée / recharge)* | 7 · 2,6 m · 6,0 s | 10 · 2,9 m · 5,0 s | 14 · 3,2 m · 4,2 s |
| **Haleine** *(rayon / dégât par morsure)* | 2,8 m · 1 | 3,35 m · 2 | 3,9 m · 3 |

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
- **Le catalogue actuel** : `claw` (AUTO dirigé, de départ) · `hairball` (AUTO auto-visé) ·
  `breath` (AUTO de zone) · `bite` (ACTIF) · `move_speed` · `max_health` · `pickup_radius`.
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
> `skills.tick(delta)`, qui rend déjà la main en pause. Chaque compétence testait la pause
> elle-même — `breath_aura.gd` avait son `_get_game()` et son `_is_run_paused()` privés. À
> seize compétences, c'est seize endroits où oublier de s'arrêter derrière un carton, et le
> défaut est **invisible** : une aura qui continue de mordre pendant qu'on choisit une
> upgrade ne se voit pas, elle se constate à la barre de vie d'un ennemi.

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
```

> ⚠️ **`--autofire` n'est pas un confort.** Une compétence active attend un clic, et dans
> un `--write-movie` **la souris ne clique jamais** : sans lui, la première compétence
> active du jeu serait strictement incapturable, donc jugée sans avoir été vue.

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
| Arc | **90°** frontal | — |
| Portée T1→T3 | 2,6 / 2,9 / 3,2 m | 11 / 13 / 15 m |
| Dégâts T1→T3 | **7 / 10 / 14** | 2 / 3 / 4 |
| Recharge | 6 / 5 / 4,2 s | 1,6 / 1,35 / 1,1 s |

- **La morsure porte MOINS LOIN que la griffure** (5,2 m) et frappe deux fois plus fort :
  un croc se paye en distance, pas seulement en cooldown. 7 dégâts au T1 = exactement la
  vie d'une brute de départ, donc un effet lisible dès la première prise.
- **La cible est fixée au déclenchement, pas au claquement.** Deux poses passent entre les
  deux (~67 ms) et un chaser parcourt 25 cm : la chercher au claquement ferait mordre un
  ennemi que le joueur ne visait pas. Une morsure doit toucher ce qu'elle **montre**.
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

---

## Règles de développement

> Tiré de `03 - Production/Contexte IA.md` dans le vault — ces règles priment sur les instincts par défaut.

- **Fournir des scripts complets** lors de modifications, jamais des extraits partiels.
- **Ne pas complexifier** — architecture simple et modulaire, pas d'abstractions spéculatives.
- **Respecter l'arborescence** : `scenes/`, `scripts/`, `assets/`.
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

**Systèmes en place :** mouvement 8 directions, **visée souris indépendante**, spawn
ennemis, **attaque de griffure au corps à corps**, **aura d'haleine puante**, XP/niveaux,
**système de compétences à paliers**, scaling difficulté, HUD complet, Game Over/restart,
arène large. Toute la logique de gameplay tourne — le passage en 3D ne l'a pas touchée.

**Le socle des compétences est posé le 2026-08-17** — voir « Les compétences » plus haut.
Les 7 upgrades à plat ont cédé la place aux trois types (AUTO / ACTIF / PASSIF), aux
paliers T1→T3, aux slots et au tirage pondéré de `Gameplay et Progression` §2. La griffure
et l'haleine sont devenues **deux instances du même contrat**.

**Et les trois types sont jouables depuis le même jour.** Le runtime des ACTIFS existe
(deux slots, deux clics, cooldown, pastilles au HUD en pas), et deux compétences témoins
l'éprouvent : la **morsure** (le 1ᵉʳ actif) et la **boule de poils** (1ᵉʳ AUTO auto-visé,
qui réveille le projectile). Les contrôles sont passés à **WASD + les deux clics**.

**Restent à faire :** le carton de remplacement quand une famille de slots est pleine
(chantier 2), les ultimes T4, et le reste du contenu (~7 auto, ~5 actifs de plus).

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
et le post-process §8bis (grain sur 3s + vignette) dans `shaders/retro_post.gdshader`.

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

Le chat touché par un ennemi déclenche **deux** effets, et §8 les demande ensemble
(*« hit → petites étoiles chaudes + flash ambre »*). Ils se partagent le travail au lieu
de se doubler : **l'éclat dit OÙ ça a cogné, l'impact frame dit que c'était un coup.**

| Effet | Portée | Durée | Couleur |
|---|---|---|---|
| **Éclat** `hit_burst` | local, planté au point de contact | 8 poses sur 2s (~267 ms) | rose-rouge `#D45870` + cœur crème |
| **Impact frame** `impact_frame` | plein cadre | 2 frames, coupe franche | ambre `#D4A860` |

- Déclenchés par `player.hit(contact_position)`. L'ennemi passe sa position à
  `take_damage`, le **chat** en déduit le point de contact — l'éclat doit se lire comme
  posé sur lui, pas sur l'agresseur.
- L'impact frame est en **layer −1**, donc *sous* `RetroPost` : c'est une frame de
  l'**image**, le grain et la vignette de §8bis doivent passer par-dessus. Au-dessus,
  elle se lirait comme un calque d'UI collé sur le film.
- **Rallonger un FX se fait en ajoutant des POSES, jamais en ralentissant la cadence** —
  §8 veut les FX *plus rapides* que les personnages, c'est ce qui leur donne du claquant.
  4 poses ne suffisaient pas à comprendre ce qu'on voyait ; 8 (le plafond de §7) oui.

> ⚠️ Quatre pièges, tous **mesurés sur les PNG du jeu** et aucun visible en raisonnant :
> un flash ambre en `mix` assombrit l'image (et en `screen` seul, il la *refroidit*) ;
> une étoile à pointes arrondies se lit comme une **fleur** ; la distance radiale n'est
> pas la distance au bord, donc l'encre ne cerne que les pointes ; et une pique plus
> longue que `r = 1` se fait trancher par le bord du quad. Détail chiffré dans la Todo,
> section « Pièges FX ».

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
  il fait partie de l'**image** et reçoit le grain et la vignette. Même argument que
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

**Juger l'UI sans jouer** — les cartons n'apparaissent pas dans une capture passive :

```bash
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path . \
  --write-movie <dossier>/c.png --fixed-fps 30 --quit-after 30 -- --ui-card=level
#   --ui-card=level      le carton de niveau et ses 3 choix
#   --ui-card=gameover   le carton de K.O.
#   --ui-card=settings   le carton de réglages (langue)
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

**Prochaines priorités :**
0. 🅿️ **Le squash du `hit`** — l'impact frame est faite, mais §7 demande aussi un
   squash/stretch franc sur le squelette quand le chat encaisse. C'est du travail
   Blender (`tools/build_animations.py`), pas du shader.
1. **Le meuble comme terrain de jeu** — le chat saute sur le canapé, les ennemis sont
   fortement ralentis pour le franchir. Rien n'en est écrit : ni collision, ni saut, ni
   ralentissement n'existent aujourd'hui, le mobilier est purement visuel. C'est un
   chantier de **gameplay**, à spécifier dans le Game Manifest avant d'être codé.
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
