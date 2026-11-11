extends Node
## A heavy salvo's shells falling together on one spot: one column that swells, not a stack of columns (the owner's
## report, 11 Nov 2026), and a near miss hard alongside a ship (its foam stays on the sea, not on her decks).
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_stack.tscn -- <dir>
var battle: Node
var frame := 0
var out := ""
var at := Vector2.ZERO
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	var S = preload("res://scripts/skirmish.gd"); var pr: Dictionary = S.PRESETS[0]
	GameData.pending = {"player": pr.player, "enemy": pr.enemy, "enemy_fac": pr.fac, "player_tech": S.ERA_TECH[pr.era], "enemy_tech": S.ERA_TECH[pr.era], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	frame += 1
	var sim = battle.sim
	if frame == 3:
		var f = sim.flag; battle.paused = false; sim.hold_fire = true
		for s in sim.ships: s.hold = true
		at = f.pos + Vector2(0, -260); battle.cam_free = true; battle.camera.position = f.pos + Vector2(0, -130); battle.camera.zoom = Vector2.ONE * 2.2
	if frame >= 6 and frame < 30 and frame % 4 == 2:   # six heavy shells within a few metres, a few frames apart
		sim.fx_splash(at + Vector2(randf() - 0.5, randf() - 0.5) * 16.0, 24.0)
		sim.fx_splash(sim.flag.pos + Vector2(10.0 + frame, sim.flag.d.B * 0.5 + 5.0).rotated(sim.flag.a), 18.0)   # hard alongside her
	if frame == 34: get_viewport().get_texture().get_image().save_png(out + "/stack_a.png")
	if frame == 60: get_viewport().get_texture().get_image().save_png(out + "/stack_b.png"); get_tree().quit()
