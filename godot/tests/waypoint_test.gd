extends Node
## Ctrl+Click waypoints: on the chart a course with two further legs is sailed to the end through every waypoint;
## in battle the flagship steers through its waypoints by itself. godot --headless --path godot res://tests/waypoint_test.tscn
func _ready() -> void:
	seed(4)
	Campaign.new_game("academy", "pacific")
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player; G.fleets = []
	P.x = Campaign.lon_x(-160.0); P.y = Campaign.lat_y(10.0)
	var pts := [Vector2(P.x + 40, P.y), Vector2(P.x + 40, P.y + 40), Vector2(P.x, P.y + 50)]
	Campaign.set_course(P, pts[0].x, pts[0].y)
	var ok1 := Campaign.add_waypoint(P, pts[1].x, pts[1].y) and Campaign.add_waypoint(P, pts[2].x, pts[2].y)
	var near := [INF, INF, INF]
	for i in 30 * 10 * 6:
		Campaign.paused = false; Campaign.update(1.0 / 30.0)
		for k in 3: near[k] = minf(near[k], Campaign.mdist(P.x, P.y, pts[k].x, pts[k].y))
		if P.get("route") == null: break
	var chart_ok: bool = ok1 and near.all(func(d): return d < 3.0) and P.get("route") == null
	# waypoints closer together than the turning circle, on dry bunkers (the owner's video): no orbiting for ever
	G.cargo.fuel = 0; var zz := []
	for i in 10: zz.append(Vector2(P.x + 6 + i * 3.0, P.y + (4.0 if i % 2 else -4.0)))
	Campaign.set_course(P, zz[0].x, zz[0].y)
	for i in range(1, zz.size()): Campaign.add_waypoint(P, zz[i].x, zz[i].y)
	var zdays := -1.0
	for i in 30 * 10 * 30:
		Campaign.paused = false; Campaign.update(1.0 / 30.0)
		if P.get("route") == null: zdays = i / 300.0; break
	print("close zig-zag on dry bunkers: finished after %.1f days" % zdays)
	chart_ok = chart_ok and zdays > 0.0
	print("chart: legs added %s, closest to each waypoint %s, arrived %s" % [ok1, near.map(func(d): return snappedf(d, 0.1)), P.get("route") == null])
	# battle
	var S = preload("res://scripts/skirmish.gd"); var pr: Dictionary = S.PRESETS[0]
	var sim := BattleSim.new(); sim.setup(pr.player.map(func(t): return Campaign.new_ship(t, null, "player", [])), pr.enemy.map(func(t): return Campaign.new_ship(t, null, "directorate", [])), [], [], 0)
	var bnear := INF; var b_ok := false
	if not sim.ships.is_empty():
		sim.flag = sim.ships[0]; var f = sim.flag; f.throttle = 4
		var w1: Vector2 = f.pos + Vector2.from_angle(f.a + 1.2) * 3000.0; var w2: Vector2 = w1 + Vector2.from_angle(f.a + 2.6) * 3000.0
		sim.waypoints = [w1, w2]; var hit1 := false
		for i in 60 * 50 * 10:
			sim.step(0.02)
			if sim.finished: break
			if f.pos.distance_to(w1) < 400: hit1 = true
			bnear = minf(bnear, f.pos.distance_to(w2))
			if sim.waypoints.is_empty(): break
		b_ok = hit1 and sim.waypoints.is_empty()
		print("battle: passed the first waypoint %s, waypoints left %d, closest to the last %d m" % [hit1, sim.waypoints.size(), int(bnear)])
	else: print("battle: preset has no player ships as types; skipped")
	print("waypoint test ", "ok" if chart_ok and b_ok else "FAIL")
	get_tree().quit(0 if chart_ok and b_ok else 1)
