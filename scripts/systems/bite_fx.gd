extends MeshInstance3D

## Le dessin de la morsure — les machoires qui claquent.
##
## Meme decoupe que `claw_slash.gd` : ce script avance les poses,
## `bite.gdshader` dessine la forme et ne sait rien du temps.
##
## ⚠️ Contrairement a la griffure, IL NE DISTRIBUE AUCUN DEGAT. La morsure ne
## touche qu'UNE cible, choisie par `bite_skill` au moment du declenchement — un
## Area3D ferait de ce dessin une zone, et une zone touche tout ce qu'elle
## recouvre. C'est la difference de fond entre un balayage et un croc.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## La morsure, pose par pose. Poses TENUES puis coupe franche (§8).
##
## Le sens de lecture est celui d'une machoire : elle s'ouvre grand, claque, puis
## se rouvre a peine en se dissipant. Le CLAQUEMENT est la pose 3 — la plus
## fermee et la plus epaisse — et c'est sur elle que la morsure blesse.
##
## La dissipation se fait par `thick` qui tombe et `taper` qui monte, jamais par
## l'alpha : §8 interdit le fondu.
##
## HUIT poses, mais des DUREES INEGALES — voir `hold`. Le geste tient ~500 ms au
## total, tres en dessous du cooldown le plus court (4,2 s) : deux morsures ne
## peuvent pas se chevaucher.
## ⚠️ `thick` a ETE DOUBLE apres la premiere capture. A 0,07-0,09 les deux arcs
## sortaient en traits de un a deux pixels : ils se lisaient comme un coup de
## ciseaux, et ni le brun ni le creme n'apparaissaient — le cluster 2 tons
## n'existait que dans le fichier. Une machoire est une MASSE ; c'est son
## epaisseur qui la separe d'une griffure, pas sa courbure.
## ⚠️ `gape + thick` EST BORNE A 0,395, DES DEUX COTES — voir `jaw_offset` dans
## le shader. Trop grand, le haut de la machoire est tranche net par le bord du
## quad ; trop grand aussi, le bas retombe sur le chat et le personnage se
## retrouve dans la gueule. L'ouverture n'est donc pas un choix de dessin, c'est
## ce que l'encadrement laisse.
##
## ⚠️ HUIT poses depuis le 2026-08-17, contre cinq — la morsure ne restait pas
## assez longtemps a l'ecran (~167 ms). RALLONGER UN FX SE FAIT EN AJOUTANT DES
## POSES, JAMAIS EN RALENTISSANT LA CADENCE : §8 veut les FX plus rapides que les
## personnages, c'est ce qui leur donne du claquant, et l'eclat de collision avait
## deja tranche exactement ce cas (4 poses → 8). Huit est le plafond de §7.
##
## ⚠️ `hold` — CHAQUE POSE A SA PROPRE DUREE, en multiples de `FxCadence.FX_POSE`.
##
## C'est la troisieme correction de duree, et les deux premieres etaient de
## mauvaises pistes :
##
##   • RALENTIR LA CADENCE est exclu — §8 veut les FX plus rapides que les
##     personnages, c'est ce qui leur donne du claquant ;
##   • AJOUTER DES POSES est plafonne a 8 (§7), et on y est.
##
## La bonne reponse etait dans §7 depuis le debut : *"des poses TENUES coupees
## par des transitions rapides — le personnage s'arrete vraiment"*. Une cadence
## uniforme est un metronome, pas de l'animation posee. Le claquement (pose 2)
## tient donc QUATRE fois plus longtemps que l'ouverture, et le geste passe de
## 267 a ~500 ms sans qu'une seule pose s'ajoute ni que la cadence de base bouge.
##
## Les poses 2, 3 et 4 sont la machoire fermee : le geste claque, puis il RESTE.
## Une morsure qui se rouvre aussitot ne se lit pas comme une prise.
const POSES := [
	{"gape": 0.235, "thick": 0.160, "taper": 1.5, "hold": 1},
	{"gape": 0.130, "thick": 0.185, "taper": 1.4, "hold": 1},
	{"gape": 0.015, "thick": 0.215, "taper": 1.3, "hold": 4},
	{"gape": 0.008, "thick": 0.220, "taper": 1.3, "hold": 3},
	{"gape": 0.025, "thick": 0.205, "taper": 1.4, "hold": 2},
	{"gape": 0.070, "thick": 0.160, "taper": 1.7, "hold": 2},
	{"gape": 0.120, "thick": 0.100, "taper": 2.3, "hold": 1},
	{"gape": 0.170, "thick": 0.044, "taper": 3.2, "hold": 1},
]

