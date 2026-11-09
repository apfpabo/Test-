extends Node2D
## The chart: the world's oceans from real coastlines, ports, survey sites, pack ice and every fleet at sea. Shows the
## campaign and feeds it input; all rules live in campaign.gd.

const SANS := 13
var zoom = 0.9                 # screen pixels per map unit
var cam = Vector2.ZERO         # camera centre in map units
var free_cam = false
var drag = {}
var world: Node2D
var land_copies: Array = []
var marks: Node2D
var overlay: Control
var ui: Control
var top: HBoxContainer
var stats = {}
var speed_btns = []
var toasts: VBoxContainer
var dock: Button
var panel_layer: Control
var panel_open = false
var wakes: Array = []
var wake_t = 0.0
var tnow = 0.0
var land_tris: Array = []       # [PackedVector2Array] parts that triangulate
var coast_lines: Array = []     # PackedVector2Array per polygon, closed
var chan_lines: Array = []
var last_coast_zoom = -1.0

func _ready() -> void:
    RenderingServer.set_default_clear_color(Color("#0a171c"))
    _prepare_land()
    world = Node2D.new(); add_child(world)
    var sea = SeaDrawer.new(); sea.map = self; world.add_child(sea)
    for k in [-1, 0, 1]:
        var copy = LandCopy.new(); copy.map = self; copy.position.x = k * Campaign.MW; world.add_child(copy); land_copies.append(copy)
        # shallow-water glow along the coasts, with rounded joins so sharp headlands don't throw spikes
        for pl in coast_lines:
            for g in [[14.0, 0.09], [5.0, 0.14]]:
                var ln = Line2D.new(); ln.points = pl; ln.width = g[0]; ln.default_color = Color(0.5, 0.69, 0.75, g[1])
                ln.joint_mode = Line2D.LINE_JOINT_ROUND; ln.begin_cap_mode = Line2D.LINE_CAP_ROUND; ln.end_cap_mode = Line2D.LINE_CAP_ROUND
                ln.show_behind_parent = true; copy.add_child(ln)
    marks = Marks.new(); marks.map = self; world.add_child(marks)
    var cl = CanvasLayer.new(); cl.layer = 5; add_child(cl)
    ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.theme = UI.theme(); cl.add_child(ui)
    overlay = Overlay.new(); overlay.map = self; overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(overlay)
    _build_top(); _build_toasts()
    dock = UI.button("Dock", _on_dock, true); dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); dock.position = Vector2(-80, -60); dock.visible = false; ui.add_child(dock)
    dock.set_anchor_and_offset(SIDE_LEFT, 0.5, -90); dock.set_anchor_and_offset(SIDE_RIGHT, 0.5, 90); dock.set_anchor_and_offset(SIDE_TOP, 1.0, -64); dock.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -26)
    panel_layer = Control.new(); panel_layer.set_anchors_preset(Control.PRESET_FULL_RECT); panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(panel_layer)
    Campaign.toast.connect(_toast); Campaign.encounter.connect(_on_encounter); Campaign.reached_port.connect(open_port)
    cam = Vector2(Campaign.G.player.x, Campaign.G.player.y)
    if Campaign.show_aftermath: Campaign.show_aftermath = false; _show_aftermath(Campaign.last_result)
    else: Campaign.paused = false

func _prepare_land() -> void:
    for poly in Campaign.C.land:
        var pv = PackedVector2Array()
        for i in range(0, poly.size(), 2): pv.append(Vector2(poly[i], poly[i + 1]))
        var closed = pv.duplicate(); closed.append(pv[0]); coast_lines.append(closed)
        if not Geometry2D.triangulate_polygon(pv).is_empty(): land_tris.append(pv); continue
        for q in Geometry2D.offset_polygon(pv, 0.01): # repair self-touching outlines; parts that still fail (lakes) are skipped
            if not Geometry2D.triangulate_polygon(q).is_empty(): land_tris.append(q)
    for ch in Campaign.C.channels:
        var pv = PackedVector2Array()
        for q in ch: pv.append(Vector2(q[0], q[1]))
        chan_lines.append(pv)

func rx(x: float) -> float: return cam.x + Campaign.wdx(cam.x, x) # place a wrapped world x next to the camera
func to_screen(p: Vector2) -> Vector2: return (Vector2(rx(p.x), p.y) - cam) * zoom + get_viewport_rect().size / 2
func to_world(sp: Vector2) -> Vector2: return (sp - get_viewport_rect().size / 2) / zoom + cam
func boost() -> float: return pow(zoom, 0.75) if zoom > 1 else 1.0

# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
    var dt = minf(delta, 0.05); tnow += dt
    var G: Dictionary = Campaign.G
    if not panel_open:
        var pan = Vector2((1 if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) else 0) - (1 if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) else 0),
            (1 if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) else 0) - (1 if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) else 0))
        if pan != Vector2.ZERO: free_cam = true; cam += pan * 600 * dt / zoom
        if not Campaign.paused:
            for i in Campaign.map_speed:
                if panel_open or Campaign.paused: break
                Campaign.update(dt)
            _wakes(dt)
    if not free_cam: cam = Vector2(G.player.x, G.player.y)
    var vs = get_viewport_rect().size
    cam.x = Campaign.wrap_x(cam.x)
    cam.y = clampf(cam.y, vs.y / 2 / zoom - 40, Campaign.MH - vs.y / 2 / zoom + 40) if vs.y / zoom < Campaign.MH else Campaign.MH / 2
    world.scale = Vector2(zoom, zoom); world.position = vs / 2 - cam * zoom
    if absf(zoom - last_coast_zoom) / maxf(last_coast_zoom, 0.01) > 0.08:
        last_coast_zoom = zoom
        for c in land_copies: c.queue_redraw()
    marks.queue_redraw(); overlay.queue_redraw(); world.get_child(0).queue_redraw()
    _update_top(); _update_dock()

func _wakes(dt: float) -> void:
    wake_t -= dt
    if wake_t <= 0:
        wake_t = 0.07
        var G: Dictionary = Campaign.G; var vs = get_viewport_rect().size
        var add = func(o: Dictionary): if o.v > 0.8: wakes.append({"x": o.x - cos(o.h) * 0.6, "y": o.y - sin(o.h) * 0.6, "h": o.h, "t": 0.0, "s": minf(1.0, o.v / 16.0)})
        add.call(G.player)
        for f in G.fleets: if Campaign.mdist(f.x, f.y, G.player.x, G.player.y) < vs.x / zoom: add.call(f)
    for i in range(wakes.size() - 1, -1, -1):
        wakes[i].t += dt
        if wakes[i].t > 3: wakes.remove_at(i)

# ------------------------------------------------------------------ drawing
class SeaDrawer extends Node2D:   # open sea, graticule and pack ice
    var map
    func _draw() -> void:
        var z: float = map.zoom; var vs: Vector2 = map.get_viewport_rect().size; var cam: Vector2 = map.cam
        var hw = vs.x / 2 / z; var hh = vs.y / 2 / z
        draw_rect(Rect2(cam.x - hw, 0, hw * 2, Campaign.MH), Color("#183039"))
        var g0 = int(floor((cam.x - hw) / 200.0)) - 1; var g1 = int(ceil((cam.x + hw) / 200.0)) + 1
        for k in range(g0, g1 + 1): draw_line(Vector2(k * 200, 0), Vector2(k * 200, Campaign.MH), Color(0.5, 0.69, 0.86, 0.09), 1.0 / z)
        for lat in range(80, -71, -10): draw_line(Vector2(cam.x - hw, Campaign.lat_y(lat)), Vector2(cam.x + hw, Campaign.lat_y(lat)), Color(0.5, 0.69, 0.86, 0.09), 1.0 / z)
        var eq = Campaign.lat_y(0); var x = cam.x - hw
        while x < cam.x + hw: draw_line(Vector2(x, eq), Vector2(x + 10 / z, eq), Color(0.89, 0.7, 0.24, 0.18), 1.0 / z); x += 20 / z
        # seasonal pack ice
        var ie = Campaign.ice_edges(Campaign.G.day); var north = PackedVector2Array([Vector2(cam.x - hw - 40, 0)])
        var xx = cam.x - hw - 40
        while xx <= cam.x + hw + 40: north.append(Vector2(xx, Campaign.lat_y(Campaign.ice_north_at(Campaign.x_lon(xx), ie)))); xx += 20
        north.append(Vector2(cam.x + hw + 40, 0))
        var ice = Color(0.86, 0.91, 0.93, 0.32)
        draw_colored_polygon(north, ice)
        draw_rect(Rect2(cam.x - hw - 40, Campaign.lat_y(ie.y), hw * 2 + 80, Campaign.MH - Campaign.lat_y(ie.y)), ice)

