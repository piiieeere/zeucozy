// L'eclat de collision — "Visual Art Direction" §8.
//
// L'etoile d'impact qui claque a l'endroit exact ou un ennemi touche le chat.
//
// ─── REECRIT LE 2026-08-17 : UN IMPACT DE MANGA, PLUS UNE VOLUTE ───
//
// §8 notait le defaut depuis le 2026-08-16 : "il recouvre le chat et se lit
// toujours comme une FLEUR". Ce n'etait pas un reglage rate, c'etait la forme
// elle-meme :
//
//   * le profil `pow(abs(cos(a * n)), sharp)` ne sait produire que des LOBES
//     TANGENTS. Quel que soit l'exposant, deux branches se rejoignent par une
//     courbe — jamais par un angle. Monter `sharp` amincit les petales, ca n'en
//     fait pas des pointes ;
//   * le coeur creme etait un DISQUE centre, donc un pistil ;
//   * l'animation GRANDISSAIT de la premiere pose a la derniere (0,80 → 1,44),
//     ce qui est le geste d'une corolle qui s'ouvre, pas d'un choc.
//
// L'etoile est donc desormais un VRAI POLYGONE : 7 pointes, 14 sommets, des
// segments DROITS entre eux. L'angle vif n'est plus une approximation qu'on
// cherche, c'est ce que la geometrie donne.
//
// ⚠️ §3 interdit les angles vifs — et c'est une regle sur les OBJETS du monde
// (chat, ennemis, mobilier), pas sur l'encre qu'on jette par-dessus. Un impact
// de manga est anguleux par definition : c'est meme la seule chose qui le
// separe d'une eclaboussure. La regle a ete precisee dans la DA en meme temps
// que ce shader.
//
// ─── CE QUI COMPOSE L'EVENEMENT ───
//
//   1. L'ETOILE — polygone a pointes inegales, cluster 2 tons, cernee ;
//   2. LES TESSONS — 4 eclats effiles projetes vers l'exterieur, qui se
//      DETACHENT de l'etoile a mesure qu'elle s'effondre ;
//   3. LE FLASH — la 1ere pose, ou l'etoile est entierement CREME. C'est
//      l'impact frame de §7, ramenee a la taille du coup au lieu du plein
//      cadre qui avait ete debranche le 2026-08-17.
//
// Le meme vocabulaire que le reste du jeu :
//   * deux tons de cluster, francs, sans le moindre degrade (variante A) ;
//   * un trait d'encre epais, jamais noir (§4) ;
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

// Nombre de pointes. IMPAIR a dessein — un compte pair produit une etoile
// symetrique, donc une forme mecanique.
//
// C'est une `const` et non un uniform, pour deux raisons : elle borne les
// boucles du polygone (un compte fixe evite toute boucle dynamique), et ce
// n'est pas un reglage — 7 pointes est une decision de dessin, au meme titre
// que les 2 tons du cluster.
const int SPIKES = 7;
const int VERTS = SPIKES * 2;

// Nombre de tessons projetes. QUATRE : deux ne se lisent pas comme une
// dispersion, six deviennent une gerbe et l'oeil cesse de compter.
const int SHARDS = 4;

// Elancement d'un tesson — sa demi-largeur en fraction de sa demi-longueur.
// Un tesson est une ECHARDE : au-dela de ~0,50 il redevient un galet, et la
// lecture retombe sur la particule molle que §8 refuse.
//
// ⚠️ MONTE de 0,34 a 0,42 apres capture. A 0,34 les tessons sortaient en
// SLIVERS D'ENCRE : leur cerne mangeait plus de la moitie de leur demi-largeur
// et il ne restait aucun rose dedans. C'est la meme borne que sur les dents de
// la morsure, prise par l'autre bout — la ou la denture butait sur le NOMBRE de
// dents, les tessons butent sur leur ELANCEMENT.
const float SHARD_ASPECT = 0.42;

