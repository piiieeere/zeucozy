class_name Projectile
extends Area3D

## Projectile — la boule de poils crachee.
##
## Deplace dans _physics_process et non _process : l'interpolation physique est
## active sur le projet (project.godot), et un node deplace hors du tick
## physique se fait interpoler entre deux positions qu'il n'a jamais eues.

const CelProp := preload("res://scripts/systems/cel_prop.gd")

## Le boudin de poils roule, modelise le 2026-08-19 (`tools/build_hairball.py`).
## 288 tris, 146 sommets — §11 : "Pickups, projectiles | minimal". Avant, c'etait
## une capsule primitive `#FDD166`, jaune pale sur un parquet parchemin : moins
## de 0,10 d'ecart de valeur, soit sous le seuil de lecture releve sur le canape.
##
## ⚠️ LE MAILLAGE EST DEJA ORIENTE. Son axe long est Z en Godot (Y dans Blender),
## donc il suit la trajectoire des que le node tourne — la capsule, elle, avait
## besoin d'une matrice de rotation posee dans `projectile.tscn`, qui a disparu
## avec elle. Un jour ou l'autre quelqu'un aurait regle l'une sans l'autre.
## ⚠️ La sphere de collision suit LA TAILLE REELLE du maillage, comme celle de
## la croquette : 0,26 m, entre sa demi-largeur (0,19) et sa demi-longueur
## (0,39). Elle valait 0,30 pour une capsule de 0,13 de rayon — la boule mordait
## donc deux fois plus loin que ce qu'elle montrait, du meme defaut que la
## portee d'aura calculee en Area3D. La marge de visee, elle, vient de la
## hurtbox ennemie (0,75 m), pas d'une sphere gonflee sur le projectile.
const MODEL := "res://assets/models/projectile_boule_poils.glb"
const VARIANT := "boule_poils"

## Vitesse de rotation sur l'axe de vol, en tours par seconde.
##
## ⚠️ Elle n'existe QUE parce que le projectile a ralenti (17,5 -> 10,0 m/s au
## T1). A l'ancienne vitesse il traversait sa propre longueur en trois frames :
## faire tourner un objet qu'on ne voit pas se poser n'aurait rien montre. A
## 10 m/s il vit ~1,1 s a l'ecran, et une boule de poils qui roule sur sa
## trajectoire est la seule chose qui dise qu'elle a ete CRACHEE et non posee.
##
## Autour de l'axe de VOL et pas d'un axe du monde : c'est ce qui fait defiler
## les bourrelets sans changer la silhouette. La croquette a le probleme inverse
## et la meme parade — voir `xp_orb._physics_process`.
@export var spin_speed: float = 2.2

@export var speed: float = 10.0
@export var damage: int = 1
@export var max_distance: float = 10.0

@onready var body: MeshInstance3D = $Body

var direction := Vector3.FORWARD
var travelled_distance := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)

	# Maillage ET materiaux viennent du cache de `cel_prop` : la boule de poils
	# part toutes les 1,1 a 1,6 s pendant toute une run, et chacune fabriquant
	# les siens on aurait des centaines de ShaderMaterial pour une apparence.
	# C'est le P6 de la revue de code, regle ici par le passage au modele.
	CelProp.dress(body, MODEL, VARIANT, CelProp.PICKUP)

	# Le cap de depart, tire au hasard : deux boules crachees a la suite ne
	# doivent pas etre le meme tampon. Meme geste que l'inclinaison des
	# onomatopees et que le cap des croquettes.
	body.rotate_z(randf() * TAU)


func setup(new_direction: Vector3, new_damage: int, new_speed: float, new_max_distance: float) -> void:
	if new_direction == Vector3.ZERO:
		direction = Vector3.FORWARD
	else:
		direction = new_direction.normalized()

	damage = new_damage
	speed = new_speed
	max_distance = new_max_distance
	# La forme est allongee sur -Z : on l'aligne sur la trajectoire.
	rotation.y = atan2(-direction.x, -direction.z)


func _physics_process(delta: float) -> void:
	# Sur l'axe LOCAL de vol, pas sur celui du monde : le node a deja pivote sur
	# son Y pour viser, et tourner autour d'un axe monde ferait vaciller le
	# boudin au lieu de le faire rouler.
	body.rotate_z(spin_speed * TAU * delta)

	var step := direction * speed * delta
	global_position += step
	travelled_distance += step.length()

	if travelled_distance >= max_distance:
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	var enemy := area.get_parent() as Enemy

	if enemy != null:
		enemy.take_damage(damage)
		queue_free()
