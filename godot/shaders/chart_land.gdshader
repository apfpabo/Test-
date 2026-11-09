// Land on the chart: the baked terrain (data/terrain.png, 0.1° per texel) plus fine ground detail that fades in only
// when the chart is zoomed in close, so the coarse texture never shows its texels.
shader_type canvas_item;
varying vec2 wp;
void vertex() { wp = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float px = length(fwidth(wp));                 // map units per screen pixel
	float fade = 1.0 - smoothstep(0.08, 0.5, px);
	if (fade > 0.0) {
		float d = 0.0, amp = 0.5; vec2 q = wp / 2.5;
		for (int i = 0; i < 4; i++) { d += amp * (noise(q) - 0.5); q = q * 2.13 + 17.0; amp *= 0.5; }
		c.rgb *= 1.0 + d * 0.32 * fade;
	}
	COLOR = c;
}
