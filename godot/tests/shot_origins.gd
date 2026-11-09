extends Node
## Title screen with the origins, and one origin's page: res://tests/shot_origins.tscn -- <out dir>
var menu: Control
var f := 0
func _ready() -> void:
    menu = load("res://scenes/main_menu.tscn").instantiate(); get_tree().root.add_child.call_deferred(menu)
func _process(_d: float) -> void:
    f += 1
    var out: String = OS.get_cmdline_user_args()[0]
    if f == 6: get_viewport().get_texture().get_image().save_png(out + "/title.png")
    if f == 7:
        for b in menu.find_children("*", "Button", true, false): if b.text.begins_with("The Survivor"): b.pressed.emit()
    if f == 12: get_viewport().get_texture().get_image().save_png(out + "/origin.png"); get_tree().quit()
