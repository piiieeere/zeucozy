class_name DrivenFx
extends MeshInstance3D

## ⭐ UN FX DONT L'HORLOGE VIENT DE DEHORS.
##
## Trois decalques du jeu ne s'avancent pas tout seuls : l'aura de l'haleine, le
## mouton de poussiere et l'onde du feulement. C'est la competence qui les porte
## qui appelle `advance(delta)`, depuis son `tick` — donc depuis
## `player._process`, qui rend deja la main quand la run est en pause.
##
## C'est le meme dispositif que `skills/skill.gd`, et pour la meme raison : une
## aura qui continuerait de mordre derriere un carton de niveau ne se VOIT pas,
## elle se constate a la barre de vie d'un ennemi. Un `_process` par FX, c'est un
## test de pause par FX, donc un endroit de plus ou l'oublier.
##
## ⚠️ CE N'EST PAS "LE SOCLE DES FX" — `hit_burst`, `bite_fx` et `shout_fx` n'en
## sont pas. Eux n'appartiennent a personne : ils sont plantes dans le monde,
## vivent leurs six poses et se liberent. Ils gardent donc leur `_process`. La
## ligne de partage est la propriete, pas la cadence.
##
## Le contrat tient en une methode, et il n'y en aura pas d'autre : ce type
## existe pour que `hiss_skill` puisse ecrire `child is DrivenFx` au lieu de
## `child.has_method("advance")`.


## Avance d'une frame de run vivante. Jamais appelee en pause.
func advance(_delta: float) -> void:
	pass
