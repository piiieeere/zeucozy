class_name Projectile
extends Area3D

## Projectile — la croquette lancee.
##
## Deplace dans _physics_process et non _process : l'interpolation physique est
## active sur le projet (project.godot), et un node deplace hors du tick
## physique se fait interpoler entre deux positions qu'il n'a jamais eues.

const CelStyle := preload("res://scripts/systems/cel_style.gd")

@export var speed: float = 17.5
@export var damage: int = 1
@export var max_distance: float = 10.0
@export var body_color: Color = Color("#FDD166")
@export var outline_thickness: float = 0.012

@onready var body: MeshInstance3D = $Body

var direction := Vector3.FORWARD
var travelled_distance := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	CelStyle.apply_outlined(body, body_color, outline_thickness)


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
