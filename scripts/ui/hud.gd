class_name Hud
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
## "Visual Art Direction" §9.2-9.3. Deux registres, et c'est leur CONTRASTE qui
## fait l'evenement, pas la taille des cartons :
##
##   • LE HUD PERMANENT EST NU. Aucune plaque, aucun cadre, aucune equerre. Du
##     texte creme cerne d'encre, pose directement sur le jeu, minuscule et
##     tasse dans un coin. Il se detache par son cerne — la logique exacte du
##     contour du chat sur le parquet.
##   • LES CARTONS ONT UN CONTENANT. Plaque de gris OPAQUE, filet fin, angles
##     droits et reperes d'angle, lignes de vitesse, entree EN PAS. Ils prennent
##     l'ecran parce qu'ils sont les seuls a en avoir le droit.
##
## ⚠️ Le jour ou une plaque apparait derriere le HUD, le registre bascule
## d'"anime" a "logiciel" et rien dans le code ne le signalera.
##
## ─── v3, 2026-08-17 : ce que ce fichier a change et pourquoi ───
##
## La reference d'interface passe d'Orbitals a Cowboy Bebop + Evangelion pour
## la couleur, la matiere et la composition (§9 v3). Le partage ci-dessus est
## intact — Orbitals avait raison sur la PLACE. Trois choses seulement bougent,
## et chacune porte son commentaire a l'endroit ou elle se lit :
##
##   1. PLUS RIEN N'EST TRANSLUCIDE (voile de fond excepte). Les cartes de choix
##      etaient a 8 % : le joueur choisissait entre trois fantomes.
##   2. LES PLAQUES SONT EN GRIS NEUTRE, hors de la palette chaude du monde.
##      Une UI n'appartient pas a l'appartement du chat.
##   3. LE SURVOL SE DIT EN AMBRE, plus par l'opacite — consequence directe du
##      point 1, le signal etait la transparence elle-meme.
##
## Et une regle de composition qui traverse les trois cartons : LES TITRES SONT
## CALES A GAUCHE. Rien n'est centre sauf le carton lui-meme (§9.1 regle 5).

const UiStyle := preload("res://scripts/systems/ui_style.gd")
const FxCadence := preload("res://scripts/systems/fx_cadence.gd")
const Locale := preload("res://scripts/systems/locale.gd")
const SkillDefinitions := preload("res://scripts/systems/skill_definitions.gd")
const SkillThumb := preload("res://scripts/systems/skill_thumb.gd")

## Le carton s'ouvre en 3 poses. §9.3 regle 4 : en pas, jamais en fondu — un
## panneau qui glisse en `tween` serait le seul element de l'image a ne pas etre
## en cellulo, et ca se voit immediatement.
const CARD_POSES: Array[float] = [0.0, 0.34, 0.72, 1.0]

## ⚠️ +92 px de haut le 2026-08-17 (300 → 392), et c'est la VIGNETTE qui l'a
## demande, pas le confort. La largeur, elle, ne bouge pas : 3 x 168 + 2 x 12 =
## 528, exactement l'interieur du carton.
##
## ⚠️ LA PREMIERE VALEUR ESSAYEE (352) DEBORDAIT, et le debordement etait MUET :
## un VBoxContainer a court de place ecrase ses enfants SOUS leur
## `custom_minimum_size` au lieu de se plaindre. La fenetre de vignette, declaree
## carree, est sortie en 86 x 65 — et rien, ni erreur ni avertissement, ne disait
## que la carte etait trop petite. C'est exactement le piege de la piste d'XP
## (`custom_minimum_size` est un minimum, il ne garantit rien), vu par l'autre
## bout. Toute retouche de `CHOICE_SIZE` se REVERIFIE en capture.
##
## ⚠️ +32 x +16 le 2026-08-20, ET PAS UN PIXEL DE PLUS QUE CE QUE L'EPAISSEUR
## PREND. Les cartes ont gagne 8 px de cote et d'ombre chacune (§9.9 amplifie),
## le carton 7 : sa boite interieure est donc EXACTEMENT celle d'avant, et rien
## de ce qui est mesure au-dessus n'a a etre remesure. Interieur en largeur :
## 592 - 2 x 16 - 7 = 553, pour 3 x 176 + 2 x 12 = 552.
const CARD_SIZE := Vector2(592.0, 408.0)
const GAME_OVER_SIZE := Vector2(448.0, 268.0)
const SETTINGS_SIZE := Vector2(468.0, 266.0)
## +20 px le 2026-08-17 pour le marqueur de palier, puis +86 le meme jour pour le
## bandeau de type et la vignette. Compte tenu : bandeau 18 + marge 10 + fenetre
## 84 + trois blocs de texte et leurs separations.
##
## ⚠️ +8 px dans les deux axes le 2026-08-20 : `UiStyle.relief_inset()` pour une
## plaque RAISED est passe de 3 a 11 px, et une plaque ne peut pas peindre son
## epaisseur hors de son rectangle. La carte grandit donc de ce que sa tranche et
## son ombre lui prennent — sa boite de contenu, elle, ne bouge pas d'un pixel.
## C'est la seule facon de toucher au relief SANS retomber sur l'ecrasement muet
## du VBoxContainer que l'avertissement ci-dessus decrit.
const CHOICE_SIZE := Vector2(176.0, 262.0)
const LANGUAGE_SIZE := Vector2(158.0, 52.0)

## Une carte du carton "quoi remplacer ?" — la meme carte de competence, SANS sa
## description.
##
## ⚠️ CE N'EST PAS UNE ECONOMIE DE PLACE, c'est la seule chose que le joueur n'a
## pas besoin de relire : il PORTE deja cette competence, il sait ce qu'elle
## fait. Ce qu'il ne sait pas d'un coup d'oeil, c'est a quel palier il l'a
## montee — et c'est justement ce qui decide du prix de l'abandon. Le marqueur
## de palier reste donc, la description part.
const SACRIFICE_SIZE := Vector2(176.0, 218.0)

