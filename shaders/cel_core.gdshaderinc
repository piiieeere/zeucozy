// Fonctions partagees par cel_toon.gdshader et cel_face.gdshader.
// Aucune uniform ici : uniquement des fonctions pures, pour que les deux
// shaders gardent leurs propres reglages sans se marcher dessus.

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// L'ombre n'est JAMAIS un gris multiplie : on decale la teinte vers l'orange,
// on sature un peu et on assombrit. Voir "Convention Blender" §5.1.
vec3 warm_shadow(vec3 base, float hue_shift, float saturation, float value) {
	vec3 hsv = rgb2hsv(base);
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
	hsv.z = hsv.z * value;
	return hsv2rgb(hsv);
}

float hash_noise(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// --- SDF 2D, pour dessiner les details du visage ------------------------------

// Distance signee approchee a une ellipse (suffisant a notre echelle).
float sd_ellipse(vec2 p, vec2 r) {
	return (length(p / r) - 1.0) * min(r.x, r.y);
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Triangle isocele pointe en bas, pour le nez.
float sd_nose(vec2 p, float size) {
	p.y = -p.y;
	float d = max(abs(p.x) * 0.866 + p.y * 0.5, -p.y);
	return d - size;
}
