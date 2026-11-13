extends Node
## A heavy splash through its life, and shells falling on one spot for fifteen seconds (the owner, 13 Nov 2026: the bowl
## grew without end, the column stood still, rays stuck out of the crown, the foam after looked crackled). Pictures at
## set moments of battle time. xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_splash_seq.tscn -- <dir>
var battle: Node
var out := ""
var t0 := -1.0
var next_shot := 0.0
var shots := [0.4, 1.2, 2.2, 3.5, 5.0, 8.0, 12.0, 16.0]
var bowl0 := 0.0
var light := 0.0   # a second argument: a light gun's splash of this size instead, faster (a destroyer firing on one point)
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1: light = float(OS.get_cmdline_user_args()[1]); shots = [0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4, 3.0, 4.0, 5.0, 6.0, 6.3, 6.6, 6.9, 7.2, 7.6, 8.0, 9.0, 10.0, 11.0]
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	GameData.pending = {"player": ["dd_fletcher"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	var sim = battle.sim
	if sim == null or sim.flag == null: return
	if t0 < 0.0:
		for s in sim.ships: s.hold = true; s.ai_off = true
		sim.hold_fire = true
		var at: Vector2 = sim.flag.pos + Vector2(0, -400)
		battle.cam_free = true; battle.camera.position = at; battle.camera.zoom = Vector2.ONE * (3.0 if light <= 0.0 else 5.0); t0 = sim.t; set_meta("at", at)
	var el: float = sim.t - t0
	if el >= next_shot and el < (14.0 if light <= 0.0 else 6.0):   # a 16-inch shell on the same spot every second and a half
		sim.fx_splash(get_meta("at") + Vector2(randf() - 0.5, randf() - 0.5) * (12.0 if light <= 0.0 else light * 1.6), sim.shell_splash({"mm": 406}, 3.4) if light <= 0.0 else light); next_shot += 1.5 if light <= 0.0 else 0.7
	var b = sim.splash_laces[0] if not sim.splash_laces.is_empty() else null
	if b != null and bowl0 == 0.0: bowl0 = b.size
	if not shots.is_empty() and el >= shots[0]:
		get_viewport().get_texture().get_image().save_png("%s/seq_%04.1f.png" % [out, shots[0]])
		if b != null: print("t %.1f  bowl %.1f (began %.1f)" % [shots[0], b.size, bowl0])
		shots.pop_front()
		if shots.is_empty(): get_tree().quit()