group_uniforms cadrage;
// Cote du quad en metres. Il ne bouge PAS d'une pose a l'autre — tout le geste
// est joue dans le fragment, en unites de quad.
//
// ⚠️ C'est un changement par rapport a l'ancienne version, qui echelonnait le
// quad lui-meme : les tessons s'eloignent, et un quad qui suit la taille de
// l'etoile les aurait tranches net au moment ou ils partent. Le budget est
// donc fixe et explicite — rien ne doit depasser r = 0,96 sur les axes (les
// coins du quad, eux, vont a 1,41).
//
// 2,8 m pour un chat de 1,86 : l'etoile a son extreme fait ~1,9 m de large et
// les tessons portent l'evenement a ~2,3 m. L'ANCIENNE faisait 3,0 m de large
// a elle seule, d'ou le "il recouvre le chat" de §8.
uniform float size = 2.8;
// Graine tiree a chaque impact : deux coups de suite ne doivent pas tamponner
// la meme etoile. Meme role que le `seed` de la griffure et de la morsure.
uniform float seed = 0.0;

group_uniforms pose;
// Rayon de la plus longue pointe, en unites de quad (le quad va de -1 a 1).
// C'EST le geste : voir la table de poses dans hit_burst.gd.
uniform float burst : hint_range(0.0, 1.0) = 0.60;
// L'etoile CREME, en fraction de l'etoile pleine. 0 = plus de 2e ton, 1 =
// l'etoile entiere en creme (la pose de FLASH).
//
// ⚠️ C'est une COPIE REDUITE de l'etoile, pas un disque. Un disque pale au
// centre d'une forme a pointes est un pistil, et c'est exactement ce qui
// faisait lire l'ancien eclat comme une fleur.
uniform float core : hint_range(0.0, 1.0) = 0.38;
// Distance du centre des tessons, en unites de quad.
uniform float shard_dist : hint_range(0.0, 1.0) = 0.63;
// Demi-longueur d'un tesson, en unites de quad. A 0 il n'y a pas de tesson du
// tout — c'est le cas de la pose de flash.
uniform float shard_len : hint_range(0.0, 0.4) = 0.135;

group_uniforms forme;
// Fond des creux, en FRACTION de `burst`. Bas : c'est lui qui fait la
// difference entre une etoile et une rosace. Une fraction et non une valeur
// absolue — sinon les creux ne suivent pas l'effondrement de l'etoile et les
// dernieres poses sortent en anneau.
//
// ⚠️ REMONTE de 0,30 a 0,40 apres capture, et c'est `ink` qui l'a impose, pas
// le dessin : a 0,30 les pointes etaient plus etroites que deux epaisseurs de
// trait, donc ENTIEREMENT en encre. Le cluster 2 tons retombait a un seul ton
// (contre §2bis) — exactement le defaut mesure sur le corps de la griffure,
// et exactement celui des dents de la morsure qui sortaient en treillis.
//
// LES DEUX SE REGLENT ENSEMBLE : un creux profond veut un trait fin, un trait
// epais veut une etoile trapue. On ne peut pas avoir les deux.
uniform float valley : hint_range(0.05, 0.60) = 0.40;

group_uniforms couleurs;
// Rose-rouge #D45870 — c'est ce que §4 range explicitement en "hit feedback".
// Volontairement PAS l'or des croquettes ni l'ambre du level up : tout est
// chaud dans ce jeu, et un eclat dore sur un degat se lirait comme un gain.
uniform vec4 fill_color : source_color = vec4(0.831, 0.345, 0.439, 1.0);
// Le 2e ton du cluster — creme chaud #F7EFE0, jamais un blanc froid (§5). Le
// meme creme que le pelage tuxedo, l'email de la morsure et le front du
// feulement : le projet n'en fabrique pas un second.
uniform vec4 core_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
// Trait tres sombre, TEINTE vers le rose-rouge (#3A161C) plutot que le brun
// #3D2B1A de §4. C'est la regle deja payee sur le pelage tuxedo puis sur la
// morsure : un aplat qui change de teinte force son encre a se teinter vers
// lui, sinon le trait cesse d'appartenir a l'objet. Jamais de noir pur.
uniform vec4 ink_color : source_color = vec4(0.227, 0.086, 0.110, 1.0);
// Epaisseur du trait, en unites de quad. Epais, comme partout — variante A
// (§2bis). Elle est BORNEE plus bas par la taille de ce qu'elle cerne.
//
// ⚠️ MONTE de 0,038 a 0,065 en deux captures, et les deux chiffres viennent de
// l'image, pas du gout :
//   * a 0,038 le trait sortait a 1,7 px sur la frame de jeu — un cheveu.
//     L'etoile se lisait comme un aplat rose a coeur creme, SANS CERNE, ce que
//     §8 refuse explicitement ("le meme trait que les personnages") ;
//   * a 0,085 il faisait 3,8 px et mangeait les pointes en entier. Voir
//     `valley`, qui a du s'ouvrir dans le meme mouvement.
// A 0,065 il fait ~2,9 px, l'ordre du trait du chat.
//
// La conversion a connaitre : le quad fait `size` metres de cote, donc une
// unite de quad vaut `size / 2` = 1,4 m, et 1 m fait ~32 px au cadrage de jeu.
uniform float ink : hint_range(0.0, 0.2) = 0.065;


