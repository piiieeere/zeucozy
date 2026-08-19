extends RefCounted

## ⭐ LA VIGNETTE D'UNE COMPETENCE — une pose de son FX, rendue pour de vrai.
##
## Sur une carte de choix, le titre et la description disent ce que fait l'arme ;
## rien ne disait a quoi elle RESSEMBLE. Le joueur qui a deja vu une boule de
## poils a l'ecran ne pouvait pas relier la carte au dessin, et un survivor se
## joue trop vite pour lire trois descriptions.
##
## ─── ELLE EST RENDUE, PAS DESSINEE UNE SECONDE FOIS ───
##
## C'est LE point de ce fichier, et c'est la lecon que ce projet a payee entre
## Blender et Godot : deux dessins de la meme chose divergent, toujours. Une
## vignette redessinee en `canvas_item` serait un deuxieme jeu de couleurs, de
## seuils et d'epaisseurs a tenir synchronise a la main — et le jour ou la gueule
## de la morsure passerait du brun au rouge, la carte garderait le brun sans que
## rien ne le signale.
##
## Ici la vignette EST le shader du jeu, avec ses couleurs a lui, fige sur une
## pose. Le seul chemin possible, les six FX etant des `shader_type spatial` :
## un SubViewport, une camera ORTHOGONALE, un quad. Rien de tout ca n'est
## reproductible en shader d'UI.
##
## ⚠️ ET LE `size` EST CELUI DU JEU, jamais un chiffre de vignette. Trois FX
## expriment une epaisseur de trait en METRES (`ink_world` de l'haleine,
## l'encre du feulement, celle du mouton) : la reduire pour "faire tenir" le
## dessin epaissirait son cerne en proportion, et la vignette montrerait un
## dessin que le jeu ne produit jamais. C'est la CAMERA qui cadre — `frame` est
## une distance en metres, pas un facteur d'echelle.
##
## ─── Ce qu'elle ne fait PAS ───
##
##   • Elle n'anime pas. Une pose, tenue. Six vignettes qui bougent derriere un
##     choix a faire, c'est six choses qui tirent l'oeil au moment ou il doit se
##     poser — et §9.3 regle 1 dit que l'ecran appartient au jeu.
##   • Elle n'existe pas pour les PASSIFS. Un passif n'est jamais dessine dans le
##     jeu ; lui inventer une image serait lui inventer une presence a l'ecran
##     qu'il n'a pas. La carte se replie proprement sans elle.

const CelProp := preload("res://scripts/systems/cel_prop.gd")

const CLAW_SHADER := preload("res://shaders/claw_slash.gdshader")
const BITE_SHADER := preload("res://shaders/bite.gdshader")
const HISS_SHADER := preload("res://shaders/hiss_ring.gdshader")
const DUST_SHADER := preload("res://shaders/dust_bunny.gdshader")
const BREATH_SHADER := preload("res://shaders/breath_aura.gdshader")
const PURR_SHADER := preload("res://shaders/purr_halo.gdshader")

## Le rendu, en px. Carre — la camera orthogonale a alors le meme cadrage en
## largeur qu'en hauteur, et `frame` reste UN nombre au lieu de deux.
const SIZE := 76

## Le sol de la vignette.
##
## ⚠️ IL EST CLAIR, ET C'EST LA SEULE VALEUR JUSTE — trouve en capture, contre
## l'intuition. Le premier essai etait le registre bas des cartons (`#22221F`,
## 0,13) : le raisonnement etait bon en UI (une fenetre est CREUSEE, comme une
## piste de jauge) et faux pour ce qu'elle contient. Le corps de la griffure est
## l'anthracite `#37393B` (0,22) et son encre le brun `#1A120C` (0,08) : sur un
## fond a 0,13, l'aplat ET le trait disparaissaient ensemble, et il ne restait
## que le liseré creme du coeur. La griffure sortait en trois fentes lumineuses.
##
## LA RAISON DE FOND : ces six FX sont dessines pour se lire sur le PARQUET, a
## ~0,84 de luminance. Leurs deux tons de cluster et leur encre sont doses contre
## ce fond-la et contre aucun autre. Une vignette sur fond sombre ne montre pas
## le FX plus discretement — elle en montre un AUTRE, dont le cluster est
## retombe a un seul ton (§2bis).
##
## D'ou un ble assourdi : la valeur du sol du jeu, descendue de ce qu'il faut
## pour que la fenetre reste une fenetre et non un trou de lumiere dans un carton
## gris. C'est la seule couleur chaude admise dans un carton (§9.5) — et elle est
## admise parce qu'elle n'est pas de l'interface : c'est le MONDE, vu au travers.
const BACKING := Color("#C4B594")

