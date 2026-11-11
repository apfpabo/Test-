// The world as a globe (the chart's far overview): an orthographic sphere ray-cast in the fragment shader and painted
// from the same baked terrain as the flat chart (data/terrain.png: equirectangular, lat_top N down lat_span degrees,
// alpha 0 on the sea). centre = the longitude and latitude facing the viewer, in radians.
shader_type canvas_item;
uniform sampler2D terrain : filter_linear, repeat_enable;
uniform vec2 size = vec2(1400.0, 860.0);
uniform vec2 mid = vec2(700.0, 430.0);
uniform float radius = 300.0;
uniform vec2 centre = vec2(0.0, 0.0);
uniform float lat_top = 82.0;
uniform float lat_span = 160.0;
uniform float fade = 1.0;
// the day's weather (the chart's own coarse grid: R storminess, G fog; 180 x 80 over the whole chart) and the hour
uniform sampler2D wx : filter_linear, repeat_enable;
uniform bool has_wx = false;
uniform float day_frac = 0.0;     // fraction of the day at longitude 0
uniform float winter_n = 0.0;     // -1 high summer to 1 midwinter in the northern hemisphere
uniform float rt = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + vec2(3.1, 7.7); a *= 0.5; } return v; }
// A smooth (cubic B-spline) read of the coarse weather grid, as the chart's own weather shader does it: the texture
// filter reads this half-float grid as flat squares.
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
// a thin line where v crosses a multiple of step (v and step in degrees), about one pixel wide
float grid(float v, float step_, float w) { float d = abs(fract(v / step_ + 0.5) - 0.5) * step_; return 1.0 - smoothstep(0.0, w, d); }
void fragment() {
	vec2 p = (UV * size - mid) / radius; p.y = -p.y;       // y up, the sphere of radius 1
	float r2 = dot(p, p);
	// the dark behind the world: deep blue-black, a few faint stars
	vec3 col = mix(vec3(0.020, 0.045, 0.060), vec3(0.008, 0.018, 0.026), clamp(length(UV - 0.5) * 1.5, 0.0, 1.0));
	vec2 sp = floor(UV * size / 2.0); float st = hash(sp);
	col += vec3(0.55, 0.62, 0.66) * step(0.9975, st) * (0.25 + 0.5 * hash(sp + 7.0));
	if (r2 < 1.0) {
		float z = sqrt(1.0 - r2);
		float lat = asin(clamp(z * sin(centre.y) + p.y * cos(centre.y), -1.0, 1.0));
		float lon = centre.x + atan(p.x, z * cos(centre.y) - p.y * sin(centre.y));
		float latd = degrees(lat), lond = degrees(lon);
		vec2 uv = vec2(lond / 360.0 + 0.5, (lat_top - latd) / lat_span);
		// the sea: the chart's own blue-green, deeper towards the middle of the oceans' noise, lighter in shoal patches
		float n = noise(vec2(lond, latd) * 0.35) * 0.6 + noise(vec2(lond, latd) * 1.3) * 0.4;
		vec3 sea = mix(vec3(0.050, 0.150, 0.185), vec3(0.085, 0.230, 0.265), n);
		vec3 c = sea;
		// a pixel here covers this much of the chart across (in uv): near the poles, where the meridians crowd together,
		// it spans many texels, and one sample of them broke into radial streaks (the owner: "the poles look weird")
		float px0 = degrees(1.0 / radius) / max(z, 0.25);
		float fw = clamp(px0 / 360.0 / max(cos(lat), 0.02), 0.0, 0.25) + smoothstep(66.0, 75.0, abs(latd)) * 0.012;   // (and the high snowfields smoothed along their parallels)
		if (uv.y > 0.0 && uv.y < 1.0) {
			vec4 t = vec4(0.0);
			for (int k = 0; k < 9; k++) t += texture(terrain, uv + vec2((float(k) / 8.0 - 0.5) * fw, 0.0));
			t /= 9.0;
			// a pale shelf of shoal water round every coast (the terrain's alpha, blurred by sampling a little way off)
			float near = 0.0;
			for (int i = 0; i < 6; i++) { float a = float(i) * 1.047; near += texture(terrain, uv + vec2(cos(a), sin(a) * 2.25) * 0.0022).a; }
			c = mix(c, vec3(0.13, 0.33, 0.36), clamp(near / 6.0, 0.0, 1.0) * 0.55 * (1.0 - t.a));
			c = mix(c, t.rgb, t.a);
		} else {
			// beyond the chart: the ice of the far north and south, its edge broken, never surveyed
			c = sea;
		}
		// the ice of the far north and south: it closes over the last degrees of the chart and everything beyond, which
		// was never surveyed. Its texture is laid on the sphere itself, not by longitude (that drew a star at each pole).
		vec3 sph = vec3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon));
		float nI = noise(sph.xz * 9.0 + sph.y * 3.0) * 0.6 + noise(sph.xz * 23.0) * 0.4;
		float e = max(-uv.y, uv.y - 1.0);
		float ice = smoothstep(-0.03, 0.02, e + (nI - 0.5) * 0.035);
		// and it lies over the last few degrees of the chart too (from 74 S and 78 N): there the snowfields of the
		// chart's own last rows, wrapped round the pole, became radial streaks (the owner: "the poles look weird")
		float cap0 = latd < 0.0 ? 74.0 : 78.0;
		ice = max(ice, smoothstep(cap0, cap0 + 3.0, abs(latd) + (nI - 0.5) * 3.0));
		c = mix(c, vec3(0.80, 0.86, 0.88) * (0.88 + 0.14 * nI), ice);
		// the graticule: every 15 degrees faintly, the equator and the prime meridian a little stronger
		float px = degrees(1.0 / radius) / max(z, 0.25);   // degrees per screen pixel hereabouts
		float g = max(grid(latd, 15.0, px * 1.2), grid(lond, 15.0, px * 1.2 / max(cos(lat), 0.05)) * step(abs(latd), 82.5));
		float g0 = max(1.0 - smoothstep(0.0, px * 1.5, abs(latd)), 1.0 - smoothstep(0.0, px * 1.5 / max(cos(lat), 0.05), abs(fract(lond / 360.0 + 0.5) - 0.5) * 360.0));
		c = mix(c, vec3(0.75, 0.86, 0.88), g * 0.10 + g0 * 0.12);
		// the weather over it: broken cloud where the sea is rough, a dark mass where it storms, pale banks of fog
		if (has_wx && uv.y > 0.0 && uv.y < 1.0) {
			vec4 w = smooth_wx(vec2(fract(uv.x), uv.y));
			float det = fbm(sph.xz * 14.0 + sph.y * 9.0 + vec2(rt * 0.004, 0.0)) * 0.6 + fbm(sph.xz * 40.0 + sph.y * 23.0) * 0.4;
			float s = w.r + (det - 0.5) * 0.22;
			float cloud = smoothstep(0.56, 0.74, s), storm = smoothstep(0.74, 0.86, s);
			c = mix(c, mix(vec3(0.80, 0.84, 0.86), vec3(0.34, 0.37, 0.41), storm), cloud * 0.42 + storm * 0.3);
			c = mix(c, vec3(0.74, 0.79, 0.80), smoothstep(0.3, 0.85, w.g + (det - 0.5) * 0.55) * (0.2 + 0.25 * fbm(sph.xz * 30.0 + sph.y * 17.0)));
		}
		// night: the side the sun has left, by the same reckoning as the chart (the hour there, and the season's length of day)
		float hr = mod(day_frac * 24.0 + lond / 15.0, 24.0);
		float half_day = clamp(6.0 - 4.2 * winter_n * sign(latd) * sin(abs(lat)), 1.5, 10.5);
		float dark = smoothstep(half_day - 0.5, half_day + 0.7, abs(hr - 12.0));
		// towards the poles the hour at each meridian drew the night as a wedge with straight sides meeting at the pole;
		// there the edge of the night is reckoned from the sun itself (a curve, as it is), blended in from 55 degrees
		float sun_lon = radians((12.0 - day_frac * 24.0) * 15.0); float decl = radians(-23.4 * winter_n);
		vec3 sun_v = vec3(cos(decl) * cos(sun_lon), sin(decl), cos(decl) * sin(sun_lon));
		float dark_sun = smoothstep(0.04, -0.08, dot(sph, sun_v));
		dark = mix(dark, dark_sun, smoothstep(55.0, 72.0, abs(latd)));
		c = mix(c, c * vec3(0.20, 0.27, 0.40) + vec3(0.0, 0.004, 0.012), dark * 0.86);
		// the light: from the upper left, the limb falling away into shade, and a soft sheen on the water
		vec3 nrm = vec3(p.x, p.y, z); vec3 L = normalize(vec3(-0.45, 0.5, 0.74));
		float lit = clamp(dot(nrm, L), 0.0, 1.0);
		c *= 0.55 + 0.58 * pow(lit, 0.8);
		c += (1.0 - dark) * vec3(0.10, 0.16, 0.17) * pow(clamp(dot(reflect(-L, nrm), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 24.0);
		// the air at the limb
		c = mix(c, vec3(0.42, 0.66, 0.74), pow(1.0 - z, 3.5) * 0.55);
		float edge = smoothstep(1.0, 1.0 - 2.5 / radius, sqrt(r2));
		col = mix(col, c, edge);
	}
	// the glow of the air round the world
	float d = sqrt(r2) - 1.0;
	if (d > -0.01) col += vec3(0.20, 0.42, 0.50) * exp(-max(d, 0.0) * 22.0) * 0.38 * (0.6 + 0.4 * clamp(dot(normalize(p + vec2(0.0001)), normalize(vec2(-0.45, 0.5))), 0.0, 1.0));
	COLOR = vec4(col, fade);
}
