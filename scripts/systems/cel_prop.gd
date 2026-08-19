extends RefCounted

## Le style des .glb SANS SQUELETTE — pendant statique de cel_model.gd.
##
## Trois fabriques de style coexistent, et le decoupage n'est pas arbitraire :
##
##   cel_style.gd  primitives sans modele (ennemis placeholder, murs, sol).
##                 Une couleur, un contour, rien de peint.
##   cel_prop.gd   modeles .glb SANS squelette — les meubles et les
##                 ramassables. Palette par materiau et Attr_Style, mais ni
##                 rest_undo ni calottes.
##   cel_model.gd  le chat. Squelette, visage peint, calottes, rest_undo.
##
## Ce que ce script apporte par rapport a `cel_style.make_outlined()` :
##
##   * il ALLUME `use_vertex_style`. Un modele exporte par `tools/export_prop.py`
##     porte Attr_Style, donc son trait varie, ses ombres sont peintes et son
##     accent est masque. Laisse a false, COLOR vaudrait (1,1,1) et le modele
##     partirait en pleine lumiere avec le trait le plus epais partout ;
##   * il MUTUALISE les materiaux ET le maillage. L'arene pose une trentaine de
##     canapes et une vague morte seme des dizaines de croquettes ; chacun
##     fabriquant les siens, on aurait des centaines de ShaderMaterial pour deux
##     apparences, et regler une couleur en jeu n'en changerait qu'un.

const CelStyle := preload("res://scripts/systems/cel_style.gd")

## Les deux FAMILLES de .glb sans squelette. Le partage n'est pas un gout :
## "Visual Art Direction" §2ter.A ne range pas un ramassable avec le mobilier.
## Un objet qu'on RAMASSE est manipulable — il garde son trait plein, comme les
## personnages ; ce sont les grandes masses de fond qui se separent par la
## valeur et non par la ligne.
const MEUBLE := "meuble"
const PICKUP := "pickup"

## ⚠️ LE MEME NOM DE FAMILLE QUE `PICKUP`, DELIBEREMENT — ce n'est pas un oubli,
## et c'est pour ca que c'est un alias et non une 3e entree de `FAMILIES`.
##
## Une creature (la souris, et les ennemis modelises qui suivront) demande
## exactement les trois memes nombres qu'un ramassable : un trait de 0,036 —
## la borne du PIXEL, pas un gout —, un trait PLEIN puisqu'elle n'est pas du
## decor (§2ter.A), et un biais d'ombre neutre puisque ses normales balaient tout
## l'hemisphere comme celles de n'importe quel volume rond.
##
## La boule de poils a deja tranche ce point une fois : "trois nombres
## identiques, c'est une entree de dictionnaire en moins a tenir synchronisee".
## Un alias donne le nom juste au site d'appel — `CelProp.CREATURE` dans
## `enemy.gd` — sans recopier les nombres. Le jour ou une creature demandera
## vraiment autre chose, cette ligne devient une entree, et c'est tout.
const CREATURE := PICKUP

## Epaisseur du trait du MOBILIER, en unites monde.
##
## Volontairement la MEME que celle du chat (0,041), et non un multiple de la
## taille du canape. §11 met en garde contre un trait fixe sur de petits assets,
## pas contre un trait constant entre gros objets : a distance de camera egale,
## une epaisseur monde constante donne une largeur ECRAN constante — soit
## exactement le trait de plume unique d'une planche de cellulo. Un canape cerne
## proportionnellement a ses 3,2 m aurait un trait deux fois plus gras que le
## chat pose dessus, et volerait l'attention au personnage.
const OUTLINE_THICKNESS := 0.045

