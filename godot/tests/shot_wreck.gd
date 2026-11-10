extends Node
## Heavy damage close up: gashes, a bite out of the side, wrecked mounts, wreckage flying and afloat.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_wreck.tscn -- <dir> [design]
var battle: Node
var f := 0
func _ready() -> void:
	var a := OS.get_cmdline_user_args(); seed(6)
	GameData.pending = {"player": [a[1] if a.size() > 1 else "ca_baltimore"], "enemy": ["dd_narvik"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(_d: float) -> void:
	f += 1
	var sim = battle.sim; var s = sim.ships[0]
	if f == 2:
		for o in sim.ships: if o.side == 1: o.pos = s.pos + Vector2(9000, 9000)
		battle.cam_free = true; battle.camera.position = s.pos; battle.camera.zoom = Vector2.ONE * 4.0; battle.hud.visible = false; battle.speed_i = 0
		s.throttle = 3; s.v = 9.0
	if f in [6, 14, 22, 30, 38, 46]:   # heavy shells along her length, two of them on the deck edge
		var x: float = [-0.3, -0.12, 0.05, 0.2, 0.33, -0.2][[6, 14, 22, 30, 38, 46].find(f)] * s.d.L
		var y: float = [0.0, 0.9, -0.3, -0.95, 0.2, 0.5][[6, 14, 22, 30, 38, 46].find(f)] * sim.hull_half(s.d, x)
		var wp: Vector2 = sim.world_pt(s, x, y)
		sim.mark_hit(s, wp, 3.0, true); sim.fx_boom(wp, 14.0, 0.7); s.hull -= s.max_hull * 0.1
	if f == 34: for m in s.mounts: if m.w.kind == "gun" and m.slot.y != 0 and not m.dead: m.dead = true; sim.mark_hit(s, sim.world_pt(s, m.slot.x, m.slot.y), 0.5, false); break
	battle.camera.position = s.pos
	if f == 50: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/wreck_a.png")
	if f == 110: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/wreck_b.png"); get_tree().quit()
