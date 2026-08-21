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

## ⭐ LE 1er MEUBLE PEINT — table basse, 2026-08-21. Son volume ne porte que la
## silhouette ; le dessin arrive d'une illustration 2D projetee a 44,02°
## ("Visual Art Direction" §2quater). Il se pose exactement comme le canape :
## c'est `CelProp.PEINT` qui change tout, pas ce qui l'entoure.
const TABLE_BASSE := "res://assets/models/prop_table_basse.glb"

## Ton moyen du parquet. Sert de fond de melange aux aplats du mobilier, pour
## qu'ils restent coherents avec le sol sur lequel ils sont poses.
const FLOOR_COLOR := Color("#E8D4A8")
const INK := Color("#2A2A3A")

## Le sol deborde largement de l'aire de jeu : la camera voit au-dela du mur
## de bordure, et il ne doit jamais y avoir de vide a l'ecran.
const FLOOR_OVERSHOOT := 60.0

## ─── LE MUR ET SES BAIES (2026-08-20) ───────────────────────────────────────
##
## Le mur etait quatre boites de 1,2 m de haut, nues. Il porte desormais des
## fenetres — de VRAIS trous dans la geometrie — et une DirectionalLight3D
## passe dedans. Le pourquoi et les interdits sont dans "Visual Art Direction"
## §6bis ; la composition, dans "Prompts de Generation" §4.7. Ce qui suit n'en
## est que la mise en nombres, et chaque nombre a une raison.
##
## ⚠️ LE MUR SE DIMENSIONNE EN METRES, JAMAIS EN FRACTION D'ARENE — meme regle
## que le mobilier, et pour la meme raison. L'arene fait 160 x 90 m : ce n'est
## pas un salon, c'est un plan de jeu. Un mur unique « d'un bout a l'autre »
## n'a aucun sens a cette echelle, et une fenetre etiree a sa mesure serait une
## baie de 40 m. Le mur est donc une TRAVEE REPETABLE.

## 2,6 m — un vrai mur d'appartement, contre 1,2 m avant, qui etait la hauteur
## d'une barriere. Le changement n'est pas decoratif : sous 1,2 m il n'y a
## simplement pas la place d'ouvrir une baie au-dessus d'un chat de 1,86.
const WALL_HEIGHT := 2.6

## 0,6 m — l'embrasure, et c'est elle qui taille le rai, pas la baie.
##
## ⚠️ Descendue de 1,0 m, et ce n'est pas un arrondi. Le trou est un TUNNEL :
## a 26° de soleil, chaque metre d'epaisseur rogne 0,49 m de hauteur utile a
## l'ouverture. A 1,0 m d'epaisseur le rai tombait a moins d'un metre de
## profondeur — une frange collee au pied du mur, invisible au cadrage de jeu.
## Le mur ne collisionne rien (c'est `main.clamp_to_arena()` qui tient la
## limite), donc son epaisseur ne coute que du dessin.
const WALL_THICKNESS := 0.6

## Le PAS DE REPETITION des travees — la premiere des deux seules molettes de
## §6bis, celle qui decide si l'ombre des baies est un motif ou un accident.
##
## ⚠️ C'est le piege le mieux mesure du projet, et le rendre reel ne l'evite
## pas : le rai de soleil PEINT a ete retire le 2026-08-17 parce qu'une grande
## forme claire ancree au monde DEFILE a l'ecran des que le chat marche. Une
## ombre calculee est ancree pareil et defile pareil. Ce qui sauve celle-ci
## n'est pas son mode de calcul, c'est qu'elle se REPETE : le parquet defile
## aussi et ne gene personne. A 8 m, le cadre (~29 m) en montre trois et demie,
## soit une dizaine de panneaux de lumiere — un rythme, pas une bande.
const BAY_LENGTH := 8.0

const OPENING_WIDTH := 3.6
## Sous 1,4 m de trumeau le mur cesse de se lire comme un mur perce et devient
## une claire-voie. Borne l'ouverture quand un mur court doit resserrer ses
## travees.
const MIN_PIER := 1.4

