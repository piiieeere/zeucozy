// Contour en coque inversee — reconstruction Godot du Solidify de Blender
// Voir "Pipeline 3D" piege n°1 : la coque inversee ne survit PAS a l'export
// glTF, elle doit etre refaite ici. C'est le risque principal du pivot 3D.
//
// A brancher en next_pass sur cel_toon.gdshader.
// Equivalent Blender : Solidify (thickness negatif) + normales retournees
// + backface culling, materiau "outline" en emission.

shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, specular_disabled;

group_uniforms trait;
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0); // #3D2B1A

// Trait colore (色トレス) : le trait n'est jamais un brun uniforme, il tire
// vers la couleur de la zone qu'il cerne. Voir "Convention Blender" §5.4.
uniform vec4 tint_target : source_color = vec4(0.847, 0.604, 0.333, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.2;

group_uniforms epaisseur;
uniform float thickness : hint_range(0.0, 0.2) = 0.02;

// false = epaisseur monde, au plus pres du Solidify Blender.
// true  = epaisseur ecran constante, quelle que soit la distance camera.
uniform bool constant_screen_width = false;

group_uniforms attr_style;
// Le canal R module l'epaisseur : un trait d'encre s'alourdit vers le bas des
// formes et aux jointures, s'allege sur les aretes exposees (§2ter·1).
// A laisser false sur la geometrie sans Attr_Style — COLOR y vaut 1.0, ce qui
// donnerait le trait le plus epais partout.
uniform bool use_vertex_style = false;

void vertex() {
	float w = thickness;

	if (use_vertex_style) {
		w *= COLOR.r;
	}

	if (constant_screen_width) {
		// Compense la distance camera pour garder une largeur ecran stable
		float view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
		w *= max(view_depth, 0.001);
	}

	VERTEX += normalize(NORMAL) * w;
}

void fragment() {
	ALBEDO = mix(ink_color.rgb, tint_target.rgb, tint_amount);
}
