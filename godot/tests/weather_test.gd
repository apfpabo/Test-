extends Node
## Headless check of weather and night: the model varies with place, season and hour and joins across the chart's
## seam; a storm slows small ships, costs fuel and grounds aircraft; darkness shortens the distance at which a force
## without radar finds you; and in battle a ship beyond sight is unseen until she fires or radar finds her.
## godot --headless --path godot res://tests/weather_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _ready() -> void:
	seed(3); Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	# the model
	var counts := [0, 0, 0, 0]; var fogs := 0; var n := 0; var seam := 0.0
	for d in range(0, 360, 12):
		for j in range(4, 76, 6):
			for i in range(0, 180, 9):
				var w := Weather.at(i * 40.0, j * 40.0, float(d)); counts[int(w.sea)] += 1; n += 1
				if w.fog: fogs += 1
			seam = maxf(seam, absf(Weather.storm(1.0, j * 40.0, float(d)) - Weather.storm(Campaign.MW - 1.0, j * 40.0, float(d))))
	print("sea states over a year: calm %d%%, moderate %d%%, rough %d%%, storm %d%%; fog %d%%" % [counts[0] * 100 / n, counts[1] * 100 / n, counts[2] * 100 / n, counts[3] * 100 / n, fogs * 100 / n])
	ok(counts[0] > n / 5 and counts[3] > n / 50 and counts[3] < n / 5 and fogs > 0, "every sea state occurs, storms are the exception")
	ok(seam < 0.05, "the weather joins across the east-west seam (%.3f)" % seam)
	var hi := 0.0; var lo := 0.0
	for d in range(0, 360, 6): hi += Weather.storm(1000.0, Campaign.lat_y(60), float(d)); lo += Weather.storm(1000.0, Campaign.lat_y(5), float(d))
	ok(hi > lo, "high latitudes are rougher than the tropics")
	var x0: float = Campaign.lon_x(0); var y45: float = Campaign.lat_y(45)
	ok(not Weather.night(x0, y45, 10.5) and Weather.night(x0, y45, 10.0) and Weather.night(Campaign.lon_x(180), y45, 10.5), "noon is day, midnight is night, and it is night on the far side of the world")
	ok(Weather.half_day(Campaign.lat_y(60), 300.0) < Weather.half_day(Campaign.lat_y(60), 120.0), "northern winter days are short (%.1f h against %.1f h of sun)" % [Weather.half_day(Campaign.lat_y(60), 300.0) * 2, Weather.half_day(Campaign.lat_y(60), 120.0) * 2])
	# on the chart
	G.fleet = [Campaign.new_ship("ca_baltimore", "C", "player", []), Campaign.new_ship("dd_fletcher", "D", "player", [])]
	var storm := {"sea": 3, "fog": false, "night": false, "moon": 0.5}; var calm := {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	var dark := {"sea": 0, "fog": false, "night": true, "moon": 0.1}
	for w in [storm, calm, dark]: w.vis_km = Weather.vis_km(w)
	ok(Weather.speed_mult(storm, G.fleet) < 0.7 and Weather.speed_mult(storm, [G.fleet[0]]) > Weather.speed_mult(storm, G.fleet) and Weather.speed_mult(calm, G.fleet) == 1.0, "a storm slows the squadron, small ships most")
	ok(Weather.fuel_mult(storm) > 1.2 and not Weather.air_ok(storm, true) and not Weather.air_ok(dark, false) and Weather.air_ok(dark, true) and Weather.air_ok(calm, false), "storms cost fuel and ground aircraft; only jets fly by night")
	ok(Weather.contact_mult(dark, false) < 0.4 and Weather.contact_mult(dark, true) >= 0.8 and Weather.contact_mult(calm, false) == 1.0, "at night a force without radar finds you at %d%% of the distance, one with radar at %d%%" % [int(Weather.contact_mult(dark, false) * 100), int(Weather.contact_mult(dark, true) * 100)])
	G.fleet.append(Campaign.new_ship("cv_essex", "CV", "player", []))
	ok(Campaign.strike_reach(G.fleet, true) > Campaign.strike_reach(G.fleet, false) and is_equal_approx(Campaign.strike_reach(G.fleet, false), Campaign.CONTACT), "a carrier that cannot fly reaches no farther than the guns")
	# a storm day at sea
	Weather.force = {"sea": 3, "fog": false, "night": false}; Campaign._wx = {}
	var h0: float = G.fleet[1].hullFrac; var f0: float = G.cargo.fuel; G.cargo.fuel = 500.0; Campaign.new_day(true)
	ok(float(G.fleet[1].hullFrac) < h0 and G.get("stormWarned", false), "a day under way in a storm knocks the destroyer about")
	Weather.force = {"sea": 0, "fog": false, "night": true, "moon": 0.0}; Campaign._wx = {}
	ok(int(Campaign.battle_setup(Campaign.spawn_fleet("raiders", "raiders")).weather.vis) == 3000, "a moonless night reaches the battle: lookouts see 3 km")
	# in battle: unseen beyond sight, seen by radar, seen when she fires
	var mk := func(tech_p: Array) -> BattleSim:
		var sim := BattleSim.new(); sim.wx = Weather.battle({"sea": 0, "fog": false, "night": true, "moon": 0.0})
		sim.setup([Campaign.new_ship("dd_fletcher", "A", "player", tech_p)], [Campaign.new_ship("dd_narvik", "B", "raiders", [])], tech_p, [], 0)
		return sim
	var sim: BattleSim = mk.call([])
	var a = sim.ships[0]; var b = sim.ships[1]; b.pos = a.pos + Vector2(0, -5000)
	ok(sim.limited() and not sim.visible_to(b, 0) and not sim.visible_to(a, 1), "5 km apart on a moonless night, neither sees the other")
	ok(sim.nearest_enemy(a.pos, 0) == null and sim.nearest_any(a.pos, 0) == b, "no target, but a bearing to search along")
	b.lit_t = 0.0; ok(sim.visible_to(b, 0), "her gun flashes give her away")
	b.lit_t = 99.0; b.pos = a.pos + Vector2(0, -2500); ok(sim.visible_to(b, 0) and sim.visible_to(a, 1), "at 2.5 km the lookouts have her")
	var simr: BattleSim = mk.call(["radar"]); var ar = simr.ships[0]; var br = simr.ships[1]; br.pos = ar.pos + Vector2(0, -8000)
	ok(simr.visible_to(br, 0) and not simr.visible_to(ar, 1), "with radar you hold her at 8 km and she does not see you")
	var cv := BattleSim.new(); cv.wx = Weather.battle({"sea": 3, "fog": false, "night": false, "moon": 0.5})
	cv.setup([Campaign.new_ship("cv_essex", "CV", "player", [])], [Campaign.new_ship("dd_narvik", "B", "raiders", [])], [], [], 0)
	ok(not cv.launch_strike(cv.ships[0], cv.ships[1]) and cv.speed_mult(cv.ships[1]) < 0.9, "no flying in a storm, and the destroyer labours")
	# a whole night action plays out
	var night := BattleSim.new(); night.wx = Weather.battle({"sea": 1, "fog": false, "night": true, "moon": 0.2})
	night.setup([Campaign.new_ship("ca_baltimore", "A", "player", ["radar"]), Campaign.new_ship("dd_fletcher", "B", "player", ["radar"])], [Campaign.new_ship("ca_hipper", "X", "directorate", []), Campaign.new_ship("dd_narvik", "Y", "directorate", [])], ["radar"], [], 0)
	night.autofire = true; var steps := 0
	while not night.finished and steps < 60000: night.step(0.05); steps += 1
	ok(night.finished, "a night action fights itself to a finish in %d battle seconds" % int(night.t))
	Weather.force = null
	print("WEATHER TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