class LandCopy extends Node2D:    # one copy of the world's land; three side by side make the chart wrap
    var map
    func _draw() -> void:
        var z: float = map.zoom
        for pv in map.land_tris: draw_colored_polygon(pv, Color("#c9bb93"))
        for pl in map.coast_lines: draw_polyline(pl, Color("#7e6e4a"), maxf(1.0 / z, 0.4))
        for pl in map.chan_lines: draw_polyline(pl, Color("#183039"), maxf(2.5, 1.6 / z))

class Marks extends Node2D:       # ports, sites, wakes, routes and fleets
    var map
    func _draw() -> void:
        var G: Dictionary = Campaign.G; var z: float = map.zoom; var P: Dictionary = G.player; var vs: Vector2 = map.get_viewport_rect().size
        var hw = vs.x / 2 / z; var b: float = map.boost()
        for p in G.pois:
            var x: float = map.rx(p.x)
            if absf(x - map.cam.x) > hw + 50: continue
            var ready: bool = G.day >= p.next; var s = 6.0 / z; var col = Color(0.89, 0.7, 0.24, 1.0 if ready else 0.35)
            draw_polyline(PackedVector2Array([Vector2(x, p.y - s), Vector2(x + s, p.y), Vector2(x, p.y + s), Vector2(x - s, p.y), Vector2(x, p.y - s)]), col, 1.5 / z)
            if p.type == "wreck": draw_line(Vector2(x - s * 0.5, p.y), Vector2(x + s * 0.5, p.y), col, 1.5 / z)
        for p in G.ports:
            var x: float = map.rx(p.x)
            if absf(x - map.cam.x) > hw + 80: continue
            var s = (7.0 if p.capital else 5.5) / z
            draw_line(Vector2(x, p.y), Vector2(map.rx(p.sx), p.sy), Color(0.89, 0.91, 0.89, 0.35), 1.0 / z)
            var col = Color(GameData.fac[p.fac].map)
            if p.capital: draw_rect(Rect2(x - s, p.y - s, s * 2, s * 2), Color("#ecebe2")); draw_rect(Rect2(x - s, p.y - s, s * 2, s * 2), col, false, 3.0 / z)
            else: draw_circle(Vector2(x, p.y), s, Color("#ecebe2")); draw_arc(Vector2(x, p.y), s, 0, TAU, 20, col, 3.0 / z)
        var zb = minf(b, 3.0)
        for w in map.wakes:
            var x: float = map.rx(w.x)
            if absf(x - map.cam.x) > hw + 20: continue
            var k: float = w.t / 3.0; var spread: float = (1.5 + w.t * 5) * zb; var n = Vector2(-sin(w.h), cos(w.h))
            var r = maxf(0.6, 1.1 * b / z * (1 - k * 0.5)); var c = Color(0.88, 0.94, 0.94, 0.45 * (1 - k) * w.s)
            draw_circle(Vector2(x, w.y) + n * spread, r, c); draw_circle(Vector2(x, w.y) - n * spread, r, c)
            draw_circle(Vector2(x, w.y), r * 1.6, Color(0.88, 0.94, 0.94, 0.18 * (1 - k) * w.s))
        # planned route
        if P.get("tx") != null and P.get("route") != null:
            var r: Array = P.route; var off: Vector2 = Vector2(P.x, P.y) - Vector2(P.rx, P.ry)
            var pts = PackedVector2Array([Vector2(P.x, P.y)])
            for i in range(P.ri + 1, r.size()): pts.append(r[i] + off)
            for i in pts.size() - 1: _dash(pts[i], pts[i + 1], Color(0.89, 0.91, 0.89, 0.6), 1.5 / z, 8 / z)
            draw_arc(pts[-1], 5 / z, 0, TAU, 16, Color(0.89, 0.91, 0.89, 0.6), 1.5 / z)
        # fleets
        for f in G.fleets:
            var x: float = map.rx(f.x)
            if absf(x - map.cam.x) > hw + 60: continue
            var col = Color("#e3b23c") if f.get("mission", false) else Color(GameData.fac[f.fac].map); var hos = Campaign.hostile(f.fac)
            if z < 0.32:
                draw_colored_polygon(PackedVector2Array([Vector2(x, f.y) + Vector2.from_angle(f.h) * 7 / z, Vector2(x, f.y) + Vector2.from_angle(f.h + 2.5) * 4 / z, Vector2(x, f.y) + Vector2.from_angle(f.h - 2.5) * 4 / z]), col)
                continue
            if f.get("chasing", false): draw_arc(Vector2(x, f.y), 160, 0, TAU, 64, Color(0.85, 0.38, 0.29, 0.28), 1.0 / z)
            if hos or f.get("mission", false) or P.follow == f.id: draw_arc(Vector2(x, f.y), 16 * b / z, 0, TAU, 32, Color(Color("#e3b23c") if P.follow == f.id else col, 0.7), 1.5 / z)
            _fleet(f.ships, f.fac, Vector2(x, f.y), f.h)
        draw_arc(Vector2(P.x, P.y), 17 * b / z, 0, TAU, 32, Color("#e3b23c"), 2.0 / z)
        if G.fleet.size(): _fleet(G.fleet, "player", Vector2(P.x, P.y), P.h)

    func _dash(a: Vector2, b: Vector2, c: Color, w: float, d: float) -> void:
        var len = a.distance_to(b); var n = int(len / (d * 2)) + 1
        for i in n:
            var t0 = i * 2 * d / len; var t1 = minf(1.0, (i * 2 + 1) * d / len)
            if t0 >= 1: break
            draw_line(a.lerp(b, t0), a.lerp(b, t1), c, w)

    ## Past 2x zoom every ship of a fleet is drawn, steaming in a staggered column behind the largest.
    func _fleet(ships: Array, pal: String, p: Vector2, h: float) -> void:
        var z: float = map.zoom; var b: float = map.boost()
        var sorted = ships.duplicate(); sorted.sort_custom(func(a, c): return GameData.hulls[a.type].L > GameData.hulls[c.type].L)
        var n = sorted.size() if z >= 2 else 1; var back = 0.0
        for k in n:
            var s: Dictionary = sorted[k]; var L: float = GameData.hulls[s.type].L
            var sc = (22 + L * 0.07) * b / (L * z) * (0.9 if k else 1.0); var len = L * sc
            if k: back += len * 1.35
            var side = ((1 if k % 2 else -1) * len * 0.35) if k else 0.0
            var q = p - Vector2.from_angle(h) * back + Vector2(-sin(h), cos(h)) * side
            var info: Dictionary = GameData.sprites.ships[s.type]
            draw_set_transform(q, h, Vector2.ONE * sc / info.spr)
            for layer in ["base", "top"]:
                var t = GameData.ship_tex(s.type, pal, layer); draw_texture(t, -t.get_size() / 2)
        draw_set_transform(Vector2.ZERO)

