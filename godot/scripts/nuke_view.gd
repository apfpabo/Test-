extends Control
## A nuclear strike, shown (owner's request): the installation from the air, the missile coming in, the flash that
## whites out the sky, the fireball and the shock ring racing over the ground, then the stem climbing and the cap
## rolling out into a mushroom cloud that drifts and cools while the dust settles round a crater. The outcome is
## settled before it starts (Structures.nuke); this only shows it. About 14 seconds; Skip, Space or Esc ends it.

signal done
var s: Dictionary          # the structure as it stood before the strike (a copy)
var face := 0.0
var t := 0.0
const DUR := 14.0
const T0 := 1.6            # the moment of the burst
var C := Vector2.ZERO
var R := 200.0
var _ended := false
var _boomed := false
var _rumble := 0.0
var puffs := []            # the cloud: {kind: 0 stem, 1 cap, 2 skirt; a, r, h, s, v, ph}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var r := RandomNumberGenerator.new(); r.seed = int(s.id) * 77 + 5
	for i in 26: puffs.append({"kind": 0, "a": r.randf() * TAU, "r": r.randf_range(0.0, 0.5), "h": float(i) / 26.0, "s": r.randf_range(0.7, 1.15), "v": r.randi() % 4, "ph": r.randf() * TAU})
	for i in 46: puffs.append({"kind": 1, "a": r.randf() * TAU, "r": sqrt(r.randf()), "h": r.randf_range(-0.12, 0.2), "s": r.randf_range(0.75, 1.3), "v": r.randi() % 4, "ph": r.randf() * TAU})
	for i in 34: puffs.append({"kind": 2, "a": i * TAU / 34.0 + r.randf_range(-0.1, 0.1), "r": r.randf_range(0.85, 1.1), "h": 0.0, "s": r.randf_range(0.7, 1.2), "v": r.randi() % 4, "ph": r.randf() * TAU})
	var skip := UI.button("Skip", _end); skip.focus_mode = Control.FOCUS_NONE; add_child(skip)
	skip.set_anchor_and_offset(SIDE_RIGHT, 1.0, -24); skip.set_anchor_and_offset(SIDE_LEFT, 1.0, -110); skip.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -24); skip.set_anchor_and_offset(SIDE_TOP, 1.0, -60)

func _end() -> void:
	if _ended: return
	_ended = true; done.emit()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e.keycode == KEY_SPACE or e.keycode == KEY_ESCAPE): get_viewport().set_input_as_handled(); _end()

func _process(d: float) -> void:
	t += d
	if t >= T0 and not _boomed:
		_boomed = true; Sfx.event("blast", 1.0, 0.45); Sfx.event("hit_big", 1.0, 0.5)
	if t > T0 + 1.2 and _rumble <= 0.0 and t < T0 + 7.0: _rumble = 0.9; Sfx.event("blast", 0.5, 0.35)   # the roll of it, arriving and going on
	_rumble -= d
	if t >= DUR: _end()
	queue_redraw()

func _cloud(i: int) -> Texture2D: return GameData.fx_tex("cloud%d" % (i % 4))
func _blob(tex: Texture2D, p: Vector2, r: float, col: Color) -> void:
	if col.a > 0.01 and r > 0.5: draw_texture_rect(tex, Rect2(p.x - r, p.y - r, 2 * r, 2 * r), false, col)

