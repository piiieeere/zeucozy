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
- **Post-process léger et permanent** — grain 3–5 % *rafraîchi sur 3s*, halation chaude,
  vignette. Pas de tremblement d'image ni de saignement chroma (écartés)

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
| Bouts de pattes, bout de queue | **Matériau** `fourrure_blanche`, créé dans Blender par `tools/paint_tuxedo.py` | Un masque en shader y glisserait : Godot applique le skinning avant `vertex()` (piège n°5) et `rest_undo` ne connaît que **deux** os par surface — il en faudrait cinq |
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
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
  "C:/Users/tibo/Documents/zeucozy_3d/chat_style_v3.blend" --python tools/export_cat.py
# Réimporter les assets sans ouvrir l'éditeur
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --headless --import --path .
# Banc de test du cel-shading — mode interactif (orbite souris, touches O/P/A)
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/cel_test.tscn
# Banc de test — mode capture : 8 directions + sondes de skinning, puis quitte
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/cel_test.tscn -- --capture
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
│   ├── projectile.tscn
│   ├── xp_orb.tscn
│   ├── enemies/
│   │   ├── chaser.tscn   # Ennemi rapide (spawn dès le début) — capsule placeholder
│   │   └── brute.tscn    # Ennemi costaud (spawn après 22s) — sphère placeholder
│   └── tests/
│       └── cel_test.tscn # Banc de test du cel-shading, isolé du gameplay
├── scripts/          # Logique GDScript
│   ├── main.gd       # Directeur de jeu, spawn, difficulté, UI
│   ├── player.gd     # Mouvement, attaque auto, upgrades, XP
│   ├── enemy.gd      # Comportement ennemi de base (follow, dégâts)
│   ├── projectile.gd # Projectile (direction, portée, collision)
│   ├── xp_orb.gd     # Croquette d'XP (magnétisme, collecte)
│   ├── arena.gd      # Décor : sol, tapis, mobilier, mur de bordure
│   ├── camera_rig.gd # Vue plongeante 45°, suit le joueur, bornée à l'arène
│   ├── systems/
│   │   ├── upgrade_definitions.gd  # Pool et définitions des upgrades
│   │   ├── cel_style.gd            # Matériaux cel des primitives, du sol + ombre de contact
│   │   ├── cel_model.gd            # ⭐ Le style du chat — partagé jeu ↔ banc de test
│   │   ├── fx_cadence.gd           # ⭐ Les 2 durées de pose des FX (§7) — source unique
│   │   ├── impact_frame.gd         # Flash ambré plein cadre, 2 frames
│   │   └── hit_burst.gd            # Éclat de collision, 8 poses
│   └── tests/
│       └── cel_test.gd # Cadrage, bascules et captures du banc
├── shaders/          # cel_toon, cel_outline, cel_face, retro_post
│                     # cel_ground (parquet peint), cel_rug (tapis)
│                     # hit_burst (éclat de collision), impact_frame (flash)
│                     # cel_core + cel_floor (includes, fonctions pures)
├── tools/
│   ├── export_cat.py       # ⚠️ LE SEUL chemin d'export du chat (voir piège n°6)
│   ├── build_animations.py # Construit idle/walk posées en pas, dans le .blend
│   └── paint_tuxedo.py     # Pelage noir/blanc : matériau des extrémités + couleurs
└── assets/
    └── models/       # player_cat.glb
```

> **`cel_model.gd` est le point d'entrée du style.** Palette par matériau, visage peint,
> calottes, `rest_undo` : tout ce que le glTF ne transporte pas y est reconstruit, une fois.
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
- Speed 7,5 m/s | Health 6 | Attack interval 0.55s
- Projectile damage 1 | Speed 17,5 m/s | Range 10 m
- Pickup radius 2,5 m

### Upgrades (upgrade_definitions.gd)
6 types : `damage`, `attack_speed`, `move_speed`, `max_health`, `pickup_radius`, `projectile_speed`
3 choix aléatoires par level-up, sans doublons.

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
- **Catégories valides :** `player`, `enemy`, `xp`, `projectile`, `boss`, `pickup`, `ui`, `fx`
- **Travail en cours :** hors dépôt, dans `C:\Users\tibo\Documents\zeucozy_3d\` (`.blend` versionnés `_v01`, `_v02`…)
- Seuls les **exports validés** entrent dans `assets/models/`.

---

## État actuel

**Systèmes en place :** mouvement 8 directions, spawn ennemis, attaque auto, XP/niveaux,
6 upgrades, scaling difficulté, HUD complet, Game Over/restart, arène large.
Toute la logique de gameplay tourne — le passage en 3D ne l'a pas touchée.

**Visuels :** le **chat est dans le jeu**, cel-shadé, contour et visage peint compris, et
il se lit à taille de jeu — désormais en **tuxedo noir et blanc**, qui se détache mieux du
parquet que l'ambre d'avant. Le reste est placeholder : ennemis en primitives 3D, décor en
boîtes pastel, croquettes en cubes.

**Passe rétro anime — faite le 2026-08-16.** `Attr_Style` peint et câblé, trait à
épaisseur variable, ombres peintes, bord de cluster irrégulier, accent de brillance, et le
post-process §8bis (grain sur 3s, halation, vignette) dans `shaders/retro_post.gdshader`.

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

**Prochaines priorités :**
0. 🅿️ **Le squash du `hit`** — l'impact frame est faite, mais §7 demande aussi un
   squash/stretch franc sur le squelette quand le chat encaisse. C'est du travail
   Blender (`tools/build_animations.py`), pas du shader.
1. Modéliser l'aspirateur, le chien et le concombre — budget géométrie **serré** (§11) :
   ils se multiplient à l'écran et la coque inversée double le compte. C'est le seul
   chantier restant qui change ce qu'on **joue**, et non ce qu'on regarde.
2. 🅿️ **Liseré d'œil de profil — reporté**, yeux et cadrage conviennent en l'état. C'est
   l'**œil éloigné** qui déborde, `abs()` peignant les deux yeux sur la sphère sans rien
   savoir de la caméra. Ni `face_pitch` ni `face_front_min` ne peuvent le corriger — voir
   la Todo, les deux fausses pistes y sont mesurées.
3. Peindre 3 à 5 **dépassements de trait** — vrai travail à la main, à ne pas générer.
4. **Redresser la queue dans Blender**, si on veut qu'elle pointe vraiment vers l'arrière.
   Sa pose de repos est un point d'interrogation propre, mais la pointe revient vers
   l'avant ; l'ouvrir demanderait **111°** sur `queue_3`, ce que des poids dégradés ne
   supportent pas — le tube ondule en S. C'est du modèle, pas de l'animation.

**Comparer un cadrage sans rouvrir l'éditeur.** `camera_rig.gd`, `cel_model.gd` et le banc
lisent `--pitch=`, `--face-pitch=`, `--distance=`, `--fov=` et `--out=` en arguments
utilisateur (après le `--`). Le jeu et le banc partagent les mêmes noms.