## Ce que le carton de remplacement mesure SANS sa grille : marges, titre,
## legende, separations et bouton de retour. La plaque entiere se calcule au
## moment de l'ouverture, EN LARGEUR COMME EN HAUTEUR — le nombre de cartes a
## abandonner va de deux (les actifs) a six (les auto).
##
## ⚠️ LA LARGEUR SE CALCULE, ET C'EST §9.1 REGLE 5 QUI L'IMPOSE : « rien n'est
## centre sauf le carton lui-meme ». Une plaque figee a 560 px avec deux cartes
## dedans laisse deux marges symetriques de 90 px, et la grille se LIT comme
## centree — le seul endroit de l'interface a l'etre. Taillee sur sa grille, la
## plaque se referme dessus et la question ne se pose plus. C'est le meme geste
## que le carton de niveau, dont les trois cartes remplissent l'interieur au
## pixel pres (3 x 168 + 2 x 12 = 528).
##
## `x` est donc un PLANCHER de largeur et non la largeur, et sa valeur est
## MESUREE : « REMPLACER » en Dela Gothic 44 px fait 356 px, et deux colonnes
## n'en offrent que 348 d'interieur — le titre mangeait sa marge de droite. 404
## lui rend ses 16 px des deux cotes, au prix de 12 px de jeu autour de la
## grille, invisibles.
##
## 🅿️ Mesure a connaitre : a six candidates (deux rangees de 3) le carton fait
## 636 px de haut pour un viewport de 648 — 612 avant l'amplification du relief
## du 2026-08-20, qui a coute 8 px par rangee de cartes et 8 au carton. Ca tient
## encore, mais la marge est passee de 36 px a 12. La famille AUTO ne peut pas
## saturer aujourd'hui — quatre competences pour six slots — mais le jour ou elle
## le fera, c'est ce chiffre qu'il faudra reverifier en capture, pas en le
## relisant ici.
##
## ⚠️ +8 px comme tout le reste, dont 7 pour l'epaisseur du carton : sans eux le
## titre de 44 px reprendrait la marge de droite qu'on vient de lui rendre.
const REPLACE_CHROME := Vector2(412.0, 188.0)
## Le nombre de cartes par rangee. Trois, comme le carton de niveau.
const REPLACE_COLUMNS := 3

## Une pastille de cooldown d'ACTIF. Carree — §9.3 regle 6, angles droits sans
## exception — et minuscule, comme tout le HUD permanent (§9.1).
const CHARGE_PIP := Vector2(20.0, 20.0)

## Le nombre de crans de remplissage. §2.4 demande "4-5 poses, jamais une barre
## lisse" : cinq crans, et le passage de l'un a l'autre est franc.
const CHARGE_STEPS := 5

signal choice_selected(index: int)
signal restart_pressed
## Le joueur a choisi une langue. Le HUD ne l'applique PAS lui-meme : il ne sait
## rien des valeurs de jeu (vie, temps, objectif) qu'il faudrait reafficher. Il
## previent main.gd, qui possede l'etat et repousse tout — le meme partage que
## partout ailleurs ici, le HUD dessine, main decide.
signal language_selected(code: String)
## Le joueur demande a fermer les reglages. Le HUD ne se ferme PAS lui-meme, et
## ce n'est pas une precaution de style : fermer la plaque sans prevenir main.gd
## laisse `get_tree().paused` a true avec plus aucun carton a l'ecran, et le jeu
## est bloque pour de bon — Échap ne peut plus rien, puisqu'il n'y a plus rien
## d'ouvert a fermer. C'est arrive, exactement comme ca.
signal settings_close_requested
## Le joueur a designe la competence qui cede sa place. Le HUD ne touche a rien :
## il dit QUI part, main.gd fait l'echange et relance la run.
signal replace_selected(id: String)
## Le joueur renonce a l'echange et veut revoir ses trois cartes.
signal replace_cancelled

var _time_value: Label
var _health_fill: ColorRect
var _health_value: Label
var _xp_fill: ColorRect
var _level_value: Label
var _objective: Label
var _enemy_count: Label
var _telemetry: Label

## Une entree par slot d'ACTIF : {track, fill}. Masquees tant que le chat n'a
## pas la competence correspondante.
var _charge_slots: Array[Dictionary] = []

var _level_card: Control
var _level_title: Label
var _level_sub: Label
var _choice_slots: Array[Dictionary] = []

var _replace_card: Control
var _replace_plate: ColorRect
var _replace_title: Label
var _replace_sub: Label
var _replace_grid: GridContainer
var _replace_back: Button
var _replace_slots: Array[Dictionary] = []

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
	_build_charge_block()
	_build_telemetry()
	_build_level_card()
	_build_replace_card()
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
	# ⚠️ BEGIN, PAS CENTER. La colonne donne a toutes ses rangees la largeur de
	# la plus large ; "LEVEL 1" etant plus long que "85", la rangee de vie etait
	# plus etroite que celle d'XP — et centree, elle se retrouvait INDENTEE de
	# 20 px par rapport a elle. Le defaut existait depuis toujours ; il n'est
	# devenu visible qu'une fois les pistes opaques, personne ne pouvant aligner
	# a l'oeil deux barres a 22 % d'encre. §9.1 regle 5 : cale a gauche.
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# La piste est OPAQUE depuis le 2026-08-17 (§9.3 regle 3). Elle etait a 22 %
	# d'encre : sur le parquet clair elle disparaissait presque, sur un tapis
	# sombre elle devenait invisible — donc la jauge vide ne disait plus rien, et
	# une jauge dont on ne voit pas le VIDE ne dit pas non plus le plein.
	#
	# Son filet reste l'ENCRE, et non le gris des cartons : la piste flotte sur
	# le jeu, elle appartient au registre nu du HUD — qui se detache par son
	# cerne, comme le chat se detache du parquet.
	var track := UiStyle.make_plate(
		UiStyle.PLATE_LOW, UiStyle.INK, UiStyle.NO_TICK, 1.0
	)
	track.custom_minimum_size = gauge_size
	# ⚠️ SANS CECI LA PISTE EST UNE DALLE. Un HBoxContainer etire ses enfants a
	# la hauteur de la RANGEE, et la rangee fait la hauteur du label a cote.
	# La hauteur de `gauge_size` n'est qu'un minimum : elle ne plafonne rien.
	# Constate a l'image, invisible en lisant le code.
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)

	# Le remplissage est un ColorRect NU, enfant de la piste : a 8 px de haut une
	# seconde plaque couterait un materiau pour rien. Le filet de la piste fait
	# deja tout le travail de forme.
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


