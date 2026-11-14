extends Node
## Tuning measure for new designs (13 Nov 2026; value index 14 Nov 2026): each is fought against an established design of
## her era in the mixes of whole ships nearest equal money (ships and their standard guns), both sides under their
## captains, several times each way round. Her index is the money she destroys for the money she fields, over the same for
## her peer: 1 is fair, above 1.5 she is cheap for what she is, below 0.67 dear.
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
## Fights each way round (environment DUEL_RUNS for a larger sample; 4 by default).
var RUNS := int(OS.get_environment("DUEL_RUNS")) if OS.get_environment("DUEL_RUNS") != "" else 4
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
	print("design, against, her worth, their worth, value index (1 fair, above cheap, below dear), verdict  (mixes)")
	for id in PAIRS:
		if not only.is_empty() and not only.has(id): continue
		if not GameData.hulls.has(id) or not GameData.hulls.has(PAIRS[id][0]): print(id, ": missing"); continue
		var ref: String = PAIRS[id][0]; var tech: Array = sk.ERA_TECH[int(PAIRS[id][1])]
		var wa: float = _worth(id, tech); var wb: float = _worth(ref, tech)
		# whole ships on each side: the (up to) three mixes nearest equal money, so no one count decides it (the owner, 14 Nov 2026:
		# 1 v 1 and 3 v 4 gave opposite verdicts). Each side is scored by the money it destroys for the money it fields;
		# her index is her score over the peer's, pooled over the mixes: 1 is fair, above 1 she is cheap, below dear.
		var mixes := []
		for na in range(1, 5): for nb in range(1, 5):
			var lr: float = absf(log(na * wa / (nb * wb)))
			if lr < 0.45: mixes.append([lr + 0.02 * (na + nb), na, nb])
		mixes.sort_custom(func(x, y): return x[0] < y[0])
		mixes = mixes.slice(0, 3)
		if mixes.is_empty(): mixes = [[0.0, 1, 1]]
		var dealt_a := 0.0; var dealt_b := 0.0; var field_a := 0.0; var field_b := 0.0; var notes := []
		for mx in mixes:
			var na: int = mx[1]; var nb: int = mx[2]; var la_m := 0.0; var lb_m := 0.0
			for run in RUNS:
				seed(1000 + run * 17 + na * 101 + nb * 7)
				var sim := BattleSim.new(); var swap: bool = run % 2 == 1
				var ra: Array = _recs(id, na, tech, "player"); var rb: Array = _recs(ref, nb, tech, "directorate")
				sim.setup(rb if swap else ra, ra if swap else rb, tech, tech, 1); sim.flag = null
				while not sim.finished and sim.t < 2400: sim.step(0.04)
				for sh in sim.ships:
					var mine: bool = (sh.side == 0) != swap
					var lost: float = 1.0 - ((sh.hull / sh.max_hull) if sh.alive else 0.0)
					if mine: la_m += lost * wa
					else: lb_m += lost * wb
			field_a += na * wa * RUNS; field_b += nb * wb * RUNS; dealt_a += lb_m; dealt_b += la_m
			notes.append("%dv%d: she lost %d%%, they lost %d%%" % [na, nb, int(100 * la_m / (na * wa * RUNS)), int(100 * lb_m / (nb * wb * RUNS))])
		var eff_a: float = dealt_a / maxf(1.0, field_a); var eff_b: float = dealt_b / maxf(1.0, field_b)
		var idx: float = (eff_a + 0.02) / (eff_b + 0.02)
		var verdict := "fair"
		if idx > 1.5: verdict = "she is cheap for what she is"
		elif idx < 0.67: verdict = "she is dear for what she is"
		print("%s, %s, %d, %d, index %.2f, %s  (%s)" % [id, ref, int(wa), int(wb), idx, verdict, "; ".join(notes)])
	get_tree().quit()
