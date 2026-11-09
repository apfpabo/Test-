extends Node
## An island close up and at default zoom: res://tests/shot_island.tscn -- <out dir>
var battle: Node
var f := 0
func _ready() -> void:
    GameData.pending = {"player": ["dd_fletcher"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 2}
    battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
    f += 1
    var out: String = OS.get_cmdline_user_args()[0]
    if f == 2:
        var is_ = battle.sim.islands[0]; battle.cam_free = true; battle.camera.position = is_.c; battle.camera.zoom = Vector2.ONE * 0.9; battle.hud.visible = false; battle.paused = true
    if f == 6: get_viewport().get_texture().get_image().save_png(out + "/island_close.png"); battle.camera.zoom = Vector2.ONE * 0.3
    if f == 10: get_viewport().get_texture().get_image().save_png(out + "/island_default.png"); get_tree().quit()
