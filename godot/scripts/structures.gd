extends Node
## Land structures (autoload `Structures`): farms, steelworks, oil and industrial works, airfields, coastal batteries,
## radar stations and naval bases. Rules only, no drawing; the chart (world_map.gd) and the raid view (air_raid.gd)
## show them. See docs/LAND_STRUCTURES.md.
##
## Each structure is a record in the saved game (Campaign.G.structs, index = id):
##   id, kind, x, y (map units, on land), land, port (the port it belongs to), coastKm (distance inland), name,
##   fac (owner: a power, "player" for yours, "" unclaimed), home (who held it in March 1946), from (who held it
##   before you took it), dmg (0..1: share of its defences knocked out), ruin (0..1: share of its output wrecked),
##   garrison (your men holding it), took (day taken), store (naval bases: goods kept there), sx, sy (naval bases: the
##   harbour's sea point).
## Owner "player" is the seed of step 5 (founding your own flag): a held structure already behaves like a small
## territory of yours, with a garrison, upkeep, income and enemies who want it back.
##
## Capture is by surrender: strikes silence the defences, then a garrison is landed from your crews while your fleet
## lies off the coast. landing_force() is the one place that says what lands; troop transports (an auxiliary class,
## roadmap step 3) can replace the crews there.

var D: Dictionary = {}
var _tick := 0.0

func _ready() -> void:
	var f := FileAccess.open("res://data/structures.json", FileAccess.READ)
	D = JSON.parse_string(f.get_as_text()) if f != null else {}

func g() -> Dictionary: return Campaign.G
func all() -> Array: return g().get("structs", [])
func kind(s: Dictionary) -> Dictionary: return D.kinds[s.kind]
func cover_units() -> float: return float(D.cover_km) / Campaign.KM_PER_UNIT
func battery_units() -> float: return float(D.battery_km) / Campaign.KM_PER_UNIT

# ------------------------------------------------------------------ building the world's structures
## Builds the structures from the world tables (LAND_SITES, INSTALLATIONS) if the saved game has none yet.
func ensure() -> void:
	var G := g()
	if G.has("structs") and not G.structs.is_empty():
		for s in G.structs: if not s.has("shore"): _to_shore(s)   # saves from before coastal installations stood on the coast
		return
	var C: Dictionary = Campaign.C; var out := []
	var src := []
	for q in C.get("LAND_SITES", []): src.append(q)
	for q in C.get("INSTALLATIONS", []): src.append(q)
	var used := {}
	for q in src:
		var s := {"id": out.size(), "kind": q.kind, "x": float(q.x), "y": float(q.y), "land": q.get("land", ""), "coastKm": int(q.get("coastKm", 50)),
			"dmg": 0.0, "ruin": 0.0, "garrison": 0, "from": "", "took": -1}
		var p = _owner_port(s)
		s.port = int(p.id) if p != null else int(q.get("port", 0))
		s.fac = p.fac if p != null else ""
		s.home = s.fac
		s.name = _name(s, p, q.get("strait", ""), used)
		if s.kind == "navalbase": s.store = {}
		_to_shore(s)
		out.append(s)
	G.structs = out

const COASTAL := ["battery", "radar", "navalbase"]
## Batteries, radar stations and naval bases stand on the coast itself, about 2 km inland, facing the sea. (The world
## build's land grid is 0.1 degrees, so its nearest inland cell is already 11 km from the water: too far for a gun
## position or a harbour.) Other structures keep their place.
func _to_shore(s: Dictionary) -> void:
	s.shore = true
	if not COASTAL.has(s.kind): return
	var w := Campaign.nearest_water(s.x, s.y, 80)
	if Campaign.on_land(w.x, w.y): return
	var d := Vector2(Campaign.wdx(w.x, s.x), s.y - w.y); var L := d.length()
	if L < 0.01: return
	var u := d / L; var p := Vector2(w.x, w.y)
	for i in int(L / 0.1) + 1:   # walk from the water back towards the old place until the shore
		p += u * 0.1
		if Campaign.on_land(p.x, p.y): break
	p += u * 0.35   # a couple of km inland
	s.x = Campaign.wrap_x(p.x); s.y = p.y; s.coastKm = 2
	for k in ["face", "cx", "cy", "ox", "oy"]: s.erase(k)
	if s.kind == "navalbase": s.sx = w.x; s.sy = w.y

## The port a structure belongs to: the nearest on the same landmass within reach, else a port just across the
## water, else none (the structure is unclaimed: the far south, the empty island groups).
func _owner_port(s: Dictionary):
	var best = null; var bd: float = float(D.owner_reach)
	for p in g().ports:
		var d := Campaign.mdist(s.x, s.y, p.x, p.y)
		if p.get("land", "") == s.land and d < bd: bd = d; best = p
	if best != null: return best
	bd = 260.0
	for p in g().ports:
		var d := Campaign.mdist(s.x, s.y, p.x, p.y)
		if d < bd: bd = d; best = p
	return best

func _name(s: Dictionary, p, strait: String, used: Dictionary) -> String:
	var noun: String = kind(s).noun
	var base: String
	if strait != "": base = strait
	elif p != null and Campaign.mdist(s.x, s.y, p.x, p.y) < 500.0: base = p.name
	else: base = String(s.land).trim_prefix("the ")
	var nm := "%s %s" % [base, noun]
	if used.has(nm) and p != null:
		var a := Campaign.mang(p.x, p.y, s.x, s.y)
		var dir: String = ["East", "South", "West", "North"][int(round(fposmod(a, TAU) / (PI / 2))) % 4]
		nm = "%s %s %s" % [dir, base, noun]
	var n := 2; var root := nm
	while used.has(nm): nm = "%s No. %d" % [root, n]; n += 1
	used[nm] = true
	return nm[0].to_upper() + nm.substr(1)

# ------------------------------------------------------------------ defences
func _doc(fac: String, k: String) -> float: return float(D.doctrine.get(fac, D.doctrine[""]).get(k, 1.0))
func _era(fac := "") -> float: return 1.0 + 0.25 * (Campaign.fac_era(fac) - 1) if fac != "" and fac != "player" else 1.0

## Is a structure on watch for another: same owner, or an ally (relations 50+).
func _friend(a: String, b: String) -> bool:
	if a == "" or b == "": return false
	if a == b: return true
	if a == "player" or b == "player": return false
	return Diplomacy.rel(a, b) >= float(Diplomacy.D.bands.allied)

## Radar warning over a structure: its own radar, or one of its flag (or an ally's) within 300 km.
func radar_cover(s: Dictionary) -> bool:
	if s.kind == "radar" and s.dmg < float(D.silenced): return true
	for r in all():
		if r.kind == "radar" and r.dmg < float(D.silenced) and _friend(r.fac, s.fac) and Campaign.mdist(r.x, r.y, s.x, s.y) < cover_units(): return true
	return false

