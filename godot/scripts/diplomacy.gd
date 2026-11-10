extends Node
## Diplomacy (autoload): relations between the powers, wars and the armistice, clashes between fleets of the powers,
## contracts on every port's board, and commissions and letters of marque. Rules only, no drawing; the chart shows it.
##
## State lives in the saved game (Campaign.G): rel {"a|b": value}, wars {"a|b": day declared}, news [[day, text]],
## contracts (accepted), offers {port id: {day, list}}, commission {fac, since, marque} or null, betrayed [fac],
## nextContract, cobell {war: the war it joined}. Tables: data/diplomacy.json, written from the owner's lore.

var D: Dictionary = {}
const POWERS := ["concord", "directorate", "pacific", "combine", "republic", "freeport", "enclave", "ombria", "isles"]
var _clash_t := 0.0

func _ready() -> void:
	var f := FileAccess.open("res://data/diplomacy.json", FileAccess.READ)
	D = JSON.parse_string(f.get_as_text()) if f != null else {}

func g() -> Dictionary: return Campaign.G
static func pair(a: String, b: String) -> String: return a + "|" + b if a < b else b + "|" + a

# ------------------------------------------------------------------ relations
func base_rel(a: String, b: String) -> float:
	var r: Dictionary = D.get("relations", {})
	if r.has(a + "|" + b): return float(r[a + "|" + b])
	if r.has(b + "|" + a): return float(r[b + "|" + a])
	return 0.0

func rel(a: String, b: String) -> float:
	if a == b: return 100.0
	if a == "raiders" or b == "raiders": return -100.0
	return float(g().get("rel", {}).get(pair(a, b), base_rel(a, b)))

func shift(a: String, b: String, d: float) -> void:
	if a == b or a == "raiders" or b == "raiders" or not g().has("rel"): return
	g().rel[pair(a, b)] = clampf(rel(a, b) + d, -100.0, 100.0)

func at_war(a: String, b: String) -> bool:
	if a == "raiders" or b == "raiders": return a != b
	return g().get("wars", {}).has(pair(a, b))

func band(a: String, b: String) -> String:
	if at_war(a, b): return "war"
	var r := rel(a, b); var B: Dictionary = D.bands
	if r < B.hostile: return "armistice" if r <= B.peace else "hostile"
	if r < B.cool: return "cool"
	if r >= B.allied: return "allied"
	if r >= B.cordial: return "cordial"
	return "neutral"

const BAND_TEXT := {"war": "at war", "armistice": "armistice, barely", "hostile": "hostile", "cool": "cool", "neutral": "neutral", "cordial": "cordial", "allied": "allied"}

## Powers this one counts as its enemies (hostile or worse): sinking their ships earns its thanks.
func enemies(f: String) -> Array:
	var out := []
	for o in POWERS: if o != f and (at_war(f, o) or rel(f, o) < float(D.bands.hostile)): out.append(o)
	return out

# ------------------------------------------------------------------ setup and saves
func ensure(st := {}) -> void:
	var G := g()
	if not G.has("rel"):
		G.rel = {}
		for i in POWERS.size():
			for j in range(i + 1, POWERS.size()): G.rel[pair(POWERS[i], POWERS[j])] = base_rel(POWERS[i], POWERS[j])
	if not G.has("wars"): G.wars = {}
	if not G.has("cobell"): G.cobell = {}
	for p in POWERS:   # a save from before a power existed: its relations start where the tables put them
		for q in POWERS: if p < q and not G.rel.has(pair(p, q)): G.rel[pair(p, q)] = base_rel(p, q)
	for p in POWERS: if not G.rep.has(p): G.rep[p] = 0
	for k in ["news", "contracts", "betrayed"]: if not G.has(k): G[k] = []
	if not G.has("offers"): G.offers = {}
	if not G.has("commission"): G.commission = null
	if not G.has("nextContract"): G.nextContract = 1
	if st.has("commission") and G.commission == null:
		var c: Dictionary = D.commissions.get(st.commission, {})
		G.commission = {"fac": st.commission, "since": G.day, "marque": c.get("marque", "")}

func news(text: String, tell := true) -> void:
	var G := g(); G.news.append([G.day, text])
	if G.news.size() > 30: G.news.pop_front()
	if tell: Campaign.toast.emit(text)

