extends Node
## Armour by place, measured: gun duels between armoured ships on several seeds, the time to a decision, what each
## shell did (sys_log "shell <kind> <place>") and who won. No numbers are tuned here.
## godot --headless --path godot res://tests/armour_measure.tscn -- [seeds]
const DUELS := [["bb_iowa", "bb_yamato"], ["bb_kgv", "bb_bismarck"], ["ca_baltimore", "ca_hipper"], ["cl_cleveland", "cl_sverdlov"], ["bb_iowa", "ca_desmoines"]]
func _ready() -> void:
	var a := OS.get_cmdline_user_args(); var n: int = int(a[0]) if a.size() > 0 else 6
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	var tech: Array = ["radar"]
	for du in DUELS:
		var ts := []; var wins := 0; var log := {}; var hullA := []; var hullB := []
		for sd in n:
			seed(100 + sd)
			var sim := BattleSim.new()
			var rec := func(id: String, pal: String) -> Dictionary: return {"type": id, "name": pal + " " + id, "hullFrac": 1.0, "fit": BattleSim.default_fit(GameData.hulls[id], tech), "pal": pal}
			sim.setup([rec.call(du[0], "player")], [rec.call(du[1], "directorate")], tech, tech, 2)
			sim.flag = null
			while not sim.finished and sim.t < 5400: sim.step(0.05)
			ts.append(int(sim.t)); if sim.result.get("victory", false): wins += 1
			for k in sim.sys_log: if String(k).begins_with("shell ") and String(k).count(" ") == 2: log[k] = int(log.get(k, 0)) + int(sim.sys_log[k])
			hullA.append(snappedf(sim.ships[0].hull / sim.ships[0].max_hull, 0.01)); hullB.append(snappedf(sim.ships[1].hull / sim.ships[1].max_hull, 0.01))
		ts.sort()
		print("%s v %s: won %d of %d, time median %d s %s, hull left %s / %s" % [du[0], du[1], wins, n, ts[ts.size() / 2], ts, hullA, hullB])
		var ks := log.keys(); ks.sort()
		print("    ", ", ".join(ks.map(func(k): return "%s %d" % [String(k).substr(6), log[k]])))
	get_tree().quit()