## The airfields whose fighters would rise over this structure (not counting its own).
func cover_fields(s: Dictionary) -> Array:
	var out := []
	for a in all():
		if a.id != s.id and a.kind == "airfield" and a.dmg < float(D.silenced) and _friend(a.fac, s.fac) and Campaign.mdist(a.x, a.y, s.x, s.y) < cover_units(): out.append(a)
	return out

## What defends a structure now: flak batteries, fighter squadrons (its own and half of each covering airfield's),
## heavy guns, and the radar multiplier.
func defences(s: Dictionary) -> Dictionary:
	var k := kind(s); var up: float = 1.0 - float(s.dmg); var fac: String = s.fac; var era := _era(fac)
	var flak: float = float(k.flak) * _doc(fac, "flak") * era * up
	var guns: float = float(k.guns) * _doc(fac, "guns") * up
	var own: float = float(k.fighters) * _doc(fac, "fighters") * up
	var cov := 0.0
	for a in cover_fields(s): cov += float(kind(a).fighters) * _doc(a.fac, "fighters") * (1.0 - float(a.dmg)) * 0.5
	if fac == "": flak = float(k.flak) * 0.3 * up; own = 0.0; cov = 0.0
	return {"flak": flak, "guns": guns, "fighters": own + cov, "own_fighters": own, "radar": 1.25 if radar_cover(s) and fac != "" else 1.0}

func silenced(s: Dictionary) -> bool: return float(s.dmg) >= float(D.silenced)

# ------------------------------------------------------------------ your carriers and their aircraft
## Planes aboard a carrier (6 to a squadron when full).
func planes(rec: Dictionary) -> int:
	var h: Dictionary = Campaign.hull(rec)
	if h.kind != "carrier": return 0
	return int(rec.get("air", int(h.get("hangar", 0)) * 6))
func planes_max(rec: Dictionary) -> int: return int(Campaign.hull(rec).get("hangar", 0)) * 6 if Campaign.hull(rec).kind == "carrier" else 0
func air_group() -> int:
	var n := 0
	for s in g().fleet: n += planes(s)
	return n
func jets() -> bool: return Campaign.has_tech("jets")
func plane_cost() -> int: return int(D.jet_cost if jets() else D.plane_cost)
## Cost to bring every air group up to strength.
func replace_cost() -> int:
	var n := 0
	for s in g().fleet: n += planes_max(s) - planes(s)
	return n * plane_cost()
func replace_planes() -> void:
	for s in g().fleet: if planes_max(s) > 0: s.air = planes_max(s)

## Days (fractional) until the air groups have rearmed after a strike.
func strike_wait() -> float:
	var G := g(); return maxf(0.0, float(G.get("strikeReady", 0.0)) - (G.day + G.dayF))

## Why a strike on this structure can't be flown now, or "".
func can_strike(s: Dictionary) -> String:
	var G := g(); var P: Dictionary = G.player
	if s.fac == "player": return "It is yours."
	if s.get("nuked", false): return "There is nothing left of it."
	if s.fac == "": return "Nobody holds it. Land a garrison to claim it."
	var car: Array = G.fleet.filter(func(r): return Campaign.hull(r).kind == "carrier")
	if car.is_empty(): return "You need a carrier to strike from the air."
	if air_group() < 4: return "Your carriers have too few aircraft left. Replace them in port."
	var wx: Dictionary = Campaign.weather_here()
	if not Weather.air_ok(wx, jets()): return "Your aircraft cannot fly: %s." % ("a storm" if int(wx.sea) >= 3 else ("fog" if wx.fog else "it is night, and only jets fly by night"))
	var reach := Campaign.strike_reach(G.fleet); var d := Campaign.mdist(P.x, P.y, s.x, s.y)
	if d > reach: return "Out of reach: %d km away, and your strike reach is %d km." % [int(d * Campaign.KM_PER_UNIT), int(reach * Campaign.KM_PER_UNIT)]
	if strike_wait() > 0.0: return "The air groups are rearming: ready in %d hours." % int(ceil(strike_wait() * 24.0))
	return ""

## Striking this structure breaks the armistice with its flag (a fleet's guns would too).
func breaks_armistice(s: Dictionary) -> bool: return s.fac != "" and s.fac != "player" and not Campaign.at_war(s.fac)

# ------------------------------------------------------------------ the air strike, settled before it is shown
## Settles a strike by every ready aircraft of your carriers against a structure: fighter interception, flak, then
## the bombs on the defences. Returns the raid's story for the raid view and the report.
func strike(s: Dictionary) -> Dictionary:
	var G := g(); var dfn := defences(s); var jet := jets()
	if breaks_armistice(s):
		G.rep[s.fac] = G.rep.get(s.fac, 0) - 30; Campaign.incident(s.fac); Diplomacy.on_open_fire(s.fac)
		for e in Campaign.enemies_of(s.fac): G.rep[e] = mini(100, G.rep.get(e, 0) + 5)
	elif s.fac != "" and s.fac != "player": G.rep[s.fac] = G.rep.get(s.fac, 0) - 3
	var n := air_group(); var ord := 0
	for r in G.fleet:
		if Campaign.hull(r).kind != "carrier": continue
		var o = Campaign.officer_of(r)
		if o != null: ord = maxi(ord, int(o.sk.ord))
	var F: float = float(dfn.fighters) * 6.0 * float(dfn.radar); var A: float = float(dfn.flak) * float(dfn.radar)
	var escorts := int(round(n * 0.3))
	# 1. the defending fighters meet the strike: the escorts tie some of them up
	var lost_f := 0; var downed := 0
	if F > 0.0:
		lost_f = mini(n - 1, int(round(n * clampf(F / (F + n * 0.9 + 1.0) * 0.45, 0.0, 0.5) * randf_range(0.7, 1.3) * (0.85 if jet else 1.0))))
		downed = mini(int(ceil(F)), int(round(F * clampf(escorts * (1.4 if jet else 1.0) / (F + escorts + 1.0) * 0.6, 0.0, 0.6) * randf_range(0.6, 1.3))))
	var through := n - lost_f
	# 2. flak over the target
	var lost_a := mini(through, int(round(through * clampf(0.035 * A, 0.0, 0.45) * randf_range(0.6, 1.4))))
	var bombers := through - lost_a
	# 3. the bombs: each plane's load against how hard the target is
	var hit: float = bombers * (1.5 if jet else 1.0) * (1.0 + 0.08 * ord) * randf_range(0.7, 1.3) / (float(kind(s).hard) * 30.0)
	var before := float(s.dmg)
	s.dmg = clampf(before + hit + (downed / maxf(1.0, float(dfn.own_fighters) * 6.0)) * 0.3 * float(dfn.own_fighters > 0.0), 0.0, 1.0)
	s.ruin = clampf(float(s.ruin) + hit * 0.3, 0.0, 0.9)
	s.struck = G.day
	# losses come off the carriers in turn; the strike group needs half a day to rearm
	var lost := lost_f + lost_a; var left := lost
	for r in G.fleet:
		if left <= 0: break
		var p := planes(r)
		if p <= 0: continue
		var k := mini(p, left); r.air = p - k; left -= k
	G.strikeReady = G.day + G.dayF + 0.5
	var res := {"id": s.id, "name": s.name, "kind": s.kind, "fac": s.fac, "planes": n, "jets": jet, "escorts": escorts,
		"fighters": int(round(F)), "lost_fighters": lost_f, "downed": downed, "flak": A, "lost_flak": lost_a, "bombers": bombers,
		"before": before, "after": float(s.dmg), "silenced": silenced(s), "ruin": float(s.ruin), "x": s.x, "y": s.y}
	Campaign.log_ev("Air strike on %s: %d aircraft lost, defences %d%% out of action" % [s.name, lost, int(float(s.dmg) * 100)])
	_strike_contracts(s, res)
	Campaign.save()
	return res

