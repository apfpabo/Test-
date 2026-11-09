extends Node
## The campaign: world state, rules and saves, with no drawing. The chart scene (world_map.gd) shows it and feeds it
## input; battles hand their results back through apply_battle(). Ported from the browser build.
##
## The world map uses 1 map unit = 0.05°, equirectangular from 82°N to 78°S, wrapping east-west. Always measure with
## wdx/mdist/mang (wrap-aware), test land with on_land, and move fleets with set_course + route_move.

signal toast(text: String)
signal encounter(f: Dictionary)
signal reached_port(p: Dictionary)
signal reached_site(q: Dictionary)

const SAVE_PATH := "user://iron_meridian_save.json"
var C: Dictionary = {}           # campaign tables from data/campaign.json
var DEG = 20.0
var LAT0 = 82.0
var MW = 7200.0
var MH = 3200.0
var MASK_RES = 2.0
var mask_w = 3600
var mask_h = 1600
var mask: PackedByteArray        # RGBA8: R land, G pilotage waters within two cells of land
var nav: AStar2D
var nav_bucket = {}             # Vector2i cell -> node ids, for finding lane points near a position
var nav_routes = {}
var G: Dictionary = {}           # the saved game
var paused = false
var map_speed = 1
var last_result: Dictionary = {}
var show_aftermath := false
var start_date = {"year": 1946, "month": 3, "day": 1}

# ------------------------------------------------------------------ geometry
func lon_x(lon: float) -> float: return (lon + 180.0) * DEG
func lat_y(lat: float) -> float: return (LAT0 - lat) * DEG
func x_lon(x: float) -> float: return wrap_x(x) / DEG - 180.0
func y_lat(y: float) -> float: return LAT0 - y / DEG
func wrap_x(x: float) -> float: return fposmod(x, MW)
func wdx(ax: float, bx: float) -> float:
    var d = bx - ax
    return d - MW * round(d / MW)
func mdist(ax: float, ay: float, bx: float, by: float) -> float: return Vector2(wdx(ax, bx), by - ay).length()
func mang(ax: float, ay: float, bx: float, by: float) -> float: return atan2(by - ay, wdx(ax, bx))
static func ang_diff(a: float, b: float) -> float: return wrapf(a - b, -PI, PI)

func on_land(x: float, y: float) -> bool:
    if y < 2 or y >= MH - 2: return true
    var cx = int(floor(wrap_x(x) / MASK_RES)); var cy = int(floor(y / MASK_RES))
    return mask[(cy * mask_w + cx) * 4] > 127

func near_land_cell(x: float, y: float) -> bool:
    var cx = int(floor(wrap_x(x) / MASK_RES)); var cy = clampi(int(floor(y / MASK_RES)), 0, mask_h - 1)
    return mask[(cy * mask_w + cx) * 4 + 1] > 127

func land_near(x: float, y: float, pad: float) -> bool:
    if on_land(x, y): return true
    if pad <= 0: return false
    for k in 8:
        var a = k * PI / 4
        if on_land(x + cos(a) * pad, y + sin(a) * pad): return true
    return false

func nearest_water(x: float, y: float, max_r := 60) -> Vector2:
    if not on_land(x, y): return Vector2(wrap_x(x), y)
    for r in range(1, max_r + 1):
        for k in 24:
            var a = k / 24.0 * TAU; var nx = x + cos(a) * r; var ny = y + sin(a) * r
            if not land_near(nx, ny, 1.5): return Vector2(wrap_x(nx), ny)
    return Vector2(wrap_x(x), y)

func land_density(x: float, y: float, r: float) -> float:
    var n = 0
    for k in 24:
        var a = k / 24.0 * TAU
        for f in [0.35, 0.7, 1.0]: if on_land(x + cos(a) * r * f, y + sin(a) * r * f): n += 1
    return n / 72.0

## True if the straight leg stays at sea, with about a cell of clearance either side.
func sight_line(ax: float, ay: float, bx: float, by: float) -> bool:
    var dx = wdx(ax, bx); var dy = by - ay; var len = sqrt(dx * dx + dy * dy)
    var steps = int(ceil(len / (MASK_RES * 0.4)))
    var nx = -dy / maxf(len, 1.0) * 1.2; var ny = dx / maxf(len, 1.0) * 1.2
    for i in range(1, steps):
        var t = float(i) / steps; var x = ax + dx * t; var y = ay + dy * t
        if on_land(x, y) or on_land(x + nx, y + ny) or on_land(x - nx, y - ny): return false
    return true

# ------------------------------------------------------------------ calendar and ice
func date_of(day: int) -> Dictionary:
    var unix = Time.get_unix_time_from_datetime_dict({"year": 1946, "month": 3, "day": 1, "hour": 12}) + (day - 1) * 86400
    return Time.get_datetime_dict_from_unix_time(unix)
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
func date_str(day: int) -> String:
    var d = date_of(day); return "%d %s %d" % [d.day, MONTHS[d.month - 1], d.year]
func year() -> int: return date_of(G.day).year
## Pack-ice edges in degrees of latitude: Arctic ice peaks in March, Antarctic ice in September.
func ice_edges(day: int) -> Vector2:
    var d = date_of(day); var m = (d.month - 1) + d.day / 31.0
    return Vector2(74 + 4 * sin(TAU * (m - 5.5) / 12), -60 + 4 * sin(TAU * (m - 5) / 12))
## The Gulf Stream keeps the Norwegian and Barents seas open far north; the Bering and Okhotsk seas freeze further south.
func ice_bias(lon: float) -> float:
    return 7 * exp(-pow((lon - 15) / 38.0, 2)) - 9 * exp(-pow((wdx(lon_x(160), lon_x(lon)) / DEG) / 25.0, 2))
