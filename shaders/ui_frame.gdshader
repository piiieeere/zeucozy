shader_type canvas_item;

// Plaque de carton : aplat OPAQUE, filet fin, ANGLES DROITS + reperes d'angle.
//
// "Visual Art Direction" §9, v3 (2026-08-17) — la reference d'interface est
// passee d'Orbitals a Cowboy Bebop + Evangelion. Deux choses ont change ici :
//
//   • LE COIN COUPE A DISPARU. Le chanfrein venait d'Orbitals ; Bebop et Eva
//     sont carres SANS EXCEPTION. Mais un angle droit nu retombe exactement sur
//     le rectangle de logiciel que le chanfrein existait pour eviter — d'ou les
//     REPERES D'ANGLE qui le remplacent : deux traits courts formant un L
//     rentre, poses en retrait de chaque coin. C'est le geste de cartouche
//     technique d'Eva, et il date l'image aussi surement que le chanfrein.
//   • L'ALPHA PAR DEFAUT EST 1.0, et non 0.92. §9.3 regle 3 : un aplat d'UI est
//     opaque ou n'existe pas. La seule translucidite qui subsiste dans toute
//     l'interface est le VOILE derriere un carton, et il assombrit l'image au
//     lieu de la teinter.
//
// Pourquoi un shader et pas un StyleBoxFlat : le volet d'entree (`reveal`) doit
// COUPER la plaque, ce qu'un `scale` de Control ne fait pas — il l'ecrase. Et
// les reperes d'angle ne sont dans aucun StyleBox.
//
// ─── LE RELIEF, 2026-08-17 ───
//
// Les cartes n'avaient aucune epaisseur : trois aplats poses sur un aplat. Le
// relief se fait ici en TROIS bandes de valeur A BORD FRANC, jamais en degrade —
// §9.1 regle 2 l'interdit, et c'est aussi ce qu'est un objet peint en cellulo :
//
//   1. BISEAU — une bande claire en haut/gauche, une sombre en bas/droite,
//      juste a l'interieur du filet. C'est l'epaisseur du BORD.
//   2. FACETTE — la face de la plaque coupee en deux valeurs, la haute plus
//      claire. C'est la MASSE, et c'est elle qui porte le volume : 2 px de
//      biseau sur une carte de 168 px ne font qu'un liseré.
//   3. OMBRE PORTEE — decalee, DURE, sans flou. Elle detache la carte de ce
//      qu'elle recouvre ; c'est la seule chose qui dise "posee dessus".
//
// ⚠️ LE PARTAGE DES DEUX PREMIERES N'EST PAS COSMETIQUE. La facette seule donne
// une plaque de carton peinte en deux tons ; le biseau seul donne un cadre. Les
// deux ensemble donnent une piece MOULEE — c'est exactement le cluster 2 tons de
// §2bis, applique a l'UI au lieu du chat.
//
// ⚠️ LE FILET RESTE AU-DESSUS DE TOUT. Le biseau se pose a l'INTERIEUR de lui,
// pas a sa place : sans filet, les bandes claires deviennent le contour et la
// plaque perd le trait qui la finit.
//
// ⚠️ L'OMBRE RETRECIT LA PLAQUE, elle ne deborde pas du ColorRect. Un Control ne
// peut pas peindre hors de son rectangle : la plaque occupe donc `rect - shadow`
// et l'ombre remplit la bande liberee. Consequence a connaitre — activer
// `shadow_px` fait perdre 3 px de largeur ET de hauteur au contenu.

uniform vec4 plate_color : source_color = vec4(0.227, 0.227, 0.220, 1.0);

// Le filet, et les reperes d'angle avec lui. Une seule couleur pour les deux :
// c'est ce qui fait que le survol d'une carte (filet ambre) emporte ses reperes
// sans avoir a les recabler separement.
uniform vec4 ink_color : source_color = vec4(0.557, 0.557, 0.533, 1.0);

uniform float border_px = 2.0;

// Repere d'angle. `tick_px` a 0 le supprime — c'est le cas des jauges, ou une
// marque de 10 px sur une piste de 8 px de haut n'aurait aucun sens.
uniform float tick_px = 10.0;
uniform float tick_inset_px = 6.0;
uniform float tick_width_px = 2.0;