float hash11(float n) {
	return fract(sin(n * 12.9898 + seed * 71.53) * 43758.5453);
}


// Longueur d'une pointe, en fraction de `burst`.
//
// ⚠️ LE HASARD SEUL NE DEFAIT PAS LA REGULARITE — lecon mesuree sur la couronne
// de l'haleine puante (§8), puis reprise sur l'onde du feulement. Sept pointes
// tirees independamment dans une plage etroite restent sept pointes de meme
// taille. Il y faut une modulation BASSE FREQUENCE, ici un tour complet : un
// cote de l'etoile est franchement long, l'autre franchement court, et c'est
// ce desequilibre qui la fait lire comme un dessin plutot qu'un tampon.
//
// ⚠️ ET ELLE SE DOSE. A `0,40 + 0,60 × slow` la moitie des pointes tombait au
// plancher : l'etoile sortait en FLECHE, longue d'un cote et ronde de l'autre.
// Un eclat d'impact est radial — c'est la LONGUEUR qui doit varier, pas le
// nombre de cotes qui en ont une. Mesure en capture ; ramene a `0,58 + 0,42`,
// et l'exposant a 1,0 pour ne plus ecraser le tirage vers le bas.
float spike_len(float b) {
	float h = hash11(b * 7.31 + 1.7);
	float slow = 0.5 + 0.5 * cos(b / float(SPIKES) * TAU + seed * TAU);
	return mix(0.38, 1.0, h * (0.58 + 0.42 * slow));
}


// Un sommet du polygone. Les indices PAIRS sont des pointes, les IMPAIRS des
// fonds de creux — d'ou 14 sommets pour 7 pointes.
//
// L'angle est lui aussi bruite, mais BORNE a un tiers de l'ecart entre deux
// sommets : au-dela les sommets se croiseraient et le polygone se replierait
// sur lui-meme, ce qui inverse le test de winding et remplit l'etoile d'encre.
vec2 star_vertex(int i) {
	float n = float(SPIKES);
	float half_i = float(i) * 0.5;
	float b = floor(half_i);
	float ang = half_i / n * TAU;
	float rad;

	if (i % 2 == 0) {
		rad = burst * spike_len(b);
		ang += (hash11(b * 3.77 + 5.1) - 0.5) * (TAU / n) * 0.34;
	} else {
		rad = burst * valley * (0.70 + 0.60 * hash11(b * 5.19 + 9.4));
		ang += (hash11(b * 2.43 + 2.8) - 0.5) * (TAU / n) * 0.28;
	}

	return vec2(cos(ang), sin(ang)) * rad;
}


float cross2(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}


