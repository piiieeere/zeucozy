// La couche de tele d'epoque — "Visual Art Direction" §8bis.
//
// UN SEUL effet depuis le 2026-08-17 : le grain argentique.
//
// Ce qui a ete retire, et qu'il ne faut pas reperdre :
//
// • LA HALATION — retiree le 2026-08-16. Bave ambre autour des zones claires,
//   calculee par ecart au flou. Elle marchait, mais elle chargeait l'image sans
//   que le jeu y gagne (§15 : lisibilite > detail). Son piege de reglage reste
//   valable pour TOUT effet : elle ne peut PAS se seuiller sur la luminance
//   absolue, la palette parchemin etant deja a ~0,93.
//
// • LA VIGNETTE CHAUDE — retiree le 2026-08-17, a la demande. Brun tres leger
//   sur les bords, cense recentrer le regard. Mesuree avant de couper : c'etait
//   une rampe lisse, sans contour de banding, donc elle n'etait PAS la source
//   des lignes parasites qui ont motive la coupe (voir plus bas). Elle partait
//   quand meme, pour la meme raison que la halation : §15 demande que ces
//   effets se remarquent quand on les COUPE, pas quand on les regarde — et
//   coupee, celle-ci ne manque pas.
//
//   ⚠️ Si on la rebranche : elle assombrissait par `mix(col, col * tint, edge)`
//   avec tint = (0.62, 0.50, 0.40), force 0.30, depart a 0.72 du rayon.
//
// Ce qui est VOLONTAIREMENT absent, et ne doit pas etre rajoute :
// le tremblement du signal hertzien (nauseeux sur une run de 20 minutes),
// le saignement chromatique et les lignes de balayage (ils nuisent a la
// lecture dans une arene chargee), et tout bloom froid ou bleute.

shader_type canvas_item;

// filter_linear et non filter_linear_mipmap : plus personne ne lit l'ecran en
// LOD depuis le retrait de la halation, et la chaine de mipmaps de l'ecran
// etait regeneree a chaque frame pour elle seule.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

group_uniforms grain;
uniform float grain_amount : hint_range(0.0, 0.15) = 0.04;
// Le grain BOUILLE A LA CADENCE DE L'ANIMATION, pas a 60 (§7). Sur 3s a
// 60 fps = 20 motifs par seconde. A 60, il se lit comme un bruit numerique et
// trahit tout le travail de cellulo.
uniform float grain_hz = 20.0;
uniform float grain_size : hint_range(1.0, 4.0) = 1.5;

// ⚠️ MAIS LES CELLULES NE TOURNENT PAS ENSEMBLE — voir `grain_stagger`.
//
// Mesure du 2026-08-16, sur les frames du jeu : avec un `floor(TIME * hz)`
// global, TOUS les pixels changeaient au meme instant. L'ecart moyen d'une
// frame a l'autre, sur l'image entiere, faisait un pic de x1,85 toutes les
// 3 frames ; grain coupe, la meme mesure etait PLATE. Autrement dit le grain
// etait la seule chose de l'image a battre a 20 Hz, et il y faisait battre
// tout le reste avec lui : le jeu paraissait tourner a 20 fps alors que le
// temps de frame ne bougeait pas d'un dixieme de milliseconde.
//
// La parade ne touche pas a la cadence : chaque cellule garde ses 20 motifs
// par seconde, mais elles ne les changent plus au meme moment. Localement le
// grain bout toujours sur 3s — ce que §7 demande ; globalement plus rien ne
// clignote d'un bloc. C'est d'ailleurs ce que fait la pellicule : le dessin
// est sur 3s, le grain du support, lui, est neuf a chaque photogramme.
//
// A 0 on retrouve exactement l'ancien comportement, pour comparer.
uniform float grain_stagger : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// --- grain argentique — le seul post-traitement restant -------------------
	vec2 cell = floor(SCREEN_UV / SCREEN_PIXEL_SIZE / grain_size);
	// Le dephasage est tire de la CELLULE, donc fixe dans le temps : une
	// cellule donnee change a intervalle regulier, jamais en avance ni en
	// retard sur elle-meme. Ce sont les cellules entre elles qui sont decalees.
	float phase = hash21(cell + 19.7) * grain_stagger;
	float step_time = floor(TIME * grain_hz + phase);
	col += (hash21(cell + vec2(step_time, step_time * 1.7)) - 0.5) * grain_amount;

	COLOR = vec4(col, 1.0);
}
