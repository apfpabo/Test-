extends Node
## The contact panel for a raider flotilla of motor torpedo boats, and one for a battleship (the lead ship's plan
## must sit inside its box). xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_contact.tscn -- <dir>
var f := 0
var out := ""
var map: Node
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]; seed(3)
	Campaign.new_game("commission")
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _fleet(types: Array, fac: String) -> Dictionary:
	var fl: Dictionary = Campaign.spawn_fleet("raiders", fac); fl.ships = []
	for t in types: fl.ships.append(Campaign.new_ship(t, null, fac, []))
	return fl
func _process(_d: float) -> void:
	f += 1
	if f == 3: map.close_panel(); map._on_encounter(_fleet(["pt_sboot", "pt_sboot", "pt_elco", "pt_elco"], "raiders"))
	if f == 12: get_viewport().get_texture().get_image().save_png(out + "/contact_pt.png"); map._on_encounter(_fleet(["bb_iowa", "dd_fletcher"], "raiders"))
	if f == 20: get_viewport().get_texture().get_image().save_png(out + "/contact_bb.png"); get_tree().quit()
