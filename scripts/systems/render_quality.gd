extends RefCounted

## L'antialiasing de la 3D — le reglage, et le levier qui permet de le mesurer.
##
## Le projet n'avait AUCUN reglage d'AA : `[rendering]` ne contenait que le
## driver. Les six shaders de FX et le sol lissaient deja leurs bords a un pixel
## (`ps = dFdx/dFdy`), et `cel_face` / `cel_paws` s'y sont mis le 2026-08-18 —
## mais tout ca est du FRAGMENT. La silhouette du chat, elle, est une coque
## inversee : un vrai bord de GEOMETRIE, que seul un AA de couverture peut
## traiter. C'est la derniere famille de bords du jeu a etre restee brute.
##
## Le manuel recommande MSAA nommement pour ce cas (3D antialiasing) :
## "For projects with a low amount of reflective surfaces (such as a cartoon
## artstyle), MSAA can work well. MSAA is also a good option if avoiding
## blurriness and temporal artifacts is important."
##
## ⛔ CE QUI EST DISQUALIFIE, ET POURQUOI CA NE SE REDISCUTE PAS :
##
## - **TAA** accumule sur PLUSIEURS FRAMES, alors que le squelette change de
##   pose d'un coup toutes les 3 frames : il lisserait exactement la
##   discontinuite que la cadence en pas existe pour creer (§7). Il tenterait
##   aussi de faire converger le grain, bruite EXPRES a 20 Hz dephase (§8bis).
## - **FXAA / SMAA** sont en espace ecran et floutent — Godot ajoute meme un
##   biais de mipmap de -0,25 pour compenser. Ils s'appliqueraient au trait
##   d'encre, contre le "bord franc" de §6.
##
## Le reglage retenu vit dans `project.godot`, donc TOUT le tourne avec : le
## jeu, les trois bancs, et les captures `--write-movie`. Supersampler les
## seules captures reviendrait a juger une image que le joueur ne voit jamais —
## la divergence banc/jeu, encore, celle que `feature_aa` venait de couter.

## Les niveaux de MSAA, ecrits comme le joueur les nomme (0, 2, 4, 8) plutot
## que par leur enum. C'est ce qui rend `--msaa=4` lisible dans un journal de
## capture six mois plus tard.
const MSAA_LEVELS := {
	0: Viewport.MSAA_DISABLED,
	2: Viewport.MSAA_2X,
	4: Viewport.MSAA_4X,
	8: Viewport.MSAA_8X,
}


## A appeler dans le `_ready()` de toute scene principale — le jeu comme les
## bancs. Sans argument, elle ne fait rien : le reglage de projet est deja
## applique au viewport racine par le moteur.
##
## Deux leviers de comparaison, poses a l'execution plutot qu'edites entre deux
## captures (meme convention que `--pitch=`, `--decor-outline=` ou `--lang=`) :
##
##     --msaa=0|2|4|8   la couverture de geometrie — la silhouette
##     --ssaa=1.5|2.0   la resolution interne de la 3D — TOUS les bords,
##                      bord de cluster compris, puisqu'elle shade plusieurs
##                      fois par pixel. Cout ×4 en pixels et en VRAM a 2,0.
##
## ⚠️ MSAA ne touche QUE les bords de geometrie. Le bord du cluster d'ombre
## (`step()` dans `cel_toon` / `cel_face`) est du fragment : il ne bougera pas
## d'un pixel, quel que soit le niveau. C'est `--ssaa=` qui l'atteint, et lui
## seul.
static func apply_cmdline_overrides(viewport: Viewport) -> void:
	var touched := false

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--msaa="):
			var level := int(argument.trim_prefix("--msaa="))
			# Une valeur inconnue LEVE, comme partout ailleurs dans le projet :
			# un `--msaa=3` silencieusement ignore ferait mesurer deux fois la
			# meme image et conclure que MSAA ne sert a rien.
			assert(MSAA_LEVELS.has(level), "MSAA inconnu : %d (0, 2, 4 ou 8)" % level)
			viewport.msaa_3d = MSAA_LEVELS[level]
			touched = true
		elif argument.begins_with("--ssaa="):
			var scale := float(argument.trim_prefix("--ssaa="))
			assert(scale > 0.0, "Echelle 3D invalide : %f" % scale)
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			viewport.scaling_3d_scale = scale
			touched = true

	if touched:
		report(viewport)


## Ce sur quoi la 3D est reellement rendue. A l'ecran quand on surcharge l'AA :
## une mesure d'antialiasing qui ne sait pas a quelle resolution elle regarde ne
## mesure rien.
##
## ⚠️ ET LA RESOLUTION N'EST PAS CELLE DE LA FENETRE. Avec
## `stretch/mode="canvas_items"`, le viewport racine garde la HAUTEUR de base du
## projet (648) — la largeur suivant l'aspect, `stretch/aspect` valant "expand" —
## et TOUT y est rendu, 3D comprise, avant d'etre etire a la fenetre. Releve le
## 2026-08-19 : viewport 1175 x 648 pour une fenetre 2560 x 1411, soit un
## facteur 2,18. Un plein ecran ne rend donc pas plus de pixels de 3D — il
## agrandit ceux-la. C'est ce qui borne le cout de MSAA une fois pour toutes, et
## c'est aussi pourquoi le bord de silhouette compte autant : chaque marche
## d'escalier est etiree 2,18 fois avant d'atteindre l'oeil du joueur.
static func report(viewport: Viewport) -> void:
	var names := {
		Viewport.MSAA_DISABLED: "0", Viewport.MSAA_2X: "2x",
		Viewport.MSAA_4X: "4x", Viewport.MSAA_8X: "8x",
	}
	print("AA : msaa_3d %s · echelle 3D %.2f · viewport %dx%d · fenetre %dx%d" % [
		names.get(viewport.msaa_3d, "?"), viewport.scaling_3d_scale,
		viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y,
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
	])
