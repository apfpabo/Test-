class_name BattleSim
extends RefCounted
## The battle simulation, independent of drawing. One unit is one metre. Ships keep their real length, beam, speed in
## knots and tactical diameter; every timer is in battle seconds. Gun ranges are compressed to about a fifth of real
## (see the weapons data) so a fight fits a readable chart. step() advances physics, weapons and AI; fx() advances
## the visual effects once per frame.

const KN := 0.5144            # metres per second per knot
const BT := 2.0               # battle seconds per real second at 1x
const ESCAPE_R := 11000.0     # a retreating ship that opens the range this far gets away
const TELEGRAPH := [0.0, 0.3, 0.55, 0.8, 1.0]
const TRAV := {"S": 0.45, "M": 0.25, "L": 0.12, "H": 0.075}   # turret training rates, radians per battle second
const GUN_SIZES := ["S", "M", "L", "H"]
const WIND := Vector2(7.0, 3.5)  # smoke drift, metres per visual second
const SUN := Vector2(0.55, 0.85) # direction shadows fall on the chart

enum P { FOAM, OIL, SWAKE, TWAKE, SPLASH, GEYSER, BLAST, DC, SMOKE, GUNSMOKE, FUNNEL, DUST, FLAK, MTRAIL, FLASH, BOOM, FIRE, SPARK, FALL }

class Mount:
    var slot: Dictionary
    var wid: String
    var w: Dictionary
    var ta = 0.0
    var cd = 0.0
    var recoil = 0.0
    var tgt: CShip = null
    var tgt_t = 0.0
    var air: Dictionary = {}
    var st = ""
    var err = 0.0
    var dead = false
    var rest_t = 0.0
    var rest_o: CShip = null
    var lvl = 0        # 0 on the deck; 1 and up for superfiring mounts whose barrels pass over the one ahead

class CShip:
    var rec: Dictionary
    var d: Dictionary
    var pal: String
    var side: int
    var pos: Vector2
    var a = 0.0
    var v = 0.0
    var throttle = 3
    var rudder = 0.0
    var rud = 0.0
    var w = 0.0
    var max_hull = 1.0
    var hull = 1.0
    var armor = 0.0
    var alive = true
    var escaped = false
    var struck = false
    var sink = 0.0
    var pref_side = 1
    var side_t = 0.0
    var smoke_t = 0.0
    var wake_t = 0.0
    var trail_t = 0.0
    var ram_t = 0.0
    var dc_t = 0.0
    var flee = false
    var target: CShip = null
    var tgt_t = 0.0
    var dmg_taken = 0.0
    var sk = {"gun": 0, "helm": 0, "dc": 0, "ord": 0}
    var tech: Array = []
    var cf = 1.0
    var sub = false
    var dive = 0.0
    var want_dive = false
    var reveal_t = 0.0
    var torp_run_t = 0.0
    var ai_acc = 0.0
    var wpn_acc = 0.0
    var mounts: Array[Mount] = []
    var squads: Array = []
    var marks: Array = []
    var fires: Array = []
    var trail: Array = []
    var main_sz = ""
    var max_lvl = 0
    var view: Node = null

class Part:
    var t: int
    var pos: Vector2
    var vel = Vector2.ZERO
    var life = 0.0
    var mx = 1.0
    var size = 1.0
    var a = 0.0
    var v = -1
    var wind = false
    var side = 0
    var done = false

var AW = 26000.0
var AH = 22000.0
var ships: Array[CShip] = []
var shells: Array = []
var torps: Array = []
var missiles: Array = []
var air: Array = []
var parts: Array[Part] = []
var tracers: Array = []
var islands: Array = []
var order = "engage"
var t = 0.0        # battle clock
var vt = 0.0       # visual clock
var end_t = 0.0
var end_msg = false
var last_hit = 0.0
var flag: CShip = null
var lock: CShip = null
var autofire = false
var want_torp = false
var want_msl = false
var player_rudder = 0.0
var aim_mode = 0          # 0 none, 1 hold-fire at a point
var mouse_world = Vector2.ZERO
var mouse_down = false
var gun_aim: Dictionary = {}
var msg = "Action stations!"
var msg_t = 3.0
var finished = false
var result: Dictionary = {}
var enemy_era = 1
var sonar_tech = false
var on_boom: Callable    # (pos, vol, freq, rate) for sound
var small_craft = [false, false]  # whether each side still has torpedo boats or submarines afloat
var dcs: Array = []              # depth charges sinking towards their set depth

static func ang_diff(a: float, b: float) -> float:
    return wrapf(a - b, -PI, PI)

func say(m: String, dur := 3.0) -> void:
    msg = m; msg_t = dur

func boom(p: Vector2, vol: float, freq := 420.0, rate := 1.0) -> void:
    if on_boom.is_valid(): on_boom.call(p, vol, freq, rate)

# ------------------------------------------------------------------ setup
func setup(player_recs: Array, enemy_recs: Array, player_tech: Array, enemy_tech: Array, n_islands: int) -> void:
    for i in 80:
        if islands.size() >= n_islands: break
        var r = 350.0 + randf() * 900.0
        var c = Vector2(3000.0 + randf() * (AW - 6000.0), AH / 2 + (randf() - 0.5) * 7000.0)
        var ok = true
        for o in islands: if o.c.distance_to(c) < o.r + r + 2000.0: ok = false
        if absf(c.y - AH / 2) > 2600.0 and absf(c.x - AW / 2) < 4500.0: ok = false
        if ok: islands.append(make_island(c, r))
    enemy_era = 3 if enemy_tech.has("aegis") else 2 if enemy_tech.has("missiles") else 1
    sonar_tech = player_tech.has("sonar")
    _place(player_recs, 0, player_tech); _place(enemy_recs, 1, enemy_tech)
    flag = ships[0]

func _place(list: Array, side: int, tech: Array) -> void:
    var k = list.size()
    for i in k:
        var x = AW / 2 + (i - (k - 1) / 2.0) * 700.0 + (randf() - 0.5) * 120.0
        var y = (AH / 2 - 4500.0 - (i % 2) * 400.0) if side == 1 else (AH / 2 + 4500.0 + (i % 2) * 400.0)
        ships.append(make_ship(list[i], side, Vector2(x, y), PI / 2 if side == 1 else -PI / 2, tech))

func make_island(c: Vector2, r: float) -> Dictionary:
    var rad: Array[float] = []
    var p1 = randf() * TAU; var p2 = randf() * TAU; var p3 = randf() * TAU
    for i in 30:
        var a = i / 30.0 * TAU
        rad.append(r * (0.78 + 0.16 * sin(a * 2 + p1) + 0.1 * sin(a * 5 + p2) + 0.05 * sin(a * 9 + p3) + 0.05 * randf()))
    return {"c": c, "r": r, "rad": rad}

func island_r(is_: Dictionary, ang: float) -> float:
    var n: int = is_.rad.size(); var f = fposmod(ang, TAU) / TAU * n; var i = int(floor(f)) % n
    return lerpf(is_.rad[i], is_.rad[(i + 1) % n], f - floor(f))