# ------------------------------------------------------------------ the passing of days
func new_day() -> void:
	var G := g(); ensure()
	# relations drift back toward where the lore leaves them, a little each day
	# relations drift back toward where the lore leaves them; a war wears both sides down until they want an armistice
	for k in G.rel.keys():
		var ab: PackedStringArray = k.split("|"); var b := base_rel(ab[0], ab[1])
		if G.wars.has(k): b += 14.0 + minf(20.0, (G.day - int(G.wars[k])) / 6.0)
		G.rel[k] = float(G.rel[k]) + (b - float(G.rel[k])) * 0.015
	# about every twelve days, something happens between the powers
	if randf() < 0.085: _event()
	# wars break out past the war line; an armistice returns once tempers cool past the peace line
	for i in POWERS.size():
		for j in range(i + 1, POWERS.size()):
			var a: String = POWERS[i]; var b: String = POWERS[j]; var k := pair(a, b); var r := rel(a, b)
			if not G.wars.has(k) and r <= float(D.bands.war): declare(a, b)
			elif G.wars.has(k) and r > float(D.bands.peace) and not G.cobell.has(k): armistice(a, b)
	# sieges: in a war, ports change hands
	for k in G.wars.keys(): if randf() < float(D.get("sieges", {}).get("chance", 0.04)): _siege(k)
	for k in G.wars.keys(): Structures.war_tick(k)   # and structures ashore
	_escorts()
	# commissions: the month's pay, or the end of service if your flag has turned on you
	if G.commission != null:
		var cf: String = G.commission.fac
		if Campaign.at_war(cf) or G.rep.get(cf, 0) < 0:
			news("Your %s is withdrawn: your standing with the %s has fallen too far." % [commission_title(cf), GameData.fac[cf].name]); G.commission = null
		elif G.day > int(G.commission.since) and (G.day - int(G.commission.since)) % 30 == 0:
			var pay := int(D.commissions[cf].stipend); G.credits += pay
			Campaign.toast.emit("%s pay: %s." % [commission_title(cf), Campaign.fmt(pay)])
	# contracts past their deadline fail
	for c in G.contracts.duplicate():
		if G.day > int(c.deadline): fail(c, "The deadline has passed.")

# ------------------------------------------------------------------ wars, coalitions, armistices
func coalition_of(f: String) -> String:
	for c in D.get("coalitions", {}):
		if D.coalitions[c] is Array and D.coalitions[c].has(f): return c
	return ""

## War between two powers. Their allies (relations 50+) join at once; fellow members of a coalition who are merely
## cordial join half the time (the Federation is allergic to permanent alliances). `main` is the war a joiner joins.
func declare(a: String, b: String, main := "") -> void:
	var G := g(); var k := pair(a, b)
	if G.wars.has(k) or a == b: return
	G.wars[k] = G.day; G.rel[k] = minf(rel(a, b), float(D.bands.war))
	if main != "":
		G.cobell[k] = main
		news("ALLIANCE. The %s honours its obligations and declares war on the %s." % [GameData.fac[a].name, GameData.fac[b].name])
		return
	news("WAR. The %s and the %s are at war again. Their fleets will fight wherever they meet." % [GameData.fac[a].name, GameData.fac[b].name])
	_call_allies(a, b, k); _call_allies(b, a, k)

func _call_allies(side: String, foe: String, main: String) -> void:
	for x in POWERS:
		if x == side or x == foe or at_war(x, foe) or at_war(x, side): continue
		var r := rel(x, side); var same := coalition_of(x) != "" and coalition_of(x) == coalition_of(side)
		if rel(x, foe) >= float(D.bands.cordial): continue   # friends of both sides stay out
		if r >= float(D.bands.allied) or (same and r >= float(D.bands.cordial) and randf() < 0.5): declare(x, foe, main)
		elif same and r >= float(D.bands.cordial):
			news("The %s declares its neutrality in the war between the %s and the %s." % [GameData.fac[x].name, GameData.fac[side].name, GameData.fac[foe].name])

## The war between a and b ends; the allies who joined it lay down their arms with them.
func armistice(a: String, b: String) -> void:
	var G := g(); var k := pair(a, b)
	G.wars.erase(k)
	news("ARMISTICE. The %s and the %s agree a new armistice. Nobody believes it will last. Occupied ports stay occupied." % [GameData.fac[a].name, GameData.fac[b].name])
	for j in G.cobell.keys():
		if G.cobell[j] != k: continue
		G.cobell.erase(j); G.wars.erase(j)
		var xy: PackedStringArray = j.split("|"); G.rel[j] = maxf(rel(xy[0], xy[1]), float(D.bands.peace) + 3.0)
		news("The %s and the %s lay down their arms as well." % [GameData.fac[xy[0]].name, GameData.fac[xy[1]].name], false)

## A power's weight at sea: its fleets on the chart, its harbours, and your squadron if you serve it.
func might(f: String) -> float:
	var G := g(); var m := 0.0
	for fl in G.fleets: if fl.fac == f: m += Campaign.strength(fl.ships)
	m += 30000.0 * Campaign.ports_of(f).size()
	if G.get("commission") != null and G.commission.fac == f: m += Campaign.strength(G.fleet)
	return m

## Strength within reach of a harbour: a power's fleets nearby (weighted by its navy's quality), its own harbours
## close by, and your squadron if you serve it and are near.
func local_might(f: String, at: Dictionary) -> float:
	var G := g(); var R := float(D.sieges.get("reach", 900)); var m := 0.0
	for fl in G.fleets: if fl.fac == f and Campaign.mdist(fl.x, fl.y, at.sx, at.sy) < R: m += Campaign.strength(fl.ships)
	for p in G.ports: if p.fac == f and Campaign.mdist(p.sx, p.sy, at.sx, at.sy) < R: m += float(D.sieges.get("harbour", 25000)) * 0.5
	if G.get("commission") != null and G.commission.fac == f and Campaign.mdist(G.player.x, G.player.y, at.sx, at.sy) < R: m += Campaign.strength(G.fleet)
	return m * float(D.sieges.get("navy", {}).get(f, 1.0))

