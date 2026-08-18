extends Skill

## La griffure — l'arme DIRIGEE du chat, slot AUTO n°1 (§2.3).
##
## Le code de ce fichier vient tel quel de `player.gd` : le compteur d'attaque de
## `_process` et `_slash_forward`. Rien de son comportement n'a change — meme
## cadence, meme arc, meme alternance de patte, meme premiere griffure des la
## premiere frame (le compteur demarre a zero).
##
## Ce qui a change, c'est OU il vit. La griffure n'est plus un privilege du chat,
## c'est une competence parmi celles qu'il porte : elle occupe une slot, elle a
## des paliers, et elle est remplacable — par une autre arme dirigee uniquement,
## ce que `directed` dit dans le catalogue.
##
## ⚠️ Le decalque reste enfant du CHAT, pas de cette competence. Une griffure est
## un geste du corps : plantee dans le monde elle se detacherait du chat des la
## premiere frame — a 7,5 m/s il avance de 1,5 m pendant ses six poses. Le
## resultat serait identique en l'attachant ici (ce node ne bouge pas par
## rapport au chat), mais l'intention se lirait moins bien, et une competence qui
## disparait ne doit pas emporter le geste en cours avec elle.

const CLAW_SLASH_SCENE := preload("res://scenes/claw_slash.tscn")

## Zero : la premiere griffure part sur la premiere frame. C'etait deja le cas
## avant, et ca compte — une arme qui se fait attendre 1,1 s au lancement se lit
## comme cassee.
var _cooldown := 0.0

## Une patte puis l'autre. Le balayage change de sens a chaque coup, sans quoi
## deux griffures de suite se lisent comme un tampon recycle.
var _side := 1.0


func tick(delta: float) -> void:
	_cooldown -= delta

	if _cooldown > 0.0:
		return

	_cooldown = values["interval"]
	_swing()


## La griffure part dans la direction VISEE — jamais vers un ennemi choisi pour
## le joueur. C'est la difference de fond avec le projectile : ici, c'est le
## joueur qui pointe.
func _swing() -> void:
	if player == null:
		return

	var slash := CLAW_SLASH_SCENE.instantiate() as ClawSlash
	player.add_child(slash)
	slash.setup(
		player.aim_direction,
		values["damage"],
		values["range"],
		values["arc"],
		_side
	)
	# Sans ca, l'interpolation physique fait partir le decalque de l'origine du
	# monde sur sa premiere frame — et sa premiere frame est un sixieme de sa vie.
	slash.reset_physics_interpolation()
	_side = -_side