# ------------------------------------------------------------------ bombardment from the sea
## How far a weapon can reach ashore, in km: guns at their real range (battle ranges are a fifth of real), anti-ship
## missiles 120 km. 0 for anything that cannot.
static func shore_reach_km(w: Dictionary) -> float:
	if w.kind == "gun": return float(w.range) * 5.0 / 1000.0
	if w.kind == "ssm": return 120.0
	return 0.0

## Weight of fire a ship can put on a target this far away (km), allowing for what is left in her magazines; heavy
## shells count for more against concrete and earthworks.
func _ship_weight(rec: Dictionary, km: float) -> float:
	var wsum := 0.0
	for wid in rec.get("fit", []):
		if wid == null or wid == "" or not GameData.weapons.has(wid): continue
		var w: Dictionary = GameData.weapons[wid]
		if shore_reach_km(w) < km: continue
		if w.kind == "gun": wsum += float(w.dmg) * float(w.barrels) * 60.0 / float(w.rel) * float({"S": 0.4, "M": 0.6, "L": 0.9, "H": 1.4}.get(w.size, 0.5))
		else: wsum += float(w.dmg) * float(w.get("count", 2)) * 3.0
	return wsum * clampf(float(rec.get("ammo", 1.0)) / 0.15, 0.0, 1.0)

## Why the fleet cannot shell this structure now, or "".
func can_bombard(s: Dictionary) -> String:
	var G := g(); var P: Dictionary = G.player
	if s.fac == "player": return "It is yours."
	if s.get("nuked", false): return "There is nothing left of it."
	if s.fac == "": return "Nobody holds it. Land a garrison to claim it."
	var km := Campaign.mdist(P.x, P.y, s.x, s.y) * Campaign.KM_PER_UNIT
	var best := 0.0; var any := false
	for r in G.fleet:
		for wid in r.get("fit", []):
			if wid != null and wid != "" and GameData.weapons.has(wid): best = maxf(best, shore_reach_km(GameData.weapons[wid]))
		if _ship_weight(r, km) > 0.0: any = true
	if best <= 0.0: return "Your ships carry no guns or missiles that can reach ashore."
	if km > best: return "Out of range: %d km away, and your longest reach ashore is %d km (heavy guns about 30 km, missiles 120 km). Close the coast." % [int(km), int(best)]
	if not any: return "Your magazines are too low to shoot. Rearm in port."
	var wait := maxf(0.0, float(G.get("bombardReady", 0.0)) - (G.day + G.dayF))
	if wait > 0.0: return "The guns are being made ready: %d hours." % int(ceil(wait * 24.0))
	return ""

## A bombardment: every ship with guns (or missiles) in reach shoots for an hour. The structure's heavy guns answer.
## Shells come out of the magazines. Returns its story for the bombardment view and the report.
func bombard(s: Dictionary) -> Dictionary:
	var G := g(); var P: Dictionary = G.player; var dfn := defences(s)
	if breaks_armistice(s):
		G.rep[s.fac] = G.rep.get(s.fac, 0) - 30; Campaign.incident(s.fac); Diplomacy.on_open_fire(s.fac)
		for e in Campaign.enemies_of(s.fac): G.rep[e] = mini(100, G.rep.get(e, 0) + 5)
	elif s.fac != "" and s.fac != "player": G.rep[s.fac] = G.rep.get(s.fac, 0) - 3
	var km := Campaign.mdist(P.x, P.y, s.x, s.y) * Campaign.KM_PER_UNIT
	var weight := 0.0; var firing := []; var heavy := false
	for r in G.fleet:
		var wgt := _ship_weight(r, km)
		if wgt <= 0.0: continue
		weight += wgt; firing.append(r.name); r.ammo = maxf(0.0, float(r.get("ammo", 1.0)) - 0.15)
		for wid in r.fit: if wid != "" and GameData.weapons.has(wid) and GameData.weapons[wid].get("size", "") == "H": heavy = true
	var before := float(s.dmg)
	var hit: float = weight * randf_range(0.75, 1.25) / (float(kind(s).hard) * 7000.0)
	s.dmg = clampf(before + hit, 0.0, 1.0); s.ruin = clampf(float(s.ruin) + hit * 0.25, 0.0, 0.9); s.struck = G.day
	# the answer from the shore: its heavy guns, while they stand
	var answers := []; var g_n := int(round(float(dfn.guns) * randf_range(0.5, 1.2)))
	for i in g_n:
		if G.fleet.is_empty() or randf() > 0.45: continue
		var sh: Dictionary = G.fleet.pick_random(); var h: Dictionary = Campaign.hull(sh)
		var d := randf_range(0.02, 0.06) * clampf(1500.0 / float(h.hull), 0.3, 1.5)
		sh.hullFrac = maxf(0.05, float(sh.hullFrac) - d); answers.append("%s hit (hull %d%%)" % [sh.name, int(sh.hullFrac * 100)])
	G.bombardReady = G.day + G.dayF + 0.25
	var res := {"mode": "naval", "id": s.id, "name": s.name, "kind": s.kind, "fac": s.fac, "km": int(km), "ships": firing, "heavy": heavy,
		"shells": clampi(int(weight / 400.0), 6, 40), "guns": float(dfn.guns), "answers": answers, "before": before, "after": float(s.dmg),
		"silenced": silenced(s), "ruin": float(s.ruin), "x": s.x, "y": s.y, "planes": 0, "jets": false, "fighters": 0, "lost_fighters": 0, "downed": 0, "flak": 0.0, "lost_flak": 0, "bombers": 0}
	Campaign.log_ev("Bombarded %s: defences %d%% out of action" % [s.name, int(float(s.dmg) * 100)])
	_strike_contracts(s, res)
	Campaign.save()
	return res

