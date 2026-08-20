class_name CelModel
extends Node3D

## Instancie un modele .glb et lui applique le style cel du projet.
##
## Ce script etait a l'origine dans le banc de test (scripts/tests/cel_test.gd).
## Il en a ete extrait pour que le JEU et le BANC partagent exactement le meme
## rendu : un reglage corrige d'un cote profite a l'autre sans recopie.
##
## Ce qu'il reconstruit, et que le glTF ne transporte pas
## (liste complete dans "Pipeline 3D") :
##   - la palette par materiau (les nodes custom Blender ne s'exportent pas) ;
##   - le contour en coque inversee, en next_pass ;
##   - le visage peint (yeux, nez, bouche, moustaches) — rien n'est modelise ;
##   - les calottes peintes (interieur d'oreille) ;
##   - rest_undo, qui empeche les masques de glisser des qu'un os bouge.

const FACE_SHADER := preload("res://shaders/cel_face.gdshader")
const PAWS_SHADER := preload("res://shaders/cel_paws.gdshader")
const CelStyle := preload("res://scripts/systems/cel_style.gd")

# Le visage porte un shader dedie : yeux, nez, bouche et moustaches y sont
# DESSINES, jamais modelises. Voir "Visual Art Direction" §2bis.
#
# DEUX surfaces le portent. Le masque etant calcule en espace objet, il coule
# d'une surface a l'autre sans couture : le nez et la bouche atterrissent sur
# le museau qui depasse, pas sur le crane derriere lui.
const FACE_MATERIALS := ["visage", "museau_peint"]

# Moustaches : (depart.xy, arrivee.xy) en espace facial, cote droit seulement
# — le shader passe par |x| et dessine les deux cotes.
# Godot n'accepte pas de valeur par defaut sur un tableau d'uniforms.
# Portee volontairement limitee : au-dela de ~0,62 la moustache atteint le bord
# du cone facial et se ferait couper net par face_front_min.
const WHISKERS := [
	Vector4(0.16, -0.08, 0.60, 0.06),
	Vector4(0.17, -0.13, 0.63, -0.09),
	Vector4(0.16, -0.18, 0.58, -0.24),
]

# LES GRIFFES (2026-08-16) — trois traits par patte, DESSINES.
#
# Meme methode que les moustaches : des segments SDF dans un espace local
# projete, rien de modelise (§2bis). Ce qui change, c'est l'ancrage.
#
# Le visage tient sur UN os (`tete`), les oreilles sur deux que le signe de x
# separe. Les extremites creme en portent CINQ, et c'est ce qui avait fait
# renoncer a les peindre en shader (voir tools/paint_tuxedo.py). La sortie :
# `BONE_INDICES` est lisible dans le vertex shader de Godot 4 — verifie sur
# 4.7.1 — donc on choisit la matrice PAR SOMMET d'apres son os porteur, au lieu
# de la deviner d'apres un signe de coordonnee.
#
# Boites de repos relevees sur le .glb par tools/dump_paws.gd, jamais estimees.
# Le bout de queue (`queue_3`) partage le materiau mais n'est pas dans la liste :
# il n'a pas de griffes, et il sort du shader sans en recevoir.
const PAW_MATERIAL := "fourrure_blanche"
const PAWS := [
	{
		"bone": "pattavant_L",
		"center": Vector3(-0.255, 0.075, 0.373),
		"radius": Vector3(0.087, 0.109, 0.106),
	},
	{
		"bone": "pattavant_R",
		"center": Vector3(0.255, 0.075, 0.373),
		"radius": Vector3(0.087, 0.109, 0.106),
	},
	{
		"bone": "piedar_L",
		"center": Vector3(-0.285, 0.060, -0.415),
		"radius": Vector3(0.081, 0.088, 0.117),
	},
	{
		"bone": "piedar_R",
		"center": Vector3(0.285, 0.060, -0.415),
		"radius": Vector3(0.081, 0.088, 0.117),
	},
]

# Trois griffes par patte : (depart.xy, arrivee.xy) en espace patte, comme
# WHISKERS l'est en espace facial. Le repere est deja normalise par les
# demi-axes de la patte, donc ces valeurs sont des fractions de patte.
#
# Elles s'evasent vers le bas et celle du MILIEU porte le plus loin — trois
# traits egaux et paralleles se liraient comme une fourchette, exactement le
# defaut evite sur la griffure de l'attaque (`claw_slash.gdshader`).
#
# Portee volontairement bornee a ~0,55 du centre : au-dela le trait atteint le
# bord du cone avant (`claw_front_min`) et se ferait trancher net en plein
# milieu, comme les moustaches trop longues sur le visage.
const CLAWS := [
	Vector4(-0.40, 0.22, -0.27, -0.36),
	Vector4(0.00, 0.30, 0.00, -0.44),
	Vector4(0.40, 0.22, 0.27, -0.36),
]