## Les pastilles de cooldown des ACTIFS, en bas a droite — §2.4.
##
## Une pastille par slot active, et AUCUNE tant que le chat n'a pas de
## competence active : une pastille eteinte annoncerait une touche qui ne fait
## rien, ce qui est le meme mensonge a l'ecran que `projectile_speed` du temps ou
## il reglait un projectile debranche (il est revenu le 2026-08-19, et cette
## fois il agit — voir `skill_definitions.gd`).
##
## En BAS A DROITE, et c'est le seul coin qui restait : le haut gauche porte la
## survie, le haut droit la vague, le bas gauche le releve de build. C'est aussi
## le coin le plus proche de la main qui clique.
##
## ⚠️ ELLES SE REMPLISSENT EN PAS, jamais en continu (§2.4). Un remplissage lisse
## serait le SEUL element lisse de l'image — exactement l'erreur du grain qui
## battait en bloc, et le contraire de tout ce que §7 demande. La charge est donc
## quantifiee en 5 crans, et le passage d'un cran au suivant est franc.
func _build_charge_block() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.offset_left = -180.0
	row.offset_top = -(CHARGE_PIP.y + UiStyle.MARGIN)
	row.offset_right = -UiStyle.MARGIN
	row.offset_bottom = -UiStyle.MARGIN
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	for _index in range(SkillDefinitions.MAX_ACTIVE_SLOTS):
		# Meme dessin que les jauges de vie et d'XP : piste opaque, filet
		# d'ENCRE, angles droits, pas de repere d'angle. Elles flottent sur le
		# jeu, elles appartiennent donc au registre nu du HUD — celui qui se
		# detache par son cerne (§9.6).
		var track := UiStyle.make_plate(
			UiStyle.PLATE_LOW, UiStyle.INK, UiStyle.NO_TICK, 1.0
		)
		track.custom_minimum_size = CHARGE_PIP
		# Sans ca, le HBoxContainer etire la pastille a la hauteur de la rangee —
		# le piege deja paye sur la piste d'XP, invisible en lisant le code.
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		track.visible = false
		row.add_child(track)

		var fill := ColorRect.new()
		fill.color = UiStyle.AMBER
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)

		_charge_slots.append({"track": track, "fill": fill})


## La charge de chaque slot active, de 0 a 1. Une liste vide efface les pastilles.
##
## ⚠️ C'est le HUD qui QUANTIFIE, pas l'appelant. `main` pousse une valeur
## continue a chaque frame ; le decoupage en crans est une decision de DESSIN
## (§7), et la laisser au jeu, c'est la voir un jour diverger d'un element a
## l'autre — exactement ce que `fx_cadence.gd` existe pour empecher.
func set_charges(charges: Array) -> void:
	var inner: Vector2 = CHARGE_PIP - Vector2(2.0, 2.0)

	for index in range(_charge_slots.size()):
		var entry: Dictionary = _charge_slots[index]
		var track: ColorRect = entry["track"]

		if index >= charges.size():
			track.visible = false
			continue

		track.visible = true

		var charge := clampf(float(charges[index]), 0.0, 1.0)
		# Pleine charge : la pastille CLAQUE (§2.4). Le cran plein est teste a
		# part et non deduit de l'arrondi — sans ca, un cooldown a 99,5 % rendrait
		# le meme dessin qu'un cooldown pret, et le joueur cliquerait dans le vide.
		var charged := charge >= 0.999
		var stepped := 1.0 if charged else floorf(charge * float(CHARGE_STEPS)) / float(CHARGE_STEPS)

		var fill: ColorRect = entry["fill"]
		# Elle se remplit PAR LE BAS : une jauge qui monte se lit comme une
		# reserve qui se refait, une qui descend comme un compte a rebours. Ici
		# c'est bien une reserve.
		fill.size = Vector2(inner.x, inner.y * stepped)
		fill.position = Vector2(1.0, 1.0 + inner.y * (1.0 - stepped))

		# Le filet passe a l'ambre quand c'est pret — l'accent DESIGNE ce sur quoi
		# le joueur peut agir (§9.3 regle 4). Meme dispositif que le survol d'une
		# carte et que la pastille de langue active : trois facons differentes de
		# dire "c'est celui-la" obligeraient a apprendre l'interface trois fois.
		track.material.set_shader_parameter(
			"ink_color", UiStyle.AMBER if charged else UiStyle.INK
		)


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

	# Le voile est la SEULE translucidite de toute l'interface (§9.3 regle 3), et
	# c'est aussi la seule qui soit legitime : il n'y a pas d'autre facon de
	# montrer que le jeu est en pause DERRIERE le carton.
	#
	# ⚠️ Il ASSOMBRIT, il ne teinte plus. A 55 % d'encre brune il repeignait la
	# scene en sepia — le sol, le chat et les ennemis changeaient de couleur, ce
	# qui est exactement ce qu'un voile ne doit pas faire.
	var veil := ColorRect.new()
	veil.color = Color(UiStyle.VEIL, 0.80)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(veil)

	# Les lignes sont SOMBRES, et opaques.
	#
	# Elles etaient en ambre a 30 %. Deux raisons de changer de couleur, et la
	# seconde compte plus : §9.3 regle 3 interdit la translucidite, et §9.3
	# regle 4 reserve l'ambre a ce qui DESIGNE — l'option active, le survol,
	# l'alerte. Des lignes de vitesse ne designent rien, elles decorent :
	# depenser l'unique accent sature de l'ecran sur un fond, c'est ne plus
	# l'avoir pour le survol d'une carte, qui en a besoin.
	#
	# ⚠️ ET ELLES SONT PLUS SOMBRES QUE LE VOILE, PAS PLUS CLAIRES. Premier essai
	# en gris de filet (#8E8E88, 0,56) : opaques, elles ont AVALE L'IMAGE — la
	# scene voilee tombe a ~0,25, des traits a 0,56 par-dessus deviennent le
	# sujet du cadre et le carton passe au second plan. C'est le piege exact que
	# §9.3 regle 3 annonce : la tentation est alors de les rendre translucides,
	# et la vraie reponse est de les rendre plus SOMBRES. A 0,10 sur un fond a
	# 0,25 elles se lisent comme de l'encre — le registre du manga, d'ailleurs,
	# ou le trait de vitesse est noir.
	var lines := UiStyle.make_speedlines(UiStyle.VEIL)
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(lines)

	# ⚠️ `card_size`, PAS `size` : dans une methode de Control, `size` est la
	# taille du noeud lui-meme — ici le HUD plein cadre. Le carton s'etalait sur
	# tout l'ecran, reperes d'angle compris, et le seul indice etait un avertissement
	# de shadowing que rien n'obligeait a lire.
	# ⚠️ EN RELIEF, et pas seulement pour faire joli : les cartes qu'il contient
	# le sont depuis le 2026-08-17. Une plaque plate portant trois plaques en
	# volume met le contenant EN ARRIERE de son contenu, et le carton cesse d'etre
	# ce qui prend l'ecran (§9.3 regle 2).
	var plate := UiStyle.make_plate(
		UiStyle.PLATE, UiStyle.RULE, UiStyle.TICK, UiStyle.BORDER,
		UiStyle.RELIEF_CARTON
	)
	plate.set_anchors_preset(Control.PRESET_CENTER)
	_size_plate(plate, card_size)
	card.add_child(plate)

	# ⚠️ LES MARGES BASSE ET DROITE PAIENT L'EPAISSEUR DU CARTON. Une plaque en
	# relief peint sa tranche et son ombre DEDANS, pas autour — le contenu cale a
	# `PAD` mordait donc sur elles. C'etait deja vrai des 3 px d'ombre du
	# 2026-08-17, et personne ne l'avait vu ; a 7 px la grille de cartes serait
	# passee sous le cote du carton.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := int(UiStyle.relief_inset(UiStyle.RELIEF_CARTON))
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(UiStyle.PAD))
	margin.add_theme_constant_override("margin_right", int(UiStyle.PAD) + inset)
	margin.add_theme_constant_override("margin_bottom", int(UiStyle.PAD) + inset)
	plate.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)

	return {"card": card, "plate": plate, "lines": lines, "column": column, "content": margin}