func ice_north_at(lon: float, e: Vector2) -> float: return e.x + ice_bias(lon)
func in_ice(x: float, y: float) -> bool:
    var lat = y_lat(y); var e = ice_edges(G.day)
    return lat > ice_north_at(x_lon(x), e) or lat < e.y

# ------------------------------------------------------------------ loading
func _ready() -> void:
    C = JSON.parse_string(FileAccess.open("res://data/campaign.json", FileAccess.READ).get_as_text())
    DEG = C.DEG; LAT0 = C.LAT0; MW = C.MW; MH = C.MH; MASK_RES = C.MASK_RES
    var img: Image = load("res://data/land_mask.png").get_image()
    if img.is_compressed(): img.decompress()
    img.convert(Image.FORMAT_RGBA8); mask_w = img.get_width(); mask_h = img.get_height(); mask = img.get_data()
    _load_nav()

class Lanes extends AStar2D:
    var mw = 7200.0
    func _wd(a: Vector2, b: Vector2) -> float:
        var dx = b.x - a.x; dx -= mw * round(dx / mw); return Vector2(dx, b.y - a.y).length()
    func _compute_cost(a: int, b: int) -> float: return _wd(get_point_position(a), get_point_position(b))
    func _estimate_cost(a: int, b: int) -> float: return _wd(get_point_position(a), get_point_position(b))

func _load_nav() -> void:
    nav = Lanes.new(); nav.mw = MW
    var nodes = FileAccess.get_file_as_bytes("res://data/nav_nodes.bin").to_float32_array()
    var edges = FileAccess.get_file_as_bytes("res://data/nav_edges.bin").to_int32_array()
    var n = nodes.size() / 2
    nav.reserve_space(n + 64)
    for i in n:
        var p = Vector2(nodes[i * 2], nodes[i * 2 + 1]); nav.add_point(i, p)
        var c = Vector2i(int(p.x / 20.0), int(p.y / 20.0))
        if not nav_bucket.has(c): nav_bucket[c] = []
        nav_bucket[c].append(i)
    for i in range(0, edges.size(), 2): nav.connect_points(edges[i], edges[i + 1])
    nav_routes = JSON.parse_string(FileAccess.open("res://data/nav_routes.json", FileAccess.READ).get_as_text()).routes
    if n == 0 or edges.is_empty(): push_error("Sea-lane data is missing (data/nav_*.bin): routes will fail. Check the export include filter.")
    else: print("Sea lanes: %d points, %d links" % [n, edges.size() / 2])

func _nodes_near(p: Vector2, r: float) -> Array:
    var out = []; var c = Vector2i(int(wrap_x(p.x) / 20.0), int(p.y / 20.0)); var k = int(ceil(r / 20.0)); var gw = int(MW / 20.0)
    for dj in range(-k, k + 1):
        for di in range(-k, k + 1):
            var cc = Vector2i(posmod(c.x + di, gw), c.y + dj)
            if nav_bucket.has(cc):
                for id in nav_bucket[cc]:
                    var q = nav.get_point_position(id); var d = mdist(p.x, p.y, q.x, q.y)
                    if d <= r: out.append([d, id])
    out.sort_custom(func(a, b): return a[0] < b[0])
    return out

## Ties a temporary point into the lane network through the nearest lane points it can see.
func _tie(id: int, p: Vector2) -> bool:
    nav.add_point(id, Vector2(wrap_x(p.x), p.y)); var n = 0
    for r in [30.0, 60.0, 120.0]:
        for e in _nodes_near(p, r):
            if n >= 5: break
            var q = nav.get_point_position(e[1])
            if sight_line(p.x, p.y, q.x, q.y): nav.connect_points(id, e[1]); n += 1
        if n > 0: return true
    return false

## A sea route from a to b as waypoints, pulled tight so it keeps only the turns needed to stay at sea.
func find_path(a: Vector2, b: Vector2) -> Array:
    var sa = 900000; var sb = 900001
    var ok = _tie(sa, a) and _tie(sb, b)
    var ids = nav.get_id_path(sa, sb) if ok else PackedInt64Array()
    var pts = []
    for id in ids: pts.append(nav.get_point_position(id))
    nav.remove_point(sa); if nav.has_point(sb): nav.remove_point(sb)
    if pts.size() < 2: return []
    pts[pts.size() - 1] = Vector2(wrap_x(b.x), b.y)
    var out = []; var cur: Vector2 = a; var k = 0
    while k < pts.size() - 1:
        var far = k + 1
        for j in range(mini(pts.size() - 1, k + 300), k + 1, -1):
            if sight_line(cur.x, cur.y, pts[j].x, pts[j].y): far = j; break
        out.append(pts[far]); cur = pts[far]; k = far
    return out

func port_route(from_id: int, to_id: int) -> Array:
    var a = mini(from_id, to_id); var b = maxi(from_id, to_id); var r = nav_routes.get("%d>%d" % [a, b])
    if r == null:
        var p: Dictionary = G.ports[to_id]; return [Vector2(p.sx, p.sy)]
    var pts = []
    for q in r: pts.append(Vector2(q[0], q[1]))
    if from_id > to_id: pts.reverse()
    pts.pop_front(); return pts

# ------------------------------------------------------------------ ships and fleets
func hull(rec: Dictionary) -> Dictionary: return GameData.hulls[rec.type]
func era_of(tech: Array) -> int:
    var e = 1
    for t in tech:
        for x in C.TECH: if x.id == t: e = maxi(e, int(x.era))
    return e
func has_tech(t: String) -> bool: return G.tech.has(t)
func player_era() -> int: return era_of(G.tech)
func enemy_era() -> int: return clampi(maxi(player_era(), 1 + int(G.day / 400)), 1, 3)
func enemy_tech(era: int) -> Array:
    var t = []
    if era >= 2: t.append_array(["radar", "homing", "missiles", "jets", "nuclear"])
    if era >= 3: t.append_array(["ciws", "aegis"])
    return t
