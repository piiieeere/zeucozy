// La morsure — la premiere competence ACTIVE du jeu.
//
// Deux machoires qui se referment : une GENCIVE en arc, et des DENTS plantees
// dessus qui s'engrenent au claquement. C'est un GESTE ponctuel, declenche par
// le joueur — l'inverse exact de l'haleine puante, qui ne se commande pas.
//
// Le vocabulaire est celui de claw_slash.gdshader, dont ce fichier reprend le
// squelette : billboard epingle a un point du monde, quad tourne dans le plan de
// l'ecran pour suivre la visee, SDF a bords effiles, cluster 2 tons + encre.
//
// ─── REFONTE DU 2026-08-17 : LES DENTS SONT DES DENTS ───
//
// La version precedente dessinait la denture en CREUX sur le bord interieur de
// deux arcs — un feston. A taille de jeu ce feston ne se lisait pas : on voyait
// deux bandes brunes qui se rapprochaient, et rien qui dise "gueule". Le detail
// etait dans le fichier, pas dans l'image.
//
// Les dents sont donc devenues de la FORME : des crocs coniques unis a la
// gencive (`min` de deux champs), avec deux canines plus longues, et un decalage
// d'une demi-dent entre le haut et le bas pour qu'ils s'ENGRENENT au claquement
// au lieu de se cogner bout a bout. Le zigzag de la gueule fermee est ce qui
// dit "morsure" ; deux arcs qui se touchent disaient "ciseaux".
//
// ⚠️ ET LE CLUSTER 2 TONS A CHANGE DE SENS. Avant : un coeur creme au milieu
// d'une machoire brune — un eclat decoratif, qui ne designait rien. Maintenant
// les deux tons sont les deux MATIERES : gencive rouge, email creme. Le 2e ton
// n'est plus un reflet pose sur la forme, c'est la forme elle-meme qui se
// separe. §2bis est tenu, et il est tenu pour une raison.
//
// ─── LE ROUGE (2026-08-17) ───
//
// Le brun chaud #8A6A4A a ete remplace par un rouge #C4382E. L'argument
// d'origine — "le terracotta est a deux points du rose de l'eclat de collision,
// il se lirait comme lui" — reste vrai et il est ASSUME : l'eclat sera
// retravaille. Ce qui a tranche est que le brun etait la couleur du DECOR
// (parquet, encre, bois) et qu'une gueule ne peut pas etre de la meme famille
// que le sol sur lequel elle se peint.
//
// Le rouge est franc mais pas primaire : 0,38 de luminance, il tranche sur le
// parquet (0,84) et sur son propre trait (0,12). Le trait a suivi le meme
// glissement que sur le chat tuxedo — un aplat qui change de teinte force son
// encre a se teinter vers lui, sinon le trait cesse d'appartenir a l'objet.
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
// ⚠️ ELLE EST CALEE SUR L'ARC DE DEGATS, pas choisie a l'oeil : 0,574 = sin 35°,
// donc la corde du dessin (2 × 0,574 × portee) vaut celle de l'arc de 70° a sa
// portee (2 × portee × sin 35°). La gueule ne montre ni plus ni moins large
// qu'elle ne mord. Bouger l'un sans l'autre est un mensonge de dessin.
//
// ⚠️ RESSERREE de 0,72 (90°) a 0,574 (70°) le 2026-08-17, en meme temps que la
// denture. Le 90° n'avait jamais ete une decision de gameplay : il avait ete
// OUVERT pour donner de la place a un dessin qui ne tenait pas, la seule
// dimension libre a l'epoque etant la largeur. Les dents ayant repris ce travail
// vers l'interieur, l'arc peut revenir a ce que la competence voulait dire —
// *un croc pique, il ne balaie pas*.
//
// A 0,72 la gueule etait plus large que le chat n'est haut, cinq fois : elle se
// lisait comme une bouche autonome posee sur le sol plutot que comme la sienne.
uniform float jaw_half_width : hint_range(0.1, 1.0) = 0.574;
// Avance de la morsure devant l'ancre, en unites de quad. La morsure mord DEVANT
// le chat, pas sur lui.
//
// ⚠️ Le calcul se fait a l'ECRAN, pas au sol. Le decalque est un billboard : son
// decalage vers l'avant est un decalage dans le plan de l'image, et le chat y
// occupe ~0,5 m de rayon autour de son ancre. C'est ce rayon-la qu'il faut
// degager, pas la moitie de la profondeur du chat au sol — l'erreur d'une
// tentative precedente, qui raisonnait en metres de terrain.
//
// D'ou l'encadrement qui fixe toutes les valeurs de pose :
//   `jaw_offset − (gape + thick) ≥ 0,19`  la gueule degage le chat
//   `jaw_offset + (gape + thick) ≤ 0,98`  le haut n'est pas tranche par le quad
// soit un decalage au milieu (0,585) et une demi-ouverture bornee a 0,395.
//
// ⚠️ Les DENTS n'entrent pas dans cet encadrement, et c'est structurel : elles
// poussent vers l'INTERIEUR de la gueule. Elles ne peuvent donc jamais toucher
// le bord du quad ni retomber sur le chat, quelle que soit leur longueur.
uniform float jaw_offset : hint_range(-0.5, 0.9) = 0.585;
// Graine tiree a chaque morsure — deux morsures de suite ne doivent pas etre le
// meme tampon. Meme raison que le `seed` de la griffure.
uniform float seed = 0.0;

