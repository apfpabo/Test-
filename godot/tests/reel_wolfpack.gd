extends Node
## A staged clip for Reels (owner's brief, 11 Nov 2026): three freighters in line ahead, centred; torpedoes come in
## from off the screen and sink them; then the three boats that fired, already dived. Captions and the tag are put on
## afterwards (tools/make_wolfpack.sh). Recorded upright by the movie writer, no interface, no music.
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 30 \
##     --write-movie <out.avi> res://tests/reel_wolfpack.tscn
const T_TORPS := 3.2     # the torpedoes are fired (off the screen to starboard)
const T_BOATS := 15.5    # cut to the boats
const T_END := 22.0
var battle: Node
var t := 0.0
var f := 0
var fired := false
var mid = null
func _ready() -> void:
	seed(4); Settings.sensors = false
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	GameData.pending = {"quiet": true, "player": ["ss_vii", "ss_vii", "ss_vii"], "enemy": ["fr_liberty", "fr_liberty", "fr_liberty"], "enemy_fac": "concord", "player_tech": [], "enemy_tech": [], "islands": 0}
	battle = load("res://scenes/battle.tscn").instantiate(); add_child(battle)
func _process(d: float) -> void:
	f += 1
	var sim = battle.sim
	var boats: Array = sim.ships.filter(func(s): return s.side == 0); var ships: Array = sim.ships.filter(func(s): return s.side == 1)
	if f == 2:
		var c := Vector2(12000, 12000); var up := -PI / 2
		for i in ships.size():   # line ahead, a cable and a half apart, steaming up the screen
			var s = ships[i]; s.pos = c + Vector2(0, (i - 1) * 235.0); s.a = up; s.v = 5.6; s.throttle = 2; s.ai_off = true; s.rudder = 0.0; s.hull = 620.0; s.flee = false
		for i in boats.size():   # the boats, well off to starboard and already under, in line abreast
			var b = boats[i]; b.pos = c + Vector2(2600.0 + (i - 1) * 62.0, 300.0 + absf(i - 1) * 38.0); b.a = up;   # three abreast, the middle boat a little ahead, running up the screen b.v = 1.6; b.throttle = 1; b.dive = 0.63; b.want_dive = true; b.ai_off = true; b.hold = true
		sim.flag = null; sim.hold_fire = true; mid = ships[1]
		battle.set_clean(true); Sfx.music(""); battle.speed_i = 1; battle.cam_free = true
		battle.camera.position = mid.pos; battle.camera.zoom = Vector2.ONE * 2.5
	if f < 3: return
	t += d
	for b in boats: b.want_dive = true; b.dive = 0.63   # under, but shallow enough to be seen from above
	sim.finished = false
	if not fired and t >= T_TORPS:
		fired = true   # two torpedoes for each ship, laid to meet her: she steams up the screen while they run in
		for s in ships:
			var run := 300.0; var secs: float = run / (23.0 * 2.0)   # the battle runs at twice the clock
			for k in 2:
				var meet: Vector2 = s.pos + Vector2.from_angle(s.a) * (s.v * 2.0 * secs + (k - 0.5) * 46.0)
				sim.torps.append({"pos": meet + Vector2(run + k * 40.0, 0.0), "a": PI, "speed": 23.0, "life": 60.0, "dmg": 650, "side": 0, "homing": false, "arm": 0.0})
	if t < T_BOATS:
		if mid != null: battle.camera.position = battle.camera.position.lerp(mid.pos, 0.15)
		battle.camera.zoom = Vector2.ONE * (2.5 + 0.01 * t)
	else:
		var b = boats[1]
		if absf(t - T_BOATS) < d * 1.5: battle.camera.position = b.pos
		else: battle.camera.position = battle.camera.position.lerp(b.pos, 0.2)
		battle.camera.zoom = Vector2.ONE * (5.6 + 0.07 * (t - T_BOATS))
	if t >= T_END: get_tree().quit()