func in_island(is_: Dictionary, p: Vector2, pad := 0.0) -> bool:
    var dv: Vector2 = p - is_.c; var dl = dv.length()
    if dl > is_.r * 1.3 + pad: return false
    return dl < island_r(is_, dv.angle()) + pad

func land_at(p: Vector2) -> bool:
    for is_ in islands: if in_island(is_, p): return true
    return false

static func default_fit(design: Dictionary, tech: Array) -> Array:
    var out = []
    for s in design.slots:
        var w: String = s.def
        if w == "tor" and tech.has("homing") and design.kind != "pt": w = "torh"
        if w == "torh" and not tech.has("homing"): w = "tor"
        if (w == "aa40" or w == "aa20") and tech.has("ciws") and randf() < 0.5: w = "ciws"
        if w == "ciws" and not tech.has("ciws"): w = "aa40"
        if w == "g76" and not tech.has("missiles"): w = "g102t"
        if w == "g203r" and not tech.has("radar"): w = "g203"
        var wd: Dictionary = GameData.weapons[w]
        if wd.has("tech") and not tech.has(wd.tech) and s.s == "V": w = ""
        out.append(w)
    return out

func make_ship(rec: Dictionary, side: int, p: Vector2, a: float, tech: Array) -> CShip:
    var s = CShip.new(); var d: Dictionary = GameData.hulls[rec.type]
    s.rec = rec; s.d = d; s.pal = rec.pal if side == 1 else "player"; s.side = side; s.pos = p; s.a = a
    s.v = d.kn * KN * 0.6; s.max_hull = d.hull; s.hull = d.hull * rec.hullFrac; s.armor = d.armor * (0.6 + 0.4 * rec.hullFrac)
    s.pref_side = 1 if randf() < 0.5 else -1; s.tech = tech; s.sub = d.kind == "sub"
    for i in d.slots.size():
        var wid: String = rec.fit[i]
        if wid == "" or not GameData.weapons.has(wid): continue
        var m = Mount.new(); m.slot = d.slots[i]; m.wid = wid; m.w = GameData.weapons[wid]; m.ta = m.slot.arcs[0][0]; m.cd = randf() * m.w.rel * 0.5
        s.mounts.append(m)
    for i in int(d.get("hangar", 0)): s.squads.append({"state": "ready", "t": 0.0, "n": 6})
    if side == 1 and d.kind == "merchant": s.flee = true
    var best = -1
    for m in s.mounts: if m.w.kind == "gun": best = maxi(best, GUN_SIZES.find(m.w.size))
    s.main_sz = GUN_SIZES[maxi(best, 0)]
    superfiring(s)
    return s

## Works out which mounts stand higher from the layout: a gun mount nearer amidships, on the same line as one further
## out and close enough that its barrels reach over it, is superfiring. Chains (A, B, C) give rising levels.
func superfiring(s: CShip) -> void:
    var guns: Array = s.mounts.filter(func(m): return m.w.kind == "gun")
    for _pass in 3:
        for a in guns:
            for b in guns:
                if a == b: continue
                var ax: float = a.slot.x; var bx: float = b.slot.x
                if signf(ax) != signf(bx) or absf(ax) >= absf(bx): continue          # a must be nearer amidships, same end
                if absf(a.slot.y - b.slot.y) > (a.w.tw + b.w.tw) * 0.3: continue    # on the same line
                if absf(bx - ax) > a.w.tl * 0.42 + a.w.bl + b.w.tw * 0.6: continue   # a's barrels reach over b
                a.lvl = maxi(a.lvl, b.lvl + 1)
    for m in s.mounts: s.max_lvl = maxi(s.max_lvl, m.lvl)

# ------------------------------------------------------------------ queries
func world_pt(s: CShip, lx: float, ly: float) -> Vector2:
    return s.pos + Vector2(lx, ly).rotated(s.a)

func active(s: CShip) -> bool: return s.alive and not s.escaped
func engageable(s: CShip) -> bool: return s.alive and not s.escaped and not s.struck
func submerged(s: CShip) -> bool: return s.sub and s.dive > 0.6

func detected_by(sb: CShip, side: int) -> bool:
    if not submerged(sb) or sb.reveal_t > 0: return true
    var sonar_r = 1500.0 * ((1.6 if sonar_tech else 1.0) if side == 0 else (1.6 if enemy_era >= 2 else 1.0))
    for o in ships:
        if o.side != side or not active(o): continue
        var dd = o.pos.distance_to(sb.pos)
        if dd < 500.0 or (o.d.get("sonar", false) and dd < sonar_r): return true
    return false

func visible_to(s: CShip, side: int) -> bool:
    return s.side == side or not s.sub or detected_by(s, side)

func speed_mult(s: CShip) -> float:
    return (1 + 0.06 * s.sk.helm) * (0.75 + 0.25 * s.cf) * (0.6 + 0.4 * s.hull / s.max_hull)

func gun_range(s: CShip, w: Dictionary) -> float:
    return w.range * (1.15 if s.tech.has("radar") and w.kind == "gun" else 1.0) * (1.4 if w.kind == "sam" and s.tech.has("aegis") else 1.0)

func max_gun_range(s: CShip) -> float:
    var r = 0.0
    for m in s.mounts: if m.w.kind == "gun" and m.w.size != "S" and not m.dead: r = maxf(r, gun_range(s, m.w))
    if r == 0.0:
        for m in s.mounts: if m.w.kind == "gun" and not m.dead: r = maxf(r, gun_range(s, m.w))
    return r if r > 0.0 else 2000.0

func has_kind(s: CShip, k: String) -> bool:
    for m in s.mounts: if m.w.kind == k and not m.dead: return true
    return false

## Whether a mount can bear on a local bearing: x is 1 if it can, y is the bearing clamped to its arc.
func arc_check(slot: Dictionary, local: float) -> Vector2:
    var best := 0.0; var bd := INF
    for arc in slot.arcs:
        var c: float = arc[0]; var h: float = arc[1]; var rel := ang_diff(local, c)
        if absf(rel) <= h: return Vector2(1.0, local)
        var dd := absf(rel) - h
        if dd < bd: bd = dd; best = c + signf(rel) * h
    return Vector2(0.0, best)

func lead_point(from: Vector2, tg: CShip, speed: float) -> Vector2:
    var p = tg.pos; var vel = Vector2.from_angle(tg.a) * tg.v
    for i in 3: p = tg.pos + vel * (from.distance_to(p) / speed)
    return p

func best_target(from: Vector2, side: int, max_d: float, filt: Callable, heavy: bool) -> CShip:
    var best: CShip = null; var bs = INF
    for o in ships:
        if o.side == side or not engageable(o) or not visible_to(o, side): continue
        if filt.is_valid() and not filt.call(o): continue
        var dd = from.distance_to(o.pos)
        if dd > max_d: continue
        var sc = dd / clampf(o.d.L / 110.0, 0.5, 2.6) if heavy else dd
        if sc < bs: bs = sc; best = o
    return best

