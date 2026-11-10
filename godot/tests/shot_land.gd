extends Node
## Shells on an island: armour-piercing, high explosive and incendiary, just after they land and a few seconds on.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_land.tscn -- <dir>
var battle: Node
var f := 0
var c := Vector2.ZERO
func _ready() -> void:
	seed(3); Settings.sensors = false
	GameData.pending = {"player": ["dd_fletcher"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 3}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OS.get_cmdline_user_args()[0], n])
func _process(_d: float) -> void:
	f += 1
	var sim = battle.sim
	if f == 2:
		var is_: Dictionary = sim.islands[0]; c = is_.c
		for s in sim.ships: s.pos = c + Vector2(6000 if s.side else -6000, 6000); s.throttle = 0
		battle.hud.visible = false; battle.speed_i = 0; battle.cam_free = true; sim.hold_fire = true
	if f > 2: battle.camera.position = c; battle.camera.zoom = Vector2.ONE * 2.2
	if f == 20:
		for i in 3: sim.fx_land(c + Vector2(-150 + i * 20, -60 + i * 25), [1.0, 2.3, 3.4][i], "ap")
		for i in 3: sim.fx_land(c + Vector2(-20 + i * 30, -40 + i * 30), [1.0, 2.3, 3.4][i], "he")
		for i in 3: sim.fx_land(c + Vector2(120 + i * 25, -50 + i * 30), [1.0, 2.3, 3.4][i], "inc")
	if f == 30: _shot("land_a")
	if f == 110: _shot("land_b")
	if f == 112: get_tree().quit()
