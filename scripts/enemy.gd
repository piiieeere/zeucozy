class_name Enemy
extends CharacterBody3D

## Ennemi de base — suit le joueur et lui fait mal au contact.
##
## DEUX APPARENCES POSSIBLES, et une seule ligne les separe :
##
##   * `model_path` vide  -> une PRIMITIVE cel-shadee (`body_color` +
##     `outline_thickness`) ;
##   * `model_path` rempli -> un .glb habille par `CelProp`, comme le canape et
##     les ramassables.
##
## ⚠️ PLUS AUCUN ENNEMI N'EMPRUNTE LA PREMIERE BRANCHE depuis le 2026-08-19 : le
## chaser est la souris, la brute est le chien. C'etait le dernier placeholder de
## primitive du gameplay.
##
## Elle est gardee quand meme, et ce n'est pas de la sentimentalite : elle vaut
## trois lignes, et il reste trois ennemis a modeliser (aspirateur, concombre, le
## boss veterinaire). Un ennemi neuf doit pouvoir exister et s'equilibrer avant
## d'exister en .blend — c'est exactement ce qu'ont fait le chaser et la brute
## pendant tout le prototype. Ne PAS la supprimer pour "nettoyer" : ce qu'on
## supprimerait, c'est la possibilite de commencer par le gameplay.

signal defeated(world_position: Vector3, xp_value: int)

@export var base_speed: float = 3.7
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var xp_drop: int = 1

@export var body_color: Color = Color("#FFADAD")
## Epaisseur du contour, en unites monde — proportionnelle a la taille de la
## forme, sinon le placeholder parait sur-cerne ("Visual Art Direction" §11).
## Ne sert qu'aux ennemis restes en primitive : un .glb prend celle de sa famille.
@export var outline_thickness: float = 0.03

## Le modele, quand l'ennemi en a un. Vide = primitive — voir l'en-tete.
@export var model_path: String = ""
## La variante de palette dans `CelProp.PALETTES`. Vide n'a de sens que si
## `model_path` l'est aussi.
@export var model_variant: String = ""

## Vitesse de rotation du modele vers le chat.
##
## ⚠️ ELLE N'EXISTE QUE DEPUIS QU'UN ENNEMI A UN AVANT. Tant que les deux
## ennemis etaient une capsule et une sphere, rien ici ne tournait — et personne
## ne pouvait s'en apercevoir, une primitive de revolution ayant la meme
## silhouette sous tous les caps. Une souris qui glisse en crabe, elle, se voit
## immediatement.
##
## Plus vive que celle du chat (12,0 pour ~7,5 m/s) rapportee a sa vitesse : une
## souris pivote sec, c'est ce qui la separe d'un objet pousse.
@export var turn_speed: float = 10.0

const CelStyle := preload("res://scripts/systems/cel_style.gd")
const CelProp := preload("res://scripts/systems/cel_prop.gd")

@onready var damage_area: Area3D = $DamageArea
@onready var body: MeshInstance3D = $Body
@onready var shadow: MeshInstance3D = $Shadow

var current_health := 0
var target: Node3D
var damage_cooldown := 0.0

## Le RECUL — vitesse imposee de l'exterieur, qui remplace la poursuite tant
## qu'elle n'est pas retombee. Posee par `push()`, freinee par `_knockback_drag`.
##
## ⚠️ Elle REMPLACE la poursuite au lieu de s'y ajouter, et c'est ce qui la rend
## lisible : additionnee, une poussee de 15 m/s contre une course de 3,7 m/s
## donne 11,3 m/s, soit le meme mouvement en un peu moins fort — le joueur ne
## verrait pas le recul, il verrait un ennemi qui rame. Remplacee, l'ennemi part
## en arriere pour de bon, puis reprend sa marche : deux etats nets plutot qu'un
## melange, ce qui est la meme regle que les poses tenues de §7.
var _knockback := Vector3.ZERO
var _knockback_drag := 32.0


func _ready() -> void:
	# Le SEUL groupe qui reste dans le jeu, et le seul qui se justifie : ce n'est
	# pas un singleton deguise, c'est un ENSEMBLE — "tous les ennemis vivants",
	# que six armes interrogent a chaque frame. Il n'a plus qu'un lecteur,
	# `GameRoot.enemies()`, qui le rend type (voir P3 de la revue de code) : une
	# competence ne cherche plus rien elle-meme, elle demande au jeu.
	add_to_group("enemies")
	current_health = max_health

	if model_path.is_empty():
		CelStyle.apply_outlined(body, body_color, outline_thickness)
		# Meme regle que les ennemis modelises, qui la tiennent de `CelProp` :
		# ce qui bouge recoit le soleil et ne le projette pas (2026-08-20).
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		# `dress` et non `spawn` : le noeud `Body` existe deja dans la scene, et
		# une vague en pose jusqu'a cinq d'un coup. Instancier la PackedScene du
		# .glb par ennemi ajouterait un Node3D chacun pour un maillage et des
		# materiaux qui sont de toute facon partages (le cache de `CelProp`).
		CelProp.dress(body, model_path, model_variant, CelProp.CREATURE)

	CelStyle.apply_contact_shadow(shadow)