func _strike_contracts(s: Dictionary, res: Dictionary) -> void:
	var notes := []
	for c in g().get("contracts", []).duplicate():
		if c.kind == "strike" and int(c.struct) == int(s.id) and float(s.dmg) >= 0.7 and (s.fac == c.get("target", s.fac) or s.fac == ""): Diplomacy.complete(c, notes)
	res.notes = notes

# ------------------------------------------------------------------ surrender, occupation and garrisons
## The sea off the coast nearest a structure, reachable by sea (an inland lake won't do: then its port's
## roadstead). Cached in the record.
func coast_point(s: Dictionary) -> Vector2:
	if s.has("ox"): return Vector2(float(s.ox), float(s.oy))
	var p: Dictionary = g().ports[int(s.port)]; var w := Campaign.nearest_water(s.x, s.y, 80)
	# stand off the shore, clear of the land by about three map units, so a fleet can arrive without circling
	var out := Vector2(Campaign.wdx(s.x, w.x), w.y - s.y).normalized()
	if out != Vector2.ZERO:
		for i in 16:
			if not Campaign.land_near(w.x, w.y, 3.0): break
			var nx := w + out * 0.5
			if Campaign.on_land(nx.x, nx.y): break
			w = Vector2(Campaign.wrap_x(nx.x), nx.y)
	var ok := func(q: Vector2) -> bool: return not Campaign.on_land(q.x, q.y) and (Campaign.sight_line(p.sx, p.sy, q.x, q.y) or not Campaign.find_path(Vector2(p.sx, p.sy), q).is_empty())
	if not ok.call(w):
		# the nearest water is a lake, or cut off: look outwards in rings for open sea a fleet can reach, as far as the
		# structure is said to lie inland; only then fall back to its port
		var found := false; var far: float = float(s.coastKm) / Campaign.KM_PER_UNIT + 12.0; var r := 6.0
		while r <= far and not found:
			var n := int(clampf(r * 0.5, 12.0, 48.0)); var tries := 0
			for i in n:
				var q := Vector2(Campaign.wrap_x(s.x + cos(i * TAU / n) * r), s.y + sin(i * TAU / n) * r)
				if q.y < 10.0 or q.y > Campaign.MH - 10.0 or Campaign.on_land(q.x, q.y) or Campaign.land_near(q.x, q.y, 2.0): continue
				tries += 1
				if tries > 6: break   # a few candidates a ring: route finding is not free
				if ok.call(q): w = q; found = true; break
			r += maxf(4.0, r * 0.15)
		if not found: w = Vector2(p.sx, p.sy)
	s.ox = w.x; s.oy = w.y
	return w

## Close enough to land a garrison: the fleet lies off the coast nearest the structure.
func off_coast(s: Dictionary) -> bool:
	var P: Dictionary = g().player
	return Campaign.mdist(P.x, P.y, s.x, s.y) <= float(s.coastKm) / Campaign.KM_PER_UNIT + 14.0

## Men needed to hold it.
func garrison_need(s: Dictionary) -> int: return int(kind(s).garrison)

## What goes ashore to hold a structure: soldiers from your troopships first, then men from your crews.
func landing_force() -> int: return int(g().crew) + troops()

# ------------------------------------------------------------------ troopships and invasions
## Soldiers embarked in your troopships, and how many they can carry.
func troops() -> int: return int(g().get("troops", 0))
func troop_capacity() -> int:
	var n := 0
	for r in g().fleet: n += int(Campaign.hull(r).get("troops", 0))   # the transports in company: a detached main body keeps its own soldiers (its fleet's `troops`)
	return n
## Every soldier you pay and feed: those with you and those in a detached main body's transports.
func troops_all() -> int:
	var b = Campaign.body()
	return troops() + (int(b.get("troops", 0)) if b != null else 0)
const TROOP_COST := 40      # to embark a soldier in port
const TROOP_WAGE := 0.2     # a day

## Defenders a structure puts up against a landing: five men to every post of its garrison, thinned by every strike
## and bombardment, stiffened by radar warning and fighter cover.
func defenders(s: Dictionary) -> float:
	var d := defences(s)
	var base: float = float(kind(s).garrison) * 5.0 * (_doc(s.fac, "guns") * 0.3 + 0.7) if s.fac != "" else float(kind(s).garrison)
	return base * (1.0 - 0.75 * float(s.dmg)) * float(d.radar) + float(d.fighters) * 40.0

func can_invade(s: Dictionary) -> String:
	if s.get("nuked", false): return "A poisoned ruin. Nothing can be held here again."
	if s.fac == "player": return "It is yours."
	if troops() <= 0: return "You have no troops embarked. Troopships embark soldiers in port (Repairs & crew)."
	if not off_coast(s): return "Your fleet must lie off the coast nearest it (%d km inland)." % int(s.coastKm)
	return ""

## A landing: your soldiers against the defenders, fought out at once. Win, and the survivors hold it (those not needed
## for the garrison re-embark); lose, and the survivors are taken off again. Returns the story of it.
func invade(s: Dictionary) -> Dictionary:
	var G := g(); var old: String = s.fac; var men := troops(); var D := defenders(s)
	if breaks_armistice(s):
		G.rep[s.fac] = G.rep.get(s.fac, 0) - 30; Campaign.incident(s.fac); Diplomacy.on_open_fire(s.fac)
	var A: float = men * (1.25 if Campaign.has_tech("amphib") else 1.0)
	var odds := invade_odds(s)
	var won := randf() < odds
	var lost := int(round(men * clampf(D / maxf(1.0, A + D) * randf_range(0.5, 1.1) * (0.7 if won else 1.4), 0.03, 0.95)))
	var left := maxi(0, men - lost); G.troops = left
	var res := {"name": s.name, "men": men, "lost": lost, "won": won, "odds": odds, "defenders": int(round(D))}
	if won and left > 0:
		var need := garrison_need(s); var hold := mini(left, maxi(need, left))
		G.troops = left - mini(left, need); s.garrison = mini(left, need)
		if int(s.garrison) < need: s.garrison = int(s.garrison)   # a thin garrison holds it as best it can
		s.from = old; s.fac = "player"; s.took = G.day; s.dmg = maxf(float(s.dmg), 0.5)
		if old != "": G.rep[old] = G.rep.get(old, 0) - 10; Diplomacy.thanks(old, 1)
		Campaign.log_ev("Stormed the " + s.name)
	else:
		res.won = false
		s.dmg = minf(1.0, float(s.dmg) + 0.1)   # the attack costs them too
		Campaign.log_ev("Landing at the %s beaten off" % s.name)
	Campaign.save()
	return res

