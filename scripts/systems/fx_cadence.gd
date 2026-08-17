extends RefCounted

## La cadence des FX — "Visual Art Direction" §7.
##
## Trois durees seulement, et elles vivent ENSEMBLE pour la meme raison que la
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

## Une pose d'element PERMANENT. §7 : "decor anime, elements de fond — sur 5s",
## soit 12 fps percus. La cadence la plus lente du tableau.
##
## ⚠️ Elle n'est PAS reservee au decor, et le Soufflement est le cas qui l'a fait
## sortir : un FX qui ne dure pas ne se juge pas comme un FX qui ne s'arrete
## jamais. La cadence de 2s existe pour donner du claquant a une forme qui tient
## 200 ms ; appliquee a une aura toujours a l'ecran, elle donne un clignotement a
## ~4 Hz pendant vingt minutes — exactement le motif que §8bis a ecarte en
## refusant le tremblement du signal ("nauseeux sur une run de 20 minutes").
##
## La regle qui en sort : la cadence se choisit sur la DUREE DE VIE de l'element,
## pas sur sa categorie.
const AMBIENT_POSE := 5.0 / 60.0 - MARGIN