## La taille d'une plaque centree. Elle vaut la peine d'exister parce que le
## carton de remplacement en CHANGE a chaque ouverture : deux actifs a
## abandonner ne demandent pas la meme plaque que six auto, et une plaque taillee
## pour le pire cas laisserait un trou beant sous le cas courant.
func _size_plate(plate: Control, card_size: Vector2) -> void:
	plate.custom_minimum_size = card_size
	plate.size = card_size
	plate.offset_left = -card_size.x * 0.5
	plate.offset_top = -card_size.y * 0.5
	plate.offset_right = card_size.x * 0.5
	plate.offset_bottom = card_size.y * 0.5


func _build_level_card() -> void:
	var parts := _build_card(CARD_SIZE)
	_level_card = parts["card"]
	_level_card.set_meta("plate", parts["plate"])
	_level_card.set_meta("lines", parts["lines"])
	_level_card.set_meta("content", parts["content"])

	var column: VBoxContainer = parts["column"]

	# ⚠️ CALE A GAUCHE, et sans cerne. Les deux viennent du meme endroit.
	#
	# L'alignement : §9.1 regle 5 — rien n'est centre sauf le carton lui-meme.
	# Un titre centre au-dessus d'une legende centree est une composition de
	# boite de dialogue ; le meme couple cale a gauche est un cartouche d'anime.
	#
	# Le cerne : il existe pour detacher un texte qui FLOTTE sur le jeu. Ici la
	# plaque est opaque, plus rien ne flotte — et une encre brune sur du gris
	# neutre serait une 4e valeur a l'ecran (§9.3 regle 4). L'ombre decalee, elle,
	# reste : ce n'est pas de la lisibilite, c'est la trace de tele d'epoque.
	_level_title = UiStyle.make_label(
		Locale.t("hud.level") % 2, UiStyle.display_font(), UiStyle.SIZE_CARD_TITLE,
		UiStyle.CREAM, UiStyle.TRACKING_TITLE, 0, true
	)
	_level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_level_title)

	_level_sub = UiStyle.make_label(
		Locale.t("card.level_sub"), UiStyle.body_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.CREAM_DIM, 1, 0, false
	)
	_level_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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


