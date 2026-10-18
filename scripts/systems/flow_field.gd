class_name FlowField
extends Node

## La CARTE DES CHEMINS — un champ de Dijkstra calcule DEPUIS le chat, que tous
## les ennemis lisent (2026-10-18).
##
## ⭐ UN SEUL CALCUL POUR TOUTE LA HORDE, et c'est ce qui l'a fait preferer a
## NavigationServer / AStarGrid2D. Ceux-la cherchent un chemin PAR AGENT ; or
## dans un survivor, tous les agents vont au MEME endroit. Un Dijkstra lance a
## l'envers — source au chat, propage sur toute l'arene — donne d'un coup la
## distance au chat de chaque case, donc la direction a prendre de partout. Le
## cout ne depend plus du nombre d'ennemis, seulement de la taille de la grille,
## et il ne se paie que quand le chat change de case.
##
## Trois couts de case, releves une fois a la construction :
##
##   * SOLID — dans l'emprise d'un meuble bloquant : infranchissable ;
##   * RING  — a moins de CLEARANCE du meuble : franchissable, mais RING_COST
##     fois plus cher. Les chemins longent donc les meubles a distance, sans que
##     l'anneau soit un mur : un ennemi repousse dedans, ou un chat colle au
##     canape, garde un chemin pour en sortir ;
##   * FREE  — le parquet.
##
## ⛔ LE CALCUL TOURNE SUR UN THREAD DE TRAVAIL, ET CE N'EST PAS UNE COQUETTERIE.
## Mesure le 2026-10-18 sur l'arene de 160 x 90 m en cases de 0,5 m (58 604
## cases, bordure comprise) : ~51 ms par calcul en GDScript, soit trois frames
## entieres. Sur le thread principal, chaque pas du chat d'une case a l'autre
## aurait fait un a-coup. Le calcul ecrit donc dans un tampon neuf, et le champ
## n'est echange qu'une fois fini — les ennemis lisent toujours un champ
## complet, au pire vieux de ~50 ms, soit 0,4 m de course du chat.
##
## ⚠️ LA DIRECTION SE LIT EN BILINEAIRE, jamais case par case. Dijkstra a 8
## voisins ne connait que 8 caps ; lu tel quel, un ennemi tournerait par crans
## de 45° a chaque frontiere de case. Le melange des 4 cases voisines arrondit
## les virages sans rien couter de plus.
##
## ⚠️ ET LE CHAMP NE SERT QUE QUAND LE CHAT EST CACHE — c'est l'ennemi qui en
## decide (`Enemy._has_clear_run`). A decouvert, la poursuite reste la ligne
## droite d'avant, au cap exact : rien ne doit changer la ou il n'y a rien a
## contourner.

const CELL_SIZE := 0.5

## Marge gardee autour d'un meuble. 1,0 m couvre la plus grosse bete (le
## basset, rayon de collision 0,9) ; la souris (0,65) passe un peu plus au
## large que necessaire, ce qui ne se voit pas.
const CLEARANCE := 1.0
const RING_COST := 4

## Couts de pas ENTIERS — 5 et 7, soit un rapport 1,4 pour √2. C'est ce qui
## permet la file a seaux (Dial) au lieu d'un tas binaire.
const STRAIGHT := 5
const DIAGONAL := 7

const SOLID := 0
const FREE := 1
const UNREACHED := 1 << 30
const NO_FLOW := 255

# Les 8 voisins : E, O, S, N, puis les diagonales. `_OPPOSITE[k]` pointe dans
# l'autre sens — le flux d'une case pointe VERS la case qui l'a atteinte, donc
# a rebours du pas de propagation.
const _DX := [1, -1, 0, 0, 1, -1, 1, -1]
const _DY := [0, 0, 1, -1, 1, 1, -1, -1]
const _OPPOSITE := [1, 0, 3, 2, 7, 6, 5, 4]

var _target: Node3D
## Coin haut-gauche de la grille dans le plan XZ, BORDURE comprise.
var _origin := Vector2.ZERO
var _columns := 0
var _rows := 0

## Fige apres `setup()` : le thread de travail le lit sans verrou, et c'est sur
## parce que plus personne ne l'ecrit.
var _cost := PackedByteArray()
## Le champ que lisent les ennemis. Remplace d'un bloc, jamais modifie en place.
var _flow := PackedByteArray()

