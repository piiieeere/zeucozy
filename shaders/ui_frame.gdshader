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

	// Distance aux deux bords les plus proches, en x et en y. Le rectangle est
	// droit : le minimum des deux EST la distance au bord, sans cas particulier
	// par coin — c'est ce que le chanfrein obligeait a corriger.
	vec2 d = min(p, rect_size - p);
	float dist = min(d.x, d.y);

	float half_w = rect_size.x * 0.5;
	if (abs(p.x - half_w) > half_w * reveal) {
		discard;
	}

	vec4 col = mix(plate_color, ink_color, 1.0 - smoothstep(border_px - 1.0, border_px, dist));

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

	COLOR = col;
}
