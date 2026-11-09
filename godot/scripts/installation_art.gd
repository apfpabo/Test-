class_name InstallationArt
## Top-down drawings of land structures, in the chart's muted palette (Rule the Waves 3 plans: no outlines, no bright
## colours), lit from the upper left with shadows cast to the lower right. Used by the chart at close zoom and by the
## air-raid view. Everything is drawn round a centre c with radius R in the canvas item's current units; `face` is
## the bearing towards the sea (gun casemates and piers point that way). Deterministic for a given seed.

const CONCRETE := Color("#8f8b80")
const ASPHALT := Color("#5b5a55")
const EARTH := Color("#76664c")
const ROOF := Color("#7b5d4b")
const ROOF2 := Color("#6c7062")
const TANK := Color("#c8c2b1")
const STEEL := Color("#9aa0a2")
const RAIL := Color("#4a4640")
const SHADOW := Color(0.05, 0.06, 0.05, 0.32)

## draw_colored_polygon, skipping polygons too small or thin to triangulate (they would only log errors).
static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		push_warning("art polygon skipped: " + str(pts)); return
	ci.draw_colored_polygon(pts, col)

static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed * 7919 + 17; return r

static func _box(ci: CanvasItem, c: Vector2, w: float, h: float, a: float) -> PackedVector2Array:
	var u := Vector2.from_angle(a); var v := Vector2(-u.y, u.x)
	return PackedVector2Array([c - u * w / 2 - v * h / 2, c + u * w / 2 - v * h / 2, c + u * w / 2 + v * h / 2, c - u * w / 2 + v * h / 2])

## A building: its shadow to the lower right, then the roof, a lit edge and a ridge.
static func building(ci: CanvasItem, c: Vector2, w: float, h: float, a: float, col: Color, ht: float, ridge := true) -> void:
	var sh := Vector2(1, 1) * ht
	_poly(ci, _box(ci, c + sh, w, h, a), SHADOW)
	_poly(ci, _box(ci, c, w, h, a), col)
	var u := Vector2.from_angle(a); var v := Vector2(-u.y, u.x)
	if ridge: ci.draw_line(c - u * w * 0.48, c + u * w * 0.48, col.lightened(0.18), maxf(h * 0.08, 0.01))
	_poly(ci, _box(ci, c - v * h * 0.4, w, h * 0.2, a), col.lightened(0.1))

static func tank(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(r, r) * 0.35, r, SHADOW)
	ci.draw_circle(c, r, TANK.darkened(0.15)); ci.draw_circle(c - Vector2(r, r) * 0.12, r * 0.82, TANK)
	ci.draw_arc(c, r * 0.5, 0, TAU, 12, TANK.darkened(0.1), r * 0.06)

static func gun_pit(ci: CanvasItem, c: Vector2, r: float, a: float, barrel: float) -> void:
	ci.draw_circle(c, r * 1.25, EARTH.darkened(0.15)); ci.draw_circle(c, r, EARTH.lightened(0.05))
	ci.draw_circle(c + Vector2(r, r) * 0.15, r * 0.55, SHADOW); ci.draw_circle(c, r * 0.5, STEEL.darkened(0.3))
	ci.draw_line(c, c + Vector2.from_angle(a) * barrel, STEEL.darkened(0.45), r * 0.22)

## Bomb craters and scorch: more of them the more of the defences are knocked out.
static func damage(ci: CanvasItem, c: Vector2, R: float, seed: int, dmg: float, ruin: float) -> void:
	var r := _rng(seed + 991)
	for i in int(ruin * 10.0):
		var p := c + Vector2.from_angle(r.randf() * TAU) * r.randf() * R * 0.8
		ci.draw_circle(p, R * r.randf_range(0.08, 0.16), Color(0.12, 0.1, 0.08, 0.35))
	for i in int(dmg * 22.0):
		var p := c + Vector2.from_angle(r.randf() * TAU) * r.randf() * R * 0.9; var cr := R * r.randf_range(0.025, 0.05)
		ci.draw_circle(p, cr * 1.5, Color(0.55, 0.5, 0.42, 0.5)); ci.draw_circle(p, cr, Color(0.16, 0.14, 0.11, 0.9))

