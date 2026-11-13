// The sea sinking round a shell's splash (the new splash style; the owner's reference, 12 Nov 2026), seen from above
// and drawn on one quad. The surface is modelled as a height field - a bowl with a raised, ragged lip and a few ripples
// running out beyond it - and lit from the sun, so the light and shade fall across it as they would on real water.
// COLOR carries the burst: r = how deep the hollow is now (1..0), g = a seed, b = the light (1 by day, less at night),
// a = where the ripples are in their run (a clock, wrapped). The quad spans 1.5 bowl radii each way.
shader_type canvas_item;
uniform vec2 sun = vec2(0.55, 0.85);   // the way shadows fall: the light comes from the other way

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + vec2(3.1, 7.7); a *= 0.5; } return v; }

// the surface's height at p (in bowl radii); d is how deep the hollow is now (1 as the shell goes in, 0 when the sea
// has closed over it), ph where the ripples are in their run. Nothing here depends on a clock that can be put back:
// another shell in the same hollow only deepens it again (the owner saw it "reset", 13 Nov 2026).
float height(vec2 p, float d, float seed, float ph) {
	float ang = atan(p.y, p.x);
	float rag = 1.0 + 0.12 * (noise(vec2(cos(ang), sin(ang)) * 2.3 + seed) - 0.5) + 0.05 * (noise(vec2(cos(ang), sin(ang)) * 6.0 + seed * 2.0) - 0.5);
	float r0 = length(p), r = r0 / rag;   // the lip is ragged; the bowl inside it is smooth (a ragged bowl showed spokes)
	float depth = 0.34 * d * d;   // a shallow dish: water gives a few metres under a shell, it is not a crater
	float bowl = -depth * pow(max(0.0, 1.0 - r0 * r0 * 0.8), 2.0) * smoothstep(1.12, 0.6, r0);   // sloping gently all the way up to the lip: no wall
	float lr = 0.92 + 0.3 * (1.0 - d);   // the lip is the swell the hollow pushed up: it runs outward and sinks as the hollow fills
	float lip = 0.075 * d * exp(-pow((r - lr) / 0.3, 2.0)) * (0.6 + 0.8 * fbm(p * 2.2 + seed));   // low, broad and uneven: a swell, not a rim
	float rip = 0.03 * d * sin((r0 - 1.0) * 14.0 - ph + 2.0 * fbm(p * 1.5 + seed)) * exp(-max(r0 - lr, 0.0) * 3.5) * smoothstep(lr + 0.02, lr + 0.25, r0);   // (round the true centre, pulled a little out of true: on the ragged radius they showed as spokes)
	float chop = 0.03 * d * (fbm(p * 5.0 + seed * 3.0 + vec2(ph * 0.05, 0.0)) - 0.5) * smoothstep(1.2, 0.5, r);   // the surface inside is broken water, not glass
	return bowl + lip + rip + chop;
}

void fragment() {
	float d = clamp(COLOR.r, 0.0, 1.0), seed = COLOR.g * 41.0, light = COLOR.b, ph = COLOR.a * 6.2832;
	vec2 p = (UV * 2.0 - 1.0) * 1.5;
	float e = 0.02;
	float h = height(p, d, seed, ph);
	float hx = height(p + vec2(e, 0.0), d, seed, ph) - height(p - vec2(e, 0.0), d, seed, ph);
	float hy = height(p + vec2(0.0, e), d, seed, ph) - height(p - vec2(0.0, e), d, seed, ph);
	vec3 n = normalize(vec3(-hx / (2.0 * e), -hy / (2.0 * e), 2.2));   // (a gentle relief: water sinks a few metres in a bowl tens across)
	vec3 l = normalize(vec3(-normalize(sun), 1.15));                         // the sun some 40 degrees up
	float flat_l = l.z;
	float shade = dot(n, l) - flat_l;                                       // lighter or darker than the open sea
	float fade = smoothstep(1.5, 1.05, length(p)) * smoothstep(0.0, 0.3, d);
	vec4 o = vec4(0.0);
	// shadowed slopes darken the sea, lit ones brighten it towards the sky's reflection
	if (shade < 0.0) o = vec4(0.0, 0.03, 0.05, clamp(-shade * 2.2, 0.0, 0.3));
	else o = vec4(vec3(0.55, 0.76, 0.8) * light, clamp(shade * 2.2, 0.0, 0.3));
	// the water in the hollow is stirred and full of air: a little darker at the bottom, paler and greener about it
	float deep = clamp(-h * 2.0, 0.0, 1.0);
	o.rgb = mix(o.rgb, vec3(0.0, 0.05, 0.06), deep * 0.4 * (1.0 - o.a));
	o.a = max(o.a, deep * 0.14);
	float r0 = length(p);
	float air = smoothstep(1.1, 0.3, r0) * d * (0.55 + 0.45 * fbm(p * 2.5 + seed));
	o.rgb = mix(o.rgb, vec3(0.3, 0.62, 0.62) * light, air * 0.35); o.a = max(o.a, air * 0.16);
	// broken white water inside it, thickest in the middle where the column stands and falls back, and on the lip
	float fn = fbm(p * 6.0 + seed * 5.0 + vec2(0.0, ph * 0.04));
	float inf = smoothstep(0.48, 0.74, fn + 0.25 * (1.0 - r0)) * smoothstep(1.05, 0.25, r0) * d;
	float lipf = smoothstep(0.07, 0.13, h) * smoothstep(0.5, 0.78, fn);
	float foam = clamp(inf * 0.6 + lipf, 0.0, 1.0);
	o.rgb = mix(o.rgb, vec3(0.88, 0.95, 0.94) * light, foam * 0.8); o.a = max(o.a, foam * 0.5);
	// the sun's glint on the lit side of the lip
	vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(n, hv), 0.0), 40.0) * smoothstep(0.02, 0.09, h) * 0.5;
	o.rgb += vec3(spec) * light; o.a = max(o.a, spec * 0.7);
	COLOR = vec4(o.rgb, o.a * fade);
}