// Distance signee au polygone, negative a l'interieur.
//
// ⚠️ C'EST LE POINT QUI A FAIT TOMBER L'ANCIEN DEFAUT D'ENCRE. La version
// precedente mesurait une distance RADIALE (`r - radius`), qui vaut plusieurs
// fois la vraie distance sur le flanc d'une pique : le trait ne cernait que les
// POINTES et laissait les flancs nus. Elle le corrigeait en divisant par la
// pente, avec une garde pres du centre ou la pente diverge — une approximation
// qu'il fallait regler.
//
// Une vraie distance au segment supprime le probleme au lieu de le corriger :
// le trait fait le tour, exactement de la meme epaisseur partout, y compris au
// FOND DES CREUX (ou l'approximation precedente bavait le plus).
//
// ─── ⚠️ LE SIGNE NE SE PREND PAS PAR PARITE DE RAYON, ET LE PIEGE EST MUET ───
//
// La formule canonique d'un polygone (celle d'iq) compte les traversees d'un
// rayon HORIZONTAL, avec `p.y >= vi.y`, `p.y < vj.y` et un test de cote
// `e.x * w.y > e.y * w.x`. Elle est exacte — verifiee ici en float64 sur 400
// graines, pas une erreur — et elle CASSE quand meme sur GPU :
//
//   * une arete quasi HORIZONTALE ne selectionne qu'UNE rangee de pixels ;
//   * sur cette rangee, `w.y` est minuscule et `w.x` vaut presque toute la
//     largeur du quad, donc le test de cote compare deux produits presque
//     egaux. En float32 le signe bascule pour les pixels LOIN de l'etoile ;
//   * la parite est donc fausse depuis le bord du quad jusqu'a l'etoile.
//
// Ca sort en UNE LIGNE de fill pleine, sans encre, en travers du decalque —
// trouve en capture, invisible en lisant le code, et impossible a reproduire
// dans un portage numpy puisque le defaut EST la precision.
//
// La sortie n'est pas de rafistoler le test mais de ne plus en avoir besoin :
// ce polygone est ETOILE PAR RAPPORT A SON CENTRE (les sommets sont a angles
// strictement croissants, le bruit d'angle etant borne a un tiers de l'ecart),
// donc il se pave exactement par ses 14 triangles (0, v[j], v[i]). Un point est
// dedans s'il est dans l'un d'eux. Chaque test est un produit vectoriel entre
// vecteurs franchement separes : un point loin echoue NETTEMENT, il n'y a plus
// de difference de grandeurs voisines nulle part.
float sd_star(vec2 p) {
	vec2 vj = star_vertex(VERTS - 1);
	float d = dot(p - vj, p - vj);
	bool inside = false;

	for (int i = 0; i < VERTS; i++) {
		vec2 vi = star_vertex(i);
		// Arete dans le sens direct : les indices croissants tournent dans le
		// sens trigonometrique, et `vj` est le sommet PRECEDENT.
		vec2 e = vi - vj;
		vec2 w = p - vj;

		vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(b, b));

		// Le coin angulaire (0, vj, vi) fait ~26° : le test est franc.
		bool wedge = cross2(vj, p) >= 0.0 && cross2(p, vi) > 0.0;
		if (wedge && cross2(e, w) >= 0.0) {
			inside = true;
		}

		vj = vi;
	}

	return (inside ? -1.0 : 1.0) * sqrt(d);
}


float ndot(vec2 a, vec2 b) {
	return a.x * b.x - a.y * b.y;
}


// Un losange a coins VIFS — la forme d'echarde. Un ovale aurait redonne la
// particule molle, une capsule un tetard.
float sd_rhombus(vec2 p, vec2 b) {
	vec2 q = abs(p);
	float h = clamp(ndot(b - 2.0 * q, b) / dot(b, b), -1.0, 1.0);
	float d = length(q - 0.5 * b * vec2(1.0 - h, 1.0 + h));
	return d * sign(q.x * b.y + q.y * b.x - b.x * b.y);
}


