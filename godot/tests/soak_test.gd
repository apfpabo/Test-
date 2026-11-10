extends Node
## A long unattended campaign, headless: godot --headless --path godot res://tests/soak_test.tscn -- [days] [origin] [navy] [seed]
## (defaults: 400 days, merchant, concord, seed 11). The real weather and calendar run (no Weather.force). A scripted
## captain sails from open port to open port, repairs, rearms, rests, signs contracts and story orders, saves and
## loads; every hostile contact is fought out by the battle simulation as the battle scene sets it up (weather, night,
## range, crew, readiness); on set days he is reinforced to a big squadron, founds a flag, storms a port, raises a
## guard, builds works, detaches a fast division, runs dark, runs out of fuel and is towed, strikes and bombards and
## lands on a structure, and fires a nuclear weapon. Every day the state is checked for nonsense (positions on land,
## negative stores, hull or readiness out of range, runaway fleet counts); at the end the save must load back the same.
## A lost squadron starts a new campaign so the run always covers its days. Script errors show in the log as
## "SCRIPT ERROR"; the run prints SOAK TEST PASSED or FAILED.
var fails := 0
var st := {"days": 0, "campaigns": 1, "contacts": 0, "battles": 0, "night": 0, "night_unfinished": 0, "unfinished": 0, "won": 0, "lost_ships": 0, "sunk": 0, "prizes": 0,
	"docks": 0, "closed": 0, "loads": 0, "no_route": 0, "toasts": 0, "max_fleets": 0, "tows": 0, "contracts": 0, "storms": 0, "ticks": 0, "tick_ms": 0.0, "battle_ms": 0.0, "aground_days": 0}
var did := {}
var verbose := false
var origin := "merchant"
var navy := "concord"
var day0 := 0                     # days of earlier campaigns in this run
var last_day := -1
var help_day := -1
var adrift := 0

