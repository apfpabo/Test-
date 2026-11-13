extends Node
## The globe overview: opened from the chart, turned, zoomed, a port under the pointer, and back down to the chart.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_globe.tscn -- <dir>
var map: Node
var f := 0
var out := ""
var bad := 0
func ok(c: bool, m: String) -> void:
    print(("ok   " if c else "FAIL ") + m)
    if not c: bad += 1
func _shot(n: String) -> void: get_viewport().get_texture().get_image().save_png("%s/globe_%s.png" % [out, n])
func _ready() -> void:
    out = OS.get_cmdline_user_args()[0]
    Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
    Campaign.new_game("commission")
    map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
func _process(_d: float) -> void:
    f += 1
    var g = map.globe
    if f == 5:
        Campaign.set_course(Campaign.G.player, Campaign.lon_x(25.0), Campaign.lat_y(45.0))
        Campaign.G.wars[Diplomacy.pair("concord", "directorate")] = int(Campaign.G.day) - 12   # a war to show
        for fl in Campaign.G.fleets.slice(0, 12): fl.vis = true
        map.zoom = map.ZOOM_MIN; map._zoom_at(1.0 / 1.12, Vector2(700, 430))
        ok(g.is_open(), "scrolling out past the chart's widest view opens the globe")
    if f == 40:
        _shot("open")
        var P = Campaign.G.player; var q = g.project(P.x, P.y); var back = g.unproject(Vector2(q.x, q.y))
        ok(q.z > 0.9 and back != null and Vector2(back).distance_to(Vector2(P.x, P.y)) < 2.0, "it opens on your squadron, and a point of the screen maps back to the same place on the chart")
        g.lon0 += 1.2; g.lat0 = -0.2
    if f == 44: _shot("turned"); g.k = 2.2; g.lon0 = g.lon_of(Campaign.G.ports[0].x); g.lat0 = g.lat_of(Campaign.G.ports[0].y)
    if f == 46:
        var p = Campaign.G.ports[0]; var q = g.project(p.x, p.y); g.hover = g._port_at(Vector2(q.x, q.y))
        ok(g.hover == p, "the port under the pointer is found")
    if f == 48: _shot("close"); g.k = 0.7; g.lat0 = 1.2
    if f == 51: _shot("north"); g.lat0 = -1.2
    if f == 54: _shot("south"); g.k = 2.2; g.lat0 = -1.35   # close over the south pole (the owner: the poles looked wrong)
    if f == 57:
        _shot("south_close"); g.k = 1.0; var p = Campaign.G.ports[3]; map._show_place(p.x, p.y)   # "Show" on the Locations tab, with the globe up
    if f == 85:
        var p = Campaign.G.ports[3]; var q = g.project(p.x, p.y)
        ok(g.visible and q.z > 0.97 and g.pin != null, "Show on the Locations tab turns the globe to the place and marks it (facing %.2f)" % q.z)
        _shot("show")
        # orders from the globe are the chart's own (the owner, 13 Nov 2026): a click on a harbour sets the same course
        var P: Dictionary = Campaign.G.player; P.route = null; P.destPort = null; P.tx = null
        map.order_at(Vector2(p.x, p.y), map.zoom)
        var want_port = P.destPort; var want_len: int = P.route.size() if P.get("route") != null else -1
        P.route = null; P.destPort = null; P.tx = null
        for down in [true, false]:
            var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = down; ev.position = Vector2(q.x, q.y); g._gui_input(ev)
        var got_len: int = P.route.size() if P.get("route") != null else -1
        ok(g.is_open() and want_port == p.id and P.destPort == p.id and got_len == want_len and got_len > 0, "a click on a harbour on the globe sets the course the chart would (%d legs, %d on the chart), and the globe stays up" % [got_len, want_len])
        var fl = null
        for x in Campaign.G.fleets:   # one at sea, on the side of the world that faces us, with no harbour beside her
            if x.fac == "player" or fl != null or g.project(x.x, x.y).z < 0.3: continue
            if Campaign.G.ports.all(func(pp): return Campaign.mdist(pp.x, pp.y, x.x, x.y) > 90.0): fl = x
        fl.vis = true; var fq = g.project(fl.x, fl.y)
        ok(map.fleet_at(Vector2(fl.x, fl.y), g.scale_at()) != null, "a fleet in sight can be picked at the globe's scale")
        P.route = null; P.destPort = null; P.follow = null
        if fq.z > 0.1:
            for down in [true, false]:
                var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = down; ev.position = Vector2(fq.x, fq.y); g._gui_input(ev)
            ok(P.get("follow") != null, "a click on a fleet on the globe locks an intercept, as on the chart")
        P.follow = null; Campaign.paused = true
        g.close(Vector2(p.x, p.y))
    if f == 120:
        var p = Campaign.G.ports[3]
        ok(not g.visible and map.free_cam and absf(Campaign.wdx(map.cam.x, p.x)) < 1.0 and absf(map.cam.y - p.y) < get_viewport().get_visible_rect().size.y / map.zoom * 0.5, "closing it puts the chart at the place chosen (the chart keeps its own top and bottom in view)")
        ok(map.overlay.visible and map.world.visible, "and the chart's own names and marks are back")
        _shot("chart")
        print("GLOBE TEST PASSED" if bad == 0 else "GLOBE TEST FAILED (%d)" % bad); get_tree().quit(0 if bad == 0 else 1)