func nearest_enemy(from: Vector2, side: int, max_d := INF, filt := Callable()) -> CShip:
    var best: CShip = null; var bd = max_d
    for o in ships:
        if o.side == side or not engageable(o) or not visible_to(o, side): continue
        if filt.is_valid() and not filt.call(o): continue
        var dd = from.distance_to(o.pos)
        if dd < bd: bd = dd; best = o
    return best

func heavy_guns(s: CShip) -> bool:
    for m in s.mounts: if m.w.kind == "gun" and (m.w.size == "L" or m.w.size == "H"): return true
    return false

func hull_half(d: Dictionary, x: float) -> float:
    var h: float = d.L / 2; var fe: float = d.p.get("bow", 0.33) * d.L; var fr: float = d.p.get("run", 0.2) * d.L; var half: float = d.B / 2
    if x > h - fe: half *= sqrt(maxf(0.0, (h - x) / fe))
    elif x < -h + fr: half *= maxf(d.p.get("tw", 0.5) if d.p.get("stern", "c") == "t" else 0.15, sqrt(maxf(0.0, (x + h) / fr)))
    return half

# ------------------------------------------------------------------ effects
func part(type: int, p: Vector2, mx: float, size: float, vel := Vector2.ZERO, wind := false, life := 0.0) -> Part:
    var q = Part.new(); q.t = type; q.pos = p; q.mx = mx; q.size = size; q.vel = vel; q.wind = wind; q.life = life; q.v = randi() % 4
    parts.append(q); return q

func fx_boom(p: Vector2, size: float, mx := 0.6) -> void:
    part(P.BOOM, p, mx, size)
    for i in 2: part(P.SMOKE, p + Vector2(randf() - 0.5, randf() - 0.5) * size * 0.5, 5.0 + randf() * 3.0, size * 0.7, Vector2(randf() - 0.5, randf() - 0.5) * 6.0, true, -0.15)

func fx_splash(p: Vector2, size: float) -> void:
    part(P.SPLASH, p, 1.8, size); part(P.FOAM, p, 10.0, size * 1.5)

func fx_muzzle(p: Vector2, ang: float, size: String, barrels: int) -> void:
    var S: float = {"S": 5.0, "M": 9.0, "L": 15.0, "H": 26.0}[size]
    var n: int = {"S": 2, "M": 3, "L": 5, "H": 8}[size] + barrels
    var f = part(P.FLASH, p, 0.22, S * (1 + barrels * 0.12)); f.a = ang
    part(P.BLAST, p, 0.7, S * 2.6)
    for i in ceili(n / 2.0):
        var a = ang + (randf() - 0.5) * 0.9
        part(P.SPARK, p, 0.3 + randf() * 0.3, S * 0.12, Vector2.from_angle(a) * (60.0 + randf() * 120.0))
    for i in n:
        var a = ang + (randf() - 0.5) * 0.7
        part(P.GUNSMOKE, p + Vector2.from_angle(ang) * S * 0.5, 7.0 + randf() * 5.0, S * (0.5 + randf() * 0.4), Vector2.from_angle(a) * (0.2 + randf()) * S * 6.0, true, -i * 0.02)

func tracer(p: Vector2, q: Vector2) -> void:
    tracers.append({"a": p, "b": q + Vector2(randf() - 0.5, randf() - 0.5) * 20.0, "life": 0.12})

# ------------------------------------------------------------------ weapons
func fire_gun(s: CShip, m: Mount, aim: Vector2, w: Dictionary) -> void:
    var p = world_pt(s, m.slot.x, m.slot.y); var ang = s.a + m.ta
    var rng: float = gun_range(s, w); var d = minf(rng, p.distance_to(aim))
    var fc = (0.6 if s.tech.has("radar") else 1.0) * (1 - 0.12 * s.sk.gun) * (1.15 if s.side == 1 else 1.0)
    var spread: float = w.spread * fc
    for i in int(w.get("barrels", 1)):
        var a = ang + (randf() - 0.5) * 2 * spread
        var dd = maxf(60.0, d * (1 + (randf() - 0.5) * 0.06 * fc))
        shells.append({"s": p, "e": p + Vector2.from_angle(a) * dd, "pos": p, "t": 0.0, "T": dd / w.speed + i * 0.15, "dmg": w.dmg, "side": s.side, "size": w.size})
    m.recoil = 1.0
    var mz = p + Vector2.from_angle(ang) * (w.tl * 0.42 + w.bl)
    fx_muzzle(mz, ang, w.size, int(w.get("barrels", 1)))
    boom(p, {"S": 0.1, "M": 0.16, "L": 0.26, "H": 0.42}[w.size], {"S": 700.0, "M": 520.0, "L": 350.0, "H": 220.0}[w.size])

func fire_torps(s: CShip, m: Mount, aim: Vector2) -> void:
    var w = m.w; var p = world_pt(s, m.slot.x, m.slot.y); var base = (aim - p).angle()
    for i in int(w.count):
        var a: float = base + (i - (w.count - 1) / 2.0) * 0.06
        torps.append({"pos": p, "a": a, "speed": w.speed, "life": gun_range(s, w) / w.speed, "dmg": w.dmg, "side": s.side, "homing": w.get("homing", false), "arm": 150.0 / w.speed})
    boom(p, 0.1, 900.0)
    if s.sub: s.reveal_t = 20.0

func fire_missile(s: CShip, m: Mount, tg: CShip) -> void:
    var w = m.w; var p = world_pt(s, m.slot.x, m.slot.y)
    for i in int(w.count):
        missiles.append({"pos": p, "a": s.a + (randf() - 0.5) * 0.6, "v": 80.0, "speed": w.speed, "life": gun_range(s, w) / w.speed * 1.4, "dmg": w.dmg, "side": s.side, "target": tg, "kind": "ssm", "delay": i * 2.0})
    if s.sub: s.reveal_t = 25.0
    boom(p, 0.18, 1200.0, 0.6)

func fire_sam(s: CShip, m: Mount, tg) -> void:
    var p = world_pt(s, m.slot.x, m.slot.y); var tp: Vector2 = tg.pos
    missiles.append({"pos": p, "a": (tp - p).angle(), "v": 200.0, "speed": m.w.speed, "life": gun_range(s, m.w) / m.w.speed * 1.5, "dmg": 0, "side": s.side, "target": tg, "kind": "sam", "p": m.w.pd, "delay": 0.0})
    boom(p, 0.08, 1400.0, 0.8)

func reload_mult(s: CShip, w: Dictionary) -> float:
    var r = 0.5 + 0.5 * s.cf
    if w.kind == "gun": r *= 1 + 0.08 * s.sk.gun
    if w.kind == "torp" or w.kind == "ssm": r *= 1 + 0.12 * s.sk.ord
    return r

func nearest_air(side: int, p: Vector2, rng: float):
    var best = null; var bd = rng
    for q in air:
        if q.side == side or q.n <= 0: continue
        var dd: float = p.distance_to(q.pos)
        if dd < bd: bd = dd; best = q
    return best

