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
var booms := []       # bomb bursts on the target: {o, t0, k, burn}
var puffs := []       # flak bursts: {o, t0}
var falls := []       # aircraft going down: {p, v, a, t0, ours}
var C := Vector2.ZERO
var R := 200.0
var face := 0.0
var _ended := false
var _sfx_t := 0.0

const Battle := preload("res://scripts/battle.gd")
var fx: BattleSim          # used only for its particles: the battle's own explosions, smoke, flak and fire
var _fx_t := 0.0
var sky: Node2D

## What the battle's particle renderer asks of its host: the particles, the zoom (one pixel a unit) and the view.
class FxHost extends RefCounted:
	var sim: BattleSim
	var raid: Control
	func zoom() -> float: return 1.0
	func view_rect() -> Rect2: return Rect2(Vector2.ZERO, raid.size)

## The aircraft and the caption, drawn above the smoke.
class SkyLayer extends Node2D:
	var raid
	func _draw() -> void: raid._sky(self)

var naval := false   # a bombardment from the sea: shells instead of aircraft, and the shore's guns answering
var muzzles := []    # the structure's guns firing back: {t0, o}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	face = float(s.get("face", 0.0))
	naval = res.get("mode", "") == "naval"
	if naval: _ready_naval(); return
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
	for i in hits: booms.append({"t0": 9.0 + i * 0.09 + r.randf_range(0, 0.5), "o": Vector2.from_angle(r.randf() * TAU) * r.randf() * 0.85, "k": r.randf_range(0.7, 1.3), "burn": r.randf() < 0.45})
	_setup_fx()   # the battle's effects, in the style chosen in Settings (modern or classic)

## A bombardment: ranging shots, then salvos walking across the target, the shore's guns answering out to sea.
func _ready_naval() -> void:
	var r := RandomNumberGenerator.new(); r.seed = int(s.id) * 17 + int(Time.get_ticks_msec() % 1000)
	for i in int(res.shells): booms.append({"t0": 1.5 + i * (7.0 / float(res.shells)) + r.randf_range(0, 0.3), "o": Vector2.from_angle(r.randf() * TAU) * r.randf() * (0.95 if i > 2 else 1.6), "k": r.randf_range(0.8, 1.3) * (1.25 if res.heavy else 0.9), "burn": r.randf() < 0.35})
	for i in int(round(float(res.guns) * 2.0)): muzzles.append({"t0": 2.5 + r.randf() * 6.0, "o": Vector2.from_angle(face + PI / 2) * r.randf_range(-0.6, 0.6)})
	_setup_fx()