func ok(c: bool, what: String) -> void:
	if not c: print("FAIL day %d: %s" % [int(Campaign.G.get("day", 0)), what]); fails += 1

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var days: int = int(a[0]) if a.size() > 0 else 400
	if a.size() > 1: origin = a[1]
	if a.size() > 2: navy = a[2]
	seed(int(a[3]) if a.size() > 3 else 11)
	verbose = a.size() > 4
	Weather.force = null
	Campaign.toast.connect(func(t: String): st.toasts += 1; if verbose: print("  [%d] %s" % [int(Campaign.G.day), t]))
	Campaign.encounter.connect(_met)
	Campaign.reached_port.connect(_dock)
	Campaign.reached_site.connect(func(q: Dictionary): Campaign.do_survey(q))
	_begin()
	var t0 := Time.get_ticks_msec()
	while day0 + int(Campaign.G.day) < days:
		var G: Dictionary = Campaign.G; var P: Dictionary = G.player
		if G.fleet.is_empty():
			if Campaign.body() != null: Campaign.rejoin()   # the flag division is gone: the main body is the squadron now
			if G.fleet.is_empty(): day0 += int(G.day); st.campaigns += 1; _begin(); continue
		if int(G.day) != last_day: last_day = int(G.day); _daily()
		G = Campaign.G; P = G.player
		if Campaign.paused: Campaign.paused = false
		if Campaign.dead_in_water() and P.get("towed") == null:   # adrift: call for help once a day, and after ten days a passing oiler obliges
			if int(G.day) != help_day: help_day = int(G.day); adrift += 1; Campaign.distress()
			if adrift > 10: G.cargo.fuel = float(Campaign.bunker_cap()) * 0.5; G.crew = maxi(int(G.crew), Campaign.crew_need()); adrift = 0
		elif P.get("route") == null and P.get("follow") == null and P.get("towed") == null: adrift = 0; _pick_course()
		var t1 := Time.get_ticks_usec()
		Campaign.update(0.05)
		st.tick_ms += (Time.get_ticks_usec() - t1) / 1000.0; st.ticks += 1
	st.days = days
	_final()
	print("soak: %s" % str(st))
	print("soak: %.0f s; chart tick %.2f ms average; %d battles took %.0f s" % [(Time.get_ticks_msec() - t0) / 1000.0, st.tick_ms / maxf(1.0, st.ticks), st.battles, st.battle_ms / 1000.0])
	print("SOAK TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)

func _begin() -> void:
	Campaign.new_game(origin, navy); Campaign.paused = false; last_day = -1
	if st.campaigns > 1: did = {"again": true}   # the scripted events are for the first campaign; later ones just sail and fight

func _pick_course() -> void:
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	if G.fleet.size() >= 3 and randf() < 0.4:   # a squadron goes looking for trouble: the nearest raider or enemy in sight
		var prey = null
		for f in G.fleets:
			if not f.get("vis", true) or not Campaign.hostile_fleet(f) or Campaign.mdist(f.x, f.y, P.x, P.y) > 500.0: continue
			if prey == null or Campaign.mdist(f.x, f.y, P.x, P.y) < Campaign.mdist(prey.x, prey.y, P.x, P.y): prey = f
		if prey != null: P.follow = int(prey.id); P.repathT = 0.0; P.destPort = null; return
	var open: Array = G.ports.filter(func(p): return not Campaign.hostile(p.fac) and Campaign.mdist(p.sx, p.sy, P.x, P.y) > 20.0)
	if open.is_empty(): open = G.ports.filter(func(p): return Campaign.mdist(p.sx, p.sy, P.x, P.y) > 20.0)
	open.sort_custom(func(x, y): return Campaign.mdist(x.sx, x.sy, P.x, P.y) < Campaign.mdist(y.sx, y.sy, P.x, P.y))
	var p: Dictionary = open[randi() % mini(6, open.size())]   # one of the nearer harbours, so the year is spent in several seas
	if Campaign.set_course(P, p.sx, p.sy):
		P.destPort = int(p.id)
		if verbose: print("  [%d] course for %s, %d km, %d kn on the chart" % [int(G.day), p.name, int(Campaign.route_remaining(P) * Campaign.KM_PER_UNIT), int(Campaign.player_speed() / 0.576 * 0.7)])
	else:
		st.no_route += 1
		ok(Campaign.on_land(P.x, P.y), "no sea route from open water at %.0f,%.0f to %s" % [P.x, P.y, p.name])
		var w := Campaign.nearest_water(P.x, P.y, 60); P.x = w.x; P.y = w.y

# ------------------------------------------------------------------ contacts and battles
func _met(f: Dictionary) -> void:
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	st.contacts += 1
	if Campaign.hostile_fleet(f): _fight(f)
	elif Campaign.dead_in_water() and f.get("answering", false):
		var msg := Campaign.take_tow(f); st.tows += 1
		ok(P.get("towed") != null or msg.begins_with("No sea route") or msg.begins_with("There is no harbour"), "a tow is taken: " + msg)
	else: f.cool = 30.0; f.answering = false
	if not Campaign.G.is_empty(): Campaign.G.player.cool = maxf(float(Campaign.G.player.cool), 5.0)
	Campaign.paused = false

func _fight(f: Dictionary) -> void:
	var G: Dictionary = Campaign.G
	var cfg: Dictionary = Campaign.battle_setup(f); GameData.pending = cfg
	var sim := BattleSim.new(); sim.modern = st.battles % 2 == 0
	sim.wx = cfg.get("weather", Weather.CLEAR)
	sim.sep = clampf(float(cfg.get("range_km", 90)) * 100.0, 9000.0, 18000.0)
	sim.setup(cfg.player_recs, cfg.enemy_recs, cfg.player_tech, cfg.enemy_tech, cfg.get("islands", 1))
	for sh in sim.ships:   # as battle.gd sets a campaign action up
		if sh.side == 0:
			sh.cf = cfg.get("crew_frac", 1.0) * (0.7 + 0.3 * Campaign.readiness(sh.rec))
			if cfg.get("no_fuel", false): sh.fuel_k = 0.25
			for o in cfg.get("officers", []): if o.ship == sh.rec.id: sh.sk = o.sk
		else: sh.sk = {"gun": mini(2, int(G.day / 80)), "helm": 0, "dc": 0, "ord": 0}
	sim.flag = null
	if st.battles % 3 == 1: sim.order = "line"
	if st.battles % 5 == 2: sim.hold_fire = true
	var t0 := Time.get_ticks_msec(); var night: bool = sim.wx.night
	while not sim.finished and sim.t < 7200.0: sim.step(0.02)
	st.battle_ms += Time.get_ticks_msec() - t0
	st.battles += 1
	if night: st.night += 1
	if not sim.finished:
		st.unfinished += 1
		if night: st.night_unfinished += 1
	for s in sim.ships:
		ok(not (is_nan(s.pos.x) or is_nan(s.pos.y) or is_nan(s.hull)), "battle: %s has a position and a hull that are numbers" % s.rec.name)
		for m in s.mounts: ok(int(m.ammo) >= 0, "battle: no mount of %s has fired more rounds than it had" % s.rec.name)
	var before: int = G.fleet.size()
	var r: Dictionary = Campaign.apply_battle(sim)
	if verbose: print("  [%d] battle with %s (%s%s): %s in %.0f s of battle, sunk %d, lost %d" % [int(G.day), f.name, sim.wx.text, "" if sim.finished else ", UNFINISHED", "victory" if r.victory else ("disengaged" if r.retreated else "defeat"), sim.t, r.sunk.size(), r.lost.size()])
	if r.victory: st.won += 1
	st.sunk += r.sunk.size(); st.lost_ships += r.lost.size()
	ok(G.fleet.size() == before - r.lost.size(), "after a battle the squadron is the ships that were not lost")
	for s in r.prizes:   # take prizes into the squadron while there is room, as the aftermath screen offers
		if G.fleet.size() < 10: s.pal = "player"; G.fleet.append(s); Campaign.study_prize(s); st.prizes += 1
	if not sim.finished: f.cool = 30.0

# ------------------------------------------------------------------ in port
func _dock(p: Dictionary) -> void:
	var G: Dictionary = Campaign.G
	st.docks += 1
	if verbose: print("  [%d] in harbour at %s (%s)" % [int(G.day), p.name, p.fac])
	if Campaign.hostile(p.fac): st.closed += 1; return
	Diplomacy.on_dock(p)
	G.credits = maxf(float(G.credits), 250000.0)   # the purser is never short: this run is about rules, not the economy
	for s in G.fleet:
		G.credits -= Campaign.repair_cost(s) + Campaign.rearm_cost(s); s.hullFrac = 1.0; s.ammo = 1.0
	Structures.replace_planes()
	G.crew = maxi(int(G.crew), Campaign.crew_need())
	G.cargo.fuel = float(G.cargo.fuel) + Campaign.fuel_room(); G.cargo.food = maxf(float(G.cargo.food), Campaign.food_use() * 40.0)
	if Structures.troop_capacity() > Structures.troops(): Structures.embark(Structures.troop_capacity() - Structures.troops())
	for c in Diplomacy.offers(p):
		if G.contracts.size() < 3 and Diplomacy.can_accept(c) == "": Diplomacy.accept(c); st.contracts += 1
	if p.capital and G.get("commission") == null and not Flag.founded() and Diplomacy.can_commission(p.fac) == "": Diplomacy.take_commission(p.fac)
	if p.capital and G.mission == null and Campaign.story_idx(p.fac) < Campaign.story_chain(p.fac).size() and int(G.rep.get(p.fac, 0)) >= 0: Campaign.accept_mission(p.fac)
	if Campaign.fleet_readiness() < 0.75: Campaign.rest_in_port(Campaign.days_to_rest())
	if st.docks % 3 == 0: _save_load()

func _save_load() -> void:
	Campaign.save()
	var before: Dictionary = Campaign.G.duplicate(true); Campaign._strip_routes(before.player)
	for f in before.fleets: Campaign._strip_routes(f)
	ok(Campaign.load_game(), "the save loads")
	var after: Dictionary = Campaign.G.duplicate(true); Campaign._strip_routes(after.player)
	for f in after.fleets: Campaign._strip_routes(f)
	var diff := _diff(before, after, "G")
	ok(diff == "", "the game is the same after a save and a load: " + diff)
	st.loads += 1

## The first difference between two saved values, numbers compared by value (JSON makes every number a float).
func _diff(a, b, path: String) -> String:
	if (a is int or a is float) and (b is int or b is float): return "" if is_equal_approx(float(a), float(b)) or absf(float(a) - float(b)) < 1e-6 * maxf(1.0, absf(float(a))) else "%s %s != %s" % [path, a, b]
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k):
				if a[k] == null: continue
				return "%s.%s is lost" % [path, k]
			var d := _diff(a[k], b[k], "%s.%s" % [path, k])
			if d != "": return d
		for k in b: if not a.has(k): return "%s.%s appears" % [path, k]
		return ""
	if a is Array and b is Array:
		if a.size() != b.size(): return "%s has %d entries, then %d" % [path, a.size(), b.size()]
		for i in a.size():
			var d := _diff(a[i], b[i], "%s[%d]" % [path, i])
			if d != "": return d
		return ""
	if a is Vector2 and b is Array: return ""
	return "" if typeof(a) == typeof(b) and a == b else "%s %s != %s" % [path, a, b]

