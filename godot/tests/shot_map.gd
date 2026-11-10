extends Node
## Screenshots of the chart at world, default and close zoom, and of the port panel.
var map: Node
var f := 0
var out := ""
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    Campaign.new_game("commission")
    map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _process(_d: float) -> void:
    f += 1
    if f == 5:
        var P = Campaign.G.player
        Campaign.set_course(P, Campaign.lon_x(25.0), Campaign.lat_y(45.0))
        for i in 600:
            for fl in Campaign.G.fleets: fl.cool = 99.0
            Campaign.update(1.0 / 30.0)
        map.zoom = 0.9
    if f == 12: get_viewport().get_texture().get_image().save_png(out + "/m_default.png"); map.zoom = 0.16
    if f == 20: get_viewport().get_texture().get_image().save_png(out + "/m_world.png"); map.zoom = 8.0
    if f == 28: get_viewport().get_texture().get_image().save_png(out + "/m_close.png"); _strait("Tarsene Gate", 2.5)
    if f == 31: get_viewport().get_texture().get_image().save_png(out + "/m_strait.png"); _strait("Kessel Canal", 8.0)
    if f == 34: get_viewport().get_texture().get_image().save_png(out + "/m_canal.png"); _strait("Corvo Canal", 3.0)
    if f == 37: get_viewport().get_texture().get_image().save_png(out + "/m_corvo.png"); map.free_cam = false; map.zoom = 0.9; map.open_port(Campaign.G.ports[0])
    if f == 40: get_viewport().get_texture().get_image().save_png(out + "/m_port.png"); Campaign.G.rp = 200; map.port_tab = "yard"; map._render_port()
    var tabs = {48: "refit", 56: "officers", 64: "research", 72: "admiralty"}
    if tabs.has(f): get_viewport().get_texture().get_image().save_png(out + "/m_tab_%d.png" % f); map.port_tab = tabs[f]; map._render_port()
    if f == 80: get_viewport().get_texture().get_image().save_png(out + "/m_tab_80.png"); map.cmd_tab = "missions"; map.show_command()
    if f == 88: get_viewport().get_texture().get_image().save_png(out + "/m_cmd.png"); get_tree().quit()

## Close-ups of a choke point: the chart centred on a named strait or canal.
func _strait(name: String, z: float) -> void:
    for st in Campaign.C.STRAITS: if st.name == name: map.free_cam = true; map.cam = Vector2(st.x, st.y); map.zoom = z
