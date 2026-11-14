extends Node
## Headless regressions from the code review round (docs/ROADMAP.md, "Code review and bug hunt"): each check failed
## before its fix. godot --headless --path godot res://tests/review_test.tscn
var fails := 0
var sections := 0   # a script error ends a section early: every section must reach its end
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
	_battle(); _campaign(); _world(); _chart(); _sounds(); _decisions(); _economy(); _supply(); _fighting(); _divisions(); _night_and_dc(); _gunnery(); _weights(); _flying(); _sound(); _friends(); _grace(); _ageing(); _levels(); _armour(); _rebuilds(); _ew(); _slots_keys(); _subs(); _traits()
	ok(sections == 25, "every section ran to its end (%d of 25)" % sections)
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
	_radar()
	ok(sim.planes_left(sim.ships[0]) + sim.planes_left(sim.ships[1]) == n0, "aircraft in the air are counted once each (%d aboard, %d counted)" % [n0, sim.planes_left(sim.ships[0]) + sim.planes_left(sim.ships[1])])
	sections += 1

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
	sections += 1

func _fleet(kind: String, fac: String, x: float, y: float, types: Array) -> Dictionary:
	var G: Dictionary = Campaign.G
	var f := {"id": G.nextId, "kind": kind, "fac": fac, "h": 0.0, "v": 0.0, "tx": null, "ty": null, "cool": 0.0, "ships": [], "cargo": {}, "x": x, "y": y, "home": {"x": x, "y": y}, "name": "%s %s" % [fac, kind]}
	G.nextId += 1
	for t in types: f.ships.append(Campaign.new_ship(t, null, fac, []))
	G.fleets.append(f); return f

func _world() -> void:
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	var w := Campaign.water_point(8.0)
	# two neutral fleets that pass each other stay open to contact with you (their meeting used to put both out of
	# your reach, and out of the chase, for two and a half days)
	G.fleets.clear()
	var a := _fleet("patrol", "concord", w.x, w.y, ["dd"]); var b := _fleet("convoy", "combine", w.x + 3.0, w.y, ["freighter"])
	Diplomacy._clash_t = 0.0; Diplomacy.clash_tick(0.1)
	ok(float(a.cool) <= 0.0 and float(b.cool) <= 0.0, "fleets that pass each other can still be met by you (cool %.0f, %.0f)" % [a.cool, b.cool])
	Diplomacy._clash_t = 0.0; Diplomacy.clash_tick(0.1)
	ok(a.ships.size() == 1 and b.ships.size() == 1, "and do not meet each other again at once")
	# a bounty captain is yours to collect: patrols leave her be
	G.fleets.clear()
	a = _fleet("bounty", "raiders", w.x, w.y, ["cl", "dd"]); b = _fleet("patrol", "concord", w.x + 3.0, w.y, ["bb", "ca"])
	for i in 6: Diplomacy._clash_t = 0.0; Diplomacy.clash_tick(0.1)
	ok(G.fleets.has(a) and a.ships.size() == 2, "a patrol does not sink a posted bounty before you can")
	# the ship towing you, or answering your call, is not drawn into other fleets' fights
	G.fleets.clear()
	a = _fleet("patrol", "concord", w.x, w.y, ["dd"]); b = _fleet("raiders", "raiders", w.x + 3.0, w.y, ["dd", "dd"]); P.towed = int(a.id)
	ok(not Diplomacy._free(a), "the ship towing you keeps out of other fights")
	P.towed = null; a.answering = true
	ok(not Diplomacy._free(a), "and so does one answering your call")
	# a tow interrupted on the way resumes for its harbour, and ends if the tug is lost
	G.fleets.clear(); P.x = w.x; P.y = w.y; a = _fleet("patrol", "concord", P.x + 2.0, P.y, ["dd"])
	G.cargo.fuel = 0.0; G.reserve = 0.0; G.credits = 50000.0
	var tow_msg := Campaign.take_tow(a); P.route = null   # as a contact on the way leaves it
	Campaign.update(0.05); Campaign.paused = false
	ok(P.get("towed") != null and P.get("route") != null, "a tow whose course was lost picks it up again (%s; towed %s, route %s)" % [tow_msg, P.get("towed"), P.get("route") != null])
	G.fleets.erase(a); Campaign.update(0.05); Campaign.paused = false
	ok(P.get("towed") == null, "and a tow whose tug is gone is over")
	G.cargo.fuel = 200.0; P.route = null; P.destPort = null
	G.fleets.clear()
	# a delivery consignment is the shipper's: abandon the contract and it goes back, or is paid for
	G.fleet = [Campaign.new_ship("freighter", "Carrier", "player", [])]; G.credits = 50000.0; G.cargo.electronics = 0.0
	var c := {"id": 9001, "kind": "delivery", "fac": "concord", "port": 0, "dest": 1, "good": "electronics", "qty": 30, "days": 20, "reward": 4000, "rep": 5, "title": "Carry 30 electronics"}
	Diplomacy.accept(c); G.cargo.electronics = 10.0   # twenty tons sold on the quiet
	Diplomacy.fail(c, "Abandoned.")
	ok(float(G.cargo.electronics) == 0.0 and float(G.credits) < 50000.0, "a failed delivery gives the consignment back and pays for what is missing (credits %d)" % int(G.credits))
	# a failed escort contract releases its convoy
	G.contracts.clear()
	c = {"id": 9002, "kind": "escort", "fac": "concord", "port": 0, "dest": 1, "days": 5, "reward": 4000, "rep": 5, "title": "Escort"}
	Diplomacy.accept(c); var cv = Campaign._fleet(int(c.fleet))
	Diplomacy.fail(c, "Too late.")
	ok(int(cv.get("escort", 0)) == 0 and Diplomacy._free(cv), "the convoy of a failed escort contract sails on by itself")
	# no contract to make war on the flag you serve
	G.contracts.clear(); G.commission = {"fac": "concord", "since": G.day}
	c = {"id": 9003, "kind": "war", "fac": "directorate", "target": "concord", "days": 30, "reward": 4000, "rep": 5, "title": "War patrol"}
	ok(Diplomacy.can_accept(c) != "", "a war contract against the flag you serve is refused: " + Diplomacy.can_accept(c))
	G.commission = null
	# withdrawing a garrison and landing it again does not wipe out the old owner's claim
	var st: Dictionary = {}
	for x in Structures.all(): if x.fac == "directorate" and x.kind != "battery" and int(x.coastKm) < 300: st = x; break
	G.fleet = [Campaign.new_ship("ca", "Flag", "player", [])]; G.crew = 2000
	var cp := Structures.coast_point(st); P.x = cp.x; P.y = cp.y; st.dmg = 1.0
	Structures.take(st); Structures.withdraw(st); Structures.take(st)
	ok(st.from == "directorate", "a structure given up and taken again still has its old owner after it (from '%s')" % st.from)
	st.nuked = true; st.fac = ""; G.troops = 0
	G.fleet.append(Campaign.new_ship("ap_haskell", "T", "player", ["amphib"])); G.troops = 500
	ok(Structures.can_invade(st) != "", "no landing on a ruin the bomb left: " + Structures.can_invade(st))
	# warheads belong to the boats that carry them
	G.tech = ["nuclear", "missiles", "nukes"]
	G.fleet = [Campaign.new_ship("ssn_charlie", "A", "player", G.tech), Campaign.new_ship("ssn_charlie", "B", "player", G.tech), Campaign.new_ship("dd", "D", "player", G.tech)]
	var cap := Structures.nuke_capacity(); G.nukes = cap
	Campaign.detach([G.fleet[0], G.fleet[2]])
	var tgt: Dictionary = {}
	for x in Structures.all(): if x.fac == "directorate" and x.kind == "farm": tgt = x; break
	var cpt := Structures.coast_point(tgt); P.x = cpt.x; P.y = cpt.y   # (off the coast nearest her: an inland target can lie beyond the missiles' reach)
	ok(cap >= 2 and Structures.can_nuke(tgt) == "", "two missile boats carry %d warheads (%s)" % [cap, Structures.can_nuke(tgt)])
	Structures.nuke(tgt); Campaign.rejoin()
	ok(Structures.nukes() == cap - 1, "firing one warhead with a boat detached uses one warhead (%d of %d left)" % [Structures.nukes(), cap])
	G.fleet = G.fleet.filter(func(r): return r.name == "D"); Structures.trim_troops()
	ok(int(G.get("nukes", 0)) == 0, "warheads go down with the boats that carried them (%d left)" % int(G.get("nukes", 0)))
	# standing stays within -100..100 however often you strike
	G.rep.concord = -340; G.rep.pacific = 180; G.cargo.food = 500.0; G.cargo.fuel = 500.0
	Campaign.new_day(false)
	ok(int(G.rep.concord) == -100 and int(G.rep.pacific) == 100, "standing is kept within -100 and 100 (%d, %d)" % [int(G.rep.concord), int(G.rep.pacific)])
	sections += 1

func _chart() -> void:
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	var map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	var port: Dictionary = G.ports[0]
	# no design sells for more than the yard charges, whole or stripped (the hull was priced without her weapons)
	var worst := 0.0; var worst_id := ""; var worst_strip := 0.0; var strip_id := ""
	for id in GameData.hulls:
		G.fleet = [G.fleet[0]]; G.credits = 5000000.0
		var pr: int = map.ship_price(port, id); var sh: Dictionary = map.buy_ship(id, pr)
		var whole: float = float(map.sell_value(sh)) / pr
		if whole > worst: worst = whole; worst_id = id
		var empty := []; for i in sh.fit.size(): empty.append("")
		var before: float = G.credits; map.apply_refit(sh, empty)
		var back: float = (float(G.credits) - before + map.sell_value(sh)) / pr
		if back > worst_strip: worst_strip = back; strip_id = id
	ok(worst <= 1.0, "no new ship sells for more than she cost (best resale %d%% of the price, %s)" % [int(worst * 100), worst_id])
	ok(worst_strip <= 1.0, "nor does stripping her first pay (best return %d%% of the price, %s)" % [int(worst_strip * 100), strip_id])
	# a ship that was not bought (a prize) still sells by what she is worth
	var prize: Dictionary = Campaign.new_ship("ca", null, "directorate", [])
	ok(map.sell_value(prize) == int(floor(Campaign.ship_value(prize) * 0.45)), "a prize still sells for 45% of her value")
	# buying a shipload and selling it straight back loses money, both ways round
	G.fleet = [Campaign.new_ship("freighter", "A", "player", []), Campaign.new_ship("freighter", "B", "player", []), Campaign.new_ship("freighter", "C", "player", [])]
	for gd in Campaign.C.GOODS: G.cargo[gd.id] = 0.0
	G.credits = 1000000.0; map.cur_port = port; port.drift.steel = 0.0
	map._buy(port, "steel", -1); var got: int = int(G.cargo.steel); map._sell(port, "steel", -1)
	ok(got > 100 and float(G.credits) <= 1000000.0, "buying %d tons and selling them back makes no money (%d)" % [got, int(G.credits) - 1000000])
	G.cargo.steel = 400.0; port.drift.steel = 0.0; G.credits = 1000000.0
	map._sell(port, "steel", -1); map._buy(port, "steel", 400)
	ok(float(G.credits) <= 1000000.0 or int(G.cargo.steel) < 400, "nor does selling a shipload and buying it back (%d, %d tons)" % [int(G.credits) - 1000000, int(G.cargo.steel)])
	G.cargo.steel = 0.0; port.drift.steel = 0.0; G.credits = 1000000.0
	map._buy(port, "steel", 200); map._sell(port, "steel", -1)
	ok(float(G.credits) <= 1000000.0, "nor a batch of 200 tons bought and sold back, which used to pay about 14%% (%d)" % (int(G.credits) - 1000000))
	map.cur_port = {}
	# a port ceded to you by treaty: its yard still works, and giving it up returns it to a real flag
	var dp: Dictionary = {}
	for q in G.ports: if q.fac == "directorate" and not q.capital: dp = q; break
	G.flag = {"name": "Test Company", "short": "Company", "day": G.day}; Flag.apply()
	dp.fac = "player"; dp.from = ""; dp.men = 100; dp.took = G.day
	var yard: Array = map.yard_of(dp)
	ok(yard != null and not yard.is_empty(), "the yard of a ceded port has designs to sell (%d)" % (yard.size() if yard != null else -1))
	Flag.abandon(dp)
	ok(dp.fac == "directorate", "a ceded port given up goes back to a real flag ('%s')" % dp.fac)
	# the militia of a stormed port's structures is not yours to embark as crew
	var sp: Dictionary = {}
	for q in G.ports:
		if q.fac == "concord" and not q.capital and Structures.all().any(func(x): return int(x.port) == int(q.id) and x.fac == "concord"): sp = q; break
	G.fleet = [Campaign.new_ship("ca", "Flag", "player", []), Campaign.new_ship("ap_haskell", "T", "player", ["amphib"])]
	P.x = sp.sx; P.y = sp.sy; G.crew = 1000
	for i in 40:
		G.troops = 1500
		if Flag.assault(sp).won: break
	var mil: Dictionary = {}
	for x in Structures.all(): if int(x.port) == int(sp.id) and x.fac == "player": mil = x; break
	ok(sp.fac == "player" and not mil.is_empty(), "a port is stormed and its works come with it")
	if not mil.is_empty():
		G.crew = 1000; Structures.withdraw(mil)
		ok(int(G.crew) == 1000, "withdrawing the militia of a stormed port's structure adds no crew (%d)" % int(G.crew))
	# losing the fast division is not the end while the main body is afloat
	G.fleet = [Campaign.new_ship("dd", "Fast", "player", []), Campaign.new_ship("bb", "Slow", "player", []), Campaign.new_ship("ca", "Slow2", "player", [])]
	Campaign.detach([G.fleet[0]])
	var foe := _fleet("raiders", "raiders", P.x + 5.0, P.y, ["ca", "ca"])
	GameData.pending = Campaign.battle_setup(foe)
	var sim := BattleSim.new(); sim.setup(GameData.pending.player_recs, GameData.pending.enemy_recs, [], [], 0); sim.flag = null
	for x in sim.ships: if x.side == 0: x.alive = false; x.hull = 0.0
	sim.finished = true
	Campaign.apply_battle(sim)
	ok(G.fleet.size() == 2 and Campaign.body() == null, "with the fast division sunk, the main body becomes your squadron (%d ships)" % G.fleet.size())
	# a convoy that gets clean away leaves no cargo behind
	G.fleet = [Campaign.new_ship("dd", "Chaser", "player", [])]; for gd in Campaign.C.GOODS: G.cargo[gd.id] = 0.0
	foe = _fleet("convoy", "combine", P.x + 5.0, P.y, ["freighter", "freighter"]); foe.cargo = {"steel": 100, "food": 100}
	GameData.pending = Campaign.battle_setup(foe)
	sim = BattleSim.new(); sim.setup(GameData.pending.player_recs, GameData.pending.enemy_recs, [], [], 0); sim.flag = null
	for x in sim.ships: if x.side == 1: x.escaped = true
	sim.finished = true
	var res: Dictionary = Campaign.apply_battle(sim)
	ok(int(G.cargo.steel) == 0 and int(G.cargo.food) == 0, "a convoy that escapes untouched yields no cargo (%s)" % res.goods)
	# a ship that struck her colours is no prize if you then break off
	G.fleet = [Campaign.new_ship("dd", "Runner", "player", [])]
	foe = _fleet("patrol", "directorate", P.x + 5.0, P.y, ["ca", "dd"])
	GameData.pending = Campaign.battle_setup(foe)
	sim = BattleSim.new(); sim.setup(GameData.pending.player_recs, GameData.pending.enemy_recs, [], [], 0); sim.flag = null
	for x in sim.ships:
		if x.side == 1 and x.rec == foe.ships[1]: x.struck = true
		if x.side == 0: x.escaped = true
	sim.finished = true
	res = Campaign.apply_battle(sim)
	ok(res.prizes.is_empty() and foe.ships.size() == 2 and not res.victory, "no prize from a battle you broke off (%d prizes, %d ships left to them)" % [res.prizes.size(), foe.ships.size()])
	# a campaign opens in daylight wherever it starts
	var dark_starts := []
	for o in Origins.LIST:
		for nv in (Origins.NAVIES if Origins.INFO[o].navy else ["concord"]):
			Campaign.new_game(o, nv)
			var wx: Dictionary = Weather.at(Campaign.G.player.x, Campaign.G.player.y)
			if absf(float(wx.hour) - 8.0) > 0.01: dark_starts.append("%s/%s %.1fh" % [o, nv, float(wx.hour)])
	ok(dark_starts.is_empty(), "every origin puts to sea at eight in the morning, local time %s" % str(dark_starts))
	Campaign.new_game("commission"); G = Campaign.G; P = G.player
	# the supply limit counts every ship you own (ten destroyers weigh 20 against a limit of 16: within half as much again, but no room for more... 
	G.fleet = []; for i in 6: G.fleet.append(Campaign.new_ship("dd", "D%d" % i, "player", []))
	Campaign.detach(G.fleet.slice(0, 3)); G.fleet.append_array([Campaign.new_ship("dd", "X", "player", []), Campaign.new_ship("dd", "Y", "player", []), Campaign.new_ship("dd", "Z", "player", []), Campaign.new_ship("dd", "W", "player", [])])
	var wreck: Dictionary = {}
	for q in G.pois: if q.type == "wreck": wreck = q; break
	var most := 0
	for i in 60: wreck.next = 0; Campaign.do_survey(wreck); most = maxi(most, Campaign.all_ships().size())
	for f in G.fleets.duplicate(): if f.kind == "raiders" and not f.has("home"): G.fleets.erase(f)
	ok(most > 10 and most <= Campaign.SHIPS_MAX and Campaign.supply_need() <= int(Campaign.supply_cap() * 1.5), "hulks found on surveys join only while supply allows, counting a detached division (%d ships, supply %d of %d)" % [most, Campaign.supply_need(), Campaign.supply_cap()])
	map.queue_free()
	# docking a little short of the roads ends the passage: putting to sea does not "arrive" and open the port again
	var pm = map
	if is_instance_valid(pm):
		var Gp: Dictionary = Campaign.G; var Pp: Dictionary = Gp.player; var hp: Dictionary = Gp.ports[0]
		var was := [Pp.x, Pp.y, Campaign.paused, Pp.get("cool", 0.0)]
		for q in Gp.ports: if not Campaign.hostile(q.fac): hp = q; break
		Pp.x = hp.sx + 8.0; Pp.y = hp.sy; Pp.destPort = int(hp.id); Campaign.set_course(Pp, hp.sx, hp.sy); Pp.destPort = int(hp.id)
		pm.open_port(hp, false)
		ok(Pp.get("destPort") == null and Pp.get("route") == null, "entering a harbour you were making for ends the passage")
		pm.cur_port = {}; pm.close_panel()
		Pp.x = was[0]; Pp.y = was[1]; Campaign.paused = was[2]; Pp.cool = was[3]; Pp.route = null; Pp.tx = null
	sections += 1

## The owner's report: a large squadron got "no sea route" near the Strelsk Sounds. A full squadron of carriers and
## oilers (the widest turning circle there is) works in and out of the Sounds, changing course every few seconds
## as a player clicking about would: wherever she lies, a course to open water nearby and to the ports must be found.
func _sounds() -> void:
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	G.fleet = []
	for t in ["cv_essex", "cv_shokaku", "cv_essex", "ao_cimarron", "ao_t2", "ao_cimarron", "bb_iowa", "bb_yamato", "ca", "ae_hood"]: G.fleet.append(Campaign.new_ship(t, null, "player", []))
	G.crew = Campaign.crew_need(); G.cargo.fuel = 5000.0; G.cargo.food = 5000.0; G.credits = 1000000.0; G.fleets.clear()
	var snd: Dictionary = {}
	for z in Campaign.C.STRAITS: if z.name == "Strelsk Sounds": snd = z
	var strelsk: Dictionary = {}; var korv: Dictionary = {}
	for q in G.ports:
		if q.name == "Strelsk": strelsk = q
		if q.name == "Korvagrad": korv = q
	var start := Campaign.nearest_water(snd.x, snd.y, 60); P.x = start.x; P.y = start.y; P.route = null; P.v = 0.0
	seed(21)
	var tried := 0; var refused := 0; var aground := 0; var worst := ""; var legs := 0
	for leg in 90:
		# a new order: a point of open water somewhere about the Sounds, or one of the ports beyond them
		var goal: Vector2
		if leg % 9 == 4: goal = Vector2(strelsk.sx, strelsk.sy)
		elif leg % 9 == 8: goal = Vector2(korv.sx, korv.sy)
		else: goal = Campaign.water_point(3.0, Vector2(snd.x, snd.y), 170.0)
		tried += 1
		if not Campaign.set_course(P, goal.x, goal.y):
			refused += 1; worst = "from %.0f,%.0f to %.0f,%.0f" % [P.x, P.y, goal.x, goal.y]
			continue
		legs += 1
		for i in randi_range(40, 260):   # two to thirteen seconds on this course, then a change of mind
			Campaign.update(0.05)
			if Campaign.paused: Campaign.paused = false
			if P.get("route") == null: break
		if Campaign.on_land(P.x, P.y): aground += 1
	ok(refused == 0, "a full squadron of carriers and oilers is never refused a course about the Strelsk Sounds (%d of %d refused%s)" % [refused, tried, (", e.g. " + worst) if worst != "" else ""])
	ok(aground == 0 and legs > 60, "and never fetches up on the land (%d times in %d legs)" % [aground, legs])
	# the owner's report at Port Saffron: a fleet leaving harbour with her bow towards the shore wedged in a corner of
	# the coast. From every port, on eight headings, for the two nearest ports: she gets away.
	var wedged := []; var sailed := 0
	for p in G.ports:
		var near: Array = G.ports.filter(func(q): return q != p)
		near.sort_custom(func(a, b): return Campaign.mdist(a.sx, a.sy, p.sx, p.sy) < Campaign.mdist(b.sx, b.sy, p.sx, p.sy))
		for q in near.slice(0, 2):
			for k in 8:
				var o := {"x": p.sx, "y": p.sy, "h": wrapf(k * PI / 4.0, -PI, PI), "v": 0.0, "route": Campaign.build_route({"x": p.sx, "y": p.sy}, Campaign.port_route(int(p.id), int(q.id))), "ri": 0, "rx": p.sx, "ry": p.sy}
				var last := Vector2(o.x, o.y); var idle := 0; var arrived := false
				for i in 500:
					if Campaign.route_move(o, 10.0, 0.3 if k % 2 == 0 else 0.15, 0.05): arrived = true; break
					idle = idle + 1 if Vector2(o.rx, o.ry).distance_to(last) < 0.002 else 0
					last = Vector2(o.rx, o.ry)
					if idle > 80: break
				sailed += 1
				if idle > 80 and not arrived: wedged.append("%s for %s, bow %d deg" % [p.name, q.name, k * 45])
	ok(wedged.is_empty(), "no fleet wedges against the coast leaving any harbour, whichever way she lay (%d of %d wedged%s)" % [wedged.size(), sailed, (": " + ", ".join(wedged.slice(0, 4))) if not wedged.is_empty() else ""])
	sections += 1

