class_name Arena
extends Node3D

## Construit le decor 3D de l'arene : sol, tapis, mobilier et mur de bordure.
##
## Trois differences assumees, dictees par le passage a la 3D :
##
##   - AUCUNE transparence sur le mobilier. Les zones de couleur sont
##     pre-melangees avec le sol a la construction : la DA demande des aplats
##     francs (§2bis), et un aplat pre-melange se lit exactement comme le
##     calque semi-transparent d'avant sans couter de tri de transparence.
##   - Tout est dimensionne en METRES, pas en fraction d'arene. Un canape
##     proportionnel a une arene de 160 m serait un mur de 20 m ; a l'echelle
##     du chat (1,86 unite) plus rien ne se lirait.
##   - Le decor se REPETE par cellules. Consequence de la precedente : sept
##     meubles a taille reelle dans 160 x 90 m, on n'en croiserait jamais un.
##
## Le sol, lui, ne se construit plus en geometrie du tout — voir plus bas.

const CelStyle := preload("res://scripts/systems/cel_style.gd")
const CelProp := preload("res://scripts/systems/cel_prop.gd")

const CANAPE := "res://assets/models/prop_canape.glb"

## Ton moyen du parquet. Sert de fond de melange aux aplats du mobilier, pour
## qu'ils restent coherents avec le sol sur lequel ils sont poses.
const FLOOR_COLOR := Color("#E8D4A8")
const INK := Color("#2A2A3A")

## Le sol deborde largement de l'aire de jeu : la camera voit au-dela du mur
## de bordure, et il ne doit jamais y avoir de vide a l'ecran.
const FLOOR_OVERSHOOT := 60.0

const WALL_HEIGHT := 1.2
const WALL_THICKNESS := 1.0

## Motif du decor. Repete sur toute l'arene, avec un decalage aleatoire par
## cellule pour que ca ne se lise pas comme du papier peint.
const CELL := Vector2(40.0, 28.0)
const CELL_JITTER := Vector2(3.5, 2.5)

## Rayon garde libre autour du point d'apparition du chat.
const SPAWN_CLEARANCE := 2.5

## Couche de collision du mobilier bloquant — bit 3, nommee `decor_bloquant`
## dans `project.godot`. Le chat et les ennemis l'ajoutent a leur MASQUE ; le
## meuble, lui, ne scrute rien.
##
## C'est la premiere couche de CORPS que le projet branche vraiment : jusqu'ici
## tous les `CharacterBody3D` etaient en `collision_mask = 0` et il n'existait
## aucun `StaticBody3D` — `move_and_slide()` ne resolvait donc jamais rien, et
## c'est `main.clamp_to_arena()` qui tenait lieu de mur. Il le tient toujours :
## le mur de bordure reste un `MeshInstance3D` nu, seul le mobilier collisionne.
const DECOR_LAYER := 1 << 2

## Trait du mobilier — canapes ET boites pastel, meme facteur. La decision et
## son pourquoi vivent dans `cel_prop.OUTLINE_SCALE` : c'est la fabrique de
## style des meubles, et la recopier ici ferait diverger le jeu du banc.
##
## Les boites y passent aussi. Ce sont des meubles en attente de leur modele,
## pas une autre famille d'objets : laisser la table basse franchement cernee
## pendant que le canape s'allege redessinerait exactement la hierarchie que ce
## reglage existe pour corriger.
##
## Surcharge par `--decor-outline=` — meme convention que `--pitch=` et
## `--ui-card=`. C'est par la que 100 / 50 / 0 % ont ete compares a l'image,
## §16 interdisant de trancher un reglage de trait en raisonnant.
var _outline_scale := CelProp.OUTLINE_SCALE

# Tapis — centre en fraction de la cellule, emprise en metres.
# L'ordre compte : chaque tapis se pose un cran au-dessus du precedent.
#
# La palette vient de "Visual Art Direction" §4 : les pastels de l'ancien
# prototype 2D (#9FF6FF, #FFC6FF, #BDB2FF) n'en font pas partie et juraient
# avec le bois. Les flaques de lumiere ont quitte cette liste — elles sont
# desormais peintes par le shader de sol, ce qui leur donne un bord irregulier
# et les fait traverser les tapis au lieu de s'arreter a leur bord.
const RUGS := [
	{"at": Vector2(0.50, 0.52), "size": Vector2(18.0, 12.0),
		"color": Color("#A0C8D8")},   # grand tapis central, bleu ciel Ghibli
	{"at": Vector2(0.10, 0.78), "size": Vector2(8.0, 8.0),
		"color": Color("#E8B8A8")},   # rose poudre
	{"at": Vector2(0.86, 0.22), "size": Vector2(9.0, 7.0),
		"color": Color("#C8E4B8")},   # vert sauge
	{"at": Vector2(0.16, 0.52), "size": Vector2(9.0, 7.0),
		"color": Color("#C8A8D8")},   # lavande douce
	{"at": Vector2(0.84, 0.60), "size": Vector2(10.0, 8.0),
		"color": Color("#C8E4B8")},   # vert sauge
]

