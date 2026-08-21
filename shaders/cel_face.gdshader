// Visage peint — yeux, nez, bouche, moustaches
//
// Meme base cel que cel_toon.gdshader, plus les details du visage DESSINES sur
// la surface. Aucun n'est modelise : c'est la regle de "Visual Art Direction"
// §2bis, apprise a la dure (des yeux en geometrie debordent de la silhouette
// vue de profil et deviennent des taches vertes autour du crane).
//
// Les details vivent dans un espace facial projete : on ramene la position
// objet a une direction sur l'ellipsoide de la tete, et on garde (x, y) comme
// coordonnees 2D. On peut alors dessiner de vraies formes (ellipses, arcs,
// segments) la ou des calottes ne suffisaient plus.
//
// |x| avant le calcul : un seul jeu de formes dessine les deux cotes.

shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;

group_uniforms couleur;
uniform vec4 base_color : source_color = vec4(0.909, 0.769, 0.549, 1.0);
uniform float shadow_hue_shift : hint_range(-0.2, 0.2) = -0.02;
uniform float shadow_saturation : hint_range(0.5, 2.0) = 1.15;
uniform float shadow_value : hint_range(0.1, 1.0) = 0.65;

group_uniforms lumiere;
uniform vec3 light_dir = vec3(-0.35, 0.85, 0.4);
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;

group_uniforms attr_style;
// Meme biais peint que cel_toon : sans lui, le terminateur du visage serait
// une courbe mathematique propre pendant que celui du corps ondule — et la
// frontiere entre les deux coques se verrait.
uniform bool use_vertex_style = false;
uniform float shadow_bias_strength : hint_range(0.0, 2.0) = 1.0;
uniform float edge_noise : hint_range(0.0, 0.3) = 0.0;
uniform float edge_noise_scale : hint_range(1.0, 200.0) = 35.0;

group_uniforms repere_visage;
// Centre et demi-axes de la tete, en espace objet.
uniform vec3 face_center = vec3(0.0, 1.1, 0.64);
uniform vec3 face_radius = vec3(0.5016, 0.4651, 0.456);
// L'avant du chat est +Z apres conversion Y-up du glTF.
// Cone du visage. Plus la valeur est haute, plus le visage cesse tot quand la
// tete se detourne. Il doit rester au-dessus de la portee du detail le plus
// large (les moustaches) pour ne jamais couper une forme en deux.
uniform float face_front_min : hint_range(-1.0, 1.0) = 0.46;
// Bascule du repere facial vers le haut. La camera plonge a ~60° : un visage
// strictement frontal passe sous l'horizon et on ne voit que le crane. On
// releve donc le masque pour qu'il regarde la camera — c'est du cadrage, pas
// de l'anatomie, et c'est le reglage habituel des jeux en vue plongeante.
uniform float face_pitch_deg : hint_range(0.0, 80.0) = 26.0;
// ⭐ LE CADRAGE, et lui seul. Retranche des hauteurs du visage juste avant le
// dessin, donc TOUTES les valeurs qui suivent sont des mesures brutes de la
// maquette, lisibles telles quelles a cote de la planche.
//
// Il existe parce que la maquette regarde droit devant et que la camera du jeu
// plonge de 45° (§11) : poser le visage a sa hauteur de maquette le mettrait
// sous l'horizon du crane, la ou la camera ne voit plus que le front.
//
// ⚠️ Il ne touche PAS le cone facial (`in_face`) : le cone decrit la geometrie
// de la tete, pas la mise en page du dessin.
uniform float face_lift : hint_range(-0.5, 0.8) = 0.33;

