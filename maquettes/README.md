# Maquettes de référence

Les **images de référence** générées à partir des prompts de
`02 - Direction Artistique/Prompts de Génération.md` (vault Obsidian).

Une maquette est un **document de travail**, pas un asset. Elle décide la forme, la
composition et l'intention ; elle ne décide ni les valeurs de couleur (elles sortent de
§4 de la DA) ni l'épaisseur de trait (elle se mesure en jeu, en pixels).

## ⛔ Rien d'ici n'est un asset

Aucun fichier de ce dossier n'est chargé par le jeu, n'entre dans `assets/`, ne sert de
texture ni de calque de référence embarqué. Le style est **reconstruit dans le moteur** —
`cel_model.gd`, `cel_prop.gd`, les shaders — et c'est ce qui fait qu'un réglage corrigé au
banc profite au jeu sans recopie.

**`.gdignore` est là pour ça** : Godot importe tout ce qu'il trouve sous la racine du
projet, et sans ce fichier chaque PNG déposé ici sortirait dans le dock FileSystem et dans
`.godot/imported/`. Le fichier doit rester **vide** — son contenu est ignoré, il ne
comprend aucun motif à la `.gitignore`.
Voir `05 - Godot Docs/Best practices/Project organization.md`.

## Nommage

`<sujet>_<variante>_<date>.png` — `ui_carton_v2_0819.png`, `veto_blouse_0819.png`,
`sol_joints_0819.png`. Trois essais du même sujet se rangent alors ensemble, et on
retrouve à quel prompt les rattacher.

## Ce qu'on garde, ce qu'on jette

**La maquette qui a TRANCHÉ quelque chose reste ici**, et la décision qu'elle a produite
s'écrit dans le vault — c'est la décision qui se relit dans six mois, pas l'image.

Les variantes écartées sont **jetables** : les supprimer une fois le choix fait. Un
dossier de maquettes qui grossit à chaque essai finit par peser plus lourd que le code
qu'il a servi à écrire, et personne ne sait plus laquelle des huit images a été suivie.
