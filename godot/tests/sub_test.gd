extends Node
## Submarine warfare check (headless): a destroyer with sonar and a nuclear boat with homing torpedoes against a
## submerged enemy boat. Prints whether the enemy was found, depth-charged and hit.
## godot --headless --path godot res://tests/sub_test.tscn
func _ready() -> void:
    var sim := BattleSim.new()
    var tech := ["homing", "sonar", "nuclear", "radar"]
    var mk = func(t: String, pal: String): var d: Dictionary = GameData.hulls[t]; return {"type": t, "name": t, "hullFrac": 1.0, "fit": BattleSim.default_fit(d, tech), "pal": pal}
    sim.setup([mk.call("dd_fletcher", "player"), mk.call("ssn_skipjack", "player")], [mk.call("ssn_november", "directorate")], tech, tech, 0)
    var foe: BattleSim.CShip = sim.ships.filter(func(s): return s.side == 1)[0]
    var mine = sim.ships.filter(func(s): return s.side == 0)
    foe.dive = 1.0; foe.want_dive = true; mine[1].dive = 1.0; mine[1].want_dive = true
    foe.pos = mine[0].pos + Vector2(1800, 300); sim.flag = mine[1]; sim.order = "engage"
    var hull0: float = foe.hull; var dcs := 0; var torps := 0
    for k in 30000:
        var n0 = sim.dcs.size(); var t0 = sim.torps.size()
        sim.step(0.02)
        if sim.dcs.size() > n0: dcs += 1
        if sim.torps.size() > t0: torps += 1
        if not foe.alive or sim.finished: break
    print("enemy boat detected: ", sim.detected_by(foe, 0) or not foe.alive, " · depth-charge drops ", dcs, " · torpedo launches ", torps, " · hull ", int(foe.hull), "/", int(hull0), " · sunk ", not foe.alive, " · t ", int(sim.t))
    get_tree().quit()
