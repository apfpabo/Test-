extends Node
## Shells in flight and light-gun tracer close up: xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_gunfire.tscn -- <dir> [night]
var battle: Node
var f := 0
var args: PackedStringArray
func _ready() -> void:
	args = OS.get_cmdline_user_args()
	GameData.pending = {"player": ["bb_iowa"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": ["ciws"], "enemy_tech": [], "islands": 0}
	if args.size() > 1: GameData.pending.weather = Weather.battle({"sea": 0, "fog": false, "night": true, "moon": 0.6})
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	f += 1
	var sim = battle.sim; var s = sim.ships[0]
	var out: Vector2 = Vector2.from_angle(s.a + PI / 2)
	if f == 2:
		for o in sim.ships: if o.side == 1: o.pos = s.pos + out * 2600.0
		battle.cam_free = true; battle.camera.position = s.pos + out * 260.0; battle.camera.zoom = Vector2.ONE * 1.6
		battle.hud.visible = false; battle.speed_i = 0
	if f >= 4 and f < 80:   # every light gun on the engaged side keeps up a stream at a point off the beam
		for m in s.mounts:
			if (m.w.kind == "aa" or m.w.kind == "ciws") and (f + int(m.slot.x)) % 3 == 0:
				var p: Vector2 = sim.world_pt(s, m.slot.x, m.slot.y)
				if (p - s.pos).dot(out) > 0.0: sim.aa_shot(s, m, p, s.pos + out * 700.0 + Vector2.from_angle(s.a) * float(m.slot.x) * 2.0)
	if f == 20:
		for m in s.mounts: if m.w.kind == "gun": m.ta = PI / 2 if m.slot.y >= 0 else -PI / 2; sim.fire_gun(s, m, s.pos + out * 2600.0, m.w)
	if f == 34: get_viewport().get_texture().get_image().save_png(args[0] + "/gunfire_a.png")
	if f == 44: battle.camera.position = s.pos + out * 500.0; battle.camera.zoom = Vector2.ONE * 3.0
	if f == 50: get_viewport().get_texture().get_image().save_png(args[0] + "/gunfire_b.png")
	if f == 51: get_tree().quit()
