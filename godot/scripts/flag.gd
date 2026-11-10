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
	else:   # no flag yet: your ships still need a name and a colour (a detached division is drawn like any fleet)
		GameData.fac["player"] = {"name": "Your squadron", "short": "Yours", "map": COLOUR, "desc": ""}

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
	k *= 1.0 + 0.3 * works(p, "customs") + minf(0.5, 0.1 * recognisers())               # a customs house; trade with the powers that recognise you
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
	Campaign.rep_note("Stormed their port")
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
				s.fac = "player"; s.from = old; s.took = G.day; s.garrison = Structures.garrison_need(s); s.militia = int(s.garrison); s.dmg = maxf(float(s.dmg), 0.3); res.took.append(s.name)
		for o in Diplomacy.POWERS:   # the neighbours draw their conclusions
			if o != old: G.rep[o] = G.rep.get(o, 0) + (3 if Diplomacy.at_war(o, old) else -3)
		Campaign.rep_note("A port stormed (the neighbours' view)")
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
	var old: String = yard_flag(p)   # a port ceded to you by treaty has no `from`: it goes back to whose it was in 1946
	_lose(p, old)
	return "%s is handed back to the %s." % [p.name, GameData.fac[old].name]
func _lose(p: Dictionary, to: String) -> void:
	p.fac = to; p.men = 0; p.erase("from"); p.officers = []; p.offDay = -99; g().offers.erase(str(int(p.id)))
	disband_guard(p)   # its guard squadron is paid off (it would draw pay for ever, with no Governor tab left to disband it)
	for s in Structures.all():
		if int(s.port) == int(p.id) and s.fac == "player": s.fac = to; s.garrison = 0; s.from = ""

# ------------------------------------------------------------------ the calendar
func new_day() -> void:
	var G := g()
	if founded(): _chancery_day()
	if ports().is_empty(): return
	_works_day(); _convoys(); _volunteers()
	if G.day % 30 == 0:
		var total := 0
		for p in ports(): total += tax(p)
		G.credits += total
		Campaign.toast.emit("Harbour dues and customs from your ports: %s." % Campaign.fmt(total)); Campaign.log_ev("Port dues: " + Campaign.fmt(total))
	# the old owner comes back for it: a relief force with troopships, the first within two months, then now and again
	for p in ports():
		var by: String = p.get("from", "")
		if by == "" or Campaign.ports_of(by).is_empty() or treaty(by): continue   # a treaty stops all hostilities, the old owner's too
		if G.fleets.any(func(f): return int(f.get("portAssault", -1)) == int(p.id)): continue
		var age: int = G.day - int(p.get("took", G.day))
		if age < 25: continue
		if randf() < (0.035 if age < 160 else 0.012): launch(p, by)
	# and any power at war with you whose harbours lie near enough may try for a port of yours
	for p in ports():
		if G.fleets.any(func(f): return int(f.get("portAssault", -1)) == int(p.id)): continue
		for o in Diplomacy.POWERS:
			if o == p.get("from", "") or not Campaign.at_war(o) or treaty(o): continue
			if Campaign.ports_of(o).any(func(q): return Campaign.mdist(q.sx, q.sy, p.sx, p.sy) < 1800.0) and randf() < 0.006: launch(p, o); break

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
	Campaign.toast.emit("Word from %s: a %s has sailed from %s to retake the port. Meet it at sea, or trust the garrison." % [p.name, Campaign.fname(f), from.name])
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
	var A: float = troops * 450.0 + Campaign.strength(esc) / 400.0
	var guns := 0.0
	for s in Structures.all(): if int(s.port) == int(p.id) and s.fac == "player" and s.kind == "battery" and not Structures.silenced(s): guns += 250.0
	guns += 450.0 * works(p, "battery")
	# the guard squadron meets them off the harbour first: if it is the stronger, half the transports never arrive
	var gd = guard(p)
	if gd != null and Campaign.mdist(gd.x, gd.y, p.sx, p.sy) < 120.0:
		if Campaign.strength(gd.ships) * randf_range(0.6, 1.4) > Campaign.strength(esc):
			var sunk := int(ceil(troops / 2.0)); troops -= sunk; A = troops * 450.0 + Campaign.strength(esc) / 800.0
			Campaign.toast.emit("Your guard squadron at %s falls on the %s and sinks %d of its transports." % [p.name, Campaign.fname(f), sunk])
		else:
			if gd.ships.size() > 1: gd.ships.pop_back()
			Campaign.toast.emit("Your guard squadron at %s is driven off by the escort of the %s." % [p.name, Campaign.fname(f)])
		for sh in gd.ships: sh.hullFrac = maxf(0.2, float(sh.hullFrac) - randf_range(0.05, 0.3))
		if troops <= 0: Campaign.toast.emit("The %s turns back from %s with nothing left to land." % [f.name, p.name]); return
	var Dv: float = float(p.get("men", 0)) * 3.0 + guns   # men behind walls and on their own quays
	if randf() < Dv / maxf(1.0, A + Dv):
		var lost := int(round(float(p.men) * randf_range(0.1, 0.3))); p.men = maxi(1, int(p.men) - lost)
		Campaign.toast.emit("%s holds. The %s landing is beaten off the quays; %d of your garrison are killed or wounded." % [p.name, GameData.fac[f.fac].short, lost])
		Campaign.log_ev("Held %s against a landing" % p.name)
	else:
		Campaign.toast.emit("FALLEN. %s troops retake %s. Your garrison of %d is lost, and your flag comes down." % [GameData.fac[f.fac].short, p.name, int(p.get("men", 0))])
		Campaign.log_ev("Lost %s" % p.name)
		_lose(p, f.fac)

