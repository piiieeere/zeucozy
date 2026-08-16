extends RefCounted

## Le pool d'upgrades.
##
## `projectile_speed` en a ete retiree avec le passage a l'attaque de griffure :
## le projectile dort, une upgrade qui n'ameliore rien de visible est un mensonge
## a l'ecran. `claw_range` prend sa place. Le cas `projectile_speed` existe
## toujours dans `player.apply_upgrade` — le rebrancher tient en une entree ici.

const DEFINITIONS: Array[Dictionary] = [
	{
		"id": "damage",
		"title": "Griffes aiguisees",
		"description": "+1 degat sur chaque griffure."
	},
	{
		"id": "attack_speed",
		"title": "Patte vive",
		"description": "Griffe plus souvent."
	},
	{
		"id": "move_speed",
		"title": "Pas nerveux",
		"description": "Court plus vite."
	},
	{
		"id": "max_health",
		"title": "Reserve de vie",
		"description": "+2 vie max et soigne de 2."
	},
	{
		"id": "pickup_radius",
		"title": "Aimant artisanal",
		"description": "Augmente le rayon de ramassage."
	},
	{
		"id": "claw_range",
		"title": "Grande allonge",
		"description": "La griffure porte plus loin et balaie plus large."
	}
]


static func roll_choices(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = DEFINITIONS.duplicate(true)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
