extends Node
## Headless check of squadron orders, reserve, divisions and readiness: line ahead keeps a column, hold fire silences
## all but the flagship, ships in reserve take no part in a battle, a fast division parts company and the main body
## follows and rejoins, readiness wears with steaming and battle and comes back with rest, and the screens open.
## godot --headless --path godot res://tests/orders_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _ready() -> void:
	seed(6); Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	# ---- line ahead
	var sim := BattleSim.new()
	sim.setup([Campaign.new_ship("ca_baltimore", "A", "player", []), Campaign.new_ship("dd_fletcher", "B", "player", []), Campaign.new_ship("dd_fletcher", "C", "player", [])], [Campaign.new_ship("dd_narvik", "X", "raiders", [])], [], [], 0)
	sim.ships[3].pos = sim.ships[0].pos + Vector2(9000, 9000); sim.ships[3].eng_out = 1e9; sim.escape_r = 1e9   # a hulk far off, so the action does not end
	sim.order = "line"; sim.flag.throttle = 3
	for i in 9000:
		sim.player_rudder = 0.25 if (i > 3000 and i < 4500) else 0.0
		sim.step(0.05)
	var f = sim.flag; var b = sim.ships[1]; var c = sim.ships[2]
	var astern := func(lead, s) -> float: return (lead.pos - s.pos).dot(Vector2.from_angle(lead.a))
	print("line ahead: B %.0f m astern of A (off line %.0f), C %.0f m astern of B; headings %.2f %.2f %.2f" % [astern.call(f, b), absf((b.pos - f.pos).cross(Vector2.from_angle(f.a))), astern.call(b, c), f.a, b.a, c.a])
	ok(astern.call(f, b) > 250.0 and astern.call(f, b) < 1100.0 and astern.call(b, c) > 150.0 and astern.call(b, c) < 1100.0, "the column keeps its order and distance through a turn")
	ok(absf(BattleSim.ang_diff(b.a, f.a)) < 0.35 and absf(BattleSim.ang_diff(c.a, f.a)) < 0.45, "and steers the flagship's course")
	# ---- hold fire
	var s2 := BattleSim.new()
	s2.setup([Campaign.new_ship("dd_fletcher", "A", "player", []), Campaign.new_ship("dd_fletcher", "B", "player", [])], [Campaign.new_ship("fr_liberty", "X", "raiders", [])], [], [], 0)
	s2.ships[2].pos = s2.ships[1].pos + Vector2(0, -1500); s2.hold_fire = true
	for i in 1200: s2.step(0.05)
	var fired := func(sh) -> int:
		var n := 0
		for m in sh.mounts: if m.w.kind == "gun" and m.ammo_max > 0: n += m.ammo_max - m.ammo
		return n
	ok(fired.call(s2.ships[1]) == 0, "holding fire, the consort fires nothing in a minute at 1,500 m")
	s2.hold_fire = false
	for i in 1200: s2.step(0.05)
	ok(fired.call(s2.ships[1]) > 0, "released, she opens fire (%d rounds)" % fired.call(s2.ships[1]))
	# ---- reserve
	G.fleet = [Campaign.new_ship("ca_baltimore", "Flag", "player", []), Campaign.new_ship("ao_cimarron", "Oiler", "player", []), Campaign.new_ship("dd_fletcher", "Escort", "player", [])]
	G.crew = Campaign.crew_need(); G.fleet[1].reserve = true
	var foe: Dictionary = Campaign.spawn_fleet("raiders", "raiders")
	var cfg: Dictionary = Campaign.battle_setup(foe)
	ok(cfg.player_recs.size() == 2 and not cfg.player_recs.has(G.fleet[1]), "the oiler in reserve is not in the battle")
	for x in G.fleet: x.reserve = true
	ok(Campaign.battle_setup(foe).player_recs.size() == 3, "with every ship in reserve, all fight")
	for x in G.fleet: x.reserve = false
	# ---- divisions
	var slow_kn: float = Campaign.fleet_map_speed(G.fleet)
	ok(Campaign.detach([]) != "" and Campaign.body() == null, "nothing marked, nothing detached")
	var cap0: int = Campaign.cargo_cap(); var need0: int = Campaign.crew_need()
	print(Campaign.detach([G.fleet[0], G.fleet[2]]))
	var body = Campaign.body()
	ok(body != null and body.ships.size() == 1 and G.fleet.size() == 2 and Campaign.fleet_map_speed(G.fleet) > slow_kn, "the fast division is faster (%.1f against %.1f)" % [Campaign.fleet_map_speed(G.fleet), slow_kn])
	ok(Campaign.cargo_cap() == cap0 and Campaign.crew_need() == need0 and Campaign.all_ships().size() == 3, "holds, bunkers and crews are still counted together")
	var P: Dictionary = G.player; var w := Campaign.water_point(8, Vector2(P.x, P.y), 30); P.x = w.x; P.y = w.y; body.x = w.x; body.y = w.y
	var dest := Campaign.water_point(8, Vector2(P.x, P.y), 260)
	Campaign.set_course(P, dest.x, dest.y); G.cargo.fuel = 500.0
	Campaign.encounter.connect(func(fl): Campaign.paused = false; fl.cool = 30.0; P.cool = 30.0)
	for fl in G.fleets: if fl != body: fl.cool = 9999.0
	var far := 0.0
	for i in 30 * 40:
		Campaign.paused = false; Campaign.update(1.0 / 30.0); far = maxf(far, Campaign.mdist(P.x, P.y, body.x, body.y))
	ok(far > 3.0 and G.fleets.has(body), "the fast division draws ahead (%.1f units) and the main body follows" % far)
	body.join = true; P.route = null; P.tx = null
	for i in 30 * 300:
		Campaign.paused = false; Campaign.update(1.0 / 30.0)
		if Campaign.body() == null: break
	ok(Campaign.body() == null and G.fleet.size() == 3, "signalled, it comes up and rejoins")
	# ---- readiness
	for x in G.fleet: x.rdy = 1.0
	G.cargo.fuel = 5000.0; G.cargo.food = 500.0; G.credits = 500000
	P.spd = "flank"; for i in 20: Campaign._readiness_day(true)
	var worn := Campaign.fleet_readiness()
	P.spd = "slow"; for i in 20: Campaign._readiness_day(true)
	ok(worn < 0.8 and is_equal_approx(Campaign.fleet_readiness(), worn), "twenty days at flank speed wear the crews to %d%%; at Slow nothing more" % int(worn * 100))
	for i in 5: Campaign._readiness_day(false)
	ok(Campaign.fleet_readiness() > worn, "hove to, they recover slowly (%d%%)" % int(Campaign.fleet_readiness() * 100))
	var d0: int = G.day; var nd := Campaign.days_to_rest(); Campaign.rest_in_port(nd)
	ok(Campaign.fleet_readiness() >= 0.999 and int(G.day) == d0 + nd, "%d days alongside restore them, and the calendar moves" % nd)
	# a battle costs readiness
	var bs := BattleSim.new(); bs.setup(Campaign.battle_setup(foe).player_recs, foe.ships, [], [], 0)
	for sh in bs.ships: if sh.side == 1: sh.alive = false
	bs.result = {"victory": true, "sunk": [], "lost": [], "struck": [], "escaped": [], "time": 10.0}
	GameData.pending = {"fleet_id": foe.id}; Campaign.apply_battle(bs)
	ok(Campaign.readiness(G.fleet[0]) < 0.95, "a battle costs readiness (%d%%)" % int(Campaign.readiness(G.fleet[0]) * 100))
	# ---- the screens
	var map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	G.fleet[0].fast = true; map._cmd_tab("fleet"); map.close_panel()
	var port: Dictionary = G.ports[0]; map.cur_port = port; map.port_tab = "fleet"; map._render_port(); map.close_panel()
	var f2: Dictionary = Campaign.spawn_fleet("raiders", "raiders"); map._on_encounter(f2); map._toggle_commit(G.fleet[1], f2); map.close_panel()
	ok(G.fleet[1].get("reserve", false), "the panels open; a click on the contact panel puts a ship in reserve")
	Campaign.detach([G.fleet[0]]); map._cmd_tab("fleet"); map.close_panel()
	Campaign.save(); ok(Campaign.load_game() and Campaign.body() != null and Campaign.readiness(Campaign.G.fleet[0]) < 1.0, "divisions and readiness survive a save")
	print("ORDERS TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
