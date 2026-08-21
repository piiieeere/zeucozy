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

> ⚠️ **CE CHAPITRE PARLE DU CHAT DE 2026-08-16.** Le chat du jeu est le **chat tuxedo**
> du 2026-08-20, reconstruit d'un script (`tools/build_cat_tuxedo.py`) d'après
> `maquettes/CatTuxedo.png` — voir « LE CHAT A ETE REMODELISE » dans l'état actuel, et
> [[Le chat — style, pelage, fluidité]] pour le détail. Les six pièges ci-dessous
> **valent toujours** : ils portent sur le pont Blender → glTF → Godot, pas sur un modèle.
> Seul le n°3 a été précisé — les poids ne sont plus rigides partout, et ce que la règle
> protégeait est désormais **vérifié par le script** au lieu d'être tenu par convention.

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
# ⭐ LE CHAT DU JEU — le chat tuxedo (2026-08-20), d'apres maquettes/CatTuxedo.png.
#    Le .blend est REGENERE a chaque fois, jamais edite a la main : geometrie, rig,
#    poids et Attr_Style ont la meme source. Les trois commandes vont ensemble et
#    dans cet ordre — sans la 2e, le .glb sort sans animation.
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup   --python tools/build_cat_tuxedo.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background   "C:/Users/tibo/Documents/zeucozy_3d/chat_tuxedo_v1.blend"   --python tools/build_animations.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background   "C:/Users/tibo/Documents/zeucozy_3d/chat_tuxedo_v1.blend"   --python tools/export_cat.py -- --mesh=MSH_chat_tuxedo --out=player_cat_tuxedo.glb
# ⚠️ Puis --headless --import, ET VERIFIER `animation/fps=60` dans le .import : Godot
#    y ecrit 30 par defaut, ce qui detruit la cadence en pas (piege n°4).
#
# ─── Le chat de 2026-08-16, garde dans le depot mais plus charge par le jeu ─────
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
#   --model=res://assets/models/player_cat.glb   l'autre chat, pour comparer
#   --mouth-open=1     la GUEULE OUVERTE (rien ne l'anime encore)
#   --pitch=26         camera dans l'axe du visage — le cadrage ou se juge le dessin
#   --out=<dossier>    ou ecrire les PNG
# Reconstruire puis exporter le canape (le .blend est REGENERE, jamais edite a la main)
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup \
  --python tools/build_couch.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
  "C:/Users/tibo/Documents/zeucozy_3d/prop_canape_v1.blend" \
  --python tools/export_prop.py -- --mesh MSH_canape --out prop_canape.glb
# Reconstruire puis exporter la CROQUETTE (meme moule : .blend REGENERE)
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup   --python tools/build_kibble.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background   "C:/Users/tibo/Documents/zeucozy_3d/xp_croquette_v1.blend"   --python tools/export_prop.py -- --mesh MSH_croquette --out xp_croquette.glb
# Reconstruire puis exporter la BOULE DE POILS (le projectile) — meme moule
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup   --python tools/build_hairball.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background   "C:/Users/tibo/Documents/zeucozy_3d/projectile_boule_poils_v1.blend"   --python tools/export_prop.py -- --mesh MSH_boule_poils --out projectile_boule_poils.glb
# Reconstruire puis exporter le CHIEN (la BRUTE) — meme moule
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup   --python tools/build_dog.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background   "C:/Users/tibo/Documents/zeucozy_3d/enemy_chien_v1.blend"   --python tools/export_prop.py -- --mesh MSH_chien --out enemy_chien.glb
# Reconstruire puis exporter la SOURIS (le 1er ennemi modelise) — meme moule
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup   --python tools/build_mouse.py -- --save
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background   "C:/Users/tibo/Documents/zeucozy_3d/enemy_souris_v1.blend"   --python tools/export_prop.py -- --mesh MSH_souris --out enemy_souris.glb
# Banc des modeles sans squelette — 8 directions + le chat a cote, au cadrage de jeu
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64.exe" --path . res://scenes/tests/prop_test.tscn -- --capture
#   --model=res://assets/models/xp_croquette.glb   n'importe quel .glb sans squelette
#   --model=res://assets/models/projectile_boule_poils.glb
#   --model=res://assets/models/enemy_souris.glb
#   --model=res://assets/models/enemy_chien.glb
#   (par defaut le canape ; le cadrage se deduit de la boite englobante)
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
# Le MUR A BAIES et son SOLEIL — le chat colle au mur, sinon on ne voit rien
"C:/Users/tibo/Games/Godot/Godot_v4.7.1-stable_win64_console.exe" --path .   --write-movie <dossier>/g.png --fixed-fps 30 --quit-after 60 -- --aim=160 --spawn=0,-40
#   --spawn=x,z      ou le chat commence — le mur n'entre au cadre qu'a la bordure
#   --sun=off        LE TEST D'ACCEPTATION de §6bis : lampe coupee = le jeu d'avant
#   --sun-elev=18    hauteur du soleil — c'est elle qui decide si le rai entre au cadre
#   --sun-yaw=200    azimut ; 180 = le soleil traverse le mur du fond
#   --sun-distance=  portee de la carte d'ombre (defaut 80 m — PAS ce que voit la camera)
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
| `02 - Direction Artistique/Prompts de Génération.md` | Les prompts de **maquette** — sol, meubles, UI, boss vétérinaire, coffres. Réécrit le 2026-08-19 : la partie sprites 2D a été supprimée |
| `04 - Roadmap/Todo.md` | Suivi des features en cours |