# ------------------------------------------------------------------ your flag among the powers
## Each power takes one of four stances toward your flag: at war with it, unrecognised (the default: a band of
## adventurers), recognised (its merchants use your ports, yours use its), or bound by a treaty of non-aggression.
## Your standing with each power is the same standing you always had (G.rep).
const RECOG_COST := 20000
const TREATY_COST := 40000
const TREATY_DAYS := 360
const PEACE_COST := 30000        # an indemnity, plus CEDE_COST for each port of theirs you keep
const CEDE_COST := 40000
func recognised(fac: String) -> bool: return founded() and g().flag.get("recog", {}).has(fac)
func treaty(fac: String) -> bool: return founded() and int(g().flag.get("treaty", {}).get(fac, 0)) > int(g().day)
func recognisers() -> int: return g().flag.get("recog", {}).size() if founded() else 0
func stance(fac: String) -> String:
	if Campaign.at_war(fac): return "war"
	if treaty(fac): return "treaty"
	return "recognised" if recognised(fac) else "unrecognised"
func stance_text(fac: String) -> String:
	match stance(fac):
		"war": return "at war with you"
		"treaty": return "treaty of non-aggression, %d days left" % (int(g().flag.treaty[fac]) - int(g().day))
		"recognised": return "recognises your flag"
	return "does not recognise your flag"
func held_from(fac: String) -> Array: return ports().filter(func(p): return p.get("from", "") == fac)

func can_recognise(fac: String) -> String:
	var G := g()
	if recognised(fac): return "Already recognised."
	if Campaign.at_war(fac): return "They are at war with you. Make peace first."
	if ports().is_empty(): return "No power recognises a flag without a port."
	if int(G.rep.get(fac, 0)) < 10: return "Needs standing 10 with them (now %d)." % int(G.rep.get(fac, 0))
	if not held_from(fac).is_empty(): return "Not while you hold a port taken from them. Settle that first (peace terms)."
	if int(G.credits) < RECOG_COST: return "The envoy's gifts and the legation cost %s." % Campaign.fmt(RECOG_COST)
	return ""
func seek_recognition(fac: String) -> String:
	var G := g(); G.credits -= RECOG_COST
	if not G.flag.has("recog"): G.flag.recog = {}
	G.flag.recog[fac] = G.day; G.rep[fac] = G.rep.get(fac, 0) + 5
	Campaign.rep_note("Recognition of your flag")
	Diplomacy.news("RECOGNITION. The %s receives the envoy of %s and recognises its flag. Its merchants may use your harbours, and yours its own." % [GameData.fac[fac].name, flag_name()], true)
	Campaign.log_ev("Recognised by the " + GameData.fac[fac].short); Campaign.save()
	return "The %s recognises %s." % [GameData.fac[fac].name, flag_name()]

func can_treaty(fac: String) -> String:
	var G := g()
	if treaty(fac): return "A treaty is in force."
	if not recognised(fac): return "Only a power that recognises you will treat with you."
	if Campaign.at_war(fac): return "They are at war with you."
	if int(G.rep.get(fac, 0)) < 25: return "Needs standing 25 with them (now %d)." % int(G.rep.get(fac, 0))
	if int(G.credits) < TREATY_COST: return "The negotiations cost %s." % Campaign.fmt(TREATY_COST)
	return ""
