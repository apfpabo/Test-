// Bloom: the bright parts of the picture (flashes, fires, tracers, sun on spray) bleed light into what is around them.
// One pass over the finished frame: blurred copies of it (the screen texture's mip levels) are sampled on three rings,
// only what is brighter than the threshold is kept, and the sum is added on top.
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float strength = 0.5;
uniform float threshold = 0.8;
vec3 bright(vec2 uv, float lod) {
	vec3 c = textureLod(screen_tex, uv, lod).rgb;
	float l = max(c.r, max(c.g, c.b));
	// warm light (fire, flash) blooms more readily than white foam and grey paint
	float warm = clamp((c.r - c.b) * 2.5, 0.0, 1.0);
	float th = threshold - 0.22 * warm;
	return c * clamp((l - th) / (1.0 - th), 0.0, 1.0);
}
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE; vec3 acc = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854; vec2 d = vec2(cos(a), sin(a));
		acc += bright(SCREEN_UV + d * px * 5.0, 2.0) * 0.5;
		acc += bright(SCREEN_UV + d.yx * px * 14.0, 3.0) * 0.35;
		acc += bright(SCREEN_UV + d * px * 34.0, 4.0) * 0.25;
	}
	acc += bright(SCREEN_UV, 1.0) * 1.2;
	COLOR = vec4(acc / 8.0 * strength, 1.0);
}
