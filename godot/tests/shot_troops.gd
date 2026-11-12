extends Node
## Screenshots of the auxiliaries round: the Research screen, troops under Repairs & crew, the shipyard with the new
## classes, a structure's panel with "Land the troops", and the landing report.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_troops.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var port: Dictionary
var tgt: Dictionary
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    seed(3); Campaign.new_game("commission"); var G: Dictionary = Campaign.G
    G.credits = 400000; G.rp = 120; G.tech = ["radar", "radar+2", "amphib", "dc", "sonar"]
    G.fleet = [Campaign.new_ship("ca_baltimore", "Resolute", "player", G.tech), Campaign.new_ship("ap_haskell", "Pilgrim's Rest", "player", G.tech), Campaign.new_ship("ao_cimarron", "Wellhead", "player", G.tech),
        Campaign.new_ship("ae_hood", "Firebrand", "player", G.tech), Campaign.new_ship("ar_vulcan", "Artificer", "player", G.tech)]
    G.crew = Campaign.crew_need(); G.troops = 900; G.cargo.munitions = 120; G.cargo.steel = 80
    for p in G.ports: if p.name == "Calder Roads": port = p
    for s in Structures.all(): if s.kind == "battery" and s.fac == "directorate": tgt = s; break
    map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _process(_d: float) -> void:
    f += 1
    if f == 5: map.open_port(port); map.port_tab = "research"; map._render_port()
    if f == 14: _shot("research")
    if f == 16: map.port_tab = "fleet"; map._render_port()
    if f == 24: _shot("troops_port")
    if f == 26: map.port_tab = "yard"; map._render_port()
    if f == 30: map._panel_scroll.scroll_vertical = 900
    if f == 36: _shot("yard")
    if f == 38:
        map.close_panel(); var w := Structures.coast_point(tgt); Campaign.G.player.x = w.x; Campaign.G.player.y = w.y; tgt.dmg = 0.6
    if f == 44: map.open_struct(tgt)
    if f == 54: _shot("struct_landing")
    if f == 56: Campaign.G.troops = 1500; map._invade_report(tgt, Structures.invade(tgt))
    if f == 66: _shot("landing_report"); get_tree().quit()