## Appui et linteau — LES BANDES HORIZONTALES de §4.7. Sous une camera a 45°
## une surface verticale est ecrasee : un mur de 2,6 m ne rend qu'~1,8 m de
## hauteur apparente. Ce qui doit se lire se pose donc a plat ; les montants ne
## portent rien. Et rien d'important ne descend dans le tiers bas, qui
## n'atteint jamais l'ecran.
const SILL_HEIGHT := 0.95
const HEAD_HEIGHT := 2.25

## Les meneaux DECOUPENT LE RAI en une grille lisible, et c'est tout leur
## interet : sans eux la baie pose un rectangle de lumiere muet. Ils sont donc
## de la geometrie, pas un dessin — un meneau peint n'arrete aucun photon.
const MULLION_COUNT := 2
const MULLION_WIDTH := 0.16
const TRANSOM_HEIGHT := 0.14
const TRANSOM_AT := 0.62
## Profondeur de la menuiserie, posee au nu INTERIEUR : c'est le seul plan ou
## le joueur la voit. Le rai, lui, est taille par l'embrasure de toute facon.
const FRAME_DEPTH := 0.14

## Le couvre-mur — la seule piece a porter le trait PLEIN.
##
## ⚠️ C'est LA reponse aux deux poids d'encre de §4.7, et elle est geometrique
## plutot que shader. Le mur doit garder l'arete qui dit « ici on ne passe
## plus » — une limite qu'on ne voit pas est une limite qu'on decouvre en s'y
## cognant — sans qu'un quadrillage de baies a l'encre pleine, sur la plus
## grande surface de l'image, ne ramene le regard sur le decor. Une piece
## pleine en haut, tout le reste a la moitie.
const CREST_HEIGHT := 0.16
const CREST_OVERHANG := 0.07

const WALL_INK := 0.05
const WALL_INK_INNER := 0.025

## L'aplat vu derriere les baies. Un seul ton, aucun paysage (§4.7).
const SKY_COLOR := Color("#A0C8D8")
const SKY_GAP := 0.5

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
	# La table basse — le 1er objet du jeu dont le dessin vient d'une IMAGE.
	#
	# Son emprise 3,0 x 1,6 est celle que la boite pastel occupait deja : on ne
	# change pas la place d'un meuble en meme temps que sa nature, sinon on ne
	# sait plus lequel des deux on juge. Sa HAUTEUR, elle, monte de 0,8 a 1,0 —
	# l'assise du canape est a 1,6, et une table basse se lit contre elle.
	#
	# ⚠️ ET ELLE BLOQUE, DESORMAIS. La boite pastel ne portait aucune collision
	# (`_add_prop` n'en pose que sur les modeles) : passer la table en .glb lui
	# en donne une, comme au canape. C'est voulu — c'est le second geste du
	# chantier « le meuble comme terrain de jeu », et une table de 3 m au CENTRE
	# de la cellule est exactement l'obstacle qui rend le placement du chat
	# decisif. Le point d'apparition est protege par `SPAWN_CLEARANCE`.
	{"at": Vector2(0.50, 0.52), "size": Vector2(3.0, 1.6),
		"model": TABLE_BASSE, "variant": "table_basse", "yaw": 0.0,
		"family": CelProp.PEINT},
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
	# ⚠️ Le sol RECOIT l'ombre, il n'en jette pas. Un plan a y = 0 qui caste sur
	# lui-meme ne produit que de l'acne de carte d'ombre.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	# Meme raison que le sol, a 12 mm pres : un tapis pose a plat ne jetterait
	# son ombre que sur le parquet qu'il touche.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	var node := CelProp.spawn(
		prop["model"], prop["variant"], _outline_scale,
		prop.get("family", CelProp.MEUBLE),
	)

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
##
## Quatre travees de baies, plus le soleil qui passe dedans. Voir le bandeau
## des constantes plus haut ; ici, seulement l'assemblage.
##
## ⚠️ Les quatre murs sont batis, y compris le PLUS PROCHE — celui entre la
## camera et le chat, dont §4.7 dit qu'il n'entre jamais dans l'image. Il n'y
## entre pas et il n'occulte rien (a 45° la ligne camera→chat passe 16 m
## au-dessus de son couvre-mur), mais il ferme la piece pour le soleil : sans
## lui, un mur sur deux serait une paroi qui commence nulle part.
func _build_walls(rect: Rect2) -> void:
	var half := WALL_THICKNESS * 0.5

	# Les murs en X portent les angles ; ceux en Z s'arretent au nu interieur.
	# Deux boites qui se croisent produisent un trait parasite a leur
	# intersection (piege n°2 du pivot) — au coin d'un mur c'est un joint, on
	# l'evite quand meme : il ne coute qu'un decalage de l'emprise.
	_build_wall_run(
		Vector3(rect.position.x - half, 0.0, rect.position.y), Vector3(1.0, 0.0, 0.0),
		rect.size.x + WALL_THICKNESS, 1.0
	)
	_build_wall_run(
		Vector3(rect.position.x - half, 0.0, rect.end.y), Vector3(1.0, 0.0, 0.0),
		rect.size.x + WALL_THICKNESS, -1.0
	)
	_build_wall_run(
		Vector3(rect.position.x, 0.0, rect.position.y + half), Vector3(0.0, 0.0, 1.0),
		rect.size.y - WALL_THICKNESS, 1.0
	)
	_build_wall_run(
		Vector3(rect.end.x, 0.0, rect.position.y + half), Vector3(0.0, 0.0, 1.0),
		rect.size.y - WALL_THICKNESS, -1.0
	)

	_build_sun()


