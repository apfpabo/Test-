extends Node
## Sea routes under stress (the owner's request, 13 Nov 2026, after a test campaign found a squadron jammed against the
## top of the chart for six months): a ship is sailed, by the game's own course-setting and movement, between every pair
## of harbours and between a few hundred pairs of open-water points, and each passage is checked: a course is found, she
## arrives, she is never on land, never on the chart's outermost rows, never stuck for long, and she does not take far
## longer than the length of her route allows. godot --headless --path godot res://tests/route_stress.tscn [-- quick]
var fails := 0
var worst := []
func ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		if fails <= 40: print("FAIL ", msg)
func _voyage(ax: float, ay: float, bx: float, by: float, name: String, sp: float, turn: float) -> Dictionary:
	var o := {"x": ax, "y": ay, "rx": ax, "ry": ay, "h": 0.0, "v": 0.0, "ri": 0, "id": 1}
	if not Campaign.set_course(o, bx, by): ok(false, "%s: no course found" % name); return {"ok": false}
	var length: float = Campaign.route_remaining(o); var dt := 0.25
	var limit: int = int((length / sp * 2.2 + 120.0) / dt); var aground := 0; var edge := 0; var jams := 0; var steps := 0; var still := 0; var last := Vector2(o.x, o.y)
	for i in limit:
		steps = i
		if int(o.get("jam", 0)) > 0: Campaign.unjam(o); jams += 1
		elif Campaign.route_move(o, sp, turn, dt): o.route = null
		if o.get("route") == null: break
		if Campaign.on_land(o.x, o.y): aground += 1
		if o.y < 4.0 or o.y > Campaign.MH - 4.0: edge += 1
		var p := Vector2(o.x, o.y)
		if p.distance_to(last) < 0.002: still += 1
		last = p
	var arrived: bool = o.get("route") == null and Campaign.mdist(o.x, o.y, bx, by) < 3.0
	var t: float = steps * dt
	ok(arrived, "%s: did not arrive (%.0f units to go after %.0f s, route %.0f units, %d jams)" % [name, Campaign.mdist(o.x, o.y, bx, by), t, length, jams])
	ok(aground <= 2, "%s: %d steps on land" % [name, aground])
	ok(edge == 0, "%s: %d steps on the chart's outermost rows" % [name, edge])
	ok(still * dt < 30.0, "%s: stopped dead for %.0f s" % [name, still * dt])
	if arrived:
		var slow: float = t / maxf(1.0, length / sp)
		ok(slow < 2.0, "%s: took %.1f times as long as her route's length allows (%d jams)" % [name, slow, jams])
		worst.append([slow, name, jams])
	return {"ok": arrived, "jams": jams, "len": length}
func _ready() -> void:
	var quick: bool = OS.get_cmdline_user_args().has("quick")
	Campaign.new_game("commission")
	var G: Dictionary = Campaign.G; var ports: Array = G.ports
	var sp := 9.0; var turn := 0.5; var n := 0; var jam_total := 0; var t0 := Time.get_ticks_msec()
	# no lane and no stored route touches the chart's outermost rows
	var top := 0
	for id in Campaign.nav.get_point_ids(): if Campaign.nav.get_point_position(id).y < 4.0 or Campaign.nav.get_point_position(id).y > Campaign.MH - 4.0: top += 1
	ok(top == 0, "%d lane points lie on the chart's outermost rows, where no ship can sail" % top)
	# every pair of harbours, each way for a third of them
	for a in ports.size():
		for b in ports.size():
			if a == b or (b < a and (a + b) % 3 != 0) or (quick and (a * 7 + b) % 9 != 0): continue
			var r := _voyage(ports[a].sx, ports[a].sy, ports[b].sx, ports[b].sy, "%s to %s" % [ports[a].name, ports[b].name], sp, turn); n += 1; jam_total += int(r.get("jams", 0))
	var harbour_n := n
	# open water to open water, and open water to a harbour, with a slow ship and a fast one
	seed(20261113)
	for i in (60 if quick else 400):
		var p: Vector2 = Campaign.water_point(6.0); var q: Vector2 = Campaign.water_point(6.0)
		if i % 3 == 0: var pt: Dictionary = ports[randi() % ports.size()]; q = Vector2(pt.sx, pt.sy)
		var r := _voyage(p.x, p.y, q.x, q.y, "open water %.0f,%.0f to %.0f,%.0f" % [p.x, p.y, q.x, q.y], [5.0, 9.0, 14.0][i % 3], [0.35, 0.5, 0.8][i % 3]); n += 1; jam_total += int(r.get("jams", 0))
	worst.sort_custom(func(x, y): return x[0] > y[0])
	print("route stress: %d passages (%d between harbours), %d failures, %d jams cleared on the way, %.0f s" % [n, harbour_n, fails, jam_total, (Time.get_ticks_msec() - t0) / 1000.0])
	for w in worst.slice(0, 5): print("  slowest: %s, %.2f times her route's length, %d jams" % [w[1], w[0], w[2]])
	print("ROUTE STRESS PASSED" if fails == 0 else "ROUTE STRESS FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
