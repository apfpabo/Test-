class_name Origins
## Campaign origins: who you were before the game begins. The owner's text for each is kept, word for word, in
## docs/LORE.md; this file turns it into a starting position: ships (worn or damaged where the story says so), money,
## cargo, standing with each flag, the captain's experience, and lasting conditions (perks). Origins tied to a navy
## let the player choose which of the three great navies.
##
## Perks read by Campaign and the chart:
##   restricted: [fac]        ports of these flags offer limited services (no shipyard or officers, dearer goods)
##   hunted: [{fac, name, days, max, every, budget}]
##                            hunter groups of that flag seek you out until the day given (hostile whatever your standing)
##   trade: 0.06              better buying and selling margins
##   evade: 15                added to the chance to break off from a hostile force (percentage points)
##   prize: {fac: 1.3}        prize money multiplier for ships of that flag sunk or taken
##   rp: 40                   research points at the start (intelligence brought over)

const NAVIES := ["concord", "directorate", "pacific"]
# per great navy: its enemy in the unfinished war, home and second port, a neutral bolt-hole, and its ships
const NAVY := {
	"concord": {"enemy": "directorate", "home": "Calder Roads", "second": "Halbrook", "neutral": "Halvardsby", "dd": "dd_fletcher", "cl": "cl_cleveland", "small": "co_flower"},
	"directorate": {"enemy": "concord", "home": "Strelsk", "second": "Norvask", "neutral": "Isfjell", "dd": "dd_narvik", "cl": "ca_hipper", "small": "pt_sboot"},
	"pacific": {"enemy": "directorate", "home": "Amakura", "second": "Lumaya", "neutral": "Sanpo", "dd": "dd_kagero", "cl": "cl_agano", "small": "co_tacoma"},
}

const LIST := ["disgraced", "hijacker", "merchant", "survivor", "privateer", "defector", "smuggler", "academy"]
const INFO := {
	"disgraced": {"label": "The Disgraced Officer", "navy": true, "short": "Stripped of rank after a disaster or a purge, pensioned off with a worn-out destroyer.",
		"start": "A worn destroyer, a seasoned captain, little money. Your old navy is cold and its ports offer only limited services; its rivals see a useful defector."},
	"hijacker": {"label": "The Hijacker", "navy": false, "short": "You seized a freighter in a bloody action. There is a price on your head.",
		"start": "A seized freighter, a small hard crew, almost no money. Legitimate flags are hostile and bounty hunters are out for you; the freeports will still trade."},
	"merchant": {"label": "The Merchant Captain", "navy": false, "short": "You own a modest freighter and chase profitable, dangerous contracts.",
		"start": "A Victory-type freighter, a good stake and cargo, better trading margins. Tolerated by the great powers, welcome among traders; raiders see easy prey."},
	"survivor": {"label": "The Survivor of the Lost Fleet", "navy": true, "short": "Your task force was annihilated. You escaped in a damaged ship.",
		"start": "A badly damaged destroyer, a short-handed crew, an experienced captain and next to nothing else. The victors would like you silenced; independents treat you with respect."},
	"privateer": {"label": "The Privateer", "navy": false, "short": "A letter of marque from the Tarsene Free Republic against Directorate shipping.",
		"start": "A fast Corvo destroyer, the Republic's favour and better prize money against the Directorate. The Directorate treats you as a combatant; neutrals are wary."},
	"defector": {"label": "The Defector", "navy": true, "short": "You came over to the enemy with a valuable ship and what you know.",
		"start": "A cruiser from your old navy and intelligence worth research points. Your old flag hunts you; your new patrons are interested but don't fully trust you."},
	"smuggler": {"label": "The Smuggler", "navy": false, "short": "Fast, discreet and lightly armed: restricted goods through blockades.",
		"start": "A fast destroyer stripped of her torpedoes, contraband in the hold, a better chance to slip away, good trading. Navies see a nuisance; freeports a customer."},
	"academy": {"label": "The Academy Cast-Off", "navy": true, "short": "A green junior officer handed a minor command as a favour or a punishment.",
		"start": "A corvette or torpedo boat, a green captain, a modest stake and a clean name. Nobody important is watching yet."},
}