## In a war, one side may move on a port of the other: the defender's nearest harbour to the attacker's own, never a
## capital. Which side moves is a coin weighted by the navies' size and quality; whether the port falls depends on
## the strength at sea near it, against the harbour's defences and garrison.
func _siege(k: String) -> void:
	var G := g(); var ab: PackedStringArray = k.split("|")
	var na := might(ab[0]) * float(D.sieges.navy.get(ab[0], 1.0)); var nb := might(ab[1]) * float(D.sieges.navy.get(ab[1], 1.0))
	if na + nb <= 0.0: return
	var att: String = ab[0] if randf() * (na + nb) < na else ab[1]; var dfn: String = ab[1] if att == ab[0] else ab[0]
	var best = null; var bd := INF
	for p in G.ports:
		if p.fac != dfn or p.capital: continue
		for q in G.ports:
			if q.fac != att: continue
			var d := Campaign.mdist(p.sx, p.sy, q.sx, q.sy)
			if d < bd: bd = d; best = p
	if best == null or bd > 2600.0: return
	var la := local_might(att, best); var ld := local_might(dfn, best) + float(D.sieges.get("harbour", 25000)) * float(best.get("garrison", 1))
	var take := clampf(la / maxf(1.0, la + ld) * 0.8, 0.03, 0.6)
	if randf() < take: capture(best, att)
	else: news("SIEGE. A %s attack on %s is beaten off. The %s holds the port." % [GameData.fac[att].short, best.name, GameData.fac[dfn].name], Campaign.mdist(best.sx, best.sy, G.player.x, G.player.y) < 900.0)

## A port changes hands: its market, officers and contract board are the new owner's from now on.
func capture(p: Dictionary, by: String) -> void:
	var G := g(); var old: String = p.fac
	var home: String = Campaign.C.ports[int(p.id)].fac   # who held it in 1946: an ally retaking it hands it back
	if home != by and home != old and (rel(home, by) >= float(D.bands.allied) or (coalition_of(home) != "" and coalition_of(home) == coalition_of(by))):
		p.fac = home; p.merge(Campaign.market_mods(home), true); p.officers = []; p.offDay = -99; G.offers.erase(str(int(p.id)))
		Structures.on_port_captured(p, old, home)
		shift(by, home, 4.0)
		news("LIBERATED. The %s retakes %s and hands it back to the %s." % [GameData.fac[by].name, p.name, GameData.fac[home].name])
		return
	p.fac = by; p.merge(Campaign.market_mods(by), true); p.officers = []; p.offDay = -99; G.offers.erase(str(int(p.id)))
	Structures.on_port_captured(p, old, by)
	shift(by, old, -5.0)
	news("FALLEN. %s falls to the %s. The %s flag comes down over the harbour." % [p.name, GameData.fac[by].name, GameData.fac[old].short])
	Campaign.log_ev("%s taken by the %s" % [p.name, GameData.fac[by].name])

func _event() -> void:
	var ev: Array = D.get("events", [])
	if ev.is_empty(): return
	var G := g(); if not G.has("recentEvents"): G.recentEvents = {}
	var fresh: Array = ev.filter(func(e): return G.day - int(G.recentEvents.get(e.id, -999)) > 45)   # no repeats within six weeks
	if fresh.is_empty(): return
	var tot := 0.0
	for e in fresh: tot += float(e.weight)
	var r := randf() * tot
	for e in fresh:
		r -= float(e.weight)
		if r > 0: continue
		for p in e.pairs: shift(p[0], p[1], float(p[2]) * randf_range(0.7, 1.3))
		G.recentEvents[e.id] = G.day; news(e.text)
		return

# ------------------------------------------------------------------ fleets of the powers meeting at sea
## Called from Campaign.update. Fleets of powers at war fight where they meet; patrols hunt raiders and raiders fall on
## convoys; under the armistice, two hostile patrols that meet sometimes trade fire (an incident that sours relations).
func clash_tick(dt: float) -> void:
	_clash_t -= dt
	if _clash_t > 0.0: return
	_clash_t = 0.5
	var fl: Array = Campaign.G.fleets
	# fleets that have met leave each other alone for a while. This is their own timer (`cc`): it used to be the
	# `cool` that also gates contact with you, so a hostile patrol that passed a convoy could not be brought to
	# action, nor chase you, for two and a half days.
	for f in fl: if float(f.get("cc", 0.0)) > 0.0: f.cc = float(f.cc) - 0.5
	var free: Array = fl.filter(_free)   # asked once for each fleet, not once for each pair
	for i in free.size():
		var a: Dictionary = free[i]
		for j in range(i + 1, free.size()):
			var b: Dictionary = free[j]
			if a.fac == b.fac: continue
			if Campaign.mdist(a.x, a.y, b.x, b.y) > Campaign.CONTACT: continue
			var raid: bool = (a.fac == "raiders" and a.kind != "bounty") or (b.fac == "raiders" and b.kind != "bounty")   # a posted bounty is left for you
			if raid and (a.kind == "patrol" or b.kind == "patrol" or a.kind == "convoy" or b.kind == "convoy"):
				_fight(a, b, ""); return
			if a.fac == "raiders" or b.fac == "raiders": continue
			if a.fac == "player" or b.fac == "player":   # ships of your own flag: they fight the powers you are at war with, and pass the rest
				if Campaign.at_war(b.fac if a.fac == "player" else a.fac): _fight(a, b, ""); return
				a.cc = 25.0; b.cc = 25.0; continue
			if at_war(a.fac, b.fac): _fight(a, b, ""); return
			a.cc = 25.0; b.cc = 25.0   # they have met: whatever happens, not again for a while
			if band(a.fac, b.fac) in ["armistice", "hostile"] and (a.kind == "patrol" or b.kind == "patrol") and randf() < 0.05:
				shift(a.fac, b.fac, -4.0); _fight(a, b, "incident"); return

