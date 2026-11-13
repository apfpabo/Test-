extends "res://tests/soak_test.gd"
## The tuning probe: soak_test's unattended captain with honest money, for the owner's tuning sheet
## (docs/TUNING_SHEET.md). No numbers in the game are changed. Unlike the soak, the purser is never topped up and no
## scripted events (reinforcements, a flag, the bomb) are run: the captain lives on what he earns. In port he sells
## his cargo, repairs and rearms if he can pay, hires crew to need, buys fuel to the bunkers' room and food for forty
## days, takes contracts, commissions and story orders as the soak does, and rests a tired squadron; before sailing he
## buys the good with the best margin at the port he is bound for. He takes prizes (as the aftermath offers) but buys
## no ships, so the day each class becomes affordable is read off his purse, not off a purchase.
## godot --headless --path godot res://tests/tune_probe.tscn -- <days> <origin> <navy> <seed> <out.json>
var WM = null
var rec := {"daily": [], "money": [], "contacts": [], "prices": [], "afford": {}, "start": {}}
var out_path := ""
var in_port = null          # the port he is lying in (from the dock to the next course)
var day_cash := 0.0
var cls_cache := {}
var hook := 0.0             # money the hooks below have accounted for during the current chart tick
var tried := false          # he tried to break off from this contact and failed
## Test-only knobs for trying the origins' hunters at other settings (the game's numbers are not changed): HUNT_SCALE
## (environment) rebuilds each hunter group at that multiple of the strength the game sized it to, and HUNT_MAX caps
## how many of one origin's hunter groups may be out at once. Unset, the probe plays the game as it is.
var hunt_scale := float(OS.get_environment("HUNT_SCALE")) if OS.get_environment("HUNT_SCALE") != "" else 1.0
var hunt_max := int(OS.get_environment("HUNT_MAX")) if OS.get_environment("HUNT_MAX") != "" else 0

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var days: int = int(a[0]) if a.size() > 0 else 180
	if a.size() > 1: origin = a[1]
	if a.size() > 2: navy = a[2]
	seed(int(a[3]) if a.size() > 3 else 11)
	out_path = a[4] if a.size() > 4 else "user://tune.json"
	Weather.force = null
	WM = load("res://scripts/world_map.gd").new()
	Campaign.encounter.connect(_met)
	Campaign.reached_port.connect(_dock)
	Campaign.reached_site.connect(func(q: Dictionary): Campaign.do_survey(q))
	Campaign.new_game(origin, navy); Campaign.paused = false; last_day = -1
	var G0: Dictionary = Campaign.G
	rec.start = {"origin": origin, "navy": navy, "credits": float(G0.credits), "ships": G0.fleet.map(func(s): return String(s.type)), "port": _near_port_name(), "seed": int(a[3]) if a.size() > 3 else 11}
	day_cash = float(G0.credits)
	while int(Campaign.G.day) < days:
		var G: Dictionary = Campaign.G; var P: Dictionary = G.player
		if G.fleet.is_empty():
			if Campaign.body() != null: Campaign.rejoin()
			if G.fleet.is_empty(): rec["lost_day"] = int(G.day); break   # the squadron is gone: the record ends there
		if int(G.day) != last_day: last_day = int(G.day); _daily()
		G = Campaign.G; P = G.player
		if Campaign.paused: Campaign.paused = false
		if Campaign.dead_in_water() and P.get("towed") == null:
			if int(G.day) != help_day: help_day = int(G.day); adrift += 1; Campaign.distress()
			if adrift > 10: _money("fuel bought from a passing oiler", -float(Campaign.bunker_cap()) * 0.5 * 12.0); G.cargo.fuel = float(Campaign.bunker_cap()) * 0.5; adrift = 0
		elif P.get("follow") != null and int(G.day) - chase_day > 4: P.follow = null; P.route = null
		elif P.get("route") == null and P.get("follow") == null and P.get("towed") == null: adrift = 0; _pick_course()
		# what the chart's own tick pays or charges beyond what the hooks saw: at a day's turn the wages and tenders
		# (counted apart) and a commission's monthly pay; otherwise contract rewards paid at sea or on arrival
		var c0 := float(G.credits); var d0 := int(G.day); var wage: float = Campaign.wages() + Campaign.supply_upkeep(); hook = 0.0
		Campaign.update(0.05)
		if Campaign.G.is_empty(): continue
		_retune_hunters()
		var dd: float = float(Campaign.G.credits) - c0 - hook
		if int(Campaign.G.day) != d0: dd += wage
		if absf(dd) >= 0.5: rec.money.append({"day": int(Campaign.G.day), "src": "commission pay" if int(Campaign.G.day) != d0 and dd > 0 else ("contracts paid at sea or on arrival" if dd > 0 else "charges at sea"), "amt": dd})
	rec["days"] = int(Campaign.G.day); rec["battles"] = st.battles; rec["won"] = st.won; rec["docks"] = st.docks
	var f := FileAccess.open(out_path, FileAccess.WRITE); f.store_string(JSON.stringify(rec)); f.close()
	print("tune probe: %s/%s seed %s: %d days, %d battles (%d won), %d docks, credits %.0f -> %s" % [origin, navy, rec.start.seed, rec.days, st.battles, st.won, st.docks, rec.start.credits, Campaign.fmt(int(Campaign.G.credits)) if not Campaign.G.is_empty() else "?"])
	WM.free()
	get_tree().quit(0)

