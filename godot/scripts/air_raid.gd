class_name AirRaid extends Control
## A short, watchable air raid over a land structure. The outcome is settled before it starts (Structures.strike);
## this only shows it: the strike group comes in from the sea, the defending fighters rise to meet it, flak bursts
## round the formation, the bombs fall on the installation and the survivors turn for home. About 16 seconds; Skip,
## Space or Esc ends it at once.

signal done
var res: Dictionary
var s: Dictionary
var t := 0.0
const DUR := 16.0
var planes := []      # ours: {off, fate ("ok", "fighter", "flak"), tdie, bomb, dropped}
var foes := []        # defending fighters: {side, tdie}
var booms := []       # bomb bursts on the target: {p, t0, k}
var puffs := []       # flak bursts: {p, t0}
var falls := []       # aircraft going down: {p, v, a, t0, ours}
var smoke := []       # smoke columns over the target: {p, t0}
var tracers := []
var C := Vector2.ZERO
var R := 200.0
var face := 0.0
var _ended := false
var _sfx_t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	face = float(s.get("face", 0.0))
	var r := RandomNumberGenerator.new(); r.seed = int(s.id) * 31 + int(res.planes) * 7 + int(Time.get_ticks_msec() % 1000)
	var n := mini(int(res.planes), 18); var k := float(n) / maxf(1.0, float(res.planes))
	var lost_f := int(round(int(res.lost_fighters) * k)); var lost_a := int(round(int(res.lost_flak) * k))
	for i in n:
		var vic := i / 3; var pos := i % 3   # vics of three, the vics stepped back in echelon
		var vo := Vector2(-(vic / 2) * 95.0, ((vic % 2) * 2 - 1) * 55.0 * (1 + vic / 2) * 0.6)
		var po: Vector2 = [Vector2(0, 0), Vector2(-26, -24), Vector2(-26, 24)][pos]
		var fate := "ok"
		if i >= n - lost_f: fate = "fighter"
		elif i >= n - lost_f - lost_a: fate = "flak"
		planes.append({"off": vo + po + Vector2(r.randf_range(-3, 3), r.randf_range(-3, 3)), "fate": fate,
			"tdie": r.randf_range(3.8, 6.8) if fate == "fighter" else r.randf_range(6.8, 9.0), "bomb": 8.6 + i * 0.08 + r.randf_range(0, 0.4), "dropped": false})
	var nf := mini(int(res.fighters), 12)
	for i in nf: foes.append({"off": Vector2(r.randf_range(-120, 120), r.randf_range(-120, 120)), "tdie": (r.randf_range(4.0, 7.0) if i < int(res.downed) else 99.0), "ph": r.randf() * TAU})
	var flak_n := int(clampf(float(res.flak) * 9.0, 4.0, 60.0))
	for i in flak_n: puffs.append({"t0": r.randf_range(6.0, 10.5), "o": Vector2(r.randf_range(-170, 90), r.randf_range(-150, 150))})
	var hits := mini(int(res.bombers), 30)
	for i in hits: booms.append({"t0": 9.0 + i * 0.09 + r.randf_range(0, 0.5), "o": Vector2.from_angle(r.randf() * TAU) * r.randf() * 0.85, "k": r.randf_range(0.7, 1.3)})
	var skip := UI.button("Skip ▸", func(): _end(), true); skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.set_anchor_and_offset(SIDE_LEFT, 1, -130); skip.set_anchor_and_offset(SIDE_TOP, 1, -60); skip.set_anchor_and_offset(SIDE_RIGHT, 1, -20); skip.set_anchor_and_offset(SIDE_BOTTOM, 1, -22)
	add_child(skip)

func _end() -> void:
	if _ended: return
	_ended = true; done.emit()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT: _end()
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e.keycode == KEY_ESCAPE or e.keycode == KEY_SPACE): get_viewport().set_input_as_handled(); _end()

func _process(dt: float) -> void:
	t += dt
	if t >= DUR: _end(); return
	C = size / 2 + Vector2(0, 30); R = minf(size.x, size.y) * 0.33
	# sound: flak, the bombs, the fighters' guns
	for p in puffs: if not p.get("heard", false) and t >= p.t0: p.heard = true; Sfx.event("aa40", 0.18)
	for b in booms: if not b.get("heard", false) and t >= b.t0: b.heard = true; Sfx.event("hit_big", 0.35 * b.k, randf_range(0.8, 1.1)); smoke.append({"p": C + b.o * R, "t0": t})
	_sfx_t -= dt
	if foes.size() and t > 3.0 and t < 7.5 and _sfx_t <= 0.0: _sfx_t = 0.35; Sfx.event("aa20", 0.12)
	for pl in planes:
		if pl.fate != "ok" and not pl.get("fell", false) and t >= pl.tdie:
			pl.fell = true; falls.append({"p": _plane_pos(pl, pl.tdie), "a": _heading(pl.tdie), "t0": t, "ours": true})
	for f in foes:
		if not f.get("fell", false) and t >= f.tdie: f.fell = true; falls.append({"p": _foe_pos(f, f.tdie), "a": randf() * TAU, "t0": t, "ours": false})
	queue_redraw()

