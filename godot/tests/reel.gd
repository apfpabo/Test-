extends Node
## Clips for Reels (owner's request): a battle fought by the simulation, HUD off, the camera cutting between ships,
## recorded upright by Godot's movie writer. tools/make_reels.sh runs every clip and turns them into MP4.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 30 \
##     --write-movie <out.avi> res://tests/reel.tscn -- <clip> [seconds]
## Each clip is a list of cuts: [second, who, zoom, lead in metres along her course]. Who: "me" and "them" (each side's
## largest ship), "mid", "air" (a squadron in the air), "deck" (the machine on the deck run or the approach, else the
## carrier), "torp" (a torpedo running), "sub" (a submarine). A clip's "until" names what the action is run forward to
## before the camera rolls: "torp_close", "strike_in", "landing", "dc"; "place" "ahead" puts the enemy up the screen.
const CLIPS := {
	"duel": {"player": ["bb_iowa", "ca_baltimore"], "enemy": ["bb_bismarck", "ca_hipper"], "sep": 3000.0, "pre": 45.0, "wx": {},
		"cuts": [[0.0, "me", 3.0, 20.0], [4.0, "them", 2.6, 0.0], [8.5, "mid", 0.32, 0.0], [11.0, "them", 3.4, 0.0]]},
	"night": {"player": ["ca_desmoines", "dd_gearing", "dd_gearing"], "enemy": ["ca_takao", "dd_kagero", "dd_kagero"], "sep": 2600.0, "pre": 30.0, "wx": {"sea": 0, "fog": false, "night": true, "moon": 0.7},
		"cuts": [[0.0, "me", 3.2, 20.0], [4.5, "them", 3.0, 0.0], [9.0, "mid", 0.36, 0.0], [12.0, "me", 4.0, 0.0]]},
	"destroyers": {"player": ["dd_fletcher", "dd_fletcher", "dd_fletcher"], "enemy": ["dd_narvik", "dd_narvik", "dd_narvik"], "sep": 1800.0, "pre": 25.0, "wx": {"sea": 1, "fog": false, "night": false, "moon": 0.5},
		"cuts": [[0.0, "me", 6.0, 10.0], [4.0, "them", 5.5, 0.0], [8.0, "mid", 0.5, 0.0], [11.0, "them", 7.0, 0.0]]},
	"torpedo": {"player": ["dd_kagero", "dd_kagero", "dd_kagero", "dd_kagero"], "enemy": ["bb_kgv", "ca_baltimore"], "sep": 2400.0, "pre": 35.0, "wx": {"sea": 0, "fog": false, "night": false, "moon": 0.5},
		"cuts": [[0.0, "me", 5.5, 10.0], [4.0, "mid", 0.4, 0.0], [7.5, "them", 3.0, 0.0]]},
	# carriers: the strike going off the deck one machine after another, the attack going in, and the squadrons coming home
	"carrier_launch": {"player": ["cv_essex", "dd_fletcher", "dd_fletcher"], "enemy": ["ca_hipper"], "sep": 16000.0, "pre": 5.0, "wx": {}, "place": "ahead",
		"cuts": [[0.0, "me", 3.4, 70.0], [5.0, "deck", 6.5, 0.0], [9.5, "me", 1.5, 220.0]]},
	"carrier_strike": {"player": ["cv_essex", "cv_essex"], "enemy": ["bb_bismarck", "ca_hipper", "dd_narvik"], "sep": 9000.0, "pre": 600.0, "until": "strike_in", "wx": {}, "place": "ahead",
		"cuts": [[0.0, "air", 2.6, 0.0], [4.0, "them", 1.9, 0.0], [9.0, "them", 3.0, 0.0]]},
	"carrier_landing": {"player": ["cv_essex", "dd_fletcher"], "enemy": ["fr_liberty"], "sep": 7000.0, "pre": 1500.0, "until": "landing", "wx": {}, "place": "ahead",
		"cuts": [[0.0, "me", 2.6, -110.0], [5.0, "deck", 4.0, 0.0], [9.5, "me", 3.2, -60.0]]},
	"carrier_jets": {"player": ["cv_forrestal", "ddg_adams"], "enemy": ["ca_hipper"], "sep": 20000.0, "pre": 5.0, "wx": {}, "place": "ahead", "tech": ["radar", "jets", "missiles"],
		"cuts": [[0.0, "me", 2.6, 60.0], [5.5, "deck", 3.6, 0.0], [9.5, "air", 1.6, 0.0]]},
	# submarines: a torpedo attack on a convoy (a depth-charge hunt was tried and dropped: staged this way the destroyers never get over the boat)
	"sub_attack": {"player": ["ss_gato", "ss_gato"], "enemy": ["ao_t2", "fr_liberty", "fr_liberty"], "sep": 2200.0, "pre": 900.0, "until": "torp_close", "wx": {},
		"cuts": [[0.0, "torp", 5.0, 0.0], [3.5, "victim", 2.8, 0.0], [11.0, "sub", 6.0, 0.0]]},
}
var battle: Node
var clip: Dictionary
var t := 0.0
var length := 15.0
var f := 0
var cam_pos := Vector2.ZERO
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	clip = CLIPS[a[0] if a.size() and CLIPS.has(a[0]) else "duel"]
	if a.size() > 1: length = float(a[1])
	seed(11); Settings.sensors = false
	GameData.pending = {"player": clip.player, "enemy": clip.enemy, "enemy_fac": "directorate", "player_tech": clip.get("tech", ["radar"]), "enemy_tech": ["radar"], "islands": 0}
	if not clip.wx.is_empty(): GameData.pending.weather = Weather.battle(clip.wx)
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _ship(side: int):
	var best = null
	for s in battle.sim.ships: if s.side == side and s.alive and (best == null or s.d.L > best.d.L): best = s
	return best
