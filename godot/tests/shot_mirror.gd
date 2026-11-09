extends Node
## The flagship's status panel mirroring her (turrets trained, damage taken, a mount knocked out), then an enemy
## battleship that has struck her colours, with the white flag at her stern.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_mirror.tscn -- <dir>
var battle: Node
var frame := 0
var out := ""
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	var S = preload("res://scripts/skirmish.gd"); var pr: Dictionary = S.PRESETS[2]
	GameData.pending = {"player": pr.player, "enemy": pr.enemy, "enemy_fac": pr.fac, "player_tech": S.ERA_TECH[pr.era], "enemy_tech": S.ERA_TECH[pr.era], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	frame += 1
	var sim = battle.sim
	if frame == 3:
		var f = sim.flag
		for m in f.mounts: m.ta = m.slot.arcs[0][0] + 0.9 * (1 if m.slot.x > 0 else -1)   # trained round to port
		f.mounts[0].dead = true
		for i in 6: sim.mark_hit(f, f.pos + Vector2.from_angle(f.a) * randf_range(-80, 80) + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 4.0, true)
		f.eng = 0.6; f.fires.append({"x": 10.0, "y": 0.0, "r": 4.0, "t": 30.0, "st": 0.0})
		battle.paused = true
	if frame == 12:
		get_viewport().get_texture().get_image().save_png(out + "/mirror.png")
		var e = null
		for o in sim.ships: if o.side == 1 and o.d.klass == "bb": e = o
		e.struck = true; battle.cam_free = true; battle.camera.position = e.pos - Vector2.from_angle(e.a) * e.d.L * 0.4; battle.camera.zoom = Vector2.ONE * 3.0; battle.paused = false
	if frame == 60: get_viewport().get_texture().get_image().save_png(out + "/white_flag.png"); get_tree().quit()
