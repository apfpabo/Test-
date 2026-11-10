extends Node
## A full battle, ten ships a side, timed: godot --headless --path godot res://tests/battle_perf.tscn  (script time a
## frame with no renderer), or under xvfb with -- <dir> to save a screenshot of the HUD with both lists full.
var battle: Node
var f := 0
var times: Array = []
var last := 0
func _ready() -> void:
	seed(9)
	var mine := ["bb_iowa", "bb_kgv", "cv_essex", "ca_baltimore", "cl_cleveland", "dd_fletcher", "dd_fletcher", "dd_fletcher", "dd_kclass", "ddg_adams"]
	var theirs := ["bb_bismarck", "bb_scharnhorst", "ca_hipper", "ca_hipper", "cl_agano", "dd_narvik", "dd_narvik", "dd_narvik", "dd_kagero", "dd_kagero"]
	GameData.pending = {"player": mine, "enemy": theirs, "enemy_fac": "directorate", "player_tech": ["radar", "missiles", "jets"], "enemy_tech": ["radar"], "islands": 2}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	f += 1
	var now := Time.get_ticks_usec()
	if f > 400: times.append((now - last) / 1000.0)
	last = now
	if f == 3: battle.speed_i = 2; battle.sim.flag.throttle = 4
	if f == 700:
		var s := 0.0; var mx := 0.0
		for t in times: s += t; mx = maxf(mx, t)
		var sim = battle.sim
		print("battle 10 v 10 at t=%d s: frame mean %.1f ms, worst %.1f ms; %d shells, %d particles, %d tracers" % [int(sim.t), s / times.size(), mx, sim.shells.size(), sim.parts.size(), sim.tracers.size()])
		var t0 := Time.get_ticks_usec()
		for i in 100: sim.step(0.02)
		var st := (Time.get_ticks_usec() - t0) / 100.0 / 1000.0
		t0 = Time.get_ticks_usec()
		for i in 100: sim.fx(0.02)
		print("  one sim.step %.2f ms (the battle runs %d a frame at this clock); sim.fx %.2f ms" % [st, int(ceil(battle.combat_speed() * 0.0167 * 2.0 / 0.04)) if battle.has_method("combat_speed") else 0, (Time.get_ticks_usec() - t0) / 100.0 / 1000.0])
		var a := OS.get_cmdline_user_args()
		if not a.is_empty(): get_viewport().get_texture().get_image().save_png(a[0] + "/battle_10v10.png")
		get_tree().quit()