## The chance a landing carries the place: your soldiers (a quarter better with amphibious warfare) against its defenders.
func invade_odds(s: Dictionary) -> float:
	var A: float = troops() * (1.25 if Campaign.has_tech("amphib") else 1.0)
	return clampf(A / maxf(1.0, A + defenders(s)) * 1.3 - 0.15, 0.05, 0.95)
## Soldiers put aboard in port (TROOP_COST each), as many as there are berths and money for. Returns how many.
func embark(n: int) -> int:
	var G := g(); var k := mini(mini(n, troop_capacity() - troops()), int(G.credits / TROOP_COST))
	if k <= 0: return 0
	G.credits -= k * TROOP_COST; G.troops = troops() + k
	return k
func disembark() -> int:
	var n := troops(); g().troops = 0
	return n
## Soldiers without a berth (their transport was sunk or sold) are lost to you.
func trim_troops() -> int:
	var over := troops() - troop_capacity()
	if over > 0: g().troops = troop_capacity()
	var b = Campaign.body()
	if b != null:   # and the main body's, if it lost a transport
		var cap := 0
		for r in b.ships: cap += int(Campaign.hull(r).get("troops", 0))
		if int(b.get("troops", 0)) > cap: over = maxi(0, over) + int(b.troops) - cap; b.troops = cap
	if g().has("nukes"):   # and warheads go down with the boats that carried them
		var tubes := 0
		for r in Campaign.all_ships(): if Campaign.hull(r).klass == "ssn": for w in r.fit: if w != null and w != "" and GameData.weapons.has(w) and GameData.weapons[w].kind == "ssm": tubes += 1
		g().nukes = mini(int(g().nukes), tubes)
	return maxi(0, over)

# ------------------------------------------------------------------ nuclear weapons
## The treaties of 1945 kept nuclear weapons out of the world. With the Nuclear warheads research your missile
## submarines (nuclear boats with missile tubes) can carry them: one warhead to a missile tube, fitted at a port or
## naval base of your own or at an Enclave port. A warhead fired from the chart at a structure within reach destroys
## it for good: nothing can be built or held there again. Its owner is at war with you from that hour, at the lowest
## standing there is, and will not make peace; every other power turns on you; and a power of the missile age answers
## in kind against something you hold. The powers themselves never fire first.
const NUKE_COST := 120000
const NUKE_REACH_KM := 600.0
func nuke_boats() -> Array: return g().fleet.filter(func(r): return Campaign.hull(r).klass == "ssn" and r.fit.any(func(w): return w != null and w != "" and GameData.weapons.has(w) and GameData.weapons[w].kind == "ssm"))
func nuke_capacity() -> int:
	var n := 0
	for r in nuke_boats(): for w in r.fit: if w != null and w != "" and GameData.weapons.has(w) and GameData.weapons[w].kind == "ssm": n += 1
	return n
func nukes() -> int: return mini(int(g().get("nukes", 0)), nuke_capacity())
func can_arm(at_fac: String) -> String:
	var G := g()
	if not Campaign.has_tech("nukes"): return "Needs the Nuclear warheads research."
	if at_fac != "player" and at_fac != "enclave": return "Warheads are fitted only at a port or naval base of your own, or by the Enclaves."
	if nuke_capacity() <= 0: return "You have no missile submarine: a nuclear boat with missile tubes carries them."
	if nukes() >= nuke_capacity(): return "Every missile tube that can take a warhead has one (%d)." % nuke_capacity()
	if int(G.credits) < NUKE_COST: return "A warhead costs %s." % Campaign.fmt(NUKE_COST)
	return ""
func arm() -> void:
	var G := g(); G.credits -= NUKE_COST; G.nukes = nukes() + 1
func can_nuke(s: Dictionary) -> String:
	var G := g(); var P: Dictionary = G.player
	if s.get("nuked", false): return "There is nothing left of it."
	if s.fac == "player": return "It is yours."
	if nukes() <= 0: return "You carry no warheads."
	var d := Campaign.mdist(P.x, P.y, s.x, s.y) * Campaign.KM_PER_UNIT
	if d > NUKE_REACH_KM: return "Out of reach: %d km away, and the missiles reach %d km." % [int(d), int(NUKE_REACH_KM)]
	return ""
## Fires one. Returns what followed, for the report.
func nuke(s: Dictionary) -> Dictionary:
	var G := g(); var old: String = s.fac; G.nukes = maxi(0, int(G.get("nukes", 0)) - 1)   # one warhead, not the count clamped to the boats in company
	var res := {"name": s.name, "fac": old, "notes": [], "first": not G.get("nukeUsed", false)}
	s.nuked = true; s.fac = ""; s.dmg = 1.0; s.ruin = 1.0; s.garrison = 0; s.from = ""; s.erase("store")
	G.nukeUsed = true; G.nukeCount = int(G.get("nukeCount", 0)) + 1
	if old != "":
		G.rep[old] = -100; Campaign.incident(old); Diplomacy.on_open_fire(old)
		if not G.has("nukedFacs"): G.nukedFacs = []
		if not G.nukedFacs.has(old): G.nukedFacs.append(old)
		res.notes.append("The %s is at war with you from this hour, and will not treat with you again." % GameData.fac[old].name)
		if Campaign.fac_era(old) >= 3 or Diplomacy.POWERS.any(func(o): return o != old and Diplomacy.coalition_of(o) != "" and Diplomacy.coalition_of(o) == Diplomacy.coalition_of(old) and Campaign.fac_era(o) >= 3):
			if not G.has("nukeDebt"): G.nukeDebt = []
			G.nukeDebt.append({"fac": old, "day": int(G.day) + randi_range(20, 70)})
			res.notes.append("They have, or their allies have, weapons of the same kind. Expect an answer.")
	var turned := []
	for o in Diplomacy.POWERS:
		if o == old: continue
		var ally: bool = old != "" and (Diplomacy.coalition_of(o) != "" and Diplomacy.coalition_of(o) == Diplomacy.coalition_of(old) or Diplomacy.rel(o, old) >= 40.0)
		var enemy: bool = old != "" and Diplomacy.at_war(o, old)
		var hit: int = 60 if ally else (15 if enemy else 30)
		G.rep[o] = maxi(-100, int(G.rep.get(o, 0)) - hit)
		if ally: turned.append(GameData.fac[o].short)
	if G.has("flag"):   # no treaty or recognition survives it
		for k in ["treaty", "recog"]: if G.flag.has(k): G.flag[k] = {}
	if G.get("commission") != null: res.notes.append("Your commission is revoked."); G.commission = null
	res.notes.append("Every power has marked it: standing -60 with %s, -30 with the rest (-15 with the victim's enemies). Treaties and recognition of your flag are void." % (", ".join(turned) if not turned.is_empty() else "the victim's allies"))
	Diplomacy.news("THE BOMB. A nuclear weapon has destroyed the %s%s. The treaties of 1945 are ash. Every chancellery in the world knows whose missile it was." % [s.name, (", a %s possession" % GameData.fac[old].short) if old != "" else ""], true)
	Campaign.log_ev("Destroyed the %s with a nuclear weapon" % s.name); Campaign.save()
	return res