## Has the action reached the moment the clip is to open on?
var dc0 := -1
var victim = null
var dropper = null
func _ready_to_roll(sim, n: int) -> bool:
	match String(clip.get("until", "")):
		"torp_close":
			for tp in sim.torps: for s in sim.ships: if s.side != tp.side and s.alive and s.pos.distance_to(tp.pos) < 330.0: return true
		"strike_in":
			for q in sim.air: if q.side == 0 and q.state == "out" and q.up > 0 and q.target != null and q.pos.distance_to(q.target.pos) < 1700.0: return true
		"landing":
			if n < 200: for s in sim.ships: if s.side == 1: s.god = true
			for q in sim.air: if q.side == 0 and q.state == "land": for s in sim.ships: if not s.deck_ops.is_empty() and s.deck_ops[0].k == "ld": return true
		"dc":
			var left := 0
			for s in sim.ships:
				if s.side != 0: continue
				left += s.dc_left
				if dropper == null or s.dc_left < dropper.dc_left: dropper = s   # the one whose racks have been emptied
			if dc0 < 0: dc0 = left
			return left < dc0
	return false
func _spot(who: String, lead: float) -> Variant:
	var sim = battle.sim
	match who:
		"air":
			for q in sim.air: if q.side == 0 and q.up > 0: return q.pos + Vector2(-26.0, 0).rotated(q.a)
		"deck":
			for s in sim.ships:
				if s.side != 0 or s.deck_ops.is_empty(): continue
				var op: Dictionary = s.deck_ops[0]; var span: Vector2 = sim.deck_span(s)
				return sim.world_pt(s, lerpf(span.x, span.y, 0.75 if op.k == "to" else 0.1), 0.0)
		"torp":
			for tp in sim.torps: return tp.pos + Vector2.from_angle(tp.a) * 40.0
		"victim":   # the ship the torpedoes are running at: once chosen, stay with her
			if victim == null:
				var bd := INF
				for tp in sim.torps: for s in sim.ships: if s.side != tp.side and s.alive and s.pos.distance_to(tp.pos) < bd: bd = s.pos.distance_to(tp.pos); victim = s
			if victim != null: return victim.pos
		"sub":
			for s in sim.ships: if s.sub and s.alive: return s.pos
		"dropper":   # the ship that dropped the pattern, and the water astern of her where it bursts
			if dropper != null: return dropper.pos + Vector2.from_angle(dropper.a) * lead
	return null
func _process(d: float) -> void:
	f += 1
	var sim = battle.sim
	if f == 2:   # the two lines on parallel courses, broadside to broadside, already in range
		var me: Array = sim.ships.filter(func(s): return s.side == 0); var them: Array = sim.ships.filter(func(s): return s.side == 1)
		var c := Vector2(12000, 12000)
		var up := -PI / 2   # every ship heads up the screen: an upright frame suits a ship seen along her length
		for i in me.size(): me[i].pos = c + Vector2(clip.sep * 0.5, i * 420.0); me[i].a = up; me[i].v = 9.0; me[i].throttle = 3
		for i in them.size(): them[i].pos = c + Vector2(-clip.sep * 0.5, i * 420.0 - 200.0); them[i].a = up; them[i].v = 9.0; them[i].throttle = 3
		if String(clip.get("place", "")) == "ahead":   # the enemy far up the screen, coming on
			for i in me.size(): me[i].pos = c + Vector2(i * 500.0 * (1 if i % 2 else -1), i * 250.0)
			for i in them.size(): them[i].pos = c + Vector2(i * 450.0, -clip.sep - i * 300.0); them[i].a = -up
			for s in me:   # the carriers hold their course into the wind and send everything they have
				if s.squads.is_empty(): continue
				s.ai_off = true; s.throttle = 3; s.rudder = 0.0; sim.launch_strike(s, them[0])
		sim.flag = null   # both sides fought by the simulation
		battle.hud.visible = false; battle.speed_i = 1; battle.cam_free = true
		battle.set_clean(true)   # no interface, no rings; shells, tracer, missiles and aircraft stay
		var n := 0   # the action is already joined when the clip opens: the ranges found, shells in the air, smoke over the water
		while n < int(float(clip.pre) / 0.02) and not sim.finished and not _ready_to_roll(sim, n):
			sim.step(0.02); n += 1
			if n % 3 == 0: sim.fx(0.06)
	if f < 3: return
	t += d
	var cut: Array = clip.cuts[0]
	for c in clip.cuts: if t >= float(c[0]): cut = c
	var a = _ship(0); var b = _ship(1); var want := cam_pos
	var sp = _spot(String(cut[1]), float(cut[3]))
	if sp != null: want = sp
	elif a != null and b != null:
		match String(cut[1]):
			"me": want = a.pos + Vector2.from_angle(a.a) * float(cut[3])
			"them": want = b.pos
			_: want = (a.pos + b.pos) * 0.5
	elif a != null: want = a.pos
	elif b != null: want = b.pos
	var fresh: bool = absf(t - float(cut[0])) < d * 1.5 or f == 3
	cam_pos = want if fresh else cam_pos.lerp(want, 0.08)
	battle.camera.position = cam_pos
	var z: float = float(cut[2]) * (1.0 + 0.04 * (t - float(cut[0])))   # a slow push in on every cut
	if String(cut[1]) == "mid" and a != null and b != null: z = clampf(760.0 / maxf(a.pos.distance_to(b.pos), 500.0), 0.25, 1.4)   # wide enough for both flagships, no wider
	battle.camera.zoom = Vector2.ONE * (z if fresh else lerpf(battle.camera.zoom.x, z, 0.2))
	if t >= length: get_tree().quit()