# Tables precalculees a la taille de la grille : decalage lineaire de chaque
# voisin, cout de base du pas, et les deux cases a verifier pour une diagonale.
var _step := PackedInt32Array()
var _base_cost := PackedInt32Array()
var _side_a := PackedInt32Array()
var _side_b := PackedInt32Array()
var _direction: Array[Vector3] = []

## La case du chat pour laquelle le dernier calcul a ete LANCE.
var _source := -1
var _task := -1
## Ecrit par le thread de travail, lu par le thread principal une fois la tache
## terminee — jamais avant.
var _solved := PackedByteArray()


## `obstacles` — les emprises au sol des meubles bloquants, dans le plan XZ
## (x → x, y → z). Elles viennent de `Arena.blockers`, pas de la physique : un
## releve par requete de forme sur 60 000 cases couterait plus que le jeu.
func setup(target: Node3D, arena_rect: Rect2, obstacles: Array[Rect2]) -> void:
	_finish_task()
	_target = target

	# Une case de BORDURE, solide, tout autour. C'est elle qui dispense la
	# boucle de Dijkstra de tout test de limite : le voisin d'une case du bord
	# existe toujours, il est juste infranchissable.
	_origin = arena_rect.position - Vector2.ONE * CELL_SIZE
	_columns = int(ceil(arena_rect.size.x / CELL_SIZE)) + 2
	_rows = int(ceil(arena_rect.size.y / CELL_SIZE)) + 2

	var count := _columns * _rows
	_cost.resize(count)
	_cost.fill(FREE)
	_flow.resize(count)
	_flow.fill(NO_FLOW)

	for x in _columns:
		_cost[x] = SOLID
		_cost[(_rows - 1) * _columns + x] = SOLID
	for y in _rows:
		_cost[y * _columns] = SOLID
		_cost[y * _columns + _columns - 1] = SOLID

	for rect in obstacles:
		_stamp(rect)

	_step.resize(8)
	_base_cost.resize(8)
	_side_a.resize(8)
	_side_b.resize(8)
	_direction.clear()

	for k in 8:
		var dx: int = _DX[k]
		var dy: int = _DY[k]
		_step[k] = dy * _columns + dx
		_base_cost[k] = STRAIGHT if dx == 0 or dy == 0 else DIAGONAL
		_side_a[k] = dx
		_side_b[k] = dy * _columns
		_direction.append(Vector3(dx, 0.0, dy).normalized())

	_source = -1
	_refresh()


## Le node est en PROCESS_MODE_PAUSABLE (main.tscn) : derriere un carton, aucun
## calcul n'est relance. Une tache deja partie finit, et son champ est pris a
## la reprise.
func _physics_process(_delta: float) -> void:
	_refresh()


## ⛔ Un thread qui lit les tableaux d'un node libere plante le jeu. Le restart
## recharge la scene : on attend donc la tache en cours avant de partir.
func _exit_tree() -> void:
	_finish_task()


## La direction a prendre depuis `world_position`, a plat et normee — ou
## `Vector3.ZERO` hors grille, dans un meuble, ou avant le premier calcul.
## L'appelant retombe alors sur la ligne droite.
func direction_at(world_position: Vector3) -> Vector3:
	if _columns == 0:
		return Vector3.ZERO

	# Cases dont le CENTRE encadre le point : -0,5 case avant la troncature.
	var gx := (world_position.x - _origin.x) / CELL_SIZE - 0.5
	var gy := (world_position.z - _origin.y) / CELL_SIZE - 0.5
	var x0 := int(floor(gx))
	var y0 := int(floor(gy))
	var fx := gx - x0
	var fy := gy - y0

	var blended := Vector3.ZERO

	for corner in 4:
		var x := x0 + (corner & 1)
		var y := y0 + (corner >> 1)

		if x < 0 or y < 0 or x >= _columns or y >= _rows:
			continue

		var flow := _flow[y * _columns + x]

		if flow == NO_FLOW:
			continue

		var weight := (fx if corner & 1 else 1.0 - fx) * (fy if corner >> 1 else 1.0 - fy)
		blended += _direction[flow] * weight

	if blended.length_squared() < 1.0e-6:
		return Vector3.ZERO

	return blended.normalized()


