// La couche de tele d'epoque — "Visual Art Direction" §8bis.
//
// Deux effets, tous deux discrets, appliques sur l'image finale :
// grain argentique et vignette chaude.
//
// La HALATION a ete retiree le 2026-08-16. Elle etait la troisieme couche
// (bave ambre autour des zones claires, calculee par ecart au flou) : elle
// marchait, mais elle chargeait l'image sans que le jeu y gagne. §15 tranche
// dans ce sens — lisibilite > detail. Son diagnostic reste dans la doc, il ne
// faut pas le reperdre si on la rebranche un jour : elle ne peut PAS se
// seuiller sur la luminance absolue, la palette parchemin etant deja a ~0,93.
//
// Ce qui est VOLONTAIREMENT absent, et ne doit pas etre rajoute :
// le tremblement du signal hertzien (nauseeux sur une run de 20 minutes),
// le saignement chromatique et les lignes de balayage (ils nuisent a la
// lecture dans une arene chargee), et tout bloom froid ou bleute.
//
// §15 tranche : ces effets doivent se remarquer quand on les COUPE, pas
// quand on les regarde.

shader_type canvas_item;

// filter_linear et non filter_linear_mipmap : plus personne ne lit l'ecran en
// LOD depuis le retrait de la halation, et la chaine de mipmaps de l'ecran
// etait regeneree a chaque frame pour elle seule.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

group_uniforms grain;
uniform float grain_amount : hint_range(0.0, 0.15) = 0.04;
// Le grain doit BOUILLIR A LA CADENCE DE L'ANIMATION, pas a 60 (§7).
// Sur 3s a 60 fps = 20 motifs par seconde. A 60, il se lit comme un bruit
// numerique et trahit tout le travail de cellulo.
uniform float grain_hz = 20.0;
uniform float grain_size : hint_range(1.0, 4.0) = 1.5;

group_uniforms vignette;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.30;
uniform float vignette_start : hint_range(0.0, 1.4) = 0.72;
uniform vec4 vignette_tint : source_color = vec4(0.62, 0.50, 0.40, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// --- vignette chaude : recentre le regard, pose l'epoque -----------------
	float edge = smoothstep(vignette_start, 1.42, length(SCREEN_UV - vec2(0.5)) * 2.0);
	col = mix(col, col * vignette_tint.rgb, edge * vignette_strength);

	// --- grain argentique ----------------------------------------------------
	vec2 cell = floor(SCREEN_UV / SCREEN_PIXEL_SIZE / grain_size);
	float step_time = floor(TIME * grain_hz);
	col += (hash21(cell + vec2(step_time, step_time * 1.7)) - 0.5) * grain_amount;

	COLOR = vec4(col, 1.0);
}
