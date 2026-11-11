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
## Version 4: the fictional world map. Saves from the real-Earth map (3 and older) cannot be loaded.
const SAVE_VERSION := 4
var C: Dictionary = {}           # campaign tables from data/campaign.json
var S: Dictionary = {}           # story chains of the other powers, from data/stories.json
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
var _ice_day := -1
var _ice_e := Vector2.ZERO
func ice_edges(day: int) -> Vector2:
    if day == _ice_day: return _ice_e   # asked for every fleet on every tick of the chart: worked out once a day
    var d = date_of(day); var m = (d.month - 1) + d.day / 31.0
    _ice_day = day; _ice_e = Vector2(74 + 4 * sin(TAU * (m - 5.5) / 12), -60 + 4 * sin(TAU * (m - 5) / 12))
    return _ice_e
## Ocean currents bend the ice edge (campaign.json ICE_BIAS: [lon, shift in degrees, width]): a warm current keeps the
## Vargan north-west coast open far north; the cold northern Halcyon freezes further south.
func ice_bias(lon: float) -> float:
    var b := 0.0
    for c in C.get("ICE_BIAS", []): b += float(c[1]) * exp(-pow((wdx(lon_x(c[0]), lon_x(lon)) / DEG) / float(c[2]), 2))
    return b
func ice_north_at(lon: float, e: Vector2) -> float: return e.x + ice_bias(lon)
func in_ice(x: float, y: float) -> bool:
    var lat = y_lat(y)
    if lat < 45.0 and lat > -55.0: return false   # nowhere near either ice edge (the currents shift it by a few degrees at most)
    var e = ice_edges(G.day)
    return lat > ice_north_at(x_lon(x), e) or lat < e.y

# ------------------------------------------------------------------ loading
func _ready() -> void:
    C = JSON.parse_string(FileAccess.open("res://data/campaign.json", FileAccess.READ).get_as_text())
    S = JSON.parse_string(FileAccess.open("res://data/stories.json", FileAccess.READ).get_as_text())
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
## A line over water with no sea room asked either side (the last resort for a ship close under the land).
func bare_line(ax: float, ay: float, bx: float, by: float) -> bool:
    var dx := wdx(ax, bx); var dy := by - ay; var steps := int(ceil(sqrt(dx * dx + dy * dy) / (MASK_RES * 0.4)))
    for i in range(1, steps): if on_land(ax + dx * i / steps, ay + dy * i / steps): return false
    return true
func _tie(id: int, p: Vector2, bare := false) -> bool:
    if nav.has_point(id): nav.remove_point(id)
    nav.add_point(id, Vector2(wrap_x(p.x), p.y)); var n = 0
    for r in [30.0, 60.0, 120.0]:
        for e in _nodes_near(p, r):
            if n >= 5: break
            var q = nav.get_point_position(e[1])
            if (bare_line(p.x, p.y, q.x, q.y) if bare else sight_line(p.x, p.y, q.x, q.y)): nav.connect_points(id, e[1]); n += 1
        if n > 0: return true
    return false

## A sea route from a to b as waypoints, pulled tight so it keeps only the turns needed to stay at sea.
func find_path(a: Vector2, b: Vector2) -> Array:
    var sa = 900000; var sb = 900001
    # A big squadron swings wide and can fetch up hard against a coast, where no lane point is in clear sight (the
    # sight line wants sea room either side). Then stand off to the nearest open water first and route from there.
    var a0 := a; var lead := false
    if not _tie(sa, a):
        nav.remove_point(sa); var w := nearest_water(a.x, a.y, 60)
        if not _tie(sa, w) and not _tie(sa, w, true):
            if not _tie(sa, a, true): nav.remove_point(sa); return []
        else: a = w; lead = true
    var ok = _tie(sb, b) or _tie(sb, b, true)
    var ids = nav.get_id_path(sa, sb) if ok else PackedInt64Array()
    var pts = []
    for id in ids: pts.append(nav.get_point_position(id))
    if nav.has_point(sa): nav.remove_point(sa)
    if nav.has_point(sb): nav.remove_point(sb)
    if pts.size() < 2: return []
    pts[pts.size() - 1] = Vector2(wrap_x(b.x), b.y)
    var out = []; var cur: Vector2 = a; var k = 0
    if lead: out.append(Vector2(wrap_x(a.x), a.y))   # first leg: clear of the land
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
## The era a set of technologies has reached: Era II opens with ERA_GATE (3) Era I technologies, Era III with
## ERA_GATE Era II technologies on top. (Technologies of an era can only be researched once it is open.)
const ERA_GATE := 3
func era_count(tech: Array, era: int) -> int:
    var n := 0
    for x in C.TECH: if int(x.era) == era and tech.has(x.id): n += 1
    return n
func era_of(tech: Array) -> int:
    if era_count(tech, 1) < ERA_GATE: return 1
    if era_count(tech, 2) < ERA_GATE: return 2
    return 3
func has_tech(t: String) -> bool: return G.tech.has(t)
func player_era() -> int: return era_of(G.tech)
## Each power runs its own Quiet Race. Its research points grow every day at its own pace (faster at war); its era,
## and with it the ships, guns and defences it fields, follows its own points, not yours. Reaching the missile age
## early does not drag the world along. 400 points for Era II, 800 for Era III: at the base pace, the old calendar.
const RESEARCH_PACE := {"concord": 1.0, "directorate": 1.15, "pacific": 0.95, "combine": 1.2, "republic": 0.65, "freeport": 0.55,
    "enclave": 0.9, "ombria": 0.6, "isles": 0.6}
const ERA_POINTS := [0.0, 400.0, 800.0]
func fac_rp(fac: String) -> float:
    if fac == "raiders": return maxf(0.0, fac_rp("freeport") - 400.0)   # scavenged ships, a step behind the freeports
    return float(G.get("facRp", {}).get(fac, float(G.get("day", 1)) * float(RESEARCH_PACE.get(fac, 0.8))))
func fac_era(fac: String) -> int:
    var p := fac_rp(fac); var e := 1
    for i in ERA_POINTS.size(): if p >= ERA_POINTS[i]: e = i + 1
    return clampi(e, 1, 3)
## The newest era fielded by any power (for things not tied to one flag).
func enemy_era() -> int:
    var e := 1
    for f in RESEARCH_PACE: e = maxi(e, fac_era(f))
    return e
func _research_day() -> void:
    if not G.has("facRp"): G.facRp = {}
    for f in RESEARCH_PACE:
        var at_war := Diplomacy.POWERS.any(func(o): return o != f and Diplomacy.at_war(f, o))
        var before := fac_era(f)
        G.facRp[f] = fac_rp(f) + float(RESEARCH_PACE[f]) * (1.3 if at_war else 1.0) * randf_range(0.8, 1.2)
        var now := fac_era(f)
        if now > before and GameData.fac.has(f):
            toast.emit("Intelligence: %s yards are fielding %s designs." % [GameData.fac[f].short, C.ERA_NAME[str(now)].split("· ")[1].to_lower()])
## What a power fielding this era has researched (enough to open it, as for you).
func enemy_tech(era: int) -> Array:
    var t = []
    if era >= 2: t.append_array(["radar", "sonar", "homing", "aa_prox", "dc", "amphib", "missiles", "jets", "nuclear", "snorkel"])
    if era >= 3: t.append_array(["helo", "ecm", "ciws", "aegis", "vls", "reactors", "datalink"])
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
    var up = s.get("up")
    if up != null: for k in up: if BattleSim.UPGRADES.has(k): v += float(hull(s).price) * float(BattleSim.UPGRADES[k].cost) * int(up[k])   # yard work counts in what she is worth
    return v
## Crews (docs/GUNNERY.md): a ship's company learns its trade in action. `xp` on a ship is the actions she has fought
## (a new ship's crew counts as one: trained; a prize's as none: green); heavy casualties thin what was learned.
func crew_xp(s: Dictionary) -> float: return float(s.get("xp", 1.0))
func crew_name(s: Dictionary) -> String: return String(BattleSim.CREW[BattleSim.crew_level(crew_xp(s))].name)
## A ship's speed for her loading (BattleSim.loading), kept on her record (`ldv`) so the chart does not work the
## ledger out every tick. Call ship_refitted(s) whenever her weapons or systems change.
func load_speed(s: Dictionary) -> float:
    var v = s.get("ldv")
    if v == null: v = float(BattleSim.loading(hull(s), s.fit, s.get("up", {})).speed); s.ldv = v
    return float(v)
func ship_refitted(s: Dictionary) -> void: s.erase("ldv")
## How much of her readiness a refit costs: the crew must work up what has been changed. Moving a twentieth of her
## displacement costs 30%; small jobs a few per cent (owner's decision: refits are done at once and paid for in
## readiness, not in waiting).
func refit_readiness(s: Dictionary, tons_moved: float) -> float:
    if tons_moved <= 0.0: return 0.0
    return clampf(0.3 * tons_moved / (0.05 * maxf(float(hull(s).t), 300.0)), 0.02, 0.3)
func refit_done(s: Dictionary, tons_moved: float) -> void:
    s.rdy = maxf(RDY_MIN, readiness(s) - refit_readiness(s, tons_moved)); ship_refitted(s)
## Other navies refit their ships too (owner's decision): a ship may carry up to `marks` system upgrades, chosen so
## that she stays within her weight and topweight; a cruiser or a battleship may land torpedoes to pay for them.
func make_variant(s: Dictionary, marks: int) -> void:
    var d: Dictionary = hull(s); var up := {}; var opts: Array = ["hull", "fc", "eng", "tds", "turret", "mag", "radar"]; opts.shuffle()
    if d.kind == "merchant" or d.kind == "sub": return
    for k in opts:
        if up.size() >= marks: break
        var up2: Dictionary = up.duplicate(); up2[k] = 1
        var ld: Dictionary = BattleSim.loading(d, s.fit, up2)
        if float(ld.top) > BattleSim.TOP_SLACK: continue
        if float(ld.over_t) > 0.0:
            if not ["cl", "ca", "bb"].has(d.klass): continue
            var fit2: Array = s.fit.duplicate(); var landed := false
            for i in d.slots.size(): if d.slots[i].s == "T" and fit2[i] != "" and not landed: fit2[i] = ""; landed = true
            if not landed or float(BattleSim.loading(d, fit2, up2).over_t) > 0.0: continue
            s.fit = fit2
        up = up2
    if not up.is_empty(): s.up = up; ship_refitted(s)
## What a look through the glasses tells of a force's refits, for the contact panel ("" if none).
func refit_text(ships: Array) -> String:
    var n := 0; var kinds := {}
    for s in ships:
        var up = s.get("up")
        if up == null or up.is_empty(): continue
        n += 1
        for k in up: if BattleSim.UPGRADES.has(k): kinds[String(BattleSim.UPGRADES[k].name).to_lower()] = true
    if n == 0: return ""
    return "%d of them %s been refitted (%s)." % [n, "has" if n == 1 else "have", ", ".join(kinds.keys())]
func strength(ships: Array) -> float:
    var t = 0.0
    for s in ships: t += ship_value(s) * (0.3 + 0.7 * s.hullFrac)
    return t
func cargo_cap() -> int:
    var t = 0
    for s in all_ships(): t += int(hull(s).cargo)
    return t
## Cargo beyond the room in the holds (a ship sold, scuttled or sunk took her holds with her) and fuel beyond the
## bunkers: taken out of the stores, share and share alike, and returned as {good: tons} for the caller to sell or
## to write off.
func trim_cargo() -> Dictionary:
    var out := {}; var over: int = cargo_used() - cargo_cap()
    if over > 0:
        var used: float = maxf(1.0, cargo_used()); var left := over
        for g in C.GOODS:
            if g.id == "fuel" or left <= 0: continue
            var n: int = mini(left, int(ceil(float(G.cargo[g.id]) * over / used))); n = mini(n, int(floor(G.cargo[g.id])))
            if n > 0: G.cargo[g.id] -= n; out[g.id] = n; left -= n
        for g in C.GOODS:   # rounding: whatever is still over comes off the fullest
            if g.id == "fuel" or left <= 0: continue
            var n: int = mini(left, int(floor(G.cargo[g.id])))
            if n > 0: G.cargo[g.id] -= n; out[g.id] = int(out.get(g.id, 0)) + n; left -= n
    var fo: int = int(ceil(G.cargo.fuel)) - bunker_cap()
    if fo > 0 and bunker_cap() >= 0: G.cargo.fuel = float(bunker_cap()); out["fuel"] = fo
    return out
func cargo_text(lost: Dictionary) -> String:
    var parts := []
    for g in C.GOODS: if lost.has(g.id): parts.append("%d %s" % [int(lost[g.id]), String(g.name).to_lower()])
    return ", ".join(parts)
func cargo_used() -> int:
    var t = 0
    for g in C.GOODS: if g.id != "fuel": t += int(floor(G.cargo[g.id]))   # fuel lives in the bunkers, not the hold
    return t
func crew_need() -> int:
    var t = 0
    for s in all_ships(): t += int(hull(s).crew)
    return t
func crew_frac() -> float: return minf(1.0, G.crew / maxf(1.0, crew_need()))
func fuel_use() -> float:
    var t = 0.0
    for s in all_ships(): t += hull(s).fuel   # a detached main body steams too, and still fills the bunkers
    return t
