extends Node
## A torpedo's burst against a ship's side (it must stand over her, not under), a submerged boat's track, and the
## landing pattern astern of a carrier.  xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_wash.tscn -- <dir>
var battle: Node
var f := 0
var out := ""
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
    GameData.pending = {"player": ["ss_gato", "cv_essex"], "enemy": ["ao_t2"], "enemy_fac": "directorate", "player_tech": ["radar"], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/wash_%s.png" % [out, n])
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim; var sub = sim.ships[0]; var cv = sim.ships[1]; var e = sim.ships[2]
    if f == 2:
        battle.set_clean(true); battle.speed_i = 1; battle.cam_free = true; sim.hold_fire = true
        for s in sim.ships: s.ai_off = true
        e.pos = sub.pos + Vector2(0, -4000); e.god = false; sub.want_dive = true; sub.dive = 1.0; sub.throttle = 3; cv.pos = sub.pos + Vector2(3000, 0); cv.throttle = 3
        sim.launch_strike(cv, e)
    if f > 2 and f < 400: sub.want_dive = true
    if f == 200: battle.camera.position = sub.pos - Vector2.from_angle(sub.a) * 60.0; battle.camera.zoom = Vector2.ONE * 4.0
    if f == 203: _shot("sub_track")
    if f == 204:   # a torpedo into the tanker's side
        sim.torps.append({"pos": sim.world_pt(e, 0.0, 60.0), "a": e.a - PI / 2, "speed": 20.0, "life": 30.0, "dmg": 300, "side": 0, "homing": false, "arm": 0.0})
        battle.camera.position = e.pos; battle.camera.zoom = Vector2.ONE * 3.2
    if [30, 40, 50, 65, 100].has(f - 204): _shot("torp_%d" % (f - 204))
    if f == 320:
        for q in sim.air: q.state = "land"; q.up = q.n; q.dk = 0; q.ops = 0; q.pos = sim.world_pt(cv, -600.0, 100.0)
        cv.deck_ops.clear(); cv.deck_t = 0.0
    if f == 320 + 330: battle.camera.position = sim.world_pt(cv, -260.0, 0.0); battle.camera.zoom = Vector2.ONE * 1.5
    if f == 320 + 333: _shot("pattern")
    if f == 320 + 336: get_tree().quit()
