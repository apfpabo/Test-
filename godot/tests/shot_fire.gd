extends Node
## A broadside close up: res://tests/shot_fire.tscn -- <out dir> [design] [zoom]. Saves frames just after firing.
var battle: Node
var f := 0
var args: PackedStringArray
func _ready() -> void:
    args = OS.get_cmdline_user_args()
    GameData.pending = {"player": [args[1] if args.size() > 1 else "dd_kclass"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim; var s = sim.ships[0]
    if f == 2:
        for o in sim.ships: if o.side == 1: o.pos = s.pos + Vector2.from_angle(s.a + PI / 2) * 2000.0
        battle.cam_free = true; battle.camera.position = s.pos; battle.camera.zoom = Vector2.ONE * (float(args[2]) if args.size() > 2 else 4.0)
        battle.hud.visible = false; battle.speed_i = 0
    if f == 4:
        var aim = s.pos + Vector2.from_angle(s.a + PI / 2) * 2000.0
        for m in s.mounts:
            if m.w.kind == "gun": m.ta = PI / 2 if m.slot.y >= 0 else -PI / 2; sim.fire_gun(s, m, aim, m.w)
    for k in [6, 12, 24, 40]:
        if f == k: get_viewport().get_texture().get_image().save_png(args[0] + "/fire_%02d.png" % k)
    if f == 41: get_tree().quit()
