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
	# a fleet action: two battle lines with their cruisers and destroyers
	# the super battleships (12 Nov 2026): A-150 and Montana against Yamato and Sovetsky Soyuz
	"super": {"player": ["bb_a150", "bb_montana", "ca_desmoines", "dd_gearing"], "enemy": ["bb_yamato", "bb_soyuz", "ca_takao", "dd_kagero"], "sep": 3800.0, "pre": 70.0, "wx": {"sea": 1, "fog": false, "night": false, "moon": 0.5},
		"cuts": [[0.0, "me", 2.3, 30.0], [4.0, "them", 2.2, 0.0], [8.0, "mid", 0.3, 0.0], [11.0, "me", 3.0, 0.0]]},
	# two carriers working up a strike together, the deck runs busy, then the squadrons formed up overhead
	"carrier_ops": {"player": ["cv_essex", "cv_essex", "dd_fletcher", "dd_fletcher"], "enemy": ["bb_yamato", "ca_takao"], "sep": 15000.0, "pre": 25.0, "wx": {}, "place": "ahead",
		"cuts": [[0.0, "deck", 5.0, 0.0], [4.5, "me", 2.4, 120.0], [9.0, "air", 3.4, 0.0]]},
	# a strike arriving over an enemy squadron: the flak, the torpedo runs, bombs and water columns
	"air_attack": {"player": ["cv_essex", "cv_essex", "cv_essex"], "enemy": ["bb_yamato", "ca_takao", "dd_kagero", "dd_kagero"], "sep": 9000.0, "pre": 700.0, "until": "strike_in", "wx": {}, "place": "ahead",
		"cuts": [[0.0, "air", 3.6, 0.0], [3.5, "them", 2.8, 0.0], [8.0, "them", 3.6, 0.0], [11.5, "air", 3.2, 0.0]]},
	# a fleet action in a rising sea at dusk: the lines in spray and gun flashes
	"heavy_sea": {"player": ["bb_iowa", "bb_kgv", "ca_baltimore", "dd_fletcher", "dd_fletcher"], "enemy": ["bb_bismarck", "bb_littorio", "ca_hipper", "dd_narvik", "dd_narvik"], "sep": 3200.0, "pre": 60.0, "wx": {"sea": 3, "fog": false, "night": false, "moon": 0.5},
		"cuts": [[0.0, "me", 2.8, 20.0], [4.0, "them", 2.6, 0.0], [8.0, "mid", 0.3, 0.0], [11.0, "them", 3.4, 0.0]]},
	# the owner's request (12 Nov 2026): night, a storm, star shell, and carriers' jets going in on a battleship. Aircraft
	# cannot take off in a storm, so the strike is flown off in the heavy sea before it and goes in as the storm breaks
	# ("storm_at" puts the weather the camera rolls in); both sides light the action with star shell ("stars")
	"night_storm": {"player": ["cv_forrestal", "cv_forrestal", "dd_gearing", "dd_gearing", "dd_gearing"], "enemy": ["bb_yamato", "dd_kagero", "dd_kagero"], "sep": 9000.0, "pre": 900.0,
		"until": "strike_d", "until_d": 3800.0, "split": true, "screen": true,
		"wx": {"sea": 2, "fog": false, "night": true, "moon": 0.25}, "storm_at": {"sea": 3, "fog": false, "night": true, "moon": 0.25}, "stars": true, "place": "ahead", "tech": ["radar", "jets", "missiles"],
		"cuts": [[0.0, "launching", 1.2, 120.0], [4.5, "them", 2.4, 0.0], [10.5, "them", 1.1, 0.0]]},
	"fleet": {"player": ["bb_iowa", "bb_kgv", "ca_baltimore", "ca_baltimore", "dd_fletcher", "dd_fletcher"], "enemy": ["bb_bismarck", "bb_scharnhorst", "ca_hipper", "ca_hipper", "dd_narvik", "dd_narvik"], "sep": 3400.0, "pre": 60.0, "wx": {},
		"cuts": [[0.0, "me", 2.6, 20.0], [4.0, "them", 2.4, 0.0], [8.0, "mid", 0.3, 0.0], [11.0, "them", 3.2, 0.0]]},
	# destroyers hunting a dived boat: she lies ahead of them, they find her with sonar and run in over her
	"sub_hunt": {"player": ["dd_fletcher", "dd_fletcher", "dd_fletcher"], "enemy": ["ss_vii"], "sep": 1300.0, "pre": 900.0, "until": "dc", "wx": {}, "place": "ahead", "hunt": true,
		"cuts": [[0.0, "dropper", 3.2, -75.0], [2.6, "pattern", 2.3, 0.0], [8.5, "dropper", 1.7, -160.0]]},
	# submarines: a torpedo attack on a convoy (a depth-charge hunt was tried and dropped: staged this way the destroyers never get over the boat)
	"sub_attack": {"player": ["ss_gato", "ss_gato"], "enemy": ["ao_t2", "fr_liberty", "fr_liberty"], "sep": 2200.0, "pre": 900.0, "until": "torp_close", "wx": {},
		"cuts": [[0.0, "torp", 5.0, 0.0], [3.5, "victim", 2.8, 0.0], [11.0, "sub", 6.0, 0.0]]},
}
var battle: Node
var clip: Dictionary
var t := 0.0
var ui := false
var length := 15.0
var f := 0
var cam_pos := Vector2.ZERO
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	clip = CLIPS[a[0] if a.size() and CLIPS.has(a[0]) else "duel"]
	if a.size() > 1: length = float(a[1])
	ui = a.size() > 2 and a[2] == "ui"   # the interface on (the owner asked for each clip with it and without)
	seed(11); Settings.sensors = false
	GameData.pending = {"quiet": true, "player": clip.player, "enemy": clip.enemy, "enemy_fac": "directorate", "player_tech": clip.get("tech", ["radar"]), "enemy_tech": ["radar"], "islands": 0}
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
var pattern_at = null
func _ready_to_roll(sim, n: int) -> bool:
	match String(clip.get("until", "")):
		"torp_close":
			for tp in sim.torps: for s in sim.ships: if s.side != tp.side and s.alive and s.pos.distance_to(tp.pos) < 330.0: return true
		"strike_in":
			for q in sim.air: if q.side == 0 and q.state == "out" and q.up > 0 and q.target != null and q.pos.distance_to(q.target.pos) < 1700.0: return true
		"strike_d":   # the first strike's dive bombers this far from their target
			for q in sim.air: if q.side == 0 and q.type == "db" and q.state == "out" and q.up > 0 and q.target != null and q.pos.distance_to(q.target.pos) < float(clip.until_d): return true
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
			if left < dc0 and dropper != null: pattern_at = sim.dc_pattern(dropper)[0]
			return left < dc0
	return false