func _setup_fx() -> void:
	fx = BattleSim.new(); fx.modern = Settings.fx_modern
	var host := FxHost.new(); host.sim = fx; host.raid = self
	for kind in ["below", "above", "light"]:
		var d = Battle.Drawer.new(); d.battle = host; d.kind = kind
		if kind == "light": var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; d.material = mat
		add_child(d)
	sky = SkyLayer.new(); sky.raid = self; add_child(sky)
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
	if t >= (11.0 if naval else DUR): _end(); return
	C = size / 2 + Vector2(0, 30); R = minf(size.x, size.y) * 0.33
	var P := BattleSim.P
	if naval:   # the shore's guns answering: flash and smoke at the casemates, splashes out at sea
		for m in muzzles:
			if m.get("fired", false) or t < m.t0: continue
			m.fired = true; Sfx.event("gun_H", 0.3)
			var at: Vector2 = C + m.o * R + Vector2.from_angle(face) * R * 0.2
			fx.fx_muzzle(at, face, "H", 1)
			fx.fx_splash(C + Vector2.from_angle(face + randf_range(-0.5, 0.5)) * R * randf_range(1.3, 2.2), 26.0)
	# flak bursts round the formation
	for p in puffs:
		if p.get("heard", false) or t < p.t0: continue
		p.heard = true; Sfx.event("aa40", 0.18)
		var at: Vector2 = _group(p.t0) + p.o
		fx.part(P.FLAK, at, 2.2, 13.0)
		if fx.modern: fx.part(P.CORE, at, 0.1, 9.0); fx.part(P.GLOW, at, 0.3, 30.0)
		else: fx.part(P.FLASH, at, 0.12, 8.0)
	# the bombs: the battle's explosions, earth thrown up, and fires that keep burning
	for b in booms:
		if b.get("heard", false) or t < b.t0: continue
		b.heard = true; Sfx.event("hit_big", 0.35 * b.k, randf_range(0.8, 1.1))
		var at: Vector2 = C + b.o * R
		if naval and b.o.length() > 1.0 and Vector2(b.o).dot(Vector2.from_angle(face)) > 0.3: fx.fx_splash(at, 30.0 * b.k); continue   # a short one, into the sea
		fx.fx_boom(at, R * 0.11 * b.k, 1.0)
		fx.part(P.DUST, at, 2.4, R * 0.1 * b.k)
		if b.k > 1.15: fx.flash = maxf(fx.flash, 0.5)
	_fx_t -= dt
	if _fx_t <= 0.0:
		_fx_t = 0.12
		for b in booms:
			if not b.burn or t < b.t0 + 0.4: continue
			var at: Vector2 = C + b.o * R + Vector2(randf() - 0.5, randf() - 0.5) * 8.0
			fx.part(P.FIRE, at, 0.7, R * 0.025 * b.k)
			if randf() < 0.5: fx.part(P.SMOKE, at, 6.0 + randf() * 3.0, R * 0.045 * b.k, Vector2(randf() - 0.5, randf() - 0.5) * 6.0, true)
		for fl in falls:   # aircraft going down trail fire and smoke, and burst where they hit the ground
			var a: float = t - fl.t0
			if a < 2.5: var at := _fall_pos(fl, a); fx.part(P.SMOKE, at, 3.5, 7.0, Vector2.ZERO, true); fx.part(P.FIRE, at, 0.3, 4.0)
			elif not fl.get("crashed", false): fl.crashed = true; fx.fx_boom(_fall_pos(fl, 2.5), 14.0, 0.6)
	_sfx_t -= dt
	if foes.size() and t > 3.0 and t < 7.5 and _sfx_t <= 0.0: _sfx_t = 0.35; Sfx.event("aa20", 0.12)
	for pl in planes:
		if pl.fate != "ok" and not pl.get("fell", false) and t >= pl.tdie:
			pl.fell = true; falls.append({"p": _plane_pos(pl, pl.tdie), "a": _heading(pl.tdie), "t0": t, "ours": true})
	for f in foes:
		if not f.get("fell", false) and t >= f.tdie: f.fell = true; falls.append({"p": _foe_pos(f, f.tdie), "a": randf() * TAU, "t0": t, "ours": false})
	fx.fx(dt)
	queue_redraw()
	for c in get_children(): if c is Node2D: c.queue_redraw()

func _fall_pos(fl: Dictionary, a: float) -> Vector2: return fl.p + Vector2.from_angle(fl.a) * a * 40.0 + Vector2(0, a * a * 6.0)

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

## The ground, the sea on the structure's seaward side, the installation as it is at this moment. Smoke and fire
## are drawn over it by the battle's particle renderer, and the aircraft over those (SkyLayer).
func _draw() -> void:
	InstallationArt.landscape(self, Rect2(Vector2.ZERO, size), int(s.id), Campaign.y_lat(s.y), C, R * 1.1)
	var u := Vector2.from_angle(face)
	if Structures.kind(s).military and s.kind != "airfield" and s.kind != "radar" or s.kind == "navalbase":
		var shore := C + u * R * (0.72 if s.kind == "navalbase" else 0.62); var n := Vector2(-u.y, u.x) * 3000.0
		draw_colored_polygon(PackedVector2Array([shore + n, shore - n, shore - n + u * 3000.0, shore + n + u * 3000.0]), Color("#23414a"))
		draw_line(shore + n, shore - n, Color(0.6, 0.72, 0.75, 0.6), 4.0)
	var dmg_now: float = lerpf(float(res.before), float(res.after), clampf((t - 9.0) / 3.0, 0.0, 1.0))
	InstallationArt.draw(self, s.kind, C, R, int(s.id), face, dmg_now, float(res.ruin) * clampf((t - 9.0) / 3.0, 0.0, 1.0), false, t)