## The reserve: the last few days of fuel kept back in the bunkers, burned at a third of the normal rate at a
## crawl once the bunkers are dry. When it is gone the squadron is dead in the water: call a friendly fleet by
## wireless for a tow or a merchant convoy for fuel. It fills again from the bunkers once you have fuel.
## Food eaten a day: a ton feeds about 400 men (the owner found the old rate, 250 men, too fast).
const FOOD_PER_MAN := 0.0025
func food_use() -> float: return (float(G.crew) + Structures.troops_all()) * FOOD_PER_MAN
func reserve_cap() -> float: return fuel_use() * 4.0
## Fuel oil the squadron can carry: forty days' steaming in the ships' own bunkers, plus the cargo tanks of its oilers.
func tank_cap() -> int:
    var t := 0
    for s in all_ships(): t += int(hull(s).get("tank", 0))
    return t
func bunker_cap() -> int: return int(ceil(fuel_use() * 40.0)) + tank_cap()
func fuel_room() -> int: return maxi(0, bunker_cap() - int(ceil(G.cargo.fuel)))
## Ships of yours with an auxiliary's fitting: "ammo" (ammunition ships), "repair" (repair ships), "tank", "troops".
func aux(field: String) -> Array: return G.fleet.filter(func(s): return hull(s).get(field, false))
func repair_cost(s: Dictionary) -> int: return int(ceil((1.0 - float(s.hullFrac)) * float(hull(s).price) * 0.2))

## Replenishment at sea, once a day. An ammunition ship passes shells across from the munitions in the holds (40 tons a
## day each); a repair ship patches the worst-damaged hulls with steel from the holds (15 tons a day each), up to
## three-quarters sound: the rest wants a dock. Both work under way; neither works without the cargo.
const AMMO_TONS := 120.0     # of rearming cost to a ton of munitions
const STEEL_TONS := 60.0    # of repair cost to a ton of steel
const SEA_REPAIR := 0.75
func rearm_tons(s: Dictionary) -> float: return rearm_cost(s) / AMMO_TONS
func _replenish() -> void:
    var ae: Array = aux("ammo"); var ar: Array = aux("repair")
    if not ae.is_empty():
        var budget: float = 40.0 * ae.size(); var want := false; var did := false
        var order: Array = G.fleet.duplicate(); order.sort_custom(func(a, b): return float(a.get("ammo", 1.0)) < float(b.get("ammo", 1.0)))
        for s in order:
            var need: float = rearm_tons(s)
            if need <= 0.01 or float(s.get("ammo", 1.0)) > 0.995: continue
            want = true
            var give: float = minf(need, minf(budget, float(G.cargo.munitions)))
            if give <= 0.0: break
            s.ammo = minf(1.0, float(s.get("ammo", 1.0)) + (1.0 - float(s.get("ammo", 1.0))) * give / need)
            if s.ammo > 0.995: s.ammo = 1.0
            G.cargo.munitions -= give; budget -= give; did = true
        if want and not did and float(G.cargo.munitions) < 1.0:
            if not G.get("ammoWarned", false): G.ammoWarned = true; toast.emit("The %s has nothing to pass across: no munitions in the holds. Buy munitions and she will rearm the squadron at sea." % ae[0].name)
        else: G.ammoWarned = false
        if did and not G.fleet.any(func(s): return float(s.get("ammo", 1.0)) < 0.995): toast.emit("Replenishment complete: the %s has filled every magazine." % ae[0].name)
    if not ar.is_empty():
        var budget: float = 15.0 * ar.size(); var want := false; var did := false
        var order: Array = G.fleet.duplicate(); order.sort_custom(func(a, b): return float(a.hullFrac) < float(b.hullFrac))
        for s in order:
            if float(s.hullFrac) >= SEA_REPAIR: continue
            want = true
            var per: float = float(hull(s).price) * 0.2 / STEEL_TONS          # tons of steel for the whole hull
            var give: float = minf((SEA_REPAIR - float(s.hullFrac)) * per, minf(budget, float(G.cargo.steel)))
            if give <= 0.0: break
            s.hullFrac = minf(SEA_REPAIR, float(s.hullFrac) + give / per); G.cargo.steel -= give; budget -= give; did = true
        if want and not did and float(G.cargo.steel) < 1.0:
            if not G.get("steelWarned", false): G.steelWarned = true; toast.emit("The %s has no plate to work with: no steel in the holds. Buy steel and she will patch your hulls at sea." % ar[0].name)
        else: G.steelWarned = false
        if did and not G.fleet.any(func(s): return float(s.hullFrac) < SEA_REPAIR - 0.001): toast.emit("The %s has made every ship seaworthy (75%%). The rest is dockyard work." % ar[0].name)

## A prize of a design new to you is measured and her drawings copied: research points at once (double for a design
## of an era you have not reached), and a naval base you hold can lay down the class from then on.
func studied(id: String) -> bool: return G.get("studied", []).has(id)
func study_prize(s: Dictionary) -> String:
    if not G.has("studied"): G.studied = []
    if G.studied.has(s.type): return ""
    G.studied.append(s.type)
    var h: Dictionary = hull(s)
    var rp: int = maxi(5, int(round(float(h.price) / 2500.0))) * (2 if int(h.era) > player_era() else 1)
    G.rp += rp; log_ev("Copied the drawings of the %s class (+%d RP)" % [h.dn, rp])
    return "Her drawings are copied: +%d RP. A naval base you hold can now build the %s class." % [rp, h.dn]
func reserve() -> float: return float(G.get("reserve", reserve_cap()))
func dead_in_water() -> bool: return G.player.get("towed") == null and (int(G.crew) <= 0 or (G.cargo.fuel <= 0 and reserve() <= 0.0 and fuel_use() > 0))

func wages() -> float:
    var t: float = G.crew * 0.15
    for o in G.officers: t += 40 * o.lvl
    t += (Structures.garrison_total() + Flag.garrison_total()) * 0.15   # the men holding your structures and ports ashore
    t += Flag.guards() * Flag.GUARD_PAY                                # guard squadrons on station
    t += Structures.troops_all() * Structures.TROOP_WAGE   # soldiers embarked in troopships
    return t
var show_origin := false   # the chart opens with the origin's story once, at the start of a campaign

func perk(k: String, default = null): return G.get("perks", {}).get(k, default)

## Hunter groups (and anything else that comes for you on sight) are hostile whatever your standing with their flag.
## Whether this force will fire on you. The armistice of 1945 holds: a flag's warships only engage you on sight if
## your standing with it has fallen to -60, if you caused an incident with it lately (opened fire under the
## armistice), or if your origin made you its declared target. Raiders, hunters and mission targets always fight.
func hostile_fleet(f: Dictionary) -> bool: return at_war(f.fac) or f.get("hunter", false) or f.get("mission", false) or f.get("kind", "") == "assault"
const WAR_STANDING := -60
const INCIDENT_DAYS := 90
func at_war(fac: String) -> bool:
    if fac == "raiders": return true
    if fac == "player": return false
    return G.rep.get(fac, 0) <= WAR_STANDING or G.get("nukedFacs", []).has(fac) or int(G.get("incidents", {}).get(fac, 0)) > G.day or (perk("outlaw", []) as Array).has(fac) or Diplomacy.commission_enemy(fac)
## Days left of an incident with this flag (0 if none).
func incident_days(fac: String) -> int: return maxi(0, int(G.get("incidents", {}).get(fac, 0)) - G.day)
## You fired on a flag's ships under the armistice: its warships engage you on sight for three months.
func incident(fac: String) -> void:
    if not G.has("incidents"): G.incidents = {}
    G.incidents[fac] = G.day + INCIDENT_DAYS

## Limited services at this flag's ports: your origin left you a stain there.
func restricted(fac: String) -> bool: return (perk("restricted", []) as Array).has(fac)

## Ports closed: a flag's harbours refuse you while your standing is below -10 (its ships may still keep the peace).
func hostile(fac: String) -> bool: return fac == "raiders" or G.rep.get(fac, 0) < -10
## The powers this one counts as enemies (hostile or at war), from Diplomacy's relations.
func enemies_of(f: String) -> Array: return Diplomacy.enemies(f)
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
    for s in ships:
        var up = s.get("up")
        m = minf(m, hull(s).kn * (0.75 + 0.25 * s.hullFrac) * (1.0 + 0.04 * (int(up.get("eng", 0)) if up != null else 0)) * load_speed(s))   # an overloaded ship holds the squadron back on passage too
    return m * 0.576
## The engine-room telegraph on the chart: speed as a share of cruising speed, and fuel burned a day as a share of
## the cruising burn (it rises steeply with speed, so slow steaming stretches the bunkers and flank speed drains them).
const SPEEDS := {"slow": [0.5, 0.35, "Slow", "Slow ahead"], "half": [0.75, 0.6, "Half", "Half ahead"], "cruise": [1.0, 1.0, "Cruise", "Cruising speed"],
    "full": [1.2, 1.6, "Full", "Full ahead"], "flank": [1.38, 2.4, "Flank", "Flank speed"]}
const SPEED_ORDER := ["slow", "half", "cruise", "full", "flank"]
func speed_order() -> String: return str(G.player.get("spd", "cruise"))
## Your squadron's speed on the chart at the ordered setting (before fuel, ice and tows).
func player_speed() -> float: return fleet_map_speed(G.fleet) * float(SPEEDS[speed_order()][0])
## Fuel burned a day at the ordered setting.
func fuel_burn() -> float: return fuel_use() * float(SPEEDS[speed_order()][1])

func fleet_turn_rate(ships: Array) -> float:
    var L = 0.0
    for s in ships: L = maxf(L, hull(s).L)
    return clampf(0.55 - L / 800.0, 0.15, 0.45)

# ------------------------------------------------------------------ supply: how big a fleet you can keep at sea
## The fleet is limited by what can supply it, not by a count of ten (owner's order of work, step 2; docs/SUPPLY.md).
## Every ship weighs on the supply train by her size (`supply_weight`); what the train can carry (`supply_cap`) comes
## from the flagship's own staff, the auxiliaries in company, a navy you serve and the harbours you hold. Over the
## limit the fleet still sails, but tenders must be hired by the day and the crews cannot be kept fresh; half as much
## again over it, no yard will hand you another ship. Twenty ships is the most one flag officer can handle at all,
## and ten the most that fight in one action (the rest stand off, as ships in reserve do).
const SUPPLY_W := {"pt": 1, "corvette": 1, "dd": 2, "ss": 2, "freighter": 1, "ap": 2, "ao": 1, "ae": 1, "ar": 1, "cl": 3, "ddg": 3, "ssn": 3, "cve": 4, "ca": 4, "cg": 5, "bb": 6, "cv": 7}
const SUPPLY_TRAIN := {"ao": 5, "ae": 4, "ar": 4, "freighter": 2}   # what an auxiliary in company adds
const SUPPLY_BASE := 16
const SUPPLY_MAX := 60
const SUPPLY_HIRE := 120          # a day, for each point over the limit: tenders hired to make up the difference
const SHIPS_MAX := 20
const BATTLE_MAX := 10
func supply_weight(s: Dictionary) -> int: return int(SUPPLY_W.get(hull(s).klass, 2))
func supply_need() -> int:
    var n := 0
    for s in all_ships(): n += supply_weight(s)
    return n
## Where the limit comes from: [what, points], the first being the flagship's own staff.
func supply_parts() -> Array:
    var out := [["Your flagship's staff and stores", SUPPLY_BASE]]
    var train := {}
    for s in all_ships():
        var k: String = hull(s).klass
        if SUPPLY_TRAIN.has(k): train[k] = int(train.get(k, 0)) + int(SUPPLY_TRAIN[k])
    for k in train: out.append([{"ao": "Oilers in company", "ae": "Ammunition ships", "ar": "Repair ships", "freighter": "Freighters carrying stores"}[k], int(train[k])])
    if G.get("commission") != null: out.append(["The dockyards of the %s" % GameData.fac[G.commission.fac].short, 8])
    var np: int = Flag.ports().size()
    if np > 0: out.append(["%d port%s under your flag" % [np, "" if np == 1 else "s"], np * 5])
    var nb := 0
    for s in Structures.held(): if s.kind == "navalbase" and not Structures.silenced(s): nb += 1
    if nb > 0: out.append(["%d naval base%s" % [nb, "" if nb == 1 else "s"], nb * 6])
    return out
func supply_cap() -> int:
    var c := 0
    for p in supply_parts(): c += int(p[1])
    return mini(c, SUPPLY_MAX)
func supply_over() -> int: return maxi(0, supply_need() - supply_cap())
func supply_upkeep() -> float: return supply_over() * float(SUPPLY_HIRE)
## The best readiness an overstretched fleet can hold: 100% within the limit, falling to 50% at half as much again.
func rdy_cap() -> float:
    var c := supply_cap()
    return clampf(1.0 - float(supply_need() - c) / maxf(1.0, float(c)), 0.5, 1.0)
## "" if a ship of this design can join you, or why not.
func can_add_ship(type: String) -> String:
    if all_ships().size() >= SHIPS_MAX: return "One flag officer cannot handle more than %d ships." % SHIPS_MAX
    var w := int(SUPPLY_W.get(GameData.hulls[type].klass, 2)); var c := supply_cap()
    if supply_need() + w > int(c * 1.5): return "Your supply train cannot keep her at sea (supply %d of %d, and she needs %d). Add an oiler, an ammunition ship or a repair ship, hold a port or a base, or part with a ship." % [supply_need(), c, w]
    return ""
