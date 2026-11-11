extends Node
## Floatplanes: parked on a cruiser's and a battleship's catapults (drawn as the carriers' piston aircraft), flown off
## to spot, circling the enemy, and home again. Checks the books as well as the pictures.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_float.tscn -- <dir>
var battle: Node
var frame := 0
var out := ""
var bad := 0
func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: bad += 1
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}; Campaign.new_game("commission")
	var a := [Campaign.new_ship("ca_baltimore", "Quincy Bay", "player", []), Campaign.new_ship("bb_iowa", "Sovereign", "player", [])]
	var b := [Campaign.new_ship("ca_hipper", null, "directorate", []), Campaign.new_ship("dd_narvik", null, "directorate", [])]
	GameData.pending = {"player_recs": a, "enemy_recs": b, "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	frame += 1

	var sim = battle.sim
	if frame == 3:
		battle.paused = true; sim.hold_fire = true
		for x in sim.ships: if x.side == 1: for m in x.mounts: if m.w.kind == "aa" or m.w.get("aa", 0) > 0: m.ammo = 0   # (no flak: the test follows her whole flight)
		var ca = sim.ships[0]
		ok(ca.fp == 2 and sim.ships[1].fp == 2, "a Baltimore and an Iowa each carry two floatplanes (%d, %d)" % [ca.fp, sim.ships[1].fp])
		battle.cam_free = true; battle.camera.position = sim.world_pt(ca, -85, 0); battle.camera.zoom = Vector2.ONE * 6.0
	if frame == 8: get_viewport().get_texture().get_image().save_png(out + "/float_parked.png")
	if frame == 10:
		var ca = sim.ships[0]
		ok(sim.launch_spotter(ca) and ca.fp == 1 and sim.spotters.size() == 1, "F flies one off (one left aboard)")
		battle.paused = false
	if frame == 40: get_viewport().get_texture().get_image().save_png(out + "/float_launch.png"); battle.camera.zoom = Vector2.ONE * 0.6
	if frame == 41: for k in 1800: sim.step(0.05)   # three minutes of the action, at once
	if frame == 60:
		var mine: Array = sim.spotters.filter(func(x): return x.ship == sim.ships[0]); var q = mine[0] if not mine.is_empty() else null
		var e = sim.nearest_enemy(sim.ships[0].pos, 0)
		ok(q != null and e != null and q.pos.distance_to(e.pos) < BattleSim.SPOT_ORBIT * 2.2, "she goes out over the enemy (%.0f m off)" % (q.pos.distance_to(e.pos) if q != null and e != null else -1.0))
		ok(q != null and sim.spotter_over(0, e.pos), "and spots there")
		if q != null: battle.camera.position = q.pos; battle.camera.zoom = Vector2.ONE * 3.0
	if frame == 64: get_viewport().get_texture().get_image().save_png(out + "/float_aloft.png")
	if frame == 66:
		for x in sim.spotters: if x.ship == sim.ships[0]: x.t = BattleSim.SPOT_ENDURE + 1.0
		for k in 2400: sim.step(0.05)
	if frame == 70:
		ok(not sim.spotters.any(func(x): return x.ship == sim.ships[0]) and sim.ships[0].fp == 2, "at the end of her endurance she comes home and is hoisted in (%d aboard)" % sim.ships[0].fp)
		print("FLOAT TEST PASSED" if bad == 0 else "FLOAT TEST FAILED (%d)" % bad); get_tree().quit(0 if bad == 0 else 1)