## Une paroi complete, de `origin` sur `length` metres le long de `axis`.
##
## `inward` dit de quel cote est la piece (+1 ou -1 sur l'axe transverse) : il
## place la menuiserie au nu interieur, le ciel au nu exterieur, et il est le
## seul nombre qui change d'un des quatre murs a l'autre.
##
## Le decoupage en travees n'est pas `length / BAY_LENGTH` tronque : le pas est
## AJUSTE pour tomber juste. Une derniere travee de 2 m serait le seul accident
## d'un rythme regulier, donc la seule chose que l'œil verrait.
func _build_wall_run(origin: Vector3, axis: Vector3, length: float, inward: float) -> void:
	if length <= 0.0:
		return

	var across := Vector3(axis.z, 0.0, axis.x) * inward
	var bays := maxi(1, int(round(length / BAY_LENGTH)))
	var bay := length / float(bays)
	var opening := minf(OPENING_WIDTH, bay - 2.0 * MIN_PIER)

	# Deux materiaux, deux poids d'encre, et c'est tout ce qui les separe (§4.7).
	var body := CelStyle.make_wall(WALL_INK_INNER)
	var crest := CelStyle.make_wall(WALL_INK)

	if opening <= 0.0:
		# Mur trop court pour une baie : il reste plein, et c'est une paroi
		# valide. Aucun garde ailleurs n'a besoin de le savoir.
		_add_wall_box(origin, axis, across, 0.0, length, 0.0, WALL_HEIGHT, WALL_THICKNESS, 0.0, body)
		return

	var pier := (bay - opening) * 0.5

	# 1 — l'allege, d'un bout a l'autre. Une seule piece, pas une par travee :
	#     deux boites bout a bout dessineraient un joint d'encre a chaque
	#     travee, soit le quadrillage que §4.7 refuse.
	_add_wall_box(origin, axis, across, 0.0, length, 0.0, SILL_HEIGHT, WALL_THICKNESS, 0.0, body)
	# 2 — le linteau, meme raison.
	_add_wall_box(
		origin, axis, across, 0.0, length,
		HEAD_HEIGHT, WALL_HEIGHT - HEAD_HEIGHT, WALL_THICKNESS, 0.0, body
	)

	# 3 — les trumeaux. Ceux de deux travees voisines sont FUSIONNES en une
	#     piece : accoles, ils se liraient comme deux poteaux jumeaux.
	for index in bays + 1:
		var start := maxf(float(index) * bay - pier, 0.0)
		var stop := minf(float(index) * bay + pier, length)
		_add_wall_box(
			origin, axis, across, start, stop - start,
			SILL_HEIGHT, HEAD_HEIGHT - SILL_HEIGHT, WALL_THICKNESS, 0.0, body
		)

	# 4 et 5 — la menuiserie dans le trou, au nu interieur.
	var frame_offset := (WALL_THICKNESS - FRAME_DEPTH) * 0.5
	for index in bays:
		var opening_start := float(index) * bay + pier

		for pane in MULLION_COUNT:
			var at := opening_start + opening * float(pane + 1) / float(MULLION_COUNT + 1)
			_add_wall_box(
				origin, axis, across, at - MULLION_WIDTH * 0.5, MULLION_WIDTH,
				SILL_HEIGHT, HEAD_HEIGHT - SILL_HEIGHT, FRAME_DEPTH, frame_offset, body
			)

		_add_wall_box(
			origin, axis, across, opening_start, opening,
			SILL_HEIGHT + (HEAD_HEIGHT - SILL_HEIGHT) * TRANSOM_AT - TRANSOM_HEIGHT * 0.5,
			TRANSOM_HEIGHT, FRAME_DEPTH, frame_offset, body
		)

	# 6 — le couvre-mur : la seule piece a l'encre pleine.
	_add_wall_box(
		origin, axis, across, 0.0, length, WALL_HEIGHT, CREST_HEIGHT,
		WALL_THICKNESS + 2.0 * CREST_OVERHANG, 0.0, crest
	)

	_add_sky_plate(origin, axis, across, length)


