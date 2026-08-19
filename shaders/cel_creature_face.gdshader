// Visage peint des CREATURES SANS SQUELETTE — yeux et truffe
//
// Meme base cel que cel_toon.gdshader, plus les details du visage DESSINES sur
// la surface. C'est la regle de "Visual Art Direction" §2bis, appliquee cette
// fois sans entorse : des yeux en geometrie debordent de la silhouette vue de
// profil, et le chien comme la souris les avaient en lentilles modelisees.
//
// Les details vivent dans un espace facial projete : on ramene la position
// objet a une direction sur l'ellipsoide de la tete, et on garde (x, y) comme
// coordonnees 2D. |x| avant le calcul : un seul jeu de formes dessine les deux
// cotes.
//
// ─── CE QU'IL NE FAIT PAS, ET C'EST LA MOITIE DU FICHIER QUI DISPARAIT ───────
//
// ⚠️ AUCUN `rest_undo`, ET CE N'EST PAS UN OUBLI. cel_face.gdshader porte trois
// uniforms de skinning et tout un protocole de mise a jour par frame parce que
// Godot applique le skinning AVANT vertex() (piege n°5) : sur le chat, VERTEX
// arrive deja deforme et un masque calcule dessus GLISSE des qu'un os bouge.
// Une creature sans squelette n'a rien qui glisse — `VERTEX` en espace objet
// EST la position de repos. C'est la partie la plus couteuse de cel_face, et
// elle ne s'applique tout simplement pas ici.
//
// ⚠️ ET AUCUNE EXPRESSION. Pas d'iris, pas de pupille, pas de reflet, pas de
// bouche, pas de moustaches : un oeil est ici UNE ELLIPSE D'ENCRE, exactement
// ce que la lentille modelisee rendait. Le visage qui JOUE (§6.3, §17) reste
// reserve au chat — et aux boss, le jour ou il y en aura. Un ennemi qu'on croise
// par cinq et qu'on lit a ~4 px d'oeil n'a rien a exprimer, et lui en donner les
// moyens reviendrait a payer des uniforms animes que personne ne verrait.
//
// ─── L'AVANT EST −Z, CONTRAIREMENT AU CHAT ──────────────────────────────────
//
// cel_face.gdshader dit "l'avant du chat est +Z apres conversion Y-up du glTF",
// d'ou le `yaw_offset_deg = 180` de cel_model.gd. Les creatures, elles, sont
// construites museau vers +Y dans Blender, et la conversion glTF envoie
// Blender +Y sur glTF −Z : leur avant est donc DEJA celui de Godot, aucun
// offset de lacet nulle part. Le repere facial est ecrit pour −Z en dur —
// un uniform de direction inviterait a poser un +Z qui ne correspondrait a
// aucun modele du dossier.

shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, specular_disabled;

group_uniforms couleur;
uniform vec4 base_color : source_color = vec4(0.541, 0.353, 0.220, 1.0);

// Le ton d'ombre n'est jamais saisi a la main : il est derive de la couleur
// locale par decalage TSV. C'est ce qui rend impossible le gris multiplie.
uniform float shadow_hue_shift : hint_range(-0.2, 0.2) = -0.02;
uniform float shadow_saturation : hint_range(0.5, 2.0) = 1.15;
uniform float shadow_value : hint_range(0.1, 1.0) = 0.65;

group_uniforms lumiere;
uniform vec3 light_dir = vec3(-0.35, 0.85, 0.4);
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;

group_uniforms attr_style;
uniform bool use_vertex_style = false;
uniform float shadow_bias_strength : hint_range(0.0, 2.0) = 1.0;

group_uniforms accent;
uniform vec4 accent_color : source_color = vec4(0.961, 0.925, 0.847, 1.0);
uniform float accent_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float accent_strength : hint_range(0.0, 1.0) = 0.0;

group_uniforms grain;
uniform float edge_noise : hint_range(0.0, 0.3) = 0.0;
uniform float edge_noise_scale : hint_range(1.0, 200.0) = 35.0;

group_uniforms repere_visage;
// Centre et demi-axes de la tete, en espace objet. Ce n'est pas la boite
// englobante du crane : c'est l'ellipsoide sur lequel on PROJETTE, et son seul
// role est de rendre le mapping stable. Les valeurs vivent dans `FACES`, dans
// cel_prop.gd.
uniform vec3 face_center = vec3(0.0, 1.0, -0.45);
uniform vec3 face_radius = vec3(0.42, 0.40, 0.42);
// Cone du visage. Plus la valeur est haute, plus le visage cesse tot quand la
// tete se detourne. Il doit rester SOUS la portee du detail le plus excentre
// (l'oeil) pour ne jamais le couper en deux, et AU-DESSUS de ce que la
// machoire projette, sinon la truffe se repeint sous le menton.
uniform float face_front_min : hint_range(-1.0, 1.0) = 0.15;
// Bascule du repere vers le haut. La camera plonge a 45° : un visage
// strictement frontal passe sous l'horizon et on ne voit que le crane. C'est du
// cadrage, pas de l'anatomie.
uniform float face_pitch_deg : hint_range(0.0, 80.0) = 26.0;

group_uniforms traits;
// Une seule encre pour tout le visage. §4 la donne : `#3D2B1A`, le contour
// principal. C'est EXACTEMENT la couleur que portaient les coques d'oeil et de
// truffe qu'on retire — le remplacement ne deplace aucune couleur.
uniform vec4 ink_color : source_color = vec4(0.239, 0.169, 0.102, 1.0);

