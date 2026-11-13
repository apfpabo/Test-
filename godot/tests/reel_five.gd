extends Node
## Five staged clips with no interface, in portrait (the owner's request, 13 Nov 2026): "shell" (the camera rides a
## battleship's salvo to its fall), "eras" (four fights, 1940s guns to the rail gun), "yamato" (the biggest battleship
## against sea-skimming missiles), "sinking" (a container ship's last minutes) and "night" (a star shell, then every gun).
##   tools/make_five.sh <out dir> [clips]
var clip := "shell"
var battle: Node
var sim
var t := 0.0
var st := 0
var C := Vector2.ZERO
var A = null
var B = null
var shade: ColorRect
var follow = null
var stay := 0.0
var seg := -1
var seg_t := 0.0
var marks := {}
const DAY := {"sea": 1, "fog": false, "night": false, "moon": 0.5}
const E4 := ["radar", "missiles", "ciws", "jets", "aegis", "vls", "ecm", "datalink", "stealth", "netcentric", "precision", "railgun"]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: clip = a[0]
	seed(11); Settings.sensors = false
	var wx: Dictionary = {"sea": 1, "fog": false, "night": true, "moon": 0.35} if clip == "night" else DAY
	Weather.force = wx
	var setup: Array = {
		"shell": [["bb_iowa"], ["bb_yamato"], ["radar"], []],
		"eras": [["ca_baltimore"], ["ca_hipper"], [], []],
		"yamato": [["bb_yamato"], ["ddg_sovremenny"], [], ["radar", "missiles"]],
		"sinking": [["ss_gato"], ["fr_container"], [], []],
		"night": [["ca_baltimore", "dd_fletcher", "dd_fletcher"], ["ca_hipper", "dd_narvik", "dd_narvik"], [], []]}[clip]
	GameData.pending = {"quiet": true, "player": setup[0], "enemy": setup[1], "enemy_fac": "directorate", "player_tech": setup[2], "enemy_tech": setup[3], "islands": 0, "weather": Weather.battle(wx)}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
	var cl := CanvasLayer.new(); cl.layer = 50; add_child(cl)
	shade = ColorRect.new(); shade.color = Color(0.02, 0.05, 0.07, 1.0); shade.set_anchors_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(shade)

func _cam(p: Vector2, z: float, k := 1.0) -> void:
	battle.camera.position = battle.camera.position.lerp(p, k); battle.camera.zoom = battle.camera.zoom.lerp(Vector2.ONE * z, k)
func _still(s, v := 0.0) -> void:
	s.ai_off = true; s.hold = true; s.v = v
func _clear() -> void:
	for s in sim.ships.duplicate():
		battle.remove_view(s); sim.despawn(s)
	sim.air.clear(); sim.missiles.clear(); sim.shells.clear(); sim.torps.clear(); sim.flag = null
func _put(id: String, side: int, at: Vector2, a: float, tech: Array):
	var s = sim.spawn(id, side, at, a, tech); battle._add_view(s); return s
func _warm(secs: float, until: Callable = Callable()) -> void:
	for i in int(secs / 0.05):
		sim.step(0.05)
		if until.is_valid() and until.call(): break
func _train(s, at: Vector2, d: float) -> void:
	for m in s.mounts:
		if m.w.kind != "gun": continue
		var want: float = (at - (s.pos + Vector2(m.slot.x, m.slot.y).rotated(s.a))).angle() - s.a
		m.ta = lerp_angle(m.ta, want, clampf(d * 2.5, 0.0, 1.0))
func _salvo(s, at: Vector2, tgt) -> void:
	for m in s.mounts:
		if m.w.kind == "gun" and m.w.size == "H": sim.fire_gun(s, m, at, m.w, tgt)
func _my_shell(s):
	var best = null
	for sh in sim.shells:
		if sh.who == s and (best == null or float(sh.t) < float(best.t)): best = sh
	return best
func _missile(from: Vector2, tg) -> void:
	var w: Dictionary = GameData.weapons["ssm"]
	sim.missiles.append({"pos": from, "a": (tg.pos - from).angle(), "v": 240.0, "speed": float(w.speed), "life": 40.0, "dmg": float(w.dmg), "side": 1 - tg.side, "target": tg, "kind": "ssm", "delay": 0.0, "prof": "skim", "sk": 0.0})

