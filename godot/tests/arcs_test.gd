extends Node
## Prints each gun mount's clear arc and saves a picture of ships with every turret ordered to train dead astern.
var battle: Node
var f := 0
func _ready() -> void:
    GameData.pending = {"player": ["bb_iowa", "bb_bismarck", "cl_cleveland", "dd_fletcher", "ca_takao"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
    f += 1
    if f == 2:
        var sim = battle.sim
        for s in sim.ships:
            if s.side != 0: continue
            var desc := []
            for m in s.mounts:
                if m.w.kind != "gun": continue
                var n := 0
                for c in m.clear: n += c
                desc.append("%s@%d,%d:%d°" % [m.wid, int(m.slot.x), int(m.slot.y), n * 2])
            print(s.rec.type, "  ", ", ".join(desc))
        # line the ships up side by side, bows up, close together, and order every gun to bear dead astern then abeam
        var i := 0
        for s in sim.ships:
            if s.side != 0: continue
            s.pos = Vector2(10000 + i * 60, 10000); s.a = -PI / 2; s.v = 0; i += 1
            for m in s.mounts: if m.w.kind == "gun": m.ta = sim.mount_arc(m, PI * 0.92 if m.slot.y >= 0 else -PI * 0.92).y
        battle.cam_free = true; battle.camera.position = Vector2(10120, 9930); battle.camera.zoom = Vector2.ONE * 5.5; battle.paused = true; battle.hud.visible = false
        sim.flag = null
    if f == 8: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); get_tree().quit()