> 📦 **Archivés** (pipeline 2D abandonné, conservés pour référence historique) :
> `Pipeline Sprites.md`, `Convention de Nommage Sprites.md`,
> `Template Intégration Assets.md`.

### Le journal technique — `06 - Journal technique/` (sorti de CLAUDE.md le 2026-08-19)

**Le journal des décisions et des pièges vit désormais dans le vault**, en dix notes.
Ce fichier-ci est chargé à chaque session : il doit porter ce qu'il faut savoir **avant**
de toucher au code — chemins, commandes, arborescence, règles, état. Le récit d'un
chantier, lui, se consulte **quand on entre dans son domaine**, et c'est de la
documentation.

> ⚠️ **CE N'EST PAS DE L'ARCHIVE, C'EST DE LA DOC À LIRE.** Chacune de ces notes porte des
> pièges mesurés qui coûteront une journée à quiconque les redécouvre. **Ouvrir la note du
> domaine avant d'y travailler** est au même rang que lire le manuel Godot : chercher coûte
> une commande, se tromper coûte une refonte.

> ⚠️ **Les renvois « voir « … » plus haut / plus bas » qui restent dans CLAUDE.md
> désignent un chapitre de ces notes**, pas un passage de ce fichier. Le tableau
> ci-dessous dit lequel — et rien n'a été réécrit au passage, ce sont les mêmes lignes.

