extends Node3D

## Construit le decor 3D de l'arene : sol, carrelage, tapis, mobilier et mur
## de bordure.
##
## Transposition du decor Polygon2D d'origine — memes couleurs, meme esprit.
## Trois differences assumees, dictees par le passage a la 3D :
##
##   - AUCUNE transparence. Les zones de couleur sont pre-melangees avec le sol
##     a la construction : la DA demande des aplats francs (§2bis), et un aplat
##     pre-melange se lit exactement comme le calque semi-transparent d'avant
##     sans couter de tri de transparence.
##   - Tout est dimensionne en METRES, pas en fraction d'arene. Un canape
##     proportionnel a une arene de 160 m serait un mur de 20 m ; a l'echelle
##     du chat (1,74 unite) plus rien ne se lirait.
##   - Le decor se REPETE par cellules. Consequence de la precedente : sept
##     meubles a taille reelle dans 160 x 90 m, on n'en croiserait jamais un.
##
## Et une addition : le carrelage au sol. En vue plongeante, un sol uni ne
## donne aucun repere de deplacement — on se croit immobile.

const CelStyle := preload("res://scripts/systems/cel_style.gd")

const FLOOR_COLOR := Color("#F7EDE2")
const INK := Color("#2A2A3A")

## Le sol deborde largement de l'aire de jeu : la camera voit au-dela du mur
## de bordure, et il ne doit jamais y avoir de vide a l'ecran.
const FLOOR_OVERSHOOT := 60.0

const GRID_COLOR := Color("#E0CFB2")
const GRID_STEP := 6.0
const GRID_WIDTH := 0.16

const WALL_HEIGHT := 1.2
const WALL_THICKNESS := 1.0

## Motif du decor. Repete sur toute l'arene, avec un decalage aleatoire par
## cellule pour que ca ne se lise pas comme du papier peint.
const CELL := Vector2(40.0, 28.0)
const CELL_JITTER := Vector2(3.5, 2.5)

## Rayon garde libre autour du point d'apparition du chat.
const SPAWN_CLEARANCE := 2.5

# Zones de couleur au sol — centre en fraction de la cellule, emprise en metres.
# L'ordre compte : chaque zone se pose un cran au-dessus de la precedente.
const FLOOR_PATCHES := [
	{"at": Vector2(0.22, 0.16), "size": Vector2(15.0, 10.0),
		"color": Color("#FFD6A5"), "alpha": 0.45},   # flaque de lumiere
	{"at": Vector2(0.78, 0.84), "size": Vector2(15.0, 11.0),
		"color": Color("#FFD6A5"), "alpha": 0.34},
	{"at": Vector2(0.10, 0.78), "size": Vector2(8.0, 8.0),
		"color": Color("#FFC6FF"), "alpha": 0.40},
	{"at": Vector2(0.86, 0.22), "size": Vector2(9.0, 7.0),
		"color": Color("#CDFFBF"), "alpha": 0.45},
	{"at": Vector2(0.50, 0.52), "size": Vector2(18.0, 12.0),
		"color": Color("#9FF6FF"), "alpha": 0.32},   # tapis central
	{"at": Vector2(0.16, 0.52), "size": Vector2(9.0, 7.0),
		"color": Color("#BDB2FF"), "alpha": 0.26},
	{"at": Vector2(0.84, 0.60), "size": Vector2(10.0, 8.0),
		"color": Color("#FFC6FF"), "alpha": 0.24},
]

# Mobilier — meme convention, plus une hauteur.
const PROPS := [
	{"at": Vector2(0.24, 0.30), "size": Vector2(6.4, 2.6), "height": 1.6,
		"color": Color("#9FC4FF"), "alpha": 0.72},   # canape
	{"at": Vector2(0.76, 0.66), "size": Vector2(6.4, 2.6), "height": 1.6,
		"color": Color("#FFD6A5"), "alpha": 0.70},   # canape
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

	_add_ground_quad(rect.grow(FLOOR_OVERSHOOT), 0.0, FLOOR_COLOR)
	_build_grid(rect)
	_build_furnishings(rect)
	_build_walls(rect)


# ------------------------------------------------------------------------- sol

## Carrelage. Sans lui, traverser un sol uni ne se voit pas.
func _build_grid(rect: Rect2) -> void:
	var area := rect.grow(FLOOR_OVERSHOOT * 0.5)
	var color := _over_floor(GRID_COLOR, 1.0)

	var x := ceilf(area.position.x / GRID_STEP) * GRID_STEP
	while x <= area.end.x:
		_add_ground_quad(
			Rect2(x - GRID_WIDTH * 0.5, area.position.y, GRID_WIDTH, area.size.y),
			0.004,
			color
		)
		x += GRID_STEP

	var z := ceilf(area.position.y / GRID_STEP) * GRID_STEP
	while z <= area.end.y:
		_add_ground_quad(
			Rect2(area.position.x, z - GRID_WIDTH * 0.5, area.size.x, GRID_WIDTH),
			0.004,
			color
		)
		z += GRID_STEP


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
			for patch in FLOOR_PATCHES:
				var area := _placed(origin + jitter, patch)
				if _is_placeable(area, rect, spawn):
					_add_ground_quad(area, float(layer) * 0.01,
							_over_floor(patch["color"], patch["alpha"]))
				layer += 1

			for prop in PROPS:
				var footprint := _placed(origin + jitter, prop)
				if _is_placeable(footprint, rect, spawn):
					_add_prop(footprint, prop)


## Emprise au sol d'un element, une fois pose dans sa cellule.
func _placed(origin: Vector2, item: Dictionary) -> Rect2:
	var size: Vector2 = item["size"]
	return Rect2(origin + item["at"] * CELL - size * 0.5, size)


## Un element est ecarte s'il deborde de l'aire de jeu, ou s'il empiete sur le
## point d'apparition — le chat s'y retrouverait plante dans la table basse.
func _is_placeable(area: Rect2, rect: Rect2, spawn: Vector2) -> bool:
	if not rect.encloses(area):
		return false

	return not area.grow(SPAWN_CLEARANCE).has_point(spawn)


func _add_prop(footprint: Rect2, prop: Dictionary) -> void:
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
		minf(footprint.size.x, minf(footprint.size.y, height)) * 0.045
	)
	add_child(node)


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

## Quad horizontal, sans contour : une coque inversee sur une surface plane
## pousse ses sommets vers le haut et ne se voit pas d'en haut.
func _add_ground_quad(area: Rect2, y: float, color: Color) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = area.size

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(area.get_center().x, y, area.get_center().y)
	CelStyle.apply_flat(node, color)
	add_child(node)


## Aplat opaque equivalent a `color` pose sur le sol avec `alpha` d'opacite.
func _over_floor(color: Color, alpha: float) -> Color:
	return FLOOR_COLOR.lerp(color, alpha)