## The whole installation. ground: draw the bare ground pad first (the raid view has its own terrain).
static func draw(ci: CanvasItem, kind: String, c: Vector2, R: float, seed: int, face: float, dmg := 0.0, ruin := 0.0, ground := true, t := 0.0) -> void:
	var r := _rng(seed)
	if ground:
		var pad := PackedVector2Array()
		for i in 18: pad.append(c + Vector2.from_angle(i * TAU / 18.0) * R * (0.92 + 0.12 * sin(i * 2.3 + seed)))
		_poly(ci, pad, Color(0.3, 0.29, 0.22, 0.22))
	match kind:
		"airfield": _airfield(ci, c, R, r, face)
		"battery": _battery(ci, c, R, r, face)
		"radar": _radar(ci, c, R, r, t)
		"navalbase": _naval(ci, c, R, r, face)
		"oil": _oil(ci, c, R, r)
		"mine": _mine(ci, c, R, r)
		"farm": _farm(ci, c, R, r)
		"industry": _industry(ci, c, R, r)
	damage(ci, c, R, seed, dmg, ruin)

static func _airfield(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator, face: float) -> void:
	var a := r.randf() * PI
	for k in [[0.0, 1.8], [1.05, 1.45]]:
		var ang: float = a + k[0]; var L: float = R * k[1]
		_poly(ci, _box(ci, c, L, R * 0.1, ang), ASPHALT)
		var u := Vector2.from_angle(ang)
		for i in 9: var p := c + u * L * (-0.42 + i * 0.105); ci.draw_line(p, p + u * L * 0.04, Color(0.85, 0.84, 0.78, 0.7), R * 0.008)
	# perimeter taxiway and dispersal pens
	ci.draw_arc(c, R * 0.72, a + 0.3, a + 2.6, 24, ASPHALT.lightened(0.05), R * 0.035)
	for i in 7:
		var p := c + Vector2.from_angle(a + 0.4 + i * 0.32) * R * 0.8
		ci.draw_arc(p, R * 0.05, a + i * 0.32 + PI * 0.5, a + i * 0.32 + PI * 1.5, 8, EARTH, R * 0.025)
		if r.randf() < 0.7: _plane(ci, p, R * 0.07, a + i * 0.32 + PI)
	var hp := c + Vector2.from_angle(a - 1.2) * R * 0.55
	_poly(ci, _box(ci, hp + Vector2.from_angle(a - 1.2) * R * 0.02, R * 0.62, R * 0.36, a - 1.2 + PI / 2), CONCRETE.darkened(0.12))   # apron
	for i in 3: building(ci, hp + Vector2.from_angle(a - 1.2 + PI / 2) * R * (i - 1) * 0.2 + Vector2.from_angle(a - 1.2) * R * 0.1, R * 0.17, R * 0.2, a - 1.2, ROOF2, R * 0.035)   # hangars
	for i in 3: _plane(ci, hp + Vector2.from_angle(a - 1.2 + PI / 2) * R * (i - 1) * 0.2 - Vector2.from_angle(a - 1.2) * R * 0.08, R * 0.07, a - 1.2 + PI)
	building(ci, c + Vector2.from_angle(a + PI + 0.4) * R * 0.45, R * 0.1, R * 0.1, a, CONCRETE.lightened(0.05), R * 0.06)   # control tower
	building(ci, c + Vector2.from_angle(a + PI + 0.75) * R * 0.5, R * 0.2, R * 0.09, a, ROOF, R * 0.03)   # barracks
	for i in 5: gun_pit(ci, c + Vector2.from_angle(a + i * TAU / 5.0 + 0.2) * R * 0.95, R * 0.035, r.randf() * TAU, R * 0.05)

static func _plane(ci: CanvasItem, p: Vector2, s: float, a: float) -> void:
	var u := Vector2.from_angle(a); var v := Vector2(-u.y, u.x)
	ci.draw_line(p - u * s * 0.5, p + u * s * 0.5, STEEL.lightened(0.15), s * 0.18)
	ci.draw_line(p + u * s * 0.1 - v * s * 0.55, p + u * s * 0.1 + v * s * 0.55, STEEL.lightened(0.15), s * 0.16)
	ci.draw_line(p - u * s * 0.42 - v * s * 0.2, p - u * s * 0.42 + v * s * 0.2, STEEL, s * 0.12)

