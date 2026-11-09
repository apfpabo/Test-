extends Node
## Battle wakes: a battleship and a destroyer at speed, the destroyer turning, captured close and from farther off.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_bwake.tscn -- <out dir> [designs...]
var battle: Node
var f := 0
var args: PackedStringArray
func _ready() -> void:
    args = OS.get_cmdline_user_args()
    var mine: Array = Array(args.slice(1)) if args.size() > 1 else ["bb_iowa", "dd_fletcher"]
    GameData.pending = {"player": mine, "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/wake_%s.png" % [args[0], n])
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim
    if f == 2:
        sim.ships[-1].pos = Vector2(2000, 2000)
        for i in sim.ships.size() - 1:
            var s = sim.ships[i]; s.pos = Vector2(12000, 11000 + i * 260); s.a = -0.2; s.v = s.d.kn * BattleSim.KN; s.throttle = 1.0; s.trail.clear()
        battle.hud.visible = false; battle.speed_i = 2; battle.cam_free = true
    if f > 2 and f < 500:
        sim.order = "hold"
        for i in sim.ships.size() - 1: sim.ships[i].throttle = 1.0
        sim.player_rudder = 0.0
        if sim.ships.size() > 2: sim.ships[1].rudder = 0.6 if f > 200 else 0.0
    if f == 420: battle.camera.position = sim.ships[0].pos - Vector2.from_angle(sim.ships[0].a) * 120; battle.camera.zoom = Vector2.ONE * 1.6
    if f == 424: _shot("close")
    if f == 430: battle.camera.position = sim.ships[0].pos - Vector2.from_angle(sim.ships[0].a) * 300 + Vector2(0, 150); battle.camera.zoom = Vector2.ONE * 0.6
    if f == 434: _shot("mid")
    if f == 440 and sim.ships.size() > 2: battle.camera.position = sim.ships[1].pos; battle.camera.zoom = Vector2.ONE * 2.4
    if f == 444: _shot("dd"); get_tree().quit()
