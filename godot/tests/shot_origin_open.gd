extends Node
## The chart's opening panel for an origin: res://tests/shot_origin_open.tscn -- <out.png> <origin> [navy]
var f := 0
func _ready() -> void:
    var a := OS.get_cmdline_user_args()
    Campaign.new_game(a[1], a[2] if a.size() > 2 else "concord")
    add_child(load("res://scenes/world_map.tscn").instantiate())
func _process(_d: float) -> void:
    f += 1
    if f == 10: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); get_tree().quit()
