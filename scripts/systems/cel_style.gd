extends RefCounted

## Fabrique de materiaux cel-shades pour la geometrie SANS modele dedie :
## ennemis placeholder, projectiles, croquettes, decor de l'arene.
##
## Le chat passe par cel_model.gd — il a une palette par materiau, un visage
## peint et des calottes procedurales, ce qui n'a pas de sens ici.
##
## Voir "Visual Art Direction" §4 (palette) et §11 (epaisseur de trait
## proportionnelle a la taille de l'objet).

const TOON_SHADER := preload("res://shaders/cel_toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/cel_outline.gdshader")

## Trait principal — brun chaud. Jamais de noir pur, meme sur un contour (§4).
const INK := Color("#3D2B1A")


## Aplat cel sans contour. Pour le sol et les zones de couleur posees dessus :
## une coque inversee sur une surface plane pousse ses sommets vers le haut et
## ne produit rien de visible en vue plongeante.
static func make_flat(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("base_color", color)
	return mat


## Aplat cel + contour en coque inversee (cel_outline en next_pass).
## `thickness` est en unites monde : la donner proportionnelle a la taille de
## l'objet, sinon les petits assets paraissent sur-cernes (§11).
static func make_outlined(color: Color, thickness: float) -> ShaderMaterial:
	var mat := make_flat(color)

	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("ink_color", INK)
	# Trait colore : le contour tire vers la couleur qu'il cerne (§5.4).
	outline.set_shader_parameter("tint_target", color)
	outline.set_shader_parameter("thickness", thickness)

	mat.next_pass = outline
	return mat


## Ombre de contact — la petite tache posee sous un personnage.
##
## Seul materiau non-cel du jeu, et c'est assume : en vue plongeante sans elle
## tout le monde flotte, et c'est la seule chose qui doit se MELANGER au sol,
## dont la couleur change d'un tapis a l'autre. Un aplat opaque devrait donc
## connaitre la couleur de ce qu'il recouvre — ce qu'il ne peut pas.
static func make_contact_shadow() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Brun chaud translucide, jamais un gris neutre (§4).
	mat.albedo_color = Color(INK.r, INK.g, INK.b, 0.20)
	return mat


static func apply_flat(mesh_instance: MeshInstance3D, color: Color) -> void:
	mesh_instance.material_override = make_flat(color)


static func apply_contact_shadow(mesh_instance: MeshInstance3D) -> void:
	mesh_instance.material_override = make_contact_shadow()


static func apply_outlined(mesh_instance: MeshInstance3D, color: Color, thickness: float) -> void:
	mesh_instance.material_override = make_outlined(color, thickness)
