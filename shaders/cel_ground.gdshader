// Le sol — parquet peint, facon fond d'anime TV 80-90.
//
// Remplace la grille de quads du prototype. Un fond d'anime n'est pas un
// quadrillage technique : c'est une surface PEINTE, ou chaque lame a sa
// valeur propre et ou les joints sont des traits d'encre trembles, d'epaisseur
// inegale, qui depassent parfois au croisement.
//
// Tout tient dans UN plan et UN materiau. Le motif est ancre sur les
// coordonnees MONDE, pas sur l'UV : la taille du plan peut changer sans que le
// parquet bouge sous les pieds du chat.
//
// Trois regles de DA gouvernent ce fichier :
//   - §2bis  aplats francs, aucun degrade, aucun PBR
//   - §2ter·1  le trait est de l'encre : epaisseur variable, couleur locale,
//              depassements
//   - §2ter·2  l'ombre est une forme dessinee. Un sol plat a une normale
//              constante : sa lumiere ne peut etre QUE peinte.

shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, specular_disabled;

group_uniforms lames;
// Longueur x largeur d'une lame, en metres. Calibre pour le cadre de jeu :
// le chat fait 1,86 unite, le cadre montre ~29 m — une lame de 1,2 m de large
// donne ~10 rangees a l'ecran. Plus fin, le parquet grouille et concurrence
// les personnages (§15 : lisibilite > detail).
uniform vec2 plank_size = vec2(6.0, 1.2);

// Trois valeurs de bois, jamais melangees entre elles : chaque lame en prend
// UNE. C'est ce qui fait un parquet plutot qu'un degrade de bois.
//
// ⚠️ Ce sont trois VALEURS d'un meme bois, pas trois couleurs de la palette.
// Premier essai fait avec le ble dore, le parchemin et l'ambre de §4 : les
// lames ambre sautaient aux yeux une par une, le sol se lisait comme un
// damier orange et volait la vedette au chat. §5 le disait deja — une couleur
// principale par objet, plus son ombre et son highlight.
uniform vec4 wood_mid : source_color = vec4(0.910, 0.831, 0.659, 1.0);   // #E8D4A8 ble dore
uniform vec4 wood_light : source_color = vec4(0.941, 0.878, 0.745, 1.0); // #F0E0BE
uniform vec4 wood_dark : source_color = vec4(0.859, 0.757, 0.565, 1.0);  // #DBC190

uniform float light_plank_ratio : hint_range(0.0, 1.0) = 0.30;
uniform float dark_plank_ratio : hint_range(0.0, 1.0) = 0.22;

// Micro-variation de valeur d'une lame a l'autre — la matiere de peinture de
// §2ter·3, obtenue sans texture. A garder tres bas : au-dela de 0,06 le sol
// devient tachete et se met a clignoter quand la camera bouge.
uniform float plank_jitter : hint_range(0.0, 0.12) = 0.035;

group_uniforms trait;
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0); // #3D2B1A
// Trait colore : le joint tire vers le bois qu'il cerne, il n'est jamais un
// brun uniforme (§2ter·1, meme reglage que cel_outline).
uniform float ink_tint : hint_range(0.0, 1.0) = 0.22;

uniform float joint_width : hint_range(0.005, 0.2) = 0.05;
// Le trait gonfle et maigrit le long du joint. A 0, on retombe sur le fil de
// fer que le style refuse.
uniform float joint_variation : hint_range(0.0, 1.0) = 0.6;
// Tremblement du joint, en metres. Une main, pas une regle.
uniform float joint_wobble : hint_range(0.0, 0.3) = 0.11;
// Depassement au croisement, en metres — le trait de crayon mal arrete.
uniform float joint_overshoot : hint_range(0.0, 0.5) = 0.24;

group_uniforms flaques;
// Echelle de la flaque de lumiere, en metres. ~26 m pour ~1 flaque par ecran.
uniform float pool_scale : hint_range(4.0, 80.0) = 26.0;
uniform float pool_level : hint_range(0.0, 1.0) = 0.50;
uniform float pool_wobble : hint_range(0.0, 1.0) = 0.40;

// Le ton clair tire vers l'ambre chaud : c'est une tache de soleil, pas une
// simple eclaircie.
uniform vec4 sun_color : source_color = vec4(1.0, 0.839, 0.647, 1.0); // #FFD6A5
uniform float sun_strength : hint_range(0.0, 1.0) = 0.22;

