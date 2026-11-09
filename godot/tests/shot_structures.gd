extends Node
## Screenshots of land structures: map symbols at normal zoom, drawn installations close in, a structure's panel,
## frames of an air raid, the strike report, a held structure, a port warehouse and the Holdings tab.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_structures.tscn -- <dir>
var f := 0
var out := ""
var map: Node
var tgt: Dictionary
var raid: Node
func _ready() -> void:
	out = OS.get_cmdline_user_args()[0]
	seed(5)
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G
	G.fleet = [Campaign.new_ship("cve_colossus", "Vigilant", "player", []), Campaign.new_ship("cve_casa", "Harbinger", "player", []), Campaign.new_ship("dd", "Escort", "player", [])]
	G.crew = Campaign.crew_need() + 400; G.credits = 120000
	for s in Structures.all(): if s.kind == "airfield" and s.fac == "directorate": tgt = s; break
	var w := Structures.coast_point(tgt); G.player.x = w.x; G.player.y = w.y; G.player.h = 0.0
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _shot(n: String) -> void: print("SHOT ", n); get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")
func _process(_d: float) -> void:
	f += 1
	if f == 3: map.close_panel(); Campaign.paused = true; map.free_cam = true; map.cam = Vector2(tgt.x, tgt.y); map.zoom = 0.9
	if f == 10: _shot("st_chart"); map.zoom = 0.45
	if f == 16: _shot("st_chart_wide"); map.zoom = 4.0
	if f == 22:
		_shot("st_close_airfield")
		for s in Structures.all(): if s.kind == "battery" and Campaign.mdist(s.x, s.y, tgt.x, tgt.y) < 300: map.cam = Vector2(s.x, s.y); break
	if f == 28:
		_shot("st_close_battery")
		for s in Structures.all(): if s.kind == "oil": map.cam = Vector2(s.x, s.y); break
	if f == 34:
		_shot("st_close_oil")
		for s in Structures.all(): if s.kind == "mine": map.cam = Vector2(s.x, s.y); break
	if f == 22: pass
	if f == 40:
		_shot("st_close_mine"); map.zoom = 0.9; map.cam = Vector2(tgt.x, tgt.y)
		for s in Structures.all(): if s.kind == "battery": map.open_struct(s); break
	if f == 43:
		_shot("st_panel_battery")
		for s in Structures.all(): if s.kind == "navalbase": map.open_struct(s); break
	if f == 46:
		_shot("st_panel_naval")
		for s in Structures.all(): if s.kind == "oil": map.open_struct(s); break
	if f == 49:
		_shot("st_panel_oil")
		for s in Structures.all(): if s.kind == "radar": map.open_struct(s); break
	if f == 52:
		_shot("st_panel_radar"); map.open_struct(tgt)
	if f == 56:
		_shot("st_panel"); map._fly_strike(tgt)
		for c in map.panel_layer.get_children(): if c is AirRaid: raid = c
	if f > 58 and f < 1290 and (raid == null or not is_instance_valid(raid)): f = 1290
	if raid != null and is_instance_valid(raid):
		for k in [[4.5, "st_raid_1"], [7.5, "st_raid_2"], [10.2, "st_raid_3"], [13.0, "st_raid_4"]]:
			if raid.t >= k[0] and not raid.has_meta(k[1]): raid.set_meta(k[1], true); _shot(k[1])
	if f == 1300: _shot("st_report"); Campaign.G.strikeReady = 0.0; tgt.dmg = 0.95; map.open_struct(tgt)
	if f == 1308:
		_shot("st_panel_silenced"); print(Structures.take(tgt))
		for s in Structures.all(): if s.kind == "farm" and s.fac != "" and s.fac != "player": s.dmg = 0.9; var w := Structures.coast_point(s); Campaign.G.player.x = w.x; Campaign.G.player.y = w.y; Structures.take(s); break
		while Campaign.G.day % 30 != 29: Campaign.G.day += 1
		Campaign.new_day(false); map.open_struct(tgt)
	if f == 1316:
		_shot("st_held"); map.close_panel(); map.cmd_tab = "holdings"; map.show_command()
	if f == 1324:
		_shot("st_holdings"); map.close_panel()
		for p in Campaign.G.ports: if not Structures.store_of(p).is_empty(): map.open_port(p); map.port_tab = "warehouse"; map._render_port(); break
	if f == 1332:
		_shot("st_warehouse"); map.close_panel()
		var fl: Dictionary = Structures.launch_assault(tgt, "directorate"); fl.warned = true
		map.free_cam = true; map.cam = Vector2(tgt.x, tgt.y); map.zoom = 0.6; map._update_orders(true)
	if f == 1340:
		_shot("st_assault")
		for p in Campaign.G.ports: if p.name == "Port Saffron": Campaign.G.rep.freeport = 20; map.open_port(p); map.port_tab = "yard"; map._render_port()
	if f == 1348: _shot("st_saffron_yard"); get_tree().quit()
