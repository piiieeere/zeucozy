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
## jamais un clair qui tire au froid.
##
## ─── v3, 2026-08-17 : la reference d'interface a CHANGE ───
##
## Cowboy Bebop + Neon Genesis Evangelion remplacent Orbitals pour la COULEUR,
## la MATIERE et la COMPOSITION. Orbitals garde la PLACE (HUD nu dans un coin,
## texte minuscule, ombre decalee, entree en pas) : tout §9.4 et tout ce qui
## precede sont intacts. Trois choses seulement changent, et elles sont liees :
##
##   • L'UI N'EST PLUS TRANSLUCIDE, NULLE PART. Les cartes de choix etaient a
##     8 % d'opacite — ce n'etait pas une carte, c'etait un voile. Ni Bebop ni
##     Eva n'ont un seul element d'UI translucide : c'est ce qui les fait lire
##     comme du PAPIER POSE sur l'image plutot que comme un calque de logiciel.
##     Seul le voile de fond garde un alpha, et il ASSOMBRIT au lieu de teinter.
##   • L'UI EST EN GRIS NEUTRE, hors de la palette chaude de §4. Une interface
##     n'appartient pas au monde : le brun ramenait l'UI dans l'appartement du
##     chat. ⚠️ Le gris reste QUASI NEUTRE (2 % de saturation) et non le gunmetal
##     bleute de Bebop — precedent mesure : le corps de la griffure a du passer
##     de #383E42 a #37393B parce qu'un gris bleute se lit comme une tache
##     FROIDE sur un sol parchemin. L'UI est posee sur ce meme sol.
##   • LES COINS SONT DROITS, avec des reperes d'angle. Le chanfrein venait
##     d'Orbitals ; Bebop et Eva sont carres sans exception.
##
## Et une regle de composition qui remplace les demi-teintes : LA HIERARCHIE SE
## FAIT A L'ECHELLE, pas au gris. Un mot de carton a 44 px contre sa legende a
## 10 px dit ce qu'aucune nuance ne dira.

const FRAME_SHADER := preload("res://shaders/ui_frame.gdshader")
const SPEEDLINES_SHADER := preload("res://shaders/ui_speedlines.gdshader")

# ─────────────────────────────────────────────────────────────────────────────
# Palette — "Visual Art Direction" §9.5
# ─────────────────────────────────────────────────────────────────────────────

## Le trait. Reprend l'outline principal de §4 : l'UI et le monde partagent leur
## encre, c'est ce qui fait qu'elle se lit comme dessinee sur la meme cel.
##
## ⚠️ Il ne sert plus QUE ce qui flotte sur le jeu — le HUD nu et les jauges. A
## l'interieur d'un carton, la plaque est opaque : plus rien n'a besoin d'etre
## detache, et un brun chaud sur du gris neutre y serait une 4e valeur (§9.3
## regle 4). Voir `make_label` et le cerne.
const INK := Color("#3D2B1A")

## La plaque des cartons — ardoise QUASI NEUTRE, 2 % de saturation.
##
## ⚠️ Elle etait brune (#241A11) jusqu'au 2026-08-17. Le raisonnement d'alors
## etait juste — "une plaque parchemin sur un sol parchemin ne se lit pas" —
## mais sa conclusion etait trop etroite : elle ne considerait que des couleurs
## DE LA PALETTE DU MONDE. Sortir de cette palette etait la 3e option, et
## personne ne l'avait posee. Le gris n'est pas une entorse a §4, c'est la
## reconnaissance que l'UI n'est pas dans son domaine.
##
## 0,23 de luma contre 0,84 pour le parquet : 0,61 d'ecart. C'est ce chiffre qui
## rend la plaque VOYANTE sans lui donner de contour epais — une plaque se lit a
## la valeur, le filet ne fait que la finir.
const PLATE := Color("#3A3A38")

## Le second gris, plus sombre : piste de jauge, pastille de cooldown. Tout ce
## qui est CREUSE dans un carton.
const PLATE_LOW := Color("#2A2A28")

