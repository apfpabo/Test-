// The sea sinking round a shell's splash (the new splash style; the owner's reference, 12 Nov 2026), seen from above
// and drawn on one quad. The surface is modelled as a height field - a bowl with a raised, ragged lip and a few ripples
// running out beyond it - and lit from the sun, so the light and shade fall across it as they would on real water.
// COLOR carries the burst: r = progress 0..1 (the bowl fills as it goes), g = a seed, b = the light (1 by day, less at
// night). The quad spans 1.5 bowl radii each way.
shader_type canvas_item;
uniform vec2 sun = vec2(0.55, 0.85);   // the way shadows fall: the light comes from the other way

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + vec2(3.1, 7.7); a *= 0.5; } return v; }

// the surface's height at p (in bowl radii); k is how far it has filled again
float height(vec2 p, float k, float seed) {
	float ang = atan(p.y, p.x);
	float rag = 1.0 + 0.09 * (noise(vec2(cos(ang), sin(ang)) * 2.3 + seed) - 0.5) + 0.04 * (noise(vec2(cos(ang), sin(ang)) * 6.0 + seed * 2.0) - 0.5);
	float r0 = length(p), r = r0 / rag;   // the lip is ragged; the bowl inside it is smooth (a ragged bowl showed spokes)
	float depth = (1.0 - k) * (1.0 - k);
	float bowl = -depth * pow(max(0.0, 1.0 - r0 * r0), 1.6) * smoothstep(1.06, 0.9, r0);   // eased into the lip: no dark crease inside it
	float lip = 0.2 * (1.0 - k) * exp(-pow((r - 1.02) / 0.13, 2.0)) * (0.7 + 0.6 * fbm(p * 3.0 + seed));
	float rip = 0.06 * (1.0 - k) * sin((r - 1.0) * 14.0 - k * 9.0) * exp(-max(r - 1.0, 0.0) * 3.5) * smoothstep(1.02, 1.25, r);   // eased in: no crease at the edge
	float chop = 0.015 * (fbm(p * 4.0 + seed * 3.0) - 0.5) * smoothstep(1.3, 0.6, r);   // the disturbed surface inside
	return bowl + lip + rip + chop;
}

void fragment() {
	float k = clamp(COLOR.r, 0.0, 1.0), seed = COLOR.g * 41.0, light = COLOR.b;
	vec2 p = (UV * 2.0 - 1.0) * 1.5;
	float e = 0.02;
	float h = height(p, k, seed);
	float hx = height(p + vec2(e, 0.0), k, seed) - height(p - vec2(e, 0.0), k, seed);
	float hy = height(p + vec2(0.0, e), k, seed) - height(p - vec2(0.0, e), k, seed);
	vec3 n = normalize(vec3(-hx / (2.0 * e), -hy / (2.0 * e), 2.2));   // (a gentle relief: water sinks a few metres in a bowl tens across)
	vec3 l = normalize(vec3(-normalize(sun), 1.15));                         // the sun some 40 degrees up
	float flat_l = l.z;
	float shade = dot(n, l) - flat_l;                                       // lighter or darker than the open sea
	float fade = smoothstep(1.5, 1.15, length(p)) * (1.0 - smoothstep(0.5, 1.0, k));
	vec4 o = vec4(0.0);
	// shadowed slopes darken the sea, lit ones brighten it towards the sky's reflection
	if (shade < 0.0) o = vec4(0.0, 0.03, 0.05, clamp(-shade * 3.0, 0.0, 0.55));
	else o = vec4(vec3(0.55, 0.76, 0.8) * light, clamp(shade * 2.6, 0.0, 0.45));
	// deep water in the bowl: darker, a little greener, as the sea is where it is deeper and stirred
	float deep = clamp(-h, 0.0, 1.0);
	o.rgb = mix(o.rgb, vec3(0.0, 0.05, 0.06), deep * 0.5 * (1.0 - o.a));
	o.a = max(o.a, deep * 0.28);
	// foam on the lip, where it is highest, broken up
	float lipf = smoothstep(0.12, 0.2, h) * smoothstep(0.55, 0.8, fbm(p * 6.0 + seed * 5.0));
	o.rgb = mix(o.rgb, vec3(0.88, 0.95, 0.94) * light, lipf * 0.8); o.a = max(o.a, lipf * 0.55);
	// the sun's glint on the lit side of the lip
	vec3 hv = normalize(l + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(n, hv), 0.0), 40.0) * smoothstep(0.03, 0.14, h) * 0.6;
	o.rgb += vec3(spec) * light; o.a = max(o.a, spec * 0.7);
	COLOR = vec4(o.rgb, o.a * fade);
}