# ------------------------------------------------------------------ every day
func _daily() -> void:
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player; var day := int(G.day)
	st.max_fleets = maxi(st.max_fleets, G.fleets.size())
	ok(is_finite(P.x) and is_finite(P.y) and is_finite(P.h) and is_finite(P.v), "the squadron's position, heading and speed are numbers")
	if Campaign.on_land(P.x, P.y): st.aground_days += 1
	ok(is_finite(float(G.credits)) and float(G.credits) >= 0.0, "money is a number and not negative (%s)" % G.credits)
	ok(int(G.crew) >= 0, "crew is not negative (%s)" % G.crew)
	ok(Structures.troops() >= 0 and Structures.troops() <= Structures.troop_capacity(), "troops fit their transports (%d of %d)" % [Structures.troops(), Structures.troop_capacity()])
	for g in G.cargo: ok(is_finite(float(G.cargo[g])) and float(G.cargo[g]) >= -0.001, "%s in the hold is not negative (%s)" % [g, G.cargo[g]])
	ok(float(G.get("reserve", 0.0)) >= 0.0, "the fuel reserve is not negative")
	for s in Campaign.all_ships():
		ok(float(s.hullFrac) >= 0.049 and float(s.hullFrac) <= 1.0001, "%s: hull %s in range" % [s.name, s.hullFrac])
		ok(Campaign.readiness(s) >= Campaign.RDY_MIN - 0.001 and Campaign.readiness(s) <= 1.0001, "%s: readiness in range" % s.name)
		ok(float(s.get("ammo", 1.0)) >= 0.0 and float(s.get("ammo", 1.0)) <= 1.0001, "%s: ammunition in range" % s.name)
		ok(GameData.hulls.has(s.type), "%s is of a known design" % s.name)
	ok(Campaign.all_ships().size() <= 10, "no more than ten ships in all (%d)" % Campaign.all_ships().size())
	ok(G.fleets.size() < 220, "the world's fleets do not pile up (%d)" % G.fleets.size())
	ok(G.log.size() <= 40 and G.get("news", []).size() <= 80, "the log and the news stay bounded (%d, %d)" % [G.log.size(), G.get("news", []).size()])
	ok(G.contracts.size() <= 3, "at most three contracts")
	var ids := {}
	for f in G.fleets:
		ok(not f.ships.is_empty() or f.get("body", false), "%s (%s) has ships" % [f.name, f.kind])
		ok(is_finite(f.x) and is_finite(f.y) and f.x >= 0.0 and f.x <= Campaign.MW, "%s has a position on the chart" % f.name)
		ok(f.fac == "raiders" or GameData.fac.has(f.fac), "%s flies a known flag (%s)" % [f.name, f.fac])
		ok(not ids.has(int(f.id)), "fleet ids are unique (%d)" % int(f.id)); ids[int(f.id)] = true
		if f.has("dest"): ok(int(f.dest) >= 0 and int(f.dest) < G.ports.size(), "%s is bound for a real port" % f.name)
		if f.has("guardOf"): ok(G.ports[int(f.guardOf)].fac == "player", "%s guards a port that is still yours" % f.name)
	for p in G.ports: ok(p.fac == "player" or Diplomacy.POWERS.has(p.fac), "%s is held by a power (%s)" % [p.name, p.fac])
	ok(Structures.all().size() == 384, "384 structures (%d)" % Structures.all().size())
	for s in Structures.all():
		ok(float(s.dmg) >= 0.0 and float(s.dmg) <= 1.0 and float(s.get("ruin", 0.0)) >= 0.0 and float(s.get("ruin", 0.0)) <= 1.0 and int(s.garrison) >= 0, "%s: damage, ruin and garrison in range" % s.name)
		ok(s.fac == "" or s.fac == "player" or Diplomacy.POWERS.has(s.fac), "%s has a known owner (%s)" % [s.name, s.fac])
	for a in Diplomacy.POWERS: for b in Diplomacy.POWERS: if a < b: ok(absf(Diplomacy.rel(a, b)) <= 100.001, "relations of %s and %s in range" % [a, b])
	for f in G.rep: ok(absf(float(G.rep[f])) <= 100.0, "standing with %s within -100..100 (%s)" % [f, G.rep[f]])
	# the chart's own questions, asked every day wherever the squadron is
	Campaign.weather_here(); Campaign.signature(); Campaign.tow_fee(); Campaign.nearest_caller(true); Campaign.nearest_caller(false); Campaign.distress_ship()
	Campaign.salvage_mult(); Campaign.bunker_cap(); Campaign.wages(); Diplomacy.marks()
	# a supply ship meets her when stores run low: this run is about the rules, not about starving (a scripted captain
	# who never shops would lose his crew to hunger and drift for the rest of the year)
	if float(G.cargo.food) < Campaign.food_use() * 15.0: G.cargo.food = Campaign.food_use() * 45.0
	if int(G.crew) < Campaign.crew_need() / 2: G.crew = Campaign.crew_need()
	G.credits = maxf(float(G.credits), 100000.0)
	if not did.has("again"): _events(day)

