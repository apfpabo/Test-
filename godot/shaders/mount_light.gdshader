// Gun mounts, baked in neutral grey with their height packed in: R = grey, G = height (metres / h_max), A = alpha.
// The flag's paint is applied here (tint = the paint colour; the bake used a 50% reference grey), and the roof, sloped plates, edges and
// rangefinder hoods are lit from the sun's direction, so turrets stand apart from the deck and from each other at any
// heading. Per draw, the vertex colour carries: rg = direction shadows fall in the texture's frame (0..1 encoded),
// b = 0 for a wrecked mount, otherwise 0.5 + 0.1 per superfiring level (raised turrets read a little lighter).
// Tower/superstructure cast shadows: samples the ship's superstructure height map (ship_hmap, from top_h.png) along
// the sun vector in ship-frame metres (VERTEX in MountLayer) so bridges, pagoda masts, and funnels cast soft shadows
// across adjacent turret roofs and barrels.
shader_type canvas_item;

uniform vec3 tint = vec3(1.0);
uniform float h_max = 40.0;
uniform float px_per_m = 20.0;
uniform float sun_k = 1.0; // shadow length per metre of height
// A heeled ship (see ship_light.gdshader): lean is metres carried across the ship (+y in her frame) per metre of
// height, and sun_ship the way shadows fall in her frame. The mount's own turn is found by comparing that with the
// sun's direction in the mount's frame (the vertex colour), so the lean runs the same way for a turret trained
// anywhere, and by the same rule as the superstructure: each point carried over by its own height.
uniform float lean = 0.0;
uniform vec2 sun_ship = vec2(0.0, 1.0);
// Superstructure shadow casting onto mounts (set per ShipView on its duplicated mount_mat):
uniform sampler2D ship_hmap : filter_linear_mipmap, repeat_disable;
uniform bool use_ship_h = false;
uniform vec2 ship_size_m = vec2(100.0, 20.0);
uniform float freeboard = 4.0;
// The ship's frame: a point of the battle (MODEL_MATRIX * VERTEX) is turned into metres along and across her by these
// (the inverse of her view's transform, set each frame). VERTEX alone is the mount's own rectangle, not her frame.
uniform vec2 ship_ix = vec2(1.0, 0.0);
uniform vec2 ship_iy = vec2(0.0, 1.0);
uniform vec2 ship_io = vec2(0.0);

varying vec4 vc;
varying vec2 ship_pos_m;

// (a macro, not a function: a function cannot read TEXTURE)
#define H_AT(q) (texture(TEXTURE, (q)).g * texture(TEXTURE, (q)).a * h_max * float((q).x >= 0.0 && (q).y >= 0.0 && (q).x <= 1.0 && (q).y <= 1.0))

float ship_hat(vec2 uv, float lod) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	return textureLod(ship_hmap, uv, lod).r * h_max;
}

void vertex() {
	vc = COLOR;
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	ship_pos_m = ship_ix * wp.x + ship_iy * wp.y + ship_io;
}

