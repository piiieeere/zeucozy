# CLAUDE.md — Zeucozy

Guide de référence pour Claude Code sur ce projet. Lire les docs listés ci-dessous avant toute tâche non triviale.

---

## Projet

**Zeucozy** est un jeu action-roguelite 2D cozy à thème chat, de type survivor. Le joueur contrôle un chat qui survit à des vagues d'ennemis (aspirateur, chien, concombre), collecte des croquettes (XP) et choisit des améliorations à chaque niveau.

- **Moteur :** Godot 4.7 — GDScript idiomatique Godot 4
- **Physique :** Jolt Physics
- **Plateforme cible :** Windows (DirectX 12), dev sous VS Code
- **Dépôt :** `https://github.com/piiieeere/zeucozy.git`
- **Branche principale :** `master` — branche de travail : `dev`

---

## Documentation de référence

Lire ces fichiers avant toute tâche concernant le domaine correspondant :

| Fichier | Contenu |
|--------|---------|
| [docs/game_design.md](docs/game_design.md) | Manifeste du jeu — boucle de gameplay, ennemis, upgrades, équilibre |
| [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md) | Contraintes de développement, préférences, à lire EN PRIORITÉ |
| [docs/VISUAL_ART_DIRECTION.md](docs/VISUAL_ART_DIRECTION.md) | Direction artistique complète — palette, style, principes visuels |
| [docs/SPRITE_NAMING_CONVENTION.md](docs/SPRITE_NAMING_CONVENTION.md) | Convention de nommage et pipeline d'assets |
| [docs/CODEX_ASSET_TASK_TEMPLATE.md](docs/CODEX_ASSET_TASK_TEMPLATE.md) | Workflow d'intégration de sprites |
| [docs/MVP_ROADMAP.md](docs/MVP_ROADMAP.md) | Critères de succès du prototype |
| [docs/todo.md](docs/todo.md) | Suivi des features en cours |

---

## Architecture

```
zeucozy/
├── scenes/           # Scènes Godot (.tscn)
│   ├── main.tscn     # Scène principale (arène, UI, game manager)
│   ├── player.tscn
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
├── assets/sprites/
│   ├── raw/          # Assets en cours (versionnés : _v01, _v02…)
│   ├── approved/     # Assets validés, prêts pour la prod
│   └── sheets/       # Sprite sheets / frames d'animation
└── docs/             # Documentation complète du projet
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

> Tiré de [docs/AI_CONTEXT.md](docs/AI_CONTEXT.md) — ces règles priment sur les instincts par défaut.

- **Fournir des scripts complets** lors de modifications, jamais des extraits partiels.
- **Ne pas complexifier** — architecture simple et modulaire, pas d'abstractions spéculatives.
- **Respecter l'arborescence** : `scenes/`, `scripts/`, `assets/`.
- **Langue UI :** Français (labels, titres d'upgrades, descriptions).
- **Pas de dépendances externes** sans demande explicite.
- **Itérations rapides et testables** — les changements doivent être vérifiables immédiatement dans Godot.
- **Nord étoile :** *"Rendre le jeu plus fun, plus mignon, sans complexifier."*

---

## Conventions d'assets

- **Raw :** `{catégorie}_{nom}_v##.png` ex. `player_cat_v01.png`
- **Approved :** `{catégorie}_{nom}.png` ex. `player_cat.png`
- **Catégories valides :** `player`, `enemy`, `xp`, `projectile`, `boss`, `pickup`, `ui`, `fx`
- Raw → `assets/sprites/raw/` | Approved → `assets/sprites/approved/`

---

## État actuel

**Systèmes en place :** mouvement 8 directions, spawn ennemis, attaque auto, XP/niveaux, 6 upgrades, scaling difficulté, HUD complet, Game Over/restart, arène large.

**En cours :** intégration des sprites — `player_cat_v01.png` créé, pas encore approuvé.

**Prochaine priorité :** remplacer les visuels vectoriels placeholder par les vrais sprites.
