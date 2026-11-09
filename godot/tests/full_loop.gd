extends Node
## End-to-end: new game, a raider encounter on the chart, the battle scene, and back to the chart's aftermath.
var f := 0
var out := ""
var stage := 0
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    if not has_meta("runner"):   # hand over to a runner parented to the root, which survives scene changes
        var n := Node.new(); n.set_script(get_script()); n.set_meta("runner", true); get_tree().root.add_child.call_deferred(n); set_process(false); return
    Campaign.new_game("commission")
    get_tree().change_scene_to_file.call_deferred("res://scenes/world_map.tscn")
func _process(_d: float) -> void:
    f += 1
    var scene := get_tree().current_scene
    if stage == 0 and f == 10:
        var P = Campaign.G.player; var r := Campaign.spawn_fleet("raiders", "raiders"); r.x = P.x + 8; r.y = P.y; r.route = null; r.cool = 0.0; P.cool = 0.0
        stage = 1
    if stage == 1 and f % 30 == 0: print("f ", f, " scene ", scene.name, " panel ", scene.get("panel_open"), " paused ", Campaign.paused, " fleets near ", Campaign.G.fleets.filter(func(x): return Campaign.mdist(x.x, x.y, Campaign.G.player.x, Campaign.G.player.y) < 40).map(func(x): return [x.name, int(Campaign.mdist(x.x, x.y, Campaign.G.player.x, Campaign.G.player.y)), x.cool]))
    if stage == 1 and f > 400: get_tree().quit()
    if stage == 1 and scene.panel_open and f > 14:
        get_viewport().get_texture().get_image().save_png(out + "/l_encounter.png")
        var fl = null
        for x in Campaign.G.fleets: if Campaign.mdist(x.x, x.y, Campaign.G.player.x, Campaign.G.player.y) < 20: fl = x
        scene._battle(fl); stage = 2; f = 100
    if stage == 2 and scene.name == "Battle" and f > 110:
        get_viewport().get_texture().get_image().save_png(out + "/l_battle.png")
        var sim = scene.sim; sim.flag = null
        while not sim.finished and sim.t < 7200: sim.step(0.02)
        stage = 3; f = 200
    if stage == 3 and f > 206:
        print("battle result ", scene.sim.result)
        Campaign.apply_battle(scene.sim); Campaign.show_aftermath = true; get_tree().change_scene_to_file("res://scenes/world_map.tscn"); stage = 4; f = 300
    if stage == 4 and f > 310:
        get_viewport().get_texture().get_image().save_png(out + "/l_after.png"); print("fleet now ", Campaign.G.fleet.map(func(s): return s.name + " %d%%" % int(s.hullFrac * 100))); get_tree().quit()
