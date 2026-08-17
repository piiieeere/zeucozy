extends RefCounted

## Le pool d'upgrades.
##
## `projectile_speed` en a ete retiree avec le passage a l'attaque de griffure :
## le projectile dort, une upgrade qui n'ameliore rien de visible est un mensonge
## a l'ecran. `claw_range` prend sa place. Le cas `projectile_speed` existe
## toujours dans `player.apply_upgrade` — le rebrancher tient en une entree ici.
##
## ⚠️ CE FICHIER NE PORTE PLUS AUCUN TEXTE depuis le 2026-08-17 (passage au
## bilingue). Le titre et la description de chaque upgrade vivent dans
## locale.gd, sous les cles `upgrade.<id>.title` et `upgrade.<id>.desc` — c'est
## `id` qui fait le lien, il n'y a donc rien a tenir synchronise a la main.
##
## Les entrees restent des dictionnaires alors qu'elles ne portent qu'une cle :
## une upgrade finira par avoir une rarete, une icone ou une condition
## d'apparition, et elles se poseront ici sans toucher aux appelants.

const DEFINITIONS: Array[Dictionary] = [
	{"id": "damage"},
	{"id": "attack_speed"},
	{"id": "move_speed"},
	{"id": "max_health"},
	{"id": "pickup_radius"},
	{"id": "claw_range"},
	# La seule qui DEBLOQUE au lieu de regler, et la seule qui se cumule
	# visiblement — voir "L'haleine puante" dans CLAUDE.md.
	{"id": "breath"},
]


static func roll_choices(count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = DEFINITIONS.duplicate(true)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))