func nearest_missile(side: int, p: Vector2, rng: float, for_sam := false):
    var best = null; var bd = rng
    for q in missiles:
        if q.side == side or q.kind != "ssm" or q.delay > 0: continue
        if for_sam and q.get("engaged", 0) >= 2: continue
        var dd: float = p.distance_to(q.pos)
        if dd < bd: bd = dd; best = q
    return best

func kill_missile(ms: Dictionary) -> void:
    ms.dead = true; fx_boom(ms.pos, 18.0, 0.5)

func flak(s: CShip, m: Mount, sq: Dictionary, chance: float) -> void:
    var p = world_pt(s, m.slot.x, m.slot.y); tracer(p, sq.pos)
    part(P.FLAK, sq.pos + Vector2(randf() - 0.5, randf() - 0.5) * 50.0, 0.6, 8.0)
    if randf() < chance * (0.6 if sq.jet else 1.0):
        sq.n -= 1; part(P.FALL, sq.pos + Vector2(randf() - 0.5, randf() - 0.5) * 30.0, 1.4, 6.0)

func update_weapons(s: CShip, dt: float) -> void:
    var is_player = s == flag; var sm = submerged(s)
    for m in s.mounts:
        if m.dead: m.st = ""; continue
        var w = m.w; m.cd -= dt * reload_mult(s, w); m.recoil = maxf(0.0, m.recoil - dt * 1.2)
        var p = world_pt(s, m.slot.x, m.slot.y)
        match w.kind:
            "gun":
                if sm or (s.sub and s.dive > 0.1): continue
                var rng = gun_range(s, w)
                var aim = null; var aim_lock = false; var aim_air = null; var manual = false
                if is_player and w.size == s.main_sz:
                    manual = true
                    var lock_ok = lock != null and engageable(lock) and visible_to(lock, 0)
                    var over_lock = lock_ok and lock.pos.distance_to(mouse_world) < maxf(lock.d.L * 0.7, 120.0)
                    if lock_ok and (not mouse_down or over_lock): aim = lead_point(p, lock, w.speed); aim_lock = true
                    elif mouse_down: aim = mouse_world
                    elif lock_ok: aim = lead_point(p, lock, w.speed); aim_lock = true
                    else: aim = mouse_world
                else:
                    m.tgt_t -= dt
                    if m.tgt_t <= 0 or m.tgt == null or not engageable(m.tgt) or not visible_to(m.tgt, s.side):
                        m.tgt_t = 3.0; m.tgt = null
                        var pri: CShip = null
                        if s.target != null and engageable(s.target) and visible_to(s.target, s.side) and p.distance_to(s.target.pos) < rng and arc_check(m.slot, ang_diff((s.target.pos - p).angle(), s.a)).x > 0: pri = s.target
                        var heavy: bool = w.size == "L" or w.size == "H"
                        var slot = m.slot; var sa = s.a
                        var f = func(o: CShip) -> bool: return arc_check(slot, ang_diff((o.pos - p).angle(), sa)).x > 0 and not submerged(o)
                        var bt = best_target(p, s.side, rng, f, heavy)
                        m.tgt = pri if (pri != null and not heavy) else (bt if bt != null else pri)
                        m.air = {}
                        if m.tgt == null and w.aa > 0:
                            var na = nearest_air(s.side, p, rng * 0.7)
                            if na != null: m.air = na
                    if m.tgt != null: aim = lead_point(p, m.tgt, w.speed)
                    elif not m.air.is_empty() and m.air.n > 0: aim = m.air.pos; aim_air = m.air
                if aim == null: # nothing in range: lay on the nearest enemy, so the turret is trained when one closes
                    m.rest_t -= dt
                    if m.rest_t <= 0:
                        m.rest_t = 2.0; m.rest_o = nearest_enemy(p, s.side, rng * 2.5, func(x: CShip) -> bool: return not submerged(x))
                    var o: CShip = m.rest_o if (m.rest_o != null and engageable(m.rest_o)) else null
                    var rest: float = arc_check(m.slot, ang_diff((o.pos - p).angle(), s.a)).y if o != null else m.slot.arcs[0][0]
                    m.ta += clampf(ang_diff(rest, m.ta), -TRAV[w.size] * dt, TRAV[w.size] * dt)
                    continue
                var want = ang_diff((aim - p).angle(), s.a)
                var ac = arc_check(m.slot, want)
                m.ta += clampf(ang_diff(ac.y, m.ta), -TRAV[w.size] * dt, TRAV[w.size] * dt)
                var aligned: bool = absf(ang_diff(want, m.ta)) < 0.04 and ac.x > 0
                var in_range = p.distance_to(aim) < rng
                var trigger = (mouse_down or (autofire and aim_lock)) if manual else true
                if manual:
                    m.st = "arc" if ac.x == 0 else "range" if not in_range else "train" if not aligned else "reload" if m.cd > 0 else "ready"
                    m.err = absf(ang_diff(want, m.ta)); gun_aim = {"pos": aim, "lock": aim_lock}
                if aligned and in_range and trigger and m.cd <= 0:
                    m.cd = w.rel
                    if aim_air != null: flak(s, m, aim_air, w.aa * 1.2)
                    else: fire_gun(s, m, aim, w)
            "aa":
                if sm or m.cd > 0: continue
                var done = false
                var ms = nearest_missile(s.side, p, w.range)
                if ms != null:
                    m.ta = ang_diff((ms.pos - p).angle(), s.a); m.cd = w.rel; tracer(p, ms.pos)
                    if randf() < w.pd: kill_missile(ms)
                    done = true
                if not done:
                    var sq = nearest_air(s.side, p, w.range)
                    if sq != null: m.ta = ang_diff((sq.pos - p).angle(), s.a); m.cd = w.rel; flak(s, m, sq, w.aa); done = true
                if not done and small_craft[1 - s.side]:
                    var o = nearest_enemy(p, s.side, w.range, func(x: CShip) -> bool: return not submerged(x) and (x.d.kind == "pt" or x.d.kind == "sub"))
                    if o != null:
                        m.ta = ang_diff((o.pos - p).angle(), s.a); m.cd = w.rel * 2; tracer(p, o.pos)
                        if randf() < 0.35: damage(o, w.dmg * 3, "shell")
            "sam":
                if m.cd > 0: continue
                var rng = gun_range(s, w)
                var ms = nearest_missile(s.side, p, rng, true)
                if ms != null: ms.engaged = ms.get("engaged", 0) + 1; m.cd = w.rel; fire_sam(s, m, ms); continue
                var sq = nearest_air(s.side, p, rng)
                if sq != null: m.cd = w.rel * 1.5; fire_sam(s, m, sq)
            "torp":
                if m.cd > 0: continue
                var rng = gun_range(s, w)
                if is_player:
                    if not want_torp: continue
                    var want = ang_diff((mouse_world - p).angle(), s.a)
                    if not arc_check(m.slot, want).x > 0: continue
                    m.ta = want; m.cd = w.rel; fire_torps(s, m, mouse_world); continue
                var tg: CShip = s.target if (s.target != null and engageable(s.target) and visible_to(s.target, s.side) and not submerged(s.target)) else nearest_enemy(s.pos, s.side, rng * 0.75, func(x: CShip) -> bool: return not submerged(x))
                if tg == null or p.distance_to(tg.pos) > rng * 0.75: continue
                var lp = lead_point(p, tg, w.speed); var want = ang_diff((lp - p).angle(), s.a)
                var ac = arc_check(m.slot, want)
                if ac.x == 0: m.ta += ang_diff(ac.y, m.ta) * minf(1.0, dt * 2); continue
                m.ta = want; m.cd = w.rel; fire_torps(s, m, lp); s.torp_run_t = 60.0
            "ssm":
                if m.cd > 0: continue
                var rng = gun_range(s, w)
                if is_player:
                    if not want_msl: continue
                    var tg: CShip = lock if (lock != null and engageable(lock) and visible_to(lock, 0) and not submerged(lock)) else nearest_enemy(mouse_world, 0, 3000.0, func(x: CShip) -> bool: return not submerged(x))
                    if tg == null or p.distance_to(tg.pos) > rng: continue
                    m.cd = w.rel; fire_missile(s, m, tg); continue
                var tg2: CShip = s.target if (s.target != null and engageable(s.target) and visible_to(s.target, s.side) and not submerged(s.target)) else nearest_enemy(s.pos, s.side, rng, func(x: CShip) -> bool: return not submerged(x))
                if tg2 != null and p.distance_to(tg2.pos) < rng: m.cd = w.rel * (0.8 + randf() * 0.5); fire_missile(s, m, tg2)
    if s.d.get("sonar", false) and not s.sub:
        s.dc_t -= dt
        if s.dc_t <= 0:
            var sb = nearest_enemy(s.pos, s.side, 260.0, func(o: CShip) -> bool: return o.sub and submerged(o))
            if sb != null:
                s.dc_t = 25.0; var st = world_pt(s, -s.d.L / 2, 0)
                for i in 6:
                    var q = part(P.DC, st + Vector2(randf() - 0.5, randf() - 0.5) * 90.0, 1.4, 24.0); q.life = -1.5 - i * 0.4; q.side = s.side; dcs.append({"pos": q.pos, "t": (1.5 + i * 0.4) * BT, "side": s.side})

