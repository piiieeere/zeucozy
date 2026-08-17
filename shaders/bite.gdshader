// La morsure — la premiere competence ACTIVE du jeu.
//
// Deux machoires qui se referment : un arc en haut, un arc en bas, pointus aux
// extremites comme des crocs, qui claquent l'un sur l'autre. C'est un GESTE
// ponctuel, declenche par le joueur — l'inverse exact de l'haleine puante, qui
// ne se commande pas.
//
// Le vocabulaire est celui de claw_slash.gdshader, dont ce fichier reprend le
// squelette : billboard epingle a un point du monde, quad tourne dans le plan de
// l'ecran pour suivre la visee, SDF a bords effiles, cluster 2 tons + encre.
//
// ⚠️ ELLE NE PEUT PARTAGER SA COULEUR NI AVEC LA GRIFFURE NI AVEC L'ECLAT.
// L'anthracite est pris par la griffure, le rose-rouge #D45870 par le chat
// TOUCHE (§4, "hit feedback"), la lavande par l'haleine. Le terracotta #D46858
// aurait ete le choix semantique ("danger soft") et il est ecarte : a deux
// points du rose de l'eclat, il se lirait comme lui.
//
// D'ou un BRUN CHAUD moyen au corps et un coeur creme — la lecture est celle
// d'un croc sombre avec un eclat clair dessus, l'idiome anime du croc qui
// brille. Et surtout : un aplat creme seul serait ILLISIBLE sur le parquet
// (#E8D4A8 a 0,84 de luminance, creme a 0,93 — 0,09 d'ecart). C'est le cas
// d'echec deja mesure sur le canape, qui avait du descendre a #8FBAC9.
//
// Tout ce qui bouge est pose depuis bite_fx.gd, pose par pose. Ce shader ne sait
// rien du temps : il dessine UNE pose (§7).

shader_type spatial;

// Jamais occulte, comme la griffure : depuis la camera a 45° un meuble avale ce
// qui passe derriere lui, et une morsure coupee en deux par un canape ne dit
// plus au joueur que sa competence est partie.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled,
	blend_mix, shadows_disabled;

group_uniforms cadrage;
// Largeur du decalque en metres. Posee par bite_fx.gd d'apres la portee REELLE
// de la morsure : un palier qui allonge la portee doit SE VOIR, meme contrat que
// `claw_slash.DRAW_SIZE`.
uniform float size = 3.0;
// La direction visee, en MONDE. Le quad tourne dans le plan de l'ecran pour que
// son haut pointe dessus — un quad pose a plat dans le monde serait vu par la
// tranche des qu'on mord lateralement sous 45° de plongee.
uniform vec3 aim = vec3(0.0, 0.0, -1.0);

group_uniforms forme;
// Demi-largeur de la machoire, en unites de quad (le quad va de -1 a 1). C'est
// elle qui donne la corde de l'arc, donc la place des deux crocs.
//
// ⚠️ Descendue de 0,62 a 0,50 apres une premiere capture : a 0,62 les deux arcs
// etaient si longs et si FINS qu'ils se lisaient comme deux coups de griffe
// paralleles. Ce qui fait lire une machoire est le rapport largeur/epaisseur,
// pas sa courbure — et c'est l'epaisseur qui manquait.
//
// Remontee a 0,72 le 2026-08-17 : la gueule etait trop petite, et c'est en
// LARGEUR qu'elle pouvait grandir. Vers l'avant elle est prise en tenaille — le
// bord du quad d'un cote, le chat de l'autre (voir `jaw_offset`) ; en travers,
// rien ne la borne que la portee qu'elle promet.
//
// A cette valeur la corde vaut ~3,74 m, soit exactement la largeur de l'arc de
// morsure a sa portee (2 × 2,6 × sin 45°) — l'arc a ete ouvert de 70° a 90°
// dans le meme mouvement, pour que la gueule ne montre pas plus large qu'elle
// ne mord.
uniform float jaw_half_width : hint_range(0.1, 1.0) = 0.72;
// Avance de la morsure devant l'ancre, en unites de quad. La morsure mord DEVANT
// le chat, pas sur lui.
//
// ⚠️ MONTEE deux fois — 0,30 puis 0,46, enfin 0,585 le 2026-08-17 — et chaque
// fois pour le meme defaut : LE CHAT SE RETROUVAIT DANS LA GUEULE. La machoire
// inferieure retombait derriere l'ancre et se peignait par-dessus le personnage.
//
// ⚠️ Le calcul se fait a l'ECRAN, pas au sol. Le decalque est un billboard : son
// decalage vers l'avant est un decalage dans le plan de l'image, et le chat y
// occupe ~0,5 m de rayon autour de son ancre. C'est ce rayon-la qu'il faut
// degager, pas la moitie de la profondeur du chat au sol — l'erreur de la
// deuxieme tentative, qui raisonnait en metres de terrain.
//
// D'ou l'encadrement qui fixe toutes les valeurs de pose :
//   `jaw_offset − (gape + thick) ≥ 0,19`  la gueule degage le chat
//   `jaw_offset + (gape + thick) ≤ 0,98`  le haut n'est pas tranche par le quad
// soit un decalage au milieu (0,585) et une demi-ouverture bornee a 0,395.
uniform float jaw_offset : hint_range(-0.5, 0.9) = 0.585;
// Graine tiree a chaque morsure — deux morsures de suite ne doivent pas etre le
// meme tampon. Meme raison que le `seed` de la griffure.
uniform float seed = 0.0;

