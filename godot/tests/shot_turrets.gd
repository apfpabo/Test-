extends Node
## Screenshot of an Iowa-type with her turrets trained abeam just after a broadside, to check superfiring and recoil.
var battle: Node
var frame := 0
func _ready() -> void:
    GameData.pending = {"player": ["bb_iowa", "ca_takao", "bb_bismarck"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
    frame += 1
    if frame == 2:
        for s in battle.sim.ships:
            if s.side == 0: print(s.rec.type, " levels: ", s.mounts.filter(func(m): return m.w.kind == "gun").map(func(m): return "%s@%d:%d" % [m.wid, int(m.slot.x), m.lvl]))
        var s = battle.sim.ships[0]; battle.cam_free = true; battle.camera.position = s.pos + Vector2(0, -60).rotated(s.a + PI / 2); battle.camera.zoom = Vector2.ONE * 3.2
        for m in s.mounts:
            if m.w.size == "H": m.ta = 0.18 if m.slot.x > 0 else 2.6
        battle.paused = true; battle.hud.visible = false
    if frame == 6:
        for m in battle.sim.ships[0].mounts: if m.w.size == "H": m.recoil = 1.0
    if frame == 9: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); get_tree().quit()