## Facteur applique a cette epaisseur sur tout le MOBILIER — modeles et boites
## pastel. C'est la reponse a "Visual Art Direction" §2ter.A.
##
## Le releve d'*Orbitals* dit que le decor n'est presque pas cerne : personnages
## et objets manipulables ont un trait, les grandes masses de fond se separent
## par la VALEUR, pas par la ligne. Zeucozy cernait tout de la meme encre, et un
## canape de 6,4 m entierement trace n'est pas plus fidele au style — il est
## plus charge, et il ramene le regard sur le decor au lieu du chat (§15 :
## lisibilite > detail).
##
## REDUIT, pas supprime, et c'est la MESURE qui a tranche dans ce sens — 100 /
## 50 / 0 % captures au cadrage de jeu, §16 interdisant de decider un reglage de
## trait en raisonnant. Sur la silhouette du canape contre le parquet :
##
##   100 %  saut de valeur median 0,33  —  0,0 % du bord sous 0,10
##    50 %  saut de valeur median 0,39  —  0,3 % du bord sous 0,10
##     0 %  saut de valeur median 0,12  — 28,7 % du bord sous 0,10, 7,6 % sous 0,05
##
## A 0 le meuble perd son ASSISE : un canape n'a pas d'ombre de contact (elle est
## reservee aux personnages), donc le trait est la seule chose qui le pose sur le
## sol. Plus d'un quart de son contour tombe alors sous le seuil de lecture et il
## flotte. A 0,5 il n'en tombe rien — 0,3 % — pour 41 % d'encre en moins
## (masse d'encre 658 -> 386 sur la meme image). C'est tout l'interet du reglage :
## la charge s'en va, la lecture reste.
##
## Ne s'applique NI au chat, NI aux ennemis, NI aux ramassables : le releve dit
## l'inverse pour eux. Ni au mur de bordure, qui n'est pas du decor mais la
## limite de jeu.
const OUTLINE_SCALE := 0.5

## Bord de cluster irregulier — §5.3 demande ±0,03, le shader prend la moitie.
## Partage par les deux familles : c'est une regle de matiere de peinture, elle
## ne depend pas de ce qu'on peint.
const EDGE_NOISE := 0.06

## Accent de brillance (canal B). Le chat l'a descendu a 0,12 parce que son
## pelage est noir et qu'un melange vers le creme y ajoutait un 3e ton. Les
## tissus de meuble sont clairs (valeur ~0,85, comme l'ancien chat ambre) et l'or
## de la croquette l'est autant (0,91) : l'accent y reste un souffle, et 0,30
## retrouve le reglage d'origine.
const ACCENT_STRENGTH := 0.30

