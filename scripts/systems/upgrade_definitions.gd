extends RefCounted

const DEFINITIONS: Array[Dictionary] = [
	{
		"id": "damage",
		"title": "Charge creuse",
		"description": "+1 degat sur chaque projectile."
	},
	{
		"id": "attack_speed",
		"title": "Rafale stable",
		"description": "Tire plus souvent."
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
		"id": "projectile_speed",
		"title": "Munition rapide",
		"description": "Projectiles plus rapides et plus longs."
	}
]


static func roll_choices(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = DEFINITIONS.duplicate(true)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
