extends Node
## The nuclear strike view at five moments, and a nuclear plant close up: xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_nuke.tscn -- <dir>
var map: Node
var f := 0
var out := ""
var nv
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("commission"); Settings.sensors = false
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	var plant: Dictionary = Structures.plants_of("concord")[0]
	map.free_cam = true; map.cam = Vector2(plant.x, plant.y); map.zoom = 5.0; Campaign.paused = true
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _process(_d: float) -> void:
	f += 1
	if f == 8:
		_shot("nuke_plant")
		var tgt: Dictionary = Structures.plants_of("directorate")[0]
		nv = preload("res://scripts/nuke_view.gd").new(); nv.s = tgt.duplicate(true); nv.set_anchors_preset(Control.PRESET_FULL_RECT); map.panel_layer.add_child(nv); nv.set_process(false)
	for pair in [[12, 1.0], [16, 1.9], [20, 3.4], [24, 6.5], [28, 12.0]]:
		if f == pair[0]: nv.t = pair[1]; nv.queue_redraw()
		if f == pair[0] + 3: _shot("nuke_t%02d" % int(pair[1] * 10 / 10))
	if f == 34: get_tree().quit()
