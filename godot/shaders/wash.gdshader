// What a shell leaves on the sea after the column has fallen back, seen from above, drawn on one quad: a patch of
// foam that breaks into cells and wastes away, paler aerated water under it, and a trough running out across the
// sea with a thin broken crest (owner's request, 10 Nov 2026). COLOR carries it: r = age 0..1, g = seed.
// The quad spans four radii each way.
shader_type canvas_item;
uniform float night = 0.0;
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
void fragment() {
	float k = COLOR.r, seed = COLOR.g * 37.0;
	vec2 p = (UV * 2.0 - 1.0) * 4.0; float r = length(p), ang = atan(p.y, p.x);
	float a0 = 1.0 - k; vec4 o = vec4(0.0);
	float born = min(1.0, k * 10.0);
	// the trough: a darker band running out behind the crest, then the crest itself, thin and flecked
	float rr = 0.9 + 2.7 * (1.0 - exp(-k * 3.2));
	float wob = 1.0 + 0.05 * (noise(vec2(cos(ang), sin(ang)) * 2.0 + seed) - 0.5);
	float d = r / wob - rr;
	float trough = smoothstep(-1.1, -0.15, d) * (1.0 - smoothstep(-0.15, 0.02, d));
	over(o, vec3(0.0, 0.04, 0.07), COLOR.a * trough * 0.72 * a0 * born);
	float crest = 1.0 - smoothstep(0.0, 0.06, abs(d - 0.03));
	float fleck = smoothstep(0.55, 0.75, noise(vec2(cos(ang), sin(ang)) * 9.0 + seed * 1.3 + k * 2.0));
	over(o, vec3(0.86, 0.95, 0.96), COLOR.a * crest * (0.3 + 0.65 * fleck) * a0 * a0 * born * step(rr, 3.85));
	// aerated water: a paler disc where the shell went in
	float rf = 0.75 + 0.55 * sqrt(min(1.0, k * 5.0)) + 0.25 * k;
	float edge = rf * (0.8 + 0.4 * fbm(vec2(cos(ang), sin(ang)) * 1.6 + seed));
	float disc = 1.0 - smoothstep(edge * 0.55, edge * 1.05, r);
	over(o, vec3(0.42, 0.68, 0.72), disc * 0.5 * pow(a0, 0.8) * born);
	// the foam: cells that open up and waste away from the edge inwards
	vec2 fp = p * (2.8 + 0.5 * k) + seed + vec2(k * 0.6, -k * 0.4);
	fp += (vec2(fbm(fp * 0.9 + 3.1), fbm(fp * 0.9 + 11.7)) - 0.5) * 1.5;      // pulled about, so the cells are ragged, not tiles
	float tex = fbm(fp * 1.6 + seed);
	float c = min(1.0, cells(fp) * 2.4) * 0.5 + tex * 0.75;
	float th = mix(0.14, 0.98, pow(k, 1.7)) + 0.25 * smoothstep(0.55, 1.0, r / edge);
	float foam = smoothstep(th, th + 0.2, c) * (0.6 + 0.4 * smoothstep(0.3, 0.7, tex)) * (1.0 - smoothstep(edge * 0.85, edge * 1.02, r)) * born;
	over(o, mix(vec3(0.8, 0.9, 0.93), vec3(1.0), smoothstep(th + 0.05, th + 0.3, c)), foam * 0.92 * min(1.0, a0 * 2.5));
	o.rgb *= mix(1.0, 0.5, night);
	COLOR = o;
}
