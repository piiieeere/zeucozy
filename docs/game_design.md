# GAME MANIFEST — Projet Survivor

## 1. Vision du jeu

Créer un **survivor-like 2D** nerveux, lisible et satisfaisant, centré sur :
- le **plaisir immédiat**
- des **runs courtes et rejouables**
- une **montée en puissance spectaculaire**
- un développement **simple, modulaire et itératif** dans Godot 4

Le jeu doit être facile à prendre en main, rapide à tester, et suffisamment profond pour donner envie de relancer “une run de plus”.

---

## 2. Pitch

Le joueur contrôle un survivant perdu dans une zone hostile infestée d’ennemis.  
Il doit survivre le plus longtemps possible face à des vagues toujours plus denses, tout en gagnant de l’expérience, en choisissant des améliorations et en construisant un build de plus en plus destructeur.

Le cœur du plaisir vient de la progression suivante :

**faible → stable → puissant → surpuissant → chaos maîtrisé**

---

## 3. Promesse joueur

Le jeu promet au joueur :

- une action immédiate
- des contrôles simples
- des décisions d’upgrade fréquentes
- une sensation de puissance croissante
- des builds variés à chaque partie
- des runs courtes, intenses, rejouables

Le joueur doit ressentir :
- “je comprends tout en 10 secondes”
- “je deviens vraiment fort”
- “j’ai envie de recommencer pour tester une autre build”

---

## 4. Genre et positionnement

### Genre principal
- Action roguelite 2D
- Survivor-like
- Auto-attack / arena survival

### Références
- Vampire Survivors
- Brotato
- 20 Minutes Till Dawn
- Soulstone Survivors

### Positionnement
Un survivor-like **minimaliste, propre, lisible**, pensé pour :
- être amusant très vite
- être réalisable sans complexité excessive
- servir de base solide à des extensions futures

---

## 5. Piliers de design

### 5.1 Lisibilité avant tout
Le joueur doit toujours comprendre :
- où il est
- où sont les menaces
- ce que font ses attaques
- quels objets/XP il peut ramasser
- pourquoi il gagne ou perd

### 5.2 Fun immédiat
Dès les 30 premières secondes, il doit déjà se passer quelque chose :
- ennemis qui arrivent
- tirs automatiques
- esquive
- collecte d’XP
- progression visible

### 5.3 Croissance de puissance
Chaque run doit raconter une montée en puissance claire :
- stats qui augmentent
- armes qui évoluent
- écran plus rempli
- destruction plus massive
- build de plus en plus marquée

### 5.4 Simplicité systémique
Le jeu doit reposer sur des systèmes simples mais combinables :
- déplacement
- spawn
- attaque auto
- dégâts
- XP
- level up
- upgrades

### 5.5 Rejouabilité par les choix
La variété vient surtout de :
- choix d’upgrades
- ordre d’obtention
- synergies
- pression croissante des ennemis

---

## 6. Boucle de jeu principale

### Boucle moment-to-moment
1. Le joueur se déplace
2. Les ennemis apparaissent et poursuivent le joueur
3. Le personnage attaque automatiquement
4. Les ennemis meurent et lâchent de l’XP
5. Le joueur récupère l’XP
6. Il monte de niveau
7. Il choisit une amélioration
8. La difficulté augmente
9. Il tente de survivre le plus longtemps possible

### Boucle de run
1. Début faible
2. Stabilisation
3. Construction d’un build
4. Explosion de puissance ou effondrement
5. Mort ou victoire sur objectif de durée
6. Recommencer avec apprentissage et envie d’optimiser

---

## 7. Expérience cible

### Début de partie
- peu d’ennemis
- faible puissance
- nécessité de bouger et kiter

### Milieu de partie
- choix de build qui se dessinent
- densité d’ennemis plus forte
- premières synergies visibles

### Fin de partie
- tension élevée
- écran dense
- gros volume d’attaques et d’effets
- sentiment de chaos contrôlé
- test final de la build du joueur

---

## 8. Scope MVP

Le MVP doit être **petit, jouable, fun**.