static func _battery(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator, face: float) -> void:
	var v := Vector2.from_angle(face + PI / 2)
	# trench line and earthworks behind the guns
	var tr := PackedVector2Array()
	for i in 9: tr.append(c - Vector2.from_angle(face) * R * 0.35 + v * R * (-0.8 + i * 0.2) + Vector2.from_angle(face) * R * 0.06 * ((i % 2) * 2 - 1))
	ci.draw_polyline(tr, EARTH.darkened(0.3), R * 0.04)
	for i in 3:
		var p := c + Vector2.from_angle(face) * R * 0.15 + v * R * (i - 1) * 0.45
		building(ci, p, R * 0.3, R * 0.24, face, CONCRETE, R * 0.04, false)
		ci.draw_circle(p, R * 0.09, CONCRETE.darkened(0.25))
		ci.draw_line(p, p + Vector2.from_angle(face + r.randf_range(-0.25, 0.25)) * R * 0.38, STEEL.darkened(0.5), R * 0.045)
	building(ci, c - Vector2.from_angle(face) * R * 0.6, R * 0.22, R * 0.14, face + PI / 2, CONCRETE.darkened(0.1), R * 0.03, false)   # magazine
	building(ci, c - Vector2.from_angle(face) * R * 0.15 + v * R * 0.85, R * 0.12, R * 0.12, face, CONCRETE.lightened(0.05), R * 0.06, false)   # range-finding tower
	for i in 3: gun_pit(ci, c - Vector2.from_angle(face) * R * 0.75 + v * R * (i - 1) * 0.6, R * 0.04, r.randf() * TAU, R * 0.06)

static func _radar(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator, t: float) -> void:
	ci.draw_arc(c, R * 0.85, 0, TAU, 36, Color(0.3, 0.3, 0.26, 0.7), R * 0.012)   # wire fence
	for k in 2:
		var m := c + Vector2(R * (k * 0.5 - 0.3), -R * 0.1)
		var s := R * 0.11
		ci.draw_line(m + Vector2(s, s) * 2.0, m + Vector2(s, s) * 2.8, SHADOW, s * 0.4)   # the mast's long shadow
		ci.draw_rect(Rect2(m - Vector2(s, s), Vector2(s, s) * 2), STEEL.darkened(0.3), false, R * 0.012)
		ci.draw_line(m - Vector2(s, s), m + Vector2(s, s), STEEL.darkened(0.3), R * 0.01); ci.draw_line(m + Vector2(-s, s), m + Vector2(s, -s), STEEL.darkened(0.3), R * 0.01)
		var aa := t * (0.9 + k * 0.4) + k
		ci.draw_line(m - Vector2.from_angle(aa) * R * 0.2, m + Vector2.from_angle(aa) * R * 0.2, STEEL.lightened(0.2), R * 0.035)
	building(ci, c + Vector2(R * 0.1, R * 0.4), R * 0.3, R * 0.14, 0.0, ROOF2, R * 0.03)   # plotting room
	building(ci, c + Vector2(-R * 0.4, R * 0.35), R * 0.14, R * 0.12, 0.3, ROOF, R * 0.025)
	ci.draw_circle(c + Vector2(R * 0.45, R * 0.05), R * 0.09, CONCRETE.lightened(0.1))   # height-finder dish
	ci.draw_arc(c + Vector2(R * 0.45, R * 0.05), R * 0.06, 0, TAU, 12, CONCRETE.darkened(0.2), R * 0.015)
	for i in 3: gun_pit(ci, c + Vector2.from_angle(i * TAU / 3.0 + 0.5) * R * 0.7, R * 0.035, r.randf() * TAU, R * 0.05)

static func _naval(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator, face: float) -> void:
	var u := Vector2.from_angle(face); var v := Vector2(-u.y, u.x)
	_poly(ci, _box(ci, c + u * R * 0.25, R * 0.5, R * 1.5, face), CONCRETE.darkened(0.05))   # the quay apron
	for i in 3: _poly(ci, _box(ci, c + u * R * 0.68 + v * R * (i - 1) * 0.45, R * 0.5, R * 0.08, face), CONCRETE)   # piers
	ci.draw_arc(c + u * R * 0.55, R * 0.95, face - 0.9, face + 0.9, 20, CONCRETE.darkened(0.2), R * 0.06)   # breakwater
	for i in 2: for j in 2: tank(ci, c - u * R * (0.25 + i * 0.22) + v * R * (0.35 + j * 0.22), R * 0.09)
	building(ci, c - u * R * 0.15 - v * R * 0.4, R * 0.38, R * 0.16, face + PI / 2, ROOF2, R * 0.04)   # repair shop
	building(ci, c - u * R * 0.5 - v * R * 0.25, R * 0.18, R * 0.12, face, ROOF, R * 0.03)
	_poly(ci, _box(ci, c + u * R * 0.2 - v * R * 0.62, R * 0.55, R * 0.07, face), CONCRETE.lightened(0.08))   # slipway
	for i in 4: gun_pit(ci, c + Vector2.from_angle(face + PI + (i - 1.5) * 0.7) * R * 0.85, R * 0.035, face, R * 0.05)