## Le gris des plaques EN RELIEF : cartes de choix, pastilles de langue.
##
## ⚠️ IL EST PLUS CLAIR QUE `PLATE`, ET C'EST TOUT SON OBJET. Les cartes etaient
## en `PLATE_LOW` (0,16) sur un carton a 0,23 : plus sombres que ce qui les
## porte, donc lues comme des TROUS. On peut leur ajouter tous les biseaux qu'on
## veut, un objet plus sombre que son fond s'enfonce — c'est la premiere chose
## que dit une image, avant tout dessin de bord.
##
## La regle qui en sort, et qui vaut pour tout ce qu'on ajoutera : dans un
## carton, CE QU'ON PEUT PRENDRE EST PLUS CLAIR QUE SON FOND, ce qui recoit est
## plus sombre. Le partage n'est plus "contenant / contenu" mais "en relief /
## en creux", et il se lit sans avoir a le savoir.
##
## ⚠️ 0,30 de luma, et le premier essai a 0,27 NE SUFFISAIT PAS : la facette lui
## reprend `facet_drop` sur toute sa face avant, ce qui la ramenait a 0,24 —
## soit la valeur du carton a 0,23, au point pres. La carte redevenait invisible
## sauf par son filet. Une plaque en relief se dimensionne APRES sa facette, pas
## avant : c'est la face sombre qui doit rester au-dessus du fond, pas la claire.
const PLATE_RAISED := Color("#504F4B")

## Le filet et les reperes d'angle des cartons. Assez clair pour se lire sur la
## plaque, assez sombre pour ne pas concurrencer le texte.
##
## ⚠️ C'est lui qui remplace INK comme cerne DES CARTONS. Sur une plaque a 0,23,
## une encre a 0,19 ne serait pas un cadre — ce serait la couleur de son fond.
const RULE := Color("#8E8E88")

## Le voile derriere un carton. La SEULE translucidite de toute l'interface, et
## la seule qui soit legitime : elle assombrit l'image au lieu de la teinter.
## L'encre a 55 % qu'elle remplace teintait la scene en brun.
const VEIL := Color("#1A1A19")

## Le creme du texte — le meme que le blanc du pelage tuxedo.
##
## ⚠️ IL NE CHANGE PAS, alors qu'un creme plus neutre serait plus "Bebop".
## #F7EFE0 est deja le blanc du pelage, le coeur de la griffure et le creme de
## l'haleine puante. Fabriquer un second creme pour l'UI seule, c'est fabriquer
## exactement la divergence de constantes que ce projet passe son temps a
## reparer. Et §5 tient : un blanc froid sur une image chaude est un bug.
const CREAM := Color("#F7EFE0")

## Texte secondaire : legendes, sous-titres, telemetrie.
##
## ⚠️ Neutralise le 2026-08-17. L'ancien #C9BCA6 etait un gris CHAUD ; sur une
## plaque brune il passait, sur du gris neutre il se lit comme du texte jauni.
## C'est le seul changement de couleur que le passage au gris impose vraiment.
const CREAM_DIM := Color("#A8A5A0")

const AMBER := Color("#D4A860")      # accent, survol
const TERRACOTTA := Color("#D46858") # vie
const GOLD := Color("#E8C040")       # XP
const MINT := Color("#60C498")       # soin, bonus
const HIT_ROSE := Color("#D45870")   # alerte, vie basse

# ─────────────────────────────────────────────────────────────────────────────
# Le code de type des competences — §9.9 (2026-08-17)
# ─────────────────────────────────────────────────────────────────────────────
#
# AUTO, ACTIF et PASSIF ne se distinguaient que par la lecture de la
# description : trois cartes identiques, et le joueur devait deduire le type des
# mots. C'est un bandeau en tete de carte qui le dit maintenant, et il le dit
# TROIS FOIS — par sa couleur, par son mot, et par la presence ou l'absence de
# vignette dessous.
#
# ⚠️ LES TEINTES SONT FRANCHEMENT SOUS LA SATURATION DE L'AMBRE, et c'est la
# condition qui rend le code couleur compatible avec §9.1 regle 4 ("un seul
# accent sature, et il DESIGNE"). L'ambre garde le survol : il doit rester le
# plus sature de l'ecran, sinon le joueur ne voit plus quelle carte il pointe.
#   sauge   #7E9A80 — 18 % de saturation
#   brique  #A86A56 — 49 %, mais a 0,42 de valeur : sombre, il ne claque pas
#   ambre   #D4A860 — 55 % a 0,83 de valeur, le seul qui saute aux yeux
#
# ⚠️ AUCUNE des deux ne tire au FROID (§5), sauge comprise : son vert est tire
# vers le jaune, pas vers le bleu. C'est la meme contrainte qui avait fait passer
# le corps de la griffure de #383E42 a #37393B.
#
# ⚠️ LE PASSIF N'A PAS DE TEINTE, et ce n'est pas une economie. Un passif n'est
# JAMAIS dessine dans le jeu (`skill_definitions.gd`) — c'est ce qui justifie
# qu'il ne coute ni slot ni pixel. Lui donner une couleur d'arme dirait le
# contraire, et l'absence de couleur est ici l'information exacte : deux teintes
# neuves seulement, au lieu de trois.
const KIND_AUTO := Color("#7E9A80")
const KIND_ACTIVE := Color("#A86A56")
const KIND_PASSIVE := RULE

