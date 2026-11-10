extends Node
## Clips for Reels (owner's request): a battle fought by the simulation, HUD off, the camera cutting between ships,
## recorded upright by Godot's movie writer. tools/make_reels.sh runs every clip and turns them into MP4.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 30 \
##     --write-movie <out.avi> res://tests/reel.tscn -- <duel|night|destroyers|torpedo> [seconds]
## Each clip is a list of cuts: [second, who ("me", "them", "mid"), zoom, lead in metres along her course].
const CLIPS := {
	"duel": {"player": ["bb_iowa", "ca_baltimore"], "enemy": ["bb_bismarck", "ca_hipper"], "sep": 3000.0, "pre": 45.0, "wx": {},
		"cuts": [[0.0, "me", 3.0, 20.0], [4.0, "them", 2.6, 0.0], [8.5, "mid", 0.32, 0.0], [11.0, "them", 3.4, 0.0]]},
	"night": {"player": ["ca_desmoines", "dd_gearing", "dd_gearing"], "enemy": ["ca_takao", "dd_kagero", "dd_kagero"], "sep": 2600.0, "pre": 30.0, "wx": {"sea": 0, "fog": false, "night": true, "moon": 0.7},
		"cuts": [[0.0, "me", 3.2, 20.0], [4.5, "them", 3.0, 0.0], [9.0, "mid", 0.36, 0.0], [12.0, "me", 4.0, 0.0]]},
	"destroyers": {"player": ["dd_fletcher", "dd_fletcher", "dd_fletcher"], "enemy": ["dd_narvik", "dd_narvik", "dd_narvik"], "sep": 1800.0, "pre": 25.0, "wx": {"sea": 1, "fog": false, "night": false, "moon": 0.5},
		"cuts": [[0.0, "me", 6.0, 10.0], [4.0, "them", 5.5, 0.0], [8.0, "mid", 0.5, 0.0], [11.0, "them", 7.0, 0.0]]},
	"torpedo": {"player": ["dd_kagero", "dd_kagero", "dd_kagero", "dd_kagero"], "enemy": ["bb_kgv", "ca_baltimore"], "sep": 2400.0, "pre": 35.0, "wx": {"sea": 0, "fog": false, "night": false, "moon": 0.5},
		"cuts": [[0.0, "me", 5.5, 10.0], [4.0, "mid", 0.4, 0.0], [7.5, "them", 3.0, 0.0]]},
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
	GameData.pending = {"player": clip.player, "enemy": clip.enemy, "enemy_fac": "directorate", "player_tech": ["radar"], "enemy_tech": ["radar"], "islands": 0}
	if not clip.wx.is_empty(): GameData.pending.weather = Weather.battle(clip.wx)
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _ship(side: int):
	var best = null
	for s in battle.sim.ships: if s.side == side and s.alive and (best == null or s.d.L > best.d.L): best = s
	return best
func _process(d: float) -> void:
	f += 1
	var sim = battle.sim
	if f == 2:   # the two lines on parallel courses, broadside to broadside, already in range
		var me: Array = sim.ships.filter(func(s): return s.side == 0); var them: Array = sim.ships.filter(func(s): return s.side == 1)
		var c := Vector2(12000, 12000)
		var up := -PI / 2   # every ship heads up the screen: an upright frame suits a ship seen along her length
		for i in me.size(): me[i].pos = c + Vector2(clip.sep * 0.5, i * 420.0); me[i].a = up; me[i].v = 9.0; me[i].throttle = 3
		for i in them.size(): them[i].pos = c + Vector2(-clip.sep * 0.5, i * 420.0 - 200.0); them[i].a = up; them[i].v = 9.0; them[i].throttle = 3
		sim.flag = null   # both sides fought by the simulation
		battle.hud.visible = false; battle.speed_i = 1; battle.cam_free = true
		for n in ["overlay"]: if battle.layers.has(n): battle.layers[n].visible = false
		var n := 0   # the action is already joined when the clip opens: the ranges found, shells in the air, smoke over the water
		while n < int(float(clip.pre) / 0.02) and not sim.finished:
			sim.step(0.02); n += 1
			if n % 3 == 0: sim.fx(0.06)
	if f < 3: return
	t += d
	var cut: Array = clip.cuts[0]
	for c in clip.cuts: if t >= float(c[0]): cut = c
	var a = _ship(0); var b = _ship(1); var want := cam_pos
	if a != null and b != null:
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
