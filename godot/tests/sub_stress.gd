extends Node
## Submarine and night actions fought by the simulation alone, with the sensors' books checked at every step, and a
## count of how the actions end (a force that runs silent must still find its enemy).
## godot --headless --path godot res://tests/sub_stress.tscn
func _ready() -> void:
	Campaign.new_game("commission")
	var bad := 0; var notes := {}
	var night := {"sea": 0, "fog": false, "night": true, "moon": 0.3}; var fog := {"sea": 1, "fog": true, "night": false, "moon": 0.5}
	var cases := [
		[["dd_fletcher", "dd_fletcher", "dd_gearing"], ["ss_vii", "ss_vii"], {}, "destroyers hunt two boats by day"],
		[["dd_fletcher", "dd_fletcher", "dd_gearing"], ["ss_xxi", "ss_vii"], night, "the same by night"],
		[["ss_gato", "ss_gato"], ["fr_liberty", "fr_liberty", "ao_t2", "co_flower", "dd_narvik"], {}, "boats against an escorted convoy"],
		[["ss_gato", "ss_tang"], ["fr_liberty", "ao_t2", "dd_narvik", "dd_narvik"], night, "the same by night"],
		[["ca_baltimore", "dd_fletcher", "dd_fletcher"], ["ca_hipper", "dd_narvik", "dd_narvik"], night, "a night action, radar on both sides"],
		[["ca_baltimore", "dd_fletcher", "dd_fletcher"], ["ca_hipper", "dd_narvik", "dd_narvik"], fog, "the same in fog"],
		[["ssn_la", "ddg_adams"], ["ssn_akula", "ddg_kashin"], night, "nuclear boats and missile destroyers by night"],
		[["bb_iowa", "cl_cleveland", "dd_fletcher", "ss_gato"], ["bb_bismarck", "ca_hipper", "dd_narvik", "ss_vii"], {}, "a mixed action with a boat a side"],
	]
	for ci in cases.size():
		var cs: Array = cases[ci]
		for rep in 2:
			seed(500 + ci * 10 + rep)
			var sim := BattleSim.new(); sim.wx = Weather.battle(cs[2]) if not cs[2].is_empty() else Weather.CLEAR
			var a := []; var b := []
			for t in cs[0]: a.append(Campaign.new_ship(t, null, "player", []))
			for t in cs[1]: b.append(Campaign.new_ship(t, null, "directorate", []))
			var tech: Array = ["radar", "sonar"] + (["missiles", "homing", "nuclear", "reactors"] if ci == 6 else [])
			sim.setup(a, b, tech, tech, 0)
			if rep == 1: sim.flag = null   # both sides run by their captains
			var steps := 0; var most_pings := 0; var t0 := Time.get_ticks_msec(); var silent_ok := true
			while not sim.finished and steps < 50000:
				sim.step(0.05); steps += 1
				most_pings = maxi(most_pings, sim.pings.size())
				if steps % 5 != 0: continue
				for s in sim.ships:
					var why := ""
					if is_nan(s.pos.x) or is_nan(s.v) or is_nan(s.hull): why = "nan"
					elif s.sub and (s.dive < -0.001 or s.dive > 1.001): why = "dive out of range"
					elif s.held_t < 0.0 or s.heard_t < 0.0 or s.ping_t < -1.0: why = "sensor timer negative"
					elif not s.sub and not sim.radar_fitted(s) and sim.has_radar(s): why = "radar without a set"
					elif sim.active(s) and sim.submerged(s) and sim.visible_to(s, 1 - s.side) != sim.detected_by(s, 1 - s.side) and not sim.limited() and sim.screens.is_empty(): why = "a dived boat seen without being detected (or the reverse)"
					if why != "": bad += 1; notes[why] = notes.get(why, 0) + 1
				for p in sim.pings: if is_nan(p.r) or p.r < 0.0 or (p.who != null and not (p.who is BattleSim.CShip)): bad += 1; notes["bad ping"] = notes.get("bad ping", 0) + 1
			if most_pings > 400: bad += 1; notes["pings pile up"] = notes.get("pings pile up", 0) + 1
			var mine := 0; var theirs := 0
			for s in sim.ships:
				if sim.engageable(s):
					if s.side == 0: mine += 1
					else: theirs += 1
			var how: String = "unfinished" if not sim.finished else ("fought out" if mine == 0 or theirs == 0 else "contact lost")
			print("%-52s %s  %5d steps (%4.0f s) %-12s left %d v %d  pings<=%d  %.2f ms/step" % [cs[3], "captains" if rep == 1 else "flagship", steps, sim.t, how, mine, theirs, most_pings, float(Time.get_ticks_msec() - t0) / maxf(1.0, steps)])
			if not sim.finished: bad += 1; notes["an action that never ends"] = notes.get("an action that never ends", 0) + 1
	print("notes: ", notes)
	print("SUB STRESS PASSED" if bad == 0 else "SUB STRESS FAILED (%d)" % bad)
	get_tree().quit(0 if bad == 0 else 1)
