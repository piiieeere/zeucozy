extends Node3D

## Instancie un modele .glb et lui applique le style cel du projet.
##
## Ce script etait a l'origine dans le banc de test (scripts/tests/cel_test.gd).
## Il en a ete extrait pour que le JEU et le BANC partagent exactement le meme
## rendu : un reglage corrige d'un cote profite a l'autre sans recopie.
##
## Ce qu'il reconstruit, et que le glTF ne transporte pas
## (liste complete dans "Pipeline 3D") :
##   - la palette par materiau (les nodes custom Blender ne s'exportent pas) ;
##   - le contour en coque inversee, en next_pass ;
##   - le visage peint (yeux, nez, bouche, moustaches) — rien n'est modelise ;
##   - les calottes peintes (interieur d'oreille) ;
##   - rest_undo, qui empeche les masques de glisser des qu'un os bouge.

const FACE_SHADER := preload("res://shaders/cel_face.gdshader")
const CelStyle := preload("res://scripts/systems/cel_style.gd")

# Le visage porte un shader dedie : yeux, nez, bouche et moustaches y sont
# DESSINES, jamais modelises. Voir "Visual Art Direction" §2bis.
#
# DEUX surfaces le portent. Le masque etant calcule en espace objet, il coule
# d'une surface a l'autre sans couture : le nez et la bouche atterrissent sur
# le museau qui depasse, pas sur le crane derriere lui.
const FACE_MATERIALS := ["visage", "museau_peint"]

# Moustaches : (depart.xy, arrivee.xy) en espace facial, cote droit seulement
# — le shader passe par |x| et dessine les deux cotes.
# Godot n'accepte pas de valeur par defaut sur un tableau d'uniforms.
# Portee volontairement limitee : au-dela de ~0,62 la moustache atteint le bord
# du cone facial et se ferait couper net par face_front_min.
const WHISKERS := [
	Vector4(0.16, -0.08, 0.60, 0.06),
	Vector4(0.17, -0.13, 0.63, -0.09),
	Vector4(0.16, -0.18, 0.58, -0.24),
]

# Palette par materiau — tiree de "Visual Art Direction" §4.
# Les materiaux du glTF ne transportent pas le look Blender (nodes custom),
# on repique donc les couleurs locales depuis la DA.
const PALETTE := {
	"fourrure": Color("#D89A55"),
	"corps_peint": Color("#C88A46"),
	"ventre": Color("#F0DCB8"),
	"visage": Color("#E8C48C"),
	# Pas le parchemin #F5ECD8 : trop clair, il delave son propre trait
	# (le trait colore se melange 20 % vers la couleur locale, §5.4).
	"museau_peint": Color("#F0DCB8"),
	# L'oreille n'est pas rose en entier : couleur pelage dehors, rose PEINT
	# dedans (voir PAINTED). Un chat n'a de rose que l'interieur du pavillon.
	"oreille_peinte": Color("#D89A55"),
}
const FALLBACK_COLOR := Color("#D89A55")

# Details peints par calotte procedurale — la methode des yeux, appliquee ici
# a l'interieur d'oreille. Voir "Visual Art Direction" §2bis.
#
# Le cone d'oreille est CONSERVE : contrairement aux yeux, la geometrie de
# l'oreille EST la silhouette (§3, "oreilles tres visibles et pointues").
# Ce qui disparait, c'est la surface rose separee qui produisait une tache
# plate sans contour sur le crane.
#
# Reperes en espace objet Godot (glTF Y-up) : Blender (x, y, z) -> (x, z, -y).
# Oreille Blender (0.281, -0.622, 1.472) -> Godot (0.281, 1.472, 0.622).
const PAINTED := {
	"oreille_peinte": {
		"center": Vector3(0.281, 1.472, 0.622),
		# L'oreille est mince en Z : on etire cet axe pour que le masque
		# soit pilote par l'avant/arriere et non par la hauteur.
		"squash": Vector3(1.0, 0.6, 3.0),
		"mirror_x": true,
		# Interieur du pavillon : vers l'avant (+Z), legerement ecarte (+X),
		# l'oreille etant lacet de ~23° vers l'exterieur dans Blender.
		"dirs": [Vector3(0.3, 0.0, 0.95)],
		"thresholds": [0.02],
		"colors": [Color("#E8B8A8")],
	},
}

# Quel os defaire pour retrouver la position de repos, par materiau.
# Deuxieme entree = os du cote droit, pour une paire symetrique que |x|
# dessine d'un seul jeu de formes. Voir "Pipeline 3D", piege n°4.
const REST_UNDO_BONES := {
	"visage": ["tete", ""],
	"museau_peint": ["tete", ""],
	"oreille_peinte": ["oreille_L", "oreille_R"],
}

@export_file("*.glb") var model_path: String = "res://assets/models/player_cat.glb"

## Le chat regarde +Z apres la conversion Y-up du glTF, alors que l'avant de
## Godot est -Z ("Pipeline 3D", ecart n°3). Le jeu met 180 pour le remettre
## dans le bon sens ; le banc de test garde 0, sa convention de captures
## considerant 0° comme la vue de face.
@export var yaw_offset_deg: float = 0.0

