extends RefCounted

## La cadence des FX — "Visual Art Direction" §7.
##
## Deux durees seulement, et elles vivent ENSEMBLE pour la meme raison que la
## palette du chat vit dans cel_model.gd : deux FX qui divergent d'une frame et
## la cadence — ce qui fait qu'une image se lit comme du cellulo plutot que
## comme de la 3D — se perd sans que rien ne casse ni ne previenne.
##
## Elles ne servent PAS a mesurer une duree, mais a TENIR une pose. Un FX de ce
## projet est une suite de poses dessinees, coupees franc : jamais une courbe
## echantillonnee.

## Marge de tolerance. Ce n'est pas un reglage : a 60 Hz reel, `delta` oscille
## autour de 1/60 et tomberait une fois sur deux du mauvais cote d'un seuil
## pose pile dessus — chaque pose tiendrait alors une frame de trop.
const MARGIN := 0.002

## Une frame de jeu. §7 : "impact frame (flash) — 1 a 2 frames seulement".
const GAME_FRAME := 1.0 / 60.0 - MARGIN

## Une pose de FX. §7 : "FX, feedbacks de hit — sur 2s", soit 30 fps percus.
## Plus rapide que les personnages (sur 3s) : c'est ce qui donne du claquant
## aux FX, et l'ecart entre les deux cadences fait partie du style.
const FX_POSE := 2.0 / 60.0 - MARGIN