## Les six FX, et pour chacun : le shader du jeu, sa taille de jeu, la pose
## retenue, et le cadrage.
##
## ─── COMMENT LA POSE A ETE CHOISIE ───
##
## Toujours la pose la plus LISIBLE, jamais la premiere ni la derniere. Les FX de
## ce jeu naissent petits et meurent en s'affinant (§8 : "la dissipation se fait
## par la FORME") : leurs poses extremes sont precisement celles ou il n'y a rien
## a reconnaitre. On prend donc la pose pleine, celle qu'on retient d'un coup
## d'oeil en jouant.
##
## ⚠️ `seed` EST FIXE, et c'est le seul endroit du projet ou il l'est. Partout
## ailleurs il est tire au hasard pour que deux coups de suite ne soient pas le
## meme tampon ; ici la vignette doit etre la MEME a chaque ouverture de carton,
## sinon la carte ne devient jamais un objet reconnaissable.
const FX := {
	# La griffure. Pose 2 sur 6 : l'arc a fini de s'ouvrir et le trait est encore
	# epais. Apres, `thick` s'effile jusqu'au cheveu et les trois griffes ne se
	# distinguent plus l'une de l'autre a 76 px.
	"claw": {
		"shader": CLAW_SHADER,
		# 5,20 m de portee T1 x claw_slash.DRAW_SIZE (1,6).
		"size": 8.32,
		"frame": 4.1,
		# L'arc vit autour de +y, entre 1,4 et 3,1 m du centre : centre sur le
		# quad, il laisserait la moitie basse de la vignette vide.
		"offset": Vector3(0.0, -2.24, 0.0),
		"pose": {
			"aim": Vector3(0.0, 1.0, 0.0),
			"reach": 0.99, "span": 1.24, "thick": 0.104, "taper": 2.0, "roll": -0.02,
			"seed": 0.31,
		},
	},

	# La morsure. Pose 2 sur 8 — LE CLAQUEMENT, celle qui tient 6 crans en jeu et
	# la seule ou les crocs s'engrenent. Les poses ouvertes montrent deux arcs
	# separes, ce qui ne se lit pas comme une gueule.
	"bite": {
		"shader": BITE_SHADER,
		# 3,60 m de portee T1 x bite_fx.DRAW_SIZE (2,0).
		"size": 7.20,
		"frame": 4.7,
		# La gueule mord DEVANT son ancre (`jaw_offset` 0,585 unite de quad).
		"offset": Vector3(0.0, -2.11, 0.0),
		"pose": {
			"aim": Vector3(0.0, 1.0, 0.0),
			"gape": 0.320, "thick": 0.075, "tooth_len": 0.262, "taper": 1.3,
			"seed": 0.62,
		},
	},

	# Le feulement. Pose 4 sur 6 : l'onde a presque atteint sa portee, donc
	# l'anneau est grand et le bord dechiquete se lit. Aux premieres poses il est
	# petit et epais — un disque, pas une onde.
	"hiss": {
		"shader": HISS_SHADER,
		"size": 7.20,  # 3,60 m de rayon T1 x 2
		"frame": 7.7,
		"offset": Vector3.ZERO,
		"pose": {"ring": 0.90, "band": 0.056, "seed": 0.17},
	},

	# Le mouton de poussiere, au repos. `puff` 1,0 : la touffe pleine, avant le
	# pouf. C'est l'etat sous lequel le joueur la voit le plus longtemps.
	"dust": {
		"shader": DUST_SHADER,
		"size": 1.50,  # 0,75 m de rayon T1 x 2
		"frame": 1.75,
		"offset": Vector3.ZERO,
		"pose": {"puff": 1.00, "seed": 0.44},
	},

	# Le ronron, sur sa pose de SOIN (`purr_halo.HEAL_POSE` = 0) : les deux arches
	# pleines et le croissant creme ouvert au maximum. C'est la pose ou la
	# competence agit, et la seule ou le 2e ton du cluster existe — les cinq
	# autres la degonflent et referment le creme.
	#
	# ⚠️ SEUL FX DONT LE `size` N'EST PAS DERIVE D'UNE PORTEE. Les cinq autres
	# recopient ici un rayon de palier x un facteur de dessin ; le halo du ronron
	# ne promet aucune distance (voir l'en-tete de son shader), sa taille est une
	# constante du FX. Rien a tenir synchronise avec le catalogue.
	"purr": {
		"shader": PURR_SHADER,
		"size": 2.80,
		# Les arches vivent au-dessus du centre, entre 0,46 et 0,82 de rayon :
		# centrees sur le quad, elles laisseraient la moitie basse vide. Le
		# decalage les ramene au milieu de la fenetre, le cadrage les y serre.
		"frame": 2.6,
		"offset": Vector3(0.0, -0.85, 0.0),
		"pose": {"swell": 1.00, "core": 0.55, "seed": 0.28},
	},

	# L'haleine puante, sur sa pose de MORSURE (`breath_aura.BITE_POSE` = 0) :
	# couronne gonflee et accents cremes au maximum. C'est la pose ou la
	# competence agit, et la seule ou le 2e ton du cluster existe.
	"breath": {
		"shader": BREATH_SHADER,
		"size": 5.60,  # 2,80 m de rayon T1 x 2
		"frame": 7.5,
		"offset": Vector3.ZERO,
		"pose": {"swell": 1.00, "core": 0.45, "spin": 0.0, "seed": 0.73},
	},
}