func _sky(ci: CanvasItem) -> void:
	if naval: _sky_naval(ci); return
	var jet: bool = res.jets
	for pl in planes:   # our aircraft, with their shadows on the ground
		if pl.get("fell", false) or t > 15.5: continue
		var p := _plane_pos(pl, t); var h := _heading(t)
		_aircraft(ci, p + Vector2(55, 75), h, 17.0, Color(0, 0, 0, 0.13), jet)
		_aircraft(ci, p, h, 17.0, Color("#56646d"), jet)
		if t >= pl.bomb and t < pl.bomb + 0.6: ci.draw_circle(p.lerp(C, (t - pl.bomb) / 0.6 * 0.4), 2.5, Color(0.15, 0.15, 0.15))
	for f in foes:   # the defending fighters and their gunfire
		if f.get("fell", false) or t < 1.5 or t > 9.5: continue
		var p := _foe_pos(f, t); var tg := _group(t)
		_aircraft(ci, p + Vector2(45, 60), (tg - p).angle(), 14.0, Color(0, 0, 0, 0.12), false)
		_aircraft(ci, p, (tg - p).angle(), 14.0, Color("#857f5a"), false)
		if t > 3.5 and t < 7.5 and fmod(t * 7.0 + f.ph, 1.0) < 0.35:
			ci.draw_line(p, p + (tg - p).normalized() * 60.0, Color(1.0, 0.85, 0.5, 0.8), 1.2)
	for fl in falls:   # aircraft going down
		var a: float = t - fl.t0
		if a < 2.5: _aircraft(ci, _fall_pos(fl, a), fl.a + a * 2.5, 17.0 * (1.0 - a / 4.0), Color("#5f6c74") if fl.ours else Color("#7d7a5c"), jet and fl.ours)
	var font := ThemeDB.fallback_font   # the caption
	ci.draw_rect(Rect2(0, 0, size.x, 64), Color(0.03, 0.07, 0.09, 0.75))
	ci.draw_string(font, Vector2(24, 30), "AIR STRIKE · " + s.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#eef0ec"))
	var phase := "Strike group inbound: %d aircraft" % int(res.planes)
	if t > 3.0 and int(res.fighters) > 0: phase = "Fighters rising to meet the strike"
	if t > 6.0: phase = "Over the target: flak"
	if t > 8.8: phase = "Bombs away"
	if t > 11.5: phase = "Defences %d%% out of action  ·  %d aircraft lost  ·  turning for home" % [int(float(res.after) * 100), int(res.lost_fighters) + int(res.lost_flak)]
	ci.draw_string(font, Vector2(24, 52), phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e3b23c"))

## Shells in the last second of their flight, coming in from the sea, and the caption.
func _sky_naval(ci: CanvasItem) -> void:
	for b in booms:
		var a: float = t - (b.t0 - 0.6)
		if a < 0.0 or a > 0.6: continue
		var to: Vector2 = C + b.o * R; var from: Vector2 = to + Vector2.from_angle(face) * size.length() * 0.6
		var head: Vector2 = from.lerp(to, a / 0.6); var dir: Vector2 = (to - from).normalized()
		ci.draw_line(head - dir * 40.0, head, Color(1.0, 0.92, 0.7, 0.45), 2.0); ci.draw_circle(head, 2.2, Color(1.0, 0.95, 0.8))
	var font := ThemeDB.fallback_font
	ci.draw_rect(Rect2(0, 0, size.x, 64), Color(0.03, 0.07, 0.09, 0.75))
	ci.draw_string(font, Vector2(24, 30), "BOMBARDMENT · " + s.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#eef0ec"))
	var phase := "Ranging shots from %d km offshore" % int(res.km)
	if t > 3.0: phase = "Fire for effect"
	if t > 4.0 and float(res.guns) > 0.05: phase = "Fire for effect · the shore's guns are answering"
	if t > 9.0: phase = "Cease fire · defences %d%% out of action" % int(float(res.after) * 100)
	ci.draw_string(font, Vector2(24, 52), phase, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#e3b23c"))

## An aircraft from above: fuselage, wings, tailplane (swept wings for a jet).
func _aircraft(ci: CanvasItem, p: Vector2, a: float, s: float, col: Color, jet: bool) -> void:
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
	ci.draw_colored_polygon(pts, col)
	if col.a > 0.5: ci.draw_line(p + u * s * 0.9, p - u * s * 0.6, col.lightened(0.25), s * 0.1)   # light along the spine
