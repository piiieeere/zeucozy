// Le Soufflement — l'aura de souffle du chat.
//
// Une couronne de volutes posee AU SOL autour du chat, qui marque exactement la
// zone ou son souffle mord. C'est la premiere competence lootable du jeu : elle
// n'existe que si le joueur l'a prise, et elle grandit a chaque fois qu'il la
// reprend.
//
// §8 dit ce que doit etre un FX de ce jeu, et il le dit litteralement pour
// celui-ci : "la poussiere et les impacts sont des volutes rondes CERNEES, avec
// le meme trait que les personnages". D'ou onze volutes rondes, cernees d'encre
// brune, et surtout pas un halo en degrade — un glow radial est exactement la
// "particule molle" que §8 refuse.
//
// TROIS choix engagent le reste, et aucun n'est cosmetique :
//
//   * ELLE EST AU SOL, pas en billboard. La griffure et l'eclat sont des
//     billboards parce qu'ils marquent un geste ou un point ; le Soufflement
//     marque une ZONE. Un cercle en billboard resterait un cercle parfait a
//     l'ecran, alors que les ennemis, eux, vivent dans le plan du sol : un
//     ennemi au bord du cercle ecran ne serait pas au bord du cercle monde, et
//     le dessin mentirait sur la portee. Sous la plongee a 45° un disque au sol
//     se lit en ellipse, et c'est la lecture JUSTE ;
//
//   * ELLE EST OCCULTEE, contrairement aux deux autres FX. `depth_test_disabled`
//     est deliberement ABSENT : sans lui, l'arc arriere de la couronne — qui se
//     projette ~1,8 m plus haut a l'ecran, soit la taille du chat — se peindrait
//     par-dessus le chat. Le prix a payer est qu'un meuble cache un bout de
//     couronne, ce que le decor fait deja aux ennemis depuis le passage a 45° ;
//
//   * L'INTERIEUR EST VIDE. Seule la couronne est dessinee. Remplir le disque
//     teinterait le parquet, le chat et les ennemis sous une nappe permanente,
//     et §15 tranche : lisibilite > detail.
//
// Tout ce qui bouge est pose depuis breath_aura.gd, pose par pose. Ce shader ne
// sait rien du temps : il dessine UNE pose (§7).

shader_type spatial;

// Non eclaire (aucun PBR nulle part, §2bis). `depth_draw_never` parce que c'est
// un decalque transparent pose sur le sol — il ne doit pas ecrire de profondeur
// et se couper lui-meme. Voir plus haut pour l'absence de `depth_test_disabled`.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

group_uniforms cadrage;
// DIAMETRE de la zone en metres. Pose par breath_aura.gd d'apres le rayon reel
// de la morsure : la couronne et la portee ne peuvent pas diverger, et une
// reprise de la competence doit SE VOIR.
uniform float size = 5.6;

group_uniforms forme;
// Rayon de la plus grosse volute, en unites de quad (le quad va de -1 a 1, donc
// 1 = le rayon de la zone).
//
// Chaque volute est posee a `1 - son propre rayon` : sa crete touche donc
// exactement le bord de zone, quelle que soit sa taille. Le bord EXTERIEUR de la
// couronne est ainsi un cercle net — c'est le contrat de portee, il ne doit pas
// onduler — et c'est le bord INTERIEUR qui est nuageux, la ou personne n'a
// besoin de lire une distance.
//
// ⚠️ 0,20 avec VINGT ET UNE volutes, et le couple ne se separe pas : c'est
// l'ecartement des centres (≈2·(1−lobe)·sin(π/n)) qui decide si la couronne est
// un chapelet de perles ou une chaine de bouffees. A onze volutes de 0,24 les
// disques ne se recouvraient que de 0,03 — la marge exacte que l'encre mange —
// et l'aura sortait en collier de pastilles, soit precisement l'indicateur de
// portee que §8 refuse. Mesure sur les frames du jeu, pas devinee.
uniform float lobe : hint_range(0.05, 0.45) = 0.24;
// Rotation lente de toute la couronne. Avancee pose par pose (donc EN PAS) : un
// souffle tourne, il ne glisse pas.
uniform float spin = 0.0;
// Graine tiree a l'apparition — deux runs ne doivent pas poser la meme couronne.
uniform float seed = 0.0;

