extends Node
## Headless check of salvage after battle and running dark on the chart.
## godot --headless --path godot res://tests/salvage_test.tscn
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c: fails += 1

func _ready() -> void:
	seed(12); Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}; Campaign._wx = {}
	# ---- salvage
	ok(GameData.hulls.has("ar_diver") and GameData.hulls.ar_diver.get("salvage", false) and GameData.ship_tex("ar_diver", "player", "base") != null, "the salvage ship exists and has her art")
	G.fleet = [Campaign.new_ship("ca_baltimore", "Flag", "player", []), Campaign.new_ship("fr_liberty", "Hold", "player", [])]
	for g in ["steel", "munitions", "food", "medicine", "electronics"]: G.cargo[g] = 0
	G.cargo.fuel = 0.0
	var deep := Campaign.water_point(60.0); G.player.x = deep.x; G.player.y = deep.y
	ok(not Campaign.land_near(deep.x, deep.y, 28.0) and is_equal_approx(Campaign.salvage_mult(), 1.0), "deep water, no salvage ship: the plain yield")
	var wrecks := func() -> Array: return [Campaign.new_ship("ca_hipper", "X", "directorate", []), Campaign.new_ship("dd_narvik", "Y", "directorate", [])]
	var tot := func(mult_setup: Callable) -> float:
		var sum := 0.0
		for i in 40:
			for g in ["steel", "munitions"]: G.cargo[g] = 0
			G.cargo.fuel = 0.0; mult_setup.call(); var r: Dictionary = Campaign.salvage(wrecks.call()); sum += int(r.steel) + int(r.munitions)
		return sum / 40.0
	var plain: float = tot.call(func(): pass)
	var c0: int = G.credits; var one: Dictionary = Campaign.salvage(wrecks.call())
	ok(int(one.steel) > 0 and int(one.coin) > 0 and int(G.credits) == c0 + int(one.coin) and int(one.rp) == 0, "two wrecks yield steel %d, munitions %d, fuel %d, fittings %d" % [int(one.steel), int(one.munitions), int(one.fuel), int(one.coin)])
	G.fleet.append(Campaign.new_ship("ar_diver", "Grapple", "player", []))
	var with_ship: float = tot.call(func(): pass)
	ok(with_ship > plain * 1.7 and with_ship < plain * 2.3, "a salvage ship doubles it (%.0f against %.0f tons)" % [with_ship, plain])
	G.fleet[2].reserve = true; ok(is_equal_approx(Campaign.salvage_mult(), 1.0), "not if she is held in reserve"); G.fleet[2].reserve = false
	var port: Dictionary = G.ports[0]; G.player.x = port.sx; G.player.y = port.sy
	ok(is_equal_approx(Campaign.salvage_mult(), 3.0), "shoal water adds half as much again (x%.1f with the ship)" % Campaign.salvage_mult())
	G.cargo.steel = Campaign.cargo_cap() - 3; var full: Dictionary = Campaign.salvage(wrecks.call())
	ok(int(full.steel) <= 3 and full.left, "full holds leave the rest in the water")
	G.tech = []; var modern: Dictionary = Campaign.salvage([Campaign.new_ship("cg_tico", "Z", "concord", Campaign.enemy_tech(3))])
	ok(int(modern.rp) > 0, "a wreck of an era ahead of yours yields research (+%d RP)" % int(modern.rp))
	ok(Campaign.salvage([]).steel == 0, "nothing sunk, nothing salvaged")
	# through a battle
	for g in ["steel", "munitions"]: G.cargo[g] = 0
	var foe: Dictionary = Campaign.spawn_fleet("raiders", "raiders")
	var bs := BattleSim.new(); bs.setup(Campaign.battle_setup(foe).player_recs, foe.ships, [], [], 0)
	for sh in bs.ships: if sh.side == 1: sh.alive = false
	GameData.pending = {"fleet_id": foe.id}; var res: Dictionary = Campaign.apply_battle(bs)
	ok(res.victory and res.has("salvage") and int(res.salvage.steel) > 0 and int(G.cargo.steel) == int(res.salvage.steel), "a victory salvages its wrecks (%d tons of steel)" % int(res.salvage.steel))
	# ---- running dark
	var P: Dictionary = G.player; P.spd = "cruise"; P.dark = false; G.erase("heardUntil")
	ok(is_equal_approx(Campaign.signature(), 1.0), "cruising with lights on: found at the usual distance")
	P.spd = "flank"; var fl := Campaign.signature(); P.spd = "slow"; var sl := Campaign.signature()
	ok(fl > 1.2 and sl < 0.75, "flank speed gives you away (%d%%), slow hides you (%d%%)" % [int(fl * 100), int(sl * 100)])
	P.spd = "full"; Campaign.set_dark(true)
	ok(Campaign.dark() and Campaign.speed_order() == "half", "running dark holds the engines to Half")
	var day_sig := Campaign.signature(); Weather.force = {"sea": 0, "fog": false, "night": true, "moon": 0.3}; Campaign._wx = {}
	var night_sig := Campaign.signature()
	ok(night_sig < day_sig and is_equal_approx(night_sig, 0.85 * 0.6), "dark helps most by night (%d%% against %d%% by day)" % [int(night_sig * 100), int(day_sig * 100)])
	var f: Dictionary = Campaign.spawn_fleet("patrol", "concord")
	var seen_dark := Campaign.ck_them(f, Campaign.weather_here()); Campaign.set_dark(false); P.spd = "cruise"
	ok(seen_dark < Campaign.ck_them(f, Campaign.weather_here()), "a patrol finds a darkened squadron later")
	Campaign.set_dark(true); ok(Campaign.call_fleet(f).begins_with("You are running dark"), "no wireless while dark")
	Campaign.set_dark(false); P.spd = "cruise"; f.x = P.x + 50.0; f.y = P.y; G.rep.concord = 20
	var said := Campaign.call_fleet(f)
	ok(Campaign.heard() and is_equal_approx(Campaign.signature(), 1.5), "a wireless call is heard: found at 150%% for a day (%s)" % said.substr(0, 40))
	G.day = int(G.day) + 2; ok(not Campaign.heard(), "and forgotten after")
	# the screens
	var map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	Campaign.set_dark(true); map._set_speed("flank")
	ok(Campaign.speed_order() != "flank", "the telegraph refuses Flank while dark")
	map._update_telegraph(); Campaign.last_result = res; map._show_aftermath(res); map.close_panel()
	ok(map.dark_btn.text.begins_with("Running dark"), "the panels open: '%s'" % map.dark_btn.text)
	Campaign.save(); ok(Campaign.load_game() and Campaign.dark(), "running dark survives a save")
	Weather.force = null
	print("SALVAGE TEST ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
