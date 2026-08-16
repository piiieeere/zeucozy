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
render_mode unshaded, cull_back, shadows_disabled, specular_disabled;

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
// Antialiasing seulement — les aplats doivent rester francs (§2bis).
uniform float feature_aa : hint_range(0.0, 0.05) = 0.004;

group_uniforms yeux;
uniform vec4 iris_color : source_color = vec4(0.533, 0.722, 0.533, 1.0);
uniform vec4 pupil_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
uniform vec4 glint_color : source_color = vec4(0.961, 0.925, 0.847, 1.0);
uniform vec4 line_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
// "Grands yeux expressifs avec reflets lumineux" — §3.
uniform vec2 eye_pos = vec2(0.30, 0.14);
uniform vec2 eye_size = vec2(0.155, 0.19);
uniform float eye_border : hint_range(0.0, 0.1) = 0.022;
uniform vec2 pupil_size = vec2(0.066, 0.145);
uniform vec2 glint_offset = vec2(-0.055, 0.066);
uniform float glint_size : hint_range(0.0, 0.1) = 0.044;

group_uniforms nez_bouche;
uniform vec4 nose_color : source_color = vec4(0.909, 0.722, 0.659, 1.0);
uniform vec2 nose_pos = vec2(0.0, -0.09);
uniform float nose_size : hint_range(0.0, 0.2) = 0.062;
uniform vec2 mouth_center = vec2(0.072, -0.16);
uniform float mouth_radius : hint_range(0.0, 0.3) = 0.085;
uniform float mouth_weight : hint_range(0.0, 0.05) = 0.016;

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
uniform float bib_line : hint_range(-0.6, 0.4) = -0.02;
uniform float bib_falloff : hint_range(0.0, 2.0) = 0.55;
uniform float bib_blaze_height : hint_range(0.0, 0.4) = 0.12;
uniform float bib_blaze_width : hint_range(0.02, 0.5) = 0.14;

group_uniforms moustaches;
// Trait secondaire brun moyen (§4) — plus fin que le contour principal.
uniform vec4 whisker_color : source_color = vec4(0.353, 0.243, 0.157, 1.0);
// Sur la fourrure noire, le brun moyen disparait : une moustache doit rester
// plus claire que ce qu'elle traverse. Les trois moustaches traversent
// justement la frontiere de la bavette — elles changent donc de couleur en
// cours de trait, exactement comme sur un vrai chat bicolore.
uniform vec4 whisker_color_dark : source_color = vec4(0.906, 0.855, 0.749, 1.0);
uniform float whisker_weight : hint_range(0.0, 0.03) = 0.011;
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

// Pose un aplat franc si la distance signee passe sous zero.
vec3 paint(vec3 under, float dist, vec3 col) {
	return mix(col, under, smoothstep(0.0, feature_aa, dist));
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
	// |x| : les deux cotes d'un coup
	vec2 uv = vec2(abs(dot(dir, f_right)), dot(dir, f_up));

	float bib = 0.0;
	if (in_face) {
		float blaze = uv.x / bib_blaze_width;
		float limit = bib_line
				+ bib_blaze_height * exp(-blaze * blaze)
				- bib_falloff * uv.x * uv.x;
		// Bornes dans l'ordre croissant : smoothstep() n'est pas defini autrement.
		bib = (1.0 - smoothstep(limit - feature_aa, limit + feature_aa, uv.y)) * bib_strength;
	}

	vec3 local = mix(base_color.rgb, bib_color.rgb, bib);
	vec3 shadow_col = warm_shadow(local, shadow_hue_shift, shadow_saturation, shadow_value);
	vec3 col = mix(shadow_col, local, lit);

	if (in_face) {
		// Moustaches d'abord : tout le reste passe par-dessus.
		vec3 whisker = mix(whisker_color_dark.rgb, whisker_color.rgb, bib);

		for (int i = 0; i < 3; i++) {
			float d = sd_segment(uv, whiskers[i].xy, whiskers[i].zw) - whisker_weight;
			col = paint(col, d, whisker);
		}

		// Bouche en oméga : un arc de cercle par cote, moitie basse seulement.
		vec2 mo = uv - mouth_center;
		float ring = abs(length(mo) - mouth_radius) - mouth_weight;
		float lower = mouth_center.y - uv.y;   // > 0 sous le centre de l'arc
		col = paint(col, max(ring, -lower), line_color.rgb);

		// Philtrum : le petit trait vertical entre le nez et la bouche.
		float philtrum = sd_segment(uv, vec2(0.0, nose_pos.y - nose_size),
				vec2(0.0, mouth_center.y)) - mouth_weight * 0.8;
		col = paint(col, philtrum, line_color.rgb);

		// Nez
		col = paint(col, sd_nose(uv - nose_pos, nose_size), nose_color.rgb);

		// Yeux : cerne, iris, pupille, reflet — du plus large au plus petit.
		float eye = sd_ellipse(uv - eye_pos, eye_size);
		col = paint(col, eye - eye_border, line_color.rgb);
		col = paint(col, eye, iris_color.rgb);
		col = paint(col, sd_ellipse(uv - eye_pos, pupil_size), pupil_color.rgb);
		col = paint(col, sd_ellipse(uv - eye_pos - glint_offset,
				vec2(glint_size)), glint_color.rgb);
	}

	ALBEDO = col;
}
