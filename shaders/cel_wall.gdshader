// Le MUR d'arene — la paroi qui porte les baies.
//
// Ecrit le 2026-08-20 avec les fenetres, et c'est le chemin que
// "Prompts de Generation" §4.7 designe : `tools/build_wall.py` + `cel_wall`,
// poses par `arena._build_walls()`. Le modele Blender n'a pas ete necessaire —
// une travee est une poignee de boites orthogonales, et §4.7 demande
// justement des « COUNTABLE MASSES ». Ce fichier ne porte donc que ce qui est
// DESSINE sur ces boites ; la geometrie vit dans `arena.gd`.
//
// ─── CE QU'IL FAIT DE PLUS QUE cel_toon ───
//
// Une CIMAISE — un trait d'encre horizontal, a hauteur fixe, ancre au MONDE.
// §4.7 : « COMPOSE IN HORIZONTAL BANDS. Sous une camera a 45° une surface
// verticale est ecrasee : un mur de 2,5 m ne rend qu'1,8 m de hauteur
// apparente. » Un trait horizontal survit a cet ecrasement, un montant
// vertical non — c'est le piege de la queue de souris, a l'echelle du decor.
//
// ⚠️ ET IL EST A LA MOITIE DU POIDS DU CONTOUR, deliberement. §4.7 tranche
// deux poids d'encre sur le meme objet : PLEIN pour l'arete qui dit « ici on
// ne passe plus », REDUIT pour tout ce qui est dessine a l'interieur. Un
// quadrillage a l'encre pleine sur la plus grande surface de l'image ramene
// le regard sur le decor, ce que §15 et la nord etoile interdisent.
//
// ⚠️ AUCUNE GRANDE FORME CLAIRE N'EST PEINTE ICI. Le rai de soleil est REEL
// (§6bis) et il vient de la geometrie des baies, pas d'un motif. Le motif
// peint a deja ete retire une fois du sol, pour une raison qui vaut ici mot
// pour mot : ancre au monde, il defile a l'ecran des que le chat marche.

shader_type spatial;
render_mode ambient_light_disabled, cull_back, specular_disabled;

group_uniforms couleur;
// ⚠️ LA VALEUR DU MUR CONTRE LE PARQUET, et c'est la regle de la blouse du
// veterinaire en plus fort — le mur est la plus grande masse de l'image.
//
// Le creme #F7EFE0 est INTERDIT ici : c'est deja le blanc du pelage tuxedo, le
// cœur de la griffure et le texte de l'UI. Et le precedent est double, le
// canape descendu a #8FBAC9 et la boite de thon partie de #8FBAC9 et non de
// #A0C8D8 : une valeur tombee dans la plage des lames claires du parquet
// DISSOUT l'objet. La parade est celle deja payee deux fois — descendre la
// valeur et rechauffer la teinte, jamais baisser l'alpha, rien n'est
// translucide.
//
// #9C7B5C — luma 0,50, et la valeur a ete choisie EN CAPTURE, contre les
// trois voisines que le mur touche vraiment. §16 interdit de trancher ca en
// raisonnant, et le premier essai (#C8AC8C, luma 0,69) l'a montre : il se
// lisait bien contre le parquet en plein soleil (0,87) et se DISSOLVAIT dans
// le sol a son propre pied — qui est a l'ombre du mur (0,68) par construction,
// puisque le soleil vient de derriere lui. Seul le trait d'encre les separait.
//
// Les deux fenetres possibles etaient donc ≤ 0,50 ou ≥ 0,78. La haute passe
// trop pres du parquet clair (#F0E0BE, 0,87) sur le mur que le soleil eclaire
// de face, et elle marche vers le creme interdit. La basse tient partout :
//
//   sol a l'ombre  0,68  |  sol au soleil  0,87  |  souris taupe  0,59
//
// ⚠️ La souris DOIT rester plus claire que le mur, pas l'inverse (§15) : un
// ennemi qui longe la paroi se lit sur elle. A 0,69 les deux se confondaient.
uniform vec4 base_color : source_color = vec4(0.612, 0.482, 0.361, 1.0);

uniform float shadow_hue_shift : hint_range(-0.2, 0.2) = -0.02;
uniform float shadow_saturation : hint_range(0.5, 2.0) = 1.15;
// Plus haut que sur un personnage (0,65) : le mur est la plus grande masse de
// l'image, et un cluster franc sur une masse pareille en fait un objet, pas un
// fond. Il lui faut la separation de ses faces, rien de plus.
uniform float shadow_value : hint_range(0.1, 1.0) = 0.86;

group_uniforms lumiere;
// LA MEME direction que cel_toon, et ce n'est pas une coincidence : c'est le
// soleil DESSINE, celui qui decide des clusters. Le soleil REEL, celui qui
// pose les rais, est une DirectionalLight3D et n'a rien a voir avec ce vecteur.
uniform vec3 light_dir = vec3(-0.35, 0.85, 0.4);
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;

group_uniforms cimaise;
// Hauteur du trait, en metres au-dessus du sol.
//
// ⚠️ 0,55 M, DONC EN PLEIN DANS LE TIERS BAS — et §4.7 dit exactement le
// contraire : « rien d'important ne se joue dans le tiers bas du mur », « il
// n'atteint jamais l'ecran ». La capture dit l'inverse, et c'est elle qui
// tranche : le mur est COUPE PAR LE HAUT (son couvre-mur est hors cadre), donc
// la seule partie qu'on voie toujours est justement sa BASE. Le premier essai
// a 1,55 m posait le trait entre l'appui et le linteau, c'est-a-dire dans le
// vide de la baie — il n'existait que sur les trumeaux.
uniform float rail_height = 0.55;
uniform float rail_width = 0.035;
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0); // #3D2B1A
// Le trait tire vers la couleur qu'il cerne (色トレス, "Convention Blender" §5.4).
uniform float ink_tint : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_world;
varying vec3 v_world_normal;

#include "res://shaders/cel_core.gdshaderinc"
#include "res://shaders/cel_sun.gdshaderinc"

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float ndl = dot(normalize(v_world_normal), normalize(light_dir));
	float lit = step(threshold, ndl);

	vec3 local = base_color.rgb;
	vec3 col = mix(warm_shadow(local, shadow_hue_shift, shadow_saturation, shadow_value), local, lit);

	// La cimaise. Uniquement sur les faces VERTICALES : posee sur le dessus
	// d'un appui ou d'un couvre-mur elle donnerait une bande large et fausse,
	// puisque la hauteur y est constante sur toute la surface.
	float vertical = 1.0 - abs(v_world_normal.y);
	float d = abs(v_world.y - rail_height);
	float aa = fwidth(d) + 1e-6;
	float rail = (1.0 - smoothstep(rail_width - aa, rail_width + aa, d)) * step(0.5, vertical);
	// Le trait s'eteint quand il devient plus fin qu'un pixel — meme garde que
	// les joints du parquet, qui moiraient au fond du cadre sans elle.
	rail *= 1.0 - smoothstep(rail_width * 1.5, rail_width * 5.0, aa);

	col = mix(col, mix(ink_color.rgb, local, ink_tint), rail);

	ALBEDO = col;
	// L'aplat peint part en EMISSION : c'est lui qui survit a la coupure
	// du soleil, au pixel pres. Voir le bandeau de cel_sun.gdshaderinc.
	EMISSION = ALBEDO;
}
