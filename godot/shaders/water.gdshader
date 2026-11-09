// Open sea seen from above: two scales of drifting swell from fractal noise, normals taken from the noise so the
// low sun puts glints on wave faces, a cooler tint in the troughs, and a vignette at the screen edges.
shader_type canvas_item;

uniform vec2 cam = vec2(0.0);          // world position at the centre of the screen (metres)
uniform float zoom = 0.25;              // screen pixels per metre
uniform vec2 screen = vec2(1400.0, 860.0);
uniform float t = 0.0;                  // battle seconds
uniform vec3 deep : source_color = vec3(0.075, 0.235, 0.275);
uniform vec3 shallow : source_color = vec3(0.14, 0.34, 0.37);
uniform vec2 sun_dir = vec2(-0.55, -0.85); // direction the light comes from, on the chart

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
void fragment() {
	vec2 w = cam + (SCREEN_UV - 0.5) * screen / zoom;
	// lighting follows the broad swell only, so glints are smooth sheens rather than speckle
	float e = max(6.0, 3.0 / max(zoom, 0.05));
	float h = sea(w), hs = swell_h(w);
	vec2 grad = vec2(swell_h(w + vec2(e, 0.0)) - hs, swell_h(w + vec2(0.0, e)) - hs) / e;
	vec3 n = normalize(vec3(-grad * 220.0, 1.0));
	vec3 l = normalize(vec3(sun_dir, 0.9));
	float diff = clamp(dot(n, l), 0.0, 1.0);
	float spec = pow(clamp(dot(reflect(-l, n), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 40.0);
	vec3 col = mix(deep, shallow, smoothstep(0.3, 0.75, h));
	col *= 0.82 + 0.3 * diff;
	col += vec3(0.75, 0.8, 0.78) * spec * 0.12 * clamp(zoom * 2.0, 0.2, 1.0);
	vec2 v = SCREEN_UV - 0.5; col *= 1.0 - dot(v, v) * 0.75;
	COLOR = vec4(col, 1.0);
}