group_uniforms pose;
// Gonflement des volutes, en multiple de `lobe`. Toujours <= 1 : le souffle
// respire vers l'INTERIEUR, pour que la crete ne promette jamais plus que ce que
// la morsure atteint.
uniform float swell : hint_range(0.5, 1.0) = 1.0;
// Rayon de l'accent creme, en fraction du rayon de la volute. 0 = pas d'accent.
// Il s'ouvre sur la pose qui MORD et se referme ensuite : c'est ce qui donne au
// souffle un battement lisible sans rien ajouter a l'ecran.
//
// ⚠️ Ce n'est pas un COEUR centre, et l'essai a ete fait : une pastille creme au
// milieu de chaque volute donne un collier de baies. C'est un ACCENT DE
// BRILLANCE au sens de §6 — decale vers l'exterieur, present sur une volute sur
// deux seulement, et libre de se faire rogner par l'encre du bord. Une bouffee
// eclairee sur son flanc, pas une perle a pois.
uniform float core : hint_range(0.0, 0.9) = 0.0;

group_uniforms couleurs;
// Lavande douce #C8A8D8 — §4 la range en "magie, effets speciaux", et c'est
// exactement ce qu'est une competence lootable. Le choix est CONTRAINT, pas une
// humeur : le rose-rouge #D45870 est deja l'eclat du chat TOUCHE, l'ambre est
// l'impact frame, l'or est l'XP, l'anthracite est la griffure. Restait a
// distinguer ce que le chat inflige EN PERMANENCE de ce qu'il inflige d'un coup.
//
// ⚠️ Le bleu ciel #A0C8D8 aurait ete le choix semantique (§4 : "elements air"),
// et il est ecarte pour une raison MESUREE : le canape a du descendre a #8FBAC9
// parce que le #A0C8D8 plein "tombe dans la plage de valeurs des lames claires
// du parquet". Or cette couronne est dessinee SUR le parquet — c'est le cas
// d'echec documente, en pire.
uniform vec4 fill_color : source_color = vec4(0.784, 0.659, 0.847, 1.0);
// Creme chaud #F7EFE0 — le 2e ton du cluster, au coeur de la volute. Jamais un
// blanc froid (§5).
uniform vec4 core_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
// Trait brun chaud #3D2B1A (§4). Il n'a PAS eu a s'assombrir comme celui de la
// griffure : la lavande est a ~0,70 de luminance contre 0,18 pour l'encre, les
// deux tons ne risquent pas de fusionner en une seule masse.
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
// Epaisseur du trait, en METRES et non en unites de quad. C'est la seule facon
// de tenir §11 : la zone grandit a chaque reprise de la competence, et un trait
// exprime en fraction du quad grossirait avec elle jusqu'a sortir du registre
// du trait des personnages (le chat est cerne a 0,041).
// ⚠️ Deux essais mesures avant de se poser la : a 0,075 m le trait sortait a
// 3 px au cadrage de jeu et les volutes se lisaient comme des aplats nus ; a
// 0,13 m il mangeait la volute et la couronne devenait une chaine noire a pois.
// Une bouffee ne fait que ~0,55 m de rayon, la ou le decalque de griffure fait
// plusieurs metres : c'est la taille de la FORME CERNEE qui fixe le trait, pas
// la taille du decalque.
uniform float ink_world : hint_range(0.0, 0.3) = 0.09;


// Vingt et une volutes. Impair a dessein — un compte pair range la couronne en
// paires symetriques, donc en objet mecanique (meme raison que les 7 pointes de
// l'eclat). Constante et non uniform : une borne de boucle variable interdirait
// les derivees d'ecran juste apres.
const int VOLUTES = 21;


float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}


void vertex() {
	// Pas de billboard : le quad reste a plat au sol, tel que la scene le pose.
	// C'est tout l'inverse de claw_slash et hit_burst — voir l'en-tete.
	VERTEX.xy *= size;
}