## The strike group's track: in from the sea to the target by about 9 s, then a turn away for home.
func _group(tt: float) -> Vector2:
	var from := C + Vector2.from_angle(face) * size.length() * 0.42
	var out := C + Vector2.from_angle(face + 1.6) * size.length() * 0.7
	if tt < 9.2: return from.lerp(C, 1.0 - pow(1.0 - tt / 9.2, 1.3))
	return C.lerp(out, pow(clampf((tt - 9.2) / 6.0, 0.0, 1.0), 1.3))
func _heading(tt: float) -> float: return (_group(tt + 0.1) - _group(tt)).angle()
func _plane_pos(pl: Dictionary, tt: float) -> Vector2: return _group(tt) + pl.off.rotated(_heading(tt))
func _foe_pos(f: Dictionary, tt: float) -> Vector2:
	# up from behind the target, into the strike group on its way in, then (the survivors) away inland
	var land := C - Vector2.from_angle(face) * size.length() * 0.3
	var k := clampf((tt - 1.5) / 2.0, 0.0, 1.0)
	var p: Vector2 = land.lerp(_group(tt), k) + f.off * (1.0 - 0.5 * k) + Vector2(sin(tt * 2.3 + f.ph), cos(tt * 1.9 + f.ph)) * 45.0 * k
	if tt > 7.2: p = p.lerp(land, clampf((tt - 7.2) / 2.0, 0.0, 1.0))
	return p

