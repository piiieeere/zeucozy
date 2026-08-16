shader_type canvas_item;

// Lignes de vitesse — le seul emprunt franc au manga de toute l'interface.
//
// "Visual Art Direction" §9.3 : elles ne servent QUE les moments (niveau, K.O.).
// Permanentes, elles deviendraient un fond, et un fond ne dit plus "il se passe
// quelque chose".
//
// Le trou central n'est pas decoratif : c'est lui qui laisse le carton lisible.
// Des lignes qui vont jusqu'au centre passent SOUS le texte et le hachent.

uniform vec4 line_color : source_color = vec4(0.239, 0.169, 0.102, 0.55);
uniform float line_count = 84.0;

// Rayon de depart moyen, en fraction de la demi-hauteur.
uniform float inner_radius = 0.34;

uniform float seed = 0.0;

// Ouverture, pilotee EN PAS depuis le GDScript.
uniform float reveal = 1.0;

float hash11(float n) {
	return fract(sin(n * 127.1 + seed * 13.7) * 43758.5453123);
}

void fragment() {
	// Taille deduite du shader — meme raison que dans ui_frame.gdshader.
	vec2 rect_size = 1.0 / max(fwidth(UV), vec2(1e-6));

	vec2 c = (UV - 0.5) * rect_size;
	float half_h = max(rect_size.y * 0.5, 1.0);

	float r = length(c) / half_h;
	float a = atan(c.y, c.x) / TAU + 0.5;

	float cell = floor(a * line_count);
	float h = hash11(cell);
	float h2 = hash11(cell + 31.0);

	// Largeur angulaire propre a chaque trait. C'est l'IRREGULARITE qui fait la
	// main ; des traits tous identiques font une mire de reglage.
	float width = mix(0.16, 0.46, h);
	float edge = abs(fract(a * line_count) - 0.5);

	// Chaque trait demarre a son propre rayon. Sinon ils convergent tous sur un
	// meme cercle net et le trou central se lit comme un disque decoupe au
	// compas — exactement ce qu'un trait a la main ne fait pas.
	float start = inner_radius * mix(0.75, 1.75, h2);

	// L'epaisseur en pixels croit avec le rayon, puisque la largeur est
	// ANGULAIRE : fin au centre, epais au bord. C'est la forme meme du trait de
	// vitesse au manga, et elle sort gratuitement du repere polaire.
	float on = 1.0 - smoothstep(width * 0.5 - 0.04, width * 0.5, edge);
	on *= smoothstep(start, start + 0.10, r);
	on *= clamp(reveal, 0.0, 1.0);

	COLOR = vec4(line_color.rgb, line_color.a * on);
}
