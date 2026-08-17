extends Node3D

## ⭐ L'ONOMATOPEE — le bruit d'une competence active, ECRIT dans l'image.
##
## "CHOMP" au-dessus du chat quand la morsure claque. C'est le vocabulaire de
## l'anime TV 80-90 et du manga : le son n'est pas joue, il est DESSINE, en
## grosses lettres posees dans le cadre.
##
## ─── POURQUOI C'EST LE SOCLE DES ACTIFS QUI LE PORTE, ET PAS LA MORSURE ───
##
## Un actif est le seul type de competence qui soit une DECISION D'INSTANT
## (§2.4). L'onomatopee est ce qui rend cet instant lisible : elle dit "ca vient
## de partir, c'etait toi". Un AUTO n'en veut pas — six armes qui crient a leur
## propre cadence rempliraient l'ecran de texte en permanence, et le mot cesserait
## d'annoncer quoi que ce soit.
##
## Elle est donc branchee dans `active_skill.gd`, une fois, et toute competence
## active a venir criera sans avoir une ligne a ecrire pour ca.
##
## ─── CE QUI LA GARDE DANS L'IMAGE PLUTOT QUE SUR ELLE ───
##
## C'est un `Label3D` billboard plante dans le MONDE, pas un `Control` dans une
## `CanvasLayer`. Trois consequences, et les trois sont le but :
##
##   • elle est sous `RetroPost`, donc elle recoit le grain de
##     §8bis — meme argument que l'ATH (layer −2) et l'impact frame (−1) : au
##     dessus, elle se lirait comme un calque d'UI colle sur le film ;
##   • elle suit le chat, parce qu'elle appartient au coup et non a l'ecran ;
##   • elle est en pas comme tout le reste (`FxCadence.FX_POSE`).
##
## ⚠️ ELLE N'EST PAS DE L'INTERFACE, et pourtant elle prend la police et les
## couleurs de `ui_style`. Ce n'est pas une contradiction : `ui_style` est la
## source unique du CREME et de l'ENCRE du projet, et en fabriquer un second jeu
## pour l'onomatopee, c'est fabriquer exactement la divergence de constantes que
## ce projet passe son temps a reparer (cf. le crème du pelage tuxedo, §9).

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")
const UiStyle := preload("res://scripts/systems/ui_style.gd")

## Le mot, pose par pose. Poses TENUES puis coupe franche (§8) : elle ne
## s'estompe pas, elle n'est plus la.
##
## Le sens de lecture est celui d'un coup : elle ARRIVE trop grande, rebondit
## sous sa taille, revient, et tient. C'est le squash/stretch que §7 demande sur
## un impact, applique a un mot — deux poses de depassement suffisent, et c'est
## ce qui la separe d'un texte qui apparait.
##
## ⚠️ AUCUNE POSE NE TOUCHE A L'ALPHA. §8 interdit le fondu, et il l'interdit
## d'autant plus ici : un mot a demi transparent se lit comme un mot qu'on hesite
## a dire. Le seul moyen de le faire disparaitre est de le couper.
##
## 14 crans, soit ~440 ms. Cale pour tenir SOUS le geste qui l'a declenchee (la
## morsure vit 867 ms) : le bruit finit avant le mouvement, jamais l'inverse.
const POSES := [
	{"scale": 1.42, "rise": 0.00, "hold": 1},
	{"scale": 0.86, "rise": 0.06, "hold": 1},
	{"scale": 1.10, "rise": 0.12, "hold": 1},
	{"scale": 1.00, "rise": 0.16, "hold": 5},
	{"scale": 1.02, "rise": 0.22, "hold": 4},
	{"scale": 0.97, "rise": 0.30, "hold": 2},
]

## Hauteur du mot au-dessus du chat, en metres.
##
## ⚠️ Il est POSE AU-DESSUS, pas devant. Un actif dessine son geste DEVANT le
## chat (la gueule de la morsure occupe tout l'avant) : un mot pose la-dedans
## recouvrirait exactement ce qu'il commente. Sous une plongee de 45°, le dessus
## est le seul secteur libre.
const HEIGHT := 2.55