## La boule de poils n'a pas de shader de FX : c'est le PROJECTILE, un maillage
## cel-shade. Sa vignette passe donc par l'autre chemin — le VRAI modele, habille
## par `cel_prop` exactement comme en jeu.
##
## ✅ LA DUPLICATION NOTEE ICI A DISPARU le 2026-08-19. Ce bloc recopiait le rayon,
## la hauteur, la couleur et le trait de la capsule placeholder, faute de pouvoir
## les lire sans instancier un Area3D avec sa collision. Le passage au modele
## (`tools/build_hairball.py`) la supprime : `CelProp.dress()` prend le maillage
## et les materiaux dans le meme cache que le projectile en vol, donc la vignette
## ne PEUT plus diverger de ce que le joueur verra. Il ne reste que le cadrage,
## qui est une decision de vignette et de rien d'autre.
##
## `frame` est la hauteur vue par la camera ortho, en metres. 0,95 pour un amas
## de 0,77 : la meme marge que les FX, sans laquelle le trait touche le bord.
const HAIRBALL := {
	"model": "res://assets/models/projectile_boule_poils.glb",
	"variant": "boule_poils",
	"frame": 0.95,
}


## Une competence a-t-elle une vignette ? Non pour les passifs, qui ne sont
## jamais dessines dans le jeu.
static func has_thumb(id: String) -> bool:
	return FX.has(id) or id == "hairball"


## Le rig d'une carte : un SubViewport vide, sa camera et son porte-sujet.
##
## ⚠️ IL SE FABRIQUE UNE FOIS PAR SLOT, PAS UNE FOIS PAR TIRAGE. Les trois cartes
## changent de competence a chaque niveau ; construire un SubViewport a chaque
## ouverture en creerait trois par level-up, et une run de dix niveaux en
## laisserait trente derriere elle. C'est `configure()` qui rejoue le contenu.
static func make() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(SIZE, SIZE)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sinon la colonne l'etire a sa largeur et la vignette devient un bandeau —
	# le piege deja paye sur la piste d'XP, et invisible en lisant le code.
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	# ⚠️ SON PROPRE MONDE. Sans ca la vignette herite du monde du jeu : elle
	# verrait l'arene, le chat et les ennemis derriere son quad.
	viewport.own_world_3d = true
	# Le fond du carton doit passer au travers — c'est `BACKING`, dessine par
	# l'UI, pas par la 3D. Une couleur d'environnement ici serait une 4e valeur
	# a l'ecran que personne ne pourrait retrouver depuis `ui_style.gd`.
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(viewport)

	var camera := Camera3D.new()
	# ORTHOGONALE, et ce n'est pas un detail de confort : une perspective
	# donnerait de la fuite a un decalque plat, donc un dessin vu de biais. Tous
	# ces FX sont des dessins epingles face camera (§8) — la vignette doit les
	# montrer comme le jeu les montre, de face.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.01
	camera.far = 100.0
	camera.position = Vector3(0.0, 0.0, 10.0)
	camera.name = "Cadre"
	viewport.add_child(camera)

	var subject := MeshInstance3D.new()
	subject.name = "Sujet"
	subject.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewport.add_child(subject)

	return container