func supply_text() -> String:
    var lines := []
    for p in supply_parts(): lines.append("%s: %d" % [p[0], int(p[1])])
    var over := supply_over()
    return "Supply %d of %d. %s%s" % [supply_need(), supply_cap(), "; ".join(lines) + ".", (" Over the limit by %d: tenders hired at %s a day, and readiness cannot be kept above %d%%." % [over, fmt(supply_upkeep()), int(rdy_cap() * 100)]) if over > 0 else ""]

# ------------------------------------------------------------------ the economy: wars, sieges, convoys and works
## Prices answer to the world (owner's order of work, step 2; docs/ECONOMY.md). Each port carries a shortage per good
## (`short`: 0 is normal, 0.3 is thirty per cent dearer, a little below nought is a glut) and the day each cause last
## bit (`why`), both saved. Convoys that arrive bring it down, convoys lost put it up, a siege or a blockade puts it
## up, and it wears off by a twentieth a day. A power's farms, steelworks, oil works and industry feed all its
## markets (`G.works`, worked out once a day): what is burning, taken or destroyed makes that good dearer everywhere
## under the flag. War demand is Diplomacy.price_mult.
const SHORT_MAX := 0.9
const FEEDS := {"farm": ["food"], "mine": ["steel"], "oil": ["fuel"], "industry": ["munitions", "electronics"], "nuclear": ["munitions", "electronics"]}
const WHY := {"convoy": "a convoy bound here was lost", "siege": "an attack on the port was beaten off", "taken": "the port changed hands", "blockade": "hostile ships lie off the port"}
func _econ(p: Dictionary) -> void:
    if not p.has("short"): p.short = {}; p.why = {}
    for g in C.GOODS: if not p.short.has(g.id): p.short[g.id] = 0.0
func _need(p: Dictionary) -> float:
    _econ(p); var t := 0.0
    for gid in p.short: t += float(p.short[gid])
    return t
func goods_ids() -> Array: return C.GOODS.map(func(g): return g.id)
## Push a port's shortage of some goods up (or down); `why` is a key of WHY, or "" for good news.
func shortage(p: Dictionary, goods: Array, amt: float, why := "") -> void:
    _econ(p)
    for gid in goods: p.short[gid] = clampf(float(p.short[gid]) + amt, -0.15, SHORT_MAX)
    if why != "": p.why[why] = int(G.day)
func works_mult(fac: String, gid: String) -> float: return float(G.get("works", {}).get(fac, {}).get(gid, 1.0))
## Everything the world does to a price at this port, as one factor (war demand, shortage, the flag's works).
func supply_mult(p: Dictionary, gid: String) -> float:
    _econ(p)
    return clampf(Diplomacy.price_mult(p.fac, gid) * (1.0 + float(p.short[gid])) * works_mult(p.fac, gid), 0.6, 2.4)
## Why prices here are what they are, as short phrases for the market page (newest causes only).
func market_notes(p: Dictionary) -> Array:
    _econ(p); var out := []
    for k in WHY: if p.why.has(k) and int(G.day) - int(p.why[k]) <= 20 and goods_ids().any(func(gid): return float(p.short[gid]) > 0.08): out.append(WHY[k])
    if p.fac != "player" and Diplomacy.POWERS.has(p.fac) and Diplomacy.POWERS.any(func(o): return Diplomacy.at_war(p.fac, o)): out.append("the %s is at war" % GameData.fac[p.fac].short)
    var lost := []
    for g in C.GOODS: if works_mult(p.fac, g.id) > 1.08: lost.append(String(g.name).to_lower())
    if lost.size(): out.append("works of this flag are burning or lost (%s)" % ", ".join(lost))
    var glut := []
    for g in C.GOODS: if float(p.short[g.id]) < -0.06: glut.append(String(g.name).to_lower())
    if glut.size(): out.append("convoys have lately landed %s" % ", ".join(glut))
    return out
## A convoy makes port: what it carries is landed. One that never arrives is missed.
func convoy_landed(f: Dictionary) -> void:
    if not f.has("dest") or f.get("cargo", {}).is_empty(): return
    var gl := []
    for gid in f.cargo: if float(f.cargo[gid]) > 0: gl.append(gid)
    shortage(G.ports[int(f.dest)], gl, -0.07)
func convoy_lost(f: Dictionary) -> void:
    if f.get("kind", "") != "convoy" or not f.has("dest") or f.get("missed", false): return
    f.missed = true
    var p: Dictionary = G.ports[int(f.dest)]; var gl := []
    for gid in f.get("cargo", {}): gl.append(gid)
    if gl.is_empty(): gl = goods_ids()
    shortage(p, gl, 0.12, "convoy")
    var worst := 0.0
    for gid in gl: worst = maxf(worst, float(p.short[gid]))
    if worst >= 0.3 and int(p.get("shortDay", -99)) < int(G.day) - 10:
        p.shortDay = int(G.day); Diplomacy.news("SHORTAGE. %s is running short: the convoys are not getting through, and prices there are climbing." % p.name, mdist(p.sx, p.sy, G.player.x, G.player.y) < 900.0)
## Once a day: shortages wear off, blockaded ports go short, and each flag's works are counted.
func econ_day() -> void:
    var hostile: Array = G.fleets.filter(func(f): return f.kind == "raiders" or f.kind == "patrol" or Structures._is_assault(f) or Flag.is_relief(f))
    for p in G.ports:
        _econ(p)
        for gid in p.short: p.short[gid] = float(p.short[gid]) * 0.95
        for f in hostile:
            if f.fac == p.fac or mdist(f.x, f.y, p.sx, p.sy) > 60.0: continue
            if f.kind == "raiders" or (p.fac == "player" and Flag.is_relief(f)) or (Diplomacy.POWERS.has(f.fac) and Diplomacy.POWERS.has(p.fac) and Diplomacy.at_war(f.fac, p.fac)):
                shortage(p, ["food", "fuel", "medicine"], 0.03, "blockade"); break
        # you blockade a port yourself by lying off it while at war with its flag
        if p.fac != "player" and not G.get("docked", false) and at_war(p.fac) and mdist(G.player.x, G.player.y, p.sx, p.sy) < 60.0: shortage(p, ["food", "fuel", "medicine"], 0.03, "blockade")
    var tot := {}; var up := {}; var held := {}
    for s in Structures.all():
        if not FEEDS.has(s.kind): continue
        var home: String = s.get("home", s.fac); var ok: bool = not s.get("nuked", false) and not Structures.silenced(s)
        for gid in FEEDS[s.kind]:
            var k: String = home + "|" + gid; tot[k] = int(tot.get(k, 0)) + 1
            if ok and s.fac == home: up[k] = int(up.get(k, 0)) + 1
            if ok and s.fac == "player" and home != "player": held[gid] = int(held.get(gid, 0)) + 1
    var w := {}
    for k in tot:
        var fg: PackedStringArray = k.split("|")
        if not w.has(fg[0]): w[fg[0]] = {}
        w[fg[0]][fg[1]] = 1.0 + 0.4 * (1.0 - float(up.get(k, 0)) / float(tot[k]))
    w["player"] = {}
    for gid in held: w["player"][gid] = maxf(0.7, 1.0 - 0.06 * int(held[gid]))   # works you hold feed your own harbours
    G.works = w

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

## A new campaign from an origin (see Origins and docs/LORE.md); navy picks the great navy for origins tied to one.
func new_game(start_key: String, navy := "concord", test := false) -> void:
    var st: Dictionary = Origins.build(start_key, navy) if Origins.INFO.has(start_key) else C.STARTS[start_key]
    var ports = []
    for p in C.ports:
        var q: Dictionary = p.duplicate(); q.merge(market_mods(p.fac)); q.officers = []; q.offDay = -99; ports.append(q)
    var pois = []
    for p in C.pois: var q: Dictionary = p.duplicate(); q.next = 0; pois.append(q)
    var rep = {}
    for f in GameData.fac: rep[f] = st.rep.get(f, 0)
    rep.raiders = -100
    G = {"v": SAVE_VERSION, "ports": ports, "pois": pois, "day": 1, "dayF": 0.0, "credits": st.credits, "rep": rep, "tech": [], "rp": 0, "fleet": [], "cargo": {}, "fleets": [], "nextId": 1, "kills": 0, "crew": 0, "officers": [], "story": 0, "mission": null, "log": [], "start": start_key, "movedToday": false,
        "origin": start_key, "navy": st.get("navy", ""), "perks": st.get("perks", {}).duplicate(true)}
    for f in st.fleet:
        var sh: Dictionary = new_ship(f[0], f[1], "player", [])
        var o: Dictionary = f[2] if f.size() > 2 else {}
        sh.hullFrac = float(o.get("hull", 1.0))
        var d: Dictionary = GameData.hulls[sh.type]
        for i in d.slots.size(): if o.get("strip", []).has(d.slots[i].s): sh.fit[i] = ""   # stripped mounts, for cargo and speed of turnaround
        G.fleet.append(sh)
    G.crew = int(round(crew_need() * float(st.get("crew", 1.0))))
    G.rp = int(G.perks.get("rp", 0))
    var o = new_officer(int(st.get("officer", 1))); o.ship = G.fleet[0].id; G.officers.append(o)
    # hunters stay on your trail for a while: until a given day
    for h in G.perks.get("hunted", []): h.until = int(h.days)
    G.repSeen = {}; G.repLog = {}
    for f in rep: if f != "raiders" and int(rep[f]) != 0: G.repLog[f] = {"Where you began (your origin)": int(rep[f])}
    for f in rep: G.repSeen[f] = int(rep[f])
    Diplomacy.ensure(st)
    Structures.ensure()
    Flag.apply()
    if test:
        G.test = true; _test_topup()
        for t in C.TECH: if not G.tech.has(t.id): G.tech.append(t.id)
    for g in C.GOODS: G.cargo[g.id] = st.cargo.get(g.id, 0)
    var p0: Dictionary = {}
    for p in G.ports: if p.name == st.port: p0 = p
    G.player = {"x": p0.sx, "y": p0.sy, "h": mang(p0.x, p0.y, p0.sx, p0.sy), "v": 0.0, "tx": null, "ty": null, "cool": 3.0, "destPort": null, "follow": null}
    # the clock starts at eight in the morning where you lie, not at midnight by the chart's meridian (the first
    # actions of a campaign used to be night actions, fought without radar)
    G.dayF = fposmod((8.0 - x_lon(p0.sx) / 15.0) / 24.0, 1.0)
    for i in 40: maintain_fleets(true)
    show_origin = Origins.INFO.has(start_key)
    toast.emit(date_str(1) + ". You put to sea from " + p0.name + ". Click the chart to set a course (Ctrl+Click adds waypoints, right-click a fleet for orders); scroll to zoom out to the whole world.")
    toast.emit("Wreck fields and abandoned bases (◇ on the chart) can be surveyed for salvage and research.")
    save()

## Test mode (title screen, New campaign): every technology, every design in every yard (world_map.yard_of), and
## money and research points that never run out.
func test_mode() -> bool: return G.get("test", false)
func _test_topup() -> void:
    G.credits = maxf(float(G.credits), 5000000.0); G.rp = maxi(int(G.rp), 5000)

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

## A port of the flag for a patrol to put out from, weighted by its garrison (campaign.json: Gatehold and Strelsk x3).
func _garrison_port(fac: String) -> Dictionary:
    var ps: Array = ports_of(fac); var tot := 0.0
    for p in ps: tot += float(p.get("garrison", 1))
    var r := randf() * tot
    for p in ps:
        r -= float(p.get("garrison", 1))
        if r <= 0: return p
    return ps.back()

func spawn_fleet(kind: String, fac: String, initial := false, mission = null) -> Dictionary:
    var P: Dictionary = G.player; var era = fac_era(mission.fac if mission != null else fac); var tl = enemy_tech(era); var scale = 1.0 + G.day / 120.0
    var f = {"id": G.nextId, "kind": kind, "fac": mission.fac if mission != null else fac, "h": randf() * TAU, "v": 0.0, "tx": null, "ty": null, "cool": 0.0, "ships": [], "cargo": {}}
    G.nextId += 1
    var pos = Vector2.ZERO; var from_id = -1
    for i in 30:
        if mission != null:
            var np: Dictionary = {}
            for p in G.ports: if p.name == mission.near: np = p
            pos = water_point(8, Vector2(np.sx, np.sy), 160)
        elif kind == "patrol": var p: Dictionary = _garrison_port(fac); pos = water_point(8, Vector2(p.sx, p.sy), 260)
        elif kind == "convoy": var p: Dictionary = ports_of(fac).pick_random(); pos = Vector2(p.sx, p.sy); from_id = p.id
        elif kind == "raiders" and not C.get("RAIDER_GROUNDS", []).is_empty() and randf() < 0.6:   # their favourite hunting grounds
            var g: Array = C.RAIDER_GROUNDS.pick_random(); pos = water_point(8, Vector2(g[0], g[1]), g[2])
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
        if dests.size() > 1 and randf() < 0.5:   # half the convoys sail for whichever port in reach is shortest of goods
            for p in dests: if _need(p) > _need(d) + 0.05: d = p
        f.dest = d.id; f.from = from_id
        for g in C.GOODS: if randf() < 0.55: f.cargo[g.id] = randi_range(15, 50) * n
        f.cargo.fuel = int(f.cargo.get("fuel", 0)) + randi_range(40, 120)   # bunker fuel to spare: a merchant will sell it
        f.cash = randi_range(8, 25) * 1000
    elif kind == "raiders": f.name = "Raider flotilla"; f.ships = build_by_budget(C.PATROL_POOL.raiders, (12000 + randf() * 30000) * scale, 6, "raiders", tl)
    else:
        f.captain = ["\"Hook\" Marlowe", "Ysolde Crane", "\"Bosun\" Teague", "Anika Vell", "Black Corwin", "Mother Grist", "\"Lantern\" Pike", "Severin Oakes"].pick_random()
        f.name = "Bounty: " + f.captain
        f.ships.append(new_ship("ca" if scale > 2.5 else "cl", null, "raiders", tl))
        f.ships.append_array(build_by_budget(["pt", "dd", "dd", "ss"], (30000 + randf() * 30000) * scale, 5, "raiders", tl))
        f.reward = round(strength(f.ships) * 0.35 / 500.0) * 500
    if f.ships.is_empty(): f.ships.append(new_ship("pt" if fac == "raiders" else "corvette", null, f.fac, tl))
    f.capt = {"patrol": randi_range(1, 5), "convoy": randi_range(1, 3), "raiders": randi_range(1, 4), "bounty": randi_range(4, 7), "mission": randi_range(3, 6)}.get(f.kind, randi_range(1, 4))
    # some ships have been through a yard since they were built: a bounty hunter's most of all, a raider's seldom
    var vp: float = {"patrol": 0.3, "bounty": 0.8, "mission": 0.5, "raiders": 0.12, "convoy": 0.1}.get(f.kind, 0.25)
    for sh in f.ships: if randf() < vp: make_variant(sh, 3 if f.kind == "bounty" else randi_range(1, 2))
    # and their crews are as good as their captain has made them: a green captain's are green, a renowned one's veterans
    for sh in f.ships: sh.xp = [0.0, 0.5, 1.5, 2.0, 4.0, 5.0, 7.0, 10.0][clampi(int(f.capt), 0, 7)]
    G.fleets.append(f)
    return f

