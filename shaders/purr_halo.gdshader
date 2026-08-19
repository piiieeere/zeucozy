// Le ronron — le 3e ACTIF, et le premier effet de SOIN du jeu.
//
// Deux arches concentriques qui montent au-dessus du chat et gonflent d'un cran
// a chaque bouffee de ronron. Elles ne blessent personne et ne portent nulle
// part : elles disent que le chat se REFAIT.
//
// ─── LA PREMIERE FORME DU JEU QUI NE PROMET AUCUNE DISTANCE ───
//
// Les six autres FX ont tous un contrat de portee : la couronne de l'haleine
// affleure son rayon de morsure, l'onde du feulement finit exactement sur sa
// portee de poussee, la touffe de poussiere dessine sa zone de contact, la
// griffure et la morsure dimensionnent leur decalque sur `range`. C'est la regle
// de §2.10 — le dessin et la portee ne peuvent pas diverger.
//
// Le ronron n'a pas de portee du tout. Il soigne le chat, personne d'autre, et
// nulle part ailleurs. Consequences a connaitre, parce qu'elles retirent trois
// contraintes que tous les autres shaders de ce dossier subissent :
//
//   * `size` est une CONSTANTE, pas une valeur de palier. Un palier de ronron
//     rend plus de vie, il ne dessine pas plus grand. Le trait peut donc vivre
//     en unites de quad sans le risque que §8 signale sur l'haleine (un trait
//     exprime en fraction du decalque GROSSIT avec la zone a chaque palier) ;
//   * le gonflement pourrait depasser 1,0 — l'interdit de l'haleine et du mouton
//     ("la crete ne doit jamais promettre une portee qu'on n'a pas") ne
//     s'applique pas ici. Il reste sous 1,0 pour une tout autre raison : le
//     BORD DU QUAD. Voir l'invariant plus bas ;
//   * rien a verifier entre le dessin et la feuille de soin. C'est le seul FX du
//     jeu dont on peut changer la taille sans rien mesurer d'autre.
//
// ─── DEUX ARCHES, PAS TROIS, ET C'EST LE PIXEL QUI L'A DECIDE ───
//
// Trois arcs reguliers, c'est un pictogramme de haut-parleur ; et surtout, a la
// taille du jeu, le troisieme ne tenait pas. Une arche doit porter son encre des
// DEUX cotes (~1,9 px chacune) plus son aplat : sous ~9 px de large elle sort en
// trait double, c'est-a-dire en salete. C'est exactement le mur des machoires de
// la morsure ("a `thick` 0,07 elles se lisaient comme un coup de ciseaux") et
// celui des dents ("le nombre de dents est borne par le TRAIT").
//
// Restent une GROSSE arche et un ECHO fin. Le contraste d'echelle fait le
// travail que la regularite ne faisait pas — meme geste que les deux canines au
// milieu des petites dents, et que le 44 px contre 10 px des cartons (§9.3).
//
// ─── ELLES S'OUVRENT VERS LE HAUT, ELLES NE SE REFERMENT PAS ───
//
// Un anneau ferme existe deja : c'est le feulement. Deux arcs ouverts par le bas
// se lisent autrement — ils MONTENT au lieu de s'etendre, et rien ne les
// confond avec une zone posee au sol. Un cercle autour du chat aurait annonce
// une portee, et ce FX n'en a aucune.
//
// ⚠️ ET ILS SONT INCLINES, jamais d'aplomb — voir `tilt`. Deux arcs
// concentriques poses droit au-dessus d'une tete, c'est le pictogramme du
// signal reseau, et ca a ete constate en capture avant d'etre corrige.
//
// Tout ce qui bouge est pose depuis purr_halo.gd, pose par pose. Ce shader ne
// sait rien du temps : il dessine UNE pose (§7).

shader_type spatial;