## The starting position for an origin (and, for navy origins, the navy chosen).
static func build(key: String, navy := "concord") -> Dictionary:
	var N: Dictionary = NAVY.get(navy, NAVY.concord); var en: String = N.enemy
	var others := NAVIES.filter(func(f): return f != navy)
	var st := {"key": key, "navy": navy, "fleet": [], "credits": 20000, "cargo": {"fuel": 70, "food": 40}, "rep": {}, "port": "Calder Roads", "officer": 1, "crew": 1.0, "perks": {}}
	match key:
		"disgraced":
			st.fleet = [[N.dd, null, {"hull": 0.7}]]; st.credits = 14000; st.officer = 3; st.port = N.second
			st.rep = {navy: -5, en: -30}; for o in others: if o != en: st.rep[o] = 10
			if en != "concord" and navy != "concord": st.rep["concord"] = 5
			st.perks = {"restricted": [navy]}
		"hijacker":
			st.fleet = [["fr_liberty", "Ashen Wake", {"hull": 0.8}], ["pt_elco", null, {"hull": 0.85}]]; st.credits = 9000; st.officer = 2; st.port = "Kesselport"; st.crew = 0.85
			st.cargo = {"fuel": 60, "food": 25, "munitions": 20}
			st.rep = {"concord": -35, "directorate": -35, "pacific": -35, "combine": -45, "republic": -20, "enclave": -15, "freeport": 15}
			st.perks = {"evade": 5, "hunted": [{"fac": "raiders", "name": "Bounty hunters", "days": 240, "max": 2, "every": 0.06, "budget": 30000}, {"fac": "combine", "name": "Combine reprisal squadron", "days": 150, "max": 1, "every": 0.03, "budget": 45000}]}
		"merchant":
			st.fleet = [["fr_victory", "Southern Trader", {}]]; st.credits = 45000; st.port = "Cape Ombra"
			st.cargo = {"fuel": 120, "food": 60, "steel": 60, "electronics": 20}
			st.rep = {"combine": 15, "freeport": 15}
			st.perks = {"trade": 0.06}
		"survivor":
			st.fleet = [[N.dd, null, {"hull": 0.45}]]; st.credits = 6000; st.officer = 3; st.port = N.neutral; st.crew = 0.7
			st.cargo = {"fuel": 35, "food": 15}
			st.rep = {navy: 0, en: -40, "freeport": 10, "enclave": 10}
			st.perks = {"hunted": [{"fac": en, "name": GameData.fac[en].short + " hunter group", "days": 180, "max": 1, "every": 0.025, "budget": 50000}]}
		"privateer":
			st.fleet = [["dd_soldati", null, {}]]; st.credits = 20000; st.officer = 2; st.port = "Puerto Corvo"
			st.rep = {"republic": 30, "directorate": -40, "concord": -5, "pacific": -5, "combine": -5}
			st.perks = {"prize": {"directorate": 1.3}}
		"defector":
			var to: String = en
			st.fleet = [[N.cl, null, {"hull": 0.9}]]; st.credits = 20000; st.officer = 2; st.port = NAVY[to].home if NAVY.has(to) else "Tarsa"
			st.rep = {navy: -60, to: 5}; for o in GameData.fac: if not st.rep.has(o) and o != "raiders" and o != "freeport": st.rep[o] = -5
			st.perks = {"rp": 40, "hunted": [{"fac": navy, "name": GameData.fac[navy].short + " intelligence squadron", "days": 300, "max": 2, "every": 0.04, "budget": 60000}]}
		"smuggler":
			st.fleet = [["dd_soldati", null, {"strip": ["T"]}]]; st.credits = 28000; st.officer = 2; st.port = "Port Saffron"
			st.cargo = {"fuel": 90, "food": 20, "medicine": 15, "electronics": 10}
			st.rep = {"freeport": 25, "concord": -10, "directorate": -10, "pacific": -5}
			st.perks = {"trade": 0.03, "evade": 15}
		"academy":
			st.fleet = [[N.small, null, {}]]; st.credits = 15000; st.officer = 1; st.port = N.home
			st.rep = {navy: 10, en: -30}
	return st

## The owner's text for each origin (data/lore.json, the same words as docs/LORE.md).
static func lore(key: String) -> Dictionary:
	var f := FileAccess.open("res://data/lore.json", FileAccess.READ)
	if f == null: return {}
	var d = JSON.parse_string(f.get_as_text())
	return d.origins.get(key, {}) if d is Dictionary else {}