static func _oil(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator) -> void:
	for i in 3: for j in 3: tank(ci, c + Vector2(R * (0.15 + i * 0.2), R * (-0.25 + j * 0.2)), R * 0.075)
	building(ci, c + Vector2(-R * 0.25, R * 0.15), R * 0.3, R * 0.18, 0.0, ROOF2, R * 0.04)   # refinery
	for k in 3: ci.draw_line(c + Vector2(-R * 0.1, R * (0.08 + k * 0.06)), c + Vector2(R * 0.12, R * (-0.2 + k * 0.17)), STEEL.darkened(0.2), R * 0.012)
	ci.draw_circle(c + Vector2(-R * 0.15, -R * 0.1), R * 0.035, Color(0.35, 0.33, 0.3))   # stack
	for i in 10:   # derricks across the field
		var p := c + Vector2.from_angle(r.randf() * TAU) * R * r.randf_range(0.45, 0.9); var s := R * 0.05
		_poly(ci, PackedVector2Array([p + Vector2(s, s) * 0.6 + Vector2(-s, s), p + Vector2(s, s) * 0.6 + Vector2(s, s), p + Vector2(s, s) * 0.6 + Vector2(0, -s * 1.2)]), SHADOW)
		ci.draw_polyline(PackedVector2Array([p + Vector2(-s, s), p + Vector2(0, -s * 1.2), p + Vector2(s, s), p + Vector2(-s, s)]), STEEL.darkened(0.35), R * 0.01)

static func _mine(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator) -> void:
	for i in 4:   # spoil heaps
		var p := c + Vector2.from_angle(1.0 + i * 1.4) * R * r.randf_range(0.45, 0.75); var s := R * r.randf_range(0.14, 0.22)
		s *= 0.75
		ci.draw_circle(p + Vector2(s, s) * 0.3, s, SHADOW)
		for k in 4: ci.draw_circle(p - Vector2(s, s) * 0.1 * k, s * (1.0 - k * 0.2), Color("#5d5850").lightened(k * 0.06))
	ci.draw_line(c + Vector2(-R, R * 0.3), c + Vector2(R, R * 0.05), RAIL, R * 0.02)
	building(ci, c + Vector2(R * 0.05, R * 0.15), R * 0.6, R * 0.15, -0.12, ROOF2, R * 0.04)   # rolling mill
	building(ci, c + Vector2(-R * 0.25, -R * 0.2), R * 0.2, R * 0.16, 0.2, ROOF, R * 0.04)
	var h := c + Vector2(R * 0.2, -R * 0.2)   # headframe
	ci.draw_line(h + Vector2(R, R) * 0.08, h + Vector2(R, R) * 0.2, SHADOW, R * 0.04)
	ci.draw_polyline(PackedVector2Array([h + Vector2(-R * 0.06, R * 0.06), h, h + Vector2(R * 0.06, R * 0.06)]), STEEL.darkened(0.4), R * 0.02)
	ci.draw_circle(h, R * 0.03, STEEL)
	for i in 2: ci.draw_circle(c + Vector2(R * (0.35 + i * 0.1), R * 0.0), R * 0.035, Color(0.3, 0.28, 0.26))   # chimneys
	for i in 3: gun_pit(ci, c + Vector2.from_angle(i * TAU / 3.0 + 0.3) * R * 0.95, R * 0.035, r.randf() * TAU, R * 0.05)