group_uniforms pose;
// Ecartement des deux machoires, en unites de quad. C'est LE geste : il tombe de
// grand ouvert a referme, et la morsure blesse sur la pose ou il touche le fond.
uniform float gape : hint_range(0.0, 1.0) = 0.55;
// Epaisseur d'une machoire au milieu, en unites de quad.
uniform float thick : hint_range(0.005, 0.3) = 0.085;
// Finesse des deux bouts — ce sont les COMMISSURES. Bas = machoire a bouts
// ronds, haut = pointes fines. C'est lui qui dissipe le dessin PAR LA FORME,
// jamais par l'alpha : §8 interdit le fondu.
uniform float taper : hint_range(0.5, 6.0) = 1.6;

group_uniforms dents;
// Les DENTS, en creux sur le bord INTERIEUR de chaque machoire.
//
// ⚠️ Ajoutees apres capture, et elles ne sont pas un ornement : sans elles, deux
// arcs qui se rapprochent se lisent comme un coup de ciseaux. C'est la denture
// qui dit "gueule".
//
// Elles TIENNENT a la taille de jeu, contrairement aux griffes du chat (§2bis,
// "5 pixels") : la machoire fait ~2 m de corde, soit ~80 px au cadrage de jeu,
// donc une dent de 4 crans en fait ~10. C'est au-dessus du seuil, et c'est la
// seule raison pour laquelle ce detail vaut d'etre dessine.
uniform float teeth_count : hint_range(1.0, 8.0) = 4.0;
// Profondeur du creux entre deux dents, en fraction de l'epaisseur.
//
// ⚠️ Descendue de 0,46 a 0,36 en meme temps que le profil s'arrondissait : a
// 0,46 avec des creux en V, la denture sortait en DENTS DE SCIE — un angle vif,
// ce que §3 interdit sans exception, et un chat n'a pas une gueule de requin.
uniform float teeth_depth : hint_range(0.0, 0.9) = 0.36;

group_uniforms couleurs;
// Brun chaud moyen #8A6A4A — le ton exterieur du cluster. A 0,42 de luminance
// il tranche a la fois sur le parquet (0,84) et sur son propre trait (0,18).
uniform vec4 fill_color : source_color = vec4(0.541, 0.416, 0.290, 1.0);
// Creme chaud #F7EFE0 — le 2e ton, au coeur de la machoire : l'eclat du croc.
// Le meme creme que le pelage tuxedo, la griffure et l'haleine.
uniform vec4 core_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
// Trait brun fonce #3D2B1A — l'encre canonique de §4, et ici elle SUFFIT :
// 0,24 d'ecart de luminance avec l'aplat, la ou la griffure passee a
// l'anthracite n'en avait plus que 0,034 et avait du s'assombrir a #1A120C.
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
uniform float ink : hint_range(0.0, 0.2) = 0.034;


float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}


