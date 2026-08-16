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
  Rien à changer dans `player.gd` / `enemy.gd` : la cadence vit dans les fichiers d'animation
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
│       └── prop_test.tscn # Banc de test du mobilier
├── scripts/          # Logique GDScript
│   ├── main.gd       # Directeur de jeu, spawn, difficulté, UI
│   ├── player.gd     # Mouvement, attaque auto, upgrades, XP
│   ├── enemy.gd      # Comportement ennemi de base (follow, dégâts)
│   ├── claw_slash.gd # ⚔️ Griffure : 6 poses + dégâts sur les 3 premières
│   ├── projectile.gd # 💤 Projectile (direction, portée, collision) — débranché
│   ├── xp_orb.gd     # Croquette d'XP (magnétisme, collecte)
│   ├── arena.gd      # Décor : sol, tapis, mobilier, mur de bordure
│   ├── camera_rig.gd # Vue plongeante 45°, suit le joueur, bornée à l'arène
│   ├── systems/
│   │   ├── upgrade_definitions.gd  # Pool et définitions des upgrades
│   │   ├── cel_style.gd            # Matériaux cel des primitives, du sol + ombre de contact
│   │   ├── cel_model.gd            # ⭐ Le style du chat — partagé jeu ↔ banc de test
│   │   ├── cel_prop.gd             # ⭐ Le style des meubles — .glb sans squelette
│   │   ├── fx_cadence.gd           # ⭐ Les 2 durées de pose des FX (§7) — source unique
│   │   ├── impact_frame.gd         # Flash ambré plein cadre, 2 frames
│   │   └── hit_burst.gd            # Éclat de collision, 8 poses
│   └── tests/
│       ├── cel_test.gd  # Cadrage, bascules et captures du banc du chat
│       └── prop_test.gd # Banc des meubles : 8 directions + rapport de taille au chat
├── shaders/          # cel_toon, cel_outline, cel_face, cel_paws, retro_post
│                     # cel_paws (bouts de pattes + les 3 griffes dessinées)
│                     # cel_ground (parquet peint), cel_rug (tapis)
│                     # hit_burst (éclat de collision), impact_frame (flash)
│                     # claw_slash (la griffure — 3 traits cernés, billboard dirigé)
│                     # cel_core + cel_floor (includes, fonctions pures)
├── tools/
│   ├── export_cat.py       # ⚠️ LE SEUL chemin d'export du chat (voir piège n°6)
│   ├── build_animations.py # Construit idle/walk posées en pas, dans le .blend
│   ├── paint_tuxedo.py     # Pelage noir/blanc : matériau des extrémités + couleurs
│   ├── build_outline.py    # Contour Blender : épaisseur × Attr_Style.R, 1 encre / surface
│   ├── build_couch.py      # Canapé : géométrie ET Attr_Style, dans un .blend neuf
│   ├── export_prop.py      # Export générique d'un meuble, même réinjection COLOR_0
│   └── dump_paws.gd        # Relève os porteurs + boîtes de repos — source des PAWS
└── assets/
    └── models/       # player_cat.glb, prop_canape.glb
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

### Joueur — stats de base (player.gd)
- Speed 7,5 m/s | Health 6 | Attack interval **1,1 s**
- **Griffure** : damage 3 | range 5,2 m | arc frontal 120° | **visée à la souris**
- Projectile *(en sommeil)* : damage 1 | Speed 17,5 m/s | Range 10 m
- Pickup radius 2,5 m

### L'attaque — la griffure (2026-08-16)
L'auto-attaque est passée du **projectile** au **corps à corps**. Le projectile n'est pas
supprimé : scène, script, `spawn_projectile` et `_fire_at_nearest_enemy` sont intacts et
suivent toujours l'upgrade de dégâts. Il est **débranché de `_process`**, rien de plus.

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

### Upgrades (upgrade_definitions.gd)
6 types : `damage`, `attack_speed`, `move_speed`, `max_health`, `pickup_radius`, `claw_range`
3 choix aléatoires par level-up, sans doublons.
`projectile_speed` est sortie du pool avec le passage à la griffure — une upgrade qui
n'améliore plus rien de visible est un mensonge à l'écran. Son cas reste dans
`apply_upgrade` : la rebrancher tient à une entrée ici.

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
- **Langue UI :** Français (labels, titres d'upgrades, descriptions).
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
ennemis, **attaque de griffure au corps à corps**, XP/niveaux, 6 upgrades, scaling
difficulté, HUD complet, Game Over/restart, arène large. Toute la logique de gameplay
tourne — le passage en 3D ne l'a pas touchée.

**L'attaque a changé de nature le 2026-08-16** — voir « L'attaque » plus haut. Le projectile
auto-visé cède la place à une griffure dirigée par le joueur : c'est la première fois
que le jeu demande au joueur autre chose que d'esquiver. On peut désormais se faire toucher
dans le dos, et c'est la contrepartie assumée de dégâts trois fois plus élevés.

**La visée s'est détachée du déplacement le même jour** — voir « La visée » plus haut.
Elle était portée par la direction de marche ; elle est désormais à la **souris**, ce qui
ouvre le jeu de jambes que le survivor demande : reculer en frappant devant soi. La manette
reste à faire, et sa place est déjà prévue (`aim_source`).

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