class Overlay extends Control:    # text on the chart, at fixed pixel sizes
    var map
    func _t(p: Vector2, s: String, col: Color, size := 13, align := HORIZONTAL_ALIGNMENT_CENTER, w := 300.0) -> void:
        var x = p.x - (w / 2 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
        draw_string(ThemeDB.fallback_font, Vector2(x, p.y), s, align, w, size, col)
    func _draw() -> void:
        var G: Dictionary = Campaign.G; var z: float = map.zoom; var vs = size; var P: Dictionary = G.player; var b: float = map.boost()
        # graticule labels
        var hw = vs.x / 2 / z; var g0 = int(floor((map.cam.x - hw) / 200.0)) - 1; var g1 = int(ceil((map.cam.x + hw) / 200.0)) + 1
        for k in range(g0, g1 + 1):
            if z < 0.3 and k % 2: continue
            var lon = int(round(Campaign.x_lon(k * 200))); var sx: float = (k * 200 - map.cam.x) * z + vs.x / 2
            _t(Vector2(sx + 4, 58), "%d°%s" % [absi(lon), "W" if lon < 0 else ("E" if lon > 0 else "")], Color(0.5, 0.69, 0.86, 0.5), 11, HORIZONTAL_ALIGNMENT_LEFT, 60)
        for lat in range(80, -71, -10):
            var sy: float = (Campaign.lat_y(lat) - map.cam.y) * z + vs.y / 2
            _t(Vector2(6, sy + 14), "%d°%s" % [absi(lat), "N" if lat > 0 else ("S" if lat < 0 else "")], Color(0.5, 0.69, 0.86, 0.5), 11, HORIZONTAL_ALIGNMENT_LEFT, 60)
        if z < 1.6:
            for th in Campaign.C.THEATERS:
                var sp: Vector2 = map.to_screen(Vector2(Campaign.lon_x(th[1]), Campaign.lat_y(th[2])))
                _t(sp, " ".join(th[0].split("")), Color(0.78, 0.88, 0.92, 0.24 if z < 0.35 else 0.16), 15 if z < 0.35 else 19, HORIZONTAL_ALIGNMENT_CENTER, 600)
        for p in G.pois:
            if z <= 0.45: break
            var sp: Vector2 = map.to_screen(Vector2(p.x, p.y))
            if sp.x < -100 or sp.x > vs.x + 100: continue
            _t(sp + Vector2(0, 20), p.name, Color(0.89, 0.7, 0.24, 0.9 if G.day >= p.next else 0.4), 11)
        for p in G.ports:
            if not (z > 0.28 or p.capital): continue
            var sp: Vector2 = map.to_screen(Vector2(p.x, p.y))
            if sp.x < -150 or sp.x > vs.x + 150: continue
            var s = 7.0 if p.capital else 5.5; var closed = Campaign.hostile(p.fac)
            _t(sp - Vector2(0, s + 5), p.name, Color("#eef0ec"), 15 if p.capital else 13)
            if z > 0.45: _t(sp + Vector2(0, s + 15), GameData.fac[p.fac].short + (" · capital" if p.capital else "") + (" · hostile" if closed else ""), Color("#d9614a") if closed else Color(GameData.fac[p.fac].map), 11)
        for f in G.fleets:
            var hos = Campaign.hostile(f.fac)
            if not (z >= 0.6 or hos or f.get("mission", false) or f.kind == "bounty"): continue
            var sp: Vector2 = map.to_screen(Vector2(f.x, f.y))
            if sp.x < -150 or sp.x > vs.x + 150 or z < 0.32: continue
            var col = Color("#e3b23c") if f.get("mission", false) else Color(GameData.fac[f.fac].map)
            var txt: String = (f.captain + " · " + Campaign.fmt(f.reward)) if f.kind == "bounty" else (f.name + " (%d)" % f.ships.size())
            _t(sp + Vector2(0, 18 * b + 12), ("◎ " if P.follow == f.id else "") + txt, col, 12)
        var psp: Vector2 = map.to_screen(Vector2(P.x, P.y))
        _t(psp + Vector2(0, 21 * b + 13), "Your task force · %d kn" % int(round(P.v / 0.8)), Color("#e3b23c"), 12)
        if P.get("tx") != null and P.get("route") != null:
            var end: Vector2 = P.route[-1] + Vector2(P.x, P.y) - Vector2(P.rx, P.ry)
            var days: float = Campaign.route_remaining(P) / maxf(0.5, Campaign.fleet_map_speed(G.fleet)) * 0.1
            _t(map.to_screen(end) + Vector2(0, 20), "under a day" if days < 1 else "≈ %d days" % int(ceil(days)), Color(0.89, 0.91, 0.89, 0.75), 11)
        var mp: Vector2 = map.to_world(get_local_mouse_position())
        _t(Vector2(vs.x - 160, vs.y - 14), "%.1f°%s %.1f°%s" % [absf(Campaign.y_lat(mp.y)), "N" if Campaign.y_lat(mp.y) >= 0 else "S", absf(Campaign.x_lon(mp.x)), "E" if Campaign.x_lon(mp.x) >= 0 else "W"], Color(0.62, 0.67, 0.67), 12, HORIZONTAL_ALIGNMENT_RIGHT, 150)

# ------------------------------------------------------------------ top bar, toasts, dock
func _build_top() -> void:
    var bg = PanelContainer.new(); bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
    var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.04, 0.09, 0.11, 0.85); sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 6; sb.content_margin_bottom = 6
    bg.add_theme_stylebox_override("panel", sb); ui.add_child(bg)
    top = HBoxContainer.new(); top.add_theme_constant_override("separation", 18); bg.add_child(top)
    for k in ["DATE", "FUNDS", "FUEL", "CREW", "HOLD", "RESEARCH"]:
        var box = HBoxContainer.new(); box.add_theme_constant_override("separation", 6)
        box.add_child(UI.label(k, UI.DIM, 11)); var v = UI.label("", UI.INK, 14); box.add_child(v); stats[k] = v; top.add_child(box)
    var spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer)
    for pair in [[0, "❚❚"], [1, "1×"], [2, "2×"], [4, "4×"], [8, "8×"]]:
        var v: int = pair[0]
        var b = UI.button(pair[1], func(): _speed(v)); b.custom_minimum_size.x = 38; top.add_child(b); speed_btns.append([v, b])
    top.add_child(UI.button("Centre", func(): free_cam = false))
    top.add_child(UI.button("Command", func(): show_command()))
    top.add_child(UI.button("Sound", func(): Sfx.muted = not Sfx.muted))

func _speed(v: int) -> void:
    if v == 0: Campaign.paused = not Campaign.paused
    else: Campaign.map_speed = v; Campaign.paused = false

func _update_top() -> void:
    var G: Dictionary = Campaign.G
    stats.DATE.text = Campaign.date_str(G.day); stats.FUNDS.text = Campaign.fmt(G.credits)
    var fu = Campaign.fuel_use(); stats.FUEL.text = "%d (%s)" % [int(G.cargo.fuel), ("%dd" % int(G.cargo.fuel / fu)) if fu > 0 else "∞"]
    stats.FUEL.add_theme_color_override("font_color", UI.RED if fu > 0 and G.cargo.fuel / fu < 5 else UI.INK)
    stats.CREW.text = "%d/%d" % [G.crew, Campaign.crew_need()]; stats.HOLD.text = "%d/%d" % [Campaign.cargo_used(), Campaign.cargo_cap()]; stats.RESEARCH.text = "%d RP" % G.rp
    for pair in speed_btns:
        var on: bool = (pair[0] == 0 and Campaign.paused) or (pair[0] == Campaign.map_speed and not Campaign.paused)
        pair[1].modulate = UI.GOLD if on else Color.WHITE

func _build_toasts() -> void:
    toasts = VBoxContainer.new(); toasts.add_theme_constant_override("separation", 6); ui.add_child(toasts)
    toasts.set_anchor_and_offset(SIDE_LEFT, 0, 14); toasts.set_anchor_and_offset(SIDE_RIGHT, 0, 460); toasts.set_anchor_and_offset(SIDE_TOP, 1, -300); toasts.set_anchor_and_offset(SIDE_BOTTOM, 1, -14)
    toasts.alignment = BoxContainer.ALIGNMENT_END; toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _toast(text: String) -> void:
    var pc = PanelContainer.new(); var sb = StyleBoxFlat.new(); sb.bg_color = Color(0.086, 0.149, 0.172, 0.94); sb.border_color = UI.GOLD; sb.border_width_left = 3
    sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 7; sb.content_margin_bottom = 7; pc.add_theme_stylebox_override("panel", sb)
    var l = UI.label(text, UI.INK, 14, true); l.custom_minimum_size.x = 420; pc.add_child(l); pc.mouse_filter = Control.MOUSE_FILTER_IGNORE; toasts.add_child(pc)
    while toasts.get_child_count() > 5: toasts.get_child(0).queue_free(); toasts.remove_child(toasts.get_child(0))
    get_tree().create_timer(6.5).timeout.connect(func(): if is_instance_valid(pc): pc.queue_free())

