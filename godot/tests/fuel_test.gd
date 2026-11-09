extends Node
## Fuel: dry bunkers, a crawl on the reserve until the squadron is dead in the water; a friendly patrol called by
## wireless comes alongside and tows you to the nearest open port; merchant convoys carry fuel to sell.
## godot --headless --path godot res://tests/fuel_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1
func _ready() -> void:
	seed(6)
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	ok(Campaign.reserve() > 0.0 and is_equal_approx(Campaign.reserve(), Campaign.reserve_cap()), "a full reserve at the start (%.1f)" % Campaign.reserve())
	ok(G.fleets.filter(func(f): return f.kind == "convoy").all(func(f): return int(f.cargo.get("fuel", 0)) > 0 and f.has("cash")), "every convoy carries fuel to sell, and cash")
	# out to sea and run the bunkers dry
	var a := Campaign.water_point(30.0); P.x = a.x; P.y = a.y; G.cargo.fuel = 0
	G.fleets = G.fleets.filter(func(f): return not Campaign.hostile_fleet(f))
	for k in 20:
		var b := Campaign.water_point(10.0, Vector2(P.x, P.y), 1500.0)
		if Campaign.mdist(P.x, P.y, b.x, b.y) > 600.0 and Campaign.set_course(P, b.x, b.y): break
	print("start %.0f,%.0f route %s" % [P.x, P.y, P.get("route") != null])
	var days := 0.0
	while not Campaign.dead_in_water() and days < 40:
		Campaign.paused = false; P.cool = 99.0; Campaign.update(1.0 / 30.0); days += 1.0 / 300.0
	ok(Campaign.dead_in_water(), "dead in the water after %.1f days on the reserve" % days)
	var x0: float = P.x
	for i in 300: Campaign.paused = false; P.cool = 99.0; Campaign.update(1.0 / 30.0)
	ok(absf(Campaign.wdx(x0, P.x)) < 0.5, "she no longer moves")
	# a friendly patrol answers a wireless call and comes alongside
	var pat: Dictionary = Campaign.spawn_fleet("patrol", "concord"); var pw := Campaign.water_point(8.0, Vector2(P.x, P.y), 140.0); pat.x = pw.x; pat.y = pw.y; pat.route = null
	print(Campaign.call_fleet(pat))
	var met := []; Campaign.encounter.connect(func(f): met.append(f.id); Campaign.paused = false)
	P.cool = 0.0
	for i in 30 * 10 * 10:
		Campaign.paused = false; Campaign.update(1.0 / 30.0)
		if met.has(pat.id): break
	ok(met.has(pat.id), "the patrol came alongside (contact)")
	G.credits = 50000
	print(Campaign.take_tow(pat))
	ok(P.get("towed") == pat.id, "under tow")
	var port = Campaign.nearest_open_port(); var t := 0
	for i in 30 * 10 * 40:
		Campaign.paused = false; P.cool = 99.0; Campaign.update(1.0 / 30.0); t = i
		if P.get("towed") == null: break
	ok(P.get("towed") == null and Campaign.mdist(P.x, P.y, port.sx, port.sy) < 30.0, "towed into %s after %.1f days" % [port.name, t / 300.0])
	Campaign.save(); ok(Campaign.load_game(), "save/load")
	print("fuel test done, %d failures" % fails)
	get_tree().quit(1 if fails else 0)
