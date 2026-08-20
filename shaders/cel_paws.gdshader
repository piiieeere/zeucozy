// Bouts de pattes — les GRIFFES peintes
//
// Meme base cel que cel_toon.gdshader, plus trois traits de griffe dessines sur
// chaque patte. Rien n'est modelise, exactement comme le visage : c'est la regle
// de "Visual Art Direction" §2bis, et c'est la meme methode que les moustaches
// (espace local projete + SDF de segments).
//
// Ce shader porte la surface `fourrure_blanche` — les quatre bouts de patte ET
// le bout de queue, qui partagent un materiau.
//
// --- POURQUOI CE SHADER EXISTE SEPAREMENT ---------------------------------
//
// "Pipeline 3D" piege n°4 : Godot applique le skinning AVANT vertex(), donc
// tout masque calcule sur VERTEX glisse des qu'un os bouge. La parade habituelle
// est `rest_undo`, l'inverse du delta repos->pose de l'os porteur. Mais elle ne
// connait que DEUX os par surface (le cas des oreilles, separees par le signe
// de x), et cette surface-ci en porte CINQ :
//
//   pattavant_L  pattavant_R  piedar_L  piedar_R  queue_3
//
// C'est ce qui avait fait renoncer a peindre le blanc des extremites en shader
// (voir tools/paint_tuxedo.py). La sortie est ailleurs : `BONE_INDICES` et
// `BONE_WEIGHTS` sont lisibles dans le vertex shader de Godot 4 — verifie sur
// 4.7.1, ils compilent et tournent. On choisit donc la matrice PAR SOMMET,
// d'apres son os porteur, au lieu de la deviner d'apres un signe de coordonnee.
//
// Chaque matrice fait tout le trajet d'un coup : elle defait l'os, recentre sur
// la patte et divise par ses demi-axes. `v_paw_pos` en sort deja normalise, il
// n'y a plus qu'a le projeter. Les centres et rayons vivent dans cel_model.gd,
// pas ici — deux tables de mesures qui divergent est exactement ce que le chat
// a deja paye cher.
//
// Le bout de queue ne recoit AUCUN os de la liste : il sort avec v_paw = -1 et
// ne porte pas de griffes. C'est voulu, pas un oubli.

shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;

group_uniforms couleur;
uniform vec4 base_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
uniform float shadow_hue_shift : hint_range(-0.2, 0.2) = -0.02;
uniform float shadow_saturation : hint_range(0.5, 2.0) = 1.15;
uniform float shadow_value : hint_range(0.1, 1.0) = 0.65;

group_uniforms lumiere;
uniform vec3 light_dir = vec3(-0.35, 0.85, 0.4);
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;

group_uniforms attr_style;
uniform bool use_vertex_style = false;
uniform float shadow_bias_strength : hint_range(0.0, 2.0) = 1.0;
uniform float edge_noise : hint_range(0.0, 0.3) = 0.0;
uniform float edge_noise_scale : hint_range(1.0, 200.0) = 35.0;

group_uniforms accent;
uniform vec4 accent_color : source_color = vec4(0.961, 0.925, 0.847, 1.0);
uniform float accent_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float accent_strength : hint_range(0.0, 1.0) = 0.0;

group_uniforms griffes;
// Trait secondaire brun moyen (§4) — le meme registre que les moustaches : plus
// fin que le contour principal, et jamais un noir pur. Il est pose sur le creme
// des extremites, ou il a tout le contraste qu'il lui faut.
uniform vec4 claw_color : source_color = vec4(0.353, 0.243, 0.157, 1.0);
// 0,055 et non le double, compare en image : a 0,105 les trois traits se
// lisent comme trois grosses barres et perdent le registre du trait secondaire
// (§5.4, plus fin que le contour). Et ca ne rachetait rien — a taille de jeu on
// passe de 5 a 9 pixels, tous les deux invisibles (voir la Todo).
uniform float claw_weight : hint_range(0.0, 0.2) = 0.055;
// Un segment par griffe : (depart.xy, arrivee.xy) en espace patte.
// Godot refuse les valeurs par defaut sur un tableau d'uniforms — elles
// viennent de CLAWS, dans cel_model.gd.
uniform vec4 claws[3];
// Bascule du repere de patte vers le haut, exactement comme `face_pitch_deg`
// pour le visage et pour la meme raison : la camera plonge de 45°, une griffe
// posee a plat sur l'avant de la patte passerait sous l'horizon et on ne verrait
// que le dessus du chausson. C'est du cadrage, pas de l'anatomie.
uniform float claw_pitch_deg : hint_range(0.0, 90.0) = 38.0;
// Cone de la face avant. Doit rester en dessous de la portee du dessin, sinon
// une griffe se fait trancher net en plein trait.
uniform float claw_front_min : hint_range(-1.0, 1.0) = 0.30;

