// L'ILLUSTRATION PROJETEE — le decor peint (2026-08-21)
//
// `cel_toon.gdshader` MOINS le cluster, PLUS une texture. Ce n'est pas un
// reglage de cel_toon : le cluster y est la structure du fragment(), pas une
// option. Voir "Pipeline 3D" §4 et "Visual Art Direction" §2quater.
//
// LE PRINCIPE, EN UNE LIGNE : le maillage porte la POSITION, l'illustration
// porte le DESSIN. L'UV a ete CUITE au build (`tools/build_coffee_table.py`),
// par une projection orthographique a 44,02° de plongee — l'axe optique reel de
// `camera_rig.gd`, `look_height` comprise. Elle ne peut donc plus glisser, quoi
// que fasse la camera.
//
// ⛔ CE QUE CE SHADER NE FAIT PAS, ET AUCUN DE CES POINTS N'EST UN OUBLI :
//
//   * pas de `step(NdotL)`. L'illustration PORTE DEJA ses deux tons — elle a
//     ete demandee comme ca (§4.8 des prompts). Recalculer un cluster par-dessus
//     poserait une SECONDE frontiere d'ombre en travers de la premiere, soit le
//     defaut exact que §2ter·2 interdit ;
//   * pas de `warm_shadow()`, pour la meme raison : l'ombre chaude est peinte ;
//   * pas de biais `Attr_Style.G` — il n'y a plus de seuil a biaiser. Le canal
//     est laisse a 0,5 par le build, et le canal B a 0,0 ;
//   * pas d'accent de brillance — il est dans l'image.
//
// ✅ CE QU'IL GARDE, ET C'EST CE QUI LE RATTACHE AU RESTE DU JEU :
//
//   * `Attr_Style.R` sert toujours — mais il est lu par `cel_outline`, en
//     next_pass, pas ici. Le contour est de la GEOMETRIE, il ignore la texture ;
//   * `cel_sun.gdshaderinc` est inclus TEL QUEL. C'est la seule light() du
//     projet et elle le reste. Le test d'acceptation de §6bis vaut donc ici
//     aussi : `--sun=off` rend le pixel exact de l'illustration.
//
// A utiliser avec cel_outline.gdshader en next_pass, au facteur mobilier de
// 50 % (`CelProp.OUTLINE_SCALE`).

shader_type spatial;
render_mode cull_back, ambient_light_disabled, specular_disabled;

group_uniforms illustration;

// `filter_linear_mipmap_anisotropic` n'est pas un gout : a 44° de plongee
// TOUTES les surfaces sont rasantes, et c'est precisement le cas que le filtre
// anisotrope existe pour traiter ("Pipeline 3D" §3). Sans mipmaps la texture
// gresille des qu'elle s'eloigne — le defaut de bord que MSAA 4x a ete pose
// pour supprimer, reintroduit par une autre porte.
uniform sampler2D illustration : source_color, filter_linear_mipmap_anisotropic;

// Repli quand l'illustration manque : `cel_prop.gd` previent deja, mais un
// `sampler2D` non affecte rend du NOIR — un meuble noir ne ressemble pas a une
// texture absente, il ressemble a un bug d'eclairage. La couleur de repli, elle,
// se lit tout de suite comme « l'image n'est pas la ».
uniform vec4 fallback_color : source_color = vec4(0.831, 0.659, 0.376, 1.0);
uniform bool has_illustration = true;

#include "res://shaders/cel_sun.gdshaderinc"

void fragment() {
	vec3 painted = has_illustration
		? texture(illustration, UV).rgb
		: fallback_color.rgb;

	ALBEDO = painted;
	// L'aplat peint part en EMISSION, comme partout ailleurs dans ce jeu :
	// c'est lui qui survit a la coupure du soleil, au pixel pres. `light()` ne
	// fait que RETRANCHER un pas d'ombre chaude la ou une ombre PORTEE tombe.
	// Voir le bandeau de cel_sun.gdshaderinc.
	EMISSION = ALBEDO;
}