## Epaisseur du contour, en unites monde. A garder proportionnelle a la
## taille du modele (§11).
##
## Relevee de 0,035 a 0,041 avec l'arrivee d'`Attr_Style` : le canal R module
## desormais l'epaisseur et vaut ~0,85 en moyenne, la valeur d'avant donnait
## donc un trait globalement plus maigre qu'avant. 0,041 x 0,85 ≈ 0,035.
@export var outline_thickness: float = 0.041

## Attr_Style existe dans le `.glb` depuis le 2026-08-16 : R module le trait,
## G porte les ombres peintes, B autorise les accents. Voir `tools/export_cat.py`
## — l'exporteur glTF ne sait pas sortir cet attribut tout seul.
@export var use_vertex_style: bool = true

## Bord de cluster legerement irregulier — un bord de pinceau, pas une courbe
## mathematique (§2ter·2). Le shader en prend la moitie de part et d'autre :
## 0,06 donne le ±0,03 que demande Convention Blender §5.3.
@export var edge_noise: float = 0.06

## Accent de brillance sur le dessus des volumes, masque par le canal B.
## Le seul ecart autorise a la regle des 2 tons (§5.5).
@export var accent_strength: float = 0.35

## Bascule du repere facial. Compromis de cadrage sous une camera qui plonge :
## trop bas le visage passe sous l'horizon, trop haut il reste visible de dos.
@export var face_pitch_deg: float = 26.0

var mesh_instance: MeshInstance3D
var skeleton: Skeleton3D

var toon_materials: Array[ShaderMaterial] = []
var outline_materials: Array[ShaderMaterial] = []
var face_materials: Array[ShaderMaterial] = []
var paint_counts: Array[int] = []

# ShaderMaterial -> [nom d'os gauche/unique, nom d'os droit ou ""]
var _skinned_paint := {}


func _ready() -> void:
	# La bascule du visage est indissociable de la plongee de la camera : la
	# comparer en ligne de commande evite de juger une plongee avec un visage
	# regle pour une autre.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--face-pitch="):
			face_pitch_deg = float(arg.trim_prefix("--face-pitch="))

	mesh_instance = _spawn_model()

	if mesh_instance == null:
		push_warning("cel_model : aucun MeshInstance3D trouve dans %s" % model_path)
		set_process(false)
		return

	skeleton = mesh_instance.get_parent() as Skeleton3D
	_apply_cel_materials()

	# Sans surface peinte ni squelette, rest_undo reste l'identite pour
	# toujours : inutile de le recalculer a chaque frame.
	set_process(skeleton != null and not _skinned_paint.is_empty())


## Recalcule, pour chaque surface peinte, la transformation qui ramene un
## sommet deforme a sa position de repos. Sans ca, tout ce qui est peint
## (visage, interieur d'oreille) glisse sur la geometrie des qu'un os bouge.
func _process(_delta: float) -> void:
	update_rest_undo()


# ------------------------------------------------------------------ mise en place

func _spawn_model() -> MeshInstance3D:
	var packed: PackedScene = load(model_path)

	if packed == null:
		return null

	var model := packed.instantiate() as Node3D
	add_child(model)
	model.rotation_degrees.y = yaw_offset_deg
	return _find_mesh_instance(model)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var found := _find_mesh_instance(child)

		if found != null:
			return found

	return null


func _apply_cel_materials() -> void:
	var mesh := mesh_instance.mesh

	for i in mesh.get_surface_count():
		var source := mesh.surface_get_material(i)
		var mat_name := source.resource_name if source else ""
		var color: Color = PALETTE.get(mat_name, FALLBACK_COLOR)
		var is_face: bool = mat_name in FACE_MATERIALS

		var toon_mat := CelStyle.make_outlined(color, outline_thickness)
		var caps := 0

		if is_face:
			toon_mat.shader = FACE_SHADER
			toon_mat.set_shader_parameter("base_color", color)
			toon_mat.set_shader_parameter("whiskers", PackedVector4Array(WHISKERS))
			toon_mat.set_shader_parameter("face_pitch_deg", face_pitch_deg)
			face_materials.append(toon_mat)
		else:
			caps = _apply_painted_caps(toon_mat, mat_name)
			toon_mat.set_shader_parameter("accent_strength", accent_strength)

		# Attr_Style : le chat est le seul maillage a le porter. Le reste du
		# jeu garde use_vertex_style a false, sinon COLOR y vaudrait 1.0 et
		# tout partirait en pleine lumiere avec le trait le plus epais.
		toon_mat.set_shader_parameter("use_vertex_style", use_vertex_style)
		toon_mat.set_shader_parameter("edge_noise", edge_noise)
		(toon_mat.next_pass as ShaderMaterial).set_shader_parameter(
			"use_vertex_style", use_vertex_style
		)

		# Ne jamais laisser une mat4 d'uniform a sa valeur par defaut : une
		# matrice nulle ferait s'effondrer tout le masque.
		toon_mat.set_shader_parameter("rest_undo", Transform3D.IDENTITY)
		toon_mat.set_shader_parameter("rest_undo_right", Transform3D.IDENTITY)

		if REST_UNDO_BONES.has(mat_name):
			var bones: Array = REST_UNDO_BONES[mat_name]
			_skinned_paint[toon_mat] = bones

			if bones[1] != "":
				toon_mat.set_shader_parameter("rest_undo_split", true)

		mesh_instance.set_surface_override_material(i, toon_mat)

		toon_materials.append(toon_mat)
		outline_materials.append(toon_mat.next_pass as ShaderMaterial)
		paint_counts.append(caps)


