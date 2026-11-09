extends Node
## Screenshot of the chart's right-click menu on a friendly fleet, then of your squadron escorting it.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_context.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var cv
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]; seed(11)
	Campaign.new_game("merchant")
	for fl in Campaign.G.fleets: if fl.kind == "convoy" and not Campaign.hostile_fleet(fl): cv = fl; break
	Campaign.G.player.x = cv.x + 12.0; Campaign.G.player.y = cv.y + 6.0
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _process(_d: float) -> void:
	f += 1
	if f == 3: map.close_panel(); map.zoom = 2.2
	if f == 8: map._context(map.to_screen(Vector2(cv.x, cv.y))); Campaign.paused = true
	if f == 14: get_viewport().get_texture().get_image().save_png(out + "/context_menu.png"); map._context_pick(1)
	if f == 300: get_viewport().get_texture().get_image().save_png(out + "/escorting.png"); get_tree().quit()