# La bavette blanche du chat tuxedo — le bas du visage, museau compris.
#
# Elle est DESSINEE en espace facial, comme les yeux et le nez, et pour la
# meme raison : rien de tout ca n'est modelise (§2bis). C'est aussi le seul
# endroit ou elle peut vivre — le bas du visage n'est pas une coque a part,
# c'est la moitie basse de la sphere de tete.
#
# La frontiere n'est pas droite. Deux corrections, chacune pour une raison
# precise :
#   * `blaze_*` la fait remonter au centre — la liste blanche entre les yeux,
#     sans quoi le museau blanc parait colle sous un masque noir ;
#   * `falloff` la fait redescendre sur les cotes, pour que le blanc s'arrete
#     de lui-meme AVANT le bord du cone facial. Sans elle, la bavette serait
#     tranchee net par `face_front_min` et cette coupe se lirait comme un arc
#     de cercle sur la joue.
#
# Repere : les yeux sont a y = 0,14 et descendent a -0,05 ; la ligne passe donc
# sous eux partout, sauf la liste qui remonte entre les deux.
const BIB := {
	"line": -0.02,
	"falloff": 0.55,
	"blaze_height": 0.12,
	"blaze_width": 0.14,
}

# Palette par materiau — tiree de "Visual Art Direction" §4.
# Les materiaux du glTF ne transportent pas le look Blender (nodes custom),
# on repique donc les couleurs locales depuis la DA.
#
# CHAT TUXEDO (2026-08-16) — le roux ambre a laisse place au noir et blanc.
# Deux regles de la DA survivent au changement et le contraignent entierement :
# jamais de #000000 (§2bis), jamais de blanc froid (§5). Le noir est donc un
# brun tres sombre, le blanc un creme chaud — et le creme est volontairement
# plus clair que le parquet #E8D4A8, sans quoi le chat s'y fondrait.
const NOIR := Color("#4A4038")
const BLANC := Color("#F7EFE0")

const PALETTE := {
	"fourrure": NOIR,
	# Le dos reste d'un cran plus sombre que le reste du pelage, comme du temps
	# du chat roux : c'est ce qui detache la tete du corps en vue plongeante.
	"corps_peint": Color("#40372F"),
	# Blanc par coherence seulement : cette surface est enfermee dans celle du
	# dos et ne se voit nulle part (mesure en tete de PAINTED). Le plastron
	# qu'on voit vraiment est peint sur `corps_peint`.
	"ventre": BLANC,
	"visage": NOIR,
	# Museau blanc — il prolonge la bavette dessinee par cel_face.gdshader, et
	# les deux DOIVENT partager exactement la meme couleur : le museau depasse
	# au milieu de la bavette, une nuance d'ecart et la couture se verrait.
	"museau_peint": BLANC,
	# Bouts de patte et bout de queue. Surface creee dans Blender par
	# tools/paint_tuxedo.py — voir ce script pour pourquoi un masque en shader
	# ne pouvait pas s'en charger.
	"fourrure_blanche": BLANC,
	# L'oreille n'est pas rose en entier : couleur pelage dehors, rose PEINT
	# dedans (voir PAINTED). Un chat n'a de rose que l'interieur du pavillon.
	"oreille_peinte": NOIR,
}
const FALLBACK_COLOR := NOIR

# Trait par materiau. Le trait doit rester plus sombre que l'aplat qu'il cerne,
# ET que son ton d'ombre — sinon il se lit comme une lumiere, pas comme de
# l'encre. Sur la fourrure noire, INK (#3D2B1A, §4) ne remplit plus cette
# condition : l'ombre du noir descend a ~#302B23, sous le trait. On passe donc
# a un brun plus profond pour ces surfaces-la, toujours pas un noir pur.
const INK_SOMBRE := Color("#1A120C")
const INKS := {
	"fourrure": INK_SOMBRE,
	"corps_peint": INK_SOMBRE,
	"visage": INK_SOMBRE,
	"oreille_peinte": INK_SOMBRE,
}

# Surfaces blanches. Elles partagent un travers que le chat roux n'avait pas :
# le trait colore de §5.4 melange 20 % vers la couleur locale, et ce melange se
# fait en LINEAIRE. Vers un creme a 0,93 de luminance lineaire, 20 % suffisent
# a remonter le trait a ~#82796F — un gris delave, plus une encre. On garde
# donc la teinte, mais a la dose qui rend le meme ecart PERCU.
const OUTLINE_TINT := 0.2
const OUTLINE_TINT_CLAIR := 0.06
const MATERIAUX_BLANCS := ["ventre", "museau_peint", "fourrure_blanche"]

