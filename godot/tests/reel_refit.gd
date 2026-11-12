extends Node
## A Reels clip of the refit (the owner's request, 12 Nov 2026): an Iowa-type in a harbour's yard. Guns are tried in
## her turrets (an 18-inch triple forward; a 20-inch twin aft, which the yard will not pass for weight; a 15-inch
## quadruple there instead), her secondaries and light AA are changed, the weight ledger answering each choice, the
## refit is confirmed; then the refitted ship in a gun action. Upright like the battle clips.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 30 \
##     --write-movie <out.avi> res://tests/reel_refit.tscn -- [seconds] [shots dir]
const UI_SCALE := 1.12   # the harbour panel is 960 wide: at this it fills the upright frame
const CUT := 7.6         # into the action
var map: Node
var battle: Node
var port: Dictionary
var s: Dictionary
var t := 0.0
var f := 0
var length := 14.0
var shots := ""
var done := {}
var scroll_to := -1.0
var cam := Vector2.ZERO
var bf := 0
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: length = float(a[0])
	if a.size() > 1: shots = a[1]
	seed(5); Settings.sensors = false
	get_tree().root.content_scale_factor = UI_SCALE   # the interface larger, so it reads on a phone
	Campaign.new_game("commission"); var G: Dictionary = Campaign.G
	for x in Campaign.C.TECH: if not G.tech.has(x.id): G.tech.append(x.id)
	G.credits = 900000
	s = Campaign.new_ship("bb_iowa", "Resolute", "player", G.tech); G.fleet = [s]; G.crew = Campaign.crew_need()
	for p in G.ports: if p.name == "Calder Roads": port = p
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	Sfx.music("")
func _once(k: String, at: float) -> bool:
	if t >= at and not done.has(k): done[k] = true; return true
	return false
func _plan() -> Array: return map.refit_plan.get(s.id, s.fit.duplicate())
func _pick(slots: Array, wid: String, look: String, below: float) -> void:
	var pl: Array = _plan()
	for i in slots: pl[i] = wid
	map.refit_plan[s.id] = pl; map.refit_sel = int(slots[0]); map._render_port(); _look(look, below)
