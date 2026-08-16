extends RefCounted

## ⭐ LA source du style d'interface — registre anime TV 80-90.
##
## Meme role que cel_model.gd pour le chat et cel_style.gd pour le decor : tout
## ce qui decide de l'allure de l'UI vit ICI. Recopier une de ces constantes
## dans un ecran, c'est fabriquer la divergence qu'on paie ensuite — exactement
## ce qui est arrive entre Blender et Godot.
##
## ─── D'ou viennent ces choix ───
##
## De "Visual Art Direction" §9, REECRIT le 2026-08-16 apres analyse image
## d'Orbitals (4 min de gameplay en 720p60 + 5 captures editeur en 4K). Ce sont
## des valeurs RELEVEES, pas devinees. Les trois qui comptent :
##
##   • LE HUD PERMANENT N'A AUCUN CONTENANT. Ni plaque, ni cadre, ni equerre de
##     coin. Le texte est pose nu sur l'image et se detache par son CERNE — la
##     meme logique que le contour du chat sur le parquet. Les plaques existent
##     ici, mais elles ne servent QUE les cartons (niveau, K.O.) : c'est ce
##     contraste qui fabrique l'evenement, pas leur taille.
##   • LE TEXTE EST MINUSCULE. Hauteur de capitale ~2 % de la hauteur d'ecran.
##     A 648 px de reference, ca fait 13 px de capitale.
##   • L'OMBRE EST DECALEE, pas diffuse. Chez eux elle est rouge — une
##     desynchronisation video analogique. Chez nous elle est brun d'encre : la
##     palette est chaude, un decalage rouge y passerait pour un bug.
##
## ⚠️ Ce que §5 impose survit intact et contraint tout : jamais de #000000,
## jamais un clair qui tire au froid. D'ou un brun tres sombre et un creme chaud.

const FRAME_SHADER := preload("res://shaders/ui_frame.gdshader")
const SPEEDLINES_SHADER := preload("res://shaders/ui_speedlines.gdshader")

# ─────────────────────────────────────────────────────────────────────────────
# Palette — "Visual Art Direction" §9.5
# ─────────────────────────────────────────────────────────────────────────────

## Le trait. Reprend l'outline principal de §4 : l'UI et le monde partagent leur
## encre, c'est ce qui fait qu'elle se lit comme dessinee sur la meme cel.
const INK := Color("#3D2B1A")

## La plaque des cartons. Plus sombre que l'encre pour que l'encre reste VISIBLE
## dessus : un cadre de la couleur de son fond n'est pas un cadre.
##
## ⚠️ Elle est SOMBRE, la ou §9 demandait du parchemin avant sa reecriture. Ce
## n'est pas un gout : le sol du jeu est en parchemin (#F5ECD8) et en ble
## (#E8D4A8). Une plaque parchemin sur un sol parchemin ne se lit pas.
const PLATE := Color("#241A11")

## Le creme du texte — le meme que le blanc du pelage tuxedo. Un blanc froid sur
## une image entierement chaude se lit comme une erreur d'affichage (§5).
const CREAM := Color("#F7EFE0")

## Creme assourdi : legendes, kana decoratif, telemetrie. Une hierarchie de
## texte se fait a la VALEUR avant de se faire a la taille.
const CREAM_DIM := Color("#C9BCA6")

const AMBER := Color("#D4A860")      # accent, survol
const TERRACOTTA := Color("#D46858") # vie
const GOLD := Color("#E8C040")       # XP
const MINT := Color("#60C498")       # soin, bonus
const HIT_ROSE := Color("#D45870")   # alerte, vie basse