func setup(new_target: Node3D, difficulty_scale: float) -> void:
	target = new_target

	# Le cap est POSE d'un coup a l'apparition, jamais interpole depuis le cap
	# par defaut : un ennemi qui nait dos au chat et pivote en 0,2 s se lit comme
	# s'il avait hesite, alors qu'il vient d'arriver.
	_face_target(INF)
	max_health = max(1, int(round(max_health * difficulty_scale)))
	current_health = max_health
	base_speed *= 1.0 + (difficulty_scale - 1.0) * 0.35

	# ⚠️ CETTE LIGNE NE FAISAIT RIEN AVANT LE 2026-08-16, et personne ne pouvait
	# le voir : `contact_damage` valait 1 pour le chaser, donc `round(1 * 1,2)`
	# rendait 1. Il fallait un facteur de 1,5 — soit 225 s de run — pour que le
	# degat passe enfin a 2, c'est-a-dire DOUBLE d'un coup.
	#
	# Le passage de la vie du joueur en points (6 → 100) a remis les degats a
	# l'echelle (1 → 15, 2 → 30), et l'arrondi cesse de tout ecraser : le chaser
	# monte desormais de 15 a ~21 en continu sur une run. C'est un EFFET DE BORD
	# du changement d'echelle, pas une decision d'equilibrage — la montee en
	# difficulte fait enfin ce que cette ligne dit depuis le debut, et la fin de
	# run est donc plus dure qu'avant.
	contact_damage = max(1, int(round(contact_damage * (1.0 + (difficulty_scale - 1.0) * 0.2))))


## Aucune garde de pause : les ennemis vivent sous le node `Enemies`, qui est en
## PROCESS_MODE_PAUSABLE (main.tscn). Derriere un carton, Godot n'appelle plus
## cette methode — et il coupe aussi les serveurs physiques, donc les
## recouvrements d'Area3D cessent d'eux-memes.
func _physics_process(delta: float) -> void:
	if damage_cooldown > 0.0:
		damage_cooldown -= delta

	if _knockback.length_squared() > 0.01:
		# Repousse : la poursuite attend. Voir `_knockback`.
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector3.ZERO, _knockback_drag * delta)
	elif is_instance_valid(target):
		# Poursuite a plat : tout le jeu vit dans le plan XZ.
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		velocity = to_target.normalized() * base_speed
	else:
		velocity = Vector3.ZERO

	move_and_slide()
	_face_target(delta)

	if damage_cooldown > 0.0:
		return

	for area in damage_area.get_overlapping_areas():
		# ⚠️ `as Player` ET NON `has_method("take_damage")`. Le chat et l'ennemi
		# portent tous deux une methode de ce nom, avec des signatures
		# DIFFERENTES (celle du chat prend la position de l'agresseur en plus).
		# Le jour ou un masque de collision bouge et qu'une DamageArea ennemie
		# croise une Hurtbox ennemie, `has_method` laissait passer l'appel et
		# l'erreur d'arite tombait en pleine frame de jeu. Avec le type, un
		# ennemi rend simplement `null` — et une erreur d'appel se voit
		# desormais a la compilation.
		var actor := area.get_parent() as Player

		if actor != null:
			# La position sert a placer l'eclat de collision, pas a calculer le
			# degat : c'est le chat qui decide ou tombe le point de contact.
			actor.take_damage(contact_damage, global_position)
			damage_cooldown = 0.7
			break


## Le modele regarde LA CIBLE, jamais sa propre vitesse — et la nuance ne se voit
## que quand le recul entre en jeu. Un ennemi repousse recule en CONTINUANT de
## faire face au chat ; s'il s'orientait sur sa vitesse, il partirait en marche
## arriere puis ferait demi-tour, ce qui se lit comme une fuite et non comme un
## coup encaisse.
##
## C'est `$Body` qui tourne, jamais le CharacterBody3D — meme partage que le
## chat, dont seul `$Model` pivote. Les formes de collision sont un cylindre et
## deux spheres : les faire tourner ne changerait rien, mais ca ferait croire au
## lecteur suivant que l'orientation compte pour la physique.
##
## Un objet Godot tourne de rotation.y regarde (-sin y, 0, -cos y) : d'ou l'atan2
## sur les composantes negatives. Meme formule que `player._face_direction`.
## `delta` infini pose le cap d'un coup (voir `setup`).
func _face_target(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0

	if to_target.length_squared() < 1.0e-6:
		return

	var wanted := atan2(-to_target.x, -to_target.z)
	body.rotation.y = lerp_angle(body.rotation.y, wanted, 1.0 - exp(-turn_speed * delta))


## Repousse. `direction` est la direction DU CHAT VERS L'ENNEMI, deja normalisee
## par l'appelant : c'est lui qui sait d'ou vient l'onde, pas nous.
##
## ⚠️ La composante verticale est ecrasee. Tout le jeu vit dans le plan XZ, et un
## ennemi qui decollerait ne retomberait jamais — rien ici n'a de gravite.
func push(direction: Vector3, speed: float, drag: float) -> void:
	direction.y = 0.0

	if direction.length_squared() < 1e-6:
		return

	# La plus forte gagne, elle ne s'ajoute pas : deux ondes coup sur coup ne
	# doivent pas envoyer un ennemi a l'autre bout de l'arene.
	var wanted := direction.normalized() * speed

	if wanted.length() >= _knockback.length():
		_knockback = wanted
		_knockback_drag = maxf(1.0, drag)


func take_damage(amount: int) -> void:
	current_health = max(0, current_health - max(1, amount))

	if current_health <= 0:
		defeated.emit(global_position, xp_drop)
		queue_free()
