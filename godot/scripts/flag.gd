extends Node
## Your own flag (step 5 of the owner's plan, first part): founding it, storming ports with troops, holding and
## taxing them, and the old owners' attempts to take them back. Autoload `Flag`. State lives in the save:
## G.flag = {name, short, day}; a port you hold has fac "player", `from` (who you took it from, whose yard workers
## and designs stay), `men` (its garrison) and `took` (the day). See docs/OWN_FLAG.md.

const COLOUR := "#e3b23c"
const FOUND_COST := 30000        # a charter, a printing of ensigns, agents in the freeports
const PORT_MEN := 400            # defenders of a harbour, times its garrison weight (and doubled at a capital)
const HOLD_MEN := 250            # the garrison a port wants, times its garrison weight
const TAX := 3500                # a month, times the port's garrison weight (doubled at a capital)
const NAMES := ["Free Captains' League", "Meridian Company", "Ironbound Fellowship", "Sovereign Squadron", "Grey Ensign Compact", "League of the Open Sea"]

func g() -> Dictionary: return Campaign.G
func founded() -> bool: return g().has("flag")
func flag_name() -> String: return str(g().flag.name) if founded() else "your squadron"

## Puts your flag into the tables the rest of the game reads a power from (its name and chart colour), so a port that
## flies it works like any other. Called on a new game, on loading and on founding.
func apply() -> void:
	var G := g()
	if G.has("flag"):
		GameData.fac["player"] = {"name": G.flag.name, "short": G.flag.short, "map": COLOUR, "desc": "Your own flag, founded in %d." % Campaign.year()}
	else:
		GameData.fac.erase("player")

## Why you can't found a flag yet, or "".
func can_found() -> String:
	var G := g()
	if founded(): return "Your flag already flies."
	var held: Array = Structures.held()
	if not held.any(func(s): return s.kind == "navalbase") and held.size() < 3: return "A flag needs ground under it: hold a naval base, or any three structures ashore."
	if int(G.credits) < FOUND_COST: return "Founding costs %s." % Campaign.fmt(FOUND_COST)
	return ""

## Founds your flag. You leave any service you are in; the powers take note.
func found(flag_name_: String) -> String:
	var G := g(); var nm := flag_name_.strip_edges()
	if nm == "": nm = NAMES[0]
	G.credits -= FOUND_COST
	if G.get("commission") != null: Diplomacy.resign()
	var words: PackedStringArray = nm.split(" ")
	G.flag = {"name": nm, "short": words[words.size() - 1] if words.size() > 1 and nm.length() > 16 else nm, "day": G.day}
	apply()
	Diplomacy.news("A NEW FLAG. %s is proclaimed. The chancelleries of the powers take note, and wait to see what it is worth." % nm, true)
	Campaign.log_ev("Founded " + nm); Campaign.save()
	return "%s is founded. Ports you storm now fly your flag: bring troops." % nm

# ------------------------------------------------------------------ ports
func ports() -> Array: return g().ports.filter(func(p): return p.fac == "player")
func weight(p: Dictionary) -> float: return float(p.get("garrison", 1)) * (2.0 if p.capital else 1.0)
func hold_need(p: Dictionary) -> int: return int(HOLD_MEN * weight(p))
func tax(p: Dictionary) -> int:
	var k: float = clampf(float(p.get("men", 0)) / maxf(1.0, hold_need(p)), 0.3, 1.0)   # an under-garrisoned port pays less: smuggling, unrest
	return int(round(TAX * weight(p) * k / 100.0) * 100)
func garrison_total() -> int:
	var n := 0
	for p in ports(): n += int(p.get("men", 0))
	return n

## The men a port puts on its quays against a landing: its harbour garrison, and the crews of every battery and
## naval base of its own that still stands near it. Silence those first.
func port_defenders(p: Dictionary) -> float:
	var d: float = PORT_MEN * weight(p)
	for s in Structures.all():
		if int(s.port) == int(p.id) and s.fac == p.fac and (s.kind == "battery" or s.kind == "navalbase") and not Structures.silenced(s): d += 220.0 * (1.0 - float(s.dmg))
	return d
