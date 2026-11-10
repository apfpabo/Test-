extends Node
## The "IM" monogram for a profile picture (owner's request): iron capitals on the chart's dark teal, inside a
## riveted compass bezel, with the meridian itself in gold. Square, 1080 px; everything sits inside the circle a
## profile picture is cropped to.  xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_monogram.tscn -- <dir>
const S := 1080.0
var vp: SubViewport
var f := 0
class Plate extends Control:
	func _draw() -> void:
		var c := Vector2(540, 540); var gold := Color(0.89, 0.7, 0.24)
		draw_rect(Rect2(0, 0, 1080, 1080), Color("#050d11"))
		for i in 60: draw_circle(c, 760.0 * (1.0 - i / 60.0), Color("#050d11").lerp(Color("#0e2a33"), pow(i / 60.0, 1.6)))   # a glow at the centre
		# the globe behind: parallels and meridians, faint
		for k in [-2, -1, 1, 2]:
			var y: float = c.y + k * 95.0; var hw: float = sqrt(maxf(0.0, 410.0 * 410.0 - (y - c.y) * (y - c.y)))
			draw_line(Vector2(c.x - hw, y), Vector2(c.x + hw, y), Color(0.55, 0.75, 0.78, 0.09), 2.0, true)
		draw_line(Vector2(c.x - 410, c.y), Vector2(c.x + 410, c.y), Color(0.55, 0.75, 0.78, 0.13), 2.0, true)
		for k in [0.35, 0.7]:
			var pts := PackedVector2Array()
			for i in 73: var a: float = i * TAU / 72.0; pts.append(c + Vector2(cos(a) * 410.0 * k, sin(a) * 410.0))
			draw_polyline(pts, Color(0.55, 0.75, 0.78, 0.09), 2.0, true)
		# the bezel: a steel ring, lit from above, with rivets; inside it the compass card's ticks
		draw_arc(c, 482.0, 0, TAU, 180, Color(0.05, 0.06, 0.07), 22.0, true)
		draw_arc(c, 482.0, 0, TAU, 180, Color(0.36, 0.38, 0.39), 14.0, true)
		draw_arc(c, 486.0, PI * 1.05, PI * 1.95, 90, Color(0.8, 0.82, 0.82), 4.0, true)
		draw_arc(c, 478.0, PI * 0.05, PI * 0.95, 90, Color(0.14, 0.15, 0.16), 4.0, true)
		for i in 24:
			var p: Vector2 = c + Vector2.from_angle(i * TAU / 24.0 + TAU / 48.0) * 482.0
			draw_circle(p + Vector2(2, 3), 9.0, Color(0, 0, 0, 0.5)); draw_circle(p, 9.0, Color(0.45, 0.47, 0.47)); draw_circle(p - Vector2(2.5, 2.5), 3.6, Color(0.82, 0.84, 0.82))
		draw_arc(c, 440.0, 0, TAU, 180, Color(0.6, 0.78, 0.8, 0.35), 2.0, true)
		for i in 72:
			var d := Vector2.from_angle(i * TAU / 72.0); var long_: bool = i % 6 == 0
			draw_line(c + d * (414.0 if long_ else 426.0), c + d * 440.0, Color(0.7, 0.85, 0.86, 0.75 if long_ else 0.4), 3.0 if long_ else 2.0, true)
		# the meridian: one gold line from pole to pole, a diamond at the north
		draw_line(c + Vector2(0, -440), c + Vector2(0, 440), Color(gold, 0.95), 5.0, true)
		draw_line(c + Vector2(0, -440), c + Vector2(0, 440), Color(1.0, 0.9, 0.6, 0.5), 1.5, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -470), c + Vector2(17, -440), c + Vector2(0, -410), c + Vector2(-17, -440)]), gold)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -470), c + Vector2(17, -440), c + Vector2(0, -440)]), Color(1.0, 0.88, 0.5))
		draw_circle(c + Vector2(0, 440), 8.0, gold)
func _ready() -> void:
	vp = SubViewport.new(); vp.size = Vector2i(1080, 1080); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.msaa_2d = Viewport.MSAA_4X; add_child(vp)
	var plate := Plate.new(); plate.size = Vector2(S, S); vp.add_child(plate)
	var font: Font = UI.font("cond"); var size := 440
	# each letter stands on its own side of the meridian
	var asc: float = font.get_ascent(size); var cap: float = size * 0.72
	var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/iron_title.gdshader"); mat.set_shader_parameter("top_y", asc - cap); mat.set_shader_parameter("bottom_y", asc)
	var wi: float = font.get_string_size("I", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x; var wm: float = font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var gap := 54.0; var total: float = wi + gap + wm
	var centred: bool = OS.get_cmdline_user_args().size() > 1   # second argument: centre the pair and let the meridian pass behind the iron
	var x0: float = (540.0 - total * 0.5 - 6.0) if centred else 540.0 - (wi + gap * 0.5)   # otherwise the meridian runs through the gap
	var y0: float = 540.0 - (asc - cap) - cap * 0.5
	for it in [["I", x0], ["M", x0 + wi + gap]]:
		for lay in [[Color(0, 0, 0, 0.6), Vector2(12, 16), null], [Color(0.08, 0.08, 0.08, 0.95), Vector2(3, 5), null], [Color.WHITE, Vector2.ZERO, mat]]:
			var l := Label.new(); l.text = it[0]; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size)
			l.add_theme_color_override("font_color", lay[0]); l.position = Vector2(float(it[1]), y0) + lay[1]; if lay[2] != null: l.material = lay[2]
			vp.add_child(l)
func _process(_d: float) -> void:
	f += 1
	if f == 6: vp.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + ("/monogram_centred.png" if OS.get_cmdline_user_args().size() > 1 else "/monogram.png"))
	if f == 8: get_tree().quit()