## A power that was struck answers in kind, once for each strike: it destroys the most valuable thing you hold.
func _nuke_answers() -> void:
	var G := g()
	for d in G.get("nukeDebt", []).duplicate():
		if int(G.day) < int(d.day): continue
		G.nukeDebt.erase(d)
		var mine: Array = held().filter(func(s): return not s.get("nuked", false))
		var ports: Array = Flag.ports()
		if not mine.is_empty():
			mine.sort_custom(func(a, b): return int(yield_of(a).get("money", 0)) + (5000 if a.kind == "navalbase" else 0) > int(yield_of(b).get("money", 0)) + (5000 if b.kind == "navalbase" else 0))
			var t: Dictionary = mine[0]
			t.nuked = true; t.fac = ""; t.dmg = 1.0; t.ruin = 1.0; var lost := int(t.garrison); t.garrison = 0; t.from = ""; t.erase("store")
			Diplomacy.news("RETALIATION. A %s missile destroys your %s. Its garrison of %d is gone, and nothing will stand there again." % [GameData.fac[d.fac].short, t.name, lost], true)
			Campaign.log_ev("Lost the %s to a nuclear weapon" % t.name)
		elif not ports.is_empty():
			var p: Dictionary = ports[0]; var men := int(p.get("men", 0)); p.men = int(men * 0.2); p.works = {}; p.volunteers = []
			Flag.disband_guard(p)
			Diplomacy.news("RETALIATION. A %s missile bursts over the harbour of %s. Four in five of the garrison are dead, the works are rubble and the guard squadron is gone." % [GameData.fac[d.fac].short, p.name], true)
			Campaign.log_ev("%s struck by a nuclear weapon" % p.name)
		else:
			var sh: Dictionary = G.fleet[randi() % G.fleet.size()]
			for x in G.fleet: x.hullFrac = maxf(0.05, float(x.hullFrac) - randf_range(0.2, 0.5))
			var dead := int(float(G.crew) * 0.3); G.crew -= dead
			Diplomacy.news("RETALIATION. A %s missile bursts over your squadron at sea. Every ship is damaged and %d of your men are dead." % [GameData.fac[d.fac].short, dead], true)

## Why it can't be taken now, or "".
func can_take(s: Dictionary) -> String:
	if s.get("nuked", false): return "A poisoned ruin. Nothing can be held here again."
	if s.fac == "player": return "It is yours."
	if not off_coast(s): return "Your fleet must lie off the coast nearest it (%d km inland)." % int(s.coastKm)
	if s.fac != "" and not silenced(s): return "The garrison will not surrender while its defences stand (%d%% out of action; it surrenders at %d%%)." % [int(float(s.dmg) * 100), int(float(D.silenced) * 100)]
	if landing_force() < garrison_need(s): return "You need %d men to hold it and have %d aboard." % [garrison_need(s), landing_force()]
	return ""

## The garrison surrenders (or an unclaimed site is occupied): your men land and hold it.
func take(s: Dictionary) -> String:
	var G := g(); var old: String = s.fac; var need := garrison_need(s)
	var from_troops := mini(troops(), need); G.troops = troops() - from_troops; G.crew -= need - from_troops; s.garrison = need; s.fac = "player"; s.erase("militia")
	if old != "": s.from = old   # an unclaimed site keeps the claim of whoever held it before you withdrew
	elif not s.has("from"): s.from = ""; s.took = G.day
	s.dmg = maxf(float(s.dmg), 0.5)   # what is left of the defences is yours to repair
	var t: String
	if old == "":
		t = "Your men land and run up your colours over the %s. Nobody contests it." % s.name
	else:
		G.rep[old] = G.rep.get(old, 0) - 10; Diplomacy.thanks(old, 1)
		t = "The garrison of the %s surrenders. %d of your men take it over. The %s will want it back." % [s.name, need, GameData.fac[old].name]
	Campaign.log_ev("Took the " + s.name)
	Campaign.save()
	return t

## Hand a structure taken from your flag's enemy to the flag you serve: standing and a reward instead of income.
func can_hand_over(s: Dictionary) -> bool:
	var c = g().get("commission")
	return s.fac == "player" and c != null and s.from != "" and s.from != c.fac
func hand_over(s: Dictionary) -> String:
	var G := g(); var cf: String = G.commission.fac
	var reward := int(round((6000.0 + 4000.0 * float(kind(s).military)) / 500.0) * 500)
	G.crew += maxi(0, int(s.garrison) - int(s.get("militia", 0))); s.erase("militia"); s.garrison = 0; s.fac = cf; s.from = ""; G.credits += reward
	G.rep[cf] = mini(100, G.rep.get(cf, 0) + 8)
	Campaign.log_ev("Handed the %s to the %s" % [s.name, GameData.fac[cf].name])
	return "You hand the %s over to the %s. %s, and standing +8." % [s.name, GameData.fac[cf].name, Campaign.fmt(reward)]

## Take the garrison off (only with the fleet off the coast): the structure is left unclaimed.
func withdraw(s: Dictionary) -> String:
	var n := maxi(0, int(s.garrison) - int(s.get("militia", 0)))   # a stormed port's militia stays ashore: only your own men re-embark
	var G := g(); G.crew += n; s.erase("militia")
	s.garrison = 0; s.fac = ""
	return "%d men re-embark from the %s. It is left to whoever comes next." % [n, s.name]

func held() -> Array: return all().filter(func(s): return s.fac == "player")
func garrison_total() -> int:
	var n := 0
	for s in held(): n += int(s.garrison)
	return n

# ------------------------------------------------------------------ income: monthly, money paid, goods to a depot
## Where a structure's goods are kept: your nearest naval base within 900 units, else the nearest port open to you
## within 900 units, else at the structure itself (collect them with the fleet off its coast).
func depot_of(s: Dictionary):
	var best = null; var bd := 900.0
	for b in held():
		if b.kind != "navalbase": continue
		var d := Campaign.mdist(b.x, b.y, s.x, s.y)
		if d < bd: bd = d; best = b
	if best != null: return best
	bd = 900.0
	for p in g().ports:
		if Campaign.hostile(p.fac): continue
		var d := Campaign.mdist(p.x, p.y, s.x, s.y)
		if d < bd: bd = d; best = p
	return best if best != null else s

