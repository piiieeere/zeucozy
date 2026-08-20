// Le SOLEIL REEL — l'ombre PORTEE, et rien d'autre.
//
// Ouvert le 2026-08-20 avec les fenetres du mur d'arene, et borne par
// "Visual Art Direction" §6bis. La regle d'or y tient en une ligne :
//
//     la lumiere reelle S'AJOUTE, elle ne REMPLACE rien.
//
// Le cluster 2 tons, l'ombre peinte au canal G, l'accent de brillance au
// canal B et le contour d'encre restent exactement ce qu'ils etaient. Ce
// fichier ne sait faire qu'une chose : RETRANCHER un pas d'ombre chaude la ou
// une ombre PORTEE tombe.
//
// ─── LE MONTAGE, ET POURQUOI IL EST FAIT COMME CA ───
//
// L'aplat peint part en EMISSION, pas en lumiere. C'est ce qui rend le test
// d'acceptation de §6bis litteralement vrai : sans DirectionalLight3D dans la
// scene, `light()` n'est jamais appelee, DIFFUSE_LIGHT reste nul, et le pixel
// vaut EXACTEMENT ce qu'il valait en `unshaded`. Pas « a peu pres » — le meme
// nombre. `--sun=off` est donc une vraie preuve, pas une impression.
//
// Corollaire : la contribution de `light()` est NEGATIVE. Le soleil n'eclaire
// pas, il creuse. C'est le seul montage ou la surface AU SOLEIL — soit la
// quasi-totalite du cadre — reste au pixel pres celle d'aujourd'hui, et ou
// seule l'ombre est une information nouvelle. L'inverse (aplat sombre + soleil
// qui ajoute) rendrait tout le jeu plus clair des qu'on allume, ce qui est
// precisement « le calcul a pris la place du dessin ».
//
// ─── LES DEUX GARDES, AUCUNE N'EST COSMETIQUE ───
//
//  1. ON NE TOUCHE PAS A L'OMBRE PROPRE. Une surface qui tourne le dos au
//     soleil est deja ombree PAR LE DESSIN (§2ter·2 : l'ombre sous le menton
//     fait partie du dessin et ne bouge pas quand le personnage tourne). Si on
//     laissait `ATTENUATION` l'assombrir en plus, on aurait recalcule
//     l'auto-ombrage — le defaut exact que §6bis interdit. D'ou le test sur
//     `ndl` : on ne creuse QUE la ou le soleil frappe et ou quelque chose
//     s'interpose.
//  2. L'ATTENUATION EST QUANTIFIEE. Elle arrive filtree, donc CONTINUE : c'est
//     un degrade, et un degrade est le 3e ton que la variante A refuse. Elle
//     repasse par un `step()`, comme `NdotL` (§6bis, consequence n°2).
//
// ⚠️ LES UNIFORMS SONT ICI, ET C'EST VOULU — contrairement a `cel_core` et
// `cel_floor`, qui n'en portent aucune. Ces deux-la partagent des FONCTIONS
// entre des shaders qui doivent garder leurs reglages propres. Le soleil,
// lui, doit etre LE MEME partout : sol, tapis, mur, chat, ennemis. Deux
// valeurs qui divergent d'un demi-pouce et le bord de l'ombre saute au passage
// d'un tapis — exactement le defaut que `cel_floor` decrit pour la flaque.

group_uniforms soleil;

// LA MOLETTE DE CONTRASTE de §6bis — 0 = pas d'ombre, 1 = le pas plein.
//
// ⚠️ Sa borne haute n'est pas esthetique, elle est de §15 : une bande d'ombre
// franche en travers de l'arene CACHE les ennemis qui la traversent. La souris
// est taupe #A89684 (luma 0,60) sur un parquet ble #E8D4A8 (luma 0,83) ; au
// pas plein le sol a l'ombre tombe a ~0,70. La marge est mince et elle se
// mesure en capture, pas au gout.
uniform float sun_shade_depth : hint_range(0.0, 1.0) = 1.0;

// L'ombre RECHAUFFE, elle ne grise pas (§4 : jamais un gris multiplie). Le
// bleu tombe plus que le rouge, donc la teinte glisse vers l'orange — meme
// geste que `warm_shadow()`, en multiplicatif parce qu'ici on ne connait pas
// la couleur locale, seulement l'aplat deja compose.
//
// Valeurs LINEAIRES : ALBEDO l'est deja. 0,70 lineaire ≈ 0,85 en sRGB.
uniform vec3 sun_shade_tint = vec3(0.70, 0.64, 0.54);

// Sous ce `dot(N, L)` la surface tourne le dos au soleil : son ombre est
// PEINTE, on n'y touche pas. Le seuil est positif et non nul pour eviter que
// l'acne de shadow map ne creuse les surfaces rasantes.
uniform float sun_facing_min : hint_range(-1.0, 1.0) = 0.15;

// 1.0 la ou une ombre PORTEE tombe, 0.0 partout ailleurs. Franc des deux
// cotes : aucune penombre, aucun degrade.
float cast_shadow_amount(float ndl, float attenuation) {
	float faces_sun = step(sun_facing_min, ndl);
	float occluded = 1.0 - step(0.5, attenuation);
	return faces_sun * occluded;
}

// Ce que `light()` ajoute a DIFFUSE_LIGHT — negatif par construction, voir le
// bandeau.
//
// ⚠️ AUCUN ALBEDO ICI, ET C'EST LE PIEGE DE CE FICHIER : Godot multiplie
// DIFFUSE_LIGHT par ALBEDO **apres** `light()`. Le manuel ne le dit pas, son
// exemple le montre seulement en creux — la ligne modele n'y contient pas
// d'albedo. Mesure sur capture le 2026-08-20 : avec un `painted` de trop,
// l'ombre sortait en `painted - painted²`, soit un creusement qui S'AFFAIBLIT
// a mesure que la surface s'assombrit, et un virage BLEU (le canal le plus bas
// perdait le moins). Un mur creme se creusait de 12 %, un parquet ble de 25 %,
// et rien dans l'image ne disait pourquoi.
//
// Le rendu final vaut donc EMISSION + ALBEDO x DIFFUSE_LIGHT, soit ici
// painted x (1 + (tint - 1) x shade) : `painted` a l'ombre nulle, `painted x
// tint` a l'ombre pleine. Exactement proportionnel a l'aplat, quel qu'il soit.
vec3 cast_shadow_delta(float shade) {
	return (mix(vec3(1.0), sun_shade_tint, sun_shade_depth) - vec3(1.0)) * shade;
}

// LA fonction light() du projet — definie ICI et nulle part ailleurs.
//
// §6bis, consequence n°5 : `unshaded` etait aussi ce qui rendait le rendu
// deterministe et independant de l'environnement. Le jour ou six shaders
// portent chacun leur version du meme calcul, ils divergent — exactement
// comme Blender et Godot ont diverge. Un `#include` ne laisse pas ce jour
// arriver.
//
// Les lampes non directionnelles sont ignorees : le projet n'en a pas, et le
// jour ou une lampe d'appoint arrive, elle ne doit surtout pas creuser une
// seconde ombre par-dessus celle du soleil.
//
// ⚠️ Ecrit en `if` et non en sortie anticipee — le compilateur de Godot refuse
// `return` dans un processeur `light()`, et le message ne le dit qu'a la
// compilation du shader, donc au lancement du jeu.
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float ndl = dot(normalize(NORMAL), normalize(LIGHT));
		DIFFUSE_LIGHT += cast_shadow_delta(cast_shadow_amount(ndl, ATTENUATION));
	}
}