func tech_ok(t, tech: Array) -> bool: return t == null or t == "" or tech.has(t)
func design_ok(id: String, tech: Array) -> bool:
    var d: Dictionary = GameData.hulls[id]; return tech_ok(d.get("tech"), tech) and era_of(tech) >= int(d.era)

## A design of a class for a flag: its own yards first, the newest designs most often, older ones still in service.
func design_for(cls: String, fac: String, tech: Array) -> String:
    var all = []
    for id in C.DESIGNS_OF.get(cls, []): if design_ok(id, tech): all.append(id)
    if all.is_empty(): return ""
    var makers = GameData.fac_makers.get(fac)
    var opts = all
    if makers != null:
        opts = all.filter(func(id): return makers.has(GameData.hulls[id].yard))
        if opts.is_empty(): opts = all
    var newest = 0
    for id in opts: newest = maxi(newest, int(GameData.hulls[id].era))
    var wts = []; var tot = 0.0
    for id in opts:
        var w: float = (3.0 if int(GameData.hulls[id].era) == newest else 1.0) * ((2000.0 - GameData.hulls[id].year * 0.95) if fac == "raiders" else 1.0)
        wts.append(w); tot += w
    var r = randf() * tot
    for i in opts.size():
        r -= wts[i]
        if r <= 0: return opts[i]
    return opts[-1]

func new_ship(type: String, ship_name = null, pal := "player", tech: Array = []) -> Dictionary:
    if C.DESIGNS_OF.has(type) and not GameData.hulls.has(type):
        var id = design_for(type, pal, tech)
        if id == "": id = design_for(type, pal, enemy_tech(3))
        type = id
    var names: Array = GameData.names.get(pal, GameData.names.player)
    return {"id": str(randi()), "type": type, "name": ship_name if ship_name != null else names.pick_random(), "hullFrac": 1.0, "fit": BattleSim.default_fit(GameData.hulls[type], tech), "pal": pal}

func ship_value(s: Dictionary) -> float:
    var v: float = hull(s).price
    for w in s.fit: if w != "" and GameData.weapons.has(w): v += GameData.weapons[w].price
    return v
func strength(ships: Array) -> float:
    var t = 0.0
    for s in ships: t += ship_value(s) * (0.3 + 0.7 * s.hullFrac)
    return t
func cargo_cap() -> int:
    var t = 0
    for s in G.fleet: t += int(hull(s).cargo)
    return t
func cargo_used() -> int:
    var t = 0
    for g in C.GOODS: if g.id != "fuel": t += int(floor(G.cargo[g.id]))   # fuel lives in the bunkers, not the hold
    return t
func crew_need() -> int:
    var t = 0
    for s in G.fleet: t += int(hull(s).crew)
    return t
func crew_frac() -> float: return minf(1.0, G.crew / maxf(1.0, crew_need()))
func fuel_use() -> float:
    var t = 0.0
    for s in G.fleet: t += hull(s).fuel
    return t
func wages() -> float:
    var t: float = G.crew * 0.15
    for o in G.officers: t += 40 * o.lvl
    return t
func hostile(fac: String) -> bool: return fac == "raiders" or G.rep.get(fac, 0) < -10
func enemies_of(f: String) -> Array:
    var out = []
    for w in C.WARS: if w.has(f): out.append(w[1] if w[0] == f else w[0])
    return out
func officer_of(rec: Dictionary):
    for o in G.officers: if o.ship == rec.id: return o
    return null
func new_officer(lvl: int) -> Dictionary:
    var o = {"id": str(randi()), "name": C.OFFICER_FIRST.pick_random() + " " + C.OFFICER_LAST.pick_random(), "lvl": lvl, "xp": 0, "pts": 0, "sk": {"gun": 0, "helm": 0, "dc": 0, "ord": 0}, "ship": null}
    for i in lvl:
        var k = ["gun", "helm", "dc", "ord"].pick_random()
        if o.sk[k] < 3: o.sk[k] += 1
        else: o.pts += 1
    return o

## Cruise speed on the chart in map units a second: about 70% of the slowest ship's top speed.
func fleet_map_speed(ships: Array) -> float:
    var m = INF
    for s in ships: m = minf(m, hull(s).kn * (0.75 + 0.25 * s.hullFrac))
    return m * 0.576
func fleet_turn_rate(ships: Array) -> float:
    var L = 0.0
    for s in ships: L = maxf(L, hull(s).L)
    return clampf(0.55 - L / 800.0, 0.15, 0.45)

# ------------------------------------------------------------------ new game and world
func market_mods(fac: String) -> Dictionary:
    var mod = {}; var drift = {}
    var gl = []
    for g in C.GOODS: if g.id != "fuel": gl.append(g.id)
    gl.shuffle()
    var bias: Dictionary = C.MARKET_BIAS.get(fac, {})
    for g in C.GOODS:
        var m = 0.85 + randf() * 0.3
        if gl.slice(0, 2).has(g.id): m = 0.55 + randf() * 0.2
        if gl.slice(2, 4).has(g.id): m = 1.35 + randf() * 0.45
        if g.id == "fuel": m = 0.9 + randf() * 0.25
        mod[g.id] = m * bias.get(g.id, 1.0); drift[g.id] = 0.0
    return {"mod": mod, "drift": drift}

