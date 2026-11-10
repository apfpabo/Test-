extends Node
## The sensor display on the chart (R): xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_sensors.tscn -- <dir>
## (the battle's is in shot_weather: night, storm or fog at a wide zoom)
var map: Node
var f := 0
var out := ""
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("commission"); Campaign.G.tech.append("radar"); Settings.sensors = true
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map); map.zoom = 0.9
func _process(_d: float) -> void:
	f += 1
	if f == 10: get_viewport().get_texture().get_image().save_png(out + "/sensors_day.png"); Weather.force = {"sea": 2, "fog": false, "night": true, "moon": 0.2}; Campaign._wx = {}; Campaign.set_dark(true)
	if f == 20: get_viewport().get_texture().get_image().save_png(out + "/sensors_night_dark.png"); get_tree().quit()