func _process(d: float) -> void:
	sim = battle.sim
	if sim == null: return
	var vw: float = get_viewport().get_visible_rect().size.x
	if st == 0:
		st = 1; Sfx.music(""); battle.hud.visible = false; battle.set_clean(true); battle.cam_free = true; sim.editor = true
		battle.speed_i = 1; C = Vector2(sim.AW * 0.5, sim.AH * 0.5)
		call("_init_" + clip)
		battle.camera.position = marks.get("cam", C); battle.camera.zoom = Vector2.ONE * float(marks.get("zoom", 1.0))
	t += d
	var length: float = call("_run_" + clip, d, vw)
	var a: float = clampf(maxf(1.0 - t / 0.35, (t - (length - 0.35)) / 0.35), 0.0, 1.0)
	if clip == "eras" and seg_t < 0.1: a = 1.0   # a hard cut between the eras
	shade.color.a = a
	if t >= length: get_tree().quit()

# ---------------------------------------------------------------- 1. riding the shell
func _init_shell() -> void:
	A = sim.flag; B = sim.ships.filter(func(x): return x.side == 1)[0]
	A.pos = C + Vector2(-300, 1200); A.a = 0.0; A.god = true; _still(A, 11.0)
	B.pos = C + Vector2(400, -1000); B.a = PI; _still(B, 9.0); B.god = true
	sim.hold_fire = true; marks = {"cam": A.pos, "zoom": 0.62 * 1080.0 / float(A.d.L), "n": 0, "next": 2.6}
func _run_shell(d: float, vw: float) -> float:
	A.v = 11.0; B.v = 9.0
	var lead: Vector2 = B.pos + Vector2.from_angle(B.a) * B.v * 3.2
	_train(A, lead, d)
	var za: float = 0.62 * vw / float(A.d.L); var zb: float = 0.7 * vw / float(B.d.L)
	if follow != null and not sim.shells.has(follow):
		follow = null; stay = 3.0 if int(marks.n) < 3 else 6.0
	if follow != null:
		var kk: float = float(follow.t) / float(follow.T)
		_cam(follow.pos - Vector2(0, sin(PI * kk) * 180.0), lerpf(za * 1.1, zb * 0.8, smoothstep(0.0, 1.0, kk)), minf(1.0, d * 8.0))
	elif stay > 0.0:
		stay -= d; _cam(B.pos, zb, minf(1.0, d * 4.0))
		if stay <= 0.0 and int(marks.n) < 3:
			marks.next = t + 1.3; battle.camera.position = A.pos; battle.camera.zoom = Vector2.ONE * za
	else:
		_cam(A.pos, za, minf(1.0, d * 6.0))
		if t >= float(marks.next) and int(marks.n) < 3:
			marks.n = int(marks.n) + 1
			if int(marks.n) == 3: B.god = false   # the third salvo is let tell
			_salvo(A, lead, B); follow = _my_shell(A)
	return 27.0

# ---------------------------------------------------------------- 3. the Yamato against the missile age
func _init_yamato() -> void:
	A = sim.flag; B = sim.ships.filter(func(x): return x.side == 1)[0]
	A.pos = C; A.a = -PI / 2; A.hold = true; A.v = 12.0
	B.pos = C + Vector2(6000, -9000); _still(B)
	marks = {"cam": A.pos, "zoom": 0.6 * 1080.0 / float(A.d.L), "waves": [[3.2, 4], [9.0, 8], [15.0, 12]], "w": 0}
func _run_yamato(d: float, vw: float) -> float:
	A.v = 12.0; A.rud = 0.0
	var close: float = 0.6 * vw / float(A.d.L); var wide: float = vw / 900.0
	var w: int = int(marks.w)
	if w < marks.waves.size() and t >= float(marks.waves[w][0]):
		marks.w = w + 1
		for i in int(marks.waves[w][1]):
			var ang: float = -PI / 2 + randf_range(-0.9, 0.9) + (0.5 if w == 1 else 0.0)
			_missile(A.pos + Vector2.from_angle(ang) * randf_range(1500.0, 2100.0), A)
	var z: float = close if t < 2.2 else lerpf(wide, close * 0.8, smoothstep(20.0, 24.0, t))
	_cam(A.pos + Vector2(0, -120.0 if t > 2.2 and t < 20.0 else 0.0), z, minf(1.0, d * 2.2))
	return 26.0

# ---------------------------------------------------------------- 4. she goes down
func _init_sinking() -> void:
	A = sim.flag; B = sim.ships.filter(func(x): return x.side == 1)[0]
	A.pos = C + Vector2(7000, 7000); _still(A)
	B.pos = C; B.a = -PI / 2; _still(B, 6.0); sim.flag = null
	marks = {"cam": B.pos, "zoom": 0.78 * 1080.0 / float(B.d.L), "hits": [3.0, 6.5], "h": 0, "sunk": false}
func _torp(s, side_: float, along: float) -> void:
	var p: Vector2 = s.pos + Vector2(along * float(s.d.L), side_ * float(s.d.B) * 0.45).rotated(s.a)
	sim.hit_systems(s, p, 420.0, "torp"); sim.damage(s, 420.0, "torp"); sim.part(BattleSim.P.GEYSER, p, 1.6, 40.0); sim.fx_boom(p, 30.0, 1.0)
