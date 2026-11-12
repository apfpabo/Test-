extends Node
## Pictures of a tale's pages on the chart (scripts/tales.gd): the example tales' first scenes and a choice followed.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_tales.tscn -- <dir>
var map: Node
var f := 0
var out := ""
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/tale_%s.png" % [out, n])
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("merchant"); Campaign.G.credits = 5000
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _process(_d: float) -> void:
	f += 1
	if f == 3 and map.panel_open: map.close_panel()
	if f == 6: Tales.open("lights_in_the_rain"); map._open_tale()
	if f == 30: _shot("1_sea")
	if f == 32: Tales.choose("won"); map._open_tale()
	if f == 60: _shot("2_won")
	if f == 62: map.close_panel(); Tales.finish(); var p: Dictionary = Campaign.G.ports.filter(func(q): return q.fac == "concord")[0]; Tales.open("requisitioned"); map._open_tale(p)
	if f == 90: _shot("3_port")
	if f == 92: Tales.choose("refuse"); map._open_tale(Campaign.G.ports.filter(func(q): return q.fac == "concord")[0])
	if f == 120: _shot("4_refuse")
	if f == 122: get_tree().quit()
