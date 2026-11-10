extends Node
## Headless check of nuclear weapons: only missile submarines carry them, only with the research and only fitted at
## your own port or the Enclaves; a strike destroys a structure for good, makes its owner an enemy for good, turns the
## other powers against you and voids your treaties; a power of the missile age answers in kind; the screens open.
## godot --headless --path godot res://tests/nuke_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _ready() -> void:
	seed(8); Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	ok(Campaign.C.TECH.any(func(t): return t.id == "nukes") and not Campaign.enemy_tech(3).has("nukes"), "the research exists, and the powers do not start with it")
	var t3: Array = Campaign.enemy_tech(3)
	G.fleet = [Campaign.new_ship("ca_baltimore", "C", "player", t3)]
	ok(Structures.nuke_capacity() == 0 and Structures.can_arm("player") != "", "a cruiser carries none: " + Structures.can_arm("player"))
	G.fleet.append(Campaign.new_ship("ssn_typhoon", "T", "player", t3)); G.fleet.append(Campaign.new_ship("ssn_la", "L", "player", t3))
	ok(Structures.nuke_capacity() == 5, "a Typhoon and a Los Angeles: %d tubes" % Structures.nuke_capacity())
	G.credits = 1000000
	ok(Structures.can_arm("player").begins_with("Needs"), "not without the research")
	G.tech = t3 + ["nukes"]
	ok(Structures.can_arm("player").begins_with("Warheads are made at a nuclear plant"), "no warhead without a nuclear plant of your own")
	var plant: Dictionary = Structures.plants_of("concord")[0]; plant.fac = "player"; plant.garrison = 150; plant.pile = int(G.day)
	ok(Structures.can_arm("player").begins_with("Your plant has no warhead ready"), "nor before the plant has made one: " + Structures.can_arm("player"))
	G.warStock = 2
	ok(Structures.can_arm("concord") != "" and Structures.can_arm("player") == "", "fitted only at a port or base of your own")
	Structures.arm(); Structures.arm()
	ok(Structures.nukes() == 2 and int(G.credits) == 1000000 - 2 * Structures.NUKE_COST, "two warheads aboard")
	var tgt: Dictionary = {}
	for s in Structures.all(): if s.kind == "industry" and s.fac == "directorate": tgt = s; break
	ok(Structures.can_nuke(tgt).begins_with("Out of reach"), "not from the far side of the world")
	var w := Campaign.nearest_water(tgt.x, tgt.y, 80); G.player.x = w.x; G.player.y = w.y
	ok(Structures.can_nuke(tgt) == "", "within 600 km: possible")
	# a flag with a treaty, to see it voided; a held structure, to see the answer fall on it
	var base: Dictionary = {}
	for s in Structures.all(): if s.kind == "navalbase": base = s; break
	base.fac = "player"; base.from = ""; base.took = G.day; base.garrison = 200
	Flag.found("Test Flag"); G.flag.treaty = {"concord": int(G.day) + 300}; G.flag.recog = {"concord": 1}
	if not G.has("facRp"): G.facRp = {}
	G.facRp.directorate = 900.0   # the Directorate has reached the missile age
	var before := {}
	for o in Diplomacy.POWERS: before[o] = int(G.rep.get(o, 0))
	var r := Structures.nuke(tgt)
	for n in r.notes: print("  ", n)
	ok(tgt.get("nuked", false) and tgt.fac == "" and Structures.yield_of(tgt).is_empty() and Structures.can_take(tgt) != "" and Structures.can_strike(tgt) != "", "the structure is gone for good")
	ok(int(G.rep.directorate) == -100 and Campaign.at_war("directorate") and Flag.can_peace("directorate").begins_with("They will never"), "its owner is an enemy for good")
	var worse := 0
	for o in Diplomacy.POWERS: if o != "directorate" and int(G.rep.get(o, 0)) <= before[o] - 15: worse += 1
	ok(worse == Diplomacy.POWERS.size() - 1 and not Flag.treaty("concord") and not Flag.recognised("concord"), "every other power turns on you; treaties and recognition are void")
	ok(Structures.nukes() == 1 and G.get("nukeDebt", []).size() == 1, "one warhead left; an answer is owed")
	G.day = int(G.nukeDebt[0].day); Structures.new_day()
	ok(base.get("nuked", false) and Structures.held().is_empty() and G.nukeDebt.is_empty(), "the answer destroys your naval base")
	for i in 40: Structures.new_day()
	ok(float(tgt.ruin) == 1.0 and float(base.dmg) == 1.0, "nothing mends there")
	# the screens
	var map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	var t2: Dictionary = {}
	for s in Structures.all(): if s.kind == "farm" and s.fac == "directorate": t2 = s; break
	w = Campaign.nearest_water(t2.x, t2.y, 80); G.player.x = w.x; G.player.y = w.y
	map.open_struct(t2); map._nuke_confirm(t2); map._nuke_fire(t2); map.close_panel(); map.open_struct(tgt); map.close_panel()
	ok(t2.get("nuked", false) and Structures.nukes() == 0, "the panels open and the second warhead is spent")
	Campaign.save(); ok(Campaign.load_game() and Structures.all()[int(tgt.id)].get("nuked", false), "it survives a save")
	print("NUKE TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
