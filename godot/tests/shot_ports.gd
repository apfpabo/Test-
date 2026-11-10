extends Node
## Harbour towns, flags and coastlines on the chart: xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_ports.tscn -- <dir>
var map: Node
var f := 0
var out := ""
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("commission"); Settings.sensors = false
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map); Campaign.paused = true
	var p: Dictionary = Campaign.G.ports[0]; map.free_cam = true; map.cam = Vector2(p.x, p.y); map.zoom = 8.0
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _process(_d: float) -> void:
	f += 1
	if f == 8: _shot("port_capital"); var p: Dictionary = Campaign.G.ports[3]; map.cam = Vector2(p.x, p.y); map.zoom = 12.0
	if f == 14: _shot("port_small"); map.zoom = 1.6
	if f == 20: _shot("port_region"); map.cmd_tab = "missions"; map.show_command()
	if f == 28: _shot("port_flags"); get_tree().quit()