func new_game(start_key: String) -> void:
    var st: Dictionary = C.STARTS[start_key]
    var ports = []
    for p in C.ports:
        var q: Dictionary = p.duplicate(); q.merge(market_mods(p.fac)); q.officers = []; q.offDay = -99; ports.append(q)
    var pois = []
    for p in C.pois: var q: Dictionary = p.duplicate(); q.next = 0; pois.append(q)
    var rep = {}
    for f in GameData.fac: rep[f] = st.rep.get(f, 0)
    rep.raiders = -100
    G = {"v": 3, "ports": ports, "pois": pois, "day": 1, "dayF": 0.0, "credits": st.credits, "rep": rep, "tech": [], "rp": 0, "fleet": [], "cargo": {}, "fleets": [], "nextId": 1, "kills": 0, "crew": 0, "officers": [], "story": 0, "mission": null, "log": [], "start": start_key, "movedToday": false}
    for f in st.fleet: G.fleet.append(new_ship(f[0], f[1], "player", []))
    G.crew = crew_need()
    var o = new_officer(1); o.ship = G.fleet[0].id; G.officers.append(o)
    for g in C.GOODS: G.cargo[g.id] = st.cargo.get(g.id, 0)
    var p0: Dictionary = {}
    for p in G.ports: if p.name == st.port: p0 = p
    G.player = {"x": p0.sx, "y": p0.sy, "h": mang(p0.x, p0.y, p0.sx, p0.sy), "v": 0.0, "tx": null, "ty": null, "cool": 3.0, "destPort": null, "follow": null}
    for i in 40: maintain_fleets(true)
    toast.emit(date_str(1) + ". You put to sea from " + p0.name + ". Click the chart to set a course; scroll to zoom out to the whole world.")
    toast.emit("Wreck fields and abandoned bases (◇ on the chart) can be surveyed for salvage and research.")
    save()

func water_point(pad := 8.0, near = null, rad := 0.0) -> Vector2:
    for i in 400:
        var x: float; var y: float
        if near != null: var a = randf() * TAU; var d = randf() * rad; x = near.x + cos(a) * d; y = near.y + sin(a) * d
        else: x = randf() * MW; y = lat_y(70 - randf() * 125)
        x = wrap_x(x)
        if y < lat_y(76) or y > lat_y(-62): continue
        if not land_near(x, y, pad): return Vector2(x, y)
    return Vector2(near.x, near.y) if near != null else Vector2(lon_x(-40), lat_y(40))

func ports_of(f: String) -> Array: return G.ports.filter(func(p): return p.fac == f)

func build_by_budget(pool: Array, budget: float, mx: int, fac: String, tech: Array) -> Array:
    var ships = []
    while budget > 4000 and ships.size() < mx:
        var opts = []
        for c in pool:
            var id = design_for(c, fac, tech)
            if id != "" and GameData.hulls[id].price <= budget: opts.append(id)
        if opts.is_empty(): break
        var t: String = opts.pick_random(); ships.append(new_ship(t, null, fac, tech)); budget -= GameData.hulls[t].price
    return ships

func spawn_fleet(kind: String, fac: String, initial := false, mission = null) -> Dictionary:
    var P: Dictionary = G.player; var era = enemy_era(); var tl = enemy_tech(maxi(1, era - 1) if kind == "raiders" else era); var scale = 1.0 + G.day / 120.0
    var f = {"id": G.nextId, "kind": kind, "fac": mission.fac if mission != null else fac, "h": randf() * TAU, "v": 0.0, "tx": null, "ty": null, "cool": 0.0, "ships": [], "cargo": {}}
    G.nextId += 1
    var pos = Vector2.ZERO; var from_id = -1
    for i in 30:
        if mission != null:
            var np: Dictionary = {}
            for p in G.ports: if p.name == mission.near: np = p
            pos = water_point(8, Vector2(np.sx, np.sy), 160)
        elif kind == "patrol": var p: Dictionary = ports_of(fac).pick_random(); pos = water_point(8, Vector2(p.sx, p.sy), 260)
        elif kind == "convoy": var p: Dictionary = ports_of(fac).pick_random(); pos = Vector2(p.sx, p.sy); from_id = p.id
        else:
            var p: Dictionary = G.ports.filter(func(q): return q.fac != "enclave").pick_random(); pos = water_point(8, Vector2(p.sx, p.sy), 420)
        if mission != null or initial or mdist(pos.x, pos.y, P.x, P.y) > 300: break
    f.x = pos.x; f.y = pos.y; f.home = {"x": pos.x, "y": pos.y}
    if mission != null:
        f.kind = "mission"; f.name = mission.title; f.mission = true
        for sh in mission.ships: f.ships.append(new_ship(sh[0], sh[1] if sh.size() > 1 else null, f.fac, tl))
    elif kind == "patrol": f.name = GameData.fac[fac].short + " patrol"; f.ships = build_by_budget(C.PATROL_POOL[fac], (18000 + randf() * 45000) * scale, 6, fac, tl)
    elif kind == "convoy":
        f.name = GameData.fac[fac].short + " convoy"
        var n = randi_range(1, 3)
        for i in n: f.ships.append(new_ship("freighter", null, fac, tl))
        f.ships.append_array(build_by_budget(C.ESCORT_POOL[fac], 8000 + randf() * 25000, 2, fac, tl))
        var from: Dictionary = G.ports[from_id]; var en = enemies_of(fac)
        var dests: Array = G.ports.filter(func(p): return p.id != from_id and not en.has(p.fac) and mdist(p.sx, p.sy, from.sx, from.sy) < 2600)
        var d: Dictionary = dests.pick_random() if dests.size() else G.ports.filter(func(p): return p.id != from_id).pick_random()
        f.dest = d.id; f.from = from_id
        for g in C.GOODS: if randf() < 0.55: f.cargo[g.id] = randi_range(15, 50) * n
    elif kind == "raiders": f.name = "Raider flotilla"; f.ships = build_by_budget(C.PATROL_POOL.raiders, (12000 + randf() * 30000) * scale, 6, "raiders", tl)
    else:
        f.captain = ["\"Hook\" Marlowe", "Ysolde Crane", "\"Bosun\" Teague", "Anika Vell", "Black Corwin", "Mother Grist", "\"Lantern\" Pike", "Severin Oakes"].pick_random()
        f.name = "Bounty: " + f.captain
        f.ships.append(new_ship("ca" if scale > 2.5 else "cl", null, "raiders", tl))
        f.ships.append_array(build_by_budget(["pt", "dd", "dd", "ss"], (30000 + randf() * 30000) * scale, 5, "raiders", tl))
        f.reward = round(strength(f.ships) * 0.35 / 500.0) * 500
    if f.ships.is_empty(): f.ships.append(new_ship("pt" if fac == "raiders" else "corvette", null, f.fac, tl))
    G.fleets.append(f)
    return f

