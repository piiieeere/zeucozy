extends RefCounted

## Le style des MEUBLES modelises — pendant statique de cel_model.gd.
##
## Trois fabriques de style coexistent, et le decoupage n'est pas arbitraire :
##
##   cel_style.gd  primitives sans modele (ennemis placeholder, murs, sol).
##                 Une couleur, un contour, rien de peint.
##   cel_prop.gd   modeles .glb SANS squelette — les meubles. Palette par
##                 materiau et Attr_Style, mais ni rest_undo ni calottes.
##   cel_model.gd  le chat. Squelette, visage peint, calottes, rest_undo.
##
## Ce que ce script apporte par rapport a `cel_style.make_outlined()` :
##
##   * il ALLUME `use_vertex_style`. Un meuble exporte par `tools/export_prop.py`
##     porte Attr_Style, donc son trait varie, ses ombres sont peintes et son
##     accent est masque. Laisse a false, COLOR vaudrait (1,1,1) et le meuble
##     partirait en pleine lumiere avec le trait le plus epais partout ;
##   * il MUTUALISE les materiaux. L'arene pose une trentaine de canapes ;
##     chacun fabriquant les siens, on aurait soixante ShaderMaterial pour deux
##     apparences, et regler une couleur en jeu n'en changerait qu'un.

const CelStyle := preload("res://scripts/systems/cel_style.gd")

## Epaisseur du trait, en unites monde.
##
## Volontairement la MEME que celle du chat (0,041), et non un multiple de la
## taille du canape. §11 met en garde contre un trait fixe sur de petits assets,
## pas contre un trait constant entre gros objets : a distance de camera egale,
## une epaisseur monde constante donne une largeur ECRAN constante — soit
## exactement le trait de plume unique d'une planche de cellulo. Un canape cerne
## proportionnellement a ses 3,2 m aurait un trait deux fois plus gras que le
## chat pose dessus, et volerait l'attention au personnage.
const OUTLINE_THICKNESS := 0.045

## Bord de cluster irregulier — §5.3 demande ±0,03, le shader prend la moitie.
const EDGE_NOISE := 0.06

## Accent de brillance (canal B). Le chat l'a descendu a 0,12 parce que son
## pelage est noir et qu'un melange vers le creme y ajoutait un 3e ton. Les
## tissus de meuble sont clairs (valeur ~0,85, comme l'ancien chat ambre) :
## l'accent y reste un souffle, et 0,30 retrouve le reglage d'origine.
const ACCENT_STRENGTH := 0.30

## Force du biais d'ombre peinte. Le shader applique `(G - 0,5) x 2 x force`.
##
## Au-dessus du 1,0 du chat, et pour une raison de FORME, pas de gout. La
## lumiere du jeu vient d'en haut : sur un chat fait de spheres, les normales
## balaient tout l'hemisphere et le cluster se coupe tout seul. Un meuble, lui,
## n'offre a une camera plongeante que des faces tournees vers le ciel — elles
## tombent TOUTES du cote eclaire et le canape s'aplatit en un seul aplat.
##
## "Convention Blender" §4 le dit d'avance : le vrai bouton est ici, pas dans
## l'amplitude peinte. Peindre G plus bas figerait la surface en ombre
## permanente quelle que soit la lumiere ; monter la force garde les ombres
## peintes modulables.
const SHADOW_BIAS_STRENGTH := 1.5

## Palette par variante, puis par materiau du .glb.
##
## Strictement "Visual Art Direction" §4 — les pastels du prototype 2D
## (#9FC4FF, #FFD6A5) n'en font pas partie et juraient avec le bois, exactement
## comme ceux que les tapis ont deja abandonnes.
##
## Le coussin n'est PAS une seconde couleur : c'est la couleur de palette, et le
## bati en est la version assombrie d'un cran. Le capitonnage se detache donc du
## meuble sans ajouter de teinte, ce qui tient la limite de §5 (une couleur
## principale par objet). Le bati est descendu apres mesure : a la valeur de
## palette pleine, le canape se retrouvait dans la meme plage de valeurs que les
## lames claires du parquet et se lisait delave a taille de jeu.
const PALETTES := {
	"bleu": {
		"tissu": Color("#8FBAC9"),    # bleu ciel Ghibli, assombri
		"coussin": Color("#A0C8D8"),  # bleu ciel Ghibli
	},
	"sauge": {
		"tissu": Color("#B2D3A0"),    # vert sauge, assombri
		"coussin": Color("#C8E4B8"),  # vert sauge
	},
}

const FALLBACK_COLOR := Color("#A0C8D8")

# (chemin du modele + variante) -> Array[ShaderMaterial], indexe par surface.
static var _cache := {}


## Instancie un meuble, style applique, pret a etre place.
static func spawn(model_path: String, variant: String) -> Node3D:
	var packed: PackedScene = load(model_path)

	if packed == null:
		push_warning("cel_prop : modele introuvable — %s" % model_path)
		return null

	var root := packed.instantiate() as Node3D
	var mesh_instance := _find_mesh(root)

	if mesh_instance == null:
		push_warning("cel_prop : aucun MeshInstance3D dans %s" % model_path)
		return root

	var materials := _materials(model_path, variant, mesh_instance.mesh)

	for i in materials.size():
		mesh_instance.set_surface_override_material(i, materials[i])

	return root


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var found := _find_mesh(child)

		if found != null:
			return found

	return null


static func _materials(model_path: String, variant: String, mesh: Mesh) -> Array:
	var key := "%s|%s" % [model_path, variant]

	if _cache.has(key):
		return _cache[key]

	var palette: Dictionary = PALETTES.get(variant, {})
	var materials: Array[ShaderMaterial] = []

	for i in mesh.get_surface_count():
		var source := mesh.surface_get_material(i)
		var mat_name := source.resource_name if source else ""
		var color: Color = palette.get(mat_name, FALLBACK_COLOR)

		var mat := CelStyle.make_outlined(color, OUTLINE_THICKNESS)
		mat.set_shader_parameter("use_vertex_style", true)
		mat.set_shader_parameter("edge_noise", EDGE_NOISE)
		mat.set_shader_parameter("accent_strength", ACCENT_STRENGTH)
		mat.set_shader_parameter("shadow_bias_strength", SHADOW_BIAS_STRENGTH)
		(mat.next_pass as ShaderMaterial).set_shader_parameter("use_vertex_style", true)

		materials.append(mat)

	_cache[key] = materials
	return materials


## Etat de `Attr_Style` tel que Godot le voit, par surface.
##
## Meme role que `cel_model.style_report()`, et pour la meme raison : l'attribut
## ne traverse le glTF que parce qu'un script le reinjecte (piege n°6). Une
## surface revenue a R/G/B = 1/1/1 est une surface que l'exporteur a laissee
## blanche — elle ne casse rien, elle passe simplement en pleine lumiere avec le
## trait le plus epais, ce qui ne ressemble pas a un probleme d'export.
static func style_report(mesh: Mesh) -> Array[String]:
	var lines: Array[String] = []

	for i in mesh.get_surface_count():
		var source := mesh.surface_get_material(i)
		var mat_name := source.resource_name if source else "<sans nom>"
		var colors: PackedColorArray = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]

		if colors.is_empty():
			lines.append("  %-12s COLOR_0 ABSENT" % mat_name)
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
		lines.append("  %-12s R %.2f/%.2f/%.2f  G %.2f/%.2f/%.2f  B %.2f/%.2f/%.2f" % [
			mat_name,
			lo.x, mean.x, hi.x,
			lo.y, mean.y, hi.y,
			lo.z, mean.z, hi.z,
		])

	return lines
