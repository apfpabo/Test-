extends Node
## Three upright clips made of slow shots joined with long crossfades (the owner's request, 14 Nov 2026): a trailer,
## two Fletchers under an A-150's guns, and the generations (one ship of each era, centred, firing). Each shot is its
## own recording; tools/make_trio.sh records them and joins them.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 30 \
##     --write-movie <out.avi> res://tests/reel_trio.tscn -- <shot>
var shot := "t_bismarck"
var battle: Node
var sim
var t := 0.0
var st := 0
var C := Vector2.ZERO
var A = null
var B = null
var mk := {}
const DAY := {"sea": 1, "fog": false, "night": false, "moon": 0.5}
const E3 := ["radar", "missiles", "ciws", "jets", "aegis", "vls", "ecm", "datalink"]
const E4 := ["radar", "missiles", "ciws", "jets", "aegis", "vls", "ecm", "datalink", "stealth", "netcentric", "precision", "railgun"]
const LEN := {"t_bismarck": 7.5, "t_vanguard": 7.5, "t_line": 8.0, "t_kgv": 7.5, "t_yamato": 8.0,
	"f_column": 8.0, "f_a150": 7.5, "f_straddle": 8.0, "f_end": 8.5,
	"g_iowa": 8.0, "g_montana": 8.0, "g_tico": 8.5, "g_thunder": 8.5}

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: shot = a[0]
	seed(7); Settings.sensors = false
	Weather.force = DAY
	GameData.pending = {"quiet": true, "player": ["dd_fletcher"], "enemy": ["dd_fletcher"], "enemy_fac": "directorate", "player_tech": [], "enemy_tech": [], "islands": 0, "weather": Weather.battle(DAY)}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)

# ---------------------------------------------------------------- helpers
func _cam(p: Vector2, z: float, k := 1.0) -> void:
	battle.camera.position = battle.camera.position.lerp(p, k); battle.camera.zoom = battle.camera.zoom.lerp(Vector2.ONE * z, k)
func _clear() -> void:
	for s in sim.ships.duplicate():
		battle.remove_view(s); sim.despawn(s)
	sim.air.clear(); sim.missiles.clear(); sim.shells.clear(); sim.torps.clear(); sim.flag = null
func _put(id: String, side: int, at: Vector2, a: float, tech: Array, v := 0.0, ai := false):
	var s = sim.spawn(id, side, at, a, tech); battle._add_view(s)
	s.v = v; s.throttle = 3 if v > 0.0 else 0
	if not ai: s.ai_off = true; s.hold = true
	return s
func _warm(secs: float) -> void:
	for i in int(secs / 0.05): sim.step(0.05)
func _train(s, at: Vector2, k := 1.0) -> void:
	for m in s.mounts:
		if m.w.kind != "gun": continue
		var want: float = (at - (s.pos + Vector2(m.slot.x, m.slot.y).rotated(s.a))).angle() - s.a
		m.ta = lerp_angle(m.ta, want, k)
func _fire(s, at: Vector2, tgt, sizes := ["H"]) -> void:
	for m in s.mounts:
		if m.w.kind == "gun" and sizes.has(m.w.size) and not m.dead: sim.fire_gun(s, m, at, m.w, tgt)
func _missiles(s, tg, n: int) -> void:
	var w: Dictionary = GameData.weapons["ssm"]
	for i in n:
		var from: Vector2 = s.pos + Vector2(float(s.d.L) * (0.3 - 0.06 * i), 0).rotated(s.a)
		sim.missiles.append({"pos": from, "a": s.a - PI / 2 + randf_range(-0.2, 0.2), "v": 60.0, "speed": float(w.speed), "life": 60.0, "dmg": float(w.dmg), "side": s.side, "target": tg, "kind": "ssm", "delay": 0.25 * i, "prof": "skim", "sk": 0.0, "who": s})
func _at(k: String, when: float) -> bool:
	if t >= when and not mk.has(k): mk[k] = true; return true
	return false
func _fit(s, frac: float, vh: float) -> float: return frac * vh / float(s.d.L)   # zoom so her length is `frac` of the frame's height

func _process(d: float) -> void:
	sim = battle.sim
	if sim == null: return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if st == 0:
		st = 1; Sfx.music(""); battle.hud.visible = false; battle.set_clean(true); battle.cam_free = true; sim.editor = true
		battle.speed_i = 1; C = Vector2(sim.AW * 0.5, sim.AH * 0.5); _clear()
		call("_init_" + shot.substr(0, 1), shot)
		return
	t += d
	call("_run_" + shot.substr(0, 1), shot, d, vs)
	if t >= float(LEN[shot]): get_tree().quit()