func _run_sinking(d: float, vw: float) -> float:
	if B.alive: B.v = maxf(0.0, 6.0 - t * 0.5)
	var h: int = int(marks.h)
	if h < marks.hits.size() and t >= float(marks.hits[h]):
		marks.h = h + 1; _torp(B, 1.0, 0.18 - 0.36 * h)
	if t >= 10.0 and not marks.sunk:
		marks.sunk = true; sim.damage(B, B.max_hull * 10.0, "resolved")
	_cam(B.pos, lerpf(0.78, 0.6, smoothstep(0.0, 22.0, t)) * vw / float(B.d.L), minf(1.0, d * 3.0))
	return 23.0

# ---------------------------------------------------------------- 5. night action
func _init_night() -> void:
	var i := 0; var j := 0
	for s in sim.ships:
		if s.side == 0:
			s.pos = C + Vector2(-250.0 - 330.0 * i, 560); s.a = 0.0; i += 1
		else:
			s.pos = C + Vector2(250.0 + 330.0 * j, -620); s.a = PI; j += 1
		_still(s, 8.0); s.radar_on = false
	A = sim.flag; B = sim.ships.filter(func(x): return x.side == 1)[0]
	sim.hold_fire = true; marks = {"cam": C + Vector2(0, 300), "zoom": 1080.0 / 1500.0, "star": false, "go": false}
func _run_night(d: float, vw: float) -> float:
	if not marks.go:
		for s in sim.ships: s.v = 8.0
	if t >= 4.5 and not marks.star:
		marks.star = true
		if not sim.fire_star(A, B.pos + Vector2(-150, 0)): sim.flares.append({"p": B.pos + Vector2(-150, 0), "t": -2.5, "v": 0})
	if t >= 7.2 and not marks.go:
		marks.go = true; sim.hold_fire = false; sim.flag = null
		for s in sim.ships:
			s.ai_off = false; s.hold = false; s.radar_on = true
	var mid: Vector2 = (A.pos + B.pos) * 0.5
	_cam(mid, vw / lerpf(1500.0, 1250.0, smoothstep(0.0, 24.0, t)), minf(1.0, d * 2.0))
	return 25.0

# ---------------------------------------------------------------- 2. eighty years in thirty seconds
func _init_eras() -> void:
	marks = {"cam": C, "zoom": 1.5}
func _seg(i: int) -> void:
	seg = i; seg_t = 0.0; _clear(); follow = null
	match i:
		0:   # the 1940s: a gun duel
			A = _put("ca_baltimore", 0, C + Vector2(-400, 700), 0.0, []); B = _put("ca_hipper", 1, C + Vector2(-200, -1500), 0.0, [])
			sim.flag = null; _warm(40.0)
		1:   # the missile age: a destroyer lets her missiles go
			A = _put("ddg_sovremenny", 0, C + Vector2(-300, 500), 0.0, ["radar", "missiles"]); B = _put("ca_hipper", 1, C + Vector2(0, -5200), 0.0, [])
			sim.flag = null; _still(B, 8.0)
		2:   # jets: missiles let go from far off
			A = _put("cv_forrestal", 0, C + Vector2(0, 7000), -PI / 2, E4); B = _put("ca_hipper", 1, C, 0.0, [])
			_still(A, 10.0); sim.flag = null
			for k in 2:
				sim.launch_strike(A, B); _warm(20.0)
			_warm(600.0, func(): return sim.missiles.any(func(m): return int(m.side) == 0 and m.pos.distance_to(B.pos) < 1500.0))
		3:   # the network age: hidden guns and the rail gun
			A = _put("cg_thunder", 0, C + Vector2(-300, 600), 0.0, E4); _put("ddg_zumwalt", 0, C + Vector2(-800, 1000), 0.0, E4)
			B = _put("ddg_sovremenny", 1, C + Vector2(0, -2300), 0.0, ["radar", "missiles"]); sim.flag = null; _warm(6.0)
	battle.camera.position = A.pos if i != 2 else B.pos
func _run_eras(d: float, vw: float) -> float:
	var want: int = mini(3, int(t / 6.5))
	if want != seg: _seg(want)
	seg_t += d
	match seg:
		0: _cam(A.pos + Vector2(0, -60), 0.7 * vw / float(A.d.L), 1.0)
		1: _cam(A.pos + Vector2(0, -80), 0.6 * vw / float(A.d.L), 1.0)
		2: _cam(B.pos + Vector2(0, 150), vw / 800.0, 1.0)
		3: _cam(A.pos + Vector2(0, -40), 0.72 * vw / float(A.d.L), 1.0)
	return 26.0
