extends Node
## Close-ups of capital ships under way in the battle line preset (sterns, wakes, smoke), for checking artefacts.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_stern.tscn -- <dir> [preset]
var battle: Node
var frame := 0
var out := ""
func _ready() -> void:
	var a := OS.get_cmdline_user_args(); out = a[0]
	var S = preload("res://scripts/skirmish.gd"); var pr: Dictionary = S.PRESETS[int(a[1]) if a.size() > 1 else 2]
	GameData.pending = {"player": pr.player, "enemy": pr.enemy, "enemy_fac": pr.fac, "player_tech": S.ERA_TECH[pr.era], "enemy_tech": S.ERA_TECH[pr.era], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	frame += 1
	var sim = battle.sim
	if frame == 3: sim.flag.throttle = 4; battle.camera.zoom = Vector2.ONE * 2.2
	if frame > 3:
		var f = sim.flag; battle.cam_free = true; battle.camera.position = f.pos - Vector2.from_angle(f.a) * f.d.L * 0.45; battle.camera.zoom = Vector2.ONE * 3.0
	for k in [[120, "stern_1"], [200, "stern_2"]]:
		if frame == k[0]: get_viewport().get_texture().get_image().save_png(out + "/" + k[1] + ".png")
	if frame == 202: get_tree().quit()
