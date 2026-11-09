extends Node
## Headless campaign check: new game, sea routes across oceans and through straits, a month at sea with every fleet
## moving, a forced battle applied back to the campaign, and a save/load round trip.
func _ready() -> void:
    var t0 := Time.get_ticks_msec()
    Campaign.new_game("commission")
    print("new game: ", Time.get_ticks_msec() - t0, " ms (nav load happened at startup), fleets ", Campaign.G.fleets.size())
    var port := func(n): for p in Campaign.G.ports: if p.name == n: return p
    for pair in [["Calder Roads", "Wexmouth"], ["Calder Roads", "Kotaraya"], ["Strelsk", "Korvagrad"], ["Tavrosk", "Kesselport"], ["Port Saffron", "Puerto Vela"], ["Amakura", "Anvil Harbour"], ["Tarsa", "Port Merrow"]]:
        var a: Dictionary = port.call(pair[0]); var b: Dictionary = port.call(pair[1])
        var t1 := Time.get_ticks_msec(); var path := Campaign.find_path(Vector2(a.sx, a.sy), Vector2(b.sx, b.sy))
        var len := 0.0; var prev := Vector2(a.sx, a.sy); var bad := 0
        for q in path:
            len += Campaign.mdist(prev.x, prev.y, q.x, q.y)
            if not Campaign.sight_line(prev.x, prev.y, q.x, q.y): bad += 1
            prev = q
        print("%-12s -> %-12s %3d legs, %5.0f units (%4.1f days), %d legs over land, %d ms" % [pair[0], pair[1], path.size(), len, len / 12.0 * 0.1, bad, Time.get_ticks_msec() - t1])
    var P: Dictionary = Campaign.G.player
    Campaign.set_course(P, Campaign.lon_x(30), Campaign.lat_y(40))
    var met := []
    Campaign.encounter.connect(func(f): met.append(f.name); Campaign.paused = false; f.cool = 30.0; Campaign.G.player.cool = 30.0)
    t0 = Time.get_ticks_msec()
    for i in 30 * 10 * 30: Campaign.update(1.0 / 30.0)
    print("30 days at sea: ", Time.get_ticks_msec() - t0, " ms, day ", Campaign.G.day, ", fleets ", Campaign.G.fleets.size(), ", encounters ", met.size(), ", fuel ", int(Campaign.G.cargo.fuel), ", credits ", int(Campaign.G.credits))
    # a battle against the nearest raiders, fought headlessly
    var f: Dictionary = Campaign.spawn_fleet("raiders", "raiders")
    GameData.pending = Campaign.battle_setup(f)
    var sim := BattleSim.new(); sim.setup(GameData.pending.player_recs, GameData.pending.enemy_recs, [], [], 1); sim.flag = null
    while not sim.finished and sim.t < 7200: sim.step(0.02)
    var r := Campaign.apply_battle(sim)
    print("battle: victory ", r.victory, " sunk ", r.sunk.size(), " prizes ", r.prizes.size(), " lost ", r.lost.size(), " coin ", r.coin, " rp ", r.rp, " notes ", r.notes)
    Campaign.save(); var day: int = Campaign.G.day
    print("save/load: ", Campaign.load_game(), " day ", Campaign.G.day == day, " fleets ", Campaign.G.fleets.size())
    for i in 300: Campaign.update(1.0 / 30.0)
    print("after load ok, day ", Campaign.G.day)
    get_tree().quit()
