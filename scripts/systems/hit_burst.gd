extends MeshInstance3D

## L'eclat de collision — "Visual Art Direction" §8.
##
## L'etoile dessinee qui claque LA OU un ennemi touche le chat, et qui reste
## plantee a cet endroit du monde le temps de ses quatre poses. Elle ne suit ni
## le chat ni l'ennemi : un impact marque un point, il ne se promene pas.
##
## Ce script ne fait qu'une chose — avancer les poses. Toute la forme est dans
## hit_burst.gdshader, qui, lui, ne sait rien du temps.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## L'eclat, pose par pose. Poses TENUES, puis une coupe franche : §8 dit que
## les FX "tiennent puis disparaissent d'un coup". Rien n'est interpole d'une
## pose a la suivante — c'est du dessin, pas une courbe.
##
## Le sens de lecture est celui d'un eclat dessine : il NAIT deja gros (un
## impact n'a pas de temps de montee, ce serait le montrer arriver), s'ouvre
## jusqu'a un EXTREME qu'il tient deux poses, puis se dissipe en s'effilant.
##
## La dissipation se fait par la FORME, jamais par l'alpha : §8 interdit le
## fondu. Les pointes s'allongent et s'amincissent jusqu'a n'etre plus que des
## aiguilles, et la a disparait d'un coup.
##
## HUIT poses, soit 16 frames a la cadence de §7 (~267 ms). Quatre ne
## suffisaient pas : l'eclat passait avant qu'on ait compris ce qu'on voyait.
## C'est bien le NOMBRE de poses qui a ete augmente, pas leur duree — ralentir
## la cadence aurait coute le claquant que §8 attend precisement des FX
## ("plus rapides que les personnages"), et 8 poses reste le plafond de §7.
## `sharp` ne redescend jamais sous ~3 : en dessous, les pointes s'arrondissent
## en petales et l'eclat se lit comme une fleur, pas comme un impact. Teste, et
## c'est exactement ce qui s'est produit a 2,2.
const POSES := [
	{"scale": 0.80, "sharp": 4.5, "core": 0.42},
	{"scale": 1.02, "sharp": 3.4, "core": 0.32},
	{"scale": 1.18, "sharp": 2.8, "core": 0.24},
	{"scale": 1.22, "sharp": 2.7, "core": 0.20},
	{"scale": 1.26, "sharp": 3.2, "core": 0.14},
	{"scale": 1.32, "sharp": 4.2, "core": 0.00},
	{"scale": 1.38, "sharp": 6.0, "core": 0.00},
	{"scale": 1.44, "sharp": 8.5, "core": 0.00},
]

var _material: ShaderMaterial
var _pose := -1
var _held := 0.0


func _ready() -> void:
	_material = material_override as ShaderMaterial
	# Deux coups de suite ne doivent pas tamponner la meme etoile au meme
	# angle : c'est ce qui trahirait le decalque et le ferait lire comme un
	# sprite recycle plutot que comme un dessin.
	_material = _material.duplicate()
	_material.set_shader_parameter("spin", randf() * TAU)
	material_override = _material
	_show(0)


func _process(delta: float) -> void:
	_held += delta

	if _held < FxCadence.FX_POSE:
		return

	_held = 0.0
	_show(_pose + 1)


func _show(pose: int) -> void:
	# Fin de la sequence : l'eclat ne s'estompe pas, il n'est plus la.
	if pose >= POSES.size():
		queue_free()
		return

	_pose = pose
	var values: Dictionary = POSES[pose]
	_material.set_shader_parameter("burst_scale", values["scale"])
	_material.set_shader_parameter("sharp", values["sharp"])
	_material.set_shader_parameter("core", values["core"])