# ─────────────────────────────────────────────────────────────────────────────
# Typographie — §9.4
# ─────────────────────────────────────────────────────────────────────────────
#
# ⚠️ IL N'Y A AUCUNE MINCHO DANS ORBITALS — verifie a l'image. Son HUD est une
# grotesque techno carree, son logo une gothique lourde angulaire. Une mincho
# avait ete choisie ici le 2026-08-16 par reflexe "carton d'anime", puis retiree
# le meme jour : le reflexe est repandu et faux pour cette reference.
#
# On garde leur GRAMMAIRE (capitales, minuscule, nu, ombre decalee) sans leur
# LETTRE : la techno carree est un afficheur de machine, elle dirait "station
# spatiale" dans un jeu de chat. CLAUDE.md exclut explicitement le sci-fi.
#
#   • DISPLAY (Dela Gothic One) — les MOMENTS. Gothique lourde, angulaire,
#     terminaisons coupees net : la lettre du logo Orbitals. Illisible en petit.
#   • CORPS (Zen Kaku Gothic New) — l'INFORMATION. Tient a 13 px sur une image
#     chargee, ce qu'aucune display ne fait.
#
# Les deux portent le kana, ce qui evite une 3e famille pour les accents.
#
# ⚠️ Les fichiers sont des SOUS-ENSEMBLES (tools/fetch_fonts.ps1) : `latin`
# couvre U+0000-00FF (tous les accents francais), `latin-ext` ajoute l'oe lie,
# `kana` ne porte QUE les caracteres de KANA ci-dessous. Un kana ajoute ici sans
# etre ajoute au script rend un carre vide, en silence.

const _DISPLAY_LATIN := preload("res://assets/fonts/DelaGothicOne.latin.woff2")
const _DISPLAY_EXT := preload("res://assets/fonts/DelaGothicOne.latin-ext.woff2")
const _DISPLAY_KANA := preload("res://assets/fonts/DelaGothicOne.kana.woff2")

const _BODY_LATIN := preload("res://assets/fonts/ZenKakuGothicNew-Medium.latin.woff2")
const _BODY_EXT := preload("res://assets/fonts/ZenKakuGothicNew-Medium.latin-ext.woff2")
const _BODY_KANA := preload("res://assets/fonts/ZenKakuGothicNew-Medium.kana.woff2")

const _BOLD_LATIN := preload("res://assets/fonts/ZenKakuGothicNew-Bold.latin.woff2")
const _BOLD_EXT := preload("res://assets/fonts/ZenKakuGothicNew-Bold.latin-ext.woff2")
const _BOLD_KANA := preload("res://assets/fonts/ZenKakuGothicNew-Bold.kana.woff2")

## Les kana decoratifs, en un seul endroit. Le francais porte TOUTE
## l'information ; ceux-ci n'ajoutent que l'epoque, en petit et en creme
## assourdi. Aucun n'est necessaire a la comprehension du jeu.
const KANA := {
	"time": "タイム",
	"level": "レベル",
	"life": "ライフ",
	"level_up": "レベルアップ",
	"game_over": "ゲームオーバー",
	"to_be_continued": "つづく",
	"cat": "ネコ",
}

# ─────────────────────────────────────────────────────────────────────────────
# Metriques
# ─────────────────────────────────────────────────────────────────────────────
#
# En pixels de la resolution de reference (1152 x 648). Le projet est en stretch
# `canvas_items` : ce sont donc des unites d'UI stables, pas des pixels d'ecran.

const BASE_VIEWPORT := Vector2(1152.0, 648.0)

const MARGIN := 20.0        ## Marge au bord de l'ecran.
const PAD := 16.0           ## Air interieur d'un carton.
const BORDER := 2.0         ## Filet d'encre des cartons.
const CHAMFER := 12.0       ## Coin coupe des cartons.
const CHAMFER_SMALL := 3.0  ## Coin coupe des pastilles et des jauges.

## Le decalage de l'ombre, en px. Deux suffisent : au-dela ca ne lit plus comme
## un defaut de registre mais comme une ombre portee, et on retombe sur l'UI de
## logiciel que tout ce fichier existe pour eviter.
const SHADOW_OFFSET := Vector2i(2, 2)