// Distance signee approchee a UNE machoire.
//
// L'arc est defini implicitement — `p.y = bulge * (1 - (x/hw)^2)` — plutot que
// par un cercle passant par trois points. Ce n'est pas un raccourci : un cercle
// DEGENERE quand la machoire se referme (son rayon part a l'infini), et c'est
// exactement la pose ou la morsure doit etre la plus nette. La parabole, elle,
// reste definie a `bulge = 0`, ou elle rend une droite.
//
// Le champ n'est pas unitaire ; il est renormalise par sa pente dans `fragment`,
// comme celui de la griffure.
float jaw_distance(vec2 p, float bulge, float hw, float w, float sharp) {
	float t = clamp(p.x / max(hw, 1e-4), -1.0, 1.0);
	// L'epaisseur tombe a zero aux deux bouts : ce sont les commissures.
	float w_x = w * pow(max(0.0, 1.0 - t * t), sharp);

	// De quel cote de la machoire on se trouve. L'interieur de la gueule est du
	// cote des y negatifs (l'autre machoire y est), donc c'est LA que les dents
	// se creusent — une denture sur le dos de la machoire ne voudrait rien dire.
	float side = p.y - bulge * (1.0 - t * t);

	// Le creux entre deux dents.
	//
	// ⚠️ `sin^2` et NON `abs(sin)`, et la difference se voit : `abs(sin)` a un
	// point de rebroussement a chaque zero — un V — et la denture sortait en
	// dents de scie sur la capture. `sin^2`, ecrit ici sous sa forme en cosinus,
	// est lisse partout : les creux sont des vallees arrondies, les dents des
	// bosses. §3 interdit les angles vifs, y compris dans une gueule.
	float notch = 0.5 - 0.5 * cos(t * teeth_count * TAU);
	float w_inner = w_x * (1.0 - teeth_depth * (1.0 - notch));

	// ⚠️ Fondu autour de la ligne mediane, et il est NECESSAIRE : deux epaisseurs
	// differentes de part et d'autre de `side = 0` font un saut du champ EN PLEIN
	// DANS l'aplat. Le bord ne bouge pas, mais `core_w` se mesure depuis ce
	// champ — le coeur creme se serait fendu en deux le long de la mediane.
	float w_use = mix(w_inner, w_x, smoothstep(-0.015, 0.015, side));
	float band = abs(side) - w_use;

	// Au-dela de la corde, la machoire n'existe plus : la distance redevient
	// celle au croc, et l'arc s'arrete net au lieu de filer hors du quad.
	float dx = max(0.0, abs(p.x) - hw);
	return dx > 0.0 ? length(vec2(dx, max(band, 0.0))) : band;
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

	vec3 v = (VIEW_MATRIX * vec4(normalize(aim), 0.0)).xyz;
	float ang = atan(v.x, v.y);
	float s = sin(ang);
	float c = cos(ang);

	vec2 q = VERTEX.xy;
	VERTEX.xy = vec2(q.x * c + q.y * s, -q.x * s + q.y * c) * size;
}


void fragment() {
	// ⚠️ Le Y de l'UV d'un QuadMesh descend quand son Y local monte — le piege
	// qui avait envoye la griffure DERRIERE le chat, trouve en regardant les
	// frames. Meme correction ici : +y du dessin pointe vers la visee.
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	// La morsure mord devant l'ancre : on decale le repere, pas le quad.
	p.y -= jaw_offset;

	// Taille d'un pixel en unites de quad, mesuree comme une LONGUEUR : le quad
	// est tourne a l'ecran, donc dFdx(p.x) seul ne mesure plus le pas d'un pixel.
	float ps = max(length(vec2(dFdx(p.x), dFdx(p.y))), 1e-6);

	// Les deux machoires ne sont pas identiques — un chat n'est pas une pince.
	float h = hash11(seed * 11.7);
	float upper = jaw_distance(
		p, gape * (1.0 + 0.10 * h), jaw_half_width, thick, taper
	);
	float lower = jaw_distance(
		vec2(p.x, -p.y), gape * (1.0 - 0.14 * h), jaw_half_width * (0.94 + 0.10 * h),
		thick * 0.88, taper
	);

	float d = min(upper, lower);

	// Le profil effile rend le champ non unitaire pres des crocs : on le
	// renormalise par sa pente pour que la bande d'encre garde partout la meme
	// epaisseur, sinon elle grossit aux pointes et le croc finit en massue.
	vec2 grad = vec2(dFdx(d), dFdy(d)) / ps;
	d /= max(length(grad), 1.0);

	// Un pixel de lissage, et pas un de plus : de l'antialiasing, pas un degrade.
	float aa = ps * 0.75;
	float alpha = 1.0 - smoothstep(-aa, aa, d);

	if (alpha < 0.01) {
		discard;
	}

	// L'encre et le coeur suivent l'amincissement — fixes, ils mangeraient toute
	// la machoire des la 4e pose et la morsure finirait en barre brune.
	float ink_w = min(ink, thick * 0.40);
	// Le coeur se mesure DEPUIS l'encre, pas depuis le bord : pose trop pres il
	// tombe sous l'encre, le brun se reduit a un lisere invisible et le cluster
	// n'a plus qu'un ton (contre §2bis). Piege deja mesure sur la griffure.
	//
	// ⚠️ Monte de 0,26 a 0,40 apres capture : a 0,26 le creme n'apparaissait PAS
	// une seule frame — l'encre et le brun se rejoignaient et la machoire sortait
	// en trait noir uni. Le cluster 2 tons n'existait que dans le fichier.
	float core_w = ink_w + thick * 0.40;

	float ink_mask = smoothstep(-ink_w - aa, -ink_w + aa, d);
	float core_mask = 1.0 - smoothstep(-core_w - aa, -core_w + aa, d);

	vec3 col = mix(fill_color.rgb, core_color.rgb, core_mask);
	ALBEDO = mix(col, ink_color.rgb, ink_mask);
	ALPHA = alpha;
}
