// L'eclat de collision — "Visual Art Direction" §8.
//
// L'etoile dessinee qui claque a l'endroit exact ou un ennemi touche le chat.
//
// §8 est categorique sur ce que ce FX ne doit PAS etre : "formes dessinees,
// pas des particules molles — la poussiere et les impacts sont des volutes
// rondes CERNEES, avec le meme trait que les personnages". D'ou une forme
// pleine a contour epais, et non un nuage de sprites qui s'estompent.
//
// Le meme vocabulaire que le chat, applique a un decalque :
//   * deux tons de cluster, francs, sans le moindre degrade (variante A) ;
//   * un trait d'encre epais, brun chaud, jamais noir (§4) ;
//   * des pointes INEGALES — un eclat dessine a la main n'est pas une rosace.
//
// Tout ce qui bouge est pose depuis hit_burst.gd, pose par pose. Ce shader ne
// sait rien du temps : il dessine UNE pose. C'est ce qui garantit qu'aucune
// interpolation ne se glisse dans un FX qui doit claquer (§7).

shader_type spatial;

// Non eclaire (aucun PBR nulle part, §2bis) et JAMAIS occulte : depuis le
// passage de la camera a 45°, le decor cache pour de bon ce qui passe derriere
// lui. Un eclat d'impact avale par un canape ne remplit pas son office.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled,
	blend_mix, shadows_disabled;

group_uniforms forme;
// Taille de base en metres. Le chat fait 1,86 : l'eclat doit se lire comme un
// evenement a sa taille, pas comme une decoration posee a cote.
// Releve avec MAX_REACH : brider la pique dans l'espace du quad reduit la
// forme, on rend donc au quad la taille monde correspondante pour que l'eclat
// garde exactement la meme presence a l'ecran.
uniform float size = 3.2;
// Nombre de pointes. Impair a dessein — un compte pair produit une etoile
// symetrique, donc une forme mecanique.
uniform int points = 7;
// Rayon des creux entre deux pointes. BAS : c'est lui qui fait la difference
// entre une etoile et une fleur. Remonte, les pointes deviennent des petales
// et l'eclat se lit comme un sticker mignon — teste, et c'est exactement ce
// qui s'est produit a 0,45.
uniform float valley : hint_range(0.0, 1.0) = 0.23;
// Orientation, tiree au hasard a chaque impact : deux coups de suite ne
// doivent pas tamponner exactement la meme etoile.
uniform float spin = 0.0;

group_uniforms pose;
// Taille de la pose courante, en multiple de `size`.
uniform float burst_scale = 1.0;
// Finesse des pointes — l'exposant du profil. Sous ~1,5 les pointes sont des
// lobes ronds ; au-dela de 3 ce sont des piques. L'eclat s'effile de pose en
// pose, et c'est cet effilement qui le fait se dissiper.
uniform float sharp : hint_range(0.5, 12.0) = 3.0;
// Rayon du coeur creme, en fraction du rayon local. 0 = pas de coeur. A garder
// PETIT : un grand disque pale au centre d'une forme a pointes, c'est un
// pistil, et la lecture bascule vers la fleur.
uniform float core : hint_range(0.0, 1.0) = 0.34;

group_uniforms couleurs;
// Rose-rouge #D45870 — c'est ce que §4 range explicitement en "hit feedback".
// Volontairement PAS l'or des croquettes ni l'ambre du level up : tout est
// chaud dans ce jeu, et un eclat dore sur un degat se lirait comme un gain.
// La chaleur demandee par §8 ("petites etoiles chaudes") reste tenue.
uniform vec4 fill_color : source_color = vec4(0.831, 0.345, 0.439, 1.0);
// Le 2e ton du cluster — creme chaud, jamais un blanc froid (§5).
uniform vec4 core_color : source_color = vec4(0.961, 0.925, 0.847, 1.0);
// Trait brun chaud #3D2B1A (§4). Jamais de noir pur, pas plus ici qu'ailleurs.
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
// Epaisseur du trait, en unites de quad, mesuree en VRAIE distance au bord
// (voir fragment()). Epais, comme partout — c'est la variante A (§2bis).
uniform float ink : hint_range(0.0, 0.5) = 0.055;