func maintain_fleets(initial: bool) -> void:
    var count = func(k: String, fac := "") -> int: return G.fleets.filter(func(f): return f.kind == k and (fac == "" or f.fac == fac)).size()
    for fac in GameData.fac:
        if fac == "raiders" or fac == "player": continue   # your own flag sends out no patrols or convoys of its own yet
        var np = ports_of(fac).size()
        if np == 0: continue
        var want_patrol = 1 if fac == "enclave" else int(ceil(np * 0.7)) + (mini(3, int(G.day / 60)) if fac == "directorate" else 0)
        if count.call("patrol", fac) < want_patrol and (initial or randf() < 0.3): spawn_fleet("patrol", fac, initial)
        if fac != "enclave" and count.call("convoy", fac) < int(ceil(np * 0.6)) and (initial or randf() < 0.3): spawn_fleet("convoy", fac, initial)
    if count.call("raiders") < 6 and (initial or randf() < 0.3): spawn_fleet("raiders", "raiders", initial)
    for h in perk("hunted", []):
        if G.day > int(h.get("until", 0)): continue
        var have: int = G.fleets.filter(func(f): return f.get("hunter", false) and f.name == h.name).size()
        if have < int(h.max) and not initial and randf() < float(h.every): spawn_hunter(h)
    if count.call("bounty") < 2 and (initial or randf() < 0.08):
        var f = spawn_fleet("bounty", "raiders", initial)
        if not initial: toast.emit("Bounty posted on %s: %s." % [f.captain, fmt(f.reward)])

## A group sent after you (your origin's hunters): it appears some way off and casts about where you were last seen.
func spawn_hunter(h: Dictionary) -> Dictionary:
    var P: Dictionary = G.player; var fac: String = h.fac
    var f = {"id": G.nextId, "kind": "hunter", "hunter": true, "fac": fac, "name": h.name, "until": int(h.until), "h": randf() * TAU, "v": 0.0, "tx": null, "ty": null, "cool": 0.0, "ships": [], "cargo": {}}
    G.nextId += 1
    var pos := water_point(8, Vector2(P.x, P.y), 420.0)
    for i in 20:
        if mdist(pos.x, pos.y, P.x, P.y) > 220: break
        pos = water_point(8, Vector2(P.x, P.y), 420.0)
    f.x = pos.x; f.y = pos.y; f.home = {"x": pos.x, "y": pos.y}
    var tl = enemy_tech(fac_era(fac)); var pool: Array = C.PATROL_POOL.get(fac, C.PATROL_POOL.raiders)
    f.ships = build_by_budget(pool, float(h.budget) * (1.0 + G.day / 200.0), 4, fac, tl)
    if f.ships.is_empty(): f.ships.append(new_ship("dd", null, fac, tl))
    f.capt = randi_range(4, 7)   # they send a good man after you
    G.fleets.append(f)
    toast.emit("Word reaches you that a %s is searching for you." % h.name.to_lower())
    return f

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
    o.tx = wrap_x(x); o.ty = y; o.route = build_route(o, pts); o.ri = 0; o.rx = o.x; o.ry = o.y; o.wps = []
    return true

## Ctrl+Click on the chart: a further leg from the end of the course already set, through the sea lanes. The
## waypoint is remembered as a route index (o.wps), so the chart can mark it until the fleet has passed it.
func add_waypoint(o: Dictionary, x: float, y: float) -> bool:
    var r = o.get("route")
    if r == null or o.ri >= r.size() - 1: return set_course(o, x, y)
    var end: Vector2 = r[r.size() - 1]
    var pts: Array = [Vector2(wrap_x(x), y)] if sight_line(end.x, end.y, x, y) else find_path(Vector2(wrap_x(end.x), end.y), Vector2(x, y))
    if pts.is_empty(): return false
    var ext: Array = build_route({"x": end.x, "y": end.y}, pts)
    if not o.has("wps") or o.wps == null: o.wps = []
    o.wps.append(r.size() - 1)
    r.append_array(ext.slice(1)); o.tx = wrap_x(x); o.ty = y
    return true

func route_remaining(o: Dictionary) -> float:
    var r: Array = o.route; var d = Vector2(o.rx, o.ry).distance_to(r[o.ri + 1])
    # the length of the legs beyond the next waypoint changes only when a waypoint is passed or the route is replaced:
    # it is kept (a route across an ocean has hundreds of points, and this is asked for every fleet on every tick)
    var last: Vector2 = r[r.size() - 1]
    if o.get("remI", -1) != o.ri or o.get("remN", -1) != r.size() or o.get("remX") != last.x or o.get("remY") != last.y:
        var tail := 0.0
        for i in range(o.ri + 1, r.size() - 1): tail += r[i].distance_to(r[i + 1])
        o.remI = o.ri; o.remN = r.size(); o.remX = last.x; o.remY = last.y; o.remT = tail
    return d + float(o.remT)

## Advances along the route; true once the fleet has arrived. The fleet moves the way its bow points and steers onto
## the route through a turning circle (radius from the turn rate: the longer the ships, the wider), so it never slides
## sideways. Speed builds and bleeds off gradually; ships ease off for bends, in confined waters, in a hard turn and on
## the final approach.
func route_move(o: Dictionary, max_sp: float, turn: float, dt: float) -> bool:
    var r = o.get("route")
    if r == null or o.ri >= r.size() - 1: coast(o, dt); return true
    if near_land_cell(o.x, o.y): max_sp *= 0.5
    var cur := Vector2(o.rx, o.ry); var R := 1.2 / turn          # turning radius in map units (about 15-45 km)
    # pass waypoints already reached: the projection onto the current leg has run off its end
    while o.ri < r.size() - 1:
        var a: Vector2 = r[o.ri]; var b: Vector2 = r[o.ri + 1]; var ab := b - a; var L2 := ab.length_squared()
        var t := clampf((cur - a).dot(ab) / maxf(L2, 0.0001), 0.0, 1.0)
        if (t >= 0.999 or cur.distance_to(b) < 0.5) and o.ri < r.size() - 2: o.ri += 1
        # a point inside the turning circle and well off the bow can't be reached this time round: count it as
        # passed rather than orbit it for ever (close Ctrl+Click waypoints, or a slow ship on dry bunkers)
        elif cur.distance_to(b) < minf(R, o.v / maxf(turn * 0.5, 0.01)) * 1.2 + 0.3 and absf(ang_diff((b - cur).angle(), o.h)) > 1.2:
            if o.ri < r.size() - 2: o.ri += 1
            else: o.rx = cur.x; o.ry = cur.y; o.route = null; return true
        else: break
    # aim at a point a little way along the route: further ahead the faster we go
    var a0: Vector2 = r[o.ri]; var b0: Vector2 = r[o.ri + 1]; var ab0 := b0 - a0
    var proj: Vector2 = a0 + ab0 * clampf((cur - a0).dot(ab0) / maxf(ab0.length_squared(), 0.0001), 0.0, 1.0)
    var look := maxf(R * 1.5, 3.0); var aim := proj; var k: int = o.ri
    while look > 0 and k < r.size() - 1:
        var seg_end: Vector2 = r[k + 1]; var sl := aim.distance_to(seg_end)
        if sl >= look: aim += (seg_end - aim) / maxf(sl, 0.0001) * look; look = 0
        else: aim = seg_end; look -= sl; k += 1
    var end: Vector2 = r[r.size() - 1]; var rem = route_remaining(o)
    # a watch on her progress: under way for four seconds and no nearer the end of the route, she is jammed against
    # the land (a leg of the route clips the coast in a few tight places): `jam` counts it, for `unjam` to act on
    o.prT = float(o.get("prT", 0.0)) + dt
    if o.prT >= 4.0:
        if max_sp > 0.5 and float(o.get("prR", INF)) - rem < 0.3: o.jam = 1; o.jams = int(o.get("jams", 0)) + 1
        else: o.jam = 0; o.jams = 0
        o.prT = 0.0; o.prR = rem
    if rem < maxf(0.6, o.v * dt * 1.5) and o.ri >= r.size() - 2:   # arrived
        o.rx = end.x; o.ry = end.y; o.x = wrap_x(end.x); o.y = end.y; o.route = null; return true
    var want := (aim - cur).angle(); var err := ang_diff(want, o.h)
    # speed: ease for bends ahead and on the final approach; a hard turn costs some way, as at sea, but not most of it
    var bend = 0.0; var pp = cur; var ph = want; var la = maxf(15.0, o.v * 2.5)
    for i in range(o.ri + 1, r.size()):
        if la <= 0: break
        var h: float = (r[i] - pp).angle(); bend += absf(ang_diff(h, ph)); la -= pp.distance_to(r[i]); pp = r[i]; ph = h
    var target = max_sp * clampf(1 - bend / 2.4, 0.5, 1.0)
    if not o.get("noBrake", false): target = minf(target, sqrt(2 * max_sp * 0.5 * rem) + 0.4)
    target *= lerpf(1.0, 0.65, clampf(absf(err) / PI, 0.0, 1.0))
    o.v = o.v + clampf(target - o.v, -max_sp * 0.6 * dt, max_sp * 0.3 * dt)
    # the bow swings at the rate the turning circle allows at this speed (slowly when barely under way)
    var rate := maxf(o.v / R, turn * 0.5)
    o.h = wrapf(o.h + clampf(err, -rate * dt, rate * dt), -PI, PI)
    var step := Vector2.from_angle(o.h) * maxf(0.0, o.v * dt); var nxt := cur + step
    if on_land(nxt.x, nxt.y):
        # never run aground cutting a corner. Land is ahead: make for the route by the first way that is open, the
        # point steered for, the nearest point of the leg she is on, its next waypoint, then feeling round to either
        # hand of the course. (Only the first was tried: a ship that left harbour pointing at the shore could wedge
        # in a corner of the coast with the point she steered for across a headland, and lie there for ever.)
        var sl := maxf(step.length(), 0.05); var found := false; var probe := maxf(sl, 1.0)   # look a cell ahead, not a ship's length
        var tries: Array = [aim - cur, proj - cur, b0 - cur]
        for da in [0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.6, -1.6, 2.0, -2.0, 2.4, -2.4, 2.8, -2.8, PI]: tries.append(Vector2.from_angle(want + da))   # right round, astern last
        for dv in tries:
            if dv.length_squared() < 0.000001: continue
            var cand: Vector2 = cur + dv.normalized() * minf(sl, maxf(dv.length(), sl)); var ahead: Vector2 = cur + dv.normalized() * probe
            if not on_land(cand.x, cand.y) and not on_land(ahead.x, ahead.y):
                nxt = cand; found = true
                o.h = wrapf(o.h + clampf(ang_diff(dv.angle(), o.h), -rate * dt * 4.0, rate * dt * 4.0), -PI, PI)   # her bow comes round to the way she is going
                break
        if not found: nxt = cur
    o.rx = nxt.x; o.ry = nxt.y; o.x = wrap_x(nxt.x); o.y = nxt.y
    return false