## Une carte de competence : plaque, onglet de type, fenetre, palier, titre.
##
## ⚠️ UNE SEULE FABRIQUE POUR LES DEUX CARTONS, et c'est le point de cette
## methode. Le carton de niveau propose des competences, celui de remplacement en
## reprend — mais c'est le MEME objet dans les deux cas, et le joueur doit le
## reconnaitre d'un balayage. Deux fabriques, ce sont deux jeux de marges, de
## tailles et de couleurs a tenir synchronises : exactement la divergence que ce
## projet passe son temps a reparer.
##
## Le bouton est invisible parce qu'un Button de Godot ne sait pas porter cette
## plaque : son `material` teinterait aussi son texte. On separe donc le dessin
## (ColorRect + Labels) de l'interaction (Button a plat) — c'est plus simple que
## de se battre avec un theme, et ca garde les reperes d'angle.
##
## ⚠️ LA PLAQUE ETAIT LE DEFAUT N°1 DE L'INTERFACE : `Color(CREAM, 0.08)`, soit
## 8 % d'opacite. Ce n'etait pas une carte, c'etait un voile pose sur un autre
## voile, et le joueur devait choisir entre trois fantomes.
func _make_skill_card(card_size: Vector2, with_desc: bool) -> Dictionary:
	var slot := Control.new()
	slot.custom_minimum_size = card_size

	# ⚠️ `relief` — la carte a du VOLUME depuis le 2026-08-17 (§9.9). Biseau,
	# facette 2 tons et ombre portee dure, tout a bord franc : c'est le cluster
	# 2 tons du chat (§2bis) applique a une plaque d'interface, et surtout pas un
	# degrade, que §9.1 regle 2 interdit.
	#
	# C'est la SEULE plaque du jeu qui doit dire "prends-moi". Les cartons, eux,
	# n'ont rien a offrir qu'on puisse saisir : ils portent le relief pour ne pas
	# etre plus plats que ce qu'ils contiennent, jamais pour appeler le clic.
	#
	# ⚠️ ELLE RESTE EN RELIEF MEME QUAND ON L'ABANDONNE, et c'est reflechi. Sur le
	# carton de remplacement, cliquer une carte c'est s'en defaire — mais le geste
	# reste "designer celle-la", et §9.9 ne connait qu'un seul dispositif pour ca.
	# Une carte en creux y aurait dit "je recois", soit l'inverse de ce qu'elle
	# fait ; et deux dessins pour un meme objet obligeraient a l'apprendre deux
	# fois. Ce qui dit qu'on abandonne, c'est le TITRE DU CARTON, pas la carte.
	var plate := UiStyle.make_plate(
		UiStyle.PLATE_RAISED, UiStyle.RULE, UiStyle.TICK, 1.0,
		UiStyle.RELIEF_RAISED
	)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plate)

	# Ce que la tranche et l'ombre prennent au contenu, a droite et en bas. Tout
	# ce qui se pose sur la carte s'y rentre — sinon le dessin passe sur le COTE
	# de l'objet, ce qui est le seul endroit de la plaque a ne pas etre son
	# dessus.
	var inset := UiStyle.relief_inset(UiStyle.RELIEF_RAISED)

	# ── L'onglet de type, en tete de carte ───────────────────────────────────
	#
	# AUTO / ACTIF / PASSIF ne se lisaient nulle part : trois cartes identiques,
	# et le joueur devait deduire le type de la description. Or le type decide de
	# tout — une slot occupee, une touche a presser, ou un chiffre qu'on ne verra
	# jamais (§2.1).
	#
	# ⚠️ IL EST EN TETE, PAS EN PIED. C'est la premiere chose que le balayage
	# rencontre, donc la premiere qui trie les cartes ; en legende sous le titre il
	# aurait ete une precision de plus, apres coup.
	#
	# ⚠️ IL NE VA PAS D'UN BORD A L'AUTRE, et ce n'est pas une preference : pleine
	# largeur, il RECOUVRE LES DEUX REPERES D'ANGLE DU HAUT. La carte se retrouve
	# alors avec deux L en bas et rien en haut, ce qui ne se lit plus comme un
	# cartouche mais comme un cadre inacheve. Constate en capture.
	#
	# Il est donc rentre de `TICK_INSET + TICK`, exactement de quoi les degager —
	# et il y gagne : un bandeau rentre est un ONGLET, donc un objet pose sur la
	# carte, ce qui va avec le relief qu'elle vient de prendre. Pleine largeur, il
	# n'etait qu'une bande de couleur.
	var band_inset := UiStyle.TICK_INSET + UiStyle.TICK
	var band := ColorRect.new()
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_left = band_inset
	band.offset_top = 1.0
	band.offset_right = -(band_inset + inset)
	band.offset_bottom = 1.0 + UiStyle.BAND_HEIGHT
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(band)

	var band_label := UiStyle.make_label(
		"", UiStyle.bold_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.KIND_LABEL, UiStyle.TRACKING_LABEL, 0, false
	)
	band_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	band_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(band_label)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_theme_constant_override("margin_top", int(UiStyle.BAND_HEIGHT) + 10)
	margin.add_theme_constant_override("margin_right", 10 + int(inset))
	margin.add_theme_constant_override("margin_bottom", 10 + int(inset))
	slot.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	# ⚠️ CENTRE VERTICALEMENT, et c'est la vignette qui l'impose. Un passif n'en
	# a pas : sa carte perd 76 px d'un coup, et calee en haut elle laisserait un
	# trou beant sous sa description. Centree, la carte se referme sur son
	# contenu quel qu'il soit.
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)

	# ── La vignette du FX ────────────────────────────────────────────────────
	#
	# Une pose du VRAI shader de la competence, rendue dans un SubViewport — voir
	# `skill_thumb.gd`, qui explique pourquoi elle n'est pas redessinee en UI.
	#
	# Sa fenetre est CREUSEE, pas posee : plaque `BACKING` sans relief, a l'exact
	# inverse de la carte qui la porte. C'est le meme partage que la piste d'une
	# jauge contre la carte — ce qui est en creux recoit, ce qui est en relief se
	# prend.
	#
	# ⚠️ Son filet est L'ENCRE, pas le gris de regle des cartons. Le gris etait
	# invisible sur un fond a 0,72, et surtout il n'a rien a faire la : ce cadre
	# ne borde pas de l'interface, il borde le MONDE. L'encre `#3D2B1A` est
	# exactement celle qui cerne le chat, les meubles et les six FX qu'on voit
	# dedans — la fenetre est cernee du meme trait que ce qu'elle montre.
	var window := UiStyle.make_plate(
		SkillThumb.BACKING, UiStyle.INK, UiStyle.NO_TICK, 2.0
	)
	window.custom_minimum_size = Vector2(SkillThumb.SIZE + 8, SkillThumb.SIZE + 8)
	window.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	window.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_child(window)

	var thumb := SkillThumb.make()
	thumb.set_anchors_preset(Control.PRESET_CENTER)
	thumb.offset_left = -SkillThumb.SIZE * 0.5
	thumb.offset_top = -SkillThumb.SIZE * 0.5
	thumb.offset_right = SkillThumb.SIZE * 0.5
	thumb.offset_bottom = SkillThumb.SIZE * 0.5
	window.add_child(thumb)

	# Le marqueur de palier — "NOUVEAU", "PALIER 2", "ULTIME".
	#
	# ⚠️ Il est INDISPENSABLE depuis que les competences ont des paliers : sans
	# lui, reprendre l'haleine puante affiche exactement la meme carte qu'a sa
	# premiere prise, et rien ne dit au joueur s'il debloque ou s'il renforce.
	# ⚠️ ET IL COMPTE ENCORE PLUS SUR LE CARTON DE REMPLACEMENT, ou il dit
	# l'inverse : ce qu'un abandon COUTE, c'est le palier qu'on avait monte.
	# Abandonner un T3 et abandonner un T1 sont deux decisions differentes, et
	# c'est la seule chose de la carte qui les separe.
	#
	# Au corps de LEGENDE (10 px) contre 17 px pour le titre : c'est le contraste
	# d'echelle de §9.3 regle 5, pas une nuance de gris de plus. Et il reste en
	# creme assourdi meme au survol — l'ambre est l'unique accent sature de
	# l'ecran, et son role est de designer la carte survolee, pas de decorer un
	# marqueur qui, lui, ne designe rien (§9.3 regle 4).
	var tier_label := UiStyle.make_label(
		"", UiStyle.body_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.CREAM_DIM, UiStyle.TRACKING_LABEL, 0, false
	)
	column.add_child(tier_label)

	var title := UiStyle.make_label(
		"", UiStyle.bold_font(), UiStyle.SIZE_CHOICE_TITLE,
		UiStyle.CREAM, UiStyle.TRACKING_LABEL, 0, false
	)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var entry := {
		"slot": slot, "plate": plate, "tier": tier_label, "title": title,
		"band": band, "band_label": band_label, "window": window, "thumb": thumb,
		"desc": null,
	}

	if with_desc:
		var desc := UiStyle.make_label(
			"", UiStyle.body_font(), UiStyle.SIZE_CHOICE_DESC,
			UiStyle.CREAM_DIM, 0, 0, false
		)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(desc)
		entry["desc"] = desc

	# ⚠️ LE BOUTON S'ARRETE A LA FACE. Etendu au rectangle entier, il rendrait
	# l'ombre portee cliquable — et surtout survolable : le filet passerait a
	# l'ambre alors que le curseur est sur le vide a cote de la carte. A 3 px
	# d'ombre ca ne se voyait pas ; a 11 px de tranche + ombre, si.
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.offset_right = -inset
	button.offset_bottom = -inset
	button.focus_mode = Control.FOCUS_NONE
	slot.add_child(button)

	entry["button"] = button
	button.mouse_entered.connect(_set_slot_hover.bind(entry, true))
	button.mouse_exited.connect(_set_slot_hover.bind(entry, false))

	return entry


## Ce qu'une carte AFFICHE, une fois, dans la langue du moment. Les competences
## arrivent en `id` et en palier — le catalogue ne porte plus de texte depuis le
## passage au bilingue, et plus de valeurs depuis le passage aux paliers.
##
## `marker` est passe par l'appelant et non deduit ici : le meme couple
## (id, palier) ne dit pas la meme chose selon le carton. Voir `_tier_marker`.
func _fill_skill_card(entry: Dictionary, id: String, tier: int, marker: String) -> void:
	entry["tier"].text = marker
	entry["title"].text = Locale.skill_title(id).to_upper()
	_set_slot_kind(entry, SkillDefinitions.kind_of(id))

	if entry["desc"] != null:
		entry["desc"].text = Locale.skill_description(id, tier)

	# La fenetre disparait quand la competence n'a rien a montrer, elle ne
	# reste pas vide. Un cadre noir sur une carte de passif se lirait comme
	# une image qui n'a pas fini de charger — et §2.10 vaut aussi ici : une
	# carte ne doit rien promettre qu'elle ne tienne.
	var window: Control = entry["window"]
	window.visible = SkillThumb.configure(entry["thumb"], id)

	_set_slot_hover(entry, false)