## Pose un meuble sur la grille : SOLID dans son emprise, RING autour.
func _stamp(rect: Rect2) -> void:
	var halo := rect.grow(CLEARANCE)
	var x_from := maxi(1, int(floor((halo.position.x - _origin.x) / CELL_SIZE)))
	var y_from := maxi(1, int(floor((halo.position.y - _origin.y) / CELL_SIZE)))
	var x_to := mini(_columns - 2, int(ceil((halo.end.x - _origin.x) / CELL_SIZE)))
	var y_to := mini(_rows - 2, int(ceil((halo.end.y - _origin.y) / CELL_SIZE)))

	for y in range(y_from, y_to + 1):
		for x in range(x_from, x_to + 1):
			var center := _origin + (Vector2(x, y) + Vector2.ONE * 0.5) * CELL_SIZE
			# Distance du centre de case au rectangle — nulle dedans.
			var outside := Vector2(
				maxf(maxf(rect.position.x - center.x, center.x - rect.end.x), 0.0),
				maxf(maxf(rect.position.y - center.y, center.y - rect.end.y), 0.0)
			).length()
			var index := y * _columns + x

			if outside <= 0.0:
				_cost[index] = SOLID
			elif outside <= CLEARANCE and _cost[index] != SOLID:
				_cost[index] = RING_COST


## Prend le champ d'une tache terminee, et en relance une si le chat a change
## de case. Une seule tache a la fois : un chat qui court plus vite que le
## calcul ne fait que sauter des cases, il n'empile rien.
func _refresh() -> void:
	if _task != -1:
		if not WorkerThreadPool.is_task_completed(_task):
			return

		_finish_task()

	if not is_instance_valid(_target) or not _target.is_inside_tree() or _columns == 0:
		return

	var x := int(floor((_target.global_position.x - _origin.x) / CELL_SIZE))
	var y := int(floor((_target.global_position.z - _origin.y) / CELL_SIZE))
	var source := clampi(y, 1, _rows - 2) * _columns + clampi(x, 1, _columns - 2)

	if source == _source:
		return

	_source = source
	_task = WorkerThreadPool.add_task(_solve.bind(source), false, "FlowField")


func _finish_task() -> void:
	if _task == -1:
		return

	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_flow = _solved


## Dijkstra, en file a seaux (algorithme de Dial) : les couts de pas sont des
## entiers bornes, donc une case de distance `d` se range dans le seau
## `d % seaux`, et aucun tas n'est necessaire. Une entree perimee (la case a
## ete atteinte plus court entre-temps) se reconnait a sa distance, et passe.
##
## Le flux de chaque case est pose au moment ou elle est AMELIOREE : il pointe
## vers la case d'ou vient le meilleur chemin. Aucune seconde passe.
##
## ⚠️ PAS DE COUPE DE COIN : une diagonale exige ses deux cases laterales
## franchissables. Sans ca, le chemin passerait en biais entre deux cases
## solides qui se touchent par un coin — soit a travers l'angle du canape.
##
## ⛔ TOURNE SUR LE THREAD DE TRAVAIL. Ne lit que ce que `setup()` a fige, et
## n'ecrit que des tableaux locaux, rendus par `_solved` en une affectation.
func _solve(source: int) -> void:
	var distance := PackedInt32Array()
	distance.resize(_cost.size())
	distance.fill(UNREACHED)
	var flow := PackedByteArray()
	flow.resize(_cost.size())
	flow.fill(NO_FLOW)

	var bucket_count := DIAGONAL * RING_COST + 1
	var buckets: Array[Array] = []
	for _index in bucket_count:
		buckets.append([])

	distance[source] = 0
	buckets[0].append(source)
	var pending := 1
	var current := 0

	while pending > 0:
		var bucket: Array = buckets[current % bucket_count]

		for cell: int in bucket:
			pending -= 1

			if distance[cell] != current:
				continue

			for k in 8:
				var next := cell + _step[k]
				var weight := _cost[next]

				if weight == SOLID:
					continue

				if k >= 4 and (_cost[cell + _side_a[k]] == SOLID or _cost[cell + _side_b[k]] == SOLID):
					continue

				var reached := current + _base_cost[k] * weight

				if reached < distance[next]:
					distance[next] = reached
					flow[next] = _OPPOSITE[k]
					buckets[reached % bucket_count].append(next)
					pending += 1

		bucket.clear()
		current += 1

	_solved = flow