func _free(f: Dictionary) -> bool:
	if f.get("answering", false) or (Campaign.G.player.get("towed") != null and int(Campaign.G.player.towed) == int(f.id)): return false   # busy with you
	return f.cool <= 0 and float(f.get("cc", 0.0)) <= 0.0 and f.kind != "assault" and not f.get("mission", false) and not f.get("hunter", false) and int(f.get("contract", 0)) == 0 and int(f.get("escort", 0)) == 0 and not f.ships.is_empty()

## An action between two fleets, settled without the player: the stronger side usually wins, and the loser loses
## most of its ships. Within earshot of your task force, you hear of it.
func _fight(a: Dictionary, b: Dictionary, why: String) -> void:
	var sa := pow(Campaign.strength(a.ships), 1.2) * randf_range(0.6, 1.4); var sb := pow(Campaign.strength(b.ships), 1.2) * randf_range(0.6, 1.4)
	var a_wins := sa >= sb
	var w: Dictionary = a if a_wins else b; var l: Dictionary = b if a_wins else a
	var lose := int(ceil(l.ships.size() * (randf_range(0.2, 0.5) if why == "incident" else randf_range(0.4, 1.0))))
	l.ships.shuffle(); var sunk: Array = l.ships.slice(0, lose); l.ships = l.ships.slice(lose)
	for s in w.ships: s.hullFrac = maxf(0.1, s.hullFrac - randf_range(0.0, 0.3))
	var odds := (sb / maxf(sa, 1.0)) if a_wins else (sa / maxf(sb, 1.0))
	if w.ships.size() > 1 and randf() < 0.25 * minf(1.0, odds): w.ships.pop_back()
	a.cc = 30.0; b.cc = 30.0
	for f in [a, b]: if f.ships.is_empty(): Campaign.G.fleets.erase(f)
	var P: Dictionary = Campaign.G.player; var d := Campaign.mdist(a.x, a.y, P.x, P.y)
	var tell := d < 600.0 or why == "incident"
	var lead := ("Incident %s: %s and %s ships traded fire." % [where(a.x, a.y), _who(a), _who(b)]) if why == "incident" else ("Action %s:" % where(a.x, a.y))
	var res := " A %s %s sank %d %s ship%s%s." % [_who(w), "flotilla" if w.fac == "raiders" else w.kind, sunk.size(), _who(l), "" if sunk.size() == 1 else "s", ", and the rest scattered" if not l.ships.is_empty() else ""]
	if tell or sunk.size() >= 3: news(lead + res, tell)

func _who(f: Dictionary) -> String: return "raider" if f.fac == "raiders" else GameData.fac[f.fac].short

## "off Gatehold" near a port, otherwise "in the Saffron Sea" by the nearest theatre on the chart.
func where(x: float, y: float) -> String:
	var bp = null; var bd := 260.0
	for p in Campaign.G.ports:
		var d := Campaign.mdist(x, y, p.sx, p.sy)
		if d < bd: bd = d; bp = p
	if bp != null: return "off " + bp.name
	var bt := ""; bd = INF
	for t in Campaign.C.THEATERS:
		var d := Campaign.mdist(x, y, Campaign.lon_x(t[1]), Campaign.lat_y(t[2]))
		if d < bd: bd = d; bt = t[0]
	return "in the " + bt.capitalize()

# ------------------------------------------------------------------ commissions and letters of marque
func commission_title(fac: String) -> String: return D.commissions.get(fac, {}).get("title", "commission")

func can_commission(fac: String) -> String:   # "" if offered, otherwise why not
	var G := g()
	if not D.commissions.has(fac): return "This flag does not commission independents."
	if G.commission != null: return "You already hold a %s." % commission_title(G.commission.fac)
	if G.betrayed.has(fac): return "Betrayal is remembered. They will not offer you service again."
	if Campaign.at_war(fac) or Campaign.hostile(fac): return "Not while they would sooner sink you."
	if G.rep.get(fac, 0) < 20: return "They offer service to captains they trust: standing 20 or better (yours is %d)." % G.rep.get(fac, 0)
	return ""

func take_commission(fac: String) -> void:
	var G := g(); var c: Dictionary = D.commissions[fac]
	G.commission = {"fac": fac, "since": G.day, "marque": c.get("marque", "")}
	G.rep[fac] = mini(100, G.rep.get(fac, 0) + 5)
	news("You accept a %s. Pay: %s a month." % [c.title, Campaign.fmt(int(c.stipend))])
	Campaign.log_ev("Accepted a " + c.title)