func _spot(who: String, lead: float) -> Variant:
	var sim = battle.sim
	match who:
		"air":
			for q in sim.air: if q.side == 0 and q.up > 0: return q.pos + Vector2(-26.0, 0).rotated(q.a)
		"launching":   # the carrier flying off her strike, with her screen about her: the camera on her, a little ahead
			for s in sim.ships:
				if s.side == 0 and s.alive and not s.squads.is_empty() and not s.deck_ops.is_empty(): return s.pos + Vector2.from_angle(s.a) * lead
			for s in sim.ships:
				if s.side == 0 and s.alive and not s.squads.is_empty() and s.deck_out <= 0.0 and s.ai_off: return s.pos + Vector2.from_angle(s.a) * lead
		"deck":
			for s in sim.ships:
				if s.side != 0 or s.deck_ops.is_empty(): continue
				return s.deck_ops[0].pos
		"torp":
			for tp in sim.torps: return tp.pos + Vector2.from_angle(tp.a) * 40.0
		"victim":   # the ship the torpedoes are running at: once chosen, stay with her
			if victim == null:
				var bd := INF
				for tp in sim.torps: for s in sim.ships: if s.side != tp.side and s.alive and s.pos.distance_to(tp.pos) < bd: bd = s.pos.distance_to(tp.pos); victim = s
			if victim != null: return victim.pos
		"sub":
			for s in sim.ships: if s.sub and s.alive: return s.pos
		"pattern":   # the water where the pattern was laid: the camera stays there while the charges go off and the ship runs on
			if pattern_at != null: return pattern_at
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
			var cvs: Array = me.filter(func(x): return not x.squads.is_empty())
			if clip.get("screen", false) and cvs.size() > 0:   # destroyers screening the carrier the camera opens on, close about her
				var cv = cvs[cvs.size() - 1]; var k := 0
				for x in me:
					if not x.squads.is_empty(): continue
					x.pos = cv.pos + [Vector2(-320, -420), Vector2(330, -380), Vector2(0, -700)][k % 3]; x.a = up; k += 1
			for s in cvs:   # the carriers hold their course into the wind and send everything they have
				s.ai_off = true; s.throttle = 3; s.rudder = 0.0
				if not clip.get("split", false) or s == cvs[0]: sim.launch_strike(s, them[0])   # (split: the first one's strike is already on its way)
				else: for q in s.squads: if q.state == "ready": q.state = "held"   # her captain would fly them off in the run-up: held for the camera
		sim.flag = null   # both sides fought by the simulation
		battle.hud.visible = ui; battle.speed_i = 1; battle.cam_free = true
		battle.set_clean(not ui)   # without: no interface, no rings; shells, tracer, missiles and aircraft stay
		Sfx.music("")           # the game's own sounds only: a clip gets its music where it is posted
		if clip.get("hunt", false):
			for s in sim.ships:
				if s.sub: s.dive = 1.0; s.want_dive = true; s.hold = true
				else: s.smoke_left = 0.0
		var n := 0   # the action is already joined when the clip opens: the ranges found, shells in the air, smoke over the water
		while n < int(float(clip.pre) / 0.02) and not sim.finished and not _ready_to_roll(sim, n):
			sim.step(0.02); n += 1
			if n % 3 == 0: sim.fx(0.06)
	if f < 3: return
	if f == 3 and clip.get("split", false):   # the other carrier flies off her strike as the camera rolls on her
		var them1 = _ship(1)
		for s in sim.ships:
			if s.side != 0 or them1 == null: continue
			var held := false
			for q in s.squads: if q.state == "held": q.state = "ready"; held = true
			if held: sim.launch_strike(s, them1)
	if f == 3 and clip.has("storm_at"): sim.wx = Weather.battle(clip.storm_at); battle.apply_weather()   # the storm breaks as the camera rolls
	if clip.get("stars", false) and f % 180 == 3:   # the target's escorts keep star shell burning over and beside her (their own, so it is
		var tg = _ship(1)                                  # there as the camera rolls: ours, from 8 km off, took fourteen seconds to arrive)
		if tg != null:
			var off := Vector2(170.0, -260.0) if (f / 180) % 2 == 0 else Vector2(-210.0, 160.0)   # in the frame with her
			sim.flares.append({"p": tg.pos + off, "t": 1.6, "v": randi() % 4})
	t += d
	if clip.get("hunt", false):   # a depth-charge hunt: the boat stays down and silent, and nobody hides the picture in smoke
		for s in sim.ships:
			if s.sub: s.want_dive = true; s.dive = maxf(s.dive, 0.9); s.hold = true
			else: s.smoke_left = 0.0; s.smoke_on = false
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