// Longueur maximale d'une pique, en unites de quad.
//
// Le quad ne s'etend que jusqu'a r = 1 SUR SES AXES (ses coins vont a 1,41).
// Une pique plus longue qui pointe vers un cote sort du quad et se fait donc
// TRANCHER NET par son bord, pendant que ses voisines pointant vers un coin
// passent intactes — d'ou des etoiles a pointes coupees, et coupees
// irregulierement. Le plafond est ici, pas dans la taille du quad : agrandir
// le quad agrandirait la forme avec lui et ne changerait rien.
//
// La marge sous 1,0 laisse la place a l'antialiasing du contour.
const float MAX_REACH = 0.96;


float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}


void vertex() {
	// Billboard : l'eclat regarde toujours la camera. C'est un decalque
	// DESSINE epingle a un point du monde, pas un objet pose dedans — le faire
	// tourner avec la scene le trahirait immediatement.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	VERTEX.xy *= size * burst_scale;
}


void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + spin;
	float n = float(points);

	// Longueur de la pointe courante. Le decrochage d'une branche a l'autre est
	// place dans les CREUX (d'ou le +0,5), ou personne ne peut le voir : le
	// deplacer sur les pointes trancherait chaque etoile en deux.
	//
	// Le `mod` n'est pas cosmetique. `atan` ramene l'angle dans (-PI, PI] : sans
	// repliage, la branche a cheval sur ±PI recoit DEUX numeros donc DEUX
	// longueurs, et cette pointe-la se retrouve tranchee net en plein milieu.
	float branch = mod(floor(a / TAU * n + 0.5), n);
	float wobble = MAX_REACH * (0.65 + 0.35 * hash11(branch + spin * 7.13));

	float k = pow(abs(cos(a * n * 0.5)), sharp);
	float radius = mix(valley, wobble, k);

	// `r - radius` n'est PAS la distance au bord : c'est une distance
	// RADIALE, et sur le flanc d'une pique elle vaut plusieurs fois la vraie.
	// Une bande d'encre calculee dessus ne cerne donc que la POINTE et laisse
	// les flancs nus — l'eclat perdait son trait, alors que §8 le veut cerne
	// "avec le meme trait que les personnages". On divise par la pente pour
	// retrouver une vraie distance, et le trait fait enfin le tour.
	float dr = r - radius;
	float px = max(abs(dFdx(p.x)), 1e-6);
	float py = max(abs(dFdy(p.y)), 1e-6);
	vec2 slope = vec2(dFdx(dr) / px, dFdy(dr) / py);

	// La pente diverge quand r tend vers 0 : le terme angulaire du rayon y est
	// divise par r. Sans garde, la correction ecrase la distance au centre,
	// tout le coeur passe pour un bord et l'etoile se remplit d'encre. On ne
	// corrige donc que la ou la correction a un sens : pres du contour.
	float trust = smoothstep(0.0, valley, r);
	float d = dr / mix(1.0, max(length(slope), 1.0), trust);

	// Un pixel de lissage, et pas un de plus : c'est de l'antialiasing, pas un
	// degrade (§2bis interdit les seconds, pas le premier).
	float aa = max(px, py) * 0.75;

	float alpha = 1.0 - smoothstep(-aa, aa, d);

	if (alpha < 0.01) {
		discard;
	}

	float ink_mask = smoothstep(-ink - aa, -ink + aa, d);
	float core_mask = 1.0 - smoothstep(radius * core - aa, radius * core + aa, r);

	vec3 col = mix(fill_color.rgb, core_color.rgb, core_mask * step(0.001, core));
	ALBEDO = mix(col, ink_color.rgb, ink_mask);
	ALPHA = alpha;
}