## A fleet (or you) jammed against the land: plan the course again from where she lies; if that jams too, the pilot
## takes her clear to the nearest water with sea room and plans from there.
func unjam(o: Dictionary) -> void:
    var n := int(o.get("jams", 1)); var tx = o.get("tx"); var ty = o.get("ty")
    if n >= 2:
        for rad in [2.0, 3.5, 5.0, 7.0, 10.0]:
            var done := false
            for k in 16:
                var q := Vector2(o.x + cos(k * TAU / 16.0) * rad, o.y + sin(k * TAU / 16.0) * rad)
                if not land_near(q.x, q.y, 2.2) and bare_line(o.x, o.y, q.x, q.y): o.x = wrap_x(q.x); o.y = q.y; o.rx = o.x; o.ry = o.y; done = true; break
            if done: break
    var keep_port = o.get("destPort")
    if tx == null or not set_course(o, tx, ty): o.route = null
    if keep_port != null: o.destPort = keep_port
    o.jam = 0; o.jams = n; o.prT = 0.0; o.prR = INF   # acted on once: the watch starts again
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
    if not G.has("reserve"): G.reserve = reserve_cap()
    if moved and P.get("towed") == null:
        var burn: float = fuel_burn() * (1.5 if in_ice(P.x, P.y) else 1.0) * Weather.fuel_mult(weather_here())
        if G.cargo.fuel > 0: G.cargo.fuel -= burn
        else:
            G.reserve = maxf(0.0, float(G.reserve) - burn / 3.0)
            if G.reserve <= 0.0 and not G.get("deadWarned", false):
                G.deadWarned = true
                toast.emit("The reserve is gone. Your squadron is dead in the water. Send a distress call (the red button below) and the nearest warship will come and tow you to port; or right-click the sea to call a merchant convoy, which can sell you fuel.")
        if G.cargo.fuel < 0:
            G.cargo.fuel = 0
            if not G.get("noFuelWarned", false): toast.emit("Bunkers are dry. The squadron crawls on its reserve, about %d days of it. Buy fuel oil at a port, or from a merchant convoy." % int(ceil(reserve() / maxf(0.1, fuel_use() / 3.0)))); G.noFuelWarned = true
        elif G.cargo.fuel > 0: G.noFuelWarned = false
    # the reserve fills again from the bunkers
    if G.cargo.fuel > 0 and reserve() < reserve_cap():
        var k: float = minf(reserve_cap() - reserve(), G.cargo.fuel); G.reserve = reserve() + k; G.cargo.fuel -= k; G.deadWarned = false
    if moved and in_ice(P.x, P.y):   # (this sat inside the reserve's refill, so ice only bit while the reserve was short)
        for s in G.fleet: s.hullFrac = maxf(0.05, s.hullFrac - 0.015)
        if not G.get("iceWarned", false): toast.emit("Pack ice. Speed is cut, fuel burn rises and the ice grinds at your hulls."); G.iceWarned = true
    elif not in_ice(P.x, P.y): G.iceWarned = false
    _storm_day(moved)
    _readiness_day(moved)
    G.cargo.food -= food_use()
    if G.cargo.food < 0:
        G.cargo.food = 0; var lost = int(ceil(G.crew * 0.03)); G.crew -= lost
        if lost: toast.emit("No food aboard. %d sailors deserted." % lost)
    G.credits -= wages() + supply_upkeep()
    if supply_over() > 0 and not G.get("supplyWarned", false):
        G.supplyWarned = true; toast.emit("Your fleet has outgrown its supply (%d of %d): tenders are hired at %s a day and the crews cannot be kept fresh. Add auxiliaries, hold a port, or part with a ship." % [supply_need(), supply_cap(), fmt(supply_upkeep())])
    elif supply_over() == 0: G.supplyWarned = false
    if G.credits < 0:
        var lost = int(ceil(G.crew * 0.05)); G.crew -= lost; G.credits = 0; toast.emit("Pay is in arrears. %d sailors walked off." % lost)
    for p in G.ports:
        for g in C.GOODS: p.drift[g.id] = clampf(p.drift[g.id] * 0.93 + (randf() - 0.5) * 0.05, -0.3, 0.45)
    econ_day()
    rep_note("Other dealings")
    for k in G.rep: G.rep[k] = clampi(int(G.rep[k]), -100, 100)   # standing has a floor and a ceiling, whatever pushed it
    rep_note("Beyond the limits of -100 and 100 (not counted)")
    maintain_fleets(false)
    Diplomacy.new_day()
    Structures.new_day()
    Flag.new_day()
    _replenish()
    if G.get("test", false): _test_topup()
    if G.day % 3 == 0: save()   # autosave every few days at sea
    _research_day()

## A day in a storm at sea knocks small ships about; the first day of one is announced, and so is its passing.
func _storm_day(moved: bool) -> void:
    var wx: Dictionary = weather_here(); var s: int = int(wx.sea)
    if s >= 3 and not G.get("docked", false):
        var hurt := []
        for sh in G.fleet:
            var h: Dictionary = hull(sh)
            if float(h.t) < 2500.0 and h.kind != "sub" and moved: sh.hullFrac = maxf(0.05, float(sh.hullFrac) - randf_range(0.01, 0.03)); hurt.append(sh.name)
        if not G.get("stormWarned", false):
            G.stormWarned = true
            toast.emit("A storm. Speed is cut, fuel burn rises, aircraft cannot fly and nobody sees far%s. Heave to, or run for the edge of it." % ((". Your small ships are taking damage: " + ", ".join(hurt)) if not hurt.is_empty() else ""))
    elif G.get("stormWarned", false):
        G.stormWarned = false; toast.emit("The storm has blown itself out: %s." % String(Weather.SEA[s]))

## One tick of the chart: the calendar, your task force, and every other fleet. Emits encounter() on contact.
func update(dt: float) -> void:
    if paused or G.is_empty(): return
    var P: Dictionary = G.player; P.cool = maxf(0.0, P.cool - dt)
    G.dayF += dt * 0.1
    if G.dayF >= 1:
        G.dayF -= 1; new_day(G.movedToday); G.movedToday = false
    _sight_t -= dt
    if _sight_t <= 0.0: _sight_t = 0.4; _sighting()
    P.noBrake = P.follow != null
    if P.follow != null:
        var f = _fleet(P.follow); P.repathT = P.get("repathT", 0.0) - dt
        if f == null or not f.get("vis", true): P.follow = null; toast.emit("Contact lost.")
        elif P.repathT <= 0:
            var d = mdist(P.x, P.y, f.x, f.y); P.repathT = 2.0 if d > 300 else 0.6
            var lead = minf(d / maxf(0.5, fleet_map_speed(G.fleet)), 12.0)
            var lx: float = f.x + cos(f.h) * f.v * lead; var ly: float = f.y + sin(f.h) * f.v * lead
            if not set_course(P, f.x if on_land(lx, ly) else lx, f.y if on_land(lx, ly) else ly): set_course(P, f.x, f.y)
    # escorting a fleet: keep station a little astern of it, at its speed, without making contact
    var esc = null
    if P.get("escort") != null:
        esc = _fleet(P.escort); P.repathT = P.get("repathT", 0.0) - dt
        if esc == null: P.escort = null; toast.emit("The fleet you were escorting has made harbour or gone. You are on your own again.")
        elif P.repathT <= 0:
            var d := mdist(P.x, P.y, esc.x, esc.y); P.repathT = 1.5 if d > 200 else 0.5
            var st := Vector2(esc.x, esc.y) - Vector2.from_angle(esc.h) * 6.0
            if on_land(st.x, st.y): st = Vector2(esc.x, esc.y)
            if mdist(P.x, P.y, st.x, st.y) < 1.5: P.route = null
            elif not set_course(P, st.x, st.y): set_course(P, esc.x, esc.y)
    # under tow: if the tug is gone the hawser is too; if the course was lost (a contact on the way cleared it), the tow
    # resumes for its harbour. (You used to lie there for ever, towed by nobody to nowhere, with no distress button.)
    if P.get("towed") != null:
        if _fleet(P.towed) == null: P.towed = null; toast.emit("The ship towing you is gone. You are adrift again.")
        elif P.get("route") == null:
            var hp = G.ports[int(P.destPort)] if P.get("destPort") != null else nearest_open_port()
            if hp == null or not set_course(P, hp.sx, hp.sy): P.towed = null
            else: P.destPort = int(hp.id)
    var ice = in_ice(P.x, P.y)
    var wx: Dictionary = weather_here()
    if P.get("route") != null:
        var no_fuel: bool = G.cargo.fuel <= 0 and fuel_use() > 0
        var sp = (fleet_map_speed(G.fleet) * 0.2 if no_fuel else player_speed()) * (0.4 if ice else 1.0)
        sp *= Weather.speed_mult(wx, G.fleet)   # a head sea
        sp *= 0.35 + 0.65 * crew_frac()   # short-handed in the stokeholds: less steam
        if dead_in_water(): sp = 0.0
        if int(G.crew) <= 0 and not G.get("nocrewWarned", false):
            G.nocrewWarned = true; toast.emit("There is not a soul aboard to raise steam. Your ships drift. Call a friendly fleet by wireless for a tow, then hire a crew in port.")
        elif int(G.crew) > 0: G.nocrewWarned = false
        var tow = _fleet(P.towed) if P.get("towed") != null else null
        if tow != null: sp = minf(fleet_map_speed(G.fleet), fleet_map_speed(tow.ships) * 0.55)   # under tow: slow, but moving
        if esc != null: sp = minf(sp, maxf(esc.v, 0.5) + maxf(0.0, mdist(P.x, P.y, esc.x, esc.y) - 6.0) * 0.6 + 0.3)   # close up, then match her speed
        G.movedToday = sp > 0.0
        if sp <= 0.0: coast(P, dt)   # dead in the water: way comes off her, and she drifts to a stop
        elif int(P.get("jam", 0)) > 0 and P.get("tx") != null: unjam(P)
        elif route_move(P, sp, fleet_turn_rate(G.fleet), dt):
            P.tx = null; P.route = null
            if P.follow == null and P.get("escort") == null: _arrive()
            else: P.repathT = 0.0
    else: coast(P, dt)
    Diplomacy.clash_tick(dt)
    Structures.tick(dt)
    var ps = strength(G.fleet)
    var pr := strike_reach(G.fleet, Weather.air_ok(weather_here(), has_tech("jets")))
    # per tick, not per fleet: how far you see, and which flags are at war with you (this loop runs for every fleet in
    # the world on every tick, eight times a frame at 8x, so nothing in it is worked out twice)
    var ky := ck_you(wx); var war := {}
    for f in G.fleets.duplicate():
        f.cool = maxf(0.0, f.cool - dt)
        if P.get("towed") != null and f.id == P.towed:   # the towing ship keeps station ahead of you on the hawser
            f.x = wrap_x(P.x + cos(P.h) * 2.5); f.y = P.y + sin(P.h) * 2.5; f.h = P.h; f.v = P.v; f.route = null
            continue
        var dP = mdist(f.x, f.y, P.x, P.y)
        if not war.has(f.fac): war[f.fac] = at_war(f.fac)
        var hos: bool = war[f.fac] or f.get("hunter", false) or f.get("mission", false) or f.kind == "assault"   # as hostile_fleet()
        var rate = 0.6
        if hos and f.cool <= 0 and P.cool <= 0 and dP < SIGHT * fleet_watch(f) * ck_them(f, wx) and not f.ships.all(func(s): return hull(s).kind == "merchant"):   # a hunter that cannot see you does not chase
            var chase: bool = strength(f.ships) > ps * 0.5 or f.get("mission", false)
            f.chaseT = f.get("chaseT", 0.0) - dt; rate = 1.0 if chase else 0.95
            if f.chaseT <= 0 or f.get("route") == null:
                f.chaseT = 1.2
                var fx: float = P.x if chase else f.x - wdx(f.x, P.x) * 1.5; var fy: float = P.y if chase else clampf(f.y + (f.y - P.y) * 1.5, 20, MH - 20)
                if not set_course(f, fx, fy): f.route = null
            f.chasing = chase
        else:
            if f.get("chasing", false): f.chasing = false; f.route = null
            if f.get("body", false):   # your main body, left astern when the fast division was detached: it follows you
                f.ansT = f.get("ansT", 0.0) - dt; rate = 1.0
                if dP < 6.0: f.route = null
                elif f.ansT <= 0.0:
                    f.ansT = 1.5
                    if not set_course(f, P.x, P.y): f.route = null
                if f.get("join", false) and dP < 14.0: rejoin(); continue
            elif f.get("answering", false):   # answering your wireless call: steam to where you are
                f.ansT = f.get("ansT", 0.0) - dt
                if f.ansT <= 0.0:
                    f.ansT = 1.5
                    if not set_course(f, P.x, P.y): f.answering = false
                rate = 1.0
            elif f.get("route") == null:
                if Flag.is_relief(f):   # a relief force bound for a port of yours
                    if mdist(f.x, f.y, f.tgt.x, f.tgt.y) < 10.0 or not set_course(f, f.tgt.x, f.tgt.y): Flag.relief_lands(f); continue
                elif Structures._is_assault(f):   # an assault force bound for your structure: land, or get back on course
                    var tg: Dictionary = f.get("tgt", {"x": f.x, "y": f.y})
                    if mdist(f.x, f.y, tg.x, tg.y) < 8.0: Structures.assault_lands(f); continue
                    if not set_course(f, tg.x, tg.y): Structures.assault_lands(f); continue
                elif f.has("dest") and f.get("started", false):
                    if int(f.get("escort", 0)) > 0: Diplomacy.on_convoy_arrived(f)
                    if f.fac == "player": Flag.convoy_arrived(f)
                    convoy_landed(f)
                    G.fleets.erase(f); continue
                if Structures._is_assault(f) or Flag.is_relief(f): pass
                elif f.has("dest"):
                    f.started = true; var d: Dictionary = G.ports[f.dest]
                    f.route = build_route(f, port_route(f.from, f.dest)); f.ri = 0; f.rx = f.x; f.ry = f.y; f.tx = d.sx; f.ty = d.sy
                elif f.get("hunter", false):
                    if G.day > f.until and dP > 200: G.fleets.erase(f); continue   # the trail has gone cold
                    var w = water_point(6, Vector2(P.x, P.y), 140.0)   # casting about where you were last reported
                    if not set_course(f, w.x, w.y): f.route = null
                else:
                    var w = water_point(6, Vector2(f.home.x, f.home.y), 120.0 if (f.get("mission", false) or f.kind == "bounty") else 320.0)
                    if not set_course(f, w.x, w.y): f.route = null
        # a fleet's own speed and turning circle change only with its ships and their damage: looked at again a few times a second
        _spd_n += 1
        if not f.has("msp") or (_spd_n + int(f.id)) % 24 == 0: f.msp = fleet_map_speed(f.ships); f.mtr = fleet_turn_rate(f.ships)
        var fsp = float(f.msp) * rate * (0.4 if in_ice(f.x, f.y) else 1.0) * Weather.speed_mult(wx if dP < 400.0 else Weather.CLEAR, f.ships)   # the same sea slows those near you
        if int(f.get("escort", 0)) > 0 and dP > 45.0: fsp = 0.0   # an escorted convoy waits for its escort
        if f.get("route") != null:
            var was := Vector2(f.x, f.y)
            if int(f.get("jam", 0)) > 0: unjam(f)
            elif route_move(f, fsp, float(f.mtr), dt): f.route = null
            # wedged against a headland in narrow waters: after a few seconds, plan again from here
            elif fsp > 0.0 and was.distance_to(Vector2(f.x, f.y)) < 0.001:
                f.stuckT = f.get("stuckT", 0.0) + dt
                if f.stuckT > 3.0:
                    f.stuckT = 0.0; var tx = f.get("tx"); var ty = f.get("ty")
                    if tx == null or not set_course(f, tx, ty): f.route = null
            else: f.stuckT = 0.0
        # contact: hostile forces engage at the longer of the two sides' reach; an intercept closes to gun range.
        # A force that has been met stays quiet until the range opens past its reach again.
        # Weather and darkness: each side finds the other only as far as it can see (or its radar reaches), and
        # carriers reach out only when their aircraft can fly.
        var kt := ck_them(f, wx) if hos else 1.0
        var reach := maxf(strike_reach(f.ships, Weather.air_ok(wx, fac_era(f.fac) >= 2)) * kt, pr * ky) if hos else 0.0
        if f.get("met", false) and dP > maxf(reach, CONTACT) * 1.2: f.met = false
        var close_in: bool = ((P.follow == f.id or f.get("answering", false)) and dP < CONTACT * maxf(ky, 0.35)) or (hos and dP < CONTACT * maxf(kt, ky))   # inside gun range, whoever sees the other brings on the action
        if f.cool <= 0 and P.cool <= 0 and not G.get("docked", false) and (close_in or (hos and dP < reach and not f.get("met", false))):
            f.met = true; f.vis = true; f.contactKm = int(round(dP * KM_PER_UNIT / 5.0) * 5); paused = true; encounter.emit(f); return

