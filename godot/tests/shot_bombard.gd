extends Node
## A bombardment from the sea: the panel's button, frames of the shoot (shells in from the sea, the battery's
## guns answering) and the report. xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_bombard.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var bat: Dictionary
var raid
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]; seed(9)
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G
	G.fleet = [Campaign.new_ship("bb_iowa", "Resolute", "player", []), Campaign.new_ship("dd_fletcher", "Petrel", "player", [])]
	G.crew = Campaign.crew_need() + 200
	for s in Structures.all(): if s.kind == "battery" and s.fac == "directorate": bat = s; break
	var w := Structures.coast_point(bat); G.player.x = w.x; G.player.y = w.y
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _process(_d: float) -> void:
	f += 1
	if f == 3: map.close_panel(); map.open_struct(bat)
	if f == 8: _shot("bomb_panel"); map._fly_strike(bat, true); for c in map.panel_layer.get_children(): if c is AirRaid: raid = c
	if raid != null and is_instance_valid(raid):
		for k in [[2.6, "bomb_1"], [5.5, "bomb_2"], [9.5, "bomb_3"]]:
			if raid.t >= k[0] and not raid.has_meta(k[1]): raid.set_meta(k[1], true); _shot(k[1])
	elif f > 10 and f < 500: f = 500
	if f == 505: _shot("bomb_report"); get_tree().quit()
