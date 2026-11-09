extends Node
## A hard turn at deep zoom on the chart, as in the owner's video: frames of the ship and its wake turning about.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_turn.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var P: Dictionary
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]; seed(2)
	Campaign.new_game("academy", "pacific")
	P = Campaign.G.player; P.x = Campaign.lon_x(-160.0); P.y = Campaign.lat_y(10.0); P.h = 0.0; P.v = 12.0
	Campaign.G.fleets = []
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _process(_d: float) -> void:
	f += 1
	if f == 3: map.close_panel(); map.zoom = 11.0; Campaign.set_course(P, P.x + 60.0, P.y)
	if f == 60: Campaign.set_course(P, P.x - 8.0, P.y + 6.0)
	for k in [[90, "turn_1"], [130, "turn_2"], [170, "turn_3"], [230, "turn_4"]]:
		if f == k[0]: get_viewport().get_texture().get_image().save_png(out + "/" + k[1] + ".png")
	if f == 240: get_tree().quit()
