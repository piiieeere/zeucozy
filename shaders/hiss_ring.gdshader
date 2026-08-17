// Le feulement — l'onde de choc qui REPOUSSE.
//
// Un anneau qui s'ouvre au sol autour du chat. Il ne tue pas, il fait de la
// PLACE : chaque ennemi que le front traverse est projete vers l'arriere. C'est
// le premier effet de recul du jeu, et la premiere competence dont la valeur ne
// se compte pas en degats.
//
// ─── L'ONDE EST L'AGENT, PAS UN COMMENTAIRE ───
//
// `hiss_ring.gd` pousse les ennemis pose par pose, a mesure que le front les
// atteint. C'est la seule facon de tenir §2.10 sur un effet qui GRANDIT : une
// poussee instantanee sur tout le rayon aurait projete un ennemi du bord avant
// que le dessin ne l'ait touche — le meme defaut que la morsure qui cherchait sa
// cible au claquement, et le meme correctif.
//
// ─── LE SEUL FX SANS COULEUR, ET C'EST CE QUI LE REND LISIBLE ───
//
// La palette d'accents est prise : rouge = morsure, rose = chat touche, lavande
// = haleine, ambre = accent d'UI, or = XP, menthe = soin, terracotta = vie. Un
// huitieme ton sature aurait ete une couleur de plus a apprendre.
//
// Le feulement est donc de l'AIR : creme au front, gris chaud a la traine,
// encre pour tenir le tout. Aucune chroma. C'est le vocabulaire de l'onde de
// choc au manga — blanc cerne de noir — et sur un sol parchemin (0,84) c'est le
// TRAIT qui le porte, pas l'aplat. Exactement l'argument de §9 sur le texte nu
// de l'ATH.
//
// Tout ce qui bouge est pose depuis hiss_ring.gd, pose par pose. Ce shader ne
// sait rien du temps : il dessine UNE pose (§7).

shader_type spatial;

// Pose A PLAT AU SOL et OCCULTE, comme l'haleine puante et pour ses deux
// raisons : un anneau en billboard resterait un cercle parfait a l'ecran alors
// que les ennemis vivent dans le plan du sol — le dessin mentirait sur la portee
// — et l'arc arriere d'un anneau de 4 m se projette assez haut pour se peindre
// par-dessus le chat si on coupe le test de profondeur.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

group_uniforms cadrage;
// DIAMETRE de la portee en metres. Pose par hiss_ring.gd d'apres le rayon reel
// de la poussee : le dessin et la portee ne peuvent pas diverger.
uniform float size = 8.0;

group_uniforms pose;
// Rayon courant du front, en unites de quad (le quad va de -1 a 1, donc 1 = le
// rayon de la zone). C'EST le geste : il part petit et finit exactement a 1,0,
// ou il affleure le bord de la zone de poussee.
uniform float ring : hint_range(0.0, 1.0) = 0.5;
// Demi-epaisseur de l'onde, en unites de quad. Elle MAIGRIT en s'ouvrant : une
// onde d'epaisseur constante se lit comme un anneau qui grandit, pas comme une
// onde qui se propage.
uniform float band : hint_range(0.005, 0.4) = 0.10;

group_uniforms forme;
// De combien le bord ARRIERE est decoupe, en fraction de l'epaisseur.
//
// ⚠️ LE BORD AVANT RESTE NET, toujours. C'est lui qui promet la portee — un
// front qui ondulerait rendrait la distance de poussee illisible. Le bord
// arriere, lui, ne promet rien a personne : c'est la qu'on met le desordre.
// Meme partage que l'haleine puante, dont le cercle exterieur est net et le bord
// interieur nuageux.
uniform float ragged : hint_range(0.0, 1.0) = 0.45;
// Nombre de lobes sur le tour. Volontairement PREMIER par rapport aux 3 bosses
// de la modulation basse frequence : sans ca les deux se superposent toujours au
// meme endroit et l'onde sort en roue dentee — le defaut mesure sur la couronne
// de l'haleine.
uniform float lobes : hint_range(2.0, 24.0) = 7.0;
// Graine tiree a chaque feulement : deux ondes de suite ne sont pas le meme
// tampon. Meme raison que le `seed` de la griffure et de la morsure.
uniform float seed = 0.0;

