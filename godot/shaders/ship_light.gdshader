// Ship plans are baked lit from overhead. Here the side facing the sun is brightened and the far side falls into
// shade, using the sun's direction in the ship's own frame, so lighting stays true at any heading. soot darkens a
// battered hull.
shader_type canvas_item;

uniform vec2 sun_local = vec2(0.0, 1.0); // direction shadows fall, in sprite space (x along the hull, y across)
uniform vec2 size_m = vec2(100.0, 12.0); // sprite size in metres
uniform float beam = 12.0;
uniform float soot = 0.0;

void fragment() {
	vec4 c = COLOR; // already the texture colour times the node's modulate
	vec2 m = (UV - 0.5) * size_m;
	// the hull's sides face port and starboard, so light depends on which side of the centreline a pixel is on
	float across = clamp(m.y / (beam * 0.5), -1.0, 1.0);
	float s = across * normalize(sun_local + vec2(0.0001)).y; // -1 on the sunlit side, +1 on the shaded side
	c.rgb *= mix(1.08, 0.84, s * 0.5 + 0.5);
	c.rgb *= 1.0 - soot * 0.35;
	COLOR = c;
}
