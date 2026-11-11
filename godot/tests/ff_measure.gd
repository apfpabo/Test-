extends Node
## How often do shells, torpedoes and depth charges fall on friends? Actions fought by the captains alone, counting hits
## on the firer's own side against all hits, by weapon, and the hull points lost to friends. Each case is fought with
## the captains' care (check fire, torp_fouls, dc_fouls) and again without it, on the same seeds, to show what it saves.
## A measurement, not a pass/fail test.  godot --headless --path godot res://tests/ff_measure.tscn [-- reps]
func _ready() -> void:
	Campaign.new_game("commission")
	var a_ := OS.get_cmdline_user_args(); var reps: int = int(a_[0]) if a_.size() > 0 else 4
	var night := {"sea": 0, "fog": false, "night": true, "moon": 0.3}
	var big_a := ["bb_iowa", "bb_kgv", "ca_baltimore", "ca_baltimore", "cl_cleveland", "dd_fletcher", "dd_fletcher", "dd_fletcher", "dd_kclass", "dd_gearing"]
	var big_b := ["bb_bismarck", "bb_scharnhorst", "ca_hipper", "ca_hipper", "cl_agano", "dd_narvik", "dd_narvik", "dd_narvik", "dd_kagero", "dd_kagero"]
	var cases := [
		[big_a, big_b, {}, "ten a side by day", []],
		[big_a, big_b, night, "ten a side by night", []],
		[["dd_fletcher", "dd_fletcher", "dd_fletcher", "dd_gearing"], ["dd_narvik", "dd_narvik", "dd_kagero", "dd_kagero"], night, "destroyers by night", []],
		[["dd_fletcher", "dd_fletcher", "pt_elco", "pt_elco", "pt_elco"], ["dd_narvik", "dd_kagero", "pt_sboot", "pt_sboot", "pt_sboot"], night, "destroyers and boats mixed, night", []],
		[["dd_fletcher", "dd_fletcher", "dd_gearing", "ss_gato"], ["ss_vii", "ss_vii"], {}, "hunt, a friendly boat about, day", []],
		[["dd_fletcher", "dd_fletcher", "dd_gearing", "ss_gato"], ["ss_xxi", "ss_vii"], night, "hunt, a friendly boat about, night", []],
		[["dd_fletcher", "dd_gearing", "ss_gato", "ss_gato"], ["dd_narvik", "dd_narvik", "ss_vii", "ss_vii"], night, "boats and hunters both sides, night", []],
		[["ss_tang", "ss_tang", "dd_gearing", "dd_gearing"], ["ss_xxi", "ss_xxi", "dd_narvik", "dd_narvik"], {}, "homing torpedoes both sides, day", ["homing"]],
	]
	var tot := {}
	for care in [true, false]:
		print("== captains %s ==" % ("take care (the game as it is)" if care else "take NO care (for comparison)"))
		var keys := ["shell", "torp", "dc"]; var all := {}
		for k in keys: all[k] = [0, 0]
		var all_d := [0.0, 0.0, 0.0, 0.0]
		for ci in cases.size():
			var cs: Array = cases[ci]; var c := {}
			for k in keys: c[k] = [0, 0]
			var held := [0, 0]
			var dmg := [0.0, 0.0, 0.0]; var lost := 0.0; var t0 := Time.get_ticks_msec()
			for rep in reps:
				seed(900 + ci * 10 + rep)
				var sim := BattleSim.new(); sim.wx = Weather.battle(cs[2]) if not cs[2].is_empty() else Weather.CLEAR; sim.ff_care = care
				var a := []; var b := []; var tech: Array = ["radar", "sonar"] + cs[4]
				for t in cs[0]: a.append(Campaign.new_ship(t, null, "player", tech))   # (fitted with what the research allows: homers need it)
				for t in cs[1]: b.append(Campaign.new_ship(t, null, "directorate", tech))
				sim.setup(a, b, tech, tech, 0); sim.flag = null
				var steps := 0
				while not sim.finished and steps < 40000: sim.step(0.05); steps += 1
				for k in sim.sys_log:
					var ks := String(k)
					if ks.begins_with("shell ") and ks != "shell on a friend": c.shell[0] += int(sim.sys_log[k])
				c.shell[1] += int(sim.sys_log.get("shell on a friend", 0))
				c.torp[0] += int(sim.sys_log.get("torpedo hit", 0)) + int(sim.sys_log.get("torpedo on a friend", 0)); c.torp[1] += int(sim.sys_log.get("torpedo on a friend", 0))
				c.dc[0] += int(sim.sys_log.get("depth charge hit", 0)) + int(sim.sys_log.get("depth charge on a friend", 0)); c.dc[1] += int(sim.sys_log.get("depth charge on a friend", 0))
				held[0] += int(sim.sys_log.get("torpedoes held for a friend", 0)); held[1] += int(sim.sys_log.get("pattern held for a friend", 0))
				dmg[0] += sim.ff_dmg; dmg[1] += sim.ff_dmg_t; dmg[2] += sim.ff_dmg_dc
				for s in sim.ships: lost += s.max_hull - maxf(0.0, s.hull)
			for k in keys: all[k][0] += c[k][0]; all[k][1] += c[k][1]
			for i in 3: all_d[i] += dmg[i]
			all_d[3] += lost
			print("%-38s shells %5d/%-3d torpedoes %3d/%-3d depth-charge bursts %3d/%-3d (hits/on friends); held for a friend: torpedoes %d, patterns %d; hull lost to friends %.0f of %.0f (%.1f%%)  [%d s]" % [cs[3], c.shell[0], c.shell[1], c.torp[0], c.torp[1], c.dc[0], c.dc[1], held[0], held[1], dmg[0] + dmg[1] + dmg[2], lost, 100.0 * (dmg[0] + dmg[1] + dmg[2]) / maxf(1.0, lost), (Time.get_ticks_msec() - t0) / 1000])
		print("ALL (%s): shells %d hits, %d on friends (%.2f%%); torpedoes %d hits, %d on friends (%.1f%%); depth-charge bursts that hurt %d, %d of them friends (%.1f%%); hull lost to friends %.0f of %.0f (%.2f%%: shells %.0f, torpedoes %.0f, charges %.0f)" % ["care" if care else "no care",
			all.shell[0], all.shell[1], 100.0 * all.shell[1] / maxf(1, all.shell[0]), all.torp[0], all.torp[1], 100.0 * all.torp[1] / maxf(1, all.torp[0]), all.dc[0], all.dc[1], 100.0 * all.dc[1] / maxf(1, all.dc[0]),
			all_d[0] + all_d[1] + all_d[2], all_d[3], 100.0 * (all_d[0] + all_d[1] + all_d[2]) / maxf(1.0, all_d[3]), all_d[0], all_d[1], all_d[2]])
	get_tree().quit()