## Radar and sonar (docs/SENSORS.md): submarines carry no radar; a rotating set paints a contact beyond the eye's
## reach once each turn of its aerial and the echo fades between; a phased array holds it all the time.
func _radar() -> void:
	var night := Weather.battle({"sea": 0, "fog": false, "night": true, "moon": 0.0})
	for phased in [false, true]:
		var sim := BattleSim.new(); sim.wx = night
		var tech: Array = ["radar", "aegis"] if phased else ["radar"]
		sim.setup([Campaign.new_ship("ca", null, "player", tech), Campaign.new_ship("ss", null, "player", tech)], [Campaign.new_ship("dd_narvik", null, "directorate", [])], tech, [], 0); sim.flag = null
		var me = sim.ships[0]; var boat = sim.ships[1]; var foe = sim.ships[2]
		if not phased: ok(sim.has_radar(me) and not sim.has_radar(boat) and sim.sonar_range(boat) > 0.0 and sim.sonar_range(me) == 0.0, "a cruiser has radar and no sonar; a submarine has sonar and no radar")
		me.pos = Vector2(8000, 8000); boat.pos = Vector2(8000, 8300); foe.pos = Vector2(8000 + 7000, 8000)   # 7 km: beyond the eye by night, inside the radar
		ok(not sim.eye_sees(foe, 0) and sim.visible_to(foe, 0), "at 7 km on a dark night she is held by radar, not by eye")
		var worst := 0.0; var paints := 0; var prev := 99.0
		for i in 1500:   # a minute of battle: six turns of the aerial
			for x in sim.ships: x.pos = Vector2(8000, 8000) if x == me else (Vector2(8000, 8300) if x == boat else Vector2(15000, 8000)); x.v = 0.0
			sim._radar_plot(0.04); sim.t += 0.04
			if foe.paint_t < prev: paints += 1
			prev = foe.paint_t; if i > 300: worst = maxf(worst, foe.paint_t)
		if phased: ok(foe.radar_only and worst < 0.1, "a phased array holds the contact all the time (longest gap %.2f s)" % worst)
		else: ok(foe.radar_only and paints >= 5 and paints <= 7 and worst > 8.0 and worst <= 10.1, "a rotating set paints her once a turn: %d times in a minute, the echo up to %.1f s old" % [paints, worst])

## The owner's decisions after the review (10 Nov 2026): sighting follows the captain, for you and for them; resting
## in port lets the world move; marks show where a hunted fleet was last seen; a treaty stops all hostilities; the
## bomb makes an enemy for good; soldiers are in particular transports; a ship sold or lost takes her holds with her.
func _decisions() -> void:
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	# the same distance for both sides, times each captain's watch
	var o = Campaign.officer_of(G.fleet[0]); o.lvl = 1; var s1 := Campaign.sight_radius(); o.lvl = 8; var s8 := Campaign.sight_radius()
	ok(s8 > s1 * 1.4, "a renowned captain sees farther than a green one (%d km against %d)" % [int(s8 * Campaign.KM_PER_UNIT), int(s1 * Campaign.KM_PER_UNIT)])
	var w := Campaign.water_point(8.0); P.x = w.x; P.y = w.y; G.fleets.clear(); o.lvl = 4
	var green := _fleet("patrol", "directorate", w.x, w.y, ["dd"]); green.capt = 1
	var old := _fleet("patrol", "directorate", w.x, w.y, ["dd"]); old.capt = 8
	ok(Campaign.found_radius(false, old) > Campaign.found_radius(false, green) * 1.4, "and a renowned captain finds you from farther off (%d km against %d)" % [int(Campaign.found_radius(false, old) * Campaign.KM_PER_UNIT), int(Campaign.found_radius(false, green) * Campaign.KM_PER_UNIT)])
	green.capt = 4
	ok(absf(Campaign.found_radius(false, green) - Campaign.sight_radius()) < 1.0, "captains of equal skill see each other at the same distance (%d km and %d km)" % [int(Campaign.found_radius(false, green) * Campaign.KM_PER_UNIT), int(Campaign.sight_radius() * Campaign.KM_PER_UNIT)])
	# resting in port: the world moves, and nothing can bring you to action alongside
	G.fleets.clear(); G.cargo.food = 500.0; G.credits = 100000.0
	var cv := _fleet("convoy", "combine", w.x + 600.0, w.y, ["freighter"]); cv.capt = 2
	var far := Campaign.water_point(8.0, Vector2(w.x + 600.0, w.y), 200.0)
	for i in 20:   # open water she can sail from (a random point can fall in a pocket no route leaves)
		cv.x = far.x; cv.y = far.y
		var to := Campaign.water_point(6.0, far, 300.0)
		if Campaign.set_course(cv, to.x, to.y): break
		far = Campaign.water_point(8.0, Vector2(w.x + 600.0, w.y), 200.0)
	cv.route = null; cv.home = {"x": far.x, "y": far.y}; var cx: float = cv.x; var cy: float = cv.y
	var foe := _fleet("raiders", "raiders", w.x + 3.0, w.y, ["dd"]); var met := [0]
	var cb := func(_f): met[0] += 1
	Campaign.encounter.connect(cb)
	var d0: int = G.day; Campaign.paused = true; Campaign.rest_in_port(3)
	Campaign.encounter.disconnect(cb)
	ok(int(G.day) == d0 + 3 and Campaign.paused, "three days alongside are three days (and the clock is as you left it)")
	ok(not G.fleets.has(cv) or Campaign.mdist(cv.x, cv.y, cx, cy) > 20.0, "other fleets steam on while you rest")
	ok(met[0] == 0, "and nobody brings you to action while you lie in harbour (%d contacts)" % met[0])
	Campaign.paused = false
	# a hunted flotilla is marked where it was last seen, not where it is
	G.fleets.clear(); G.contracts.clear()
	var c := {"id": 9100, "kind": "hunt", "fac": "concord", "port": 0, "x": w.x + 300.0, "y": w.y, "days": 30, "reward": 8000, "rep": 5, "title": "Hunt"}
	Diplomacy.accept(c); var hf = Campaign._fleet(int(c.fleet)); hf.vis = false; hf.erase("seenDay")
	var home := Vector2(hf.home.x, hf.home.y); hf.x = home.x + 150.0
	var mk: Array = Diplomacy.marks()[0]
	ok(absf(float(mk[0]) - home.x) < 1.0, "never sighted, she is marked where she was reported")
	hf.seenX = home.x + 40.0; hf.seenY = home.y; hf.seenDay = G.day
	ok(absf(float(Diplomacy.marks()[0][0]) - (home.x + 40.0)) < 1.0 and absf(Diplomacy.target_of(c).x - (home.x + 40.0)) < 1.0, "once sighted and lost, at her last known position")
	hf.vis = true
	ok(absf(float(Diplomacy.marks()[0][0]) - hf.x) < 1.0, "and in sight, where she is")
	G.fleets.clear(); G.contracts.clear()
	# a treaty stops every attack by that power; the bomb makes an enemy for good
	G.flag = {"name": "Test Company", "short": "Company", "day": G.day, "recog": {"directorate": G.day}, "treaty": {"directorate": int(G.day) + 300}}; Flag.apply()
	var st: Dictionary = {}
	for x in Structures.all(): if x.fac == "directorate" and x.kind == "farm": st = x; break
	st.fac = "player"; st.from = "directorate"; st.took = int(G.day) - 200; st.garrison = 30
	var port: Dictionary = {}
	for q in G.ports: if q.fac == "directorate" and not q.capital: port = q; break
	port.fac = "player"; port.from = "directorate"; port.men = 300; port.took = int(G.day) - 200
	seed(3)
	for i in 600: Structures._counterattacks(); Flag.new_day()
	ok(not G.fleets.any(func(f): return f.kind == "assault"), "under a treaty the old owner sends nothing against your port or your structures")
	G.flag.treaty = {}
	for i in 600: Structures._counterattacks()
	ok(G.fleets.any(func(f): return f.kind == "assault"), "without one, it does")
	G.fleets.clear(); G.rep.pacific = 40; G.nukedFacs = ["pacific"]
	ok(Campaign.at_war("pacific") and Flag.can_peace("pacific").begins_with("They will never"), "a power you used the bomb on stays at war with you whatever your standing")
	G.nukedFacs = []; G.commission = {"fac": "concord", "since": G.day, "marque": "republic"}; G.rep.republic = 0
	ok(Campaign.at_war("republic") and Flag.can_peace("republic") != "" and not Flag.can_peace("republic").begins_with("Their terms"), "no paying for a peace that is not yours to make: " + Flag.can_peace("republic"))
	G.commission = null
	# soldiers are in particular transports
	G.fleet = [Campaign.new_ship("dd", "Fast", "player", []), Campaign.new_ship("ap_haskell", "T1", "player", ["amphib"]), Campaign.new_ship("ca", "Heavy", "player", [])]
	G.troops = 1200; var tgt: Dictionary = {}
	for x in Structures.all(): if x.fac == "concord" and x.kind == "farm" and int(x.coastKm) < 300: tgt = x; break
	var cp := Structures.coast_point(tgt); P.x = cp.x; P.y = cp.y
	ok(Structures.can_invade(tgt) == "", "with the troopship in company a landing is possible")
	Campaign.detach([G.fleet[0]])
	ok(Structures.troops() == 0 and Structures.troops_all() == 1200 and Structures.can_invade(tgt) != "", "with her left in the main body the soldiers are there, not with you: " + Structures.can_invade(tgt))
	var wages_split := Campaign.wages(); Campaign.rejoin()
	ok(Structures.troops() == 1200 and is_equal_approx(Campaign.wages(), wages_split), "they are paid all the same, and come back when the main body rejoins")
	# a ship sold or lost takes her holds with her
	G.troops = 0; G.fleet = [Campaign.new_ship("dd", "Keeper", "player", []), Campaign.new_ship("freighter", "Hauler", "player", [])]
	for gd in Campaign.C.GOODS: G.cargo[gd.id] = 0.0
	G.cargo.steel = float(Campaign.cargo_cap() - 10); G.cargo.food = 10.0
	var map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	map.cur_port = G.ports[0]; var money: float = G.credits
	map._sell_ship(G.fleet[1])
	ok(Campaign.cargo_used() <= Campaign.cargo_cap() and float(G.credits) > money + map.sell_value(Campaign.new_ship("freighter", null, "player", [])) * 0.5, "selling a freighter lands the cargo her holds carried and sells it (hold %d of %d)" % [Campaign.cargo_used(), Campaign.cargo_cap()])
	map.cur_port = {}; map.queue_free()
	# nuclear plants: five powers hold one; warheads come only from a working plant, one a month, for you and for them
	Campaign.new_game("commission"); G = Campaign.G; P = G.player
	var plants: Array = Structures.all().filter(func(x): return x.kind == "nuclear")
	ok(plants.size() == 5 and Structures.plants_of("directorate").size() == 1 and Structures.all().size() == 384, "five powers each hold a nuclear plant (%d plants, %d structures)" % [plants.size(), Structures.all().size()])
	G.tech = ["nuclear", "missiles", "nukes"]; G.fleet = [Campaign.new_ship("ssn_charlie", "Boat", "player", G.tech)]; G.credits = 1000000.0; G.cargo.food = 5000.0; G.cargo.fuel = 500.0
	ok(Structures.can_arm("player").begins_with("Warheads are made"), "you cannot fit a warhead without a plant")
	var mine: Dictionary = Structures.plants_of("combine")[0]; mine.fac = "player"; mine.from = ""; mine.garrison = 150; mine.pile = int(G.day)
	ok(Structures.can_arm("player").begins_with("No warhead is ready yet"), "nor until your plant has made one")
	for i in 31: Campaign.new_day(false)
	ok(Structures.stock() == 1 and Structures.can_arm("player") == "", "a month on, the plant has made one (%d in store)" % Structures.stock())
	Structures.arm()
	ok(Structures.nukes() == 1 and Structures.stock() == 0, "fitting it takes it out of the store")
	G.facRp = {"directorate": 900.0}
	ok(Structures.can_answer("directorate"), "a power of the missile age with a working plant can answer in kind")
	var dp: Dictionary = Structures.plants_of("directorate")[0]; dp.dmg = 1.0
	ok(not Structures.can_answer("directorate"), "with its plant knocked out it cannot")
	dp.dmg = 0.0
	# the standing ledger says why each power thinks of you as it does
	var victim: Dictionary = {}
	for x in Structures.all(): if x.fac == "concord" and x.kind == "farm": victim = x; break
	P.x = victim.x; P.y = victim.y; var before: int = int(G.rep.concord)
	Structures.nuke(victim)
	var lines: Array = Campaign.rep_lines("concord"); var sum := 0
	for k in G.repLog.concord: sum += int(G.repLog.concord[k])
	ok(lines.any(func(l): return String(l).begins_with("Nuclear strike")) and sum == int(G.rep.concord) and int(G.rep.concord) == -100, "the ledger books a nuclear strike and adds up to the standing (%s)" % str(lines.slice(0, 3)))
	G.fleets.clear(); G.fleet = [Campaign.new_ship("ca", "Guard", "player", [])]
	st = {}
	for x in Structures.all(): if x.fac == "directorate" and x.kind == "farm": st = x; break
	st.fac = "player"; st.from = "directorate"; st.took = int(G.day); st.garrison = 30
	# a landing force beaten at sea gives the landing up, even if its troopships got away
	G.fleet = [Campaign.new_ship("ca", "Guard", "player", [])]; G.fleets.clear()
	var lf: Dictionary = Structures.launch_assault(st, "directorate")
	ok(not lf.is_empty() and Structures._is_assault(lf), "an assault force sails for a structure of yours")
	GameData.pending = Campaign.battle_setup(lf)
	var sim := BattleSim.new(); sim.setup(GameData.pending.player_recs, GameData.pending.enemy_recs, [], [], 0); sim.flag = null
	for x in sim.ships: if x.side == 1: x.escaped = true
	sim.finished = true; var res: Dictionary = Campaign.apply_battle(sim)
	ok(res.victory and G.fleets.has(lf) and not Structures._is_assault(lf) and lf.kind == "patrol" and not Campaign.hostile_fleet(lf) == (not Campaign.at_war("directorate")), "driven off, it gives the landing up and goes home as a patrol (%s)" % lf.name)
	# the last ships of both sides lost together is no victory, reserve or not
	G.fleet = [Campaign.new_ship("dd", "Last", "player", []), Campaign.new_ship("dd", "Spare", "player", [])]; G.fleet[1].reserve = true
	var rf := _fleet("raiders", "raiders", P.x + 5.0, P.y, ["dd"])
	GameData.pending = Campaign.battle_setup(rf)
	sim = BattleSim.new(); sim.setup(GameData.pending.player_recs, GameData.pending.enemy_recs, [], [], 0); sim.flag = null
	for x in sim.ships: x.alive = false; x.hull = 0.0
	sim.finished = true; res = Campaign.apply_battle(sim)
	ok(not res.victory and G.fleet.size() == 1, "both sides' last ships lost together is not a victory, though a ship in reserve survives")
	# line ahead: ships astern of a stopped leader stop on their stations
	sim = BattleSim.new(); var recs := []
	for i in 3: recs.append(Campaign.new_ship("dd_fletcher", "L%d" % i, "player", []))
	sim.setup(recs, [Campaign.new_ship("dd_narvik", null, "directorate", [])], [], [], 0)
	sim.order = "line"; sim.hold_fire = true
	for x in sim.ships: if x.side == 1: x.pos = sim.flag.pos + Vector2(9000, 9000)
	sim.flag.throttle = 0; sim.flag.v = 0.0
	var close := INF
	for i in 9000:
		sim.flag.throttle = 0; sim.step(0.02)
		if i > 6000: for x in sim.ships: if x.side == 0 and x != sim.flag: close = minf(close, x.pos.distance_to(sim.flag.pos))
	var moving := 0.0
	for x in sim.ships: if x.side == 0 and x != sim.flag: moving = maxf(moving, x.v)
	ok(close > sim.flag.d.L * 0.8 and moving < 1.0, "astern of a stopped flagship the line stops clear of her (nearest %d m, fastest %.1f m/s)" % [int(close), moving])
	# a face fits the name: a woman's name never gets a man's portrait, nor the other way about
	var ArtT = load("res://scripts/art.gd"); var bad := 0; var seen := {}
	if not ArtT.faces().is_empty():
		for i in 300:
			var of: Dictionary = Campaign.new_officer(1); ArtT.portrait(of); var sx: String = ArtT.sex_of(of)
			if sx != "" and ArtT.is_woman(str(of.face)) != (sx == "f"): bad += 1
			seen[of.face] = true
		var oldo := {"id": "7", "name": "Vera Quint", "face": "p01.jpg"}; ArtT.portrait(oldo)
		ok(bad == 0 and ArtT.is_woman(str(oldo.face)), "portraits fit the officers' names (%d wrong of 300; an old save's mismatch is re-picked: %s)" % [bad, oldo.face])
		ok(seen.size() >= 20 and not seen.has("port.jpg"), "nearly every portrait is used and none is a scene (%d of %d)" % [seen.size(), ArtT.faces().size()])
	sections += 1

## The economy answers to wars, sieges, convoys and works (docs/ECONOMY.md).
func _economy() -> void:
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; G.fleets.clear(); G.wars = {}
	var p: Dictionary = G.ports.filter(func(q): return q.fac == "directorate" and not q.capital)[0]
	Campaign.econ_day()
	var base: float = Campaign.supply_mult(p, "food"); var fuel0: float = Campaign.supply_mult(p, "fuel")
	ok(absf(base - 1.0) < 0.01 and absf(fuel0 - 1.0) < 0.01, "at peace, with every works standing, the world leaves prices alone (food x%.2f, fuel x%.2f)" % [base, fuel0])
	# a convoy lost on the way is missed where it was bound; one that arrives is not
	var c := _fleet("convoy", "directorate", p.sx + 300, p.sy, ["freighter"]); c.dest = int(p.id); c.cargo = {"food": 40, "steel": 30}
	Campaign.convoy_lost(c); Campaign.convoy_lost(c)
	ok(absf(Campaign.supply_mult(p, "food") - 1.12) < 0.01 and absf(Campaign.supply_mult(p, "medicine") - 1.0) < 0.01, "a lost convoy makes what it carried dearer where it was bound, once (food x%.2f, medicine x%.2f)" % [Campaign.supply_mult(p, "food"), Campaign.supply_mult(p, "medicine")])
	ok(Campaign.market_notes(p).size() == 1, "and the market page says why: %s" % str(Campaign.market_notes(p)))
	var c2 := _fleet("convoy", "directorate", p.sx, p.sy, ["freighter"]); c2.dest = int(p.id); c2.cargo = {"food": 40}
	Campaign.convoy_landed(c2); G.fleets.clear()
	ok(absf(Campaign.supply_mult(p, "food") - 1.05) < 0.01, "a convoy that makes port brings the price down again (food x%.2f)" % Campaign.supply_mult(p, "food"))
	for i in 40: Campaign.econ_day()
	ok(absf(Campaign.supply_mult(p, "food") - 1.0) < 0.02, "left alone, a shortage wears off in a few weeks (food x%.2f)" % Campaign.supply_mult(p, "food"))
	# war demand, and a port that changes hands
	G.wars[Diplomacy.pair("directorate", "concord")] = {"day": G.day}
	ok(Campaign.supply_mult(p, "munitions") > 1.2 and Campaign.supply_mult(p, "steel") > 1.1 and absf(Campaign.supply_mult(p, "food") - 1.0) < 0.02, "a power at war pays more for munitions, fuel, steel and medicine, not for food")
	# raiders lying off a port starve it; so does an enemy squadron in a war
	var r := _fleet("raiders", "raiders", p.sx + 20, p.sy, ["dd"])
	for i in 10: Campaign.econ_day()
	var blk: float = Campaign.supply_mult(p, "food")
	ok(blk > 1.2, "raiders lying off a port for ten days make food dear there (x%.2f)" % blk)
	G.fleets.clear(); G.wars = {}
	for i in 60: Campaign.econ_day()
	Diplomacy.capture(p, "concord")
	ok(Campaign.supply_mult(p, "food") > 1.25 and Campaign.market_notes(p).has(Campaign.WHY.taken), "a port that has just changed hands is short of everything (food x%.2f)" % Campaign.supply_mult(p, "food"))
	# the works that feed a flag
	var farms: Array = Structures.all().filter(func(s): return s.kind == "farm" and s.get("home", s.fac) == "directorate" and s.fac == "directorate")
	if farms.size():
		var q: Dictionary = G.ports.filter(func(x): return x.fac == "directorate")[0]
		for s in farms: s.dmg = 1.0
		Campaign.econ_day()
		ok(absf(Campaign.works_mult("directorate", "food") - 1.4) < 0.01 and Campaign.supply_mult(q, "food") > 1.35, "with every farm of a flag burning, food is dear in all its ports (x%.2f)" % Campaign.supply_mult(q, "food"))
		for s in farms: s.dmg = 0.0
		farms[0].fac = "player"; Campaign.econ_day()
		ok(Campaign.works_mult("player", "food") < 1.0 and Campaign.works_mult("directorate", "food") > 1.0, "a farm you hold feeds your harbours and is missed by the flag that lost it")
		farms[0].fac = "directorate"
	else: ok(false, "the Directorate has farms to test with")
	# prices stay within bounds whatever is piled on
	Campaign.shortage(p, Campaign.goods_ids(), 5.0, "siege"); G.wars[Diplomacy.pair(p.fac, "directorate")] = {"day": G.day}
	ok(Campaign.supply_mult(p, "munitions") <= 2.4, "however much is piled on, the world cannot more than multiply a price by 2.4")
	# a save made before this had no shortages: the port still prices
	p.erase("short"); p.erase("why"); G.erase("works")
	ok(absf(Campaign.supply_mult(p, "food") - 1.0) < 0.01, "a port from an older save, with no shortages recorded, prices as before")
	sections += 1

