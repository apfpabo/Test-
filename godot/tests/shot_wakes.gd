extends Node
## A fleet under way on the chart, close up, to check wakes: res://tests/shot_wakes.tscn -- <out.png> [zoom]
var map: Node
var f := 0
func _ready() -> void:
    Campaign.new_game("commission")
    var P = Campaign.G.player
    while Campaign.G.fleet.size() < 3: Campaign.G.fleet.append(Campaign.G.fleet[0].duplicate(true))
    map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
    Campaign.set_course(P, P.x + 300, P.y + 40)
func _process(_d: float) -> void:
    f += 1
    if f == 3: map.zoom = float(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 3.0; Campaign.paused = false; Campaign.map_speed = 4
    for fl in Campaign.G.fleets: fl.cool = 99.0
    if f == 240: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); get_tree().quit()
