extends Node
## How often do shells fall on friends? Ten-a-side and smaller actions fought by the captains alone, counting shell
## hits on the firer's own side against all shell hits. A measurement, not a pass/fail test.
## godot --headless --path godot res://tests/ff_measure.tscn
func _ready() -> void:
	Campaign.new_game("commission")
	var night := {"sea": 0, "fog": false, "night": true, "moon": 0.3}
	var big_a := ["bb_iowa", "bb_kgv", "ca_baltimore", "ca_baltimore", "cl_cleveland", "dd_fletcher", "dd_fletcher", "dd_fletcher", "dd_kclass", "dd_gearing"]
	var big_b := ["bb_bismarck", "bb_scharnhorst", "ca_hipper", "ca_hipper", "cl_agano", "dd_narvik", "dd_narvik", "dd_narvik", "dd_kagero", "dd_kagero"]
	var cases := [
		[big_a, big_b, {}, "ten a side by day"],
		[big_a, big_b, night, "ten a side by night"],
		[["ca_baltimore", "cl_cleveland", "dd_fletcher", "dd_fletcher", "dd_fletcher"], ["ca_hipper", "cl_agano", "dd_narvik", "dd_narvik", "dd_kagero"], {}, "five a side by day"],
		[["dd_fletcher", "dd_fletcher", "dd_fletcher", "dd_gearing"], ["dd_narvik", "dd_narvik", "dd_kagero", "dd_kagero"], night, "destroyers by night"],
	]
	var all_h := 0; var all_f := 0
	for ci in cases.size():
		var cs: Array = cases[ci]; var hits := 0; var ff := 0; var dmg := 0.0; var tot := 0.0
		for rep in 4:
			seed(900 + ci * 10 + rep)
			var sim := BattleSim.new(); sim.wx = Weather.battle(cs[2]) if not cs[2].is_empty() else Weather.CLEAR
			var a := []; var b := []
			for t in cs[0]: a.append(Campaign.new_ship(t, null, "player", []))
			for t in cs[1]: b.append(Campaign.new_ship(t, null, "directorate", []))
			sim.setup(a, b, ["radar"], ["radar"], 0); sim.flag = null
			var steps := 0
			while not sim.finished and steps < 40000: sim.step(0.05); steps += 1
			for k in sim.sys_log: if String(k).begins_with("shell ") and k != "shell on a friend": hits += int(sim.sys_log[k])
			ff += int(sim.sys_log.get("shell on a friend", 0)); dmg += sim.ff_dmg
			for s in sim.ships: tot += s.max_hull - maxf(0.0, s.hull)
		all_h += hits; all_f += ff
		print("%-22s %5d shell hits, %4d on friends (%.1f%%); %.0f of %.0f hull points lost were to friends' shells (%.1f%%)" % [cs[3], hits, ff, 100.0 * ff / maxf(1, hits), dmg, tot, 100.0 * dmg / maxf(1.0, tot)])
	print("ALL: %d hits, %d on friends (%.2f%%)" % [all_h, all_f, 100.0 * all_f / maxf(1, all_h)])
	get_tree().quit()
