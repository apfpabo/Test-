extends Node
## Every campaign origin (with each navy where it has one): the start is valid (ships, port, crew, standing), and
## 20 days at sea show who comes after you. godot --headless --path godot res://tests/origins_test.tscn
func _ready() -> void:
    for key in Origins.LIST:
        for navy in (Origins.NAVIES if Origins.INFO[key].navy else ["-"]):
            Campaign.new_game(key, navy if navy != "-" else "concord")
            var G: Dictionary = Campaign.G; var P: Dictionary = G.player
            var hostile_ports: int = G.ports.filter(func(p): return Campaign.hostile(p.fac)).size()
            var start_port := ""
            for p in G.ports: if Campaign.mdist(p.sx, p.sy, P.x, P.y) < 1.0: start_port = p.name
            var hunted := {}; var met := []
            var on := func(f): met.append(f.name); Campaign.paused = false; f.cool = 30.0; Campaign.G.player.cool = 30.0
            Campaign.encounter.connect(on)
            Campaign.set_course(P, P.x + 200.0, P.y + 60.0)
            for i in 20 * 10 * 30:
                Campaign.update(1.0 / 30.0)
                if i % 600 == 0:
                    for f in G.fleets: if f.get("hunter", false): hunted[f.name] = true
                    if G.player.get("tx") == null: Campaign.set_course(P, P.x + randf_range(-150, 150), P.y + randf_range(-60, 60))
            Campaign.encounter.disconnect(on)
            var ships = G.fleet.map(func(s): return "%s %d%%" % [s.type, int(s.hullFrac * 100)])
            print("%-10s %-12s %-14s ships %s · %s cr · crew %d · RP %d · hostile ports %d · hunters seen %s · encounters %d" % [key, navy, start_port, ships, Campaign.fmt(G.credits), G.crew, G.rp, hostile_ports, hunted.keys(), met.size()])
    get_tree().quit()
