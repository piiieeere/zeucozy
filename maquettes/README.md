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

> ### ⚠️ Amendement du 2026-08-21 — une exception, et une seule
>
> Le **décor** se peint désormais : un volume grossier porte une **illustration 2D
> projetée** (DA §2quater). Cette illustration-là **est un asset**, et elle va dans
> `assets/textures/` — pas ici. Elle sort du prompt §4.8, et de lui seul.
>
> **Ce dossier garde sa version SOURCE** — pleine résolution, calques compris. C'est le
> garde-fou : une image dont on n'a que le PNG aplati à 1024 px est un cul-de-sac, et la
> raison d'origine de la règle reste vraie (*une image générée n'est ni rejouable ni
> corrigeable*).
>
> ⛔ **Le reste ne bouge pas.** Rien de ce qui **tourne** — chat, ennemis, ramassables,
> projectile, FX — ne prend de texture. L'UI non plus, sauf pour ce qui est déjà un
> tableau : DA §9.11 en donne la liste close.

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
