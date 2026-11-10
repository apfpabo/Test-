// A column of water thrown up by a shell or a depth charge, seen from above, drawn on one quad.
// COLOR carries the burst: r = progress 0..1, g = seed, b = 1 for a depth charge. The quad spans four radii each way.
shader_type canvas_item;
uniform vec2 sun = vec2(0.54, 0.84);     // the way shadows fall, in canvas space
uniform float night = 0.0;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.1 + vec2(1.7, 9.2); a *= 0.5; } return v; }
// angular noise that joins up round the circle
float ring_noise(float ang, float freq, float seed) { return noise(vec2(cos(ang), sin(ang)) * freq + seed); }
void over(inout vec4 dst, vec3 c, float a) { a = clamp(a, 0.0, 1.0); dst.rgb = mix(dst.rgb, c, a / max(0.0001, dst.a + a * (1.0 - dst.a))); dst.a = dst.a + a * (1.0 - dst.a); }
void fragment() {
	float k = COLOR.r, seed = COLOR.g * 37.0, deep = step(0.5, COLOR.b);
	float big = COLOR.a;   // 0 when the burst is only a few pixels across: then its rings and crown would read as stray little circles, so only the column is drawn
	vec2 p = (UV * 2.0 - 1.0) * 4.0;                 // in radii
	float r = length(p), ang = atan(p.y, p.x);
	// a shell punches the sea down first: for the first tenth there is only the hollow, then the column climbs out of it
	float kb = mix(max(0.0, (k - 0.1) / 0.9), k, deep);
	float rise = sin(min(1.0, kb / mix(0.22, 0.3, deep)) * 1.5708);
	float fall = smoothstep(0.3, 1.0, kb), up = rise * (1.0 - fall), a0 = 1.0 - k;
	float hgt = mix(3.0, 1.7, deep) * up;            // how high it stands, in radii
	vec4 o = vec4(0.0);
	// the shock of a depth charge whitens the surface in a disc
	if (deep > 0.5 && k < 0.2) over(o, vec3(0.86, 0.95, 0.95), (1.0 - smoothstep(0.7, 1.0, r / (1.0 + 9.0 * k))) * 0.6 * (1.0 - k / 0.2));
	// the hollow: a bowl in the sea, dark in its depth, its far wall catching the light, a bright lip running out
	if (deep < 0.5 && k < 0.34) {
		float kc = k / 0.34, rb = 0.45 + 1.5 * sqrt(kc), dn = r / rb;
		float bowl = (1.0 - smoothstep(0.75, 1.0, dn)) * (1.0 - kc * kc);
		over(o, vec3(0.0, 0.035, 0.06), bowl * (0.5 + 0.35 * (1.0 - dn)) * big);
		float wall = smoothstep(0.35, 0.95, dn) * (1.0 - smoothstep(0.95, 1.05, dn)) * clamp(dot(normalize(p + 0.0001), -sun) * 0.9 + 0.1, 0.0, 1.0);
		over(o, vec3(0.45, 0.7, 0.74), wall * 0.55 * (1.0 - kc) * big);
		float lip = 1.0 - smoothstep(0.0, 0.09, abs(dn - 1.03));
		over(o, vec3(0.9, 0.97, 0.97), lip * 0.6 * (1.0 - kc) * big);
	}
	// churned water, darker, mottled
	float churn = 1.0 - smoothstep(0.5, 1.0, r / (0.9 + 1.4 * k));
	over(o, vec3(0.03, 0.12, 0.15), churn * (0.35 + 0.25 * fbm(p * 3.0 + seed)) * a0);
	// rings running out across the sea: thin, a little broken
	for (int i = 0; i < 3; i++) {
		float rr = 0.5 + k * mix(2.4, 3.1, deep) + float(i) * 0.42;
		float band = 1.0 - smoothstep(0.0, 0.07, abs(r - rr));
		over(o, vec3(0.86, 0.95, 0.95), big * band * 0.45 * a0 * a0 * (1.0 - float(i) * 0.28) * (0.6 + 0.4 * ring_noise(ang, 5.0, seed + float(i))) * step(rr, 3.9));
	}
	// the column's shadow, thrown across the water
	if (hgt > 0.05) {
		vec2 q = p - sun * hgt * 0.5; vec2 al = vec2(dot(q, sun), dot(q, vec2(-sun.y, sun.x)));
		float sh = 1.0 - smoothstep(0.6, 1.0, length(al / vec2(0.5 + hgt * 0.5, 0.5 + 0.15 * rise)));
		over(o, vec3(0.0, 0.03, 0.05), sh * 0.5 * up);
	}
	// spray: fingers of water flung out radially from the crown, each its own length
	float rc = 0.5 + 0.8 * sqrt(kb);
	float fing = ring_noise(ang, 13.0, seed * 1.7); float fine = ring_noise(ang, 44.0, seed * 3.1);
	float flen = (0.15 + 0.95 * fing * fing * fing) * (0.4 + 0.6 * rise);
	float streak = smoothstep(0.58, 0.72, fing * 0.5 + fine * 0.5) * step(rc, r) * (1.0 - smoothstep(0.0, flen, r - rc));
	over(o, vec3(0.95, 0.99, 0.99), streak * 0.7 * pow(a0, 1.5) * min(1.0, kb * 12.0));
	// the crown of foam at its foot: a jagged white ring, sharp inside, feathered outside
	float jag = rc * (1.0 + 0.16 * (ring_noise(ang, 12.0, seed) - 0.5) + 0.1 * (fine - 0.5));
	float crown = smoothstep(jag - 0.16, jag - 0.04, r) * (1.0 - smoothstep(jag, jag + 0.22, r));
	over(o, vec3(1.0), big * crown * (0.55 + 0.45 * fbm(p * 7.0 + seed)) * a0 * min(1.0, kb * 12.0));
	// the column from above: a boiling head, bright where the sun strikes it and grey-blue on the far side
	float rt = (0.4 + 0.42 * rise) * (1.0 + 0.5 * fall);
	vec2 hp = p + sun * hgt * 0.1;                    // the head stands towards the light
	float edge = rt * (0.7 + 0.6 * fbm(vec2(atan(hp.y, hp.x) * 2.2, length(hp) * 2.0) + seed + k * 1.5));
	float body = (1.0 - smoothstep(edge * 0.82, edge, length(hp))) * pow(1.0 - fall, 1.2) * min(1.0, kb * 16.0);
	float tur = fbm(hp * 5.0 + seed + vec2(k * 2.0, 0.0));
	float lit = clamp(0.62 - dot(normalize(hp + 0.0001), sun) * 0.34 * smoothstep(0.1, 0.9, length(hp) / rt) + (tur - 0.5) * 0.5, 0.0, 1.0);
	vec3 wc = mix(vec3(0.42, 0.55, 0.62), vec3(1.0), lit);
	over(o, wc, body * (0.75 + 0.25 * tur));
	// mist drifting as it falls back, in torn patches
	float mist = (1.0 - smoothstep(0.4, 1.0, r / (1.0 + 2.2 * fall))) * smoothstep(0.35, 0.7, fbm(p * 1.8 + seed + k)) * fall * a0 * 1.6;
	over(o, vec3(0.9, 0.96, 0.96), mist * 0.5);
	o.rgb *= mix(1.0, 0.5, night);
	o.a *= 1.0 - smoothstep(3.6, 4.0, r);
	COLOR = o;
}