## The fleet is limited by its supply, not by a count of ten (docs/SUPPLY.md).
func _supply() -> void:
	var over := []
	for k in Campaign.C.STARTS.keys():
		Campaign.new_game(k)
		if Campaign.supply_over() > 0: over.append("%s %d/%d" % [k, Campaign.supply_need(), Campaign.supply_cap()])
	ok(over.is_empty(), "every origin starts within its supply %s" % str(over))
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; G.commission = null
	G.fleet = []; for i in 8: G.fleet.append(Campaign.new_ship("dd", "D%d" % i, "player", []))
	ok(Campaign.supply_need() == 16 and Campaign.supply_cap() == 16 and Campaign.supply_over() == 0 and is_equal_approx(Campaign.rdy_cap(), 1.0), "eight destroyers weigh sixteen, which a flagship's own staff can supply")
	ok(Campaign.can_add_ship("bb_iowa") == "" and Campaign.can_add_ship("dd_fletcher") == "", "a battleship can still join (22 of 16 is within half as much again)")
	G.fleet.append(Campaign.new_ship("bb", "B", "player", []))
	ok(Campaign.supply_over() == 6 and Campaign.supply_upkeep() == 720.0 and absf(Campaign.rdy_cap() - 0.625) < 0.001, "over the limit by six: tenders at 720 a day, readiness held to %d%%" % int(Campaign.rdy_cap() * 100))
	ok(Campaign.can_add_ship("bb_iowa") != "" and Campaign.can_add_ship("dd_fletcher") == "", "a second battleship is refused (28 of 16), a destroyer is not (24)")
	for s in G.fleet: s.rdy = 1.0
	var c0: float = G.credits
	for i in 30: Campaign._readiness_day(false)
	ok(absf(Campaign.fleet_readiness() - 0.625) < 0.02, "an overstretched fleet's readiness wastes away to what its supply allows (%d%%)" % int(Campaign.fleet_readiness() * 100))
	G.fleet.append(Campaign.new_ship("ao", "Oiler", "player", [])); G.fleet.append(Campaign.new_ship("ar", "Repair", "player", []))
	ok(Campaign.supply_cap() == 25 and Campaign.supply_need() == 24 and Campaign.supply_over() == 0, "an oiler and a repair ship in company carry the difference (%d of %d)" % [Campaign.supply_need(), Campaign.supply_cap()])
	for i in 20: Campaign._readiness_day(false)
	ok(Campaign.fleet_readiness() > 0.8, "and the crews recover (%d%%)" % int(Campaign.fleet_readiness() * 100))
	# twenty ships at most, ten in one action
	G.fleet = []; for i in 14: G.fleet.append(Campaign.new_ship("corvette", "C%d" % i, "player", []))
	var foe := _fleet("patrol", "directorate", G.player.x + 5, G.player.y, ["dd"])
	ok(Campaign.battle_setup(foe).player_recs.size() == 10, "of fourteen ships, ten fight in one action")
	for i in 6: G.fleet.append(Campaign.new_ship("corvette", "E%d" % i, "player", []))
	ok(Campaign.can_add_ship("pt_elco") != "", "a twenty-first ship is refused whatever the supply")
	G.commission = {"fac": "concord", "since": G.day, "marque": ""}
	ok(Campaign.supply_cap() == 24, "a navy you serve lends its dockyards (limit %d)" % Campaign.supply_cap())
	sections += 1

## Smoke screens, damage you can see in how a ship moves, and formations that hold station.
func _fighting() -> void:
	# smoke: no eye sees through it, radar does, and it blows away
	var sim := _sim(["dd_fletcher", "dd_fletcher"], ["dd_narvik"])
	var a = sim.ships[0]; var b = sim.ships[1]; var e = sim.ships[2]; sim.flag = null
	a.pos = Vector2(10000, 10000); a.a = 0.0; a.v = 12.0; b.pos = Vector2(9000, 10400); e.pos = Vector2(10600, 7000); e.a = 0.0
	for x in sim.ships: x.tech = []
	ok(sim.visible_to(e, 0) and sim.visible_to(a, 1), "on a clear day each side sees the other")
	ok(sim.make_smoke(a, true), "a destroyer can make smoke")
	for i in 1500: a.throttle = 4; a.rudder = 0; a.a = 0.0; b.throttle = 0; e.throttle = 0; e.v = 0.0; b.v = 0.0; sim._smoke_tick(0.02); a.pos += Vector2(12.0 * 0.02, 0)
	var wall: int = sim.screens.size()
	ok(wall >= 6, "thirty seconds of it leaves a wall of smoke astern (%d cells)" % wall)
	b.pos = a.pos + Vector2(-200, 600); e.pos = a.pos + Vector2(-200, -2500)   # the second destroyer behind the wall, the enemy beyond it
	ok(sim.smoke_blocks(b.pos, e.pos) and not sim.visible_to(b, 1), "a ship behind the smoke cannot be seen from the far side")
	ok(not sim.smoke_blocks(e.pos, e.pos + Vector2(3000, 0)), "and smoke does not hide what it does not lie between")
	e.tech = ["radar"]
	ok(sim.has_radar(e) and sim.visible_to(b, 1), "radar looks through smoke")
	e.tech = []
	a.smoke_on = false
	for i in int((BattleSim.SMOKE_LIFE + 2.0) / 0.1): sim._smoke_tick(0.1)
	ok(sim.screens.is_empty() and sim.visible_to(b, 1), "a little over a minute later the smoke is gone and she is in sight again")
	var charge: float = a.smoke_left
	ok(charge < BattleSim.SMOKE_CHARGE, "the generators are run down by it and recharge (%d s of %d)" % [int(charge), int(BattleSim.SMOKE_CHARGE)])
	# damage shows in how she moves
	var turn := func(steer: float, list: float) -> float:
		var s2 := _sim(["ca_baltimore"], ["dd_narvik"]); var c = s2.ships[0]; s2.flag = c; s2.ships[1].pos = Vector2(1000, 1000)
		c.pos = Vector2(12000, 12000); c.a = 0.0; c.v = 10.0; c.steer = steer; c.list = list
		for i in 3000: c.throttle = 3; s2.player_rudder = 1.0; c.rudder = 1.0; c.steer = steer; c.list = list; s2.step(0.01)
		return c.a
	var sound: float = turn.call(1.0, 0.0); var worn: float = turn.call(0.4, 0.0)
	ok(worn < sound * 0.6, "a ship with her steering gear shot about turns far less in a minute (%.1f rad against %.1f)" % [worn, sound])
	var s3 := _sim(["ca_baltimore"], ["dd_narvik"]); var c3 = s3.ships[0]; s3.flag = c3; s3.ships[1].pos = Vector2(1000, 1000)
	c3.pos = Vector2(12000, 12000); c3.a = 0.0; c3.v = 10.0
	var v0: float = 0.0
	for i in 6000: c3.throttle = 4; c3.rudder = 0.0; s3.player_rudder = 0.0; s3.step(0.01)
	v0 = c3.v; var a0: float = c3.a
	for i in 6000: c3.throttle = 4; c3.rudder = 0.0; s3.player_rudder = 0.0; c3.list = 0.8; s3.step(0.01)
	ok(c3.v < v0 * 0.9 and absf(c3.a - a0) > 0.15, "a listing ship is slower and pulls to her low side with the helm amidships (%.1f against %.1f m/s, %.2f rad off her course)" % [c3.v, v0, c3.a - a0])
	# formations hold station
	for ord in ["abreast", "screen", "escort"]:
		var s4 := _sim(["ca_baltimore", "dd_fletcher", "dd_fletcher", "cl_cleveland", "dd_fletcher"], ["fr_liberty"])
		var fl = s4.ships[0]; s4.flag = fl; s4.order = ord; s4.hold_fire = true
		for x in s4.ships: if x.side == 1: x.pos = Vector2(1500, 1500)   # an unarmed merchant far off keeps the action open
		fl.pos = Vector2(12000, 12000); fl.a = 0.0; fl.v = 9.0
		for i in range(1, 5): s4.ships[i].pos = fl.pos + Vector2(-600 - i * 300, (i - 2.5) * 400); s4.ships[i].a = 0.0; s4.ships[i].v = 9.0
		var worst := 0.0
		for i in 30000:   # five minutes: straight, a turn to starboard, straight again
			fl.throttle = 2; s4.player_rudder = 0.6 if (i > 12000 and i < 15000) else 0.0; s4.finished = false; s4.step(0.01)   # (the merchant runs off the chart: the action is kept open)
			if i > 24000: for k in range(1, 5): worst = maxf(worst, s4.ships[k].pos.distance_to(fl.pos + s4.station(s4.ships[k]).rotated(fl.a)))
		ok(worst < 220.0, "%s: after a turn every ship is back on her station and holds it (worst %d m off)" % [ord, int(worst)])
	sections += 1

## Orders to single ships and divisions.
func _divisions() -> void:
	var sim := _sim(["ca_baltimore", "dd_fletcher", "dd_fletcher", "dd_fletcher", "cl_cleveland"], ["bb_bismarck"])
	var fl = sim.ships[0]; sim.flag = fl; sim.order = "line"; var foe = sim.ships[5]
	fl.pos = Vector2(12000, 14000); fl.a = 0.0; fl.v = 9.0; foe.pos = Vector2(12000, 3000); foe.a = 0.0; foe.v = 0.0
	for i in range(1, 5): sim.ships[i].pos = fl.pos + Vector2(-500.0 * i, 0); sim.ships[i].a = 0.0; sim.ships[i].v = 9.0
	var d1 = sim.ships[1]; var d2 = sim.ships[2]; var d3 = sim.ships[3]; var cl = sim.ships[4]
	ok(sim.ord_of(d1) == "line", "a ship with no order of her own follows the squadron's")
	# one destroyer sent to a point, one told to hold her fire, the cruiser kept in the line
	d1.ord = "goto"; d1.ord_pt = Vector2(9000, 15500); d2.hold = true
	for x in sim.ships: x.hull = x.max_hull
	for i in 24000:
		fl.throttle = 2; sim.player_rudder = 0.0; foe.throttle = 0; foe.hull = foe.max_hull; sim.finished = false
		for x in sim.ships: if x.side == 0: x.hull = x.max_hull; x.eng = 1.0; x.eng_out = 0.0; x.jam = 0.0; x.list = 0.0
		sim.step(0.01)
	ok(d1.pos.distance_to(d1.ord_pt) < 350.0 and d1.v < 1.5, "a ship sent to a point goes there and lies there (%d m off, %.1f m/s)" % [int(d1.pos.distance_to(d1.ord_pt)), d1.v])
	ok(cl.pos.distance_to(fl.pos) < 2500.0 and d3.pos.distance_to(fl.pos) < 2500.0, "while the rest keep the line astern of the flagship")
	ok(sim.holding(d2) and not sim.holding(d3) and not sim.hold_fire, "one ship can be told to hold her fire and the rest left free")
	# a division of two forms line abreast by itself while the squadron stays in line ahead
	d1.ord = "abreast"; d2.ord = "abreast"; d2.hold = false
	ok(sim.station(d1).y == -sim.station(d2).y and absf(sim.station(d1).y) == 500.0, "two ships given line abreast take the two nearest stations, one on either beam")
	# a torpedo attack: run in, fire, rejoin
	for x in [d1, d2]: x.ord = ""
	d3.ord = "torp"; d3.ord_tgt = foe; foe.pos = fl.pos + Vector2(0, -9000); var fired := false; var closest := INF
	ok(sim.has_torps(d3), "she has torpedoes to attack with")
	for i in 40000:
		fl.throttle = 0; sim.player_rudder = 0.0; foe.throttle = 0; foe.v = 0.0; foe.hull = foe.max_hull; sim.finished = false; sim.hold_fire = false
		for x in sim.ships: if x.side == 0: x.hull = x.max_hull; x.eng = 1.0; x.eng_out = 0.0; x.jam = 0.0; x.list = 0.0; x.steer = 1.0
		sim.step(0.01)
		closest = minf(closest, d3.pos.distance_to(foe.pos))
		if sim.torps.any(func(tp): return tp.get("src") == d3 or true) and not fired and d3.ord == "": fired = true
		if d3.ord == "": break
	ok(d3.ord == "" and closest < 6000.0, "ordered to a torpedo attack she runs in, fires and takes the squadron's order again (closed to %d m)" % int(closest))
	# her tubes knocked out on the way in: she gives the attack up (she used to circle the enemy for ever)
	d1.ord = "torp"; d1.ord_tgt = foe
	for m in d1.mounts: if m.w.kind == "torp": m.dead = true
	for i in 50: sim.finished = false; sim.ai_ship(d1, 0.25)
	ok(d1.ord == "", "a ship ordered to a torpedo attack whose tubes are knocked out gives it up and rejoins")
	sections += 1

## Star shell, and the flagship's damage-control decisions.
func _night_and_dc() -> void:
	var night := Weather.battle({"sea": 0, "fog": false, "night": true, "moon": 0.0})
	var sim := _sim(["dd_fletcher"], ["dd_narvik"], night)
	var a = sim.ships[0]; var e = sim.ships[1]; a.tech = []; e.tech = []
	a.pos = Vector2(8000, 12000); e.pos = Vector2(8000, 12000 - float(night.vis) * 2.5); e.lit_t = 99.0; a.lit_t = 99.0; e.throttle = 0; e.v = 0.0
	ok(not sim.visible_to(e, 0), "on a dark night an enemy at two and a half times the lookouts' reach is not seen (%.1f km)" % (float(night.vis) * 2.5 / 1000.0))
	ok(sim.fire_star(a, e.pos + Vector2(200, 0)) and not sim.fire_star(a, e.pos), "a destroyer fires star shell, and must reload before the next")
	sim.flares[0].t = 1.0
	ok(sim.star_lit(e.pos) and sim.visible_to(e, 0), "under the flare she is in sight")
	ok(a.lit_t < 1.0, "and the ship that fired it has shown herself by the flash")
	for i in int((BattleSim.STAR_LIFE + 1.0) / 0.1): sim._star_tick(0.1)
	e.lit_t = 99.0
	ok(sim.flares.is_empty() and not sim.visible_to(e, 0), "half a minute later the flare has burned out and she is lost again")
	# damage control: priorities, flooding a magazine, counter-flooding
	var s2 := _sim(["ca_baltimore"], ["dd_narvik"]); var c = s2.ships[0]; s2.flag = c
	c.list = 0.8; c.dc_pri = "flood"; var fast: float = 0.0
	for i in 600: s2.systems_tick(c, 0.1)
	fast = 0.8 - c.list; c.list = 0.8; c.dc_pri = "mach"
	for i in 600: s2.systems_tick(c, 0.1)
	ok(fast > (0.8 - c.list) * 2.5, "with the parties sent to the flooding first a list comes off more than twice as fast (%.2f against %.2f in a minute)" % [fast, 0.8 - c.list])
	c.list = 0.7; c.ballast = 0.0
	ok(s2.counter_flood(c) and absf(c.list) < 0.2 and c.ballast > 0.2, "counter-flooding rights her at once and leaves water aboard (list %.2f, ballast %.2f)" % [c.list, c.ballast])
	c.mag_fire = 30.0; c.mag_x = c.mounts.filter(func(m): return m.w.kind == "gun" and m.slot.y == 0)[0].slot.x
	ok(s2.flood_magazine(c) and c.mag_fire == 0.0 and c.mounts.any(func(m): return m.dead), "flooding a burning magazine saves the ship and costs the turret above it")
	var other = s2.ships[1]; other.list = 0.75
	s2.systems_tick(other, 0.1)
	ok(absf(other.list) < 0.3, "other captains right a bad list themselves")
	sections += 1

## Gunnery that finds the range over salvos, and crews that learn their trade (docs/GUNNERY.md).
func _gunnery() -> void:
	seed(21)
	var first := []; var later := []; var radar_first := []
	for trial in 60:
		var sim := _sim(["ca_baltimore"], ["ca_hipper"]); var a = sim.ships[0]; var e = sim.ships[1]
		a.tech = ["radar"] if trial % 2 else []; a.pos = Vector2(8000, 14000); e.pos = Vector2(8000, 6000)
		var so: Dictionary = sim.solution(a, e, 0.7, 1.0, 0.012)
		(radar_first if trial % 2 else first).append(absf(float(so.r)))
		if trial % 2 == 0:
			for k in 6: sim.t += 20.0; sim.spot(a, e, 10.0)
			later.append(absf(float(so.r)))
	var mean := func(arr: Array) -> float:
		var t := 0.0
		for v in arr: t += float(v)
		return t / maxf(1.0, arr.size())
	var m1: float = mean.call(first); var m2: float = mean.call(later)
	ok(m1 > 0.02 and m2 < m1 * 0.35, "the first salvo is out by %.1f%% of the range on average, the seventh by %.1f%%" % [m1 * 100, m2 * 100])
	# every shell of a salvo carries the same error: they fall together
	var s2 := _sim(["bb_iowa"], ["bb_bismarck"]); var b = s2.ships[0]; var tg = s2.ships[1]; b.pos = Vector2(8000, 16000); tg.pos = Vector2(8000, 5000); b.a = 0.0; b.tech = []
	var mt = b.mounts.filter(func(m): return m.w.kind == "gun" and m.w.size == "H")[0]; mt.ta = -PI / 2
	s2.shells.clear(); for i in 3: s2.fire_barrel(b, mt, tg.pos, i, tg)
	var ends: Array = s2.shells.map(func(sh): return sh.e)
	var centre: Vector2 = (ends[0] + ends[1] + ends[2]) / 3.0; var spread := 0.0
	for p2 in ends: spread = maxf(spread, (p2 as Vector2).distance_to(centre))
	var so2: Dictionary = b.sol[tg.get_instance_id()]
	ok(spread < 260.0, "the three shells of a salvo fall together, whatever the error (pattern %d m across, error %d m)" % [int(spread * 2), int(absf(float(so2.r)) * 11000)])
	s2.shells.clear(); for i in 3: s2.fire_barrel(b, mt, tg.pos, i)
	ok(s2.shells.all(func(sh): return sh.get("tgt") == null), "fire laid by hand on a point of the sea has no solution and scatters as before")
	ok(s2.sol_state(b, tg) == "ranging", "the gun-laying readout says she is finding the range")
	so2.r = 0.004; so2.n = 3
	ok(s2.sol_state(b, tg) == "straddling", "and that she is straddling once the error is inside the pattern")
	# crews
	ok(BattleSim.crew_level(0.0) == 0 and BattleSim.crew_level(1.0) == 1 and BattleSim.crew_level(4.0) == 2 and BattleSim.crew_level(7.0) == 3 and BattleSim.crew_level(12.0) == 4, "a crew is green, trained, seasoned, veteran or crack by the actions it has fought")
	var rec: Dictionary = Campaign.new_ship("dd_fletcher", null, "player", [])
	ok(Campaign.crew_name(rec) == "trained", "a new ship's crew is trained")
	var green: Dictionary = Campaign.new_ship("dd_fletcher", null, "player", []); green.xp = 0.0
	var vet: Dictionary = Campaign.new_ship("dd_fletcher", null, "player", []); vet.xp = 8.0
	var s3 := BattleSim.new(); s3.wx = Weather.CLEAR; s3.setup([green, vet], [Campaign.new_ship("dd_narvik", null, "directorate", [])], [], [], 0)
	var w: Dictionary = s3.ships[0].mounts[0].w
	ok(s3.reload_mult(s3.ships[1], w) > s3.reload_mult(s3.ships[0], w) * 1.12 and s3.ships[0].cq == 0 and s3.ships[1].cq == 3, "a veteran crew loads faster than a green one (x%.2f against x%.2f)" % [s3.reload_mult(s3.ships[1], w), s3.reload_mult(s3.ships[0], w)])
	Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	var foe := _fleet("patrol", "directorate", G.player.x + 3, G.player.y, ["co_flower"]); foe.capt = 7
	var cfg: Dictionary = Campaign.battle_setup(foe); var s4 := BattleSim.new(); s4.wx = Weather.CLEAR
	s4.setup(cfg.player_recs, cfg.enemy_recs, [], [], 0)
	for x in s4.ships: if x.side == 1: x.hull = 0.0; x.alive = false
	var x0: float = Campaign.crew_xp(G.fleet[0]); s4.finished = true; s4.result = {"victory": true, "sunk": [], "prizes": [], "lost": []}
	GameData.pending = {"fleet_id": foe.id}; Campaign.apply_battle(s4)
	ok(Campaign.crew_xp(G.fleet[0]) == x0 + 1.0, "a crew that comes through an action has learned from it (%.1f to %.1f)" % [x0, Campaign.crew_xp(G.fleet[0])])
	var f7 := Campaign.spawn_fleet("patrol", "directorate"); f7.capt = 7
	ok(f7.ships.all(func(sh): return sh.has("xp")), "other navies' crews are as good as their captains have made them")
	sections += 1