group_uniforms pose;
// Ecartement des deux gencives, en unites de quad. Avec `thick` et `tooth_len`
// il decide de l'ouverture reelle de la gueule :
//   bord interieur de la gencive = gape − thick
//   pointe des dents             = gape − thick − tooth_len
// La morsure blesse sur la pose ou les pointes passent la ligne mediane.
uniform float gape : hint_range(0.0, 1.0) = 0.275;
// Epaisseur de la gencive au milieu, en unites de quad. C'est la MASSE de la
// machoire : c'est elle qui la separe d'une griffure, pas sa courbure.
uniform float thick : hint_range(0.005, 0.3) = 0.120;
// Finesse des deux bouts — ce sont les COMMISSURES. Bas = machoire a bouts
// ronds, haut = pointes fines. C'est lui qui dissipe le dessin PAR LA FORME,
// jamais par l'alpha : §8 interdit le fondu.
//
// Il pilote aussi l'etagement des dents : elles raccourcissent vers les
// commissures avec la meme loi que la gencive, sinon elles depasseraient d'une
// machoire qui n'existe plus.
uniform float taper : hint_range(0.5, 6.0) = 1.3;
// Longueur des dents au milieu de l'arc, en unites de quad. Elle fait partie de
// la pose : les dents POUSSENT vers le claquement et rentrent en se dissipant.
uniform float tooth_len : hint_range(0.0, 0.4) = 0.175;

group_uniforms dents;
// ─── UNE DENTURE DE CHAT, PAS UNE DENTURE REGULIERE (2026-08-17) ───
//
// Deux GRANDES CANINES et de PETITES DENTS entre elles. C'est la denture du
// chat, et c'est aussi ce qui empeche la gueule de retomber dans le registre du
// requin : une rangee de dents toutes egales est une scie, quelle que soit la
// forme de chaque dent prise a part. Ce qui fait lire "chat" est le CONTRASTE
// d'echelle a l'interieur de la rangee — le meme geste que §9.3 applique au
// texte des cartons (44 px contre 10).
//
// Les dents restent posees sur une grille reguliere : chez un chat aussi, ce qui
// varie d'une dent a l'autre est la TAILLE, pas l'ecartement.
//
// Nombre de dents sur la corde, machoire du haut. Celle du bas est decalee d'une
// demi-dent (voir `jaw_fields`) et en porte donc une de plus — la rangee du bas
// tombe dans les creux de celle du haut, ce qui est a la fois l'engrenement et
// la denture reelle d'un chat, dont les incisives du bas ferment derriere celles
// du haut.
//
//   haut (7) : 2 canines · 2 incisives · 2 petites du fond
//   bas  (7) : 2 canines · 3 incisives · 2 petites du fond
//
// A la portee T1 la corde fait ~4,1 m, soit ~165 px au cadrage de jeu : une
// canine en fait ~19 de large et ~28 de long, une incisive ~10 sur 11. C'est
// au-dessus du seuil de lecture, contrairement aux griffes du chat (§2bis,
// "5 pixels") — et c'est la seule raison pour laquelle ce detail vaut d'etre
// dessine.
uniform float teeth_count : hint_range(2.0, 12.0) = 7.0;
// Demi-largeur d'une CANINE a sa racine, en fraction de l'ecart entre deux dents.
// Sous ~0,5 les dents sont separees par du rouge ; au-dela elles se touchent et
// la denture redevient une bande.
//
// ⚠️ C'est la BASE, et non la pointe, qui separe un croc d'une dent de scie. Une
// premiere capture donnait des triangles quasi equilateraux — une gueule de
// requin, le registre que §3 refuse. Un croc se reconnait a son elancement : il
// lui faut au moins 1,7 fois plus long que large.
uniform float tooth_width : hint_range(0.1, 0.9) = 0.45;
// Rayon de la pointe, en fraction de la racine. Jamais zero : §3 interdit
// l'angle vif sans exception, y compris au bout d'un croc.
//
// ⚠️ MONTE de 0,10 a 0,34 : a 0,10 la pointe faisait 0,6 px de rayon, soit un
// sommet franc une fois l'antialiasing passe dessus. A 0,34 elle fait ~2 px, et
// comme l'encre en fait ~3, le dernier tiers du croc sort en pointe SOMBRE et
// ronde — le meme registre que les griffes du chat.
uniform float tooth_tip : hint_range(0.02, 0.5) = 0.34;