func resign() -> void:
	var G := g(); if G.commission == null: return
	var fac: String = G.commission.fac; G.rep[fac] = G.rep.get(fac, 0) - 10
	news("You resign your %s. The %s will remember the manner of your going." % [commission_title(fac), GameData.fac[fac].name]); G.commission = null

## You opened fire on a flag's ships under the armistice: if it is the flag you serve, that is betrayal.
func on_open_fire(fac: String) -> void:
	var G := g()
	if G.commission != null and G.commission.fac == fac:
		G.rep[fac] = G.rep.get(fac, 0) - 40; G.betrayed.append(fac); G.commission = null
		news("Betrayal. You turned your guns on the %s, the flag you served. Your commission is torn up, and they will not forget." % GameData.fac[fac].name)

## Your commission makes you a combatant: against the flags your flag is at war with, and a letter of marque's target.
func commission_enemy(fac: String) -> bool:
	var c = g().get("commission")
	if c == null or fac == "raiders": return false
	return fac == c.get("marque", "") or at_war(c.fac, fac)

## Standing earned with each power for ships of `fac` beaten: its enemies thank you, the flag you serve twice over.
func thanks(fac: String, n: int) -> void:
	var G := g(); var who: Array = ["concord", "pacific", "combine", "freeport"] if fac == "raiders" else enemies(fac)
	for e in who: G.rep[e] = mini(100, G.rep.get(e, 0) + n * (2 if G.commission != null and G.commission.fac == e else 1))

## Wartime prices: munitions and fuel dearer in the ports of a power at war.
func price_mult(fac: String, gid: String) -> float:
	if gid != "munitions" and gid != "fuel": return 1.0
	for o in POWERS: if at_war(fac, o): return 1.25
	return 1.0

# ------------------------------------------------------------------ contracts
## The offers on a port's board, renewed every couple of weeks. Hostile ports post nothing for you.
func offers(p: Dictionary) -> Array:
	var G := g(); ensure(); var key := str(int(p.id))
	var o = G.offers.get(key)
	if o == null or G.day - int(o.day) >= int(D.contracts.refresh_days):
		var list := []
		for i in int(D.contracts.offers_per_port):
			var c := _make(p)
			if not c.is_empty(): list.append(c)
		o = {"day": G.day, "list": list}; G.offers[key] = o
	return o.list