func _make_choice_slot(index: int) -> Control:
	var entry := _make_skill_card(CHOICE_SIZE, true)
	entry["button"].pressed.connect(func() -> void: choice_selected.emit(index))
	_choice_slots.append(entry)
	return entry["slot"]


## Le survol s'exprime en AMBRE — filet, reperes d'angle et titre ensemble.
##
## ⚠️ Il ne peut plus se dire par l'opacite, et c'est la consequence a laquelle
## le passage a l'opaque oblige. En v2, survoler une carte la faisait passer de
## 8 % a 26 % : le signal ETAIT la transparence. Tout etant desormais opaque, il
## fallait un autre signal, et §9.3 regle 4 le designe — l'ambre est le seul
## sature de l'ecran, et son role est precisement de DESIGNER.
##
## Le fond, lui, ne bouge pas. Une plaque qui change de valeur au survol fait
## sauter la carte hors de la rangee ; un filet qui s'allume la designe sans la
## deplacer. C'est le meme dispositif que la pastille de langue active (§9.7).
func _set_slot_hover(entry: Dictionary, hovered: bool) -> void:
	var mat: ShaderMaterial = entry["plate"].material
	mat.set_shader_parameter("ink_color", UiStyle.AMBER if hovered else UiStyle.RULE)
	entry["title"].add_theme_color_override(
		"font_color", UiStyle.AMBER if hovered else UiStyle.CREAM
	)


func _build_game_over_card() -> void:
	var parts := _build_card(GAME_OVER_SIZE)
	_game_over_card = parts["card"]
	_game_over_card.set_meta("plate", parts["plate"])
	_game_over_card.set_meta("lines", parts["lines"])
	_game_over_card.set_meta("content", parts["content"])

	var column: VBoxContainer = parts["column"]

	var title := UiStyle.make_label(
		"K.O.", UiStyle.display_font(), UiStyle.SIZE_CARD_TITLE + 8,
		UiStyle.TERRACOTTA, UiStyle.TRACKING_TITLE, 0, true
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(title)

	_game_over_summary = UiStyle.make_label(
		"", UiStyle.body_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.CREAM_DIM, 1, 0, false
	)
	_game_over_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_game_over_summary)

	_restart_button = _make_wide_button(Locale.t("card.restart"))
	column.add_child(_restart_button)
	_restart_button.pressed.connect(func() -> void: restart_pressed.emit())


# ─────────────────────────────────────────────────────────────────────────────
# Le carton « quoi remplacer ? » — chantier 2 de §2.9
# ─────────────────────────────────────────────────────────────────────────────


## Le carton qui s'ouvre quand une competence NEUVE arrive dans une famille de
## slots pleine (§2.3). Il montre les competences portees qui peuvent lui ceder
## leur place, et une seule autre issue : revenir au choix.
##
## ⛔ IL REMPLACE LE CARTON DE NIVEAU, IL NE S'EMPILE PAS DESSUS. La conception
## l'annoncait comme un carton « qui doit s'ouvrir PAR-DESSUS un carton de niveau
## qui attend deja une decision » — et c'est le point qui rendait ce chantier
## couteux. Il tombe : une fois la carte cliquee, le carton de niveau
## N'ATTEND PLUS RIEN. Sa decision est prise, il n'a plus qu'a s'effacer.
##
## Ce que ca evite est exactement ce que main.gd a deja paye : deux cartons
## empiles sur un voile a moitie transparent ne se lisent plus, et c'est la
## raison pour laquelle Échap ne fait rien pendant un carton de niveau. Un seul
## contenant a l'ecran, toujours — §9.3 regle 2.
##
## ⚠️ ET IL FAUT POUVOIR REVENIR. Sans le bouton de retour, decouvrir le prix de
## l'echange APRES avoir choisi serait un piege : le joueur clique une carte, on
## lui apprend qu'elle coute une de ses armes, et il n'a plus le droit de
## preferer les deux autres. Le retour rouvre le carton de niveau avec LES MEMES
## trois cartes — il ne rejoue pas le tirage, sinon le "retour" serait une
## seconde chance deguisee.
func _build_replace_card() -> void:
	# Bati pour deux cartes ; `show_replace_card` retaille la plaque a l'ouverture.
	var parts := _build_card(_replace_card_size(2))
	_replace_card = parts["card"]
	_replace_plate = parts["plate"]
	_replace_card.set_meta("plate", parts["plate"])
	_replace_card.set_meta("lines", parts["lines"])
	_replace_card.set_meta("content", parts["content"])

	var column: VBoxContainer = parts["column"]

	# Cale a gauche et sans cerne, comme les deux autres cartons : §9.1 regle 5,
	# rien n'est centre sauf le carton lui-meme.
	_replace_title = UiStyle.make_label(
		Locale.t("card.replace_title"), UiStyle.display_font(), UiStyle.SIZE_CARD_TITLE,
		UiStyle.CREAM, UiStyle.TRACKING_TITLE, 0, true
	)
	_replace_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_replace_title)

	# ⚠️ C'EST CETTE LEGENDE QUI PORTE LA MOITIE MANQUANTE DE L'ECHANGE. Le carton
	# de niveau vient de s'effacer : sans le nom de la competence qui arrive, le
	# joueur choisit ce qu'il abandonne sans plus voir ce qu'il gagne.
	_replace_sub = UiStyle.make_label(
		"", UiStyle.body_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.CREAM_DIM, 1, 0, false
	)
	_replace_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_replace_sub)

	# Une GRILLE et non une rangee : les actifs en presentent deux, les auto
	# jusqu'a six, et six cartes de 168 px cote a cote debordent l'ecran. Trois par
	# rangee est la largeur d'interieur deja payee par le carton de niveau.
	_replace_grid = GridContainer.new()
	_replace_grid.columns = REPLACE_COLUMNS
	_replace_grid.add_theme_constant_override("h_separation", 12)
	_replace_grid.add_theme_constant_override("v_separation", 12)
	_replace_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_replace_grid)

	# Autant de cartes que la plus grande famille a de slots : c'est le pire cas,
	# et les cartes se recyclent d'une ouverture a l'autre comme celles du niveau.
	for index in range(SkillDefinitions.MAX_AUTO_SLOTS):
		var entry := _make_skill_card(SACRIFICE_SIZE, false)
		# La carte porte l'id qu'elle affiche : la grille se reordonne d'une
		# ouverture a l'autre (les candidates dependent du build), donc un index
		# fige mentirait des la deuxieme fois.
		entry["id"] = ""
		entry["button"].pressed.connect(_on_sacrifice_pressed.bind(index))
		_replace_slots.append(entry)
		_replace_grid.add_child(entry["slot"])

	_replace_back = _make_wide_button(Locale.t("card.replace_back"))
	column.add_child(_replace_back)
	# Comme REPRENDRE et RELANCER : le bouton DEMANDE, main.gd decide. Un bouton
	# d'UI qui rouvrirait lui-meme le carton de niveau laisserait main.gd croire
	# que l'echange est en cours, et le prochain clic ferait n'importe quoi.
	_replace_back.pressed.connect(func() -> void: replace_cancelled.emit())