# Details peints par calotte procedurale — la methode des yeux, appliquee ici
# a l'interieur d'oreille. Voir "Visual Art Direction" §2bis.
#
# Le cone d'oreille est CONSERVE : contrairement aux yeux, la geometrie de
# l'oreille EST la silhouette (§3, "oreilles tres visibles et pointues").
# Ce qui disparait, c'est la surface rose separee qui produisait une tache
# plate sans contour sur le crane.
#
# Reperes en espace objet Godot (glTF Y-up) : Blender (x, y, z) -> (x, z, -y).
# Oreille Blender (0.281, -0.622, 1.592) -> Godot (0.281, 1.592, 0.622).
# Le z Blender est passe de 1,472 a 1,592 le 2026-08-16 : les cones d'oreille
# et leurs os ont ete remontes de 0,12 pour degager le crane (0,19 -> 0,30).
const PAINTED := {
	# LE PLASTRON. Il est peint sur `corps_peint` — le dos — et surtout PAS sur
	# `ventre`, dont c'est pourtant le nom.
	#
	# Mesure du 2026-08-16 : la sphere `ventre` est enfermee dans celle du dos.
	# Elle ne depasse que de 0,03 sur l'avant, et un test de visibilite (ventre
	# peint en magenta, tour de camera 8 directions) ne lui trouve que ~0,02 %
	# de l'image, sur trois vues de profil. La colorer ne se voit pas.
	#
	# La surface reellement exposee sous la tete est celle du dos. Elle tient
	# sur UN os (`dos`), donc rest_undo suffit a l'ancrer, exactement comme le
	# visage sur `tete`.
	#
	# Ellipsoide du dos, mesure sur le .glb : centre (0, 0.64, -0.05),
	# demi-axes (0.40, 0.35, 0.56) — d'ou le squash, qui est son inverse.
	"corps_peint": {
		"center": Vector3(0.0, 0.64, -0.05),
		"squash": Vector3(1.0, 1.14, 0.71),
		"mirror_x": false,
		# Vers l'avant, legerement vers le bas : gorge et poitrail.
		"dirs": [Vector3(0.0, -0.45, 0.90)],
		"thresholds": [0.22],
		"colors": [BLANC],
		# Une autre couleur de pelage, pas un aplat graphique : elle a son ombre.
		"shaded": true,
	},
	"oreille_peinte": {
		"center": Vector3(0.281, 1.592, 0.622),
		# L'oreille est mince en Z : on etire cet axe pour que le masque
		# soit pilote par l'avant/arriere et non par la hauteur.
		"squash": Vector3(1.0, 0.6, 3.0),
		"mirror_x": true,
		# Interieur du pavillon : vers l'avant (+Z), legerement ecarte (+X),
		# l'oreille etant lacet de ~23° vers l'exterieur dans Blender.
		"dirs": [Vector3(0.3, 0.0, 0.95)],
		"thresholds": [0.02],
		"colors": [Color("#E8B8A8")],
	},
}

# Quel os defaire pour retrouver la position de repos, par materiau.
# Deuxieme entree = os du cote droit, pour une paire symetrique que |x|
# dessine d'un seul jeu de formes. Voir "Pipeline 3D", piege n°4.
const REST_UNDO_BONES := {
	"visage": ["tete", ""],
	"museau_peint": ["tete", ""],
	"corps_peint": ["dos", ""],
	"oreille_peinte": ["oreille_L", "oreille_R"],
}

# Clips portes par le .glb, construits par tools/build_animations.py.
const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"

# L'os racine — le seul dont la TRANSLATION deplace tout le personnage.
# Voir _smooth_root_translation().
const ROOT_BONE := &"racine"

@export_file("*.glb") var model_path: String = "res://assets/models/player_cat.glb"

## Le chat regarde +Z apres la conversion Y-up du glTF, alors que l'avant de
## Godot est -Z ("Pipeline 3D", ecart n°3). Le jeu met 180 pour le remettre
## dans le bon sens ; le banc de test garde 0, sa convention de captures
## considerant 0° comme la vue de face.
@export var yaw_offset_deg: float = 0.0

## Epaisseur du contour, en unites monde. A garder proportionnelle a la
## taille du modele (§11).
##
## Relevee de 0,035 a 0,041 avec l'arrivee d'`Attr_Style` : le canal R module
## desormais l'epaisseur et vaut ~0,85 en moyenne, la valeur d'avant donnait
## donc un trait globalement plus maigre qu'avant. 0,041 x 0,85 ≈ 0,035.
@export var outline_thickness: float = 0.041

## Attr_Style existe dans le `.glb` depuis le 2026-08-16 : R module le trait,
## G porte les ombres peintes, B autorise les accents. Voir `tools/export_cat.py`
## — l'exporteur glTF ne sait pas sortir cet attribut tout seul.
@export var use_vertex_style: bool = true

## Bord de cluster legerement irregulier — un bord de pinceau, pas une courbe
## mathematique (§2ter·2). Le shader en prend la moitie de part et d'autre :
## 0,06 donne le ±0,03 que demande Convention Blender §5.3.
@export var edge_noise: float = 0.06

