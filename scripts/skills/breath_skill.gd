extends Skill

## L'haleine puante — l'aura de souffle, slot AUTO libre.
##
## La competence et son DESSIN sont deux choses, et ce fichier est la premiere.
## `breath_aura.gd` sait faire une couronne de volutes, respirer en huit poses et
## mordre sur l'une d'elles ; il ne sait rien des paliers ni du pool. C'est ici
## qu'un palier devient un rayon et des degats.
##
## ⚠️ L'aura est enfant de cette competence, donc petite-fille du chat — et
## surtout PAS enfant du modele. Le node `Player` ne tourne pas, seul `$Model`
## tourne : la couronne garde ainsi son orientation dans le monde et ne se met
## pas a pivoter des que le joueur vise ailleurs. Le jour ou une competence sera
## retiree d'une slot (chantier 2), son dessin partira avec elle sans qu'on ait
## rien a nettoyer a la main.

const BREATH_AURA_SCENE := preload("res://scenes/fx/breath_aura.tscn")

var _aura: BreathAura = null


## L'aura n'existe qu'a partir du premier palier — il n'y a pas d'etat "arme
## presente mais eteinte". Une competence non prise n'a pas de node du tout.
func _on_tier_changed() -> void:
	if _aura == null or not is_instance_valid(_aura):
		_aura = BREATH_AURA_SCENE.instantiate() as BreathAura
		add_child(_aura)
		# Sans ca, l'interpolation physique fait partir la couronne de l'origine
		# du monde sur sa premiere frame.
		_aura.reset_physics_interpolation()

	_aura.setup(player, values["radius"], values["damage"])


## L'aura n'a plus d'horloge a elle : c'est la competence qui l'avance, et elle
## n'est avancee que sur une run vivante. Voir `skill.gd` — c'est tout l'objet du
## contrat, et ce fichier est le cas qui l'a impose.
func tick(delta: float) -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.advance(delta)