## Le lettrage POSE SUR un bandeau de type. Le registre bas, pas l'encre : le
## cerne brun est le trait du MONDE, et §9.8 l'a retire de l'interieur des
## cartons. Ici il n'y a rien a detacher, juste des lettres sombres sur un aplat.
const KIND_LABEL := PLATE_LOW

const BAND_HEIGHT := 18.0

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
# ⚠️ LES KANA DECORATIFS ONT ETE RETIRES le 2026-08-17 (demande directe). Il n'y
# a donc plus de sous-ensemble `kana` : les deux familles ne portent plus que le
# latin, et rien dans l'UI ne demande un glyphe japonais.
#
# Ce que les cartons perdent : le petit accent d'epoque qui coiffait leur titre.
# Ce qu'ils gardent : la gothique lourde, qui porte a elle seule le registre
# anime TV — c'est la LETTRE qui datait l'image, pas l'alphabet.
#
# ⚠️ Les fichiers sont des SOUS-ENSEMBLES (tools/fetch_fonts.ps1) : `latin`
# couvre U+0000-00FF (tous les accents francais), `latin-ext` ajoute l'oe lie.

const _DISPLAY_LATIN := preload("res://assets/fonts/DelaGothicOne.latin.woff2")
const _DISPLAY_EXT := preload("res://assets/fonts/DelaGothicOne.latin-ext.woff2")

const _BODY_LATIN := preload("res://assets/fonts/ZenKakuGothicNew-Medium.latin.woff2")
const _BODY_EXT := preload("res://assets/fonts/ZenKakuGothicNew-Medium.latin-ext.woff2")

const _BOLD_LATIN := preload("res://assets/fonts/ZenKakuGothicNew-Bold.latin.woff2")
const _BOLD_EXT := preload("res://assets/fonts/ZenKakuGothicNew-Bold.latin-ext.woff2")

# ─────────────────────────────────────────────────────────────────────────────
# Metriques
# ─────────────────────────────────────────────────────────────────────────────
#
# En pixels de la resolution de reference (1152 x 648). Le projet est en stretch
# `canvas_items` : ce sont donc des unites d'UI stables, pas des pixels d'ecran.

const BASE_VIEWPORT := Vector2(1152.0, 648.0)

const MARGIN := 20.0  ## Marge au bord de l'ecran.
const PAD := 16.0     ## Air interieur d'un carton.
const BORDER := 2.0   ## Filet des cartons.

## Le repere d'angle — deux traits courts en L rentre, en retrait de chaque coin.
##
## ⚠️ Il REMPLACE le chanfrein, il ne s'y ajoute pas. Bebop et Eva sont carres
## sans exception ; mais un angle droit NU retombe sur le rectangle de logiciel
## que le chanfrein existait pour eviter. Le repere est ce qui date l'interface
## a sa place — c'est le cartouche technique d'Eva.
const TICK := 10.0
const TICK_INSET := 6.0
const TICK_WIDTH := 2.0

## Pas de repere. Les jauges : une marque de 10 px sur une piste de 8 px de haut
## n'a aucun sens, et §9.6 leur demande le meme dessin qu'entre elles, pas le
## meme qu'un carton.
const NO_TICK := 0.0