# ---------------------------------------------------------------- the trailer
func _init_t(s: String) -> void:
	match s:
		"t_bismarck":   # alone at speed; the camera draws back along her
			A = _put("bb_bismarck", 0, C, -PI / 2, [], 13.0); A.god = true
			battle.camera.position = A.pos + Vector2(0, -80); battle.camera.zoom = Vector2.ONE * 3.2
		"t_vanguard":   # a broadside to starboard, the camera drifting aft along her
			A = _put("bb_vanguard", 0, C, -PI / 2, ["radar"], 10.0); B = _put("bb_yamato", 1, C + Vector2(16000, -2000), PI / 2, [], 8.0)
			A.god = true; B.god = true; _train(A, B.pos)
			battle.camera.position = A.pos + Vector2(0, -70); battle.camera.zoom = Vector2.ONE * 2.2
		"t_line":       # the lines, wide, both firing
			var mine := ["bb_iowa", "bb_montana", "bb_kgv"]; var theirs := ["bb_yamato", "bb_bismarck", "bb_a150"]
			for i in 3:
				var p = _put(mine[i], 0, C + Vector2(-1500, 900 * i), -PI / 2, ["radar"], 10.0, true); p.god = true
				var q = _put(theirs[i], 1, C + Vector2(1500, 900 * i - 400), -PI / 2, [], 10.0, true); q.god = true
			sim.flag = null; _warm(30.0)
			for x in sim.ships: x.v = 10.0
			battle.camera.position = C + Vector2(0, 1000); battle.camera.zoom = Vector2.ONE * 0.36
		"t_kgv":        # shells coming down round her, and hitting
			A = _put("bb_kgv", 0, C, -PI / 2, ["radar"], 10.0); B = _put("bb_bismarck", 1, C + Vector2(-13000, -3000), -PI / 2, [], 10.0)
			A.god = true; B.god = true; _train(B, A.pos)
			battle.camera.position = A.pos; battle.camera.zoom = Vector2.ONE * 2.0
		"t_yamato":     # the biggest guns: close, then drawing away as she fires
			A = _put("bb_yamato", 0, C, -PI / 2, [], 9.0); B = _put("bb_iowa", 1, C + Vector2(-17000, 1500), -PI / 2, [], 9.0)
			A.god = true; B.god = true; _train(A, B.pos)
			battle.camera.position = A.pos + Vector2(0, -60); battle.camera.zoom = Vector2.ONE * 2.6
func _run_t(s: String, d: float, vs: Vector2) -> void:
	match s:
		"t_bismarck":
			A.v = 13.0; _cam(A.pos + Vector2(0, lerpf(-80.0, 0.0, t / 7.5)), lerpf(3.2, _fit(A, 0.62, vs.y), smoothstep(0.0, 7.5, t)), 1.0)
		"t_vanguard":
			A.v = 10.0; _train(A, B.pos + Vector2(0, -600), minf(1.0, d * 2.0))
			if _at("s1", 1.6): _fire(A, B.pos, B, ["H"])
			if _at("s2", 4.6): _fire(A, B.pos, B, ["H"])
			_cam(A.pos + Vector2(0, lerpf(-70.0, 60.0, t / 7.5)), lerpf(2.2, 1.7, smoothstep(0.0, 7.5, t)), 1.0)
		"t_line":
			for x in sim.ships: x.v = 10.0
			_cam(C + Vector2(0, 1000 - 10.0 * t * 10.0), lerpf(0.36, 0.42, t / 8.0), 1.0)
		"t_kgv":
			A.v = 10.0
			if _at("b1", 0.1): _fire(B, A.pos + Vector2(0, -260), A)
			if _at("b2", 2.2): _fire(B, A.pos + Vector2(0, -220), A)
			if _at("god", 3.5): A.god = false
			_cam(A.pos, lerpf(2.0, 1.6, smoothstep(0.0, 7.5, t)), 1.0)
		"t_yamato":
			A.v = 9.0; _train(A, B.pos, minf(1.0, d * 2.0))
			if _at("y1", 1.4): _fire(A, B.pos, B, ["H"])
			if _at("y2", 4.8): _fire(A, B.pos, B, ["H", "M"])
			_cam(A.pos, lerpf(2.6, _fit(A, 0.55, vs.y), smoothstep(0.0, 8.0, t)), 1.0)

