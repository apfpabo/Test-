extends Node
## The quick battle page's ship editor (13 Nov 2026): a ship picked, refitted, and the battle starts with her fit.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_skirmish.tscn -- <dir>
var page: Node
var f := 0
var out := ""
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	page = load("res://scenes/skirmish.tscn").instantiate(); add_child(page); page.size = get_viewport().get_visible_rect().size
func _process(_d: float) -> void:
	f += 1
	if f == 3:
		page.design_pick.selected = page.ids.find("bb_iowa"); page._add(page.mine)
		page.design_pick.selected = page.ids.find("bb_yamato"); page._add(page.theirs)
		page._edit(page.mine, page.mine_mods, 0)
		page.mine_mods[0].fit[0] = "g460"; page.mine_mods[0].up["fc"] = 1; page._edit(page.mine, page.mine_mods, 0)
	if f == 12:
		var sc: ScrollContainer = page.get_child(1); sc.scroll_vertical = 600
	if f == 18: get_viewport().get_texture().get_image().save_png(out + "/skirmish_editor.png")
	if f == 20:
		var B = load("res://scripts/battle.gd").new()
		var recs: Array = B._recs(page.mine, "player", [], page.mine_mods)
		printerr("mods passed: ", recs[0].fit[0], " ", recs[0].get("up", {}))
		B.free(); get_tree().quit()