## Accent de brillance sur le dessus des volumes, masque par le canal B.
## Le seul ecart autorise a la regle des 2 tons (§5.5).
##
## Abaisse de 0,35 a 0,12 avec le pelage tuxedo : l'accent est un MELANGE vers
## le creme, donc son effet depend de ce qu'il eclaircit. Sur l'ambre d'avant
## il montait la valeur de 0,85 a 0,89 — un souffle. Sur le noir il la ferait
## passer de 0,29 a 0,52, et le dessus du chat virerait au gris : un troisieme
## ton de cluster en pleine violation de §5.5.
@export var accent_strength: float = 0.12

## Bascule du repere facial. Compromis de cadrage sous une camera qui plonge :
## trop bas le visage passe sous l'horizon, trop haut il reste visible de dos.
@export var face_pitch_deg: float = 26.0

## Sortir la translation de l'os racine de la cadence en pas — voir
## _smooth_root_translation(). A false, le chat retrouve le rebond en escalier
## d'avant le 2026-08-16 : c'est ce qui permet de MESURER ce que le lissage
## apporte, au lieu de le supposer. Se coupe aussi en ligne de commande, par
## `--root-step`, comme les autres reglages comparables.
@export var smooth_root: bool = true

var mesh_instance: MeshInstance3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer

var toon_materials: Array[ShaderMaterial] = []
var outline_materials: Array[ShaderMaterial] = []
var face_materials: Array[ShaderMaterial] = []
var paint_counts: Array[int] = []

# Le materiau des extremites creme, celui qui porte les griffes. Une seule
# surface le porte — d'ou un champ et non un tableau.
var paw_material: ShaderMaterial

# ShaderMaterial -> [nom d'os gauche/unique, nom d'os droit ou ""]
var _skinned_paint := {}


func _ready() -> void:
	# La bascule du visage est indissociable de la plongee de la camera : la
	# comparer en ligne de commande evite de juger une plongee avec un visage
	# regle pour une autre.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--face-pitch="):
			face_pitch_deg = float(arg.trim_prefix("--face-pitch="))
		elif arg == "--root-step":
			smooth_root = false

	mesh_instance = _spawn_model()

	if mesh_instance == null:
		push_warning("cel_model : aucun MeshInstance3D trouve dans %s" % model_path)
		set_process(false)
		return

	# ⚠️ Le chat RECOIT le soleil et ne le PROJETTE pas — meme regle que les
	# creatures, meme raisons, ecrites en tete de `cel_prop._apply()`. Ici elle
	# se voit au banc : sans ca, une oreille pose une bande dure en travers du
	# crane, et c'est l'ombre PROPRE que §6bis garde peinte.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	skeleton = mesh_instance.get_parent() as Skeleton3D
	_apply_cel_materials()
	_setup_claws()
	_setup_animations()

	# rest_undo doit se calculer sur la pose de la frame COURANTE, donc APRES
	# que l'AnimationPlayer l'ait ecrite. Ce player est un descendant, et un
	# parent est traite avant ses enfants : sans cette priorite, la peinture
	# du visage travaillerait sur la pose de la frame precedente et decalerait
	# d'une frame a chaque changement de pose.
	# (Godot : priorite plus haute = traite plus tard.)
	process_priority = 100

	# Sans surface peinte ni squelette, rest_undo reste l'identite pour
	# toujours : inutile de le recalculer a chaque frame.
	set_process(skeleton != null and (not _skinned_paint.is_empty() or paw_material != null))


## Recalcule, pour chaque surface peinte, la transformation qui ramene un
## sommet deforme a sa position de repos. Sans ca, tout ce qui est peint
## (visage, interieur d'oreille) glisse sur la geometrie des qu'un os bouge.
func _process(_delta: float) -> void:
	update_rest_undo()


# ------------------------------------------------------------------ mise en place

func _spawn_model() -> MeshInstance3D:
	var packed: PackedScene = load(model_path)

	if packed == null:
		return null

	var model := packed.instantiate() as Node3D
	add_child(model)
	model.rotation_degrees.y = yaw_offset_deg
	animation_player = _find_node(model, "AnimationPlayer") as AnimationPlayer
	return _find_node(model, "MeshInstance3D") as MeshInstance3D


func _find_node(node: Node, type_name: StringName) -> Node:
	if node.is_class(type_name):
		return node

	for child in node.get_children():
		var found := _find_node(child, type_name)

		if found != null:
			return found

	return null


