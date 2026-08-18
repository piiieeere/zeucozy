class_name DustBunny
extends DrivenFx

## Un mouton de poussiere pose au sol.
##
## Meme decoupe que les autres FX : ce script avance les poses, `dust_bunny.gdshader`
## dessine la forme et ne sait rien du temps.
##
## ⚠️ IL NE BLESSE PERSONNE. C'est `dust_skill` qui teste les distances et
## consomme le mouton — comme `hiss_skill` pousse et comme `bite_skill` mord.
## Un FX qui distribuerait ses propres degats serait un FX qu'on ne peut plus
## regler sans toucher au gameplay.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## Le mouton, pose par pose, en TROIS temps distincts.
##
## ⚠️ Ils n'ont pas la meme cadence, et c'est la regle de §7 telle que l'haleine
## puante l'a elargie : la cadence se choisit sur la DUREE DE VIE de l'element,
## pas sur sa categorie.
##
##   NAISSANCE  il tombe et s'ecrase       `FX_POSE`      (2 frames) — c'est un coup
##   REPOS      il respire sur place       `AMBIENT_POSE` (5 frames) — il dure des secondes
##   POUF       il eclate et disparait     `FX_POSE`      (2 frames) — c'est un coup
##
## Le repos a la cadence des FX aurait donne un battement a ~4 Hz sur un objet
## qui reste 3,5 s a l'ecran, et jusqu'a dix a la fois : precisement ce que §8bis
## refuse. La naissance et le pouf a la cadence d'ambiance auraient molli les deux
## seuls instants ou le mouton est un evenement.
const BIRTH := [
	{"puff": 0.42, "hold": 1},
	{"puff": 1.12, "hold": 1},
	{"puff": 0.94, "hold": 1},
]

## Le repos BOUCLE. Il respire vers l'interieur seulement : la crete ne repasse
## jamais au-dessus de 1,00, sinon le dessin promettrait une zone de contact plus
## large que celle que la competence teste.
const IDLE := [
	{"puff": 1.00, "hold": 1},
	{"puff": 0.97, "hold": 1},
	{"puff": 0.94, "hold": 1},
	{"puff": 0.96, "hold": 1},
]

## POUF. Il grossit ET il part : la dissipation est une FORME qui s'ouvre, jamais
## un alpha qui tombe (§8 interdit le fondu).
const POOF := [
	{"puff": 1.28, "hold": 1},
	{"puff": 1.52, "hold": 1},
]

## Hauteur du decalque au-dessus du sol, en metres. Sous la couronne de l'haleine
## puante (0,06) : quand les deux se croisent, c'est l'aura du chat qui passe
## devant, parce qu'elle bouge et que le mouton est un decor pose.
const LIFT := 0.045

var _material: ShaderMaterial
var _phase := 0  ## 0 = naissance, 1 = repos, 2 = pouf
var _pose := 0
var _held := 0.0
var _spent := false


func _ready() -> void:
	_material = (material_override as ShaderMaterial).duplicate()
	material_override = _material


func setup(radius: float) -> void:
	# Le quad porte le DIAMETRE : le shader travaille en unites de rayon.
	_material.set_shader_parameter("size", maxf(0.2, radius) * 2.0)
	_material.set_shader_parameter("seed", randf())
	position.y = LIFT
	_apply()


## Consomme. Le mouton passe au pouf et ne peut plus etre consomme deux fois —
## sans cette garde, deux ennemis arrives sur la meme frame prendraient chacun le
## degat d'un mouton qui n'existe qu'une fois.
func consume() -> bool:
	if _spent:
		return false

	_spent = true
	_phase = 2
	_pose = 0
	_held = 0.0
	_apply()
	return true


func is_spent() -> bool:
	return _spent


func advance(delta: float) -> void:
	_held += delta

	if _held < _pose_duration():
		return

	_held = 0.0
	_pose += 1

	match _phase:
		0:
			if _pose >= BIRTH.size():
				_phase = 1
				_pose = 0
		1:
			# Le repos boucle : c'est le seul phase sans fin, et c'est la duree de
			# vie posee par la competence qui y met un terme, pas le tableau.
			_pose %= IDLE.size()
		2:
			if _pose >= POOF.size():
				queue_free()
				return

	_apply()


func _sequence() -> Array:
	match _phase:
		0:
			return BIRTH
		2:
			return POOF
		_:
			return IDLE


## ⚠️ `MARGIN` n'est rendue qu'UNE fois par pose, pas une par cran.
func _pose_duration() -> float:
	var base: float = FxCadence.AMBIENT_POSE if _phase == 1 else FxCadence.FX_POSE
	var holds := int(_sequence()[_pose].get("hold", 1))
	return float(holds) * (base + FxCadence.MARGIN) - FxCadence.MARGIN


func _apply() -> void:
	_material.set_shader_parameter("puff", _sequence()[_pose]["puff"])