// ─── LE VISAGE EST RELEVE SUR LA MAQUETTE, PAS COMPOSE A L'OEIL ──────────────
//
// Toutes les valeurs ci-dessous sont MESUREES sur `maquettes/CatTuxedoFace.png`
// (2026-08-20), la planche de visage de face — gueule fermee a droite, gueule
// ouverte a gauche. La mesure est directe : sur une vue de face orthographique,
// un point de la surface a l'angle theta de l'axe tombe a `sin(theta) x R` de
// l'ecran, ce qui est exactement l'espace facial de ce shader. Un releve en
// pixels divise par le rayon de la tete dessinee donne donc des uv SANS
// conversion.
//
// ⛔ ET C'EST LA QUE LE PREMIER RELEVE S'EST TROMPE — le visage est passe par ce
// shader une premiere fois le 2026-08-20 au matin, et il en est sorti avec des
// yeux trop petits. La cause tient en une ligne : `R` N'EST PAS UN NOMBRE, C'EN
// EST DEUX. `uv.x` se normalise par la demi-LARGEUR de la tete, `uv.y` par sa
// demi-HAUTEUR, et sur ce chat la tete est plus large que haute — 167,5 px
// contre 129,5, soit un rapport de 1,29. Le premier releve a divise les DEUX
// axes par la demi-largeur : toutes les hauteurs sont sorties 29 % trop
// courtes, d'un seul coup et de facon coherente. C'est exactement le genre
// d'erreur qui ne se voit pas — le visage restait plausible, il etait juste
// ecrase. Mesure : demi-hauteur d'iris 0,216 rendue contre 0,290 relevee.
//
// Repere de la planche : axe du visage x = 1014, centre de tete y = 325,5,
// demi-axes (167,5 ; 129,5).
//
// ⚠️ LA HAUTEUR ABSOLUE DU GROUPE NE VIENT PAS DE LA MAQUETTE, et elle a
// desormais son propre uniform (`face_lift`). Avant, elle etait AJOUTEE A LA
// MAIN dans chaque valeur, ce qui melangeait sans le dire une mesure et un
// choix de cadrage : impossible de recaler le visage sans refaire le releve, et
// impossible de savoir, devant un chiffre, lequel des deux on lisait.

group_uniforms yeux;
uniform vec4 iris_color : source_color = vec4(0.533, 0.722, 0.533, 1.0);
// L'iris de la maquette est en DEUX VERTS, sombre en haut, clair en bas, avec
// une frontiere franche a mi-hauteur. C'est le cluster de §5.5 applique a
// l'oeil — sauf qu'il est DESSINE, pas subi : §2bis veut que l'oeil reste un
// aplat franc quelle que soit la lumiere.
uniform vec4 iris_shadow_color : source_color = vec4(0.259, 0.478, 0.243, 1.0);
uniform float iris_split : hint_range(-0.3, 0.3) = -0.039;
uniform vec4 pupil_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
uniform vec4 glint_color : source_color = vec4(0.961, 0.925, 0.847, 1.0);
uniform vec4 line_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
// "Grands yeux expressifs avec reflets lumineux" — §3.
//
// Releve sur la planche : iris de 45 x 75 px, centres a 66 px de l'axe, soit
// des demi-axes (0,134 ; 0,286) a 0,394. C'est un oeil DEUX FOIS PLUS HAUT QUE
// LARGE — l'amande de la maquette — et il occupe 29 % de la hauteur de tete a
// lui seul. La pupille est une fente verticale (19 x 39 px) et le reflet un
// ovale FRANC pose en haut, du cote exterieur : ce sont les deux details qui
// font qu'un oeil se lit comme un oeil a taille de jeu, et les deux etaient
// sortis trop petits.
//
// ⚠️ ET LES TROIS LARGEURS SONT ELARGIES DE 17 %, PAS RELEVEES. Les fractions
// de tete se transposent exactement — l'oeil rendu occupe 13,2 % de la largeur
// et 29,8 % de la hauteur, contre 13,4 % et 29,0 % sur la planche — mais LA
// TETE DU MODELE N'A PAS L'ALLONGEMENT DE CELLE DU DESSIN : projetee, elle fait
// 258 x 235 px (rapport 1,10) quand la planche en fait 335 x 259 (rapport 1,29).
// Une amande juste en fractions sort donc trop etroite en FORME : 2,06 de haut
// pour 1 de large contre 1,67 sur la planche. Le facteur 1,29 / 1,10 = 1,177
// rattrape la difference sur les trois formes de l'oeil — et sur elles seules,
// parce que c'est le seul detail du visage qu'on lise vraiment a taille de jeu.
//
// La vraie correction serait d'elargir la TETE, pas l'oeil. Elle est en
// geometrie (`HEAD_R` dans tools/build_cat_tuxedo.py), elle deplace les
// oreilles, la boite de griffes et l'ellipsoide d'ANCHORS, et elle n'a pas ete
// faite ici : ce chantier-ci porte sur le dessin.
uniform vec2 eye_pos = vec2(0.394, -0.197);
uniform vec2 eye_size = vec2(0.157, 0.286);
uniform float eye_border : hint_range(0.0, 0.1) = 0.028;
uniform vec2 pupil_size = vec2(0.067, 0.160);
uniform vec2 glint_offset = vec2(0.028, 0.158);
uniform vec2 glint_size = vec2(0.060, 0.077);