# ------------------------------------------------------------------ divisions, reserve and readiness
## Every ship you own: the squadron you sail with and, when a fast division is detached, the main body left astern.
func body():
    for f in G.fleets: if f.get("body", false): return f
    return null
func all_ships() -> Array:
    var b = body()
    return G.fleet + b.ships if b != null else G.fleet
## Detach a fast division: you go on with these ships, and the rest become the main body, which follows at its own
## speed. It is a fleet like any other while it is apart: powers at war with you will fight it if they meet it.
func detach(fast: Array) -> String:
    if body() != null: return "The main body is already detached."
    var rest: Array = G.fleet.filter(func(s): return not fast.has(s))
    if fast.is_empty() or rest.is_empty(): return "Mark some ships, and leave some."
    var P: Dictionary = G.player
    var f = {"id": G.nextId, "kind": "division", "fac": "player", "h": P.h, "v": 0.0, "tx": null, "ty": null, "cool": 0.0, "ships": rest, "cargo": {},
        "x": P.x, "y": P.y, "home": {"x": P.x, "y": P.y}, "body": true, "join": false, "name": "Your main body"}
    # soldiers stay with the transports they are in: those berthed in the main body go with it
    var berths := func(list: Array) -> int:
        var n := 0
        for s in list: n += int(hull(s).get("troops", 0))
        return n
    var all_b: int = berths.call(G.fleet); var away: int = int(round(float(Structures.troops()) * berths.call(rest) / all_b)) if all_b > 0 else 0
    f.troops = away; G.troops = Structures.troops() - away
    G.nextId += 1; G.fleets.append(f); G.fleet = fast
    for s in G.fleet: s.erase("fast")
    return "The fast division parts company: %d ships at %d knots. The main body (%d ships) follows at %d." % [fast.size(), int(fleet_map_speed(fast) / 0.576 * 0.7), rest.size(), int(fleet_map_speed(rest) / 0.576 * 0.7)]
func rejoin() -> void:
    var b = body()
    if b == null: return
    G.fleet.append_array(b.ships); G.fleets.erase(b); G.troops = Structures.troops() + int(b.get("troops", 0))
    toast.emit("The main body rejoins: %d ships in company." % G.fleet.size())

## Readiness: how fresh a ship's company and machinery are, 1 down to RDY_MIN. Steaming wears it (faster at full
## speed and in a storm, not at all at Slow), a battle costs a tenth and more for damage taken; lying hove to brings
## it back slowly and rest in port quickly. In battle a tired ship reloads, steams and fights fires as if short of crew.
const RDY_MIN := 0.3
func readiness(s: Dictionary) -> float: return float(s.get("rdy", 1.0))
func fleet_readiness() -> float:
    var m := 1.0
    for s in all_ships(): m = minf(m, readiness(s))
    return m
func _readiness_day(moved: bool) -> void:
    var d := 0.0
    if not moved: d = 0.012
    else:
        var k: float = {"slow": 0.0, "half": 0.5, "cruise": 1.0, "full": 1.8, "flank": 3.0}[speed_order()]
        d = -0.004 * k * (2.5 if int(weather_here().sea) >= 3 else (1.4 if int(weather_here().sea) == 2 else 1.0))
    var top := rdy_cap()   # an overstretched supply train cannot keep crews fresh: readiness above what it allows wastes away
    for s in all_ships(): s.rdy = clampf(readiness(s) + d, RDY_MIN, 1.0) if readiness(s) <= top else maxf(top, readiness(s) + minf(d, 0.0) - 0.02)
    var low := fleet_readiness()
    if low < 0.55 and not G.get("rdyWarned", false):
        G.rdyWarned = true; toast.emit("Your crews are worn out (readiness %d%%): tired ships reload and steam slower and fight fires badly. Rest them in port (Repairs & crew), or heave to." % int(low * 100))
    elif low > 0.7: G.rdyWarned = false
## Days alongside: the calendar runs on (wages, food, the world's business) and the crews rest.
func rest_in_port(days: int) -> void:
    G.docked = true; var was_paused: bool = paused; paused = false
    var b = body(); var near: bool = b == null or mdist(b.x, b.y, G.player.x, G.player.y) < 30.0   # a main body far astern is not alongside
    for i in days:
        G.day_rest = true
        # the world does not stop for you: every other fleet steams on through the day (convoys arrive, relief
        # forces close, patrols fight), while you lie alongside, out of their reach
        var d0: int = G.day; G.movedToday = false; var guard := 0
        while int(G.day) == d0 and guard < 400: update(0.1); guard += 1
        for s in (all_ships() if near else G.fleet): s.rdy = maxf(readiness(s), minf(rdy_cap(), readiness(s) + 0.1))
    G.docked = false; G.erase("day_rest"); paused = was_paused; save()
func days_to_rest() -> int: return int(ceil((1.0 - fleet_readiness()) / 0.112))

# ------------------------------------------------------------------ what you can see of the world's fleets
## You see a fleet on the chart only while somebody of yours has it in sight: your squadron (lookouts and radar about
## 550 km, search aircraft from a carrier to their reach, all cut by weather and darkness), your main body and guard
## squadrons, the fleets of the flag you serve and its coalition, and the ports and structures you hold (radar
## stations and airfields farthest). Your own and allied fleets, a convoy you escort, a fleet answering your call and
## an assault your radar has reported are always shown. A fleet that passes out of sight is kept for five days as a
## grey mark where it was last seen.
const SIGHT := 100.0
const GHOST_DAYS := 5
var _sight_t := 0.0
var _spd_n := 0
func friendly_fac(fac: String) -> bool:
    if fac == "player": return true
    var cm = G.get("commission")
    if cm == null: return false
    return fac == cm.fac or (Diplomacy.coalition_of(fac) != "" and Diplomacy.coalition_of(fac) == Diplomacy.coalition_of(cm.fac))
func always_seen(f: Dictionary) -> bool:
    return friendly_fac(f.fac) or int(f.get("escort", 0)) > 0 or f.get("answering", false) or f.get("warned", false) or G.player.get("escort") == f.id
## How far your squadron sees other fleets on the chart, in map units: lookouts and radar about 550 km on a clear
## day, a carrier's search aircraft three times as far as her strike reaches, all cut by weather and darkness.
func sight_radius() -> float: return maxf(maxf(eye_radius(), radar_radius()), air_radius())
## Its three parts, each a ring on the chart: your lookouts, your radar (0 without the research), and a carrier's
## search aircraft (0 with no carrier, or when they cannot fly). The captain of your flagship sets how sharp a watch
## is kept (lookouts and the radar plot); the aircraft reach as far as they fly.
func eye_radius() -> float: return SIGHT * your_watch() * Weather.contact_mult(weather_here(), false)
func radar_radius() -> float: return SIGHT * your_watch() * Weather.contact_mult(weather_here(), true) if has_tech("radar") else 0.0
func air_radius() -> float:
    var wx: Dictionary = weather_here(); var r := strike_reach(G.fleet, Weather.air_ok(wx, has_tech("jets")))
    return r * 3.0 * ck_you(wx) if r > 120.0 / KM_PER_UNIT + 1.0 else 0.0
## How far off a hostile force notices you and gives chase (map units): with lookouts alone, or with radar; under the
## captain given (a fleet), or an average one.
func found_radius(radar: bool, f = null) -> float:
    return SIGHT * Weather.contact_mult(weather_here(), radar) * signature() * (fleet_watch(f) if f != null else watch(3))
## The watch a captain keeps (owner's decision): how far a force sees is not fixed, it follows its captain. The same
## base distance (SIGHT) for you and for every other fleet, times this: a green captain (level 1) 87%, a seasoned one
## (level 4) 108%, the best (level 8) 136%; a squadron with no captain in the flagship 80%.
func watch(lvl: float) -> float: return 0.8 + 0.07 * clampf(lvl, 0.0, 8.0)
func your_watch() -> float:
    if G.fleet.is_empty(): return watch(0)
    var o = officer_of(G.fleet[0])
    return watch(float(o.lvl) if o != null else 0.0)
## A fleet's captain: set when it is formed (`capt`); fleets from older saves get one by their number.
func fleet_capt(f: Dictionary) -> int:
    if f.has("capt"): return int(f.capt)
    return 1 + int(f.id) % 4 + (2 if f.get("hunter", false) or f.get("mission", false) or f.get("kind", "") == "bounty" else 0)
func fleet_watch(f: Dictionary) -> float: return watch(fleet_capt(f))
const CAPT_WORD := ["green", "green", "able", "able", "seasoned", "seasoned", "veteran", "veteran", "renowned"]
func capt_text(f: Dictionary) -> String: return "%s captain (level %d)" % [CAPT_WORD[clampi(fleet_capt(f), 0, 8)], fleet_capt(f)]
func _sighting() -> void:
    var P: Dictionary = G.player; var wx: Dictionary = weather_here(); var ky := ck_you(wx)
    var eyes := [[P.x, P.y, sight_radius()]]
    for f in G.fleets: if friendly_fac(f.fac) and not f.ships.is_empty(): eyes.append([f.x, f.y, SIGHT * 0.8])
    for p in G.ports: if p.fac == "player": eyes.append([p.sx, p.sy, 90.0])
    for s in Structures.held(): eyes.append([s.x, s.y, {"radar": 220.0, "airfield": 250.0, "navalbase": 120.0, "battery": 60.0}.get(s.kind, 40.0)])
    for f in G.fleets:
        var seen := always_seen(f)
        if not seen:
            for e in eyes:
                if absf(f.y - e[1]) < e[2] and mdist(f.x, f.y, e[0], e[1]) < e[2]: seen = true; break
        if seen: f.vis = true; f.seenX = f.x; f.seenY = f.y; f.seenDay = G.day; f.seenH = f.h
        else: f.vis = false
## Whether to draw a grey last-known mark for a fleet out of sight.
func ghost(f: Dictionary) -> bool: return not f.get("vis", true) and f.has("seenDay") and int(G.day) - int(f.seenDay) <= GHOST_DAYS

# ------------------------------------------------------------------ salvage
## After a victory your boats work the wrecks. From every sunk ship: steel from her plating, munitions and fuel oil
## from what floats or can be reached, and money for fittings; from a ship of an era ahead of yours, research from
## her equipment. Shoal water (land within about 150 km) lets divers reach the hull: half as much again. A salvage
## ship doubles everything. What the holds cannot take is left; fuel goes to the bunkers.
func salvage_ships() -> Array: return G.fleet.filter(func(s): return hull(s).get("salvage", false) and not s.get("reserve", false))
func salvage_mult() -> float:
    var P: Dictionary = G.player
    return (1.5 if land_near(P.x, P.y, 28.0) else 1.0) * (2.0 if not salvage_ships().is_empty() else 1.0)
