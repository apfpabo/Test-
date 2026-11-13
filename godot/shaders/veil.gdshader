// Weather over the battle: the murk beyond what your ships can see (each visible ship clears a pool round itself),
// a wash of fog, and rain driving across the screen. Drawn over the world, under the bloom and the HUD.
shader_type canvas_item;
render_mode unshaded;
uniform vec4 spots[24];                  // xy: screen pixels, z: radius in pixels, w: unused
uniform int n_spots = 0;
uniform vec3 murk : source_color = vec3(0.02, 0.03, 0.05);
uniform float murk_a = 0.0;              // how dark it is beyond sight, 0 = no limit
uniform float fog = 0.0;                 // an even wash over everything
uniform vec3 fog_col : source_color = vec3(0.62, 0.66, 0.68);
uniform float rain = 0.0;
uniform float rt = 0.0;
uniform vec2 screen = vec2(1400.0, 860.0);
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
// a hash that holds for cell numbers into the thousands
float rhash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void fragment() {
	vec2 px = SCREEN_UV * screen;
	float clear = 0.0;
	for (int i = 0; i < n_spots; i++) {
		float d = distance(px, spots[i].xy), r = spots[i].z;
		clear = max(clear, 1.0 - smoothstep(r * 0.72, r * 1.08, d));
	}
	// the edge of sight wavers a little, as banks of mist and squalls do
	float wav = noise(px / 90.0 + vec2(rt * 0.05, rt * 0.03)) * 0.25 + 0.875;
	float a = murk_a * (1.0 - clear * wav);
	vec3 col = murk;
	// fog: thicker in drifting banks
	float bank = noise(px / 260.0 + vec2(rt * 0.02, 0.0)) * 0.5 + 0.75;
	float fa = fog * bank * (0.55 + 0.45 * (1.0 - clear));
	col = mix(col, fog_col, fa / max(0.001, a + fa)); a = 1.0 - (1.0 - a) * (1.0 - fa);
	// rain: slanting streaks in two layers, moving fast
	if (rain > 0.0) {
		vec2 q = vec2(px.x + px.y * 0.35, px.y);
		// (cell numbers are kept small: the first hash lost its precision with large ones, and the rain thinned out
		// across the screen and as the clock ran on - the owner saw it on one side only, 13 Nov 2026)
		float s1 = rhash(vec2(mod(floor(q.x / 2.0), 1024.0), mod(floor((q.y + mod(rt * 1900.0, 70.0 * 512.0)) / 70.0), 512.0)));
		float s2 = rhash(vec2(mod(floor(q.x / 1.5) + 7.0, 1024.0), mod(floor((q.y + mod(rt * 2600.0, 46.0 * 512.0)) / 46.0), 512.0) + 517.0));
		float st = step(0.985, s1) * 0.5 + step(0.99, s2) * 0.35;
		float ra = st * rain * 0.3;
		col = mix(col, vec3(0.8, 0.84, 0.88), ra / max(0.001, a + ra)); a = 1.0 - (1.0 - a) * (1.0 - ra);
		a = 1.0 - (1.0 - a) * (1.0 - rain * 0.1);   // and a general greyness
	}
	COLOR = vec4(col, a);
}