func _apply_painted_caps(mat: ShaderMaterial, mat_name: String) -> int:
	if not PAINTED.has(mat_name):
		return 0

	var cfg: Dictionary = PAINTED[mat_name]
	var dirs := PackedVector3Array(cfg["dirs"])
	var thresholds := PackedFloat32Array(cfg["thresholds"])
	var colors := PackedColorArray(cfg["colors"])
	var count: int = cfg["dirs"].size()

	# Les tableaux du shader ont une taille fixe de 3 : on complete.
	while dirs.size() < 3:
		dirs.append(Vector3.FORWARD)
		thresholds.append(2.0)  # seuil inatteignable = calotte inactive
		colors.append(Color.MAGENTA)

	mat.set_shader_parameter("paint_count", count)
	mat.set_shader_parameter("paint_center", cfg["center"])
	mat.set_shader_parameter("paint_squash", cfg["squash"])
	mat.set_shader_parameter("paint_mirror_x", cfg["mirror_x"])
	mat.set_shader_parameter("paint_dir", dirs)
	mat.set_shader_parameter("paint_threshold", thresholds)
	mat.set_shader_parameter("paint_color", colors)

	return count


# ----------------------------------------------------------------------- reglages

func update_rest_undo() -> void:
	if skeleton == null:
		return

	for mat in _skinned_paint:
		var bones: Array = _skinned_paint[mat]
		mat.set_shader_parameter("rest_undo", _bone_undo(bones[0]))

		if bones[1] != "":
			mat.set_shader_parameter("rest_undo_right", _bone_undo(bones[1]))


## Inverse du delta repos -> pose de l'os. Identite quand l'os est au repos.
## Exact parce que le rig est en poids rigides ("Pipeline 3D", piege n°3).
func _bone_undo(bone_name: String) -> Transform3D:
	var bone := skeleton.find_bone(bone_name)

	if bone == -1:
		return Transform3D.IDENTITY

	var deform := skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse()
	return deform.affine_inverse()


## Etat de `Attr_Style` tel que Godot le voit reellement, par surface.
##
## Diagnostic, pas decoration : l'attribut a deja traverse le pont a moitie
## (l'exporteur glTF ne remplissait qu'une primitive sur six, voir
## `tools/export_cat.py`). C'est aussi ce qui prouve qu'aucune conversion
## sRGB ne s'applique au passage — un G peint a 0,47 doit arriver a 0,47.
func style_report() -> Array[String]:
	var lines: Array[String] = []

	if mesh_instance == null:
		return lines

	var mesh := mesh_instance.mesh

	for i in mesh.get_surface_count():
		var source := mesh.surface_get_material(i)
		var mat_name := source.resource_name if source else "<sans nom>"
		var colors: PackedColorArray = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]

		if colors.is_empty():
			lines.append("  %-15s COLOR_0 ABSENT" % mat_name)
			continue

		var lo := Vector3(2.0, 2.0, 2.0)
		var hi := Vector3(-1.0, -1.0, -1.0)
		var sum := Vector3.ZERO

		for c in colors:
			var v := Vector3(c.r, c.g, c.b)
			lo = lo.min(v)
			hi = hi.max(v)
			sum += v

		var mean := sum / float(colors.size())
		lines.append("  %-15s R %.2f/%.2f/%.2f  G %.2f/%.2f/%.2f  B %.2f/%.2f/%.2f" % [
			mat_name,
			lo.x, mean.x, hi.x,
			lo.y, mean.y, hi.y,
			lo.z, mean.z, hi.z,
		])

	return lines


func set_face_pitch(value: float) -> void:
	face_pitch_deg = clampf(value, 0.0, 60.0)

	for mat in face_materials:
		mat.set_shader_parameter("face_pitch_deg", face_pitch_deg)


func set_outline_enabled(enabled: bool) -> void:
	for i in toon_materials.size():
		toon_materials[i].next_pass = outline_materials[i] if enabled else null


func set_paint_enabled(enabled: bool) -> void:
	for i in toon_materials.size():
		toon_materials[i].set_shader_parameter(
			"paint_count", paint_counts[i] if enabled else 0
		)

	# Le visage se coupe autrement : un seuil d'orientation inatteignable.
	for mat in face_materials:
		mat.set_shader_parameter("face_front_min", 0.12 if enabled else 2.0)