func maintain_fleets(initial: bool) -> void:
    var count = func(k: String, fac := "") -> int: return G.fleets.filter(func(f): return f.kind == k and (fac == "" or f.fac == fac)).size()
    for fac in GameData.fac:
        if fac == "raiders": continue
        var np = ports_of(fac).size()
        if np == 0: continue
        var want_patrol = 1 if fac == "enclave" else int(ceil(np * 0.7)) + (mini(3, int(G.day / 60)) if fac == "directorate" else 0)
        if count.call("patrol", fac) < want_patrol and (initial or randf() < 0.3): spawn_fleet("patrol", fac, initial)
        if fac != "enclave" and count.call("convoy", fac) < int(ceil(np * 0.6)) and (initial or randf() < 0.3): spawn_fleet("convoy", fac, initial)
    if count.call("raiders") < 6 and (initial or randf() < 0.3): spawn_fleet("raiders", "raiders", initial)
    if count.call("bounty") < 2 and (initial or randf() < 0.08):
        var f = spawn_fleet("bounty", "raiders", initial)
        if not initial: toast.emit("Bounty posted on %s: %s." % [f.captain, fmt(f.reward)])

static func fmt(n: float) -> String:
    var s = str(int(round(absf(n)))); var out = ""
    while s.length() > 3: out = "," + s.substr(s.length() - 3) + out; s = s.substr(0, s.length() - 3)
    return ("-" if n < 0 else "") + s + out

# ------------------------------------------------------------------ routes and movement
## Routes have their corners rounded into arcs that stay at sea.
func build_route(o: Dictionary, pts: Array) -> Array:
    var raw = [Vector2(o.x, o.y)]
    for p in pts: var prev: Vector2 = raw[-1]; raw.append(Vector2(prev.x + wdx(prev.x, p.x), p.y))
    var out = [raw[0]]
    for i in range(1, raw.size() - 1):
        var a: Vector2 = raw[i - 1]; var b: Vector2 = raw[i]; var c: Vector2 = raw[i + 1]
        var l1 = maxf(a.distance_to(b), 1.0); var l2 = maxf(c.distance_to(b), 1.0)
        var r = minf(18.0, minf(l1 * 0.35, l2 * 0.35)); var arc = []
        for tries in 3:
            if r <= 1: break
            var p1 = b + (a - b) / l1 * r; var p2 = b + (c - b) / l2 * r; var seg = []; var ok = true
            for k in 7:
                var t = k / 6.0; var u = 1.0 - t; var q = u * u * p1 + 2 * u * t * b + t * t * p2
                if on_land(q.x, q.y): ok = false; break
                seg.append(q)
            if ok: arc = seg; break
            r /= 2
        if arc.size(): out.append_array(arc)
        else: out.append(b)
    if raw.size() > 1: out.append(raw[-1])
    return out

func set_course(o: Dictionary, x: float, y: float) -> bool:
    var pts: Array = [Vector2(wrap_x(x), y)] if sight_line(o.x, o.y, x, y) else find_path(Vector2(o.x, o.y), Vector2(x, y))
    if pts.is_empty(): return false
    o.tx = wrap_x(x); o.ty = y; o.route = build_route(o, pts); o.ri = 0; o.rx = o.x; o.ry = o.y
    return true

func route_remaining(o: Dictionary) -> float:
    var r: Array = o.route; var d = Vector2(o.rx, o.ry).distance_to(r[o.ri + 1])
    for i in range(o.ri + 1, r.size() - 1): d += r[i].distance_to(r[i + 1])
    return d

## Advances along the route; true once the fleet has arrived. Speed builds and bleeds off gradually, ships slow for
## bends, in confined waters and on the final approach, and the bow swings at the fleet's own turn rate.
func route_move(o: Dictionary, max_sp: float, turn: float, dt: float) -> bool:
    var r = o.get("route")
    if r == null or o.ri >= r.size() - 1: coast(o, dt); return true
    if near_land_cell(o.x, o.y): max_sp *= 0.5
    var cur = Vector2(o.rx, o.ry); var seg_h = (r[o.ri + 1] - cur).angle()
    var bend = 0.0; var look = maxf(15.0, o.v * 2.5); var pp = cur; var ph = seg_h
    for i in range(o.ri + 1, r.size()):
        if look <= 0: break
        var h: float = (r[i] - pp).angle(); bend += absf(ang_diff(h, ph)); look -= pp.distance_to(r[i]); pp = r[i]; ph = h
    var rem = route_remaining(o)
    var target = max_sp * clampf(1 - bend / 1.6, 0.3, 1.0)
    if not o.get("noBrake", false): target = minf(target, sqrt(2 * max_sp * 0.5 * rem) + 0.4)
    o.h += clampf(ang_diff(seg_h, o.h), -turn * dt, turn * dt)
    target *= maxf(0.12, cos(clampf(ang_diff(seg_h, o.h), -PI / 2, PI / 2)))
    o.v = o.v + clampf(target - o.v, -max_sp * 0.6 * dt, max_sp * 0.3 * dt)
    var d = maxf(0.0, o.v * dt)
    while d > 0 and o.ri < r.size() - 1:
        var nxt: Vector2 = r[o.ri + 1]; var c2 = Vector2(o.rx, o.ry); var sl = c2.distance_to(nxt)
        if sl <= d: o.rx = nxt.x; o.ry = nxt.y; o.ri += 1; d -= sl
        else: var q = c2 + (nxt - c2) / sl * d; o.rx = q.x; o.ry = q.y; d = 0
    o.x = wrap_x(o.rx); o.y = o.ry
    if o.ri >= r.size() - 1: o.route = null; return true
    return false