group_uniforms canines;
// Quelle dent est la canine, comptee depuis le milieu de la gueule : 0 = la plus
// centrale, 1 = la suivante.
//
// ⚠️ C'est un RANG et non une position, pour que la canine reste une dent
// entiere quand `teeth_count` bouge. Exprimee en fraction de corde, elle tombait
// entre deux dents des qu'on changeait le compte : deux dents a demi grandies au
// lieu d'un croc.
uniform float canine_rank : hint_range(0.0, 4.0) = 1.0;
// Longueur des petites dents, en fraction de la canine. C'EST LE RAPPORT QUI
// FAIT LA DENTURE : a 1,0 toutes les dents sont des canines et la gueule
// redevient une scie ; a 0,35 les incisives sont des nubs entre deux crocs.
//
// ⚠️ REDESCENDU de 0,42 a 0,36 en meme temps que `tooth_len` montait. Le rapport
// et la longueur de croc se reglent ENSEMBLE, sinon allonger les canines allonge
// aussi les incisives et la denture reste la meme, juste plus grande. Ici les
// deux mouvements se compensent exactement : les petites dents mesurent 0,094
// avant comme apres, les canines gagnent 16 %.
uniform float incisor_len : hint_range(0.1, 1.0) = 0.36;
// Largeur des petites dents, en fraction de la canine.
//
// ⚠️ Elle ne suit PAS `incisor_len`, et c'est le trait qui l'interdit : une
// incisive reduite dans les deux sens tombait a ~5 px de large, dont 2×3 px
// d'encre — elle sortait entierement noire. Une petite dent doit rester TRAPUE
// pour rester une dent. C'est d'ailleurs la forme d'une vraie incisive.
uniform float incisor_width : hint_range(0.1, 1.0) = 0.78;

group_uniforms couleurs;
// Rouge #C4382E — la GENCIVE, le ton exterieur du cluster. A 0,38 de luminance
// il tranche a la fois sur le parquet (0,84) et sur son propre trait (0,12).
uniform vec4 fill_color : source_color = vec4(0.769, 0.220, 0.180, 1.0);
// Creme chaud #F7EFE0 — l'EMAIL, le 2e ton. Le meme creme que le pelage tuxedo,
// la griffure et l'haleine : le projet n'en fabrique pas un second.
uniform vec4 tooth_color : source_color = vec4(0.969, 0.937, 0.878, 1.0);
// Trait #3A1410 — un brun-rouge tres sombre, pas l'encre brune canonique de §4.
// Meme raison que le trait du chat noir : le trait doit rester plus sombre que
// l'aplat ET appartenir a sa famille de teinte. Le #3D2B1A du monde vire au
// verdatre pose sur du rouge.
uniform vec4 ink_color : source_color = vec4(0.227, 0.078, 0.063, 1.0);
// ⚠️ 0,020 et non les 0,034 d'avant : le trait est desormais borne par la piece
// la plus FINE du dessin, pas par la plus grosse. Un croc fait 0,10 de large ;
// a 0,034 de chaque cote il ne restait plus que 0,032 d'email au milieu, et les
// dents sortaient noires. Un cerne se dose sur ce qu'il cerne (deja mesure sur
// le petit texte de l'ATH, §9), jamais en valeur partagee.
uniform float ink : hint_range(0.0, 0.2) = 0.020;


float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}