func _on_sacrifice_pressed(index: int) -> void:
	var id: String = _replace_slots[index]["id"]

	if id != "":
		replace_selected.emit(id)


## `candidates` arrive en {id, tier}, comme les choix du carton de niveau — le
## HUD ne sait pas ce que le chat porte, et il n'a pas a le savoir.
func show_replace_card(new_id: String, candidates: Array) -> void:
	_replace_title.text = Locale.t("card.replace_title")
	_replace_sub.text = Locale.t("card.replace_sub") % Locale.skill_title(new_id)
	_replace_back.text = Locale.t("card.replace_back")

	var count := mini(candidates.size(), _replace_slots.size())
	_replace_grid.columns = maxi(mini(count, REPLACE_COLUMNS), 1)

	for index in range(_replace_slots.size()):
		var entry: Dictionary = _replace_slots[index]
		var slot: Control = entry["slot"]

		if index >= count:
			# Vide l'id AUSSI : une carte masquee qui garderait l'id d'une ouverture
			# precedente est une carte qui echangerait la mauvaise competence le jour
			# ou un clic l'atteindrait.
			entry["id"] = ""
			slot.visible = false
			continue

		var id := String(candidates[index]["id"])
		var tier := int(candidates[index].get("tier", 1))
		entry["id"] = id
		slot.visible = true
		# Le NOMBRE, toujours, jamais "NOUVEAU" — voir `_tier_marker`.
		_fill_skill_card(entry, id, tier, Locale.t("card.tier") % tier)

	_size_plate(_replace_plate, _replace_card_size(count))

	# AVANT `_open_card`, comme le carton de niveau : les quatre poses d'ouverture
	# sont ce qui donne au SubViewport le temps de rendre sa premiere frame.
	_set_replace_thumbs_running(true)
	_open_card(_replace_card)


## La plaque se taille sur ce qu'elle porte, dans les deux dimensions. Deux
## actifs tiennent en une rangee ; six auto en demandent deux, et une plaque
## figee sur le pire cas laisserait un demi-carton vide dans le cas courant.
func _replace_card_size(count: int) -> Vector2:
	var columns := clampi(count, 1, REPLACE_COLUMNS)
	var rows := int(ceil(float(maxi(count, 1)) / float(columns)))
	# Deux colonnes au minimum : c'est ce qu'il faut au titre de 44 px.
	var wide := maxi(columns, 2)

	return Vector2(
		maxf(
			REPLACE_CHROME.x,
			UiStyle.PAD * 2.0 + float(wide) * SACRIFICE_SIZE.x + float(wide - 1) * 12.0
		),
		REPLACE_CHROME.y + float(rows) * SACRIFICE_SIZE.y + float(rows - 1) * 12.0
	)


func hide_replace_card() -> void:
	_replace_card.visible = false
	_set_replace_thumbs_running(false)


func is_replace_card_open() -> bool:
	return _replace_card.visible


func _set_replace_thumbs_running(running: bool) -> void:
	for entry in _replace_slots:
		SkillThumb.set_running(entry["thumb"], running)


# ─────────────────────────────────────────────────────────────────────────────
# Le carton de reglages
# ─────────────────────────────────────────────────────────────────────────────


## Les reglages sont un CARTON, pas un ecran a part.
##
## Ils passent donc par le meme squelette que le niveau et le K.O. — voile,
## lignes de vitesse, plaque grise a angles droits, ouverture en pas. Une fenetre de
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

	_settings_title = UiStyle.make_label(
		Locale.t("settings.title"), UiStyle.display_font(), UiStyle.SIZE_CARD_TITLE - 6,
		UiStyle.CREAM, UiStyle.TRACKING_TITLE, 0, true
	)
	_settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_settings_title)

	_settings_hint = UiStyle.make_label(
		Locale.t("settings.hint"), UiStyle.body_font(), UiStyle.SIZE_CARD_SUB,
		UiStyle.CREAM_DIM, 1, 0, false
	)
	_settings_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_settings_hint)

	column.add_child(_build_language_row())

	_settings_close = _make_wide_button(Locale.t("settings.close"))
	column.add_child(_settings_close)
	# ⚠️ PAS `close_settings_card` directement — voir `settings_close_requested`.
	# Le bouton demande, main.gd ferme ET relance le jeu.
	_settings_close.pressed.connect(func() -> void: settings_close_requested.emit())


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

	# En relief comme les cartes de choix : c'est le meme geste — un aplat sur
	# lequel on clique. Les jauges du HUD restent plates, elles ne se cliquent pas.
	var plate := UiStyle.make_plate(
		UiStyle.PLATE_RAISED, UiStyle.RULE, UiStyle.TICK, 1.0,
		UiStyle.RELIEF_RAISED
	)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(plate)

	# Le nom de la langue N'EST PAS traduit — voir Locale.NATIVE_NAMES.
	var label := UiStyle.make_label(
		Locale.native_name(code), UiStyle.bold_font(), UiStyle.SIZE_BUTTON,
		UiStyle.CREAM, UiStyle.TRACKING_LABEL, 0, false
	)
	# ⚠️ CENTRE SUR LA FACE, PAS SUR LE RECTANGLE. La tranche et l'ombre occupent
	# les 11 px bas-droite de la pastille : un libelle centre sur le rectangle
	# entier tomberait 5 px trop bas et trop a droite, et sur un objet de 158 x 52
	# ca se voit — le mot ne serait plus pose au milieu de son dessus.
	var inset := UiStyle.relief_inset(UiStyle.RELIEF_RAISED)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_right = -inset
	label.offset_bottom = -inset
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.offset_right = -inset
	button.offset_bottom = -inset
	button.focus_mode = Control.FOCUS_NONE
	slot.add_child(button)

	button.pressed.connect(func() -> void: language_selected.emit(code))

	_language_slots.append({"code": code, "plate": plate, "label": label})
	return slot


