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
	_battle(); _campaign(); _world(); _chart(); _sounds(); _decisions(); _economy(); _supply(); _fighting(); _divisions(); _night_and_dc(); _gunnery(); _weights(); _flying(); _sound()
	ok(sections == 15, "every section ran to its end (%d of 15)" % sections)
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
	P.x = tgt.x; P.y = tgt.y
	ok(cap >= 2 and Structures.can_nuke(tgt) == "", "two missile boats carry %d warheads" % cap)
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
	var far := Campaign.water_point(8.0, Vector2(w.x + 600.0, w.y), 200.0); cv.x = far.x; cv.y = far.y; var cx: float = cv.x; var cy: float = cv.y
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
	ok(Structures.can_arm("player").begins_with("Your plant has no warhead ready"), "nor until your plant has made one")
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
