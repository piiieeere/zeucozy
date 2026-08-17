// Fonctions partagees par cel_ground.gdshader et cel_rug.gdshader.
//
// Meme regle que cel_core : aucune uniform ici, uniquement des fonctions
// pures. Ce qui compte, c'est que le sol et les tapis evaluent EXACTEMENT la
// meme flaque de lumiere — sinon le bord de la flaque saute au passage d'un
// tapis, et on voit le decoupage geometrique que tout le style existe pour
// cacher.

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.x, p.y, p.x) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Bruit de valeur. Sert de CHAMP, jamais de couleur : on le seuille toujours
// pour retrouver un bord franc (§2bis — aucun degrade lisse).
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Seuil franc a l'ecran : la transition ne fait jamais plus d'un pixel, quelle
// que soit la distance. Un aplat franc en vue plongeante aliase sans ca.
float franc_edge(float field, float level) {
	float w = fwidth(field) * 0.7 + 1e-6;
	return smoothstep(level - w, level + w, field);
}

// Trait d'encre : coverage d'une ligne dont `d` est la distance en metres.
//
// Deux termes. Le premier antialiase le bord. Le second ETEINT la ligne quand
// elle devient plus fine qu'un pixel — au fond du cadre, les joints du parquet
// se croisent a quelques pixels d'intervalle et produiraient un moire. Un fond
// d'anime simplifie de la meme facon a distance : c'est le bon comportement,
// pas un pis-aller.
float ink_line(float d, float width) {
	float aa = fwidth(d) + 1e-6;
	float line = 1.0 - smoothstep(width - aa, width + aa, d);
	return line * (1.0 - smoothstep(width * 1.5, width * 5.0, aa));
}

// ─── CE QUI SUIT N'EST PLUS APPELE DEPUIS LE 2026-08-17 ───
//
// La flaque de lumiere a ete retiree du sol et des tapis : ancree au monde,
// elle defilait en diagonale sur toute la largeur du cadre des que le chat
// marchait, et se lisait comme un artefact d'affichage plutot que comme du
// soleil. Motif complet et reglages d'alors : en tete de `cel_ground.gdshader`.
//
// ⚠️ ELLE RESTE ICI, ET C'EST LA RAISON D'ETRE DE CE FICHIER. Si la lumiere
// peinte revient un jour, elle doit revenir A UN SEUL ENDROIT, partage par le
// sol et les tapis — sinon leur bord commun se remet a sauter. Deux
// reimplementations divergentes sont le defaut que cet include existe pour
// empecher ; la supprimer, c'est les garantir.

// Direction des rais de lumiere — 30°, jamais l'axe du parquet. Un rai qui
// suivrait les lames se confondrait avec elles.
const vec2 SUN_DIR = vec2(0.866, 0.5);

// Flaque de lumiere — la seule "ombre" d'un sol plat.
//
// Un sol horizontal a une normale constante : aucun eclairage ne peut y creer
// de cluster. La lumiere y est donc entierement DESSINEE (§2ter·2), comme la
// tache de soleil peinte d'un fond d'anime.
//
// ⚠️ Le champ est ANISOTROPE, et ce n'est pas un detail. Premier essai fait
// avec un bruit isotrope : les flaques sortaient en amibes, et une amibe plus
// claire sur un parquet ne se lit pas comme du soleil, elle se lit comme une
// tache. Etire dans le sens du soleil et resserre en travers, le meme bruit
// donne des RAIS — l'image d'interieur d'anime qu'on cherche.
//
// Le champ basse frequence donne la forme, le haute frequence lui donne un
// bord de pinceau irregulier.
float light_pool(vec2 p, float scale, float level, float wobble) {
	vec2 r = vec2(dot(p, SUN_DIR), dot(p, vec2(-SUN_DIR.y, SUN_DIR.x)));
	float field = vnoise(vec2(r.x / (scale * 2.2), r.y / (scale * 0.45)));
	field += (vnoise(p / (scale * 0.16)) - 0.5) * wobble;
	return franc_edge(field, level);
}
