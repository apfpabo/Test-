extends Node
## The game's icon, redrawn from the owner's compass logo (the file itself did not reach the session): a riveted steel
## bezel, a tick ring and a compass rose on the chart's dark teal, transparent outside the bezel.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_icon.tscn -- <dir>   (writes icon.png, 1024 px)
var vp: SubViewport
var f := 0
class Rose extends Control:
	func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void: draw_colored_polygon(PackedVector2Array([a, b, c]), col)
	func _draw() -> void:
		var c := Vector2(512, 512); var k := 1024.0 / 1080.0
		var light := Color("#d0d6d9"); var mid := Color("#7b8789"); var dark := Color("#0b1b22")
		draw_circle(c, 450.0 * k, dark)
		# bezel and rivets
		draw_arc(c, 432.0 * k, 0, TAU, 200, Color("#0a1418"), 34.0 * k, true)
		draw_arc(c, 432.0 * k, 0, TAU, 200, Color("#a9b0b4"), 26.0 * k, true)
		draw_arc(c, 441.0 * k, PI * 1.1, PI * 1.9, 100, Color("#c9cfd2"), 4.0 * k, true)
		for i in 24:
			var p: Vector2 = c + Vector2.from_angle(i * TAU / 24.0 + TAU / 48.0 + PI / 2) * 432.0 * k
			draw_circle(p, 9.0 * k, Color("#6d767a")); draw_circle(p, 7.0 * k, Color("#c4cacd")); draw_circle(p - Vector2(2, 2) * k, 2.6 * k, Color("#f0f3f3"))
		# the card: a fine ring and its ticks
		draw_arc(c, 404.0 * k, 0, TAU, 200, Color(0.55, 0.62, 0.66, 0.6), 2.5 * k, true)
		for i in 72:
			var d := Vector2.from_angle(i * TAU / 72.0); var long_: bool = i % 6 == 0
			draw_line(c + d * (384.0 if long_ else 393.0) * k, c + d * 404.0 * k, Color(0.55, 0.62, 0.66, 0.85 if long_ else 0.55), (4.0 if long_ else 2.5) * k, true)
		# the small points between the cardinals
		for i in 4:
			var d := Vector2.from_angle(PI / 4 + i * PI / 2); var n := d.orthogonal()
			var tip: Vector2 = c + d * 205.0 * k; var root: Vector2 = c + d * 70.0 * k
			_tri(root + n * 38.0 * k, tip, root, Color("#59646f")); _tri(root - n * 38.0 * k, tip, root, Color("#8a9399"))
		# the rose: north long enough to break the bezel, each point in a light and a shaded half
		var lens := [300.0, 330.0, 300.0, 470.0]   # east, south, west, north
		for i in 4:
			var d := Vector2.from_angle(i * PI / 2); var tip: Vector2 = c + d * float(lens[i]) * k
			var a: Vector2 = c + Vector2.from_angle(i * PI / 2 - PI / 4) * 96.0 * k; var b: Vector2 = c + Vector2.from_angle(i * PI / 2 + PI / 4) * 96.0 * k
			_tri(a, tip, c, light if i % 2 == 0 else mid); _tri(b, tip, c, mid if i % 2 == 0 else light)
		draw_circle(c, 72.0 * k, dark); draw_arc(c, 50.0 * k, 0, TAU, 64, light, 12.0 * k, true); draw_circle(c, 16.0 * k, light)
func _ready() -> void:
	vp = SubViewport.new(); vp.size = Vector2i(1024, 1024); vp.transparent_bg = true; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.msaa_2d = Viewport.MSAA_4X; add_child(vp)
	var r := Rose.new(); r.size = Vector2(1024, 1024); vp.add_child(r)
func _process(_d: float) -> void:
	f += 1
	if f == 6: vp.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/icon.png")
	if f == 8: get_tree().quit()