## A month's output of a structure, after war damage.
func yield_of(s: Dictionary) -> Dictionary:
	if s.get("nuked", false): return {}
	var out := {}; var f: float = (1.0 - float(s.ruin)) * (1.0 - 0.5 * float(s.dmg))
	for k in kind(s).yields: out[k] = int(round(float(kind(s).yields[k]) * f))
	return out

func depot_name(dp) -> String: return dp.name if dp != null else "nowhere"

func _payday() -> void:
	var G := g(); var money := 0; var goods := {}
	for s in held():
		var y := yield_of(s)
		money += int(y.get("money", 0))
		var dp = depot_of(s)
		if dp == null: continue
		if not dp.has("store"): dp.store = {}
		for k in y:
			if k == "money" or int(y[k]) <= 0: continue
			dp.store[k] = int(dp.store.get(k, 0)) + int(y[k])
			var key := "%s at %s" % [k, dp.name]; goods[key] = int(goods.get(key, 0)) + int(y[k])
	if held().is_empty(): return
	G.credits += money
	var parts := []
	if money > 0: parts.append(Campaign.fmt(money))
	for k in goods: parts.append("%d %s" % [goods[k], k])
	Campaign.toast.emit("A month's yield from your holdings: %s." % (", ".join(parts) if parts.size() else "nothing"))
	Campaign.log_ev("Holdings: " + ", ".join(parts))

## The goods waiting at a port or naval base for you.
func store_of(dp: Dictionary) -> Dictionary: return dp.get("store", {})

# ------------------------------------------------------------------ the passing of days
func new_day() -> void:
	var G := g(); ensure()
	_nuke_answers()
	for s in all():
		if s.get("nuked", false): continue   # nothing mends there
		if s.fac != "player" or int(s.garrison) > 0:   # repairs: owners mend their defences; ruins come back slowly
			s.dmg = maxf(0.0, float(s.dmg) - float(D.repair_per_day))
		s.ruin = maxf(0.0, float(s.ruin) - float(D.ruin_per_day))
	if G.day % 30 == 0: _payday()
	_spotting()
	_counterattacks()
	_warnings()

## Enemy airfields spot your fleet within their reach and vector their flag's patrols onto you.
func _spotting() -> void:
	var G := g(); var P: Dictionary = G.player
	if not G.has("spotted"): G.spotted = {}
	for a in all():
		if a.kind != "airfield" or a.fac == "" or a.fac == "player" or silenced(a) or not Campaign.at_war(a.fac): continue
		if Campaign.mdist(a.x, a.y, P.x, P.y) > cover_units() * minf(1.0, Campaign.signature()) * (0.5 if Campaign.weather_here().night else 1.0): continue   # search planes find a darkened, slow squadron late, and little by night
		if G.day - int(G.spotted.get(str(a.id), -99)) < 3: continue
		G.spotted[str(a.id)] = G.day; var sent := 0
		for f in G.fleets:
			if f.fac != a.fac or f.kind != "patrol" or Campaign.mdist(f.x, f.y, P.x, P.y) > 700.0: continue
			if Campaign.set_course(f, P.x, P.y): sent += 1
		Campaign.toast.emit("Search planes from the %s have found you.%s" % [a.name, (" %s patrols are being vectored onto your position." % GameData.fac[a.fac].short) if sent else ""])

## Coastal batteries of flags that engage you shell your ships while you are in range. Called from Campaign.update.
func tick(dt: float) -> void:
	_tick -= dt
	if _tick > 0.0: return
	_tick = 3.0   # about a third of a day at 1×
	var G := g(); var P: Dictionary = G.player
	if G.fleet.is_empty(): return
	for s in all():
		if s.kind != "battery" or s.fac == "" or s.fac == "player" or silenced(s) or not Campaign.at_war(s.fac): continue
		if Campaign.mdist(s.x, s.y, P.x, P.y) > battery_units(): continue
		var guns: float = float(defences(s).guns)
		if randf() > 0.35 + 0.1 * guns: Campaign.toast.emit("Shells from the %s fall short." % s.name); continue
		var sh: Dictionary = G.fleet.pick_random(); var d := randf_range(0.02, 0.05) * guns / 4.0
		sh.hullFrac = maxf(0.05, float(sh.hullFrac) - d)
		Campaign.toast.emit("The %s straddles you: the %s is hit (hull %d%%). Open the range, or silence it from the air." % [s.name, sh.name, int(sh.hullFrac * 100)])

# ------------------------------------------------------------------ the powers fight over structures
## In a war, one side may take a structure of the other near its own ports. Called from Diplomacy.new_day per war.
func war_tick(k: String) -> void:
	if randf() > float(D.struct_war_chance): return
	var G := g(); var ab: PackedStringArray = k.split("|")
	var att: String = ab[0] if randf() < 0.5 else ab[1]; var dfn: String = ab[1] if att == ab[0] else ab[0]
	var best = null; var bd := 1200.0
	for s in all():
		if s.fac != dfn: continue
		for p in G.ports:
			if p.fac != att: continue
			var d := Campaign.mdist(s.x, s.y, p.x, p.y)
			if d < bd: bd = d; best = s
	if best == null: return
	var at := {"sx": best.x, "sy": best.y}
	var la := Diplomacy.local_might(att, at); var ld := Diplomacy.local_might(dfn, at) + 15000.0 * (1.0 + float(defences(best).flak) * 0.2)
	if randf() < clampf(la / maxf(1.0, la + ld), 0.05, 0.6):
		best.fac = att; best.dmg = 0.6; best.ruin = minf(0.9, float(best.ruin) + 0.2)
		Diplomacy.news("The %s takes the %s from the %s." % [GameData.fac[att].name, best.name, GameData.fac[dfn].short], Campaign.mdist(best.x, best.y, G.player.x, G.player.y) < 900.0)

## A port changed hands: the structures that belong to it and were held by the old owner go with it.
func on_port_captured(p: Dictionary, old: String, by: String) -> void:
	for s in all():
		if int(s.port) == int(p.id) and s.fac == old: s.fac = by

