extends RefCounted
## The flags of the powers, drawn (no image files): fictional designs in each power's chart colour. Loaded by path
## (`const Flags = preload("res://scripts/flags.gd")`); `Flags.draw` paints one into a rectangle on any canvas item,
## `Flags.icon` gives a small control for rows of text. See docs/ART.md.

const GOLD := Color(0.89, 0.72, 0.28)
const WHITE := Color(0.93, 0.93, 0.9)
const INK := Color(0.07, 0.08, 0.1)

static func _star(ci: CanvasItem, c: Vector2, r: float, n: int, col: Color, inner := 0.45) -> void:
	var pts := PackedVector2Array()
	for i in n * 2: pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / n) * (r if i % 2 == 0 else r * inner))
	ci.draw_colored_polygon(pts, col)

## A flag in `r`. Every design is a field, one or two bands, and one plain emblem that reads at twelve pixels high.
static func draw(ci: CanvasItem, fac: String, r: Rect2, alpha := 1.0) -> void:
	var w := r.size.x; var h := r.size.y; var o := r.position; var c := o + r.size / 2
	var A := func(col: Color) -> Color: return Color(col.r, col.g, col.b, alpha)
	match fac:
		"concord":   # deep blue, a white band edged in gold, a gold compass star at the hoist
			ci.draw_rect(r, A.call(Color(0.13, 0.25, 0.45)))
			ci.draw_rect(Rect2(o + Vector2(0, h * 0.4), Vector2(w, h * 0.2)), A.call(WHITE))
			ci.draw_rect(Rect2(o + Vector2(0, h * 0.36), Vector2(w, h * 0.04)), A.call(GOLD)); ci.draw_rect(Rect2(o + Vector2(0, h * 0.6), Vector2(w, h * 0.04)), A.call(GOLD))
			ci.draw_circle(o + Vector2(w * 0.25, h * 0.5), h * 0.3, A.call(Color(0.13, 0.25, 0.45))); _star(ci, o + Vector2(w * 0.25, h * 0.5), h * 0.27, 8, A.call(GOLD), 0.4)
		"directorate":   # dark red, a black bar at the hoist, a white gear ring
			ci.draw_rect(r, A.call(Color(0.62, 0.16, 0.12))); ci.draw_rect(Rect2(o, Vector2(w * 0.24, h)), A.call(INK))
			ci.draw_arc(o + Vector2(w * 0.62, h * 0.5), h * 0.24, 0, TAU, 20, A.call(WHITE), maxf(1.0, h * 0.1))
			for i in 8: var a := i * TAU / 8.0; ci.draw_line(o + Vector2(w * 0.62, h * 0.5) + Vector2.from_angle(a) * h * 0.26, o + Vector2(w * 0.62, h * 0.5) + Vector2.from_angle(a) * h * 0.37, A.call(WHITE), maxf(1.0, h * 0.09))
			ci.draw_circle(o + Vector2(w * 0.62, h * 0.5), h * 0.07, A.call(WHITE))
		"pacific":   # violet, a pale disc ringed by six islands
			ci.draw_rect(r, A.call(Color(0.33, 0.25, 0.52)))
			ci.draw_circle(c, h * 0.2, A.call(Color(0.9, 0.86, 0.96)))
			for i in 6: ci.draw_circle(c + Vector2.from_angle(i * TAU / 6.0 - PI / 2) * h * 0.36, h * 0.06, A.call(Color(0.9, 0.86, 0.96)))
		"combine":   # teal, a white bend, a black lozenge
			ci.draw_rect(r, A.call(Color(0.12, 0.42, 0.4)))
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(0, h * 0.72), o + Vector2(0, h), o + Vector2(w * 0.2, h), o + Vector2(w, h * 0.28), o + Vector2(w, 0), o + Vector2(w * 0.8, 0)]), A.call(WHITE))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.24), c + Vector2(h * 0.2, 0), c + Vector2(0, h * 0.24), c + Vector2(-h * 0.2, 0)]), A.call(INK))
		"republic":   # orange, white, orange, with the Gate (two pillars and a lintel) in the white
			ci.draw_rect(r, A.call(Color(0.82, 0.47, 0.18))); ci.draw_rect(Rect2(o + Vector2(0, h * 0.3), Vector2(w, h * 0.4)), A.call(WHITE))
			for sx in [-1.0, 1.0]: ci.draw_rect(Rect2(c + Vector2(sx * h * 0.17 - h * 0.04, -h * 0.13), Vector2(h * 0.08, h * 0.28)), A.call(Color(0.25, 0.16, 0.1)))
			ci.draw_rect(Rect2(c + Vector2(-h * 0.26, -h * 0.17), Vector2(h * 0.52, h * 0.06)), A.call(Color(0.25, 0.16, 0.1)))
		"freeport":   # green, a white chevron from the hoist, a gold coin
			ci.draw_rect(r, A.call(Color(0.2, 0.42, 0.24)))
			ci.draw_colored_polygon(PackedVector2Array([o, o + Vector2(w * 0.42, h * 0.5), o + Vector2(0, h)]), A.call(WHITE))
			ci.draw_circle(o + Vector2(w * 0.68, h * 0.5), h * 0.2, A.call(GOLD)); ci.draw_arc(o + Vector2(w * 0.68, h * 0.5), h * 0.12, 0, TAU, 14, A.call(Color(0.5, 0.38, 0.1)), maxf(1.0, h * 0.05))
		"enclave":   # white, a blue foot, a blue six-armed frost star
			ci.draw_rect(r, A.call(WHITE)); ci.draw_rect(Rect2(o + Vector2(0, h * 0.74), Vector2(w, h * 0.26)), A.call(Color(0.2, 0.36, 0.55)))
			for i in 3: var a := i * PI / 3.0; ci.draw_line(c + Vector2(0, -h * 0.1) - Vector2.from_angle(a) * h * 0.26, c + Vector2(0, -h * 0.1) + Vector2.from_angle(a) * h * 0.26, A.call(Color(0.2, 0.36, 0.55)), maxf(1.0, h * 0.09))
		"ombria":   # terracotta under a black head, a gold sun
			ci.draw_rect(r, A.call(Color(0.68, 0.36, 0.24))); ci.draw_rect(Rect2(o, Vector2(w, h * 0.28)), A.call(INK))
			_star(ci, o + Vector2(w * 0.5, h * 0.62), h * 0.27, 12, A.call(GOLD), 0.62); ci.draw_circle(o + Vector2(w * 0.5, h * 0.62), h * 0.15, A.call(GOLD))
		"isles":   # sea blue, two white waves, a white star
			ci.draw_rect(r, A.call(Color(0.25, 0.5, 0.64)))
			for k in 2:
				var pts := PackedVector2Array(); for i in 13: pts.append(o + Vector2(w * i / 12.0, h * (0.62 + k * 0.18) + sin(i * 1.05) * h * 0.05))
				ci.draw_polyline(pts, A.call(WHITE), maxf(1.0, h * 0.08))
			_star(ci, o + Vector2(w * 0.5, h * 0.3), h * 0.2, 5, A.call(WHITE))
		"raiders":   # black, a yellow hourglass
			ci.draw_rect(r, A.call(INK))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.22, -h * 0.3), c + Vector2(h * 0.22, -h * 0.3), c]), A.call(Color(0.82, 0.63, 0.24)))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.22, h * 0.3), c + Vector2(h * 0.22, h * 0.3), c]), A.call(Color(0.82, 0.63, 0.24)))
		"player":   # your own: gold, a dark anchor
			ci.draw_rect(r, A.call(Color(0.86, 0.68, 0.24)))
			ci.draw_line(c + Vector2(0, -h * 0.3), c + Vector2(0, h * 0.26), A.call(INK), maxf(1.0, h * 0.1)); ci.draw_line(c + Vector2(-h * 0.16, -h * 0.16), c + Vector2(h * 0.16, -h * 0.16), A.call(INK), maxf(1.0, h * 0.09))
			ci.draw_arc(c + Vector2(0, h * 0.04), h * 0.24, 0.25, PI - 0.25, 10, A.call(INK), maxf(1.0, h * 0.09)); ci.draw_circle(c + Vector2(0, -h * 0.32), h * 0.07, A.call(INK))
		_:   # unclaimed: plain grey
			ci.draw_rect(r, A.call(Color(0.5, 0.5, 0.47)))
	ci.draw_rect(r, Color(0, 0, 0, 0.45 * alpha), false, maxf(r.size.y * 0.05, 0.02))   # a hairline edge, in the flag's own scale

## A flag for a row of text.
class Icon extends Control:
	var fac := ""
	func _draw() -> void: load("res://scripts/flags.gd").draw(self, fac, Rect2(Vector2(0, (size.y - custom_minimum_size.y) / 2.0), custom_minimum_size))
static func icon(fac: String, h := 14.0) -> Control:
	var i := Icon.new(); i.fac = fac; i.custom_minimum_size = Vector2(h * 1.55, h); i.mouse_filter = Control.MOUSE_FILTER_IGNORE; i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return i