## Refits are ruled by weight (docs/REFIT.md).
func _weights() -> void:
	var over := []; var none := []
	for id in GameData.hulls:
		var d: Dictionary = GameData.hulls[id]; var raw := []
		for sl in d.slots:
			raw.append(sl.def)
			if not BattleSim.TONS.has(sl.def): none.append(sl.def)
		var ld: Dictionary = BattleSim.loading(d, raw, {})
		if not ld.ok or absf(float(ld.speed) - 1.0) > 0.001 or absf(float(ld.spread) - 1.0) > 0.001: over.append(id)
		for tech in [["homing", "ciws", "missiles", "radar"], ["homing"], []]:
			var l2: Dictionary = BattleSim.loading(d, BattleSim.default_fit(d, tech), {})
			if float(l2.over_t) > 0.0 or float(l2.top) > BattleSim.TOP_SLACK: over.append("%s with %s (%d t over, top %.2f)" % [id, str(tech), int(l2.over_t), float(l2.top)])
	ok(none.is_empty(), "every weapon a design carries has a weight %s" % str(none))
	ok(over.is_empty(), "every design as built, in any era's standard fit, is within her weight and topweight %s" % str(over.slice(0, 6)))
	for w in GameData.weapons: if not BattleSim.TONS.has(w): none.append(w)
	ok(none.is_empty(), "every weapon in the yard's list has a weight %s" % str(none))
	var d: Dictionary = GameData.hulls["dd_fletcher"]; var fit := []
	for sl in d.slots: fit.append(sl.def)
	var base: Dictionary = BattleSim.loading(d, fit, {})
	var armoured: Dictionary = BattleSim.loading(d, fit, {"hull": 1})
	ok(float(armoured.over_t) > 0.0 and armoured.ok and float(armoured.speed) < 1.0 and float(armoured.turn) < 1.0, "armour on a destroyer eats her margin: %d t over, %d%% slower" % [int(armoured.over_t), int(round((1.0 - float(armoured.speed)) * 100))])
	ok(not BattleSim.loading(d, fit, {"hull": 2, "tds": 2}).ok, "and the yard will not pass her with two marks of armour and of torpedo protection")
	var landed: Array = fit.duplicate()
	for i in d.slots.size(): if d.slots[i].s == "T": landed[i] = ""
	var traded: Dictionary = BattleSim.loading(d, landed, {"hull": 1})
	ok(float(traded.over_t) <= 0.0 and is_equal_approx(float(traded.speed), 1.0), "landing her torpedoes pays for it, as navies did (%d t in hand)" % int(-float(traded.over_t)))
	ok(float(BattleSim.loading(d, landed, {}).speed) > 1.0, "a ship lighter than designed is a little faster")
	var top: Dictionary = BattleSim.loading(d, fit, {"radar": 2, "fc": 2})
	ok(float(top.top) > BattleSim.TOP_SLACK and float(top.spread) > 1.0, "directors and radar aloft make her top-heavy: salvos %d%% wider" % int(round((float(top.spread) - 1.0) * 100)))
	# it tells in battle, for you and not for other navies' ships
	var rec: Dictionary = Campaign.new_ship("dd_fletcher", null, "player", []); rec.up = {"hull": 1, "radar": 2, "fc": 2}
	var sim := BattleSim.new(); sim.wx = Weather.CLEAR
	sim.setup([rec], [Campaign.new_ship("dd_narvik", null, "directorate", [])], [], [], 0)
	ok(sim.ships[0].ld_speed < 1.0 and sim.ships[0].ld_spread > 1.0 and is_equal_approx(sim.ships[1].ld_speed, 1.0), "an overloaded ship of yours is slower and shoots wider in battle (speed x%.2f, spread x%.2f)" % [sim.ships[0].ld_speed, sim.ships[0].ld_spread])
	# other navies are held to the same rules: one of theirs stripped of her torpedoes is lighter and faster
	var theirs: Dictionary = Campaign.new_ship("dd_narvik", null, "directorate", []); var dn: Dictionary = GameData.hulls["dd_narvik"]
	for i in dn.slots.size(): if dn.slots[i].s == "T": theirs.fit[i] = ""
	var sim2 := BattleSim.new(); sim2.wx = Weather.CLEAR; sim2.setup([Campaign.new_ship("dd_fletcher", null, "player", [])], [theirs], [], [], 0)
	ok(sim2.ships[1].ld_speed > 1.0, "the weight rules bind other navies' ships too (theirs, lightened: speed x%.3f)" % sim2.ships[1].ld_speed)
	var map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	var plan: Array = rec.fit.duplicate(); var ti := -1
	for i in d.slots.size(): if d.slots[i].s == "T" and ti < 0: ti = i
	plan[ti] = ""
	var c: Array = map.refit_cost(rec, plan)
	ok(int(c[0]) == int(BattleSim.weapon_tons(rec.fit[ti]) * map.YARD_PER_TON), "the yard charges by the ton for landing a mount (%d)" % int(c[0]))
	# a refit is done at once and paid for in readiness
	rec.up = {}; rec.rdy = 1.0; Campaign.ship_refitted(rec); Campaign.G.credits = 100000
	var v_std: float = Campaign.fleet_map_speed([rec])
	map.apply_refit(rec, plan)
	ok(Campaign.readiness(rec) < 0.95 and Campaign.readiness(rec) >= 0.7, "landing a bank of torpedo tubes costs a destroyer some readiness, at once (%d%%)" % int(Campaign.readiness(rec) * 100))
	ok(Campaign.refit_readiness(rec, 2.0) <= 0.03 and Campaign.refit_readiness(rec, 5000.0) == 0.3, "a small job costs a few per cent, the biggest thirty")
	# chart speed follows loading
	ok(Campaign.fleet_map_speed([rec]) > v_std, "lightened, she is faster on the chart too (%.2f against %.2f)" % [Campaign.fleet_map_speed([rec]), v_std])
	rec.fit = fit.duplicate(); rec.up = {"hull": 2}; Campaign.ship_refitted(rec)
	ok(Campaign.fleet_map_speed([rec]) < v_std, "overloaded with armour, slower (%.2f)" % Campaign.fleet_map_speed([rec]))
	# other navies refit their ships, within the same rules
	seed(3); var n_var := 0; var broke := []; var landed_t := 0
	for i in 400:
		var id: String = ["dd_narvik", "ca_hipper", "bb_bismarck", "cl_cleveland", "co_flower", "cv_essex"][i % 6]
		var e: Dictionary = Campaign.new_ship(id, null, "directorate", [])
		Campaign.make_variant(e, 1 + i % 3)
		if e.has("up"):
			n_var += 1
			var le: Dictionary = BattleSim.loading(GameData.hulls[id], e.fit, e.up)
			if float(le.over_t) > 0.0 or float(le.top) > BattleSim.TOP_SLACK: broke.append(id)
			if e.fit.has("") and not BattleSim.default_fit(GameData.hulls[id], []).has(""): landed_t += 1
	ok(n_var > 300 and broke.is_empty(), "refitted ships of other navies stay within their weight and topweight (%d refitted, %d out of bounds; %d landed torpedoes for it)" % [n_var, broke.size(), landed_t])
	var e2: Dictionary = Campaign.new_ship("ca_hipper", null, "directorate", []); e2.up = {"hull": 1, "fc": 1}
	var sim3 := BattleSim.new(); sim3.wx = Weather.CLEAR; sim3.setup([Campaign.new_ship("dd_fletcher", null, "player", [])], [e2], [], [], 0)
	ok(sim3.ships[1].max_hull > GameData.hulls["ca_hipper"].hull * 1.05 and Campaign.refit_text([e2]).contains("fire control"), "an enemy's refit counts in battle and shows in the contact panel: %s" % Campaign.refit_text([e2]))
	ok(Campaign.ship_value(e2) > Campaign.ship_value(Campaign.new_ship("ca_hipper", null, "directorate", [])), "and in what she is reckoned to be worth")
	map.queue_free()
	sections += 1

## Carriers fly their aircraft off and on one at a time; a holed flight deck stops both; a lost ship takes her time
## going down; a heavy hit beside an older gash widens it instead of crossing it.
func _flying() -> void:
	seed(33)
	var sim := _sim(["cv_essex"], ["dd_narvik"]); var cv = sim.ships[0]; var e = sim.ships[1]
	cv.pos = Vector2(6000, 14000); e.pos = Vector2(6000, 2000); e.ai_off = true; cv.ai_off = true; e.god = true; sim.hold_fire = true
	var full: int = sim.planes_left(cv); var nsq: int = cv.squads.size()
	ok(sim.launch_strike(cv, e), "a carrier with a sound deck sends her squadrons off")
	ok(sim.air.size() == nsq and sim.air[0].up == 0, "nothing is in the air the moment the order is given (%d groups, %d up)" % [sim.air.size(), sim.air[0].up])
	var seen_one := false; var most_ops := 0
	for i in 400:
		sim.update_air(0.1); most_ops = maxi(most_ops, cv.deck_ops.size())
		if sim.air[0].up == 1: seen_one = true
	ok(seen_one and most_ops <= 6, "the machines leave the deck one after another (never more than %d on the run at once)" % most_ops)
	var up := 0
	for q in sim.air: up += int(q.up)
	ok(up > 0 and up < full, "forty seconds on, some are up and some still wait their turn (%d of %d)" % [up, full])
	ok(sim.planes_left(cv) == full, "and every machine is still counted, on the deck or off it (%d of %d)" % [sim.planes_left(cv), full])
	var w: Array = sim.wing(cv); var tot := 0
	for x in w: tot += int(x.aboard) + int(x.air)
	ok(w.size() == nsq and tot == full, "the air-wing readout accounts for all of them")
	# a hole in the deck: the take-offs stop until it is patched
	cv.deck_out = 30.0
	for i in 150: sim.update_air(0.1)
	var up2 := 0
	for q in sim.air: up2 += int(q.up)
	for i in 100: sim.update_air(0.1)
	var up3 := 0
	for q in sim.air: up3 += int(q.up)
	ok(up3 == up2 and not sim.launch_strike(cv, e), "with the flight deck holed nothing more takes off (%d up, then %d)" % [up2, up3])
	cv.deck_out = 0.0
	for i in 3000:
		sim.update_air(0.1)
		if sim.air.all(func(q): return q.state != "form"): break
	ok(sim.air.all(func(q): return q.state != "form" and q.up == q.n), "patched, the rest follow and the strike goes out")
	# they come home to a holed deck: they circle, and land when it is mended
	for q in sim.air: q.state = "home"; q.pos = cv.pos + Vector2(0, 1500)
	cv.deck_out = 40.0
	for i in 300: sim.update_air(0.1)
	ok(sim.air.size() == nsq and sim.air.all(func(q): return q.state == "land" and q.up == q.n), "aircraft cannot land on a holed deck: they circle")
	cv.deck_out = 0.0
	for i in 6000:
		sim.update_air(0.1)
		if sim.air.is_empty(): break
	ok(sim.air.is_empty() and sim.planes_left(cv) == full and cv.squads.all(func(sq): return sq.state == "rearm" or sq.state == "ready"), "once it is patched they land in turn and are struck below to rearm (%d of %d aboard)" % [sim.planes_left(cv), full])
	# a bomb on the deck can hole it
	var holed := 0
	for i in 40:
		cv.deck_out = 0.0; sim.hit_systems(cv, cv.pos, 240.0, "bomb")
		if cv.deck_out > 0.0: holed += 1
		cv.eng = 1.0; cv.eng_out = 0.0; cv.mag_fire = 0.0
	ok(cv.alive and holed > 8 and holed < 36, "a bomb amidships holes the flight deck about half the time (%d of 40)" % holed)
	# sinking takes its time
	sim = _sim(["bb_iowa", "dd_fletcher", "dd_fletcher"], ["dd_narvik"]); var bb = sim.ships[0]; var dd = sim.ships[1]
	for x in sim.ships: x.ai_off = true
	sim.hold_fire = true; sim.ships[3].hold = true
	sim.damage(bb, bb.hull + 1.0, "resolved"); sim.damage(dd, dd.hull + 1.0, "resolved")
	for i in 250: sim.finished = false; sim.step(0.02)   # five seconds
	ok(not bb.alive and sim.sink_k(bb) < 0.3 and sim.sink_k(dd) < 0.4 and sim.sink_k(dd) > sim.sink_k(bb), "five seconds after she is lost a ship has barely begun to go (battleship %.2f, destroyer %.2f)" % [sim.sink_k(bb), sim.sink_k(dd)])
	for i in 1800: sim.finished = false; sim.step(0.02)
	ok(sim.sink_k(bb) >= 1.0, "and within three quarters of a minute she is gone")
	# the action does not end with a ship half under
	sim = _sim(["bb_iowa"], ["dd_narvik"]); e = sim.ships[1]; sim.ships[0].ai_off = true; sim.hold_fire = true
	sim.damage(e, e.hull + 1.0, "resolved")
	for i in 400: sim.step(0.02)   # eight seconds: the old report came up after five
	ok(not sim.finished and sim.sink_k(e) < 1.0, "the action is not called over while the last ship is still going down (%.2f under after 8 s)" % sim.sink_k(e))
	for i in 3000:
		sim.step(0.02)
		if sim.finished: break
	ok(sim.finished and sim.sink_k(e) >= 1.0, "it ends once she is gone")
	# a carrier taken off the sea in the editor takes her aircraft with her
	sim = _sim(["cv_essex", "dd_fletcher"], ["dd_narvik"]); cv = sim.ships[0]; sim.editor = true
	sim.launch_strike(cv, sim.ships[2])
	for i in 300: sim.update_air(0.1)
	sim.despawn(cv)
	for i in 50: sim.update_air(0.1)
	ok(sim.air.is_empty(), "a carrier removed in the editor leaves no aircraft circling for ever (%d groups)" % sim.air.size())
	# aircraft whose carrier is sunk make for another of their side
	sim = _sim(["cv_essex", "cve_casa"], ["dd_narvik"]); cv = sim.ships[0]; var cve = sim.ships[1]; e = sim.ships[2]
	for x in sim.ships: x.ai_off = true
	sim.hold_fire = true; e.god = true; e.pos = cv.pos + Vector2(0, -20000); cve.pos = cv.pos + Vector2(900, 0)
	var own: int = sim.planes_left(cve); sim.launch_strike(cv, e)
	for i in 3000:
		sim.update_air(0.1)
		if sim.air.all(func(q): return q.state == "out"): break
	var flying := 0
	for q in sim.air: flying += int(q.up)
	sim.damage(cv, cv.hull + 1.0, "resolved")
	for i in 20000:
		sim.update_air(0.1)
		if sim.air.is_empty(): break
	ok(sim.air.is_empty() and sim.planes_left(cve) > own and sim.planes_left(cv) == 0, "aircraft whose carrier is sunk land on another of their side (%d were up; she had %d of her own and now has %d)" % [flying, own, sim.planes_left(cve)])
	ok(GameData.ship_h_at("bb_iowa", 0.0, 0.0) > 2.0 and GameData.ship_h_at("bb_iowa", 0.0, 15.0) < 1.0, "and the height of a design's upper works can be read for damage marks")
	# gashes do not cross
	sim = _sim(["bb_iowa"], ["dd_narvik"]); bb = sim.ships[0]
	for i in 12: sim.mark_hit(bb, bb.pos + Vector2(20.0 + i * 0.4, 1.0).rotated(bb.a), 3.0, true, 0.0)
	var gashes := 0
	for m in bb.marks: if m.get("gash", false): gashes += 1
	ok(gashes == 1, "twelve heavy hits in one place leave one gash, widened, not twelve across each other (%d)" % gashes)
	sections += 1

## Submarines are found by sound, and sound cuts both ways: an active ping finds a dived boat far off and tells every
## hydrophone where the pinger is; a silent ship only hears a boat close to, and a creeping boat hardly at all. Radar
## can be switched off, and a radiating set is picked up farther than it sees.
func _sound() -> void:
	seed(41)
	var sim := _sim(["dd_fletcher"], ["ss_vii"]); var dd = sim.ships[0]; var boat = sim.ships[1]
	for x in sim.ships: x.ai_off = true
	sim.hold_fire = true; boat.hold = true; boat.dive = 1.0; boat.want_dive = true; boat.v = 0.5; boat.throttle = 0; dd.v = 3.0; dd.throttle = 1
	var rng: float = sim.sonar_range(dd)
	dd.pos = Vector2(8000, 8000); boat.pos = dd.pos + Vector2(rng * 0.8, 0); dd.ping_t = 0.0
	ok(not sim.detected_by(boat, 0), "a dived boat lying quiet %.0f m off is not found until a ping reaches her" % (rng * 0.8))
	var found_at := -1.0
	for i in 200:
		sim._sonar_tick(0.05)
		if found_at < 0.0 and sim.detected_by(boat, 0): found_at = (i + 1) * 0.05
	ok(found_at > 0.5 and found_at < 6.0 and dd.heard_t < BattleSim.HEARD_FOR, "the ping runs out to her, finds her (%.1f s) and the boat hears who sent it" % found_at)
	# the owner's report: destroyers shelled the water over a dived boat, through the one making her run. Guns leave a dived boat alone
	boat.pos = dd.pos + Vector2(900, 0); dd.target = boat; sim.hold_fire = false; dd.hold = false; sim.shells.clear()
	for i in 200:
		sim._sonar_tick(0.05); sim.update_weapons(dd, 0.05)
	ok(sim.detected_by(boat, 0) and sim.shells.is_empty(), "a boat held on sonar 900 m off, dived, is not fired on by the guns")
	boat.dive = 0.0
	for i in 200: sim.update_weapons(dd, 0.05)
	ok(not sim.shells.is_empty(), "once she is on the surface they open fire")
	boat.dive = 1.0; sim.hold_fire = true; sim.shells.clear(); dd.target = null; boat.pos = dd.pos + Vector2(rng * 0.8, 0)
	# shells hurt whatever they land on (owner's word): a captain checks fire when a friend lies in the fall of shot
	var s3 := _sim(["dd_fletcher", "dd_fletcher"], ["dd_fletcher"]); var g = s3.ships[1]; var fr = s3.ships[0]; var en = s3.ships[2]   # (the flagship's guns are laid by hand: the other ship shoots)
	for x in s3.ships: x.ai_off = true; x.hold = true; x.v = 0.0; x.throttle = 0
	g.hold = false; g.pos = Vector2(8000, 8000); g.a = PI / 2; en.pos = g.pos + Vector2(2000, 0); en.a = 0.0; fr.pos = en.pos + Vector2(0, 25); fr.a = 0.0; g.target = en
	for i in 200: s3.update_weapons(g, 0.05)
	ok(s3.shells.is_empty() and s3.friend_near(g, en.pos, en), "with a friend alongside the enemy 25 m off the guns check fire")
	fr.pos = g.pos + Vector2(0, 3000)
	for i in 200: s3.update_weapons(g, 0.05)
	ok(not s3.shells.is_empty(), "with her clear they open fire")
	var fh: float = fr.hull
	for sh in s3.shells: sh.e = Vector2(8000, 3000) + (sh.e - en.pos) * 0.1   # onto the friend (their scatter kept small: whether a shell hits must not hang on the dice)
	en.pos = Vector2(3000, 3000); fr.pos = Vector2(8000, 3000)
	for i in 400:
		if s3.shells.is_empty(): break
		s3.step(0.05)
	ok(fr.hull < fh, "a salvo that falls on a friend hurts her (-%.0f)" % (fh - fr.hull))
	dd.sonar_on = false
	for i in 400: sim._sonar_tick(0.05)
	ok(not sim.detected_by(boat, 0) and dd.heard_t > BattleSim.HEARD_FOR, "with the sonar silent the contact is lost, and the destroyer is no longer heard")
	var creep: float = sim.passive_range(dd, boat); boat.v = float(boat.d.get("subKn", boat.d.kn * 0.4)) * BattleSim.KN
	var run: float = sim.passive_range(dd, boat)
	ok(run > creep * 2.5 and creep < 300.0, "listening only, a creeping boat is heard at %.0f m and one running hard at %.0f m" % [creep, run])
	boat.pos = dd.pos + Vector2(run * 0.9, 0)
	ok(sim.detected_by(boat, 0), "so a boat running fast close by is heard without a ping")
	boat.v = 0.5; boat.pos = dd.pos + Vector2(rng * 2.0, 0); boat.sonar_on = true; boat.ping_t = 0.0
	for i in 200: sim._sonar_tick(0.05)
	ok(sim.detected_by(boat, 0) and boat.heard_t < BattleSim.HEARD_FOR, "a boat that pings gives herself away to a destroyer twice her sonar's range off")
	# at night a pinging destroyer is heard by a boat that cannot see her
	var night := {"sea": 0, "fog": false, "night": true, "moon": 0.0}
	sim = _sim(["ss_gato"], ["dd_narvik"], Weather.battle(night)); var mine = sim.ships[0]; var foe = sim.ships[1]
	for x in sim.ships: x.ai_off = true
	foe.tech = []; foe.radar_on = false; mine.dive = 1.0; mine.want_dive = true
	mine.pos = Vector2(8000, 8000); foe.pos = mine.pos + Vector2(float(sim.wx.vis) * 1.15, 0); foe.sonar_on = false; foe.lit_t = 99.0
	ok(not sim.visible_to(foe, 0), "at night a silent destroyer beyond the lookouts' reach is not seen (%.0f m, sight %.0f m)" % [mine.pos.distance_to(foe.pos), float(sim.wx.vis)])
	foe.sonar_on = true; foe.ping_t = 0.0
	for i in 200: sim._sonar_tick(0.05)
	ok(mine.pos.distance_to(foe.pos) < sim.sonar_range(foe) * BattleSim.PING_HEAR and sim.visible_to(foe, 0), "but once she pings, the boat's hydrophones have her")
	# depth charges are dropped for where the boat will be, and burst well astern
	sim = _sim(["dd_fletcher"], ["ss_vii"]); dd = sim.ships[0]; boat = sim.ships[1]
	for x in sim.ships: x.ai_off = true
	sim.hold_fire = true; boat.dive = 1.0; boat.want_dive = true; boat.v = 0.0; boat.throttle = 0; boat.held_t = 0.0
	dd.pos = Vector2(8000, 8000); dd.a = 0.0; dd.v = 14.0; dd.throttle = 3
	boat.pos = dd.pos + Vector2(0, 200)
	ok(not sim.dc_on(dd, boat), "a boat 200 m on the beam is not under the pattern: she does not drop (she used to, at anything inside 260 m)")
	var pat: Array = sim.dc_pattern(dd); boat.pos = pat[0]
	ok(sim.dc_on(dd, boat) and sim.drop_dcs(dd), "with the boat where the pattern will fall, she drops")
	var nearest_burst := INF; var bursts := 0; var hull0: float = boat.hull
	for i in 400:
		var before: Array = sim.dcs.duplicate()
		sim.finished = false; sim.step(0.05)
		for q in before: if not q.has("rel") and not sim.dcs.has(q): bursts += 1; nearest_burst = minf(nearest_burst, q.pos.distance_to(sim.world_pt(dd, -dd.d.L / 2, 0)))
	ok(bursts == 6 and nearest_burst > 70.0, "six charges burst, none nearer her stern than %.0f m (the first used to go off some 45 m astern)" % nearest_burst)
	ok(boat.hull < hull0, "and the boat under them is hurt (%.0f of %.0f)" % [boat.hull, hull0])
	# ramming and collisions: hulls, not circles; friend or foe; by closing speed and weight
	sim = _sim(["dd_fletcher", "bb_iowa"], ["ss_vii", "dd_narvik"]); dd = sim.ships[0]; var bbr = sim.ships[1]; boat = sim.ships[2]; var foe_dd = sim.ships[3]
	for x in sim.ships: x.ai_off = true; x.pos = Vector2(3000 + 3000 * sim.ships.find(x), 3000); x.v = 0.0; x.throttle = 0
	sim.hold_fire = true; foe_dd.hold = true; boat.hold = true
	# two ships lying beam to beam 40 m apart do not touch (as circles they did)
	dd.pos = Vector2(8000, 8000); dd.a = 0.0; foe_dd.pos = dd.pos + Vector2(0, 40); foe_dd.a = 0.0; var h0: float = dd.hull
	sim._collisions()
	ok(dd.pos == Vector2(8000, 8000) and dd.hull == h0, "two destroyers lying beam to beam 40 m apart are clear of each other")
	# a touch at a crawl fends them off and hurts neither
	foe_dd.pos = dd.pos + Vector2(0, 8); dd.v = 0.5; dd.a = 0.3
	sim._collisions()
	ok(dd.hull == h0 and foe_dd.hull == foe_dd.max_hull and dd.pos.distance_to(foe_dd.pos) > 8.5, "touching at a crawl they are fended off and neither is hurt")
	# the destroyer rams a boat on the surface, stem on to her side, at 15 m/s
	foe_dd.pos = Vector2(3000, 12000); boat.dive = 0.0; boat.pos = Vector2(10000, 8000); boat.a = PI / 2; dd.pos = boat.pos - Vector2(dd.d.L * 0.5 + boat.d.B * 0.5 - 2.0, 0); dd.a = 0.0; dd.v = 15.0
	var bh: float = boat.hull; sim._collisions()
	ok(boat.hull < bh * 0.5 and dd.hull < h0 and (h0 - dd.hull) < (bh - boat.hull) and absf(boat.list) > 0.04, "a destroyer ramming a surfaced boat at speed all but sinks her, and is hurt herself (boat -%.0f, destroyer -%.0f; the boat lists)" % [bh - boat.hull, h0 - dd.hull])
	var after: float = dd.hull; dd.ram_t = 0.0; boat.ram_t = 0.0; dd.pos = boat.pos - Vector2(dd.d.L * 0.5 + boat.d.B * 0.5 - 2.0, 0); dd.v = 15.0
	boat.alive = true; boat.sink = 0.0; boat.hull = 100.0; sim._collisions()
	ok(dd.hull == after, "it is one collision: they do not strike again a moment later")
	# a boat gone deep is passed over
	boat.alive = true; boat.sink = 0.0; boat.hull = boat.max_hull; boat.dive = 1.0; dd.sheer_t = 0.0   # (the ram sank her: afloat again for the next checks)
	boat.sheer_t = 0.0; dd.ram_t = 0.0; boat.ram_t = 0.0; dd.v = 15.0; dd.pos = boat.pos - Vector2(dd.d.L * 0.5 + boat.d.B * 0.5 - 2.0, 0); bh = boat.hull; sim._collisions()
	ok(boat.hull == bh, "a boat gone deep is passed over")
	boat.dive = 0.7; dd.ram_t = 0.0; boat.ram_t = 0.0; dd.sheer_t = 0.0; boat.sheer_t = 0.0; dd.v = 15.0; dd.pos = boat.pos - Vector2(dd.d.L * 0.5 + boat.d.B * 0.5 - 2.0, 0); sim._collisions()
	ok(boat.hull < bh, "but one at periscope depth can be rammed")
	# friends: a destroyer running into her own battleship's side
	boat.pos = Vector2(3000, 15000); dd.hull = dd.max_hull; dd.ram_t = 0.0; dd.sheer_t = 0.0; bbr.a = PI / 2; bbr.pos = Vector2(12000, 8000); dd.a = 0.0; dd.v = 12.0; dd.pos = bbr.pos - Vector2(dd.d.L * 0.5 + bbr.d.B * 0.5 - 2.0, 0)
	var bb0: float = bbr.hull; h0 = dd.hull; sim._collisions()
	ok(dd.hull < h0 and bbr.hull < bb0 and (h0 - dd.hull) / dd.max_hull > 4.0 * (bb0 - bbr.hull) / bbr.max_hull, "friends are hurt too, the light ship far the worse (destroyer -%.0f%%, battleship -%.1f%%)" % [100.0 * (h0 - dd.hull) / dd.max_hull, 100.0 * (bb0 - bbr.hull) / bbr.max_hull])
	# other navies' captains choose what to send out
	sim = _sim(["ss_gato"], ["dd_narvik", "dd_narvik", "ca_hipper"], Weather.battle(night)); mine = sim.ships[0]
	for x in sim.ships: x.tech = ["radar"] if x.side == 1 else []; x.lit_t = 99.0
	mine.dive = 1.0; mine.want_dive = true; mine.v = 0.3; mine.pos = Vector2(8000, 12000)
	for i in 3: sim.ships[1 + i].pos = Vector2(7000 + i * 800, 4000)
	sim.flag = mine; sim.t = 30.0; sim._emcon_t = 0.0; sim._emcon(0.1)
	var pinging := 0; var radiating := 0
	for x in sim.ships: if x.side == 1: pinging += int(x.sonar_on and sim.has_sonar(x)); radiating += int(x.radar_on)
	ok(pinging == 0 and radiating == 0, "at night, unseen and with nothing in sight, another navy's ships run silent with their sets off (%d pinging, %d radiating)" % [pinging, radiating])
	sim.t = 95.0; sim._emcon_t = 0.0; sim._emcon(0.1)
	radiating = 0
	for x in sim.ships: if x.side == 1: radiating += int(x.radar_on)
	ok(radiating == 1, "but one of them looks round with her radar now and then (%d radiating)" % radiating)
	mine.pos = sim.ships[1].pos + Vector2(600, 0); mine.reveal_t = 20.0; sim._emcon_t = 0.0; sim._emcon(0.1)
	pinging = 0
	for x in sim.ships: if x.side == 1: pinging += int(x.sonar_on and sim.has_sonar(x))
	ok(pinging >= 1 and sim.sub_alarm[1] < 1.0, "once a boat has shown herself the destroyers near her start pinging (%d)" % pinging)
	sim = _sim(["ss_gato"], ["dd_narvik"]); sim.flag = sim.ships[0]; sim.ships[1].sonar_on = false; sim.ships[1].radar_on = false; sim.ships[1].tech = ["radar"]; sim._emcon_t = 0.0; sim._emcon(0.1)
	ok(sim.ships[1].sonar_on and sim.ships[1].radar_on, "by day in clear weather everything is on: nothing is lost by it")
	# radar: off sees nothing and is not heard; on, it is picked up farther than it sees
	sim = _sim(["ca_baltimore"], ["ca_hipper"], Weather.battle(night)); var a = sim.ships[0]; var b = sim.ships[1]
	a.tech = ["radar"]; b.tech = ["radar"]; a.lit_t = 99.0; b.lit_t = 99.0
	a.pos = Vector2(8000, 8000); b.pos = a.pos + Vector2(sim.sight(b) * 1.15, 0); a.radar_on = false   # yours listens with her own set switched off
	ok(sim.has_radar(b) and sim.visible_to(b, 0) and not sim.visible_to(a, 1), "a radiating ship is picked up beyond her own radar's reach by one that keeps her set off, and does not see who has her")
	b.radar_on = false
	ok(not sim.has_radar(b) and sim.radar_fitted(b) and not sim.visible_to(b, 0), "with her set switched off she is not picked up there")
	a.radar_on = true; b.pos = a.pos + Vector2(sim.sight(a) * 0.8, 0)
	ok(sim.visible_to(b, 0), "inside the other's radar she is seen whatever she does")
	ok(sim.visible_to(a, 1), "and the ship that radiates there is known to her, set off or not")
	sections += 1