## Powers whose structures you took send assault forces to retake them; powers at war with you try for what you
## hold near their ports.
func _counterattacks() -> void:
	var G := g(); var live: Array = G.fleets.filter(func(f): return _is_assault(f))
	if live.size() >= int(D.max_assaults): return
	for s in held():
		if live.any(func(f): return int(f.assault) == int(s.id)): continue
		var by := ""
		if s.from != "" and not Campaign.ports_of(s.from).is_empty() and not Flag.treaty(s.from):   # a treaty stops all hostilities
			var ch: float = float(D.assault_chance[0]) if G.day - int(s.took) < 150 else float(D.assault_chance[1])
			if randf() < ch: by = s.from
		if by == "":
			for f in Diplomacy.POWERS:
				if not Campaign.at_war(f) or Flag.treaty(f) or Campaign.ports_of(f).is_empty(): continue
				if Campaign.ports_of(f).any(func(p): return Campaign.mdist(p.x, p.y, s.x, s.y) < 1500.0) and randf() < 0.004: by = f; break
		if by != "": launch_assault(s, by); return

## An assault force sails from the attacker's nearest port for the coast nearest the structure: escorts and troop
## ships. Sink it before it lands, or trust the garrison.
func launch_assault(s: Dictionary, by: String) -> Dictionary:
	var G := g(); var from = null; var bd := INF
	for p in Campaign.ports_of(by):
		var d := Campaign.mdist(p.sx, p.sy, s.x, s.y)
		if d < bd: bd = d; from = p
	var f: Dictionary = Campaign.spawn_fleet("patrol", by)
	var tl: Array = Campaign.enemy_tech(Campaign.fac_era(by))
	var esc: Array = Campaign.build_by_budget(Campaign.C.PATROL_POOL[by], (20000.0 + randf() * 30000.0) * (1.0 + G.day / 200.0), 4, by, tl)
	if not esc.is_empty(): f.ships = esc
	var carrier := "ap" if Campaign.design_for("ap", by, tl + ["amphib"]) != "" else "freighter"   # every power learned landings in the war
	for i in randi_range(1, 2): var tr: Dictionary = Campaign.new_ship(carrier, null, by, tl + ["amphib"]); tr.troops = true; f.ships.append(tr)
	f.kind = "assault"; f.assault = int(s.id); f.name = "%s assault force" % GameData.fac[by].short; f.cool = 0.0
	f.x = from.sx; f.y = from.sy; f.home = {"x": from.sx, "y": from.sy}
	var w := coast_point(s); f.tgt = {"x": w.x, "y": w.y}
	if not Campaign.set_course(f, w.x, w.y):   # no way there by sea: the expedition is called off (it used to land at once, from its home port)
		G.fleets.erase(f); return {}
	f.warned = radar_held(s)
	if f.warned: Campaign.toast.emit("Your radar at the %s reports a %s assault force sailing from %s to retake the %s. Intercept it, or trust the garrison." % [radar_name(s), GameData.fac[by].short, from.name, s.name])
	Campaign.log_ev("%s assault force sailed for the %s" % [GameData.fac[by].short, s.name])
	return f

## One of your radar stations within 300 km of the structure (it warns you as soon as an assault sails).
func radar_held(s: Dictionary) -> bool: return radar_name(s) != ""
func radar_name(s: Dictionary) -> String:
	for r in held(): if r.kind == "radar" and Campaign.mdist(r.x, r.y, s.x, s.y) < cover_units(): return r.name
	return ""

## Without radar you hear of an assault only when it is within about 400 units of the structure.
func _warnings() -> void:
	for f in g().fleets:
		if not _is_assault(f) or f.get("warned", false): continue
		var s: Dictionary = all()[int(f.assault)]
		if Campaign.mdist(f.x, f.y, s.x, s.y) < 400.0:
			f.warned = true
			Campaign.toast.emit("Lookouts ashore report a %s, %s, closing on the %s." % [Campaign.fname(f), Diplomacy.where(f.x, f.y), s.name])

func _is_assault(f: Dictionary) -> bool: return f.has("assault") and int(f.assault) >= 0

## The assault force reached the coast (Campaign.update): the landing is fought out against the garrison.
func assault_lands(f: Dictionary) -> void:
	var G := g(); var s: Dictionary = all()[int(f.assault)]; G.fleets.erase(f)
	if s.fac != "player": return   # you gave it up or it changed hands; the force goes home
	var troops := 0; var esc := []
	for sh in f.ships:
		if sh.get("troops", false): troops += 1
		else: esc.append(sh)
	if troops == 0: Campaign.toast.emit("The %s reaches the coast without its troopships and turns back." % f.name); return
	var dfn := defences(s)
	var A: float = troops * 450.0 + Campaign.strength(esc) / 250.0
	var Dv: float = (float(s.garrison) * 2.0 + float(dfn.guns) * 60.0 + float(dfn.flak) * 30.0 + float(dfn.fighters) * 40.0) * float(dfn.radar)
	if randf() < Dv / (A + Dv):
		s.dmg = minf(1.0, float(s.dmg) + 0.25); var lost := int(round(float(s.garrison) * randf_range(0.1, 0.3))); s.garrison = maxi(1, int(s.garrison) - lost)
		Campaign.toast.emit("The garrison of the %s beats off a %s landing. %d of your men are killed or wounded." % [s.name, GameData.fac[f.fac].short, lost])
		Campaign.log_ev("Held the %s against a landing" % s.name)
	else:
		Campaign.toast.emit("FALLEN. %s troops storm the %s. Your garrison of %d is lost." % [GameData.fac[f.fac].short, s.name, int(s.garrison)])
		Campaign.log_ev("Lost the %s" % s.name)
		s.fac = f.fac; s.garrison = 0; s.from = ""; s.dmg = 0.5

# ------------------------------------------------------------------ for the chart and the panels
## The structure under a chart point, within r map units.
func at_point(x: float, y: float, r: float):
	var best = null; var bd := r
	for s in all():
		var d := Campaign.mdist(s.x, s.y, x, y)
		if d < bd: bd = d; best = s
	return best

func owner_name(s: Dictionary) -> String:
	if s.fac == "player": return "Yours"
	if s.fac == "": return "Unclaimed"
	return GameData.fac[s.fac].name

## A one-line summary of a structure's defences, for panels.
func defence_text(s: Dictionary) -> String:
	var d := defences(s); var parts := []
	var fl := float(d.flak)
	if fl > 0.05: parts.append(("light flak" if fl < 1.5 else ("%d flak batteries" % int(round(fl)))) + (" (much of it knocked out)" if float(s.dmg) > 0.4 else ""))
	if float(d.fighters) > 0.05: parts.append("about %d fighters%s" % [int(round(float(d.fighters) * 6.0)), " (with cover from nearby airfields)" if float(d.fighters) > float(d.own_fighters) + 0.05 else ""])
	if float(d.guns) > 0.05: parts.append("%d heavy guns" % maxi(1, int(round(float(d.guns)))))
	if float(d.radar) > 1.0: parts.append("radar warning")
	return ", ".join(parts) if parts.size() else "none to speak of"
