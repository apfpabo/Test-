extends Node
## The title screen's settings panel: res://tests/shot_settings.tscn -- <out.png>
var menu: Node
var f := 0
func _ready() -> void:
    menu = load("res://scenes/main_menu.tscn").instantiate(); add_child(menu)
func _process(_d: float) -> void:
    f += 1
    if f == 3:
        for b in menu.find_children("*", "Button", true, false): if b.text == "Settings": b.pressed.emit()
    if f == 8: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); get_tree().quit()