group_uniforms couleurs;
// Creme chaud #F7EFE0 — LE FRONT. Le meme creme que le pelage tuxedo et l'email
// de la morsure : le projet n'en fabrique pas un second.
uniform vec4 front_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
// Gris chaud #CDBFA8 — LA TRAINE, le 2e ton du cluster. Il est plus SOMBRE que
// le parquet clair (0,75 contre 0,84) : c'est ce qui fait que l'onde se lit
// comme un relief et non comme une tache de lumiere.
uniform vec4 back_color : source_color = vec4(0.804, 0.749, 0.659, 1.0);
// L'encre canonique de §4. Ici elle ne cerne pas, elle PORTE : sans elle un
// creme a 0,93 sur un ble a 0,84 n'existe pas.
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
uniform float ink : hint_range(0.0, 0.1) = 0.020;


void vertex() {
	// Pas de billboard : le quad reste a plat au sol, tel que la scene le pose.
	// C'est tout l'inverse de claw_slash, de la morsure et de l'eclat.
	//
	// ⚠️ Le QuadMesh fait 1 × 1 : SANS CETTE LIGNE le decalque garde un metre de
	// cote quel que soit `size`, et l'anneau — dont le rayon vaut une unite de
	// quad — sort en quatre croissants tangents aux bords, entierement manges par
	// l'encre. Defaut constate en capture, et parfaitement muet : ni erreur, ni
	// avertissement, juste un dessin qui n'a plus rien a voir avec sa portee.
	VERTEX.xy *= size;
}


void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y * 2.0 - 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);

	// Taille d'un pixel EN UNITES DE RAYON. Le champ est radial, donc c'est bien
	// la pente de `r` qu'il faut mesurer, pas celle d'une coordonnee du quad :
	// sous 45° de plongee le quad est vu en biais et les deux diffèrent.
	float ps = max(length(vec2(dFdx(r), dFdy(r))), 1e-6);

	float w = max(band, 1e-4);

	// Le desordre du bord arriere : une haute frequence (les lobes) modulee par
	// une basse (3 bosses sur le tour). C'est la LEÇON de la couronne de
	// l'haleine — le hasard seul ne defait pas la regularite, il faut une
	// modulation lente pour que le tour ait des cotes differents.
	float fine = 0.5 + 0.5 * cos(a * lobes + seed * TAU);
	float slow = 0.5 + 0.5 * sin(a * 3.0 - seed * 4.7);
	float chew = ragged * fine * (0.45 + 0.55 * slow);

	float outer = ring + w * 0.55;
	float inner = ring - w * (1.0 - chew);

	// Bande radiale. Champ non unitaire mais monotone en `r` : `ps` suffit a le
	// convertir en pixels, comme sur les autres decalques du projet.
	float d = max(inner - r, r - outer);

	float aa = ps * 0.75;
	float alpha = 1.0 - smoothstep(-aa, aa, d);

	if (alpha < 0.01) {
		discard;
	}

	// L'encre suit l'amincissement de l'onde : fixe, elle mangerait toute la
	// bande sur les dernieres poses et le feulement finirait en cercle noir.
	float ink_w = min(ink, w * 0.42);
	float ink_mask = smoothstep(-ink_w - aa, -ink_w + aa, d);

	// Les deux tons ne sont pas un dedans/dehors, ce sont un AVANT et un
	// ARRIERE : le creme est du cote ou l'onde va. C'est ce qui lui donne un
	// sens de marche sans qu'aucune fleche ait a le dire.
	float lead = smoothstep(ring - w * 0.20, ring + w * 0.20, r);
	vec3 col = mix(back_color.rgb, front_color.rgb, lead);
	ALBEDO = mix(col, ink_color.rgb, ink_mask);
	ALPHA = alpha;
}