## Ce qui change d'une famille a l'autre, et RIEN d'autre. Deux entrees, trois
## nombres : tout le reste est commun, et doit le rester.
##
## `shadow_bias_strength` est la force du biais d'ombre peinte — le shader
## applique `(G - 0,5) x 2 x force`. C'est le seul des trois qui merite une
## explication, parce que l'ecart entre les deux familles est une question de
## FORME, pas de gout :
##
##   * un MEUBLE n'offre a une camera plongeante que des faces tournees vers le
##     ciel — elles tombent toutes du cote eclaire du cluster et le canape
##     s'aplatit en un seul aplat. Il faut donc pousser (1,5) pour que les
##     ombres peintes reprennent la main. "Convention Blender" §4 le dit
##     d'avance : le vrai bouton est ici, pas dans l'amplitude peinte ;
##   * une CROQUETTE est un petit ellipsoide. Ses normales balaient tout
##     l'hemisphere, exactement comme les spheres du chat : le cluster se coupe
##     tout seul, et pousser le biais ne ferait qu'assombrir le ramassable a
##     mesure qu'il tourne. Elle reste donc a 1,0, le neutre.
const FAMILIES := {
	MEUBLE: {
		"thickness": OUTLINE_THICKNESS,
		"outline_scale": OUTLINE_SCALE,
		"shadow_bias_strength": 1.5,
	},
	PICKUP: {
		# Proportionnelle a la taille de l'objet, ce que §11 exige explicitement
		# des petits assets. La croquette fait 0,51 m de large contre 1,86 au
		# chat : le trait du chat pose tel quel la cernerait trois fois trop.
		#
		# Le chiffre a ete pris PAR LE BAS, pas par le haut : le canal R du
		# modele descend a 0,68 sur le bord expose au ciel, et c'est LUI qui
		# decide — a 0,032 ce bord-la tombait a 0,7 px et le trait y disparaissait
		# en jeu. A 0,036 il tient 0,98 px, le creux entre deux lobes 1,44.
		"thickness": 0.036,
		# PLEIN, et c'est le point de la famille : un ramassable n'est pas du
		# decor. C'est meme l'objet que le joueur doit reperer en premier.
		"outline_scale": 1.0,
		# ⚠️ LA BOULE DE POILS PARTAGE CETTE FAMILLE, et il a fallu resister a
		# lui en ecrire une troisieme. La Todo l'annoncait : "il n'a pas besoin
		# de la meme epaisseur de trait, il file, on ne le lit pas a l'arret".
		# C'est vrai de son ROLE et faux de son epaisseur, pour deux raisons
		# mesurees ailleurs :
		#
		#   * la borne basse n'est pas un gout, c'est LE PIXEL. La croquette a
		#     du remonter a 0,036 parce qu'a 0,032 son bord tombait a 0,7 px et
		#     que le trait y disparaissait. Un trait sous le pixel ne se lit pas
		#     comme un trait fin, il se lit comme de la salissure (la lecon
		#     d'antialiasing du visage). Il n'y a donc rien a gagner en dessous ;
		#   * sur la boule, le trait ne PORTE de toute facon pas la separation
		#     d'avec le sol — le pelage est a 0,29 de valeur contre 0,96 pour le
		#     parquet, la ou l'or de la croquette n'avait que 0,085 d'ecart sur
		#     son bord expose au ciel. Le laisser plein ne charge rien.
		#
		# Trois nombres identiques, c'est une entree de dictionnaire en moins a
		# tenir synchronisee.
		"shadow_bias_strength": 1.0,
	},
}

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
	# La croquette n'a qu'un materiau : §5 veut une couleur principale par objet
	# et une croquette n'a pas de seconde matiere. `#E8C040` est l'or chaud que
	# §4 range explicitement en "Croquettes / XP" — et non le #FFD166 que le
	# cube placeholder portait, qui n'etait dans aucune palette.
	"croquette": {
		"croquette": Color("#E8C040"),
	},
	# La boule de poils — LE PELAGE DU CHAT, pas une couleur de plus. C'est
	# exactement `cel_model.NOIR` : une boule de poils est faite des poils du
	# chat, et lui donner une teinte a elle en ferait un objet du decor plutot
	# que quelque chose qu'il a crache.
	#
	# Ce que le placeholder coutait, et qui n'etait pas qu'un probleme de forme :
	# la capsule etait `#FDD166`, un jaune pale, sur un parquet `#F5ECD8` a
	# `#E8D4A8`. Moins de 0,10 d'ecart de valeur, soit SOUS le seuil de lecture
	# releve sur la silhouette du canape — le projectile ne se detachait pas du
	# sol. Le brun est a 0,29 contre 0,96 : 0,67 d'ecart.
	"boule_poils": {
		"poils": Color("#4A4038"),
		# Les TRACES CLAIRES du pelage tuxedo — mais assourdies, jamais le
		# `#F7EFE0` du poitrail. Une boule de poils est du poil mate, roule dans
		# la salive : elle n'a plus l'eclat du pelage vivant. Et a ~22 px, le
		# creme plein contre le brun sombre ferait 0,68 d'ecart A L'INTERIEUR de
		# la silhouette — plus que l'ecart de l'objet avec le parquet. La trace
		# deviendrait le sujet et la boule se lirait en deux morceaux.
		#
		# Meme geste que le canape, dont le bati est la couleur du coussin
		# descendue d'un cran : pas une seconde teinte, la meme matiere a deux
		# valeurs. §5 tient — le tuxedo du chat est deja fait de ca.
		"poils_clairs": Color("#B3A895"),
	},
	# La SOURIS — le premier ennemi modelise. Trois matieres, dont deux sont des
	# ZONES peintes sur la meme bete et non des objets a part : la peau nue
	# (museau + interieur des oreilles) et l'oeil.
	#
	# Le taupe est borne des DEUX cotes, et aucune borne n'est un gout :
	#
	#   * au-dessus de ~0,85 de valeur il rejoint le parquet (#F5ECD8 a #E8D4A8,
	#     0,91 a 0,96) et l'ennemi cesse de se detacher du sol — exactement le mur
	#     que le projectile jaune pale a paye, moins de 0,10 d'ecart ;
	#   * en dessous de ~0,40 il rejoint le pelage du chat (0,29). Dans un
	#     survivor le joueur trie a la VALEUR avant de trier a la forme (§15), et
	#     un ennemi de la meme valeur que le personnage se perd dans la melee.
	#
	# `#A89684` tombe a 0,66, et il est CHAUD — hue ~30°, saturation 21 %. §17
	# interdit explicitement le gris neutre.
	#
	# La queue est en `pelage` et non en peau rose, alors qu'une vraie queue de
	# souris est rose nue : a 0,91 de valeur sur un parquet a 0,93, elle
	# disparaitrait. Le rose ne tient que la ou il est cerne de pelage.
	"souris": {
		"pelage": Color("#A89684"),
		"peau": Color("#E8B8A8"),
		"oeil": Color("#3D2B1A"),
	},
}

