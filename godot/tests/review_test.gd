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
	_battle(); _campaign(); _world(); _chart(); _sounds()
	ok(sections == 5, "every section ran to its end (%d of 5)" % sections)
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
	# the cap of ten counts every ship you own
	G.fleet = []; for i in 6: G.fleet.append(Campaign.new_ship("dd", "D%d" % i, "player", []))
	Campaign.detach(G.fleet.slice(0, 3)); G.fleet.append_array([Campaign.new_ship("dd", "X", "player", []), Campaign.new_ship("dd", "Y", "player", []), Campaign.new_ship("dd", "Z", "player", []), Campaign.new_ship("dd", "W", "player", [])])
	var wreck: Dictionary = {}
	for q in G.pois: if q.type == "wreck": wreck = q; break
	var most := 0
	for i in 60: wreck.next = 0; Campaign.do_survey(wreck); most = maxi(most, Campaign.all_ships().size())
	for f in G.fleets.duplicate(): if f.kind == "raiders" and not f.has("home"): G.fleets.erase(f)
	ok(most <= 10, "a hulk found on a survey does not take you past ten ships with a division detached (%d)" % most)
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