func sign_treaty(fac: String) -> String:
	var G := g(); G.credits -= TREATY_COST
	if not G.flag.has("treaty"): G.flag.treaty = {}
	G.flag.treaty[fac] = int(G.day) + TREATY_DAYS
	Diplomacy.news("TREATY. %s and the %s sign a treaty of non-aggression for a year." % [flag_name(), GameData.fac[fac].name], true)
	Campaign.log_ev("Treaty with the " + GameData.fac[fac].short); Campaign.save()
	return "Treaty signed with the %s: for a year your growth does not alarm them, and they send no force against your ports." % GameData.fac[fac].name

## Peace with a power at war with you: an indemnity, and for each port of theirs you keep, its price. They cede those
## ports (no more relief forces), call off any force at sea, and the armistice holds again.
func peace_cost(fac: String) -> int: return PEACE_COST + CEDE_COST * held_from(fac).size()
func can_peace(fac: String) -> String:
	var G := g()
	if not Campaign.at_war(fac): return "You are not at war with them."
	# a war that is your commission's or a contract's is not theirs to end: paying would change nothing
	if int(G.rep.get(fac, 0)) > Campaign.WAR_STANDING and Campaign.incident_days(fac) <= 0 and held_from(fac).is_empty() and not g().get("nukedFacs", []).has(fac) and not (Campaign.perk("outlaw", []) as Array).has(fac):
		return "Your quarrel with them is your commission's, not your own: there is nothing between you to settle."
	if g().get("nukedFacs", []).has(fac): return "They will never treat with you: you used the bomb on them."
	if (Campaign.perk("outlaw", []) as Array).has(fac): return "They will not treat with you: your quarrel with them is older than your flag."
	if int(G.credits) < peace_cost(fac): return "Their terms: %s." % Campaign.fmt(peace_cost(fac))
	return ""
func make_peace(fac: String) -> String:
	var G := g(); var ceded: Array = held_from(fac); G.credits -= peace_cost(fac)
	G.rep[fac] = maxi(int(G.rep.get(fac, 0)), -9); if G.has("incidents"): G.incidents.erase(fac)
	Campaign.rep_note("Peace made")
	for c in G.contracts.duplicate(): if c.get("target", "") == fac and (c.kind == "war" or c.kind == "strike"): Diplomacy.fail(c, "You made peace with its target.")
	for p in ceded: p.from = ""
	for s in Structures.held(): if s.from == fac: s.from = ""
	for f in G.fleets.duplicate(): if (is_relief(f) or Structures._is_assault(f)) and f.fac == fac: G.fleets.erase(f)
	Diplomacy.news("PEACE. %s and the %s come to terms%s." % [flag_name(), GameData.fac[fac].name, (": " + ", ".join(ceded.map(func(p): return p.name)) + " ceded") if not ceded.is_empty() else ""], true)
	Campaign.log_ev("Peace with the " + GameData.fac[fac].short); Campaign.save()
	return "Peace with the %s. Their ports open to you again once your standing recovers." % GameData.fac[fac].name

## Daily: a treaty broken by war is void; once a month the powers weigh how large you have grown.
func _chancery_day() -> void:
	var G := g()
	for fac in G.flag.get("treaty", {}).keys():
		if int(G.flag.treaty[fac]) > int(G.day) and Campaign.at_war(fac):
			G.flag.treaty.erase(fac); G.rep[fac] = G.rep.get(fac, 0) - 20
			Campaign.rep_note("Treaty broken")
			Diplomacy.news("TREATY BROKEN. The %s denounces its treaty with %s." % [GameData.fac[fac].name, flag_name()], true)
	for fac in G.flag.get("recog", {}).keys():
		if Campaign.at_war(fac): G.flag.recog.erase(fac); Campaign.toast.emit("The %s withdraws its recognition of your flag." % GameData.fac[fac].name)
	if int(G.day) % 30 != 0: return
	var size := 0.0
	for p in ports(): size += weight(p)
	var alarm := int(floor((size - 2.0) / 2.0))   # two small ports alarm nobody; an empire in the making does
	if alarm <= 0: return
	Campaign.rep_note("Other dealings")
	var wary := []
	for fac in Diplomacy.POWERS:
		if treaty(fac) or Campaign.at_war(fac): continue
		var before: int = G.rep.get(fac, 0); G.rep[fac] = before - mini(4, alarm)
		if before >= -10 and int(G.rep[fac]) < -10: wary.append(GameData.fac[fac].short)
	Campaign.rep_note("Alarm at your flag's growth")
	if not wary.is_empty(): Diplomacy.news("ALARM. Your flag has grown too large for the liking of: %s. Their ports close to you." % ", ".join(wary), true)
	else: Campaign.toast.emit("The powers watch your flag grow: standing -%d with every power not bound to you by treaty." % mini(4, alarm))

