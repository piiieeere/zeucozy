class_name HitBurst
extends MeshInstance3D

## L'eclat de collision — "Visual Art Direction" §8.
##
## L'etoile d'impact qui claque LA OU un ennemi touche le chat, et qui reste
## plantee a cet endroit du monde le temps de ses poses. Elle ne suit ni le chat
## ni l'ennemi : un impact marque un point, il ne se promene pas.
##
## Ce script ne fait qu'une chose — avancer les poses. Toute la forme est dans
## hit_burst.gdshader, qui, lui, ne sait rien du temps.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## ─── L'ANIMATION REECRITE LE 2026-08-17 : ELLE S'EFFONDRE, ELLE NE S'OUVRE PLUS
##
## §8 notait le defaut depuis le 2026-08-16 — "il recouvre le chat et se lit
## toujours comme une FLEUR" — et la moitie de la cause etait ICI, pas dans le
## shader : l'ancienne table faisait GRANDIR l'eclat de la premiere pose a la
## derniere (`scale` 0,80 → 1,44, monotone). C'est le geste d'une corolle qui
## s'ouvre. Un choc fait l'inverse : il est DEJA a son maximum, puis il tombe.
##
## Le sens de lecture est desormais celui d'un impact de manga :
##
##   pose 0  LE FLASH      l'etoile entierement CREME, cernee, et c'est LA PLUS
##                         GRANDE de la sequence. C'est l'impact frame de §7
##                         ramenee a la taille du coup — le plein cadre, lui,
##                         reste debranche depuis le 2026-08-17 (voir
##                         impact_frame.gd)
##   pose 1  LA COULEUR    l'etoile prend son rose-rouge et ses tessons, qui
##                         sont encore DANS son enveloppe : ils se lisent comme
##                         accroches a elle
##   pose 2  L'EXTREME TENU legerement plus petite, mais TENUE 2 crans. C'est
##                         la pose qu'on voit reellement, et les tessons s'en
##                         detachent ici
##   poses 3-5 L'EFFONDREMENT l'etoile tombe, les tessons partent et maigrissent
##
## ⚠️ LE FLASH A DU DOUBLER apres capture — il etait a `burst` 0,30, soit 13 px
## de rayon a l'ecran, et il ne se voyait tout simplement PAS : un point creme
## sur la joue du chat pendant 33 ms. Une pose qu'on ne voit pas ne raconte
## rien, et celle-ci porte a elle seule ce qui restait de l'impact frame. A 0,74
## elle est le pic du geste, ce qui remet la sequence dans le bon sens : le choc
## est deja a son maximum a la premiere frame, tout le reste est une chute.
##
## ⚠️ La dissipation se fait par la FORME, jamais par l'alpha : §8 interdit le
## fondu. Puis coupe franche.
##
## ⚠️ `hold` — CHAQUE POSE A SA PROPRE DUREE, en multiples de `FxCadence.FX_POSE`,
## comme la morsure depuis le 2026-08-17. §7 demande "des poses TENUES coupees
## par des transitions rapides" : une cadence uniforme est un metronome, pas de
## l'animation posee. Ici c'est ce qui permet de tenir l'extreme 2 crans sans
## ralentir la cadence (interdit — §8 veut les FX plus rapides que les
## personnages) ni depasser les 8 poses de §7.
##
## 7 crans, soit 14 frames a 60 fps (~233 ms) pour 6 poses. L'ancienne version
## en depensait 16 sur 8 poses toutes egales, dont aucune ne durait assez pour
## etre lue.
##
## ⚠️ LES DEUX BUDGETS QUE CETTE TABLE NE PEUT PAS DEPASSER, et ils sont dans le
## quad, pas dans le dessin :
##   * `burst` ≤ 0,96 — au-dela la pointe la plus longue sort du quad et se fait
##     trancher net par son bord, pendant que ses voisines passent intactes ;
##   * `shard_dist × 1,05 + shard_len × 1,15` ≤ 0,96 — meme piege, sur les
##     tessons, avec les multiplicateurs de dispersion du shader.
const POSES := [
	{"burst": 0.74, "core": 1.00, "shard_dist": 0.00, "shard_len": 0.000, "hold": 1},
	{"burst": 0.68, "core": 0.52, "shard_dist": 0.46, "shard_len": 0.200, "hold": 1},
	{"burst": 0.60, "core": 0.38, "shard_dist": 0.58, "shard_len": 0.175, "hold": 2},
	{"burst": 0.47, "core": 0.22, "shard_dist": 0.66, "shard_len": 0.140, "hold": 1},
	{"burst": 0.33, "core": 0.00, "shard_dist": 0.72, "shard_len": 0.105, "hold": 1},
	{"burst": 0.20, "core": 0.00, "shard_dist": 0.76, "shard_len": 0.070, "hold": 1},
]

var _material: ShaderMaterial
var _pose := -1
var _held := 0.0


func _ready() -> void:
	_material = material_override as ShaderMaterial
	# Deux coups de suite ne doivent pas tamponner la meme etoile au meme
	# angle : c'est ce qui trahirait le decalque et le ferait lire comme un
	# sprite recycle plutot que comme un dessin. La graine pilote a la fois
	# l'orientation, la longueur des pointes et la dispersion des tessons.
	_material = _material.duplicate()
	_material.set_shader_parameter("seed", randf())
	material_override = _material
	_show(0)


func _process(delta: float) -> void:
	_held += delta

	if _held < _pose_duration(_pose):
		return

	_held = 0.0
	_show(_pose + 1)


## La duree d'une pose, en secondes.
##
## ⚠️ `MARGIN` n'est rendue qu'UNE fois, pas une par cran. Elle existe pour ne
## pas rater un seuil quand `delta` oscille autour de 1/60 — elle n'est pas une
## duree, et la multiplier par `hold` allongerait chaque pose tenue d'un peu
## plus que ce que la table annonce.
func _pose_duration(pose: int) -> float:
	var holds := int(POSES[pose].get("hold", 1))
	return float(holds) * (FxCadence.FX_POSE + FxCadence.MARGIN) - FxCadence.MARGIN


func _show(pose: int) -> void:
	# Fin de la sequence : l'eclat ne s'estompe pas, il n'est plus la.
	if pose >= POSES.size():
		queue_free()
		return

	_pose = pose
	var values: Dictionary = POSES[pose]
	_material.set_shader_parameter("burst", values["burst"])
	_material.set_shader_parameter("core", values["core"])
	_material.set_shader_parameter("shard_dist", values["shard_dist"])
	_material.set_shader_parameter("shard_len", values["shard_len"])
