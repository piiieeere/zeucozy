class_name HissRing
extends DrivenFx

## L'onde du feulement — l'anneau qui s'ouvre au sol.
##
## Meme decoupe que `bite_fx.gd` : ce script avance les poses, `hiss_ring.gdshader`
## dessine la forme et ne sait rien du temps.
##
## ⚠️ IL NE POUSSE PERSONNE, exactement comme les machoires de la morsure ne
## blessent personne. Il annonce ou en est le FRONT, et `hiss_skill` en tire les
## ennemis a repousser. Un FX qui distribuerait ses propres effets serait un FX
## qu'on ne peut plus regler sans toucher au gameplay.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## L'onde, pose par pose. Poses TENUES puis coupe franche (§8).
##
## `front` est le rayon du front en fraction du rayon de poussee, `band` sa
## demi-epaisseur. Les deux vont dans des sens opposes, et ce n'est pas
## decoratif : une onde d'epaisseur constante se lit comme un anneau qui grandit.
## C'est le fait qu'elle MAIGRISSE en s'ouvrant qui la fait lire comme une onde
## qui se propage — la meme quantite d'air etalee sur un tour plus long.
##
## ⚠️ LA DERNIERE POSE EST A 1,00 EXACTEMENT. C'est le contrat de portee : le
## front affleure le bord de la zone de poussee, ni avant ni apres. Toute pose
## au-dela promettrait une distance que la competence n'a pas.
##
## 15 crans, soit ~500 ms pour traverser le rayon. A 3,6 m de rayon T1 le front
## avance a ~7,6 m/s, soit un peu plus vite que le chat (7,5) : personne ne
## distance l'onde, et elle ne rattrape rien qu'elle n'aurait pas du toucher.
## ⚠️ `band` EST BORNEE PAR `front`, pas choisie librement. L'epaisseur se prend
## des DEUX cotes du front : des que `band` depasse `front`, le bord interieur
## passe sous zero et l'anneau devient un DISQUE PLEIN. Mesure en capture — les
## deux premieres poses sortaient en assiette creme posee sous le chat, et rien
## dans le code ne le disait. La regle qui en sort : `band ≤ front × 0,35`.
const POSES := [
	{"front": 0.30, "band": 0.100, "hold": 2},
	{"front": 0.46, "band": 0.090, "hold": 2},
	{"front": 0.62, "band": 0.078, "hold": 2},
	{"front": 0.77, "band": 0.066, "hold": 2},
	{"front": 0.90, "band": 0.056, "hold": 3},
	{"front": 1.00, "band": 0.046, "hold": 4},
]

## Hauteur du decalque au-dessus du sol, en metres. Assez pour ne pas se disputer
## le z-buffer avec le parquet, assez peu pour rester une marque AU sol.
const LIFT := 0.06

## Le front vient d'avancer : voici son rayon en METRES. C'est ce que
## `hiss_skill` ecoute pour pousser ce que l'onde vient d'atteindre.
signal swept(reach: float)

var _material: ShaderMaterial
var _radius := 4.0
var _pose := -1
var _held := 0.0


func _ready() -> void:
	# Materiau propre a cette onde : la graine et les poses sont individuelles.
	_material = (material_override as ShaderMaterial).duplicate()
	material_override = _material


func setup(radius: float) -> void:
	_radius = maxf(0.5, radius)
	# Le quad porte le DIAMETRE : le shader travaille en unites de rayon.
	_material.set_shader_parameter("size", _radius * 2.0)
	_material.set_shader_parameter("seed", randf())
	position.y = LIFT
	_show(0)


func advance(delta: float) -> void:
	if _pose < 0:
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
	# Fin de la sequence : l'onde ne s'estompe pas, elle n'est plus la (§8).
	if pose >= POSES.size():
		queue_free()
		return

	_pose = pose
	var values: Dictionary = POSES[pose]
	var front := float(values["front"])
	_material.set_shader_parameter("ring", front)
	_material.set_shader_parameter("band", values["band"])
	# Le signal part APRES avoir pose le dessin : la poussee et l'image tombent
	# sur la meme frame, comme le degat de la morsure et son claquement.
	swept.emit(front * _radius)
