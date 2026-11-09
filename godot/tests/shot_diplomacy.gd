extends Node
## Screenshots of diplomacy: a port's contract board, the commission office, the Missions & diplomacy tab with the
## powers and the news, and a contract target on the chart. xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_diplomacy.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var port: Dictionary
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    seed(3)
    Campaign.new_game("commission")
    for p in Campaign.G.ports: if p.name == "Calder Roads": port = p
    for i in 40: Diplomacy.new_day(); Campaign.G.day += 1   # some news between the powers
    map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _process(_d: float) -> void:
    f += 1
    if f == 5: map.open_port(port); map.port_tab = "contracts"; map._render_port()
    if f == 12:
        _shot("contracts")
        for c in Diplomacy.offers(port): if Diplomacy.can_accept(c) == "": Diplomacy.accept(c)
        Campaign.G.rep.concord = 25; map.port_tab = "commission"; map._render_port()
    if f == 20: _shot("commission"); map.close_panel(); map.cmd_tab = "missions"; map.show_command()
    if f == 28:
        _shot("diplomacy"); map.close_panel()
        var m: Array = Diplomacy.marks()
        if not m.is_empty(): map.free_cam = true; map.cam = Vector2(m[0][0], m[0][1]); map.zoom = 1.2
    if f == 36: _shot("contract_mark"); get_tree().quit()