const FALLBACK_COLOR := Color("#A0C8D8")

## Trait par VARIANTE, quand `CelStyle.INK` (#3D2B1A, §4) ne convient pas.
##
## Meme regle et meme raison que `cel_model.INKS` : un trait doit rester plus
## sombre que l'aplat qu'il cerne ET que son ton d'ombre, sinon il se lit comme
## une lumiere et non comme de l'encre. Sur le brun tres sombre du pelage,
## l'ombre descend a ~#302B23 — soit SOUS `INK`. On passe donc au meme brun
## profond que le chat, qui n'est toujours pas un noir pur (§2bis).
##
## Par variante et non par materiau : une variante decrit un objet entier, et
## aucun des deux modeles concernes n'a de surface claire a cerner autrement.
const INK_SOMBRE := Color("#1A120C")
const INKS := {
	"boule_poils": INK_SOMBRE,
}

# (chemin du modele + variante + famille + epaisseur) -> Array[ShaderMaterial],
# indexe par surface.
static var _materials_cache := {}

# chemin du modele -> Mesh. Le PackedScene partage deja sa ressource entre ses
# instances ; ce cache-ci sert aux appelants qui ont DEJA leur MeshInstance3D et
# ne veulent pas instancier une scene par exemplaire (`dress`).
static var _mesh_cache := {}


## Instancie un modele, style applique, pret a etre place.
##
## `outline_scale` ne se passe que pour COMPARER — le banc et le jeu prennent
## tous deux celui de la famille par defaut, et c'est ce qui les empeche de
## diverger.
static func spawn(
	model_path: String, variant: String, outline_scale: float = -1.0,
	family: String = MEUBLE
) -> Node3D:
	var packed: PackedScene = load(model_path)

	if packed == null:
		push_warning("cel_prop : modele introuvable — %s" % model_path)
		return null

	var root := packed.instantiate() as Node3D
	var mesh_instance := find_mesh(root)

	if mesh_instance == null:
		push_warning("cel_prop : aucun MeshInstance3D dans %s" % model_path)
		return root

	_apply(mesh_instance, model_path, variant, family, outline_scale)
	return root