# ─────────────────────────────────────────────────────────────────────────────
# Le relief des plaques — §9.9 (2026-08-17)
# ─────────────────────────────────────────────────────────────────────────────
#
# Les cartes de choix etaient trois aplats poses sur un aplat : rien ne disait
# qu'on pouvait les prendre. Le volume se fait en BANDES DE VALEUR A BORD FRANC
# (§9.1 regle 2 interdit le degrade) — biseau + facette + ombre portee dure, le
# detail est dans `ui_frame.gdshader`.
#
# ⚠️ IL N'EST PAS UNIVERSEL, et c'est la ligne de partage : le relief va a ce qui
# est POSE SUR l'image (cartons, cartes, pastilles de langue), jamais a ce qui y
# est CREUSE (pistes de jauge, pastilles de cooldown). Une jauge en relief se
# lirait comme un bouton, donc comme quelque chose sur quoi cliquer.

## ⚠️ 3 px et non 2, et l'ecart de valeur a monte avec. A 2 px sur `PLATE_LOW`
## (0,16), le biseau ne se voyait tout simplement pas en capture — une plaque
## sombre absorbe une bande claire etroite, la ou une plaque claire l'aurait
## rendue criarde. Le biseau se dose sur CE QU'IL CERNE, comme le trait du chat,
## comme le cerne d'un glyphe de 12 px : jamais en valeur absolue partagee.
const BEVEL := 3.0
const BEVEL_LIFT := 0.14
const BEVEL_DROP := 0.10

## La coupe de la facette, en fraction de la hauteur.
##
## ⚠️ 0,13 ET NON 0,42, et l'ecart entre les deux est toute la difference entre
## un volume et un motif. A 0,42 la carte sortait en DEUX RECTANGLES EMPILES —
## une moitie haute claire, une moitie basse sombre, et la coupe tombait au
## milieu du texte sans que rien ne l'explique. C'est le defaut annonce dans le
## commentaire de `face_split`, simplement decale d'un cran.
##
## Une face de dessus est ETROITE : c'est la tranche d'un objet vu de trois
## quarts, pas la moitie de sa facade. A 0,13 le bandeau clair se lit comme
## l'epaisseur eclairee du haut de la plaque — le meme geste que les deux ombres
## portees peintes du canape, qui font lire son volume de dessus (§4).
const FACET_SPLIT := 0.13
const FACET_LIFT := 0.045
const FACET_DROP := 0.030

## Le decalage de l'ombre portee. Meme sens que `SHADOW_OFFSET` du texte (bas
## droite), et a peine plus grand : deux ombres qui partiraient de cotes
## differents donneraient deux soleils dans la meme image.
const PLATE_SHADOW := 3.0

## Le decalage de l'ombre, en px. Deux suffisent : au-dela ca ne lit plus comme
## un defaut de registre mais comme une ombre portee, et on retombe sur l'UI de
## logiciel que tout ce fichier existe pour eviter.
const SHADOW_OFFSET := Vector2i(2, 2)

# Corps. Le HUD reste DELIBEREMENT petit — §9.1 releve ~13 px de capitale, ce
# qui correspond a un corps de ~17 px sur cette gothique.
const SIZE_TIME := 34       ## L'horloge — le seul gros chiffre du HUD.
const SIZE_LABEL := 15      ## Legendes en capitales ("NIVEAU", "ENNEMIS").
const SIZE_TELEMETRY := 12  ## Le releve de build, en bas.

## Le mot des cartons ("NIVEAU 3", "K.O.") et sa legende.
##
## ⚠️ L'ECART ENTRE LES DEUX EST LE DISPOSITIF, pas leur taille absolue. 44
## contre 10, soit un facteur 4,4 : c'est le geste d'Eva, un mot cadre a ras
## bord et une legende minuscule a cote. Il REMPLACE la hierarchie par nuances
## de gris que la v2 tenait (§9.3 regle 5). Rapprocher les deux corps, meme de
## 4 px, c'est reintroduire le besoin de demi-teintes qu'on vient de supprimer.
const SIZE_CARD_TITLE := 44
const SIZE_CARD_SUB := 10

const SIZE_CHOICE_TITLE := 17
const SIZE_CHOICE_DESC := 12
const SIZE_BUTTON := 16