group_uniforms yeux;
uniform vec2 eye_pos = vec2(0.40, 0.20);
uniform vec2 eye_size = vec2(0.13, 0.15);

group_uniforms truffe;
// A ZERO, la truffe n'est pas dessinee. C'est le cas de la souris, dont le bout
// de museau est une ZONE DE MATIERE rose sur le maillage — donc deja de la
// peinture, pas de la geometrie, donc rien a reprendre ici.
//
// ⚠️ UNE ELLIPSE, ET SURTOUT PAS `sd_nose()`. Le premier jet reprenait le nez du
// chat, qui est un triangle isocele pointe en bas — juste sur un petit museau de
// chat, et illisible sur le gros chanfrein d'un chien : la pointe se lisait
// comme une ENTAILLE, ou comme une gueule ouverte de face. Une truffe de chien
// est un bouton large et rond, ce qu'etait d'ailleurs la coque qu'on remplace :
// le dessin doit rendre ce que la geometrie rendait, pas autre chose.
uniform vec2 nose_pos = vec2(0.0, -0.34);
uniform vec2 nose_size = vec2(0.0);

varying vec3 v_style;
varying vec3 v_object_pos;

#include "res://shaders/cel_core.gdshaderinc"

// Pose un aplat franc si la distance signee passe sous zero.
// `aa` est une DEMI-BANDE en unites d'espace facial, mesuree a l'ecran par
// fragment() — voir la note sur `ps` la-bas. Elle est passee en parametre et
// non lue dans un uniform : une derivee ne se calcule qu'a un seul endroit,
// hors de tout branchement.
vec3 paint(vec3 under, float dist, float aa, vec3 col) {
	return mix(col, under, smoothstep(-aa, aa, dist));
}

void vertex() {
	v_style = COLOR.rgb;
	v_object_pos = VERTEX;
}

void fragment() {
	// NORMAL est en espace vue dans fragment() : on repasse en monde pour
	// pouvoir la comparer a une direction de lumiere monde.
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Le biais peint : l'ombre est une forme decidee, pas un calcul (§2ter·2)
	float bias = 0.0;
	if (use_vertex_style) {
		bias = (v_style.g - 0.5) * 2.0 * shadow_bias_strength;
	}

	// Bord de cluster legerement irregulier — un bord de pinceau (§2ter·3)
	float jitter = 0.0;
	if (edge_noise > 0.0) {
		jitter = (hash_noise(floor(v_object_pos * edge_noise_scale)) - 0.5) * edge_noise;
	}

	float lit = step(threshold - bias + jitter, dot(n, normalize(light_dir)));

	vec3 local = base_color.rgb;
	vec3 shadow_col = warm_shadow(local, shadow_hue_shift, shadow_saturation, shadow_value);
	vec3 col = mix(shadow_col, local, lit);

	// Accent de brillance — seulement dans le ton clair : un accent pose dans
	// l'ombre se lirait comme une erreur de cluster.
	if (use_vertex_style && accent_strength > 0.0) {
		col = mix(col, accent_color.rgb, step(accent_threshold, v_style.b) * lit * accent_strength);
	}

	// --- espace facial ---------------------------------------------------
	vec3 dir = normalize((v_object_pos - face_center) / face_radius);

	float fp = radians(face_pitch_deg);
	vec3 f_fwd = vec3(0.0, sin(fp), -cos(fp));   // ou "regarde" le visage — voir l'en-tete
	vec3 f_up = vec3(0.0, cos(fp), sin(fp));
	vec3 f_right = vec3(1.0, 0.0, 0.0);

	bool in_face = dot(dir, f_fwd) > face_front_min;
	vec2 uv_signed = vec2(dot(dir, f_right), dot(dir, f_up));
	// |x| : les deux cotes d'un coup
	vec2 uv = vec2(abs(uv_signed.x), uv_signed.y);

	// UN PIXEL, EN UNITES D'ESPACE FACIAL. Meme geste que cel_face et que les
	// six shaders de FX : un pixel de lissage, et pas un de plus — c'est de
	// l'antialiasing, pas un degrade (§2bis interdit les seconds, pas le
	// premier). Une valeur FIXE serait juste au banc et inerte en jeu : c'est
	// le defaut mesure sur le visage du chat, un facteur 10 entre les deux.
	//
	// ⚠️ Derivees prises sur les coordonnees SIGNEES. `uv.x` passe par abs() :
	// sa derivee exploserait sur la colonne de pixels de l'axe de symetrie,
	// pile la ou passe la truffe.
	//
	// ⚠️ Et calculees ICI, hors de `if (in_face)`. Une derivee dans un
	// branchement non uniforme est indefinie en GLSL : les pixels voisins du
	// quad n'ont pas forcement pris la meme branche.
	float ps = max(max(fwidth(uv_signed.x), fwidth(uv_signed.y)), 1e-6);
	float aa = ps * 0.75;

	if (in_face) {
		if (nose_size.x > 0.0) {
			col = paint(col, sd_ellipse(uv - nose_pos, nose_size), aa, ink_color.rgb);
		}

		col = paint(col, sd_ellipse(uv - eye_pos, eye_size), aa, ink_color.rgb);
	}

	ALBEDO = col;
}
