extends Node
## Sonar pings running out, the echo off a dived boat, and the radar and sonar menu.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_sonar.tscn -- <dir>
var battle: Node
var f := 0
var out := ""
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}; Settings.sensors = true
    GameData.pending = {"player": ["dd_fletcher", "dd_fletcher"], "enemy": ["ss_vii"], "enemy_fac": "directorate", "player_tech": ["radar", "sonar"], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/sonar_%s.png" % [out, n])
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim; var dd = sim.ships[0]; var boat = sim.ships[2]
    if f == 2:
        battle.speed_i = 1; battle.cam_free = true; sim.hold_fire = true
        for s in sim.ships: s.ai_off = true
        boat.pos = dd.pos + Vector2(900, -500); boat.dive = 1.0; boat.want_dive = true; boat.v = 1.0; dd.ping_t = 0.3; sim.ships[1].sonar_on = false
        battle.camera.position = dd.pos + Vector2(450, -250); battle.camera.zoom = Vector2.ONE * 0.42
    if f > 2: boat.want_dive = true
    if f == 40: _shot("ping_out")
    if f == 75: _shot("echo")
    if f == 110: _shot("held")
    if f == 112: battle.camera.zoom = Vector2.ONE * 1.6; battle.camera.position = dd.pos
    if f == 116: battle._ship_menu(dd, Vector2(720, 430))
    if f == 122: _shot("menu"); get_tree().quit()
