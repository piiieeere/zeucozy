# 🐾 GAME MANIFEST — Cozy Cat Survivor

---

## 1. Vision du jeu

Créer un **survivor-like 2D cozy**, lisible et satisfaisant, centré sur :
- le **plaisir immédiat**
- des **runs courtes et relaxantes**
- une **montée en puissance mignonne et fun**
- un développement **simple, modulaire et itératif** dans Godot 4

Le jeu doit être :
- facile à prendre en main  
- relaxant malgré l’action  
- satisfaisant visuellement et auditivement  
- irrésistible pour les **cat lovers**

---

## 2. Pitch

Le joueur incarne un **chat** dans un environnement domestique.  
Il doit survivre face à tout ce qu’un chat déteste :

- aspirateurs 🌀  
- chiens 🐶  
- concombres 🥒  

En progressant, il récupère des **croquettes (XP)**, améliore ses capacités et devient un chat surpuissant.

Le cœur du plaisir :

**chat fragile → chat malin → chat dominant → chaos félin maîtrisé**

---

## 3. Promesse joueur

Le jeu promet :

- une expérience **cozy mais dynamique**
- des contrôles simples
- une ambiance **mignonne et humoristique**
- une montée en puissance satisfaisante
- des builds fun (et parfois absurdes)
- des runs rapides et rejouables

Le joueur doit ressentir :
- “c’est trop mignon”
- “c’est relax mais fun”
- “mon chat devient OP 😂”
- “encore une run”

---

## 4. Genre et positionnement

### Genre principal
- Action roguelite 2D
- Survivor-like cozy
- Auto-attack / arena survival

### Références
- Vampire Survivors
- Brotato

### Positionnement
Un survivor-like :
- **cozy**
- **accessible**
- **humoristique**
- centré sur les chats

---

## 5. Piliers de design

### 5.1 Lisibilité cozy
- couleurs douces
- formes simples
- animations claires
- feedback visuel agréable

### 5.2 Fun sans stress
- pas de gore
- pas de tension anxiogène
- feedback toujours “cute”

### 5.3 Fantasy féline
Le joueur se sent comme un chat :
- agile
- rapide
- joueur
- imprévisible

### 5.4 Simplicité systémique
- systèmes simples
- combinables
- faciles à coder

### 5.5 Humour et attachement
- éléments drôles
- situations relatable pour les propriétaires de chats

---

## 6. Boucle de jeu principale

### Boucle moment-to-moment

1. Le chat se déplace  
2. Les ennemis apparaissent  
3. Le chat attaque automatiquement  
4. Les ennemis disparaissent  
5. Ils lâchent des croquettes  
6. Le chat mange les croquettes  
7. Level up  
8. Choix d’amélioration  
9. Intensité augmente  

---

### Boucle de run

1. Début fragile  
2. Stabilisation  
3. Build qui se construit  
4. Montée en puissance  
5. Chaos mignon  
6. Mort ou victoire  
7. Rejouer  

---

## 7. Expérience cible

### Début
- calme
- découverte

### Milieu
- builds intéressants
- variété

### Fin
- chaos lisible
- fun maximal

---

## 8. Scope MVP

### Contenu minimal

- 🐱 1 chat jouable  
- 🏠 1 arène (salon / appartement)  
- déplacement 8 directions  
- attaque automatique  
- ennemis :
  - aspirateur
  - chien
  - concombre  
- croquettes (XP)  
- système de niveau  
- upgrades  
- HUD minimal  
- écran game over  
- timer  

---

### Boss MVP

- 🧑‍⚕️ Vétérinaire
  - seringues 💉  
  - cage  
  - appel “pspsps”  

---

## 9. Direction gameplay

### Contrôles
- déplacement uniquement  
- attaque automatique  
- choix upgrades  

### Priorité
Le mouvement du chat doit être **fluide et agréable**

---

## 10. Systèmes principaux

### Player (Chat)
- déplacement
- vie
- récupération XP

### Enemy
- spawn
- poursuite
- dégâts
- disparition
- drop croquettes

### Weapon System
- attaque automatique
- projectiles
- scaling

### XP System
- croquettes
- level up

### Upgrade System
- choix
- bonus

### Game Director
- difficulté progressive

---

## 11. Build fantasy

- chat rapide
- chat tank
- chat chaos
- chat sniper
- chat aimant à croquettes

---

## 12. Progression de difficulté

- plus d’ennemis
- plus rapides
- plus variés

Toujours :
- lisible
- juste

---

## 13. Esthétique et direction visuelle

### Style

- cozy
- pastel
- cartoon / pixel soft

### Règles

- pas de gore
- animations douces
- lisibilité maximale

---

## 14. État actuel du prototype

### Boucle jouable déjà en place

- déplacement 8 directions
- auto-attaque
- XP
- level up
- choix d'upgrades
- timer
- game over
- HUD

### Spawns et rythme actuels

- les ennemis spawnent dans un rayon proche du player
- la croissance du nombre d'ennemis est volontairement linéaire
- la difficulté a été ralentie pour garder une sensation cozy et lisible

### Carte actuelle

- grande carte avec caméra centrée sur le player
- mode windowed fullscreen pour le développement
- décor non bloquant déjà présent pour renforcer la sensation de déplacement

### Direction de production actuelle

- placeholders autorisés tant que la lisibilité est bonne
- éviter toute architecture complexe
- privilégier des itérations courtes et testables
- tout nouveau visuel doit respecter `docs/VISUAL_ART_DIRECTION.md`
- tout travail d'intégration de sprites doit respecter le pipeline décrit dans les docs du dossier `docs/`

---

## 15. Prochaine intégration visuelle prévue

- remplacer progressivement les placeholders vectoriels par de vrais sprites
- priorités MVP :
  - player chat
  - ennemi aspirateur
  - ennemi chien
  - ennemi concombre
  - croquette XP
  - projectile

---

## 16. Références de contexte

- direction artistique : `docs/VISUAL_ART_DIRECTION.md`
- prompts sprites : `docs/SPRITE_PROMPTS.md`
- tâche d'intégration d'assets : `docs/CODEX_ASSET_TASK_TEMPLATE.md`
- contraintes agent/code : `docs/AI_CONTEXT.md`

---

## 14. Direction sonore

- miaulements 🐱  
- croquettes “crunch”  
- aspirateur doux  
- sons cartoon  

---

## 15. UX / UI

### HUD

- vie  
- XP  
- niveau  
- temps  

### Objectif

Toujours comprendre :
- état du joueur
- progression

---

## 16. Cadre technique

### Moteur
- Godot 4.6.1
- GDScript
- 2D

### Structure
project/
├─ scenes/
├─ scripts/
├─ assets/
├─ ui/
├─ systems/
└─ docs/

---

## 17. Méthode de développement

1. Player  
2. Ennemis  
3. Croquettes  
4. Attaque  
5. Level up  
6. Upgrades  
7. Boss  

---

## 18. Conditions de réussite

- fun rapide  
- mignon  
- lisible  
- addictif  

---

## 19. Conditions d’échec

- trop stressant  
- pas lisible  
- gameplay mou  

---

## 20. North Star

**Rendre le jeu plus fun, plus mignon, sans complexifier.**

---

## 21. Résumé

Un survivor-like cozy où :

- tu es un chat 🐱  
- tu évites aspirateurs, chiens et concombres  
- tu manges des croquettes  
- tu deviens surpuissant  
- tu bats un vétérinaire  

👉 fun simple, mignon et addictif
