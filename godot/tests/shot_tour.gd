extends Node
## A tour of the interface for review (12-13 Nov 2026, the UI humanising pass): the title pages, the chart, a harbour's
## tabs, the Command drawer's pages, a contact, a battle with its HUD and the aftermath. Pictures only.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_tour.tscn -- <dir> [only-prefix]
var out := ""
var only := ""
var f := 0
var node: Node
var steps: Array = []
var si := 0
var wait := 0
func _shot(n: String) -> void:
	if only == "" or n.begins_with(only): get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
func _ready() -> void:
	var a := OS.get_cmdline_user_args(); out = a[0]; only = a[1] if a.size() > 1 else ""
	Weather.force = {"sea": 1, "fog": false, "night": false, "moon": 0.5}
	seed(3)
	steps = [
		func(): node = load("res://scenes/main_menu.tscn").instantiate(); add_child(node); return "01_title",
		func(): node.go(node._new_campaign); return "02_new_campaign",
		func(): node._origin(node.pc, node.home, "merchant"); return "03_origin",
		func():
			node.queue_free(); Campaign.new_game("disgraced"); Campaign.G.credits = 60000
			node = load("res://scenes/world_map.tscn").instantiate(); add_child(node); return "04_chart_origin",
		func(): node.close_panel(); return "05_chart",
		func():
			var p = null
			for q in Campaign.G.ports: if not Campaign.hostile(q.fac) and q.fac == "concord": p = q; break
			node.open_port(p, false); return "06_port_market",
		func(): node.port_tab = "contracts"; node._render_port(); return "07_port_contracts",
		func(): node.port_tab = "yard"; node._render_port(); return "08_port_yard",
		func(): node.port_tab = "fleet"; node._render_port(); return "09_port_fleet",
		func(): node.port_tab = "officers"; node._render_port(); return "10_port_officers",
		func(): node.close_panel(); node.cur_port = {}; node.cmd_tab = "fleet"; node.show_command(); return "11_cmd_fleet",
		func(): node.cmd_tab = "officers"; node.show_command(); return "12_cmd_officers",
		func(): node.cmd_tab = "research"; node.show_command(); return "13_cmd_research",
		func(): node.cmd_tab = "missions"; node.show_command(); return "14_cmd_missions",
		func(): node.cmd_tab = "holdings"; node.show_command(); return "15_cmd_holdings",
		func(): node.cmd_tab = "hold"; node.show_command(); return "16_cmd_hold",
		func(): node.cmd_tab = "locations"; node.show_command(); return "17_cmd_locations",
		func(): node.cmd_tab = "codex"; node.show_command(); return "18_cmd_codex",
		func():
			node.close_drawer(); var fl = Campaign.spawn_fleet("raiders", "raiders"); fl.x = Campaign.G.player.x + 4; fl.y = Campaign.G.player.y; fl.contactKm = 12
			node._on_encounter(fl); return "19_contact",
		func(): node._pause_menu(); return "20_pause",
	]
func _process(_d: float) -> void:
	f += 1
	if wait > 0: wait -= 1; return
	if si >= steps.size(): get_tree().quit(); return
	if f % 2 == 1: return
	var n: String = steps[si].call(); si += 1; wait = 18
	await get_tree().process_frame
	for i in 16: await get_tree().process_frame
	_shot(n)