func _apply_cel_materials() -> void:
	var mesh := mesh_instance.mesh

	for i in mesh.get_surface_count():
		var source := mesh.surface_get_material(i)
		var mat_name := source.resource_name if source else ""
		var color: Color = PALETTE.get(mat_name, FALLBACK_COLOR)
		var is_face: bool = mat_name in FACE_MATERIALS

		var toon_mat := CelStyle.make_outlined(
			color,
			outline_thickness,
			INKS.get(mat_name, CelStyle.INK),
			OUTLINE_TINT_CLAIR if mat_name in MATERIAUX_BLANCS else OUTLINE_TINT,
		)
		var caps := 0

		if mat_name == PAW_MATERIAL:
			# Meme base cel, plus les griffes. Le shader dedie existe pour une
			# raison de skinning, pas de style : voir son en-tete.
			toon_mat.shader = PAWS_SHADER
			toon_mat.set_shader_parameter("base_color", color)
			toon_mat.set_shader_parameter("claws", PackedVector4Array(CLAWS))
			paw_material = toon_mat

		if is_face:
			toon_mat.shader = FACE_SHADER
			toon_mat.set_shader_parameter("base_color", color)
			toon_mat.set_shader_parameter("whiskers", PackedVector4Array(WHISKERS))
			toon_mat.set_shader_parameter("face_pitch_deg", face_pitch_deg)
			toon_mat.set_shader_parameter("bib_color", BLANC)
			toon_mat.set_shader_parameter("bib_line", BIB["line"])
			toon_mat.set_shader_parameter("bib_falloff", BIB["falloff"])
			toon_mat.set_shader_parameter("bib_blaze_height", BIB["blaze_height"])
			toon_mat.set_shader_parameter("bib_blaze_width", BIB["blaze_width"])
			face_materials.append(toon_mat)
		else:
			caps = _apply_painted_caps(toon_mat, mat_name)
			toon_mat.set_shader_parameter("accent_strength", accent_strength)

		# Attr_Style : le chat est le seul maillage a le porter. Le reste du
		# jeu garde use_vertex_style a false, sinon COLOR y vaudrait 1.0 et
		# tout partirait en pleine lumiere avec le trait le plus epais.
		toon_mat.set_shader_parameter("use_vertex_style", use_vertex_style)
		toon_mat.set_shader_parameter("edge_noise", edge_noise)
		(toon_mat.next_pass as ShaderMaterial).set_shader_parameter(
			"use_vertex_style", use_vertex_style
		)

		# Ne jamais laisser une mat4 d'uniform a sa valeur par defaut : une
		# matrice nulle ferait s'effondrer tout le masque.
		toon_mat.set_shader_parameter("rest_undo", Transform3D.IDENTITY)
		toon_mat.set_shader_parameter("rest_undo_right", Transform3D.IDENTITY)

		if REST_UNDO_BONES.has(mat_name):
			var bones: Array = REST_UNDO_BONES[mat_name]
			_skinned_paint[toon_mat] = bones

			if bones[1] != "":
				toon_mat.set_shader_parameter("rest_undo_split", true)

		mesh_instance.set_surface_override_material(i, toon_mat)

		toon_materials.append(toon_mat)
		outline_materials.append(toon_mat.next_pass as ShaderMaterial)
		paint_counts.append(caps)


## Le glTF transporte les clips mais pas leur mode de boucle : Godot les
## importe tous en LOOP_NONE, et le chat se figerait sur sa derniere pose.
func _setup_animations() -> void:
	if animation_player == null:
		return

	for anim_name in animation_player.get_animation_list():
		var anim := animation_player.get_animation(anim_name)

		if anim.loop_mode == Animation.LOOP_NONE:
			anim.loop_mode = Animation.LOOP_LINEAR

		# Le mode de boucle d'abord : l'interpolation a besoin de savoir que la
		# piste se referme, sinon elle rate le raccord de fin de cycle.
		_smooth_root_translation(anim)

	# Aucun fondu entre clips. Un fondu interpole les deux poses pendant sa
	# duree — soit exactement le glissement que la cadence en pas existe pour
	# supprimer. "Pose a pose, jamais de flux continu" ("Convention Blender"
	# §6.3) : le passage idle <-> walk est une coupe franche, comme au montage.
	animation_player.playback_default_blend_time = 0.0

	play(ANIM_IDLE)