// BILLBOARD et hors du test de profondeur, comme la griffure, la morsure et
// l'eclat — et pour leur raison, pas pour celle de l'haleine. Ces trois-la
// marquent un GESTE ou un ETAT du personnage : un canape qui en avalerait la
// moitie ferait disparaitre l'information au moment ou elle compte. L'aura de
// l'haleine et l'onde du feulement, elles, sont occultees parce qu'elles
// promettent une distance AU SOL, ou le decor a son mot a dire.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled,
	blend_mix, shadows_disabled;

group_uniforms cadrage;
// DIAMETRE du halo en metres. Constant — voir l'en-tete : le ronron ne promet
// aucune distance, donc aucun palier ne le fait grandir.
uniform float size = 2.8;

group_uniforms pose;
// Gonflement des deux arches, en fraction du rayon de quad. 1,00 = la bouffee
// pleine, celle qui soigne.
//
// ⚠️ INVARIANT DU BORD DU QUAD, a revalider des qu'un des quatre chiffres bouge :
//     swell x (echo_radius + echo_thick) + ink <= 0,98
// Le quad va de -1 a 1, et les arches vivent autour de +y ou le rayon maximum
// vaut exactement 1,0 : au-dela, l'echo est TRANCHE NET par le bord et le halo
// sort avec un couvercle plat. Meme borne que `jaw_offset + gape + thick < 1,0`
// sur la morsure, qui l'a payee en capture.
uniform float swell : hint_range(0.3, 1.0) = 1.0;
// Ouverture du croissant creme sur l'arche, en fraction de son epaisseur.
// 0 = plus de creme, l'arche retombe a un seul ton.
uniform float core : hint_range(0.0, 1.0) = 0.55;

group_uniforms forme;
// Demi-ouverture des arches, en radians, mesuree depuis le HAUT. 1,22 rad = 70°,
// soit une arche qui descend jusqu'a 20° au-dessus de l'horizontale. Ses bouts
// retombent donc de part et d'autre de la tete sans jamais se rejoindre sous le
// chat — c'est ce qui la distingue d'un anneau.
uniform float aperture : hint_range(0.3, 1.57) = 1.22;
// L'arche : rayon de sa ligne moyenne et demi-epaisseur, en unites de quad.
uniform float arch_radius : hint_range(0.1, 0.9) = 0.46;
uniform float arch_thick : hint_range(0.02, 0.3) = 0.140;
// L'echo, plus loin et bien plus fin. C'est le contraste des deux qui fait lire
// une bouffee plutot qu'un pictogramme.
uniform float echo_radius : hint_range(0.1, 0.95) = 0.82;
uniform float echo_thick : hint_range(0.02, 0.3) = 0.075;

// Inclinaison du halo, en radians. Tiree au hasard a chaque ronron.
//
// ⚠️ CE N'EST PAS UN ORNEMENT, C'EST CE QUI SEPARE UN DESSIN D'UNE ICONE.
// Trouve en capture : deux arcs concentriques poses D'APLOMB au-dessus d'une
// tete, c'est le pictogramme de signal — le lecteur y voit une barre de reseau
// avant d'y voir un ronron, et aucun reglage de couleur ou d'encre ne rattrape
// ca. Une icone est axee ; un dessin ne l'est pas. Meme geste que l'inclinaison
// tiree au hasard des onomatopees, et pour exactement la meme raison : posee
// d'aplomb, une onomatopee redevient un sous-titre.
uniform float tilt = 0.0;

// Irregularite du rayon, en fraction. Deux frequences, comme la couronne de
// l'haleine et le bord du mouton : le hasard seul ne defait pas la regularite,
// il faut une modulation LENTE pour que le tour ait des cotes differents.
uniform float wobble : hint_range(0.0, 0.2) = 0.038;
// Graine tiree a chaque ronron : deux bouffees de suite ne sont pas le meme
// tampon. Meme raison que la griffure, la morsure et le feulement.
uniform float seed = 0.0;

