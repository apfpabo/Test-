shader_type canvas_item;
// The title in iron: brushed steel shading from a pale top edge to a dark foot, a bright bevel band, fine
// horizontal brushing, rust bloom and a few pits. Applied to a Label; top/bottom are the capitals' extent in the
// label's own pixels (set by main_menu.gd from the font's metrics).
uniform float top_y = 0.0;
uniform float bottom_y = 100.0;
varying vec2 lp;

void vertex() { lp = VERTEX; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float a = texture(TEXTURE, UV).a * COLOR.a;
	float t = clamp((lp.y - top_y) / max(1.0, bottom_y - top_y), 0.0, 1.0);
	vec3 top = vec3(0.86, 0.87, 0.86), mid = vec3(0.47, 0.49, 0.5), low = vec3(0.2, 0.21, 0.22);
	vec3 c = t < 0.45 ? mix(top, mid, t / 0.45) : mix(mid, low, (t - 0.45) / 0.55);
	c += vec3(0.32, 0.31, 0.28) * smoothstep(0.07, 0.0, abs(t - 0.38));          // the bevel's bright line
	c *= 0.82 + 0.3 * noise(vec2(lp.x * 0.015, lp.y * 1.7));                     // brushed grain
	float rust = smoothstep(0.6, 0.86, noise(lp * 0.045 + 7.0)) * smoothstep(0.25, 1.0, t);
	c = mix(c, vec3(0.45, 0.24, 0.12), rust * 0.55);                              // rust blooming from the foot
	c *= 1.0 - 0.3 * step(0.985, hash(floor(lp * 0.6)));                          // pits
	COLOR = vec4(c, a);
}
