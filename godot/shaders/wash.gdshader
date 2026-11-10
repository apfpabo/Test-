// What a shell leaves on the sea after the column has fallen back, seen from above, drawn on one quad: a patch of
// foam that breaks into cells and wastes away, paler aerated water under it, and a trough running out across the
// sea with a thin broken crest (owner's request, 10 Nov 2026). COLOR carries it: r = age 0..1, g = seed.
// The quad spans four radii each way.
shader_type canvas_item;
uniform float night = 0.0;
uniform vec2 sun = vec2(0.54, 0.84);     // the way shadows fall, in canvas space
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 3; i++) { v += a * noise(p); p = p * 2.1 + vec2(1.7, 9.2); a *= 0.5; } return v; }
// cells: nought along the seams between them and rising towards the middle of each, like foam breaking up
float cells(vec2 p) {
	vec2 i = floor(p), f = fract(p); float d = 1.0, d2 = 1.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y)); vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
		float l = length(g + o - f);
		if (l < d) { d2 = d; d = l; } else if (l < d2) d2 = l;
	}
	return d2 - d;
}
void over(inout vec4 dst, vec3 c, float a) { a = clamp(a, 0.0, 1.0); dst.rgb = mix(dst.rgb, c, a / max(0.0001, dst.a + a * (1.0 - dst.a))); dst.a = dst.a + a * (1.0 - dst.a); }
// A ripple standing on the sea, in relief: the face turned to the light is bright, the face turned away is dark, so
// it reads as a raised ring and not a line (owner's request). `d` is the distance from its crest in radii, `w` its
// width, `dir` the way out from the centre; returns light (positive) or shade (negative).
float relief(float d, float w, vec2 dir, vec2 lightdir) {
	float bump = exp(-d * d / (w * w));
	float slope = -2.0 * d / w * bump;               // falling away outside the crest, rising to it inside
	return slope * dot(dir, lightdir);
}
// The blast of a gun on the sea beside the ship (COLOR.b = 1; the quad is turned so +x is the line of fire and spans
// two radii each way): the shock front racing out in a fan, the water beaten flat and ruffled behind it in fine
// ripples and radial streaks, a darker hollow under the muzzle, and spray torn off the surface close in.
vec4 blast(vec2 uv, float k, float seed, float big, vec2 lightdir) {
	vec2 p = (uv * 2.0 - 1.0) * 2.0; float r = length(p), ang = atan(p.y, p.x);
	float a0 = 1.0 - k; vec4 o = vec4(0.0);
	float fan = (1.0 - smoothstep(0.55, 1.4, abs(ang) + 0.25 * (noise(vec2(r * 4.0, seed)) - 0.5))) * smoothstep(0.02, 0.2, r);       // a fan some 60 degrees either side
	float rs = 0.22 + 1.6 * (1.0 - exp(-k * 4.5));                                           // the front
	float inside = 1.0 - smoothstep(rs - 0.04, rs + 0.02, r);
	float an = noise(vec2(ang * 9.0, seed)) * 0.6 + noise(vec2(ang * 23.0, seed + 5.0)) * 0.4;
	// the hollow pressed into the sea under the muzzle, first and briefly
	over(o, vec3(0.0, 0.04, 0.07), fan * inside * (1.0 - smoothstep(0.0, 0.9, r / rs)) * 0.55 * pow(a0, 3.0) * big);
	// beaten water: paler, in fine ripples that run out with the front, streaked along the blast
	float rip = 0.5 + 0.5 * sin((r - rs) * 27.0 + an * 3.0 + fbm(p * 3.5 + seed) * 7.0);   // ripples, pulled out of true so they are not rings on a dial
	float streak = smoothstep(0.3, 0.9, noise(vec2(ang * 9.0 + seed, r * 1.6 - k * 3.0)) * 0.7 + noise(vec2(ang * 21.0 + seed, r * 3.0)) * 0.3);
	float body = fan * inside * smoothstep(0.1, 0.45, r) * (0.35 + 0.65 * smoothstep(0.0, 1.0, r / rs));
	over(o, vec3(0.62, 0.8, 0.83), body * (0.14 + 0.16 * rip * rip * (0.4 + 0.6 * streak) + 0.22 * streak) * pow(a0, 1.3) * big);
	// spray torn off close in, in flecks
	float fl = smoothstep(0.62, 0.8, fbm(p * 9.0 + seed + vec2(k * 2.0, 0.0))) * fan * (1.0 - smoothstep(0.2, 0.2 + rs * 0.7, r));
	over(o, vec3(0.95, 0.98, 0.98), fl * 0.8 * pow(a0, 2.0));
	// the front itself: a thin bright arc, broken, with a fainter one behind it
	vec2 dir = p / max(r, 0.001);
	for (int i = 0; i < 2; i++) {
		float rl = relief(r - rs * (1.0 - 0.28 * float(i)), 0.07, dir, lightdir) * fan * (0.5 + 0.5 * an) * (1.0 - 0.5 * float(i));
		over(o, vec3(0.9, 0.97, 0.97), max(rl, 0.0) * 0.75 * a0 * a0 * big);
		over(o, vec3(0.0, 0.035, 0.06), max(-rl, 0.0) * 0.6 * a0 * a0 * big);
	}
	o.a *= 1.0 - smoothstep(1.8, 2.0, r);
	return o;
}
// The foam left where a shell went in: froth at first, then a lace of white threads round holes that widen until
// only wisps are left (not slabs: the white is the seams between the cells, and it is soft and broken).
float foam_at(vec2 p, float k, float seed, float edge) {
	float r = length(p);
	vec2 fp = p * 3.4 + seed + vec2(k * 0.5, -k * 0.3);
	fp += (vec2(fbm(fp * 0.8 + 3.1), fbm(fp * 0.8 + 11.7)) - 0.5) * 1.8;        // pulled about, so nothing is regular
	float big = cells(fp), fine = cells(fp * 2.7 + 5.0);                         // 0 on the seams, rising into each hole
	float wide = mix(0.6, 0.03, pow(k, 0.55)) * (1.0 - 0.6 * smoothstep(0.45, 1.0, r / edge));   // how thick the threads still are
	float lace = 1.0 - smoothstep(wide, wide + 0.16, big);
	lace = max(lace, (1.0 - smoothstep(wide * 0.6, wide * 0.6 + 0.2, fine)) * 0.7);
	float froth = 0.55 + 0.45 * fbm(fp * 4.0 + seed);                            // fine grain: bubbles, not paint
	return lace * froth * (1.0 - smoothstep(edge * 0.8, edge * 1.05, r));
}
void fragment() {
	float k = COLOR.r, seed = COLOR.g * 37.0;
	vec2 light = -normalize(sun);                    // where the light comes from
	if (COLOR.b > 0.5) { vec4 bl = blast(UV, k, seed, COLOR.a, light); bl.rgb *= mix(1.0, 0.5, night); COLOR = bl; }
	else {
	vec2 p = (UV * 2.0 - 1.0) * 4.0; float r = length(p), ang = atan(p.y, p.x);
	float a0 = 1.0 - k; vec4 o = vec4(0.0);
	float born = min(1.0, k * 10.0);
	// two ripples run out and are gone in the first quarter of its life: raised rings, lit and shaded
	float kr = clamp(k * 4.0, 0.0, 1.0), fade = pow(1.0 - kr, 1.5) * born * COLOR.a;
	vec2 dir = p / max(r, 0.001);
	float wob = 1.0 + 0.05 * (noise(dir * 2.0 + seed) - 0.5);
	for (int i = 0; i < 2; i++) {
		float rr = (0.8 + 2.6 * (1.0 - exp(-kr * 2.6))) * (1.0 - 0.3 * float(i));
		float d = r / wob - rr, w = 0.16 - 0.04 * float(i);
		float rl = relief(d, w, dir, light) * (1.0 - 0.45 * float(i)) * step(rr, 3.8);
		over(o, vec3(0.86, 0.95, 0.96), max(rl, 0.0) * 0.6 * fade);
		over(o, vec3(0.0, 0.035, 0.06), max(-rl, 0.0) * 0.6 * fade);
		float fleck = smoothstep(0.6, 0.8, noise(dir * 9.0 + seed * 1.3 + k * 2.0 + float(i) * 4.0));
		over(o, vec3(0.92, 0.98, 0.98), (1.0 - smoothstep(0.0, 0.05, abs(d))) * fleck * 0.5 * fade);   // the crest breaking here and there
	}
	// aerated water: a paler disc where the shell went in
	float rf = 0.6 + 0.35 * sqrt(min(1.0, k * 5.0)) + 0.3 * k;
	float edge = rf * (0.8 + 0.4 * fbm(vec2(cos(ang), sin(ang)) * 1.6 + seed));
	float disc = 1.0 - smoothstep(edge * 0.55, edge * 1.05, r);
	over(o, vec3(0.36, 0.62, 0.67), disc * 0.42 * pow(a0, 1.2) * born);
	// the foam, standing a little proud of the water: its shadow first, then the foam, bright on the edge towards the light
	float f0 = foam_at(p, k, seed, edge), f1 = foam_at(p + light * 0.07, k, seed, edge), f2 = foam_at(p - light * 0.07, k, seed, edge);
	float vis = born * min(1.0, a0 * 2.5);
	over(o, vec3(0.0, 0.05, 0.08), f1 * (1.0 - f0) * 0.16 * vis);
	vec3 fc = mix(vec3(0.7, 0.83, 0.86), vec3(0.88, 0.93, 0.93), clamp(0.6 + (f0 - f2) * 0.5, 0.0, 1.0));
	over(o, fc, clamp(f0 * 1.15, 0.0, 1.0) * 0.78 * vis);
	o.rgb *= mix(1.0, 0.5, night);
	COLOR = o;
	}
}
