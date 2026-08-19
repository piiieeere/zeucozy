class_name TierPips
extends Control

## 🔶 Le palier d'une competence, en LOSANGES — un par palier, remplis jusqu'a
## celui qu'on tient.
##
## Vient de `maquettes/panelwithcards2.png`, ou la carte porte trois losanges
## sous sa vignette au lieu d'une ligne de texte.
##
## ─── Pourquoi c'est DESSINE et pas ecrit ───
##
## ⚠️ IL N'Y A PAS DE GLYPHE LOSANGE DANS CE JEU, et c'est un piege qui ne se
## voit qu'a l'ecran. Les deux familles d'UI sont des SOUS-ENSEMBLES latins
## (`tools/fetch_fonts.ps1`) : `latin` couvre U+0000-00FF, `latin-ext` ajoute
## l'oe lie. U+25C6 ◆ et U+25C7 ◇ ne sont dans ni l'un ni l'autre. Un label
## "◆◇◇" sortirait donc en tofu — et sans erreur, puisqu'un glyphe manquant
## n'est pas une faute pour Godot. Poser ces caracteres dans `locale.gd` aurait
## le meme defaut, deux fois.
##
## Le dessin evite aussi de figer le nombre de paliers dans une chaine : il se
## lit du catalogue, et une competence a 2 ou 4 paliers sortirait juste.
##
## ─── Ce qu'il NE remplace PAS ───
##
## Le marqueur de texte reste a cote ("NOUVEAU", "PALIER 2", "ULTIME"). Les deux
## ne disent pas la meme chose : le losange dit OU ON EN EST sur l'echelle —
## information que le texte ne porte pas, "PALIER 2" ne disant pas s'il en reste
## un ou trois — et le texte dit ce que la carte FAIT, un deblocage n'etant pas
## un renfort. C'est le meme partage que le bandeau de type, ou la couleur se lit
## d'un balayage et le mot se lit lentement mais toujours (§9.9).


## Le losange, en px. A 9 il pese exactement la ligne de legende (10 px de
## corps) : la rangee ne prend donc aucune hauteur que la carte n'avait pas, et
## `CHOICE_SIZE` ne bouge pas — ce que le commentaire de `hud.gd` demande
## expressement de ne pas faire a la legere.
const PIP := 9.0
const GAP := 4.0

var _filled := 0
var _total := 0
var _color := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `filled` est borne a `total` : un ULTIME arrive a `tier` = taille + 1 (voir
## `_tier_marker`), et sans borne il demanderait un 4e losange qui n'existe pas.
func set_tiers(filled: int, total: int, color: Color) -> void:
	_total = maxi(total, 0)
	_filled = clampi(filled, 0, _total)
	_color = color

	var width := 0.0 if _total == 0 else float(_total) * PIP + float(_total - 1) * GAP
	custom_minimum_size = Vector2(width, PIP)
	queue_redraw()


func _draw() -> void:
	# Les losanges ACQUIS sont pleins, les autres en contour. Meme teinte pour
	# les deux : ce n'est pas une autre categorie, c'est la meme echelle vue plus
	# loin — un contour d'une autre couleur en ferait deux informations.
	#
	# ⚠️ AUCUN ANTIALIASING, et c'est le meme parti que partout ailleurs : §9.1
	# regle 2 interdit le degrade, et un contour lisse est un degrade de 1 px. Le
	# reste de l'interface est a bord franc, une pastille floue s'y verrait.
	var half := PIP * 0.5
	var y := size.y * 0.5

	for index in range(_total):
		var cx := float(index) * (PIP + GAP) + half
		var points := PackedVector2Array([
			Vector2(cx, y - half),
			Vector2(cx + half, y),
			Vector2(cx, y + half),
			Vector2(cx - half, y),
		])

		if index < _filled:
			draw_colored_polygon(points, _color)
		else:
			# Le contour se REFERME : `draw_polyline` ne relie pas le dernier
			# point au premier, et un losange ouvert se lit comme un chevron.
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, _color, 1.5, false)
