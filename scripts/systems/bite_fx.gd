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
## se rouvre a peine en se dissipant. Le CLAQUEMENT est la pose 2 — celle ou les
## pointes passent la ligne mediane — et c'est sur elle que la morsure blesse.
##
## La dissipation se fait par `thick` et `tooth_len` qui tombent et `taper` qui
## monte, jamais par l'alpha : §8 interdit le fondu.
##
## ─── L'OUVERTURE SE LIT SUR LES DENTS, PLUS SUR LES GENCIVES (2026-08-17) ───
##
## Avant, la gueule se fermait en faisant se CHEVAUCHER les deux arcs : a la pose
## de claquement `gape` (0,015) tombait tres en dessous de `thick` (0,215), donc
## les deux bandes s'interpenetraient de 0,2 et fusionnaient en une masse. Toute
## denture y disparaissait — impossible de dessiner des dents dans une machoire
## qui se referme sur elle-meme.
##
## Le geste est donc inverse : les gencives restent ECARTEES (gape − thick reste
## positif du debut a la fin) et ce sont les DENTS qui traversent la ligne
## mediane. C'est ce que fait une vraie gueule, et c'est ce qui rend l'engrenement
## visible — voir `phase` dans le shader.
##
##   pointe des dents = gape − thick − tooth_len
##   pose 0 : +0,115   grand ouvert
##   pose 2 : −0,020   les pointes se croisent → le degat tombe ici
##   pose 7 : +0,233   rouvert, et deja presque efface
##
## ⚠️ ET C'EST `thick` QUI DOIT MAIGRIR POUR QUE `tooth_len` GROSSISSE. Les deux
## se disputent la meme borne (`gape + thick ≤ 0,395`, et la pointe doit atteindre
## la mediane) : une gencive epaisse mange l'ouverture, donc raccourcit les dents,
## donc les rend trapues — c'est ainsi que la premiere capture avait sorti des
## dents de scie. Deux passes l'ont descendue, 0,120 → 0,095 → **0,075** au
## claquement, et les crocs ont suivi dans l'autre sens : 0,175 → 0,225 → **0,262**.
##
## ⚠️ La pointe de la canine reste au MEME endroit (elle croise la mediane de
## 0,023), alors que le croc a gagne 16 % de longueur : ce qu'il gagne, il le
## gagne du cote de la RACINE, la gencive ayant recule. C'est ce qui permet
## d'allonger les crocs sans jamais toucher a l'engrenement, qui est le seul
## chiffre que le geste doit tenir.
##
## ⚠️ `gape + thick` EST BORNE A 0,395, DES DEUX COTES — voir `jaw_offset` dans
## le shader. Trop grand, le haut de la machoire est tranche net par le bord du
## quad ; trop grand aussi, le bas retombe sur le chat et le personnage se
## retrouve dans la gueule. Les huit poses sont a 0,38-0,395 : l'ouverture n'est
## pas un choix de dessin, c'est ce que l'encadrement laisse.
## ⚠️ `tooth_len` N'ENTRE PAS dans cette borne — les dents poussent vers
## l'interieur de la gueule. C'est la seule dimension du dessin qui soit libre,
## et c'est pour ca que la lisibilite passe par elle.
##
## ⚠️ `hold` — CHAQUE POSE A SA PROPRE DUREE, en multiples de `FxCadence.FX_POSE`.
##
## Deux leviers de duree sont interdits, et les avoir essayes vaut d'etre garde :
##
##   • RALENTIR LA CADENCE est exclu — §8 veut les FX plus rapides que les
##     personnages, c'est ce qui leur donne du claquant ;
##   • AJOUTER DES POSES est plafonne a 8 (§7), et on y est.
##
## Le troisieme etait dans §7 depuis le debut : *"des poses TENUES coupees par des
## transitions rapides"*. Une cadence uniforme est un metronome, pas de
## l'animation posee.
##
## 26 crans au total, soit ~830 ms — contre 500 ms avant le 2026-08-17, ou la
## morsure passait encore trop vite pour qu'on la voie. C'est tres en dessous du
## cooldown le plus court (4,2 s) : deux morsures ne peuvent pas se chevaucher.
##
## Les poses 2, 3 et 4 sont la gueule fermee, soit 15 crans sur 26 : le geste
## claque, puis il RESTE. Une morsure qui se rouvre aussitot ne se lit pas comme
## une prise.
const POSES := [
	{"gape": 0.352, "thick": 0.043, "tooth_len": 0.196, "taper": 1.5, "hold": 2},
	{"gape": 0.336, "thick": 0.059, "tooth_len": 0.226, "taper": 1.4, "hold": 2},
	{"gape": 0.320, "thick": 0.075, "tooth_len": 0.262, "taper": 1.3, "hold": 6},
	{"gape": 0.313, "thick": 0.079, "tooth_len": 0.262, "taper": 1.3, "hold": 5},
	{"gape": 0.320, "thick": 0.075, "tooth_len": 0.256, "taper": 1.4, "hold": 4},
	{"gape": 0.335, "thick": 0.060, "tooth_len": 0.221, "taper": 1.7, "hold": 3},
	{"gape": 0.351, "thick": 0.043, "tooth_len": 0.163, "taper": 2.3, "hold": 2},
	{"gape": 0.363, "thick": 0.024, "tooth_len": 0.099, "taper": 3.2, "hold": 2},
]

## La pose qui CLAQUE — les pointes passent la ligne mediane, la gencive est a son
## epaisseur maximale. Le degat tombe sur elle, comme la morsure de l'haleine
## puante tombe sur sa pose pleine : le joueur voit le coup au moment exact ou il
## coute de la vie.
##
## ⚠️ Elle arrive maintenant apres 4 crans (~133 ms) et non 2 (~67 ms) : l'ouverture
## a ete allongee parce qu'une gueule qui s'ouvre est la moitie du geste, et qu'a
## 67 ms personne ne la voyait. C'est un DELAI D'ANTICIPATION, pas de la latence —
## la cible etant fixee au clic (voir `bite_skill`), rien de ce que fait l'ennemi
## pendant ces 133 ms ne change le resultat.
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
## (`jaw_offset + gape + thick` ≈ 0,98) tombe pile sur la distance ou la morsure
## mord, quel que soit le palier.
##
## ⚠️ C'est ce qui fait que le DEGAGEMENT DU CHAT se resserre quand la portee
## grandit : il vaut `(jaw_offset − gape − thick) × portee`, soit 0,49 m a 2,6 m
## de portee et 0,68 m a 3,6 m. Il travaille donc dans le bon sens — allonger la
## portee eloigne la gueule du chat au lieu de la lui rentrer dedans.
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
	_material.set_shader_parameter("tooth_len", values["tooth_len"])
	_material.set_shader_parameter("taper", values["taper"])


func _get_game() -> Node:
	return get_tree().get_first_node_in_group("game_root")


func _is_run_paused() -> bool:
	var game = _get_game()
	return game != null and game.is_run_paused()