func _process(d: float) -> void:
	f += 1
	if battle == null and f == 3:
		if map.panel_open: map.close_panel()
		map.open_port(port); map.port_tab = "refit"; map.refit_idx = 0; map.refit_sel = 0; map._render_port()
	if f < 5: return
	t += d
	if battle == null:
		if _once("a0", 0.2): _look("Resolute ·", 300.0)                                   # her plan
		if _once("b", 1.3): _pick([0], "g460", "Resolute ·", 300.0)                       # an 18-inch triple forward
		if _once("c", 2.5): _pick([2], "g510t", "WEIGHTS", 1100.0)                         # a 20-inch twin aft: far too heavy
		if _once("c2", 3.7): _pick([2], "g381q", "WEIGHTS", 1100.0)                        # a 15-inch quadruple there instead
		if _once("d", 4.8): _pick([3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "g76", "WEIGHTS", 1100.0)   # 76 mm rapid DP for the 5-inch twins
		if _once("e", 5.8): _pick([13, 14, 15, 16, 17, 18], "ciws", "WEIGHTS", 1100.0)    # gatlings for the Bofors
		if _once("g", 6.8):                                                                 # confirmed
			map.apply_refit(s, _plan()); map.refit_plan.erase(s.id); map._toast("%s refitted." % s.name); map._render_port(); _look("WEIGHTS", 1100.0)
		if scroll_to >= 0.0 and is_instance_valid(map._panel_scroll):
			var sb: ScrollContainer = map._panel_scroll
			var mx: float = sb.get_v_scroll_bar().max_value - sb.size.y
			sb.scroll_vertical = int(lerpf(float(sb.scroll_vertical), clampf(scroll_to, 0.0, mx), 0.12))
		if t >= CUT: _to_sea()
	else: _sea(d)
	if shots != "":
		for k in [[1.0, "1"], [2.0, "2"], [3.2, "3"], [4.4, "4"], [6.4, "5"], [7.3, "6"], [9.0, "7"], [11.5, "8"], [13.5, "9"]]:
			if _once("shot" + k[1], k[0]): get_viewport().get_texture().get_image().save_png("%s/rf_%s.png" % [shots, k[1]])
	if t >= length: get_tree().quit()
## Scroll the page so the first control whose text begins with `txt` sits `below` pixels from the top of the view.
func _look(txt: String, below: float) -> void:
	for i in 3: await get_tree().process_frame   # after the page has been redrawn and put back where it was
	if battle != null or not is_instance_valid(map._panel_scroll): return
	var sb: ScrollContainer = map._panel_scroll
	var hit: Control = _find(sb, txt)
	if hit != null: scroll_to = float(sb.scroll_vertical) + (hit.global_position.y - sb.global_position.y) - below / UI_SCALE
func _find(n: Node, txt: String) -> Control:
	for c in n.get_children():
		if (c is Label or c is Button) and String(c.text).begins_with(txt) and c.is_visible_in_tree(): return c
		var r = _find(c, txt)
		if r != null: return r
	return null

# ------------------------------------------------------------------ the refitted ship in action
func _to_sea() -> void:
	get_tree().root.content_scale_factor = 1.0
	var G: Dictionary = Campaign.G
	var mine: Array = [s, Campaign.new_ship("dd_gearing", "Starling", "player", G.tech), Campaign.new_ship("dd_gearing", "Harrow", "player", G.tech)]
	var theirs: Array = [Campaign.new_ship("bb_bismarck", null, "directorate", ["radar"]), Campaign.new_ship("ca_hipper", null, "directorate", ["radar"]), Campaign.new_ship("dd_narvik", null, "directorate", ["radar"])]
	GameData.pending = {"quiet": true, "player_recs": mine, "enemy_recs": theirs, "enemy_fac": "directorate", "player_tech": G.tech, "enemy_tech": ["radar"], "islands": 0, "weather": Weather.battle({"sea": 1, "fog": false, "night": false, "moon": 0.5})}
	map.queue_free()
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
	Sfx.music("")
func _sea(d: float) -> void:
	bf += 1
	var sim = battle.sim
	if bf == 2:   # the lines broadside to broadside, already in range and the shooting started
		var me: Array = sim.ships.filter(func(x): return x.side == 0); var them: Array = sim.ships.filter(func(x): return x.side == 1)
		var c := Vector2(12000, 12000); var up := -PI / 2
		for i in me.size(): me[i].pos = c + Vector2(1700, i * 520.0); me[i].a = up; me[i].v = 9.0; me[i].throttle = 3
		for i in them.size(): them[i].pos = c + Vector2(-1700, i * 520.0 - 250.0); them[i].a = up; them[i].v = 9.0; them[i].throttle = 3
		sim.flag = null
		battle.hud.visible = false; battle.speed_i = 1; battle.cam_free = true; battle.set_clean(true)
		var n := 0
		while n < 1500 and not sim.finished: sim.step(0.02); n += 1; if n % 3 == 0: sim.fx(0.06)
		cam = _ship_of(s).pos
	if bf < 3: return
	var ts: float = t - CUT
	var me = _ship_of(s); var foe = null
	for x in sim.ships: if x.side == 1 and x.alive and (foe == null or x.d.L > foe.d.L): foe = x
	var want: Vector2 = cam; var z := 2.5
	if ts < 3.2 and me != null: want = me.pos + Vector2.from_angle(me.a) * 30.0; z = 2.4 + 0.06 * ts      # on her, her new guns firing
	elif foe != null: want = foe.pos; z = 2.2 + 0.05 * (ts - 3.2)                                          # her shells arriving
	var fresh: bool = absf(ts - 3.2) < d * 1.5 or bf == 3
	cam = want if fresh else cam.lerp(want, 0.08)
	battle.camera.position = cam; battle.camera.zoom = Vector2.ONE * z
func _ship_of(rec: Dictionary):
	for x in battle.sim.ships: if x.rec == rec: return x
	return null
