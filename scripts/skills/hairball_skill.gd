extends Skill

## La boule de poils — l'arme AUTO a distance.
##
## Elle REVEILLE le projectile, en sommeil depuis le passage a la griffure le
## 2026-08-16. Rien n'a ete remodelise : la scene, `projectile.gd` et
## `main.spawn_projectile` etaient restes entiers, precisement pour ce jour-la.
##
## ─── ELLE ROUVRE UNE FANTASY QUE LE MANIFESTE NOTAIT EN SUSPENS ───
##
## §11 du manifeste liste "Chat sniper" comme la seule build fantasy sans support
## depuis que l'attaque est au corps a corps, et designe ce projectile comme ce
## qui la rouvrirait. C'est fait.
##
## ─── UN TROISIEME REGISTRE DE JEU, PAS UNE TROISIEME ARME ───
##
## | | Griffure | Haleine | Boule de poils |
## |---|---|---|---|
## | Visee | le joueur | aucune | **automatique** |
## | Portee | 5,2 m | 2,8 m | **11 m** |
## | Cibles | tout l'arc | tout le cercle | **une seule** |
##
## ⚠️ ELLE NE SE VISE PAS, et c'est deliberement l'inverse de la griffure. La slot
## AUTO n°1 est reservee a l'arme DIRIGEE (§2.3) ; celle-ci occupe une slot libre
## et cherche l'ennemi le plus proche toute seule. Un deuxieme tir dirige aurait
## partage le curseur avec la griffure, et deux armes qui obeissent au meme geste
## ne font qu'une arme.
##
## Sa contrepartie est dans ses chiffres : elle frappe UNE cible pour peu de
## degats, la ou la griffure en balaie plusieurs. Elle porte loin, elle ne
## nettoie pas.

## Le compteur demarre a zero : la premiere boule part des la prise. Une arme qui
## se fait attendre 1,6 s a l'instant ou on la choisit se lit comme cassee.
var _cooldown := 0.0


func tick(delta: float) -> void:
	_cooldown -= delta

	if _cooldown > 0.0:
		return

	_cooldown = float(values["interval"])
	_spit()


## Le tir. La cible est l'ennemi le plus proche — la meme logique que
## `player._fire_at_nearest_enemy`, qui dormait avec le projectile et que ce
## fichier remplace.
##
## ⚠️ Rien ne part quand il n'y a personne. Un tir a vide toutes les 1,6 s
## remplirait l'arene de boules de poils inutiles, et §2.10 est clair : ce qui
## s'affiche doit correspondre a ce qui agit.
func _spit() -> void:
	if player == null:
		return

	var root := game()

	if root == null:
		return

	var direction := _nearest_direction()

	if direction == Vector3.ZERO:
		return

	var origin: Vector3 = player.global_position + Vector3(0.0, player.muzzle_height, 0.0)

	root.spawn_projectile(
		origin,
		direction,
		int(values["damage"]),
		# ⚠️ LE PALIER DONNE LA BASE, LE PASSIF MULTIPLIE — et la portee ne suit
		# PAS. `projectile_speed` fait arriver la boule plus tot au meme endroit,
		# il ne la fait pas porter plus loin : la portee est ce que la carte
		# promet et ce que l'ATH affiche, et un passif qui l'allongerait en
		# silence serait le mensonge a l'ecran que §2.10 interdit.
		#
		# Multiplie ICI, a la ponte, et pas sur le projectile en vol : une boule
		# qui accelererait en cours de route perdrait la trajectoire lisible que
		# le ralentissement du 2026-08-19 lui a donnee.
		float(values["speed"]) * player.projectile_speed,
		float(values["range"])
	)


## La direction de l'ennemi le plus proche, ou ZERO s'il n'y en a aucun.
func _nearest_direction() -> Vector3:
	var here: Vector3 = player.global_position
	var best := Vector3.ZERO
	var best_distance := INF

	for enemy in enemies():
		var to_enemy := enemy.global_position - here
		# Tout le jeu vit dans le plan XZ.
		to_enemy.y = 0.0
		var distance := to_enemy.length()

		if distance < 0.001 or distance >= best_distance:
			continue

		# Hors de portee, la boule mourrait en vol : on ne la tire pas.
		if distance > float(values["range"]):
			continue

		best_distance = distance
		best = to_enemy / distance

	return best
