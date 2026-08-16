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
- Le joueur et les ennemis sont désormais **tous** des `Polygon2D` placeholders.
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
> `Attr_Style`** (R/G/B). C'est à peu près la seule chose stylistique qui survit à l'export.
> Détail dans `Convention Blender.md`.

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

> ⚠️ **La plongée caméra à 60° est à reconsidérer en DA.** Elle est la cause racine de trois
> problèmes distincts : le personnage se lit mal de face, l'oreille éloignée se projette dans
> le crâne, et le visage doit être relevé — ce qui le rend visible de dos.

### Trois pièges connus (appris à la dure, ne pas les reperdre)

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
4. *(anticipé, pas encore vérifié)* **L'export glTF détruit la cadence en pas** si l'option
   *Always Sample Animations* reste cochée — elle rebake tout en LINEAR. À décocher, et à
   contrôler au premier export. Parade : forcer `Animation.INTERPOLATION_NEAREST` à l'import.
5. **Godot applique le skinning AVANT `vertex()`** *(vérifié le 2026-08-16, en animation)*.
   `VERTEX` arrive déformé : tout masque peint calculé dessus **glisse sur la géométrie** dès
   qu'un os bouge. Parade dans les shaders : `rest_undo`, l'inverse du delta repos→pose de
   l'os porteur, remis à jour chaque frame. **Exact grâce aux poids rigides du piège n°3.**
   Pour une paire symétrique sur deux os (les oreilles), deux matrices, choisies par le
   signe de `x`. Ne jamais laisser une `mat4` d'uniform à sa valeur par défaut.

### Décision ouverte

§2bis décrit de la **3D temps réel** (caméra top-down 3/4 ~60°). Or tout le code actuel est
en nœuds 2D (`CharacterBody2D`, `Camera2D`, `Polygon2D`). La migration des scènes vers des
nœuds 3D **n'est pas tranchée** — à décider une fois le shader validé.

---

## Outils locaux

| Outil | Chemin |
|---|---|
| **Godot 4.7.1** | `C:\Users\tibo\Games\Godot\Godot_v4.7.1-stable_win64.exe` (+ `..._console.exe`) |
| Blender | 5.2.0 LTS — fichiers de travail dans `C:\Users\tibo\Documents\zeucozy_3d\` |
| Vault Obsidian | `C:\Users\tibo\ThibsVault\02 — Projets\jeu-video-godot\` |

Godot n'est **pas dans le `PATH`** — toujours l'appeler par son chemin complet.

```bash
# Réimporter les assets sans ouvrir l'éditeur
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --headless --import --path .
# Banc de test du cel-shading — mode interactif (orbite souris, touches O/P/A)
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/cel_test.tscn
# Banc de test — mode capture : 8 directions + sondes de skinning, puis quitte
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/cel_test.tscn -- --capture
```

> ⚠️ **Lancer le jeu (`scenes/main.tscn`) ne montre rien du travail 3D** : le gameplay est
> toujours en `Polygon2D` 2D, le chat n'y est pas branché. Tout le 3D vit dans le banc de test.

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
├── scenes/           # Scènes Godot (.tscn)
│   ├── main.tscn     # Scène principale (arène, UI, game manager)
│   ├── player.tscn   # Placeholder Polygon2D (ambre + contour brun)
│   ├── projectile.tscn
│   ├── xp_orb.tscn
│   └── enemies/
│       ├── chaser.tscn   # Ennemi rapide (spawn dès le début)
│       └── brute.tscn    # Ennemi costaud (spawn après 22s)
├── scripts/          # Logique GDScript
│   ├── main.gd       # Directeur de jeu, spawn, difficulté, UI
│   ├── player.gd     # Mouvement, attaque auto, upgrades, XP
│   ├── enemy.gd      # Comportement ennemi de base (follow, dégâts)
│   ├── projectile.gd # Projectile (direction, portée, collision)
│   ├── xp_orb.gd     # Orbe XP (magnétisme, collecte)
│   └── systems/
│       └── upgrade_definitions.gd  # Pool et définitions des upgrades
└── assets/
    └── models/       # Modèles 3D (glTF) — vide pour l'instant
```

---

## Systèmes clés

### Difficulté (main.gd)
- Scale temporelle : `1.0 + elapsed_time / 90.0`
- Intervalle de spawn : 0.95–1.35s, décroissant avec le temps
- Nombre d'ennemis par vague : 1 au début → 5 vers 140s

### Joueur — stats de base (player.gd)
- Speed 240 px/s | Health 6 | Attack interval 0.55s
- Projectile damage 1 | Speed 560 px/s | Range 360 px
- Pickup radius 72 px

### Upgrades (upgrade_definitions.gd)
6 types : `damage`, `attack_speed`, `move_speed`, `max_health`, `pickup_radius`, `projectile_speed`
3 choix aléatoires par level-up, sans doublons.

### XP (xp_orb.gd)
- Magnétisme déclenché à < 170 px du joueur
- Vitesse d'attraction proportionnelle à la proximité

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
Toute la logique de gameplay tourne — elle n'est pas affectée par le pivot graphique.

**Visuels :** **tout est placeholder.** Joueur et ennemis en `Polygon2D` vectoriel.
Aucun asset graphique final dans le dépôt.

**Prochaine priorité :** valider le pipeline glTF + shader cel-shading/contour dans Godot
avec le chat, avant toute autre modélisation.