# Corps. Le HUD reste DELIBEREMENT petit — §9.1 releve ~13 px de capitale, ce
# qui correspond a un corps de ~17 px sur cette gothique.
const SIZE_TIME := 34       ## L'horloge — le seul gros chiffre du HUD.
const SIZE_LABEL := 15      ## Legendes en capitales ("NIVEAU", "ENNEMIS").
const SIZE_KANA := 12       ## Kana decoratif — toujours le plus petit de l'ecran.
const SIZE_TELEMETRY := 12  ## Le releve de build, en bas.
const SIZE_CARD_TITLE := 40 ## Le mot des cartons ("NIVEAU 3", "K.O.").
const SIZE_CARD_SUB := 14
const SIZE_CHOICE_TITLE := 17
const SIZE_CHOICE_DESC := 12
const SIZE_BUTTON := 16

## Interlettrage des capitales. Une capitale sans chasse ajoutee se lit comme un
## mot tasse ; c'est ce qui separe un intertitre d'un label de formulaire.
const TRACKING_LABEL := 2
const TRACKING_TITLE := 3

# Jauges.
#
# La vie est PLUS EPAISSE que l'XP, et c'est la seule hierarchie dont le joueur
# ait besoin entre les deux : perdre sa vie termine la run, gagner de l'XP la
# prolonge. Deux barres de meme epaisseur demanderaient de lire une legende.
const HEALTH_BAR := Vector2(186.0, 14.0)
const XP_BAR := Vector2(186.0, 8.0)

## En dessous de ce ratio, la barre de vie passe au rose de blessure (§8, la
## couleur du feedback de hit). Un seuil plutot qu'un degrade continu : un
## degrade ne dit jamais QUAND s'inquieter, une bascule si.
const HEALTH_LOW := 0.30

# ─────────────────────────────────────────────────────────────────────────────
# Polices assemblees
# ─────────────────────────────────────────────────────────────────────────────
#
# Les trois sous-ensembles d'une famille sont recolles par le mecanisme de repli
# de Godot : le `latin` porte la police, les deux autres arrivent quand un
# glyphe manque. Fait UNE fois — d'ou les `static var`.

static var _display: FontFile
static var _body: FontFile
static var _bold: FontFile


static func display_font() -> FontFile:
	if _display == null:
		_display = _DISPLAY_LATIN
		_display.fallbacks = [_DISPLAY_EXT, _DISPLAY_KANA]
	return _display


static func body_font() -> FontFile:
	if _body == null:
		_body = _BODY_LATIN
		_body.fallbacks = [_BODY_EXT, _BODY_KANA]
	return _body


static func bold_font() -> FontFile:
	if _bold == null:
		_bold = _BOLD_LATIN
		_bold.fallbacks = [_BOLD_EXT, _BOLD_KANA]
	return _bold


# ─────────────────────────────────────────────────────────────────────────────
# Fabriques
# ─────────────────────────────────────────────────────────────────────────────


