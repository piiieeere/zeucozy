// Cel-shading 2 tons — variante A
// Traduction en shader Godot du setup Blender decrit dans
// "Visual Art Direction" §2bis et "Convention Blender" §5.1.
//
// Choix assume : unshaded + direction de lumiere en uniform, plutot qu'une
// fonction light(). Le rendu devient deterministe et independant de
// l'environnement, ce qui est exactement ce que demande la DA
// (aucun PBR, vue Standard, aplats francs). Le rig d'eclairage vit ici.
//
// A utiliser avec cel_outline.gdshader en next_pass.

shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, specular_disabled;

group_uniforms couleur;
uniform vec4 base_color : source_color = vec4(0.847, 0.604, 0.333, 1.0);

// Le ton d'ombre n'est jamais saisi a la main : il est derive de la couleur
// locale par decalage TSV. C'est ce qui rend impossible le gris multiplie.
uniform float shadow_hue_shift : hint_range(-0.2, 0.2) = -0.02;
uniform float shadow_saturation : hint_range(0.5, 2.0) = 1.15;
uniform float shadow_value : hint_range(0.1, 1.0) = 0.65;

group_uniforms lumiere;
uniform vec3 light_dir = vec3(-0.35, 0.85, 0.4);
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;

group_uniforms attr_style;
// Passe a true une fois l'attribut Attr_Style cree dans Blender.
// Tant qu'il n'existe pas, COLOR vaut (1,1,1,1) et le biais serait faux.
uniform bool use_vertex_style = false;
uniform float shadow_bias_strength : hint_range(0.0, 2.0) = 1.0;

group_uniforms grain;
uniform float edge_noise : hint_range(0.0, 0.3) = 0.0;
uniform float edge_noise_scale : hint_range(1.0, 200.0) = 35.0;

group_uniforms details_peints;
// Calottes procedurales — portage du masque Blender decrit dans
// "Visual Art Direction" §2bis et "Convention Blender" §5.5.
//
//   dot( normalize(coord_objet_ecrasees), direction ) > seuil  ->  dans la calotte
//
// Sert aux details qui ne doivent PAS etre modelises : yeux (3 calottes
// emboitees : iris / pupille / reflet) et interieur d'oreille (1 calotte).
// Les calottes sont peintes en aplat franc : elles ne captent pas le shading.
// Les suivantes recouvrent les precedentes — ordre = du plus large au plus petit.
uniform int paint_count : hint_range(0, 3) = 0;
uniform vec3 paint_center = vec3(0.0);
uniform vec3 paint_squash = vec3(1.0, 1.0, 1.0);
// |x| avant le calcul : une seule calotte dessine les deux cotes (les deux
// yeux, les deux oreilles). Le centre s'exprime alors en x positif.
uniform bool paint_mirror_x = true;
uniform vec3 paint_dir[3];
uniform float paint_threshold[3];
uniform vec4 paint_color[3] : source_color;

group_uniforms skinning;
// Godot applique le skinning AVANT vertex() : VERTEX arrive deja deforme, et
// un masque calcule dessus derape des que l'os bouge. On defait donc la
// transformation de l'os porteur pour retrouver la position AU REPOS. Exact
// ici parce que le rig est en poids rigides (1 sommet = 1 os).
//
// Deux matrices : une surface peut porter une paire symetrique sur DEUX os
// distincts — les deux oreilles, que |x| dessine d'un seul jeu de formes.
// Le signe de x separe les deux cotes, qui ne se croisent jamais.
uniform mat4 rest_undo;
uniform mat4 rest_undo_right;
uniform bool rest_undo_split = false;

varying vec3 v_style;
varying vec3 v_object_pos;

#include "res://shaders/cel_core.gdshaderinc"

void vertex() {
	v_style = COLOR.rgb;
	mat4 undo = rest_undo;
	if (rest_undo_split && VERTEX.x > 0.0) {
		undo = rest_undo_right;
	}
	v_object_pos = (undo * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// NORMAL est en espace vue dans fragment() : on repasse en monde pour
	// pouvoir la comparer a une direction de lumiere monde.
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float ndl = dot(n, normalize(light_dir));

	// Le biais peint : l'ombre est une forme decidee, pas un calcul (§2ter·2)
	float bias = 0.0;
	if (use_vertex_style) {
		bias = (v_style.g - 0.5) * 2.0 * shadow_bias_strength;
	}

	// Bord de cluster legerement irregulier — un bord de pinceau (§2ter·3)
	float jitter = 0.0;
	if (edge_noise > 0.0) {
		jitter = (hash_noise(floor(v_object_pos * edge_noise_scale)) - 0.5) * edge_noise;
	}

	float lit = step(threshold - bias + jitter, ndl);

	vec3 shadow_col = warm_shadow(base_color.rgb, shadow_hue_shift, shadow_saturation, shadow_value);
	vec3 col = mix(shadow_col, base_color.rgb, lit);

	// Details peints — aplats francs poses par-dessus le cluster
	if (paint_count > 0) {
		vec3 p = v_object_pos;
		if (paint_mirror_x) {
			p.x = abs(p.x);
		}
		vec3 d = normalize((p - paint_center) * paint_squash);
		for (int i = 0; i < paint_count; i++) {
			if (dot(d, normalize(paint_dir[i])) > paint_threshold[i]) {
				col = paint_color[i].rgb;
			}
		}
	}

	ALBEDO = col;
}
