extends Node
## Electronic war measured (docs/SENSORS.md): missile ships against each other on several seeds, with and without the
## ECM research, counting what the missiles met (sys_log) and how long a decision took. No numbers are tuned here.
## godot --headless --path godot res://tests/ew_measure.tscn -- [seeds]
const DUELS := [[["ddg_burke", "ddg_burke"], ["ddg_sovremenny", "ddg_sovremenny"]], [["cg_tico"], ["cg_slava"]], [["ddg_adams", "ddg_adams"], ["ddg_kashin", "ddg_kashin"]]]
func _ready() -> void:
	var a := OS.get_cmdline_user_args(); var n: int = int(a[0]) if a.size() > 0 else 5
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	for ecm in [false, true]:
		var tech: Array = ["radar", "missiles", "ciws", "aegis", "sonar"] + (["ecm"] if ecm else [])
		for du in DUELS:
			var ts := []; var wins := 0; var log := {}
			for sd in n:
				seed(200 + sd)
				var sim := BattleSim.new()
				var recs := func(ids: Array, pal: String) -> Array: return ids.map(func(id): return {"type": id, "name": pal + " " + id, "hullFrac": 1.0, "fit": BattleSim.default_fit(GameData.hulls[id], tech), "pal": pal})
				sim.setup(recs.call(du[0], "player"), recs.call(du[1], "directorate"), tech, tech, 2)
				sim.flag = null
				while not sim.finished and sim.t < 3600: sim.step(0.05)
				ts.append(int(sim.t)); if sim.result.get("victory", false): wins += 1
				for k in sim.sys_log: if String(k).contains("missile") or String(k).contains("chaff"): log[k] = int(log.get(k, 0)) + int(sim.sys_log[k])
			ts.sort()
			print("%s %s v %s: won %d of %d, median %d s %s  %s" % ["ECM" if ecm else "---", du[0], du[1], wins, n, ts[ts.size() / 2], ts, log])
	get_tree().quit()
