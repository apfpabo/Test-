extends Node
## Torpedoes in the water: a spread of ours and one of theirs passing near the flagship, at two zooms.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_torps.tscn -- <dir>
var battle: Node
var frame := 0
var out := ""
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	var S = preload("res://scripts/skirmish.gd"); var pr: Dictionary = S.PRESETS[0]
	GameData.pending = {"player": pr.player, "enemy": pr.enemy, "enemy_fac": pr.fac, "player_tech": S.ERA_TECH[pr.era], "enemy_tech": S.ERA_TECH[pr.era], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	frame += 1
	var sim = battle.sim
	if frame == 3:
		var f = sim.flag; battle.paused = false
		for k in 4: sim.torps.append({"pos": f.pos + Vector2.from_angle(f.a + 0.6) * 300.0 + Vector2(k * 40.0, 0), "a": f.a - 0.4 + k * 0.05, "speed": 18.0, "life": 200.0, "dmg": 400, "side": 0, "homing": false, "arm": -30.0})
		for k in 3: sim.torps.append({"pos": f.pos + Vector2.from_angle(f.a - 1.2) * 700.0 + Vector2(0, k * 40.0), "a": f.a + 2.2, "speed": 18.0, "life": 200.0, "dmg": 400, "side": 1, "homing": false, "arm": -30.0})
		battle.cam_free = true; battle.camera.position = f.pos; battle.camera.zoom = Vector2.ONE * 1.0
	if frame == 160: get_viewport().get_texture().get_image().save_png(out + "/torps_close.png"); battle.camera.zoom = Vector2.ONE * 0.4
	if frame == 200: get_viewport().get_texture().get_image().save_png(out + "/torps_far.png"); get_tree().quit()
