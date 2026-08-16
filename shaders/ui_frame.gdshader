shader_type canvas_item;

// Plaque de carton : fond sombre, filet d'encre, coins COUPES.
//
// "Visual Art Direction" §9. Reserve aux MOMENTS (niveau, K.O.) et aux jauges —
// le HUD permanent ne pose aucune plaque (§9.2), il se detache par le cerne de
// son texte.
//
// Le coin coupe plutot qu'arrondi n'est pas un detail : un rayon de 18 px est
// la signature d'une pop-up de 2015, un coin coupe celle d'une incrustation de
// diffusion d'epoque. C'est le seul geste de forme qui date l'interface.
//
// Pourquoi un shader et pas un StyleBoxFlat : StyleBoxFlat sait arrondir, pas
// chanfreiner. Et le volet d'entree (`reveal`) doit COUPER la plaque, ce qu'un
// `scale` de Control ne fait pas — il l'ecrase.

uniform vec4 plate_color : source_color = vec4(0.141, 0.102, 0.067, 0.92);
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);
uniform float border_px = 2.0;
uniform float chamfer_px = 12.0;

// Volet d'entree, pilote EN PAS depuis le GDScript (§9.3 regle 4). Il ouvre
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
	// resolution du layout : les chanfreins sortaient 3 a 4 fois trop gros, et
	// d'un facteur DIFFERENT par plaque — ce qui rendait le defaut illisible,
	// puisqu'aucune plaque n'etait juste pour servir de temoin.
	vec2 rect_size = 1.0 / max(fwidth(UV), vec2(1e-6));

	vec2 p = UV * rect_size;

	// Distance aux deux bords les plus proches, en x et en y.
	vec2 d = min(p, rect_size - p);

	// Le polygone chanfreine tient en deux distances : les bords droits, et la
	// diagonale du coin. Les prendre au minimum donne la distance signee au
	// bord reel — chanfrein compris, sans cas particulier par coin.
	float straight = min(d.x, d.y);
	float diagonal = d.x + d.y - chamfer_px;
	float dist = min(straight, diagonal);

	// -1.0 et non 0.0 : on garde une bande d'un pixel pour l'antialiasing. Sans
	// elle la diagonale du chanfrein sort en escalier, ce qui la ferait lire
	// comme un defaut de rendu et non comme un coin coupe.
	if (dist < -1.0) {
		discard;
	}

	float half_w = rect_size.x * 0.5;
	if (abs(p.x - half_w) > half_w * reveal) {
		discard;
	}

	vec4 col = mix(plate_color, ink_color, 1.0 - smoothstep(border_px - 1.0, border_px, dist));
	col.a *= smoothstep(-1.0, 0.0, dist);
	COLOR = col;
}
