// L'impact frame — "Visual Art Direction" §8.
//
// UNE a DEUX frames de flash ambre plein cadre quand le chat encaisse un coup.
// Ce n'est pas un effet continu : c'est une frame DESSINEE qui remplace
// l'image, comme dans un anime cellulo. Elle tient, puis disparait d'un coup —
// jamais de fondu (§8 : "les FX tiennent puis disparaissent d'un coup").
//
// Deux regles de la DA contraignent entierement le melange :
//
//   * "jamais blanc pur" (§8). L'ambre #D4A860 de §4 l'interdit par
//     construction : son canal bleu plafonne bien sous 1, donc aucun pixel ne
//     peut virer au blanc, meme a intensite maximale.
//
//   * le flash doit se lire comme de la LUMIERE, pas comme un calque de
//     couleur. Un simple mix vers l'ambre ASSOMBRIRAIT l'image : le parquet
//     parchemin est a ~0,93 de luminance, l'ambre a ~0,72. Le fond virerait au
//     terne a la frame precise ou il doit claquer.
//
// D'ou le melange en "screen" plutot qu'en mix : il ne peut que remonter une
// valeur, et il la remonte d'autant plus qu'elle est basse. Le chat noir, les
// traits d'encre et les ennemis s'allument franchement ; le parquet, deja
// clair, bouge a peine. C'est exactement le comportement d'une pellicule
// surexposee une frame — et c'est ce qui fait lire le flash comme de l'image
// et non comme un voile pose dessus.
//
// MAIS le screen seul ne suffit pas, et c'est mesure, pas suppose : sur une
// premiere version le flash faisait BAISSER la chaleur moyenne de l'image de
// 1,7 (mesure sur les frames enregistrees). Logique — screen remonte les trois
// canaux a peu pres autant sur un fond deja clair, donc il eclaircit sans
// rechauffer, et le parquet virait au creme delave. §8 demande un flash
// AMBRE, pas un flash pale.
//
// D'ou la seconde etape : on rebascule le resultat vers l'ambre A LUMINANCE
// CONSTANTE. On ne touche donc qu'a la teinte — le gain de lumiere du screen
// est integralement conserve, et l'image entiere prend la couleur au lieu de
// se decolorer. Le chat reste plus sombre que le parquet : la silhouette tient
// pendant le flash, ce qui interdit qu'il se lise comme un carton de couleur.

shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// Ambre Ghibli #D4A860 (§4). Pousse depuis impact_frame.gd, ou vivent les
// couleurs — la DA est du ressort du GDScript dans ce projet, pas du shader.
uniform vec4 flash_color : source_color = vec4(0.66, 0.37, 0.12, 1.0);

// Intensite de la pose courante. A 0 le shader est l'identite ; le ColorRect
// est de toute facon cache hors flash, il ne coute donc rien au repos.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

// Part de la bascule vers l'ambre, a luminance egale. C'est ce reglage qui
// distingue un flash AMBRE d'un flash pale (voir l'entete).
uniform float warmth : hint_range(0.0, 1.0) = 0.60;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	// 1. La lumiere : remonte les sombres, laisse les clairs tranquilles.
	vec3 lit = 1.0 - (1.0 - col) * (1.0 - flash_color.rgb);

	// 2. La couleur : le meme pixel, a la meme luminance, mais en ambre.
	vec3 warm = clamp(
		flash_color.rgb * dot(lit, LUMA) / max(dot(flash_color.rgb, LUMA), 1e-4),
		0.0,
		1.0
	);

	COLOR = vec4(mix(col, mix(lit, warm, warmth), flash), 1.0);
}