func _update_dock() -> void:
    if panel_open: dock.visible = false; return
    var np = Campaign.nearest_port(28.0); var poi = null if np != null else Campaign.nearest_poi(22.0)
    dock.visible = np != null or poi != null
    if np != null: dock.text = "Dock at " + np.name; dock.set_meta("port", np.id); dock.set_meta("poi", -1)
    elif poi != null: dock.text = "Survey " + poi.name; dock.set_meta("poi", poi.id); dock.set_meta("port", -1)

func _on_dock() -> void:
    if dock.get_meta("port", -1) >= 0: open_port(Campaign.G.ports[dock.get_meta("port")])
    elif dock.get_meta("poi", -1) >= 0: open_survey(Campaign.G.pois[dock.get_meta("poi")])

# ------------------------------------------------------------------ input
func _unhandled_input(e: InputEvent) -> void:
    if panel_open:
        if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and not _blocking: close_panel()
        return
    if e is InputEventMouseButton:
        var mb = e as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed: _zoom_at(1.12, mb.position)
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed: _zoom_at(1 / 1.12, mb.position)
        elif mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed: drag = {"at": mb.position, "cam": cam, "moved": false}
            else:
                if not drag.is_empty() and not drag.moved: _click(mb.position)
                drag = {}
    elif e is InputEventMouseMotion and not drag.is_empty():
        var d: Vector2 = e.position - drag.at
        if not drag.moved and d.length() < 6: return
        drag.moved = true; free_cam = true; cam = drag.cam - d / zoom
    elif e is InputEventKey and e.pressed and not e.echo:
        match e.keycode:
            KEY_SPACE: Campaign.paused = not Campaign.paused
            KEY_1: _speed(1)
            KEY_2: _speed(2)
            KEY_3: _speed(4)
            KEY_4: _speed(8)
            KEY_C, KEY_HOME: free_cam = false
            KEY_EQUAL, KEY_KP_ADD: zoom = clampf(zoom * 1.25, 0.14, 14)
            KEY_MINUS, KEY_KP_SUBTRACT: zoom = clampf(zoom / 1.25, 0.14, 14)

func _zoom_at(f: float, sp: Vector2) -> void:
    var before = to_world(sp); zoom = clampf(zoom * f, 0.14, 14)
    if free_cam: cam += before - to_world(sp)

func _click(sp: Vector2) -> void:
    var G: Dictionary = Campaign.G; var P: Dictionary = G.player; var w = to_world(sp); w.x = Campaign.wrap_x(w.x)
    var near = func(x: float, y: float, r: float) -> bool: return Campaign.mdist(x, y, w.x, w.y) < r / minf(zoom, 1.5)
    P.destPort = null; P.follow = null; Campaign.paused = false
    for f in G.fleets:
        if near.call(f.x, f.y, 16 * boost()): P.follow = f.id; P.repathT = 0.0; f.cool = 0.0; _toast("Intercept course locked on the " + f.name.to_lower() + ". You will close and make contact."); return
    for p in G.ports:
        if near.call(p.x, p.y, 14) or near.call(p.sx, p.sy, 10):
            if Campaign.mdist(p.sx, p.sy, P.x, P.y) < 28: open_port(p); return
            P.destPort = p.id
            if not Campaign.set_course(P, p.sx, p.sy): P.tx = null; _toast("No sea route to " + p.name + ".")
            return
    for q in G.pois:
        if near.call(q.x, q.y, 12):
            if Campaign.mdist(q.x, q.y, P.x, P.y) < 22: open_survey(q); return
            Campaign.set_course(P, q.x, q.y); return
    if Campaign.on_land(w.x, w.y): _toast("That is land. Pick a point on the water."); return
    if not Campaign.set_course(P, w.x, clampf(w.y, 4, Campaign.MH - 4)): P.tx = null; _toast("No sea route to that point.")

# ------------------------------------------------------------------ panels
var _blocking = false   # a panel that must be answered (an encounter or an aftermath)
var cur_panel: Control

func open_panel(build: Callable, blocking := false, width := 760.0) -> VBoxContainer:
    close_panel(); panel_open = true; _blocking = blocking; Campaign.paused = true
    var shade = ColorRect.new(); shade.color = Color(0.016, 0.047, 0.063, 0.6); shade.set_anchors_preset(Control.PRESET_FULL_RECT); panel_layer.add_child(shade); shade.mouse_filter = Control.MOUSE_FILTER_STOP
    var center = CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); shade.add_child(center)
    var pc = PanelContainer.new(); pc.custom_minimum_size = Vector2(width, 0); center.add_child(pc)
    var scroll = ScrollContainer.new(); scroll.custom_minimum_size = Vector2(width - 44, 0); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; pc.add_child(scroll)
    var box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); scroll.add_child(box)
    cur_panel = shade
    build.call(box)
    _fit_panel.call_deferred(scroll, box)
    return box

## Panels grow with their contents up to the screen height, then scroll.
func _fit_panel(scroll: ScrollContainer, box: Control) -> void:
    if not is_instance_valid(scroll): return
    scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y + 4, get_viewport_rect().size.y - 140)

func close_panel() -> void:
    for c in panel_layer.get_children(): c.queue_free()
    panel_open = false; _blocking = false; Campaign.paused = false

func _p(box: Control, text: String, col := UI.INK, size := 15) -> void:
    var l = UI.label(text, col, size, true); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(l)

func _counts(ships: Array) -> String:
    var counts = {}; var order = []
    for s in ships:
        var h: Dictionary = GameData.hulls[s.type]; var k: String = h.dn + "-class " + h.name.to_lower()
        if not counts.has(k): counts[k] = 0; order.append(k)
        counts[k] += 1
    return ", ".join(order.map(func(k): return "%d× %s" % [counts[k], k]))

func _on_encounter(f: Dictionary) -> void:
    var G: Dictionary = Campaign.G; var P: Dictionary = G.player; P.tx = null; P.route = null; P.follow = null
    var ratio = Campaign.strength(f.ships) / maxf(1.0, Campaign.strength(G.fleet))
    var odds = "They badly outgun you." if ratio > 1.6 else ("They have the heavier squadron." if ratio > 1.1 else ("It would be an even fight." if ratio > 0.75 else "You outgun them."))
    var evade = int(round(clampf(0.4 + (Campaign.fleet_map_speed(G.fleet) - Campaign.fleet_map_speed(f.ships)) / 40.0, 0.1, 0.9) * 100))
    open_panel(func(box):
        if not Campaign.hostile(f.fac):
            var en = Campaign.enemies_of(f.fac)
            box.add_child(UI.title(f.name)); box.add_child(_lead_pic(f)); _p(box, "%s ships close to signalling distance: %s." % [GameData.fac[f.fac].name, _counts(f.ships)])
            _p(box, odds + " Attacking costs 30 %s standing%s." % [GameData.fac[f.fac].short, (" and earns thanks from " + " and ".join(en.map(func(e): return GameData.fac[e].short))) if en.size() else ""], UI.DIM)
            box.add_child(UI.row([UI.button("Exchange signals and pass", func(): f.cool = 8.0; P.cool = 3.0; close_panel(), true),
                UI.button("Open fire", func():
                    G.rep[f.fac] -= 30
                    for e in en: G.rep[e] = mini(100, G.rep[e] + 5)
                    _toast("%s standing is now %d." % [GameData.fac[f.fac].name, G.rep[f.fac]]); _battle(f))]))
        else:
            var who: String = ("Your mission target, " + f.name + ",") if f.get("mission", false) else (("%s's squadron, worth %s," % [f.captain, Campaign.fmt(f.reward)]) if f.kind == "bounty" else "A " + GameData.fac[f.fac].name + " force")
            box.add_child(UI.title("Contact")); box.add_child(_lead_pic(f)); _p(box, "%s is closing on you: %s." % [who, _counts(f.ships)]); _p(box, odds, UI.DIM)
            box.add_child(UI.row([UI.button("Action stations", func(): _battle(f), true),
                UI.button("Break off (%d%%)" % evade, func():
                    if randf() * 100 < evade: f.cool = 7.0; P.cool = 4.0; close_panel(); _toast("You turn away under a smoke screen and open the range.")
                    else: open_panel(func(b2): b2.add_child(UI.title("No escape")); _p(b2, "Their lookouts have you, and they hold the faster ships. You will have to fight."); b2.add_child(UI.button("Action stations", func(): _battle(f), true)), true))]))
    , true)