## Habille un MeshInstance3D DEJA en place — maillage compris.
##
## Pendant de `spawn()` pour les objets qui possedent deja leur noeud. Les
## croquettes tombent par dizaines : leur faire instancier chacune la scene du
## .glb ajouterait un `PackedScene.instantiate()` et un Node3D par ramassable,
## pour un maillage et des materiaux qui sont de toute facon les memes.
##
## Le maillage vient d'ici et non du .tscn parce qu'un .glb importe est une
## PackedScene : sa ressource Mesh n'est pas referencable depuis une scene. Meme
## situation que le chat, dont cel_model.gd charge le modele au _ready.
static func dress(
	mesh_instance: MeshInstance3D, model_path: String, variant: String,
	family: String = MEUBLE
) -> void:
	var mesh := mesh_of(model_path)

	if mesh == null:
		return

	mesh_instance.mesh = mesh
	_apply(mesh_instance, model_path, variant, family, -1.0)


## Le maillage d'un .glb, charge une fois pour toutes.
static func mesh_of(model_path: String) -> Mesh:
	if _mesh_cache.has(model_path):
		return _mesh_cache[model_path]

	var packed: PackedScene = load(model_path)

	if packed == null:
		push_warning("cel_prop : modele introuvable — %s" % model_path)
		return null

	var root := packed.instantiate() as Node3D
	var mesh_instance := find_mesh(root)
	var mesh: Mesh = mesh_instance.mesh if mesh_instance != null else null

	if mesh == null:
		push_warning("cel_prop : aucun MeshInstance3D dans %s" % model_path)

	# L'instance n'a servi qu'a atteindre la ressource : la ressource, elle,
	# survit a la liberation du noeud qui la portait.
	root.free()

	_mesh_cache[model_path] = mesh
	return mesh


static func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var found := find_mesh(child)

		if found != null:
			return found

	return null


static func _apply(
	mesh_instance: MeshInstance3D, model_path: String, variant: String,
	family: String, outline_scale: float
) -> void:
	var materials := _materials(model_path, variant, family, outline_scale)

	for i in materials.size():
		mesh_instance.set_surface_override_material(i, materials[i])


static func _materials(
	model_path: String, variant: String, family: String, outline_scale: float
) -> Array:
	var style: Dictionary = FAMILIES.get(family, FAMILIES[MEUBLE])

	if outline_scale < 0.0:
		outline_scale = style["outline_scale"]

	# L'epaisseur entre dans la cle : deux runs de comparaison ne doivent pas se
	# repasser les materiaux du premier.
	var key := "%s|%s|%s|%.3f" % [model_path, variant, family, outline_scale]

	if _materials_cache.has(key):
		return _materials_cache[key]

	var mesh := mesh_of(model_path)

	if mesh == null:
		return []

	var palette: Dictionary = PALETTES.get(variant, {})
	var materials: Array[ShaderMaterial] = []

	for i in mesh.get_surface_count():
		var source := mesh.surface_get_material(i)
		var mat_name := source.resource_name if source else ""
		var color: Color = palette.get(mat_name, FALLBACK_COLOR)

		var mat := CelStyle.make_outlined(
			color,
			style["thickness"] * outline_scale,
			INKS.get(variant, CelStyle.INK),
		)
		mat.set_shader_parameter("use_vertex_style", true)
		mat.set_shader_parameter("edge_noise", EDGE_NOISE)
		mat.set_shader_parameter("accent_strength", ACCENT_STRENGTH)
		mat.set_shader_parameter("shadow_bias_strength", style["shadow_bias_strength"])

		# Absent a epaisseur nulle : `make_outlined` retire le contour plutot
		# que de le laisser a zero (une coque nulle z-fighte avec sa surface).
		var outline := mat.next_pass as ShaderMaterial
		if outline != null:
			outline.set_shader_parameter("use_vertex_style", true)

		materials.append(mat)

	_materials_cache[key] = materials
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
