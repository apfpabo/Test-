extends Node
## Screenshots of the owner's lore in the game: the title screen's codex tabs, an origin with its 1946 backstory,
## a port panel with the flag's attitude and a rumour, the pack-ice edge, the chart's pause menu and the fleet list. xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_codex.tscn -- <dir>
var f := 0
var out := ""
var menu: Control
var map: Node
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    menu = load("res://scenes/main_menu.tscn").instantiate(); add_child(menu)
func _shot(name: String) -> void: get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
func _press(root: Node, text: String) -> void:
    for c in root.find_children("*", "Button", true, false): if c.text == text and c.is_visible_in_tree(): c.pressed.emit(); return
func _process(_d: float) -> void:
    f += 1
    if f == 5: _press(menu, "The world")
    if f == 10: _shot("codex_world"); _press(menu, "The Meridian War")
    if f == 15: _shot("codex_history"); _press(menu, "The powers")
    if f == 20: _shot("codex_powers"); _press(menu, "Mysteries")
    if f == 25: _shot("codex_mysteries"); _press(menu, "Back")
    if f == 30: for c in menu.find_children("*", "Button", true, false): if c.text.begins_with("The Hijacker") and c.is_visible_in_tree(): c.pressed.emit()
    if f == 35:
        _shot("origin_hijacker"); menu.queue_free()
        Campaign.new_game("commission")
        map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
    if f == 45:
        for p in Campaign.G.ports: if p.name == "Port Saffron": map.open_port(p)
    if f == 52: _shot("port_saffron"); map.close_panel(); map.free_cam = true; map.cam = Vector2(Campaign.lon_x(15.0), Campaign.lat_y(72.0)); map.zoom = 1.6
    if f == 60: _shot("ice_edge"); map._pause_menu()
    if f == 66: _shot("pause_menu"); map.cmd_tab = "fleet"; map.show_command()
    if f == 72: _shot("command_fleet"); get_tree().quit()
