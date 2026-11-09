extends SceneTree
## Lists gun mounts whose turret footprint overlaps superstructure or a funnel in the design data.
func _init():
    var d0 = JSON.parse_string(FileAccess.open("res://data/game_data.json", FileAccess.READ).get_as_text())
    for id in d0.HULLS:
        var d = d0.HULLS[id]; var p = d.p
        for sl in d.slots:
            var w = d0.WEAPONS.get(sl.def)
            if w == null or w.kind != "gun": continue
            var r = maxf(w.tw * 0.55, w.tl * 0.5); var c = Vector2(sl.x, sl.y)
            for b in p.get("sup", []):
                var rect = Rect2(b[0] - b[1] / 2.0, -b[2] / 2.0, b[1], b[2])
                var q = Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
                if q.distance_to(c) < r: print("%-14s %-6s at (%5.1f,%5.1f) r%.1f overlaps sup [%s] by %.1f m" % [id, sl.def, sl.x, sl.y, r, ", ".join(b.map(func(v): return str(v))), r - q.distance_to(c)])
            for fu in p.get("fun", []):
                var fc = Vector2(fu[0], fu[3] if fu.size() > 3 else 0.0)
                if fc.distance_to(c) < r + fu[2]: print("%-14s %-6s at (%5.1f,%5.1f) overlaps funnel at %s" % [id, sl.def, sl.x, sl.y, str(fc)])
    quit()