## Rejoue le rig pour une competence donnee. Rend `false` si elle n'a pas de
## vignette — l'appelant masque alors la fenetre au lieu d'en montrer une vide.
static func configure(thumb: SubViewportContainer, id: String) -> bool:
	if not has_thumb(id):
		set_running(thumb, false)
		return false

	var viewport := thumb.get_child(0) as SubViewport
	var camera := viewport.get_node("Cadre") as Camera3D
	var subject := viewport.get_node("Sujet") as MeshInstance3D

	if not FX.has(id):
		# La boule de poils. Inclinee, et pas de face : son axe long EST son axe
		# de vol, donc la poser d'aplomb la ferait lire comme un oeuf pose. En
		# biais, elle se lit comme quelque chose qui a ete CRACHE — meme geste
		# que l'inclinaison tiree au hasard des onomatopees, sauf qu'ici elle est
		# fixe : une vignette de carte n'est pas un evenement, elle doit etre la
		# meme a chaque tirage.
		#
		# Deux rotations : le Y ecarte l'axe de la profondeur (sinon le boudin
		# pointe vers la camera et on ne voit qu'un rond), le Z le penche.
		camera.size = HAIRBALL["frame"]
		subject.position = Vector3.ZERO
		subject.rotation_degrees = Vector3(-18.0, 90.0, 26.0)
		# ⚠️ `CelProp.dress` pose les materiaux sur les SURFACES, pas en
		# override : l'override d'un FX precedent les masquerait entierement.
		# Les trois cartes se recyclent d'un tirage a l'autre, ce cas arrive
		# donc pour de bon.
		subject.material_override = null
		CelProp.dress(subject, HAIRBALL["model"], HAIRBALL["variant"], CelProp.PICKUP)
		return true

	var entry: Dictionary = FX[id]

	camera.size = entry["frame"]

	# Le QuadMesh reste a 1 x 1 : TOUS ces shaders font `VERTEX.xy *= size` eux
	# memes. Le redimensionner ici multiplierait deux fois.
	subject.mesh = QuadMesh.new()
	subject.position = entry["offset"]
	subject.rotation_degrees = Vector3.ZERO
	subject.set_surface_override_material(0, null)

	# Le materiau part du SHADER NU, pas d'un materiau de scene duplique. Les
	# couleurs, les seuils et les epaisseurs sont tous des valeurs par defaut
	# d'uniform dans le fichier `.gdshader` — repartir de la garantit que la
	# vignette porte exactement ce que le shader dit, et non ce qu'une scene
	# aurait pu surcharger au passage.
	var mat := ShaderMaterial.new()
	mat.shader = entry["shader"]
	mat.set_shader_parameter("size", entry["size"])

	for key in entry["pose"]:
		mat.set_shader_parameter(key, entry["pose"][key])

	subject.material_override = mat
	return true


## Allume ou coupe le rendu des vignettes d'un carton.
##
## ⚠️ CE N'EST PAS UNE OPTIMISATION, c'est la seule facon d'avoir une image. Un
## SubViewport en `UPDATE_DISABLED` ne rend RIEN, jamais — sa texture reste
## noire, et le defaut est parfaitement muet : ni erreur, ni avertissement, juste
## trois fenetres vides sur les cartes.
##
## `UPDATE_ALWAYS` plutot qu'`UPDATE_ONCE` : le carton s'ouvre en pas pendant que
## le jeu est en pause, et `ONCE` consomme sa frame unique au moment ou le
## contenu est encore masque. Trois quads non eclaires de 76 px ne coutent rien,
## et ils ne tournent que pendant qu'un carton est a l'ecran.
static func set_running(thumb: SubViewportContainer, running: bool) -> void:
	if thumb == null:
		return

	var viewport := thumb.get_child(0) as SubViewport
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if running else SubViewport.UPDATE_DISABLED
	)
