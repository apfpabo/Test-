extends Node
## Carrier actions fought by the simulation alone, with the aircraft's books checked at every step.
## godot --headless --path godot res://tests/air_stress.tscn
func _ready() -> void:
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("commission")
	var bad := 0; var notes := {}
	for run in 8:
		seed(100 + run)
		var sim := BattleSim.new(); sim.wx = Weather.CLEAR
		var a := []; var b := []
		for t in [["cv_essex", "cve_casa", "ca_baltimore", "dd_fletcher"], ["cv_midway", "bb_iowa"], ["cv_forrestal", "ddg_adams"], ["cve_colossus", "cv_shokaku", "dd_fletcher"]][run % 4]: a.append(Campaign.new_ship(t, null, "player", []))
		for t in [["cv_shokaku", "ca_hipper", "dd_narvik", "dd_narvik"], ["cv_essex", "cv_eagle", "ca_hipper"], ["bb_iowa", "ca_hipper", "dd_narvik"], ["cv_midway", "cve_ryujo"]][run % 4]: b.append(Campaign.new_ship(t, null, "directorate", []))
		sim.setup(a, b, [], [], 0)
		if run >= 4: sim.flag = null
		var side_total := [0, 0]
		for s in sim.ships: side_total[s.side] += sim.planes_left(s)
		var form_t := {}; var steps := 0; var launched := 0; var landed := 0; var deck_hits := 0; var ditched := 0
		while not sim.finished and steps < 60000:
			sim.step(0.05); steps += 1
			if steps % 400 == 0 and run % 2 == 1:   # now and then a carrier's deck is holed, or she takes a list
				for s in sim.ships: if s.alive and not s.squads.is_empty() and randf() < 0.3: s.deck_out = 60.0; deck_hits += 1
			for q in sim.air:
				var why := ""
				if q.up < 0 or q.dk < 0 or q.ops < 0: why = "negative count"
				elif q.up > q.n and q.n > 0: why = "more up than there are"   # (n == 0: lost with their ship, struck off at the next step)
				elif (q.state == "form" or q.state == "land") and q.up + q.dk + q.ops > q.n: why = "more machines than there are"
				elif q.state == "out" and q.target != null and not (q.target is BattleSim.CShip): why = "bad target"
				elif is_nan(q.pos.x) or is_nan(q.a): why = "nan"
				if q.state == "form":
					form_t[q] = form_t.get(q, 0) + 1
					if form_t[q] == 12000 and q.home.alive and sim.deck_ok(q.home): why = "ten minutes forming up with a sound deck"
				if why != "":
					bad += 1; notes[why] = notes.get(why, 0) + 1
					if bad < 6: print("  ", why, ": state ", q.state, " n ", q.n, " n0 ", q.n0, " up ", q.up, " dk ", q.dk, " ops ", q.ops, " home alive ", q.home.alive, " step ", steps)
			var side_now := [0, 0]   # a side never gains aircraft (one carrier may gain another's)
			for s in sim.ships: side_now[s.side] += sim.planes_left(s)
			for sd in 2:
				if side_now[sd] > side_total[sd]: bad += 1; notes["aircraft from nowhere"] = notes.get("aircraft from nowhere", 0) + 1
				side_total[sd] = side_now[sd]
			for s in sim.ships:
				if s.squads.is_empty(): continue
				for sq in s.squads:
					if sq.state == "out":
						var found := 0
						for q in sim.air: if is_same(q.sq, sq): found += 1
						if found != 1: bad += 1; notes["a squadron out with %d groups" % found] = notes.get("a squadron out with %d groups" % found, 0) + 1
				for e in sim.wing(s): if e.aboard < 0 or e.air < 0 or e.lost < 0 or e.aboard + e.air > e.full: bad += 1; notes["readout wrong"] = notes.get("readout wrong", 0) + 1
		var left := 0; var stuck := 0
		for q in sim.air:
			left += 1
			if q.state == "form" and q.up == 0: stuck += 1
		print("run %d: %d steps (%.0f s), finished %s, groups still up %d, on deck %d, decks holed %d" % [run, steps, sim.t, sim.finished, left, stuck, deck_hits])
	print("notes: ", notes)
	print("AIR STRESS PASSED" if bad == 0 else "AIR STRESS FAILED (%d)" % bad)
	get_tree().quit(0 if bad == 0 else 1)