func salvage(sunk: Array) -> Dictionary:
    var out := {"steel": 0, "munitions": 0, "fuel": 0, "coin": 0, "rp": 0, "shoal": land_near(G.player.x, G.player.y, 28.0), "ship": "", "left": false}
    if sunk.is_empty(): return out
    var ss: Array = salvage_ships(); if not ss.is_empty(): out.ship = ss[0].name
    var k := salvage_mult(); var steel := 0.0; var mun := 0.0; var fuel := 0.0; var coin := 0.0; var rp := 0.0
    for s in sunk:
        var h: Dictionary = hull(s); var t: float = float(h.t)
        steel += sqrt(t) * 0.12 * randf_range(0.5, 1.2)
        if h.kind != "merchant": mun += sqrt(t) * 0.05 * randf_range(0.3, 1.2) * float(s.get("ammo", 1.0))
        fuel += float(h.fuel) * randf_range(1.0, 5.0)
        coin += ship_value(s) * randf_range(0.01, 0.03)
        if int(h.era) > player_era(): rp += float(h.price) / 12000.0
    var free: int = maxi(0, cargo_cap() - cargo_used())   # holds already over-full (a freighter lost) take nothing, and give nothing up
    out.steel = mini(int(steel * k), free); free -= int(out.steel)
    out.munitions = mini(int(mun * k), free)
    out.fuel = mini(int(fuel * k), fuel_room())
    out.left = int(steel * k) > int(out.steel) or int(mun * k) > int(out.munitions)
    out.coin = int(round(coin * k / 50.0) * 50); out.rp = int(round(rp * k))
    G.cargo.steel += out.steel; G.cargo.munitions += out.munitions; G.cargo.fuel += out.fuel; G.credits += out.coin; G.rp += out.rp
    return out

# ------------------------------------------------------------------ running dark
## How easily you are found, as a share of the usual distance. Speed makes smoke, wake and noise (Slow 70% to Flank
## 130%). Running dark (ship darkened, wireless silent, no smoke: at most Half speed) cuts it to 60% by night and
## 85% by day. A wireless call gives your position away for a day (150%). The enemy's weather and radar still apply.
const SIG_SPEED := {"slow": 0.7, "half": 0.85, "cruise": 1.0, "full": 1.15, "flank": 1.3}
func dark() -> bool: return G.player.get("dark", false)
func set_dark(on: bool) -> void:
    G.player.dark = on
    if on and SPEED_ORDER.find(speed_order()) > 1: G.player.spd = "half"   # a darkened ship makes no smoke: no more than Half
func heard() -> bool: return int(G.get("heardUntil", 0)) > int(G.day)
func signature() -> float:
    var k: float = SIG_SPEED[speed_order()]
    if dark(): k *= 0.6 if weather_here().night else 0.85
    if heard(): k *= 1.5
    return k

## The weather where your squadron is (cached for the tick), and how far each side sees in it as a share of clear
## daylight: lookouts, or radar for a side that has it (you: the Fire-control radar research; a power: Era II).
var _wx := {}
var _wx_t := -1.0
func weather_here() -> Dictionary:
    var t := Weather.now()
    if _wx.is_empty() or absf(t - _wx_t) > 0.01: _wx = Weather.at(G.player.x, G.player.y, t); _wx_t = t
    return _wx
func ck_you(wx: Dictionary) -> float: return Weather.contact_mult(wx, has_tech("radar"))
func ck_them(f: Dictionary, wx: Dictionary) -> float: return Weather.contact_mult(wx, f.fac != "raiders" and fac_era(f.fac) >= 2) * signature()

## How far a force can reach out and start a fight, in map units (1 unit = 0.05°, about 5.5 km). Guns need contact,
## about 90 km, close enough to bring the lines together; anti-ship missiles about 120 km; a carrier's strike group
## 250 km from an escort carrier and 350 km from a fleet carrier.
const CONTACT := 16.0
const KM_PER_UNIT := 5.55
func strike_reach(ships: Array, air := true) -> float:
    var r := CONTACT
    for s in ships:
        var h: Dictionary = hull(s)
        if h.kind == "carrier" and air: r = maxf(r, 350.0 / KM_PER_UNIT if h.klass == "cv" else 250.0 / KM_PER_UNIT)
        for w in s.get("fit", []):
            if w != null and w != "" and GameData.weapons.has(w) and GameData.weapons[w].kind == "ssm": r = maxf(r, 120.0 / KM_PER_UNIT)
    return r

## A wireless call to a fleet that does not fire on you: it comes to you if its flag thinks well enough of you.
## Within signalling distance it answers at once. Returns what happens, for a toast.
## The nearest fleet that would answer a wireless call (a warship of a flag that thinks well enough of you, or a
## merchant convoy), in sight or not: you call into the ether and whoever hears, answers.
func nearest_caller(merchant: bool):
    var best = null; var bd: float = WIRELESS
    for f in G.fleets:
        if f.fac == "player" or hostile_fleet(f) or f.kind == "raiders" or f.kind == "bounty" or f.kind == "assault" or f.ships.is_empty(): continue
        if (f.kind == "convoy") != merchant or G.rep.get(f.fac, 0) < -10: continue
        var d := mdist(f.x, f.y, G.player.x, G.player.y)
        if d < bd: bd = d; best = f
    return best
const WIRELESS := 900.0   # map units, about 5,000 km: the long-range sets of 1946
func call_fleet(f: Dictionary) -> String:
    var d := mdist(f.x, f.y, G.player.x, G.player.y)
    if dark(): return "You are running dark: the wireless is silent. Stop running dark to call."
    if d > WIRELESS: return "The %s is beyond the range of your wireless (%d km)." % [Campaign.fname(f), int(d * KM_PER_UNIT)]
    if hostile_fleet(f) or f.kind == "raiders" or f.kind == "bounty": return "That is no friend to call on."
    if f.fac != "player" and G.rep.get(f.fac, 0) < -10: return "The %s acknowledges your call and steams on. Your standing with the %s is too low for help." % [Campaign.fname(f), GameData.fac[f.fac].short]
    f.answering = true; f.ansT = 0.0; f.cool = 0.0; f.met = false
    G.heardUntil = int(G.day) + 1   # every direction-finding station within a thousand miles has your bearing
    return "The %s answers your call and alters course to close you, %d km off." % [Campaign.fname(f), int(d * KM_PER_UNIT)]

## The nearest harbour open to you, by sea.
func nearest_open_port():
    var best = null; var bd := INF
    for p in G.ports:
        if hostile(p.fac): continue
        var d := mdist(p.sx, p.sy, G.player.x, G.player.y)
        if d < bd: bd = d; best = p
    return best

## The fee for a tow to the nearest open port: by the distance, and by what the flag of the ship that tows you thinks
## of you (half price at standing 60, the plain price at 20, a quarter more at 0, double at -60).
func tow_mult(fac: String) -> float: return clampf(1.0 - (float(G.rep.get(fac, 0)) - 20.0) / 80.0, 0.5, 2.0) if fac != "" else 1.0
func tow_fee(fac := "") -> int:
    var p = nearest_open_port()
    if p == null: return 0
    return int(round((1500.0 + mdist(p.sx, p.sy, G.player.x, G.player.y) * 6.0) * tow_mult(fac) / 100.0) * 100)

## A distress call: the nearest warship that is not your enemy, friendly or merely neutral, turns towards you,
## whatever her flag thinks of you (that shows in the fee). It breaks radio silence. Returns what happened.
func distress_ship():
    var best = null; var bd: float = WIRELESS
    for f in G.fleets:
        if f.fac == "player" or hostile_fleet(f) or f.kind != "patrol" or f.ships.is_empty() or Structures._is_assault(f): continue
        var d := mdist(f.x, f.y, G.player.x, G.player.y)
        if d < bd: bd = d; best = f
    return best
func distress() -> String:
    var f = distress_ship()
    if f == null: return "Your distress call goes unanswered: no warship that would help is within %d km. Try a merchant convoy (right-click the sea)." % int(WIRELESS * KM_PER_UNIT)
    if dark(): set_dark(false)
    f.answering = true; f.ansT = 0.0; f.cool = 0.0; f.met = false; G.heardUntil = int(G.day) + 1; G.distressDay = int(G.day)
    return "Distress call answered: the %s alters course for you, %d km off. A tow to the nearest open port will cost about %s (your standing with the %s is %d)." % [Campaign.fname(f), int(mdist(f.x, f.y, G.player.x, G.player.y) * KM_PER_UNIT), fmt(tow_fee(f.fac)), GameData.fac[f.fac].short, int(G.rep.get(f.fac, 0))]

## A warship takes you in tow to the nearest open port: the fee is paid now, and she stays alongside until you
## reach harbour.
func take_tow(f: Dictionary) -> String:
    var p = nearest_open_port()
    if p == null: return "There is no harbour open to you to be towed to."
    var fee := tow_fee(f.fac); var owed: bool = G.credits < fee
    # a ship in distress is helped whether or not she can pay, as the law of the sea expects; the flag remembers it
    if owed: G.rep[f.fac] = G.rep.get(f.fac, 0) - 5
    else: G.credits -= fee
    var P: Dictionary = G.player
    rep_note("Towed without paying")
    P.towed = int(f.id); P.follow = null; P.escort = null; P.destPort = int(p.id); f.answering = false
    if not set_course(P, p.sx, p.sy):
        P.towed = null
        if owed: G.rep[f.fac] = G.rep.get(f.fac, 0) + 5
        else: G.credits += fee
        return "No sea route to %s." % p.name
    log_ev("Towed to %s by the %s" % [p.name, f.name])
    if owed: return "You cannot pay, but no captain leaves a ship adrift. The %s takes you in tow for %s; the %s will remember it (standing -5)." % [Campaign.fname(f), p.name, GameData.fac[f.fac].short]
    return "The %s passes a hawser and takes you in tow for %s (%s)." % [Campaign.fname(f), p.name, fmt(fee)]

## A fleet's name inside a sentence ("the Concord patrol", "the raider flotilla"): a flag's name keeps its capital.
func fname(f: Dictionary) -> String:
    var n: String = f.name
    if n.begins_with("Your "): return n.substr(5)
    return n.to_lower() if n.begins_with("Raider") else n
## Where a fleet is as far as you know: where it is if somebody of yours has it in sight, else where it was last
## seen, else where it was reported when you were told of it (its station: a contract's or a mission's fleet).
func known_pos(f: Dictionary) -> Vector2:
    if f.get("vis", true): return Vector2(f.x, f.y)
    if f.has("seenDay"): return Vector2(f.seenX, f.seenY)
    return Vector2(f.home.x, f.home.y) if f.has("home") else Vector2(f.x, f.y)
## The standing ledger: why each power thinks of you as it does. Standing is changed in many places; after each kind
## of event `rep_note(reason)` books whatever has changed since the last note under that reason (G.repLog), so the
## standing screen can show the sums on hover. Anything nobody claimed is booked daily as other dealings.
func rep_note(reason: String) -> void:
    if G.is_empty() or not G.has("rep"): return
    if not G.has("repSeen"):
        G.repSeen = {}; G.repLog = {}
        for f in G.rep:
            G.repSeen[f] = int(G.rep[f])
            if int(G.rep[f]) != 0: G.repLog[f] = {"Before this record began": int(G.rep[f])}
    for f in G.rep:
        var d: int = int(G.rep[f]) - int(G.repSeen.get(f, 0))
        if d == 0: continue
        if not G.repLog.has(f): G.repLog[f] = {}
        G.repLog[f][reason] = int(G.repLog[f].get(reason, 0)) + d
        if int(G.repLog[f][reason]) == 0: G.repLog[f].erase(reason)
        G.repSeen[f] = int(G.rep[f])
## The ledger for one power as lines of text, largest first, and why it is at war with you if it is.
func rep_lines(fac: String) -> Array:
    rep_note("Other dealings")
    var out := []; var log: Dictionary = G.get("repLog", {}).get(fac, {})
    var keys: Array = log.keys(); keys.sort_custom(func(a, b): return absi(int(log[a])) > absi(int(log[b])))
    for k in keys: out.append("%s %s%d" % [k, "+" if int(log[k]) > 0 else "", int(log[k])])
    if out.is_empty(): out.append("Nothing has passed between you yet.")
    if at_war(fac):
        var why := []
        if G.get("nukedFacs", []).has(fac): why.append("you used the bomb on them: an enemy for good")
        if G.rep.get(fac, 0) <= WAR_STANDING: why.append("standing at %d or below" % WAR_STANDING)
        if incident_days(fac) > 0: why.append("you opened fire on them: %d days more" % incident_days(fac))
        if (perk("outlaw", []) as Array).has(fac): why.append("your origin made you their declared enemy")
        if Diplomacy.commission_enemy(fac): why.append("the flag you serve is at war with them, or your letter of marque names them")
        out.append("At war with you: " + "; ".join(why) + ".")
    elif hostile(fac): out.append("Ports closed to you: standing below -10.")
    return out
func _fleet(id):
    for f in G.fleets: if f.id == id: return f
    return null