static func _farm(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator) -> void:
	var a := r.randf_range(-0.4, 0.4); var cols := [Color("#7d8a4e"), Color("#9c9358"), Color("#6c7a46"), Color("#a8955e"), Color("#87804c")]
	for i in 4: for j in 4:
		var p := c + Vector2(R * (i - 1.5) * 0.42, R * (j - 1.5) * 0.42).rotated(a)
		if p.distance_to(c) > R * 0.95: continue
		var col: Color = cols[r.randi() % cols.size()]
		_poly(ci, _box(ci, p, R * 0.4, R * 0.4, a), col)
		for k in 4: var q := p + Vector2(R * (-0.15 + k * 0.1), 0).rotated(a); ci.draw_line(q - Vector2(0, R * 0.18).rotated(a), q + Vector2(0, R * 0.18).rotated(a), col.darkened(0.12), R * 0.01)
	ci.draw_line(c + Vector2(-R, R * 0.1).rotated(a), c + Vector2(R, -R * 0.05).rotated(a), RAIL, R * 0.02)
	for i in 3: tank(ci, c + Vector2(R * (0.05 + i * 0.12), -R * 0.08).rotated(a), R * 0.05)   # silos
	building(ci, c + Vector2(-R * 0.18, R * 0.02).rotated(a), R * 0.25, R * 0.12, a, ROOF, R * 0.03)   # depot sheds
	building(ci, c + Vector2(-R * 0.5, -R * 0.3).rotated(a), R * 0.12, R * 0.08, a, ROOF, R * 0.02)

static func _industry(ci: CanvasItem, c: Vector2, R: float, r: RandomNumberGenerator) -> void:
	for k in 3: ci.draw_line(c + Vector2(-R, R * (0.4 + k * 0.05)), c + Vector2(R, R * (0.35 + k * 0.05)), RAIL, R * 0.015)
	for i in 3:
		var p := c + Vector2(R * (i - 1) * 0.42, -R * 0.05)
		building(ci, p, R * 0.36, R * 0.5, 0.0, ROOF2 if i % 2 else ROOF, R * 0.05, false)
		for k in 6: ci.draw_line(p + Vector2(-R * 0.17, R * (-0.22 + k * 0.08)), p + Vector2(R * 0.17, R * (-0.22 + k * 0.08)), Color(0.85, 0.85, 0.8, 0.35), R * 0.01)   # sawtooth glazing
	for i in 3: var ch := c + Vector2(R * (-0.5 + i * 0.4), -R * 0.42); ci.draw_line(ch, ch + Vector2(R, R) * 0.15, SHADOW, R * 0.05); ci.draw_circle(ch, R * 0.045, Color(0.32, 0.28, 0.25))
	building(ci, c + Vector2(R * 0.55, R * 0.2), R * 0.16, R * 0.14, 0.0, CONCRETE, R * 0.03)
	for i in 4: gun_pit(ci, c + Vector2.from_angle(i * TAU / 4.0 + 0.4) * R * 0.95, R * 0.035, r.randf() * TAU, R * 0.05)