func _make(p: Dictionary) -> Dictionary:
	var G := g(); var fac: String = p.fac
	var kinds := ["delivery", "delivery", "hunt", "survey", "escort"]
	if fac == "freeport" or randf() < 0.2: kinds.append_array(["smuggle", "smuggle"])
	var foes := []
	for e in POWERS: if at_war(fac, e): foes.append(e)
	if not foes.is_empty(): kinds.append_array(["war", "war", "strike"])
	var kind: String = kinds.pick_random()
	var c := {"id": G.nextContract, "kind": kind, "fac": fac, "port": int(p.id), "from": p.name}
	G.nextContract += 1
	var speed := 70.0   # map units a day for planning deadlines (about 13 knots)
	match kind:
		"delivery":
			var dests: Array = G.ports.filter(func(q): return int(q.id) != int(p.id) and not Campaign.hostile(q.fac) and (q.fac == fac or rel(fac, q.fac) > float(D.bands.cool)) and Campaign.mdist(p.sx, p.sy, q.sx, q.sy) > 400.0)
			if dests.is_empty(): return {}
			var d: Dictionary = dests.pick_random(); var good: Dictionary = Campaign.C.GOODS.filter(func(x): return x.id != "fuel").pick_random()
			var qty := randi_range(2, 6) * 5; var dist := Campaign.mdist(p.sx, p.sy, d.sx, d.sy)
			c.merge({"dest": int(d.id), "good": good.id, "qty": qty, "days": int(dist / speed * 1.8) + 8, "reward": int(round((1500.0 + dist * 3.0 + qty * float(good.base) * 0.6) / 100.0) * 100), "rep": 4,
				"title": "Carry %d %s to %s" % [qty, good.name.to_lower(), d.name]})
			c.text = "A %s consignment for %s. The goods are loaded when you sign; deliver them before the deadline." % [GameData.fac[fac].short, d.name]
		"hunt":
			var at := Campaign.water_point(8, Vector2(p.sx, p.sy), 520.0)
			c.merge({"x": at.x, "y": at.y, "days": 45, "reward": int(round((6000.0 + randf() * 6000.0) * (1.0 + G.day / 240.0) / 500.0) * 500), "rep": 6,
				"title": "Hunt the raiders %s" % where(at.x, at.y)})
			c.text = "A raider flotilla has been taking %s shipping %s. Find it and sink it." % [GameData.fac[fac].short, where(at.x, at.y)]
		"survey":
			var sites: Array = G.pois.filter(func(q): return Campaign.mdist(p.sx, p.sy, q.x, q.y) < 2400.0 and G.day >= int(q.next))
			if sites.is_empty(): return {}
			var s: Dictionary = sites.pick_random(); var dist := Campaign.mdist(p.sx, p.sy, s.x, s.y)
			c.merge({"poi": int(s.id), "days": int(dist / speed * 2.0) + 15, "reward": int(round((3000.0 + dist * 2.5) / 100.0) * 100), "rep": 5, "title": "Survey %s" % s.name})
			c.text = "%s wants an independent look at %s, and a report by wireless when you have it." % [p.name, s.name]
		"escort":
			var dests: Array = G.ports.filter(func(q): return int(q.id) != int(p.id) and (q.fac == fac or rel(fac, q.fac) > float(D.bands.cool)) and Campaign.mdist(p.sx, p.sy, q.sx, q.sy) > 500.0 and Campaign.mdist(p.sx, p.sy, q.sx, q.sy) < 2600.0)
			if dests.is_empty(): return {}
			var d: Dictionary = dests.pick_random(); var dist := Campaign.mdist(p.sx, p.sy, d.sx, d.sy)
			c.merge({"dest": int(d.id), "days": int(dist / 45.0 * 1.6) + 10, "reward": int(round((4000.0 + dist * 5.0) / 100.0) * 100), "rep": 6, "title": "Escort a convoy to %s" % d.name})
			c.text = "A %s convoy sails for %s and wants a warship alongside. It sails when you do and waits when you fall behind. Raiders will be watching the route." % [GameData.fac[fac].short, d.name]
		"smuggle":
			var targets: Array = G.ports.filter(func(q): return q.fac != fac and not q.capital and (rel(fac, q.fac) < float(D.bands.cool) or Campaign.hostile(q.fac)) and Campaign.mdist(p.sx, p.sy, q.sx, q.sy) < 3000.0)
			if targets.is_empty(): return {}
			var d: Dictionary = targets.pick_random(); var good: String = ["medicine", "electronics", "munitions"].pick_random(); var qty := randi_range(2, 5) * 5
			var dist := Campaign.mdist(p.sx, p.sy, d.sx, d.sy)
			c.merge({"dest": int(d.id), "good": good, "qty": qty, "days": int(dist / speed * 1.8) + 10, "reward": int(round((5000.0 + dist * 6.0 + qty * 150.0) / 100.0) * 100), "rep": 6, "title": "Run %d %s into %s" % [qty, good, d.name]})
			c.text = "Contraband for %s, a %s harbour, landed quietly past the customs launches. Get caught and the cargo is seized and the %s remembers. The fewer ships you bring in, the better your chances." % [d.name, GameData.fac[d.fac].short, GameData.fac[d.fac].short]
		"strike":   # silence an enemy installation from the air
			var tg: Array = Structures.all().filter(func(s): return foes.has(s.fac) and Campaign.mdist(p.sx, p.sy, s.x, s.y) < 2400.0 and not Structures.silenced(s))
			if tg.is_empty(): return {}
			var s: Dictionary = tg.pick_random()
			c.merge({"struct": int(s.id), "target": s.fac, "days": 50, "reward": int(round((9000.0 + 5000.0 * float(Structures.kind(s).military) + randf() * 4000.0) / 500.0) * 500), "rep": 8,
				"title": "Strike the %s" % s.name})
			c.text = "The %s is at war with the %s. Knock out at least 70%% of the defences of the %s, from the air or with your guns from the sea. Taking this makes you a combatant to the %s." % [GameData.fac[fac].name, GameData.fac[s.fac].name, s.name, GameData.fac[s.fac].short]
		"war":
			var foe: String = foes.pick_random()
			c.merge({"target": foe, "need": 3, "got": 0, "days": 60, "reward": int(round((14000.0 + randf() * 8000.0) / 500.0) * 500), "rep": 10,
				"title": "Sink %s shipping" % GameData.fac[foe].short})
			c.text = "The %s is at war with the %s. Sink or take three of their ships within two months. Taking this makes you a combatant to them." % [GameData.fac[fac].name, GameData.fac[foe].name]
	c.deadline = 0
	return c

func can_accept(c: Dictionary) -> String:
	var G := g()
	if G.contracts.size() >= int(D.contracts.max_active): return "You can hold %d contracts at once." % int(D.contracts.max_active)
	var cm = G.get("commission")
	if cm != null and c.get("target", "") == cm.fac: return "You serve the %s: you cannot sign on against your own flag." % GameData.fac[cm.fac].short
	if (c.kind == "delivery" or c.kind == "smuggle") and Campaign.cargo_cap() - Campaign.cargo_used() < int(c.qty): return "Not enough room in the hold (%d needed)." % int(c.qty)
	return ""

func accept(c: Dictionary) -> void:
	var G := g()
	for k in G.offers: G.offers[k].list.erase(c)
	c.deadline = G.day + int(c.days)
	match c.kind:
		"delivery", "smuggle": G.cargo[c.good] = G.cargo.get(c.good, 0) + int(c.qty)
		"escort":
			var f: Dictionary = Campaign.spawn_fleet("convoy", c.fac)
			var from: Dictionary = G.ports[int(c.port)]
			f.x = from.sx; f.y = from.sy; f.home = {"x": from.sx, "y": from.sy}; f.from = int(c.port); f.dest = int(c.dest); f.route = null; f.started = false
			f.escort = int(c.id); f.name = GameData.fac[c.fac].short + " convoy (escort)"; c.fleet = int(f.id)
		"hunt":
			var f: Dictionary = Campaign.spawn_fleet("raiders", "raiders")
			# a flotilla worth the pay: about twice the reward in ships
			var tl: Array = Campaign.enemy_tech(Campaign.fac_era("raiders"))
			var ships: Array = Campaign.build_by_budget(Campaign.C.PATROL_POOL.raiders, float(c.reward) * 2.4, 6, "raiders", tl)
			if ships.size() >= 2: f.ships = ships
			f.x = c.x; f.y = c.y; f.home = {"x": c.x, "y": c.y}; f.contract = int(c.id); f.name = "Raider flotilla (contract)"; c.fleet = int(f.id)
		"war", "strike": G.incidents = G.get("incidents", {}); G.incidents[c.target] = maxi(int(G.incidents.get(c.target, 0)), c.deadline)
	G.contracts.append(c)
	Campaign.log_ev("Contract: " + c.title)