// Le ton d'ombre reste derive en TSV : le gris multiplie est structurellement
// impossible (§5.1). Ecart volontairement faible — c'est un sol, pas un mur.
uniform float shadow_hue_shift : hint_range(-0.2, 0.2) = -0.02;
uniform float shadow_saturation : hint_range(0.5, 2.0) = 1.10;
uniform float shadow_value : hint_range(0.1, 1.0) = 0.93;

varying vec3 v_world;

#include "res://shaders/cel_core.gdshaderinc"
#include "res://shaders/cel_floor.gdshaderinc"

// Decalage horizontal d'une rangee. Pose a l'anglaise : deux rangees voisines
// ne doivent jamais aligner leurs joints de tete.
float row_shift(float row) {
	return hash12(vec2(row, 7.31));
}

// Joints de tete (les petits cotes des lames) d'une rangee donnee, evalues en
// `p`. Les rangees voisines ayant un decalage different, ces traits s'arretent
// d'eux-memes au joint long — sauf quand on les laisse deborder.
//
// `reach` borne le trait : distance au joint long au-dela de laquelle il ne
// s'affiche plus. Pour la rangee courante, c'est toute la largeur de la lame ;
// pour la rangee voisine, c'est le depassement, tire au sort par croisement.
float head_joints(vec2 p, float row, float wobble, float d_long, float reach_own) {
	float colf = (p.x + wobble) / plank_size.x + row_shift(row);
	float f = fract(colf);
	float d = min(f, 1.0 - f) * plank_size.x;

	float w = joint_width * 0.9;
	w *= 1.0 + (vnoise(vec2(p.y * 0.7, row * 5.3)) - 0.5) * 2.0 * joint_variation;

	return ink_line(d, w) * step(d_long, reach_own);
}

// Tirage du depassement a un croisement donne. Deux traits sur trois s'arretent
// net : un depassement partout se lirait comme un bug, pas comme un croquis
// (§2ter·1).
float overshoot_at(vec2 p, float row, float wobble) {
	float colf = (p.x + wobble) / plank_size.x + row_shift(row);
	float pick = hash12(vec2(floor(colf + 0.5), row * 2.7));
	return joint_overshoot * max(0.0, pick * 3.0 - 2.0);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz;

	// Tremblement du trace. Le joint long ondule en z le long de x, le joint de
	// tete ondule en x le long de z — chacun perpendiculairement a lui-meme.
	float wob_long = (vnoise(vec2(p.x * 0.33, 11.0)) - 0.5) * joint_wobble;
	float wob_head = (vnoise(vec2(p.y * 0.33, 41.0)) - 0.5) * joint_wobble;

	// --- decoupe en lames ---------------------------------------------------
	float rowf = (p.y + wob_long) / plank_size.y;
	float row = floor(rowf);
	float in_row = fract(rowf);
	float d_long = min(in_row, 1.0 - in_row) * plank_size.y;

	float colf = (p.x + wob_head) / plank_size.x + row_shift(row);
	float col = floor(colf);

	// --- l'encre ------------------------------------------------------------
	// Joint long : epaisseur variable le long de x, propre a chaque rangee.
	float w_long = joint_width;
	w_long *= 1.0 + (vnoise(vec2(p.x * 0.5, row * 3.7)) - 0.5) * 2.0 * joint_variation;
	float ink = ink_line(d_long, w_long);

	// Joints de tete de la rangee courante — bornes a la largeur de la lame,
	// donc jamais coupes.
	ink = max(ink, head_joints(p, row, wob_head, d_long, plank_size.y));

	// Depassement : le joint de tete de la rangee VOISINE mord de quelques
	// centimetres dans la notre. C'est ce qui donne le croisement dessine.
	float neighbour = row + (in_row < 0.5 ? -1.0 : 1.0);
	float reach = overshoot_at(p, neighbour, wob_head);
	ink = max(ink, head_joints(p, neighbour, wob_head, d_long, reach));

	// --- la couleur ---------------------------------------------------------
	float pick = hash12(vec2(col, row));
	vec3 wood = mix(wood_mid.rgb, wood_light.rgb, step(pick, light_plank_ratio));
	wood = mix(wood, wood_dark.rgb, step(1.0 - dark_plank_ratio, pick));
	wood *= 1.0 + (hash12(vec2(row, col) + 3.1) - 0.5) * plank_jitter;

	vec3 shade = warm_shadow(wood, shadow_hue_shift, shadow_saturation, shadow_value);
	vec3 sun = mix(wood, sun_color.rgb, sun_strength);
	vec3 col_out = mix(shade, sun, light_pool(p, pool_scale, pool_level, pool_wobble));

	col_out = mix(col_out, mix(ink_color.rgb, col_out, ink_tint), clamp(ink, 0.0, 1.0));

	ALBEDO = col_out;
}
