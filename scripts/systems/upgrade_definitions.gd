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
		"title": "Griffes aiguisées",
		"description": "+1 dégât par griffure."
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
		"title": "Réserve de vie",
		"description": "+30 vie max, et soigne de 30."
	},
	{
		"id": "pickup_radius",
		"title": "Aimant artisanal",
		"description": "Ramasse les croquettes de plus loin."
	},
	{
		"id": "claw_range",
		"title": "Grande allonge",
		"description": "La griffure porte plus loin et balaie plus large."
	},
	{
		# La premiere entree du pool qui DEBLOQUE quelque chose au lieu de
		# regler un chiffre existant. Reprise, elle elargit et renforce l'aura
		# — d'ou le "se cumule", qui doit tenir dans la description : sans lui,
		# la revoir dans le tirage une fois prise se lit comme un doublon.
		"id": "breath",
		"title": "Haleine puante",
		"description": "Un halo de souffle blesse ce qui s'approche. Se cumule."
	}
]


static func roll_choices(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = DEFINITIONS.duplicate(true)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