# Mobilier — meme convention, plus une hauteur.
#
# Deux familles cohabitent, et c'est un etat transitoire assume :
#
#   * "model" — un .glb cel-shade, style pose par cel_prop.gd. Son emprise
#     "size" doit egaler celle du modele, elle ne le redimensionne pas : §11
#     interdit le scaling non uniforme sur un objet exporte, et un canape
#     etire ne serait plus le canape qu'on a valide au banc ;
#   * sans "model" — la boite pastel du prototype, en attendant son modele.
const PROPS := [
	{"at": Vector2(0.24, 0.30), "size": Vector2(6.4, 2.6),
		"model": CANAPE, "variant": "bleu", "yaw": 0.0},
	# Le second canape est pose en TRAVERS du premier, pas dans son dos.
	#
	# Deux exemplaires identiques poses dans le meme sens se liraient comme du
	# papier peint — c'est deja la raison du decalage aleatoire par cellule, et
	# le quart de tour le dit plus fort que le demi-tour : a 45° de plongee, un
	# canape retourne garde exactement la meme silhouette au sol.
	#
	# Ce n'est pas qu'une question de lecture. C'est le premier geste du
	# chantier « le meuble comme terrain de jeu » : tant que tous les canapes
	# barrent l'arene dans le meme sens, contourner un obstacle est toujours le
	# meme mouvement. Il en faut sur les DEUX axes pour que le placement du chat
	# devienne une decision.
	{"at": Vector2(0.76, 0.66), "size": Vector2(6.4, 2.6),
		"model": CANAPE, "variant": "sauge", "yaw": 90.0},
	{"at": Vector2(0.50, 0.52), "size": Vector2(3.0, 1.6), "height": 0.8,
		"color": Color("#FDFDB6"), "alpha": 0.58},   # table basse
	{"at": Vector2(0.90, 0.12), "size": Vector2(1.4, 1.4), "height": 2.6,
		"color": Color("#CDFFBF"), "alpha": 0.90},   # plante
	{"at": Vector2(0.08, 0.88), "size": Vector2(1.4, 1.4), "height": 2.6,
		"color": Color("#CDFFBF"), "alpha": 0.90},   # plante
	{"at": Vector2(0.38, 0.76), "size": Vector2(1.6, 1.6), "height": 0.45,
		"color": Color("#FFC6FF"), "alpha": 0.72},   # coussin
	{"at": Vector2(0.64, 0.24), "size": Vector2(1.6, 1.6), "height": 0.45,
		"color": Color("#FDFDB6"), "alpha": 0.74},   # coussin
]


## Appelee par main.gd une fois le rectangle d'arene connu.
func build(rect: Rect2) -> void:
	for child in get_children():
		child.queue_free()

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--decor-outline="):
			_outline_scale = float(argument.trim_prefix("--decor-outline="))

	_build_ground(rect)
	_build_furnishings(rect)
	_build_walls(rect)


# ------------------------------------------------------------------------- sol

## Le parquet peint. UN plan, UN materiau.
##
## Le prototype posait ici ~90 quads pour dessiner un quadrillage. Deux raisons
## de tout rendre au shader :
##
##   - un quadrillage regulier n'est pas un fond d'anime. Le parquet a besoin de
##     lames de valeurs differentes, de joints trembles et d'epaisseur inegale,
##     et de depassements aux croisements — rien de tout cela ne se pose en
##     geometrie sans exploser le nombre de nœuds (§2ter·1) ;
##   - un trait dessine en geometrie n'a aucun moyen de savoir qu'il est devenu
##     plus fin qu'un pixel. Au fond du cadre les joints se croisaient a
##     quelques pixels et moiraient. Le shader les eteint proprement.
##
## Le motif est ancre sur les coordonnees MONDE : agrandir l'arene ne fait pas
## glisser le parquet sous les pieds du chat.
func _build_ground(rect: Rect2) -> void:
	var area := rect.grow(FLOOR_OVERSHOOT)

	var mesh := PlaneMesh.new()
	mesh.size = area.size

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(area.get_center().x, 0.0, area.get_center().y)
	node.material_override = CelStyle.make_ground()
	add_child(node)


