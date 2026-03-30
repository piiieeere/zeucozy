Lis docs/game_design.md, docs/VISUAL_ART_DIRECTION.md et docs/SPRITE_PROMPTS.md avant de répondre.

# Sprite pipeline

- Vue: top-down 2D
- Style: cozy, cat lovers, soft pastel
- Format cible MVP: PNG carré
- Taille cible: 64x64 source, affichage possible à 32x32 ou 48x48
- Fond: transparent
- Ombres: minimales
- Pas de texte dans l'image
- Sujet centré
- Une silhouette lisible à petite taille
- Une seule idée visuelle par asset

Tâche :
- intégrer les sprites déjà présents dans assets/sprites/approved
- ne pas changer le gameplay
- ne pas créer de nouvelle architecture complexe
- respecter l’arborescence scenes/ scripts/ assets/
- si un sprite manque, créer un placeholder temporaire clairement nommé
- quand tu modifies un script, renvoie le fichier complet
- conserver la cohérence avec le prototype actuel :
  - grande carte
  - caméra centrée sur le player
  - spawns proches du player
  - direction cozy/pastel déjà appliquée à la UI et au décor

Résultat attendu :
1. liste des fichiers utilisés
2. scènes Godot à créer ou modifier
3. scripts à créer ou modifier
4. étapes de test
