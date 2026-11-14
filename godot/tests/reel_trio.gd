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
	"g_iowa": 8.0, "g_montana": 8.0, "g_tico": 8.5, "g_thunder": 8.5, "x_slava": 11.0}

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
## Train the guns on a point, each only as far as it can bear: a mount whose line of fire would cross the upper works,
## a funnel or a higher turret stops short (BattleSim.mount_arc, as the game's own gunnery does).
func _train(s, at: Vector2, k := 1.0) -> void:
	for m in s.mounts:
		if m.w.kind != "gun": continue
		var want: float = ang_diff_((at - (s.pos + Vector2(m.slot.x, m.slot.y).rotated(s.a))).angle(), s.a)
		m.ta = lerp_angle(m.ta, float(sim.mount_arc(m, want).y), k)
func ang_diff_(a: float, b: float) -> float: return wrapf(a - b, -PI, PI)
## Whether this mount bears on the point, clear of her own upper works.
func _bears(s, m, at: Vector2) -> bool:
	return sim.mount_arc(m, ang_diff_((at - (s.pos + Vector2(m.slot.x, m.slot.y).rotated(s.a))).angle(), s.a)).x > 0
func _fire(s, at: Vector2, tgt, sizes := ["H"]) -> void:
	for m in s.mounts:
		if m.w.kind == "gun" and sizes.has(m.w.size) and not m.dead and _bears(s, m, at): sim.fire_gun(s, m, at, m.w, tgt)
func _missiles(s, tg, n: int) -> void:
	var w: Dictionary = GameData.weapons["ssm"]
	for i in n:
		var from: Vector2 = s.pos + Vector2(float(s.d.L) * (0.3 - 0.06 * i), 0).rotated(s.a)
		sim.missiles.append({"pos": from, "a": s.a - PI / 2 + randf_range(-0.2, 0.2), "v": 60.0, "speed": float(w.speed), "life": 60.0, "dmg": float(w.dmg), "side": s.side, "target": tg, "kind": "ssm", "delay": 0.25 * i, "prof": "skim", "sk": 0.0, "who": s})
## Fire `src`'s guns of these sizes at where `tgt` will be when the shells arrive (a shell flies straight to its aim
## point, distance over speed).
func _shoot(src, tgt, sizes := ["H"], off := Vector2.ZERO) -> void:
	var vel: Vector2 = Vector2.from_angle(tgt.a) * float(mk.get("mps", 0.0))
	for m in src.mounts:
		if m.w.kind != "gun" or not sizes.has(m.w.size) or m.dead: continue
		var aim: Vector2 = tgt.pos + off
		for i in 3: aim = tgt.pos + off + vel * (aim.distance_to(src.pos) / float(m.w.speed))
		if _bears(src, m, aim): sim.fire_gun(src, m, aim, m.w, tgt)
## Her speed over the ground in metres a second (the sim's own units), measured by running it a second.
func _speed_of(s) -> void:
	var p0: Vector2 = s.pos; _warm(1.0); mk["mps"] = p0.distance_to(s.pos)
## Run the action on, unseen, until the first shell in the air is `lead` seconds from its fall.
func _land(lead: float) -> void:
	for i in 2000:
		var soon := INF
		for sh in sim.shells: soon = minf(soon, float(sh.T) - float(sh.t))
		if sim.shells.is_empty() or soon <= lead: return
		sim.step(0.05)
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
## An exchange before the shot opens, so she is already burning: `n` salvos from `src` that are let hit.
func _scar(src, tgt, n: int) -> void:
	var g: bool = tgt.god; tgt.god = false
	for i in n: _shoot(src, tgt); _land(0.0); _warm(2.0)
	tgt.god = g