# ------------------------------------------------------------------ damage
func damage(s: CShip, dmg: float, type: String) -> void:
    if not s.alive: return
    var hd = 0.0
    match type:
        "shell":
            var eff = dmg / (dmg + s.armor); hd = dmg * maxf(0.03, eff); s.armor = maxf(s.d.armor * 0.4, s.armor - dmg * 0.25 * eff)
        "torp": hd = dmg * (1 - minf(0.45, s.d.armor / 700.0))
        "missile": hd = dmg * (1 - minf(0.55, s.armor / 550.0))
        "bomb": hd = dmg * dmg / (dmg + s.armor * 0.7); s.armor = maxf(s.d.armor * 0.4, s.armor - dmg * 0.15)
        _: hd = dmg
    hd *= 1 - 0.07 * s.sk.dc
    s.hull -= hd; s.dmg_taken += hd; last_hit = t
    if s.side == 1 and not s.flee and s.hull / s.max_hull < 0.25 and randf() < 0.3: s.flee = true
    if s.hull <= 0:
        s.hull = 0; s.alive = false; s.sink = 0.001
        part(P.OIL, s.pos, 60.0, s.d.L * 0.45)
        for i in 24:
            var q = part(P.FIRE if i % 3 == 0 else P.SMOKE, s.pos + Vector2((randf() - 0.5) * s.d.L * 0.6, (randf() - 0.5) * s.d.B).rotated(s.a), 2.0 + randf() * 3.0, 10.0 + randf() * 18.0, Vector2(randf() - 0.5, randf() - 0.5) * 40.0, true)
        fx_boom(s.pos, s.d.L * 0.5, 1.0)
        say(("Enemy " if s.side == 1 else "Our ") + s.d.name.to_lower() + " " + s.rec.name + " is sinking!")
        boom(s.pos, 0.6, 160.0, 0.6)
        if lock == s: lock = null
        if s == flag: next_flag("Flagship lost! You transfer your flag to the ")
    elif s.side == 1 and not s.struck and not s.sub and s.hull / s.max_hull < 0.12 and s.d.kind != "pt":
        s.struck = true; s.throttle = 0; say(s.rec.name + " strikes her colours!")
        if lock == s: lock = null

## A hit leaves a scorch (and a hole for shells) in ship space; heavier hits may start a fire or knock out a mount.
func mark_hit(s: CShip, wp: Vector2, sz: float, hole: bool) -> void:
    if not s.alive: return
    var l = (wp - s.pos).rotated(-s.a)
    var x = clampf(l.x, -s.d.L * 0.46, s.d.L * 0.46); var hh = hull_half(s.d, x) * 0.85; var y = clampf(l.y, -hh, hh)
    s.marks.append({"x": x, "y": y, "r": (1.5 + sz * 2.2) * (0.7 + randf() * 0.6), "v": randi() % 4, "hole": hole})
    if s.marks.size() > 50: s.marks.pop_front()
    if randf() < 0.12 * sz: s.fires.append({"x": x, "y": y, "t": 60.0 + randf() * 180.0, "r": 0.8 + sz * 0.9, "st": 0.0})
    for m in s.mounts:
        if m.dead or m.w.kind == "sam" or m.w.kind == "ssm": continue
        if Vector2(m.slot.x - x, m.slot.y - y).length() < m.w.get("tw", 2.5) * 0.9 + 1 and randf() < 0.1 * sz:
            m.dead = true
            if s.side == 0: say("A " + m.w.name + " mount on the " + s.rec.name + " is knocked out!", 2.0)

func next_flag(m: String) -> void:
    for x in ships:
        if x.side == 0 and engageable(x): flag = x; say(m + x.rec.name + "."); return

# ------------------------------------------------------------------ AI
func steer_avoid(s: CShip, desired: float) -> float:
    var look: float = s.d.td * 1.2 + s.d.L + 300.0
    for is_ in islands:
        for k in [0.35, 0.7, 1.0]:
            if in_island(is_, s.pos + Vector2.from_angle(desired) * look * k, 250.0):
                var to_c: float = (is_.c - s.pos).angle()
                return desired + (1.0 if ang_diff(desired, to_c) >= 0 else -1.0)
    return desired

func yaw_lag(s: CShip) -> float: return 3.0 + s.d.L / 45.0

## Conning: order rudder towards a heading, easing it off early because the ship keeps swinging.
func helm(s: CShip, desired: float) -> float:
    return clampf((ang_diff(desired, s.a) - s.w * (yaw_lag(s) + 4.0)) * 4.0, -1.0, 1.0)