func _retune_hunters() -> void:
	var G: Dictionary = Campaign.G
	for f in G.fleets.duplicate():
		if not f.get("hunter", false) or f.has("probe_tuned"): continue
		f.probe_tuned = true
		if hunt_max > 0 and G.fleets.filter(func(q): return q.get("hunter", false) and q.name == f.name).size() > hunt_max:
			G.fleets.erase(f); continue
		if hunt_scale != 1.0:
			var h: Dictionary = {}
			for q in Campaign.perk("hunted", []): if q.name == f.name: h = q
			var cap: float = float(h.get("budget", 50000)) * (1.0 + G.day / 200.0)
			var tl = Campaign.enemy_tech(Campaign.fac_era(f.fac)); var pool: Array = Campaign.C.PATROL_POOL.get(f.fac, Campaign.C.PATROL_POOL.raiders)
			var ships: Array = Campaign.build_to_strength(pool, clampf(hunt_scale * Campaign.hunt_k() * Campaign.own_strength(), minf(Campaign.HUNT_FLOOR, cap), cap), 4, f.fac, tl)
			if not ships.is_empty(): f.ships = ships
		if not rec.has("hunters"): rec["hunters"] = []
		rec.hunters.append({"day": int(G.day), "name": f.name, "ships": f.ships.size(), "tons": _tons(f.ships), "ratio": Campaign.strength(f.ships) / maxf(1.0, Campaign.own_strength())})

## A prudent captain takes a prize or raises a wreck only if the squadron stays four-fifths manned (the prize screen's
## warning, 13 Nov 2026); otherwise he scuttles her for a tenth of her worth.
func _will_crew(type: String) -> bool: return Campaign.manned_with(int(GameData.hulls[type].crew)) >= 0.8

func _near_port_name() -> String:
	var P: Dictionary = Campaign.G.player; var best = null
	for p in Campaign.G.ports: if best == null or Campaign.mdist(p.sx, p.sy, P.x, P.y) < Campaign.mdist(best.sx, best.sy, P.x, P.y): best = p
	return best.name if best != null else ""

func _money(src: String, amt: float) -> void:
	hook += amt
	if absf(amt) >= 0.5: rec.money.append({"day": int(Campaign.G.day), "src": src, "amt": amt})

func _tons(ships: Array) -> float:
	var t := 0.0
	for s in ships: t += float(GameData.hulls[s.type].t) if GameData.hulls.has(s.type) else 0.0
	return t

## The cheapest design of each class the captain could order with the research he holds (any yard; a ship buildable
## only at a capital is counted at its price): {klass: [price, design id]}.
func _cheapest() -> Dictionary:
	var key := ",".join(Campaign.G.tech)
	if cls_cache.has(key): return cls_cache[key]
	var out := {}
	for id in GameData.hulls:
		var h: Dictionary = GameData.hulls[id]
		if not Campaign.design_ok(id, Campaign.G.tech): continue
		var k: String = h.klass
		if not out.has(k) or float(h.price) < float(out[k][0]): out[k] = [float(h.price), id]
	cls_cache[key] = out
	return out

func _daily() -> void:
	var G: Dictionary = Campaign.G; var day := int(G.day)
	var cash := float(G.credits)
	rec.daily.append({"day": day, "credits": cash, "ships": G.fleet.size(), "tons": _tons(Campaign.all_ships()), "wages": Campaign.wages(), "upkeep": Campaign.supply_upkeep(), "crew": int(G.crew), "need": Campaign.crew_need(), "food": float(G.cargo.food), "fuel": float(G.cargo.fuel), "tech": G.tech.size()})
	day_cash = cash
	var ch := _cheapest()
	for k in ch:
		if rec.afford.has(k) and rec.afford[k].has("day"): continue
		if not rec.afford.has(k): rec.afford[k] = {"price": ch[k][0], "design": ch[k][1], "first_listed": day}
		rec.afford[k].price = ch[k][0]; rec.afford[k].design = ch[k][1]
		if cash >= float(ch[k][0]): rec.afford[k]["day"] = day