func assault_odds(p: Dictionary) -> float:
	var A: float = Structures.troops() * (1.25 if Campaign.has_tech("amphib") else 1.0)
	return clampf(A / maxf(1.0, A + port_defenders(p)) * 1.3 - 0.15, 0.03, 0.95)

func can_assault(p: Dictionary) -> String:
	var G := g()
	if p.fac == "player": return "It is yours."
	if not founded(): return "Only a flag can hold a port. Found yours first (Command, Holdings)."
	if Structures.troops() <= 0: return "You have no troops embarked."
	if Campaign.mdist(G.player.x, G.player.y, p.sx, p.sy) > 40.0: return "Bring the fleet off the harbour."
	return ""

## Your soldiers storm the harbour. Win, and the port is yours with everything of its that stands near it; lose, and
## the survivors are taken off. Either way it is an act of war against its owner.
func assault(p: Dictionary) -> Dictionary:
	var G := g(); var old: String = p.fac; var men := Structures.troops(); var D := port_defenders(p); var odds := assault_odds(p)
	G.rep[old] = G.rep.get(old, 0) - 40; Campaign.incident(old); Diplomacy.on_open_fire(old)
	var A: float = men * (1.25 if Campaign.has_tech("amphib") else 1.0)
	var won := randf() < odds
	var lost := int(round(men * clampf(D / maxf(1.0, A + D) * randf_range(0.5, 1.1) * (0.7 if won else 1.4), 0.03, 0.95)))
	var left := maxi(0, men - lost)
	var res := {"name": p.name, "men": men, "lost": lost, "won": won and left > 0, "odds": odds, "defenders": int(round(D)), "from": old, "took": []}
	if res.won:
		var ashore := mini(left, hold_need(p)); G.troops = left - ashore
		p.fac = "player"; p.from = old; p.men = ashore; p.took = G.day; p.officers = []; p.offDay = -99; G.offers.erase(str(int(p.id)))
		for s in Structures.all():   # what stands round the port follows it, under its own militia
			if int(s.port) == int(p.id) and s.fac == old:
				s.fac = "player"; s.from = old; s.took = G.day; s.garrison = Structures.garrison_need(s); s.dmg = maxf(float(s.dmg), 0.3); res.took.append(s.name)
		for o in Diplomacy.POWERS:   # the neighbours draw their conclusions
			if o != old: G.rep[o] = G.rep.get(o, 0) + (3 if Diplomacy.at_war(o, old) else -3)
		Diplomacy.news("FALLEN. %s falls to %s. A new ensign goes up over the harbour, and the %s swears to have it down again." % [p.name, flag_name(), GameData.fac[old].name], true)
		Campaign.log_ev("Stormed %s" % p.name)
	else:
		G.troops = left
		Diplomacy.news("REPULSED. A landing at %s by %s is thrown back into the sea." % [p.name, flag_name()], true)
		Campaign.log_ev("Landing at %s beaten off" % p.name)
	Campaign.save()
	return res

## Soldiers from your transports into the garrison, or back aboard.
func reinforce(p: Dictionary, n: int) -> int:
	var k := mini(n, Structures.troops()); if k <= 0: return 0
	g().troops = Structures.troops() - k; p.men = int(p.get("men", 0)) + k
	return k
func take_off(p: Dictionary, n: int) -> int:
	var k := mini(mini(n, int(p.get("men", 0))), Structures.troop_capacity() - Structures.troops()); if k <= 0: return 0
	g().troops = Structures.troops() + k; p.men = int(p.men) - k
	return k

## Give a port up: it goes back to the flag you took it from, with what stands round it.
func abandon(p: Dictionary) -> String:
	var old: String = p.get("from", Campaign.C.ports[int(p.id)].fac)
	_lose(p, old)
	return "%s is handed back to the %s." % [p.name, GameData.fac[old].name]
func _lose(p: Dictionary, to: String) -> void:
	p.fac = to; p.men = 0; p.erase("from"); p.officers = []; p.offDay = -99; g().offers.erase(str(int(p.id)))
	for s in Structures.all():
		if int(s.port) == int(p.id) and s.fac == "player": s.fac = to; s.garrison = 0; s.from = ""

