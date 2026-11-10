extends Node
## Headless check of your own flag: founding needs ground and money, a port is stormed with troops and flies your flag
## (market, yard, dues, garrison wages, the structures round it), a relief force sails and lands, and it all survives
## a save. godot --headless --path godot res://tests/flag_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _ready() -> void:
	seed(5)
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G
	ok(not Flag.founded() and Flag.can_found() != "", "no flag without ground: " + Flag.can_found())
	var base: Dictionary = {}
	for s in Structures.all(): if s.kind == "navalbase" and s.fac == "": base = s; break
	if base.is_empty():
		for s in Structures.all(): if s.kind == "navalbase": base = s; break
	base.fac = "player"; base.from = ""; base.took = G.day; base.garrison = Structures.garrison_need(base)
	G.credits = 1000
	ok(Flag.can_found().begins_with("Founding costs"), "and not without money")
	G.credits = 500000
	ok(Flag.can_found() == "", "a naval base and the money are enough")
	print(Flag.found("Meridian Company"))
	ok(Flag.founded() and GameData.fac.has("player") and GameData.fac.player.name == "Meridian Company" and int(G.credits) == 500000 - Flag.FOUND_COST, "founded; short name '%s'" % G.flag.short)
	# storm a small Directorate port
	var port: Dictionary = {}
	for p in G.ports: if p.fac == "directorate" and not p.capital and (port.is_empty() or float(p.get("garrison", 1)) < float(port.get("garrison", 1))): port = p
	G.tech = ["amphib"]
	G.fleet = [Campaign.new_ship("ca", "Flag", "player", []), Campaign.new_ship("ap_haskell", "T1", "player", []), Campaign.new_ship("ap_haskell", "T2", "player", [])]
	G.crew = Campaign.crew_need(); G.troops = 0
	ok(Flag.can_assault(port) != "", "no storming without troops: " + Flag.can_assault(port))
	G.troops = 3000
	ok(Flag.can_assault(port) != "", "nor from far off: " + Flag.can_assault(port))
	G.player.x = port.sx; G.player.y = port.sy
	ok(Flag.can_assault(port) == "", "off the harbour with troops: possible")
	var near := Structures.all().filter(func(s): return int(s.port) == int(port.id) and s.fac == "directorate").size()
	print("port ", port.name, " defenders ", int(Flag.port_defenders(port)), " odds ", Flag.assault_odds(port), " structures of its own ", near)
	var won := false; var tries := 0; var r := {}
	while not won and tries < 10:
		G.troops = 3000; r = Flag.assault(port); tries += 1; won = r.won
		print("assault %d: %d men, %d lost, won %s" % [tries, r.men, r.lost, str(r.won)])
	ok(won and port.fac == "player" and port.from == "directorate" and int(port.men) == Flag.hold_need(port), "%s flies your flag; garrison %d" % [port.name, int(port.men)])
	ok(Campaign.at_war("directorate"), "it was an act of war")
	ok(r.took.size() == near and Structures.held().size() == near + 1, "%d structures came with it" % near)
	ok(not Campaign.hostile("player") and Flag.tax(port) > 0, "the port is open to you; dues %d a month" % Flag.tax(port))
	var w0: float = Campaign.wages(); port.men = int(port.men) + 100
	ok(is_equal_approx(Campaign.wages() - w0, 15.0), "garrisons draw wages"); port.men = int(port.men) - 100
	# its yard builds the old owner's designs and what you have measured
	var map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	Campaign.study_prize(Campaign.new_ship("bb_yamato", "P", "player", []))
	var yard: Array = map.yard_of(port)
	ok(yard.has("bb_yamato") and yard.any(func(id): return GameData.hulls[id].yard == "ostsee" or GameData.hulls[id].yard == "neva"), "the yard builds %d designs, the old owner's and your prizes'" % yard.size())
	ok(map.ship_price(port, "dd_narvik") < GameData.hulls.dd_narvik.price, "at your own price")
	map.open_port(port); map.port_tab = "governor"; map._render_port(); map.port_tab = "yard"; map._render_port(); map.port_tab = "market"; map._render_port(); map.port_tab = "fleet"; map._render_port(); map.close_panel()
	map.show_command(); map.close_panel(); map.queue_free()
	# dues on the 30th
	var c0: int = G.credits; G.day = 29; Campaign.new_day(false)
	ok(int(G.credits) > c0, "dues and yields paid on the 30th (+%d after wages)" % (int(G.credits) - c0))
	# the relief force
	var f: Dictionary = Flag.launch(port, "directorate")
	ok(Flag.is_relief(f) and Campaign.hostile_fleet(f) and f.ships.any(func(s): return s.get("troops", false)), "a relief force of %d ships sails" % f.ships.size())
	var far := Campaign.nearest_water(Campaign.wrap_x(port.sx + 3000.0), port.sy, 400); G.player.x = far.x; G.player.y = far.y   # you are elsewhere: the garrison is on its own
	for i in 30 * 1500:
		Campaign.paused = false; Campaign.update(1.0 / 30.0)
		if not G.fleets.has(f): break
	ok(not G.fleets.has(f), "it reached the port: %s now flies the %s flag, garrison %d" % [port.name, port.fac, int(port.get("men", 0))])
	# held or lost, the books stay straight
	if port.fac == "player": ok(int(port.men) >= 1, "held")
	else: ok(Structures.held().size() == 1 and not port.has("from"), "lost with what stood round it")
	# a landing against a strong garrison is beaten off; against none it succeeds
	port.fac = "player"; port.from = "directorate"; port.men = 100000; port.took = G.day
	Flag.relief_lands(Flag.launch(port, "directorate")); ok(port.fac == "player", "a strong garrison holds")
	port.men = 0; var n := 0
	while port.fac == "player" and n < 40: Flag.relief_lands(Flag.launch(port, "directorate")); n += 1   # only its batteries stand between them and the quays
	ok(port.fac == "directorate", "an ungarrisoned port falls (landing %d)" % n)
	port.fac = "player"; port.from = "directorate"; port.men = 300; port.took = G.day
	# ---- the second part: works, a guard squadron, convoys, the chancery, volunteers
	G.credits = 900000; var port2: Dictionary = port
	ok(Flag.can_build(port2, "battery") == "", "works can be laid down")
	print(Flag.build(port2, "battery")); print(Flag.build(port2, "customs")); print(Flag.build(port2, "barracks")); print(Flag.build(port2, "yard"))
	ok(Flag.works(port2, "battery") == 0 and Flag.works_building(port2, "battery") == 30 and Flag.can_build(port2, "customs") != "", "they take time; one customs house only")
	var t0 := Flag.tax(port2); G.day = int(G.day) + 50
	ok(Flag.works(port2, "battery") == 1 and Flag.works(port2, "yard") == 1 and Flag.tax(port2) > t0, "finished after their days; dues %d -> %d with the customs house" % [t0, Flag.tax(port2)])
	var map2 = load("res://scenes/world_map.tscn").instantiate(); add_child(map2)
	G.tech = Campaign.enemy_tech(3)
	ok(map2.yard_of(port2).any(func(id): return GameData.hulls[id].klass == "bb"), "the building slip lays down battleships")
	map2.open_port(port2); map2.port_tab = "governor"; map2._render_port(); map2.close_panel(); map2._cmd_tab("holdings"); map2.close_panel(); map2.queue_free()
	port2.men = 100; G.day = int(G.day) + (7 - int(G.day) % 7); Flag._works_day()
	ok(int(port2.men) == 115, "the barracks recruit 15 a week")
	var w1: float = Campaign.wages(); var gd: Dictionary = Flag.raise_guard(port2)
	ok(Flag.guard(port2) == gd and gd.fac == "player" and not gd.ships.is_empty() and is_equal_approx(Campaign.wages() - w1, Flag.GUARD_PAY) and not Campaign.hostile_fleet(gd), "a guard squadron of %d ships on station, paid by the day" % gd.ships.size())
	# the guard meets a relief force
	port2.men = 400; var held := 0
	for i in 12:
		port2.fac = "player"; port2.from = "directorate"; port2.men = 400
		if Flag.guard(port2) == null: Flag.raise_guard(port2)
		Flag.relief_lands(Flag.launch(port2, "directorate"))
		if port2.fac == "player": held += 1
	print("with a guard, a battery and 400 men: held %d of 12 landings" % held)
	ok(held >= 4, "the works and the guard tell")
	port2.fac = "player"; port2.from = "directorate"; port2.men = 400
	# a convoy sails and pays
	seed(9); var cv = null
	for i in 80:
		Flag._convoys()
		for f2 in G.fleets: if int(f2.get("convoyOf", -1)) == int(port2.id): cv = f2
		if cv != null: break
	ok(cv != null and cv.fac == "player" and cv.kind == "convoy", "a convoy under your flag sails for %s" % (G.ports[int(cv.dest)].name if cv != null else "nowhere"))
	var c1: int = G.credits; Flag.convoy_arrived(cv); G.fleets.erase(cv)
	ok(int(G.credits) > c1 and int(G.flag.trade) > 0, "and pays %d on arrival" % (int(G.credits) - c1))
	# fleets of your flag and the powers' fleets: at war they fight, otherwise they pass
	var foe: Dictionary = Campaign.spawn_fleet("patrol", "directorate"); var gf: Dictionary = Flag.guard(port2)
	foe.x = gf.x; foe.y = gf.y; foe.cool = 0.0; gf.cool = 0.0; var n0: int = foe.ships.size() + gf.ships.size()
	Diplomacy._clash_t = 0.0; Diplomacy.clash_tick(1.0)
	ok(float(foe.get("cc", 0.0)) > 0.0 and (foe.ships.size() + gf.ships.size() < n0 or not G.fleets.has(foe) or not G.fleets.has(gf)), "your guard squadron fights a Directorate patrol (at war)")
	# the chancery
	ok(Flag.stance("directorate") == "war" and Flag.stance("concord") == "unrecognised", "stances: war with the Directorate, unrecognised by the Concord")
	G.rep.concord = 5; ok(Flag.can_recognise("concord") != "", "recognition needs standing: " + Flag.can_recognise("concord"))
	G.rep.concord = 12; ok(Flag.can_recognise("concord") == "", "and comes at standing 10 with a port"); print(Flag.seek_recognition("concord"))
	ok(Flag.recognised("concord") and Flag.tax(port2) > 0 and Flag.can_treaty("concord") != "", "recognised; a treaty wants more: " + Flag.can_treaty("concord"))
	G.rep.concord = 30; print(Flag.sign_treaty("concord")); ok(Flag.treaty("concord") and Flag.stance("concord") == "treaty", "treaty signed")
	# growth alarms the powers not bound by treaty
	var extra := []
	for q in G.ports: if q.fac == "pacific" and extra.size() < 4: q.fac = "player"; q.from = ""; q.men = 300; q.took = G.day; extra.append(q)
	var rc: int = G.rep.concord; var rr: int = G.rep.get("republic", 0); G.day = int(G.day) + (30 - int(G.day) % 30); Flag._chancery_day()
	ok(int(G.rep.concord) == rc and int(G.rep.get("republic", 0)) < rr, "a large flag alarms the Republic (%d -> %d) but not the Concord, bound by treaty" % [rr, int(G.rep.get("republic", 0))])
	for q in extra: q.fac = "pacific"; q.erase("from")
	# peace with the Directorate: they cede the port
	ok(Flag.peace_cost("directorate") == Flag.PEACE_COST + Flag.CEDE_COST and Flag.can_peace("directorate") == "", "peace has its price: %d" % Flag.peace_cost("directorate"))
	Flag.launch(port2, "directorate"); print(Flag.make_peace("directorate"))
	ok(not Campaign.at_war("directorate") and port2.get("from", "x") == "" and not G.fleets.any(func(f3): return Flag.is_relief(f3)), "peace: the port is ceded and their force recalled")
	# a ship comes over
	seed(4); G.day = int(G.day) + (15 - int(G.day) % 30 + 30) % 30; var tries2 := 0
	while port2.get("volunteers", []).is_empty() and tries2 < 200: Flag._volunteers(); tries2 += 1
	ok(not port2.get("volunteers", []).is_empty(), "a ship asks to serve (after %d months)" % tries2)
	var vs: Dictionary = port2.volunteers[0]; var nf: int = G.fleet.size(); print(Flag.commission(port2, vs))
	ok(G.fleet.size() == nf + 1 and port2.volunteers.is_empty(), "and is commissioned for a bounty")
	port.fac = "player"; port.from = "directorate"; port.men = 300; port.took = G.day
	if Flag.guard(port) == null: Flag.raise_guard(port)
	Campaign.save(); GameData.fac.player.name = "x"; var loaded := Campaign.load_game()
	print("after load: ports ", Flag.ports().size(), " treaty ", Flag.treaty("concord"), " battery ", Flag.works(Flag.ports()[0], "battery") if Flag.ports().size() else -1, " guard ", Flag.guard(Flag.ports()[0]) != null if Flag.ports().size() else false)
	ok(loaded and GameData.fac.player.name == "Meridian Company" and Flag.ports().size() == 1 and Flag.treaty("concord") and Flag.works(Flag.ports()[0], "battery") == 1 and Flag.guard(Flag.ports()[0]) != null, "flag, port, treaty, works and guard survive a save")
	print(Flag.abandon(Flag.ports()[0])); ok(Flag.ports().is_empty(), "given up")
	print("FLAG TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
