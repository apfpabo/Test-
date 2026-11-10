extends Node
## Shell splashes of each calibre and a depth-charge pattern, close up, at three moments.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_splash.tscn -- <dir>
var battle: Node
var f := 0
var out := ""
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    GameData.pending = {"player": ["dd_fletcher"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim; var s = sim.ships[0]
    if f == 2:
        sim.ships[1].pos = Vector2(2000, 2000); s.pos = Vector2(12000, 11000); s.a = 0.0; s.v = 8.0; s.throttle = 2
        battle.hud.visible = false; battle.speed_i = 0; battle.cam_free = true; battle.camera.position = s.pos + Vector2(60, 60); battle.camera.zoom = Vector2.ONE * 2.6
    if f == 30:
        for i in 4: sim.fx_splash(s.pos + Vector2(-140 + i * 95, -95), [5.0, 9.0, 15.0, 24.0][i])
        sim.drop_dcs(s)
    if f == 30 + 16: sim.fx_splash(s.pos + Vector2(40, 150), 24.0); sim.fx_splash(s.pos + Vector2(170, 130), 15.0)
    for t in [3, 6, 10, 38, 50, 75, 110, 150, 200]:
        if f == 30 + t: get_viewport().get_texture().get_image().save_png("%s/splash_%03d.png" % [out, t])
    if f == 236: for i in 6: sim.fx_splash(s.pos + Vector2(-300 + i * 110, -220 + (i % 2) * 60), 5.0 + (i % 3) * 2.0)
    if f == 240: battle.camera.zoom = Vector2.ONE * 0.35
    if f == 262: get_viewport().get_texture().get_image().save_png("%s/splash_far.png" % out)
    if f == 266: get_tree().quit()