func _draw() -> void:
	# the ground, the sea on the structure's seaward side, the installation as it is at this moment
	InstallationArt.landscape(self, Rect2(Vector2.ZERO, size), int(s.id), Campaign.y_lat(s.y), C, R * 1.1)
	var u := Vector2.from_angle(face)
	if Structures.kind(s).military and s.kind != "airfield" and s.kind != "radar" or s.kind == "navalbase":
		var shore := C + u * R * (0.72 if s.kind == "navalbase" else 0.62); var n := Vector2(-u.y, u.x) * 3000.0
		draw_colored_polygon(PackedVector2Array([shore + n, shore - n, shore - n + u * 3000.0, shore + n + u * 3000.0]), Color("#23414a"))
		draw_line(shore + n, shore - n, Color(0.6, 0.72, 0.75, 0.6), 4.0)
	var dmg_now: float = lerpf(float(res.before), float(res.after), clampf((t - 9.0) / 3.0, 0.0, 1.0))
	InstallationArt.draw(self, s.kind, C, R, int(s.id), face, dmg_now, float(res.ruin) * clampf((t - 9.0) / 3.0, 0.0, 1.0), false, t)
	# bomb bursts and the smoke that follows them, drifting downwind
	for b in booms:
		var a: float = t - b.t0
		if a < 0.0: continue
		var p: Vector2 = C + b.o * R
		if a < 1.2:   # the burst: a white flash, a fireball cooling to red, a ring of blast and earth thrown out
			var k := a / 1.2; var rr: float = R * 0.1 * b.k
			draw_circle(p, rr * (0.6 + 1.2 * k), Color(0.25, 0.2, 0.15, 0.6 * (1.0 - k)))
			draw_circle(p, rr * (0.5 + 0.8 * k), Color(1.0, 0.55 - 0.3 * k, 0.15, 0.95 * (1.0 - k)))
			if k < 0.3: draw_circle(p, rr * 0.5, Color(1.0, 0.97, 0.85, 1.0 - k / 0.3))
			draw_arc(p, rr * 2.5 * k, 0, TAU, 24, Color(0.95, 0.9, 0.8, 0.45 * (1.0 - k)), 2.0)
	for sm in smoke:
		var a: float = t - sm.t0
		for j in 5:
			var q: Vector2 = sm.p + Vector2(18.0, -8.0) * (a * 0.6 + j * 0.8) + Vector2(sin(j * 1.7) * 6.0, 0)
			draw_circle(q, 10.0 + j * 5.0 + a * 3.0, Color(0.18, 0.17, 0.16, clampf(0.45 - j * 0.07 - a * 0.015, 0.0, 0.5)))
	# our aircraft, with their shadows on the ground
	var jet: bool = res.jets
	for pl in planes:
		if pl.get("fell", false) or t > 15.5: continue
		var p := _plane_pos(pl, t); var h := _heading(t)
		_aircraft(p + Vector2(55, 75), h, 17.0, Color(0, 0, 0, 0.13), jet)
		_aircraft(p, h, 17.0, Color("#56646d"), jet)
		if not pl.dropped and t >= pl.bomb and t < pl.bomb + 0.6: draw_circle(p.lerp(C, (t - pl.bomb) / 0.6 * 0.4), 2.5, Color(0.15, 0.15, 0.15))
	# the defending fighters and their gunfire
	for f in foes:
		if f.get("fell", false) or t < 1.5 or t > 9.5: continue
		var p := _foe_pos(f, t); var tg := _group(t)
		_aircraft(p + Vector2(45, 60), (tg - p).angle(), 14.0, Color(0, 0, 0, 0.12), false)
		_aircraft(p, (tg - p).angle(), 14.0, Color("#857f5a"), false)
		if t > 3.5 and t < 7.5 and fmod(t * 7.0 + f.ph, 1.0) < 0.35:
			draw_line(p, p + (tg - p).normalized() * 60.0, Color(1.0, 0.85, 0.5, 0.8), 1.2)
	# flak: a flash, then a black puff that spreads and thins
	for pf in puffs:
		var a: float = t - pf.t0
		if a < 0.0 or a > 3.0: continue
		var p: Vector2 = _group(pf.t0) + pf.o
		if a < 0.12: draw_circle(p, 7.0, Color(1.0, 0.8, 0.4, 0.9))
		draw_circle(p, 6.0 + a * 7.0, Color(0.09, 0.09, 0.09, 0.75 * (1.0 - a / 3.0)))
	# aircraft going down, trailing smoke
	for fl in falls:
		var a: float = t - fl.t0
		if a > 4.0: continue
		var p: Vector2 = fl.p + Vector2.from_angle(fl.a) * a * 40.0 + Vector2(0, a * a * 6.0)
		for j in 8: draw_circle(p - Vector2.from_angle(fl.a) * j * 9.0 - Vector2(0, j * 2.0), 3.0 + j * 1.6, Color(0.15, 0.14, 0.13, 0.5 * (1.0 - j / 8.0) * (1.0 - a / 4.0)))
		if a < 2.5: _aircraft(p, fl.a + a * 2.5, 17.0 * (1.0 - a / 4.0), Color("#5f6c74") if fl.ours else Color("#7d7a5c"), jet and fl.ours)
		if a < 2.5: draw_circle(p, 3.0, Color(1.0, 0.6, 0.2, 0.9))
	# the caption
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, size.x, 64), Color(0.03, 0.07, 0.09, 0.75))
	draw_string(font, Vector2(24, 30), "AIR STRIKE · " + s.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#eef0ec"))
	var phase := "Strike group inbound: %d aircraft" % int(res.planes)
	if t > 3.0 and int(res.fighters) > 0: phase = "Fighters rising to meet the strike"
	if t > 6.0: phase = "Over the target: flak"
	if t > 8.8: phase = "Bombs away"
	if t > 11.5: phase = "Defences %d%% out of action  ·  %d aircraft lost  ·  turning for home" % [int(float(res.after) * 100), int(res.lost_fighters) + int(res.lost_flak)]
	draw_string(font, Vector2(24, 52), phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e3b23c"))

## An aircraft from above: fuselage, wings, tailplane (swept wings for a jet).
func _aircraft(p: Vector2, a: float, s: float, col: Color, jet: bool) -> void:
	var u := Vector2.from_angle(a); var v := Vector2(-u.y, u.x)
	var pts: PackedVector2Array
	if jet:   # swept wings
		pts = PackedVector2Array([p + u * s, p + u * s * 0.4 + v * s * 0.12, p - u * s * 0.25 + v * s * 1.0, p - u * s * 0.45 + v * s * 1.0, p - u * s * 0.3 + v * s * 0.12,
			p - u * s * 0.75 + v * s * 0.45, p - u * s * 0.9 + v * s * 0.45, p - u * s * 0.95, p - u * s * 0.9 - v * s * 0.45, p - u * s * 0.75 - v * s * 0.45,
			p - u * s * 0.3 - v * s * 0.12, p - u * s * 0.45 - v * s * 1.0, p - u * s * 0.25 - v * s * 1.0, p + u * s * 0.4 - v * s * 0.12])
	else:     # straight tapered wings, a tailplane, a round cowling
		pts = PackedVector2Array([p + u * s, p + u * s * 0.35 + v * s * 0.14, p + u * s * 0.3 + v * s * 1.05, p + u * s * 0.05 + v * s * 1.1, p - u * s * 0.05 + v * s * 0.14,
			p - u * s * 0.7 + v * s * 0.08, p - u * s * 0.72 + v * s * 0.45, p - u * s * 0.9 + v * s * 0.45, p - u * s * 0.95,
			p - u * s * 0.9 - v * s * 0.45, p - u * s * 0.72 - v * s * 0.45, p - u * s * 0.7 - v * s * 0.08, p - u * s * 0.05 - v * s * 0.14,
			p + u * s * 0.05 - v * s * 1.1, p + u * s * 0.3 - v * s * 1.05, p + u * s * 0.35 - v * s * 0.14])
	if Geometry2D.triangulate_polygon(pts).is_empty(): return
	draw_colored_polygon(pts, col)
	if col.a > 0.5: draw_line(p + u * s * 0.9, p - u * s * 0.6, col.lightened(0.25), s * 0.1)   # light along the spine
