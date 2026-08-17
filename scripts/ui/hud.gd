extends Control

## L'interface du jeu — HUD permanent + cartons de moment.
##
## Construite EN CODE depuis ui_style.gd, et pas dans un .tscn : c'est ce qui
## garantit qu'aucune valeur de style ne se fige dans une scene ou personne ne
## la retrouvera. Le meme parti que arena.gd pour le decor et cel_model.gd pour
## le chat — la scene porte un noeud, le script porte le style.
##
## ─── Le partage HUD / cartons ───
##
## "Visual Art Direction" §9.2-9.3, reecrit le 2026-08-16 d'apres l'analyse
## image d'Orbitals. Deux registres, et c'est leur CONTRASTE qui fait
## l'evenement, pas la taille des cartons :
##
##   • LE HUD PERMANENT EST NU. Aucune plaque, aucun cadre, aucune equerre. Du
##     texte creme cerne d'encre, pose directement sur le jeu, minuscule et
##     tasse dans un coin. Il se detache par son cerne — la logique exacte du
##     contour du chat sur le parquet.
##   • LES CARTONS ONT UN CONTENANT. Plaque sombre, filet d'encre, coins coupes,
##     lignes de vitesse, entree EN PAS. Ils prennent l'ecran parce qu'ils sont
##     les seuls a en avoir le droit.
##
## ⚠️ Le jour ou une plaque apparait derriere le HUD, le registre bascule
## d'"anime" a "logiciel" et rien dans le code ne le signalera.

const UiStyle := preload("res://scripts/systems/ui_style.gd")
const FxCadence := preload("res://scripts/systems/fx_cadence.gd")
const Locale := preload("res://scripts/systems/locale.gd")

## Le carton s'ouvre en 3 poses. §9.3 regle 4 : en pas, jamais en fondu — un
## panneau qui glisse en `tween` serait le seul element de l'image a ne pas etre
## en cellulo, et ca se voit immediatement.
const CARD_POSES: Array[float] = [0.0, 0.34, 0.72, 1.0]

const CARD_SIZE := Vector2(560.0, 300.0)
const GAME_OVER_SIZE := Vector2(440.0, 260.0)
const SETTINGS_SIZE := Vector2(460.0, 250.0)
const CHOICE_SIZE := Vector2(168.0, 128.0)
const LANGUAGE_SIZE := Vector2(150.0, 44.0)

signal choice_selected(index: int)
signal restart_pressed
## Le joueur a choisi une langue. Le HUD ne l'applique PAS lui-meme : il ne sait
## rien des valeurs de jeu (vie, temps, objectif) qu'il faudrait reafficher. Il
## previent main.gd, qui possede l'etat et repousse tout — le meme partage que
## partout ailleurs ici, le HUD dessine, main decide.
signal language_selected(code: String)

var _time_value: Label
var _health_fill: ColorRect
var _health_value: Label
var _xp_fill: ColorRect
var _level_value: Label
var _objective: Label
var _enemy_count: Label
var _telemetry: Label

var _level_card: Control
var _level_title: Label
var _level_sub: Label
var _choice_slots: Array[Dictionary] = []

var _game_over_card: Control
var _game_over_summary: Label
var _restart_button: Button

var _settings_card: Control
var _settings_title: Label
var _settings_hint: Label
var _settings_language_label: Label
var _settings_close: Button
var _language_slots: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_corner_block()
	_build_status_block()
	_build_telemetry()
	_build_level_card()
	_build_game_over_card()
	_build_settings_card()


# ─────────────────────────────────────────────────────────────────────────────
# HUD permanent
# ─────────────────────────────────────────────────────────────────────────────


