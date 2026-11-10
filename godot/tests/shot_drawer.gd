extends Node
## The Command drawer on each of its tabs: xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_drawer.tscn -- <dir>
var map: Node
var f := 0
var out := ""
const TABS := ["fleet", "officers", "research", "missions", "holdings", "hold", "codex"]
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	for t in ["bb", "cv_essex", "ca", "cl", "dd", "dd", "ao_cimarron"]: G.fleet.append(Campaign.new_ship(t, null, "player", []))
	G.crew = Campaign.crew_need(); G.officers.append(Campaign.new_officer(3)); G.officers.append(Campaign.new_officer(5))
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map); Campaign.paused = true
func _process(_d: float) -> void:
	f += 1
	for i in TABS.size():
		if f == 6 + i * 8: map.cmd_tab = TABS[i]; map.show_command()
		if f == 12 + i * 8: get_viewport().get_texture().get_image().save_png("%s/drawer_%s.png" % [out, TABS[i]])
	if f == 14 + TABS.size() * 8: get_tree().quit()
