// Gun mounts, baked in neutral grey with their height packed in: R = grey, G = height (metres / h_max), A = alpha.
// The flag's paint is applied here (tint = the paint colour; the bake used a 50% reference grey), and the roof, sloped plates, edges and
// rangefinder hoods are lit from the sun's direction, so turrets stand apart from the deck and from each other at any
// heading. Per draw, the vertex colour carries: rg = direction shadows fall in the texture's frame (0..1 encoded),
// b = 0 for a wrecked mount, otherwise 0.5 + 0.1 per superfiring level (raised turrets read a little lighter).
shader_type canvas_item;

uniform vec3 tint = vec3(1.0);
uniform float h_max = 40.0;
uniform float px_per_m = 20.0;
uniform float sun_k = 1.0; // shadow length per metre of height
varying vec4 vc;

void vertex() { vc = COLOR; }


void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 col = vec3(t.r / 0.502) * tint * 0.94;
	vec2 sd = normalize(vc.rg * 2.0 - 1.0 + vec2(0.0001));
	vec2 fw = max(fwidth(UV), vec2(1e-6));
	vec2 mpu = 1.0 / (TEXTURE_PIXEL_SIZE * px_per_m); // metres per unit of UV
	vec4 a = texture(TEXTURE, UV + vec2(fw.x, 0.0)), b = texture(TEXTURE, UV - vec2(fw.x, 0.0));
	vec4 cc = texture(TEXTURE, UV + vec2(0.0, fw.y)), d = texture(TEXTURE, UV - vec2(0.0, fw.y));
	float hx = (a.g * a.a - b.g * b.a) * h_max / (2.0 * fw.x * mpu.x);
	float hy = (cc.g * cc.a - d.g * d.a) * h_max / (2.0 * fw.y * mpu.y);
	vec3 n = normalize(vec3(-hx, -hy, 1.0));
	vec3 L = normalize(vec3(-sd, 1.0 / sun_k));
	float ratio = clamp(dot(n, L) / L.z, 0.3, 1.75);
	col *= mix(1.0, ratio, 0.8);
	if (vc.b < 0.25) col *= vec3(0.3, 0.27, 0.25);
	else col *= 1.0 + (vc.b - 0.5) * 0.6;
	COLOR = vec4(col, t.a * vc.a);
}