// ─── Relief. A zero, la plaque retombe EXACTEMENT sur son dessin d'avant ───
//
// C'est voulu : les jauges du HUD (8 px de haut) et les pastilles de cooldown
// n'en veulent pas. Un biseau de 2 px sur une piste de 8 px la remplirait au
// quart, et une piste de jauge n'est pas un objet pose — elle est CREUSEE dans
// l'image, c'est meme tout ce qu'elle a a dire.

// Epaisseur du biseau, en px, mesuree A PARTIR du filet.
uniform float bevel_px = 0.0;
// Ce que le biseau ajoute et retire a la valeur de la plaque. Le haut gagne plus
// que le bas ne perd : la lumiere du jeu vient d'en haut (§6), une arete eclairee
// claque plus qu'une arete a l'ombre ne s'enfonce.
uniform float bevel_lift = 0.10;
uniform float bevel_drop = 0.075;

// La coupe de la facette, en fraction de la hauteur. A zero, pas de facette.
//
// ⚠️ Elle n'est PAS a 0,5. Une face haute et une face basse egales se lisent
// comme deux rectangles empiles, pas comme un volume : c'est la meme raison qui
// interdit trois griffes identiques dans `claw_slash` ou des dents regulieres
// dans `bite`. La coupe haute donne une petite face de dessus et une grande face
// de devant — la lecture d'un objet vu legerement de haut, ce qui est exactement
// la position de la camera du jeu.
uniform float face_split = 0.0;
uniform float facet_lift = 0.045;
uniform float facet_drop = 0.030;

// L'ombre portee. `shadow_px` a zero la supprime ET rend sa place a la plaque.
uniform float shadow_px = 0.0;
// Le VEIL du projet, #1A1A19. Opaque : §9.3 regle 3 vaut aussi pour une ombre —
// une ombre translucide est une ombre calculee, et rien ici n'est calcule.
uniform vec4 shadow_color : source_color = vec4(0.102, 0.102, 0.098, 1.0);

// Volet d'entree, pilote EN PAS depuis le GDScript (§9.3 regle 8). Il ouvre
// depuis l'axe vertical. 0 = ferme, 1 = ouvert.
uniform float reveal = 1.0;