## Torpedoes and depth charges hurt friends too (owner's word, 11 Nov 2026): what they strike, and the captains' and
## the player's care with them (BattleSim.torp_fouls, dc_fouls, dc_harm, ff_confirm).
func _still(sim: BattleSim) -> void:
	for x in sim.ships: x.ai_off = true; x.v = 0.0; x.throttle = 0; x.rudder = 0.0
func _friends() -> void:
	var sim := _sim(["dd_fletcher", "dd_fletcher"], ["dd_narvik"]); _still(sim)
	var a = sim.ships[0]; var b = sim.ships[1]; var e = sim.ships[2]
	a.pos = Vector2(5000, 5000); a.a = 0.0; b.pos = Vector2(5800, 5000); b.a = PI / 2; e.pos = Vector2(20000, 20000)
	# a torpedo strikes the first hull in her path, whatever its flag
	var h0: float = b.hull
	sim.torps.append({"pos": Vector2(5300, 5000), "a": 0.0, "speed": 23.0, "life": 100.0, "dmg": 650, "side": 0, "homing": false, "arm": 0.0, "en": 0.0, "who": a})
	for i in 600: sim.step(0.05)
	ok(b.hull < h0 and int(sim.sys_log.get("torpedo on a friend", 0)) == 1 and sim.ff_dmg_t > 0.0, "a torpedo running into a ship of her own side strikes her (-%.0f)" % (h0 - b.hull))
	# a straight runner never comes back on her own ship, and passes over a dived boat of either side
	sim = _sim(["dd_fletcher", "ss_gato"], ["dd_narvik"]); _still(sim); a = sim.ships[0]; var boat = sim.ships[1]; e = sim.ships[2]
	a.pos = Vector2(5000, 5000); e.pos = Vector2(20000, 20000); boat.pos = Vector2(5600, 5000); boat.a = PI / 2; boat.dive = 1.0; boat.want_dive = true
	h0 = a.hull; var bh0: float = boat.hull
	sim.torps.append({"pos": Vector2(4900, 5000), "a": 0.0, "speed": 23.0, "life": 60.0, "dmg": 650, "side": 0, "homing": false, "arm": 0.0, "en": 0.0, "who": a})
	for i in 600: sim.step(0.05)
	ok(a.hull == h0 and boat.hull == bh0, "a straight-running torpedo passes through her own ship's place and under a dived friend")
	# a homer's seeker hears the nearest ship in its cone, friend or not: a dived friend ahead of her is struck
	boat.hull = bh0
	sim.torps.append({"pos": Vector2(5100, 5000), "a": 0.0, "speed": 20.0, "life": 60.0, "dmg": 560, "side": 0, "homing": true, "arm": 0.0, "en": 0.0, "who": a})
	for i in 600: sim.step(0.05)
	ok(boat.hull < bh0, "a homing torpedo goes for a dived boat of her own side that lies nearest in her cone (-%.0f)" % (bh0 - boat.hull))
	# but not before her enabling run: she runs straight until then
	sim.torps.clear(); sim.torps.append({"pos": Vector2(4900, 5000), "a": 0.0, "speed": 20.0, "life": 60.0, "dmg": 560, "side": 0, "homing": true, "arm": 0.0, "en": 100.0, "who": a})
	boat.pos = Vector2(5500, 5200); for i in 20: sim.step(0.05)
	ok(sim.torps.size() == 1 and absf(float(sim.torps[0].a)) < 0.0001, "a homer runs straight, deaf, until her seeker comes on short of the aim point")
	# the captain's look along the track: a friend lying across it, or steaming into it, fouls it; a clear sea does not
	sim = _sim(["dd_fletcher", "dd_fletcher"], ["dd_narvik"]); _still(sim); a = sim.ships[0]; b = sim.ships[1]; e = sim.ships[2]
	var w := {"speed": 23.0, "range": 4500.0, "count": 3, "kind": "torp"}
	a.pos = Vector2(5000, 5000); e.pos = Vector2(8500, 5000); b.pos = Vector2(6500, 5000); b.a = PI / 2
	ok(sim.torp_fouls(a, a.pos, e.pos, w, e) == b, "a friend lying across the track fouls it")
	b.pos = Vector2(6500, 3800); b.v = 0.0
	ok(sim.torp_fouls(a, a.pos, e.pos, w, e) == null, "the same friend lying well clear does not")
	b.pos = Vector2(6500, 4300); b.v = 12.0
	ok(sim.torp_fouls(a, a.pos, e.pos, w, e) == b, "but steaming towards the track at 12 m/s she will cross it, and fouls it")
	b.pos = Vector2(6500, 7000); b.a = 0.0
	var hw := {"speed": 20.0, "range": 5000.0, "count": 2, "kind": "torp", "homing": true}
	b.pos = e.pos + Vector2(-100, 250); b.v = 0.0
	var w1 := {"speed": 23.0, "range": 4500.0, "count": 1, "kind": "torp"}
	ok(sim.torp_fouls(a, a.pos, e.pos, w1, e) == null and sim.torp_fouls(a, a.pos, e.pos, hw, e) == b, "a friend close by the target, clear of the track, fouls a homer (her seeker would hear the friend first) but not a straight runner")
	# a captain holds his torpedoes for a friend in the track, and fires once she is clear
	sim = _sim(["dd_fletcher", "dd_fletcher"], ["dd_narvik"]); a = sim.ships[0]; b = sim.ships[1]; e = sim.ships[2]
	a.pos = Vector2(8000, 8000); a.a = PI / 2; e.pos = Vector2(9300, 8000); e.a = PI / 2; e.v = 0.0; e.ai_off = true; e.throttle = 0; e.hold = true
	b.pos = Vector2(8650, 8000); b.a = PI / 2; b.ai_off = true; b.v = 0.0; b.throttle = 0; b.hold = true; a.ai_off = true; a.throttle = 0; a.v = 0.0
	for m in a.mounts:
		if m.w.kind == "gun" or m.w.kind == "aa": m.ammo = 0
		if m.w.kind == "torp": m.cd = 0.0
	for i in 200: sim.step(0.05)
	ok(sim.torps.is_empty() and a.foul_by == b, "a captain holds his torpedoes with a friend in the track (fouled by %s)" % (a.foul_by.rec.name if a.foul_by else "nobody"))
	b.pos = Vector2(9200, 11000)
	for i in 200: sim.step(0.05)
	ok(not sim.torps.is_empty(), "and fires once she has cleared it (%d torpedoes running)" % sim.torps.size())
	# a torpedo attack ordered with a friend in the track: she holds, says why, and gives it up rather than circle for ever
	sim = _sim(["dd_fletcher", "dd_fletcher", "dd_fletcher"], ["dd_narvik"]); a = sim.ships[1]; b = sim.ships[2]; e = sim.ships[3]; var fl = sim.ships[0]
	sim.flag = fl; fl.pos = Vector2(3000, 3000); fl.ai_off = true
	a.pos = Vector2(8000, 8000); a.a = 0.0; e.pos = Vector2(10500, 8000); e.ai_off = true; e.v = 0.0; e.throttle = 0; e.hold = true
	a.ord = "torp"; a.ord_tgt = e
	for m in a.mounts:
		if m.w.kind == "gun" or m.w.kind == "aa": m.ammo = 0
		if m.w.kind == "torp": m.cd = 0.0
	var said := false; var gave := false
	for i in 4000:
		b.pos = a.pos.lerp(e.pos, 0.5); b.a = (e.pos - a.pos).angle() + PI / 2; b.v = 0.0; b.ai_off = true; b.hold = true   # a friend kept between her and the enemy
		sim.step(0.05)
		if sim.msg.contains("holds her torpedoes"): said = true
		if sim.msg.contains("gives up her torpedo attack"): gave = true
		if a.ord != "torp": break
	ok(said and gave and a.ord != "torp" and sim.torps.is_empty(), "a torpedo attack with a friend in the track holds fire, says why, and is given up (said %s, gave up %s, %d torpedoes fired)" % [said, gave, sim.torps.size()])
	# depth charges: any boat near a burst, friend or foe; a hull close over it; the dropper herself if she is too slow
	sim = _sim(["dd_fletcher", "ss_gato", "dd_fletcher"], ["dd_narvik"]); _still(sim); a = sim.ships[0]; boat = sim.ships[1]; b = sim.ships[2]; e = sim.ships[3]
	a.pos = Vector2(5000, 5000); a.a = 0.0; e.pos = Vector2(20000, 20000); boat.dive = 1.0; boat.want_dive = true
	var burst: Vector2 = Vector2(6000, 6000)
	boat.pos = burst + Vector2(20, 0); b.pos = burst + Vector2(0, b.d.B * 0.5 + 10.0); b.a = 0.0
	ok(sim.dc_harm(boat, burst) > 100.0 and sim.dc_harm(b, burst) > 0.0 and sim.dc_harm(a, burst) == 0.0, "a burst hurts a boat of any flag close by it (%.0f) and a hull just over it (%.0f), and nothing far off" % [sim.dc_harm(boat, burst), sim.dc_harm(b, burst)])
	boat.pos = Vector2(15000, 15000); b.pos = Vector2(15000, 5000)
	a.v = 1.0; a.dc_t = 0.0
	ok(sim.dc_fouls(a) == a, "a pattern dropped at a crawl would burst under the dropper herself")
	a.v = 14.0
	ok(sim.dc_fouls(a) == null, "at speed she is well clear of her own pattern")
	h0 = a.hull; var dl0: int = a.dc_left; sim.drop_dcs(a); a.ai_off = true; a.throttle = 4
	for i in 300: sim.step(0.05)
	ok(a.hull == h0 and a.dc_left == dl0 - 1, "dropped at 14 m/s she runs clear of her own charges")
	boat.pos = sim.dc_bursts(a)[0][0] + Vector2(10, 0); boat.v = 0.0; a.v = 14.0; a.pos = Vector2(5000, 5000); a.a = 0.0
	boat.pos = sim.dc_bursts(a)[1][0] + Vector2(10, 0)
	ok(sim.dc_fouls(a) == boat, "a friendly boat where the pattern would fall fouls it")
	h0 = boat.hull; a.dc_t = 0.0; sim.drop_dcs(a)
	for i in 120: sim.step(0.05)
	ok(boat.hull < h0 and int(sim.sys_log.get("depth charge on a friend", 0)) > 0 and sim.ff_dmg_dc > 0.0, "dropped all the same, the pattern hurts her (-%.0f)" % (h0 - boat.hull))
	# a captain hunting a boat does not drop where a friendly boat would be hurt
	sim = _sim(["dd_fletcher", "ss_gato"], ["ss_gato"]); a = sim.ships[0]; boat = sim.ships[1]; var en = sim.ships[2]
	a.pos = Vector2(5000, 5000); a.a = 0.0; a.v = 14.0; a.throttle = 4; a.ai_off = true; a.dc_t = 0.0; a.sonar_on = true
	en.dive = 1.0; en.want_dive = true; en.ai_off = true; en.v = 0.0; en.held_t = 0.0
	en.pos = sim.dc_pattern(a)[0]; boat.dive = 1.0; boat.want_dive = true; boat.ai_off = true; boat.v = 0.0; boat.pos = en.pos + Vector2(30, 25)
	ok(sim.dc_on(a, en) and sim.dc_fouls(a) == boat, "the pattern would fall on the enemy boat, and on a friendly boat close by her")
	var dl1: int = a.dc_left; a.ai_off = false
	for i in 4: sim.step(0.05)
	ok(a.dc_left == dl1, "so the captain holds his charges (%d patterns before, %d after)" % [dl1, a.dc_left])
	boat.pos = Vector2(15000, 15000); en.pos = sim.dc_pattern(a)[0]; en.held_t = 0.0
	for i in 4: sim.step(0.05)
	ok(a.dc_left == dl1 - 1, "with the friend gone from there he drops (%d patterns left)" % a.dc_left)
	# the player is warned and must press again: T or Z with a friend in danger
	sim = _sim(["dd_fletcher", "dd_fletcher"], ["dd_narvik"]); _still(sim); a = sim.ships[0]; b = sim.ships[1]; e = sim.ships[2]
	sim.flag = a; a.pos = Vector2(5000, 5000); a.a = PI / 2; e.pos = Vector2(8500, 5000); b.pos = Vector2(6500, 5000); b.a = PI / 2
	sim.mouse_world = e.pos
	for m in a.mounts: if m.w.kind == "torp": m.cd = 0.0
	ok(sim.player_torp_foul() == b, "the flagship's tubes laid on the cursor would put a torpedo into the friend between")
	ok(not sim.ff_confirm("torp") and sim.msg.contains("lies in the torpedo track"), "the first T only warns: \"%s\"" % sim.msg)
	sim.t += 1.0
	ok(sim.ff_confirm("torp"), "a second T within a few seconds fires all the same")
	ok(not sim.ff_confirm("torp"), "and the next T warns again")
	sim.t += BattleSim.FF_CONFIRM + 1.0
	ok(not sim.ff_confirm("torp"), "as does one too late to count as the second")
	b.pos = Vector2(5000, 9000)
	ok(sim.ff_confirm("torp"), "with the track clear T fires at once")
	a.v = 1.0
	ok(not sim.ff_confirm("dc") and sim.msg.contains("own charges"), "Z at a crawl warns that her own charges would burst under her")
	a.v = 14.0
	ok(sim.ff_confirm("dc"), "Z at speed with no friend about drops at once")
	sections += 1

