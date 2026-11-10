extends Node
## Battles in weather and darkness: a night action, a storm by day and fog, each captured after the guns open.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_weather.tscn -- <dir> <night|storm|fog|dusk> [zoom]
var battle: Node
var f := 0
var args: PackedStringArray
func _ready() -> void:
    args = OS.get_cmdline_user_args()
    var kind: String = args[1] if args.size() > 1 else "night"
    var w: Dictionary = {"night": {"sea": 1, "fog": false, "night": true, "moon": 0.15}, "moon": {"sea": 0, "fog": false, "night": true, "moon": 1.0},
        "storm": {"sea": 3, "fog": false, "night": false, "moon": 0.5}, "fog": {"sea": 0, "fog": true, "night": false, "moon": 0.5}}[kind]
    GameData.pending = {"player": ["ca_baltimore", "dd_fletcher", "dd_fletcher"], "enemy": ["ca_hipper", "dd_narvik", "dd_narvik"], "enemy_fac": "directorate",
        "player_tech": ["radar"], "enemy_tech": [], "islands": 1, "weather": Weather.battle(w)}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim
    if f == 3:
        battle.speed_i = 3
        for i in sim.ships.size():   # start them closer, so the action opens soon
            var s = sim.ships[i]; if s.side == 1: s.pos.y += 4200.0
        if args.size() > 2: battle.camera.zoom = Vector2.ONE * float(args[2])
    if f == 500 or f == 900:
        get_viewport().get_texture().get_image().save_png("%s/wx_%s_%d.png" % [args[0], args[1] if args.size() > 1 else "night", f])
        print("t=%d visible enemies %d of %d" % [int(sim.t), sim.ships.filter(func(x): return x.side == 1 and sim.active(x) and sim.visible_to(x, 0)).size(), sim.ships.filter(func(x): return x.side == 1 and sim.active(x)).size()])
    if f == 902: get_tree().quit()