group_uniforms couleurs;
// Vert menthe #60C498 — §4 le range en "Bonus / heal", et il n'est utilise nulle
// part ailleurs dans le jeu. C'est le seul vert des FX : rien a apprendre, la
// couleur DIT le soin.
//
// ⚠️ Il est plus froid que tout ce que la palette pose d'habitude sur le
// parquet, et §5 prefere les tons chauds. Deux choses le tiennent : sa valeur
// (0,68) tranche des deux cotes — le parquet est a 0,84-0,93, le pelage a 0,29 —
// et il ne reste que deux secondes a l'ecran. Si la capture le fait lire comme
// une tache froide, la parade est celle deja payee sur le canape et sur le corps
// de la griffure : descendre la valeur et rechauffer la teinte, jamais baisser
// l'alpha.
uniform vec4 fill_color : source_color = vec4(0.376, 0.769, 0.596, 1.0);
// Creme chaud #F7EFE0 — le 2e ton du cluster, le meme creme que le pelage
// tuxedo, l'email de la morsure et le front du feulement. Le projet n'en
// fabrique pas un second.
uniform vec4 core_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
// L'encre canonique de §4.
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
// ⚠️ En unites de quad, et c'est sans danger ICI seulement : `size` ne bouge
// jamais (voir l'en-tete). 0,030 fait ~1,9 px au cadrage de jeu — au-dessus du
// plancher du pixel, sous lequel un trait ne se lit plus comme un trait mais
// comme de la salete (mesure sur le trait de la croquette).
uniform float ink : hint_range(0.0, 0.1) = 0.030;


// Distance signee a une arche centree sur +y, avec des bouts ARRONDIS.
// `sc` = (sin, cos) de la demi-ouverture, `ra` le rayon moyen, `rb` la
// demi-epaisseur. Formule d'iq — exacte, et sans le test de parite qui a coute
// si cher a l'eclat de collision : il n'y a ici qu'un `?:` entre deux branches
// franchement separees.
float arc_field(vec2 p, vec2 sc, float ra, float rb) {
	p.x = abs(p.x);
	return ((sc.y * p.x > sc.x * p.y)
		? length(p - sc * ra)
		: abs(length(p) - ra)) - rb;
}


void vertex() {
	// Billboard : le halo regarde toujours la camera. C'est un dessin epingle au
	// chat, pas un objet pose dans le monde.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);

	// ⚠️ Le QuadMesh fait 1 × 1 : sans cette ligne le halo garde un metre de cote
	// quel que soit `size`. Voir hiss_ring, ou le meme oubli a sorti l'anneau en
	// quatre croissants sans lever la moindre erreur.
	VERTEX.xy *= size;
}