func coast(o: Dictionary, dt: float) -> void: o.v = maxf(0.0, o.v - 8 * dt)

func nearest_port(max_d: float):
    var best = null; var bd = max_d
    for p in G.ports:
        var d = mdist(p.sx, p.sy, G.player.x, G.player.y)
        if d < bd: bd = d; best = p
    return best
func nearest_poi(max_d: float):
    var best = null; var bd = max_d
    for p in G.pois:
        var d = mdist(p.x, p.y, G.player.x, G.player.y)
        if d < bd: bd = d; best = p
    return best

# ------------------------------------------------------------------ the passing of days
func new_day(moved: bool) -> void:
    G.day += 1
    var P: Dictionary = G.player
    if moved:
        G.cargo.fuel -= fuel_use() * (1.5 if in_ice(P.x, P.y) else 1.0)
        if G.cargo.fuel < 0:
            G.cargo.fuel = 0
            if not G.get("noFuelWarned", false): toast.emit("Bunkers are dry. The fleet crawls on emergency reserves. Buy fuel oil at any port."); G.noFuelWarned = true
        else: G.noFuelWarned = false
        if in_ice(P.x, P.y):
            for s in G.fleet: s.hullFrac = maxf(0.05, s.hullFrac - 0.015)
            if not G.get("iceWarned", false): toast.emit("Pack ice. Speed is cut, fuel burn rises and the ice grinds at your hulls."); G.iceWarned = true
        else: G.iceWarned = false
    G.cargo.food -= G.crew * 0.004
    if G.cargo.food < 0:
        G.cargo.food = 0; var lost = int(ceil(G.crew * 0.03)); G.crew -= lost
        if lost: toast.emit("No food aboard. %d sailors deserted." % lost)
    G.credits -= wages()
    if G.credits < 0:
        var lost = int(ceil(G.crew * 0.05)); G.crew -= lost; G.credits = 0; toast.emit("Pay is in arrears. %d sailors walked off." % lost)
    for p in G.ports:
        for g in C.GOODS: p.drift[g.id] = clampf(p.drift[g.id] * 0.93 + (randf() - 0.5) * 0.05, -0.3, 0.45)
    maintain_fleets(false)
    if G.day % 3 == 0: save()   # autosave every few days at sea
    var era = enemy_era()
    if era > G.get("seenEra", 1): G.seenEra = era; toast.emit("Intelligence: Directorate yards are fielding " + C.ERA_NAME[str(era)].split("· ")[1].to_lower() + ".")

## One tick of the chart: the calendar, your task force, and every other fleet. Emits encounter() on contact.
func update(dt: float) -> void:
    if paused or G.is_empty(): return
    var P: Dictionary = G.player; P.cool = maxf(0.0, P.cool - dt)
    G.dayF += dt * 0.1
    if G.dayF >= 1:
        G.dayF -= 1; new_day(G.movedToday); G.movedToday = false
    P.noBrake = P.follow != null
    if P.follow != null:
        var f = _fleet(P.follow); P.repathT = P.get("repathT", 0.0) - dt
        if f == null: P.follow = null; toast.emit("Contact lost.")
        elif P.repathT <= 0:
            var d = mdist(P.x, P.y, f.x, f.y); P.repathT = 2.0 if d > 300 else 0.6
            var lead = minf(d / maxf(0.5, fleet_map_speed(G.fleet)), 12.0)
            var lx: float = f.x + cos(f.h) * f.v * lead; var ly: float = f.y + sin(f.h) * f.v * lead
            if not set_course(P, f.x if on_land(lx, ly) else lx, f.y if on_land(lx, ly) else ly): set_course(P, f.x, f.y)
    var ice = in_ice(P.x, P.y)
    if P.get("route") != null:
        var no_fuel: bool = G.cargo.fuel <= 0 and fuel_use() > 0
        var sp = fleet_map_speed(G.fleet) * (0.2 if no_fuel else 1.0) * (0.4 if ice else 1.0)
        G.movedToday = true
        if route_move(P, sp, fleet_turn_rate(G.fleet), dt):
            P.tx = null; P.route = null
            if P.follow == null: _arrive()
            else: P.repathT = 0.0
    else: coast(P, dt)
    var ps = strength(G.fleet)
    for f in G.fleets.duplicate():
        f.cool = maxf(0.0, f.cool - dt)
        var dP = mdist(f.x, f.y, P.x, P.y); var hos = hostile(f.fac)
        var merchant = true
        for s in f.ships: if hull(s).kind != "merchant": merchant = false
        var rate = 0.6
        if hos and f.cool <= 0 and P.cool <= 0 and dP < 160 and not merchant:
            var chase: bool = strength(f.ships) > ps * 0.5 or f.get("mission", false)
            f.chaseT = f.get("chaseT", 0.0) - dt; rate = 1.0 if chase else 0.95
            if f.chaseT <= 0 or f.get("route") == null:
                f.chaseT = 1.2
                var fx: float = P.x if chase else f.x - wdx(f.x, P.x) * 1.5; var fy: float = P.y if chase else clampf(f.y + (f.y - P.y) * 1.5, 20, MH - 20)
                if not set_course(f, fx, fy): f.route = null
            f.chasing = chase
        else:
            if f.get("chasing", false): f.chasing = false; f.route = null
            if f.get("route") == null:
                if f.has("dest") and f.get("started", false): G.fleets.erase(f); continue
                if f.has("dest"):
                    f.started = true; var d: Dictionary = G.ports[f.dest]
                    f.route = build_route(f, port_route(f.from, f.dest)); f.ri = 0; f.rx = f.x; f.ry = f.y; f.tx = d.sx; f.ty = d.sy
                else:
                    var w = water_point(6, Vector2(f.home.x, f.home.y), 120.0 if (f.get("mission", false) or f.kind == "bounty") else 320.0)
                    if not set_course(f, w.x, w.y): f.route = null
        var fsp = fleet_map_speed(f.ships) * rate * (0.4 if in_ice(f.x, f.y) else 1.0)
        if f.get("route") != null and route_move(f, fsp, fleet_turn_rate(f.ships), dt): f.route = null
        if dP < 16 and f.cool <= 0 and P.cool <= 0 and (hos or P.follow == f.id):
            paused = true; encounter.emit(f); return