func _battle(f: Dictionary) -> void:
    GameData.pending = Campaign.battle_setup(f)
    Campaign.paused = true
    get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _show_aftermath(r: Dictionary) -> void:
    if Campaign.G.fleet.is_empty():
        open_panel(func(box):
            box.add_child(UI.title("Struck from the list")); _p(box, "Your last ship went down with her colours flying.")
            _p(box, "You lasted %d days, until %d, and sank or captured %d ships." % [Campaign.G.day, Campaign.year(), Campaign.G.kills], UI.DIM)
            DirAccess.remove_absolute(Campaign.SAVE_PATH)
            box.add_child(UI.button("New campaign", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), true)), true)
        return
    open_panel(func(box):
        box.add_child(UI.title("Victory" if r.victory else ("Disengaged" if r.retreated else "Defeat")))
        var nm = func(list): return ", ".join(list.map(func(s): return "%s (%s)" % [s.name, GameData.hulls[s.type].name]))
        if r.sunk.size(): _p(box, "Sunk: " + nm.call(r.sunk))
        if r.lost.size(): _p(box, "Lost: " + nm.call(r.lost), Color(0.95, 0.75, 0.71))
        if r.casualties: _p(box, "%s sailors killed or wounded." % Campaign.fmt(r.casualties), UI.DIM)
        if r.coin: _p(box, "Prize money: %s%s." % [Campaign.fmt(r.coin), (", plus " + r.goods) if r.goods != "" else ""])
        if r.rp: _p(box, "Research: +%d RP from salvaged equipment and documents." % r.rp)
        if r.bounty: _p(box, "Bounty paid: %s." % Campaign.fmt(r.bounty))
        for n in r.notes: _p(box, n, UI.GOLD)
        if r.prizes.size():
            box.add_child(UI.label("PRIZES", UI.DIM, 12)); _p(box, "These ships struck their colours. Each prize takes a fleet slot and needs crew. It comes in at its current condition with its weapons intact.", UI.DIM)
            for s in r.prizes:
                var h: Dictionary = GameData.hulls[s.type]
                if s.get("taken", "") != "": _p(box, "%s · %s · %s" % [s.name, h.name, s.taken], UI.GREEN); continue
                box.add_child(UI.row([UI.label("%s · %s · %d%% · needs %d crew" % [s.name, h.name, int(s.hullFrac * 100), h.crew]),
                    UI.button("Take as prize", func(): _take_prize(s), true, Campaign.G.fleet.size() >= 10),
                    UI.button("Scuttle for " + Campaign.fmt(Campaign.ship_value(s) * 0.1), func(): s.taken = "Scuttled"; Campaign.G.credits += round(Campaign.ship_value(s) * 0.1); _show_aftermath(r))]))
        box.add_child(UI.button("Return to the chart", func(): _aftermath_done(r), true))
    , true)

func _take_prize(s: Dictionary) -> void:
    var G: Dictionary = Campaign.G; var r: Dictionary = Campaign.last_result
    s.taken = "Taken"; var ns = s.duplicate(true); ns.erase("taken"); ns.pal = "player"; ns.id = str(randi()); G.fleet.append(ns); G.kills += 1
    _toast("%s sails under your flag. She needs %d crew." % [s.name, GameData.hulls[s.type].crew])
    if G.mission != null:
        var m: Dictionary = Campaign.C.STORY[G.mission.idx]
        if m.goal == "capture" and s.name == m.target: Campaign._complete_mission(r)
    _show_aftermath(r)

func _aftermath_done(r: Dictionary) -> void:
    var G: Dictionary = Campaign.G
    if G.mission != null:
        var m: Dictionary = Campaign.C.STORY[G.mission.idx]
        if m.goal == "capture" and r.prizes.any(func(s): return s.name == m.target and s.get("taken", "") != "Taken"):
            _toast("Without the %s the codebook is lost. Return to the Admiralty for new orders." % m.target); G.mission = null; Campaign.log_ev("Mission failed: " + m.title)
    G.player.cool = 4.0; Campaign.save(); close_panel()

func open_survey(q: Dictionary) -> void:
    open_panel(func(box):
        box.add_child(UI.title("Survey: " + q.name)); _p(box, Campaign.C.POI_TEXT[q.type])
        box.add_child(UI.row([UI.button("Send the divers down", func(): _do_survey(q), true, Campaign.G.day < q.next), UI.button("Leave", close_panel)])))

func _do_survey(q: Dictionary) -> void:
    var out = Campaign.do_survey(q)
    open_panel(func(box):
        box.add_child(UI.title("Survey: " + q.name))
        for l in out.lines: _p(box, l)
        if out.ambush != null: box.add_child(UI.button("Action stations", func(): _battle(out.ambush), true))
        else: box.add_child(UI.button("Return to the chart", close_panel, true))
    , out.ambush != null)

func _fleet_table(box: Control, at_port: bool) -> void:
    var G: Dictionary = Campaign.G; var need = Campaign.crew_need(); var short = maxi(0, need - int(G.crew))
    _p(box, "The first ship listed is your flagship. Crew %s of %s needed%s. Wages %s a day." % [Campaign.fmt(G.crew), Campaign.fmt(need), ", so undermanned ships reload and steam slower" if short else "", Campaign.fmt(Campaign.wages())], UI.DIM, 14)
    for i in G.fleet.size():
        var s: Dictionary = G.fleet[i]; var h: Dictionary = GameData.hulls[s.type]; var o = Campaign.officer_of(s)
        var items = [UI.label(("★ " if i == 0 else "") + s.name, UI.INK), UI.label("%s · %s class (%s)" % [h.name, h.dn, GameData.makers[h.yard].short], UI.DIM, 13), UI.bar(s.hullFrac), UI.label("%d%%" % int(s.hullFrac * 100), UI.DIM, 13),
            _captain_pick(s)]
        if at_port:
            var rc = repair_cost(s)
            items.append(UI.button("Repair " + Campaign.fmt(rc), func(): G.credits -= rc; s.hullFrac = 1.0; _rerender(), false, rc == 0 or G.credits < rc))
            items.append(UI.button("Sell " + Campaign.fmt(sell_value(s)), func(): _sell_ship(s), false, G.fleet.size() < 2))
        if i: items.append(UI.button("Flagship", func(): G.fleet.erase(s); G.fleet.push_front(s); _rerender()))
        box.add_child(UI.row(items))

# ------------------------------------------------------------------ ports (market and repairs for now)
var cur_port: Dictionary = {}
var port_tab = "market"
func repair_cost(s: Dictionary) -> int: return int(ceil((1 - s.hullFrac) * GameData.hulls[s.type].price * 0.2))
func sell_value(s: Dictionary) -> int: return int(floor(Campaign.ship_value(s) * 0.45 * (0.4 + 0.6 * s.hullFrac)))
func port_price(p: Dictionary, gid: String) -> int:
    var base = 1.0
    for g in Campaign.C.GOODS: if g.id == gid: base = g.base
    return maxi(1, int(round(base * p.mod[gid] * (1 + p.drift[gid]))))
func buy_price(p: Dictionary, gid: String) -> int: return int(ceil(port_price(p, gid) * 1.06 * (1.1 if Campaign.G.rep.get(p.fac, 0) < 0 else 1.0)))
func sell_price(p: Dictionary, gid: String) -> int: return int(floor(port_price(p, gid) * 0.93))

