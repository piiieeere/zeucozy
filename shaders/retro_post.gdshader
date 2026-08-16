// La couche de tele d'epoque — "Visual Art Direction" §8bis.
//
// Trois effets, tous discrets, appliques sur l'image finale :
// grain argentique, halation chaude, vignette chaude.
//
// Ce qui est VOLONTAIREMENT absent, et ne doit pas etre rajoute :
// le tremblement du signal hertzien (nauseeux sur une run de 20 minutes),
// le saignement chromatique et les lignes de balayage (ils nuisent a la
// lecture dans une arene chargee), et tout bloom froid ou bleute.
//
// §15 tranche : lisibilite > detail. Ces trois effets doivent se remarquer
// quand on les COUPE, pas quand on les regarde.

shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

group_uniforms grain;
uniform float grain_amount : hint_range(0.0, 0.15) = 0.04;
// Le grain doit BOUILLIR A LA CADENCE DE L'ANIMATION, pas a 60 (§7).
// Sur 3s a 60 fps = 20 motifs par seconde. A 60, il se lit comme un bruit
// numerique et trahit tout le travail de cellulo.
uniform float grain_hz = 20.0;
uniform float grain_size : hint_range(1.0, 4.0) = 1.5;

group_uniforms halation;
// Seuil de SOURCE : quelles zones ont le droit de baver. Bas volontairement —
// ce n'est pas lui qui protege l'image, c'est le calcul par ecart (voir plus bas).
uniform float halation_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float halation_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 halation_tint : source_color = vec4(1.0, 0.78, 0.45, 1.0);
// Le flou large se prend gratuitement dans les mipmaps de l'ecran.
uniform float halation_lod : hint_range(0.0, 8.0) = 4.0;

group_uniforms vignette;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.30;
uniform float vignette_start : hint_range(0.0, 1.4) = 0.72;
uniform vec4 vignette_tint : source_color = vec4(0.62, 0.50, 0.40, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// --- halation : la lumiere bave, en ambre --------------------------------
	//
	// Calculee par ECART au flou, pas sur la luminance absolue. La palette du
	// jeu est un parchemin a ~0,93 de luminance : un seuil absolu allumerait
	// l'ecran entier et delaverait tous les aplats. L'ecart, lui, ne vaut
	// quelque chose que la ou un voisinage clair borde un sujet plus sombre —
	// c'est-a-dire exactement la ou une pellicule bave, et rien sur une
	// grande surface claire uniforme.
	vec3 blurred = textureLod(screen_tex, SCREEN_UV, halation_lod).rgb;
	vec3 bleed = max(blurred - col, vec3(0.0));
	float source = smoothstep(halation_threshold, 1.0, dot(blurred, vec3(0.299, 0.587, 0.114)));
	col += bleed * halation_tint.rgb * source * halation_strength;

	// --- vignette chaude : recentre le regard, pose l'epoque -----------------
	float edge = smoothstep(vignette_start, 1.42, length(SCREEN_UV - vec2(0.5)) * 2.0);
	col = mix(col, col * vignette_tint.rgb, edge * vignette_strength);

	// --- grain argentique ----------------------------------------------------
	vec2 cell = floor(SCREEN_UV / SCREEN_PIXEL_SIZE / grain_size);
	float step_time = floor(TIME * grain_hz);
	col += (hash21(cell + vec2(step_time, step_time * 1.7)) - 0.5) * grain_amount;

	COLOR = vec4(col, 1.0);
}
