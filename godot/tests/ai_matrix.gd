extends Node
## AI against AI across eras and opening ranges (the owner's improvement pack, 14 Nov 2026): looks for fights that stall
## or never resolve, and for where heavy shells land hits. Each pairing is played from several opening ranges to an end or
## to LIMIT seconds; a stall is STALL seconds with no damage done while both sides still have ships.
## godot --headless --path godot res://tests/ai_matrix.tscn [-- name,name]
const LIMIT := 3600.0
const STALL := 900.0
const RANGES := [4000.0, 9000.0, 16000.0]
const PAIRS := [
	{"name": "bb_i", "era": 1, "a": ["bb_iowa"], "b": ["bb_bismarck"]},
	{"name": "ca_i", "era": 1, "a": ["ca_baltimore"], "b": ["ca_hipper"]},
	{"name": "dd_i", "era": 1, "a": ["dd_fletcher", "dd_fletcher"], "b": ["dd_narvik", "dd_narvik"]},
	{"name": "bb_ii", "era": 2, "a": ["bb_montana"], "b": ["bb_soyuz"]},
	{"name": "msl_v_gun_ii", "era": 2, "a": ["ddg_adams"], "b": ["cl_sverdlov"]},
	{"name": "msl_v_bb_iii", "era": 3, "a": ["ddg_burke"], "b": ["bb_iowa"]},
	{"name": "msl_v_msl_iii", "era": 3, "a": ["ddg_burke"], "b": ["ddg_sovremenny"]},
	{"name": "cg_iii", "era": 3, "a": ["cg_tico"], "b": ["cg_slava"]},
	{"name": "ff_iv", "era": 4, "a": ["ff_sachsen"], "b": ["ff_thaon"]},
	{"name": "ddg_iv", "era": 4, "a": ["ddg_type45"], "b": ["ddg_zumwalt"]},
	{"name": "msl_night_ii", "era": 2, "a": ["ddg_adams"], "b": ["cl_sverdlov"], "wx": {"sea": 1, "fog": false, "night": true, "moon": 0.1}},
	{"name": "msl_fog_ii", "era": 2, "a": ["ddg_kashin"], "b": ["dd_daring"], "wx": {"sea": 2, "fog": true, "night": false, "moon": 0.5}},
	{"name": "msl_night_iii", "era": 3, "a": ["ddg_sovremenny"], "b": ["bb_iowa"], "wx": {"sea": 1, "fog": false, "night": true, "moon": 0.0}},
]
func _ready() -> void:
	var sk = preload("res://scripts/skirmish.gd")
	var only: Array = []
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: only = Array(args[0].split(","))
	var bins := {}   # heavy shells by range band (km): [fired, hit]
	var bad := 0
	for pr in PAIRS:
		if not only.is_empty() and not only.has(pr.name): continue
		for R in RANGES:
			seed(int(R) + pr.name.hash() % 1000)
			var tech: Array = sk.ERA_TECH[pr.era]
			var recs := func(ids: Array, pal: String) -> Array:
				var out := []
				for i in ids.size(): out.append({"type": ids[i], "name": "%s %d" % [pal, i], "hullFrac": 1.0, "fit": BattleSim.default_fit(GameData.hulls[ids[i]], tech), "pal": pal})
				return out
			var sim := BattleSim.new(); sim.sep = R
			sim.wx = Weather.battle(pr.get("wx", {"sea": 1, "fog": false, "night": false, "moon": 0.5}))
			sim.setup(recs.call(pr.a, "player"), recs.call(pr.b, "directorate"), tech, tech, 0)
			sim.flag = null
			var last_dmg := 0.0; var dmg_t := 0.0; var stalled := 0.0; var first_hit := -1.0
			var near := 1e9; var far := 0.0; var steps := 0
			var live: Array = []
			while not sim.finished and sim.t < LIMIT:
				for sh in sim.shells:
					if String(sh.size) == "H" and not live.any(func(x): return is_same(x, sh)): live.append(sh)   # by identity: a shell changes as it flies, and dictionaries compare by content
				sim.step(0.05); steps += 1
				if steps % 20 == 0: sim.fx(1.0)
				var gone := []
				for sh in live: if not sim.shells.any(func(x): return is_same(x, sh)): gone.append(sh)
				for sh in gone:
					live = live.filter(func(x): return not is_same(x, sh))
					var r: float = (sh.e - sh.s).length(); var band := int(r / 1000.0)
					if not bins.has(band): bins[band] = [0, 0]
					bins[band][0] += 1
					for s in sim.ships:
						if s.side == sh.side or not s.alive: continue
						var l: Vector2 = (sh.pos - s.pos).rotated(-s.a)
						if absf(l.x) < s.d.L / 2 + 3 and absf(l.y) < s.d.B / 2 + 3: bins[band][1] += 1; break
				var tot := 0.0
				for s in sim.ships: tot += s.dmg_taken
				if tot > last_dmg + 0.01:
					if first_hit < 0: first_hit = sim.t
					last_dmg = tot; dmg_t = sim.t
				var a0 := sim.ships.filter(func(s): return s.side == 0 and s.alive and not s.escaped)
				var a1 := sim.ships.filter(func(s): return s.side == 1 and s.alive and not s.escaped)
				if not a0.is_empty() and not a1.is_empty():
					var d: float = a0[0].pos.distance_to(a1[0].pos); near = minf(near, d); far = maxf(far, d)
					stalled = maxf(stalled, sim.t - maxf(dmg_t, 0.0))
			var verdict := "ok"
			if not sim.finished: verdict = "UNRESOLVED"
			elif stalled >= STALL: verdict = "STALLED"
			if verdict != "ok": bad += 1
			var r2: Dictionary = sim.result
			print("%-14s %5d m  %-10s  %5d s  first hit %5d s  longest lull %5d s  closest %6d m  widest %6d m  sunk %d escaped %d" % [pr.name, int(R), verdict, int(sim.t), int(first_hit), int(stalled), int(near), int(far), r2.get("sunk", []).size() if r2.get("sunk") is Array else int(r2.get("sunk", 0)), r2.get("escaped", []).size() if r2.get("escaped") is Array else int(r2.get("escaped", 0))])
	var keys := bins.keys(); keys.sort()
	print("heavy shells by range (km: hits of fired):")
	for k in keys: print("  %2d-%2d km  %4d of %5d  (%.1f%%)" % [k, k + 1, bins[k][1], bins[k][0], 100.0 * bins[k][1] / maxf(1, bins[k][0])])
	print("AI MATRIX: %d fights stalled or unresolved" % bad)
	get_tree().quit()