group_uniforms nez_bouche;
uniform vec4 nose_color : source_color = vec4(0.909, 0.722, 0.659, 1.0);
uniform vec2 nose_pos = vec2(0.0, -0.494);
uniform float nose_size : hint_range(0.0, 0.2) = 0.0346;
// ⚠️ LE NEZ DE LA MAQUETTE EST PLUS LARGE QUE HAUT (14 px sur 8), et
// `sd_nose()` dessine un triangle plus haut que large (3 x size de haut pour
// 1,73 x size de demi-largeur). On ecrase donc son repere avant de l'evaluer,
// au lieu de reduire sa taille — reduire aurait rendu un nez juste petit.
uniform float nose_squash : hint_range(0.5, 3.0) = 1.48;
// La levre en omega. Trois points releves par arc — la pointe centrale
// (0 ; -0,706), le creux (0,119 ; -0,788), le coin (0,203 ; -0,706) — et le
// cercle qui passe par les trois : rayon 0,1035 centre a (0,1015 ; -0,686).
//
// ⚠️ UN CERCLE DE LA PLANCHE N'EST PAS UN CERCLE EN UV : les deux axes ne se
// normalisent pas par le meme nombre (voir l'en-tete). Le cercle ci-dessus est
// donc ajuste dans l'espace uv directement, sur les trois points, et non
// converti depuis un rayon en pixels — lequel n'existe pas ici.
uniform vec2 mouth_center = vec2(0.1015, -0.686);
uniform float mouth_radius : hint_range(0.0, 0.3) = 0.1035;
uniform float mouth_weight : hint_range(0.0, 0.05) = 0.010;
// ⚠️ ET ELLE S'ARRETE. Sans cette borne, la moitie basse du cercle est dessinee
// EN ENTIER : le trait continuait jusqu'a |x| = 0,30 et remontait vers les
// joues — un sourire qui barrait tout le visage. Sur la maquette les deux arcs
// s'arretent au coin de la gueule, a 0,21.
uniform float mouth_reach : hint_range(0.05, 0.5) = 0.203;
// ⚠️ LE PHILTRUM NE REJOINT PAS LA LEVRE, et il ne le fait pas sur la maquette :
// sous le nez il n'y a qu'un TALON de 4 px, la pointe du trait de nez qui
// descend un peu. Le trait plein qui reliait le nez a la levre etait une
// invention, et il fermait le museau comme une couture.
uniform float philtrum_drop : hint_range(0.0, 0.4) = 0.055;

