class_name BreathAura
extends DrivenFx

## L'haleine puante — l'aura de souffle du chat, premiere competence lootable.
##
## Une couronne de volutes posee au sol autour du chat, qui blesse en continu
## tout ennemi entre dedans. Elle n'existe que si le joueur a pris l'upgrade
## "Haleine puante", et elle grandit — rayon ET degats — a chaque reprise.
##
## Trois choses la distinguent de la griffure, et elles vont ensemble :
##
##   * elle ne se dirige pas et ne se declenche pas. La griffure demande de
##     viser ; l'haleine puante demande de LAISSER VENIR. C'est la premiere
##     mecanique du jeu qui recompense de rester au contact ;
##   * elle frappe FAIBLE et SANS ARRET la ou la griffure frappe fort et par
##     a-coups. C'est ce qui les rend cumulables sans se doubler ;
##   * elle porte moins loin que la griffure (2,8 m contre 5,2). Un ennemi
##     touche par le souffle est deja a portee de mordre le chat — c'est le prix
##     assume d'une arme qui ne demande rien au joueur.
##
## Ce script fait deux choses et pas une de plus : avancer les poses, et mordre
## sur l'une d'elles. Toute la FORME est dans breath_aura.gdshader, qui, lui, ne
## sait rien du temps.

const FxCadence := preload("res://scripts/systems/fx_cadence.gd")

## Le souffle, pose par pose. Poses TENUES, coupees franc : rien n'est interpole
## d'une pose a la suivante (§7).
##
## Le cycle est une RESPIRATION : les volutes sont pleines et leur coeur creme
## ouvert au moment ou le souffle mord, puis elles se degonflent et leur coeur se
## referme, puis elles se remplissent a nouveau pour la morsure suivante.
##
## ⚠️ Le gonflement ne depasse JAMAIS 1,0. La crete d'une volute pleine affleure
## exactement le bord de la zone de degats : au-dela, le dessin promettrait une
## portee que la morsure n'a pas. Il respire donc vers l'interieur, ou il n'a
## rien a mentir.
##
## HUIT poses — le plafond de §7 — a la cadence des elements permanents
## (`AMBIENT_POSE`, 5 frames par pose) : un cycle de 40 frames, ~667 ms.
## La cadence de FX (2 frames) a ete essayee et rejetee : sur une aura toujours
## affichee elle donne un battement a ~4 Hz, ce que §8bis refuse explicitement
## sur la duree d'une run.
const POSES := [
	{"swell": 1.00, "core": 0.45},
	{"swell": 0.99, "core": 0.36},
	{"swell": 0.96, "core": 0.24},
	{"swell": 0.93, "core": 0.10},
	{"swell": 0.91, "core": 0.00},
	{"swell": 0.92, "core": 0.00},
	{"swell": 0.95, "core": 0.13},
	{"swell": 0.98, "core": 0.29},
]

## La pose qui MORD, et c'est la pleine — celle dont les volutes sont gonflees
## et le coeur ouvert. Le dessin et le degat tombent donc sur la meme frame :
## le joueur voit le souffle claquer au moment exact ou il coute de la vie a
## l'ennemi, sans qu'aucun FX supplementaire ait a le dire.
const BITE_POSE := 0

## Derive de la couronne, en radians par pose. Un souffle tourne — mais lentement
## et EN PAS, comme tout le reste. La periode d'une volute vaut TAU/11 ≈ 0,57 rad :
## a ce pas, le motif ne se repose sur lui-meme qu'au bout de ~2,4 s, et rien ne
## se lit comme une roue dentee.
const VOLUTE_DRIFT := 0.018

var radius := 2.8
var damage := 1

var _material: ShaderMaterial
var _pose := 0
var _held := 0.0
var _spin := 0.0


