extends Node
## Close-up of ship art: godot --path godot res://tests/shot_art.tscn -- <out.png> <zoom> <design,design,...> [heading degrees] [metres ahead of amidships]
## The designs are lined up side by side with turrets trained ahead and aft, paused, HUD hidden.
var battle: Node
var frame := 0
var args: PackedStringArray
func _ready() -> void:
    args = OS.get_cmdline_user_args()
    var ids: Array = Array(args[2].split(",")) if args.size() > 2 else ["bb_iowa", "bb_yamato", "bb_bismarck"]
    GameData.pending = {"player": ids, "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
    frame += 1
    if frame == 2:
        var sim = battle.sim; var hd := deg_to_rad(float(args[3]) if args.size() > 3 else -90.0)
        var mine: Array = sim.ships.filter(func(s): return s.side == 0)
        var gap := 0.0; for s in mine: gap = maxf(gap, s.d.B + 14.0)
        for i in mine.size():
            var s = mine[i]; s.a = hd; s.pos = Vector2(0, 0) + Vector2.from_angle(hd + PI / 2) * (i - (mine.size() - 1) / 2.0) * gap
            s.v = 0.0
            for m in s.mounts: m.ta = 0.0 if m.slot.x > 0 else PI if m.slot.y == 0 else float(m.slot.arcs[0][0])
        for s in sim.ships: if s.side == 1: s.pos = Vector2(9000, 9000)
        battle.cam_free = true; battle.camera.position = Vector2.from_angle(hd) * (float(args[4]) if args.size() > 4 else 0.0); battle.camera.zoom = Vector2.ONE * float(args[1] if args.size() > 1 else "2.5")
        battle.paused = true; battle.hud.visible = false
    if frame == 8: get_viewport().get_texture().get_image().save_png(args[0]); get_tree().quit()