## Interlettrage des capitales. Une capitale sans chasse ajoutee se lit comme un
## mot tasse ; c'est ce qui separe un intertitre d'un label de formulaire.
##
## Le titre monte a 6 le 2026-08-17 : les capitales tres espacees sont la
## signature typographique de Bebop, et le titre est le seul endroit ou une
## chasse pareille reste lisible.
const TRACKING_LABEL := 2
const TRACKING_TITLE := 6

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
		_display.fallbacks = [_DISPLAY_EXT]
	return _display


static func body_font() -> FontFile:
	if _body == null:
		_body = _BODY_LATIN
		_body.fallbacks = [_BODY_EXT]
	return _body


static func bold_font() -> FontFile:
	if _bold == null:
		_bold = _BOLD_LATIN
		_bold.fallbacks = [_BOLD_EXT]
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
		# REMPLISSENT — mesure faite sur une capture du jeu. Un cerne se dose en
		# fraction de la hauteur d'x, jamais en valeur absolue partagee par tous
		# les corps.
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


## Une plaque de carton : aplat OPAQUE, filet fin, angles droits, reperes d'angle.
##
## ⚠️ Reservee aux MOMENTS (niveau, K.O., reglages) et aux jauges. Le HUD
## permanent n'en pose aucune — §9.2. Le jour ou une plaque apparait derriere le
## HUD, le registre bascule de "anime" a "logiciel" et rien ne le signalera.
##
## ⚠️ NE JAMAIS LUI PASSER UNE COULEUR A ALPHA PARTIEL. §9.3 regle 3 : un aplat
## d'UI est opaque ou n'existe pas. Une opacite partielle est TOUJOURS la
## solution de facilite au meme probleme — "cet element est trop present" — et la
## vraie reponse est de le rendre plus petit, plus sombre, ou de le supprimer.
##
## `relief` donne a la plaque son volume — biseau, facette et ombre portee. Il
## est FAUX par defaut : voir le bloc « Le relief des plaques », le relief va a
## ce qui est pose sur l'image, jamais a ce qui y est creuse.
static func make_frame(
	plate: Color = PLATE,
	ink: Color = RULE,
	tick: float = TICK,
	border: float = BORDER,
	relief: bool = false
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FRAME_SHADER
	mat.set_shader_parameter("plate_color", plate)
	mat.set_shader_parameter("ink_color", ink)
	mat.set_shader_parameter("border_px", border)
	mat.set_shader_parameter("tick_px", tick)
	mat.set_shader_parameter("tick_inset_px", TICK_INSET)
	mat.set_shader_parameter("tick_width_px", TICK_WIDTH)
	mat.set_shader_parameter("reveal", 1.0)

	# A plat, on ne pose RIEN : les uniforms de relief valent zero dans le shader
	# et la plaque retombe exactement sur son dessin d'avant le 2026-08-17.
	if relief:
		mat.set_shader_parameter("bevel_px", BEVEL)
		mat.set_shader_parameter("bevel_lift", BEVEL_LIFT)
		mat.set_shader_parameter("bevel_drop", BEVEL_DROP)
		mat.set_shader_parameter("face_split", FACET_SPLIT)
		mat.set_shader_parameter("facet_lift", FACET_LIFT)
		mat.set_shader_parameter("facet_drop", FACET_DROP)
		mat.set_shader_parameter("shadow_px", PLATE_SHADOW)
		mat.set_shader_parameter("shadow_color", VEIL)

	return mat


## Le ColorRect qui porte une plaque.
##
## Il n'y a RIEN a recabler quand il change de taille : `ui_frame.gdshader`
## deduit ses pixels de `fwidth(UV)`. Une version precedente passait la taille
## par un uniform synchronise sur le signal `resized` — il arrivait en retard ou
## pas du tout selon l'ordre de resolution du layout, et les coins sortaient
## plusieurs fois trop gros, d'un facteur different par plaque.
static func make_plate(
	plate: Color = PLATE,
	ink: Color = RULE,
	tick: float = TICK,
	border: float = BORDER,
	relief: bool = false
) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 1)
	rect.material = make_frame(plate, ink, tick, border, relief)
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