func _arrive() -> void:
    var P: Dictionary = G.player
    if P.get("towed") != null:
        var tf = _fleet(P.towed); P.towed = null
        if tf != null: tf.answering = false; tf.cool = 20.0; tf.route = null
        toast.emit("The tow is cast off in the roads. Your squadron is in harbour.")
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
    var hk: String = ["dd", "dd", "corvette", "cl", "ss"].pick_random()
    if poi.type != "site" and roll < 0.22 and can_add_ship(GameData.hulls.keys().filter(func(id): return GameData.hulls[id].klass == hk)[0]) == "":
        var hulk = new_ship(hk, null, "raiders", [])
        hulk.pal = "player"; hulk.name = GameData.names.player.pick_random(); hulk.hullFrac = 0.22; G.fleet.append(hulk)
        out.lines.append("A %s is still afloat at her moorings. Pumped out and patched, she joins you as the %s at 22%% condition. She needs %d crew." % [hull(hulk).name.to_lower(), hulk.name, hull(hulk).crew])
    log_ev("Surveyed %s (+%d RP)" % [poi.name, rp])
    Diplomacy.on_survey(poi, out.lines)
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
    for s in G.fleet: if not s.get("reserve", false): recs.append(s)   # ships held in reserve stand off and take no part
    if recs.is_empty(): for s in G.fleet: recs.append(s)
    if recs.size() > BATTLE_MAX: recs = recs.slice(0, BATTLE_MAX)   # ten fight in one action: those listed after stand off with the reserve
    for o in G.officers: o.lastShip = o.ship
    return {"player_recs": recs, "enemy_recs": f.ships, "enemy_fac": f.fac, "player_tech": G.tech, "enemy_tech": enemy_tech(fac_era(f.fac)),
        "islands": _islands_here(), "fleet_id": f.id, "campaign": true, "crew_frac": crew_frac(), "officers": G.officers, "no_fuel": G.cargo.fuel <= 0,
        "range_km": int(f.get("contactKm", 0)), "weather": Weather.battle(weather_here())}

func _islands_here() -> int:
    var dens = land_density(G.player.x, G.player.y, 25)
    return randi_range(3, 5) if dens > 0.25 else (randi_range(1, 3) if dens > 0.05 else randi_range(0, 1))

## Applies a finished battle to the campaign: damage, losses, casualties, prizes, prize money, research, officer
## experience, bounties and missions. Mirrors the browser build's endCombat.
## Cost to refill a ship's magazines: a fraction of what its weapons cost, for the share that was fired.
func rearm_cost(s: Dictionary) -> int:
    var w := 0.0
    for wid in s.fit: if wid != null and wid != "" and GameData.weapons.has(wid): w += float(GameData.weapons[wid].price)
    return int(ceil((1.0 - float(s.get("ammo", 1.0))) * w * 0.15))

func apply_battle(sim: BattleSim) -> Dictionary:
    var f = _fleet(GameData.pending.get("fleet_id", -1))
    var r = {"victory": false, "retreated": false, "sunk": [], "lost": [], "prizes": [], "coin": 0, "rp": 0, "goods": "", "bounty": 0, "casualties": 0, "notes": []}
    var cas = 0.0
    for s in sim.ships:
        if s.side == 0:
            if not s.alive: r.lost.append(s.rec); cas += s.d.crew * 0.5
            else: s.rec.xp = crew_xp(s.rec) * (1.0 - 0.5 * clampf(s.dmg_taken / s.max_hull, 0.0, 1.0)) + 1.0; s.rec.hullFrac = maxf(0.05, s.hull / s.max_hull); s.rec.ammo = sim.ammo_frac(s); s.rec.air = mini(sim.planes_left(s), maxi(Structures.planes_max(s.rec), int(hull(s.rec).get("hangar", 0)) * 6)); s.rec.rdy = maxf(RDY_MIN, readiness(s.rec) - 0.1 - 0.25 * clampf(s.dmg_taken / s.max_hull, 0.0, 1.0)); cas += s.d.crew * (s.dmg_taken / s.max_hull) * 0.25 * (1 - 0.15 * s.sk.dc)
        else:
            if not s.alive: r.sunk.append(s.rec)
            else:
                s.rec.hullFrac = maxf(0.05, s.hull / s.max_hull)
                if s.struck: r.prizes.append(s.rec)
    r.casualties = mini(int(G.crew), int(round(cas))); G.crew -= r.casualties
    G.fleet = G.fleet.filter(func(s): return not r.lost.has(s))
    if G.fleet.is_empty() and body() != null:   # the division you sailed with is gone, but your main body is afloat: it is your squadron now
        var b = body(); r.notes.append("The division you led is lost. Your flag shifts to the main body, %d km away." % int(mdist(b.x, b.y, G.player.x, G.player.y) * KM_PER_UNIT))
        G.troops = int(b.get("troops", 0))   # the soldiers with the lost division went with it
        G.fleet = b.ships; G.fleets.erase(b); G.player.x = b.x; G.player.y = b.y; G.player.route = null; G.player.follow = null
    var drowned := Structures.trim_troops()
    if drowned > 0: r.notes.append("%d soldiers were lost with their transport." % drowned)
    var sunk_cargo := trim_cargo()
    if not sunk_cargo.is_empty(): r.notes.append("Cargo went down with the ships that carried it: %s." % cargo_text(sunk_cargo))
    for o in G.officers: if not all_ships().any(func(s): return s.id == o.ship): o.ship = null
    var had: int = f.ships.size() if f != null else 0
    var enemy_left = false
    for s in sim.ships: if s.side == 1 and sim.engageable(s): enemy_left = true
    # victory as the battle screen counts it: the enemy beaten and a ship of yours still afloat in the action (a ship
    # held in reserve does not win a battle in which your last fighting ship went down with the last of theirs)
    var mine_left := false
    for s in sim.ships: if s.side == 0 and s.alive: mine_left = true
    r.victory = not enemy_left and mine_left and G.fleet.size() > 0; r.retreated = not r.victory and G.fleet.size() > 0
    if not r.victory: r.prizes = []   # a ship that struck is yours only if you hold the field: break off, and she rejoins her squadron
    if f != null: f.ships = f.ships.filter(func(s): return not r.sunk.has(s) and not r.prizes.has(s))
    G.kills += r.sunk.size()
    var beaten: Array = r.sunk + r.prizes; var beaten_value = 0.0
    for s in beaten: beaten_value += ship_value(s)
    for s in r.sunk: r.coin += ship_value(s) * (0.07 + randf() * 0.06)
    if f != null: r.coin *= float((perk("prize", {}) as Dictionary).get(f.fac, 1.0))   # a letter of marque pays better against its target
    r.coin = int(round(r.coin / 50.0) * 50)
    r.rp = int(round(beaten_value / 4000.0)); G.rp += r.rp
    var fac: String = f.fac if f != null else "raiders"
    Diplomacy.thanks(fac, beaten.size())
    if r.victory and f != null and f.cargo.size():
        var got = []; var free = cargo_cap() - cargo_used()
        for g in f.cargo:
            # cargo comes from the ships you sank or took, not from those that got away (a convoy that scattered
            # untouched used to leave a third to two thirds of its cargo behind)
            var take = mini(free, int(floor(f.cargo[g] * (0.3 + randf() * 0.4) * beaten.size() / maxf(1.0, had))))
            if take > 0:
                G.cargo[g] += take; free -= take
                for gd in C.GOODS: if gd.id == g: got.append("%d %s" % [take, gd.name.to_lower()])
        r.goods = ", ".join(got)
    r.salvage = salvage(r.sunk) if r.victory else {}
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
    # a landing force beaten at sea gives the landing up: what is left of it turns for home as an ordinary patrol
    # (its troopships used to run, "escape", and bring the same force back the next day, again and again)
    if f != null and not gone and r.victory and (Structures._is_assault(f) or Flag.is_relief(f)):
        r.notes.append("The %s gives up the landing and turns for home." % fname(f))
        for k in ["assault", "portAssault", "tgt", "warned"]: f.erase(k)
        f.kind = "patrol"; f.name = GameData.fac[f.fac].short + " patrol"; f.route = null
        if f.has("home"): set_course(f, f.home.x, f.home.y)
    if f != null:
        if gone:
            G.fleets.erase(f); convoy_lost(f)
            if f.kind == "bounty": r.bounty = f.reward; log_ev("Collected the bounty on " + f.captain)
        else: f.cool = 8.0
    G.credits += r.coin + r.bounty
    Diplomacy.on_battle(f, beaten.size(), gone, r.notes)
    if G.mission != null and f != null and G.mission.fleet == f.id:
        var m: Dictionary = mission_def()
        if m.goal == "destroy" and gone: _complete_mission(r)
        elif m.goal == "capture" and r.sunk.any(func(s): return s.name == m.target):
            r.notes.append("The %s went down, and what she carried went with her. The mission has failed. Report back for new orders." % m.target)
            G.mission = null; log_ev("Mission failed: " + m.title)
    G.player.cool = 5.0
    last_result = r
    save()
    return r

# ------------------------------------------------------------------ story missions
## The chain of story missions a power offers at its capital: the Concord Admiralty's (campaign.json STORY) or another
## power's (stories.json). Each is played in order.
func story_chain(by: String) -> Array:
    if by == "concord": return C.STORY
    return S.get("chains", {}).get(by, {}).get("missions", [])
func story_office(by: String) -> String: return S.get("offices", {}).get(by, "Admiralty")
func story_idx(by: String) -> int:
    if G.has("stories") and G.stories.has(by): return int(G.stories[by])
    return int(G.get("story", 0)) if by == "concord" else 0
func mission_def() -> Dictionary: return story_chain(G.mission.get("by", "concord"))[int(G.mission.idx)]
func accept_mission(by: String) -> void:
    var m: Dictionary = story_chain(by)[story_idx(by)]
    var f = spawn_fleet("mission", m.fac, false, m); G.mission = {"idx": story_idx(by), "fleet": f.id, "by": by}; log_ev("Accepted orders: " + m.title)

func _complete_mission(r: Dictionary) -> void:
    var by: String = G.mission.get("by", "concord"); var m: Dictionary = mission_def()
    G.credits += m.reward.credits; G.rp += m.reward.rp; G.rep[by] = mini(100, G.rep.get(by, 0) + int(m.reward.rep))
    rep_note("Orders carried out")
    r.notes.append("Orders complete: %s. +%s, +%d RP." % [m.title, fmt(m.reward.credits), m.reward.rp])
    if not G.has("stories"): G.stories = {}
    G.stories[by] = story_idx(by) + 1
    if by == "concord": G.story = G.stories[by]
    log_ev("Completed: " + m.title); G.mission = null
    if story_idx(by) >= story_chain(by).size():
        if by == "concord": r.notes.append("Iron Will is gone, and with her the Directorate's hopes of breaking out. The armistice holds a little firmer. Your fleet, and the Quiet Race, go on.")
        else: r.notes.append(S.chains[by].end)

# ------------------------------------------------------------------ saves
func save() -> void:
    if G.is_empty(): return
    var g = G.duplicate(true)
    _strip_routes(g.player)
    for f in g.fleets: _strip_routes(f)
    var fa = FileAccess.open(SAVE_PATH, FileAccess.WRITE); fa.store_string(JSON.stringify(g))

func _strip_routes(o: Dictionary) -> void:
    for k in ["remI", "remN", "remX", "remY", "remT", "msp", "mtr", "prT", "prR", "jam", "jams"]: o.erase(k)   # worked out again as needed
    if o.get("route") != null:
        var pts = []
        for q in o.route: pts.append([q.x, q.y])
        o.route = pts

func has_save() -> bool: return FileAccess.file_exists(SAVE_PATH)
## The saved game's version, or 0 if there is none or it cannot be read.
func save_version() -> int:
    if not has_save(): return 0
    var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
    return int(d.get("v", 0)) if d is Dictionary else 0

func load_game() -> bool:
    if not has_save(): return false
    var d = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
    if not (d is Dictionary) or int(d.get("v", 0)) < SAVE_VERSION: return false
    G = d
    Diplomacy.ensure()
    Structures.ensure()
    Flag.apply()
    for o in [G.player] + G.fleets: _restore_route(o)
    _ints(G)
    _pad_fits()
    paused = false
    return true

## A design may have gained mounts since a game was saved (the corrected batteries of 11 Nov 2026): every saved ship's
## fit is made as long as her design's list of mounts, the new ones as designed.
func _pad_fits() -> void:
    var all: Array = G.get("fleet", []).duplicate()
    for f in G.get("fleets", []): all.append_array(f.get("ships", []))
    for s in all:
        if not (s is Dictionary) or not s.has("fit") or not GameData.hulls.has(s.get("type", "")): continue
        var slots: Array = GameData.hulls[s.type].slots
        while s.fit.size() < slots.size():
            var df = slots[s.fit.size()].get("def")
            s.fit.append(df if df != null else "")

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
    if g.player.get("escort") != null: g.player.escort = int(g.player.escort)
    if g.player.get("towed") != null: g.player.towed = int(g.player.towed)
    if g.player.get("wps") != null: g.player.wps = g.player.wps.map(func(i): return int(i))
    for f in g.fleets:
        f.id = int(f.id)
        if f.has("dest"): f.dest = int(f.dest)
        if f.has("from"): f.from = int(f.from)
    for p in g.ports: p.id = int(p.id)
    for s in g.get("structs", []):
        s.id = int(s.id); s.port = int(s.port); s.garrison = int(s.garrison); s.took = int(s.took); s.coastKm = int(s.coastKm)
    for f in g.fleets:
        if f.has("assault"): f.assault = int(f.assault)
        if f.has("portAssault"): f.portAssault = int(f.portAssault)
    if g.mission != null: g.mission.idx = int(g.mission.idx); g.mission.fleet = int(g.mission.fleet)
    for o in g.officers:
        o.lvl = int(o.lvl); o.pts = int(o.pts)
        for k in o.sk: o.sk[k] = int(o.sk[k])
