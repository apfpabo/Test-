extends Node
## Headless regressions from the code review round (docs/ROADMAP.md, "Code review and bug hunt"): each check failed
## before its fix. godot --headless --path godot res://tests/review_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _sim(mine: Array, theirs: Array, wx := Weather.CLEAR) -> BattleSim:
	var sim := BattleSim.new(); sim.wx = wx
	var a := []; var b := []
	for t in mine: a.append(Campaign.new_ship(t, null, "player", []))
	for t in theirs: b.append(Campaign.new_ship(t, null, "directorate", []))
	sim.setup(a, b, [], [], 0); sim.flag = null
	return sim

func _ready() -> void:
	seed(7)
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("commission")
	_battle(); _campaign()
	Weather.force = null
	print("REVIEW TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)

func _battle() -> void:
	# a flat-top with no island (the Ryujo) and guns: her arcs of fire
	var sim := _sim(["cve_ryujo", "dd_fletcher"], ["dd_narvik"])
	ok(sim.ships.size() == 3 and sim.ships.all(func(s): return s != null), "a carrier with no island takes her place in the line (%d ships)" % sim.ships.size())
	# a dark night: merchants and beaten ships do not vanish the moment nobody has them in sight
	var night := Weather.battle({"sea": 0, "fog": false, "night": true, "moon": 0.0})
	sim = _sim(["dd_fletcher", "dd_fletcher"], ["fr_liberty", "fr_liberty", "dd_narvik"], night)
	for i in 50: sim.step(0.02)
	ok(not sim.ships.any(func(s): return s.side == 1 and s.escaped), "by night a convoy is still there a second after the action opens")
	ok(not sim.finished, "and the battle is not over before it began")
	sim = _sim(["dd_fletcher", "dd_fletcher"], ["dd_narvik"], night); sim.order = "retreat"
	for i in 50: sim.step(0.02)
	ok(not sim.ships.any(func(s): return s.side == 0 and s.escaped), "withdrawing at night takes opening the range, not one second")
	# a magazine explosion sinks the ship, damage-control officer or not
	sim = _sim(["ca"], ["dd_narvik"]); var s = sim.ships[0]; s.sk = {"gun": 0, "helm": 0, "dc": 3, "ord": 0}
	sim.detonate(s)
	ok(not s.alive, "a ship whose magazine explodes is lost even with a damage-control officer (hull %.0f)" % s.hull)
	# engines stopped: the ship loses way
	sim = _sim(["dd_fletcher"], ["dd_narvik"]); s = sim.ships[0]; s.v = 15.0; s.throttle = 4; s.eng_out = 500.0
	for i in 1500: sim.step(0.02)
	ok(s.v < 10.0, "a ship with her engines stopped loses way (15.0 m/s, a minute later %.1f)" % s.v)
	# aircraft still up when the battle ends are counted once
	sim = _sim(["cv_essex", "cve_casa"], ["dd_narvik"]); var n0 := 0
	for c in [sim.ships[0], sim.ships[1]]:
		n0 += sim.planes_left(c)
		for sq in c.squads: sq.state = "out"; sim.air.append({"sq": sq, "n": int(sq.n), "side": 0})
	ok(sim.planes_left(sim.ships[0]) + sim.planes_left(sim.ships[1]) == n0, "aircraft in the air are counted once each (%d aboard, %d counted)" % [n0, sim.planes_left(sim.ships[0]) + sim.planes_left(sim.ships[1])])

func _campaign() -> void:
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	# pack ice grinds the hulls whether or not the fuel reserve happens to be filling
	G.fleet = [Campaign.new_ship("ca", "Ice", "player", [])]; G.crew = Campaign.crew_need(); G.cargo.fuel = 500.0; G.cargo.food = 500.0; G.credits = 100000.0
	G.reserve = Campaign.reserve_cap()
	var keep := [P.x, P.y]; P.x = Campaign.lon_x(0.0); P.y = Campaign.lat_y(80.5)
	if not Campaign.in_ice(P.x, P.y): P.y = Campaign.lat_y(-77.0)
	ok(Campaign.in_ice(P.x, P.y), "the test squadron lies in the pack ice")
	Campaign.new_day(true)
	ok(float(G.fleet[0].hullFrac) < 0.999, "a day under way in pack ice wears the hull with the reserve full (hull %.3f)" % float(G.fleet[0].hullFrac))
	P.x = keep[0]; P.y = keep[1]
	# salvage with the holds already over-full (a freighter lost in the same action) takes nothing out of them
	G.fleet = [Campaign.new_ship("dd", "Salvor", "player", [])]
	G.cargo.steel = float(Campaign.cargo_cap() + 200); var steel0: float = G.cargo.steel; var mun0: float = G.cargo.munitions
	var sal: Dictionary = Campaign.salvage([Campaign.new_ship("ca", null, "directorate", []), Campaign.new_ship("dd", null, "directorate", [])])
	ok(float(G.cargo.steel) >= steel0 and float(G.cargo.munitions) >= mun0 and int(sal.steel) >= 0 and int(sal.munitions) >= 0, "salvage never empties an over-full hold (steel %d to %d, salvaged %d)" % [steel0, G.cargo.steel, int(sal.steel)])
	G.cargo.steel = 0.0
	# a detached main body still burns fuel and still fills the bunkers
	G.fleet = [Campaign.new_ship("dd", "Fast", "player", []), Campaign.new_ship("bb", "Slow", "player", []), Campaign.new_ship("ca", "Slow2", "player", [])]
	var use0 := Campaign.fuel_use(); var cap0 := Campaign.bunker_cap()
	Campaign.detach([G.fleet[0]])
	ok(is_equal_approx(Campaign.fuel_use(), use0) and Campaign.bunker_cap() == cap0, "detaching the main body does not stop it burning fuel (%.1f a day before, %.1f after)" % [use0, Campaign.fuel_use()])
	Campaign.rejoin()
	# a guard squadron does not outlive the port it guards (it would be paid for ever with no way to disband it)
	var port: Dictionary = {}
	for p in G.ports: if p.fac == "directorate" and not p.capital: port = p; break
	G.flag = {"name": "Test Company", "short": "Company", "day": G.day}; Flag.apply()
	port.fac = "player"; port.from = "directorate"; port.men = 100; port.took = G.day; G.credits = 500000.0
	Flag.raise_guard(port)
	ok(Flag.guards() == 1, "a guard squadron is raised")
	Flag.abandon(port)
	ok(Flag.guards() == 0 and not G.fleets.any(func(f): return f.has("guardOf")), "and is paid off when the port is given up or lost")