## A prudent captain, as a player would be: from a force that is not clearly weaker than his (the contact panel's
## strength ratio over 0.8: "an even fight" or worse) he tries to break off, at the panel's own odds; if that fails, or
## they are weaker, he fights. (The soak's captain fights every hostile contact, and a single ship started that way is
## lost in her first week.)
func _met(f: Dictionary) -> void:
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	if Campaign.hostile_fleet(f):
		var ratio: float = Campaign.strength(f.ships) / maxf(1.0, Campaign.own_strength())
		var evade: float = clampf(0.4 + (Campaign.fleet_map_speed(G.fleet) - Campaign.fleet_map_speed(f.ships)) / 40.0 + float(Campaign.perk("evade", 0)) / 100.0 + Campaign.trait_evade(), Campaign.EVADE_FLOOR, 0.92)
		tried = false
		if ratio > 0.8:
			var got: bool = randf() < evade
			tried = not got
			if got:
				var kinds := {}
				for x in f.ships: var k: String = GameData.hulls[x.type].klass if GameData.hulls.has(x.type) else "?"; kinds[k] = int(kinds.get(k, 0)) + 1
				rec.contacts.append({"day": int(G.day), "fac": String(f.get("fac", "")), "kind": String(f.get("kind", "")), "ships": f.ships.size(), "tons": _tons(f.ships), "classes": kinds, "my_tons": _tons(G.fleet), "my_ships": G.fleet.size(), "fought": false, "won": false, "sunk": 0, "lost": 0, "ratio": ratio, "broke_off": true})
				st.contacts += 1; f.cool = 7.0; P.cool = 4.0; P.route = null; P.follow = null; Campaign.paused = false
				return
	super(f)

## Outgunned and caught all the same, he orders the squadron to withdraw (as the battle screen's retreat order does).
func _orders(sim: BattleSim, f: Dictionary) -> void:
	if Campaign.strength(f.ships) / maxf(1.0, Campaign.own_strength()) > 1.0: sim.order = "retreat"; sim.hold_fire = false

func _fight(f: Dictionary) -> void:
	var G: Dictionary = Campaign.G; var c0 := float(G.credits); var mine := _tons(G.fleet)
	var kinds := {}
	for s in f.ships: var k: String = GameData.hulls[s.type].klass if GameData.hulls.has(s.type) else "?"; kinds[k] = int(kinds.get(k, 0)) + 1
	var ratio0: float = Campaign.strength(f.ships) / maxf(1.0, Campaign.own_strength())
	var n_e: int = f.ships.size(); var t_e := _tons(f.ships); var b0: int = st.battles; var w0: int = st.won; var s0: int = st.sunk; var l0: int = st.lost_ships
	super(f)
	if Campaign.G.is_empty(): return
	_money("battle: prizes, bounty, salvage", float(Campaign.G.credits) - c0)
	rec.contacts.append({"day": int(Campaign.G.day), "fac": String(f.get("fac", "")), "kind": String(f.get("kind", "")), "ships": n_e, "tons": t_e, "classes": kinds, "my_tons": mine, "my_ships": G.fleet.size(), "fought": st.battles > b0, "won": st.won > w0, "sunk": st.sunk - s0, "lost": st.lost_ships - l0, "ratio": ratio0, "broke_off": false, "tried": tried})
	tried = false