func _draw() -> void:
	var u := maxf(0.0, t - T0)                       # seconds since the burst
	R = minf(size.x, size.y) * 0.34; C = size / 2 + Vector2(0, size.y * 0.16)
	var shake := Vector2.ZERO
	if u > 0.0 and u < 4.0: shake = Vector2(sin(t * 61.0), cos(t * 47.0)) * 9.0 * (1.0 - u / 4.0)
	draw_set_transform(shake)
	# the ground: the installation as it stood, then what is left of it
	InstallationArt.landscape(self, Rect2(Vector2(-40, -40), size + Vector2(80, 80)), int(s.id), Campaign.y_lat(s.y), C, R * 1.1)
	var gone: bool = u > 0.15
	InstallationArt.draw(self, s.kind, C, R, int(s.id), face, 1.0 if gone else float(s.dmg), 1.0 if gone else float(s.get("ruin", 0.0)), false, t)
	var glow: Texture2D = GameData.glow_tex(); var ring: Texture2D = GameData.ring_tex()
	if u <= 0.0:   # the missile: a thread of smoke down the sky and a spark at its head
		var k := clampf(t / T0, 0.0, 1.0); var from := Vector2(size.x * 0.92, -size.y * 0.1); var head := from.lerp(C, k * k)
		draw_line(from, head, Color(0.92, 0.92, 0.9, 0.5), 2.0); _blob(glow, head, 9.0, Color(1.0, 0.85, 0.6, 0.95))
	else:
		# scorched ground and the crater, spreading out from the centre and staying
		var sc := R * (0.25 + 1.5 * (1.0 - exp(-u * 1.3)))
		_blob(glow, C, sc * 1.25, Color(0.05, 0.04, 0.03, 0.75)); _blob(glow, C, sc * 0.7, Color(0.03, 0.02, 0.02, 0.85))
		draw_arc(C, R * 0.3, 0, TAU, 40, Color(0.32, 0.28, 0.22, 0.6 * clampf(u - 1.0, 0.0, 1.0)), R * 0.03)   # the crater's lip
		# the shock ring over the ground, and the dust it lifts
		var sr := R * (0.3 + u * 1.9); var sa := clampf(1.0 - u / 3.2, 0.0, 1.0)
		_blob(ring, C, sr, Color(1.0, 0.96, 0.88, 0.75 * sa)); _blob(ring, C, sr * 0.82, Color(0.8, 0.72, 0.6, 0.35 * sa))
		# the fireball: white, then yellow, then red as it cools and lifts
		var fb := R * (0.2 + 0.75 * (1.0 - exp(-u * 2.2))); var fa := clampf(1.0 - u / 4.5, 0.0, 1.0)
		var lift := Vector2(0, -R * 1.5 * (1.0 - exp(-u * 0.35)))    # everything hot rises
		_blob(glow, C + lift * 0.5, fb * 2.6, Color(1.0, 0.55, 0.18, 0.55 * fa)); _blob(glow, C + lift * 0.5, fb * 1.6, Color(1.0, 0.8, 0.4, 0.9 * fa)); _blob(glow, C + lift * 0.5, fb, Color(1.0, 0.97, 0.9, fa))
		# the cloud. Seen from high and to one side: the stem climbs up the screen from the ground zero, the cap rolls
		# out at its head, and the dust skirt spreads round its foot
		var H := R * 1.75 * (1.0 - exp(-u * 0.32))                    # how high the head has climbed
		var cap_r := R * (0.25 + 0.95 * (1.0 - exp(-maxf(0.0, u - 0.8) * 0.33)))
		var heat := clampf(1.0 - u / 6.0, 0.0, 1.0)                    # lit from inside while it is young
		var shadow_off := Vector2(R * 0.5, R * 0.42) * clampf(u / 4.0, 0.0, 1.0)
		for pass_ in 2:   # its shadow on the ground first, then the cloud
			for p in puffs:
				var pos: Vector2; var rad: float; var col: Color
				var roll: float = sin(u * 0.9 + float(p.ph)) * 0.06
				match int(p.kind):
					0:
						if float(p.h) * R * 1.75 > H: continue
						pos = C + Vector2(cos(float(p.a)) * float(p.r) * R * 0.16, -float(p.h) * H) ; rad = R * (0.13 + 0.05 * float(p.h)) * float(p.s)
						col = Color(0.42, 0.38, 0.34).lerp(Color(1.0, 0.55, 0.22), heat * 0.6 * (1.0 - float(p.h)))
					1:
						if u < 0.8: continue
						var rr: float = float(p.r) * cap_r * (1.0 + roll)
						pos = C + Vector2(cos(float(p.a)) * rr, -H + sin(float(p.a)) * rr * 0.42 + float(p.h) * cap_r); rad = cap_r * 0.36 * float(p.s)
						var under: float = clampf(0.5 + sin(float(p.a)) * 0.5, 0.0, 1.0)   # the underside faces the fire
						col = Color(0.78, 0.76, 0.73).lerp(Color(0.38, 0.34, 0.31), under * 0.7).lerp(Color(1.0, 0.5, 0.2), heat * under * 0.55)
					_:
						var kr: float = R * (0.3 + 1.25 * (1.0 - exp(-u * 0.55))) * float(p.r)
						pos = C + Vector2(cos(float(p.a)), sin(float(p.a)) * 0.6) * kr; rad = R * (0.1 + 0.07 * minf(u, 4.0) / 4.0) * float(p.s)
						col = Color(0.56, 0.5, 0.42, 0.75 * clampf(1.0 - u / 11.0, 0.0, 1.0))
				var alpha: float = clampf(u * 1.6, 0.0, 1.0) * (col.a if int(p.kind) == 2 else 0.92)
				if pass_ == 0:
					if int(p.kind) != 2: _blob(_cloud(int(p.v)), Vector2(pos.x, C.y + (pos.y - C.y) * 0.25) + shadow_off, rad * 1.1, Color(0, 0, 0, 0.22 * alpha))
				else: _blob(_cloud(int(p.v)), pos, rad, Color(col.r, col.g, col.b, alpha))
		_blob(glow, C + Vector2(0, -H), cap_r * 1.4, Color(1.0, 0.6, 0.25, 0.3 * heat))   # the glow inside the head
	draw_set_transform(Vector2.ZERO)
	# the flash: the whole sky white, then fading through yellow
	if u > 0.0 and u < 2.6:
		var f := 1.0 - u / 2.6
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97 - 0.12 * (1.0 - f), 0.9 - 0.35 * (1.0 - f), f * f))
	# caption
	var fnt: Font = UI.font("cond"); var cap: String = ("MISSILE RUNNING · THE %s" if u <= 0.0 else "THE %s") % String(s.name).to_upper()
	draw_rect(Rect2(0, 44, size.x, 76), Color(0.02, 0.03, 0.04, 0.55))   # under the top bar: the Command tabs sit over the foot of the screen
	draw_string(fnt, Vector2(28, 84), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.93, 0.94, 0.92))
	if u > 3.0: draw_string(ThemeDB.fallback_font, Vector2(28, 106), "Nothing will stand here again.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.38, 0.29))