## A small map symbol for normal zoom: a dark disc ringed in the owner's colour, with a pale glyph for the kind.
static func icon(ci: CanvasItem, kind: String, c: Vector2, s: float, ring: Color, w: float, dim := false) -> void:
	ci.draw_circle(c, s * 1.15, Color(0.07, 0.1, 0.1, 0.78))
	ci.draw_arc(c, s * 1.15, 0, TAU, 20, ring, w)
	var g := Color(0.92, 0.9, 0.82, 0.45 if dim else 0.95); var lw := w * 0.8
	match kind:
		"farm": for k in 3: var o := (k - 1) * s * 0.45; ci.draw_line(c + Vector2(o - s * 0.35, s * 0.5), c + Vector2(o + s * 0.35, -s * 0.5), g, lw)
		"mine": ci.draw_line(c + Vector2(-s, -s) * 0.55, c + Vector2(s, s) * 0.55, g, lw); ci.draw_line(c + Vector2(s, -s) * 0.55, c + Vector2(-s, s) * 0.55, g, lw); ci.draw_line(c + Vector2(-s * 0.75, -s * 0.35), c + Vector2(-s * 0.35, -s * 0.75), g, lw * 1.6)
		"oil": ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.5, s * 0.6), c + Vector2(0, -s * 0.65), c + Vector2(s * 0.5, s * 0.6)]), g, lw); ci.draw_line(c + Vector2(-s * 0.25, s * 0.0), c + Vector2(s * 0.25, s * 0.0), g, lw)
		"industry": ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, s * 0.5), c + Vector2(-s * 0.7, -s * 0.1), c + Vector2(-s * 0.25, -s * 0.5), c + Vector2(-s * 0.25, -s * 0.1), c + Vector2(s * 0.2, -s * 0.5), c + Vector2(s * 0.2, -s * 0.1), c + Vector2(s * 0.7, -s * 0.5), c + Vector2(s * 0.7, s * 0.5), c + Vector2(-s * 0.7, s * 0.5)]), g, lw)
		"airfield": ci.draw_line(c + Vector2(-s * 0.75, s * 0.2), c + Vector2(s * 0.75, -s * 0.2), g, lw * 1.7); ci.draw_line(c + Vector2(-s * 0.3, -s * 0.7), c + Vector2(s * 0.3, s * 0.7), g, lw * 1.7)
		"battery": ci.draw_circle(c + Vector2(-s * 0.2, s * 0.15), s * 0.38, g); ci.draw_line(c + Vector2(-s * 0.2, s * 0.15), c + Vector2(s * 0.75, -s * 0.55), g, lw * 1.5)
		"radar": ci.draw_arc(c + Vector2(0, s * 0.45), s * 0.75, -PI * 0.85, -PI * 0.15, 10, g, lw); ci.draw_arc(c + Vector2(0, s * 0.45), s * 0.4, -PI * 0.85, -PI * 0.15, 8, g, lw); ci.draw_circle(c + Vector2(0, s * 0.45), s * 0.12, g)
		"navalbase": ci.draw_line(c + Vector2(0, -s * 0.65), c + Vector2(0, s * 0.6), g, lw); ci.draw_line(c + Vector2(-s * 0.35, -s * 0.3), c + Vector2(s * 0.35, -s * 0.3), g, lw); ci.draw_arc(c + Vector2(0, s * 0.1), s * 0.5, 0.2, PI - 0.2, 10, g, lw); ci.draw_circle(c + Vector2(0, -s * 0.72), s * 0.12, g)

## Countryside round an installation, seen from a few thousand feet: the ground colour by climate, fields, copses
## and woods, a road or two. Fills `rect`; the installation's own pad is kept clear.
static func landscape(ci: CanvasItem, rect: Rect2, seed: int, lat: float, keep: Vector2, keep_r: float) -> void:
	var ground := Color("#727650") if absf(lat) < 40 else Color("#66704f")
	if absf(lat) > 15 and absf(lat) < 34: ground = Color("#9a8b62")
	if absf(lat) > 55: ground = Color("#6d7462")
	ci.draw_rect(rect, ground)
	var r := _rng(seed + 5)
	var fcols := [ground.lightened(0.08), ground.darkened(0.06), ground.lerp(Color("#a4975f"), 0.35), ground.lerp(Color("#5f6e3f"), 0.4)]
	for i in 70:   # field patchwork
		var p := rect.position + Vector2(r.randf(), r.randf()) * rect.size; var w := r.randf_range(40, 120); var h := r.randf_range(30, 90)
		if p.distance_to(keep) < keep_r * 0.9: continue
		_poly(ci, _box(ci, p, w, h, r.randf_range(-0.3, 0.3)), fcols[r.randi() % fcols.size()])
	for i in 3:   # roads
		var a := Vector2(rect.position.x, rect.position.y + r.randf() * rect.size.y); var b := Vector2(rect.end.x, rect.position.y + r.randf() * rect.size.y)
		if i == 1: a = Vector2(rect.position.x + r.randf() * rect.size.x, rect.position.y); b = keep
		var pts := PackedVector2Array()
		for k in 21: var q := a.lerp(b, k / 20.0); pts.append(q + Vector2(0, sin(k * 0.7 + i) * 18.0))
		ci.draw_polyline(pts, Color("#a59a7a"), 3.0)
	for w in 9:   # woods: clumps of trees, each with its shadow
		var c := rect.position + Vector2(r.randf(), r.randf()) * rect.size; var wr := r.randf_range(40, 110)
		if c.distance_to(keep) < keep_r + wr * 0.5: continue
		for k in int(wr * 0.9):
			var p := c + Vector2.from_angle(r.randf() * TAU) * sqrt(r.randf()) * wr; var tr := r.randf_range(3.5, 7.5)
			ci.draw_circle(p + Vector2(tr, tr) * 0.6, tr, Color(0.08, 0.1, 0.06, 0.35))
			ci.draw_circle(p, tr, Color("#3f5233").lerp(Color("#566b3e"), r.randf()))