| Note (vault) | Ce qu'elle porte |
|---|---|
| [[Le chat — style, pelage, fluidité]] | Cel-shading, contour, pelage tuxedo, **cadence en pas**, griffes dessinées. ⚠️ Le jeu a paru tourner à 20 fps alors qu'il tenait 60,0 — c'est là. |
| [[Le rendu — antialiasing]] | Les trois familles de bords et ce qui les lisse. **MSAA 4×** sur la silhouette, et le réglage qui n'était juste qu'au banc. |
| [[Le combat — griffure, visée, actifs]] | Griffure dirigée, visée souris, WASD + deux clics, morsure, onomatopées. |
| [[Les compétences — socle et contenu]] | AUTO / ACTIF / PASSIF, paliers T1→T3, slots, tirage pondéré, carton de remplacement, et les 13 entrées du catalogue. |
| [[L'interface — les deux refontes]] | Orbitals pour la place, Bebop/Eva pour la couleur. Cartons, cartes de choix, jauges, bilingue. |
| [[Les FX — éclat de collision]] | Le seul retour de dégât depuis que le flash plein cadre est débranché. |
| [[L'architecture — pause, injection, chiffres]] | `get_tree().paused`, l'injection à la place des recherches de groupe, et un stat de gameplay porté à **deux endroits**. |
| [[Les modèles — le décor]] | Le canapé procédural, la première collision du jeu, le trait du décor à 50 %. |
| [[Les modèles — ramassables et projectile]] | Croquette et boule de poils. ⚠️ **C'est l'encre qui borne la forme** sur un petit modèle, pas le budget de triangles. |
| [[Les modèles — les ennemis]] | Souris et chien, et le **visage peint** qui a annulé leur entorse commune à §2bis. |
| [[Le mur — les baies et le soleil réel]] | Les baies percées et la **1ʳᵉ `Light3D` du projet**. ⚠️ Godot multiplie `DIFFUSE_LIGHT` par `ALBEDO` **après** `light()` — c'est là. |

```bash
# Chercher dans tout le journal (le dossier a des espaces : garder les guillemets)
grep -rn "coque inversee" "C:/Users/tibo/ThibsVault/02 — Projets/jeu-video-godot/06 - Journal technique"
```

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
│   ├── projectile.tscn # 🌀 La boule de poils — porté par `hairball_skill`
│   ├── xp_orb.tscn
│   ├── enemies/
│   │   ├── chaser.tscn   # 🐭 Ennemi rapide (spawn dès le début) — LA SOURIS
│   │   └── brute.tscn    # Ennemi costaud (spawn après 22s) — LE CHIEN
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
│   ├── projectile.gd # 🌀 La boule de poils en vol : direction, roulis, portée
│   ├── xp_orb.gd     # Croquette d'XP (magnétisme, collecte)
│   ├── arena.gd      # Décor : sol, tapis, mobilier, MUR À BAIES + le soleil
│   ├── camera_rig.gd # Vue plongeante 45°, suit le joueur, bornée à l'arène
│   ├── skills/       # ⭐ LES COMPÉTENCES — une par fichier, toutes au même contrat
│   │   ├── skill.gd         # Le contrat : setup / set_tier / tick. Aucune n'a de _process
│   │   ├── active_skill.gd  # Le socle des ACTIFS — cooldown, garde à froid, charge
│   │   ├── claw_skill.gd    # ⚔️ La griffure — slot AUTO n°1, l'arme DIRIGÉE
│   │   ├── hairball_skill.gd # 🌀 La boule de poils — AUTO à distance, auto-visée
│   │   ├── dust_skill.gd    # 🌫️ Les moutons — AUTO semé derrière, récompense de BOUGER
│   │   ├── bite_skill.gd    # 🦷 La morsure — le 1ᵉʳ ACTIF, cible unique
│   │   ├── hiss_skill.gd    # 💢 Le feulement — ACTIF de RECUL, ne compte pas en dégâts
│   │   ├── purr_skill.gd    # 💤 Le ronron — ACTIF de SOIN, le 3ᵉ, en 4 bouffées
│   │   └── breath_skill.gd  # 💨 L'haleine puante — pilote l'aura, pas son dessin
│   ├── systems/
│   │   ├── skill_definitions.gd    # ⭐ LE catalogue — types, paliers, poids de tirage
│   │   ├── skill_set.gd            # ⭐ Ce que le chat PORTE — build, horloge, et
│   │   │                           #    l'ÉCHANGE de slot (`replace`)
│   │   ├── cel_style.gd            # Matériaux cel des primitives, du sol + ombre de contact
│   │   ├── cel_model.gd            # ⭐ Le style du chat — partagé jeu ↔ banc de test
│   │   ├── cel_prop.gd             # ⭐ Le style des .glb sans squelette — 2 familles :
│   │   │                           #    meuble (trait a 50 %) · pickup (trait plein)
│   │   ├── sun_rig.gd              # ☀️ LE SOLEIL — la 1ʳᵉ Light3D du projet. Posé par
│   │   │                           #    l'arène ET par le banc, jamais recopié (§6bis)
│   │   ├── fx_cadence.gd           # ⭐ Les 3 durées de pose des FX (§7) — source unique
│   │   ├── render_quality.gd       # 🪞 L'AA de la 3D — MSAA 4×, + `--msaa=` / `--ssaa=`
│   │   ├── driven_fx.gd            # ⭐ `class_name DrivenFx` — les FX dont l'horloge vient
│   │   │                           #    de DEHORS (aura, mouton, onde). Une méthode :
│   │   │                           #    `advance(delta)`. Les FX autonomes n'en sont pas
│   │   ├── breath_aura.gd          # 💨 L'haleine puante — aura lootable, poses + morsure
│   │   ├── bite_fx.gd              # 🦷 Les mâchoires de la morsure — 8 poses, crocs dessinés
│   │   ├── shout_fx.gd             # 💥 L'onomatopée des ACTIFS — CHOMP, en pas, dans le monde
│   │   ├── hiss_ring.gd            # 💢 L'onde du feulement — 6 poses, pousse par le FRONT
│   │   ├── purr_halo.gd            # 💤 Le halo du ronron — 2 arches, 4 bouffées de 6 poses
│   │   ├── dust_bunny.gd           # 🌫️ Une touffe — naissance / repos / pouf, 3 cadences
│   │   ├── skill_thumb.gd          # 🖼️ La vignette d'une compétence — le VRAI FX en SubViewport
│   │   ├── ui_style.gd             # ⭐ Le style de l'interface — palette, polices, cadence
│   │   ├── locale.gd               # ⭐ TOUS les textes du jeu — français + anglais
│   │   ├── settings_store.gd       # Préférences du joueur sur disque (user://settings.cfg)
│   │   ├── impact_frame.gd         # 💤 Flash ambré plein cadre — DÉBRANCHÉ, gardé entier
│   │   └── hit_burst.gd            # 💥 Éclat de collision — étoile de manga, 6 poses
│   ├── ui/
│   │   ├── hud.gd       # 🖥️ Le HUD + les 4 cartons (niveau · REMPLACER · K.O. ·
│   │   │                #    réglages), construits EN CODE depuis ui_style
│   │   └── tier_pips.gd # 🔶 Le palier en LOSANGES, sur la carte de compétence.
│   │                    #    ⚠️ DESSINÉ : nos polices sous-ensemblées n'ont pas ◆
│   └── tests/
│       ├── cel_test.gd  # Cadrage, bascules et captures du banc du chat
│       ├── prop_test.gd # Banc des .glb sans squelette : 8 directions + taille au chat
│       ├── motion_probe.gd # ⏱️ Fluidité : temps de frame + battement sur 3 frames
│       └── pause_probe.gd  # ⏸️ Pause : 18 verdicts sur `get_tree().paused` + process_mode
├── shaders/          # cel_toon, cel_outline, cel_face, cel_paws, retro_post
│                     # cel_wall (le mur d'arène : 2 tons + cimaise, encre à 50 %)
│                     # cel_sun (include) — ⭐ L'OMBRE PORTÉE, et la fonction light()
│                     #           du projet. Une seule définition, six shaders
│                     # ui_frame (plaque grise, angles droits, repères d'angle,
│                     #           + le RELIEF : biseau, facette, TRANCHE, ombre dure.
│                     #           ⚠️ ses px sont ceux du LAYOUT depuis le 08-20)
│                     # ui_speedlines (lignes de vitesse)
│                     # bite (la morsure — gencives rouges + crocs de chat qui s'engrènent)
                     # hiss_ring (le feulement — onde crème/encre, le seul FX sans chroma)
                     # purr_halo (le ronron — 2 arches menthe, le seul FX SANS PORTÉE)
                     # dust_bunny (le mouton de poussière — touffe cernée posée au sol)
│                     # cel_paws (bouts de pattes + les 3 griffes dessinées)
│                     # cel_creature_face (yeux + truffe des ENNEMIS, peints)
│                     # cel_ground (parquet peint), cel_rug (tapis)
│                     # hit_burst (éclat de collision), impact_frame (flash, en sommeil)
│                     # claw_slash (la griffure — 3 traits cernés, billboard dirigé)
│                     # breath_aura (l'haleine puante — volutes cernées, décalque AU SOL)
│                     # cel_core + cel_floor (includes, fonctions pures)
├── tools/
│   ├── setup_input_map.gd  # ⌨️ La carte d'entrées (WASD + clics), rejouable
│   ├── build_cat_tuxedo.py # ⭐ LE CHAT DU JEU (2026-08-20) — géométrie, rig, poids
│   │                       #    et Attr_Style d'un bloc, d'après la maquette.
│   │                       #    5 068 tris contre 13 028 au chat de 2026-08-16
│   ├── export_cat.py       # ⚠️ LE SEUL chemin d'export des DEUX chats (piège n°6).
│   │                       #    `--mesh=` / `--out=` ; les défauts = chat de 08-16
│   ├── build_animations.py # Construit idle/walk posées en pas, dans le .blend
│   ├── paint_tuxedo.py     # Pelage noir/blanc : matériau des extrémités + couleurs
│   ├── build_outline.py    # Contour Blender : épaisseur × Attr_Style.R, 1 encre / surface
│   ├── build_couch.py      # Canapé : géométrie ET Attr_Style, dans un .blend neuf
│   ├── build_kibble.py     # Croquette : trèfle à 3 lobes, 300 tris, même moule
│   ├── build_hairball.py   # Boule de poils : amas à 6 touffes + 3 mèches, 308 tris
│   ├── build_mouse.py      # 🐭 Souris : goutte + 2 oreilles + queue, 1 132 tris
│   ├── build_dog.py        # 🐶 Chien (la brute) : goutte + museau + 2 oreilles
│   │                       #    tombantes + 4 pattes + queue, 1 610 tris
│   ├── export_prop.py      # Export générique d'un .glb, même réinjection COLOR_0
│   ├── fetch_fonts.ps1     # Récupère les polices d'UI en sous-ensembles (rejouable)
│   └── dump_paws.gd        # Relève os porteurs + boîtes de repos — source des PAWS
├── assets/
│   ├── models/       # player_cat_tuxedo.glb ⭐ (le chat du jeu), player_cat.glb
│   │                 # (celui de 2026-08-16, gardé, plus chargé),
│   │                 # prop_canape.glb, xp_croquette.glb,
│   │                 # projectile_boule_poils.glb, enemy_souris.glb,
│   │                 # enemy_chien.glb
│   └── fonts/        # Dela Gothic One + Zen Kaku Gothic New, sous-ensembles + OFL
└── maquettes/        # 🖼️ Images de RÉFÉRENCE — jamais des assets, jamais chargées
                      # par le jeu. Prompts dans `Prompts de Génération.md` (vault).
                      # ⚠️ `.gdignore` VIDE obligatoire : sans lui Godot importe
                      #    chaque PNG dans le dock et dans `.godot/imported/`
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
**1 mètre ≈ 20 px** de l'ancienne version 2D. Le chat mesure **1,87 unité** (1,858 pour
celui de 2026-08-16 — la hauteur a été tenue exprès, c'est l'échelle de tout le décor). L'arène fait
**160 × 90 m**, le cadre en montre ~29 m de large et ~25 m de profondeur au sol (16 m
devant le point visé, 9 m derrière) — soit un chat à ~11 % de la hauteur d'écran.
Le réglage à bouger en premier si le chat paraît trop petit est `distance` dans
`camera_rig.gd` (38 m), pas le FOV.
⚠️ `arena_margin` vaut **(14, 13)** depuis le 2026-08-20, pas (17, 16) : c'est ce qui fait
entrer le mur et ses baies dans la bande haute du cadre. Hauteur du mur et marge ne se
décident pas séparément.

### Joueur — stats de base

**Le corps** (`player.gd`) : Speed 7,5 m/s | **Vie 100 points** | **Aimant 1,8 m**
*(2,5 avant le 2026-08-19 — et il en valait 5,0 en vrai, voir « L'aimant » plus bas)*

**Les armes** (`skill_definitions.gd`, jamais sur le chat) — valeurs par palier :

| | T1 | T2 | T3 |
|---|---|---|---|
| **Griffure** *(dégât / cadence / portée)* | 3 · 1,10 s · 5,2 m | 4 · 0,94 s · 5,65 m | 5 · 0,80 s · 6,1 m |
| **Boule de poils** *(dégât / cadence / portée / vitesse)* | 2 · 1,60 s · 11 m · 7 m/s | 3 · 1,35 s · 13 m · 8,5 m/s | 4 · 1,10 s · 15 m · 10 m/s |
| **Morsure** *(dégât / portée / recharge)* | 7 · 3,6 m · 6,0 s | 10 · 4,0 m · 5,0 s | 14 · 4,4 m · 4,2 s |
| **Haleine** *(rayon / dégât par morsure)* | 2,8 m · 1 | 3,35 m · 2 | 3,9 m · 3 |
| **Moutons** *(dégât / cadence / vie / rayon)* | 3 · 0,55 s · 3,5 s · 0,75 m | 4 · 0,46 s · 4,4 s · 0,85 m | 6 · 0,42 s · 5,0 s · 0,95 m |
| **Feulement** *(rayon / dégât / recharge)* | 3,6 m · 1 · 11,0 s | 4,3 m · 2 · 9,5 s | 5,0 m · 3 · 8,0 s |
| **Ronron** *(soin total / recharge)* | 18 · 14,0 s | 28 · 12,0 s | 40 · 10,0 s |

Arc frontal de griffure **120°, à tous les paliers** — l'ancienne description promettait un
balayage « plus large », le code ne l'a jamais fait.

> ⚠️ **La boule de poils a été RALENTIE DEUX FOIS le 2026-08-19** — 17,5 / 19 / 21, puis
> 10 / 12 / 14, enfin **7 / 8,5 / 10 m/s** — et le passif **`projectile_speed`** multiplie
> cette base (×1,30 / 1,60 / 2,00). Voir « La boule de poils modélisée » plus bas : la
> vitesse et la portée montent **ensemble**, donc le temps de vol reste constant
> (1,57 / 1,53 / 1,50 s) aux trois paliers.
>
> ⚠️ **7 m/s est la vraie borne basse : c'est la vitesse du chat** (7,5 m/s). En dessous, il
> rattraperait ses propres boules, et un projectile qu'on double ne se lit plus comme un
> tir.
>
> ⚠️ **Les trois `@export` du projectile en sommeil ont disparu de `player.gd`** le même
> jour, avec `_fire_at_nearest_enemy`. Ils promettaient « le jour où il revient, il revient
> en compétence » — c'est fait depuis le 2026-08-17, et `hairball_skill.gd` faisait déjà
> exactement ce que faisait cette méthode. La scène, `projectile.gd` et
> `main.spawn_projectile`, eux, **servent**.

### XP (xp_orb.gd)
- Magnétisme déclenché sous **`player.pickup_radius`** — 1,8 m au départ, jusqu'à 5,05 m
  avec le passif. Relu **à chaque frame**, jamais capturé au `setup()` : une croquette
  déjà au sol quand le joueur prend l'aimant doit se mettre à venir.
- Vitesse d'attraction proportionnelle à la proximité
- ⚠️ **Ce chiffre a été porté à DEUX endroits pendant des mois**, et c'est toujours le plus
  fort qui gagnait : `xp_orb` avait sa propre constante à 5,0 m, au-dessus des trois paliers
  du passif, qui n'améliorait donc rien avant son T3. Détail dans
  [[L'architecture — pause, injection, chiffres]].

### Interpolation physique
`common/physics_interpolation=true` dans `project.godot`. Deux conséquences à ne pas
reperdre :
- ce qui bouge doit bouger **dans `_physics_process`** — projectiles et croquettes ont été
  déplacés de `_process` pour cette raison ;
- après avoir placé un nœud fraîchement instancié, appeler **`reset_physics_interpolation()`**,
  sinon il part en traînée depuis l'origine du monde sur sa première frame.

Le rig de caméra fait exception : il bouge dans `_process`, donc son interpolation est
**désactivée** et il lit la position du joueur via `get_global_transform_interpolated()`.

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

- **Modèles 3D :** `assets/models/{catégorie}_{nom}.glb` ex. `player_cat_tuxedo.glb`
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

**La boule de poils est modélisée et ralentie depuis le 2026-08-19** — voir « La boule de
poils modélisée » plus bas. Le projectile est un amas de fourrure à 6 touffes, dans la couleur du chat, qui **roule** sur
son axe de vol à 7 m/s au lieu de 17,5. Le ralentissement n'est pas un effet de bord du
modèle, c'est sa condition : à l'ancienne vitesse la boule sautait la moitié de sa propre
longueur d'une frame à l'autre. Il ouvre au passage la place du passif **`projectile_speed`**,
qui avait été sorti du pool le 2026-08-16 faute d'améliorer quoi que ce soit de visible.

**Le relief des cartes est amplifié depuis le 2026-08-20** — voir §9.9 A bis de la DA. Les
cartes ont gagné une **tranche** (le côté de l'objet, cerné, 5 px) et une ombre de 6 px :
3 px d'épaisseur totale avant, **11** aujourd'hui. `relief` est passé de booléen à **deux
niveaux** — le carton porte moins de volume que ce qu'il contient, sinon il flotte à côté.
Un uniform **`relief_scale`** est en place pour le survol et le clic, qui restent à faire.

> ⛔ **ET LE PIXEL DU SHADER D'UI N'ÉTAIT PAS LE PIXEL DU LAYOUT** — depuis le 2026-08-17,
> jamais vu. `1.0 / fwidth(UV)` mesure en pixels de **framebuffer** ; avec
> `stretch/mode="canvas_items"` le layout, lui, reste sur la base 1152 × 648. Sur un écran
> à 2,5×, un `border_px` de 2 sortait à 0,8 px et un biseau de 3 px à **1,2** — d'où des
> réglages montés pour compenser une cause qu'on n'avait pas trouvée, et une UI qui n'avait
> pas le même dessin sur deux machines. Réparé par une varying (`VERTEX` est en pixels
> locaux). ⚠️ **Les captures d'UI d'avant le 2026-08-20 ne sont plus comparables** : filets,
> repères d'angle et biseaux y sont 2,5× plus fins.

**Le mur porte des BAIES et le soleil les traverse — le 2026-08-20.** C'est la
**première `Light3D` du projet** : la fermeture du 2026-08-18 sur les lumières est
renversée, avec sa date, en §6bis de la DA. Le mur passe de quatre boîtes nues de 1,2 m à
quatre parois de **travées de 8 m** (2,6 m de haut, 0,6 m d'épaisseur), chacune percée d'un
**vrai trou** de 3,6 m à 2 meneaux et 1 traverse — et une `DirectionalLight3D` à 26° pose
un rai sur le sol, sur le mobilier et sur ce qui passe dedans. Tout est dans
[[Le mur — les baies et le soleil réel]]. Les trois choses à savoir avant d'y toucher :

- ⭐ **La lumière S'AJOUTE, elle ne REMPLACE rien.** L'aplat peint part en `EMISSION`,
  `light()` ne fait que **retrancher** un pas d'ombre chaude là où une ombre **portée**
  tombe. Ombre propre, accents, contour : inchangés. ✅ **Test d'acceptation vérifié en
  capture : `--sun=off` rend 0 pixel de différence avec le dépôt d'avant le chantier.**
- ⚠️ **Godot multiplie `DIFFUSE_LIGHT` par `ALBEDO` APRÈS `light()`**, et le manuel ne le
  dit qu'en creux. Un `painted` de trop dans la formule et l'ombre sort en
  `painted − painted²` : elle s'affaiblit sur les surfaces sombres, vire au bleu, et la
  molette de contraste ment. Muet et plausible — une demi-journée.
- ⛔ **Ce qui BOUGE reçoit le soleil et ne le PROJETTE pas** (chat, ennemis, ramassables).
  Un corps qui entre dans sa propre carte d'ombre se ré-ombre tout seul : au banc, une
  oreille posait une bande dure en travers du crâne. Le mobilier, lui, caste.

`camera_rig.arena_margin` a suivi — **(17, 16) → (14, 13)**, et **dans le sens inverse de
celui qu'annonçait §4.7** : à 16, le pied du mur affleurait déjà le bord haut, donc le mur
n'était **jamais** dans l'image. Le mur ne bloque toujours pas — c'est `clamp_to_arena()`
qui tient la limite.

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

**Le 3ᵉ actif est posé le 2026-08-19** — le **ronron**, voir « Le ronron » plus bas. Le
catalogue passe à **13 entrées**, et surtout la famille ACTIF compte désormais **trois
compétences pour deux slots** : c'est ce qui rend le carton de remplacement (chantier 2)
**exerçable en jeu**, ce qu'il n'était pas à deux — `roll` n'avait rien à proposer en
échange. ✅ Vérifié par sonde : `bite` + `hiss` pris, `purr` T1 ne sort plus d'aucun des
8 tirages.

**Le carton de remplacement est posé le 2026-08-19** — chantier 2 de §2.9, voir « Le
carton de remplacement » plus haut. Une compétence neuve d'une famille saturée redevient
tirable, et la choisir ouvre un second carton : **qui cède sa slot ?** La nouvelle prend la
place exacte de l'ancienne, donc la survivante garde sa touche. La difficulté annoncée —
un carton empilé sur un carton — **n'existait pas** : une fois la carte cliquée, le carton
de niveau n'attend plus rien.

**Restent à faire :** les **zoomies**, 4ᵉ actif déjà spécifié (voir « Les zoomies » plus
bas) ; les ultimes T4 ; et le reste du contenu (~6 auto, ~2 actifs de plus).

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

**Et une 3ᵉ passe le 2026-08-19, sur le CONTRASTE cette fois** — d'après
`maquettes/panelwithcards2.png`, une planche qui compare quatre couples carton × carte
(variante 3 retenue). Le carton et ses cartes se tenaient à **1,39:1** : une seule masse
grise. Le carton descend à `#2E2E2C`, la carte monte à `#6E6C66` — **2,59:1**. ⚠️ **Les
deux valeurs bougent ENSEMBLE, et une carte plus claire efface tout ce qu'on pose dessus** :
les trois bandeaux de type sont devenus des pastilles **sombres** à lettrage crème (l'ACTIF
tombait à 1,22:1), le texte de carte est passé en crème plein, et les plaques en relief ont
leur filet à elles, `RULE_RAISED`, **sombre**. Le palier passe en **losanges dessinés**
(`tier_pips.gd`). Détail et mesures dans [[L'interface — les deux refontes]].

**LE CHAT A ETE REMODELISE LE 2026-08-20**, d'après `maquettes/CatTuxedo.png` (7 vues),
`maquettes/CatTuxedoFace.png` (le visage de face, gueule fermée et ouverte) et
`maquettes/CatTuxedoWalk.png` (marche, 6 poses). Tout est dans
[[Le chat — style, pelage, fluidité]]. Ce qu'il faut savoir avant d'y toucher :

- ⭐ **Il se reconstruit d'un script**, `tools/build_cat_tuxedo.py` — géométrie, rig, poids
  et `Attr_Style` d'un seul bloc, comme le canapé, la souris et le chien. Le `.blend`
  (`chat_tuxedo_v1.blend`) est **régénéré, jamais édité à la main** ; le chat de
  2026-08-16, lui, était un `.blend` source sans garde-fou, et il a coûté une passe de
  pelage perdue.
- **5 068 tris contre 13 028**, 5 surfaces contre 7, et une tête à 39 % de la hauteur au
  lieu de 54 %. L'ancien `player_cat.glb` **reste dans le dépôt** : il se recharge au banc
  par `--model=`, et `ANCHORS` dans `cel_model.gd` garde ses mesures à lui.
- ⚠️ **Les poids ne sont plus rigides partout** (le corps est une coque continue). Ce que
  le piège n°3 protégeait l'est toujours, et c'est **vérifié par le script** : `visage` et
  `museau_peint` sont à poids 1 sur `tete`, sinon il refuse d'écrire le `.blend`.
- ⚠️ **Une marque blanche est une COQUE**, pas une zone de matière — bavette, chaussettes,
  bout de queue. C'est ce qui leur donne leur trait d'encre, et ce qui évite l'escalier
  d'une frontière posée en biais sur la grille.
- **Le visage est relevé trait pour trait sur `CatTuxedoFace.png`** (yeux, truffe,
  lèvre, moustaches, bavette), et la **gueule ouverte existe** — `mouth_open`, en place
  mais **débranchée**, elle attend l'animation de visage. Se juge au banc :
  `--mouth-open=1 --pitch=26`.
- ⛔ **ET LE PREMIER RELEVÉ ÉTAIT FAUX SUR TOUTES SES HAUTEURS** — refait le 2026-08-20,
  troisième passage. `uv.x` se normalise par la demi-**largeur** de la tête, `uv.y` par sa
  demi-**hauteur** ; sur ce chat elles valent 167,5 et 129,5 px, soit **1,29 d'écart**. Le
  relevé avait divisé les deux axes par la demi-largeur, donc **toutes** les hauteurs du
  visage sortaient 29 % trop courtes — de façon cohérente, donc invisible : le visage
  restait plausible, il était juste écrasé, et les yeux paraissaient petits. ⚠️ Le ✅ qui
  l'accompagnait ne valait rien : il mesurait des deux côtés avec la convention fautive.
- ⭐ **`face_lift` (0,33) porte le cadrage, et lui seul.** Il se retranche de `uv.y` une
  fois, juste avant le dessin : **toutes** les valeurs de `cel_face.gdshader` sont donc des
  mesures brutes de la planche, lisibles à côté d'elle. Avant, la compensation de plongée
  était ajoutée à la main dans chaque chiffre — une mesure et un choix de cadrage mélangés
  sans que rien ne le dise. ⚠️ Contrepartie : `bib.line` du chat de 2026-08-16 passe à
  −0,35 dans `ANCHORS`, et son masque ne bouge pas d'un pixel.
- ⛔ **Trois choses ont été rendues puis JETÉES**, toutes pour la même raison — une zone
  peinte sur une grille ne peut pas être plus fine qu'une face : l'accent du dos et du
  crâne (canal B, à zéro partout désormais), la touffe blanche d'oreille, et une queue
  crochue qui sortait en anneau.

**Visuels :** le **chat est dans le jeu**, cel-shadé, contour, visage peint et **griffes
dessinées** compris, et il se lit à taille de jeu — désormais en **tuxedo noir et blanc**,
qui se détache mieux du
parquet que l'ambre d'avant. Les **canapés sont modélisés** et posés dans l'arène en deux
variantes (bleu ciel, vert sauge). **Les croquettes d'XP sont modélisées** depuis le
2026-08-19 — trèfle à 3 lobes, 300 tris — et **la boule de poils** le même jour : amas à
6 touffes, 308 tris, dans la fourrure du chat, mèches claires comprises. **La souris** est
arrivée le 2026-08-19 et remplace la capsule rose du `chaser` : 1 132 tris, taupe chaud,
oreilles roses et queue. **Le chien** est arrivé le même jour et remplace la sphère lavande
de la `brute` : 1 610 tris, châtaigne, oreilles tombantes et museau clair — c'était **le
dernier placeholder de primitive du gameplay**. Reste placeholder : le petit mobilier —
tables / plantes / coussins en boîtes pastel.

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

