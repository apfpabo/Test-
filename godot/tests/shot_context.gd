extends Node
## Screenshots of the chart's right-click menu on a friendly fleet, your squadron escorting it, hailing it and trading.
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
	if f == 300: get_viewport().get_texture().get_image().save_png(out + "/escorting.png"); Campaign.G.cargo.fuel = 0; map._hail(cv)
	if f == 306: get_viewport().get_texture().get_image().save_png(out + "/hail.png"); map._trade(cv)
	if f == 312: get_viewport().get_texture().get_image().save_png(out + "/trade.png"); get_tree().quit()
