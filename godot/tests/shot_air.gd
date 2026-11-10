extends Node
## Aircraft and missiles close up: a carrier's strike outbound, then a missile salvo in flight.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_air.tscn -- <dir>
var battle: Node
var f := 0
var out := ""
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    GameData.pending = {"player": ["cv_essex", "ddg_adams", "cv_forrestal"], "enemy": ["ca_hipper"], "enemy_fac": "directorate", "player_tech": ["radar", "missiles", "jets"], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/air_%s.png" % [out, n])
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim
    if f == 2: battle.hud.visible = false; battle.speed_i = 1; battle.cam_free = true
    if f == 6:
        sim.ships[0].tech = []; sim.launch_strike(sim.ships[0], sim.ships[3]); sim.launch_strike(sim.ships[2], sim.ships[3])
        for m in sim.ships[1].mounts: if m.w.kind == "ssm": sim.fire_missile(sim.ships[1], m, sim.ships[3])
    if f > 20 and f < 60 and not sim.missiles.is_empty() and sim.missiles[0].delay <= 0 and not has_meta("m"):
        set_meta("m", f); battle.camera.position = sim.missiles[0].pos + Vector2.from_angle(sim.missiles[0].a) * 40; battle.camera.zoom = Vector2.ONE * 5.0
    if has_meta("m") and f == int(get_meta("m")) + 6: battle.paused = true
    if has_meta("m") and f == int(get_meta("m")) + 8:
        battle.camera.position = sim.missiles[0].pos; 
    if has_meta("m") and f == int(get_meta("m")) + 10: _shot("missiles"); battle.paused = false
    if f == 130 and not sim.air.is_empty(): battle.camera.position = sim.air[0].pos; battle.camera.zoom = Vector2.ONE * 3.0
    if f == 133: _shot("piston")
    if f == 134 and sim.air.size() > 6: battle.camera.position = sim.air[-1].pos; battle.camera.zoom = Vector2.ONE * 3.0
    if f == 137: _shot("jets")
    if f == 140: get_tree().quit()