# ------------------------------------------------------------------ works in your ports
## What you can build in a port. Each takes its days to finish; `max` of each.
const WORKS := {
	"battery": {"name": "Harbour battery", "cost": 30000, "days": 30, "max": 3, "text": "Heavy guns on the moles: each adds as much to the defence against a landing as 180 men."},
	"barracks": {"name": "Barracks and depot", "cost": 20000, "days": 20, "max": 1, "text": "The garrison recruits for itself: 15 men a week until it is up to strength."},
	"customs": {"name": "Customs house", "cost": 25000, "days": 20, "max": 1, "text": "Harbour dues up by three tenths."},
	"yard": {"name": "Building slip", "cost": 45000, "days": 45, "max": 1, "text": "The yard can lay down battleships and fleet carriers, as a capital's can."}}
func works(p: Dictionary, k: String) -> int:   # finished
	var n := 0
	for d in p.get("works", {}).get(k, []): if int(d) <= int(g().day): n += 1
	return n
func works_building(p: Dictionary, k: String) -> int:   # days left on the one under way, or 0
	for d in p.get("works", {}).get(k, []): if int(d) > int(g().day): return int(d) - int(g().day)
	return 0
func can_build(p: Dictionary, k: String) -> String:
	var w: Dictionary = WORKS[k]
	if p.get("works", {}).get(k, []).size() >= int(w.max): return "Built." if works_building(p, k) == 0 else "Building: %d days left." % works_building(p, k)
	if works_building(p, k) > 0: return "Building: %d days left." % works_building(p, k)
	if int(g().credits) < int(w.cost): return "Costs %s." % Campaign.fmt(int(w.cost))
	return ""
func build(p: Dictionary, k: String) -> String:
	var G := g(); var w: Dictionary = WORKS[k]; G.credits -= int(w.cost)
	if not p.has("works"): p.works = {}
	if not p.works.has(k): p.works[k] = []
	p.works[k].append(int(G.day) + int(w.days))
	return "%s laid down at %s: ready in %d days." % [w.name, p.name, int(w.days)]
func _works_day() -> void:
	var G := g()
	for p in ports():
		for k in p.get("works", {}): for d in p.works[k]: if int(d) == int(G.day): Campaign.toast.emit("%s: the %s is finished." % [p.name, String(WORKS[k].name).to_lower()])
		if works(p, "barracks") > 0 and int(G.day) % 7 == 0 and int(p.get("men", 0)) < hold_need(p): p.men = mini(hold_need(p), int(p.get("men", 0)) + 15)

# ------------------------------------------------------------------ guard squadrons and trade
## A guard squadron: warships of your own that cruise off one port. It meets a relief force before it lands, and it
## fights raiders and the ships of powers at war with you that come near (Diplomacy.clash_tick). Paid by the day.
const GUARD_COST := 30000
const GUARD_PAY := 60.0
func guard(p: Dictionary):
	for f in g().fleets: if int(f.get("guardOf", -1)) == int(p.id): return f
	return null
func guards() -> int: return g().fleets.filter(func(f): return int(f.get("guardOf", -1)) >= 0).size()
func can_guard(p: Dictionary) -> String:
	if guard(p) != null: return "A guard squadron is on station."
	if int(g().credits) < int(GUARD_COST * weight(p)): return "Costs %s." % Campaign.fmt(int(GUARD_COST * weight(p)))
	return ""
func yard_flag(p: Dictionary) -> String: return p.get("from", "") if p.get("from", "") != "" else Campaign.C.ports[int(p.id)].fac
func raise_guard(p: Dictionary) -> Dictionary:
	var G := g(); G.credits -= int(GUARD_COST * weight(p)); var yf := yard_flag(p)
	var f := {"id": G.nextId, "kind": "patrol", "fac": "player", "h": randf() * TAU, "v": 0.0, "tx": null, "ty": null, "cool": 0.0, "ships": [], "cargo": {},
		"x": p.sx, "y": p.sy, "home": {"x": p.sx, "y": p.sy}, "guardOf": int(p.id), "name": "%s guard squadron" % p.name}
	G.nextId += 1
	f.ships = Campaign.build_by_budget(Campaign.C.PATROL_POOL[yf], 50000.0 * weight(p) * (1.0 + G.day / 250.0), 4, yf, G.tech)   # it grows with the times, as the forces sent against it do
	if f.ships.is_empty(): f.ships.append(Campaign.new_ship("corvette", null, yf, G.tech))
	for sh in f.ships: sh.pal = "player"; sh.name = GameData.names.player.pick_random()
	G.fleets.append(f)
	return f
func disband_guard(p: Dictionary) -> void:
	var f = guard(p)
	if f != null: g().fleets.erase(f)