// Une machoire : `x` = distance a la GENCIVE, `y` = distance aux DENTS.
//
// Les deux champs sortent separes et non unis, alors que la silhouette est bien
// leur union : c'est la couleur qui a besoin de les distinguer. L'email doit se
// peindre sur la dent SEULE, et une fois les deux champs fondus en un `min` on ne
// sait plus de qui vient la distance.
//
// ─── LA GENCIVE ───
//
// L'arc est defini implicitement — `p.y = bulge * (1 - (x/hw)^2)` — plutot que
// par un cercle passant par trois points. Ce n'est pas un raccourci : un cercle
// DEGENERE quand la machoire se referme (son rayon part a l'infini), et c'est
// exactement la pose ou la morsure doit etre la plus nette. La parabole, elle,
// reste definie a `bulge = 0`, ou elle rend une droite.
//
// ─── LES DENTS ───
//
// Repetition de domaine sur `x` : une cellule par dent, et on regarde les trois
// cellules voisines. Une seule cellule suffirait pour la dent qui contient le
// pixel, mais pas pour le VIDE entre deux dents — la ou l'encre doit se former,
// le pixel appartient a une cellule et sa dent la plus proche est dans une autre.
//
// Le decalage `phase` d'une demi-cellule est ce qui fait ENGRENER les deux
// machoires : sans lui, les pointes du haut tombent pile sur celles du bas et se
// cognent bout a bout, ce qui se lit comme une fermeture eclair.
//
// Aucun des deux champs n'est unitaire ; ils sont renormalises par leur pente
// dans `fragment`, comme celui de la griffure.
vec2 jaw_fields(
	vec2 p, float bulge, float hw, float w, float sharp,
	float tlen, float phase, float cpos, float sd
) {
	hw = max(hw, 1e-4);

	float t = clamp(p.x / hw, -1.0, 1.0);
	float w_x = w * pow(max(0.0, 1.0 - t * t), sharp);
	float side = p.y - bulge * (1.0 - t * t);
	float band = abs(side) - w_x;

	// Au-dela de la corde, la gencive n'existe plus : la distance redevient celle
	// a la commissure, et l'arc s'arrete net au lieu de filer hors du quad.
	float dx = max(0.0, abs(p.x) - hw);
	float gum = dx > 0.0 ? length(vec2(dx, max(band, 0.0))) : band;

	float pitch = 2.0 * hw / max(teeth_count, 1.0);
	float teeth = 1e6;

	for (int k = -1; k <= 1; k++) {
		float id = floor(p.x / pitch - phase) + float(k) + 0.5 + phase;
		float cx = id * pitch;
		float ct = cx / hw;

		// Pas de dent hors de la corde. Sans ce garde-fou, une dent de longueur
		// nulle reste un POINT a distance nulle de son propre centre : une tache
		// d'encre parasite apparaitrait a chaque commissure.
		if (abs(ct) >= 1.0) {
			continue;
		}

		// EST-CE UNE CANINE ? La bosse est large d'une demi-dent : la voisine
		// immediate n'en recoit plus que 0,7 %, donc un croc UNIQUE de chaque
		// cote et non deux dents a demi grandies.
		float span = 0.45 * 2.0 / max(teeth_count, 1.0);
		float bump = exp(-pow((abs(ct) - cpos) / span, 2.0));
		// Les dents s'etagent comme la gencive, en plus doux : `sharp * 0.55`.
		// A `sharp` plein, les dents des bords disparaissaient bien avant la
		// commissure et la gueule se terminait par deux becs nus.
		float env = pow(max(0.0, 1.0 - ct * ct), sharp * 0.55);
		float jitter = 0.90 + 0.20 * hash11(id * 7.31 + sd);
		float len = tlen * env * mix(incisor_len, 1.0, bump) * jitter;

		if (len < 1e-4) {
			continue;
		}

		// La racine part du bord INTERIEUR de la gencive, a l'aplomb de la dent —
		// et elle y est noyee de `bury`, sinon la dent se lit comme posee dessus
		// plutot que plantee dedans.
		float w_c = w * pow(max(0.0, 1.0 - ct * ct), sharp);
		float bury = w_c * 0.8;
		float base_y = bulge * (1.0 - ct * ct) - w_c;

		// q.y = 0 a la racine, negatif vers la pointe (l'interieur de la gueule
		// est du cote des y negatifs — l'autre machoire y est).
		// La canine est plus longue ET plus epaisse. Une canine seulement plus
		// longue se lit comme une dent ordinaire qui a glisse, pas comme un croc.
		float w0 = pitch * tooth_width * env * mix(incisor_width, 1.0, bump);

		vec2 q = vec2(p.x - cx, p.y - base_y);
		float u = clamp((bury - q.y) / (len + bury), 0.0, 1.0);
		float r = mix(w0, w0 * tooth_tip, u);

		float a = abs(q.x) - r;
		float b = abs(q.y + (len - bury) * 0.5) - (len + bury) * 0.5;
		teeth = min(teeth, length(vec2(max(a, 0.0), max(b, 0.0))) + min(max(a, b), 0.0));
	}

	return vec2(gum, teeth);
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
	// Et la machoire du bas est decalee d'une demi-dent : c'est l'engrenement.
	//
	// ⚠️ CE DECALAGE DEPLACE AUSSI LA CANINE, et il faut le suivre. La grille du
	// bas est a `n × pas` quand celle du haut est a `(n + 1/2) × pas` : le meme
	// rang de dent n'y tombe donc pas a la meme fraction de corde. Reprendre la
	// position du haut telle quelle ferait tomber la bosse ENTRE deux dents du
	// bas, et la machoire inferieure sortirait avec deux demi-canines au lieu
	// d'un croc. La canine du bas se referme ainsi juste derriere celle du haut,
	// ce qui est la denture reelle d'un chat.
	float pas = 2.0 / max(teeth_count, 1.0);
	float h = hash11(seed * 11.7);
	vec2 up = jaw_fields(
		p, gape * (1.0 + 0.08 * h), jaw_half_width,
		thick, taper, tooth_len, 0.0, (canine_rank + 0.5) * pas, seed
	);
	vec2 lo = jaw_fields(
		vec2(p.x, -p.y), gape * (1.0 - 0.10 * h),
		jaw_half_width * (0.96 + 0.06 * h), thick * 0.90, taper,
		tooth_len * 0.92, 0.5, (canine_rank + 1.0) * pas, seed + 3.0
	);

	float gum = min(up.x, lo.x);
	float teeth = min(up.y, lo.y);
	float d = min(gum, teeth);

	// Le profil effile rend les champs non unitaires pres des pointes : on les
	// renormalise par leur pente pour que la bande d'encre garde partout la meme
	// epaisseur, sinon elle grossit aux pointes et le croc finit en massue.
	vec2 grad = vec2(dFdx(d), dFdy(d)) / ps;
	d /= max(length(grad), 1.0);

	vec2 tgrad = vec2(dFdx(teeth), dFdy(teeth)) / ps;
	float dt = teeth / max(length(tgrad), 1.0);

	vec2 ggrad = vec2(dFdx(gum), dFdy(gum)) / ps;
	float dg = gum / max(length(ggrad), 1.0);

	// Un pixel de lissage, et pas un de plus : de l'antialiasing, pas un degrade.
	float aa = ps * 0.75;
	float alpha = 1.0 - smoothstep(-aa, aa, d);

	if (alpha < 0.01) {
		discard;
	}

	// L'encre suit l'amincissement — fixe, elle mangerait toute la gencive des la
	// 6e pose et la morsure finirait en barre sombre.
	float ink_w = min(ink, thick * 0.55);
	float ink_mask = smoothstep(-ink_w - aa, -ink_w + aa, d);

	// ⚠️ Le champ des dents vaut 1e6 la ou la boucle n'a trouve aucune dent, et
	// sa PENTE y est enorme au raccord : renormaliser 1e6 par une pente enorme
	// rend un petit nombre, qui repeindrait de l'email sur du vide. On teste donc
	// le champ BRUT, pas le champ normalise. La derivee, elle, se calcule
	// toujours — la prendre sous condition est un comportement indefini.
	float enamel = teeth > 0.5 ? 0.0 : 1.0 - smoothstep(-aa, aa, dt);

	// ⚠️ LA RACINE RESTE ROUGE, et sans ca les crocs sortaient en CLOUS. Le trajet
	// de la dent commence a l'interieur de la gencive (`bury`), ou le champ est
	// a son plus large et ou la boite qui le borne se termine A PLAT. La
	// silhouette n'en montrait rien — l'union avec la gencive la recouvre — mais
	// l'email, lui, se peignait dessus : on voyait une tete plate et large suivie
	// d'une tige fine, soit exactement un clou.
	//
	// L'email est donc borne a la partie EMERGEE. Ce n'est pas un correctif de
	// dessin, c'est ce que fait une dent : sa racine appartient a la gencive.
	enamel *= smoothstep(-aa, aa, dg);

	vec3 col = mix(fill_color.rgb, tooth_color.rgb, enamel);
	ALBEDO = mix(col, ink_color.rgb, ink_mask);
	ALPHA = alpha;
}