## Un Label deja habille. Passer par ici plutot que de poser des
## `theme_override_*` a la main : c'est ce qui garantit qu'un ecran ajoute plus
## tard ne reintroduise pas la police par defaut de Godot sans que rien ne casse.
##
## `outline` cerne le texte d'encre, et il est INDISPENSABLE des que le texte
## flotte sur le jeu sans plaque — c'est-a-dire partout dans le HUD. Le sol
## passe du ble clair au tapis sombre et le chat traverse le champ ; sans cerne,
## le texte devient illisible sur l'un des trois. C'est la logique du contour du
## chat : le trait n'est pas un ornement, c'est ce qui detache.
##
## `shadow` ajoute le decalage de registre video de §9.1. Cerne ET decalage
## ensemble : le cerne assure la lecture, le decalage donne l'epoque.
static func make_label(
	text: String,
	font: FontFile,
	size: int,
	color: Color,
	tracking: int = 0,
	outline: int = 0,
	shadow: bool = false
) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)

	if tracking > 0:
		label.add_theme_constant_override("extra_spacing_glyph", tracking)

	if outline > 0:
		# `outline` est l'epaisseur REELLE en px, pas un multiplicateur.
		# ⚠️ Elle doit suivre le corps : 2 px de cerne sur un glyphe de 11 px le
		# REMPLISSENT — mesure faite sur une capture du jeu, le kana sortait en
		# bouillie. Un cerne se dose en fraction de la hauteur d'x, jamais en
		# valeur absolue partagee par tous les corps.
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", INK)

	if shadow:
		label.add_theme_constant_override("shadow_offset_x", SHADOW_OFFSET.x)
		label.add_theme_constant_override("shadow_offset_y", SHADOW_OFFSET.y)
		label.add_theme_color_override("font_shadow_color", Color(INK, 0.85))

	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Le raccourci du HUD : capitales, cernees, decalees, en creme. Tout ce qui
## reste a l'ecran en permanence passe par la.
static func make_hud_label(text: String, size: int = SIZE_LABEL, color: Color = CREAM) -> Label:
	return make_label(text, bold_font(), size, color, TRACKING_LABEL, 2, true)


## Le kana decoratif : le plus petit corps de l'ecran, en creme assourdi, jamais
## porteur d'information.
##
## Cerne a 1 px SEULEMENT. Un kana est bien plus dense qu'une capitale latine du
## meme corps ; le cerne du HUD le bouchait entierement.
static func make_kana_label(key: String) -> Label:
	return make_label(KANA[key], body_font(), SIZE_KANA, CREAM_DIM, TRACKING_LABEL, 1, false)


## Une plaque de carton : fond sombre, filet d'encre, coins coupes.
##
## ⚠️ Reservee aux MOMENTS (niveau, K.O.) et aux jauges. Le HUD permanent n'en
## pose aucune — §9.2. Le jour ou une plaque apparait derriere le HUD, le
## registre bascule de "anime" a "logiciel" et rien ne le signalera.
static func make_frame(
	plate: Color = PLATE,
	ink: Color = INK,
	chamfer: float = CHAMFER,
	border: float = BORDER
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FRAME_SHADER
	mat.set_shader_parameter("plate_color", plate)
	mat.set_shader_parameter("ink_color", ink)
	mat.set_shader_parameter("border_px", border)
	mat.set_shader_parameter("chamfer_px", chamfer)
	mat.set_shader_parameter("reveal", 1.0)
	return mat


## Le ColorRect qui porte une plaque.
##
## Il n'y a RIEN a recabler quand il change de taille : `ui_frame.gdshader`
## deduit ses pixels de `fwidth(UV)`. Une version precedente passait la taille
## par un uniform synchronise sur le signal `resized` — il arrivait en retard ou
## pas du tout selon l'ordre de resolution du layout, et les chanfreins
## sortaient plusieurs fois trop gros, d'un facteur different par plaque.
static func make_plate(
	plate: Color = PLATE,
	ink: Color = INK,
	chamfer: float = CHAMFER,
	border: float = BORDER
) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 1)
	rect.material = make_frame(plate, ink, chamfer, border)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect



## Les lignes de vitesse des cartons — le seul emprunt franc au manga.
## Elles ne servent QUE les moments : permanentes, elles deviendraient un fond,
## et un fond ne dit plus "il se passe quelque chose".
static func make_speedlines(color: Color, count: float = 84.0) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 1)

	var mat := ShaderMaterial.new()
	mat.shader = SPEEDLINES_SHADER
	mat.set_shader_parameter("line_color", color)
	mat.set_shader_parameter("line_count", count)
	mat.set_shader_parameter("inner_radius", 0.34)
	mat.set_shader_parameter("seed", randf() * 100.0)
	mat.set_shader_parameter("reveal", 1.0)

	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