# ------------------------------------------------------------------ the calendar
func new_day() -> void:
	var G := g()
	if ports().is_empty(): return
	if G.day % 30 == 0:
		var total := 0
		for p in ports(): total += tax(p)
		G.credits += total
		Campaign.toast.emit("Harbour dues and customs from your ports: %s." % Campaign.fmt(total)); Campaign.log_ev("Port dues: " + Campaign.fmt(total))
	# the old owner comes back for it: a relief force with troopships, the first within two months, then now and again
	for p in ports():
		var by: String = p.get("from", "")
		if by == "" or Campaign.ports_of(by).is_empty(): continue
		if G.fleets.any(func(f): return int(f.get("portAssault", -1)) == int(p.id)): continue
		var age: int = G.day - int(p.get("took", G.day))
		if age < 25: continue
		if randf() < (0.035 if age < 160 else 0.012): launch(p, by)

## A relief force sails from the old owner's nearest port.
func launch(p: Dictionary, by: String) -> Dictionary:
	var G := g(); var from = null; var bd := INF
	for q in Campaign.ports_of(by):
		var d := Campaign.mdist(q.sx, q.sy, p.sx, p.sy)
		if d < bd: bd = d; from = q
	var f: Dictionary = Campaign.spawn_fleet("patrol", by)
	var tl: Array = Campaign.enemy_tech(Campaign.fac_era(by)) + ["amphib"]
	var esc: Array = Campaign.build_by_budget(Campaign.C.PATROL_POOL[by], (30000.0 + randf() * 40000.0) * weight(p) * (1.0 + G.day / 250.0), 5, by, tl)
	if not esc.is_empty(): f.ships = esc
	var carrier := "ap" if Campaign.design_for("ap", by, tl) != "" else "freighter"
	for i in randi_range(2, 3): var tr: Dictionary = Campaign.new_ship(carrier, null, by, tl); tr.troops = true; f.ships.append(tr)
	f.kind = "assault"; f.portAssault = int(p.id); f.name = "%s relief force" % GameData.fac[by].short; f.cool = 0.0
	f.x = from.sx; f.y = from.sy; f.home = {"x": from.sx, "y": from.sy}; f.tgt = {"x": p.sx, "y": p.sy}
	Campaign.set_course(f, p.sx, p.sy)
	Campaign.toast.emit("Word from %s: a %s has sailed from %s to retake the port. Meet it at sea, or trust the garrison." % [p.name, f.name.to_lower(), from.name])
	return f

func is_relief(f: Dictionary) -> bool: return int(f.get("portAssault", -1)) >= 0

## The relief force reached the harbour: its landing is fought out against your garrison.
func relief_lands(f: Dictionary) -> void:
	var G := g(); var p: Dictionary = G.ports[int(f.portAssault)]; G.fleets.erase(f)
	if p.fac != "player": return
	var troops := 0; var esc := []
	for sh in f.ships:
		if sh.get("troops", false): troops += 1
		else: esc.append(sh)
	if troops == 0: Campaign.toast.emit("The %s reaches %s without its troopships and turns back." % [f.name, p.name]); return
	var A: float = troops * 450.0 + Campaign.strength(esc) / 250.0
	var guns := 0.0
	for s in Structures.all(): if int(s.port) == int(p.id) and s.fac == "player" and s.kind == "battery" and not Structures.silenced(s): guns += 250.0
	var Dv: float = float(p.get("men", 0)) * 2.0 + guns
	if randf() < Dv / maxf(1.0, A + Dv):
		var lost := int(round(float(p.men) * randf_range(0.1, 0.3))); p.men = maxi(1, int(p.men) - lost)
		Campaign.toast.emit("%s holds. The %s landing is beaten off the quays; %d of your garrison are killed or wounded." % [p.name, GameData.fac[f.fac].short, lost])
		Campaign.log_ev("Held %s against a landing" % p.name)
	else:
		Campaign.toast.emit("FALLEN. %s troops retake %s. Your garrison of %d is lost, and your flag comes down." % [GameData.fac[f.fac].short, p.name, int(p.get("men", 0))])
		Campaign.log_ev("Lost %s" % p.name)
		_lose(p, f.fac)
