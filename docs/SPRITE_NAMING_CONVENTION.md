# Sprite Naming Convention

## Objectif

Definir une convention simple, stable et partagee pour nommer, stocker et valider les sprites du projet `Cozy Cat Survivor`.

Cette convention doit :
- accelerer l'integration dans Godot
- eviter les doublons et noms ambigus
- garder une structure lisible dans `assets/sprites/`

## Format recommande

- format : `PNG`
- fond : transparent
- source recommandee MVP : `64x64`
- un asset par fichier
- noms en `snake_case`
- uniquement ASCII
- pas d'espaces
- pas d'accents
- pas de majuscules

## Arborescence

Les sprites sont ranges dans :

- `assets/sprites/raw/`
  - exports bruts, variantes, versions de travail
- `assets/sprites/approved/`
  - version validee et canonique utilisee par le jeu
- `assets/sprites/sheets/`
  - sprite sheets ou regroupements de frames si necessaire plus tard

## Convention de nommage

### Fichiers bruts

Pattern :

`{category}_{name}_v##.png`

Exemples :

- `player_cat_v01.png`
- `enemy_vacuum_v01.png`
- `enemy_dog_v01.png`
- `enemy_cucumber_v01.png`
- `xp_kibble_v01.png`
- `projectile_yarn_ball_v01.png`

### Fichiers approuves

Pattern :

`{category}_{name}.png`

Exemples :

- `player_cat.png`
- `enemy_vacuum.png`
- `enemy_dog.png`
- `enemy_cucumber.png`
- `xp_kibble.png`
- `projectile_yarn_ball.png`

## Categories recommandees

- `player`
- `enemy`
- `xp`
- `projectile`

Categories possibles plus tard :

- `boss`
- `pickup`
- `ui`
- `fx`

## Variantes

Si un asset a plusieurs variantes visuelles, ajouter un suffixe clair avant la version :

- `player_cat_idle_v01.png`
- `player_cat_move_v01.png`
- `enemy_dog_alt_v02.png`

Version approuvee correspondante :

- `player_cat_idle.png`
- `player_cat_move.png`

## Frames separees

Si une animation est livree frame par frame :

- `player_cat_idle_f01.png`
- `player_cat_idle_f02.png`
- `player_cat_move_f01.png`

## Sprite sheets

Si une animation est regroupee en feuille :

- `player_cat_idle_sheet.png`
- `enemy_dog_move_sheet.png`

Ces fichiers vont dans :

- `assets/sprites/sheets/`

## Regle de validation

- `raw` peut contenir plusieurs versions
- `approved` ne doit contenir qu'une seule version canonique par asset utilise en jeu
- tout nouveau sprite integre en production doit venir de `approved`

## Set MVP recommande

Sprites a preparer en priorite :

- `assets/sprites/raw/player_cat_v01.png`
- `assets/sprites/raw/enemy_vacuum_v01.png`
- `assets/sprites/raw/enemy_dog_v01.png`
- `assets/sprites/raw/enemy_cucumber_v01.png`
- `assets/sprites/raw/xp_kibble_v01.png`
- `assets/sprites/raw/projectile_yarn_ball_v01.png`

Puis, apres validation :

- `assets/sprites/approved/player_cat.png`
- `assets/sprites/approved/enemy_vacuum.png`
- `assets/sprites/approved/enemy_dog.png`
- `assets/sprites/approved/enemy_cucumber.png`
- `assets/sprites/approved/xp_kibble.png`
- `assets/sprites/approved/projectile_yarn_ball.png`

## Regles pratiques

- une seule idee visuelle par asset
- silhouette lisible a petite taille
- conserver une taille et une logique de cadrage coherentes entre assets similaires
- ne pas multiplier les suffixes inutiles
- si un sprite manque, creer un placeholder temporaire clairement nomme

## References projet

- contexte gameplay : `docs/game_design.md`
- direction artistique : `docs/VISUAL_ART_DIRECTION.md`
- prompts de generation : `docs/SPRITE_PROMPTS.md`
- template d'integration : `docs/CODEX_ASSET_TASK_TEMPLATE.md`