## L'intervalle entre deux morsures : un cycle complet de poses. C'est aussi le
## denominateur des degats par seconde affiches dans l'ATH.
##
## `MARGIN` est rendue a la duree : elle sert a ne pas rater un seuil quand
## `delta` oscille autour de 1/60, elle ne fait pas partie de la cadence voulue.
## Le vrai cycle est de 8 poses x 5 frames.
static func cycle_seconds() -> float:
	return float(POSES.size()) * (FxCadence.AMBIENT_POSE + FxCadence.MARGIN)


static func damage_per_second(tick_damage: int) -> float:
	return float(tick_damage) / cycle_seconds()


func _ready() -> void:
	# Materiau propre a cette aura : la graine et les poses sont individuelles.
	_material = (material_override as ShaderMaterial).duplicate()
	material_override = _material
	_material.set_shader_parameter("seed", randf())
	_spin = randf() * TAU

	# On demarre sur la DERNIERE pose pour que le premier pas retombe sur la
	# morsure : la competence qu'on vient de prendre doit mordre tout de suite,
	# pas au bout d'un cycle entier.
	_pose = POSES.size() - 1
	_apply()


## Appelee a chaque palier — le premier comme les suivants. Les valeurs viennent
## du catalogue via `breath_skill` : cette aura ne sait pas ce qu'est un palier,
## elle ne sait que dessiner un rayon et mordre pour des degats.
func setup(new_radius: float, new_damage: int) -> void:
	radius = maxf(0.5, new_radius)
	damage = max(1, new_damage)
	_apply()


## Avance d'une frame. Poussee par `breath_skill`, jamais par un `_process` a
## elle — et ce n'est pas un detail de plomberie.
##
## Cette aura testait la pause elle-meme, avec son `_get_game()` et son
## `_is_run_paused()` prives. C'etait tenable a une competence ; a seize (§2.3),
## c'est seize endroits ou oublier de s'arreter derriere un carton de niveau, et
## le defaut serait INVISIBLE — une aura qui continue de mordre pendant qu'on
## choisit une upgrade ne se voit pas, elle se constate a la barre de vie d'un
## ennemi. L'horloge vient donc de dehors, une fois. Voir `skills/skill.gd`.
##
## Et depuis le 2026-08-18 plus personne ne teste la pause du tout : elle est
## celle du moteur (`get_tree().paused`), et le chat est en
## PROCESS_MODE_PAUSABLE — l'horloge s'arrete a sa source.
func advance(delta: float) -> void:
	_held += delta

	if _held < FxCadence.AMBIENT_POSE:
		return

	_held = 0.0
	_pose = (_pose + 1) % POSES.size()
	_spin += VOLUTE_DRIFT
	_apply()

	if _pose == BITE_POSE:
		_bite()


## La morsure. Pas d'Area3D, et ce n'est pas un raccourci : le dessin est un
## cercle de rayon `radius` autour du chat, et un test de distance au centre EST
## ce cercle. Une sphere de collision aurait ajoute le rayon de la hurtbox de
## l'ennemi (0,75 m) a la portee reelle — le souffle aurait mordu 27 % plus loin
## que ce qu'il montre. La griffure resout le meme probleme de la meme facon :
## la sphere donne les candidats, un test explicite donne la verite.
func _bite() -> void:
	var here := global_position

	# Une liste, pas un iterateur vif : `take_damage` peut liberer l'ennemi.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy

		if not is_instance_valid(enemy):
			continue

		var to_enemy := enemy.global_position - here
		# Tout le jeu vit dans le plan XZ : la hauteur ne doit pas rogner le rayon.
		to_enemy.y = 0.0

		if to_enemy.length() > radius:
			continue

		enemy.take_damage(damage)


func _apply() -> void:
	if _material == null:
		return

	var values: Dictionary = POSES[_pose]
	# Le shader travaille en DIAMETRE : son quad va de -1 a 1, donc 1 = le rayon.
	_material.set_shader_parameter("size", radius * 2.0)
	_material.set_shader_parameter("spin", _spin)
	_material.set_shader_parameter("swell", values["swell"])
	_material.set_shader_parameter("core", values["core"])