## Le bloc de survie, en haut a gauche : temps, vie, XP, niveau.
##
## Tout tient dans UN coin, et c'est le point. Un bandeau qui traverse l'ecran
## vole a l'arene la bande la plus utile — celle ou les ennemis arrivent.
func _build_corner_block() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	column.position = Vector2(UiStyle.MARGIN, UiStyle.MARGIN)
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	# Le kana coiffe le chiffre, en tout petit — l'accent d'epoque, jamais
	# porteur d'information (§9.4).
	column.add_child(UiStyle.make_kana_label("time"))

	_time_value = UiStyle.make_label(
		"0:00", UiStyle.display_font(), UiStyle.SIZE_TIME, UiStyle.CREAM, 0, 3, true
	)
	column.add_child(_time_value)

	var health_row := _make_gauge_row(UiStyle.HEALTH_BAR, UiStyle.TERRACOTTA)
	column.add_child(health_row["row"])
	_health_fill = health_row["fill"]

	# La vie porte son NOMBRE, contrairement a l'XP.
	#
	# §9.3 regle 5 disait "jamais de nombre la ou une forme suffit", et c'est
	# pour ca que la vie etait en pastilles. Le passage a 100 points change la
	# donne : la barre dit toujours "combien il reste", mais elle ne dit pas
	# "de combien ce coup m'a coute" ni "combien ce vol de vie m'a rendu" — et
	# c'est exactement ce qu'un systeme de points existe pour rendre lisible.
	# La forme reste le premier niveau de lecture, le nombre le second.
	_health_value = UiStyle.make_hud_label("100")
	health_row["row"].add_child(_health_value)

	var xp_row := _make_gauge_row(UiStyle.XP_BAR, UiStyle.GOLD)
	column.add_child(xp_row["row"])
	_xp_fill = xp_row["fill"]

	_level_value = UiStyle.make_hud_label(Locale.t("hud.level") % 1)
	xp_row["row"].add_child(_level_value)


## Une jauge : piste creuse cernee d'encre, remplissage plein a l'interieur.
##
## Vie et XP partagent cette fabrique. Elles n'ont pas la meme epaisseur ni la
## meme couleur, mais elles doivent avoir le meme DESSIN — deux jauges cote a
## cote qui ne se ressemblent pas se lisent comme deux systemes differents.
func _make_gauge_row(gauge_size: Vector2, fill_color: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# La piste : creuse, juste un filet d'encre. Une piste pleine ferait deux
	# barres au lieu d'une, et on ne saurait plus laquelle est la jauge.
	var track := UiStyle.make_plate(
		Color(UiStyle.INK, 0.22), UiStyle.INK, UiStyle.CHAMFER_SMALL, 1.0
	)
	track.custom_minimum_size = gauge_size
	# ⚠️ SANS CECI LA PISTE EST UNE DALLE. Un HBoxContainer etire ses enfants a
	# la hauteur de la RANGEE, et la rangee fait la hauteur du label a cote.
	# La hauteur de `gauge_size` n'est qu'un minimum : elle ne plafonne rien.
	# Constate a l'image, invisible en lisant le code.
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)

	# Le remplissage est un ColorRect NU, enfant de la piste : a 8 px de haut un
	# chanfrein ne se verrait pas et couterait un second materiau. Le filet de
	# la piste fait deja tout le travail de forme.
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.position = Vector2(1.0, 1.0)
	fill.size = Vector2(0.0, gauge_size.y - 2.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)

	return {"row": row, "track": track, "fill": fill}


## Le bloc d'etat, en haut a droite : ce que fait la vague.
##
## Aligne a DROITE, ce qui demande un anchor et pas une position : le bloc doit
## rester colle au bord quand la fenetre change de largeur.
func _build_status_block() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	column.offset_left = -320.0
	column.offset_top = UiStyle.MARGIN
	column.offset_right = -UiStyle.MARGIN
	column.offset_bottom = UiStyle.MARGIN + 80.0
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_enemy_count = UiStyle.make_hud_label(Locale.t("hud.enemies") % 0)
	_enemy_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_enemy_count)

	_objective = UiStyle.make_label(
		Locale.t("hud.objective_survive").to_upper(), UiStyle.body_font(), UiStyle.SIZE_LABEL,
		UiStyle.CREAM_DIM, UiStyle.TRACKING_LABEL, 2, true
	)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_objective)


## Le releve de build, en bas a gauche.
##
## C'est la seule concession au "mur de texte" de l'ancienne UI, et elle est
## assumee : dans un survivor, savoir ce que ses upgrades ont donne fait partie
## du jeu. Mais il est en creme ASSOURDI et au plus petit corps de l'ecran — il
## se lit quand on le cherche, pas quand on joue.
func _build_telemetry() -> void:
	_telemetry = UiStyle.make_label(
		"", UiStyle.body_font(), UiStyle.SIZE_TELEMETRY,
		UiStyle.CREAM_DIM, 1, 2, false
	)
	_telemetry.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_telemetry.offset_left = UiStyle.MARGIN
	_telemetry.offset_top = -UiStyle.MARGIN - 18.0
	_telemetry.offset_right = 700.0
	_telemetry.offset_bottom = -UiStyle.MARGIN
	add_child(_telemetry)