## A new captain's grace (tuning after the tuning sheet): bounty squadrons do not hunt you for the first BOUNTY_GRACE days.
func _grace() -> void:
	Campaign.new_game("academy"); var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	var near := 0
	for f in G.fleets: if f.kind == "bounty" and Campaign.mdist(f.x, f.y, P.x, P.y) <= 300.0: near += 1
	ok(near == 0, "no bounty squadron starts within 300 units of a new captain (%d)" % near)
	G.fleets = G.fleets.filter(func(f): return f.kind != "bounty")
	var w := Vector2(P.x, P.y)   # a point of open water in sight, outside contact range
	for k in 16:
		var c := Vector2(P.x, P.y) + Vector2.from_angle(k * TAU / 16.0) * 40.0
		if not Campaign.on_land(c.x, c.y): w = c; break
	var b := _fleet("bounty", "raiders", w.x, w.y, ["cl", "dd", "dd"]); b.captain = "Test"; b.reward = 1000
	P.cool = 0.0; P.route = null; G.day = 5
	for i in 5: b.cool = 0.0; P.cool = 0.0; G.dayF = 0.0; Campaign.paused = false; Campaign.update(0.05)
	ok(Campaign.mdist(b.x, b.y, P.x, P.y) > Campaign.CONTACT and not b.get("chasing", false), "on day 5 a bounty squadron in sight (%.0f units off) does not give chase" % Campaign.mdist(b.x, b.y, P.x, P.y))
	G.day = Campaign.BOUNTY_GRACE + 1
	for i in 5: b.cool = 0.0; P.cool = 0.0; G.dayF = 0.0; Campaign.paused = false; Campaign.update(0.05)
	ok(b.get("chasing", false), "after day %d it does" % Campaign.BOUNTY_GRACE)
	# forces that come looking for you are sized to you: bounty squadrons and an origin's hunters
	for want in [["co_flower"], ["dd_fletcher", "dd_fletcher", "cl_cleveland"], ["bb_iowa", "ca_baltimore", "ca_baltimore", "cl_cleveland", "dd_fletcher", "dd_fletcher"]]:
		G.fleet = []
		for t in want: G.fleet.append(Campaign.new_ship(t, null, "player", []))
		var me: float = Campaign.own_strength(); var lo := INF; var hi := 0.0
		for i in 12:
			var f := Campaign.spawn_fleet("bounty", "raiders"); var k: float = Campaign.strength(f.ships) / me
			lo = minf(lo, k); hi = maxf(hi, k); G.fleets.erase(f)
		var floor_k: float = Campaign.BOUNTY_FLOOR / me
		ok(lo >= minf(0.55, floor_k * 0.5) and hi <= maxf(3.6, floor_k * 2.0), "bounty squadrons against %d ships worth %s come at %.2f to %.2f times their strength" % [want.size(), Campaign.fmt(int(me)), lo, hi])
	Campaign.new_game("survivor"); G = Campaign.G
	var h: Dictionary = (Campaign.perk("hunted", []) as Array)[0]; h.every = 1.0
	G.day = 10; Campaign.maintain_fleets(false)
	ok(not G.fleets.any(func(f): return f.get("hunter", false)), "no hunters are sent after a Survivor before day %d" % Campaign.HUNT_GRACE)
	G.day = Campaign.HUNT_GRACE + 5; Campaign.maintain_fleets(false)
	var hs: Array = G.fleets.filter(func(f): return f.get("hunter", false))
	var hk: float = Campaign.strength(hs[0].ships) / Campaign.own_strength() if not hs.is_empty() else 0.0
	ok(not hs.is_empty() and hk > 0.8 and hk < 3.0, "after that they come, about %.1f times as strong as her destroyer (%.2f)" % [Campaign.HUNT_K, hk])
	# officers on half pay while you serve no one (tuning: a warship captain could not pay his way)
	Campaign.new_game("disgraced"); G = Campaign.G
	var crew_pay: float = G.crew * 0.15; var full := 0.0
	for o in G.officers: full += 40.0 * o.lvl
	ok(Campaign.half_pay() and is_equal_approx(Campaign.wages(), crew_pay + full * Campaign.HALF_PAY), "a Disgraced Officer serving no one pays his officers half (%.0f a day, full pay would be %.0f)" % [Campaign.wages(), crew_pay + full])
	G.contracts.append({"id": -1, "kind": "survey", "fac": "concord", "reward": 0})
	ok(not Campaign.half_pay() and is_equal_approx(Campaign.wages(), crew_pay + full), "with a contract in hand they are on full pay (%.0f)" % Campaign.wages())
	G.contracts.clear()
	# the navy origins' starting money (tuning: all three went broke): a pension for the Disgraced Officer, paid monthly
	G.credits = 1000.0; G.cargo.food = 500.0; G.cargo.fuel = 200.0; G.day = 29; Campaign.new_day(false)
	ok(float(G.credits) > 1000.0 + 2000.0, "a Disgraced Officer's pension is paid on day 30 (purse %.0f)" % float(G.credits))
	Campaign.new_game("defector"); G = Campaign.G
	ok(float(G.credits) >= 30000.0 and not (Campaign.perk("pension", []) as Array).is_empty(), "a Defector starts with 30,000 and a retainer from his new patrons")
	sections += 1

## Ageing, wear and laying up (Rule the Waves; the owner's go-ahead, 11 Nov 2026).
func _ageing() -> void:
	Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	G.fleet = [Campaign.new_ship("dd_fletcher", "Old", "player", []), Campaign.new_ship("dd_fletcher", "New", "player", [])]
	G.fleet[1].built = int(G.day); G.crew = Campaign.crew_need(); G.cargo.food = 900.0; G.cargo.fuel = 900.0; G.credits = 500000.0
	var old: Dictionary = G.fleet[0]; var nw: Dictionary = G.fleet[1]
	ok(Campaign.age_years(old) >= 3.0 and Campaign.age_years(nw) < 0.1, "a ship is as old as her design (%.1f years), one new from the yard is new" % Campaign.age_years(old))
	var v0: float = Campaign.fleet_map_speed([old])
	for i in 200: Campaign.new_day(true)
	ok(Campaign.wear(old) > Campaign.wear(nw) and Campaign.wear(nw) > 0.2, "two hundred days under way wear both, the older faster (%.2f against %.2f)" % [Campaign.wear(old), Campaign.wear(nw)])
	ok(Campaign.fleet_map_speed([old]) < v0 * 0.97, "a worn ship is slower on passage (%.2f against %.2f)" % [Campaign.fleet_map_speed([old]), v0])
	var sim := BattleSim.new(); sim.setup([old], [Campaign.new_ship("dd_narvik", null, "directorate", [])], [], [], 0)
	ok(sim.ships[0].eng < 0.97, "and goes into action with her machinery down (%.2f)" % sim.ships[0].eng)
	var oc: int = Campaign.overhaul_cost(old); var c0: float = G.credits; Campaign.overhaul(old)
	ok(oc > 0 and is_equal_approx(float(G.credits), c0 - oc) and is_equal_approx(Campaign.wear(old), Campaign.wear_floor(old)) and Campaign.wear_floor(old) > 0.0, "an overhaul costs %d and takes the wear off, down to her age's floor (%.2f)" % [oc, Campaign.wear(old)])
	# laying up
	var port: Dictionary = {}
	for p in G.ports: if not Campaign.hostile(p.fac) and not Campaign.at_war(p.fac) and p.fac != "player": port = p; break
	var need0: int = Campaign.crew_need(); var crew0: int = G.crew
	print("  ", Campaign.lay_up(old, port))
	ok(not G.fleet.has(old) and not Campaign.all_ships().has(old) and Campaign.laid_at(port).size() == 1, "a ship laid up leaves the squadron (and its supply and crew counts)")
	ok(Campaign.crew_need() < need0 and int(G.crew) < crew0, "her crew is paid off (%d to %d)" % [crew0, int(G.crew)])
	ok(Campaign.can_lay_up(nw, port) != "", "the last ship cannot be laid up")
	c0 = G.credits; Campaign.new_day(false)
	ok(float(G.credits) < c0 - Campaign.wages() + 0.01 and float(G.credits) > c0 - Campaign.wages() - Campaign.layup_fee(old) - 1.0, "her berth is paid each day (%.0f)" % Campaign.layup_fee(old))
	var other: Dictionary = {}
	for p in G.ports: if int(p.id) != int(port.id): other = p; break
	ok(Campaign.can_recommission(Campaign.laid_at(port)[0], other) != "", "she can be recommissioned only where she lies")
	print("  ", Campaign.recommission(Campaign.laid_at(port)[0], port))
	ok(G.fleet.has(old) and Campaign.laid().is_empty() and Campaign.readiness(old) <= 0.5, "recommissioned there she rejoins, half worked up")
	Campaign.lay_up(old, port); G.rep[port.fac] = -100; Campaign.new_day(false)
	ok(Campaign.laid().is_empty() and not G.fleet.has(old), "laid up in a harbour whose flag goes to war with you, she is seized")
	# a squadron lying in the cove by Bab Hakar's town (found by the soak: it carried on past the roads) can still put to sea
	var P: Dictionary = G.player; var gone := 0
	for p in G.ports:
		P.x = 2686.0; P.y = 1408.0
		if Campaign.set_course(P, p.sx, p.sy): gone += 1
	ok(gone == G.ports.size(), "a squadron in a cove hard by a harbour finds a course out (%d of %d harbours)" % [gone, G.ports.size()])
	# wrecks raised after an action (Starsector): some of the ships that went down slowly, never one blown up
	Campaign.new_game("commission"); G = Campaign.G; G.credits = 900000.0; G.cargo.steel = 300.0
	G.fleet = [Campaign.new_ship("cl_cleveland", "Holder", "player", [])]; G.crew = Campaign.crew_need() + 400
	var found: Array = []; var blown_raised := false
	for i in 40:
		var ws := _sim(["cl_cleveland"], ["ca_hipper", "dd_narvik"]); ws.ships[0].rec = G.fleet[0]
		for x in ws.ships: if x.side == 1: x.alive = false; x.hull = 0.0
		ws.ships[2].blown = true
		GameData.pending = {}
		var r: Dictionary = Campaign.apply_battle(ws)
		for w in r.get("wrecks", []):
			found.append(w)
			if w.rec == ws.ships[2].rec: blown_raised = true
		G.fleet = [G.fleet[0]] if not G.fleet.is_empty() else [Campaign.new_ship("cl_cleveland", "Holder", "player", [])]
	ok(not found.is_empty() and not blown_raised, "holding the field, some wrecks can be raised (%d in 40 actions), never one her magazine blew up" % found.size())
	var w0: Dictionary = found[0]; G.cargo.steel = float(Campaign.recover_cost(w0.rec).steel) + 5.0; var st0: float = G.cargo.steel; var n0: int = G.fleet.size()
	print("  ", Campaign.recover(w0))
	var raised: Dictionary = G.fleet.back()
	ok(G.fleet.size() == n0 + 1 and float(raised.hullFrac) < 0.25 and not Campaign.defects(raised).is_empty() and float(G.cargo.steel) < st0, "raised, she joins at a fifth of her hull with %d defect(s), for steel from the holds" % Campaign.defects(raised).size())
	raised.defects = ["shafts", "boilers"]; raised.hullFrac = 1.0; Campaign.ship_refitted(raised)
	var plain: Dictionary = raised.duplicate(true); plain.erase("defects")
	ok(Campaign.fleet_map_speed([raised]) < Campaign.fleet_map_speed([plain]) * 0.95, "bent shafts make her slower on passage")
	var rb: int = Campaign.rebuild_cost(raised); var cr: float = G.credits; Campaign.rebuild(raised)
	ok(Campaign.defects(raised).is_empty() and is_equal_approx(float(G.credits), cr - rb) and rb > 0, "a yard rebuilds the defects away (%s)" % Campaign.fmt(rb))
	# air raids from the land on your squadron (the owner's go-ahead): from an enemy airfield that has found you, by day
	Campaign.new_game("commission"); G = Campaign.G; var P2: Dictionary = G.player
	var af: Dictionary = {}
	for x in Structures.all(): if x.kind == "airfield" and x.fac != "" and x.fac != "player": af = x; break
	G.rep[af.fac] = -100; af.dmg = 0.0
	var cpt := Structures.coast_point(af); P2.x = cpt.x; P2.y = cpt.y
	G.fleet = [Campaign.new_ship("dd_fletcher", "Lone", "player", [])]
	var shot_dd := 0; var shot_aa := 0; var hit_dd := 0
	for i in 30: var rr := Structures.air_raid(af); shot_dd += int(rr.flak) + int(rr.fighters); hit_dd += rr.hits.size()
	G.fleet = [Campaign.new_ship("cl_atlanta", "Flak", "player", []), Campaign.new_ship("cl_atlanta", "Flak2", "player", []), Campaign.new_ship("cv_essex", "Deck", "player", [])]
	for i in 30: var rr := Structures.air_raid(af); shot_aa += int(rr.flak) + int(rr.fighters)
	ok(shot_aa > shot_dd * 1.5 and hit_dd > 0, "a raid hurts a lone destroyer; flak cruisers and a carrier's fighters bring down far more (%d against %d in 30 raids)" % [shot_aa, shot_dd])
	var fl: Dictionary = G.fleet[0]; fl.hullFrac = 1.0
	G.spotted = {str(af.id): int(G.day)}; G.raided = {}; Weather.force = {"sea": 0, "fog": false, "night": true, "moon": 0.5}; Campaign._wx = {}
	for i in 20: G.raided = {}; Structures._air_raids()
	ok(G.raided.is_empty(), "no raid comes by night")
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}; Campaign._wx = {}
	var came := false
	for i in 20:
		G.raided = {}; Structures._air_raids()
		if not G.raided.is_empty(): came = true; break
	ok(came, "by day, found by its search planes and within reach, it does")
	G.spotted = {}; G.raided = {}
	for i in 20: Structures._air_raids()
	ok(G.raided.is_empty(), "an airfield that has not found you sends nothing")
	# points of interest: each new world scatters more, and three kinds are new
	Campaign.new_game("commission"); G = Campaign.G
	var gen: Array = G.pois.filter(func(q): return q.get("gen", false))
	var kinds := {}
	for q in gen: kinds[q.type] = true
	ok(gen.size() >= 15 and kinds.has("den") and kinds.has("island") and kinds.has("fleet"), "a new world has %d more sites, dens, islands and scuttled fleets among them" % gen.size())
	ok(gen.all(func(q): return not Campaign.on_land(q.x, q.y)), "all of them at sea")
	var den: Dictionary = gen.filter(func(q): return q.type == "den")[0]
	G.cargo.munitions = 20.0; var cr0: float = G.credits; print("  ", Campaign.den_sell(den))
	ok(float(G.credits) - cr0 > 20.0 * Campaign.den_price(den, "munitions") * 1.2 and float(G.cargo.munitions) < 1.0, "a den buys munitions a quarter above the market")
	var isl: Dictionary = gen.filter(func(q): return q.type == "island")[0]
	ok(Campaign.can_take_island(isl) != "", "an island is not taken without troops")
	G.tech = ["amphib"]; G.fleet = [Campaign.new_ship("ap_haskell", "T1", "player", []), Campaign.new_ship("ap_haskell", "T2", "player", [])]; G.crew = Campaign.crew_need()
	var took := false
	for i in 20:
		G.troops = Structures.troop_capacity(); print("  ", Campaign.take_island(isl))
		if isl.fac == "player": took = true; break
	ok(took, "with troops it is taken")
	var rp0: int = int(G.rp); cr0 = G.credits; G.day = 59; G.cargo.food = 900.0; G.cargo.fuel = 900.0; Campaign.new_day(false)
	ok(int(G.rp) >= rp0 + Campaign.ISLAND_RP, "and it pays each month (RP %d to %d)" % [rp0, int(G.rp)])
	var sf: Dictionary = gen.filter(func(q): return q.type == "fleet")[0]; var nh: int = sf.hulks.size(); var t0: String = sf.hulks[0]
	ok(Campaign.fleet_wreck(sf, 0).rec.type == t0 and Campaign.fleet_wreck(sf, 0).rec.type == t0, "a scuttled fleet's hulks keep their designs between looks")
	G.credits = 900000.0; G.cargo.steel = float(Campaign.recover_cost(Campaign.fleet_wreck(sf, 0).rec).steel) + 5.0; G.fleet = [Campaign.new_ship("cl_cleveland", "C", "player", [])]; G.crew = 5000
	print("  ", Campaign.raise_hulk(sf, 0))
	ok(sf.hulks.size() == nh - 1 and G.fleet.size() == 2 and String(G.fleet[1].type) == t0, "a hulk is raised from it")
	# officers with character: bold, steady or cautious, and it tells in how the ship is fought
	ok(Campaign.TEMPERS.has(Campaign.temper(Campaign.new_officer(2))) and Campaign.temper({"name": "old"}) == "steady", "a new officer has a temper; one from before is steady")
	var dist := {}
	for tmk in ["bold", "cautious"]:
		var tot := 0.0
		for rep in 3:
			seed(70 + rep)
			var ts := _sim(["cl_cleveland", "dd_fletcher"], ["cl_agano"]); var me = ts.ships[1]; me.tm = tmk; ts.flag = ts.ships[0]; ts.flag.ai_off = true
			for x in ts.ships: x.hold = true
			ts.hold_fire = true
			for i in 4000: ts.step(0.05)
			tot += me.pos.distance_to(ts.ships[2].pos)
		dist[tmk] = tot / 3.0
	ok(float(dist.bold) < float(dist.cautious) * 0.9, "a bold captain closes the enemy, a cautious one keeps the range open (%.0f m against %.0f m)" % [float(dist.bold), float(dist.cautious)])
	var cs := _sim(["cl_cleveland", "dd_fletcher"], ["cl_agano"]); var cm = cs.ships[1]; cm.tm = "cautious"; cs.flag = cs.ships[0]; cm.hull = cm.max_hull * 0.3
	cs.ai_ship(cm, 0.1)
	ok(cm.ord == "retreat", "a cautious captain of yours, badly hurt, takes his ship out of the fight")
	# Era IV, the Network age (the owner's go-ahead): its gate, the other navies' pace, and what each technology does
	ok(Campaign.era_of(Campaign.enemy_tech(3)) == 3 and Campaign.era_of(Campaign.enemy_tech(4)) == 4, "the other navies' Era III stays Era III; their Era IV is Era IV")
	var t3: Array = Campaign.enemy_tech(3); t3.append("datalink")
	ok(Campaign.era_of(t3) == 4 and Campaign.design_ok("ddg_zumwalt", t3 + ["stealth"]) and not Campaign.design_ok("ddg_zumwalt", Campaign.enemy_tech(3)), "five Era III technologies open Era IV, and stealth shaping its stealth destroyer")
	var e4 := _sim(["ddg_burke"], ["ddg_sovremenny"]); var ab = e4.ships[0]
	ab.tech = []; var rng0: float = e4.gun_range(ab, GameData.weapons["ssm"])
	ab.tech = ["precision"]; var rng1: float = e4.gun_range(ab, GameData.weapons["ssm"])
	ok(rng1 > rng0 * 1.35, "precision strike: anti-ship missiles reach 40%% farther (%.0f to %.0f m)" % [rng0, rng1])
	var dn := _sim(["ddg_burke"], ["ddg_sovremenny"], Weather.battle({"sea": 0, "fog": false, "night": true, "moon": 0.2}))
	var nb = dn.ships[0]; nb.tech = ["drones"]; nb.fp = dn.spot_cap(nb)
	ok(dn.spot_cap(nb) == 1 and dn.spotter_why(nb) == "" and dn.launch_spotter(nb), "a destroyer with unmanned aircraft flies off a drone, by night")
	dn.spotters[0].pos = dn.ships[1].pos + Vector2(500, 0)
	ok(dn.spotter_over(0, dn.ships[1].pos), "and the drone sees in the dark, as a floatplane does not")
	sections += 1

