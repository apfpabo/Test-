extends Node
## Screenshots of your own flag: founding it (Command, Holdings), storming a port, the report, the Governor's office
## and the chart with your port. xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_flag.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var port: Dictionary
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    seed(5); Campaign.new_game("commission"); var G: Dictionary = Campaign.G
    G.credits = 400000; G.tech = ["amphib"]
    G.fleet = [Campaign.new_ship("ca_baltimore", "Resolute", "player", G.tech), Campaign.new_ship("ap_haskell", "Pilgrim's Rest", "player", G.tech), Campaign.new_ship("ap_haskell", "Long Road", "player", G.tech)]
    G.crew = Campaign.crew_need(); G.troops = 2600
    for s in Structures.all(): if s.kind == "navalbase": s.fac = "player"; s.from = ""; s.took = G.day; s.garrison = Structures.garrison_need(s); break
    for p in G.ports: if p.fac == "directorate" and not p.capital and (port.is_empty() or float(p.get("garrison", 1)) < float(port.get("garrison", 1))): port = p
    G.player.x = port.sx; G.player.y = port.sy; G.rep.directorate = -70
    map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _process(_d: float) -> void:
    f += 1
    if f == 5: map._cmd_tab("holdings")
    if f == 14: _shot("flag_found")
    if f == 16: Flag.found("Meridian Company"); map.close_panel()
    if f == 22: map.open_port(port)
    if f == 32: _shot("flag_storm")
    if f == 34:
        seed(2); var r := Flag.assault(port)
        while not r.won: Campaign.G.troops = 2600; r = Flag.assault(port)
        map._storm_report(port, r)
    if f == 44: _shot("flag_report")
    if f == 46:
        Flag.build(port, "battery"); Campaign.G.day = int(Campaign.G.day) + 31; Flag.build(port, "customs"); Flag.raise_guard(port)
        var sh: Dictionary = Campaign.new_ship("dd_narvik", "Sturmvogel", "directorate", []); sh.pal = "player"; sh.cameFrom = "directorate"; sh.hullFrac = 0.7; port.volunteers = [sh]
        Campaign.G.rep.concord = 14
        map.open_port(port); map.port_tab = "governor"; map._render_port()
    if f == 56: _shot("flag_governor")
    if f == 58: map.close_panel(); map.cur_port = {}
    if f == 64: map._blocking = false; map.close_panel(); map.cmd_tab = "holdings"; map.show_command()   # (straight to the drawer: a contact that came up while the clock ran used to keep the tab from opening)
    if f == 74: _shot("flag_chancery"); map.close_panel()
    if f == 84: _shot("flag_chart"); get_tree().quit()