void fragment() {
	// La taille du rectangle en PIXELS, deduite du shader lui-meme.
	//
	// UV va de 0 a 1 sur toute la largeur : sa derivee par pixel vaut donc
	// 1/largeur, et l'inverse rend la largeur. Un ColorRect n'ayant ni texture
	// ni TEXTURE_PIXEL_SIZE, c'est la seule mesure qui soit toujours juste.
	//
	// ⚠️ Ceci REMPLACE un uniform `rect_size` recable depuis GDScript sur le
	// signal `resized`. Il arrivait en retard ou pas du tout selon l'ordre de
	// resolution du layout : les coins sortaient 3 a 4 fois trop gros, et d'un
	// facteur DIFFERENT par plaque — ce qui rendait le defaut illisible,
	// puisqu'aucune plaque n'etait juste pour servir de temoin.
	vec2 rect_size = 1.0 / max(fwidth(UV), vec2(1e-6));

	vec2 p = UV * rect_size;

	// ⚠️ Le volet se calcule sur le rectangle ENTIER, ombre comprise. Le calculer
	// sur la plaque seule laisserait la colonne d'ombre de droite en dehors du
	// volet : elle serait rabotee des la premiere pose et l'ombre s'ouvrirait
	// avant la plaque qui la projette.
	float half_w = rect_size.x * 0.5;
	if (abs(p.x - half_w) > half_w * reveal) {
		discard;
	}

	// La plaque cede sa marge basse-droite a l'ombre portee. `max` garde la
	// plaque non degeneree si quelqu'un demande une ombre plus grande qu'elle.
	vec2 plate_size = max(rect_size - vec2(shadow_px), vec2(1.0));

	// Hors plaque : soit c'est l'ombre, soit c'est le coin haut-droit / bas-gauche
	// que l'ombre decalee ne couvre pas — et celui-la est du vide.
	//
	// ⚠️ `discard` puis un choix a la fin, JAMAIS un `return` : le langage de
	// shader de Godot refuse `return` dans `fragment()`, et le refus n'est pas
	// silencieux mais sa consequence l'est presque — la plaque retombe sur le
	// shader canvas par defaut, qui rend le `modulate` du ColorRect. Celui-ci
	// etant blanc, TOUTE l'interface est sortie en blanc pur, cartons compris.
	bool outside = p.x > plate_size.x || p.y > plate_size.y;
	bool in_shadow = shadow_px > 0.0 && p.x >= shadow_px && p.y >= shadow_px;

	if (outside && !in_shadow) {
		discard;
	}

	// Distance aux deux bords les plus proches, en x et en y. Le rectangle est
	// droit : le minimum des deux EST la distance au bord, sans cas particulier
	// par coin — c'est ce que le chanfrein obligeait a corriger.
	vec2 d = min(p, plate_size - p);
	float dist = min(d.x, d.y);

	vec3 body = plate_color.rgb;

	// 1. LA FACETTE — la masse. Coupe FRANCHE, `step` et non `smoothstep` : un
	// cluster 2 tons se lit a son BORD (§2bis), etale il n'y a plus deux tons.
	if (face_split > 0.0) {
		body += mix(facet_lift, -facet_drop, step(face_split * plate_size.y, p.y));
	}

	// 2. LE BISEAU — l'epaisseur du bord, posee JUSTE A L'INTERIEUR du filet.
	if (bevel_px > 0.0) {
		float b0 = border_px;
		float b1 = border_px + bevel_px;

		float lit = max(
			step(b0, p.y) * (1.0 - step(b1, p.y)),
			step(b0, p.x) * (1.0 - step(b1, p.x))
		);
		float shade = max(
			step(b0, plate_size.y - p.y) * (1.0 - step(b1, plate_size.y - p.y)),
			step(b0, plate_size.x - p.x) * (1.0 - step(b1, plate_size.x - p.x))
		);

		// Aux deux coins ou les bandes se croisent (haut-droit, bas-gauche), la
		// bande CLAIRE gagne. Ce n'est pas un arbitrage esthetique : une arete
		// eclairee passe devant une arete d'ombre sur un objet reel, et laisser
		// les deux se melanger rendrait un gris moyen — donc un coin arrondi
		// peint, exactement ce que §9.3 regle 6 interdit.
		body += bevel_lift * lit - bevel_drop * shade * (1.0 - lit);
	}

	// 3. LE FILET, par-dessus tout le reste. Il finit la plaque ; le biseau ne le
	// remplace pas, il se range dessous.
	vec4 col = mix(
		vec4(body, plate_color.a),
		ink_color,
		1.0 - smoothstep(border_px - 1.0, border_px, dist)
	);

	// Les reperes d'angle. `d` etant deja replie sur les quatre quadrants, un
	// seul test les pose aux quatre coins a la fois.
	//
	// Le bras horizontal court a la hauteur `tick_inset_px`, de `tick_inset_px`
	// a `tick_inset_px + tick_px` ; le bras vertical est son symetrique. Leur
	// angle tombe donc vers l'INTERIEUR de la plaque — un L rentre, et non un
	// coin redouble qui se lirait comme un cadre rate.
	if (tick_px > 0.0) {
		float half_t = tick_width_px * 0.5;

		float arm_h = (1.0 - smoothstep(half_t - 0.5, half_t + 0.5, abs(d.y - tick_inset_px)))
			* step(tick_inset_px, d.x)
			* (1.0 - step(tick_inset_px + tick_px, d.x));

		float arm_v = (1.0 - smoothstep(half_t - 0.5, half_t + 0.5, abs(d.x - tick_inset_px)))
			* step(tick_inset_px, d.y)
			* (1.0 - step(tick_inset_px + tick_px, d.y));

		col = mix(col, ink_color, clamp(arm_h + arm_v, 0.0, 1.0));
	}

	// Le corps de plaque a ete calcule meme dans la bande d'ombre — il n'y coute
	// rien et il n'y a rien a garder : les seuls fragments qui arrivent ici avec
	// `outside` vrai sont dans l'ombre, les autres ont deja ete jetes.
	COLOR = outside ? shadow_color : col;
}
