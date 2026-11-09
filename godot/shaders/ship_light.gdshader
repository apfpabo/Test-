// Ship plans are baked lit from overhead. Here the side facing the sun is brightened and the far side falls into
// shade, using the sun's direction in the ship's own frame, so lighting stays true at any heading. soot darkens a
// battered hull.
// With a height map of everything standing above the deck (hmap: grey = metres / h_max), each change of level is lit
// as a bevel from the sun's direction, and towers, decks and funnels cast shadows across the levels below them
// (is_top) and across the deck (the hull layer), by marching through the height map towards the sun.
shader_type canvas_item;

uniform vec2 sun_local = vec2(0.0, 1.0); // direction shadows fall, in sprite space; length = shadow length per metre of height
uniform vec2 size_m = vec2(100.0, 12.0); // sprite size in metres
uniform float beam = 12.0;
uniform float soot = 0.0;
uniform sampler2D hmap : filter_linear_mipmap, repeat_disable;
uniform bool use_h = false;
uniform bool is_top = false;
uniform float h_max = 40.0;

float hat(vec2 uv, float lod) { return textureLod(hmap, uv, lod).r * h_max; }

void fragment() {
	vec4 c = COLOR; // already the texture colour times the node's modulate
	vec2 m = (UV - 0.5) * size_m;
	// the hull's sides face port and starboard, so light depends on which side of the centreline a pixel is on
	float across = clamp(m.y / (beam * 0.5), -1.0, 1.0);
	vec2 sd = normalize(sun_local + vec2(0.0001));
	float s = across * sd.y; // -1 on the sunlit side, +1 on the shaded side
	c.rgb *= mix(1.08, 0.84, s * 0.5 + 0.5);
	if (use_h) {
		float k = max(0.3, length(sun_local));
		vec2 tsz = vec2(textureSize(hmap, 0));
		vec2 fw = max(fwidth(UV), vec2(1e-6));
		float lod = max(0.0, log2(max(fw.x * tsz.x, fw.y * tsz.y)));
		float h0 = 0.0;
		if (is_top) {
			h0 = hat(UV, lod);
			// bevel: the slope across one screen pixel, lit from the sun (elevation: tan = 1 / k)
			float hx = (hat(UV + vec2(fw.x, 0.0), lod) - hat(UV - vec2(fw.x, 0.0), lod)) / (2.0 * fw.x * size_m.x);
			float hy = (hat(UV + vec2(0.0, fw.y), lod) - hat(UV - vec2(0.0, fw.y), lod)) / (2.0 * fw.y * size_m.y);
			vec3 n = normalize(vec3(-hx, -hy, 1.0));
			vec3 L = normalize(vec3(-sd, 1.0 / k));
			float ratio = clamp(dot(n, L) / L.z, 0.3, 1.7);
			c.rgb *= mix(1.0, ratio, 0.75);
		}
		// cast shadows: is anything between here and the sun tall enough to hide it?
		// cone-traced: farther samples read a blurrier mip, so thin masts and step edges give soft, continuous shadows
		float sh = 0.0;
		float reach = h_max * 0.8 * k;
		float texel_m = size_m.x / tsz.x;
		float prev = 0.0;
		float jit = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))); // per-pixel offset of the samples
		for (int i = 1; i <= 32; i++) {
			float t = pow((float(i) - jit) / 32.0, 1.5) * reach;
			float stp = t - prev; prev = t;
			vec2 q = UV - sd * t / size_m;
			if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) break;
			float hq = hat(q, max(lod, log2(max(1.0, stp / texel_m))));
			float soft = 0.25 + 0.5 * stp / k;  // blend across the gap to the next sample, so shadow edges don't step
			sh = max(sh, smoothstep(-soft, soft, hq - (h0 + t / k + 0.15)));
		}
		c.rgb *= 1.0 - 0.38 * sh;
	}
	c.rgb *= 1.0 - soot * 0.35;
	COLOR = c;
}