## Taille du glyphe en metres de monde, avant la mise a l'echelle des poses.
##
## ⚠️ En METRES et non en pixels, et le decalque de la morsure a deja tranche ce
## cas : le monde est vu a distance fixe, donc les deux reviennent au meme a
## l'ecran — mais seule l'unite de monde reste juste si le cadrage bouge un jour
## (`--distance=`, `--fov=`).
##
## ⚠️ MONTE de 0,52 a 0,80 apres capture. A 0,52 le mot faisait ~21 px de
## capitale : la taille d'un TITRE DE CARTE (§9.3), donc celle d'un element
## d'interface. Une onomatopee n'est pas une legende, c'est un evenement — au
## manga elle occupe une part du cadre. A 0,80 elle fait ~32 px et pese autant
## que la tete du chat, ce qui est le rapport de la reference.
const GLYPH := 0.80

## Inclinaison, en degres. Tiree au hasard dans ±INCLINE a chaque cri.
##
## Une onomatopee de manga n'est jamais d'aplomb : posee droite elle redevient un
## sous-titre. Et le hasard est la pour la meme raison que le `seed` des shaders —
## deux CHOMP de suite ne doivent pas etre le meme tampon.
const INCLINE := 13.0

## Decalage lateral maximal, en metres. Meme raison que l'inclinaison.
const DRIFT := 0.35

var _label: Label3D
var _pose := -1
var _held := 0.0
var _base := Vector3.ZERO


## Le mot est monte ICI et non dans une scene : il n'a qu'un node, et sa police,
## sa couleur et son cerne viennent tous de `ui_style`. Une `.tscn` n'aurait
## porte que des valeurs recopiees — c'est-a-dire des valeurs a resynchroniser.
func setup(word: String) -> void:
	_base = Vector3(randf_range(-DRIFT, DRIFT), HEIGHT, 0.0)
	position = _base

	_label = Label3D.new()
	_label.text = word
	_label.font = UiStyle.display_font()
	# La police est rendue a cette taille puis mise a l'echelle par `pixel_size` :
	# grande, sinon le glyphe est rasterise petit et remonte flou.
	_label.font_size = 96
	_label.pixel_size = GLYPH / 96.0
	# Le mot grandit depuis SON PIED, pas depuis son centre : `_label` est
	# remonte d'une demi-hauteur, donc la pose de depassement (×1,42) pousse vers
	# le haut au lieu de descendre sur le chat.
	_label.position.y = GLYPH * 0.5
	_label.modulate = UiStyle.CREAM
	# Le cerne d'encre, comme sur l'ATH : c'est LUI qui detache le mot du sol
	# parchemin, et sans lui un creme a 0,93 sur un ble a 0,84 disparait (§9).
	_label.outline_modulate = UiStyle.INK
	_label.outline_size = 22
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Jamais occulte, comme la griffure et la morsure : un mot coupe en deux par
	# un canape ne dit plus rien.
	_label.no_depth_test = true
	_label.shaded = false
	_label.double_sided = true
	# Au-dessus du decalque de la competence, qui est lui-meme en priorite 1.
	_label.render_priority = 4
	_label.outline_render_priority = 3
	_label.rotation_degrees.z = randf_range(-INCLINE, INCLINE)
	add_child(_label)

	_show(0)


func _process(delta: float) -> void:
	if _pose < 0 or _is_run_paused():
		return

	_held += delta

	if _held < _pose_duration(_pose):
		return

	_held = 0.0
	_show(_pose + 1)


## ⚠️ `MARGIN` n'est rendue qu'UNE fois par pose, pas une par cran — c'est une
## tolerance de seuil, pas une duree. Meme calcul que `bite_fx`.
func _pose_duration(pose: int) -> float:
	var holds := int(POSES[pose].get("hold", 1))
	return float(holds) * (FxCadence.FX_POSE + FxCadence.MARGIN) - FxCadence.MARGIN


func _show(pose: int) -> void:
	if pose >= POSES.size():
		queue_free()
		return

	_pose = pose
	var values: Dictionary = POSES[pose]
	# Le mot grossit depuis son PIED : une onomatopee qui gonfle depuis son centre
	# descend sur le chat a la pose de depassement, la seule ou elle est enorme.
	var factor := float(values["scale"])
	_label.scale = Vector3(factor, factor, 1.0)
	position = _base + Vector3(0.0, float(values["rise"]), 0.0)


func _is_run_paused() -> bool:
	var game := get_tree().get_first_node_in_group("game_root")
	return game != null and game.is_run_paused()