group_uniforms gueule;
// ⭐ LA GUEULE OUVERTE (2026-08-20) — la seconde bouche de la maquette.
//
// `mouth_open` va de 0 (gueule fermee, la levre en omega seule) a 1 (grande
// ouverte). Rien ne la pilote encore : elle est en place pour l'animation a
// venir, et se regle depuis `cel_model.set_mouth_open()`.
//
// La cavite est l'INTERSECTION de deux formes deja dessinees : une ellipse, et
// le dessous du cercle de la levre. Elle ne peut donc pas depasser la levre,
// quel que soit le reglage — c'est ce qui evite le defaut classique du dessin
// de bouche, un ovale rose colle par-dessus le trait.
uniform float mouth_open : hint_range(0.0, 1.0) = 0.0;
uniform vec4 maw_color : source_color = vec4(0.741, 0.337, 0.325, 1.0);
uniform vec4 tongue_color : source_color = vec4(0.929, 0.522, 0.518, 1.0);
//
// ⛔ LA CAVITE EST LE SEUL DETAIL DU VISAGE REGLE A L'ARRIVEE, ET NON RELEVE.
// Ses uv de planche (demi-axes 0,146 x 0,174) rendaient 43 px de large sur 71
// de haut — une BOULE — quand la planche donne 49 x 45.
//
// La cause est geometrique et vaut pour tout ce qui descend bas sur le visage :
// `dir` se normalise par l'ELLIPSOIDE, mais la surface, elle, BOMBE sous le
// museau et le menton (`MUZZLE_BUMP` et `CHIN_BUMP` dans build_cat_tuxedo.py).
// Un meme ecart d'uv couvre donc plus d'ecran en bas du visage qu'au milieu, et
// la gueule est ce qu'il y a de plus bas. Ni la planche ni le shader ne peuvent
// le savoir : c'est la forme de la tete qui l'impose.
//
// ⚠️ Et ca ne se corrige PAS d'un facteur, parce que le rapport n'est pas
// constant : les quatre demi-hauteurs essayees rendent 15, 27, 33 puis 43 px
// (0,098 / 0,170 / 0,200 / 0,235). Le pas s'ouvre a mesure qu'on descend sur le
// bombe. La valeur retenue est celle qui rend le RAPPORT de la planche —
// 43 x 43 px, soit 1,00 contre 1,09 mesure. La largeur, elle, est intacte.
//
// ⚠️ Le HAUT de l'ellipse doit rester AU-DESSUS de la pointe de la levre
// (-0,706), sinon un liseré de museau reste coince entre le trait et la cavite.
// C'est ce qui fixe le centre : centre + demi-hauteur = -0,608, toujours.
uniform vec2 maw_center = vec2(0.0, -0.843);
uniform vec2 maw_size = vec2(0.146, 0.235);
uniform vec2 tongue_offset = vec2(0.0, -0.060);
uniform vec2 tongue_size = vec2(0.132, 0.170);
// Les crocs : deux petits triangles creme accroches sous la levre, aux coins de
// la gueule. Ils font 2 px sur la maquette — c'est le detail le plus fin du
// visage, et il ne se verra qu'en gros plan (comme les griffes, §2bis).
uniform vec4 fang_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
uniform vec2 fang_pos = vec2(0.125, -0.792);
uniform float fang_size : hint_range(0.0, 0.06) = 0.014;

group_uniforms bavette;
// Le blanc du bas de visage, chez un chat tuxedo. Applique a la couleur
// LOCALE, avant le cluster : la bavette n'est pas un aplat colle par-dessus
// l'ombre, c'est une autre couleur de pelage — elle a donc sa propre ombre
// chaude, derivee comme celle du noir.
uniform vec4 bib_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
uniform float bib_strength : hint_range(0.0, 1.0) = 1.0;
// Hauteur de la frontiere en espace facial, et ses deux corrections :
// la liste qui remonte au centre, le blanc qui redescend sur les cotes.
// Reglages et justification : BIB dans cel_model.gd.
uniform float bib_line : hint_range(-0.6, 0.4) = -0.445;
uniform float bib_falloff : hint_range(0.0, 2.0) = 0.312;
// ⚠️ UNE SEULE PARABOLE NE PEUT PAS FAIRE LES DEUX, et c'est tout l'objet de ce
// second terme.
//
// Le masque d'un tuxedo doit tomber VITE au niveau des yeux — le noir les
// encadre, la maquette est nette la-dessus — puis se RELEVER vers le menton,
// qui est blanc d'un bord a l'autre. Une parabole reglee sur la premiere
// exigence noie le menton dans le noir ; reglee sur la seconde, elle laisse le
// blanc courir jusqu'a la silhouette et le chat sort avec un museau geant. Les
// deux versions ont ete rendues.
//
// Le terme d'ordre 4 est donc NEGATIF : il freine la parabole loin de l'axe.
// Les trois points mesures pres du centre restent tenus a 0,02 pres, et le
// blanc atteint |x| = 0,70 a hauteur de menton.
uniform float bib_falloff4 : hint_range(-4.0, 12.0) = 0.26;
uniform float bib_blaze_height : hint_range(0.0, 0.4) = 0.266;
uniform float bib_blaze_width : hint_range(0.02, 0.5) = 0.110;