func ai_ship(s: CShip, dt: float) -> void:
    if s.struck: s.throttle = 0; s.rudder = 0; return
    if s.sub: s.want_dive = nearest_enemy(s.pos, s.side, 8000.0) != null
    var retreat = (order == "retreat") if s.side == 0 else s.flee
    if retreat:
        var o = nearest_enemy(s.pos, s.side)
        var home = PI / 2 if s.side == 0 else -PI / 2
        var away = (s.pos - o.pos).angle() if o != null else home
        var goal = away if absf(ang_diff(away, home)) < 1.4 else home + clampf(ang_diff(away, home), -0.9, 0.9)
        s.rudder = helm(s, steer_avoid(s, goal)); s.throttle = 4; return
    s.tgt_t -= dt
    if s.tgt_t <= 0 or s.target == null or not engageable(s.target) or not visible_to(s.target, s.side):
        s.tgt_t = 10.0; s.target = best_target(s.pos, s.side, INF, Callable(), true) if heavy_guns(s) else nearest_enemy(s.pos, s.side)
    var tg = s.target
    if s.side == 0 and order == "escort" and flag != null and flag != s:
        var close = nearest_enemy(s.pos, s.side, 3000.0)
        if close == null:
            var mine: Array = []
            for x in ships: if x.side == 0 and x != flag: mine.append(x)
            var idx = mine.find(s); var off = (1 if idx % 2 else -1) * (600.0 + 450.0 * floor(idx / 2.0))
            var g = flag.pos + Vector2.from_angle(flag.a + PI / 2) * off - Vector2.from_angle(flag.a) * 300.0
            var dd = s.pos.distance_to(g)
            s.rudder = helm(s, steer_avoid(s, (g - s.pos).angle() if dd > 250 else flag.a))
            s.throttle = 4 if dd > 900 else (maxi(2, flag.throttle) if dd > 250 else flag.throttle)
            return
        tg = close
    if tg == null: s.throttle = 2; s.rudder = helm(s, s.a); return
    var d = s.pos.distance_to(tg.pos); var to = (tg.pos - s.pos).angle()
    var pref = 0.0
    if s.d.kind == "carrier": pref = 15000.0
    elif s.d.kind == "merchant": pref = 9000.0
    elif s.sub or s.d.kind == "pt": pref = 6000.0 if s.torp_run_t > 0 else 2600.0
    elif has_kind(s, "ssm"): pref = 9000.0
    else: pref = max_gun_range(s) * 0.78
    if s.d.kind != "carrier" and s.d.kind != "merchant": pref *= maxf(0.5, 1 - t / 1500.0)
    s.torp_run_t -= dt; s.side_t -= dt
    if s.side_t <= 0:
        s.side_t = 40.0 + randf() * 30.0
        s.pref_side = -1 if absf(ang_diff(to + PI / 2, s.a)) < absf(ang_diff(to - PI / 2, s.a)) else 1
    var desired: float
    if d > pref + 600: desired = to - s.pref_side * 0.3
    elif d < pref * 0.55: desired = to + PI - s.pref_side * 0.5
    else: desired = to - s.pref_side * PI / 2
    if (s.d.kind == "pt" or s.sub) and s.torp_run_t <= 0: desired = to
    var mg: float = s.d.td + 800.0
    if s.pos.x < mg or s.pos.x > AW - mg or s.pos.y < mg or s.pos.y > AH - mg: desired = (Vector2(AW, AH) / 2 - s.pos).angle()
    s.rudder = helm(s, steer_avoid(s, desired))
    s.throttle = 4 if d > pref + 1500 else 3
    if s.d.kind == "carrier": launch_strike(s, nearest_enemy(s.pos, s.side, 30000.0, func(o: CShip) -> bool: return not submerged(o)))

func launch_strike(s: CShip, tg: CShip) -> bool:
    if tg == null or s.sub: return false
    var launched = 0
    for q in s.squads:
        if q.state != "ready" or q.n <= 0: continue
        var jet = s.tech.has("jets")
        air.append({"side": s.side, "home": s, "sq": q, "pos": s.pos, "a": s.a, "n": q.n, "type": "tb" if launched % 2 == 0 else "db", "jet": jet, "target": tg, "state": "out"})
        q.state = "out"; launched += 1
    if launched and s.side == 0: say(str(launched) + " squadron" + ("s" if launched > 1 else "") + " launched.", 2.0)
    if launched and s.side == 1: say("Enemy aircraft inbound!", 2.5)
    return launched > 0

func update_air(dt: float) -> void:
    for i in range(air.size() - 1, -1, -1):
        var q: Dictionary = air[i]; var sp = 220.0 if q.jet else 75.0
        if q.n <= 0: q.sq.n = 0; q.sq.state = "lost"; air.remove_at(i); continue
        if q.state == "out" and (q.target == null or not engageable(q.target)):
            q.target = nearest_enemy(q.pos, q.side, 40000.0, func(o: CShip) -> bool: return not submerged(o))
            if q.target == null: q.state = "home"
        var g: Vector2
        if q.state == "out":
            var tg: CShip = q.target; g = tg.pos; var d: float = q.pos.distance_to(tg.pos)
            if q.type == "tb" and d < 1300 and absf(ang_diff((tg.pos - q.pos).angle(), q.a)) < 0.35:
                var lp = lead_point(q.pos, tg, 18.0)
                for k in int(q.n): torps.append({"pos": q.pos + Vector2(randf() - 0.5, randf() - 0.5) * 150.0, "a": (lp - q.pos).angle() + (k - q.n / 2.0) * 0.05, "speed": 18.0, "life": 110.0, "dmg": 520 if q.jet else 420, "side": q.side, "homing": false, "arm": 8.0})
                q.state = "home"; boom(q.pos, 0.1, 900.0)
            elif q.type == "db" and d < 120:
                for k in int(q.n):
                    var hit = randf() < (0.55 if q.jet else 0.4)
                    var bp = tg.pos + Vector2((randf() - 0.5) * (tg.d.L * 0.4 if hit else 220.0), (randf() - 0.5) * (tg.d.B if hit else 220.0))
                    if hit: mark_hit(tg, bp, 3.0, true); damage(tg, 260 if q.jet else 230, "bomb"); fx_boom(bp, 26.0, 0.8)
                    else: fx_splash(bp, 22.0)
                q.state = "home"; boom(tg.pos, 0.4, 250.0)
        else:
            var home: CShip = q.home
            if not home.alive: q.n = 0; continue
            g = home.pos
            if q.pos.distance_to(g) < 150:
                q.sq.n = q.n; q.sq.state = "rearm"; q.sq.t = 300.0 / (1 + 0.12 * home.sk.ord); air.remove_at(i); continue
        q.a += clampf(ang_diff((g - q.pos).angle(), q.a), -0.3 * dt, 0.3 * dt)
        q.pos += Vector2.from_angle(q.a) * sp * dt
    for s in ships:
        for sq in s.squads:
            if sq.state == "rearm":
                sq.t -= dt
                if sq.t <= 0: sq.state = "ready"