func _init_t(s: String) -> void:
	match s:
		"t_bismarck":   # at speed, then her broadside
			A = _put("bb_bismarck", 0, C, -PI / 2, [], 13.0); A.god = true
			B = _put("bb_kgv", 1, C + Vector2(3600, -900), -PI / 2, [], 10.0); B.god = true; _speed_of(B); _train(A, B.pos)
			battle.camera.position = A.pos + Vector2(0, -80); battle.camera.zoom = Vector2.ONE * 3.2
		"t_vanguard":   # her broadside, and the answer coming home
			A = _put("bb_vanguard", 0, C, -PI / 2, ["radar"], 10.0); B = _put("bb_yamato", 1, C + Vector2(2900, -1200), -PI / 2, [], 10.0)
			A.god = true; B.god = true; _speed_of(A); _train(A, B.pos); _train(B, A.pos)
			_scar(B, A, 1); _shoot(B, A); _land(2.4)
			battle.camera.position = A.pos + Vector2(0, -70); battle.camera.zoom = Vector2.ONE * 3.0
		"t_line":       # the lines, wide, hitting each other; one of theirs blows up
			var mine := ["bb_iowa", "bb_montana", "bb_kgv"]; var theirs := ["bb_yamato", "bb_bismarck", "bb_a150"]
			var L0: Array = []; var L1: Array = []
			for i in 3:
				var p = _put(mine[i], 0, C + Vector2(500 - 650 * i, 1300), 0.0, ["radar"], 10.0); p.god = true; L0.append(p)   # in line ahead, heading east
				var q = _put(theirs[i], 1, C + Vector2(700 - 650 * i, -1300), 0.0, [], 10.0); q.god = true; L1.append(q)
			mk["L0"] = L0; mk["L1"] = L1; _speed_of(L0[0])
			for i in 3: _train(L0[i], L1[i].pos); _train(L1[i], L0[i].pos)
			for i in 3: _scar(L0[i], L1[i], 1); _scar(L1[i], L0[i], 1)
			for i in 3: _shoot(L1[i], L0[i])
			_land(1.0)
			battle.camera.position = (L0[1].pos + L1[1].pos) * 0.5; battle.camera.zoom = Vector2.ONE * 0.46
		"t_kgv":        # hit, and hit again
			A = _put("bb_kgv", 0, C, -PI / 2, ["radar"], 10.0); B = _put("bb_bismarck", 1, C + Vector2(-2800, -900), -PI / 2, [], 10.0)
			A.god = true; B.god = true; _train(B, A.pos); _speed_of(A)
			_scar(B, A, 2); _shoot(B, A); _land(1.0)
			battle.camera.position = A.pos; battle.camera.zoom = Vector2.ONE * 2.6
		"t_yamato":     # the biggest guns, firing as the Iowa's shells come home
			A = _put("bb_yamato", 0, C, -PI / 2, [], 9.0); B = _put("bb_iowa", 1, C + Vector2(-3000, 900), -PI / 2, [], 9.0)
			A.god = true; B.god = true; _speed_of(A); _train(A, B.pos); _train(B, A.pos)
			_scar(B, A, 1); _shoot(B, A); _land(3.0)
			battle.camera.position = A.pos + Vector2(0, -60); battle.camera.zoom = Vector2.ONE * 2.6
func _run_t(s: String, d: float, vs: Vector2) -> void:
	match s:
		"t_bismarck":
			A.v = 13.0; _train(A, B.pos, minf(1.0, d * 2.0))
			if _at("b1", 2.4): _shoot(A, B, ["H", "M"])
			if _at("b2", 5.6): _shoot(A, B, ["H"])
			_cam(A.pos + Vector2(0, lerpf(-80.0, 0.0, t / 7.5)), lerpf(3.2, _fit(A, 0.62, vs.y), smoothstep(0.0, 7.5, t)), 1.0)
		"t_vanguard":
			A.v = 10.0; _train(A, B.pos, minf(1.0, d * 2.0))
			if _at("s1", 0.9): _shoot(A, B, ["H", "M"])
			if _at("god", 2.0): A.god = false
			if _at("s2", 4.8): _shoot(A, B, ["H"])
			_cam(A.pos + Vector2(0, lerpf(-70.0, 60.0, t / 7.5)), lerpf(3.0, 2.3, smoothstep(0.0, 7.5, t)), 1.0)
		"t_line":
			for x in sim.ships: x.v = 10.0
			if _at("god", 0.5):
				for x in sim.ships: x.god = false
			if _at("l1", 0.6):
				for i in 3: _shoot(mk.L0[i], mk.L1[i])
			if _at("l2", 3.0):
				for i in 3: _shoot(mk.L1[i], mk.L0[i])
			if _at("boom", 5.0): sim.detonate(mk.L1[1])
			if _at("l3", 5.4):
				for i in 3: _shoot(mk.L0[i], mk.L1[i])
			var mid: Vector2 = (mk.L0[1].pos + mk.L1[1].pos) * 0.5
			_cam(mid, lerpf(0.46, 0.52, smoothstep(0.0, 8.0, t)), 1.0)
		"t_kgv":
			A.v = 10.0; _train(A, B.pos, minf(1.0, d * 2.0))
			if _at("god", 0.5): A.god = false
			if _at("k1", 1.4): _shoot(A, B, ["H"])
			if _at("k2", 2.4): _shoot(B, A)
			_cam(A.pos, lerpf(2.6, 2.0, smoothstep(0.0, 7.5, t)), 1.0)
		"t_yamato":
			A.v = 9.0; _train(A, B.pos, minf(1.0, d * 2.0))
			if _at("god", 2.0): A.god = false
			if _at("y1", 1.2): _shoot(A, B, ["H"])
			if _at("y2", 4.8): _shoot(A, B, ["H", "M"])
			_cam(A.pos, lerpf(2.6, _fit(A, 0.55, vs.y), smoothstep(0.0, 8.0, t)), 1.0)