func open_port(p: Dictionary) -> void:
    if not Campaign.hostile(p.fac) and Campaign.G.day - p.get("offDay", -99) > 20: # the officers' mess turns over every few weeks
        p.offDay = Campaign.G.day; p.officers = [Campaign.new_officer(randi_range(1, 2)), Campaign.new_officer(randi_range(1, 3))]
        if randf() < 0.4: p.officers.append(Campaign.new_officer(randi_range(2, 4)))
    if Campaign.hostile(p.fac):
        open_panel(func(box): box.add_child(UI.title(p.name)); _p(box, "Shore batteries track your ships as you close the harbour. %s ports are closed to you while you are at war with them. Raise your standing, or dock somewhere friendlier." % GameData.fac[p.fac].name); box.add_child(UI.button("Stand off", close_panel, true)))
        return
    cur_port = p; port_tab = "market"; _render_port(); Campaign.save()

func _rerender() -> void:
    if not cur_port.is_empty(): _render_port()
    else: show_command()

func _market(box: Control, p: Dictionary) -> void:
    var G: Dictionary = Campaign.G; var free = Campaign.cargo_cap() - Campaign.cargo_used()
    _p(box, "Hold %d / %d · Funds %s · Fleet burns %.1f fuel a day underway" % [Campaign.cargo_used(), Campaign.cargo_cap(), Campaign.fmt(G.credits), Campaign.fuel_use()], UI.DIM, 14)
    for g in Campaign.C.GOODS:
        var gid: String = g.id; var m: float = p.mod[gid] * (1 + p.drift[gid])
        var tag = " · surplus" if m < 0.75 else (" · shortage" if m > 1.3 else "")
        var bp = buy_price(p, gid); var sp = sell_price(p, gid); var held = int(floor(G.cargo[gid]))
        var can: bool = G.credits >= bp and (free >= 1 or gid == "fuel")
        var nm = UI.label(g.name + tag, UI.GREEN if m < 0.75 else (UI.RED if m > 1.3 else UI.INK)); nm.custom_minimum_size.x = 200
        box.add_child(UI.row([nm, UI.label("buy %d · sell %d · held %d" % [bp, sp, held], UI.DIM, 13),
            UI.button("Buy 10", func(): _buy(p, gid, 10), false, not can), UI.button("Max", func(): _buy(p, gid, -1), false, not can),
            UI.button("Sell 10", func(): _sell(p, gid, 10), false, held < 1), UI.button("Sell all", func(): _sell(p, gid, -1), false, held < 1)]))
    _p(box, "Your own trading moves local prices. Buying drives them up, selling drives them down.", UI.DIM, 13)

func _buy(p: Dictionary, gid: String, n: int) -> void:
    var G: Dictionary = Campaign.G; var bp = buy_price(p, gid)
    var free: int = (maxi(0, int(ceil(Campaign.fuel_use() * 40 - G.cargo.fuel))) if n < 0 else 9999) if gid == "fuel" else Campaign.cargo_cap() - Campaign.cargo_used()
    var k = mini(free, int(G.credits / bp)) if n < 0 else mini(mini(n, free), int(G.credits / bp))
    if k > 0: G.credits -= k * bp; G.cargo[gid] += k; p.drift[gid] = minf(0.6, p.drift[gid] + k * 0.003)
    _render_port()

func _sell(p: Dictionary, gid: String, n: int) -> void:
    var G: Dictionary = Campaign.G; var held = int(floor(G.cargo[gid])); var k = held if n < 0 else mini(n, held); var got = 0
    for i in k: got += sell_price(p, gid); p.drift[gid] = maxf(-0.5, p.drift[gid] - 0.003)
    G.credits += got; G.cargo[gid] -= k; _render_port()

func _sell_ship(s: Dictionary) -> void:
    var G: Dictionary = Campaign.G
    G.credits += sell_value(s); G.fleet.erase(s)
    for o in G.officers:
        if o.ship == s.id: o.ship = null
    _rerender()

func _repair_all(total: int) -> void:
    var G: Dictionary = Campaign.G
    G.credits -= total
    for s in G.fleet: s.hullFrac = 1.0
    _render_port()

# ------------------------------------------------------------------ port and command panels
var cmd_tab = "fleet"
var refit_idx = 0

func _tabs(box: Control, tabs: Array, cur: String, cb: Callable) -> void:
    var tr = HBoxContainer.new(); tr.add_theme_constant_override("separation", 2)
    for t in tabs:
        var key: String = t[0]
        tr.add_child(UI.button(t[1], func(): cb.call(key), key == cur))
    box.add_child(tr)

func _render_port() -> void:
    var p = cur_port; var G: Dictionary = Campaign.G
    var tabs = [["market", "Market"], ["yard", "Shipyard"], ["refit", "Refit"], ["fleet", "Repairs & crew"], ["officers", "Officers"]]
    if p.capital and p.fac == "concord": tabs.append_array([["admiralty", "Admiralty"], ["research", "Research"]])
    elif p.fac == "enclave": tabs.append(["research", "Research exchange"])
    open_panel(func(box):
        box.add_child(UI.title(p.name))
        _p(box, "%s%s · %d, day %d · Funds %s" % [GameData.fac[p.fac].name, " · capital" if p.capital else "", Campaign.year(), G.day, Campaign.fmt(G.credits)], UI.DIM, 14)
        _tabs(box, tabs, port_tab, func(k): port_tab = k; _render_port())
        match port_tab:
            "market": _market(box, p)
            "yard": _yard(box, p)
            "refit": _refit(box)
            "fleet": _repairs(box)
            "officers": _officers(box, p)
            "admiralty": _missions(box, true)
            "research": _research(box)
        box.add_child(UI.button("Put to sea", func(): cur_port = {}; G.player.cool = maxf(G.player.cool, 2.5); Campaign.save(); close_panel(), true))
    , false, 960)

func show_command() -> void:
    cur_port = {}
    open_panel(func(box):
        box.add_child(UI.title("Command"))
        _tabs(box, [["fleet", "Fleet"], ["officers", "Officers"], ["research", "Research"], ["missions", "Missions & standing"], ["hold", "Hold"]], cmd_tab, func(k): cmd_tab = k; show_command())
        match cmd_tab:
            "fleet": _fleet_table(box, false)
            "officers": _officers(box, {})
            "research": _research(box)
            "missions": _missions(box, false)
            "hold":
                for g in Campaign.C.GOODS: box.add_child(UI.row([UI.label(g.name), UI.label(str(int(floor(Campaign.G.cargo[g.id]))), UI.DIM)]))
                _p(box, "%d / %d used. %d enemy ships sunk or taken." % [Campaign.cargo_used(), Campaign.cargo_cap(), Campaign.G.kills], UI.DIM, 14)
        box.add_child(UI.row([UI.button("Close", close_panel, true), UI.button("Save & exit to title", func(): Campaign.save(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))]))
    , false, 960)

func _repairs(box: Control) -> void:
    var G: Dictionary = Campaign.G
    _fleet_table(box, true)
    var total = 0
    for s in G.fleet: total += repair_cost(s)
    var short = maxi(0, Campaign.crew_need() - int(G.crew))
    box.add_child(UI.row([UI.button("Repair all · " + Campaign.fmt(total), func(): _repair_all(total), false, total == 0 or G.credits < total),
        UI.button("Hire %s crew · %s" % [Campaign.fmt(short), Campaign.fmt(short * 25)], func(): G.credits -= short * 25; G.crew += short; _render_port(), false, short == 0 or G.credits < short * 25),
        UI.button("Hire 50 spare · 1,250", func(): G.credits -= 1250; G.crew += 50; _render_port(), false, G.credits < 1250)]))

func _captain_pick(s: Dictionary) -> OptionButton:
    var ob = OptionButton.new(); ob.add_item("(no captain)"); ob.set_item_metadata(0, "")
    var G: Dictionary = Campaign.G; var sel = 0
    for o in G.officers:
        ob.add_item("%s · L%d" % [o.name, o.lvl]); ob.set_item_metadata(ob.item_count - 1, o.id)
        if o.ship == s.id: sel = ob.item_count - 1
    ob.selected = sel
    ob.item_selected.connect(func(i):
        for o in G.officers:
            if o.ship == s.id: o.ship = null
        var oid = ob.get_item_metadata(i)
        for o in G.officers:
            if o.id == oid: o.ship = s.id
        _rerender())
    return ob

