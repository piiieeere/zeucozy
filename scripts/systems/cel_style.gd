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
const GROUND_SHADER := preload("res://shaders/cel_ground.gdshader")
const RUG_SHADER := preload("res://shaders/cel_rug.gdshader")

## Trait principal — brun chaud. Jamais de noir pur, meme sur un contour (§4).
const INK := Color("#3D2B1A")

## Reglage de la flaque de lumiere au sol.
##
## UNE seule source, recopiee telle quelle dans le sol et dans les tapis. C'est
## la meme raison que "ne jamais recopier les constantes de cel_model.gd" : deux
## valeurs qui divergent d'un demi-pouce et le bord de la flaque saute des qu'on
## passe sur un tapis, ce qui redessine exactement le decoupage geometrique que
## le style existe pour cacher.
const POOL := {
	"pool_scale": 26.0,
	# Au-dessus de 0,5 : la part ensoleillee est MINORITAIRE. Un sol a moitie
	# au soleil n'a plus de rai, il a deux moities.
	"pool_level": 0.56,
	"pool_wobble": 0.40,
	"sun_color": Color("#FFD6A5"),
	"sun_strength": 0.26,
	"shadow_hue_shift": -0.02,
	"shadow_saturation": 1.10,
	"shadow_value": 0.88,
}


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
##
## `ink` se surcharge parce qu'un trait doit rester plus SOMBRE que l'aplat
## qu'il cerne. Sur une couleur claire, INK convient partout ; sur la fourrure
## noire du chat, il passerait au-dessus de son propre ton d'ombre et le
## contour se lirait en clair. Voir INKS dans cel_model.gd.
static func make_outlined(
	color: Color, thickness: float, ink: Color = INK, tint: float = 0.2
) -> ShaderMaterial:
	var mat := make_flat(color)

	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("ink_color", ink)
	# Trait colore : le contour tire vers la couleur qu'il cerne (§5.4).
	outline.set_shader_parameter("tint_target", color)
	outline.set_shader_parameter("tint_amount", tint)
	outline.set_shader_parameter("thickness", thickness)

	mat.next_pass = outline
	return mat


## Le parquet peint. Un seul plan, un seul materiau : le motif est procedural
## et ancre au monde, pas a l'UV du plan (voir cel_ground.gdshader).
static func make_ground() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	_apply_pool(mat)
	return mat


## Un tapis. `size` est son emprise nominale en metres, `plane_size` celle du
## plan qui le porte — plus grande, pour laisser la silhouette onduler hors du
## rectangle sans etre tranchee. Le shader a besoin des deux : la premiere pour
## sa forme, la seconde pour convertir son UV en metres.
static func make_rug(color: Color, size: Vector2, plane_size: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RUG_SHADER
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("rug_size", size)
	mat.set_shader_parameter("plane_size", plane_size)
	# Le liseré interieur suit la taille du tapis, sinon un petit tapis se
	# retrouve entierement mange par son propre liseré.
	mat.set_shader_parameter("band_inset", clampf(minf(size.x, size.y) * 0.09, 0.25, 1.1))
	_apply_pool(mat)
	return mat


static func _apply_pool(mat: ShaderMaterial) -> void:
	for key: String in POOL:
		mat.set_shader_parameter(key, POOL[key])


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
