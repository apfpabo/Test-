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
// A heeled ship seen from above (lean: metres carried across the ship, towards +y, per metre of height). Everything
// standing above the deck is drawn as the solid it is: each point is carried over by its own height, so a tower leans
// further than a deckhouse, and on the high side the walls that were hidden under their own roofs come into view.
uniform float lean = 0.0;
varying vec4 modc;
void vertex() { modc = COLOR; }

float hat(vec2 uv, float lod) { return textureLod(hmap, uv, lod).r * h_max; }

void fragment() {
	vec4 c = COLOR; // already the texture colour times the node's modulate
	vec2 uv = UV; float wall = 0.0;
	if (use_h && is_top && abs(lean) > 0.01) {
		// which point of the ship is seen here? Look back up the slope from the farthest a roof could have been
		// carried: the first column tall enough to reach this far is the one in front of everything else.
		float al = abs(lean), sg = sign(lean), far = al * h_max;
		vec2 fw0 = max(fwidth(UV), vec2(1e-6)); vec2 ts0 = vec2(textureSize(hmap, 0));
		float lod0 = max(0.0, log2(max(fw0.x * ts0.x, fw0.y * ts0.y)));
		float t = 0.0, stp = far / 28.0; bool hit = false;
		for (int i = 0; i < 28; i++) {
			float tt = far - float(i) * stp;
			if (hat(UV - vec2(0.0, sg * tt / size_m.y), lod0) * al >= tt) { t = tt; hit = true; break; }
		}
		if (hit && t > 0.0) {   // close in on the edge of that column
			float lo = t, hi = t + stp;
			for (int j = 0; j < 6; j++) { float mid = 0.5 * (lo + hi); if (hat(UV - vec2(0.0, sg * mid / size_m.y), lod0) * al >= mid) lo = mid; else hi = mid; }
			t = lo;
			uv = UV - vec2(0.0, sg * t / size_m.y);
			// a roof ends where its own height has carried it; if the column stands well above that, this is its side
			wall = smoothstep(0.25, 0.7, hat(uv, lod0) * al - t);
		}
		c = textureLod(TEXTURE, uv, lod0) * modc;
		if (c.a < 0.5 && wall > 0.0) { c = textureLod(TEXTURE, uv - vec2(0.0, sg * 1.2 / size_m.y), lod0) * modc; }   // the very edge: take the wall's colour from just inside it
	}
	vec2 m = (uv - 0.5) * size_m;
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
			h0 = hat(uv, lod);
			// bevel: the slope across one screen pixel, lit from the sun (elevation: tan = 1 / k)
			float hx = (hat(uv + vec2(fw.x, 0.0), lod) - hat(uv - vec2(fw.x, 0.0), lod)) / (2.0 * fw.x * size_m.x);
			float hy = (hat(uv + vec2(0.0, fw.y), lod) - hat(uv - vec2(0.0, fw.y), lod)) / (2.0 * fw.y * size_m.y);
			vec3 n = normalize(vec3(-hx, -hy, 1.0));
			vec3 L = normalize(vec3(-sd, 1.0 / k));
			float ratio = clamp(dot(n, L) / L.z, 0.3, 1.7);
			c.rgb *= mix(1.0, ratio, 0.75 * (1.0 - wall));
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
			vec2 q = uv - sd * t / size_m;
			if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) break;
			float hq = hat(q, max(lod, log2(max(1.0, stp / texel_m))));
			float soft = 0.25 + 0.5 * stp / k;  // blend across the gap to the next sample, so shadow edges don't step
			sh = max(sh, smoothstep(-soft, soft, hq - (h0 + t / k + 0.15)));
		}
		c.rgb *= 1.0 - 0.38 * sh;
	}
	if (wall > 0.0) {   // her upper works' sides: plain plating, lit if the sun is on the high side, in shade if not
		float lit = clamp(sign(lean) * normalize(sun_local + vec2(0.0001)).y * 0.5 + 0.5, 0.0, 1.0);
		c.rgb = mix(c.rgb, c.rgb * mix(0.45, 0.8, lit), wall);
	}
	c.rgb *= 1.0 - soot * 0.35;
	COLOR = c;
}
