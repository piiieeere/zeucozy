class_name PurrHalo
extends DrivenFx

## Le halo du ronron — les deux arches qui enveloppent le chat pendant qu'il se
## refait.
##
## Meme decoupe que `breath_aura.gd` et `hiss_ring.gd` : ce script avance les
## poses et annonce les bouffees, `purr_halo.gdshader` dessine la forme et ne
## sait rien du temps.
##
## ⚠️ IL NE SOIGNE PERSONNE, exactement comme l'onde du feulement ne pousse
## personne et comme les machoires de la morsure ne blessent personne. Il annonce
## qu'une BOUFFEE vient de tomber, et `purr_skill` en tire les points de vie. Un
## FX qui distribuerait ses propres effets serait un FX qu'on ne peut plus regler
## sans toucher au gameplay.
##
## ─── LE CYCLE DE POSES *EST* L'INTERVALLE DE SOIN ───
##
## Il n'y a pas deux horloges, et c'est la lecon de l'haleine puante reprise
## telle quelle : la couronne gonfle exactement sur la pose ou elle mord. Ici la
## bouffee tombe sur la pose pleine. Le joueur voit le halo claquer au moment
## precis ou la barre de vie remonte d'un cran — sans qu'aucun chiffre ait a le
## dire.
##
## C'est aussi ce que "Gameplay et Progression" §2.10 exige : *un effet continu
## doit BATTRE*. Des points de vie rendus frame par frame seraient invisibles —
## le joueur ne saurait jamais quand il regagne du terrain, exactement comme des
## degats etales.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## La respiration d'une bouffee, pose par pose. Poses TENUES, coupees franc :
## rien n'est interpole d'une pose a la suivante (§7).
##
## Le cycle est litteralement une RESPIRATION, et c'est le meme geste que la
## couronne de l'haleine — ce qui est logique, un ronron EST une respiration.
## Les arches sont pleines et leur croissant creme ouvert au moment ou la bouffee
## soigne, puis elles se degonflent et le creme se referme, puis elles se
## remplissent pour la bouffee suivante.
##
## ⚠️ `swell` reste sous 1,0, mais PAS pour la raison de l'haleine ni du mouton.
## Ces deux-la ont un contrat de portee a tenir ; le ronron n'en a aucun (voir
## l'en-tete du shader). Ce qui le borne ici, c'est le BORD DU QUAD :
## `echo_radius + echo_thick + ink` = 0,925, et au-dela de 1,0 l'echo sort
## tranche a plat par le haut du decalque.
##
## SIX poses a la cadence des elements permanents (`AMBIENT_POSE`, 5 frames) :
## un cycle de 30 frames, soit 500 ms exactement.
##
## ⚠️ Pourquoi `AMBIENT_POSE` et non `FX_POSE` : le halo tient DEUX SECONDES a
## l'ecran. §7 tranche sur la duree de vie de l'element, jamais sur sa categorie
## — la cadence de 2 frames existe pour donner du claquant a une forme qui tient
## 200 ms, et appliquee ici elle donnerait deux secondes de battement a ~4 Hz,
## exactement ce que §8bis refuse. C'est le meme raisonnement que l'haleine, sur
## une duree intermediaire.
const POSES := [
	{"swell": 1.00, "core": 0.55},
	{"swell": 0.99, "core": 0.42},
	{"swell": 0.96, "core": 0.26},
	{"swell": 0.93, "core": 0.10},
	{"swell": 0.92, "core": 0.00},
	{"swell": 0.95, "core": 0.24},
]

## La pose qui SOIGNE — la pleine, arches gonflees et creme ouvert. Le dessin et
## le point de vie tombent sur la meme frame.
const HEAL_POSE := 0

## Combien de bouffees dure un ronron.
##
## ⚠️ CE CHIFFRE EST LA MOITIE DE LA COMPETENCE, pas un reglage de FX. Quatre
## bouffees sur 2 s, c'est ce qui fait qu'un ronron ne rattrape PAS un chat deja
## a bout : il faut l'avoir lance avant. Le rendre instantane supprimerait la
## seule decision que cette competence pose (voir `purr_skill.gd`), et le rendre
## plus long en ferait un objet qu'on lance et qu'on oublie.
const PULSES := 4