# ---------------------------------------------------------------- two Fletchers under the A-150's guns
func _init_f(s: String) -> void:
	var d1 = _put("dd_fletcher", 0, C, -PI / 2, ["radar"], 17.0); var d2 = _put("dd_fletcher", 0, C + Vector2(0, 520), -PI / 2, ["radar"], 17.0)
	d1.god = true; d2.god = true; A = d1; mk["d2"] = d2
	B = _put("bb_a150", 1, C + Vector2(2700, -1400), -PI / 2 - 0.4, [], 10.0); B.god = true
	_train(B, A.pos, 1.0); _speed_of(A); _train(d1, B.pos); _train(d2, B.pos)
	match s:
		"f_column":     # at full speed, firing back; the fall of shot walks onto them
			_shoot(B, A, ["H"], Vector2(0, 140)); _land(1.5)
			battle.camera.position = A.pos + Vector2(0, 260); battle.camera.zoom = Vector2.ONE * 2.2
		"f_a150":       # the A-150 firing, the destroyers' 5-inch hitting her
			_shoot(d1, B, ["M"]); _shoot(d2, B, ["M"]); _land(2.0)
			battle.camera.position = B.pos; battle.camera.zoom = Vector2.ONE * 1.9
		"f_straddle":   # straddled, and hit
			_scar(B, d2, 1); _shoot(B, A); _land(0.8)
			battle.camera.position = A.pos + Vector2(0, 130); battle.camera.zoom = Vector2.ONE * 3.0
		"f_end":        # both burning; the leader's magazine goes up
			_scar(B, A, 2); _scar(B, d2, 1); _shoot(B, d2, ["H"], Vector2(0, -120)); _land(3.5)
			battle.camera.position = A.pos + Vector2(0, 260); battle.camera.zoom = Vector2.ONE * 2.6
func _run_f(s: String, d: float, vs: Vector2) -> void:
	if A.alive: A.v = 17.0
	if mk.d2.alive: mk.d2.v = 17.0
	_train(B, A.pos, minf(1.0, d * 2.0))
	for x in [A, mk.d2]: _train(x, B.pos, minf(1.0, d * 2.0))
	match s:
		"f_column":
			if _at("r1", 1.8): _shoot(A, B, ["M"]); _shoot(mk.d2, B, ["M"])
			if _at("god", 3.0): A.god = false
			if _at("a1", 3.2): _shoot(B, A)
			if _at("r2", 5.0): _shoot(A, B, ["M"]); _shoot(mk.d2, B, ["M"])
			_cam(A.pos + Vector2(0, 260), lerpf(2.2, 1.6, smoothstep(0.0, 8.0, t)), 1.0)
		"f_a150":
			if _at("god", 0.5): B.god = false
			if _at("a1", 1.2): _shoot(B, A)
			if _at("r1", 2.6): _shoot(A, B, ["M"]); _shoot(mk.d2, B, ["M"])
			if _at("a2", 4.4): _shoot(B, A, ["H", "M"])
			_cam(B.pos + Vector2.from_angle(B.a) * lerpf(-30.0, 40.0, t / 7.5), lerpf(1.9, 1.5, smoothstep(0.0, 7.5, t)), 1.0)
		"f_straddle":
			if _at("god", 0.4): A.god = false
			if _at("r1", 2.0): _shoot(A, B, ["M"])
			if _at("a1", 3.0): _shoot(B, mk.d2)
			_cam(A.pos + Vector2(0, 130), lerpf(3.0, 2.4, smoothstep(0.0, 8.0, t)), 1.0)
		"f_end":
			if _at("god", 0.2): mk.d2.god = false
			if _at("boom", 2.6): sim.detonate(A)
			if _at("a1", 4.0): _shoot(B, mk.d2)
			_cam((A.pos if A.alive else mk.d2.pos) + Vector2(0, 260), lerpf(2.6, 1.2, smoothstep(0.0, 8.5, t)), 1.0)

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

# ---------------------------------------------------------------- the Slava's P-500s, one tube after another
func _init_x(s: String) -> void:
	A = _put("cg_slava", 0, C, -PI / 2, E3, 7.0); A.god = true
	B = _put("ddg_burke", 1, C + Vector2(9000, -3000), -PI / 2, E3, 7.0); B.god = true
	battle.camera.position = A.pos + Vector2(0, -30); battle.camera.zoom = Vector2.ONE * _fit(A, 0.7, 1920.0)
func _run_x(s: String, d: float, vs: Vector2) -> void:
	A.v = 7.0; B.v = 7.0
	if _at("fire", 1.0):
		for m in A.mounts:
			if m.wid == "ssmh": sim.fire_missile(A, m, B)
	_cam(A.pos + Vector2(0, lerpf(-30.0, -120.0, smoothstep(1.0, 11.0, t))), lerpf(_fit(A, 0.7, vs.y), _fit(A, 0.45, vs.y), smoothstep(3.0, 11.0, t)), 1.0)