func _dock(p: Dictionary) -> void:
	var G: Dictionary = Campaign.G
	st.docks += 1
	in_port = null
	if Campaign.hostile(p.fac): st.closed += 1; return
	in_port = p
	var pr := {}
	for g in Campaign.C.GOODS: pr[g.id] = WM.port_price(p, g.id)
	rec.prices.append({"day": int(G.day), "port": p.name, "fac": p.fac, "p": pr})
	var c0 := float(G.credits); Diplomacy.on_dock(p); _money("contracts and orders paid in port", float(G.credits) - c0)
	# sell the cargo
	var got := 0.0
	for g in Campaign.C.GOODS:
		if g.id == "fuel" or g.id == "food": continue
		var held := int(floor(float(G.cargo[g.id])))
		for i in held: got += WM.sell_price(p, g.id); p.drift[g.id] = maxf(-0.5, p.drift[g.id] - 0.003)
		G.cargo[g.id] = float(G.cargo[g.id]) - held
	G.credits = float(G.credits) + got; _money("trade: sales", got)
	# repairs, then ammunition, while the purse allows (a ship at a time)
	for s in G.fleet:
		var rc: int = WM.repair_cost(s)
		if rc > 0 and float(G.credits) >= rc: G.credits -= rc; s.hullFrac = 1.0; _money("repairs", -rc)
	for s in G.fleet:
		var ac: int = Campaign.rearm_cost(s)
		if ac > 0 and float(G.credits) >= ac: G.credits -= ac; s.ammo = 1.0; _money("ammunition", -ac)
	var short := maxi(0, Campaign.crew_need() - int(G.crew))
	var hire := mini(short, int(float(G.credits) / 25.0))
	if hire > 0: G.credits -= hire * 25; G.crew += hire; _money("crew hired", -hire * 25)
	_buy_good(p, "fuel", Campaign.fuel_room(), "fuel")
	_buy_good(p, "food", maxi(0, int(Campaign.food_use() * 40.0 - float(G.cargo.food))), "food")
	# a prudent captain: fighting work (a hunt, a war contract, a strike, story orders) only with three ships or more
	var armed: bool = G.fleet.size() >= 3
	for c in Diplomacy.offers(p):
		if not armed and ["hunt", "war", "strike"].has(String(c.kind)): continue
		if G.contracts.size() < 3 and Diplomacy.can_accept(c) == "": Diplomacy.accept(c); st.contracts += 1; rec.money.append({"day": int(G.day), "src": "contract taken", "amt": 0.0, "kind": String(c.kind), "reward": float(c.get("reward", 0))})
	if p.capital and G.get("commission") == null and not Flag.founded() and Diplomacy.can_commission(p.fac) == "": Diplomacy.take_commission(p.fac)
	if armed and p.capital and G.mission == null and Campaign.story_idx(p.fac) < Campaign.story_chain(p.fac).size() and int(G.rep.get(p.fac, 0)) >= 0: Campaign.accept_mission(p.fac)
	if Campaign.fleet_readiness() < 0.75: Campaign.rest_in_port(Campaign.days_to_rest())

## Buy up to n tons at the port's climbing price (as the market screen does); returns what was spent.
func _buy_good(p: Dictionary, gid: String, n: int, src: String) -> float:
	var G: Dictionary = Campaign.G; var spent := 0.0
	var room: int = Campaign.fuel_room() if gid == "fuel" else (Campaign.cargo_cap() - Campaign.cargo_used() if gid != "food" else n)
	for i in mini(n, room):
		var bp: int = WM.buy_price(p, gid)
		if float(G.credits) < bp: break
		G.credits -= bp; G.cargo[gid] = float(G.cargo[gid]) + 1; p.drift[gid] = minf(0.6, p.drift[gid] + 0.003); spent += bp
	_money(src, -spent)
	return spent

func _pick_course() -> void:
	super()
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	if in_port == null or P.get("destPort") == null: in_port = null; return
	var p: Dictionary = in_port; in_port = null
	var q: Dictionary = G.ports[int(P.destPort)]
	if Campaign.hostile(q.fac): return
	var best := ""; var bm := 0.0
	for g in Campaign.C.GOODS:
		if g.id == "fuel" or g.id == "food": continue
		var bp: int = WM.buy_price(p, g.id); var m: float = float(WM.sell_price(q, g.id) - bp) / float(bp)
		if m > bm: bm = m; best = g.id
	if best == "" or bm < 0.06: return
	var keep: float = 20.0 * (Campaign.wages() + Campaign.supply_upkeep()) + 4000.0   # pay for three weeks in hand
	var room: int = Campaign.cargo_cap() - Campaign.cargo_used(); var spend: float = float(G.credits) - keep
	if room <= 0 or spend <= 0.0: return
	# as many tons as still pay: each ton bought here raises the price here, and each sold there lowers it there
	var n := 0; var d0: float = p.drift[best]; var d1: float = q.drift[best]; var cost := 0.0
	while n < room:
		var bp: int = WM.buy_price(p, best)
		if cost + bp > spend or float(WM.sell_price(q, best) - bp) < 0.06 * bp: break
		cost += bp; n += 1; p.drift[best] = minf(0.6, p.drift[best] + 0.003); q.drift[best] = maxf(-0.5, q.drift[best] - 0.003)
	p.drift[best] = d0; q.drift[best] = d1
	if _buy_good(p, best, n, "trade: purchases") > 0.0: rec.money[rec.money.size() - 1]["good"] = best; rec.money[rec.money.size() - 1]["margin"] = bm