# ─────────────────────────────────────────────────────────────────────────────
# Mise a jour — appelee par main.gd
# ─────────────────────────────────────────────────────────────────────────────


## Le temps en minutes:secondes, pas en secondes decimales.
##
## "1:24" se lit d'un coup d'oeil ; "84.3 s" demande une conversion mentale, et
## on ne convertit pas pendant qu'on esquive. §9.3 regle 5, dans son esprit :
## une forme lisible plutot qu'un nombre exact.
func set_time(elapsed: float) -> void:
	_time_value.text = "%d:%02d" % [int(elapsed) / 60, int(elapsed) % 60]


## La vie, en POINTS depuis le 2026-08-16 — 100 au depart, et non plus 6.
##
## Le passage aux points n'est pas cosmetique : il ouvre les objets qui rendent
## ou volent de la vie par petites quantites (lifesteal), impossibles a doser
## sur une echelle de 6 ou chaque point valait 17 % de la barre.
func set_health(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	var inner := UiStyle.HEALTH_BAR - Vector2(2.0, 2.0)
	_health_fill.size = Vector2(inner.x * ratio, inner.y)

	# La bascule de couleur remplace le comptage de pastilles : sur 6 points on
	# voyait "il m'en reste 2" ; sur 100, un ratio ne se lit pas au chiffre pres
	# et il faut que la barre elle-meme dise quand s'inquieter.
	_health_fill.color = UiStyle.HIT_ROSE if ratio <= UiStyle.HEALTH_LOW else UiStyle.TERRACOTTA
	_health_value.text = str(current)


func set_xp(current: int, required: int, level: int) -> void:
	var ratio := 0.0 if required <= 0 else clampf(float(current) / float(required), 0.0, 1.0)
	var inner := UiStyle.XP_BAR - Vector2(2.0, 2.0)
	_xp_fill.size = Vector2(inner.x * ratio, inner.y)
	_level_value.text = Locale.t("hud.level") % level


func set_objective(text: String, enemies: int) -> void:
	_objective.text = text.to_upper()
	_enemy_count.text = Locale.t("hud.enemies") % enemies


func set_telemetry(text: String) -> void:
	_telemetry.text = text


# ─────────────────────────────────────────────────────────────────────────────
# Cartons de moment
# ─────────────────────────────────────────────────────────────────────────────


## Le squelette commun aux deux cartons : voile, lignes de vitesse, plaque.
##
## Le VOILE compte autant que la plaque. Sans lui le carton flotte au-dessus
## d'une arene toujours lisible et ne prend jamais vraiment l'ecran — or un
## level-up MET LE JEU EN PAUSE, et l'image doit le dire.
func _build_card(card_size: Vector2) -> Dictionary:
	var card := Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.visible = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)

	var veil := ColorRect.new()
	veil.color = Color(UiStyle.INK, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(veil)

	var lines := UiStyle.make_speedlines(Color(UiStyle.AMBER, 0.30))
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(lines)

	# ⚠️ `card_size`, PAS `size` : dans une methode de Control, `size` est la
	# taille du noeud lui-meme — ici le HUD plein cadre. Le carton s'etalait sur
	# tout l'ecran, chanfreins compris, et le seul indice etait un avertissement
	# de shadowing que rien n'obligeait a lire.
	var plate := UiStyle.make_plate()
	plate.set_anchors_preset(Control.PRESET_CENTER)
	plate.custom_minimum_size = card_size
	plate.size = card_size
	plate.offset_left = -card_size.x * 0.5
	plate.offset_top = -card_size.y * 0.5
	plate.offset_right = card_size.x * 0.5
	plate.offset_bottom = card_size.y * 0.5
	card.add_child(plate)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(UiStyle.PAD))
	plate.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)

	return {"card": card, "plate": plate, "lines": lines, "column": column, "content": margin}


func _build_level_card() -> void:
	var parts := _build_card(CARD_SIZE)
	_level_card = parts["card"]
	_level_card.set_meta("plate", parts["plate"])
	_level_card.set_meta("lines", parts["lines"])
	_level_card.set_meta("content", parts["content"])

	var column: VBoxContainer = parts["column"]

	var kana := UiStyle.make_kana_label("level_up")
	kana.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kana)

	_level_title = UiStyle.make_label(
		Locale.t("hud.level") % 2, UiStyle.display_font(), UiStyle.SIZE_CARD_TITLE,
		UiStyle.CREAM, UiStyle.TRACKING_TITLE, 4, true
	)
	_level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_level_title)

	_level_sub = UiStyle.make_label(
		Locale.t("card.level_sub"), UiStyle.body_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.CREAM_DIM, 1, 2, false
	)
	_level_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_level_sub)

	# Les trois choix COTE A COTE, et non empiles. Trois boutons empiles avec
	# titre et description dans le meme texte sont une liste ; trois cartes
	# alignees sont un choix, et le joueur les compare d'un balayage.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	for index in range(3):
		row.add_child(_make_choice_slot(index))


