extends Node
## Test harness: runs a preset battle, fast-forwards it, saves screenshots and reports the result.
## godot --path godot res://tests/shot_battle.tscn -- <preset index> <out dir> [zoom]
var battle: Node
var frame := 0
var out := "/tmp"
var zooms := [0.3, 1.2]

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    var i := int(args[0]) if args.size() > 0 else 2
    out = args[1] if args.size() > 1 else "/tmp"
    var pr: Dictionary = preload("res://scripts/skirmish.gd").PRESETS[i]
    GameData.pending = {"player": pr.player, "enemy": pr.enemy, "enemy_fac": pr.fac, "player_tech": preload("res://scripts/skirmish.gd").ERA_TECH[pr.era], "enemy_tech": preload("res://scripts/skirmish.gd").ERA_TECH[pr.era], "islands": 2}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)

func _process(_d: float) -> void:
    frame += 1
    if frame == 2:
        battle.camera.zoom = Vector2.ONE * 2.0; battle.camera.position = battle.sim.ships[0].pos
    if frame == 3:
        get_viewport().get_texture().get_image().save_png(out + "/g_fresh.png")
        var t0 := Time.get_ticks_msec()
        battle.sim.flag = null
        for k in 9000: battle.sim.step(0.02); if k % 50 == 0: battle.sim.fx(0.1)
        battle.sim.flag = null
        for s in battle.sim.ships: if s.side == 0 and battle.sim.engageable(s): battle.sim.flag = s; break
        print("sim 9000 steps ms: ", Time.get_ticks_msec() - t0, "  battle t=", int(battle.sim.t), " finished=", battle.sim.finished)
        if battle.sim.flag: battle.camera.position = battle.sim.flag.pos
        battle.camera.zoom = Vector2.ONE * zooms[0]
    if frame == 40: get_viewport().get_texture().get_image().save_png(out + "/g_far.png"); battle.camera.zoom = Vector2.ONE * zooms[1]
    if frame == 80:
        get_viewport().get_texture().get_image().save_png(out + "/g_close.png")
        var t0 := Time.get_ticks_msec()
        while not battle.sim.finished and battle.sim.t < 7200: battle.sim.step(0.02); battle.sim.fx(0.0)
        print("result: ", battle.sim.result, " in ", Time.get_ticks_msec() - t0, " ms")
        get_tree().quit()