func complete(c: Dictionary, notes = null) -> void:
	var G := g(); G.contracts.erase(c)
	G.credits += int(c.reward); G.rep[c.fac] = mini(100, G.rep.get(c.fac, 0) + int(c.rep))
	var t := "Contract complete: %s. +%s, %s standing +%d." % [c.title, Campaign.fmt(int(c.reward)), GameData.fac[c.fac].short, int(c.rep)]
	Campaign.log_ev(t)
	if notes is Array: notes.append(t)
	else: Campaign.toast.emit(t)

func fail(c: Dictionary, why: String) -> void:
	var G := g(); G.contracts.erase(c); G.rep[c.fac] = maxi(-100, int(G.rep.get(c.fac, 0)) - 8)
	if c.kind == "hunt":
		for f in G.fleets: if int(f.get("contract", 0)) == int(c.id): f.contract = 0; f.name = "Raider flotilla"
	if c.kind == "escort":   # the convoy sails on by itself (it used to wait for its escort for ever)
		for f in G.fleets: if int(f.get("escort", 0)) == int(c.id): f.erase("escort"); f.name = GameData.fac[f.fac].short + " convoy"
	if (c.kind == "delivery" or c.kind == "smuggle") and c.has("good") and not c.get("seized", false):
		# the consignment was the shipper's: what is still in the hold goes back, and what is missing is paid for
		# (it used to stay yours: free cargo for eight points of standing)
		var back: int = mini(int(c.qty), int(G.cargo.get(c.good, 0))); G.cargo[c.good] = float(G.cargo.get(c.good, 0)) - back
		var short: int = int(c.qty) - back
		if short > 0:
			var base := 0.0
			for gd in Campaign.C.GOODS: if gd.id == c.good: base = float(gd.base)
			var owe := int(round(short * base * 1.5)); G.credits = maxf(0.0, float(G.credits) - owe)
			why += " %d tons of the consignment are missing: %s charged." % [short, Campaign.fmt(owe)]
		elif back > 0: why += " The consignment is landed again."
	var t := "Contract failed: %s. %s %s standing -8." % [c.title, why, GameData.fac[c.fac].short]
	Campaign.log_ev(t); Campaign.toast.emit(t)

## Docking: deliveries for this port are handed over, if the goods are still in the hold; contraband is run ashore.
func on_dock(p: Dictionary) -> void:
	var G := g()
	var sm = smuggle_for(p)
	if sm != null: Campaign.toast.emit(run_contraband(sm, p))
	for c in G.contracts.duplicate():
		if c.kind != "delivery" or int(c.dest) != int(p.id): continue
		if int(G.cargo.get(c.good, 0)) >= int(c.qty): G.cargo[c.good] -= int(c.qty); complete(c)
		else: Campaign.toast.emit("The %s consignment is short: %d needed in the hold." % [c.title, int(c.qty)])

func on_survey(poi: Dictionary, lines: Array) -> void:
	for c in g().contracts.duplicate(): if c.kind == "survey" and int(c.poi) == int(poi.id): complete(c, lines)

## After a battle: hunts whose flotilla is gone, war contracts counting the enemy ships beaten.
func on_battle(f, beaten: int, gone: bool, notes: Array) -> void:
	if f == null: return
	for c in g().contracts.duplicate():
		if c.kind == "hunt" and int(f.get("contract", 0)) == int(c.id) and gone: complete(c, notes)
		elif c.kind == "war" and f.fac == c.target and beaten > 0:
			c.got = int(c.got) + beaten
			if int(c.got) >= int(c.need): complete(c, notes)
			else: notes.append("%s: %d of %d enemy ships." % [c.title, int(c.got), int(c.need)])

## Where each active contract points on the chart: [x, y, label].
func marks() -> Array:
	var G := g(); var out := []
	for c in G.get("contracts", []):
		match c.kind:
			"delivery", "smuggle": var p: Dictionary = G.ports[int(c.dest)]; out.append([p.x, p.y, c.title])
			"escort":
				for f in G.fleets: if int(f.get("escort", 0)) == int(c.id): out.append([f.x, f.y, c.title])
			"survey": var q: Dictionary = G.pois[int(c.poi)]; out.append([q.x, q.y, c.title])
			"hunt":
				for f in G.fleets: if int(f.get("contract", 0)) == int(c.id): out.append([f.x, f.y, c.title])
			"strike": var st: Dictionary = Structures.all()[int(c.struct)]; out.append([st.x, st.y, c.title])
	return out