group_uniforms moustaches;
// Trait secondaire brun moyen (§4) — plus fin que le contour principal.
uniform vec4 whisker_color : source_color = vec4(0.353, 0.243, 0.157, 1.0);
// Sur la fourrure noire, le brun moyen disparait : une moustache doit rester
// plus claire que ce qu'elle traverse. Les trois moustaches traversent
// justement la frontiere de la bavette — elles changent donc de couleur en
// cours de trait, exactement comme sur un vrai chat bicolore.
uniform vec4 whisker_color_dark : source_color = vec4(0.906, 0.855, 0.749, 1.0);
uniform float whisker_weight : hint_range(0.0, 0.03) = 0.007;
// Un segment par moustache : (depart.xy, arrivee.xy) en espace facial miroir.
// Godot refuse les valeurs par defaut sur les tableaux d'uniforms : les
// valeurs viennent du script (WHISKERS dans cel_test.gd).
uniform vec4 whiskers[3];

group_uniforms skinning;
// Godot applique le skinning AVANT vertex() : VERTEX arrive deja deforme.
// Un masque calcule dessus derape des qu'un os bouge — le visage glissait sur
// le crane pendant l'animation. On defait donc la transformation de l'os qui
// porte cette surface pour retrouver la position AU REPOS.
//
// Exact ici parce que le rig est en poids rigides : 1 sommet = 1 os
// (voir "Pipeline 3D", piege n°3). Le script remet cette matrice a jour
// a chaque frame ; a la pose de repos, c'est l'identite.
uniform mat4 rest_undo;

varying vec3 v_object_pos;
varying vec3 v_style;

#include "res://shaders/cel_core.gdshaderinc"
#include "res://shaders/cel_sun.gdshaderinc"

// Pose un aplat franc si la distance signee passe sous zero.
// `aa` est une DEMI-BANDE en unites d'espace facial, mesuree a l'ecran par
// fragment() — voir la note sur `ps` la-bas. Elle est passee en parametre et
// non lue dans un uniform : une derivee ne se calcule qu'a un seul endroit,
// hors de tout branchement.
//
// Bande CENTREE sur le contour (`-aa`..`+aa`), et non posee a l'exterieur
// (`0`..`aa`) comme avant : decalee, elle epaissit chaque forme d'une demi-bande,
// ce qui ne se voyait pas tant que la bande valait un quart de pixel.
vec3 paint(vec3 under, float dist, float aa, vec3 col) {
	return mix(col, under, smoothstep(-aa, aa, dist));
}

