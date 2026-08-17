// Le mouton de poussiere — la mine molle que le chat seme derriere lui.
//
// Une touffe posee au sol. Le premier ennemi qui la traverse la fait POUF et
// prend le coup ; elle ne dure que quelques secondes. C'est la premiere arme du
// jeu qui recompense de BOUGER — l'exact inverse de l'haleine puante, qui
// recompense de rester.
//
// ─── POURQUOI UNE TOUFFE ET PAS UN DISQUE ───
//
// Un disque cerne au sol, c'est une zone de degats de jeu vidéo. Une touffe de
// poils moutonnee sous un meuble, c'est un objet d'appartement que tout
// proprietaire de chat reconnait (§5.5). La forme fait tout le travail de ton, et
// elle ne coute rien : c'est le meme cercle, avec un bord mange.
//
// ─── LE BORD SE DECOUPE EN DEUX FREQUENCES, ET C'EST UNE LEÇON DEJA PAYEE ───
//
// La couronne de l'haleine puante avait appris que le hasard seul ne defait pas
// la regularite : il faut une modulation BASSE FREQUENCE pour que le tour ait des
// cotes differents. Sans elle, une haute frequence reguliere sort en roue
// dentee, quel que soit le nombre de dents.
//
// Tout ce qui bouge est pose depuis dust_bunny.gd, pose par pose. Ce shader ne
// sait rien du temps : il dessine UNE pose (§7).

shader_type spatial;

// Pose A PLAT AU SOL et OCCULTE, comme l'haleine puante : la touffe promet une
// distance de contact au sol, et un billboard mentirait dessus. Elle est de plus
// le seul FX que le chat doit pouvoir COUVRIR en passant dessus — un mouton
// peint par-dessus les pattes se lirait comme accroche au chat.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

group_uniforms cadrage;
// DIAMETRE de la zone de contact en metres. Pose par dust_bunny.gd d'apres le
// rayon reel : le dessin et la portee ne peuvent pas diverger.
uniform float size = 1.5;

group_uniforms pose;
// Gonflement, en fraction du rayon de zone. 1,0 = la crete de la touffe affleure
// exactement le bord du contact.
//
// ⚠️ IL PEUT DEPASSER 1,0, et seulement a la pose de POUF — celle ou le mouton
// n'existe plus comme zone puisqu'il vient d'etre consomme. Tant qu'il est
// actif, il respire vers l'INTERIEUR, la ou il n'a rien a mentir. Meme regle que
// le gonflement des volutes de l'haleine.
uniform float puff : hint_range(0.0, 1.6) = 1.0;

group_uniforms forme;
// Nombre de touffes sur le tour.
uniform float tufts : hint_range(3.0, 16.0) = 7.0;
// Profondeur des creux entre deux touffes, en fraction du rayon.
uniform float tuft_depth : hint_range(0.0, 0.5) = 0.20;
// Graine : deux moutons voisins ne doivent pas etre le meme tampon. C'est
// d'autant plus vrai ici qu'il y en a jusqu'a dix a l'ecran.
uniform float seed = 0.0;

group_uniforms couleurs;
// Gris-beige #9C8C74 — la poussiere. A 0,56 de luminance il tranche sur les deux
// bois du parquet (0,84 et 0,93) sans etre une tache froide : §9 a deja mesure
// qu'un gris BLEUTE se lit comme un corps etranger sur un sol parchemin.
uniform vec4 fill_color : source_color = vec4(0.612, 0.549, 0.455, 1.0);
// Creme chaud #F7EFE0 — l'accent de brillance, le 2e ton du cluster.
uniform vec4 core_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
// ⚠️ EPAIS pour un si petit objet — 0,085 du rayon, la ou l'onde du feulement
// se contente de 0,020. Le trait se dose en fraction de CE QU'IL CERNE, jamais
// en valeur partagee entre FX : une touffe fait 1,9 m de large a l'ecran, une
// onde en fait 7,2. Meme regle que le cerne du petit texte de l'ATH (§9).
uniform float ink : hint_range(0.0, 0.2) = 0.085;

group_uniforms accent;
// Direction du jour DANS LE PLAN DU QUAD, qui est couche au sol : ce n'est donc
// pas la direction de la lumiere du monde mais sa projection au sol, choisie
// pour que tous les moutons soient eclaires du meme cote (§4, la lumiere vient
// d'en haut et de derriere).
uniform vec2 light_dir = vec2(-0.45, 0.89);
// Largeur de l'accent, en fraction du rayon.
uniform float accent_width : hint_range(0.0, 0.8) = 0.34;


void vertex() {
	// Pas de billboard : le quad reste a plat au sol, tel que la scene le pose.
	//
	// ⚠️ Le QuadMesh fait 1 × 1 : sans cette ligne la touffe garde un metre de
	// cote quelle que soit `size`. Voir hiss_ring, ou le meme oubli a produit un
	// dessin entierement faux sans lever la moindre erreur.
	VERTEX.xy *= size;
}


void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y * 2.0 - 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);

	// Pente de `r` par pixel : le champ est radial (voir hiss_ring).
	float ps = max(length(vec2(dFdx(r), dFdy(r))), 1e-6);

	// Le bord, en deux frequences. La basse donne au mouton un COTE plus gros
	// que l'autre — c'est elle qui l'empeche d'etre une fleur.
	float fine = 0.5 + 0.5 * cos(a * tufts + seed * TAU);
	float slow = 0.86 + 0.14 * sin(a * 2.0 + seed * 5.3);
	float edge = puff * slow * (1.0 - tuft_depth * fine);

	float d = (r - edge) / max(ps, 1e-6);
	float alpha = 1.0 - smoothstep(-0.75, 0.75, d);

	if (alpha < 0.01) {
		discard;
	}

	// Retour en unites de rayon pour doser l'encre et l'accent, qui se mesurent
	// en fraction de la touffe et non en pixels.
	float du = d * ps;
	float aa = ps * 0.75;

	float ink_w = min(ink, puff * 0.30);
	float ink_mask = smoothstep(-ink_w - aa, -ink_w + aa, du);

	// ⚠️ L'ACCENT EST ROGNE EN CROISSANT par le bord de la touffe, il n'est pas
	// une pastille posee au milieu. C'est le reglage exact que l'haleine puante
	// avait du trouver : un accent centre est un POIS, il ne se lit comme une
	// brillance qu'une fois coupe par la silhouette qui le porte.
	// ⚠️ LES DEUX SEUILS SONT FRANCS, a un pixel d'antialiasing pres. Une premiere
	// capture les avait poses en RAMPES LARGES (0,24 d'un cote, 0,67 de l'autre)
	// et l'accent sortait en degrade aerographe — la seule zone lissee de toute
	// l'image, au milieu d'un jeu ou chaque aplat a un bord net. Un cluster 2 tons
	// se lit a son BORD (§2bis) : etale, il n'y a plus deux tons, il y en a cent.
	float lit = dot(normalize(p + vec2(1e-5)), normalize(light_dir));
	float shell = smoothstep(-accent_width - aa, -accent_width + aa, du);
	float core_mask = shell * smoothstep(0.30 - 0.06, 0.30 + 0.06, lit) * (1.0 - ink_mask);

	vec3 col = mix(fill_color.rgb, core_color.rgb, core_mask);
	ALBEDO = mix(col, ink_color.rgb, ink_mask);
	ALPHA = alpha;
}
