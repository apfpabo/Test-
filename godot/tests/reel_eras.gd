extends Node
## A clip with no interface (the owner's request, 13 Nov 2026): one ship held in the middle of the screen, firing her
## guns (one shot, then a broadside), replaced by her successor from each era in turn, Era I to Era IV.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
##     --write-movie <out.avi> res://tests/reel_eras.tscn        (tools/make_eras.sh <dir> does it and makes the MP4)
const LINES := [
	["dd_fletcher", "ddg_adams", "ddg_burke", "ddg_zumwalt"],          # Tidewater's destroyers, Era I to IV (four ships are enough: the owner)
]
const HOLD := 5.0    # seconds a ship
const FADE := 0.3
var battle: Node
var order: Array = []
var idx := -1
var t := 0.0
var ship = null
var fired := 0
var shade: ColorRect
var tech: Array
func _ready() -> void:
	for l in LINES: order.append_array(l)
	seed(7); Settings.sensors = false
	Weather.force = {"sea": 1, "fog": false, "night": false, "moon": 0.5}
	tech = preload("res://scripts/skirmish.gd").ERA_TECH[4]
	GameData.pending = {"quiet": true, "player": [order[0]], "enemy": ["fr_liberty"], "enemy_fac": "directorate", "player_tech": tech, "enemy_tech": [], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
	var cl := CanvasLayer.new(); cl.layer = 50; add_child(cl)
	shade = ColorRect.new(); shade.color = Color(0.02, 0.07, 0.09, 1.0); shade.set_anchors_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(shade)
func _take(i: int) -> void:
	var sim = battle.sim; var at := Vector2(sim.AW * 0.5, sim.AH * 0.5)
	if ship != null: battle.remove_view(ship); sim.despawn(ship)
	ship = sim.spawn(order[i], 0, at, 0.0, tech); battle._add_view(ship); sim.flag = ship
	ship.ai_off = true; ship.hold = true; ship.god = true
	for m in ship.mounts: m.ta = 0.0 if m.slot.x > 0 else PI
	fired = 0; t = 0.0
func _process(d: float) -> void:
	var sim = battle.sim
	if sim == null or sim.flag == null: return
	if idx < 0:
		Sfx.music(""); battle.hud.visible = false; battle.set_clean(true); battle.cam_free = true; sim.hold_fire = true
		for s in sim.ships:
			s.ai_off = true; s.hold = true; s.god = true
			if s.side == 1: s.pos = Vector2(sim.AW - 300.0, 300.0)
		ship = sim.flag; idx = 0; _take(0)
	t += d
	if t >= HOLD:
		idx += 1
		if idx >= order.size(): get_tree().quit(); return
		_take(idx)
	shade.color.a = clampf(maxf(1.0 - t / FADE, (t - (HOLD - FADE)) / FADE), 0.0, 1.0)
	# she steams on, the camera with her, filling most of the screen whatever her length
	ship.v = 9.0
	var vw: float = get_viewport().get_visible_rect().size.x
	battle.camera.position = ship.pos; battle.camera.zoom = Vector2.ONE * (0.6 * vw / float(ship.d.L))
	# her guns train out on the port bow, and fire: one gun at 1.2 s, then a broadside from all of them at 2.9 s (the owner's cut)
	var aim: Vector2 = ship.pos + Vector2(900.0, -2400.0)
	for m in ship.mounts:
		if m.w.kind != "gun": continue
		var want: float = (aim - (ship.pos + Vector2(m.slot.x, m.slot.y).rotated(ship.a))).angle() - ship.a
		m.ta = lerp_angle(m.ta, want, clampf(d * 3.0, 0.0, 1.0)); m.out = minf(1.0, t / 0.8); m.quiet = 0.0
	if t >= 1.2 and fired == 0:
		fired = 1
		for m in ship.mounts: if m.w.kind == "gun": sim.fire_gun(ship, m, aim, m.w); break   # the one shot: her foremost mount
	if t >= 2.9 and fired == 1:
		fired = 2
		for m in ship.mounts: if m.w.kind == "gun": sim.fire_gun(ship, m, aim, m.w)
