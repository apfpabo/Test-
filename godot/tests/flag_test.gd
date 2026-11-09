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
	ok(not Flag.founded() and Flag.can_found() != "" and not GameData.fac.has("player"), "no flag without ground: " + Flag.can_found())
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
	Campaign.save(); GameData.fac.erase("player"); ok(Campaign.load_game() and GameData.fac.has("player") and Flag.ports().size() == 1, "flag and port survive a save")
	print(Flag.abandon(Flag.ports()[0])); ok(Flag.ports().is_empty(), "given up")
	print("FLAG TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