# shipyard: the classes a flag builds, in every design its own shipbuilders offer at your technology level
func yard_of(p: Dictionary) -> Array:
    var makers: Array = GameData.fac_makers.get(p.fac, []) if GameData.fac_makers.get(p.fac) != null else []
    var out = []
    for c in Campaign.C.YARDS[p.fac]:
        if (c == "bb" or c == "cv") and not p.capital: continue
        for id in Campaign.C.DESIGNS_OF.get(c, []):
            if makers.has(GameData.hulls[id].yard) and Campaign.design_ok(id, Campaign.G.tech): out.append(id)
    out.sort_custom(func(a, b): return GameData.hull_order.find(GameData.hulls[a].klass) * 10000 + GameData.hulls[a].year < GameData.hull_order.find(GameData.hulls[b].klass) * 10000 + GameData.hulls[b].year)
    return out
func ship_price(p: Dictionary, t: String) -> int: return int(round(GameData.hulls[t].price * (1.1 if p.fac == "freeport" else 1.0) * (0.9 if Campaign.G.rep.get(p.fac, 0) > 30 else 1.0)))

func _thumb(id: String, pal: String, w: float, fit = null) -> Control:
    var t = ShipThumb.new(); t.id = id; t.pal = pal; t.fit = fit; var info: Dictionary = GameData.sprites.ships[id]
    t.custom_minimum_size = Vector2(w, w * info.h / info.w + 4); return t

## A ship's plan with its armament, for panels.
class ShipThumb extends Control:
    var id = ""
    var pal = "player"
    var fit = null
    func _ready() -> void: texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    func _draw() -> void:
        var info: Dictionary = GameData.sprites.ships[id]; var d: Dictionary = GameData.hulls[id]
        var k = size.x / info.w   # pixels per metre
        var c = size / 2
        for layer in ["base", "top"]:
            var t = GameData.ship_tex(id, pal, layer); draw_texture_rect(t, Rect2(c - Vector2(info.w, info.h) * k / 2, Vector2(info.w, info.h) * k), false)
        for i in d.slots.size():
            var sl: Dictionary = d.slots[i]; var wid = fit[i] if fit != null else sl.def
            if wid == null or wid == "" or not GameData.sprites.mounts.has(wid): continue
            if d.kind == "sub" and sl.s == "T": continue
            var mi: Dictionary = GameData.sprites.mounts[wid]; var sc: float = k / mi.spr
            draw_set_transform(c + Vector2(sl.x, sl.y) * k, sl.arcs[0][0], Vector2(sc, sc))
            var o = -Vector2(mi.ox, mi.oy) * mi.spr
            if mi.get("split", false): draw_texture(GameData.mount_tex(wid, pal + "_barrels"), o)
            draw_texture(GameData.mount_tex(wid, pal), o)
        draw_set_transform(Vector2.ZERO)

func _yard(box: Control, p: Dictionary) -> void:
    var G: Dictionary = Campaign.G
    _p(box, "Funds %s · Fleet %d / 10. New ships arrive with standard armament, and you can refit them afterwards." % [Campaign.fmt(G.credits), G.fleet.size()], UI.DIM, 14)
    for t in yard_of(p):
        var h: Dictionary = GameData.hulls[t]; var pr = ship_price(p, t)
        var fit: Array = BattleSim.default_fit(h, G.tech); var arms = {}
        for w in fit: if w != "": arms[GameData.weapons[w].name] = arms.get(GameData.weapons[w].name, 0) + 1
        var col = VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        col.add_child(UI.label("%s · %s class · %s %s" % [h.name, h.dn, h.cls, ("· era %d" % h.era) if h.era > 1 else ""], UI.INK, 16))
        col.add_child(UI.label("%s · %d · modelled on the %s" % [GameData.makers[h.yard].name, h.year, h.model], UI.DIM, 13, true))
        col.add_child(UI.label("%s t · %s m · %s kn · turning circle %s m · belt %d mm · Hull %d · Crew %s · Cargo %d%s%s" % [Campaign.fmt(h.t), str(h.L), str(h.kn), Campaign.fmt(h.td), h.armor, h.hull, Campaign.fmt(h.crew), h.cargo, (" · %d air squadrons" % h.hangar) if h.get("hangar", 0) else "", " · sonar" if h.get("sonar", false) else ""], UI.DIM, 13, true))
        col.add_child(UI.label(", ".join(arms.keys().map(func(k): return "%d× %s" % [arms[k], k])), UI.DIM, 13, true))
        col.add_child(UI.button("Buy · " + Campaign.fmt(pr), func():
            if G.credits >= pr and G.fleet.size() < 10:
                G.credits -= pr; var s = Campaign.new_ship(t, null, "player", G.tech); G.fleet.append(s); _toast("%s (%s) commissioned. Hire crew for her." % [s.name, h.name])
            _render_port(), false, G.credits < pr or G.fleet.size() >= 10))
        var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 14); row.add_child(_thumb(t, "player", 300, fit)); row.add_child(col); box.add_child(row)
        box.add_child(HSeparator.new())
    var mk: Array = GameData.fac_makers.get(p.fac, []) if GameData.fac_makers.get(p.fac) != null else []
    _p(box, "Shipbuilders here: " + ", ".join(mk.map(func(m): return GameData.makers[m].name)) + ". " + " ".join(mk.map(func(m): return GameData.makers[m].desc)), UI.DIM, 13)
    if Campaign.era_of(G.tech) < 3: _p(box, "Newer designs appear here as your research reaches the next era.", UI.DIM, 13)

func _refit(box: Control) -> void:
    var G: Dictionary = Campaign.G
    refit_idx = clampi(refit_idx, 0, G.fleet.size() - 1); var s: Dictionary = G.fleet[refit_idx]; var d: Dictionary = GameData.hulls[s.type]
    _p(box, "Swap the weapon in any mount. The old weapon sells back for half its price. Smaller guns fit larger mounts.", UI.DIM, 14)
    var picks = HBoxContainer.new()
    for i in G.fleet.size():
        var k = i
        picks.add_child(UI.button(G.fleet[i].name, func(): refit_idx = k; _render_port(), i == refit_idx))
    box.add_child(picks)
    box.add_child(_thumb(s.type, "player", 520, s.fit))
    box.add_child(UI.label("%s · %s · %s class (%s) · %s t · %s kn · belt %d mm · Hull %d" % [s.name, d.name, d.dn, GameData.makers[d.yard].short, Campaign.fmt(d.t), str(d.kn), d.armor, d.hull], UI.INK, 15))
    var sizes = {"S": "Small gun", "M": "Medium gun", "L": "Large gun", "H": "Heavy gun", "A": "AA / PD", "T": "Torpedo", "V": "Launch cells"}
    for i in d.slots.size():
        var sl: Dictionary = d.slots[i]; var cur: String = s.fit[i] if s.fit[i] != null else ""
        var lab: String = sizes[sl.s] + (" · fwd" if sl.x > 10 else (" · aft" if sl.x < -10 else " · mid"))
        var ob = OptionButton.new(); ob.add_item("(empty)"); ob.set_item_metadata(0, "")
        for wid in GameData.weapons:
            var w: Dictionary = GameData.weapons[wid]
            if not _fits(wid, sl.s) or not Campaign.tech_ok(w.get("tech"), G.tech): continue
            ob.add_item(w.name + ("" if wid == cur else " · " + Campaign.fmt(w.price))); ob.set_item_metadata(ob.item_count - 1, wid)
            if wid == cur: ob.selected = ob.item_count - 1
        var idx = i
        ob.item_selected.connect(func(j):
            var nw: String = ob.get_item_metadata(j); var cost: int = GameData.weapons[nw].price if nw != "" else 0; var refund: int = int(GameData.weapons[cur].price / 2) if cur != "" else 0
            if G.credits + refund < cost: _toast("You need %s more for that weapon." % Campaign.fmt(cost - refund - G.credits))
            else: G.credits += refund - cost; s.fit[idx] = nw
            _render_port())
        var l = UI.label(lab, UI.DIM, 14); l.custom_minimum_size.x = 180
        box.add_child(UI.row([l, ob]))