void vertex() {
	v_style = COLOR.rgb;
	v_object_pos = (rest_undo * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	float bias = 0.0;
	if (use_vertex_style) {
		bias = (v_style.g - 0.5) * 2.0 * shadow_bias_strength;
	}

	float jitter = 0.0;
	if (edge_noise > 0.0) {
		jitter = (hash_noise(floor(v_object_pos * edge_noise_scale)) - 0.5) * edge_noise;
	}

	float lit = step(threshold - bias + jitter, dot(n, normalize(light_dir)));

	// --- espace facial ---------------------------------------------------
	// Calcule AVANT le cluster : la bavette change la couleur locale, et le ton
	// d'ombre se derive de cette couleur-la. L'inverse — peindre le blanc sur
	// une ombre deja calculee pour du noir — donnerait un aplat sans ombre.
	vec3 dir = normalize((v_object_pos - face_center) / face_radius);

	float fp = radians(face_pitch_deg);
	vec3 f_fwd = vec3(0.0, sin(fp), cos(fp));   // ou "regarde" le visage
	vec3 f_up = vec3(0.0, cos(fp), -sin(fp));
	vec3 f_right = vec3(1.0, 0.0, 0.0);

	bool in_face = dot(dir, f_fwd) > face_front_min;
	vec2 uv_signed = vec2(dot(dir, f_right), dot(dir, f_up));
	// |x| : les deux cotes d'un coup.
	// Et `face_lift` se retranche ICI, UNE fois : en dessous, tout est en
	// coordonnees de maquette. `in_face` a deja ete decide au-dessus, sur la
	// geometrie — le cadrage ne doit ni elargir ni retrecir le cone.
	vec2 uv = vec2(abs(uv_signed.x), uv_signed.y - face_lift);

	// UN PIXEL, EN UNITES D'ESPACE FACIAL. Meme geste que les six shaders de
	// FX (`ps` dans hit_burst, bite, claw_slash...) : un pixel de lissage, et
	// pas un de plus — c'est de l'antialiasing, pas un degrade (§2bis interdit
	// les seconds, pas le premier).
	//
	// ⚠️ CE CALCUL REMPLACE UN UNIFORM `feature_aa` A 0,004, QUI ETAIT CALIBRE
	// AU BANC ET INERTE EN JEU. L'espace facial est normalise : `uv` couvre
	// ~0,9 sur toute la largeur du visage visible. Au banc, tete a ~600 px, un
	// pixel vaut ~0,0015 uv et la bande faisait ~2,7 px — parfait. En jeu, le
	// chat fait ~11 % de la hauteur d'ecran, la tete ~60 px, un pixel vaut
	// ~0,015 uv : la bande tombait a ~0,25 px, donc SOUS le pixel, et le
	// smoothstep redevenait un step. Un facteur 10 entre les deux — aucune
	// valeur fixe ne peut etre bonne aux deux endroits.
	//
	// ⚠️ Derivees prises sur les coordonnees SIGNEES. `uv.x` passe par abs() :
	// sa derivee exploserait sur la colonne de pixels de l'axe de symetrie,
	// pile la ou passent le philtrum et le nez.
	//
	// ⚠️ Et calculees ICI, hors de `if (in_face)`. Une derivee dans un
	// branchement non uniforme est indefinie en GLSL : les pixels voisins du
	// quad n'ont pas forcement pris la meme branche.
	float ps = max(max(fwidth(uv_signed.x), fwidth(uv_signed.y)), 1e-6);
	float aa = ps * 0.75;

	float bib = 0.0;
	if (in_face) {
		float blaze = uv.x / bib_blaze_width;
		float x2 = uv.x * uv.x;
		float limit = bib_line
				+ bib_blaze_height * exp(-blaze * blaze)
				- bib_falloff * x2
				- bib_falloff4 * x2 * x2;
		// Bornes dans l'ordre croissant : smoothstep() n'est pas defini autrement.
		bib = (1.0 - smoothstep(limit - aa, limit + aa, uv.y)) * bib_strength;
	}

	vec3 local = mix(base_color.rgb, bib_color.rgb, bib);
	vec3 shadow_col = warm_shadow(local, shadow_hue_shift, shadow_saturation, shadow_value);
	vec3 col = mix(shadow_col, local, lit);

	if (in_face) {
		// Moustaches d'abord : tout le reste passe par-dessus.
		vec3 whisker = mix(whisker_color_dark.rgb, whisker_color.rgb, bib);

		for (int i = 0; i < 3; i++) {
			float d = sd_segment(uv, whiskers[i].xy, whiskers[i].zw) - whisker_weight;
			col = paint(col, d, aa, whisker);
		}

		// --- LA GUEULE -------------------------------------------------
		// L'ordre compte : la cavite se pose AVANT la levre, pour que le trait
		// de levre la borde au lieu d'etre recouvert.
		vec2 mo = uv - mouth_center;

		// ⛔ LA COUPE SE FAIT SOUS LA COURBE, PAS HORS DU CERCLE. La version
		// d'avant ecrivait `mouth_radius - length(mo)`, donc "en dehors du
		// disque de levre" — ce qui n'a jamais ete la meme chose, et ne se
		// voyait pas tant que le disque etait grand et pose HAUT sur le visage :
		// son bord bas passait alors juste au-dessus de la cavite et faisait
		// bien office de levre. Avec l'arc releve sur la planche (rayon 0,104
		// au lieu de 0,179, et pose sur la gueule), le disque est devenu un
		// petit rond au coin des levres : il ne rabotait plus la cavite, il y
		// perforait un TROU, et il effacait les crocs en entier — ils sont
		// dedans. Ici on compare a l'ORDONNEE de l'arc, colonne par colonne.
		float lip_dx = uv.x - mouth_center.x;
		float lip_y = mouth_center.y - sqrt(max(0.0,
				mouth_radius * mouth_radius - lip_dx * lip_dx));
		float under_lip = uv.y - lip_y;   // < 0 sous la levre, donc DANS la gueule

		if (mouth_open > 0.001) {
			// La cavite : une ellipse, rabotee par le dessous de l'arc de
			// levre. Elle s'ouvre en HAUTEUR — une gueule qui s'ouvre pousse
			// la machoire vers le bas, elle ne gonfle pas dans tous les sens.
			vec2 size = vec2(maw_size.x, maw_size.y * mouth_open);
			vec2 center = vec2(maw_center.x,
					mouth_center.y - (mouth_center.y - maw_center.y) * mouth_open);
			float maw = max(sd_ellipse(uv - center, size), under_lip);
			col = paint(col, maw, aa, maw_color.rgb);

			// La langue, au fond, et les crocs accroches sous la levre.
			float tongue = max(
					sd_ellipse(uv - center - tongue_offset * mouth_open,
							tongue_size * mouth_open),
					under_lip);
			col = paint(col, tongue, aa, tongue_color.rgb);

			// Les crocs sont poses A CHEVAL sur la levre et c'est la coupe qui
			// leur donne leur forme : le triangle deborde vers le haut, la
			// levre lui tranche le sommet, il ne reste que la pointe qui pend.
			// Coupes par `maw` et non par `under_lip` : sous la levre il y a
			// encore du museau de chaque cote de la gueule, et un croc qui
			// depasse par le bas s'y poserait comme un eclat creme sur le
			// menton. La cavite est la seule surface ou un croc a un sens.
			float fang = sd_nose(uv - fang_pos, fang_size);
			col = paint(col, max(fang, maw), aa, fang_color.rgb);
		}

		// La levre en omega : un arc de cercle par cote, moitie basse seulement.
		float ring = abs(length(mo) - mouth_radius) - mouth_weight;
		float lower = mouth_center.y - uv.y;   // > 0 sous le centre de l'arc
		col = paint(col, max(max(ring, -lower), uv.x - mouth_reach), aa,
				line_color.rgb);

		// Philtrum : le TALON sous le nez. Il s'arrete a `philtrum_drop` et ne
		// rejoint pas la levre — voir l'uniform.
		float nose_bottom = nose_pos.y - 2.0 * nose_size / nose_squash;
		float philtrum = sd_segment(uv, vec2(0.0, nose_bottom),
				vec2(0.0, nose_bottom - philtrum_drop)) - mouth_weight * 0.8;
		col = paint(col, philtrum, aa, line_color.rgb);

		// Nez — repere ecrase : la maquette le veut plus large que haut.
		col = paint(col, sd_nose((uv - nose_pos) * vec2(1.0, nose_squash),
				nose_size), aa, nose_color.rgb);

		// --- LES YEUX ---------------------------------------------------
		// Du plus large au plus petit : cerne, iris en deux verts, pupille,
		// reflet. L'iris est le seul aplat du jeu a porter deux tons SANS
		// lumiere — c'est un dessin, pas un cluster (voir iris_shadow_color).
		vec2 eo = uv - eye_pos;
		float eye = sd_ellipse(eo, eye_size);
		col = paint(col, eye - eye_border, aa, line_color.rgb);
		col = paint(col, eye, aa, iris_color.rgb);
		col = paint(col, max(eye, iris_split - eo.y), aa, iris_shadow_color.rgb);
		col = paint(col, sd_ellipse(eo, pupil_size), aa, pupil_color.rgb);
		col = paint(col, sd_ellipse(eo - glint_offset, glint_size), aa,
				glint_color.rgb);
	}

	ALBEDO = col;
	// L'aplat peint part en EMISSION : c'est lui qui survit a la coupure
	// du soleil, au pixel pres. Voir le bandeau de cel_sun.gdshaderinc.
	EMISSION = ALBEDO;
}
