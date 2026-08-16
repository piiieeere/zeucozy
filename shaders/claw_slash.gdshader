// La griffure — l'attaque au corps a corps du chat.
//
// Trois traits de griffe, dessines, cernes, qui balaient devant le chat dans la
// direction ou il MARCHE. Rien ici ne cherche d'ennemi : c'est un geste, pas un
// projectile — le joueur vise en se deplacant.
//
// §8 est categorique sur ce que doit etre un FX de ce jeu : "formes dessinees,
// pas des particules molles", "volutes rondes CERNEES, avec le meme trait que
// les personnages", et "Attaque → petites formes organiques (pas de laser
// froid)". D'ou trois bandes pleines a bouts effiles, cernees de brun chaud, et
// surtout pas une trainee en degrade.
//
// Le vocabulaire est celui du reste du jeu :
//   * deux tons de cluster, francs, sans degrade (variante A, §2bis) ;
//   * un trait d'encre epais, brun tres sombre, jamais noir pur (§4) ;
//   * des griffes INEGALES — trois traits identiques feraient une fourchette.
//
// Couleurs : gris anthracite + coeur creme depuis le 2026-08-16 (le corps etait
// l'ambre Ghibli jusque-la). Toujours PAS le rose-rouge #D45870 : ce rose est
// le "hit feedback" de §4, deja pris par l'eclat qui marque le chat TOUCHE, et
// deux evenements opposes ne peuvent pas partager une couleur.
//
// Tout ce qui bouge est pose depuis claw_slash.gd, pose par pose. Ce shader ne
// sait rien du temps : il dessine UNE pose (§7).

shader_type spatial;

// Non eclaire (aucun PBR nulle part, §2bis) et jamais occulte : depuis le
// passage de la camera a 45° le decor cache pour de bon ce qui passe derriere
// lui, et une attaque avalee par un canape ne dit plus au joueur qu'il a frappe.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled,
	blend_mix, shadows_disabled;

group_uniforms cadrage;
// Largeur du decalque en metres. Posee par claw_slash.gd d'apres la portee
// reelle de l'attaque : une upgrade qui allonge la griffure doit SE VOIR.
uniform float size = 3.45;
// La direction visee, en MONDE. Le decalque est un billboard — il regarde
// toujours la camera — mais il se fait tourner dans le plan de l'ecran pour que
// son haut suive la projection de cette direction. C'est ce qui permet a la
// griffure de rester lisible qu'on frappe vers le fond ou sur le cote, ce
// qu'un quad pose a plat dans le monde ne ferait pas (a 45° il serait vu par la
// tranche des qu'on frappe lateralement).
uniform vec3 aim = vec3(0.0, 0.0, -1.0);

group_uniforms forme;
// Rayon moyen de l'arc, en unites de quad (le quad va de -1 a 1).
uniform float arc_radius : hint_range(0.1, 0.9) = 0.58;
// Ecart RADIAL entre deux griffes. Des griffes de chat laissent des traits
// paralleles, pas une rosace : elles se decalent en travers de l'arc, pas le
// long.
uniform float claw_spread : hint_range(0.0, 0.4) = 0.175;
// Leger decalage le long de l'arc : les trois griffes ne mordent pas ensemble.
uniform float claw_skew = 0.10;
// Graine tiree a chaque coup — deux griffures de suite ne doivent pas etre le
// meme tampon. Meme raison que le `spin` de l'eclat de collision.
uniform float seed = 0.0;

group_uniforms pose;
// Etirement de l'arc vers l'exterieur, en multiple de `arc_radius`.
uniform float reach : hint_range(0.3, 1.5) = 1.0;
// Longueur angulaire de la griffe la plus longue, en radians.
uniform float span : hint_range(0.1, 2.5) = 1.2;
// Epaisseur au milieu du trait, en unites de quad.
uniform float thick : hint_range(0.005, 0.4) = 0.10;
// Finesse des deux bouts. Bas = trait franc a bouts ronds, haut = aiguille.
// C'est lui qui fait DISPARAITRE la griffure par la forme, jamais par l'alpha :
// §8 interdit le fondu ("tiennent puis disparaissent d'un coup").
uniform float taper : hint_range(0.5, 6.0) = 2.0;
// Rotation de tout le dessin — c'est LE balayage. Pose par pose, l'arc pivote :
// la griffe entre par un cote et sort par l'autre.
uniform float roll = 0.0;

group_uniforms couleurs;
// Gris anthracite #37393B — le ton exterieur du cluster, celui qui donne sa
// couleur a la griffure vue de loin. C'etait l'ambre Ghibli #D4A860 de §4
// jusqu'au 2026-08-16. Anthracite quasi neutre et non le #383E42 canonique :
// sur une palette parchemin, un gris qui tire au bleu se voit comme une tache
// froide (meme raison que "jamais de blanc froid", §5).
uniform vec4 fill_color : source_color = vec4(0.216, 0.224, 0.231, 1.0);
// Creme chaud #F7EFE0 — le 2e ton, au coeur du trait. Jamais un blanc froid (§5).
uniform vec4 core_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
// Trait brun tres sombre #1A120C. Jamais de noir pur, pas plus ici qu'ailleurs.
//
// C'etait le brun chaud #3D2B1A de §4 tant que le corps etait ambre. Il a du
// suivre le passage a l'anthracite, EXACTEMENT comme sur le pelage tuxedo et
// pour la meme raison : le trait doit rester plus sombre que l'aplat qu'il
// cerne. Mesure sur les frames — #3D2B1A est a 0,182 de luminance contre 0,216
// pour l'anthracite, soit 0,034 d'ecart : l'encre couvrait 1 968 px contre
// 1 075 a l'aplat et les deux fusionnaient en une seule masse sombre, le
// cluster 2 tons retombant a un seul ton (contre §2bis). #1A120C est a 0,078,
// soit 4x plus d'ecart.
uniform vec4 ink_color : source_color = vec4(0.102, 0.071, 0.047, 1.0);
// Epaisseur du trait, en unites de quad. Epais, comme partout (variante A).
uniform float ink : hint_range(0.0, 0.2) = 0.038;


