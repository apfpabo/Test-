extends Node
## Diplomacy (autoload): relations between the powers, wars and the armistice, clashes between fleets of the powers,
## contracts on every port's board, and commissions and letters of marque. Rules only, no drawing; the chart shows it.
##
## State lives in the saved game (Campaign.G): rel {"a|b": value}, wars {"a|b": day declared}, news [[day, text]],
## contracts (accepted), offers {port id: {day, list}}, commission {fac, since, marque} or null, betrayed [fac],
## nextContract. Tables: data/diplomacy.json, written from the owner's lore.

var D: Dictionary = {}
const POWERS := ["concord", "directorate", "pacific", "combine", "republic", "freeport", "enclave"]
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
			if not G.wars.has(k) and r <= float(D.bands.war):
				G.wars[k] = G.day; news("WAR. The %s and the %s are at war again. Their fleets will fight wherever they meet." % [GameData.fac[a].name, GameData.fac[b].name])
			elif G.wars.has(k) and r > float(D.bands.peace):
				G.wars.erase(k); news("ARMISTICE. The %s and the %s agree a new armistice. Nobody believes it will last." % [GameData.fac[a].name, GameData.fac[b].name])
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
	for i in fl.size():
		var a: Dictionary = fl[i]
		if not _free(a): continue
		for j in range(i + 1, fl.size()):
			var b: Dictionary = fl[j]
			if not _free(b) or a.fac == b.fac: continue
			if Campaign.mdist(a.x, a.y, b.x, b.y) > Campaign.CONTACT: continue
			var raid: bool = (a.fac == "raiders" and b.kind != "bounty") or (b.fac == "raiders" and a.kind != "bounty")
			if raid and (a.kind == "patrol" or b.kind == "patrol" or a.kind == "convoy" or b.kind == "convoy"):
				_fight(a, b, ""); return
			if a.fac == "raiders" or b.fac == "raiders": continue
			if at_war(a.fac, b.fac): _fight(a, b, ""); return
			a.cool = 25.0; b.cool = 25.0   # they have met: whatever happens, not again for a while
			if band(a.fac, b.fac) in ["armistice", "hostile"] and (a.kind == "patrol" or b.kind == "patrol") and randf() < 0.05:
				shift(a.fac, b.fac, -4.0); _fight(a, b, "incident"); return

func _free(f: Dictionary) -> bool:
	return f.cool <= 0 and not f.get("mission", false) and not f.get("hunter", false) and int(f.get("contract", 0)) == 0 and not f.ships.is_empty()

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
	a.cool = 30.0; b.cool = 30.0
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
	var kinds := ["delivery", "delivery", "hunt", "survey"]
	var foes := []
	for e in POWERS: if at_war(fac, e): foes.append(e)
	if not foes.is_empty(): kinds.append_array(["war", "war"])
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
	if c.kind == "delivery" and Campaign.cargo_cap() - Campaign.cargo_used() < int(c.qty): return "Not enough room in the hold (%d needed)." % int(c.qty)
	return ""

func accept(c: Dictionary) -> void:
	var G := g()
	for k in G.offers: G.offers[k].list.erase(c)
	c.deadline = G.day + int(c.days)
	match c.kind:
		"delivery": G.cargo[c.good] = G.cargo.get(c.good, 0) + int(c.qty)
		"hunt":
			var f: Dictionary = Campaign.spawn_fleet("raiders", "raiders")
			# a flotilla worth the pay: about twice the reward in ships
			var tl: Array = Campaign.enemy_tech(maxi(1, Campaign.enemy_era() - 1))
			var ships: Array = Campaign.build_by_budget(Campaign.C.PATROL_POOL.raiders, float(c.reward) * 2.4, 6, "raiders", tl)
			if ships.size() >= 2: f.ships = ships
			f.x = c.x; f.y = c.y; f.home = {"x": c.x, "y": c.y}; f.contract = int(c.id); f.name = "Raider flotilla (contract)"; c.fleet = int(f.id)
		"war": G.incidents = G.get("incidents", {}); G.incidents[c.target] = maxi(int(G.incidents.get(c.target, 0)), c.deadline)
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
	var G := g(); G.contracts.erase(c); G.rep[c.fac] = G.rep.get(c.fac, 0) - 8
	if c.kind == "hunt":
		for f in G.fleets: if int(f.get("contract", 0)) == int(c.id): f.contract = 0; f.name = "Raider flotilla"
	var t := "Contract failed: %s. %s %s standing -8." % [c.title, why, GameData.fac[c.fac].short]
	Campaign.log_ev(t); Campaign.toast.emit(t)

## Docking: deliveries for this port are handed over, if the goods are still in the hold.
func on_dock(p: Dictionary) -> void:
	var G := g()
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
			"delivery": var p: Dictionary = G.ports[int(c.dest)]; out.append([p.x, p.y, c.title])
			"survey": var q: Dictionary = G.pois[int(c.poi)]; out.append([q.x, q.y, c.title])
			"hunt":
				for f in G.fleets: if int(f.get("contract", 0)) == int(c.id): out.append([f.x, f.y, c.title])
	return out
