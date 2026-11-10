extends Node
## Escorting a friendly fleet from the chart's right-click menu: the squadron keeps station astern of a convoy for
## days without making contact with it. godot --headless --path godot res://tests/escort_test.tscn
func _ready() -> void:
	seed(11)
	Campaign.new_game("merchant")
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player; var cv = null
	for f in G.fleets: if f.kind == "convoy" and not Campaign.hostile_fleet(f): cv = f; break
	var w := Campaign.nearest_water(cv.x + 8.0, cv.y, 80)   # close by, but afloat (the convoy may lie close under a coast). Not 30 units off: an escort no faster than her charge can never make that up, which is no fault of her station-keeping
	P.x = w.x; P.y = w.y; P.escort = int(cv.id); P.repathT = 0.0
	var met := []; Campaign.encounter.connect(func(f): met.append(f.id); Campaign.paused = false; f.cool = 30.0; P.cool = 30.0)
	var worst := 0.0; var gone := false
	for i in 30 * 10 * 4:
		Campaign.paused = false; Campaign.update(1.0 / 30.0)
		if not G.fleets.has(cv): gone = true; break
		if i > 30 * 10: worst = maxf(worst, Campaign.mdist(P.x, P.y, cv.x, cv.y))
	print("escort: furthest from the convoy after the first day %.1f units, convoy %s, contacts with it %d, escort order %s" % [worst, "made port" if gone else "at sea", met.count(int(cv.id)), P.get("escort")])
	print("speeds on the chart: you %.2f, the convoy %.2f" % [Campaign.fleet_map_speed(G.fleet), Campaign.fleet_map_speed(cv.ships)])
	var ok: bool = met.count(int(cv.id)) == 0 and (gone or worst < 15.0)
	print("escort test ", "ok" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