func _fleet(id):
    for f in G.fleets: if f.id == id: return f
    return null

func _arrive() -> void:
    var P: Dictionary = G.player
    if P.get("destPort") != null:
        var p: Dictionary = G.ports[P.destPort]; P.destPort = null
        if mdist(P.x, P.y, p.sx, p.sy) < 30: reached_port.emit(p)

func log_ev(t: String) -> void:
    G.log.append([G.day, t])
    if G.log.size() > 40: G.log.pop_front()

# ------------------------------------------------------------------ surveys
func do_survey(poi: Dictionary) -> Dictionary:
    var out = {"lines": [], "ambush": null}
    if G.day < poi.next: out.lines.append("Your divers have picked this site over recently. Come back in %d days." % (poi.next - G.day)); return out
    poi.next = G.day + 60
    var roll = randf(); var rp = 0; var coin = 0
    if poi.type == "wreck": rp = randi_range(6, 16); coin = randi_range(3, 12) * 1000; out.lines.append("Divers bring up range-keeping clocks, shell fragments and a sealed chart case.")
    elif poi.type == "base":
        rp = randi_range(4, 10); coin = randi_range(2, 6) * 1000; var fuel = randi_range(30, 90); G.cargo.fuel += fuel
        out.lines.append("The bunkers still hold %d tons of fuel oil, and the workshops yield spares worth selling." % fuel)
    else: rp = randi_range(15, 32); coin = randi_range(1, 4) * 1000; out.lines.append("Behind a welded door: filing cabinets, wiring diagrams and a crate of prototype valves.")
    G.rp += rp; G.credits += coin; out.lines.append("+%d RP, +%s in salvage." % [rp, fmt(coin)])
    if poi.type != "site" and roll < 0.22 and G.fleet.size() < 10:
        var hulk = new_ship(["dd", "dd", "corvette", "cl", "ss"].pick_random(), null, "raiders", [])
        hulk.pal = "player"; hulk.name = GameData.names.player.pick_random(); hulk.hullFrac = 0.22; G.fleet.append(hulk)
        out.lines.append("A %s is still afloat at her moorings. Pumped out and patched, she joins you as the %s at 22%% condition. She needs %d crew." % [hull(hulk).name.to_lower(), hulk.name, hull(hulk).crew])
    log_ev("Surveyed %s (+%d RP)" % [poi.name, rp])
    if roll > (0.65 if poi.type == "site" else 0.82):
        var f = spawn_fleet("patrol" if poi.type == "site" else "raiders", "directorate" if poi.type == "site" else "raiders")
        f.x = wrap_x(G.player.x + 6); f.y = G.player.y
        out.lines.append("Lookouts report a Directorate guard force closing fast." if poi.type == "site" else "Raiders were working the same site, and they are not sharing.")
        out.ambush = f
    save()
    return out

# ------------------------------------------------------------------ battles
## Squadrons for the battle scene, as records it can fight with directly.
func battle_setup(f: Dictionary) -> Dictionary:
    var recs = []
    for s in G.fleet: recs.append(s)
    for o in G.officers: o.lastShip = o.ship
    return {"player_recs": recs, "enemy_recs": f.ships, "enemy_fac": f.fac, "player_tech": G.tech, "enemy_tech": enemy_tech(enemy_era()),
        "islands": _islands_here(), "fleet_id": f.id, "campaign": true, "crew_frac": crew_frac(), "officers": G.officers}

func _islands_here() -> int:
    var dens = land_density(G.player.x, G.player.y, 25)
    return randi_range(3, 5) if dens > 0.25 else (randi_range(1, 3) if dens > 0.05 else randi_range(0, 1))

