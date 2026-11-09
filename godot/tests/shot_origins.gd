extends Node
## The title screen, the New campaign page with the origins and test mode, and one origin's page:
## res://tests/shot_origins.tscn -- <out dir>
var menu: Control
var f := 0
func _ready() -> void:
    menu = load("res://scenes/main_menu.tscn").instantiate(); get_tree().root.add_child.call_deferred(menu)
func _press(prefix: String) -> void:
    for b in menu.find_children("*", "Button", true, false): if b.text.begins_with(prefix) and b.is_visible_in_tree(): b.pressed.emit(); return
func _process(_d: float) -> void:
    f += 1
    var out: String = OS.get_cmdline_user_args()[0]
    if f == 6: get_viewport().get_texture().get_image().save_png(out + "/title.png")
    if f == 7: _press("New campaign")
    if f == 12: get_viewport().get_texture().get_image().save_png(out + "/new_campaign.png"); _press("The Survivor")
    if f == 18: get_viewport().get_texture().get_image().save_png(out + "/origin.png"); get_tree().quit()
