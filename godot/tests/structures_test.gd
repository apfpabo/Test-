extends Node
## Headless check of land structures: the world's structures and owners, air strikes until the defences are
## silenced, surrender, a month's income to a depot, an assault force landing, structures changing hands in a war,
## a strike contract, and a save/load round trip. godot --headless --path godot res://tests/structures_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _ready() -> void:
	seed(7)
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; var S: Array = Structures.all()
	var by := {}; var kinds := {}
	for s in S: by[s.fac] = by.get(s.fac, 0) + 1; kinds[s.kind] = kinds.get(s.kind, 0) + 1
	print("structures ", S.size(), " by kind ", kinds); print("by owner ", by)
	ok(S.size() == Campaign.C.LAND_SITES.size() + Campaign.C.INSTALLATIONS.size(), "every site and installation is a structure")
	var names := {}
	for s in S: names[s.name] = true
	ok(names.size() == S.size(), "names are unique (%d)" % names.size())
	print("examples: ", ", ".join(S.slice(0, 6).map(func(s): return s.name)), " ... ", ", ".join(S.slice(-6).map(func(s): return s.name)))
	ok(by.get("", 0) > 0 and by.get("directorate", 0) > 10, "some unclaimed, the Directorate holds many")
	# a carrier task force off a Directorate airfield
	var af: Dictionary = {}
	for s in S: if s.kind == "airfield" and s.fac == "directorate": af = s; break
	print("target: ", af.name, " defences ", Structures.defence_text(af))
	G.fleet = [Campaign.new_ship("cve_colossus", "Test Carrier", "player", []), Campaign.new_ship("cve_casa", "Second Carrier", "player", []), Campaign.new_ship("dd", "Escort", "player", [])]
	G.crew = Campaign.crew_need() + 400
	var w := Campaign.nearest_water(af.x, af.y, 80); G.player.x = w.x; G.player.y = w.y
	ok(Structures.air_group() == 30, "air group 30 planes (%d)" % Structures.air_group())
	ok(Structures.can_strike(af) == "", "strike possible: '%s'" % Structures.can_strike(af))
	var rep0: int = G.rep.directorate
	var n := 0
	while not Structures.silenced(af) and n < 8:
		if Structures.air_group() < 4: Structures.replace_planes()
		G.strikeReady = 0.0
		var r := Structures.strike(af); n += 1
		print("strike %d: %d planes, %d fighters, lost %d to fighters and %d to flak, %d downed; defences %d%% -> %d%%" % [n, r.planes, r.fighters, r.lost_fighters, r.lost_flak, r.downed, int(r.before * 100), int(r.after * 100)])
	ok(Structures.silenced(af), "silenced after %d strikes" % n)
	ok(G.rep.directorate <= rep0 - 30 and Campaign.at_war("directorate"), "the first strike broke the armistice (standing %d)" % G.rep.directorate)
	ok(Structures.can_take(af) == "", "surrender possible: '%s'" % Structures.can_take(af))
	var crew0: int = G.crew
	print(Structures.take(af))
	ok(af.fac == "player" and G.crew == crew0 - Structures.garrison_need(af), "taken, garrison landed")
	# an economic site, unclaimed or taken the same way, and the month's yield
	var oil: Dictionary = {}
	for s in S: if s.kind == "oil" and s.fac != "" and s.fac != "player": oil = s; break
	oil.dmg = 0.9; w = Campaign.nearest_water(oil.x, oil.y, 80); G.player.x = w.x; G.player.y = w.y
	print(Structures.take(oil))
	var farm: Dictionary = {}
	for s in S: if s.kind == "farm" and s.fac != "" and s.fac != "player": farm = s; break
	farm.dmg = 0.9; farm.ruin = 0.0; w = Campaign.nearest_water(farm.x, farm.y, 80); G.player.x = w.x; G.player.y = w.y
	print(Structures.take(farm))
	var c0: float = G.credits; var dp = Structures.depot_of(farm)
	print("farm goods go to ", Structures.depot_name(dp), "; oil yields ", Structures.yield_of(oil))
	while G.day % 30 != 29: G.day += 1
	Campaign.new_day(false)
	ok(int(Structures.store_of(dp).get("food", 0)) > 0, "food in the depot at %s: %s" % [dp.name, Structures.store_of(dp)])
	ok(G.credits > c0 - Campaign.wages() * 2, "money paid (credits %d -> %d)" % [int(c0), int(G.credits)])
	# an assault force sails, and lands (forced)
	var f: Dictionary = Structures.launch_assault(oil, "directorate")
	ok(f.kind == "assault" and Campaign.hostile_fleet(f) and f.ships.any(func(s): return s.get("troops", false)), "assault force with troopships (%d ships)" % f.ships.size())
	print("assault from %.0f,%.0f to %s, route %s, dist %.0f" % [f.x, f.y, f.tgt, f.get("route") != null, Campaign.mdist(f.x, f.y, f.tgt.x, f.tgt.y)])
	var steps := 0
	while G.fleets.has(f) and steps < 30 * 10 * 40:
		Campaign.paused = false; G.player.cool = 99.0; Campaign.update(1.0 / 30.0); steps += 1
	ok(not G.fleets.has(f), "the assault landed after %.1f days: the %s is %s" % [steps / 300.0, oil.name, Structures.owner_name(oil)])
	# the powers fight over structures in a war
	Diplomacy.declare("concord", "directorate")
	var before := S.filter(func(s): return s.fac == "concord").size()
	for i in 400: Structures.war_tick(Diplomacy.pair("concord", "directorate"))
	print("in 400 war days the Concord's structures went from %d to %d" % [before, S.filter(func(s): return s.fac == "concord").size()])
	# a strike contract from a Concord port at war
	var cal: Dictionary = {}
	for p in G.ports: if p.name == "Calder Roads": cal = p
	var sc := {}
	for i in 60:
		var c := Diplomacy._make(cal)
		if c.get("kind", "") == "strike": sc = c; break
	ok(not sc.is_empty(), "a strike contract: " + str(sc.get("title", "none")))
	# save and load
	Campaign.save(); var held := Structures.held().size()
	ok(Campaign.load_game() and Structures.held().size() == held and Structures.all().size() == S.size(), "save/load keeps %d structures, %d held" % [Structures.all().size(), held])
	for i in 300: Campaign.update(1.0 / 30.0)
	print("structures test done, %d failures" % fails)
	get_tree().quit(1 if fails else 0)