# ------------------------------------------------------------------ step
func step(dtv: float) -> void:
    if finished: return
    var dt = dtv * BT
    t += dt; vt += dtv
    small_craft = [false, false]
    for s in ships: if active(s) and (s.d.kind == "pt" or s.d.kind == "sub"): small_craft[s.side] = true
    for s in ships:
        if not s.alive: s.sink += dtv; continue
        if s.escaped: continue
        s.reveal_t = maxf(0.0, s.reveal_t - dt); s.ram_t = maxf(0.0, s.ram_t - dt)
        # AI ships think four times a battle second and work their weapons ten times; your flagship every step
        if s == flag: s.rudder = player_rudder
        else:
            s.ai_acc += dt
            if s.ai_acc >= 0.25: ai_ship(s, s.ai_acc); s.ai_acc = 0.0
        if s.sub: s.dive = clampf(s.dive + (dt / 30.0 if s.want_dive else -dt / 30.0), 0.0, 1.0)
        s.wpn_acc += dt
        if s == flag or s.wpn_acc >= 0.1: update_weapons(s, s.wpn_acc); s.wpn_acc = 0.0
        var sm = submerged(s)
        # engines: way builds slowly in a big ship and bleeds off slower still; a hard turn scrubs off up to a third
        var top: float = (s.d.get("subKn", s.d.kn * 0.4) if sm else s.d.kn) * KN * speed_mult(s)
        var want: float = top * TELEGRAPH[s.throttle] * (1 - 0.3 * absf(s.rud) * minf(1.0, s.v / maxf(1.0, top)))
        var t_acc: float = 40.0 + s.d.L * 0.6
        s.v += clampf(want - s.v, -top / (t_acc * 1.4) * dt, top / t_acc * dt)
        # helm: about 10 s to put the rudder hard over, then the ship settles into a turn on its tactical diameter
        s.rud += clampf(s.rudder - s.rud, -dt / 10.0, dt / 10.0)
        var w_target: float = s.rud * s.v / (s.d.td / 2) * (1 + 0.1 * s.sk.helm) * (0.8 if sm else 1.0)
        s.w += (w_target - s.w) * minf(1.0, dt / yaw_lag(s))
        s.a += s.w * dt
        s.pos += Vector2.from_angle(s.a) * s.v * dt
        for is_ in islands:
            if in_island(is_, s.pos, s.d.B * 0.6):
                var ang: float = (s.pos - is_.c).angle()
                s.pos = is_.c + Vector2.from_angle(ang) * (island_r(is_, ang) + s.d.B * 0.6 + 1)
                if s.v > 2 and s.ram_t <= 0:
                    damage(s, s.v * s.d.L * 0.05, "ram"); s.ram_t = 5.0
                    if s == flag: say("We have run aground!", 2.0)
                s.v *= 0.4
        var retreating = (order == "retreat") if s.side == 0 else s.flee
        if retreating:
            var o = nearest_enemy(s.pos, s.side)
            var edge = s.pos.x < 200 or s.pos.x > AW - 200 or s.pos.y < 200 or s.pos.y > AH - 200
            if edge or o == null or s.pos.distance_to(o.pos) > ESCAPE_R:
                s.escaped = true; say(s.rec.name + (" escapes." if s.side == 1 else " has withdrawn safely."), 2.5)
                if s == flag: next_flag("You shift your flag to the ")
                continue
        s.pos = s.pos.clamp(Vector2(100, 100), Vector2(AW - 100, AH - 100))
        # wakes and smoke
        s.trail_t -= dtv
        if s.trail_t <= 0:
            s.trail_t = 0.2; s.trail.append(trail_point(s))
            while s.trail.size() and vt - s.trail[0].t > 18.0: s.trail.pop_front()
        s.wake_t -= dtv
        if s.wake_t <= 0 and s.v > 1 and sm: s.wake_t = 0.4; part(P.SWAKE, world_pt(s, -s.d.L * 0.48, 0), 3.0, s.d.B * 0.5)
        if not s.sub and s.d.p.has("fun") and s.d.p.fun.size():
            s.smoke_t -= dtv
            if s.smoke_t <= 0:
                s.smoke_t = 0.2
                for f in s.d.p.fun: part(P.FUNNEL, world_pt(s, f[0], f[3] if f.size() > 3 else 0.0), 5.0, 2.0 + s.d.B * 0.14, -Vector2.from_angle(s.a) * 3.0, true)
        # fires burn where they started, move with the ship and pour smoke downwind until damage control puts them out
        if s.hull / s.max_hull < 0.4 and s.fires.size() < 3 and randf() < dt * 0.01: mark_hit(s, s.pos + Vector2((randf() - 0.5) * s.d.L * 0.4, 0).rotated(s.a), 2.0, false)
        for i in range(s.fires.size() - 1, -1, -1):
            var f: Dictionary = s.fires[i]; f.t -= dt * (1 + 0.3 * s.sk.dc)
            if f.t <= 0: s.fires.remove_at(i); continue
            f.st -= dtv
            if f.st <= 0: f.st = 0.35; part(P.SMOKE, world_pt(s, f.x, f.y), 8.0 + randf() * 5.0, 3.0 + f.r * 2.5, Vector2.ZERO, true)
    want_torp = false; want_msl = false
    # collisions between surface ships
    var live: Array[CShip] = []
    for s in ships: if active(s) and not submerged(s): live.append(s)
    for i in live.size():
        for j in range(i + 1, live.size()):
            var a = live[i]; var b = live[j]; var ra: float = a.d.L * 0.3; var rb: float = b.d.L * 0.3; var dd = a.pos.distance_to(b.pos)
            if dd < ra + rb and dd > 0.01:
                var nrm = (b.pos - a.pos) / dd; var ov = (ra + rb - dd) / 2
                a.pos -= nrm * ov; b.pos += nrm * ov
                if a.side != b.side and a.ram_t <= 0 and b.ram_t <= 0:
                    var rv = absf(a.v - b.v) + 4
                    damage(b, rv * a.d.L * 0.1, "ram"); damage(a, rv * b.d.L * 0.1, "ram"); a.ram_t = 8.0; b.ram_t = 8.0; a.v *= 0.5; b.v *= 0.5
    # shells land
    for i in range(shells.size() - 1, -1, -1):
        var sh: Dictionary = shells[i]; sh.t += dt; var k: float = minf(1.0, sh.t / sh.T); sh.pos = sh.s.lerp(sh.e, k)
        if sh.t < sh.T: continue
        shells.remove_at(i)
        var hit: CShip = null
        for s in ships:
            if s.side == sh.side or not active(s) or submerged(s): continue
            var l: Vector2 = (sh.pos - s.pos).rotated(-s.a)
            if absf(l.x) < s.d.L / 2 + 3 and absf(l.y) < s.d.B / 2 + 3: hit = s; break
        var sz: float = {"S": 1.0, "M": 1.5, "L": 2.3, "H": 3.4}[sh.size]
        if hit != null:
            mark_hit(hit, sh.pos, sz, true); damage(hit, sh.dmg, "shell"); fx_boom(sh.pos, 7 * sz, 0.6)
            for k2 in 3: part(P.SPARK, sh.pos, 0.4 + randf() * 0.4, 1 + sz * 0.6, Vector2(randf() - 0.5, randf() - 0.5) * 60.0)
            boom(sh.pos, 0.12 * sz, 600.0)
        elif land_at(sh.pos): part(P.DUST, sh.pos, 1.6, 9 * sz)
        else: fx_splash(sh.pos, 6 * sz)
    # torpedoes
    for i in range(torps.size() - 1, -1, -1):
        var tp: Dictionary = torps[i]; tp.life -= dt; tp.arm -= dt
        if tp.homing and tp.arm <= 0:
            var tpa: float = tp.a; var tpp: Vector2 = tp.pos
            var tg = nearest_enemy(tp.pos, tp.side, 1200.0, func(o: CShip) -> bool: return not submerged(o) and absf(ang_diff((o.pos - tpp).angle(), tpa)) < 0.7)
            if tg != null: tp.a += clampf(ang_diff((tg.pos - tp.pos).angle(), tp.a), -0.15 * dt, 0.15 * dt)
        tp.pos += Vector2.from_angle(tp.a) * tp.speed * dt
        var gone: bool = tp.life <= 0
        if not gone and land_at(tp.pos): gone = true; fx_boom(tp.pos, 20.0)
        if not gone and tp.arm <= 0:
            for s in ships:
                if s.side == tp.side or not active(s) or submerged(s): continue
                var l: Vector2 = (tp.pos - s.pos).rotated(-s.a)
                if absf(l.x) < s.d.L / 2 and absf(l.y) < s.d.B / 2 + 2:
                    mark_hit(s, tp.pos, 4.0, false); damage(s, tp.dmg, "torp"); part(P.GEYSER, tp.pos, 1.6, 40.0); part(P.FOAM, tp.pos, 12.0, 60.0)
                    boom(tp.pos, 0.5, 200.0, 0.7); gone = true; break
        if not gone and randf() < dtv * 4: part(P.TWAKE, tp.pos, 4.0, 1.5)
        if gone: torps.remove_at(i)
    # missiles
    for i in range(missiles.size() - 1, -1, -1):
        var m: Dictionary = missiles[i]
        if m.get("dead", false): missiles.remove_at(i); continue
        if m.delay > 0: m.delay -= dt; continue
        m.life -= dt; m.v = minf(m.speed, m.v + m.speed * dt)
        var tg = m.target; var alive = false
        if tg != null:
            if m.kind == "sam": alive = (tg is Dictionary and ((tg.has("n") and tg.n > 0) or (tg.get("kind", "") == "ssm" and not tg.get("dead", false))))
            else: alive = tg is CShip and engageable(tg)
        if m.kind == "ssm" and not alive:
            m.target = nearest_enemy(m.pos, m.side, 6000.0, func(o: CShip) -> bool: return not submerged(o)); alive = m.target != null
        if alive:
            var tpos: Vector2 = m.target.pos; var turn = 4.0 if m.kind == "sam" else 2.2
            m.a += clampf(ang_diff((tpos - m.pos).angle(), m.a), -turn * dt, turn * dt)
            var d: float = m.pos.distance_to(tpos)
            if m.kind == "sam" and d < 40:
                if randf() < m.p:
                    if m.target.get("kind", "") == "ssm": kill_missile(m.target)
                    else: m.target.n -= 2; part(P.FALL, tpos, 1.4, 6.0)
                part(P.FLAK, m.pos, 0.5, 14.0); missiles.remove_at(i); continue
            if m.kind == "ssm" and d < maxf(20.0, m.target.d.B):
                mark_hit(m.target, m.pos, 4.0, false); mark_hit(m.target, m.pos, 3.0, false); damage(m.target, m.dmg, "missile")
                fx_boom(m.pos, 40.0, 0.9); part(P.FIRE, m.pos, 2.0, 12.0); boom(m.pos, 0.5, 220.0); missiles.remove_at(i); continue
        m.pos += Vector2.from_angle(m.a) * m.v * dt
        if randf() < dtv * 30: part(P.MTRAIL, m.pos, 1.0 if m.kind == "sam" else 2.0, 4.0)
        if m.life <= 0:
            if m.kind == "ssm": fx_splash(m.pos, 14.0)
            missiles.remove_at(i)
    update_air(dt)
    for i in range(dcs.size() - 1, -1, -1):
        var q = dcs[i]; q.t -= dt
        if q.t > 0: continue
        dcs.remove_at(i); boom(q.pos, 0.25, 150.0, 0.6)
        for s in ships:
            if s.sub and active(s) and s.side != q.side and s.pos.distance_to(q.pos) < 60: damage(s, 160, "dc"); s.reveal_t = 30.0
    # end of the action: one side gone, or fifteen battle minutes without a hit and nothing in flight
    var mine = 0; var theirs = 0
    for s in ships:
        if engageable(s):
            if s.side == 0: mine += 1
            else: theirs += 1
    var quiet = t - last_hit > 900 and shells.is_empty() and torps.is_empty() and missiles.is_empty() and air.is_empty()
    if mine == 0 or theirs == 0 or quiet:
        end_t += dtv / BT
        if not end_msg:
            end_msg = true; say("The enemy is beaten!" if theirs == 0 else ("Contact lost." if mine and theirs else "Action over."), 3.0)
        if end_t > 2.5: _finish()

