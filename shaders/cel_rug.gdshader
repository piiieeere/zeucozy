// Les tapis — PEINTS A LA MAIN depuis le 2026-08-21.
//
// Le tapis etait dessine par ce shader : un rectangle arrondi, un bord ondule
// au bruit, un trait d'encre et un liseré interieur, le tout module par une
// couleur d'aplat. Il porte desormais une ILLUSTRATION, comme la table basse
// ("Visual Art Direction" §2quater) — et c'est le cas le plus simple de toute
// la technique.
//
// ⭐ POURQUOI IL N'Y A NI UV CUITE NI PROJECTION ICI. Un tapis est PLAT et POSE
// AU SOL. La projection orthographique a 44,02° d'une face horizontale n'est
// qu'un ecrasement uniforme en profondeur — c'est exactement ce que la camera
// refait d'elle-meme. L'illustration vue de dessus EST donc la texture, et
// l'UV du `PlaneMesh` suffit. Aucune matrice, aucun gabarit, aucun recalage :
// `tools/bake_rugs.py` ne fait que cadrer, reduire et remplir le fond.
//
// ⛔ CE QUE CE SHADER NE FAIT PLUS, ET AUCUN DE CES POINTS N'EST UN OUBLI :
//
//   * plus de silhouette calculee. Le bord ondule du tapis est DESSINE, et
//     l'alpha de la planche le porte. Un `sd_rect` par-dessus en redessinerait
//     un second, decale ;
//   * plus de trait ni de liseré. Ils sont dans l'image, a l'encre du dessin ;
//   * plus de `base_color`. La couleur est le dessin — il y a quatre planches,
//     pas une planche et quatre teintes.
//
// ✅ CE QU'IL GARDE, ET C'EST CE QUI LE RATTACHE AU SOL :
//
//   * l'aplat part en EMISSION, comme partout ailleurs ;
//   * `cel_sun.gdshaderinc` est inclus TEL QUEL, donc le tapis et le parquet
//     s'eclairent PAREIL. C'etait deja la seule regle a ne jamais casser ici :
//     deux surfaces qui divergent d'un demi-pouce et leur bord commun saute.
//     Le test d'acceptation de §6bis vaut donc aussi pour les tapis.
//
// ⚠️ LE BORD SE FAIT A LA COUVERTURE, PAS AU `discard`. L'ancien tapis coupait
// sa silhouette au `discard` : un bord franc, non antialiase, que MSAA 4x ne
// rattrape pas (le rejet vaut pour tous les echantillons du fragment). C'etait
// tolerable sur une forme calculee ; ca ne l'est plus sur un trait d'encre
// peint et adouci, dont la moitie de la matiere vit dans le degrade d'alpha.
// `alpha_to_coverage` rend cette douceur aux echantillons de MSAA, qui sont
// deja la et deja payes.

shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled,
	depth_draw_opaque, alpha_to_coverage;

group_uniforms tapis;

// `filter_linear_mipmap_anisotropic`, meme raison que `cel_painted` et en pire :
// le tapis est la surface la PLUS rasante du jeu. Il est a plat, la camera
// plonge a 44° — un texel y est vu deux fois plus court en profondeur qu'en
// largeur, et c'est precisement le cas que le filtre anisotrope traite.
uniform sampler2D rug_art : source_color, filter_linear_mipmap_anisotropic;

group_uniforms bord;

// Le seuil de silhouette. L'alpha des planches est franc — 253 dans le corps,
// 0 dehors, une poignee de texels entre les deux — donc 0,5 tombe au milieu du
// degrade et non sur un de ses cotes.
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;

// La largeur de la bande ou la couverture prend le relais du seuil. Doit rester
// SOUS `alpha_cut`, sinon elle n'a aucun effet (doc Godot, ALPHA_ANTIALIASING_EDGE).
uniform float alpha_edge : hint_range(0.0, 1.0) = 0.3;

#include "res://shaders/cel_sun.gdshaderinc"

void fragment() {
	vec4 art = texture(rug_art, UV);

	ALBEDO = art.rgb;
	// L'aplat peint part en EMISSION : c'est lui qui survit a la coupure du
	// soleil, au pixel pres. Voir le bandeau de cel_sun.gdshaderinc.
	EMISSION = ALBEDO;

	ALPHA = art.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ALPHA_ANTIALIASING_EDGE = alpha_edge;
	// En TEXELS, pas en UV : c'est la densite de la planche qui dit de combien
	// un echantillon de MSAA se deplace dans l'alpha.
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(rug_art, 0));
}