// Les tessons, reunis en un seul champ.
//
// Leurs directions sont ECARTEES INEGALEMENT et leurs distances tirees au
// hasard : quatre echardes a 90° les unes des autres seraient une croix, donc
// un symbole. Meme raison que les pointes inegales de l'etoile.
//
// ⚠️ Les multiplicateurs sont volontairement etroits (×1,05 au plus sur la
// distance, ×1,15 sur la longueur). Le budget du quad est de 0,96 sur les axes,
// et `shard_dist` monte jusqu'a 0,83 : une plage plus large ferait sortir un
// tesson du quad, qui se ferait TRANCHER NET par son bord — le meme piege que
// l'ancienne `MAX_REACH`, deplace sur les tessons.
float sd_shards(vec2 p) {
	if (shard_len < 0.001) {
		return 1e9;
	}

	float d = 1e9;

	for (int i = 0; i < SHARDS; i++) {
		float f = float(i);
		float ang = (f + 0.55 * hash11(f * 4.13 + 0.9)) / float(SHARDS) * TAU
			+ seed * TAU;
		float dist = shard_dist * (0.80 + 0.25 * hash11(f * 6.71 + 3.3));
		float len = shard_len * (0.75 + 0.40 * hash11(f * 8.09 + 6.6));

		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 q = p - dir * dist;
		// Repere du tesson : x le long du rayon, pour qu'il pointe VERS
		// L'EXTERIEUR. Une echarde en travers de sa trajectoire se lit comme un
		// debris qui tombe, pas comme un morceau projete.
		vec2 local = vec2(dot(q, dir), dot(q, vec2(-dir.y, dir.x)));
		d = min(d, sd_rhombus(local, vec2(len, len * SHARD_ASPECT)));
	}

	return d;
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
	// ⚠️ Le QuadMesh fait 1 × 1 : sans cette ligne le decalque garde un metre
	// de cote quel que soit `size`. La taille ne depend PAS de la pose — voir
	// l'en-tete de `size`.
	VERTEX.xy *= size;
}


void fragment() {
	vec2 p = UV * 2.0 - 1.0;

	// Taille d'un pixel en unites de quad. Un pixel de lissage, et pas un de
	// plus : c'est de l'antialiasing, pas un degrade (§2bis interdit les
	// seconds, pas le premier).
	float ps = max(max(abs(dFdx(p.x)), abs(dFdy(p.y))), 1e-6);
	float aa = ps * 0.75;

	float d_star = sd_star(p);
	float d_shard = sd_shards(p);

	float a_star = 1.0 - smoothstep(-aa, aa, d_star);
	float a_shard = 1.0 - smoothstep(-aa, aa, d_shard);
	float alpha = max(a_star, a_shard);

	if (alpha < 0.01) {
		discard;
	}

	// ⚠️ UN CERNE SE DOSE SUR CE QU'IL CERNE, jamais en valeur partagee. La
	// regle a deja ete payee trois fois dans ce projet : sur le petit texte de
	// l'ATH (2 px sur un glyphe de 12 le remplissent), sur les volutes de
	// l'haleine, et sur les dents de la morsure qui sortaient en treillis.
	//
	// Ici l'etoile S'EFFONDRE : une epaisseur fixe la mangerait entierement sur
	// les dernieres poses et l'impact finirait en tache d'encre. Les tessons,
	// eux, sont dix fois plus petits que l'etoile et ont leur propre borne —
	// c'est la seule raison pour laquelle ils sont composites a part.
	float ink_star = min(ink, burst * 0.22);
	float ink_shard = min(ink * 0.55, shard_len * SHARD_ASPECT * 0.30);

	float m_ink_star = smoothstep(-ink_star - aa, -ink_star + aa, d_star);
	float m_ink_shard = smoothstep(-ink_shard - aa, -ink_shard + aa, d_shard);

	// Le 2e ton : la MEME etoile, reduite. `sd_star(p / c) * c` est la distance
	// signee du polygone mis a l'echelle — les angles vifs sont donc conserves
	// tels quels, la ou un simple retrait de contour (`d < -e`) aurait arrondi
	// chaque pointe et ramene la lecture vers la fleur.
	float m_core = 0.0;
	if (core > 0.001) {
		float d_core = sd_star(p / core) * core;
		m_core = 1.0 - smoothstep(-aa, aa, d_core);
	}

	vec3 star_col = mix(fill_color.rgb, core_color.rgb, m_core);
	star_col = mix(star_col, ink_color.rgb, m_ink_star);

	vec3 shard_col = mix(fill_color.rgb, ink_color.rgb, m_ink_shard);

	// L'etoile passe DEVANT les tessons : tant qu'ils se chevauchent (les deux
	// premieres poses) ils se lisent comme encore accroches a elle, et c'est
	// leur separation qui raconte la projection.
	ALBEDO = mix(shard_col, star_col, a_star);
	ALPHA = alpha;
}