## Une carte de choix : plaque, titre, description, et un bouton TRANSPARENT
## par-dessus.
##
## Le bouton est invisible parce qu'un Button de Godot ne sait pas porter cette
## plaque : son `material` teinterait aussi son texte. On separe donc le dessin
## (ColorRect + Labels) de l'interaction (Button a plat) — c'est plus simple que
## de se battre avec un theme, et ca garde le chanfrein.
func _make_choice_slot(index: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = CHOICE_SIZE

	var plate := UiStyle.make_plate(
		Color(UiStyle.CREAM, 0.08), UiStyle.CREAM_DIM, UiStyle.CHAMFER_SMALL * 2.0, 1.0
	)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plate)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	slot.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title := UiStyle.make_label(
		"", UiStyle.bold_font(), UiStyle.SIZE_CHOICE_TITLE,
		UiStyle.CREAM, UiStyle.TRACKING_LABEL, 0, false
	)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var desc := UiStyle.make_label(
		"", UiStyle.body_font(), UiStyle.SIZE_CHOICE_DESC,
		UiStyle.CREAM_DIM, 0, 0, false
	)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(desc)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_NONE
	slot.add_child(button)

	button.pressed.connect(func() -> void: choice_selected.emit(index))
	button.mouse_entered.connect(_set_slot_hover.bind(plate, true))
	button.mouse_exited.connect(_set_slot_hover.bind(plate, false))

	_choice_slots.append({"slot": slot, "plate": plate, "title": title, "desc": desc})
	return slot


## Le survol change la PLAQUE, pas le texte. Un texte qui change de couleur au
## survol clignote ; une plaque qui s'allume designe.
func _set_slot_hover(plate: ColorRect, hovered: bool) -> void:
	var mat: ShaderMaterial = plate.material
	mat.set_shader_parameter(
		"plate_color", Color(UiStyle.AMBER, 0.26) if hovered else Color(UiStyle.CREAM, 0.08)
	)
	mat.set_shader_parameter("ink_color", UiStyle.AMBER if hovered else UiStyle.CREAM_DIM)


func _build_game_over_card() -> void:
	var parts := _build_card(GAME_OVER_SIZE)
	_game_over_card = parts["card"]
	_game_over_card.set_meta("plate", parts["plate"])
	_game_over_card.set_meta("lines", parts["lines"])
	_game_over_card.set_meta("content", parts["content"])

	var column: VBoxContainer = parts["column"]

	var kana := UiStyle.make_kana_label("game_over")
	kana.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kana)

	var title := UiStyle.make_label(
		"K.O.", UiStyle.display_font(), UiStyle.SIZE_CARD_TITLE + 8,
		UiStyle.TERRACOTTA, UiStyle.TRACKING_TITLE, 4, true
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_game_over_summary = UiStyle.make_label(
		"", UiStyle.body_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.CREAM_DIM, 1, 2, false
	)
	_game_over_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_game_over_summary)

	# "つづku" — a suivre. La formule de fin d'episode, qui dit exactement ce que
	# fait le bouton : ca continue.
	_restart_button = _make_wide_button(Locale.t("card.restart"))
	column.add_child(_restart_button)
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())


# ─────────────────────────────────────────────────────────────────────────────
# Le carton de reglages
# ─────────────────────────────────────────────────────────────────────────────


