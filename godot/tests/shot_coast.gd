extends Node
## Land structures by the coast at Calder Roads, close in, and a course set "for the coast" of the radar station:
## the fleet must arrive without circling. xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_coast.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var st: Dictionary
var P: Dictionary
var turned := 0.0
var lasth := 0.0
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]; seed(1)
	Campaign.new_game("commission")
	P = Campaign.G.player
	for s in Structures.all(): if s.name == "Calder Roads Radar Station": st = s
	print("radar at %.1f,%.1f coastKm %d, on land %s" % [st.x, st.y, int(st.coastKm), Campaign.on_land(st.x, st.y)])
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _process(_d: float) -> void:
	f += 1
	if f == 3: map.close_panel(); map.zoom = 4.0; map.free_cam = true; map.cam = Vector2(st.x, st.y); Campaign.paused = true
	if f == 8:
		get_viewport().get_texture().get_image().save_png(out + "/coast_close.png")
		P.x = P.x - 40.0; map._course_coast(st); lasth = P.h; Campaign.paused = false; map.free_cam = false; map.zoom = 2.5
	if f > 8 and f < 400:
		turned += absf(Campaign.ang_diff(P.h, lasth)); lasth = P.h
		if P.get("route") == null and f > 12:
			print("arrived after %d frames, %.0f degrees of turning, %.1f units from the coast point" % [f - 8, rad_to_deg(turned), Campaign.mdist(P.x, P.y, st.ox, st.oy)])
			get_viewport().get_texture().get_image().save_png(out + "/coast_arrived.png"); f = 400
	if f == 399: print("did not arrive; turned %.0f degrees" % rad_to_deg(turned)); get_viewport().get_texture().get_image().save_png(out + "/coast_arrived.png")
	if f == 402: get_tree().quit()