void fragment() {
	vec2 sd = normalize(vc.rg * 2.0 - 1.0 + vec2(0.0001));
	vec2 uv0 = UV; float wall = 0.0; float wlit = 0.0;
	if (abs(lean) > 0.01) {
		float ta = atan(sun_ship.y, sun_ship.x) - atan(sd.y, sd.x);            // how far the mount is turned from the ship's axis
		vec2 dir = vec2(sin(ta), cos(ta)) * sign(lean);                        // the ship's low side, in the mount's frame
		vec2 per_m = dir * TEXTURE_PIXEL_SIZE * px_per_m;                      // UV per metre that way
		float al = abs(lean), far = al * 12.0, stp = far / 20.0, tt = 0.0; bool hit = false;
		for (int i = 0; i < 20; i++) { float x = far - float(i) * stp; if (H_AT(UV - per_m * x) * al >= x) { tt = x; hit = true; break; } }
		if (hit && tt > 0.0) {
			float lo = tt, hi = tt + stp;
			for (int j = 0; j < 6; j++) { float mid = 0.5 * (lo + hi); if (H_AT(UV - per_m * mid) * al >= mid) lo = mid; else hi = mid; }
			tt = lo; uv0 = UV - per_m * tt;
			wall = smoothstep(0.2, 0.6, H_AT(uv0) * al - tt);
			if (wall > 0.0 && texture(TEXTURE, uv0).a < 0.5) uv0 -= per_m * 0.3;
			wlit = clamp(sign(lean) * normalize(sun_ship + vec2(0.0001)).y * 0.5 + 0.5, 0.0, 1.0);
		}
	}
	bool inside = uv0.x >= 0.0 && uv0.y >= 0.0 && uv0.x <= 1.0 && uv0.y <= 1.0;
	vec4 t = inside ? texture(TEXTURE, uv0) : vec4(0.0);
	vec3 col = vec3(t.r / 0.502) * tint * 0.94;
	vec2 fw = max(fwidth(UV), vec2(1e-6));
	vec2 mpu = 1.0 / (TEXTURE_PIXEL_SIZE * px_per_m); // metres per unit of UV
	vec4 a = texture(TEXTURE, uv0 + vec2(fw.x, 0.0)), b = texture(TEXTURE, uv0 - vec2(fw.x, 0.0));
	vec4 cc = texture(TEXTURE, uv0 + vec2(0.0, fw.y)), d = texture(TEXTURE, uv0 - vec2(0.0, fw.y));
	float hx = (a.g * a.a - b.g * b.a) * h_max / (2.0 * fw.x * mpu.x);
	float hy = (cc.g * cc.a - d.g * d.a) * h_max / (2.0 * fw.y * mpu.y);
	vec3 n = normalize(vec3(-hx, -hy, 1.0));
	vec3 L = normalize(vec3(-sd, 1.0 / sun_k));
	float ratio = clamp(dot(n, L) / L.z, 0.3, 1.75);
	col *= mix(1.0, ratio, 0.8 * (1.0 - wall));
	col = mix(col, vec3(t.r / 0.502) * tint * mix(0.42, 0.75, wlit), wall);   // her side: plain plating, in light or in shade

	// Superstructure cast shadow across the turret roof and barrels
	if (use_ship_h && t.a > 0.05) {
		float lvl = vc.b >= 0.45 ? max(0.0, (vc.b - 0.5) * 10.0) : 0.0;
		float foot_shift = lean * (freeboard + 2.8 * lvl);
		vec2 sm = vec2(ship_pos_m.x, ship_pos_m.y - foot_shift);
		vec2 suv = sm / max(ship_size_m, vec2(1.0)) + vec2(0.5);
		float h_mount = 2.4 + 2.8 * lvl + t.g * h_max * 0.35;
		vec2 sdir = normalize(sun_ship + vec2(0.0001));
		float k = max(0.3, length(sun_ship));
		vec2 tsz = vec2(textureSize(ship_hmap, 0));
		float texel_m = ship_size_m.x / max(1.0, tsz.x);
		float reach = h_max * 0.75 * k;
		float sh = 0.0, prev = 0.0;
		for (int i = 1; i <= 16; i++) {
			float dist = pow(float(i) / 16.0, 1.4) * reach;
			float stp = dist - prev; prev = dist;
			vec2 q = suv - (sdir * dist) / max(ship_size_m, vec2(1.0));
			if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) break;
			float mip = max(0.0, log2(max(1.0, stp / max(0.05, texel_m))));
			float hq = ship_hat(q, mip);
			float soft = 0.3 + 0.5 * stp / k;
			sh = max(sh, smoothstep(-soft, soft, hq - (h_mount + dist / k + 0.35)));
		}
		col *= 1.0 - 0.34 * sh;
	}

	if (vc.b < 0.25) col *= vec3(0.3, 0.27, 0.25);
	else col *= 1.0 + (vc.b - 0.5) * 0.6;
	COLOR = vec4(col, t.a * vc.a);
}