## Une piece du mur, en coordonnees de PAROI plutot que de monde.
##
##   `along` / `run`     position et longueur le long du mur
##   `bottom` / `height` en metres au-dessus du sol
##   `depth` / `shift`   epaisseur en travers, et son decalage vers l'interieur
func _add_wall_box(
	origin: Vector3, axis: Vector3, across: Vector3,
	along: float, run: float, bottom: float, height: float,
	depth: float, shift: float, material: Material
) -> void:
	if run <= 0.0 or height <= 0.0:
		return

	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		absf(axis.x) * run + absf(across.x) * depth,
		height,
		absf(axis.z) * run + absf(across.z) * depth
	)

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = (
		origin
		+ axis * (along + run * 0.5)
		+ across * shift
		+ Vector3(0.0, bottom + height * 0.5, 0.0)
	)
	node.material_override = material
	add_child(node)


## L'aplat derriere les baies. Un plan par paroi, pose juste dehors.
##
## ⚠️ IL EST PLACE A 0,5 m DU NU EXTERIEUR, ET C'EST LA TOUTE LA QUESTION. La
## camera plonge a 45° : par une fenetre on ne regarde pas le ciel, on regarde
## le SOL du dehors. Un plan pose loin laisserait voir le parquet deborder par
## le trou ; a 0,5 m, la ligne de visee la plus basse le rencontre avant
## d'atteindre quoi que ce soit. Il descend sous le sol pour la meme raison.
func _add_sky_plate(origin: Vector3, axis: Vector3, across: Vector3, length: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(length + 2.0, WALL_HEIGHT + 1.5)
	mesh.orientation = PlaneMesh.FACE_Z

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = (
		origin
		+ axis * (length * 0.5)
		- across * (WALL_THICKNESS * 0.5 + SKY_GAP)
		+ Vector3(0.0, WALL_HEIGHT * 0.5 - 0.5, 0.0)
	)
	node.rotation.y = atan2(across.x, across.z)
	node.material_override = CelStyle.make_sky(SKY_COLOR)
	# ⛔ Pose entre le soleil et la baie, un ciel casteur bouche exactement le
	# rai qu'on vient de construire. Le defaut serait muet : un mur perce dont
	# aucune fenetre n'eclaire rien.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## Le soleil. Voir `sun_rig.gd` — il ne se regle pas ici.
func _build_sun() -> void:
	if not SunRig.wanted():
		return

	var sun := SunRig.new()
	sun.name = "Sun"
	add_child(sun)


# ------------------------------------------------------------------------ outils

## Aplat opaque equivalent a `color` pose sur le sol avec `alpha` d'opacite.
func _over_floor(color: Color, alpha: float) -> Color:
	return FLOOR_COLOR.lerp(color, alpha)