func _add(types: Array) -> void:
	var G: Dictionary = Campaign.G
	for t in types:
		if Campaign.all_ships().size() >= 10: break
		G.fleet.append(Campaign.new_ship(t, null, "player", G.tech))
	G.crew = maxi(int(G.crew), Campaign.crew_need())
	G.cargo.fuel = float(G.cargo.fuel) + Campaign.fuel_room(); G.cargo.food = maxf(float(G.cargo.food), Campaign.food_use() * 60.0)   # they come stored for sea

func _once(k: String, day: int, at: int) -> bool:
	if day < at or did.has(k): return false
	did[k] = true; return true

func _events(day: int) -> void:
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	if _once("reinforce1", day, 12): _add(["cl", "dd", "dd", "ao_cimarron", "ae_hood"]); G.credits = maxf(float(G.credits), 250000.0)
	if _once("flag", day, 40):
		var base: Dictionary = {}
		for s in Structures.all(): if s.kind == "navalbase" and s.fac == "": base = s; break
		if base.is_empty(): for s in Structures.all(): if s.kind == "navalbase": base = s; break
		base.fac = "player"; base.from = ""; base.took = G.day; base.garrison = Structures.garrison_need(base)
		G.credits = 900000.0
		ok(Flag.can_found() == "", "a flag can be founded: " + Flag.can_found()); Flag.found("Soak Company")
		for t in ["amphib", "radar"]: if not G.tech.has(t): G.tech.append(t)
		_add(["ap_haskell", "ap_haskell"]); G.troops = Structures.troop_capacity()
	if _once("storm", day, 46) and Flag.founded():
		var port: Dictionary = {}
		for p in G.ports: if p.fac != "player" and not p.capital and (port.is_empty() or Campaign.mdist(p.sx, p.sy, P.x, P.y) < Campaign.mdist(port.sx, port.sy, P.x, P.y)): port = p
		P.x = port.sx; P.y = port.sy; P.route = null; P.destPort = null
		for i in 8:
			G.troops = Structures.troop_capacity()
			if Flag.can_assault(port) != "": break
			var r: Dictionary = Flag.assault(port); st.storms += 1
			if r.won: break
		if port.fac == "player":
			G.credits = 900000.0
			Flag.raise_guard(port); print(Flag.build(port, "battery")); Flag.build(port, "customs"); Flag.build(port, "barracks")
			did["port"] = int(port.id)
	if _once("detach", day, 70) and G.fleet.size() >= 3:
		var by: Array = G.fleet.duplicate(); by.sort_custom(func(a, b): return float(Campaign.hull(a).kn) > float(Campaign.hull(b).kn))
		print(Campaign.detach(by.slice(0, by.size() / 2)))
	if _once("rejoin", day, 80) and Campaign.body() != null: Campaign.body().join = true
	if _once("rejoined", day, 95): ok(Campaign.body() == null, "the main body has rejoined fifteen days after the signal")
	if _once("dark", day, 100): Campaign.set_dark(true)
	if _once("light", day, 112): Campaign.set_dark(false)
	if _once("reinforce2", day, 115): _add(["bb", "cv_essex", "cve", "ca", "ar_vulcan", "ar_diver"])
	if _once("dry", day, 125):   # bunkers and reserve run dry far from anywhere: a distress call, and a tow
		G.cargo.fuel = 0.0; G.reserve = 0.0
		ok(Campaign.dead_in_water() or P.get("towed") != null or Campaign.fuel_use() <= 0.0, "with no fuel and no reserve the squadron is dead in the water")
		print("[%d] %s" % [day, Campaign.distress()])
	if _once("refuel", day, 150) and Campaign.dead_in_water(): G.cargo.fuel = float(Campaign.bunker_cap())   # nobody came: a passing oiler
	if _once("strike", day, 160):
		var tgt: Dictionary = {}
		for s in Structures.all():
			if s.fac == "" or s.fac == "player" or s.get("nuked", false) or s.kind != "battery": continue
			if tgt.is_empty() or Campaign.mdist(s.x, s.y, P.x, P.y) < Campaign.mdist(tgt.x, tgt.y, P.x, P.y): tgt = s
		var c := Structures.coast_point(tgt); P.x = c.x; P.y = c.y; P.route = null; P.destPort = null
		print("[%d] strike on the %s: %s / bombard: %s / land: %s" % [day, tgt.name, Structures.can_strike(tgt), Structures.can_bombard(tgt), Structures.can_invade(tgt)])
		if Structures.can_strike(tgt) == "": Structures.strike(tgt)
		if Structures.can_bombard(tgt) == "": Structures.bombard(tgt)
		G.troops = Structures.troop_capacity()
		if Structures.can_invade(tgt) == "": Structures.invade(tgt)
	if _once("nuke", day, 200):
		for t in ["nuclear", "missiles", "nukes"]: if not G.tech.has(t): G.tech.append(t)
		if Campaign.all_ships().size() >= 10: G.fleet.pop_back()
		G.fleet.append(Campaign.new_ship("ssn_charlie", null, "player", G.tech)); G.crew = maxi(int(G.crew), Campaign.crew_need()); G.credits = 900000.0
		ok(Structures.can_arm("player") == "", "a missile boat can take a warhead: " + Structures.can_arm("player"))
		if Structures.can_arm("player") == "": Structures.arm()
		var tgt: Dictionary = {}
		for s in Structures.all():
			if s.fac == "" or s.fac == "player" or s.get("nuked", false): continue
			if tgt.is_empty() or Campaign.mdist(s.x, s.y, P.x, P.y) < Campaign.mdist(tgt.x, tgt.y, P.x, P.y): tgt = s
		var c := Structures.coast_point(tgt); P.x = c.x; P.y = c.y; P.route = null; P.destPort = null
		if Structures.can_nuke(tgt) == "": print("[%d] the bomb on the %s: %s" % [day, tgt.name, str(Structures.nuke(tgt).notes)])
		else: print("[%d] no bomb: %s" % [day, Structures.can_nuke(tgt)])
	if _once("chancery", day, 230) and Flag.founded():
		G.credits = 900000.0
		for f in Diplomacy.POWERS:
			if Flag.can_peace(f) == "": print("[%d] %s" % [day, Flag.make_peace(f)])
			if Flag.can_recognise(f) == "": Flag.seek_recognition(f)
			if Flag.can_treaty(f) == "": Flag.sign_treaty(f)

func _final() -> void:
	var G: Dictionary = Campaign.G
	_save_load()
	var kinds := {}
	for f in G.fleets: kinds[f.kind] = int(kinds.get(f.kind, 0)) + 1
	print("soak: day %d of campaign %d; fleets by kind %s; ports of yours %d; structures of yours %d; wars %s; done %s" % [int(G.day), st.campaigns, str(kinds), Flag.ports().size(), Structures.held().size(), str(G.get("wars", {}).keys()), str(did.keys())])
	ok(st.aground_days == 0, "the squadron was never found on land at dawn (%d days)" % st.aground_days)
	ok(st.battles == 0 or st.unfinished * 4 <= st.battles, "fewer than a quarter of the battles ran two hours without a result (%d of %d; by night %d of %d)" % [st.unfinished, st.battles, st.night_unfinished, st.night])