void fragment() {
	// ⚠️ Le Y de l'UV d'un QuadMesh DESCEND quand son Y local monte — le piege
	// que la griffure et la morsure ont deja paye, et que celui-ci a repaye : le
	// `UV * 2 - 1` habituel a sorti les deux arches en BOL sous les pattes du
	// chat, ouvertes vers le ciel. Un dessin symetrique n'aurait rien montre ;
	// une arche, si, des la premiere frame capturee.
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);

	// ⚠️ Pente prise sur `r`, donc sur les coordonnees SIGNEES et HORS de tout
	// branchement. `arc_field` passe `p.x` par `abs()` : une derivee prise apres
	// exploserait sur la colonne de pixels de l'axe de symetrie — pile la ou
	// passe le sommet des deux arches. Et une derivee dans un branchement non
	// uniforme est indefinie en GLSL.
	float ps = max(length(vec2(dFdx(r), dFdy(r))), 1e-6);
	float aa = ps * 0.75;

	// L'inclinaison se prend ICI, sur le repere, et non sur le node : le halo est
	// un billboard, le tourner dans le monde le ferait basculer en profondeur au
	// lieu de pencher dans le plan de l'image.
	float ct = cos(tilt);
	float st = sin(tilt);
	p = vec2(p.x * ct - p.y * st, p.x * st + p.y * ct);

	vec2 sc = vec2(sin(aperture), cos(aperture));

	// L'irregularite, prise sur l'angle SIGNE : `arc_field` symetrise ensuite,
	// mais le rayon, lui, doit rester different a gauche et a droite. Une arche
	// parfaitement symetrique est un pictogramme.
	float a = atan(p.y, p.x);
	float slow = 0.55 + 0.45 * sin(a * 2.0 - seed * 4.1);
	float bend = 1.0 + wobble * cos(a * 5.0 + seed * TAU) * slow;
	// L'echo prend un decalage de phase : sans lui les deux arches ondulent
	// ensemble et se lisent comme une seule forme epaisse.
	float bend2 = 1.0 + wobble * cos(a * 5.0 + seed * TAU + 2.4) * slow;

	float arch_r = swell * arch_radius * bend;
	float arch = arc_field(p, sc, arch_r, arch_thick);
	float echo = arc_field(p, sc, swell * echo_radius * bend2, echo_thick);

	float d = min(arch, echo);
	float alpha = 1.0 - smoothstep(-aa, aa, d);

	if (alpha < 0.01) {
		discard;
	}

	// L'encre se dose sur CE QU'ELLE CERNE, jamais en valeur partagee : l'echo
	// fait la moitie de l'epaisseur de l'arche, son trait doit suivre. Sans ce
	// plafond, l'echo sort entierement en encre — le defaut deja mesure sur
	// l'onde du feulement, qui finissait en cercle noir sur ses dernieres poses.
	float arch_ink = min(ink, arch_thick * 0.40);
	float echo_ink = min(ink, echo_thick * 0.40);

	// ⚠️ L'ENCRE SE PREND SUR LE CHAMP DE L'UNION, jamais forme par forme.
	// Le premier jet faisait le `max` des deux masques d'encre, ce qui est faux
	// et sort ENTIEREMENT NOIR : un pixel au coeur de l'arche est, par
	// construction, LOIN de l'echo — donc le masque de l'echo y vaut 1, donc le
	// `max` vaut 1, donc tout est encre. Les deux arches sont sorties en aplats
	// bruns pleins, sans un pixel de menthe ni de creme, et rien dans le code ne
	// le disait : les deux masques sont justes chacun de son cote.
	// C'est ce que `d` corrige — il ne mesure que la distance au bord LE PLUS
	// PROCHE, donc a celui qui cerne vraiment ce pixel. Sa largeur suit la forme
	// retenue : un branchement qui choisit une valeur, jamais un branchement dans
	// lequel on prendrait une derivee.
	float ink_w = (arch < echo) ? arch_ink : echo_ink;
	float ink_mask = smoothstep(-ink_w - aa, -ink_w + aa, d);

	// ⚠️ LE CREME EST UN CROISSANT SUR LE BORD INTERIEUR DE L'ARCHE, pas une
	// pastille au milieu. C'est le reglage que l'haleine puante et le mouton ont
	// tous deux du trouver : un accent centre est un POIS, il ne se lit comme
	// une brillance qu'une fois rogne par la silhouette qui le porte. Ici il est
	// rogne par le bord INTERIEUR — le cote tourne vers le chat, celui d'ou la
	// chaleur vient.
	//
	// ⚠️ ET LE SEUIL EST FRANC, a un pixel pres. Une rampe large sortirait en
	// degrade d'aerographe, la seule zone lissee de toute l'image : un cluster
	// 2 tons se lit a son BORD (§2bis), etale il n'y a plus deux tons.
	float core_w = arch_ink + (1.0 - core) * arch_thick;
	float inner = smoothstep(aa, -aa, r - arch_r);
	float core_mask = smoothstep(core_w - aa, core_w + aa, -arch) * inner;
	core_mask *= 1.0 - ink_mask;

	vec3 col = mix(fill_color.rgb, core_color.rgb, core_mask);
	ALBEDO = mix(col, ink_color.rgb, ink_mask);
	ALPHA = alpha;
}