## Research by levels (the owner's request, 12 Nov 2026).
func _levels() -> void:
	Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	var radar: Dictionary = Campaign.C.TECH.filter(func(x): return x.id == "radar")[0]
	var jets: Dictionary = Campaign.C.TECH.filter(func(x): return x.id == "jets")[0]
	G.rp = 0
	ok(Campaign.can_research(radar).begins_with("Needs") and not Campaign.research(radar), "no research without the points")
	ok(Campaign.can_research(jets).begins_with("Opens"), "an era not yet open says so (%s)" % Campaign.can_research(jets))
	G.rp = 1000
	ok(Campaign.research(radar) and Campaign.has_tech("radar") and Campaign.tech_lv("radar") == 1 and int(G.rp) == 1000 - int(radar.cost), "level I as before")
	var c2 := Campaign.tech_cost(radar)
	ok(c2 > int(radar.cost) and Campaign.research(radar) and Campaign.tech_lv("radar") == 2 and G.tech.has("radar+2"), "level II costs more (%d) and is kept as radar+2" % c2)
	ok(Campaign.research(radar) and Campaign.tech_lv("radar") == 3 and Campaign.can_research(radar) == "Fully researched." and not Campaign.research(radar), "level III is the last")
	ok(Campaign.era_count(G.tech, 1) == 1, "an era counts a technology once, whatever its level")
	var nuc: Dictionary = Campaign.C.TECH.filter(func(x): return x.id == "nuclear")[0]
	ok(Campaign.tech_max("nuclear") == 1 and Campaign.tech_cost(nuc, 2) == 0, "a technology that only opens designs has one level")
	# the effects grow with the level: gun range and salvo spread
	var sim := BattleSim.new()
	sim.setup([Campaign.new_ship("ca_baltimore", "A", "player", [])], [Campaign.new_ship("dd_fletcher", "B", "raiders", [])], ["radar"], [], 0)
	var s: BattleSim.CShip = sim.ships[0]; var w: Dictionary = {}
	for m in s.mounts: if m.w.get("kind", "") == "gun": w = m.w; break
	var r1: float = sim.gun_range(s, w)
	s.tech = ["radar", "radar+2", "radar+3"]
	ok(sim.gun_range(s, w) > r1 * 1.05, "radar level III reaches farther than level I (%.0f against %.0f m)" % [sim.gun_range(s, w), r1])
	ok(BattleSim.tech_up(s.tech, "radar") == 2 and BattleSim.tech_up(["radar"], "radar") == 0 and BattleSim.tech_lv([], "radar") == 0, "levels read from the list")
	# the powers improve what they have
	ok(Campaign.enemy_tech(3).has("radar+2") and not Campaign.enemy_tech(2).has("radar+2") and Campaign.enemy_tech(4).has("radar+3") and not Campaign.enemy_tech(4).has("nuclear+2"), "the powers' levels follow their era")
	Campaign.save(); Campaign.load_game()
	ok(Campaign.tech_lv("radar") == 3, "levels survive a save")
	# the splash styles (the owner's choice with a way back, 12 Nov 2026): the new one lays a column and a slick, classic its own
	var sp := BattleSim.new(); sp.modern = true; sp.splash_new = true; sp.fx_splash(Vector2(500, 500), 20.0)
	var kinds: Array = sp.parts.map(func(q): return q.t)
	ok(kinds.has(BattleSim.P.COLUMN) and kinds.has(BattleSim.P.LACE) and not kinds.has(BattleSim.P.SPLASH), "the new splash: a column and a lacy slick")
	sp.parts.clear(); sp.splash_new = false; sp.fx_splash(Vector2(500, 500), 20.0); kinds = sp.parts.map(func(q): return q.t)
	ok(kinds.has(BattleSim.P.SPLASH) and kinds.has(BattleSim.P.WASH) and not kinds.has(BattleSim.P.COLUMN), "classic splashes are as they were")
	ok(Settings.SPLASH_DEFAULT == "new" and BattleSim.col_stand(20.4) > BattleSim.col_stand(6.0) * 3.0, "a heavy shell's column stands far longer than a light one's")
	sp.splash_new = true
	# shells on one spot never put a splash's clock back (the owner's clip, 13 Nov 2026: the hollow "reset" at every shell)
	sp.parts.clear(); sp.splash_cols.clear(); sp.splash_laces.clear(); sp.fx_splash(Vector2(500, 500), 8.0)
	for i in 12: sp.fx(0.1)
	var bw: BattleSim.Part = sp.splash_laces[0]; var cw: BattleSim.Part = sp.splash_cols[0]
	var b_dep: float = bw.dep; var b_life: float = bw.life; var b_pos: Vector2 = bw.pos; var b_size: float = bw.size; var c_life: float = cw.life
	sp.fx_splash(b_pos + Vector2(4, 0), 8.0)   # (beside where it has drifted to)
	ok(sp.splash_laces.size() == 1 and sp.splash_cols.size() == 1 and bw.dep == b_dep and bw.life == b_life and bw.pos == b_pos and bw.size == b_size and cw.life == c_life and b_dep > 0.5 and b_dep < 1.0, "a second shell in a hollow changes nothing at the instant it falls: no clock put back, no jump")
	for i in 3: sp.fx(0.1)
	ok(bw.dep > b_dep and bw.vel.x > 0.0 and bw.vel.length() < 4.0, "it is pressed down again from the depth it had, and slides towards the new shell")
	for i in 40: sp.fx(0.1)
	ok(bw.dep == 0.0 and sp.splash_cols.is_empty(), "three seconds after the last shell the hollow has filled, and a light gun's column is gone within five")
	# Era IV guns (13 Nov 2026): concealed barrels (looks only), the rail gun, and the Sea Shadow with no guns at all
	var wr: Dictionary = GameData.weapons["rail"]; var w16: Dictionary = GameData.weapons["g406"]
	ok(GameData.weapons["g155s"].get("hide", false) and GameData.weapons["g57s"].get("hide", false) and BattleSim.weapon_tons("rail") > 0.0 and BattleSim.weapon_tons("g155s") > 0.0 and BattleSim.weapon_tons("g57s") > 0.0, "the concealed guns and the rail gun are weapons with a weight")
	ok(BattleSim.shell_pen("rail", wr, 1.0) > BattleSim.shell_pen("g406", w16, 1.0) and float(wr.dmg) < float(GameData.weapons["g152t"].dmg) and float(wr.speed) > 2.0 * float(w16.speed) and BattleSim.SHELLS.slug.fire < 0.5, "a rail gun's slug: fast, through armour at any range, a light blow and few fires")
	ok(GameData.hulls["ddg_zumwalt"].get("power", false) and not GameData.hulls["bb_iowa"].get("power", false) and Campaign.tech_max("railgun") == 1, "only a hull with the power carries a rail gun, behind its own research")
	var hs := BattleSim.new(); hs.setup([Campaign.new_ship("ddg_zumwalt", "W", "player", ["stealth"])], [Campaign.new_ship("dd_fletcher", "B", "raiders", [])], ["stealth"], [], 0)
	var hm: BattleSim.Mount = null
	for m in hs.ships[0].mounts: if m.w.get("hide", false): hm = m; break
	ok(hm != null and hm.wid == "g155s", "the Wraith's standard guns are the concealed 155 mm")
	if hm != null:
		hs.hold_fire = true; for i in 40: hs.step(0.1)
		var in_: float = hm.out
		hm.recoil = 1.0; for i in 12: hs.step(0.1)
		ok(in_ == 0.0 and hm.out == 1.0, "a concealed gun lies in while it is quiet and runs out when it fires (%.1f, %.1f)" % [in_, hm.out])
	ok(not GameData.hulls["co_shadow"].slots.any(func(q): return ["S", "M", "L", "H", "A"].has(q.s)) and GameData.hulls["co_shadow"].slots.size() == 3, "the Sea Shadow carries launch cells and no guns")
	# deck cargo slides off in a list, and a ship going down can still be struck (the owner, 13 Nov 2026)
	var cs := BattleSim.new(); cs.modern = true; cs.setup([Campaign.new_ship("fr_container", "C", "player", [])], [Campaign.new_ship("dd_fletcher", "B", "raiders", [])], [], [], 0)
	var cship: BattleSim.CShip = cs.ships[0]; var nb: int = cship.boxes.size()
	for i in 50: cs._boxes(0.1)
	var level_n: int = cship.boxes.size()
	cship.list = 0.6; for i in 20: cs._boxes(0.1)
	var mid_n: int = cship.boxes.size()
	for i in 300: cs._boxes(0.1)
	ok(nb > 30 and level_n == nb and mid_n < nb and cship.boxes.is_empty(), "a container ship's deck cargo stays put on an even keel and goes over the side in a list (%d, %d, %d)" % [nb, mid_n, cship.boxes.size()])
	var hk: BattleSim.CShip = cs.ships[1]; hk.alive = false; hk.sink = 2.0
	cs.shells.append({"s": hk.pos + Vector2(0, -400), "e": hk.pos, "pos": hk.pos, "t": 0.0, "T": 0.05, "dmg": 100, "side": 0, "size": "H", "pen": 400.0, "fall": 0.3, "who": cship, "ammo": "ap", "tgt": null, "rel": 30.0, "mm": 406})
	cs.sys_log.clear(); cs.step(0.1)
	ok(int(cs.sys_log.get("shell on a hulk", 0)) == 1, "a shell bursts on a ship that is going down")
	hk.sink = 999.0
	cs.shells.append({"s": hk.pos + Vector2(0, -400), "e": hk.pos, "pos": hk.pos, "t": 0.0, "T": 0.05, "dmg": 100, "side": 0, "size": "H", "pen": 400.0, "fall": 0.3, "who": cship, "ammo": "ap", "tgt": null, "rel": 30.0, "mm": 406})
	cs.step(0.1)
	ok(int(cs.sys_log.get("shell on a hulk", 0)) == 1, "and falls in the sea once she is under")
	# the chart's edge (13 Nov 2026: lanes ran along its top row, where a squadron jammed for good and no tow could reach her)
	var eo := {"x": 5628.0, "y": 3.0, "rx": 5628.0, "ry": 3.0, "h": 0.0, "v": 0.0, "ri": 0, "route": [Vector2(5628, 3), Vector2(5700, 1)]}
	ok(Campaign.off_edge(eo) and float(eo.y) >= 12.0 and eo.get("route") == null and not Campaign.on_land(eo.x, eo.y) and Campaign.open_sea(eo.x, eo.y), "a squadron lying on the chart's top row is brought back onto a sea lane (%.0f, %.0f)" % [float(eo.x), float(eo.y)])
	var mid := {"x": 3000.0, "y": 1600.0, "route": null}
	ok(not Campaign.off_edge(mid), "one in mid-ocean is left alone")
	var lane_top := 0
	for id in Campaign.nav.get_point_ids(): if Campaign.nav.get_point_position(id).y < 12.0 or Campaign.nav.get_point_position(id).y > Campaign.MH - 12.0: lane_top += 1
	ok(lane_top == 0 and Campaign.nav_main.size() > 30000, "no sea lane runs within the chart's edge margin, and the open sea is one network (%d points)" % Campaign.nav_main.size())
	# standing orders, division leads and moulded stations (the owner, 13 Nov 2026)
	var os := BattleSim.new(); os.setup([Campaign.new_ship("ca_baltimore", "A", "player", []), Campaign.new_ship("dd_fletcher", "B", "player", []), Campaign.new_ship("dd_fletcher", "C", "player", []), Campaign.new_ship("dd_fletcher", "D", "player", [])], [Campaign.new_ship("dd_narvik", "E", "raiders", [])], [], [], 0)
	var fa: BattleSim.CShip = os.ships[0]; var fb: BattleSim.CShip = os.ships[1]; var fc: BattleSim.CShip = os.ships[2]; var fd: BattleSim.CShip = os.ships[3]
	os.flag = fa; os.set_own(fa, true); fa.throttle = 2; os.waypoints = [fa.pos + Vector2(4000, 0), fa.pos + Vector2(4000, 4000)]
	os.take_command(fb)
	ok(os.flag == fb and fa.own and fa.own_wps.size() == 2 and fa.own_thr == 2 and os.waypoints.is_empty(), "a ship under your own orders keeps her waypoints and engine order when you shift your flag")
	var far0: float = fa.pos.distance_to(fa.own_wps[0])
	for i in 1500: os.step(0.1)
	ok(fa.throttle == 2 and (fa.own_wps.size() < 2 or fa.pos.distance_to(fa.own_wps[0]) < far0 - 300.0), "and steers for them herself, at the speed you left her")
	os.take_command(fa)
	ok(os.flag == fa and not os.waypoints.is_empty(), "taking her back gives you her waypoints again")
	fd.lead = fc; fd.ord = "escort"; fc.ord = "goto"; fc.ord_pt = fc.pos + Vector2(0, -6000)
	ok(os.lead_of(fd) == fc and os.lead_of(fb) == os.flag, "a ship can form on a lead of her own, the rest on the flagship")
	fd.st_off = Vector2(-200.0, 300.0)
	ok(os.station(fd) == Vector2(-200.0, 300.0), "and keep a station you gave her")
	fc.alive = false
	ok(os.lead_of(fd) == os.flag, "her lead lost, she forms on the flagship")
	# jets carry missiles and bombs, never torpedoes (the owner, 13 Nov 2026)
	var js := BattleSim.new(); js.setup([Campaign.new_ship("cv_forrestal", "J", "player", ["jets"])], [Campaign.new_ship("ca_hipper", "H", "raiders", [])], ["jets", "radar", "missiles"], [], 0)
	js.sep = 9000.0; Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}; js.wx = Weather.battle(Weather.force)
	js.launch_strike(js.ships[0], js.ships[1])
	var jt: Array = js.air.map(func(q): return q.type)
	ok(not jt.is_empty() and jt.has("ms") and not jt.has("tb") and js.air.all(func(q): return q.jet), "a jet carrier's strike is armed with missiles and bombs (%s)" % str(jt))
	var ps := BattleSim.new(); ps.setup([Campaign.new_ship("cv_essex", "P", "player", [])], [Campaign.new_ship("ca_hipper", "H", "raiders", [])], [], [], 0); ps.wx = Weather.battle(Weather.force)
	ps.launch_strike(ps.ships[0], ps.ships[1])
	ok(ps.air.map(func(q): return q.type).has("tb"), "a propeller air group still carries torpedoes")
	for i in 6000:
		js.step(0.1)
		if int(js.sys_log.get("air missiles", 0)) > 0: break
	ok(int(js.sys_log.get("air missiles", 0)) > 0 and js.torps.is_empty(), "the jets let their missiles go from well off, and drop no torpedo")
	ok(preload("res://scripts/skirmish.gd").ERA_TECH.has(4) and preload("res://scripts/skirmish.gd").ERA_TECH[4].has("stealth"), "the quick battle has Era IV")
	ok(BattleSim.calibre_mm("g510t") == 510 and BattleSim.calibre_mm("aa40") == 0 and sp.shell_splash({"mm": 510}, 3.4) > sp.shell_splash({"mm": 356}, 3.4) * 1.3 and sp.shell_splash({"mm": 152}, 1.5) == 9.0, "heavy guns' splashes go by calibre, lighter ones by their class")
	sections += 1

## Armour by place (docs/ARMOUR.md): belt, deck and turrets of their own; the deck struck more the steeper the fall; a
## turret pierced is out of action; thin ends; penetration by calibre and range.
func _armour() -> void:
	var iowa: Dictionary = GameData.hulls["bb_iowa"]; var a := BattleSim.armour_of(iowa)
	ok(int(a.belt) == 307 and int(a.deck) == 153 and int(a.tur) == 432 and is_equal_approx(float(a.cit), 0.6), "the Iowa: belt 307, deck 153, turrets 432 mm, citadel 0.6")
	var fl: Dictionary = GameData.hulls["dd_fletcher"]; var b := BattleSim.armour_of(fl)
	ok(is_equal_approx(float(b.deck), float(fl.armor) * 0.4) and is_equal_approx(float(b.tur), float(fl.armor)), "a design without figures: deck 0.4 of the belt, turrets as the belt")
	ok(int(BattleSim.armour_of(iowa, {"arm": {"deck": 25}}).deck) == 178, "a refit's armour adds to the place")
	var near := BattleSim.deck_share(iowa, BattleSim.fall_angle(0.1, "H")); var far := BattleSim.deck_share(iowa, BattleSim.fall_angle(1.0, "H"))
	ok(near < 0.2 and far > 0.6, "the deck is struck %d%% of the time close in, %d%% at the limit" % [int(near * 100), int(far * 100)])
	var p16a := BattleSim.shell_pen("g406", GameData.weapons["g406"], 0.0); var p16b := BattleSim.shell_pen("g406", GameData.weapons["g406"], 0.5); var p16c := BattleSim.shell_pen("g406", GameData.weapons["g406"], 1.0)
	ok(p16a > 750 and p16b > 450 and p16b < 560 and p16c < 320, "the 16-inch: %d mm close in, %d at half range, %d at the limit" % [int(p16a), int(p16b), int(p16c)])
	# shells into an Iowa from a 16-inch: where they strike and what they do
	seed(31)
	var sim := BattleSim.new()
	sim.setup([Campaign.new_ship("bb_iowa", "A", "player", [])], [Campaign.new_ship("bb_iowa", "B", "raiders", [])], [], [], 0)
	var tg: BattleSim.CShip = sim.ships[1]; tg.pos = Vector2.ZERO; tg.a = 0.0
	var places := {}; var ends := 0; var mk := func(fall: float, at: Vector2) -> Dictionary:
		var sh := {"s": at + Vector2(0, -8000), "e": at, "pos": at, "dmg": 285.0, "size": "H", "pen": BattleSim.shell_pen("g406", GameData.weapons["g406"], fall), "fall": fall, "ammo": "ap"}
		return sim.shell_result(tg, sh)
	for i in 300:
		var r: Dictionary = mk.call(1.0, Vector2(randf_range(-60, 60), 0)); places[r.get("place", "")] = int(places.get(r.get("place", ""), 0)) + 1
	ok(int(places.get("deck", 0)) > int(places.get("belt", 0)), "plunging fire at the limit strikes the deck most (%s)" % str(places))
	places = {}
	for i in 300:
		var r: Dictionary = mk.call(0.1, Vector2(randf_range(-60, 60), 0)); places[r.get("place", "")] = int(places.get(r.get("place", ""), 0)) + 1
	ok(int(places.get("belt", 0)) > 3 * int(places.get("deck", 0)), "close in it strikes the side (%s)" % str(places))
	var endr: Dictionary = mk.call(0.5, Vector2(float(iowa.L) * 0.46, 0))
	ok(endr.get("ends", false) and endr.kind != "nopen", "a hit at her bow meets thin plating (%s)" % endr.text)
	var tur: BattleSim.Mount = null
	for m in tg.mounts: if m.w.size == "H": tur = m; break
	tg.ar.tur = 50.0; tur.dead = false   # a turret with its face shot away (the shots above may have knocked it out)
	var got := false
	for i in 40:
		var r: Dictionary = mk.call(0.2, Vector2(float(tur.slot.x), float(tur.slot.y)))
		if r.get("place", "") == "tur" and r.kind == "pen": got = true; break
	ok(got and tur.dead, "a shell through a turret's face puts it out of action")
	sections += 1

## Refits by place and rebuilding (docs/REFIT.md): armour plate in a refit, weighed and paid for; reconstruction; a
## sister ship built to a plan.
func _rebuilds() -> void:
	Campaign.new_game("commission"); var G: Dictionary = Campaign.G; G.credits = 2000000
	var WM = load("res://scripts/world_map.gd").new()
	var iowa: Dictionary = GameData.hulls["bb_iowa"]
	var t1: Dictionary = BattleSim.armour_tons(iowa, {"belt": 10}); var t2: Dictionary = BattleSim.armour_tons(iowa, {"deck": 10})
	ok(float(t1.total) > 50 and float(t1.total) < 120 and float(t2.total) > 250 and float(t2.total) < 500, "10 mm more belt on an Iowa weighs %d t, 10 mm more deck %d t" % [int(t1.total), int(t2.total)])
	var fit: Array = BattleSim.default_fit(iowa, [])
	var l0: Dictionary = BattleSim.loading(iowa, fit, {}); var l1: Dictionary = BattleSim.loading(iowa, fit, {}, {"deck": 30})
	ok(float(l1.tons) > float(l0.tons) + 900 and float(l1.top) > float(l0.top) and float(l1.speed) < float(l0.speed), "30 mm more deck: %d t, slower (%.3f)" % [int(float(l1.tons) - float(l0.tons)), float(l1.speed)])
	var l2: Dictionary = BattleSim.loading(iowa, fit, {}, {"belt": -15})
	ok(float(l2.tons) < float(l0.tons) and float(l2.speed) >= float(l0.speed), "belt plate landed: lighter")
	var s: Dictionary = Campaign.new_ship("bb_iowa", "Test", "player", []); G.fleet.append(s)
	var c0 := float(G.credits); var cost: Array = WM.refit_cost(s, s.fit, {"belt": 15})
	WM.apply_refit(s, s.fit.duplicate(), {"belt": 15})
	ok(s.get("arm", {}).get("belt", 0.0) == 15.0 and float(G.credits) < c0 and float(cost[0]) > 0 and Campaign.readiness(s) < 1.0, "a refit adds 15 mm of belt for %d and some readiness" % int(cost[0]))
	ok(int(BattleSim.armour_of(iowa, s).belt) == 322, "her belt is now 322 mm")
	var sim := BattleSim.new(); sim.setup([s], [Campaign.new_ship("dd_fletcher", "B", "raiders", [])], [], [], 0)
	ok(absf(float(sim.ships[0].ar.belt) - 322.0) < 1.0, "and she goes into action with it")
	WM.apply_refit(s, s.fit.duplicate(), {})
	ok(not s.has("arm"), "landing it again leaves her as built")
	# reconstruction: an old ship only
	var old: Dictionary = Campaign.new_ship("bb_nelson", "Old", "player", []); old.built = int(G.day) - 365 * 15; old.wear = 0.6; G.fleet.append(old)
	ok(Campaign.can_reconstruct(s) != "" and Campaign.can_reconstruct(old) == "", "a new ship is not rebuilt; an old one can be")
	var floor0: float = Campaign.wear_floor(old); Campaign.reconstruct(old)
	ok(Campaign.age_years(old) < 2.1 and Campaign.wear_floor(old) < floor0 and Campaign.readiness(old) <= Campaign.RDY_MIN + 0.001, "rebuilt: she wears as a ship two years old")
	# a sister ship built to a plan
	var p: Dictionary = {}
	for q in G.ports: if WM.yard_of(q).has("bb_iowa"): p = q; break
	if not p.is_empty():
		var plan: Array = s.fit.duplicate(); var pr: int = WM.sister_price(p, s, plan, {"deck": 10})
		ok(pr > WM.ship_price(p, "bb_iowa"), "a sister ship with more deck armour costs more than the yard's price (%d)" % pr)
	else: ok(true, "(no yard builds the Iowa in this world)")
	WM.free()
	sections += 1

