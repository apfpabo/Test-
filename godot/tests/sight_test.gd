extends Node
## Headless check of what you can see on the chart, and of routes for a squadron hard against a coast.
## godot --headless --path godot res://tests/sight_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _ready() -> void:
	seed(4); Campaign.new_game("commission"); var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}; Campaign._wx = {}
	# ---- sighting
	Campaign._sighting()
	var seen: int = G.fleets.filter(func(f): return f.get("vis", true)).size()
	print("at the start you see %d of %d fleets" % [seen, G.fleets.size()])
	ok(seen > 0 and seen < G.fleets.size(), "some fleets are in sight, most are not")
	var cm: String = G.commission.fac if G.get("commission") != null else ""
	if cm != "": ok(G.fleets.filter(func(f): return f.fac == cm).all(func(f): return f.vis), "the fleets of the flag you serve are always shown")
	var foe: Dictionary = Campaign.spawn_fleet("raiders", "raiders"); foe.x = Campaign.wrap_x(P.x + 60.0); foe.y = P.y
	Campaign._sighting(); ok(foe.vis and is_equal_approx(float(foe.seenX), float(foe.x)), "a raider 330 km off is in sight")
	foe.x = Campaign.wrap_x(P.x + 400.0); Campaign._sighting()
	ok(not foe.vis and Campaign.ghost(foe) and not is_equal_approx(float(foe.seenX), float(foe.x)), "gone beyond sight, she leaves a mark where she was last seen")
	G.day = int(G.day) + Campaign.GHOST_DAYS + 1; ok(not Campaign.ghost(foe), "which fades after five days"); G.day = int(G.day) - Campaign.GHOST_DAYS - 1
	foe.x = Campaign.wrap_x(P.x + 60.0); Weather.force = {"sea": 0, "fog": false, "night": true, "moon": 0.0}; Campaign._wx = {}; Campaign._sighting()
	ok(not foe.vis, "on a dark night without radar, 330 km is too far")
	G.tech = ["radar"]; Campaign._wx = {}; Campaign._sighting(); ok(foe.vis, "with radar you hold her")
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}; Campaign._wx = {}; G.tech = []
	foe.x = Campaign.wrap_x(P.x + 180.0); Campaign._sighting(); ok(not foe.vis, "1,000 km is beyond your lookouts")
	G.fleet.append(Campaign.new_ship("cv_essex", "CV", "player", [])); Campaign._sighting(); ok(foe.vis, "a carrier's search aircraft find her")
	G.fleet.pop_back()
	foe.x = Campaign.wrap_x(P.x + 800.0); var base: Dictionary = {}
	for s in Structures.all(): if s.kind == "radar": base = s; break
	base.fac = "player"; base.garrison = 30; foe.x = Campaign.wrap_x(base.x + 150.0); foe.y = base.y
	Campaign._sighting(); ok(foe.vis, "a radar station you hold watches the sea round it")
	base.fac = ""; Campaign._sighting(); ok(not foe.vis, "and not once it is lost")
	# the chart: hidden fleets cannot be picked, and a lost contact drops the intercept
	var map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	ok(map.fleet_at(Vector2(foe.x, foe.y)) == null, "a fleet out of sight cannot be clicked")
	foe.x = Campaign.wrap_x(P.x + 50.0); foe.y = P.y; Campaign._sighting(); ok(map.fleet_at(Vector2(foe.x, foe.y)) == foe, "in sight, she can")
	P.follow = foe.id; foe.x = Campaign.wrap_x(P.x + 900.0); foe.cool = 99.0
	for fl in G.fleets: fl.cool = 99.0
	for i in 30: Campaign.paused = false; Campaign.update(1.0 / 30.0)
	ok(P.follow == null, "an intercept is dropped when the contact is lost")
	# ---- routes from hard against a coast (a big squadron swings wide and fetches up there)
	var stuck := 0; var tried := 0; var worst := ""
	for p in G.ports:
		for k in 12:
			var a := k * TAU / 12
			# the last water cell before the land, walking in from the anchorage
			var q := Vector2(p.sx, p.sy); var last := q
			for st in 80:
				q += Vector2.from_angle(a) * 0.5
				if Campaign.on_land(q.x, q.y): break
				last = q
			if last.distance_to(Vector2(p.sx, p.sy)) < 2.0: continue
			tried += 1; P.x = Campaign.wrap_x(last.x); P.y = last.y
			var far: Dictionary = G.ports[(int(p.id) + 7) % G.ports.size()]
			if not Campaign.set_course(P, far.sx, far.sy): stuck += 1; worst = "%s bearing %d" % [p.name, int(rad_to_deg(a))]
	ok(stuck == 0, "from %d places hard against the shore near every port, a route is always found (%d failed%s)" % [tried, stuck, (", e.g. " + worst) if worst != "" else ""])
	Weather.force = null
	print("SIGHT TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