// Trois griffes. Constante et non uniform : une borne de boucle qui varie
// interdirait les derivees d'ecran juste apres (elles exigent un flot de
// controle uniforme), et rien ne demande un compte reglable ici.
const int CLAWS = 3;


float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}


void vertex() {
	// Billboard : le decalque regarde toujours la camera. C'est un dessin
	// epingle a un point du monde, pas un objet pose dedans.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);

	// La direction visee, projetee a l'ecran. On tourne le QUAD (donc le dessin
	// avec lui, puisque l'UV est attache aux sommets) pour que son haut pointe
	// dessus. `aim` est horizontal et la camera plonge de 45° : sa projection ne
	// s'annule jamais, il n'y a pas de cas degenere a garder.
	vec3 v = (VIEW_MATRIX * vec4(normalize(aim), 0.0)).xyz;
	float ang = atan(v.x, v.y) + roll;
	float s = sin(ang);
	float c = cos(ang);

	vec2 q = VERTEX.xy;
	VERTEX.xy = vec2(q.x * c + q.y * s, -q.x * s + q.y * c) * size;
}


void fragment() {
	// ⚠️ Le Y de l'UV d'un QuadMesh descend quand son Y local monte : passer par
	// `UV * 2 - 1` retourne le dessin, et la griffure partait en arriere du chat
	// au lieu d'aller devant. Mesure sur les frames du jeu, pas devine.
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	// 0 = vers le haut du dessin, donc vers la direction visee.
	float a = atan(p.x, p.y);

	// Taille d'un pixel en unites de quad. Mesuree comme une LONGUEUR et non
	// composante par composante : le quad est tourne a l'ecran (voir vertex),
	// donc dFdx(p.x) seul ne mesure plus le pas d'un pixel.
	float ps = max(length(vec2(dFdx(p.x), dFdx(p.y))), 1e-6);

	float d = 1e9;
	float mid = 0.5 * (float(CLAWS) - 1.0);

	for (int k = 0; k < CLAWS; k++) {
		float lane = float(k) - mid;
		float h = hash11(float(k) * 3.71 + seed * 9.13);
		// La griffe du milieu porte le plus loin — un trio egal se lirait comme
		// une fourchette, pas comme une patte.
		float bump = 1.0 - 0.20 * abs(lane);

		float rad_k = (arc_radius + lane * claw_spread) * reach;
		float ctr_k = lane * claw_skew;
		float half_len = span * 0.5 * bump * (0.86 + 0.24 * h) * rad_k;
		float w_k = thick * bump * (0.85 + 0.26 * h);

		// L'arc DEROULE : x = le long du trait, y = en travers. Un trait fin
		// tient dans cette approximation, et elle donne une vraie distance au
		// bord la ou une distance radiale n'en donnerait pas (le piege mesure
		// sur l'eclat de collision : l'encre ne cernait que les pointes).
		vec2 q = vec2((a - ctr_k) * rad_k, r - rad_k);

		float t = clamp(q.x / max(half_len, 1e-4), -1.0, 1.0);
		float w = w_k * pow(max(0.0, 1.0 - t * t), taper);

		float dx = max(0.0, abs(q.x) - half_len);
		float dy = abs(q.y) - w;
		// Au-dela des bouts l'epaisseur est nulle : la distance y redevient
		// celle au point extreme, et le trait s'arrete net au lieu de filer.
		d = min(d, dx > 0.0 ? length(vec2(dx, max(dy, 0.0))) : dy);
	}

	// Le profil effile rend le champ non unitaire pres des bouts. On le
	// renormalise par sa pente pour que la bande d'encre garde partout la meme
	// epaisseur — sinon elle grossit aux extremites et le trait se termine en
	// massue.
	vec2 grad = vec2(dFdx(d), dFdy(d)) / ps;
	d /= max(length(grad), 1.0);

	// Un pixel de lissage, et pas un de plus : c'est de l'antialiasing, pas un
	// degrade (§2bis interdit les seconds, pas le premier).
	float aa = ps * 0.75;
	float alpha = 1.0 - smoothstep(-aa, aa, d);

	if (alpha < 0.01) {
		discard;
	}

	// L'encre et le coeur suivent l'AMINCISSEMENT du trait. Fixes, ils
	// mangeraient tout le trait des la 4e pose et la griffure finirait en barre
	// brune au lieu de s'effacer.
	float ink_w = min(ink, thick * 0.55);
	// Le coeur creme se mesure DEPUIS l'encre, pas depuis le bord : pose a
	// `thick * 0,42` il tombait sous l'encre et l'ambre se reduisait a un
	// liseré invisible — le cluster n'avait plus qu'un ton, contre §2bis.
	float core_w = ink_w + thick * 0.30;

	float ink_mask = smoothstep(-ink_w - aa, -ink_w + aa, d);
	float core_mask = 1.0 - smoothstep(-core_w - aa, -core_w + aa, d);

	vec3 col = mix(fill_color.rgb, core_color.rgb, core_mask);
	ALBEDO = mix(col, ink_color.rgb, ink_mask);
	ALPHA = alpha;
}
