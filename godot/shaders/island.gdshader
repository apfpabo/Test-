// A battle island, drawn on a quad over it. The coastline is the island's own outline (rad, the radius at 30
// bearings, in metres, as BattleSim uses for collision), so land is exactly where ships run aground. Inland, height
// rises from the shore with fractal noise for hills; the surface is beach, scrub and grass, darker woods, then bare
// rock on the heights, lit from the sun's direction. Outside the shore: a lighter shallow fringe and surf that
// breaks along the beach.
shader_type canvas_item;

uniform vec2 center = vec2(0.0);
uniform sampler2D rad : filter_linear, repeat_enable;   // radius by bearing, divided by r_max
uniform float r_max = 500.0;
uniform float seed = 0.0;
uniform vec2 sun_dir = vec2(-0.55, -0.85);   // direction the light comes from
uniform float rt = 0.0;                        // real seconds, for the surf
varying vec2 wp;

void vertex() { wp = VERTEX; }

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21) + seed); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.07 + vec2(3.1, 7.7); a *= 0.5; } return v; }
// the same radius as a smooth curve through the 30 points (Catmull-Rom), for the inland height only, so the
// hills don't crease along the bearings where the straight-line outline turns
float edge_smooth(vec2 d) {
	float x = fract(atan(d.y, d.x) / 6.28318) * 30.0; float i = floor(x), f = x - i;
	float p0 = texture(rad, vec2((i - 0.5) / 30.0, 0.5)).r, p1 = texture(rad, vec2((i + 0.5) / 30.0, 0.5)).r;
	float p2 = texture(rad, vec2((i + 1.5) / 30.0, 0.5)).r, p3 = texture(rad, vec2((i + 2.5) / 30.0, 0.5)).r;
	return r_max * (p1 + 0.5 * f * (p2 - p0 + f * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3 + f * (3.0 * (p1 - p2) + p3 - p0))));
}
float edge_at(vec2 d) { float u = fract(atan(d.y, d.x) / 6.28318) + 0.5 / 30.0; return texture(rad, vec2(u, 0.5)).r * r_max; }
// 1 at the shore, 0 at the middle, above 1 at sea
float shore(vec2 p) { vec2 d = p - center; return length(d) / max(edge_at(d), 1.0) + (fbm(p / 70.0) - 0.5) * 0.06; }  // a little ruggedness, within a few per cent of the collision outline
float height(vec2 p) {
	vec2 d = p - center; float t = length(d) / max(edge_smooth(d), 1.0);
	float base = pow(clamp(1.0 - t, 0.0, 1.0), 0.7);
	float hills = fbm(p / 160.0) * 0.85 + fbm(p / 55.0) * 0.12;
	return base * (0.35 + hills);
}
void fragment() {
	float t = shore(wp);
	vec4 col = vec4(0.0);
	if (t > 1.0) {
		// shallows: lighter, greener water fading out to the open sea, and surf along the beach
		float k = clamp((t - 1.0) / 0.35, 0.0, 1.0);
		vec3 sh = mix(vec3(0.33, 0.62, 0.6), vec3(0.18, 0.42, 0.45), k);
		// a broken white line where the waves break, and one more line of surf coming in behind it
		float brk = 0.6 + 0.4 * noise(wp / 30.0 + rt * 0.2);
		float surf = smoothstep(0.03, 0.0, t - 1.0) * 0.75 * brk + smoothstep(0.75, 1.0, sin((t - 1.0) * 90.0 - rt * 1.4)) * smoothstep(0.12, 0.03, t - 1.0) * 0.3 * brk;
		col = vec4(mix(sh, vec3(0.92, 0.95, 0.93), clamp(surf, 0.0, 1.0)), (1.0 - k) * 0.55 + surf * 0.35);
	} else {
		float h = height(wp);
		float e = 3.0;
		vec2 g = vec2(height(wp + vec2(e, 0.0)) - h, height(wp + vec2(0.0, e)) - h) / e;
		vec3 n = normalize(vec3(-g * 110.0, 1.0));
		float light = clamp(dot(n, normalize(vec3(sun_dir, 0.8))) / normalize(vec3(sun_dir, 0.8)).z, 0.6, 1.25);
		float wood = smoothstep(0.52, 0.62, fbm(wp / 60.0 + 11.0));
		vec3 sand = vec3(0.79, 0.71, 0.52), grass = vec3(0.42, 0.5, 0.29), scrub = vec3(0.5, 0.5, 0.33), forest = vec3(0.24, 0.34, 0.2), rock = vec3(0.5, 0.48, 0.42), peak = vec3(0.66, 0.64, 0.58);
		vec3 land = mix(scrub, grass, smoothstep(0.1, 0.3, h));
		land = mix(land, forest, wood * smoothstep(0.08, 0.2, h) * (1.0 - smoothstep(0.55, 0.7, h)));
		land = mix(land, rock, smoothstep(0.62, 0.8, h + noise(wp / 25.0) * 0.08));
		land = mix(land, peak, smoothstep(0.88, 1.0, h));
		land = mix(land, sand, smoothstep(0.9, 0.97, t + noise(wp / 18.0) * 0.03));
		land *= 0.9 + 0.2 * noise(wp / 9.0);    // fine texture: patches of growth and stone
		col = vec4(land * light, 1.0);
	}
	COLOR = col;
}
