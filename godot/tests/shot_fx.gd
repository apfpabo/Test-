extends Node
## Effects showcase: a battleship's broadside, shells landing short and hitting, a burning cruiser, a destroyer at
## speed and a magazine going up, captured over a few seconds. Compare the two styles:
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_fx.tscn -- <out dir> <modern|classic> [zoom]
var battle: Node
var f := 0
var args: PackedStringArray
var bb; var ca; var dd; var tgt
func _ready() -> void:
    args = OS.get_cmdline_user_args()
    Settings.fx_modern = args.size() < 2 or args[1] != "classic"
    GameData.pending = {"player": ["bb_iowa", "dd_fletcher"], "enemy": ["ca_hipper", "dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [args[0], args[1] if args.size() > 1 else "modern", n])
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim
    if f == 2:
        bb = sim.ships[0]; dd = sim.ships[1]; ca = sim.ships[2]; tgt = sim.ships[3]
        for o in sim.ships: o.throttle = 0; o.v = 0.0
        bb.a = 0.0; bb.pos = Vector2(10000, 10000)
        ca.pos = bb.pos + Vector2(500, 260); ca.a = PI
        tgt.pos = bb.pos + Vector2(700, -320); tgt.a = 0.3
        dd.pos = bb.pos + Vector2(-260, 300); dd.a = 0.15; dd.v = dd.d.kn * BattleSim.KN; dd.throttle = 1.0
        for i in 3: sim.mark_hit(ca, ca.pos + Vector2((i - 1) * 50.0, 0).rotated(ca.a), 3.0, false)
        battle.cam_free = true; battle.camera.position = bb.pos + Vector2(250, 0); battle.camera.zoom = Vector2.ONE * (float(args[2]) if args.size() > 2 else 1.1)
        battle.hud.visible = false; battle.speed_i = 0
    if f == 40:   # the broadside, laid on the target
        for m in bb.mounts:
            if m.w.kind == "gun" and (m.w.size == "L" or m.w.size == "H"): m.ta = BattleSim.ang_diff((tgt.pos - bb.pos).angle(), bb.a); sim.fire_gun(bb, m, tgt.pos, m.w)
    if f == 44: _shot("1_broadside")
    if f == 46:   # what the shells do when they arrive: a straddle and two hits
        for i in 4: sim.fx_splash(tgt.pos + Vector2(randf_range(-160, 160), randf_range(-90, 90)), 6.0 * 3.4)
        sim.fx_boom(tgt.pos + Vector2(30, 0), 7 * 3.4, 0.6); sim.fx_boom(tgt.pos + Vector2(-50, 10), 7 * 2.3, 0.6)
    if f == 52: _shot("2_impacts")
    if f == 64: _shot("3_impacts_later")
    if f == 70: sim.detonate(tgt)
    if f == 74: _shot("4_detonation")
    if f == 90: _shot("5_detonation_later")
    if f == 92: battle.camera.position = dd.pos; battle.camera.zoom = Vector2.ONE * 3.0
    if f == 100: _shot("6_wake_close")
    if f == 101: battle.camera.position = ca.pos; battle.camera.zoom = Vector2.ONE * 2.5
    if f == 108: _shot("7_fires_close"); get_tree().quit()