### Contenu minimal
- 1 personnage jouable
- 1 arène
- déplacement 8 directions
- 1 type d’attaque automatique
- 2 à 3 types d’ennemis simples
- système de dégâts et de mort
- XP drops
- système de niveau
- choix entre 3 upgrades à chaque level up
- HUD minimal
- écran de game over
- timer de survie

### Ce qu’on ne fait pas dans le MVP
- inventaire complexe
- meta progression persistante
- boutique
- boss sophistiqués
- multijoueur
- narration
- crafting
- système de classes complexe

---

## 9. Direction gameplay

### Contrôles
- déplacement uniquement
- attaque automatique
- choix d’upgrade au level up
- pause éventuelle

### Philosophie
Le jeu doit être :
- simple à jouer
- difficile à maîtriser
- profond par accumulation de systèmes simples

### Priorité
Le mouvement du joueur doit être agréable avant tout.  
Si le déplacement n’est pas bon, le reste du jeu perd beaucoup en qualité.

---

## 10. Systèmes principaux

### 10.1 Player
Responsabilités :
- déplacement
- vie
- réception des dégâts
- récupération XP
- progression

### 10.2 Enemy
Responsabilités :
- spawn
- poursuite du joueur
- contact/dégâts
- mort
- drop d’XP

### 10.3 Weapon System
Responsabilités :
- tir automatique
- cadence
- direction / ciblage
- projectiles ou aura
- scaling avec upgrades

### 10.4 XP / Leveling
Responsabilités :
- drop d’orbes
- collecte
- montée de niveau
- affichage progression

### 10.5 Upgrade System
Responsabilités :
- génération de choix
- application de bonus
- spécialisation de build
- différenciation des runs

### 10.6 Game Director
Responsabilités :
- progression de difficulté
- rythme de spawn
- montée de pression
- éventuels paliers d’intensité

---

## 11. Build fantasy

Le joueur doit pouvoir créer des builds reconnaissables, par exemple :

- mitrailleuse rapide
- gros projectiles lents mais puissants
- build critique
- build zone / aura
- build récupération / sustain
- build contrôle de foule
- build projectile en éventail
- build glass cannon

Même avec peu d’armes au départ, il faut déjà sentir cette logique.

---

## 12. Progression de difficulté

La difficulté doit augmenter par :
- nombre d’ennemis
- vitesse des ennemis
- points de vie
- nouveaux types ennemis
- pression spatiale
- fenêtres de respiration plus rares

Le joueur ne doit pas avoir l’impression d’une hausse arbitraire.  
La montée doit paraître naturelle, lisible et progressive.

---

## 13. Esthétique et direction visuelle

### Objectif visuel
Faire quelque chose de :
- propre
- lisible
- rapide à produire
- cohérent

### Style recommandé pour le prototype
- vue top-down 2D
- sprites simples ou formes géométriques
- effets visuels limités mais impactants
- contraste clair entre :
  - joueur
  - ennemis
  - projectiles
  - XP
  - zones dangereuses

### Règle d’or
La lisibilité prime sur la beauté.

---

## 14. Direction sonore

Le son doit renforcer :
- l’impact des tirs
- la satisfaction des kills
- la collecte d’XP
- la montée de niveau
- les moments de danger

Pour le prototype :
- effets simples mais propres
- peu de sons, bien choisis
- boucle musicale légère ou absente au début si nécessaire

---

## 15. UX / UI

L’interface doit rester minimale.

### HUD MVP
- barre de vie
- barre d’XP
- niveau actuel
- temps de survie
- éventuellement nombre d’ennemis tués

### Écrans minimaux
- menu principal simple
- écran game over
- écran pause
- écran de choix d’upgrade

### Objectif UX
Le joueur doit toujours savoir :
- s’il est en danger
- s’il progresse
- ce qu’il choisit
- pourquoi il a perdu

---

## 16. Cadre technique

### Moteur
- Godot 4.6.1
- GDScript
- projet 2D
- architecture simple, modulaire

### Organisation recommandée
```text
project/
├─ scenes/
├─ scripts/
├─ assets/
├─ ui/
├─ systems/
└─ docs/