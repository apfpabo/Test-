extends Node
## Pictures of the save slots page and the key bindings in Settings (12 Nov 2026).
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_saves.tscn -- <dir>
var map: Node
var f := 0
var out := ""
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("merchant"); Campaign.slot_save("Before the Cape run"); Campaign.G.day = 40; Campaign.slot_save("Rich at last")
	Settings.rebind("battle", KEY_T, KEY_L)
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _process(_d: float) -> void:
	f += 1
	if f == 3 and map.panel_open: map.close_panel()
	if f == 6: map._save_slots(true)
	if f == 30: _shot("saves")
	if f == 32: map._pause_settings()
	if f == 40: map._panel_scroll.scroll_vertical = 600
	if f == 60: _shot("keys"); Settings.reset_keys(); for m in Campaign.slots(): Campaign.slot_delete(m.id)
	if f == 62: get_tree().quit()