# ------------------------------------------------------------------- ameublement

func _build_furnishings(rect: Rect2) -> void:
	# Graine fixe : le decor doit etre le meme d'une run a l'autre, sinon on ne
	# peut plus juger un changement de rendu par comparaison.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260816

	var spawn := rect.get_center()
	var columns := int(ceil(rect.size.x / CELL.x))
	var rows := int(ceil(rect.size.y / CELL.y))

	for row in rows:
		for column in columns:
			var origin := rect.position + Vector2(column, row) * CELL
			var jitter := Vector2(
				rng.randf_range(-CELL_JITTER.x, CELL_JITTER.x),
				rng.randf_range(-CELL_JITTER.y, CELL_JITTER.y)
			)

			var layer := 1
			for rug in RUGS:
				var area := _placed(origin + jitter, rug)
				if _is_placeable(area, rect, spawn):
					_add_rug(area, rug["color"], float(layer) * 0.012)
				layer += 1

			for prop in PROPS:
				var footprint := _placed(origin + jitter, prop)
				if _is_placeable(footprint, rect, spawn):
					_add_prop(footprint, prop)


## Emprise au sol d'un element, une fois pose dans sa cellule.
func _placed(origin: Vector2, item: Dictionary) -> Rect2:
	var size := _footprint(item)
	return Rect2(origin + item["at"] * CELL - size * 0.5, size)


## Emprise au sol d'un element une fois TOURNE, en metres.
##
## `size` est celle du modele, mesuree sur son AABB — le canape fait exactement
## 6,4 x 2,6 — et elle ne le redimensionne pas. Mais `yaw` la fait tourner : un
## quart de tour ECHANGE ses deux cotes.
##
## Sans ca, un canape vertical serait teste sur l'emprise du canape horizontal :
## 3,8 m de trop en largeur, autant de manque en profondeur. Le defaut serait
## silencieux — `_is_placeable` laisserait passer un meuble qui deborde du mur,
## ou en ecarterait un qui tient — et il deviendrait un vrai bug le jour ou
## cette emprise portera une collision.
##
## La formule vaut pour un angle quelconque (c'est la boite englobante de la
## boite tournee), pas seulement pour les multiples de 90° : un `yaw` de biais
## ne doit pas rendre un chiffre plausible et faux.
func _footprint(item: Dictionary) -> Vector2:
	var size: Vector2 = item["size"]
	var angle := deg_to_rad(float(item.get("yaw", 0.0)))
	var c := absf(cos(angle))
	var s := absf(sin(angle))

	return Vector2(size.x * c + size.y * s, size.x * s + size.y * c)


## Un element est ecarte s'il deborde de l'aire de jeu, ou s'il empiete sur le
## point d'apparition — le chat s'y retrouverait plante dans la table basse.
func _is_placeable(area: Rect2, rect: Rect2, spawn: Vector2) -> bool:
	if not rect.encloses(area):
		return false

	return not area.grow(SPAWN_CLEARANCE).has_point(spawn)


## Tapis. Sans contour en coque inversee : sur une surface plane elle pousse ses
## sommets vers le haut et ne se voit pas d'en haut. Le trait du tapis est
## dessine dans son propre shader, qui decoupe aussi sa silhouette au `discard`
## pour lui donner des bords un peu mous.
func _add_rug(area: Rect2, color: Color, y: float) -> void:
	var mesh := PlaneMesh.new()
	# Marge : la silhouette ondule, elle doit avoir de la place pour deborder
	# du rectangle nominal sans etre coupee au ras du plan.
	mesh.size = area.size + Vector2(2.0, 2.0)

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(area.get_center().x, y, area.get_center().y)
	node.material_override = CelStyle.make_rug(color, area.size, mesh.size)
	add_child(node)


func _add_prop(footprint: Rect2, prop: Dictionary) -> void:
	if prop.has("model"):
		_add_model_prop(footprint, prop)
		return

	var height: float = prop["height"]

	var mesh := BoxMesh.new()
	mesh.size = Vector3(footprint.size.x, height, footprint.size.y)

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(footprint.get_center().x, height * 0.5, footprint.get_center().y)
	# Proportionnel a la plus petite dimension : c'est elle qui decide si le
	# trait paraitra epais ou non (§11).
	CelStyle.apply_outlined(
		node,
		_over_floor(prop["color"], prop["alpha"]),
		minf(footprint.size.x, minf(footprint.size.y, height)) * 0.045 * _outline_scale
	)
	add_child(node)