## Sort la TRANSLATION de l'os racine de la cadence en pas. Les rotations,
## elles, n'y touchent pas : elles restent en NEAREST, et c'est tout le style.
##
## POURQUOI CETTE EXCEPTION, ET POURQUOI ELLE SEULE
## ------------------------------------------------
## "Visual Art Direction" §7 pose deja la regle, et elle est categorique :
## *"Seule l'animation du squelette est en pas ; la position du personnage
## dans l'arene ne l'est pas."* Le rebond de marche est une POSITION — il
## souleve le chat tout entier — mais il vivait du cote squelette par simple
## accident d'implementation (`racine.ty` dans tools/build_animations.py). Il
## echappait donc a la regle sans que personne l'ait decide.
##
## Ce que ca donnait, mesure sur les frames du jeu le 2026-08-16 : le centroide
## vertical de la silhouette sautait jusqu'a 2,5 px d'un coup toutes les
## 3 frames, et restait parfaitement fige entre deux. Pendant ce temps le sol,
## lui, defilait a chaque frame. C'est cette contradiction qui se lit comme un
## a-coup — l'oeil SUIT le chat, donc il lit chaque saut de sa position, alors
## qu'il ne lit pas la cadence d'une patte qui pivote.
##
## D'ou l'exception, bornee a l'os racine : lui seul deplace tout le monde.
##
## ⚠️ CHANGER L'INTERPOLATION NE SUFFIT PAS, ET L'ESSAYER SEUL NE PREVIENT PAS.
## L'importateur reechantillonne a `animation/fps` (60, voir le `.import`), donc
## la piste arrive avec UNE CLE PAR FRAME : huit poses reelles noyees dans 25
## cles, les redondantes reprenant la valeur de la precedente. En NEAREST elles
## sont inoffensives — c'est ecrit dans _on_step_grid() — mais interpoler entre
## deux cles egales rend cette meme valeur : la courbe reste clouee a son
## escalier. Mesure : la silhouette sautait toujours, avec seulement quelques
## valeurs intermediaires egarees entre deux marches. Il faut donc DEDOUBLONNER
## d'abord, et interpoler ensuite.
##
## LINEAR et non CUBIC. Sur quatre echantillons par rebond, la cubique passe
## SOUS zero dans les creux (mesure : -0,0125) — le chat s'enfonce dans le
## parquet, quand `bounce()` dit en toutes lettres "jamais sous zero". Et le
## creux d'un rebond est un CHOC : un bas anguleux et un haut arrondi sont plus
## justes que l'inverse.
##
## ⚠️ Ne pas etendre aux autres os. Une patte, une oreille, la queue : leur
## deplacement est local, il se lit comme une pose, et c'est precisement ce que
## §7 veut voir claquer.
func _smooth_root_translation(anim: Animation) -> void:
	if not smooth_root:
		return

	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue

		if anim.track_get_path(track).get_subname(0) != ROOT_BONE:
			continue

		_keep_only_real_poses(anim, track)
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)


## Retire d'une piste les cles qui repetent la precedente — celles que
## l'importateur a fabriquees en reechantillonnant a 60 fps. Ne reste que les
## poses reellement posees dans Blender, aux instants ou la valeur CHANGE.
func _keep_only_real_poses(anim: Animation, track: int) -> void:
	# ⚠️ Les deux seules Variant qui restent dans le jeu, et elles le restent
	# expres : une cle d'animation vaut un Vector3 sur une piste de position et
	# un Quaternion sur une piste de rotation. Aucun type ne les couvre, et
	# `is_equal_approx` existe sur les deux — c'est du duck typing assume, sur
	# une API du moteur, pas entre deux scripts du projet.
	var kept := []
	var previous = null

	for key in anim.track_get_key_count(track):
		var value = anim.track_get_key_value(track, key)

		if previous != null and value.is_equal_approx(previous):
			continue

		kept.append([anim.track_get_key_time(track, key), value])
		previous = value

	# Rien a gagner, et surtout rien a casser : une piste deja propre (ou qui
	# ne bouge pas du tout) sort d'ici intacte.
	if kept.size() == anim.track_get_key_count(track):
		return

	for key in range(anim.track_get_key_count(track) - 1, -1, -1):
		anim.track_remove_key(track, key)

	for entry in kept:
		anim.track_insert_key(track, entry[0], entry[1])


## Bascule de clip. Sans effet si le clip demande tourne deja — sinon chaque
## appel relancerait la boucle a zero et le chat piétinerait sur place.
func play(anim_name: StringName) -> void:
	if animation_player == null or not animation_player.has_animation(anim_name):
		return

	if animation_player.current_animation == anim_name:
		return

	animation_player.play(anim_name)


func _apply_painted_caps(mat: ShaderMaterial, mat_name: String) -> int:
	if not PAINTED.has(mat_name):
		return 0

	var cfg: Dictionary = PAINTED[mat_name]
	var dirs := PackedVector3Array(cfg["dirs"])
	var thresholds := PackedFloat32Array(cfg["thresholds"])
	var colors := PackedColorArray(cfg["colors"])
	var count: int = cfg["dirs"].size()

	# Les tableaux du shader ont une taille fixe de 3 : on complete.
	while dirs.size() < 3:
		dirs.append(Vector3.FORWARD)
		thresholds.append(2.0)  # seuil inatteignable = calotte inactive
		colors.append(Color.MAGENTA)

	mat.set_shader_parameter("paint_count", count)
	mat.set_shader_parameter("paint_shaded", cfg.get("shaded", false))
	mat.set_shader_parameter("paint_center", cfg["center"])
	mat.set_shader_parameter("paint_squash", cfg["squash"])
	mat.set_shader_parameter("paint_mirror_x", cfg["mirror_x"])
	mat.set_shader_parameter("paint_dir", dirs)
	mat.set_shader_parameter("paint_threshold", thresholds)
	mat.set_shader_parameter("paint_color", colors)

	return count


