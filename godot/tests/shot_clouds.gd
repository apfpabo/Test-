extends Node
## Close-ups of the chart's weather overlay over the roughest sea of the day: xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_clouds.tscn -- <dir>
var map: Node
var f := 0
var out := ""
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = null
	Campaign.new_game("commission")
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	var best := Vector2.ZERO; var bv := 0.0; var t := Weather.now()
	for j in range(10, 70):
		for i in 180:
			var x := (i + 0.5) * 40.0; var y := (j + 0.5) * 40.0
			var v := Weather.storm(x, y, t)
			if v > bv and v < 0.8 and not Campaign.on_land(x, y): bv = v; best = Vector2(x, y)
	map.free_cam = true; map.cam = best; map.zoom = 1.0; Campaign.paused = true
func _process(_d: float) -> void:
	f += 1
	if f == 8: get_viewport().get_texture().get_image().save_png(out + "/clouds_1.png"); map.zoom = 3.0
	if f == 16: get_viewport().get_texture().get_image().save_png(out + "/clouds_3.png"); map.zoom = 8.0
	if f == 24: get_viewport().get_texture().get_image().save_png(out + "/clouds_8.png"); get_tree().quit()
