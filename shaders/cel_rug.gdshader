// Les tapis — memes regles que le parquet, un cran au-dessus.
//
// Un tapis de fond d'anime n'est pas un rectangle : c'est une forme posee, aux
// bords un peu mous, cernee d'un trait, avec un liseré interieur qui la fait
// lire comme du tissu et non comme un aplat de couleur.
//
// Ce qui le relie au sol pour qu'il ne se decolle pas : le meme trait d'encre,
// teinte vers la couleur locale.
//
// ⚠️ Il partageait aussi la MEME flaque de lumiere, evaluee en coordonnees
// monde, pour que le soleil traverse le tapis au lieu de s'arreter a son bord.
// La flaque a ete retiree le 2026-08-17 — motif et reglages d'alors dans le
// bandeau en tete de `cel_ground.gdshader`. Le point qui reste valable : sol et
// tapis doivent s'eclairer PAREIL, sinon leur bord commun saute.
//
// Le contour est obtenu par `discard` plutot que par un contour en coque
// inversee : sur une surface plane, la coque pousse ses sommets vers le haut
// et ne produit rien de visible en vue plongeante (meme raison que
// CelStyle.make_flat).

shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, specular_disabled, depth_draw_opaque;

group_uniforms tapis;
uniform vec4 base_color : source_color = vec4(0.784, 0.894, 0.722, 1.0);
// Emprise nominale du tapis, en metres.
uniform vec2 rug_size = vec2(10.0, 8.0);
// Emprise du PLAN qui porte le tapis, en metres. Toujours plus grande que
// `rug_size` : la silhouette ondule, il lui faut de la marge pour deborder
// sans etre tranchee au ras du plan. Sert aussi a convertir l'UV en metres,
// pour que le trait garde la meme epaisseur quelle que soit la taille du tapis.
uniform vec2 plane_size = vec2(11.5, 9.5);

group_uniforms bord;
// Mollesse du bord, en metres. Le tapis n'a pas de cotes droits.
uniform float edge_wobble : hint_range(0.0, 1.5) = 0.55;
// Retrait du liseré interieur, en metres.
uniform float band_inset : hint_range(0.05, 3.0) = 0.55;

group_uniforms trait;
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0); // #3D2B1A
uniform float ink_tint : hint_range(0.0, 1.0) = 0.30;
uniform float ink_width : hint_range(0.005, 0.3) = 0.055;
uniform float ink_variation : hint_range(0.0, 1.0) = 0.5;

varying vec3 v_world;

#include "res://shaders/cel_floor.gdshaderinc"

// Distance signee a un rectangle arrondi. Negatif dedans.
float sd_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p) - half_size + radius;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Metres depuis le centre du tapis. Le PlaneMesh porte un UV 0..1.
	vec2 q = (UV - 0.5) * plane_size;

	// Le bord ondule : un tapis pose n'a pas de cotes droits. Le bruit est
	// ancre au monde, donc deux tapis voisins n'ondulent pas pareil.
	float radius = min(rug_size.x, rug_size.y) * 0.12;
	float sd = sd_rect(q, rug_size * 0.5, radius);
	sd += (vnoise(v_world.xz * 0.55) - 0.5) * edge_wobble;

	// fwidth AVANT toute sortie de fonction : les derivees ne survivent pas a
	// un discard divergent.
	float w = ink_width * (1.0 + (vnoise(v_world.xz * 1.7) - 0.5) * 2.0 * ink_variation);
	// Trait pose A L'INTERIEUR de la silhouette : ce qui deborde serait
	// discarde, et le contour perdrait sa moitie exterieure.
	float outline = ink_line(abs(sd + w), w);
	float band = ink_line(abs(sd + band_inset), w * 0.7);

	if (sd > 0.0) {
		discard;
	}

	// Eclairage uniforme depuis le 2026-08-17 — voir le bandeau en tete de
	// `cel_ground.gdshader`. Le tapis suit le sol : ils ne peuvent pas diverger
	// sur ce point sans que leur bord commun se remette a sauter.
	vec3 col = base_color.rgb;

	float ink = clamp(max(outline, band), 0.0, 1.0);
	col = mix(col, mix(ink_color.rgb, col, ink_tint), ink);

	ALBEDO = col;
}
