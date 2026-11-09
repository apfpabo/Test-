extends Node
## The flagship's damage display after hits on several subsystems: res://tests/shot_damage.tscn -- <out.png> [design] [menu]
var battle: Node
var f := 0
func _ready() -> void:
    var a := OS.get_cmdline_user_args()
    GameData.pending = {"player": [a[1] if a.size() > 1 else "bb_iowa"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
    f += 1
    var sim = battle.sim; var s = sim.ships[0]
    if f == 2:
        s.eng = 0.35; s.jam = 30.0; s.fc = 0.55; s.cf = 0.7; s.mag_fire = 20.0
        var guns = s.mounts.filter(func(m): return m.w.kind == "gun" and m.slot.y == 0)
        s.mag_x = guns[0].slot.x; if guns.size() > 2: s.flooded.append(guns[-1].slot.x); guns[-1].dead = true
        s.mounts[-1].dead = true
        battle.paused = true
    if f == 3 and OS.get_cmdline_user_args().size() > 2: battle.hud.toggle_menu()
    if f == 6: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); get_tree().quit()