## Merchants under your flag: each port sends a convoy to the nearest harbour that will have it and is paid when it
## arrives (half as much again where your flag is recognised). Raiders and enemies can sink it on the way.
func _convoys() -> void:
	var G := g()
	for p in ports():
		if G.fleets.any(func(f): return int(f.get("convoyOf", -1)) == int(p.id)) or randf() > 0.12: continue
		var dest = null; var bd := 2600.0
		for q in G.ports:
			if q.fac == "player" and q != p: pass
			elif q == p or Campaign.hostile(q.fac): continue
			var d := Campaign.mdist(q.sx, q.sy, p.sx, p.sy)
			if d > 150.0 and d < bd: bd = d; dest = q
		if dest == null: continue
		var f := {"id": G.nextId, "kind": "convoy", "fac": "player", "h": 0.0, "v": 0.0, "tx": null, "ty": null, "cool": 0.0, "ships": [], "cargo": {},
			"x": p.sx, "y": p.sy, "home": {"x": p.sx, "y": p.sy}, "dest": int(dest.id), "from": int(p.id), "convoyOf": int(p.id), "name": "%s convoy" % G.flag.short, "cash": randi_range(6, 16) * 1000}
		G.nextId += 1
		for i in randi_range(1, 2): var sh: Dictionary = Campaign.new_ship("freighter", null, "player", G.tech); f.ships.append(sh)
		for gd in Campaign.C.GOODS: if randf() < 0.5: f.cargo[gd.id] = randi_range(15, 50)
		f.cargo.fuel = int(f.cargo.get("fuel", 0)) + randi_range(40, 100)
		G.fleets.append(f)
func convoy_pay(f: Dictionary) -> int:
	var G := g(); var d: Dictionary = G.ports[int(f.dest)]; var p: Dictionary = G.ports[int(f.from)]
	return int(round(900.0 * f.ships.size() * weight(p) * (1.5 if d.fac == "player" or recognised(d.fac) else 1.0) / 100.0) * 100)
func convoy_arrived(f: Dictionary) -> void:
	var G := g(); var pay := convoy_pay(f); G.credits += pay; G.flag.trade = int(G.flag.get("trade", 0)) + pay
	Campaign.log_ev("Convoy to %s: +%s" % [G.ports[int(f.dest)].name, Campaign.fmt(pay)])

# ------------------------------------------------------------------ a rising flag draws men and ships
## Mid-month: an officer may offer his sword, and now and then a ship comes over with her crew and lies in one of your
## ports until you commission her (a bounty to her crew) or send her away.
func _volunteers() -> void:
	var G := g()
	if int(G.day) % 30 != 15: return
	var ps: Array = ports(); var n := ps.size()
	if randf() < minf(0.6, 0.2 * n) and G.officers.size() < 12:
		var o: Dictionary = Campaign.new_officer(randi_range(2, 4)); G.officers.append(o)
		Campaign.toast.emit("%s, an officer of some name, offers his sword to %s (level %d). Give him a ship in Command, under Officers." % [o.name, flag_name(), int(o.lvl)])
	if randf() < minf(0.45, 0.12 * n):
		var p: Dictionary = ps.pick_random()
		if p.get("volunteers", []).size() >= 2: return
		var from: String = Diplomacy.POWERS.filter(func(o): return not Campaign.ports_of(o).is_empty()).pick_random()
		var sh: Dictionary = Campaign.new_ship(["corvette", "dd", "dd", "ss", "cl"].pick_random(), null, from, Campaign.enemy_tech(Campaign.fac_era(from)))
		sh.pal = "player"; sh.name = GameData.names.player.pick_random(); sh.hullFrac = randf_range(0.55, 0.9); sh.cameFrom = from
		if not p.has("volunteers"): p.volunteers = []
		p.volunteers.append(sh)
		Diplomacy.news("DEFECTION. The %s %s, late of the %s, runs into %s and asks to serve under your flag." % [String(Campaign.hull(sh).name).to_lower(), sh.name, GameData.fac[from].name, p.name], true)
func bounty(sh: Dictionary) -> int: return int(round(Campaign.ship_value(sh) * 0.25 / 500.0) * 500)
func commission(p: Dictionary, sh: Dictionary) -> String:
	var G := g(); G.credits -= bounty(sh); p.volunteers.erase(sh); sh.erase("cameFrom"); sh.paid = bounty(sh); G.fleet.append(sh)
	var note := Campaign.study_prize(sh)
	return "The %s joins your squadron. She needs %d crew.%s" % [sh.name, int(Campaign.hull(sh).crew), (" " + note) if note != "" else ""]
