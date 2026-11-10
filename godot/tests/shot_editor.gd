extends Node
## The editor: ships put on the sea, one refitted, one set on another of her own flag, the interface hidden.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_editor.tscn -- <dir>
var battle: Node
var f := 0
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1
func _ready() -> void:
	seed(4)
	GameData.pending = {"editor": true, "player": ["dd_fletcher"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_cmdline_user_args()[0], n])
func _process(_d: float) -> void:
	f += 1
	var sim = battle.sim; var ed = battle.editor
	if f == 3:
		ok(sim.editor and ed != null, "the editor's panel is up")
		ed.design = "bb_iowa"; ed.side = 0; ed.mode = "place"
		ok(ed.click(sim.flag.pos + Vector2(600, 0), false) and sim.ships.size() == 3, "a click puts a battleship on the sea")
		ed.design = "ca_hipper"; ed.side = 1; ed.mode = "place"; ed.click(sim.flag.pos + Vector2(0, -2500), false)
		var bb = sim.ships[2]; var n0: int = bb.mounts.size()
		for i in bb.d.slots.size(): if bb.d.slots[i].s == "A": bb.rec.fit[i] = ""
		sim.fit_mounts(bb); battle.rebuild_view(bb)
		ok(bb.mounts.size() < n0 and bb.view != null, "she is refitted where she lies (%d mounts to %d)" % [n0, bb.mounts.size()])
		var dd = sim.ships[0]; dd.force_tgt = bb   # a ship set on another of her own flag
		ed.pick = bb; ed.rebuild(); battle.speed_i = 5
	if f == 4: battle.camera.zoom = Vector2.ONE * 0.5
	if f == 60: _shot("editor_panel")
	if f == 61:
		ok(sim.ships[2].hull < sim.ships[2].max_hull or sim.shells.size() > 0, "a ship set on one of her own flag fires on her (her hull %d%%, shells in the air %d)" % [int(100.0 * sim.ships[2].hull / sim.ships[2].max_hull), sim.shells.size()])
		ok(not sim.finished, "the action does not end by itself")
		sim.wx = Weather.battle({"sea": 0, "fog": false, "night": true, "moon": 0.9}); battle.apply_weather(); battle.set_clean(true)
	if f == 90: _shot("editor_clean_night")
	if f == 91:
		battle.set_clean(false); sim.set_side(sim.ships[1], 0); battle.rebuild_view(sim.ships[1]); sim.flag = sim.ships[1]
		ok(sim.ships[1].side == 0 and sim.flag == sim.ships[1], "an enemy ship changes flag and is taken in command")
		for o in sim.ships.duplicate(): battle.remove_view(o); sim.despawn(o)
		ok(sim.ships.is_empty() and sim.flag == null, "every ship can be taken off the sea")
	if f == 100:
		ok(true, "and the screen goes on running with the sea empty")
		print("EDITOR TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails); get_tree().quit(1 if fails else 0)