## Un meuble modelise. Il apporte son propre style (palette, contour, ombres
## peintes) : rien de ce que fait `_add_prop` sur une boite ne s'applique ici.
##
## Pose sur le SOL, pas centre en hauteur : les modeles sortent de Blender avec
## leur origine entre les pieds, comme le chat ("Convention Blender" §2).
func _add_model_prop(footprint: Rect2, prop: Dictionary) -> void:
	var node := CelProp.spawn(prop["model"], prop["variant"], _outline_scale)

	if node == null:
		return

	node.position = Vector3(footprint.get_center().x, 0.0, footprint.get_center().y)
	node.rotation_degrees.y = prop.get("yaw", 0.0)
	_add_blocker(node, prop)
	add_child(node)


## Le meuble devient un OBSTACLE : un StaticBody3D pose en enfant du modele.
##
## `StaticBody3D` est ce que le manuel prescrit pour un decor qui ne bouge pas
## ("Physics introduction" : *walls and other obstacles*). Il ne scrute rien
## (`collision_mask = 0`) — ce sont le chat et les ennemis qui le voient, en
## ajoutant DECOR_LAYER a leur masque.
##
## ⚠️ ENFANT DU MODELE, jamais frere. La boite herite ainsi du `yaw` du meuble
## sans avoir a le refaire : un canape tourne d'un quart de tour emmene sa
## collision avec lui, et les deux ne peuvent pas diverger. C'est le pendant
## exact de `_footprint()`, qui fait tourner l'emprise du test de placement.
##
## ⚠️ La boite est relevee sur l'AABB du MAILLAGE, pas sur les chiffres de la
## table. Un `"height"` ecrit a la main serait un second nombre a tenir
## synchronise avec Blender, et le jour ou le canape change de hauteur rien ne
## signalerait que la collision est restee sur l'ancienne.
func _add_blocker(model: Node3D, prop: Dictionary) -> void:
	var bounds := _model_bounds(model)

	if bounds.size == Vector3.ZERO:
		return

	# Le meuble est modelise a l'echelle, pas mis a l'echelle : si l'emprise
	# declaree s'ecarte de celle du maillage, c'est la TABLE qui est fausse, et
	# le test de placement l'est avec elle. Sans ce garde le defaut est muet.
	var declared: Vector2 = prop["size"]
	if absf(bounds.size.x - declared.x) > 0.01 or absf(bounds.size.z - declared.y) > 0.01:
		push_warning(
			"arena : l'emprise declaree de %s (%.2f x %.2f) ne correspond pas a son maillage (%.2f x %.2f)"
			% [prop["model"], declared.x, declared.y, bounds.size.x, bounds.size.z]
		)

	var shape := BoxShape3D.new()
	shape.size = bounds.size

	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = bounds.get_center()

	var body := StaticBody3D.new()
	body.collision_layer = DECOR_LAYER
	body.collision_mask = 0
	body.add_child(collider)
	model.add_child(body)


## Boite englobante du maillage d'un meuble, dans l'espace du modele.
##
## Rend une AABB nulle si le .glb n'a pas de maillage — `CelProp.spawn` a deja
## prevenu dans ce cas, et un meuble sans dessin n'a rien a bloquer.
func _model_bounds(node: Node) -> AABB:
	if node is MeshInstance3D:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		return mesh.get_aabb() if mesh != null else AABB()

	for child in node.get_children():
		var found := _model_bounds(child)

		if found.size != Vector3.ZERO:
			return found

	return AABB()


## Mur de bordure — marque la limite de jeu, la meme que clamp_to_arena().
func _build_walls(rect: Rect2) -> void:
	var half := WALL_THICKNESS * 0.5
	var spans := [
		Rect2(rect.position.x - half, rect.position.y - half, rect.size.x + WALL_THICKNESS, WALL_THICKNESS),
		Rect2(rect.position.x - half, rect.end.y - half, rect.size.x + WALL_THICKNESS, WALL_THICKNESS),
		Rect2(rect.position.x - half, rect.position.y - half, WALL_THICKNESS, rect.size.y + WALL_THICKNESS),
		Rect2(rect.end.x - half, rect.position.y - half, WALL_THICKNESS, rect.size.y + WALL_THICKNESS),
	]

	for span: Rect2 in spans:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(span.size.x, WALL_HEIGHT, span.size.y)

		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = Vector3(span.get_center().x, WALL_HEIGHT * 0.5, span.get_center().y)
		CelStyle.apply_outlined(node, INK, 0.05)
		add_child(node)


# ------------------------------------------------------------------------ outils

## Aplat opaque equivalent a `color` pose sur le sol avec `alpha` d'opacite.
func _over_floor(color: Color, alpha: float) -> Color:
	return FLOOR_COLOR.lerp(color, alpha)