# ------------------------------------------------------------------ escorts and smuggling
## Escort convoys: they move only while you keep station (see Campaign.update); part way along, raiders try them.
func _escorts() -> void:
	var G := g()
	for c in G.contracts.duplicate():
		if c.kind != "escort": continue
		var f = null
		for q in G.fleets: if int(q.get("escort", 0)) == int(c.id): f = q
		if f == null: fail(c, "The convoy was lost."); continue
		var r = f.get("route")
		if not c.get("ambushed", false) and r != null and r.size() > 2 and float(f.ri) / r.size() > 0.3:
			c.ambushed = true
			var a: Dictionary = Campaign.spawn_fleet("raiders", "raiders")
			var w := Campaign.water_point(6, Vector2(f.x + 25.0, f.y), 30.0); a.x = w.x; a.y = w.y; a.home = {"x": w.x, "y": w.y}; a.cool = 0.0
			Campaign.toast.emit("Lookouts report raiders closing on the convoy %s." % where(f.x, f.y))

## The escorted convoy made harbour.
func on_convoy_arrived(f: Dictionary) -> void:
	for c in g().contracts.duplicate():
		if c.kind == "escort" and int(f.get("escort", 0)) == int(c.id): complete(c)

## A smuggling contract for this harbour, if you hold one.
func smuggle_for(p: Dictionary):
	for c in g().contracts: if c.kind == "smuggle" and int(c.dest) == int(p.id): return c
	return null

## The chance of being caught landing contraband here: worse in a closed harbour, better with fewer ships and a
## captain who knows how to slip away.
func smuggle_risk(p: Dictionary) -> float:
	var r := 0.45 if Campaign.hostile(p.fac) else 0.3
	r += 0.04 * maxi(0, Campaign.G.fleet.size() - 2) - float(Campaign.perk("evade", 0)) / 100.0
	return clampf(r, 0.08, 0.8)

## Land the contraband: paid if it gets ashore; if caught, the cargo is seized, the harbour's flag remembers, and in a
## closed harbour it is an incident.
func run_contraband(c: Dictionary, p: Dictionary) -> String:
	var G := g()
	if int(G.cargo.get(c.good, 0)) < int(c.qty): return "The contraband for %s is short: %d %s needed in the hold." % [p.name, int(c.qty), c.good]
	G.cargo[c.good] -= int(c.qty)
	if randf() >= smuggle_risk(p): complete(c); return "The cargo goes ashore by night at %s. Nobody saw a thing." % p.name
	G.rep[p.fac] = G.rep.get(p.fac, 0) - 12
	if Campaign.hostile(p.fac): Campaign.incident(p.fac)
	G.contracts.erase(c); G.rep[c.fac] = G.rep.get(c.fac, 0) - 4
	Campaign.log_ev("Caught smuggling at " + p.name)
	return "Customs launches catch you at %s. The cargo is seized; %s standing -12%s." % [p.name, GameData.fac[p.fac].short, " and their warships will be looking for you" if Campaign.hostile(p.fac) else ""]

# ------------------------------------------------------------------ for the chart's orders box and tooltips
## Where a contract leads now (a port, a site, a fleet), or null.
func target_of(c: Dictionary):
	var G := g()
	match c.kind:
		"delivery", "smuggle": var p: Dictionary = G.ports[int(c.dest)]; return Vector2(p.sx, p.sy)
		"survey": var q: Dictionary = G.pois[int(c.poi)]; return Vector2(q.x, q.y)
		"strike":   # flown from the sea: aim for the water off the coast nearest it
			return Structures.coast_point(Structures.all()[int(c.struct)])
		"hunt", "escort":
			for f in G.fleets: if int(f.get("contract", 0)) == int(c.id) or int(f.get("escort", 0)) == int(c.id): return Vector2(f.x, f.y)
	return null

## The full story of a contract, for a tooltip: what it asks, who posted it, the pay and the time left.
func contract_info(c: Dictionary) -> String:
	var G := g(); var lines := [c.title, c.text]
	lines.append("Posted by the %s at %s." % [GameData.fac[c.fac].name, c.from])
	lines.append("Pays %s and %s standing +%d. Failing costs 8 standing." % [Campaign.fmt(int(c.reward)), GameData.fac[c.fac].short, int(c.rep)])
	if c.kind == "war": lines.append("Progress: %d of %d enemy ships." % [int(c.got), int(c.need)])
	if c.kind == "strike": lines.append("Its defences: %d%% out of action now." % int(float(Structures.all()[int(c.struct)].dmg) * 100))
	if c.kind == "delivery" or c.kind == "smuggle": lines.append("In your hold: %d of %d %s." % [int(G.cargo.get(c.good, 0)), int(c.qty), c.good])
	var t = target_of(c)
	if t != null: lines.append("Target %s, %d km from you." % [where(t.x, t.y), int(Campaign.mdist(G.player.x, G.player.y, t.x, t.y) * Campaign.KM_PER_UNIT)])
	lines.append("Deadline %s: %d days left." % [Campaign.date_str(int(c.deadline)), maxi(0, int(c.deadline) - G.day)])
	return "\n".join(lines)
