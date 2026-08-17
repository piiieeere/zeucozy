extends CanvasLayer

## 💤 EN SOMMEIL DEPUIS LE 2026-08-17 — plus personne n'appelle `flash()`.
##
## Debranche a la demande : plein cadre, deux frames, il se lisait comme un
## flash desagreable plutot que comme un coup encaisse. Meme traitement que le
## projectile — la scene, le script, le shader et le noeud de `main.tscn` sont
## gardes ENTIERS, seul l'appel a disparu (voir `_on_player_hit` dans main.gd).
## Le rebrancher tient en une ligne.
##
## ⚠️ Le retour de degat n'a PAS disparu pour autant, et c'est ce qui rend le
## debranchement acceptable : §8 demandait deux effets qui se partagent le
## travail — l'eclat DIT ou ca a cogne, le flash disait que c'etait un coup.
## L'eclat (`hit_burst`), lui, reste branche. Ce qui part, c'est la couche
## PLEIN CADRE ; ce qui reste, c'est celle qui porte l'information.
##
## ─────────────────────────────────────────────────────────────────────────
##
## L'impact frame — "Visual Art Direction" §7 et §8.
##
## Le flash ambre plein cadre quand LE CHAT encaisse un coup. Rien a voir avec
## les projectiles qui touchent les ennemis : c'est le feedback de degat du
## joueur. §8 reserve l'impact frame aux "gros coups" — dans un survivor a 6
## points de vie ou une touche coute 1/6 de la run, chaque contact en est un.
##
## Place SOUS le post-process (layer -1, donc dessine avant RetroPost) : un
## impact frame est une frame de l'IMAGE, pas un calque d'interface. Le grain
## de §8bis doit passer par-dessus, sinon le
## flash se lit comme un element d'UI colle sur le film. Le HUD, lui, reste
## au-dessus des deux — c'est de l'interface, il ne clignote pas avec le chat.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## Ambre Ghibli (§4). §8 est explicite : le flash est ambre, et jamais blanc.
##
## Ce n'est PAS le rose-rouge #D45870 que §4 range en "hit feedback" : ce
## rose-la est porte par l'eclat de collision (hit_burst.gd), qui est le FX
## qui DIT le degat. Le flash, lui, ne dit que la violence du coup — d'ou
## l'ambre, et d'ou le partage des roles voulu par §8.
const FLASH_COLOR := Color("#D4A860")

## Le flash, pose par pose. §7 : "impact frame (flash) — 1 a 2 frames
## seulement". Deux poses donc, puis une coupe FRANCHE — pas de fondu (§8).
##
## La seconde vaut moins de la moitie de la premiere : c'est ce qui donne un
## sens de lecture au flash. Deux poses egales se liraient comme un
## clignotement de moniteur, pas comme un coup encaisse.
##
## Intensites volontairement CONTENUES. Mesure a 0,85 sur les frames
## enregistrees, le flash noyait toute l'image et devenait lui-meme le sujet ;
## or ce qu'on doit lire d'abord, c'est l'eclat, la ou ca a cogne. Le flash
## accompagne, il n'annonce pas.
const FLASH: Array[float] = [0.55, 0.22]

## Duree d'une pose : une frame de jeu (§7). Une pose doit surtout etre
## REELLEMENT dessinee au moins une fois — sur un ecran a 144 Hz elle couvre
## trois frames d'affichage, sur un ecran a 30 Hz une seule. Dans les deux cas
## l'impact frame reste ce qu'elle est : une frame d'animation.
const POSE_TIME := FxCadence.GAME_FRAME

@onready var screen: ColorRect = $Screen

var _material: ShaderMaterial
var _pose := 0
var _held := 0.0


func _ready() -> void:
	_material = screen.material
	_material.set_shader_parameter("flash_color", FLASH_COLOR)
	_stop()


## Declenche l'impact frame.
##
## Un coup pendant qu'elle tourne la RELANCE au lieu de la prolonger : deux
## flashs qui se chevauchent produiraient un fondu, exactement ce que §8
## interdit. Le chat est de toute facon invulnerable 0,45 s apres un coup, donc
## le cas ne se presente qu'a la marge.
##
## La premiere pose n'est pas ecrite ici mais dans `_process` : `take_damage`
## est appele depuis le tick physique, et Godot fait tourner `_process` APRES
## la physique et AVANT le rendu. La pose 0 est donc bien dessinee sur cette
## frame-ci — mais sans consommer son propre temps de tenue au passage.
func flash() -> void:
	_pose = -1
	_held = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if _pose < 0:
		_show(0)
		return

	_held += delta

	if _held < POSE_TIME:
		return

	_held = 0.0
	_show(_pose + 1)


func _show(pose: int) -> void:
	if pose >= FLASH.size():
		_stop()
		return

	_pose = pose
	screen.visible = true
	_material.set_shader_parameter("flash", FLASH[pose])


## Coupe franche. Le ColorRect est CACHE, pas seulement remis a zero : invisible
## il ne declenche plus la copie d'ecran que reclame `hint_screen_texture`, et
## l'effet ne coute donc rien tant que le chat n'est pas touche.
func _stop() -> void:
	_pose = 0
	screen.visible = false
	set_process(false)