## Les reglages sont un CARTON, pas un ecran a part.
##
## Ils passent donc par le meme squelette que le niveau et le K.O. — voile,
## lignes de vitesse, plaque chanfreinee, ouverture en pas. Une fenetre de
## preferences dessinee dans un autre registre serait le seul endroit du jeu a
## ressembler a un logiciel, et §9 dit exactement l'inverse.
##
## Un seul reglage aujourd'hui, la langue. La colonne est prete a en recevoir
## d'autres — c'est la raison d'etre du libelle a gauche et des pastilles a
## droite plutot que d'un simple bouton.
func _build_settings_card() -> void:
	var parts := _build_card(SETTINGS_SIZE)
	_settings_card = parts["card"]
	_settings_card.set_meta("plate", parts["plate"])
	_settings_card.set_meta("lines", parts["lines"])
	_settings_card.set_meta("content", parts["content"])

	var column: VBoxContainer = parts["column"]

	var kana := UiStyle.make_kana_label("settings")
	kana.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kana)

	_settings_title = UiStyle.make_label(
		Locale.t("settings.title"), UiStyle.display_font(), UiStyle.SIZE_CARD_TITLE - 6,
		UiStyle.CREAM, UiStyle.TRACKING_TITLE, 4, true
	)
	_settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_settings_title)

	_settings_hint = UiStyle.make_label(
		Locale.t("settings.hint"), UiStyle.body_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.CREAM_DIM, 1, 2, false
	)
	_settings_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_settings_hint)

	column.add_child(_build_language_row())

	_settings_close = _make_wide_button(Locale.t("settings.close"))
	column.add_child(_settings_close)
	_settings_close.pressed.connect(close_settings_card)


## La ligne de reglage : son nom a gauche, ses valeurs a droite.
##
## Les langues sont des PASTILLES cote a cote, et non une liste deroulante ni une
## fleche a cliquer. Avec deux ou trois langues, tout voir d'un coup coute moins
## cher a lire qu'un menu qui cache ses options — et un OptionButton de Godot
## arriverait avec son propre theme, donc son propre registre visuel.
func _build_language_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	_settings_language_label = UiStyle.make_label(
		Locale.t("settings.language"), UiStyle.bold_font(), UiStyle.SIZE_CHOICE_TITLE,
		UiStyle.CREAM, UiStyle.TRACKING_LABEL, 0, false
	)
	_settings_language_label.custom_minimum_size = Vector2(120.0, 0.0)
	_settings_language_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_settings_language_label)

	for code in Locale.LANGUAGES:
		row.add_child(_make_language_slot(code))

	return row


## Une pastille de langue. Meme dispositif que les cartes de choix d'upgrade :
## le dessin est une plaque + un Label, l'interaction un Button transparent
## par-dessus — un Button de Godot ne sait pas porter cette plaque sans teinter
## aussi son texte.
func _make_language_slot(code: String) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = LANGUAGE_SIZE

	var plate := UiStyle.make_plate(
		Color(UiStyle.CREAM, 0.08), UiStyle.CREAM_DIM, UiStyle.CHAMFER_SMALL * 2.0, 1.0
	)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plate)

	# Le nom de la langue N'EST PAS traduit — voir Locale.NATIVE_NAMES.
	var label := UiStyle.make_label(
		Locale.native_name(code), UiStyle.bold_font(), UiStyle.SIZE_BUTTON,
		UiStyle.CREAM, UiStyle.TRACKING_LABEL, 0, false
	)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_NONE
	slot.add_child(button)

	button.pressed.connect(func() -> void: language_selected.emit(code))

	_language_slots.append({"code": code, "plate": plate, "label": label})
	return slot


## Marque la langue active. La pastille choisie s'allume en ambre — le meme
## signal visuel que le survol d'une carte d'upgrade, pour la meme raison : c'est
## la PLAQUE qui designe, jamais la couleur du texte.
##
## ⚠️ Sans etat visible, deux pastilles identiques ne disent pas laquelle est en
## service, et le seul indice serait la langue du reste du carton — illisible
## precisement pour qui vient de se tromper de langue.
func _sync_language_slots() -> void:
	for entry in _language_slots:
		var active: bool = entry["code"] == Locale.language()
		var mat: ShaderMaterial = entry["plate"].material
		mat.set_shader_parameter(
			"plate_color", Color(UiStyle.AMBER, 0.26) if active else Color(UiStyle.CREAM, 0.08)
		)
		mat.set_shader_parameter("ink_color", UiStyle.AMBER if active else UiStyle.CREAM_DIM)


func show_settings_card() -> void:
	_sync_language_slots()
	_open_card(_settings_card)


func close_settings_card() -> void:
	_settings_card.visible = false


func is_settings_card_open() -> bool:
	return _settings_card.visible


# ─────────────────────────────────────────────────────────────────────────────
# Changement de langue
# ─────────────────────────────────────────────────────────────────────────────


