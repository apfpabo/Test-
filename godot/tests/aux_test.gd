extends Node
## Headless check of the auxiliaries round: every design has its art and fits out, troopships embark soldiers and
## land them on a structure, oilers extend the bunkers, an ammunition ship and a repair ship replenish at sea, a
## prize's drawings are copied, and a contact at long range opens the battle farther out.
## godot --headless --path godot res://tests/aux_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _ready() -> void:
	seed(11)
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G
	# every design: art in the player's paint, a default fit, a class in the order
	var bad := []
	for id in GameData.hulls:
		var h: Dictionary = GameData.hulls[id]
		if not GameData.sprites.ships.has(id) or not GameData.hull_order.has(h.klass) or GameData.ship_tex(id, "player", "base") == null: bad.append(id)
		var rec: Dictionary = Campaign.new_ship(id, "T", "player", Campaign.enemy_tech(3))
		if rec.fit.size() != h.slots.size(): bad.append(id + " fit")
	ok(bad.is_empty(), "%d designs with art and a fit %s" % [GameData.hulls.size(), str(bad)])
	for id in ["bb_nelson", "bb_scharnhorst", "cv_shokaku", "cve_ryujo", "cv_essex", "dd_fubuki", "cl_atlanta", "ss_foxtrot", "ss_tang", "ssn_charlie", "ddg_burke", "ddg_sovremenny", "ssn_la", "ssn_akula", "ssn_oscar", "ssn_typhoon", "cv_nimitz", "cg_kirov", "ap_haskell", "ap_lst", "ap_austin", "ap_rogov", "ao_cimarron", "ao_t2", "ae_hood", "ar_vulcan"]:
		if not GameData.hulls.has(id): ok(false, "design " + id)
	ok(Campaign.design_ok("cv_shokaku", []) and Campaign.design_ok("cv_essex", []) and Campaign.design_ok("cve_ryujo", []), "wartime carriers need no research")
	ok(not Campaign.design_ok("cv_midway", []) and not Campaign.design_ok("cv_nimitz", Campaign.enemy_tech(2)) and Campaign.design_ok("cv_nimitz", Campaign.enemy_tech(3)), "jet and nuclear carriers stay gated")
	ok(not Campaign.design_ok("ap_haskell", []) and Campaign.design_ok("ap_haskell", ["amphib"]), "troop transports need amphibious warfare")
	ok(GameData.hulls.cve_ryujo.island == null and GameData.hulls.cv_essex.island != null, "the flat-top has no island")
	ok(float(GameData.hulls.cv_nimitz.fuel) == 0.0 and float(GameData.hulls.cg_kirov.fuel) == 0.0 and float(GameData.hulls.ssn_typhoon.fuel) == 0.0, "nuclear ships burn no oil")
	# Nelson: three turrets forward; the third stays on the deck, behind the raised second
	var sim := BattleSim.new(); sim.setup([Campaign.new_ship("bb_nelson", "N", "player", [])], [Campaign.new_ship("dd", "E", "raiders", [])], [], [], 0)
	var lv := []
	for m in sim.ships[0].mounts: if m.w.size == "H": lv.append(m.lvl)
	ok(lv == [0, 1, 0], "Nelson's turret levels %s" % str(lv))
	# a contact at carrier reach opens the action farther out
	var far := BattleSim.new(); far.sep = 18000.0; far.setup([Campaign.new_ship("dd", "A", "player", [])], [Campaign.new_ship("dd", "B", "raiders", [])], [], [], 0)
	var d0: float = sim.ships[0].pos.distance_to(sim.ships[1].pos); var d1: float = far.ships[0].pos.distance_to(far.ships[1].pos)
	ok(d0 < 9600.0 and d1 > 17500.0 and far.escape_r > d1, "battle opens at %d m by default, %d m at long range" % [int(d0), int(d1)])
	G.fleet = [Campaign.new_ship("dd", "Flag", "player", [])]
	var f: Dictionary = Campaign.spawn_fleet("raiders", "raiders"); f.contactKm = 300
	ok(int(Campaign.battle_setup(f).range_km) == 300, "the contact range reaches the battle")
	# troopships
	G.tech = ["amphib"]
	G.fleet = [Campaign.new_ship("cl", "Flag", "player", []), Campaign.new_ship("ap_haskell", "Trooper", "player", []), Campaign.new_ship("ap_lst", "Lander", "player", [])]
	G.crew = Campaign.crew_need(); G.credits = 200000
	ok(Structures.troop_capacity() == 1740, "berths for %d" % Structures.troop_capacity())
	var w0: float = Campaign.wages()
	ok(Structures.embark(100) == 100 and Structures.troops() == 100 and int(G.credits) == 200000 - 100 * Structures.TROOP_COST, "embarked 100 for %d each" % Structures.TROOP_COST)
	ok(Structures.embark(99999) == 1640 and Structures.troops() == 1740, "the berths fill and no more")
	ok(is_equal_approx(Campaign.wages() - w0, 1740 * Structures.TROOP_WAGE), "soldiers draw wages")
	var tgt: Dictionary = {}
	for s in Structures.all(): if s.kind == "radar" and s.fac == "directorate": tgt = s; break
	ok(Structures.can_invade(tgt) != "", "no landing from far away: " + Structures.can_invade(tgt))
	var w := Structures.coast_point(tgt); G.player.x = w.x; G.player.y = w.y
	ok(Structures.can_invade(tgt) == "", "landing possible off the coast '%s'" % Structures.can_invade(tgt))
	tgt.dmg = 0.9
	var odds := Structures.invade_odds(tgt)
	print("target ", tgt.name, " defenders ", int(Structures.defenders(tgt)), " odds ", odds)
	var won := false; var tries := 0
	while not won and tries < 12:
		if Structures.troops() < 800: G.troops = 1740
		var r := Structures.invade(tgt); tries += 1; won = r.won
		print("landing %d: %d men, %d lost, won %s" % [tries, r.men, r.lost, str(r.won)])
	ok(won and tgt.fac == "player" and int(tgt.garrison) > 0, "the landing carried it; garrison %d, %d troops back aboard" % [int(tgt.garrison), Structures.troops()])
	ok(Campaign.at_war("directorate"), "the landing broke the armistice")
	# the transport is lost: soldiers without a berth go with her
	G.troops = 1740; G.fleet.remove_at(1)
	ok(Structures.trim_troops() == 1500 and Structures.troops() == 240, "soldiers without a berth are lost")
	# the assault forces of the powers use troop transports once they have them
	var af: Dictionary = Structures.launch_assault(tgt, "directorate")
	ok(af.ships.any(func(s): return s.get("troops", false) and GameData.hulls[s.type].klass == "ap"), "their assault force sails in troop transports")
	# oilers
	G.fleet = [Campaign.new_ship("bb_iowa", "Flag", "player", [])]
	var c0: int = Campaign.bunker_cap()
	G.fleet.append(Campaign.new_ship("ao_cimarron", "Oiler", "player", []))
	ok(Campaign.tank_cap() == 900 and Campaign.bunker_cap() > c0 + 900, "an oiler adds 900 tons to the bunkers (%d -> %d)" % [c0, Campaign.bunker_cap()])
	G.cargo.fuel = Campaign.bunker_cap() - 50
	ok(Campaign.fuel_room() == 50, "room for 50 more tons")
	# ammunition ship
	G.fleet.append(Campaign.new_ship("ae_hood", "Ammo", "player", [])); G.crew = Campaign.crew_need()
	G.fleet[0].ammo = 0.2; G.cargo.munitions = 0.0
	var need: float = Campaign.rearm_tons(G.fleet[0])
	Campaign._replenish()
	ok(is_equal_approx(float(G.fleet[0].ammo), 0.2) and G.get("ammoWarned", false), "no munitions, no rearming")
	G.cargo.munitions = 500.0; var days := 0
	while float(G.fleet[0].get("ammo", 1.0)) < 0.999 and days < 60: Campaign._replenish(); days += 1
	ok(float(G.fleet[0].ammo) >= 0.999 and absf((500.0 - float(G.cargo.munitions)) - need) < 1.0 and days == int(ceil(need / 40.0)), "rearmed at sea in %d days with %d tons" % [days, int(need)])
	# repair ship
	G.fleet.append(Campaign.new_ship("ar_vulcan", "Repair", "player", [])); G.fleet[0].hullFrac = 0.3; G.cargo.steel = 600.0; days = 0
	while float(G.fleet[0].hullFrac) < Campaign.SEA_REPAIR - 0.001 and days < 90: Campaign._replenish(); days += 1
	ok(is_equal_approx(float(G.fleet[0].hullFrac), Campaign.SEA_REPAIR) and float(G.cargo.steel) < 600.0, "patched to 75%% in %d days, %d tons of steel" % [days, int(600.0 - float(G.cargo.steel))])
	Campaign._replenish()
	ok(is_equal_approx(float(G.fleet[0].hullFrac), Campaign.SEA_REPAIR), "and no further at sea")
	# a prize's drawings
	G.tech = []; var rp0: int = G.rp
	var prize: Dictionary = Campaign.new_ship("ddg_kashin", "Prize", "player", Campaign.enemy_tech(2))
	var note := Campaign.study_prize(prize)
	ok(note != "" and int(G.rp) == rp0 + 64 and Campaign.studied("ddg_kashin"), "copied her drawings: " + note)
	ok(Campaign.study_prize(prize) == "" and int(G.rp) == rp0 + 64, "a second of the class teaches nothing new")
	# save and load keep it all
	G.troops = 77; Campaign.save(); Campaign.load_game()
	ok(Structures.troops() == 77 and Campaign.studied("ddg_kashin"), "troops and drawings survive a save")
	print("AUX TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