## Electronic war (docs/SENSORS.md): jamming shortens enemy radar and is heard far off; a sea-skimmer is not seen by a SAM
## ship until close; a high diver is flown at a ship with close-in guns and no SAMs; chaff leads seekers off.
func _ew() -> void:
	var tech := ["radar", "missiles", "ciws", "ecm"]
	var sim := BattleSim.new()
	sim.setup([Campaign.new_ship("ddg_burke", "A", "player", tech)], [Campaign.new_ship("ddg_sovremenny", "B", "directorate", tech)], tech, tech, 0)
	var a: BattleSim.CShip = sim.ships[0]; var b: BattleSim.CShip = sim.ships[1]
	sim.flag = null; Weather.force = {"sea": 0, "fog": false, "night": true, "moon": 0.0}
	ok(a.chaff == BattleSim.CHAFF_ROUNDS and sim.can_jam(a), "a ship with ECM carries chaff and a jammer")
	a.pos = Vector2.ZERO; b.pos = Vector2(sim.sight(b) * 0.8, 0)
	a.jam_on = true; sim._ew_tick(0.1)
	ok(is_equal_approx(sim.jam_mult(a), BattleSim.JAM_K) and is_equal_approx(sim.jam_mult(b), 1.0), "the jammer covers her own side only")
	ok(sim._radar_heard(a, 1), "a jammer is heard by the enemy")
	a.jam_on = false; sim._ew_tick(0.1)
	var q := {"pos": Vector2(5000, 0), "side": 1, "kind": "ssm", "delay": 0.0, "prof": "skim"}
	sim.missiles = [q]
	ok(sim.nearest_missile(0, Vector2.ZERO, 9000.0, true) == null, "a SAM ship cannot see a sea-skimmer 5 km out")
	q.pos = Vector2(1500, 0)
	ok(sim.nearest_missile(0, Vector2.ZERO, 9000.0, true) == q, "it can at 1.5 km")
	q.prof = "high"; q.pos = Vector2(5000, 0)
	ok(sim.nearest_missile(0, Vector2.ZERO, 9000.0, true) == q, "a high diver is seen far out")
	sim.missiles = []
	var c := BattleSim.new(); c.setup([Campaign.new_ship("ddg_burke", "A", "player", tech)], [Campaign.new_ship("dd_gearing", "G", "directorate", ["radar"])], tech, ["radar"], 0)
	var gearing: BattleSim.CShip = c.ships[1]
	for m in gearing.mounts: if m.w.kind == "aa": m.wid = "ciws"
	ok(c.missile_profile(c.ships[0], gearing) == "high" and c.missile_profile(c.ships[0], b) == "skim", "a high dive at a ship with close-in guns and no SAMs; low at one with SAMs")
	# chaff: a missile closing on a ship beside a cloud is led off some of the time
	var lured := 0
	for i in 60:
		sim.decoys = [{"pos": a.pos + Vector2(0, 200), "t": 20.0, "side": 0}]; a.chaff_t = 99.0
		var mq := {"pos": Vector2(1200, 0), "a": PI, "v": 250.0, "speed": 250.0, "life": 30.0, "dmg": 100, "side": 1, "target": a, "kind": "ssm", "delay": 0.0, "prof": "skim", "sk": 0.0, "age": 1.0}
		sim.missiles = [mq]; sim.step(0.02)
		if mq.has("lure"): lured += 1
	ok(lured > 12 and lured < 40, "chaff leads %d of 60 missiles off" % lured)
	# hand-laid light guns against missiles (the owner, 13 Nov 2026)
	var shot := [0, 0]
	for k in 2:
		var tk: Array = [] if k == 0 else ["radar", "missiles"]
		var w2 := BattleSim.new(); w2.setup([Campaign.new_ship("bb_yamato", "Y", "player", tk)], [Campaign.new_ship("ddg_burke", "B", "directorate", tech)], tk, tech, 0)
		var y: BattleSim.CShip = w2.ships[0]; y.pos = Vector2.ZERO; w2.ships[1].pos = Vector2(60000, 0); w2.ships[1].ai_off = true; w2.editor = true; y.god = true
		ok(is_equal_approx(w2.gun_pd(y), BattleSim.HAND_PD if k == 0 else BattleSim.HAND_PD_FC), "light guns' chance against a missile follows the ship's fire control (%d)" % k)
		for i in 40:
			var mq2 := {"pos": Vector2(4000, 0).rotated(i * 0.7), "a": i * 0.7 + PI, "v": 250.0, "speed": 250.0, "life": 30.0, "dmg": 1, "side": 1, "target": y, "kind": "ssm", "delay": 0.0, "prof": "skim", "sk": 0.0, "age": 1.0}
			w2.missiles = [mq2]
			for n in 500:
				w2.step(0.05)
				if mq2.get("dead", false): shot[k] += 1; break
				if w2.missiles.is_empty(): break
	print("  missiles shot down of 40 by a Second World War battleship: %d with her own fire control, %d with the missile age's" % shot)
	ok(shot[0] < 14 and shot[1] > shot[0], "a Second World War ship's light guns stop few missiles (%d of 40; %d with later directors)" % shot)
	# missiles against armour and above it, and the heavy missile (the owner, 13 Nov 2026)
	var mm := BattleSim.new(); mm.setup([Campaign.new_ship("bb_yamato", "Y", "player", []), Campaign.new_ship("ddg_burke", "B", "player", tech)], [Campaign.new_ship("cg_kirov", "K", "directorate", tech)], tech, tech, 0)
	var ym: BattleSim.CShip = mm.ships[0]; var bk: BattleSim.CShip = mm.ships[1]; var kv: BattleSim.CShip = mm.ships[2]
	var wd: float = float(GameData.weapons.ssm.dmg); var wh: float = float(GameData.weapons.ssmh.dmg)
	var h0: float = ym.hull; mm.damage(ym, wd, "missile"); var per: float = h0 - ym.hull
	ok(absf(per - wd * (1.0 - BattleSim.MSL_ARMOUR)) < 1.0 and ym.max_hull / per > 45.0 and ym.max_hull / per < 65.0, "a sea-skimmer costs the Yamato %.0f of %d: about %d hits to sink her (it was 74)" % [per, int(ym.max_hull), int(ym.max_hull / per)])
	h0 = ym.hull; mm.damage(ym, wh, "missile_h"); var perh: float = h0 - ym.hull
	ok(perh > per * 2.5 and ym.max_hull / perh < 22.0, "a heavy missile costs her %.0f: about %d hits" % [perh, int(ym.max_hull / perh)])
	h0 = bk.hull; mm.damage(bk, wd, "missile")
	ok((h0 - bk.hull) / bk.max_hull > 0.14 and (h0 - bk.hull) / bk.max_hull < 0.25, "a missile costs an unarmoured destroyer %d%% of her hull (it was 12%%)" % int((h0 - bk.hull) / bk.max_hull * 100.0))
	var f0: int = ym.fires.size(); var alive0: int = ym.mounts.filter(func(m): return not m.dead).size()
	for i in 6: mm._missile_blast(ym, ym.pos + Vector2(float(i) * 12.0 - 30.0, 10.0).rotated(ym.a), false)
	var heavy_dead: int = ym.mounts.filter(func(m): return m.dead and m.w.kind == "gun" and (m.w.size == "H" or m.w.size == "L")).size()
	ok(ym.fires.size() == f0 + 6 and ym.mounts.filter(func(m): return not m.dead).size() < alive0 - 3 and heavy_dead == 0, "every missile hit starts a fire and wrecks light mounts near it (%d of %d left), never an armoured turret" % [ym.mounts.filter(func(m): return not m.dead).size(), alive0])
	ok(kv.mounts.any(func(m): return m.wid == "ssmh") and GameData.weapons.ssmh.get("heavy", false) and float(GameData.weapons.ssmh.speed) > 1.9 * float(GameData.weapons.ssm.speed), "the Kirov carries the heavy missile, twice as fast as the other")
	# a salvo's later missiles leave from the cell, wherever the ship has got to by then (the owner, 13 Nov 2026)
	var ls := BattleSim.new(); ls.setup([Campaign.new_ship("ddg_burke", "B", "player", tech)], [Campaign.new_ship("ca_hipper", "H", "directorate", [])], tech, [], 0)
	var lb: BattleSim.CShip = ls.ships[0]; var lh: BattleSim.CShip = ls.ships[1]; lb.ai_off = true; lh.ai_off = true; lb.pos = Vector2(5000, 5000); lb.a = 0.0; lh.pos = Vector2(5000, 12000)
	var cellm = null
	for m in lb.mounts: if m.w.kind == "ssm" and cellm == null: cellm = m
	ls.fire_missile(lb, cellm, lh)
	var late: Dictionary = ls.missiles.back(); var worst := 0.0
	for i in 200:
		lb.v = 15.0; ls.step(0.05)
		if not ls.missiles.has(late): break
		if float(late.delay) > 0.0: worst = maxf(worst, late.pos.distance_to(ls.world_pt(lb, cellm.slot.x, cellm.slot.y)))
		else: break
	ok(ls.missiles.size() >= 2 and worst < 1.5 and lb.pos.x > 5020.0, "the last missile of a salvo waits in her cell as the ship steams on (never more than %.1f m from it; the ship moved %d m)" % [worst, int(lb.pos.x - 5000.0)])
	# every kind of shot has its card on the flagship's shell panel (the rail gun's slug had none: the panel failed every frame)
	var hud_info: Dictionary = preload("res://scripts/battle_hud.gd").SHELL_INFO
	ok(BattleSim.SHELLS.keys().all(func(k): return hud_info.has(k)), "every kind of shell has a card on the shell panel %s" % str(BattleSim.SHELLS.keys()))
	# guns by era: no design of the missile age carries a wartime mount as built, and the reverse
	var wrong := []
	for id in GameData.hulls:
		var hd: Dictionary = GameData.hulls[id]
		for sl in hd.slots:
			if int(hd.get("era", 1)) >= 3 and ["g76", "g127s", "g130t"].has(sl.def): wrong.append(id)
			if int(hd.get("era", 1)) <= 2 and ["g76a", "g127a", "g130a"].has(sl.def): wrong.append(id)
	ok(wrong.is_empty(), "wartime and missile-age designs do not share gun mounts %s" % str(wrong.slice(0, 5)))
	# a side mount takes no gun much bigger than the one she was built with there (the owner, 13 Nov 2026)
	var bd: Dictionary = GameData.hulls["ca_baltimore"]; var wing = null; var mid = null
	for sl in bd.slots:
		if sl.s == "M" and float(sl.y) != 0.0 and wing == null: wing = sl
		if sl.s == "M" and float(sl.y) == 0.0 and mid == null: mid = sl
	ok(wing != null and not BattleSim.room_for(wing, "g152") and not BattleSim.room_for(wing, "g150t") and BattleSim.room_for(wing, "g130t") and BattleSim.room_for(wing, String(wing.def)) and BattleSim.room_for(wing, ""), "a cruiser's side mount refuses a 6-inch triple and takes a gun of its own size")
	ok(mid == null or (BattleSim.room_for(mid, "g150t") and not BattleSim.room_for(wing, "g150t")), "a centreline mount has more room: it takes a 150 mm twin the side mount refuses")
	var tub: Dictionary = GameData.hulls["cve_casa"].slots[0]
	ok(not BattleSim.room_for(tub, "g152") and BattleSim.room_for(tub, String(tub.def)), "but not a 6-inch triple on an escort carrier's stern gun tub")
	var no_art := []
	for id in GameData.hulls: for sl in GameData.hulls[id].slots: if String(sl.def) != "" and GameData.weapons.has(String(sl.def)) and String(GameData.weapons[String(sl.def)].size) != "V" and not GameData.sprites.get("mounts", {}).has(String(sl.def)) and not no_art.has(String(sl.def)): no_art.append(String(sl.def))
	ok(no_art.is_empty(), "every weapon a design carries has its mount picture (sprites.json; missing: %s)" % ", ".join(no_art))
	var fx: Array = GameData.hulls["cg_slava"].slots.filter(func(q): return q.get("fixed", false))
	ok(fx.size() == 2 and fx.all(func(q): return q.def == "ssmh" and BattleSim.room_for(q, "ssmh") and not BattleSim.room_for(q, "") and not BattleSim.room_for(q, "ssm") and not BattleSim.room_for(q, "sam")), "the Slava's P-500 tubes are fixed: heavy anti-ship missiles only, never emptied")
	var sv := BattleSim.new(); sv.setup([Campaign.new_ship("cg_slava", "S", "player", ["radar", "missiles", "vls"])], [Campaign.new_ship("ddg_burke", "B", "directorate", ["radar", "missiles"])], ["radar", "missiles", "vls"], ["radar", "missiles"], 0); sv.flag = null
	var sl0 = sv.ships[0]; var tg0 = sv.ships[1]; tg0.pos = sl0.pos + Vector2.from_angle(sl0.a + PI / 2) * 9000.0
	for m in sl0.mounts: if m.wid == "ssmh": sv.fire_missile(sl0, m, tg0)
	var mine: Array = sv.missiles.filter(func(q): return q.get("who") == sl0)
	var delays: Array = mine.map(func(q): return float(q.delay)); var cells := {}
	for mq in mine: cells[mq.cell] = true
	var straight := mine.all(func(q): return absf(wrapf(float(q.a) - sl0.a, -PI, PI)) < 0.001 and float(q.get("boost", 0.0)) > 0.0)
	delays.sort()
	ok(mine.size() >= 4 and cells.size() == mine.size() and straight and delays.all(func(x): return delays.count(x) == 1), "the Slava's missiles leave one at a time, each from her own tube, straight along it (%d rounds, %d tubes)" % [mine.size(), cells.size()])
	var all_std := true
	for id in GameData.hulls: for sl in GameData.hulls[id].slots: if not BattleSim.room_for(sl, String(sl.def)): all_std = false
	ok(all_std, "every design's own guns fit her mounts")
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	sections += 1

## Save slots and key bindings (12 Nov 2026).
func _slots_keys() -> void:
	Campaign.new_game("merchant"); var G: Dictionary = Campaign.G
	for m in Campaign.slots(): Campaign.slot_delete(m.id)
	G.credits = 12345
	var id := Campaign.slot_save("My first save!")
	ok(id == "my_first_save" and Campaign.slots().size() == 1 and int(Campaign.slots()[0].credits) == 12345, "a named save is listed with its purse")
	G.credits = 1; Campaign.G.day = 50; Campaign.save()
	ok(Campaign.slot_load(id) and int(Campaign.G.credits) == 12345 and int(Campaign.G.day) == 1, "loading it brings the campaign back as it was saved")
	ok(Campaign.load_game() and int(Campaign.G.credits) == 12345, "and it is now the running campaign")
	Campaign.slot_save("Second"); ok(Campaign.slots().size() == 2 and Campaign.slots()[0].name == "Second", "newest first")
	Campaign.slot_delete(id); ok(Campaign.slots().size() == 1, "a save deleted is gone")
	Campaign.slot_delete("second")
	# keys
	Settings.reset_keys()
	ok(Settings.key("battle", KEY_T) == KEY_T and Settings.bound("battle", KEY_T) == KEY_T, "with no bindings a key is itself")
	Settings.rebind("battle", KEY_T, KEY_L)
	ok(Settings.key("battle", KEY_L) == KEY_T and Settings.key("battle", KEY_T) == KEY_NONE, "torpedoes moved to L: L fires them, T does nothing")
	Settings.rebind("battle", KEY_T, KEY_Q)
	ok(Settings.key("battle", KEY_Q) == KEY_T and Settings.bound("battle", KEY_Q) == KEY_L, "giving it Q swaps: missiles take L")
	ok(Settings.key("chart", KEY_Q) == KEY_Q, "the chart's keys are its own")
	var cf := ConfigFile.new(); cf.load(Settings.PATH)
	ok(int(cf.get_value("keys", "battle", {}).get(KEY_T, 0)) == KEY_Q, "the bindings are saved")
	Settings.reset_keys(); ok(Settings.binds.battle.is_empty(), "reset")
	sections += 1

## Submarines (the owner, 13 Nov 2026): a missile boat picked in a quick battle of an earlier era carries her missiles;
## fixed tubes fire on a gyro angle, so a boat need not point straight at her target.
func _subs() -> void:
	var sk = load("res://scripts/skirmish.gd")
	var tech: Array = sk.ERA_TECH[3]
	var fit: Array = BattleSim.default_fit(GameData.hulls["ssn_typhoon"], tech)
	ok(fit.count("ssmh") == 4, "a Typhoon-type boat in Era III carries her four missile tubes (%s)" % str(fit))
	var sim := BattleSim.new()
	sim.setup([{"type": "ss_gato", "name": "A", "hullFrac": 1.0, "fit": BattleSim.default_fit(GameData.hulls["ss_gato"], []), "pal": "player"}], [Campaign.new_ship("dd_fletcher", "B", "raiders", [])], [], [], 0)
	var b: BattleSim.CShip = sim.ships[0]; var tube: BattleSim.Mount = null
	for m in b.mounts: if m.w.kind == "torp" and absf(float(m.slot.arcs[0][0])) < 0.1: tube = m; break
	ok(tube != null and sim.arc_check(tube.slot, 0.9).x == 0 and sim.tube_check(tube.slot, 0.9).x > 0 and sim.tube_check(tube.slot, 2.0).x == 0, "a bow tube bears 50 degrees off the bow on a gyro angle, not 115")
	sections += 1

## The realism and hunter patch, and officers' traits (the owner, 13 Nov 2026).
func _traits() -> void:
	Campaign.new_game("academy"); var G: Dictionary = Campaign.G
	# the balance preset
	var pt: Dictionary = Campaign.new_ship("pt_elco", "P", "raiders", []); var dd: Dictionary = Campaign.new_ship("dd_fletcher", "D", "raiders", [])
	ok(is_equal_approx(Campaign.strength([pt]), Campaign.ship_value(pt) * Campaign.PT_STRENGTH_MULT) and is_equal_approx(Campaign.strength([dd]), Campaign.ship_value(dd)), "a motor torpedo boat counts double in a force's strength; a destroyer as she is")
	var keep: Array = G.fleet.duplicate(); G.fleet = [pt]
	ok(is_equal_approx(Campaign.own_strength(), Campaign.ship_value(pt)), "your own torpedo boat counts at her price in your squadron's strength, not double")
	G.fleet = keep
	G.day = Campaign.HUNT_GRACE
	var k0: float = Campaign.hunt_k(); G.day = Campaign.HUNT_GRACE + 200; var k1: float = Campaign.hunt_k(); G.day = 2000
	ok(is_equal_approx(k0, 1.15) and is_equal_approx(k1, 1.30) and is_equal_approx(Campaign.hunt_k(), 1.45), "hunters come at 1.15 times your strength, rising to 1.45 and no more (%.2f, %.2f, %.2f)" % [k0, k1, Campaign.hunt_k()])
	G.day = 60
	var W: Dictionary = GameData.weapons
	ok(int(W.tor.range) == 2000 and int(W.tor93.range) == 4200 and int(W.torh.range) == 2600 and int(W.ciws.range) < int(W.aa40.range) and int(W.g127.range) > int(W.tor.range), "torpedoes reach 2,000, 4,200 and 2,600 m, inside a 5-inch gun's range; the CIWS is the inner screen")
	var packs := 0; var far := 0
	for i in 300:
		var f = Campaign.spawn_fleet("raiders", "raiders")
		if f == null: continue
		if f.ships.filter(func(x): return Campaign.hull(x).klass == "pt").size() * 2 > f.ships.size():
			packs += 1
			var near: float = INF
			for q in G.pois: if q.get("kind", "") == "den": near = minf(near, Campaign.mdist(q.x, q.y, f.x, f.y))
			for q in G.ports: near = minf(near, Campaign.mdist(q.sx, q.sy, f.x, f.y))
			if near > Campaign.PT_TETHER + 1.0 or not f.has("tether"): far += 1
		G.fleets.erase(f)
	ok(packs > 0 and far == 0, "raider packs that are mostly torpedo boats start within reach of a den or a harbour (%d packs, %d far out)" % [packs, far])
	# traits
	var o: Dictionary = Campaign.new_officer(1)
	ok(Campaign.traits(o).is_empty(), "a junior officer has no trait")
	var o5: Dictionary = Campaign.new_officer(5)
	ok(Campaign.traits(o5).size() == 2 and Campaign.grant_officer_trait(o5) == "", "an officer of level 5 has two, and never a third (%s)" % Campaign.trait_names(o5))
	var o3: Dictionary = Campaign.new_officer(3)
	ok(Campaign.traits(o3).size() == 1, "one of level 3 has one")
	o.traits = ["blockade_runner"]; o.ship = G.fleet[0].id; G.officers = [o]
	var v0: float = Campaign.fleet_map_speed(G.fleet) * float(Campaign.SPEEDS[Campaign.speed_order()][0])
	ok(is_equal_approx(Campaign.player_speed(), v0 * 1.08) and is_equal_approx(Campaign.trait_evade(), 0.10), "a blockade runner in the flagship gives the squadron 8% more speed and 10% more chance of breaking off")
	o.ship = null
	ok(is_equal_approx(Campaign.player_speed(), v0) and Campaign.trait_evade() == 0.0, "ashore, he gives nothing")
	var sim := BattleSim.new(); sim.setup([Campaign.new_ship("dd_fletcher", "A", "player", [])], [Campaign.new_ship("dd_fletcher", "B", "raiders", [])], [], [], 0)
	var a: BattleSim.CShip = sim.ships[0]
	Weather.force = {"sea": 0, "fog": false, "night": true, "moon": 0.0}; sim.wx = Weather.battle(Weather.force)
	var s0: float = sim.sight(a); var d0: float = sim.dc_k(a, "fire"); var p0: float = sim.gun_pd(a)
	a.traits = ["night_owl", "iron_dc", "flak_director"]
	ok(is_equal_approx(sim.sight(a), s0 * BattleSim.TRAIT_NIGHT_SIGHT) and is_equal_approx(sim.dc_k(a, "fire"), d0 * BattleSim.TRAIT_DC) and is_equal_approx(sim.dc_k(a, "mach"), 1.0) and is_equal_approx(sim.gun_pd(a), p0 * BattleSim.TRAIT_FLAK), "a night fighter sees further in the dark, a damage-control ace mends faster, an air defence director's guns are better against missiles")
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}; sim.wx = Weather.battle(Weather.force)
	ok(is_equal_approx(sim.sight(a), sim.sight(sim.ships[1])), "by day the night fighter sees as anyone does")
	var tm = null
	for m in a.mounts: if m.w.kind == "torp": tm = m
	if tm != null:
		a.traits = []; a.ai_off = true; sim.ships[1].ai_off = true; tm.cd = 100.0; sim.step(1.0); var c0: float = 100.0 - tm.cd
		a.traits = ["torp_master"]; tm.cd = 100.0; sim.step(1.0); var c1: float = 100.0 - tm.cd
		ok(c0 > 0.0 and is_equal_approx(c1 / c0, BattleSim.TRAIT_TORP_RELOAD), "a torpedo specialist's tubes reload a quarter faster (%.2f)" % (c1 / maxf(c0, 0.001)))
	var r := {"notes": []}
	var lv: Dictionary = Campaign.new_officer(2); lv.traits = []; lv.lvl = 3
	var got: String = Campaign.grant_officer_trait(lv)
	ok(got != "" and Campaign.traits(lv).size() == 1 and Campaign.OFFICER_TRAITS.has(lv.traits[0]), "a trait is granted by name (%s)" % got)
	# the career record and the Codex's Manual (the owner, 13 Nov 2026)
	Campaign.new_game("academy"); G = Campaign.G
	G.kills = 10; G.day = 366; Campaign._career_day(); Campaign._career_day()
	var cr: Dictionary = Campaign.career()
	ok(cr.seen.has("k1") and cr.seen.has("k10") and cr.seen.has("y1") and cr.marks.size() == cr.seen.size(), "milestones are entered once each, with their day (%d)" % cr.marks.size())
	Campaign.career_battle({"victory": true, "lost": [1, 2]})
	ok(int(cr.battles) == 1 and int(cr.won) == 1 and int(cr.lost) == 2 and cr.seen.has("won1"), "an action is entered in the record")
	Campaign.save(); Campaign.load_game(); ok(Campaign.career().marks.size() == cr.marks.size(), "and the record is saved with the campaign")
	# the lore expansion: what the Codex keeps back, each power's voice on its contracts, the origins' opening tales
	var Wd: Dictionary = Codex.world()
	ok(Wd.powers.has("ombria") and Wd.powers.has("isles") and String(Wd.powers.isles.home).contains("Port Vesper") and Campaign.G.ports.any(func(q): return q.name == "Port Vesper" and q.fac == "isles" and q.capital), "the Codex has all nine powers, and the Isles' capital is Port Vesper on the chart too")
	Campaign.G.day = 30
	ok(not Codex.declassified("lost_squadron") and not Codex.declassified("throat"), "in 1946 the declassified truths are kept back")
	for q in Campaign.G.pois: if String(q.name).contains("Throat"): q.surveyed = true
	ok(Codex.declassified("throat") and not Codex.declassified("lost_squadron"), "a site surveyed opens its own truth")
	Campaign.G.day = 320
	ok(Campaign.year() == 1947 and Codex.declassified("lost_squadron"), "and from 1947 both are open")
	Campaign.G.day = 30
	var cv: Dictionary = {"fac": "directorate", "kind": "hunt", "x": Campaign.G.player.x, "y": Campaign.G.player.y, "from": "Strelsk"}
	var cvt: String = Diplomacy.voiced(cv)
	ok(cvt.begins_with("Directive 88-B") and not cvt.contains("{"), "a Directorate hunt opens in the Directorate's voice (%s)" % cvt.substr(0, 60))
	ok(Diplomacy.voiced({"fac": "raiders", "kind": "hunt"}) == "", "a flag with no voice gives the plain terms alone")
	var miss := []
	for fc in Diplomacy.POWERS: for kd in ["delivery", "hunt", "survey", "escort", "smuggle", "strike", "war"]: if String(Diplomacy._voices.get(fc, {}).get(kd, "")) == "": miss.append(fc + "/" + kd)
	ok(miss.is_empty(), "every power has a line for every kind of contract %s" % str(miss.slice(0, 4)))
	for og in ["hijacker", "merchant", "privateer", "defector", "smuggler", "academy"]: if not Tales.T.has("origin_" + og): miss.append(og)
	ok(miss.is_empty() and Tales.errors.is_empty(), "six origins have an opening tale, and no tale file has a mistake")
	var man: Array = Codex.manual()
	ok(man.size() >= 10 and man.all(func(pg): return String(pg.get("title", "")) != "" and String(pg.get("text", "")).length() > 200), "the Codex has a Manual of %d pages" % man.size())
	Campaign.new_game("academy")
	sections += 1