## Reecrit tout ce que le HUD tient lui-meme. Ce qui depend d'une valeur de jeu
## — vie, temps, objectif, niveau, telemetrie — n'est PAS ici : main.gd repousse
## ces valeurs juste apres, et c'est lui qui les possede.
##
## ⚠️ Le carton de niveau ne se rafraichit pas : on ne peut pas ouvrir les
## reglages pendant qu'il est affiche (voir main.gd), donc il n'y a pas de texte
## a changer sous les yeux du joueur.
func apply_language() -> void:
	_settings_title.text = Locale.t("settings.title")
	_settings_hint.text = Locale.t("settings.hint")
	_settings_language_label.text = Locale.t("settings.language")
	_settings_close.text = Locale.t("settings.close")
	_level_sub.text = Locale.t("card.level_sub")
	_restart_button.text = Locale.t("card.restart")
	_sync_language_slots()


func _make_wide_button(text: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	button.add_theme_font_override("font", UiStyle.bold_font())
	button.add_theme_font_size_override("font_size", UiStyle.SIZE_BUTTON)
	button.add_theme_color_override("font_color", UiStyle.CREAM)
	button.add_theme_color_override("font_hover_color", UiStyle.AMBER)
	button.add_theme_color_override("font_pressed_color", UiStyle.AMBER)
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_outline_color", UiStyle.INK)
	return button


# ─────────────────────────────────────────────────────────────────────────────
# Ouverture des cartons — en pas
# ─────────────────────────────────────────────────────────────────────────────


## Les choix arrivent en `id` seulement — le pool ne porte plus de texte depuis
## le passage au bilingue. C'est ici que l'id devient des mots, une fois, dans la
## langue du moment.
func show_level_card(level: int, choices: Array) -> void:
	_level_title.text = Locale.t("hud.level") % level
	_level_sub.text = Locale.t("card.level_sub")

	for index in range(_choice_slots.size()):
		var entry: Dictionary = _choice_slots[index]
		var slot: Control = entry["slot"]

		if index < choices.size():
			var id := String(choices[index]["id"])
			slot.visible = true
			entry["title"].text = Locale.upgrade_title(id).to_upper()
			entry["desc"].text = Locale.upgrade_description(id)
			_set_slot_hover(entry["plate"], false)
		else:
			slot.visible = false

	_open_card(_level_card)


func show_game_over(elapsed: float, level: int) -> void:
	_game_over_summary.text = Locale.t("card.game_over_summary") % [
		int(elapsed) / 60, int(elapsed) % 60, level
	]
	_open_card(_game_over_card)


func hide_level_card() -> void:
	_level_card.visible = false


## L'ouverture en pas. Chaque pose TIENT une duree, elle ne s'interpole pas —
## c'est la meme mecanique que les FX (fx_cadence.FX_POSE), et elle vit dans le
## meme fichier pour la meme raison : deux cadences qui divergent d'une frame et
## le cellulo se perd sans que rien ne casse.
func _open_card(card: Control) -> void:
	card.visible = true
	var plate: ColorRect = card.get_meta("plate")
	var lines: ColorRect = card.get_meta("lines")
	var content: Control = card.get_meta("content")

	# ⚠️ Le contenu se cache PENDANT le volet, et reapparait a la derniere pose.
	#
	# Le volet est dans le shader de la plaque ; les labels sont des ENFANTS de
	# cette plaque, donc il ne les coupe pas. Sans ce masquage, le titre et les
	# trois choix s'affichent entiers des la premiere pose pendant que la plaque
	# s'ouvre encore derriere eux — le texte flotte une fraction de seconde dans
	# le vide. C'est exactement l'inverse de ce que fait un carton d'anime, ou
	# le carton arrive d'abord et le lettrage tombe dessus.
	content.visible = false

	for pose in CARD_POSES:
		plate.material.set_shader_parameter("reveal", pose)
		lines.material.set_shader_parameter("reveal", pose)
		content.visible = is_equal_approx(pose, 1.0)

		# Le carton s'ouvre pendant que le jeu est en pause. Le CanvasLayer
		# garantit qu'on continue de dessiner ; le timer, lui, suivrait
		# l'echelle de temps — d'ou `ignore_time_scale`.
		await get_tree().create_timer(
			FxCadence.FX_POSE, true, false, true
		).timeout

		if not card.visible:
			return

	# Filet de securite : si le carton a ete rouvert pendant l'attente, la
	# boucle precedente a pu rendre la main avec le contenu masque.
	content.visible = true