func trail_point(s: CShip) -> Dictionary:
    var sx: float = s.d.L * 0.3; var sy = hull_half(s.d, sx)
    return {"p": world_pt(s, -s.d.L * 0.47, 0), "l": world_pt(s, sx, -sy), "r": world_pt(s, sx, sy), "a": s.a, "t": vt, "v": s.v, "sm": submerged(s)}

## Visual effects advance once per frame, in visual seconds.
func fx(dtv: float) -> void:
    for i in range(parts.size() - 1, -1, -1):
        var q = parts[i]; q.life += dtv
        if q.wind and q.life > 0: q.pos += WIND * dtv
        if q.vel != Vector2.ZERO:
            q.pos += q.vel * dtv; q.vel *= pow(0.16, dtv)
        if q.life >= q.mx: parts.remove_at(i)
    if parts.size() > 2400:
        parts.reverse(); parts.resize(2400); parts.reverse()
    for i in range(tracers.size() - 1, -1, -1):
        tracers[i].life -= dtv
        if tracers[i].life <= 0: tracers.remove_at(i)

func _finish() -> void:
    finished = true
    var r = {"sunk": [], "lost": [], "struck": [], "escaped": [], "victory": false}
    for s in ships:
        if s.side == 0:
            if not s.alive: r.lost.append(s.rec.name + " (" + s.d.name + ")")
        else:
            if not s.alive: r.sunk.append(s.rec.name + " (" + s.d.name + ")")
            elif s.struck: r.struck.append(s.rec.name + " (" + s.d.name + ")")
            elif s.escaped: r.escaped.append(s.rec.name + " (" + s.d.name + ")")
    var enemy_left = false
    for s in ships: if s.side == 1 and engageable(s): enemy_left = true
    var mine_left = false
    for s in ships: if s.side == 0 and s.alive: mine_left = true
    r.victory = not enemy_left and mine_left
    r.time = t
    result = r