void fragment() {
	vec2 p = UV * 2.0 - 1.0;

	// Taille d'un pixel en unites de quad, mesuree sur les DEUX axes de l'ecran
	// et non sur un seul. Le quad est vu sous 45° : sa profondeur est ecrasee
	// d'un facteur ~0,7 a l'ecran, donc le pas vertical et le pas horizontal ne
	// sont pas le meme nombre. N'en prendre qu'un sous-estime l'autre et le
	// lissage devient franc d'un cote, mou de l'autre.
	float ps = max(
		length(vec2(dFdx(p.x), dFdx(p.y))),
		length(vec2(dFdy(p.x), dFdy(p.y)))
	);
	ps = max(ps, 1e-6);

	float n = float(VOLUTES);

	// Union de disques. Le min de distances signees exactes EST la distance
	// exacte a l'union (a l'exterieur), donc rien ici n'a besoin de la
	// renormalisation par la pente qu'ont du s'ajouter l'eclat et la griffure :
	// leurs champs polaires n'etaient pas des distances, celui-ci en est une.
	float d = 1e9;
	// Le champ des accents cremes, tenu a part. Le calculer comme une PROFONDEUR
	// dans le champ precedent aurait donne un accent centre et identique partout
	// — voir `core`. Un second champ coute une soustraction et rend chaque accent
	// reglable volute par volute.
	float d_core = 1e9;

	for (int i = 0; i < VOLUTES; i++) {
		float fi = float(i);
		float h = hash11(fi * 1.73 + seed * 5.11);
		float g = hash11(fi * 3.19 + seed * 2.37);
		float b = hash11(fi * 5.77 + seed * 1.31);

		// Volutes INEGALES et mal rangees. Un chapelet regulier se lirait comme
		// un indicateur de portee de jeu video ; le souffle doit se lire comme
		// dessine a la main (meme regle que les pointes de l'eclat et les trois
		// griffes de la patte).
		float ang = (fi + 0.34 * (g - 0.5)) / n * TAU + spin;

		// ⚠️ Le hasard seul ne suffit PAS a defaire la regularite, et c'est le
		// defaut qu'il a fallu deux passes pour voir : vingt et une volutes
		// tirees independamment dans une plage etroite restent vingt et une
		// volutes de meme taille, et la couronne se lit comme un bracelet de
		// perles. Il y faut une modulation BASSE FREQUENCE — trois bosses sur le
		// tour — pour que le souffle ait des endroits gonfles et des endroits
		// maigres, comme une bouffee dessinee a la main.
		float wave = 0.5 + 0.5 * cos(ang * 3.0 + seed * TAU);
		// Plage 0,55–1,00 du rayon max, et pas plus large : sous ~0,5 la volute
		// devient plus petite que sa propre encre et sort en point sombre, ce qui
		// hache la chaine au lieu de la faire respirer.
		float rad = lobe * swell * (0.55 + 0.30 * wave + 0.15 * h);
		// Certaines volutes se replient vers l'interieur : la couronne prend une
		// deuxieme rangee par endroits au lieu de rester en file indienne.
		float sink = 0.40 * rad * g;

		// Chacune sur son propre cercle : `1 - rad - sink`. Grosse ou petite, sa
		// crete affleure le bord de zone sans jamais le depasser — le contrat de
		// portee tient, la couronne respire quand meme.
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 c = dir * (1.0 - rad - sink);
		d = min(d, length(p - c) - rad);

		// L'accent, decale dans une direction TIREE AU SORT et absent d'une
		// volute sur deux. Decale radialement, il alignait les cremes en un
		// second cercle pointille — encore le bracelet. Un rayon nul rend une
		// distance toujours positive : la volute ressort alors simplement sans
		// accent, sans qu'aucun test ait a l'ecarter.
		float accent = rad * core * step(0.52, hash11(fi * 7.31 + seed * 3.70));
		// Decale ASSEZ pour que le bord de la volute le rogne : `0,52 + 0,45`
		// depasse 1, donc l'accent mord sur l'encre et en ressort en croissant.
		// Centre, il restait un pois — le meme collier, en creme.
		vec2 shift = vec2(cos(b * TAU), sin(b * TAU)) * rad * 0.52;
		d_core = min(d_core, length(p - c - shift) - accent);
	}

	// Un pixel de lissage, et pas un de plus : c'est de l'antialiasing, pas un
	// degrade (§2bis interdit les seconds, pas le premier).
	float aa = ps * 0.75;
	float alpha = 1.0 - smoothstep(-aa, aa, d);

	if (alpha < 0.01) {
		discard;
	}

	// L'encre passe des metres aux unites de quad ici, une fois.
	float ink_q = ink_world / max(size * 0.5, 0.001);

	float ink_mask = smoothstep(-ink_q - aa, -ink_q + aa, d);
	float core_mask = 1.0 - smoothstep(-aa, aa, d_core);

	// L'ordre compte : l'accent est pose d'abord, l'encre par-dessus. C'est ce
	// qui laisse le bord de la volute ROGNER l'accent en croissant au lieu de le
	// garder rond — l'accent de brillance de §6, pas une pastille.
	vec3 col = mix(fill_color.rgb, core_color.rgb, core_mask);
	ALBEDO = mix(col, ink_color.rgb, ink_mask);
	ALPHA = alpha;
}