## Marque la langue active — filet, reperes d'angle et libelle en ambre.
##
## Exactement le meme signal que le survol d'une carte d'upgrade, et c'est
## voulu : l'ambre est le seul sature de l'ecran et son role unique est de
## DESIGNER (§9.3 regle 4). Deux dispositifs differents pour "cet element est
## celui-la" obligeraient a apprendre l'interface deux fois.
##
## ⚠️ Sans etat visible, deux pastilles identiques ne disent pas laquelle est en
## service, et le seul indice serait la langue du reste du carton — illisible
## precisement pour qui vient de se tromper de langue.
func _sync_language_slots() -> void:
	for entry in _language_slots:
		var active: bool = entry["code"] == Locale.language()
		var mat: ShaderMaterial = entry["plate"].material
		mat.set_shader_parameter("ink_color", UiStyle.AMBER if active else UiStyle.RULE)
		entry["label"].add_theme_color_override(
			"font_color", UiStyle.AMBER if active else UiStyle.CREAM
		)


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
	# ⚠️ La LEGENDE du carton de remplacement n'est pas ici : elle porte le nom de
	# la competence qui arrive, que seul `show_replace_card` connait. Elle n'a pas
	# a etre rafraichie pour autant — on ne peut pas ouvrir les reglages pendant un
	# carton de remplacement (voir main.gd), donc aucun texte ne change sous les
	# yeux du joueur. Meme raison que pour le carton de niveau.
	_replace_title.text = Locale.t("card.replace_title")
	_replace_back.text = Locale.t("card.replace_back")
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
	# Pas de cerne : le bouton est POSE SUR UNE PLAQUE OPAQUE. Le cerne d'encre
	# n'existe que pour un texte qui flotte sur le jeu — ici il n'ajouterait
	# qu'une 4e valeur brune sur du gris neutre (§9.3 regle 4).
	return button


# ─────────────────────────────────────────────────────────────────────────────
# Ouverture des cartons — en pas
# ─────────────────────────────────────────────────────────────────────────────


## Les choix arrivent en `id` et en PALIER — le catalogue ne porte plus de texte
## depuis le passage au bilingue, et plus de valeurs depuis le passage aux
## competences. C'est ici que les deux deviennent des mots, une fois, dans la
## langue du moment.
func show_level_card(level: int, choices: Array) -> void:
	_level_title.text = Locale.t("hud.level") % level
	_level_sub.text = Locale.t("card.level_sub")

	for index in range(_choice_slots.size()):
		var entry: Dictionary = _choice_slots[index]
		var slot: Control = entry["slot"]

		if index < choices.size():
			var id := String(choices[index]["id"])
			var tier := int(choices[index].get("tier", 1))
			slot.visible = true
			_fill_skill_card(entry, id, tier, _tier_marker(id, tier))
		else:
			slot.visible = false

	# ⚠️ AVANT `_open_card`, pas apres. Le carton s'ouvre en 4 poses pendant
	# lesquelles le contenu est masque ; allumer le rendu a la fin ferait
	# apparaitre trois fenetres NOIRES a la derniere pose, le temps que le
	# SubViewport rende sa premiere frame. Le lancer d'abord lui donne les quatre
	# poses d'avance qu'il faut, et c'est gratuit puisqu'on est en pause.
	_set_thumbs_running(true)
	_open_card(_level_card)


## Le bandeau de type : sa couleur et son mot, ensemble.
##
## ⚠️ LES DEUX, JAMAIS L'UN SANS L'AUTRE. La couleur se lit d'un balayage mais
## elle s'apprend ; le mot se lit toujours mais il se lit lentement. Un joueur
## qui decouvre le jeu suit le mot, un joueur qui l'a en main suit la couleur, et
## personne n'a a choisir. C'est aussi ce qui rend le code couleur sans risque
## pour qui distingue mal le vert du rouge — les deux teintes retenues n'etant,
## de surcroit, ni l'une ni l'autre saturees.
func _set_slot_kind(entry: Dictionary, kind: SkillDefinitions.Kind) -> void:
	var band: ColorRect = entry["band"]

	match kind:
		SkillDefinitions.Kind.AUTO:
			band.color = UiStyle.KIND_AUTO
			entry["band_label"].text = Locale.t("skill.kind.auto")
		SkillDefinitions.Kind.ACTIVE:
			band.color = UiStyle.KIND_ACTIVE
			entry["band_label"].text = Locale.t("skill.kind.active")
		_:
			band.color = UiStyle.KIND_PASSIVE
			entry["band_label"].text = Locale.t("skill.kind.passive")


## Ce que la carte annonce en legende : un DEBLOCAGE, un renfort, ou le moment
## fort de la run.
##
## Les trois mots ne disent pas la meme chose au joueur, et c'est pour ca qu'ils
## sont trois : "NOUVEAU" ouvre une arme qu'il n'avait pas, "PALIER 2" approfondit
## une arme qu'il joue deja, "ULTIME" ferme une bifurcation pour le reste de la
## run (§2.2). Un seul et meme "PALIER %d" les aplatirait tous les trois.
##
## ⚠️ IL NE SERT QUE LE CARTON DE NIVEAU, et c'est pour ca que `_fill_skill_card`
## recoit le marqueur au lieu de le calculer. Ces mots decrivent ce qu'une carte
## OFFRE ; sur le carton de remplacement, rien n'est offert — un T1 qu'on
## abandonne n'est pas "NOUVEAU", c'est un palier 1, et c'est le seul chiffre qui
## dit ce que l'abandon coute.
func _tier_marker(id: String, tier: int) -> String:
	if tier <= 1:
		return Locale.t("card.tier_new")

	if tier > SkillDefinitions.find(id)["tiers"].size():
		return Locale.t("card.tier_ultimate")

	return Locale.t("card.tier") % tier


func show_game_over(elapsed: float, level: int) -> void:
	_game_over_summary.text = Locale.t("card.game_over_summary") % [
		int(elapsed) / 60, int(elapsed) % 60, level
	]
	_open_card(_game_over_card)


## ⚠️ LES VIGNETTES SE COUPENT AVEC LE CARTON, et ce n'est pas une economie de
## frames : un SubViewport laisse en `UPDATE_ALWAYS` continue de rendre derriere
## un carton ferme, indefiniment, pendant toute la run. Trois quads de 76 px ne
## se verront pas au profileur — c'est precisement pour ca qu'il faut les couper
## ici plutot que de compter dessus pour s'en apercevoir un jour.
func hide_level_card() -> void:
	_level_card.visible = false
	_set_thumbs_running(false)


func is_level_card_open() -> bool:
	return _level_card.visible


func _set_thumbs_running(running: bool) -> void:
	for entry in _choice_slots:
		SkillThumb.set_running(entry["thumb"], running)


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
