// Open sea seen from above: broad colour from drifting fractal noise, travelling swell waves on the real clock that
// light the surface and carry the sun's glints, slow cloud shadows, and a vignette at the screen edges.
shader_type canvas_item;

uniform vec2 cam = vec2(0.0);          // world position at the centre of the screen (metres)
uniform float zoom = 0.25;              // screen pixels per metre
uniform vec2 screen = vec2(1400.0, 860.0);
uniform float t = 0.0;                  // battle seconds
uniform float rt = 0.0;                 // real seconds: the swell keeps rolling at its own pace whatever the battle clock
uniform vec3 deep : source_color = vec3(0.075, 0.235, 0.275);
uniform vec3 shallow : source_color = vec3(0.14, 0.34, 0.37);
uniform vec2 sun_dir = vec2(-0.55, -0.85);
uniform float sea_state = 0.0;          // 0 calm to 3 storm: steeper swell, whitecaps
uniform float night = 0.0;              // 0 day to 1 night
uniform float moon = 0.5; // direction the light comes from, on the chart

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= 0.5; } return v; }
float swell_h(vec2 w) { return fbm(w / 260.0 + vec2(t * 0.004, t * 0.002)); }
float sea(vec2 w) {
	float swell = fbm(w / 260.0 + vec2(t * 0.004, t * 0.002));
	float chop = fbm(w / 45.0 + vec2(-t * 0.02, t * 0.014));
	float detail = clamp((zoom - 0.12) / 0.5, 0.0, 1.0); // fine chop only once you are close enough to see it
	return swell * 0.8 + chop * 0.14 * detail;
}
// Travelling swell: four long-crested waves from about the same quarter, each moving at its deep-water speed
// (omega = sqrt(g k)); returns the height and its slope. The phase is broken up by noise so crests don't repeat.
vec3 swell_waves(vec2 w) {
	vec3 acc = vec3(0.0);
	vec4 len = vec4(140.0, 95.0, 63.0, 41.0); vec4 amp = vec4(0.5, 0.32, 0.2, 0.12); vec4 dir = vec4(0.35, 1.05, -0.35, 0.75);
	float ph0 = noise(w / 700.0) * 6.0;
	for (int i = 0; i < 4; i++) {
		vec2 d = vec2(cos(dir[i]), sin(dir[i])); float k = 6.2832 / len[i]; float om = sqrt(9.81 * k);
		float x = dot(d, w) * k - om * rt + ph0 * float(i + 1) * 0.6;
		acc.x += amp[i] * sin(x); acc.yz += amp[i] * k * cos(x) * d;
	}
	return acc;
}
void fragment() {
	vec2 w = cam + (SCREEN_UV - 0.5) * screen / zoom;
	// lighting follows the broad swell only, so glints are smooth sheens rather than speckle
	float e = max(6.0, 3.0 / max(zoom, 0.05));
	float h = sea(w), hs = swell_h(w);
	vec2 grad = vec2(swell_h(w + vec2(e, 0.0)) - hs, swell_h(w + vec2(0.0, e)) - hs) / e;
	vec3 sw = swell_waves(w);
	float fade = clamp((zoom - 0.45) / 0.8, 0.0, 1.0);   // far out the waves would alias into streaks: leave the broad sea
	vec3 n = normalize(vec3(-grad * 90.0 - sw.yz * 3.5 * fade, 1.0));
	vec3 l = normalize(vec3(sun_dir, 0.9));
	float diff = clamp(dot(n, l), 0.0, 1.0);
	// glints ride the moving swell (the noise slope has creases that would leave still, curly highlights)
	vec3 ns = normalize(vec3(-sw.yz * 4.0 - grad * 30.0, 1.0));
	float spec = pow(clamp(dot(reflect(-l, ns), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 24.0) * fade;
	vec3 col = mix(deep, shallow, smoothstep(0.3, 0.75, h + sw.x * 0.06 * fade));
	// cloud shadows drifting across the sea
	float cloud = smoothstep(0.45, 0.75, fbm(w / 2600.0 + vec2(rt * 0.0016, rt * 0.0009)));
	col *= 1.0 - 0.16 * cloud;
	col *= 0.82 + 0.3 * diff;
	col += vec3(0.75, 0.8, 0.78) * spec * 0.12 * clamp(zoom * 2.0, 0.2, 1.0);
	// weather: a grey, steep sea with whitecaps running down-wind as it rises
	float ss = clamp(sea_state / 3.0, 0.0, 1.0);
	col = mix(col, vec3(dot(col, vec3(0.33))) * vec3(0.92, 1.0, 1.02), ss * 0.45);
	col *= 1.0 + (sw.x * 0.05 * fade + (hs - 0.5) * 0.25) * ss;
	if (ss > 0.2) {
		// whitecaps: streaks of foam lying along the crests, in patches where the sea breaks
		vec2 wd = vec2(0.86, 0.5); vec2 wn = vec2(-wd.y, wd.x);
		vec2 wc = vec2(dot(w, wd) / 26.0 + rt * 0.3, dot(w, wn) / 90.0);
		float patch_ = smoothstep(0.5, 0.75, fbm(w / 420.0 + vec2(rt * 0.01, 0.0)));
		float caps = smoothstep(0.72 - 0.08 * ss, 0.9, fbm(wc)) * (0.35 + 0.65 * patch_);
		col = mix(col, vec3(0.8, 0.85, 0.86), caps * ss * 0.55 * clamp(zoom * 3.0, 0.2, 1.0));
	}
	// night: the sea goes to blue-black, with the moon's path on the swell
	vec3 dark = col * vec3(0.26, 0.33, 0.48) + vec3(0.0, 0.006, 0.016);
	dark += vec3(0.5, 0.56, 0.66) * spec * 0.22 * moon;
	col = mix(col, dark, night);
	vec2 v = SCREEN_UV - 0.5; col *= 1.0 - dot(v, v) * 0.75;
	COLOR = vec4(col, 1.0);
}
