extends Node
## Headless check: plays every preset engagement to the end with both sides under AI control and reports the outcome.
## godot --headless --path godot res://tests/run_presets.tscn
func _ready() -> void:
    var sk = preload("res://scripts/skirmish.gd")
    var ok := true
    for pr in sk.PRESETS:
        var sim := BattleSim.new()
        var tech: Array = sk.ERA_TECH[pr.era]
        var recs := func(ids: Array, pal: String) -> Array:
            var out := []
            for i in ids.size(): out.append({"type": ids[i], "name": "%s %d" % [pal, i], "hullFrac": 1.0, "fit": BattleSim.default_fit(GameData.hulls[ids[i]], tech), "pal": pal})
            return out
        sim.setup(recs.call(pr.player, "player"), recs.call(pr.enemy, pr.fac), tech, tech, 2)
        sim.flag = null
        var t0 := Time.get_ticks_msec(); var steps := 0
        while not sim.finished and sim.t < 7200: sim.step(0.02); steps += 1; if steps % 25 == 0: sim.fx(0.5)
        var r: Dictionary = sim.result
        if not sim.finished: ok = false
        print("%-18s %s  battle %4d s  %.2f ms/step  sunk %d struck %d escaped %d lost %d" % [pr.name, "WIN " if r.get("victory", false) else "----", int(sim.t), float(Time.get_ticks_msec() - t0) / steps, r.get("sunk", []).size(), r.get("struck", []).size(), r.get("escaped", []).size(), r.get("lost", []).size()])
    print("ALL FINISHED" if ok else "SOME DID NOT FINISH")
    get_tree().quit()
