// Weather and the night over the chart. `wx` is a coarse grid from Weather (R: storminess, G: fog); the shader breaks
// it into cloud with its own detail, tints fog, and darkens the side of the world the sun has left.
shader_type canvas_item;
uniform sampler2D wx : filter_linear, repeat_enable;
uniform float day_frac = 0.0;     // fraction of the day at longitude 0
uniform float winter_n = 0.0;     // -1 high summer to 1 midwinter in the northern hemisphere
uniform float rt = 0.0;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y); }
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + vec2(3.1, 7.7); a *= 0.5; } return v; }
// A smooth (cubic B-spline) read of the coarse grid, texel by texel (sixteen fetches): no creases along the grid lines
// however far the chart is zoomed in, and nothing left to the texture filter (which read it as flat squares).
vec4 cub(float f) { return vec4((1.0 - f) * (1.0 - f) * (1.0 - f), 4.0 - 6.0 * f * f + 3.0 * f * f * f, 1.0 + 3.0 * f + 3.0 * f * f - 3.0 * f * f * f, f * f * f) / 6.0; }
vec4 smooth_wx(vec2 uv) {
	ivec2 res = ivec2(180, 80); vec2 st = uv * vec2(res) - 0.5; ivec2 i = ivec2(floor(st)); vec2 f = st - floor(st);
	vec4 wx_ = cub(f.x); vec4 wy_ = cub(f.y); vec4 acc = vec4(0.0);
	for (int dy = 0; dy < 4; dy++) {
		int y = clamp(i.y + dy - 1, 0, res.y - 1);
		for (int dx = 0; dx < 4; dx++) {
			int x = (i.x + dx - 1 + 2 * res.x) % res.x;
			acc += texelFetch(wx, ivec2(x, y), 0) * wx_[dx] * wy_[dy];
		}
	}
	return acc;
}
void fragment() {
	vec4 w = smooth_wx(UV);
	vec2 p = UV * vec2(180.0, 80.0);
	// soft detail at three scales (broad billows down to wisps), drifting slowly
	float det = fbm(p * 0.9 + vec2(rt * 0.006, 0.0)) * 0.6 + fbm(p * 3.1 + vec2(rt * 0.011, 4.0)) * 0.4;
	float s = w.r + (det - 0.5) * 0.2;
	float cloud = smoothstep(0.56, 0.74, s);          // rough weather: broken cloud
	float storm = smoothstep(0.74, 0.86, s);          // the storm itself: a dark, solid mass
	vec3 col = mix(vec3(0.78, 0.82, 0.84), vec3(0.3, 0.33, 0.37), storm);
	float a = cloud * 0.32 + storm * 0.3;
	// fog banks: soft-edged and wispy like the cloud (they were flat slabs with hard edges, which read as a
	// different, more solid kind of cloud)
	float wisp = fbm(p * 2.3 + vec2(-rt * 0.008, 9.0));
	float fog = smoothstep(0.3, 0.85, w.g + (det - 0.5) * 0.55) * (0.55 + 0.7 * wisp);
	col = mix(col, vec3(0.86, 0.88, 0.88), fog * (1.0 - cloud)); a = max(a, fog * 0.26);
	// the night side
	float lat = radians(82.0 - UV.y * 160.0);
	float hour = fract(day_frac + UV.x - 0.5) * 24.0;
	float north = lat >= 0.0 ? winter_n : -winter_n;
	float hd = clamp(6.0 - 4.2 * north * sin(abs(lat)), 1.5, 10.5);
	float dark = smoothstep(hd - 0.5, hd + 0.7, abs(hour - 12.0)) * 0.5;
	vec3 night = vec3(0.01, 0.03, 0.09);
	float oa = 1.0 - (1.0 - a) * (1.0 - dark);
	COLOR = vec4(mix(night, col * (1.0 - dark * 0.8), a / max(oa, 0.001)), oa);
}
