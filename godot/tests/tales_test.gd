extends Node
## Tales (scripts/tales.gd, docs/WRITING_TALES.md): every file in data/tales reads without a mistake; a file with
## mistakes is caught line by line; a tale comes up where and when it should, its choices and effects work, a fight
## starts and a won fight goes on; what has happened survives a save.
## godot --headless --path godot res://tests/tales_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1
func _ready() -> void:
	seed(4)
	for e in Tales.errors: print("  ", e)
	ok(Tales.errors.is_empty(), "every tale file reads cleanly (%d tales, %d mistakes)" % [Tales.T.size(), Tales.errors.size()])
	# a file with mistakes: each is named with its line
	var T0 := Tales.T.duplicate(); var O0 := Tales.order.duplicate()
	Tales.T = {}; Tales.order = []; Tales.errors = []
	Tales.parse("""=== bad tale
=== broken
when: someday
where: near Atlantis
needs: credits, standing nobody >= 3
--- start
Some text.
! credits lots
! teleport home
* Go on -> nowhere
* No arrow here
--- lonely
Nobody comes here.
""", "bad.txt"); Tales.check()
	for e in Tales.errors: print("  ", e)
	var want := ["bad.txt:1:", "bad.txt:3:", "bad.txt:4:", "bad.txt:5:", "bad.txt:8:", "bad.txt:9:", "bad.txt:11:", "lonely"]
	ok(want.all(func(w): return Tales.errors.any(func(e): return e.contains(w))), "mistakes are named with their lines (%d)" % Tales.errors.size())
	ok(Tales.errors.any(func(e): return e.contains("nowhere")), "a choice to a missing scene is caught")
	# a small tale of our own
	Tales.T = {}; Tales.order = []; Tales.errors = []
	Tales.parse("""=== test_tale
title: A Test
when: at sea
days: 2+
needs: credits >= 100, not flag seen
--- start
Hello {flagship}.
! rp +5
* [credits >= 99999999] Too dear -> dear
* Fight them -> fight
* Leave -> leave
--- dear
x
* ok -> end
--- fight
! fight raiders pt dd "Testy" -> won
--- won
Won.
! flag seen
! credits +1000
* Done -> end
--- leave
! standing directorate -3
! fuel +7
! hull -10%
! ship dd "Gift"
* Done -> end
=== port_tale
when: arriving
where: port Strelsk
--- start
In port.
""", "mine.txt"); Tales.check()
	for e in Tales.errors: print("  ", e)
	ok(Tales.errors.is_empty(), "the test tales read cleanly")
	Campaign.new_game("merchant")
	var G: Dictionary = Campaign.G; G.fleets = []
	ok(not Tales.eligible("test_tale"), "not on day 1 (days 2+)")
	G.day = 5
	ok(Tales.eligible("test_tale"), "eligible on day 5")
	var heard := []; Tales.ready_tale.connect(func(id): heard.append(id))
	Tales.new_day()
	ok(heard == ["test_tale"] and Tales.st().open == "test_tale", "it comes up at sea")
	var out: Dictionary = Tales.enter()
	ok(int(G.rp) == 5 and Tales.text().contains(String(G.fleet[0].name)), "effects applied, {flagship} filled: " + Tales.text())
	var ch: Array = Tales.choices()
	ok(ch.size() == 3 and not ch[0].ok and ch[1].ok and ch[0].why.contains("credits"), "a choice it cannot afford is shown and barred")
	Tales.choose("leave"); var c0 := float(G.credits); var f0 := float(G.cargo.get("fuel", 0)); var n0: int = G.fleet.size()
	out = Tales.enter()
	ok(int(G.rep.directorate) < 0 and float(G.cargo.fuel) == f0 + 7 and G.fleet.size() == n0 + 1 and G.fleet[-1].name == "Gift", "standing, cargo, a ship: " + " · ".join(out.notes))
	ok(G.fleet.slice(0, n0).all(func(s): return s.hullFrac <= 0.91), "hull -10% (the ships she had)")
	Tales.choose("end")
	ok(Tales.st().open == "" and Tales.st().done.has("test_tale"), "it ends and is remembered")
	G.day = 9; Tales.new_day()
	ok(Tales.st().open == "", "once done it does not come back")
	# a fight, won, goes on
	Tales.st().done.erase("test_tale"); Tales.open("test_tale", "fight")
	out = Tales.enter()
	ok(out.fight != null and out.fight.ships.size() == 2 and out.fight.ships[0].name == "Testy" and Campaign.hostile_fleet(out.fight), "a fight spawns a hostile squadron alongside")
	Tales.st().open = ""
	ok(Tales.after_battle(true) == "test_tale" and Tales.st().scene == "won", "a won fight goes on to its scene")
	Tales.enter(); Tales.choose("end")
	ok(Tales.st().flags.has("seen") and not Tales.eligible("test_tale"), "a flag set; the tale's needs now fail")
	Tales.st().resume = {"id": "test_tale", "scene": "won"}
	ok(Tales.after_battle(false) == "" and Tales.st().resume.is_empty(), "a lost fight does not go on")
	# arriving
	var strelsk: Dictionary = G.ports.filter(func(p): return p.name == "Strelsk")[0]; var other: Dictionary = G.ports.filter(func(p): return p.name == "Halbrook")[0]
	ok(Tales.on_arrive(other) == "" and Tales.on_arrive(strelsk) == "port_tale", "an arriving tale comes up in its harbour only")
	Tales.finish()
	# saved and loaded
	Campaign.save(); Campaign.load_game()
	ok(Campaign.G.tales.done.has("port_tale") and Campaign.G.tales.flags.has("seen"), "what happened survives a save")
	# the examples: run every scene's effects so nothing in them is wrong at run time
	Tales.T = T0; Tales.order = O0
	for id in Tales.order:
		for sn in Tales.T[id].scenes:
			Tales.open(id, sn); var o2: Dictionary = Tales.enter(); Tales.choices(); Tales.text()
	Tales.finish()
	ok(true, "every scene of the shipped tales runs")
	print("DONE fails=%d" % fails)
	if fails: print("FAILED")
	get_tree().quit(1 if fails else 0)
