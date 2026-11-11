extends Node
## Carrier flying and damage close up: machines taking off one by one, the air-wing pips, a landing, a holed deck,
## a listing ship with her hull torn open, and a ship going down.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_deck.tscn -- <dir>
var battle: Node
var f := 0
var out := ""
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
    GameData.pending = {"player": ["cv_essex", "bb_iowa", "ca_baltimore", "cv_forrestal"], "enemy": ["ca_hipper"], "enemy_fac": "directorate", "player_tech": ["radar"], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/deck_%s.png" % [out, n])
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim; var cv = sim.ships[0]; var bb = sim.ships[1]; var ca = sim.ships[2]; var e = sim.ships[4]; var cj = sim.ships[3]
    if f == 2:
        battle.speed_i = 1; battle.cam_free = true; sim.hold_fire = true; e.ai_off = true; e.god = true; e.pos = cv.pos + Vector2(0, -30000)
        for s in sim.ships: s.ai_off = true
    if f == 6: sim.launch_strike(cv, e); cj.tech = ["jets", "radar"]; sim.launch_strike(cj, e)
    if f == 100: battle.camera.position = cj.pos + Vector2.from_angle(cj.a) * 150.0; battle.camera.zoom = Vector2.ONE * 2.0
    if f == 103: _shot("jets")
    if f == 150: battle.camera.position = cv.pos + Vector2.from_angle(cv.a) * 120.0; battle.camera.zoom = Vector2.ONE * 3.0
    if f == 153: _shot("takeoff")
    if f == 154: battle.camera.zoom = Vector2.ONE * 1.2
    if f == 157: _shot("takeoff_wide")
    if f == 160:   # bring one group home to land
        for q in sim.air: q.state = "land"; q.up = q.n; q.dk = 0; q.ops = 0; q.pos = sim.world_pt(cv, -500.0, 60.0)
        cv.deck_ops.clear(); cv.deck_t = 0.0
    if f == 330: battle.camera.position = cv.pos - Vector2.from_angle(cv.a) * 120.0; battle.camera.zoom = Vector2.ONE * 2.6
    if f == 333: _shot("landing")
    if f == 334:   # the battleship torn open and listing to starboard
        seed(5)
        for i in 9: sim.mark_hit(bb, sim.world_pt(bb, -90.0 + i * 22.0, [9.0, -12.0, 3.0, 13.0, -6.0, 14.0, -13.0, 0.0, 11.0][i]), 3.0, true, 0.0)
        for i in 14: sim.mark_hit(bb, sim.world_pt(bb, 20.0 + i * 6.5, [10.0, -8.0, 12.0, -12.0, 6.0, -5.0, 13.0][i % 7]), 1.0 + 0.2 * (i % 3), true, 0.0)   # light shells: holes, not gashes
        bb.list = 0.8; bb.hull = bb.max_hull * 0.4
        battle.camera.position = bb.pos; battle.camera.zoom = Vector2.ONE * 4.0
    if f > 334 and f < 349: bb.list = 0.8
    if f == 340: _shot("list")
    if f == 341: battle.camera.zoom = Vector2.ONE * 6.5; battle.camera.position = sim.world_pt(bb, -40.0, 0.0)
    if f == 344: _shot("gash")
    if f == 345: battle.hud.visible = false; battle.camera.position = sim.world_pt(bb, 60.0, 0.0)
    if f == 348: _shot("list_close")
    if f >= 349 and f < 352: bb.list = -0.8; battle.camera.position = sim.world_pt(bb, -75.0, 0.0)
    if f == 351: _shot("list_close2"); battle.hud.visible = true
    if f == 352:
        ca.list = -0.4; sim.damage(ca, ca.hull + 1.0, "resolved"); sim.finished = false
        battle.camera.position = ca.pos; battle.camera.zoom = Vector2.ONE * 3.0
    if f == 352 + 240: _shot("sinking_4s")
    if f == 352 + 600: _shot("sinking_10s")
    if f == 352 + 606: get_tree().quit()
