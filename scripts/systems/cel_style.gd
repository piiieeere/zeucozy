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
const WALL_SHADER := preload("res://shaders/cel_wall.gdshader")

## Trait principal — brun chaud. Jamais de noir pur, meme sur un contour (§4).
const INK := Color("#3D2B1A")

## ⚠️ LA FLAQUE DE LUMIERE A ETE RETIREE LE 2026-08-17, et `POOL` avec elle.
##
## Sol et tapis sont desormais eclaires UNIFORMEMENT : chacun porte sa couleur
## de palette, sans ton de soleil ni ton d'ombre. Le motif et ses reglages sont
## conserves dans le bandeau en tete de `cel_ground.gdshader`.
##
## Ce qui a tue la flaque n'etait pas son dessin mais son ANCRAGE : ancree au
## monde, comme tout le motif du parquet, elle DEFILAIT en diagonale sur toute
## la largeur du cadre des que le chat marchait — et une grande bande claire qui
## traverse l'ecran en permanence se lit comme un artefact d'affichage.
##
## Ce que `POOL` disait, en revanche, reste vrai de toute lumiere de sol qui
## reviendrait : UNE seule source, recopiee telle quelle dans le sol et dans les
## tapis. Deux valeurs qui divergent d'un demi-pouce et le bord de la flaque
## saute des qu'on passe sur un tapis — ce qui redessine exactement le decoupage
## geometrique que le style existe pour cacher.


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
##
## A `thickness` nulle le contour est RETIRE, jamais laisse a zero. Une coque
## inversee d'epaisseur nulle n'est pas invisible : ses faces arriere tombent
## exactement sur les faces avant et les deux se disputent le z-buffer, ce qui
## marbre la surface au lieu de la laisser nue.
static func make_outlined(
	color: Color, thickness: float, ink: Color = INK, tint: float = 0.2
) -> ShaderMaterial:
	return with_outline(make_flat(color), color, thickness, ink, tint)


## Pose le contour en coque inversee sur un materiau DEJA construit.
##
## Sorti de `make_outlined` le 2026-08-20, quand le mur est arrive avec son
## propre shader d'aplat : c'est la meme coque, les memes trois reglages, et
## deux copies auraient diverge a la premiere correction d'epaisseur.
static func with_outline(
	mat: ShaderMaterial, color: Color, thickness: float, ink: Color = INK, tint: float = 0.2
) -> ShaderMaterial:
	if thickness <= 0.0:
		return mat

	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("ink_color", ink)
	# Trait colore : le contour tire vers la couleur qu'il cerne (§5.4).
	outline.set_shader_parameter("tint_target", color)
	outline.set_shader_parameter("tint_amount", tint)
	outline.set_shader_parameter("thickness", thickness)

	mat.next_pass = outline
	return mat


## Le mur d'arene. `color` sert au teintage du trait, pas a l'aplat : la valeur
## du mur est arretee dans `cel_wall.gdshader`, ou vit le raisonnement qui l'a
## choisie contre le parquet.
##
## `thickness` porte les DEUX poids d'encre que "Prompts de Generation" §4.7
## tranche sur le meme objet : plein pour l'arete qui dit « ici on ne passe
## plus », moitie pour tout ce qui est dessine a l'interieur.
static func make_wall(thickness: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WALL_SHADER
	# La couleur est LUE dans le shader, jamais recopiee ici : `cel_wall` est
	# la seule a la porter, et le contour doit tirer vers elle (§5.4).
	#
	# ⚠️ Et elle rend `null` en `--headless` : sans serveur de rendu, il n'y a
	# pas de shader compile a interroger. `pause_probe` construit une arene
	# entiere dans ce mode — sans le garde, il tombe sur une affectation de Nil
	# et 18 verdicts partent avec. Le repli n'a aucun effet visible : sans
	# rendu, il n'y a pas de trait a teinter.
	var default: Variant = RenderingServer.shader_get_parameter_default(
		mat.shader.get_rid(), "base_color"
	)
	var color: Color = default if default is Color else INK
	return with_outline(mat, color, thickness)


## L'aplat vu DERRIERE une baie. Un seul ton, aucun paysage, aucun nuage.
##
## Le seul materiau du monde qui reste `unshaded`, avec le contour et les FX, et
## pour la meme raison qu'eux : il n'est pas dans la piece. Laisser le mur lui
## jeter son ombre reviendrait a peindre un ciel assombri par le batiment qu'il
## eclaire.
##
## ⚠️ Il ne CASTE pas non plus — c'est `arena` qui l'eteint, et ce n'est pas un
## detail : pose entre le soleil et la baie, un ciel casteur bouche exactement
## le rai qu'on est en train de construire.
##
## ⚠️ ET IL NE DOIT PAS DEVENIR LE POINT LE PLUS CLAIR DU CADRE (§4.7) : le
## chat doit garder l'œil. #A0C8D8 a une luma de 0,76, sous le parquet (0,83) —
## c'est un trou plus sombre que le sol, pas une lampe.
static func make_sky(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Le parquet peint. Un seul plan, un seul materiau : le motif est procedural
## et ancre au monde, pas a l'UV du plan (voir cel_ground.gdshader).
static func make_ground() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
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