func _fits(wid: String, slot: String) -> bool:
    var w: Dictionary = GameData.weapons[wid]; var gs = ["S", "M", "L", "H"]
    if gs.has(slot): return gs.has(w.size) and gs.find(w.size) <= gs.find(slot) and gs.find(w.size) >= gs.find(slot) - 1
    return w.size == slot

func _officers(box: Control, p: Dictionary) -> void:
    var G: Dictionary = Campaign.G
    if not p.is_empty():
        box.add_child(UI.label("OFFICERS' MESS AT " + p.name.to_upper(), UI.DIM, 12))
        if p.officers.is_empty(): _p(box, "Nobody is looking for a berth today.", UI.DIM, 14)
        for i in p.officers.size():
            var o: Dictionary = p.officers[i]; var cost: int = 3000 * o.lvl
            var sk = []
            for k in Campaign.C.SKILLS: if o.sk[k]: sk.append("%s %d" % [Campaign.C.SKILLS[k][0], o.sk[k]])
            box.add_child(UI.row([UI.label("%s · level %d" % [o.name, o.lvl], UI.INK), UI.label((" · ".join(sk) if sk.size() else "Green, but eager") + " · salary %d a day" % (40 * o.lvl), UI.DIM, 13),
                UI.button("Sign on · " + Campaign.fmt(cost), func():
                    G.credits -= cost; p.officers.erase(o); var free = null
                    for s in G.fleet:
                        if Campaign.officer_of(s) == null: free = s; break
                    if free != null: o.ship = free.id
                    G.officers.append(o); _toast(o.name + " signs on" + ((" and takes command of " + free.name) if free != null else "") + ".")
                    _render_port(), false, G.credits < cost)]))
    box.add_child(UI.label("YOUR OFFICERS", UI.DIM, 12))
    if G.officers.is_empty(): _p(box, "No officers yet.", UI.DIM, 14)
    for o in G.officers:
        var sh = null
        for s in G.fleet: if s.id == o.ship: sh = s
        box.add_child(UI.label("%s · level %d%s · %s · XP %d/%d" % [o.name, o.lvl, (" · %d point%s to spend" % [o.pts, "s" if o.pts > 1 else ""]) if o.pts else "", ("Commands " + sh.name) if sh != null else "Ashore, no command", o.xp, o.lvl * 100], UI.GOLD if o.pts else UI.INK))
        var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 14)
        for k in Campaign.C.SKILLS:
            var key: String = k
            row.add_child(UI.label("%s %s%s" % [Campaign.C.SKILLS[k][0], "■".repeat(o.sk[k]), "□".repeat(3 - o.sk[k])], UI.DIM, 13))
            if o.pts and o.sk[k] < 3: row.add_child(UI.button("+", func(): o.sk[key] += 1; o.pts -= 1; _rerender()))
        row.add_child(UI.button("Dismiss", func(): G.officers.erase(o); _rerender()))
        box.add_child(row)
    _p(box, ". ".join(Campaign.C.SKILLS.values().map(func(v): return v[0] + ": " + v[1].to_lower())) + ".", UI.DIM, 13)

func rp_price(p: Dictionary) -> int: return 6000 if p.get("fac") == "enclave" else (8000 if p.get("capital", false) and p.get("fac") == "concord" else 0)

func _research(box: Control) -> void:
    var G: Dictionary = Campaign.G; var pr = rp_price(cur_port) if not cur_port.is_empty() else 0
    _p(box, "%d research points available. You earn them by sinking and capturing ships, surveying sites and completing missions." % G.rp, UI.DIM, 14)
    if pr: box.add_child(UI.button(("The enclave trades research data" if cur_port.fac == "enclave" else "The Admiralty sells research") + ": buy 10 RP · " + Campaign.fmt(pr), func(): G.credits -= pr; G.rp += 10; _rerender(), false, G.credits < pr))
    _p(box, "%s. Enemy fleets are at %s." % [Campaign.C.ERA_NAME[str(Campaign.player_era())], Campaign.C.ERA_NAME[str(Campaign.enemy_era())].to_lower()])
    for t in Campaign.C.TECH:
        var done: bool = G.tech.has(t.id); var ok: bool = t.req.all(func(r): return G.tech.has(r))
        var col = VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        col.add_child(UI.label("%s · era %d" % [t.name, t.era], UI.GREEN if done else (UI.INK if ok else UI.DIM)))
        col.add_child(UI.label(t.desc, UI.DIM, 13, true))
        var act: Control
        if done: act = UI.label("Researched", UI.GREEN, 13)
        elif ok: act = UI.button("Research · %d RP" % t.cost, func():
            G.rp -= t.cost; G.tech.append(t.id); _toast("Research complete: %s." % t.name); Campaign.log_ev("Researched " + t.name); _rerender(), false, G.rp < t.cost)
        else: act = UI.label("Requires " + ", ".join(t.req.map(func(r): return Campaign.C.TECH.filter(func(x): return x.id == r)[0].name)), UI.DIM, 13)
        box.add_child(UI.row([col, act]))

func _missions(box: Control, at_admiralty: bool) -> void:
    var G: Dictionary = Campaign.G; var story: Array = Campaign.C.STORY
    var m = story[G.story] if G.story < story.size() else null
    if G.mission != null:
        var am: Dictionary = story[G.mission.idx]
        box.add_child(UI.label("Active: " + am.title, UI.GOLD, 17)); _p(box, am.brief); _p(box, "The target is marked in yellow on your chart.", UI.DIM, 14)
    elif m != null and at_admiralty:
        box.add_child(UI.label("Orders %d of %d: %s" % [G.story + 1, story.size(), m.title], UI.GOLD, 17)); _p(box, m.brief)
        _p(box, "Reward %s, %d RP, Concord standing +%d" % [Campaign.fmt(m.reward.credits), m.reward.rp, m.reward.rep], UI.DIM, 14)
        if G.rep.concord >= 0:
            box.add_child(UI.button("Accept orders", func():
                var f = Campaign.spawn_fleet("mission", m.fac, false, m); G.mission = {"idx": G.story, "fleet": f.id}; Campaign.log_ev("Accepted orders: " + m.title)
                _toast("Orders received: %s. The target is marked in yellow." % m.title); _rerender(), true))
        else: _p(box, "The Admiralty will not deal with you while your standing is below zero.", UI.DIM, 14)
    elif m != null: _p(box, "New orders await at the Concord Admiralty in Norfolk.", UI.DIM, 14)
    else: _p(box, "The war is won. The world's oceans settle into an armed peace, and the arms race goes on. Directorate fleets keep modernising, so keep your research ahead of theirs.")
    box.add_child(UI.label("STANDING", UI.DIM, 12))
    for f in GameData.fac:
        if f == "raiders": continue
        var r: int = G.rep.get(f, 0)
        box.add_child(UI.row([UI.label(GameData.fac[f].name), UI.label(("+" if r > 0 else "") + str(r), UI.INK), UI.label("hostile" if Campaign.hostile(f) else ("favoured" if r >= 30 else "neutral"), UI.RED if Campaign.hostile(f) else (UI.GREEN if r >= 30 else UI.DIM), 13)]))
    if G.log.size():
        box.add_child(UI.label("LOG", UI.DIM, 12))
        var lg: Array = G.log.slice(-8); lg.reverse()
        for l in lg: _p(box, "Day %d: %s" % [l[0], l[1]], UI.DIM, 13)

func _lead_pic(f: Dictionary) -> Control:
    var lead: Dictionary = f.ships[0]
    for s in f.ships: if GameData.hulls[s.type].L > GameData.hulls[lead.type].L: lead = s
    return _thumb(lead.type, GameData.ship_pal(lead.type, f.fac), minf(420.0, GameData.hulls[lead.type].L * 2.2 + 60), lead.fit)
