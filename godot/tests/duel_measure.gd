extends Node
## Tuning measure for new designs (13 Nov 2026): each is fought against an established design of her era at about equal
## money (ships and their standard guns), both sides under their captains, several times each way round, and the share
## of the money each side has left afloat is reported. Near 50% is fairly priced; far above, she is cheap for what she is.
##   godot --headless --path godot res://tests/duel_measure.tscn -- [design,design,...]
const PAIRS := {   # new design: [the established design she is set against, era for both sides' research]
	"ddg_zumwalt": ["ddg_burke", 4], "ddg_gorshkov": ["ddg_sovremenny", 4], "co_visby": ["co_castle", 4], "co_shadow": ["ddg_adams", 4],
	"ff_perry": ["ddg_adams", 3], "ff_independence": ["ddg_burke", 4], "ddg_type42": ["ddg_county", 3], "ddg_type45": ["ddg_burke", 4],
	"ff_bremen": ["ddg_kashin", 3], "ddg_kongo": ["ddg_burke", 3], "ff_mogami": ["ddg_sovremenny", 4], "ff_maestrale": ["ddg_adams", 3],
	"ddg_doria": ["ddg_burke", 4], "ff_sachsen": ["ddg_burke", 4], "co_braunschweig": ["ddg_adams", 4], "co_karakurt": ["ddg_adams", 4],
	"co_steregushchiy": ["ddg_kashin", 4], "ddg_hatsuyuki": ["ddg_adams", 3], "co_gepard": ["dd_gearing", 3], "co_sparviero": ["dd_fletcher", 3],
	"ff_thaon": ["ddg_sovremenny", 4], "cg_thunder": ["cg_tico", 4], "co_opv": ["co_castle", 4],
	"ddg_sovremenny": ["ddg_burke", 3], "cg_slava": ["cg_tico", 3], "cg_kirov": ["cg_tico", 3],   # the Directorate's big ships, after the 130 mm automatic gun and the heavy missile (13 Nov 2026)
	"ssn_yasen": ["ddg_burke", 4], "ssn_astute": ["ddg_burke", 4], "ssn_trafalgar": ["ddg_adams", 3], "ss_212": ["ddg_adams", 4], "ss_206": ["dd_gearing", 3], "ss_harushio": ["ddg_adams", 3], "ss_soryu": ["ddg_adams", 4],
}
const RUNS := 4
func _worth(id: String, tech: Array) -> float:
	var d: Dictionary = GameData.hulls[id]; var w: float = float(d.price)
	for wid in BattleSim.default_fit(d, tech): if wid != null and wid != "": w += float(GameData.weapons[wid].price)
	return w
func _recs(id: String, n: int, tech: Array, pal: String) -> Array:
	var out := []
	for i in n: out.append({"type": id, "name": "%s %d" % [pal, i], "hullFrac": 1.0, "fit": BattleSim.default_fit(GameData.hulls[id], tech), "pal": pal})
	return out
func _ready() -> void:
	var sk = preload("res://scripts/skirmish.gd"); var only: Array = []
	for a in OS.get_cmdline_user_args(): only.append_array(a.split(","))
	Weather.force = {"sea": 1, "fog": false, "night": false, "moon": 0.5}
	print("design, against, ships, her worth, their worth, her share left, their share left, verdict")
	for id in PAIRS:
		if not only.is_empty() and not only.has(id): continue
		if not GameData.hulls.has(id) or not GameData.hulls.has(PAIRS[id][0]): print(id, ": missing"); continue
		var ref: String = PAIRS[id][0]; var tech: Array = sk.ERA_TECH[int(PAIRS[id][1])]
		var wa: float = _worth(id, tech); var wb: float = _worth(ref, tech)
		# whole ships on each side, as near equal money as two to six hulls allow
		var best := [1, 1]; var bd := INF
		for na in range(1, 5): for nb in range(1, 7):
			var dd: float = absf(na * wa - nb * wb) / maxf(na * wa, nb * wb) + 0.03 * (na + nb)
			if dd < bd: bd = dd; best = [na, nb]
		var keep_a := 0.0; var keep_b := 0.0
		for run in RUNS:
			seed(1000 + run * 17)
			var sim := BattleSim.new(); var swap: bool = run % 2 == 1
			var ra: Array = _recs(id, best[0], tech, "player"); var rb: Array = _recs(ref, best[1], tech, "directorate")
			sim.setup(rb if swap else ra, ra if swap else rb, tech, tech, 1); sim.flag = null
			var steps := 0
			while not sim.finished and sim.t < 2400: sim.step(0.04); steps += 1
			var la := 0.0; var lb := 0.0
			for s in sim.ships:
				var mine: bool = (s.side == 0) != swap
				var k: float = (s.hull / s.max_hull) if s.alive else 0.0
				if mine: la += k
				else: lb += k
			keep_a += la / best[0]; keep_b += lb / best[1]
		keep_a /= RUNS; keep_b /= RUNS
		var verdict := "fair"
		if keep_a > keep_b + 0.3: verdict = "she is cheap for what she is"
		elif keep_b > keep_a + 0.3: verdict = "she is dear for what she is"
		print("%s, %s, %d v %d, %d, %d, %d%%, %d%%, %s" % [id, ref, best[0], best[1], int(best[0] * wa), int(best[1] * wb), int(keep_a * 100), int(keep_b * 100), verdict])
	get_tree().quit()