## Applies a finished battle to the campaign: damage, losses, casualties, prizes, prize money, research, officer
## experience, bounties and missions. Mirrors the browser build's endCombat.
func apply_battle(sim: BattleSim) -> Dictionary:
    var f = _fleet(GameData.pending.get("fleet_id", -1))
    var r = {"victory": false, "retreated": false, "sunk": [], "lost": [], "prizes": [], "coin": 0, "rp": 0, "goods": "", "bounty": 0, "casualties": 0, "notes": []}
    var cas = 0.0
    for s in sim.ships:
        if s.side == 0:
            if not s.alive: r.lost.append(s.rec); cas += s.d.crew * 0.5
            else: s.rec.hullFrac = maxf(0.05, s.hull / s.max_hull); cas += s.d.crew * (s.dmg_taken / s.max_hull) * 0.25 * (1 - 0.15 * s.sk.dc)
        else:
            if not s.alive: r.sunk.append(s.rec)
            else:
                s.rec.hullFrac = maxf(0.05, s.hull / s.max_hull)
                if s.struck: r.prizes.append(s.rec)
    r.casualties = mini(int(G.crew), int(round(cas))); G.crew -= r.casualties
    G.fleet = G.fleet.filter(func(s): return not r.lost.has(s))
    for o in G.officers: if not G.fleet.any(func(s): return s.id == o.ship): o.ship = null
    if f != null: f.ships = f.ships.filter(func(s): return not r.sunk.has(s) and not r.prizes.has(s))
    var enemy_left = false
    for s in sim.ships: if s.side == 1 and sim.engageable(s): enemy_left = true
    r.victory = not enemy_left and G.fleet.size() > 0; r.retreated = not r.victory and G.fleet.size() > 0
    G.kills += r.sunk.size()
    var beaten: Array = r.sunk + r.prizes; var beaten_value = 0.0
    for s in beaten: beaten_value += ship_value(s)
    for s in r.sunk: r.coin += ship_value(s) * (0.07 + randf() * 0.06)
    r.coin = int(round(r.coin / 50.0) * 50)
    r.rp = int(round(beaten_value / 4000.0)); G.rp += r.rp
    var fac: String = f.fac if f != null else "raiders"
    for e in (["concord", "pacific", "combine", "freeport"] if fac == "raiders" else enemies_of(fac)): G.rep[e] = mini(100, G.rep.get(e, 0) + beaten.size())
    if r.victory and f != null and f.cargo.size():
        var got = []; var free = cargo_cap() - cargo_used()
        for g in f.cargo:
            var take = mini(free, int(floor(f.cargo[g] * (0.3 + randf() * 0.4))))
            if take > 0:
                G.cargo[g] += take; free -= take
                for gd in C.GOODS: if gd.id == g: got.append("%d %s" % [take, gd.name.to_lower()])
        r.goods = ", ".join(got)
    # officers gain experience from the tonnage beaten; those aboard ships that sank go down with them
    var xp = int(round(beaten_value / 600.0)) + 10
    for s in sim.ships:
        if s.side != 0: continue
        var o = officer_of(s.rec)
        if o == null: continue
        if s.alive:
            o.xp += xp
            while o.xp >= o.lvl * 100 and o.lvl < 8:
                o.xp -= o.lvl * 100; o.lvl += 1; o.pts += 1
                r.notes.append("%s is promoted to level %d. Assign the new skill point in Command, under Officers." % [o.name, o.lvl])
    for s in r.lost:
        for o in G.officers.duplicate():
            if o.get("lastShip") == s.id: G.officers.erase(o); r.notes.append("%s went down with the %s." % [o.name, s.name])
    var gone: bool = f == null or f.ships.is_empty()
    if f != null:
        if gone:
            G.fleets.erase(f)
            if f.kind == "bounty": r.bounty = f.reward; log_ev("Collected the bounty on " + f.captain)
        else: f.cool = 8.0
    G.credits += r.coin + r.bounty
    if G.mission != null and f != null and G.mission.fleet == f.id:
        var m: Dictionary = C.STORY[G.mission.idx]
        if m.goal == "destroy" and gone: _complete_mission(r)
        elif m.goal == "capture" and r.sunk.any(func(s): return s.name == m.target):
            r.notes.append("The %s went down with her codebook. The mission has failed. Return to the Admiralty for new orders." % m.target)
            G.mission = null; log_ev("Mission failed: " + m.title)
    G.player.cool = 5.0
    last_result = r
    save()
    return r

func _complete_mission(r: Dictionary) -> void:
    var m: Dictionary = C.STORY[G.mission.idx]
    G.credits += m.reward.credits; G.rp += m.reward.rp; G.rep.concord += m.reward.rep
    r.notes.append("Orders complete: %s. +%s, +%d RP." % [m.title, fmt(m.reward.credits), m.reward.rp])
    log_ev("Completed: " + m.title); G.story += 1; G.mission = null
    if G.story >= C.STORY.size(): r.notes.append("The Directorate sues for an armistice. The war is over. Your fleet, and the arms race, go on.")

# ------------------------------------------------------------------ saves
func save() -> void:
    if G.is_empty(): return
    var g = G.duplicate(true)
    _strip_routes(g.player)
    for f in g.fleets: _strip_routes(f)
    var fa = FileAccess.open(SAVE_PATH, FileAccess.WRITE); fa.store_string(JSON.stringify(g))

func _strip_routes(o: Dictionary) -> void:
    if o.get("route") != null:
        var pts = []
        for q in o.route: pts.append([q.x, q.y])
        o.route = pts

func has_save() -> bool: return FileAccess.file_exists(SAVE_PATH)

func load_game() -> bool:
    if not has_save(): return false
    var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
    if d == null: return false
    G = d
    for o in [G.player] + G.fleets: _restore_route(o)
    _ints(G)
    paused = false
    return true

func _restore_route(o: Dictionary) -> void:
    if o.get("route") != null:
        var pts = []
        for q in o.route: pts.append(Vector2(q[0], q[1]))
        o.route = pts; o.ri = int(o.ri)

## JSON turns every number into a float; put back the integers that index arrays.
func _ints(g: Dictionary) -> void:
    g.day = int(g.day); g.nextId = int(g.nextId); g.story = int(g.story)
    if g.player.get("destPort") != null: g.player.destPort = int(g.player.destPort)
    if g.player.get("follow") != null: g.player.follow = int(g.player.follow)
    for f in g.fleets:
        f.id = int(f.id)
        if f.has("dest"): f.dest = int(f.dest)
        if f.has("from"): f.from = int(f.from)
    for p in g.ports: p.id = int(p.id)
    if g.mission != null: g.mission.idx = int(g.mission.idx); g.mission.fleet = int(g.mission.fleet)
    for o in g.officers:
        o.lvl = int(o.lvl); o.pts = int(o.pts)
        for k in o.sk: o.sk[k] = int(o.sk[k])
