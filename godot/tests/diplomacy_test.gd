extends Node
## Diplomacy check: a simulated year of relations and events between the powers, clashes at sea, every kind of
## contract taken and finished, a commission with its pay and a betrayal, and a save/load round trip.
## godot --headless --path godot res://tests/diplomacy_test.tscn
func _ready() -> void:
    seed(7)
    Campaign.new_game("commission")
    var G: Dictionary = Campaign.G
    var port := func(n): for p in G.ports: if p.name == n: return p
    # --- contracts at Calder Roads: sign one of each kind we can
    var cr: Dictionary = port.call("Calder Roads")
    var kinds := {}
    for tries in 12:
        G.offers = {}
        for c in Diplomacy.offers(cr): if not kinds.has(c.kind): kinds[c.kind] = c
    print("offer kinds seen: ", kinds.keys())
    G.cargo.food = 0; G.cargo.fuel = 20
    for k in ["delivery", "survey", "hunt"]:
        if kinds.has(k): print("sign %s: %s -> %s" % [k, kinds[k].title, Diplomacy.can_accept(kinds[k]) if Diplomacy.can_accept(kinds[k]) != "" else "ok"]); if Diplomacy.can_accept(kinds[k]) == "": Diplomacy.accept(kinds[k])
    var credits0: int = int(G.credits)
    for c in G.contracts.duplicate():
        match c.kind:
            "delivery": Diplomacy.on_dock(G.ports[int(c.dest)])
            "survey": var lines := []; Diplomacy.on_survey(G.pois[int(c.poi)], lines); print("  ", lines)
            "hunt":
                var f = null
                for q in G.fleets: if int(q.get("contract", 0)) == int(c.id): f = q
                var notes := []; Diplomacy.on_battle(f, f.ships.size(), true, notes); print("  ", notes)
    print("contracts left %d, credits +%d, Concord standing %d" % [G.contracts.size(), int(G.credits) - credits0, G.rep.concord])
    # --- a commission: offered at standing 20, paid monthly, torn up by betrayal
    G.rep.concord = 25
    print("commission offer: '%s'" % Diplomacy.can_commission("concord")); Diplomacy.take_commission("concord")
    var c1: int = int(G.credits); G.cargo.food = 9999; G.cargo.fuel = 9999
    for d in 31: Diplomacy.new_day(); G.day += 1
    print("after a month in service: credits %+d, still commissioned %s" % [int(G.credits) - c1, G.commission != null])
    Diplomacy.on_open_fire("concord"); print("after firing on the Concord: commission %s, standing %d, offer again: '%s'" % [G.commission, G.rep.concord, Diplomacy.can_commission("concord")])
    # --- a year between the powers, with the fleets at sea
    G.rep.concord = 10; G.incidents = {}
    var news0: int = G.news.size(); var fleets0: int = G.fleets.size()
    for f in G.fleets: f.cool = 0.0
    Campaign.G.player.cool = 99999.0
    var t0 := Time.get_ticks_msec(); var was_war := false
    for i in 30 * 10 * 360:
        Campaign.paused = false; Campaign.update(1.0 / 30.0); Campaign.G.player.cool = 99999.0
        if i % 300 == 0:
            var k := Diplomacy.pair("concord", "directorate"); var w: bool = G.wars.has(k)
            if w != was_war: print("  day %d: Concord-Directorate %s" % [G.day, "WAR" if w else "armistice"]); was_war = w
    print("360 days: %d ms, news %d, fleets %d -> %d" % [Time.get_ticks_msec() - t0, G.news.size() - news0, fleets0, G.fleets.size()])
    for n in G.news.slice(-10): print("  day %d: %s" % [n[0], n[1]])
    var P: Array = Diplomacy.POWERS
    for i in P.size():
        for j in range(i + 1, P.size()):
            var bd: String = Diplomacy.band(P[i], P[j])
            if bd != "neutral" and bd != "cool": print("  %s-%s %s %d" % [P[i], P[j], bd, int(Diplomacy.rel(P[i], P[j]))])
    # --- a war forced: fleets fight, war contracts appear, wartime prices
    G.rel[Diplomacy.pair("concord", "directorate")] = -90.0; Diplomacy.new_day()
    var war_offer := false
    for tries in 10:
        G.offers = {}
        for c in Diplomacy.offers(cr): if c.kind == "war": war_offer = true
    print("war: %s, war contract offered %s, munitions price x%.2f at Concord ports" % [Diplomacy.at_war("concord", "directorate"), war_offer, Diplomacy.price_mult("concord", "munitions")])
    # --- coalitions: a war between the Concord and the Directorate brings in allies
    G.wars = {}; G.cobell = {}
    G.rel[Diplomacy.pair("concord", "directorate")] = -90.0; Diplomacy.declare("concord", "directorate")
    print("coalition war: isles %s, ombria %s, pacific %s (cordial members join half the time)" % [Diplomacy.at_war("isles", "directorate"), Diplomacy.at_war("ombria", "concord"), Diplomacy.at_war("pacific", "directorate")])
    Diplomacy.armistice("concord", "directorate")
    print("armistice ends the allies' wars too: isles %s, ombria %s" % [Diplomacy.at_war("isles", "directorate"), Diplomacy.at_war("ombria", "concord")])
    # --- sieges: a port changes hands in a war
    G.rel[Diplomacy.pair("concord", "directorate")] = -90.0; Diplomacy.declare("concord", "directorate")
    var before := {}
    for p in G.ports: before[p.name] = p.fac
    for i in 6: Diplomacy._siege(Diplomacy.pair("concord", "directorate"))   # about a six-month war's worth
    var changed := []
    for p in G.ports: if before[p.name] != p.fac: changed.append("%s %s->%s" % [p.name, before[p.name], p.fac])
    print("after 6 siege rolls: ", changed)
    for p in G.ports: if p.capital and before[p.name] != p.fac: print("  ERROR: a capital fell: ", p.name)
    # --- escort: the convoy waits for you, then sails and arrives
    G.wars = {}; G.cobell = {}; G.contracts = []
    var esc = null
    for tries in 30:
        G.offers = {}
        for c in Diplomacy.offers(cr): if c.kind == "escort" and esc == null: esc = c
    if esc != null:
        Diplomacy.accept(esc); var cv = null
        for q in G.fleets: if int(q.get("escort", 0)) == int(esc.id): cv = q
        G.player.x = cv.x + 200.0; G.player.y = cv.y; for i in 30 * 20: Campaign.update(1.0 / 30.0)
        var waited := Campaign.mdist(cv.x, cv.y, cr.sx, cr.sy)
        var arrived := false
        for i in 30 * 10 * 120:
            G.player.x = cv.x; G.player.y = cv.y; G.player.cool = 9999.0; for f in G.fleets: f.cool = 9999.0
            Campaign.paused = false; Campaign.update(1.0 / 30.0)
            if not G.contracts.has(esc): arrived = true; break
            if not G.fleets.has(cv): break
        print("escort: convoy moved %.0f units while you were away; delivered %s, contracts left %d" % [waited, arrived, G.contracts.size()])
    # --- smuggling: into a closed harbour and an open one
    G.rep.directorate = -40; var sm = null
    for tries in 60:
        G.offers = {}
        for c in Diplomacy.offers(port.call("Port Saffron")): if c.kind == "smuggle" and sm == null: sm = c
    if sm != null:
        G.cargo[sm.good] = 0; Diplomacy.accept(sm); var dp: Dictionary = G.ports[int(sm.dest)]
        print("smuggle %s: risk %d%%, %s" % [sm.title, int(Diplomacy.smuggle_risk(dp) * 100), Diplomacy.run_contraband(sm, dp)])
    # --- story chains of every power: offices, and a mission accepted and completed
    for by in ["directorate", "pacific", "combine", "republic", "freeport", "enclave"]:
        G.mission = null; Campaign.accept_mission(by); var r := {"notes": []}; var m: Dictionary = Campaign.mission_def()
        Campaign._complete_mission(r); print("%s (%s): %s -> next %d of %d" % [by, Campaign.story_office(by), m.title, Campaign.story_idx(by), Campaign.story_chain(by).size()])
    G.rel[Diplomacy.pair("concord", "directorate")] = -90.0; Diplomacy.declare("concord", "directorate")
    Campaign.save(); var rel_before = Diplomacy.rel("concord", "directorate")
    print("save/load: %s, relation kept %s, wars kept %s" % [Campaign.load_game(), is_equal_approx(Diplomacy.rel("concord", "directorate"), rel_before), Diplomacy.at_war("concord", "directorate")])
    get_tree().quit()