## La pose qui CLAQUE — machoires fermees, trait le plus epais. Le degat tombe
## sur elle, comme la morsure de l'haleine puante tombe sur sa pose pleine : le
## joueur voit le coup au moment exact ou il coute de la vie.
##
## Deux poses, soit 4 frames (~67 ms) apres le clic. C'est en dessous du seuil ou
## un retard se sent, et ca vaut mieux qu'un degat sur la pose 0 : un coup qui
## part avant que le dessin ait commence se lit comme un bug.
const BITE_POSE := 2

## Hauteur du dessin, en metres. A mi-corps du chat (il fait 1,86), comme la
## griffure : au sol, la machoire se lirait comme une ombre.
const DRAW_HEIGHT := 0.9

## Largeur du decalque, en fraction de la portee. Un palier qui allonge la
## morsure doit SE VOIR — meme contrat que `claw_slash.DRAW_SIZE`.
##
## ⚠️ MONTE de 1,5 a 2,0 le 2026-08-17 : la gueule etait beaucoup trop petite a
## taille de jeu. A 2,0 le quad fait exactement DEUX fois la portee, donc une
## unite de quad vaut la portee elle-meme — et le bord superieur du dessin
## (`jaw_offset + gape + thick` ≈ 1,0) tombe pile sur les 2,6 m ou la morsure
## mord.
##
## Ce n'est pas un agrandissement gratuit : c'est le dessin qui rejoint la
## portee reelle. La regle du projet est que la portee et le dessin ne peuvent
## pas diverger — jusqu'ici la gueule promettait MOINS que ce que la competence
## faisait, ce qui est le meme defaut a l'envers.
const DRAW_SIZE := 2.0

signal snapped

var _material: ShaderMaterial
var _pose := -1
var _held := 0.0


func _ready() -> void:
	# Materiau propre a cette morsure : la graine et les poses sont individuelles.
	_material = (material_override as ShaderMaterial).duplicate()
	material_override = _material
	position.y = DRAW_HEIGHT


func setup(direction: Vector3, reach: float) -> void:
	var aim := Vector3.FORWARD if direction == Vector3.ZERO else direction.normalized()

	_material.set_shader_parameter("aim", aim)
	_material.set_shader_parameter("size", maxf(0.5, reach) * DRAW_SIZE)
	_material.set_shader_parameter("seed", randf())
	_show(0)


func _process(delta: float) -> void:
	if _pose < 0 or _is_run_paused():
		return

	_held += delta

	if _held < _pose_duration(_pose):
		return

	_held = 0.0
	_show(_pose + 1)

	if _pose == BITE_POSE:
		snapped.emit()


## La duree d'une pose, en secondes.
##
## ⚠️ `MARGIN` n'est rendue qu'UNE fois, pas une par cran. Elle existe pour ne pas
## rater un seuil quand `delta` oscille autour de 1/60 — elle n'est pas une duree,
## et la multiplier par `hold` allongerait chaque pose tenue d'un peu plus que ce
## que le tableau annonce.
func _pose_duration(pose: int) -> float:
	var holds := int(POSES[pose].get("hold", 1))
	return float(holds) * (FxCadence.FX_POSE + FxCadence.MARGIN) - FxCadence.MARGIN


func _show(pose: int) -> void:
	# Fin de la sequence : la morsure ne s'estompe pas, elle n'est plus la.
	if pose >= POSES.size():
		queue_free()
		return

	_pose = pose
	var values: Dictionary = POSES[pose]
	_material.set_shader_parameter("gape", values["gape"])
	_material.set_shader_parameter("thick", values["thick"])
	_material.set_shader_parameter("taper", values["taper"])


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _is_run_paused() -> bool:
	var game = _get_game()
	return game != null and game.is_run_paused()