## Apparie chaque patte a son os. Fait UNE fois : les identifiants d'os ne
## bougent pas, seules leurs matrices changent d'une frame a l'autre.
##
## Si un os manque a l'appel, on n'en dessine aucun plutot que quelques-uns :
## trois griffes sur deux pattes se liraient comme un bug d'affichage, pas
## comme un choix.
func _setup_claws() -> void:
	if paw_material == null or skeleton == null:
		return

	var ids := PackedInt32Array()

	for paw in PAWS:
		var id := skeleton.find_bone(paw["bone"])

		if id == -1:
			push_warning("cel_model : os de patte introuvable (%s) — griffes desactivees"
					% paw["bone"])
			return

		ids.append(id)

	paw_material.set_shader_parameter("claw_bone", ids)
	paw_material.set_shader_parameter("claw_paws", ids.size())


# ----------------------------------------------------------------------- reglages

func update_rest_undo() -> void:
	if skeleton == null:
		return

	for mat in _skinned_paint:
		var bones: Array = _skinned_paint[mat]
		mat.set_shader_parameter("rest_undo", _bone_undo(bones[0]))

		if bones[1] != "":
			mat.set_shader_parameter("rest_undo_right", _bone_undo(bones[1]))

	_update_paws()


## Une matrice par patte, refaite a chaque frame comme rest_undo — et pour la
## meme raison : sans elle les griffes glisseraient sur le chausson des que la
## patte bouge.
##
## Elle fait tout le trajet d'un coup : defaire l'os, recentrer sur la patte,
## diviser par ses demi-axes. Le shader recoit donc une position deja normalisee
## et n'a plus qu'a la projeter — les mesures restent ici, en un seul endroit.
func _update_paws() -> void:
	if paw_material == null:
		return

	var matrices := []

	for paw in PAWS:
		var r: Vector3 = paw["radius"]
		var into_paw := Transform3D(
			Basis.from_scale(Vector3(1.0 / r.x, 1.0 / r.y, 1.0 / r.z)), Vector3.ZERO
		) * Transform3D(Basis.IDENTITY, -paw["center"])
		matrices.append(into_paw * _bone_undo(paw["bone"]))

	paw_material.set_shader_parameter("paw_undo", matrices)


## Inverse du delta repos -> pose de l'os. Identite quand l'os est au repos.
## Exact parce que le rig est en poids rigides ("Pipeline 3D", piege n°3).
func _bone_undo(bone_name: String) -> Transform3D:
	var bone := skeleton.find_bone(bone_name)

	if bone == -1:
		return Transform3D.IDENTITY

	var deform := skeleton.get_bone_global_pose(bone) * skeleton.get_bone_global_rest(bone).affine_inverse()
	return deform.affine_inverse()


## Etat de `Attr_Style` tel que Godot le voit reellement, par surface.
##
## Diagnostic, pas decoration : l'attribut a deja traverse le pont a moitie
## (l'exporteur glTF ne remplissait qu'une primitive sur six, voir
## `tools/export_cat.py`). C'est aussi ce qui prouve qu'aucune conversion
## sRGB ne s'applique au passage — un G peint a 0,47 doit arriver a 0,47.
func style_report() -> Array[String]:
	var lines: Array[String] = []

	if mesh_instance == null:
		return lines

	var mesh := mesh_instance.mesh

	for i in mesh.get_surface_count():
		var source := mesh.surface_get_material(i)
		var mat_name := source.resource_name if source else "<sans nom>"
		var colors: PackedColorArray = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]

		if colors.is_empty():
			lines.append("  %-15s COLOR_0 ABSENT" % mat_name)
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
		lines.append("  %-15s R %.2f/%.2f/%.2f  G %.2f/%.2f/%.2f  B %.2f/%.2f/%.2f" % [
			mat_name,
			lo.x, mean.x, hi.x,
			lo.y, mean.y, hi.y,
			lo.z, mean.z, hi.z,
		])

	return lines


