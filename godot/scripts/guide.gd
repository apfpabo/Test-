extends CanvasLayer
## The guide for a new captain (the owner's go-ahead, 11 Nov 2026: "a guided first voyage and battle"). A small card,
## low on the screen, that does not stop the game: one step at a time, each moving on when you have done what it says
## (or when you press Next), from the chart through the first harbour to the first action and its aftermath. Offered
## on the New campaign page; its place is kept in `Campaign.G.guide` ({"step", "battle"}), so a save carries it; "End
## the guide" removes it. Loaded by path by world_map.gd and battle.gd (`const Guide = preload(...)`).
const CHART := [
	["Your squadron", "Your squadron is the gold mark. Drag the chart to look about and scroll to zoom; C brings you back to it.", "look"],
	["Your ships", "The tabs along the bottom are your Command pages. Open FLEET to see your ships: hull, readiness, crew and wear.", "fleet"],
	["A course", "Click a harbour on the chart to sail there, or open LOCATIONS and press Set course. A harbour whose name is not red will have you.", "course"],
	["Time", "Time passes as you sail. The buttons at the top run the clock at 1× to 8×; Space pauses it.", "clock"],
	["In harbour", "When you make harbour its panel opens: fuel and food in the MARKET, repairs in REPAIRS & CREW, paid work under CONTRACTS.", "port"],
	["At sea", "Put to sea when you are ready. Ships that mean you harm bring a choice: battle stations, or try to break off. The panel gives you the odds; weigh them.", "contact"],
]
const BATTLE := [
	["Battle stations", "You command the flagship. W and S set her engines, A and D her rudder.", "helm"],
	["Your guns", "Click an enemy ship to lay your guns on her; X fires at will. The readout by the cursor says when the guns bear.", "lock"],
	["Your squadron", "The bar at the top gives orders to the rest of your ships: engage, form on the flagship, line ahead, withdraw. Esc pauses and opens the menu.", "orders"],
	["Other weapons", "T fires torpedoes at the cursor (press it twice if a friend is in the way), F flies off aircraft or a cruiser's floatplane, K makes smoke.", "time"],
]
const AFTER := ["After the action", "Here are the ships sunk and taken, prizes to keep, wrecks you may raise and what your boats salvaged. That is the guide: the CODEX tab has the rest. Good hunting."]

var host        # world_map or battle
var in_battle := false
var card: PanelContainer
var head: Label
var body: Label
var t_step := 0.0
var z0 := 0.0
var c0 := Vector2.ZERO
var speed0 := 1
var paused0 := false
var order0 := ""
var thr0 := 0
var rud0 := 0.0

static func active() -> bool: return not Campaign.G.is_empty() and Campaign.G.has("guide")
static func start() -> void: Campaign.G.guide = {"step": 0, "battle": 0, "after": false}

func _ready() -> void:
	layer = 6
	card = PanelContainer.new(); card.theme = UI.theme(); card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.03, 0.07, 0.09, 0.94); sb.border_color = Color(UI.GOLD, 0.7); sb.border_width_left = 3; sb.set_corner_radius_all(2)
	sb.content_margin_left = 16; sb.content_margin_right = 14; sb.content_margin_top = 10; sb.content_margin_bottom = 10; card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); card.add_child(v)
	head = UI.label("", UI.GOLD, 12); v.add_child(head)
	body = UI.label("", UI.INK, 15, true); body.custom_minimum_size.x = 420; v.add_child(body)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); v.add_child(row)
	var nx := UI.button("Next", func(): _advance()); nx.focus_mode = Control.FOCUS_NONE; row.add_child(nx)
	var end := UI.button("End the guide", func(): Campaign.G.erase("guide"); queue_free()); end.focus_mode = Control.FOCUS_NONE; row.add_child(end)
	add_child(card)
	_reset_watch(); _show()

func _steps() -> Array: return BATTLE if in_battle else CHART
func _index() -> int: return int(Campaign.G.guide.get("battle" if in_battle else "step", 0))
func _done() -> bool:
	if in_battle: return _index() >= BATTLE.size()
	return _index() >= CHART.size() and not bool(Campaign.G.guide.get("after", false))

func _reset_watch() -> void:
	t_step = 0.0
	if in_battle:
		order0 = String(host.sim.order)
		if host.sim.flag != null: thr0 = int(host.sim.flag.throttle); rud0 = float(host.sim.flag.rudder)
	else: z0 = host.zoom; c0 = host.cam; speed0 = Campaign.map_speed; paused0 = Campaign.paused

func _advance() -> void:
	var G: Dictionary = Campaign.G
	if not G.has("guide"): return
	if not in_battle and bool(G.guide.get("after", false)):   # the last card: the aftermath read, the guide is over
		G.erase("guide"); queue_free(); return
	G.guide["battle" if in_battle else "step"] = _index() + 1
	_reset_watch(); _show()

func _show() -> void:
	if not Campaign.G.has("guide"): queue_free(); return
	if not in_battle and bool(Campaign.G.guide.get("after", false)):
		head.text = "GUIDE · " + String(AFTER[0]).to_upper(); body.text = AFTER[1]; card.visible = true; return
	if _done(): card.visible = false; return
	var st: Array = _steps()[_index()]
	head.text = "GUIDE · %s · %d OF %d" % [String(st[0]).to_upper(), _index() + 1, _steps().size()]; body.text = st[1]; card.visible = true

## Called by the chart when an action's aftermath opens: the last card.
func aftermath() -> void:
	if not Campaign.G.has("guide"): return
	Campaign.G.guide.after = true; _show()

func _process(dt: float) -> void:
	if not Campaign.G.has("guide"): queue_free(); return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	card.reset_size()
	# on the chart, at the right above the engines box; while a panel is open in the middle (a harbour, a contact) it
	# steps aside, save the last card, which sits at the top right beside the aftermath; in action, low in the middle
	var after: bool = not in_battle and bool(Campaign.G.guide.get("after", false))
	if not in_battle: card.modulate.a = 0.0 if (host.panel_open and not after) else 1.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE if card.modulate.a == 0.0 else Control.MOUSE_FILTER_STOP
	if in_battle: card.position = Vector2((vs.x - card.size.x) * 0.5, vs.y - card.size.y - 24.0)
	elif after: card.position = Vector2(vs.x - card.size.x - 16.0, 56.0)
	else: card.position = Vector2(vs.x - card.size.x - 16.0, vs.y - card.size.y - 140.0)
	if not card.visible: return
	t_step += dt
	if (not in_battle and bool(Campaign.G.guide.get("after", false))) or _done(): return
	if t_step > 1.0 and _met(String(_steps()[_index()][2])): _advance()

func _met(what: String) -> bool:
	match what:
		"look": return absf(host.zoom - z0) > 0.01 or host.cam.distance_to(c0) > 20.0
		"fleet": return host.drawer_open() and host.drawer_tab == "fleet"
		"course": return Campaign.G.player.get("route") != null
		"clock": return Campaign.map_speed != speed0 or Campaign.paused != paused0
		"port": return not host.cur_port.is_empty()
		"contact": return host.panel_open and host.cur_port.is_empty() and t_step > 3.0
		"helm": return host.sim.flag != null and (int(host.sim.flag.throttle) != thr0 or absf(float(host.sim.flag.rudder) - rud0) > 0.05)
		"lock": return host.sim.lock != null
		"orders": return String(host.sim.order) != order0 or t_step > 25.0
		"time": return t_step > 25.0
	return false
