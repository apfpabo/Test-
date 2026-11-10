extends Node
## Star shell over an enemy on a dark night: xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_star.tscn -- <dir>
var battle: Node
var f := 0
func _ready() -> void:
	seed(5); Settings.sensors = false
	GameData.pending = {"player": ["dd_fletcher"], "enemy": ["ca_hipper", "dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0,
		"weather": Weather.battle({"sea": 0, "fog": false, "night": true, "moon": 0.0})}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	f += 1
	var sim = battle.sim; var fl = sim.flag
	if f == 2:
		for x in sim.ships: if x.side == 1: x.pos = fl.pos + Vector2(300.0 * sim.ships.find(x), -3200); x.throttle = 0; x.v = 0.0; x.lit_t = 99.0
		battle.speed_i = 0; battle.cam_free = true; sim.hold_fire = true
	if f > 2:
		for x in sim.ships: x.hull = x.max_hull; x.star_t = 99.0 if f != 31 else 0.0; if x.side == 1: x.throttle = 0; x.lit_t = 99.0
		battle.camera.position = fl.pos + Vector2(200, -1700); battle.camera.zoom = Vector2.ONE * 0.22
	if f == 30: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/star_before.png")
	if f == 31: sim.flares.clear(); sim.fire_star(fl, fl.pos + Vector2(350, -3150)); sim.flares[-1].t = 0.5
	if f == 70: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/star_after.png")
	if f == 72: get_tree().quit()