## Hauteur du centre du halo au-dessus des pattes, en metres.
##
## ⚠️ ELLE A DU MONTER DE 0,95 A 1,60, ET C'EST UNE REGLE, PAS UN GOUT. A 0,95 —
## la mi-hauteur du chat, la meme que `player.hit_height` — la bande de l'arche
## couvrait 1,46 a 1,91 m, c'est-a-dire PILE LA TETE ET LES OREILLES. Or le chat
## mesure 1,858 et ses oreilles sont sa signature de silhouette (DA §3) : c'est
## exactement ce que la plongee a 45° avait ete choisie pour preserver (§11).
## Le halo se lisait comme un CASQUE, et ca ne se voit qu'a taille de jeu.
##
## A 1,60 l'arche passe au-dessus. L'effleurement qui reste sur le haut du crane
## est VOULU : c'est ce qui attache le halo au chat au lieu de le faire flotter
## au-dessus de lui comme un decor.
const LIFT := 1.60

## Amplitude de l'inclinaison tiree au hasard, en radians (~13°). Assez pour que
## le halo cesse d'etre axe, pas assez pour qu'il paraisse tomber : au-dela de
## ~0,3 rad l'arche vient poser un de ses bouts sur la tete du chat.
const TILT_SPAN := 0.23

## Une bouffee vient de tomber — `index` compte de 0 a PULSES-1. C'est ce que
## `purr_skill` ecoute pour rendre des points de vie.
signal pulsed(index: int)

var _material: ShaderMaterial
var _pose := 0
var _pulse := 0
var _held := 0.0


## La duree totale du ronron, en secondes. Sert a la description de la carte et
## a toute sonde qui voudrait verifier que le geste tient ce qu'il annonce.
##
## `MARGIN` est rendue a la duree : elle existe pour ne pas rater un seuil quand
## `delta` oscille autour de 1/60, elle ne fait pas partie de la cadence voulue.
static func total_seconds() -> float:
	return float(PULSES * POSES.size()) * (FxCadence.AMBIENT_POSE + FxCadence.MARGIN)


func _ready() -> void:
	# Materiau propre a ce ronron : la graine et les poses sont individuelles.
	_material = (material_override as ShaderMaterial).duplicate()
	material_override = _material
	_material.set_shader_parameter("seed", randf())
	# L'inclinaison, tiree comme la graine : deux ronrons de suite ne sont pas le
	# meme tampon, et surtout un halo d'aplomb se lit comme une ICONE de signal
	# — voir `tilt` dans le shader, le defaut a ete trouve en capture.
	_material.set_shader_parameter("tilt", randf_range(-TILT_SPAN, TILT_SPAN))
	position.y = LIFT


## Le ronron commence. Appelee par `purr_skill` APRES avoir connecte `pulsed`.
##
## ⚠️ L'ORDRE N'EST PAS UN DETAIL, et le voisin montre pourquoi : `hiss_ring`
## emet sa premiere pose depuis son `setup()`, que `hiss_skill` appelle AVANT de
## se connecter — la premiere emission part donc dans le vide. C'est sans
## consequence la-bas (le front reprend a la pose suivante) et ca ne le serait
## pas ici : la premiere bouffee est la plus importante des quatre, c'est celle
## qui doit tomber tout de suite. D'ou un `start()` explicite, separe.
func start() -> void:
	_pose = HEAL_POSE
	_pulse = 0
	_held = 0.0
	_apply()
	pulsed.emit(0)


## Avance d'une frame de run vivante. Poussee par `purr_skill`, jamais par un
## `_process` a elle : le chat est en PROCESS_MODE_PAUSABLE, donc c'est le moteur
## qui arrete le ronron derriere un carton de niveau. Voir `skills/skill.gd`.
func advance(delta: float) -> void:
	_held += delta

	if _held < FxCadence.AMBIENT_POSE:
		return

	_held = 0.0
	_pose += 1

	if _pose < POSES.size():
		_apply()
		return

	_pose = HEAL_POSE
	_pulse += 1

	# Fin du ronron : le halo ne s'estompe pas, il n'est plus la (§8).
	if _pulse >= PULSES:
		queue_free()
		return

	_apply()
	# Le signal part APRES avoir pose le dessin : la bouffee et le point de vie
	# tombent sur la meme frame, comme la morsure de l'haleine puante et le degat
	# de la griffure.
	pulsed.emit(_pulse)


func _apply() -> void:
	if _material == null:
		return

	var values: Dictionary = POSES[_pose]
	_material.set_shader_parameter("swell", values["swell"])
	_material.set_shader_parameter("core", values["core"])