# ---------------------------------------------------------------- two Fletchers under the A-150's guns
func _init_f(s: String) -> void:
	var d1 = _put("dd_fletcher", 0, C, -PI / 2, ["radar"], 17.0); var d2 = _put("dd_fletcher", 0, C + Vector2(0, 520), -PI / 2, ["radar"], 17.0)
	d1.god = true; d2.god = true; A = d1; mk["d2"] = d2
	B = _put("bb_a150", 1, C + Vector2(14000, -6000), -PI / 2 - 0.4, [], 10.0); B.god = true
	_train(B, A.pos, 1.0)
	match s:
		"f_column":     # the two at full speed, the first fall of shot arriving
			battle.camera.position = A.pos + Vector2(0, 260); battle.camera.zoom = Vector2.ONE * 2.4
		"f_a150":       # the A-150 herself, her 18.1-inch triples firing
			battle.camera.position = B.pos; battle.camera.zoom = Vector2.ONE * 1.9
		"f_straddle":   # straddled, and hit
			for i in 2: _fire(B, A.pos + Vector2(0, -17.0 * 20.0), A); _warm(18.0)
			battle.camera.position = A.pos + Vector2(0, 260); battle.camera.zoom = Vector2.ONE * 2.0
		"f_end":        # burning, still running, the camera drawing away
			for i in 3: _fire(B, A.pos + Vector2(0, -17.0 * 20.0), A); _warm(18.0)
			A.god = false; d2.god = false
			sim.damage(A, A.max_hull * 0.45, "shell"); sim.damage(d2, d2.max_hull * 0.3, "shell")
			battle.camera.position = A.pos + Vector2(0, 260); battle.camera.zoom = Vector2.ONE * 2.2
func _run_f(s: String, d: float, vs: Vector2) -> void:
	A.v = 17.0; mk.d2.v = 17.0
	var lead: Vector2 = A.pos + Vector2(0, -17.0 * 20.0)
	_train(B, lead, minf(1.0, d * 2.0))
	match s:
		"f_column":
			if _at("p", 0.0): _fire(B, lead, A); _warm(16.5)   # the shells are in the air as the shot opens
			_cam(A.pos + Vector2(0, 260), lerpf(2.4, 1.5, smoothstep(0.0, 8.0, t)), 1.0)
		"f_a150":
			if _at("a1", 1.2): _fire(B, lead, A)
			if _at("a2", 4.4): _fire(B, lead, A, ["H", "M"])
			_cam(B.pos + Vector2.from_angle(B.a) * lerpf(-30.0, 40.0, t / 7.5), lerpf(1.9, 1.5, smoothstep(0.0, 7.5, t)), 1.0)
		"f_straddle":
			if _at("god", 2.5): A.god = false
			_cam(A.pos + Vector2(0, 260), lerpf(2.0, 1.7, smoothstep(0.0, 8.0, t)), 1.0)
		"f_end":
			if _at("e1", 0.5): _fire(B, lead, A)
			_cam(A.pos + Vector2(0, 260), lerpf(2.2, 0.9, smoothstep(0.0, 8.5, t)), 1.0)

# ---------------------------------------------------------------- the generations: one ship of each era, centred
func _init_g(s: String) -> void:
	var spec: Array = {"g_iowa": ["bb_iowa", ["radar"]], "g_montana": ["bb_montana", ["radar"]], "g_tico": ["cg_tico", E3], "g_thunder": ["cg_thunder", E4]}[s]
	A = _put(spec[0], 0, C, -PI / 2, spec[1], 6.0); A.god = true
	B = _put("bb_bismarck", 1, C + Vector2(15000, -1500), -PI / 2, [], 6.0); B.god = true
	_train(A, B.pos, 1.0)
	battle.camera.position = A.pos; battle.camera.zoom = Vector2.ONE * _fit(A, 0.6, 1920.0)
func _run_g(s: String, d: float, vs: Vector2) -> void:
	A.v = 6.0; B.v = 6.0; _train(A, B.pos, minf(1.0, d * 3.0))
	match s:
		"g_iowa", "g_montana":
			if _at("1", 1.8): _fire(A, B.pos, B, ["H"])
			if _at("2", 5.2): _fire(A, B.pos, B, ["H", "M"])
		"g_tico":
			if _at("1", 1.4): _fire(A, B.pos, B, ["M", "L"])
			if _at("2", 2.8): _missiles(A, B, 4)
			if _at("3", 6.0): _fire(A, B.pos, B, ["M", "L"])
		"g_thunder":
			if _at("1", 1.6): _fire(A, B.pos, B, ["H", "L", "M"])
			if _at("2", 4.6): _fire(A, B.pos, B, ["H", "L", "M"])
	_cam(A.pos, lerpf(_fit(A, 0.6, vs.y), _fit(A, 0.52, vs.y), smoothstep(0.0, 8.0, t)), 1.0)
