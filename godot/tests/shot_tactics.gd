extends Node
## A screen formation, a smoke screen and a damaged ship's tags, as the player sees them:
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_tactics.tscn -- <dir>
var battle: Node
var f := 0
var out := ""
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]; seed(5); Settings.sensors = false
	GameData.pending = {"player": ["ca_baltimore", "dd_fletcher", "dd_fletcher", "cl_cleveland", "dd_fletcher", "dd_fletcher"], "enemy": ["ca_hipper", "dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
func _process(_d: float) -> void:
	f += 1
	var sim = battle.sim; var fl = sim.flag
	if f == 2:
		sim.order = "screen"; sim.hold_fire = true; battle.speed_i = 4; battle.cam_free = true
		for x in sim.ships: if x.side == 1: x.pos = fl.pos + Vector2(0, -7000); x.throttle = 0; x.v = 0.0
	if f > 2 and f < 400:
		fl.throttle = 2
		for x in sim.ships: if x.side == 1: x.hull = x.max_hull; x.throttle = 0
		battle.camera.position = fl.pos + Vector2.from_angle(fl.a) * 400.0; battle.camera.zoom = Vector2.ONE * 0.3
	if f == 150: _shot("tactics_screen")
	if f == 152: for x in sim.ships: if x.side == 0 and x.d.L < 150.0: sim.make_smoke(x, true)
	if f == 215: _shot("tactics_smoke")
	if f == 216:
		battle.speed_i = 0; var v = sim.ships[3]; v.eng = 0.35; v.list = 0.7; v.steer = 0.5; sim.ships[1].eng_out = 40.0; sim.ships[2].jam = 30.0; sim.ships[2].jam_r = 0.8
	if f > 216: battle.camera.position = sim.ships[3].pos; battle.camera.zoom = Vector2.ONE * 1.1
	if f == 260: _shot("tactics_damage")
	if f == 262: get_tree().quit()