group_uniforms skinning;
// Une matrice par os a griffes, et l'identifiant de cet os. Le tableau est de
// taille fixe : `claw_paws` dit combien de ses entrees comptent.
uniform int claw_paws : hint_range(0, 4) = 0;
uniform int claw_bone[4];
uniform mat4 paw_undo[4];

varying vec3 v_style;
varying vec3 v_object_pos;
varying vec3 v_paw_pos;
// flat : les trois sommets d'un triangle appartiennent au meme os (poids
// rigides, "Pipeline 3D" piege n°3), interpoler cet indice n'aurait aucun sens.
varying flat int v_paw;

#include "res://shaders/cel_core.gdshaderinc"
#include "res://shaders/cel_sun.gdshaderinc"

// Pose un aplat franc si la distance signee passe sous zero. Meme fonction que
// dans cel_face : un detail peint est un APLAT, jamais un degrade (§2bis).
//
// `aa` est une DEMI-BANDE en unites d'espace patte, mesuree a l'ecran par
// fragment(). Elle remplace un uniform `feature_aa` a 0,012 qui etait une
// largeur d'espace OBJET : calibre au banc, il tombait sous le pixel a taille
// de jeu et le smoothstep redevenait un step. Meme defaut et meme parade que
// dans cel_face — voir la note detaillee la-bas.
vec3 paint(vec3 under, float dist, float aa, vec3 col) {
	return mix(col, under, smoothstep(-aa, aa, dist));
}

void vertex() {
	v_style = COLOR.rgb;
	v_object_pos = VERTEX;
	v_paw = -1;
	v_paw_pos = vec3(0.0);

	// L'os porteur = celui de poids maximum. Avec des poids rigides c'est le
	// seul non nul, mais rien ne garantit qu'il soit range en premier.
	int bone = int(BONE_INDICES.x);
	float best = BONE_WEIGHTS.x;

	if (BONE_WEIGHTS.y > best) { best = BONE_WEIGHTS.y; bone = int(BONE_INDICES.y); }
	if (BONE_WEIGHTS.z > best) { best = BONE_WEIGHTS.z; bone = int(BONE_INDICES.z); }
	if (BONE_WEIGHTS.w > best) { best = BONE_WEIGHTS.w; bone = int(BONE_INDICES.w); }

	for (int i = 0; i < claw_paws; i++) {
		if (claw_bone[i] == bone) {
			v_paw = i;
			v_paw_pos = (paw_undo[i] * vec4(VERTEX, 1.0)).xyz;
		}
	}
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

	// UN PIXEL, EN UNITES D'ESPACE PATTE — meme geste que dans cel_face et que
	// dans les six shaders de FX.
	//
	// ⚠️ Calcule ICI, avant le `if (v_paw >= 0)` et avant le cone de face
	// avant : une derivee dans un branchement non uniforme est indefinie en
	// GLSL, les pixels voisins du quad n'ayant pas forcement pris la meme
	// branche. `v_paw_pos` vaut zero hors des pattes a griffes, la normalize
	// est donc gardee.
	vec3 paw_dir = normalize(v_paw_pos + vec3(0.0, 0.0, 1e-6));
	float claw_pitch = radians(claw_pitch_deg);
	vec3 claw_fwd = vec3(0.0, sin(claw_pitch), cos(claw_pitch));
	vec3 claw_up = vec3(0.0, cos(claw_pitch), -sin(claw_pitch));
	vec3 claw_right = vec3(1.0, 0.0, 0.0);
	vec2 claw_uv = vec2(dot(paw_dir, claw_right), dot(paw_dir, claw_up));
	float ps = max(max(fwidth(claw_uv.x), fwidth(claw_uv.y)), 1e-6);
	float aa = ps * 0.75;

	vec3 local = base_color.rgb;
	float lit = step(threshold - bias + jitter, dot(n, normalize(light_dir)));
	vec3 shadow_col = warm_shadow(local, shadow_hue_shift, shadow_saturation, shadow_value);
	vec3 col = mix(shadow_col, local, lit);

	if (use_vertex_style && accent_strength > 0.0) {
		float accent = step(accent_threshold, v_style.b) * lit;
		col = mix(col, accent_color.rgb, accent * accent_strength);
	}

	// --- les griffes ------------------------------------------------------
	// Posees APRES le cluster : ce sont des traits dessines par-dessus la
	// fourrure, pas une autre couleur de pelage. C'est la difference avec la
	// bavette du visage, qui entre dans le cluster avant lui.
	if (v_paw >= 0 && dot(paw_dir, claw_fwd) > claw_front_min) {
		for (int i = 0; i < 3; i++) {
			float dist = sd_segment(claw_uv, claws[i].xy, claws[i].zw) - claw_weight;
			col = paint(col, dist, aa, claw_color.rgb);
		}
	}

	ALBEDO = col;
	// L'aplat peint part en EMISSION : c'est lui qui survit a la coupure
	// du soleil, au pixel pres. Voir le bandeau de cel_sun.gdshaderinc.
	EMISSION = ALBEDO;
}