## Etat des animations tel que Godot les voit, apres le pont glTF.
##
## Diagnostic, pas decoration — meme role que style_report() pour Attr_Style.
## La cadence en pas ("Visual Art Direction" §7) ne vit dans aucun code : elle
## est ENTIEREMENT portee par l'interpolation des pistes. Une seule piste
## revenue en LINEAR et le chat se remet a glisser, sans que rien ne casse ni
## ne previenne. C'est exactement le piege n°4 de "Pipeline 3D".
##
## Lecture : NEAREST = en pas (STEP cote glTF), LINEAR = cadence perdue.
func animation_report() -> Array[String]:
	var lines: Array[String] = []

	if animation_player == null:
		lines.append("  aucun AnimationPlayer dans le .glb")
		return lines

	for anim_name in animation_player.get_animation_list():
		var anim := animation_player.get_animation(anim_name)
		var keys := 0
		var changes := 0
		var off_grid := 0
		var lisses: Array[String] = []
		var racine_en_pas: Array[String] = []

		for track in anim.get_track_count():
			var count := anim.track_get_key_count(track)
			keys += count
			var moves := false

			for key in range(1, count):
				if anim.track_get_key_value(track, key) == anim.track_get_key_value(track, key - 1):
					continue

				moves = true
				changes += 1

				if not _on_step_grid(anim.track_get_key_time(track, key)):
					off_grid += 1

			if not moves:
				continue

			var interpolation := anim.track_get_interpolation_type(track)
			var is_root_translation := (
				anim.track_get_type(track) == Animation.TYPE_POSITION_3D
				and anim.track_get_path(track).get_subname(0) == ROOT_BONE
			)

			# LA TRANSLATION DE L'OS RACINE EST L'EXCEPTION, et elle se
			# surveille a l'envers des autres : c'est la seule piste qui doit
			# etre LISSE, parce qu'elle deplace le chat tout entier (§7, et
			# _smooth_root_translation() pour le detail). La retrouver en pas
			# signifie que la passe de lissage n'a pas tourne — et le chat
			# recommencerait a sauter de 2,5 px toutes les 3 frames.
			if is_root_translation:
				if interpolation == Animation.INTERPOLATION_NEAREST:
					racine_en_pas.append(String(anim.track_get_path(track)))

				continue

			# Partout ailleurs, seule une piste qui BOUGE et qui n'est pas en
			# NEAREST casse la cadence. Godot en fabrique beaucoup d'autres
			# (position et echelle par os) qui restent a leur valeur de repos :
			# elles sont en LINEAR et parfaitement inoffensives, les compter
			# alarmerait pour rien.
			if interpolation != Animation.INTERPOLATION_NEAREST:
				lisses.append(String(anim.track_get_path(track)))

		lines.append("  %-10s %5.2fs  %2d pistes  %3d cles  %3d changements dont %d hors grille  boucle %s" % [
			anim_name, anim.length, anim.get_track_count(), keys, changes, off_grid,
			"oui" if anim.loop_mode != Animation.LOOP_NONE else "non",
		])

		if lisses.is_empty():
			lines.append("             cadence en pas intacte — aucune piste mobile interpolee")
		else:
			lines.append("             ⚠ %d piste(s) mobile(s) NON en pas : %s"
					% [lisses.size(), ", ".join(lisses)])

		if not racine_en_pas.is_empty():
			lines.append("             ⚠ translation de `%s` restee EN PAS : %s"
					% [ROOT_BONE, ", ".join(racine_en_pas)])

	return lines


## Une pose tombe-t-elle sur la grille de 3 frames a 60 fps ?
##
## Compter les cles ne mesure PAS la cadence : l'importateur de Godot
## reechantillonne a `animation/fps` (30 par defaut — a mettre a 60 dans le
## .import, sinon la grille de 3 est deja perdue a l'import). Il en resulte
## beaucoup de cles redondantes, et elles sont inoffensives : en NEAREST, une
## cle qui reprend la valeur precedente ne fait rien voir.
##
## Ce qui compte est l'instant ou la valeur CHANGE. Un seul changement entre
## deux marches ajoute une pose que personne n'a posee, et la cadence cesse
## d'etre sur 3s sans que rien ne casse ni ne previenne.
func _on_step_grid(time: float) -> bool:
	var frame := time * 60.0
	return absf(frame - roundf(frame / 3.0) * 3.0) < 0.02


func set_face_pitch(value: float) -> void:
	face_pitch_deg = clampf(value, 0.0, 60.0)

	for mat in face_materials:
		mat.set_shader_parameter("face_pitch_deg", face_pitch_deg)


func set_outline_enabled(enabled: bool) -> void:
	for i in toon_materials.size():
		toon_materials[i].next_pass = outline_materials[i] if enabled else null


func set_paint_enabled(enabled: bool) -> void:
	for i in toon_materials.size():
		toon_materials[i].set_shader_parameter(
			"paint_count", paint_counts[i] if enabled else 0
		)

	# Le visage se coupe autrement : un seuil d'orientation inatteignable.
	for mat in face_materials:
		mat.set_shader_parameter("face_front_min", 0.12 if enabled else 2.0)

	# Les griffes sont un detail peint comme les autres : la bascule du banc
	# doit les emporter, sinon on croit comparer une silhouette nue alors qu'il
	# reste du dessin dessus.
	if paw_material != null:
		paw_material.set_shader_parameter("claw_paws", PAWS.size() if enabled else 0)
