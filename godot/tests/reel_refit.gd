extends Node
## A Reels clip of the refit (the owner's request, 12 Nov 2026): an Iowa-type in a harbour's yard; a heavier gun picked
## for her forward turret, her secondaries and light AA changed, the weight ledger answering each choice, the refit
## confirmed; then ship systems fitted down the page. Upright like the battle clips, the interface as it is played.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 30 \
##     --write-movie <out.avi> res://tests/reel_refit.tscn -- [seconds] [shots dir]
var map: Node
var port: Dictionary
var s: Dictionary
var t := 0.0
var f := 0
var length := 14.0
var shots := ""
var done := {}
var scroll_to := -1.0
const UI_SCALE := 1.12   # the harbour panel is 960 wide: at this it fills the upright frame
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
func _pick(slots: Array, wid: String) -> void:
	var pl: Array = _plan()
	for i in slots: pl[i] = wid
	map.refit_plan[s.id] = pl; map.refit_sel = int(slots[0]); map._render_port()
func _process(d: float) -> void:
	f += 1
	if f == 3:
		if map.panel_open: map.close_panel()
		map.open_port(port); map.port_tab = "refit"; map.refit_idx = 0; map.refit_sel = 0; map._render_port()
	if f < 5: return
	t += d
	if _once("a0", 0.3): _look("Resolute ·", 300.0)                                  # her plan
	if _once("a", 1.6): map.refit_sel = 0; map._render_port(); _look("Resolute ·", 300.0)   # the forward turret
	if _once("b", 3.0): _pick([0], "g460"); _look("Resolute ·", 300.0)                # an 18-inch triple in it
	if _once("c", 5.0): _pick([3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "g76"); _look("Medium gun", 520.0)   # rapid 76 mm DP for the 5-inch twins
	if _once("d", 6.6): _pick([13, 14, 15, 16, 17, 18], "ciws"); _look("WEIGHTS", 900.0)   # close-in gatlings for the Bofors, and what it all weighs
	if _once("e", 8.2):                                                               # confirmed
		map.apply_refit(s, _plan()); map.refit_plan.erase(s.id); map._toast("%s refitted." % s.name); map._render_port(); _look("WEIGHTS", 900.0)
	if _once("f", 9.0): _look("SHIP SYSTEMS", 120.0)                                 # down to the ship systems
	if _once("g", 10.4): _fit("fc")
	if _once("h", 11.4): _fit("radar")
	if _once("i", 12.4): _fit("eng")
	if scroll_to >= 0.0 and is_instance_valid(map._panel_scroll):
		var sb: ScrollContainer = map._panel_scroll
		var mx: float = sb.get_v_scroll_bar().max_value - sb.size.y
		sb.scroll_vertical = int(lerpf(float(sb.scroll_vertical), clampf(scroll_to, 0.0, mx), 0.1))
	if shots != "":
		for k in [[2.0, "1"], [4.0, "2"], [7.6, "3"], [8.6, "4"], [11.0, "5"], [13.6, "6"]]:
			if _once("shot" + k[1], k[0]): get_viewport().get_texture().get_image().save_png("%s/rf_%s.png" % [shots, k[1]])
	if t >= length: get_tree().quit()
## Scroll the page so the first control whose text begins with `txt` sits `below` pixels from the top of the view.
func _look(txt: String, below: float) -> void:
	await get_tree().process_frame
	var sb: ScrollContainer = map._panel_scroll
	var hit: Control = _find(sb, txt)
	if hit != null: scroll_to = float(sb.scroll_vertical) + (hit.global_position.y - sb.global_position.y) - below / UI_SCALE
func _find(n: Node, txt: String) -> Control:
	for c in n.get_children():
		if (c is Label or c is Button) and String(c.text).begins_with(txt) and c.is_visible_in_tree(): return c
		var r = _find(c, txt)
		if r != null: return r
	return null
func _fit(k: String) -> void:
	var u: Dictionary = BattleSim.UPGRADES[k]; var lvl: int = int(s.get("up", {}).get(k, 0))
	if not s.has("up"): s.up = {}
	var d: Dictionary = GameData.hulls[s.type]
	var cost := int(round(float(d.price) * float(u.cost) * (1.0 if lvl == 0 else 1.8) / 100.0) * 100)
	Campaign.G.credits -= cost; s.up[k] = lvl + 1; Campaign.refit_done(s, BattleSim.system_tons(d, k))
	map._toast("%s: %s Mk %s fitted." % [s.name, u.name, "I" if lvl == 0 else "II"]); map._render_port(); _look("SHIP SYSTEMS", 120.0)
