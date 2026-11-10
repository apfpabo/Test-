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

enum P { FOAM, OIL, SWAKE, TWAKE, SPLASH, GEYSER, BLAST, DC, SMOKE, GUNSMOKE, FUNNEL, DUST, FLAK, MTRAIL, FLASH, BOOM, FIRE, SPARK, FALL,
    CORE, FIREBALL, RING, DEBRIS, EMBER, SPRAY, WRING, GLOW, CHURN, FLARE, SOOT, WASH, STEAM }   # the modern effects (Settings.fx_modern)

class Mount:
    var slot: Dictionary
    var wid: String
    var w: Dictionary
    var ta = 0.0
    var cd = 0.0
    var recoil = 0.0
    var rec := PackedFloat32Array()   # recoil of each barrel, 1 just fired
    var queue: Array = []             # barrels still to fire in the current salvo: {i, t, aim}
    var half := 0                     # which half of the barrels fired first last time (alternating half-salvos)
    var ammo := -1                    # rounds (guns: shells for all barrels; AA: bursts; torpedoes and missiles: salvos) left
    var ammo_max := -1
    var tgt: CShip = null
    var tgt_t = 0.0
    var air: Dictionary = {}
    var st = ""
    var err = 0.0
    var dead = false
    var rest_t = 0.0
    var rest_o: CShip = null
    var lvl = 0        # 0 on the deck; 1 and up for superfiring mounts whose barrels pass over the one ahead
    var clear := PackedByteArray()   # 1 per 2-degree bearing bin (ship frame) where the barrels clear the ship's own structure

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
    var lit_t = 99.0       # seconds since her own guns last fired: gun flashes give a ship away in the dark
    var radar_only := false   # an enemy held by your radar alone, beyond the eye's reach (see BattleSim._radar_plot)
    var paint_t := 99.0       # battle seconds since a radar sweep last painted her
    var paint_pos := Vector2.ZERO
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
    # internal subsystems (see hit_systems): machinery and fire control as 0..1, timers in battle seconds
    var eng = 1.0          # machinery: scales top speed
    var eng_out = 0.0      # engines stopped for this long
    var jam = 0.0          # rudder jammed for this long
    var ld_speed = 1.0     # her loading (see loading): speed, helm and the spread of her salvos
    var ld_turn = 1.0
    var ld_spread = 1.0
    var steer = 1.0        # steering gear: scales how hard she can turn (hits right aft wear it down)
    var list = 0.0         # -1 to 1: flooded to port or starboard; she is slower, turns worse and pulls to her low side
    var smoke_on = false   # laying a smoke screen
    var smoke_left = 60.0  # seconds of smoke in the generators
    var smoke_d = 0.0
    var v_cmd = -1.0       # a speed to hold (m/s) when keeping station, or -1 for the engine telegraph
    var jam_r = 0.0        # where it jammed
    var fc = 1.0           # fire control: salvo spread grows as it falls
    var mag_fire = 0.0     # a magazine fire burning: seconds until it reaches the charges (0 = none)
    var mag_x = 0.0        # where along the hull
    var flooded: Array = [] # magazines flooded by damage control (their x along the hull)
    var dc_left = 0        # depth-charge patterns left
    var up: Dictionary = {} # fitted system upgrades, 0-2 each: eng, hull, mag, fc, radar, sonar (see UPGRADES)
    var shell_mode = "auto"   # the flagship's choice of shell: auto, ap, he or inc (AI ships always auto)
    var last_shell = ""       # the shell her guns last loaded (shown on the shell panel when the choice is auto)
    var fuel_k = 1.0       # 0.25 when the bunkers are dry: steerage way on emergency reserves

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
    var drag = 0.16       # fraction of speed kept per second
    var spin = 0.0        # radians per second (smoke and fireballs turn as they roll)

var AW = 26000.0
var AH = 22000.0
var sep := 9000.0             # the range the action opens at: 9 km by default, more when contact was made at missile or carrier reach
var escape_r := ESCAPE_R
var ships: Array[CShip] = []
var shells: Array = []
var torps: Array = []
var missiles: Array = []
var air: Array = []
var parts: Array[Part] = []
var modern := true                 # the modern effects: layered explosions, light, spray (Settings.fx_modern); false = classic
var flash := 0.0                   # a magazine going up lights the whole sky for a moment
var wx: Dictionary = Weather.CLEAR  # the weather and light the battle is fought in (Weather.battle): sea, fog, night, moon, vis, radar
var tracers: Array = []
var hit_marks: Array = []        # floating hit results for the HUD: {pos, text, col, t, ours}
var islands: Array = []
var order = "engage"
var hold_fire := false            # squadron order: every ship but the flagship holds her fire (to stay unseen at night, or save shells)
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
var waypoints: Array = []   # Ctrl+Click: points the flagship steers through when you are not at the helm yourself
var aim_mode = 0          # 0 none, 1 hold-fire at a point
var mouse_world = Vector2.ZERO
var mouse_down = false
var gun_aim: Dictionary = {}
var msg = "Battle stations!"
var msg_t = 3.0
var finished = false
var result: Dictionary = {}
var enemy_era = 1
var sonar_tech = false
var helo_tech = false   # ASW helicopters: the player's sonar reaches farther
var on_boom: Callable    # (pos, vol, freq, rate) for sound
var on_pop: Callable     # (pos, vol, weapon id) for light AA and point-defence fire
var on_sound: Callable   # (kind, pos, vol) for recorded events: see Sfx.event
var sys_log := {}        # subsystem events this battle, for tests and balance
func _log(k: String) -> void: sys_log[k] = sys_log.get(k, 0) + 1
var small_craft = [false, false]  # whether each side still has torpedo boats or submarines afloat
var dcs: Array = []              # depth charges sinking towards their set depth

static func ang_diff(a: float, b: float) -> float:
    return wrapf(a - b, -PI, PI)

func say(m: String, dur := 3.0) -> void:
    msg = m; msg_t = dur

func boom(p: Vector2, vol: float, freq := 420.0, rate := 1.0) -> void:
    if on_boom.is_valid(): on_boom.call(p, vol, freq, rate)

func sound(kind: String, p: Vector2, vol: float) -> void:
    if on_sound.is_valid(): on_sound.call(kind, p, vol)

func pop(p: Vector2, vol: float, wid := "") -> void:
    if on_pop.is_valid(): on_pop.call(p, vol, wid)

## Light AA or point-defence burst: a tracer, a small flash at the mount and its report.
func aa_shot(s: CShip, m: Mount, p: Vector2, q: Vector2) -> void:
    if m.w.kind == "aa": use_round(m)
    tracer(p, q, m.wid, s.side)
    var f = part(P.FLASH, p, 0.12, 3.0 if m.wid != "aa20" else 2.0); f.a = (q - p).angle()
    if modern:   # each burst lights the mount and throws a little smoke and a spent-case spark or two
        var dir := (q - p).normalized()
        part(P.GLOW, p, 0.1, 14.0 if m.wid != "aa20" else 9.0)
        if randf() < 0.4: part(P.GUNSMOKE, p + dir * 2.0, 1.6 + randf(), 2.0 + randf() * 1.5, dir * (6.0 + randf() * 6.0), true)
        if randf() < 0.5: part(P.SPARK, p, 0.25 + randf() * 0.2, 0.5, dir.rotated(randf_range(1.2, 2.0) * (1.0 if randf() < 0.5 else -1.0)) * (20.0 + randf() * 30.0))
    pop(p, 0.22 if m.wid == "aa20" else (0.4 if m.wid == "ciws" else 0.32), m.wid)

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
    sonar_tech = player_tech.has("sonar"); helo_tech = player_tech.has("helo")
    escape_r = maxf(ESCAPE_R, sep + 2500.0)
    _place(player_recs, 0, player_tech); _place(enemy_recs, 1, enemy_tech)
    flag = ships[0]
    if sep > 9500.0: say("Contact at long range: their ships lie beyond the guns. Missiles and aircraft open the action.", 5.0)

func _place(list: Array, side: int, tech: Array) -> void:
    var k = list.size()
    for i in k:
        var x = AW / 2 + (i - (k - 1) / 2.0) * 700.0 + (randf() - 0.5) * 120.0
        var y = (AH / 2 - sep / 2 - (i % 2) * 400.0) if side == 1 else (AH / 2 + sep / 2 + (i % 2) * 400.0)
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
    s.up = rec.get("up", {})   # other navies' ships carry their refits into action too
    s.v = d.kn * KN * 0.6; s.max_hull = d.hull * (1.0 + 0.08 * upg(s, "hull")); s.hull = s.max_hull * rec.hullFrac; s.armor = d.armor * (1.0 + 0.1 * upg(s, "hull")) * (0.6 + 0.4 * rec.hullFrac)
    s.pref_side = 1 if randf() < 0.5 else -1; s.tech = tech; s.sub = d.kind == "sub"
    # what she is loaded with tells at sea, whoever's she is (owner's decision: other navies are held to the same rules)
    var ld := loading(d, rec.fit, s.up); s.ld_speed = ld.speed; s.ld_turn = ld.turn; s.ld_spread = ld.spread
    for i in d.slots.size():
        var wid: String = rec.fit[i]
        if wid == "" or not GameData.weapons.has(wid): continue
        var m = Mount.new(); m.slot = d.slots[i]; m.wid = wid; m.w = GameData.weapons[wid]; m.ta = m.slot.arcs[0][0]; m.cd = randf() * m.w.rel * 0.5
        m.ammo_max = full_ammo(wid, m.w); m.ammo = int(round(m.ammo_max * float(rec.get("ammo", 1.0)))) if m.ammo_max > 0 else -1
        s.mounts.append(m)
    if d.get("sonar", false) and d.kind != "sub": s.dc_left = int(round(6 * float(rec.get("ammo", 1.0))))
    # aircraft aboard: a campaign carrier may be short of planes lost in earlier strikes (rec.air)
    var aboard: int = int(rec.get("air", int(d.get("hangar", 0)) * 6))
    for i in int(d.get("hangar", 0)):
        var n := clampi(aboard - i * 6, 0, 6)
        s.squads.append({"state": "ready" if n > 0 else "lost", "t": 0.0, "n": n})
    if side == 1 and d.kind == "merchant": s.flee = true
    var best = -1
    for m in s.mounts: if m.w.kind == "gun": best = maxi(best, GUN_SIZES.find(m.w.size))
    s.main_sz = GUN_SIZES[maxi(best, 0)]
    superfiring(s)
    for m in s.mounts: if m.w.kind == "gun": m.clear = clear_bearings(s, m)
    return s

const BINS := 180
static func bin_of(a: float) -> int: return int(floor((wrapf(a, -PI, PI) + PI) / TAU * BINS)) % BINS
static func bin_angle(i: int) -> float: return -PI + (i + 0.5) * TAU / BINS

## Bearings at which a gun can point without its barrels running into its own ship: the superstructure, funnels,
## a carrier's flight deck and island, or another turret standing as high or higher. A raised turret may pass over a
## lower one; nothing passes through the bridge. The design's own firing arcs still apply on top of this.
func clear_bearings(s: CShip, m: Mount) -> PackedByteArray:
    var d := s.d; var p: Dictionary = d.p; var w := m.w
    var mp := Vector2(m.slot.x, m.slot.y)
    var reach: float = w.tl * 0.42 + w.bl; var pad: float = w.get("bw", 0.4) * 1.2 + 0.3
    var rects := []   # Rect2 obstacles in ship space
    for b in p.get("sup", []):
        # each deck of a block, shrinking as the plan draws it; a mount standing on a deck clears only that deck
        var tiers: int = int(b[3]) if b.size() > 3 else 1
        for tt in tiers:
            var ll: float = b[1] * (1 - tt * 0.17); var ww: float = b[2] * (1 - tt * 0.14); var xx: float = b[0] + b[1] * 0.06 * tt
            var r := Rect2(xx - ll / 2.0, -ww / 2.0, ll, ww)
            if not r.grow(0.5).has_point(mp): rects.append(r.grow(pad))
    if p.has("fd"):
        var fd: Dictionary = p.fd; var fl: float = d.L * fd.len; var fx: float = fd.get("x", 0.0)
        var r := Rect2(fx - fl / 2, -fd.w / 2.0, fl, fd.w)
        if not r.has_point(mp): rects.append(r.grow(pad))
        if fd.has("isl"):   # a flat-top (the Ryujo) has no island to mask her guns
            var isl: Array = fd.isl; var iy: float = fd.w / 2.0 - isl[2] / 2.0 + 1.2
            rects.append(Rect2(isl[0] - isl[1] / 2.0, iy - isl[2] / 2.0, isl[1], isl[2]).grow(pad))
    var funnels := []
    for fu in p.get("fun", []): funnels.append([Vector2(fu[0], fu[3] if fu.size() > 3 else 0.0), fu[1] + pad, fu[2] + pad])
    var houses := []  # other turrets as high or higher than this one
    for o in s.mounts:
        if o == m or o.w.kind != "gun" or o.lvl < m.lvl: continue
        houses.append([Vector2(o.slot.x, o.slot.y), o.w.tw * 0.5 + pad])
    var out := PackedByteArray(); out.resize(BINS)
    for i in BINS:
        var a := bin_angle(i); var dir := Vector2.from_angle(a); var ok := true
        # inside the design's arcs at all?
        var in_arc := false
        for arc in m.slot.arcs: if absf(ang_diff(a, arc[0])) <= arc[1]: in_arc = true
        if not in_arc: out[i] = 0; continue
        var t: float = w.tl * 0.3
        while t <= reach and ok:
            var q := mp + dir * t
            for r in rects: if r.has_point(q): ok = false
            for fu in funnels:
                var dq: Vector2 = q - fu[0]
                if pow(dq.x / fu[1], 2) + pow(dq.y / fu[2], 2) < 1.0: ok = false
            for h in houses: if q.distance_to(h[0]) < h[1]: ok = false
            t += 0.8
        out[i] = 1 if ok else 0
    # never leave a mount with nowhere to rest: its stowed bearing always counts as clear
    out[bin_of(m.slot.arcs[0][0])] = 1
    return out

## Whether a mount can bear on a local bearing: x is 1 if it can, y is the nearest bearing it can reach.
func mount_arc(m: Mount, local: float) -> Vector2:
    if m.clear.is_empty(): return arc_check(m.slot, local)
    var b := bin_of(local)
    if m.clear[b]: return Vector2(1.0, local)
    for k in range(1, BINS / 2 + 1):
        if m.clear[(b + k) % BINS]: return Vector2(0.0, bin_angle((b + k) % BINS))
        if m.clear[(b - k + BINS) % BINS]: return Vector2(0.0, bin_angle((b - k + BINS) % BINS))
    return Vector2(0.0, m.slot.arcs[0][0])

## Trains a turret towards a bearing, going the long way round when the short way would sweep through its own ship.
func train(m: Mount, target: float, step: float) -> void:
    var d := ang_diff(target, m.ta)
    if not m.clear.is_empty() and absf(d) > 0.03:
        var n := int(ceil(absf(d) / (TAU / BINS))); var blocked := false
        for k in range(1, n + 1):
            if not m.clear[bin_of(m.ta + d * k / n)]: blocked = true; break
        if blocked: d = d - signf(d) * TAU
    m.ta = wrapf(m.ta + clampf(d, -step, step), -PI, PI)

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
                if a.slot.get("low", false): continue                               # a third turret on the deck behind a raised one (Nelson's X)
                if absf(a.slot.y - b.slot.y) > (a.w.tw + b.w.tw) * 0.3: continue    # on the same line
                if absf(bx - ax) > a.w.tl * 0.42 + a.w.bl + b.w.tw * 0.6: continue   # a's barrels reach over b
                a.lvl = maxi(a.lvl, b.lvl + 1)
    for m in s.mounts: s.max_lvl = maxi(s.max_lvl, m.lvl)

# ------------------------------------------------------------------ queries
func world_pt(s: CShip, lx: float, ly: float) -> Vector2:
    return s.pos + Vector2(lx, ly).rotated(s.a)

func active(s: CShip) -> bool: return s.alive and not s.escaped
func engageable(s: CShip) -> bool: return s.alive and not s.escaped and not s.struck
## Magazine depth for a mount: shells for all its guns (by calibre), AA bursts, torpedo salvos (with one reload),
## missile salvos and SAM rounds. Roughly a long day's action for big guns; light AA can run dry in a long air fight.
static func full_ammo(wid: String, w: Dictionary) -> int:
    match String(w.kind):
        "gun": return int(w.get("barrels", 1)) * int({"H": 100, "L": 150, "M": 250, "S": 300}[w.size])
        "aa": return 60 if wid == "ciws" else (600 if wid == "aa20" else 400)
        "torp": return 2
        "ssm": return 4
        "sam": return 40
    return -1

## How full a ship's magazines are, 0..1, weighted by what the weapons cost (for the campaign to carry over).
## Planes a carrier brings home: squadrons aboard, plus those still in the air when the battle ends.
func planes_left(s: CShip) -> int:
    var n := 0
    for sq in s.squads:
        if sq.state == "out":
            for q in air: if is_same(q.sq, sq): n += int(q.n)   # the same squadron, not one that merely looks the same
        elif sq.state != "lost": n += int(sq.n)
    return n

func ammo_frac(s: CShip) -> float:
    var have := 0.0; var full := 0.0
    for m in s.mounts:
        if m.ammo_max <= 0: continue
        var wt: float = float(m.w.price); have += wt * float(m.ammo) / m.ammo_max; full += wt
    return have / full if full > 0 else 1.0

func use_round(m: Mount, n := 1) -> bool:
    if m.ammo < 0: return true
    if m.ammo < n: m.ammo = 0; return false
    m.ammo -= n; return true

func submerged(s: CShip) -> bool: return s.sub and s.dive > 0.6

func detected_by(sb: CShip, side: int) -> bool:
    if not submerged(sb) or sb.reveal_t > 0: return true
    for o in ships:
        if o.side != side or not active(o): continue
        var dd = o.pos.distance_to(sb.pos)
        if dd < 500.0 or dd < sonar_range(o): return true  # a surface ship's sonar, or a boat's hydrophones hearing another
    return false

## Whether a side can see a ship. Submarines as before (sonar). In bad visibility or at night a surface ship is seen
## only within sight of some ship of that side: the eye's reach in this weather, or the radar's for a ship that has
## one. A ship that has just fired, or is burning, shows at twice the distance: she lights herself up.
## Radar (docs/SENSORS.md). A surface ship of a side that has researched it carries a search set; submarines carry
## none (they listen: sonar). Sets of the first two eras turn a beam round the horizon, about six turns a minute, and
## see a contact once each turn; phased arrays (the Aegis research) look every way at once.
const RADAR_PERIOD := 10.0   # battle seconds for one turn of a rotating aerial
func has_radar(s: CShip) -> bool: return not s.sub and (s.tech.has("radar") or upg(s, "radar") > 0)
func phased(s: CShip) -> bool: return s.tech.has("aegis")
## Where a ship's search aerial stands: her foremast (the plan's `mast`), a carrier's island, else her bridge.
func radar_pos(o: CShip) -> Vector2:
    var p: Dictionary = o.d.get("p", {}); var x: float = o.d.L * 0.1; var y := 0.0
    if p.has("mast") and not p.mast.is_empty(): x = float(p.mast[0][0])
    elif p.has("fd") and p.fd.has("isl"): x = float(p.fd.isl[0]); y = float(p.fd.w) / 2.0 - float(p.fd.isl[2]) / 2.0 + 1.2
    elif p.has("sup") and not p.sup.is_empty(): x = float(p.sup[0][0])
    return world_pt(o, x, y)
func radar_angle() -> float: return fposmod(t / RADAR_PERIOD, 1.0) * TAU
## How far a ship's sonar hears a submerged boat (a surface ship's active set, or a boat's own hydrophones); 0 if none.
func sonar_range(o: CShip) -> float:
    var base: float = 1500.0 * ((1.6 if sonar_tech else 1.0) * (1.4 if helo_tech else 1.0) if o.side == 0 else (1.6 if enemy_era >= 2 else 1.0) * (1.4 if enemy_era >= 3 else 1.0))
    if o.sub: return base * 1.4
    return base * (1.0 + 0.3 * upg(o, "sonar")) if o.d.get("sonar", false) else 0.0
## Whether the lookouts of a side have a surface ship in sight by eye alone (no radar): within sight in this weather
## and light of one of its ships; twice as far if she has just fired or is burning.
func eye_sees(s: CShip, side: int) -> bool:
    var lim := limited()
    if not lim and screens.is_empty(): return true
    var r: float = float(wx.vis) * (2.0 if (s.lit_t < 6.0 or not s.fires.is_empty() or s.mag_fire > 0) else 1.0)
    for o in ships: if o.side == side and active(o) and (not lim or o.pos.distance_squared_to(s.pos) < r * r) and not smoke_blocks(o.pos, s.pos): return true
    return false
## Your radar plot, each step: an enemy beyond the eye's reach but inside a radar's is a contact on the plot, not a
## ship in sight. A rotating set paints her as its beam passes her bearing and the echo fades until the next turn; a
## phased array holds her all the time. (Gunnery uses the plot either way: `visible_to` is unchanged.)
func _radar_plot(dt: float) -> void:
    var a1 := radar_angle(); var a0 := a1 - dt / RADAR_PERIOD * TAU
    for e in ships:
        if e.side != 1 or not active(e): continue
        e.paint_t += dt
        if not limited() or eye_sees(e, 0) or (e.sub and submerged(e)): e.radar_only = false; continue
        e.radar_only = true
        for o in ships:
            if o.side != 0 or not active(o) or not has_radar(o) or submerged(o): continue
            var r := sight(o)
            if o.pos.distance_squared_to(e.pos) > r * r: continue
            # the beam turned from a0 to a1 this step: did it cross her bearing?
            if phased(o) or fposmod((e.pos - radar_pos(o)).angle() - a0, TAU) <= a1 - a0 + 0.0001: e.paint_t = 0.0; e.paint_pos = e.pos; break

func sight(o: CShip) -> float:
    var v: float = float(wx.vis)
    if has_radar(o): v = maxf(v, float(wx.radar) * (1.0 + 0.15 * upg(o, "radar")) * (1.15 if o.tech.has("datalink") else 1.0))
    return v
func limited() -> bool: return float(wx.vis) > 0.0
# ------------------------------------------------------------------ smoke screens
## A destroyer or cruiser can lay smoke from her generators and funnels: a wall of it astern of her that hangs and
## drifts for over a minute. Nobody sees through it by eye, from either side (a ship inside it is blind too); radar
## does. `screens` holds the smoke as overlapping round cells.
const SMOKE_LIFE := 80.0
const SMOKE_CHARGE := 60.0
var screens: Array = []     # {p, r, t}
var scr_box := Rect2()
func can_smoke(s: CShip) -> bool: return active(s) and not s.sub and s.d.kind != "merchant" and s.d.kind != "carrier"
func make_smoke(s: CShip, on: bool) -> bool:
    if on and (not can_smoke(s) or s.smoke_left < 8.0): return false
    s.smoke_on = on; return true
func _smoke_tick(dt: float) -> void:
    for s in ships:
        if not s.smoke_on: s.smoke_left = minf(SMOKE_CHARGE, s.smoke_left + dt * 0.3); continue
        s.smoke_left -= dt
        if s.smoke_left <= 0.0 or not can_smoke(s): s.smoke_on = false; if s.side == 0 and s.alive: say("The %s's smoke is spent." % s.rec.name, 1.5)
        s.smoke_d += maxf(s.v, 2.0) * dt
        if s.smoke_d >= 45.0: s.smoke_d = 0.0; screens.append({"p": s.pos - Vector2.from_angle(s.a) * s.d.L * 0.45, "r": 60.0, "t": 0.0, "v": randi() % 4})
    if screens.is_empty(): return
    var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF); var i := 0
    while i < screens.size():
        var c: Dictionary = screens[i]; c.t += dt; c.r = minf(200.0, 60.0 + c.t * 7.0); c.p += WIND * 0.25 * dt
        if c.t > SMOKE_LIFE: screens.remove_at(i); continue
        lo = lo.min(c.p - Vector2(c.r, c.r)); hi = hi.max(c.p + Vector2(c.r, c.r)); i += 1
    scr_box = Rect2(lo, hi - lo) if not screens.is_empty() else Rect2()
## Is there smoke between two points?
func smoke_blocks(a: Vector2, b: Vector2) -> bool:
    if screens.is_empty(): return false
    if maxf(a.x, b.x) < scr_box.position.x or minf(a.x, b.x) > scr_box.end.x or maxf(a.y, b.y) < scr_box.position.y or minf(a.y, b.y) > scr_box.end.y: return false
    var ab := b - a; var l2 := ab.length_squared()
    for c in screens:
        var r: float = float(c.r) * 0.85 * clampf((SMOKE_LIFE - float(c.t)) / 15.0, 0.0, 1.0)   # it thins in its last seconds
        var t := clampf((c.p - a).dot(ab) / maxf(l2, 1.0), 0.0, 1.0)
        if (a + ab * t).distance_squared_to(c.p) < r * r: return true
    return false
func visible_to(s: CShip, side: int) -> bool:
    if s.side == side: return true
    if s.sub and not detected_by(s, side): return false
    var lim := limited()
    if not lim and screens.is_empty(): return true
    var show: float = 2.0 if (s.lit_t < 6.0 or not s.fires.is_empty() or s.mag_fire > 0) else 1.0
    var eye: float = float(wx.vis) * show
    for o in ships:
        if o.side != side or not active(o): continue
        var d2: float = o.pos.distance_squared_to(s.pos)
        if has_radar(o) and not submerged(o) and d2 < sight(o) * sight(o): return true   # radar looks through the dark and through smoke
        if lim and d2 >= eye * eye: continue
        if not smoke_blocks(o.pos, s.pos): return true
    return false
## The nearest enemy whether seen or not: where a side that has lost sight of the enemy steers to find him again.
func nearest_any(from: Vector2, side: int) -> CShip:
    var best: CShip = null; var bd := INF
    for o in ships:
        if o.side == side or not engageable(o): continue
        var dd := from.distance_to(o.pos)
        if dd < bd: bd = dd; best = o
    return best

## System upgrades (bought in port, Refit tab): what each does per mark, and what it costs as a share of the hull's price.
# ------------------------------------------------------------------ the weight a ship carries (docs/REFIT.md)
## Refits are ruled by weight, as real ones were (owner's direction: Rule the Waves 3 and Ultimate Admiral:
## Dreadnoughts). Every weapon and every mark of a system weighs so many tons; a hull was designed round her
## standard fit and has a small margin beyond it. Past the margin she is slower and slow on the helm; a little
## further and no yard will send her to sea. What is carried high (AA, directors, radar) counts more towards
## topweight: a top-heavy ship rolls, and her salvos spread, worst in a sea.
const TONS := {"g102": 10, "g102t": 20, "g76": 16, "g120t": 26, "g127s": 20, "g127": 45, "g130t": 55, "g150s": 28, "g150t": 85, "g152t": 95, "g152": 155,
    "g203t": 250, "g203": 310, "g203r": 350, "g283": 750, "g356t": 900, "g356": 1150, "g356q": 1500, "g381t": 1020, "g381": 1500, "g406": 1700, "g460": 2500,
    "aa20": 1, "aa40": 11, "ciws": 2, "tor": 20, "tor93": 28, "torh": 20, "ssm": 16, "sam": 30}
const HEIGHT := {"A": 1.5, "V": 0.8, "T": 0.9}        # how high a mount sits, guns on the deck being 1
const TOP_SLACK := 1.10                                # topweight a hull bears before it tells
const TOP_LIMIT := 1.30
static func weapon_tons(wid) -> float: return float(TONS.get(wid, 0)) if wid != null else 0.0
static func system_tons(d: Dictionary, k: String) -> float: return float(UPGRADES[k].get("tons", 0.0)) * maxf(float(d.t), 300.0)
## The weight ledger of a ship with this fit and these systems: tons carried against her standard fit and margin,
## topweight against standard, and what follows for her speed, helm and gunnery. `ok` is false if no yard would
## pass her.
static func loading(d: Dictionary, fit: Array, up: Dictionary) -> Dictionary:
    var std := 0.0; var std_top := 0.0; var now := 0.0; var top := 0.0
    var parts := {"Heavy guns": 0.0, "Medium and light guns": 0.0, "Anti-aircraft": 0.0, "Torpedoes": 0.0, "Missiles": 0.0, "Systems": 0.0}
    for i in d.slots.size():
        var sl: Dictionary = d.slots[i]; var h := float(HEIGHT.get(sl.s, 1.0))
        var w0 := weapon_tons(sl.def); std += w0; std_top += w0 * h
        var wid = fit[i] if i < fit.size() else ""
        var w1 := weapon_tons(wid); now += w1; top += w1 * h
        if w1 > 0.0 and GameData.weapons.has(wid):
            var w: Dictionary = GameData.weapons[wid]
            var g: String = "Anti-aircraft" if w.kind == "aa" else ("Torpedoes" if w.kind == "torp" else ("Missiles" if w.kind == "ssm" or w.kind == "sam" else ("Heavy guns" if w.size == "H" or w.size == "L" else "Medium and light guns")))
            parts[g] += w1
    for k in up:
        if not UPGRADES.has(k): continue
        var t := system_tons(d, k) * int(up[k]); now += t; top += t * float(UPGRADES[k].get("top", 0.3)); parts["Systems"] += t
    var disp := maxf(maxf(float(d.t), std * 6.0), 300.0)   # (boats too small for these shares are reckoned as larger)
    var margin := maxf(8.0, 0.012 * disp); var limit := 0.03 * disp
    var over_t := now - std - margin; var over := maxf(0.0, over_t) / disp
    var ratio := (top + 0.01 * disp) / (std_top + 0.01 * disp)   # her masts, bridge and boats are topweight too, whatever her guns
    var speed := 1.0 - 2.0 * over
    if now < std: speed = minf(1.03, 1.0 + 0.7 * (std - now) / disp)    # landed weight gives a little back
    return {"tons": now, "std": std, "margin": margin, "limit": limit, "over_t": over_t, "top": ratio, "parts": parts,
        "speed": clampf(speed, 0.85, 1.03), "turn": clampf(1.0 - 1.5 * over, 0.85, 1.0), "spread": 1.0 + 2.0 * maxf(0.0, ratio - TOP_SLACK),
        "ok": over_t <= limit and ratio <= TOP_LIMIT}

const UPGRADES := {
    # `tons`: weight of one mark as a share of displacement; `top`: how high it sits (see loading)
    "eng": {"name": "Machinery", "per": "+4% speed", "cost": 0.10, "tons": 0.008, "top": 0.2},
    "hull": {"name": "Hull and armour", "per": "+8% hull strength, +10% armour", "cost": 0.12, "tons": 0.022, "top": 0.4},
    "tds": {"name": "Torpedo protection", "per": "torpedo damage -15%, a third less flooding", "cost": 0.09, "tons": 0.018, "top": 0.1},
    "mag": {"name": "Magazine protection", "per": "fewer magazine fires, and longer to flood them", "cost": 0.06, "tons": 0.006, "top": 0.3},
    "turret": {"name": "Turret machinery", "per": "guns reload 6% faster", "cost": 0.07, "tons": 0.004, "top": 1.0},
    "fc": {"name": "Fire control", "per": "salvos 12% tighter", "cost": 0.08, "tons": 0.002, "top": 2.5},
    "radar": {"name": "Radar", "per": "+6% gun range", "cost": 0.07, "mk2": "radar", "tons": 0.0015, "top": 3.0},
    "sonar": {"name": "Sonar", "per": "+30% sonar range", "cost": 0.05, "mk2": "sonar", "needs_sonar": true, "tons": 0.001, "top": 0.0},
}
static func upg(s: CShip, k: String) -> int: return int(s.up.get(k, 0))

func speed_mult(s: CShip) -> float:
    return (1.0 - (0.05 * int(wx.sea) if s.d.t < 3000.0 and not submerged(s) else 0.015 * int(wx.sea))) * (1.2 if s.sub and s.tech.has("snorkel") and submerged(s) else 1.0) * s.fuel_k * (1 + 0.04 * upg(s, "eng")) * (1 + 0.06 * s.sk.helm) * (0.75 + 0.25 * s.cf) * (0.6 + 0.4 * s.hull / s.max_hull) * (0.0 if s.eng_out > 0 else 0.25 + 0.75 * s.eng)

func gun_range(s: CShip, w: Dictionary) -> float:
    return w.range * ((1.15 if s.tech.has("radar") else 1.0) * (1.0 + 0.06 * upg(s, "radar")) if w.kind == "gun" else 1.0) * (1.4 if w.kind == "sam" and s.tech.has("aegis") else 1.0) * (1.15 if w.kind == "ssm" and s.tech.has("datalink") else 1.0)

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
        if o.side == side or not engageable(o): continue
        var dd = from.distance_to(o.pos)
        if dd > max_d: continue
        if filt.is_valid() and not filt.call(o): continue
        if not visible_to(o, side): continue
        var sc = dd / clampf(o.d.L / 110.0, 0.5, 2.6) if heavy else dd
        if sc < bs: bs = sc; best = o
    return best

func nearest_enemy(from: Vector2, side: int, max_d := INF, filt := Callable()) -> CShip:
    var best: CShip = null; var bd = max_d
    for o in ships:
        if o.side == side or not engageable(o): continue
        var dd = from.distance_to(o.pos)
        if dd >= bd: continue
        if filt.is_valid() and not filt.call(o): continue
        if visible_to(o, side): bd = dd; best = o
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

func rdir() -> Vector2: return Vector2.from_angle(randf() * TAU)

## An explosion. Modern: a white-hot core, rolling fireballs, a shockwave ring, debris streaking out, embers drifting
## downwind and a pool of light on the water and hulls around it. Classic: a soft flash and smoke.
func fx_boom(p: Vector2, size: float, mx := 0.6) -> void:
    part(P.BOOM, p, mx, size)
    if modern:
        part(P.CORE, p, 0.12 + size / 900.0, size * 0.7)
        for i in 3 + int(size > 30.0) * 2:
            var fb = part(P.FIREBALL, p + rdir() * size * 0.25 * randf(), mx * (1.1 + randf() * 0.7), size * (0.45 + randf() * 0.35), rdir() * size * (0.3 + randf() * 0.6))
            fb.a = randf() * TAU; fb.spin = (randf() - 0.5) * 2.0; fb.drag = 0.2
        part(P.RING, p, 0.22 + size / 500.0, size * 1.7)
        var nd := clampi(3 + int(size / 5.0), 3, 16)
        for i in nd:
            var d = part(P.DEBRIS, p, 0.35 + randf() * 0.9, (0.3 + randf() * 0.7) * (0.6 + size * 0.02), rdir() * (size * 2.0 + pow(randf(), 2.0) * size * 10.0 + 20.0)); d.drag = 0.25 + randf() * 0.2
        for i in nd / 2:
            var e = part(P.EMBER, p + rdir() * size * 0.3, 1.5 + randf() * 2.0, 0.6 + size * 0.035, rdir() * (8.0 + randf() * size * 1.5), true); e.drag = 0.35
        part(P.GLOW, p, mx * 1.8 + 0.3, size * 4.0)
        if size >= 14.0:   # a big burst: a streak of glare across it, a black heart of soot, burning fragments trailing smoke, late pops
            part(P.FLARE, p, 0.16 + size / 700.0, size * 2.6)
            for i in 2 + int(size / 25.0):
                var so = part(P.SOOT, p + rdir() * size * 0.2, mx * 2.2 + 1.0 + randf(), size * (0.5 + randf() * 0.3), rdir() * size * 0.5, true, -0.08 - randf() * 0.1)
                so.a = randf() * TAU; so.spin = (randf() - 0.5) * 0.8; so.drag = 0.3
            for i in clampi(int(size / 9.0), 1, 7):
                var ch = part(P.DEBRIS, p, 0.9 + randf() * 1.3, 1.0 + size * 0.03 + randf(), rdir() * (size * 3.0 + randf() * size * 6.0 + 30.0)); ch.drag = 0.45; ch.wind = false; ch.spin = 1.0   # spin marks a fragment that smokes
            for i in int(size / 22.0):
                var off: Vector2 = rdir() * size * (0.4 + randf() * 0.7); var dl := -0.12 - randf() * 0.45
                part(P.CORE, p + off, 0.1, size * 0.3, Vector2.ZERO, false, dl)
                var fb2 = part(P.FIREBALL, p + off, mx * 1.2, size * 0.32, rdir() * size * 0.4, false, dl); fb2.a = randf() * TAU; fb2.drag = 0.2
    for i in 2: part(P.SMOKE, p + Vector2(randf() - 0.5, randf() - 0.5) * size * 0.5, 5.0 + randf() * 3.0, size * 0.7, Vector2(randf() - 0.5, randf() - 0.5) * 6.0, true, -0.15)

## A shell into the sea: a white burst, spray thrown out in streaks, a ring running out across the water, then foam.
func fx_splash(p: Vector2, size: float) -> void:
    part(P.SPLASH, p, 2.0 if modern else 1.8, size)
    if not modern: part(P.FOAM, p, 10.0, size * 1.5)
    if modern:
        part(P.WASH, p, 9.0 + size * 0.4, size * 1.5)   # the foam patch and the trough it leaves (shaders/wash.gdshader)
        for i in 4 + int(size * 0.35):
            var q = part(P.SPRAY, p + rdir() * size * 0.15, 0.7 + randf() * 0.9, size * (0.22 + randf() * 0.2), rdir() * (size * 1.2 + randf() * size * 4.0)); q.drag = 0.18
        part(P.WRING, p, 1.4 + size / 25.0, size * 2.4)

func fx_muzzle(p: Vector2, ang: float, size: String, barrels: int) -> void:
    var S: float = {"S": 5.5, "M": 9.5, "L": 15.0, "H": 24.0}[size]
    var n: int = {"S": 3, "M": 4, "L": 7, "H": 11}[size] + barrels
    var f = part(P.FLASH, p, 0.26, S * (1 + barrels * 0.12)); f.a = ang
    if modern:
        part(P.GLOW, p + Vector2.from_angle(ang) * S, 0.35, S * 6.0)
        var c = part(P.CORE, p + Vector2.from_angle(ang) * S * 0.4, 0.07, S * 0.9); c.a = ang
    var bl = part(P.BLAST, p, 1.5 if modern else 0.9, S * (3.4 if modern else 3.0)); bl.a = ang
    if size == "H" or size == "L": part(P.FOAM, p + Vector2.from_angle(ang) * S * 0.6, 2.0, S * 1.1) # the blast flattens the sea ahead of the muzzle
    for i in ceili(n / 2.0):
        var a = ang + (randf() - 0.5) * 0.9
        part(P.SPARK, p, 0.3 + randf() * 0.3, S * 0.12, Vector2.from_angle(a) * (60.0 + randf() * 120.0))
    for i in n:
        var a = ang + (randf() - 0.5) * 0.7
        part(P.GUNSMOKE, p + Vector2.from_angle(ang) * S * 0.5, 7.0 + randf() * 5.0, S * (0.5 + randf() * 0.4), Vector2.from_angle(a) * (0.2 + randf()) * S * 6.0, true, -i * 0.02)

## A burst of tracer from a light gun: `w` is the weapon (20 mm, 40 mm, CIWS: each has its own look), `life` runs
## down from `L` as the rounds fly out along it.
func tracer(p: Vector2, q: Vector2, w := "", side := 0) -> void:
    var L: float = 0.26 if modern else 0.12
    tracers.append({"a": p, "b": q + Vector2(randf() - 0.5, randf() - 0.5) * 20.0, "life": L, "L": L, "w": w, "side": side, "ph": randf()})

# ------------------------------------------------------------------ weapons
## Salvo fire as the 1940s navies practised it under director control: the turrets fire together, rippling from
## fore to aft a fraction of a second apart (firing key and delay coils), in alternating half-salvos: one gun of each
## turret, then the others half a reload later, so the fall of each half-salvo can be spotted. Single guns fire whole.
const COIL := 0.08                                          # battle seconds between barrels in a half-salvo
const TURRET_STEP := {"S": 0.15, "M": 0.25, "L": 0.35, "H": 0.45}   # fore-to-aft ripple between turrets
func fire_gun(s: CShip, m: Mount, aim: Vector2, w: Dictionary) -> void:
    var n := int(w.get("barrels", 1))
    var order := 0   # this turret's place, bow to stern, among the ship's guns of its calibre
    for o in s.mounts:
        if o == m: break
        if o.w.kind == "gun" and o.w.size == w.size: order += 1
    var t0: float = order * TURRET_STEP[w.size]
    if n == 1: m.queue.append({"i": 0, "t": t0, "aim": aim})
    else:
        m.half = 1 - m.half
        var first := []; var second := []
        for i in n: (first if i % 2 == m.half else second).append(i)
        for k in first.size(): m.queue.append({"i": first[k], "t": t0 + k * COIL, "aim": aim})
        for k in second.size(): m.queue.append({"i": second[k], "t": t0 + float(w.rel) * 0.5 + k * COIL, "aim": aim})
    if m.queue.size() > n * 2: m.queue = m.queue.slice(m.queue.size() - n)
    _ripple(s, m, 0.0)

func _ripple(s: CShip, m: Mount, dt: float) -> void:
    for j in range(m.queue.size() - 1, -1, -1):
        var q: Dictionary = m.queue[j]; q.t -= dt
        if q.t <= 0.0: m.queue.remove_at(j); fire_barrel(s, m, q.aim, int(q.i))

func fire_barrel(s: CShip, m: Mount, aim: Vector2, i: int) -> void:
    if not use_round(m): return
    var w: Dictionary = m.w; var n := int(w.get("barrels", 1))
    var ang = s.a + m.ta; var off: float = (i - (n - 1) / 2.0) * float(w.get("gap", 0.0))
    var p = world_pt(s, m.slot.x, m.slot.y) + Vector2.from_angle(ang + PI / 2) * off
    var rng: float = gun_range(s, w); var d = minf(rng, p.distance_to(aim))
    var fc = (0.6 if s.tech.has("radar") else 1.0) * (1 - 0.12 * s.sk.gun) * (1 - 0.12 * upg(s, "fc")) * (1.0 + (s.ld_spread - 1.0) * (1.0 + 0.5 * int(wx.sea))) * (1.15 if s.side == 1 else 1.0) * (0.85 if s.tech.has("datalink") else 1.0)
    fc *= 1.0 + 0.1 * int(wx.sea)                                         # a moving platform
    if wx.night and not has_radar(s): fc *= 1.35                           # spotting the fall of shot by eye in the dark
    s.lit_t = 0.0
    var spread: float = w.spread * fc / maxf(0.3, s.fc)
    var a = ang + (randf() - 0.5) * 2 * spread
    var dd = maxf(60.0, d * (1 + (randf() - 0.5) * 0.06 * fc))
    # penetration in mm of armour, from the shell's weight, falling off with range; fall: how steeply it comes down
    var pen: float = float(w.dmg) * 1.9 * (1.0 - 0.45 * clampf(dd / rng, 0.0, 1.0))
    var kind := shell_for(s, aim, pen)
    s.last_shell = kind
    pen *= SHELLS[kind].pen
    shells.append({"s": p, "e": p + Vector2.from_angle(a) * dd, "pos": p, "t": 0.0, "T": dd / w.speed, "dmg": w.dmg, "side": s.side, "size": w.size, "pen": pen, "fall": clampf(dd / rng, 0.0, 1.0), "who": s, "ammo": kind})
    if m.rec.size() != n: m.rec.resize(n)
    m.rec[i] = 1.0; m.recoil = 1.0
    fx_muzzle(p + Vector2.from_angle(ang) * (w.tl * 0.42 + w.bl), ang, w.size, 1)
    sound("gun_" + w.size, p, {"S": 0.2, "M": 0.3, "L": 0.45, "H": 0.75}[w.size])

func fire_torps(s: CShip, m: Mount, aim: Vector2) -> void:
    if not use_round(m): return
    var w = m.w; var p = world_pt(s, m.slot.x, m.slot.y); var base = (aim - p).angle()
    for i in int(w.count):
        var a: float = base + (i - (w.count - 1) / 2.0) * 0.06
        torps.append({"pos": p, "a": a, "speed": w.speed, "life": gun_range(s, w) / w.speed, "dmg": w.dmg, "side": s.side, "homing": w.get("homing", false), "arm": 150.0 / w.speed})
    boom(p, 0.1, 900.0)
    if s.sub: s.reveal_t = 20.0

func fire_missile(s: CShip, m: Mount, tg: CShip) -> void:
    if not use_round(m): return
    var w = m.w; var p = world_pt(s, m.slot.x, m.slot.y)
    for i in int(w.count) + (1 if s.tech.has("vls") else 0):   # vertical launch: one more round in each salvo
        missiles.append({"pos": p, "a": s.a + (randf() - 0.5) * 0.6, "v": 80.0, "speed": w.speed, "life": gun_range(s, w) / w.speed * 1.4, "dmg": w.dmg, "side": s.side, "target": tg, "kind": "ssm", "delay": i * 2.0})
    if s.sub: s.reveal_t = 25.0

func fire_sam(s: CShip, m: Mount, tg) -> void:
    if not use_round(m): return
    var p = world_pt(s, m.slot.x, m.slot.y); var tp: Vector2 = tg.pos
    missiles.append({"pos": p, "a": (tp - p).angle(), "v": 200.0, "speed": m.w.speed, "life": gun_range(s, m.w) / m.w.speed * 1.5, "dmg": 0, "side": s.side, "target": tg, "kind": "sam", "p": m.w.pd, "delay": 0.0})

func reload_mult(s: CShip, w: Dictionary) -> float:
    var r = 0.5 + 0.5 * s.cf
    if w.kind == "gun": r *= (1 + 0.08 * s.sk.gun) * (1 + 0.06 * upg(s, "turret"))
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
    var p = world_pt(s, m.slot.x, m.slot.y)
    if m.w.kind == "gun" and not use_round(m, int(m.w.get("barrels", 1))): return
    if m.w.kind == "gun": # dual-purpose guns firing at aircraft: a real gun report, flash and recoil
        var ang = (sq.pos - p).angle(); tracer(p, sq.pos); m.recoil = 1.0
        m.rec.resize(int(m.w.get("barrels", 1))); m.rec.fill(1.0)
        fx_muzzle(p + Vector2.from_angle(ang) * (m.w.tl * 0.42 + m.w.bl), ang, m.w.size, int(m.w.get("barrels", 1)))
        sound("gun_" + m.w.size, p, {"S": 0.16, "M": 0.24, "L": 0.4, "H": 0.6}[m.w.size])
    else: aa_shot(s, m, p, sq.pos)
    part(P.FLAK, sq.pos + Vector2(randf() - 0.5, randf() - 0.5) * 50.0, 0.6, 8.0)
    if randf() < chance * (0.6 if sq.jet else 1.0) * (1.35 if s.tech.has("aa_prox") else 1.0):   # proximity fuzes
        sq.n -= 1; part(P.FALL, sq.pos + Vector2(randf() - 0.5, randf() - 0.5) * 30.0, 1.4, 6.0)

func update_weapons(s: CShip, dt: float) -> void:
    var is_player = s == flag; var sm = submerged(s)
    if s.struck: # a ship that has struck her colours ceases fire
        for m in s.mounts: m.queue.clear(); m.st = ""
        return
    for m in s.mounts:
        if m.dead: m.st = ""; continue
        var w = m.w; m.cd -= dt * reload_mult(s, w); m.recoil = maxf(0.0, m.recoil - dt * 0.5)
        for b in m.rec.size(): m.rec[b] = maxf(0.0, m.rec[b] - dt * 0.5)   # the barrel runs out again over about two seconds
        if not m.queue.is_empty(): _ripple(s, m, dt)
        if m.ammo == 0: m.st = "empty"; continue   # magazine dry
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
                        if s.target != null and engageable(s.target) and visible_to(s.target, s.side) and p.distance_to(s.target.pos) < rng and mount_arc(m, ang_diff((s.target.pos - p).angle(), s.a)).x > 0: pri = s.target
                        var heavy: bool = w.size == "L" or w.size == "H"
                        var slot = m.slot; var sa = s.a
                        var mm := m
                        var f = func(o: CShip) -> bool: return mount_arc(mm, ang_diff((o.pos - p).angle(), sa)).x > 0 and not submerged(o)
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
                    var rest: float = mount_arc(m, ang_diff((o.pos - p).angle(), s.a)).y if o != null else m.slot.arcs[0][0]
                    train(m, rest, TRAV[w.size] * dt)
                    continue
                var want = ang_diff((aim - p).angle(), s.a)
                var ac = mount_arc(m, want)
                train(m, ac.y, TRAV[w.size] * dt)
                var aligned: bool = absf(ang_diff(want, m.ta)) < 0.04 and ac.x > 0
                var in_range = p.distance_to(aim) < rng
                var trigger = (mouse_down or (autofire and aim_lock)) if manual else true
                if hold_fire and s.side == 0 and not manual and aim_air == null: trigger = false   # holding fire (the AA guns still defend the ship)
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
                    m.ta = ang_diff((ms.pos - p).angle(), s.a); m.cd = w.rel; aa_shot(s, m, p, ms.pos)
                    if randf() < w.pd: kill_missile(ms)
                    done = true
                if not done:
                    var sq = nearest_air(s.side, p, w.range)
                    if sq != null: m.ta = ang_diff((sq.pos - p).angle(), s.a); m.cd = w.rel; flak(s, m, sq, w.aa); done = true
                if not done and small_craft[1 - s.side]:
                    var o = nearest_enemy(p, s.side, w.range, func(x: CShip) -> bool: return not submerged(x) and (x.d.kind == "pt" or x.d.kind == "sub"))
                    if o != null:
                        m.ta = ang_diff((o.pos - p).angle(), s.a); m.cd = w.rel * 2; aa_shot(s, m, p, o.pos)
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
                if hold_fire and s.side == 0: continue   # holding fire: no torpedoes from the rest of the squadron
                # straight-running torpedoes pass over a submerged boat; acoustic homers can go after one that is held on sonar
                var homer: bool = w.get("homing", false)
                var ok_t = func(x: CShip) -> bool: return not submerged(x) or homer
                var tg: CShip = s.target if (s.target != null and engageable(s.target) and visible_to(s.target, s.side) and ok_t.call(s.target)) else nearest_enemy(s.pos, s.side, rng * 0.75, ok_t)
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
                if hold_fire and s.side == 0: continue
                var tg2: CShip = s.target if (s.target != null and engageable(s.target) and visible_to(s.target, s.side) and not submerged(s.target)) else nearest_enemy(s.pos, s.side, rng, func(x: CShip) -> bool: return not submerged(x))
                if tg2 != null and p.distance_to(tg2.pos) < rng: m.cd = w.rel * (0.8 + randf() * 0.5); fire_missile(s, m, tg2)
    if s.d.get("sonar", false) and not s.sub:
        s.dc_t -= dt
        if s.dc_t <= 0:
            var sb = nearest_enemy(s.pos, s.side, 260.0, func(o: CShip) -> bool: return o.sub and submerged(o))
            if sb != null: drop_dcs(s)

## A pattern of depth charges rolled and thrown off the stern; they sink and burst a few seconds later.
func drop_dcs(s: CShip) -> bool:
    if s.dc_left <= 0 or s.dc_t > 0.0: return false   # none left, or the racks still reloading
    s.dc_left -= 1; s.dc_t = 25.0; var st = world_pt(s, -s.d.L / 2, 0)
    for i in 6:
        var q = part(P.DC, st + Vector2(randf() - 0.5, randf() - 0.5) * 90.0, 1.4, 24.0); q.life = -1.5 - i * 0.4; q.side = s.side; dcs.append({"pos": q.pos, "t": (1.5 + i * 0.4) * BT, "side": s.side})
    if s.side == 0 and s == flag: say("Depth charges away · %d patterns left." % s.dc_left, 1.5)
    return true

## Shell types. AP: full penetration, may pass through a light ship. HE: bursts on contact: little penetration, but
## more blast against unarmoured ships and upper works, never over-penetrates, and starts fires. Incendiary: little
## penetration or blast, but fires above all. (One magazine per mount: the shells are drawn from the same stock.)
const SHELLS := {
    "ap": {"name": "AP", "pen": 1.0, "nopen": 1.0, "hit": 1.0, "fire": 1.0},
    "he": {"name": "HE", "pen": 0.35, "nopen": 3.0, "hit": 0.9, "fire": 2.0},
    "inc": {"name": "Incendiary", "pen": 0.25, "nopen": 1.6, "hit": 0.65, "fire": 4.0}}
const SHELL_MODES := ["auto", "ap", "he", "inc"]

## The shell a gun loads: the ship's choice, or (auto, and always for the AI) by the target where it aims: AP if the
## shell can beat its belt at this range, HE against light ships or armour it can't beat, incendiary for merchants.
func shell_for(s: CShip, aim: Vector2, pen: float) -> String:
    if s.shell_mode != "auto": return s.shell_mode
    var tg: CShip = null; var bd := 600.0
    for o in ships:
        if o.side == s.side or not active(o): continue
        var d := o.pos.distance_to(aim)
        if d < bd: bd = d; tg = o
    if tg == null: return "he"
    if tg.d.kind == "merchant": return "inc"
    if tg.d.armor >= 40 and pen > tg.armor * 1.15: return "ap"
    return "he"

## What a shell does when it strikes. Its penetration (mm, from its weight and the range it was fired at) meets the
## armour it hits: the belt, made thicker by the angle the shell strikes at, or the thinner deck if it comes down
## steeply from long range. A very oblique hit can ricochet; a shell that beats the armour penetrates (full damage,
## and it reaches the ship's subsystems), but a heavy shell into a lightly built ship may pass straight through
## (over-penetration); one that fails only throws splinters.
func shell_result(tg: CShip, sh: Dictionary) -> Dictionary:
    var dir: Vector2 = (sh.e - sh.s).normalized(); var side_n := Vector2.from_angle(tg.a + PI / 2)
    var obl: float = acos(clampf(absf(dir.dot(side_n)), 0.0, 1.0))   # 0 = square to the side
    var fall: float = sh.fall; var deck: bool = fall > 0.6 and randf() < (fall - 0.6) * 2.0
    var armour: float = maxf(1.0, tg.armor * (0.4 if deck else 1.0))
    if deck: obl = lerpf(obl, 0.5, 0.7)                               # coming down steeply: the deck is struck more squarely
    if not deck and obl > 1.12 and randf() < (obl - 1.0) / 0.5: return {"kind": "rico", "k": 0.03, "text": "Ricochet"}
    var eff: float = armour / maxf(cos(obl), 0.25)
    var pen: float = sh.get("pen", sh.dmg * 1.9)
    var am: Dictionary = SHELLS[sh.get("ammo", "ap")]; var tag: String = am.name + " · "
    if pen < eff:   # HE and incendiary burst on the plate: more blast and fire than an AP shell that fails
        var kb: float = (0.1 + 0.15 * pen / eff) * float(am.nopen)
        if tg.d.armor < 25: kb = maxf(kb, 0.55 * float(am.hit))   # an unarmoured ship: the burst does real harm
        return {"kind": "nopen", "k": minf(kb, 0.8), "text": tag + ("Burst on the armour" if sh.get("ammo", "ap") != "ap" else "No penetration") + (" (deck)" if deck else ""), "fire": am.fire}
    if sh.get("ammo", "ap") == "ap" and pen > eff * 4.0 and (tg.d.armor < 60 or tg.d.B < 14) and randf() < 0.55:
        return {"kind": "over", "k": 0.35, "text": tag + "Overpenetration", "fire": am.fire}
    tg.armor = maxf(tg.d.armor * 0.4, tg.armor - sh.dmg * 0.1)       # the plate is weakened where it was holed
    return {"kind": "pen", "k": float(am.hit), "text": tag + ("Deck penetration" if deck else "Penetration"), "fire": am.fire}

# ------------------------------------------------------------------ damage
func damage(s: CShip, dmg: float, type: String) -> void:
    if not s.alive: return
    var hd = 0.0
    match type:
        "resolved": hd = dmg   # already weighed against the armour (shell_result)
        "shell":
            var eff = dmg / (dmg + s.armor); hd = dmg * maxf(0.03, eff); s.armor = maxf(s.d.armor * 0.4, s.armor - dmg * 0.25 * eff)
        "torp": hd = dmg * (1 - minf(0.45, s.d.armor / 700.0)) * (1.0 - 0.15 * upg(s, "tds"))
        "missile": hd = dmg * (1 - minf(0.55, s.armor / 550.0))
        "bomb": hd = dmg * dmg / (dmg + s.armor * 0.7); s.armor = maxf(s.d.armor * 0.4, s.armor - dmg * 0.15)
        _: hd = dmg
    if type != "magazine": hd *= 1 - 0.07 * s.sk.dc   # damage control cannot save a ship whose magazine has gone up
    s.hull -= hd; s.dmg_taken += hd; last_hit = t
    if s.side == 1 and not s.flee and s.hull / s.max_hull < 0.25 and randf() < 0.3: s.flee = true
    if s.hull <= 0:
        s.hull = 0; s.alive = false; s.sink = 0.001
        part(P.OIL, s.pos, 60.0, s.d.L * 0.45)
        for i in 24:
            var q = part(P.FIRE if i % 3 == 0 else P.SMOKE, s.pos + Vector2((randf() - 0.5) * s.d.L * 0.6, (randf() - 0.5) * s.d.B).rotated(s.a), 2.0 + randf() * 3.0, 10.0 + randf() * 18.0, Vector2(randf() - 0.5, randf() - 0.5) * 40.0, true)
        fx_boom(s.pos, s.d.L * 0.5, 1.0)
        say(("Enemy " if s.side == 1 else "Our ") + s.d.name.to_lower() + " " + s.rec.name + " is sinking!")
        sound("blast", s.pos, 0.65)
        if lock == s: lock = null
        if s == flag: next_flag("Flagship lost! You transfer your flag to the ")
    elif s.side == 1 and not s.struck and not s.sub and s.hull / s.max_hull < 0.12 and s.d.kind != "pt":
        s.struck = true; s.throttle = 0; say(s.rec.name + " strikes her colours!")
        if lock == s: lock = null

## Internal subsystems. Where a hit lands along the hull decides what it reaches, and how far it gets through the armour
## decides whether it does: magazines under each centreline turret (a fire that damage control must flood before it
## reaches the charges, or outright detonation from a deep hit), machinery amidships (power falls, and a heavy hit
## stops the engines for a while), steering gear right aft (the rudder jams), fire control in the bridge block (salvo
## spread grows) and crew spaces forward (crew lost). Torpedoes strike below the belt and reach machinery and steering.
func hit_systems(s: CShip, wp: Vector2, dmg: float, kind: String) -> void:
    if not s.alive or s.d.kind == "carrier" and kind == "torp" and randf() < 0.3: return
    var l = (wp - s.pos).rotated(-s.a); var L: float = s.d.L
    var pen: float
    match kind:
        "shell": pen = dmg / (dmg + s.armor)
        "bomb": pen = dmg / (dmg + s.armor * 0.6)
        "torp": pen = 1.0 - minf(0.5, s.d.armor / 700.0)
        _: pen = 0.75
    var heavy: float = clampf(dmg / 250.0, 0.15, 1.5)
    var ours: bool = s.side == 0
    var nm: String = s.rec.name
    # magazines: below the centreline turrets of the main and secondary batteries
    if kind != "torp" or randf() < 0.4:
        for m in s.mounts:
            if m.w.kind != "gun" or m.slot.y != 0 or not ["M", "L", "H"].has(m.w.size): continue
            if absf(l.x - m.slot.x) > m.w.tl * 0.6 + 2.0: continue
            var mp: float = [1.0, 0.6, 0.35][clampi(upg(s, "mag"), 0, 2)]   # magazine protection: flash-tight hoists, better stowage
            if randf() < 0.035 * pen * pen * heavy * mp: _log("detonation (hit)"); detonate(s); return
            if s.mag_fire <= 0 and randf() < 0.14 * pen * heavy * mp:
                s.mag_fire = 25.0 + randf() * 25.0 + 12.0 * upg(s, "mag"); s.mag_x = m.slot.x; _log("magazine fire")
                say(("Fire in the %s magazine! Damage control is fighting it." if ours else "A fire is spreading aboard the %s.") % (nm if not ours else ("forward" if m.slot.x > 0 else "after")), 2.5)
            break
    # machinery amidships
    if absf(l.x) < L * 0.2 and pen > 0.3:
        s.eng = maxf(0.0, s.eng - (0.05 + 0.12 * pen) * heavy * (2.0 if kind == "torp" else 1.0))
        if s.eng_out <= 0 and (s.eng < 0.15 or randf() < 0.035 * pen * heavy):
            s.eng_out = 30.0 + randf() * 60.0; _log("engines stopped")
            say(("Engine room hit! The %s has lost power." if ours else "The %s loses way, her engines stopped.") % nm, 2.5)
    # steering gear right aft: every hit there wears it; a bad one jams the rudder
    if l.x < -L * 0.3 and pen > 0.25: s.steer = maxf(0.35, s.steer - 0.18 * pen * heavy)
    # flooding: a torpedo, or a heavy hit in a hull already half gone, lets the sea in on that side and she lists
    if kind == "torp" or (s.hull / s.max_hull < 0.55 and pen > 0.4 and randf() < 0.5):
        var side_: float = signf(l.y) if absf(l.y) > 0.5 else (1.0 if randf() < 0.5 else -1.0)
        var was: float = absf(s.list); s.list = clampf(s.list + side_ * (0.3 if kind == "torp" else 0.07 * heavy) * (1.0 - 0.33 * upg(s, "tds")), -1.0, 1.0)
        if was < 0.35 and absf(s.list) >= 0.35: say(("The %s is listing to %s: she is slow to answer her helm." if ours else "The %s takes a list to %s.") % [nm, "starboard" if s.list > 0 else "port"], 2.5); _log("listing")
    if l.x < -L * 0.38 and s.jam <= 0 and randf() < (0.6 if kind == "torp" else 0.3 * pen):
        _log("rudder jammed"); s.jam = 20.0 + randf() * 50.0; s.jam_r = clampf(s.rud + (randf() - 0.5) * 0.6, -1.0, 1.0)
        if ours: say("Steering gear hit! The %s's rudder is jammed." % nm, 2.5)
    # fire control in the bridge block
    var sup: Array = s.d.p.get("sup", [])
    if not sup.is_empty() and absf(l.x - float(sup[0][0])) < float(sup[0][1]) / 2 + 2.0 and randf() < 0.35 * maxf(pen, 0.3):
        s.fc = maxf(0.3, s.fc - 0.3 * heavy)
        if ours: say("The %s's director is hit: gunnery suffers." % nm, 2.0)
    # crew spaces
    s.cf = maxf(0.2, s.cf - 0.003 * dmg / 100.0 * pen * (3.0 if l.x > L * 0.15 and l.x < L * 0.4 else 1.0))

## A magazine goes up: the ship is lost.
func detonate(s: CShip) -> void:
    for i in 4: fx_boom(s.pos + Vector2((randf() - 0.5) * s.d.L * 0.5, 0).rotated(s.a), s.d.L * (0.4 + randf() * 0.3), 1.6)
    part(P.FLASH, s.pos, 0.5, s.d.L * 0.8); sound("blast", s.pos, 1.0); sound("hit_big", s.pos, 0.8)
    if modern:
        part(P.RING, s.pos, 0.6, s.d.L * 2.0); part(P.GLOW, s.pos, 2.5, s.d.L * 5.0); part(P.WRING, s.pos, 3.5, s.d.L * 2.6)
        for i in 24:
            var d = part(P.DEBRIS, s.pos + rdir() * s.d.L * 0.2, 0.8 + randf() * 1.8, 0.8 + randf() * 2.2, rdir() * (60.0 + pow(randf(), 2.0) * 340.0)); d.drag = 0.3 + randf() * 0.2
        flash = 1.0
    say(("Her magazine explodes! The %s is gone." if s.side == 1 else "The %s's magazine explodes!") % s.rec.name, 3.5)
    s.mag_fire = 0.0; damage(s, s.hull + 1.0, "magazine")

## Subsystems over time: damage control fights magazine fires (flooding them silences the guns above) and gets
## machinery, steering and fire control partly back.
func systems_tick(s: CShip, dt: float) -> void:
    var dc: float = (1.0 + 0.3 * s.sk.dc) * (1.3 if s.tech.has("dc") else 1.0)   # damage control schools
    if s.mag_fire > 0:
        s.mag_fire -= dt
        if randf() < dt * 0.08 * dc * (0.6 + 0.4 * s.cf):
            s.mag_fire = 0.0; _log("magazine flooded"); s.flooded.append(s.mag_x)
            for m in s.mounts: if m.w.kind == "gun" and m.slot.y == 0 and absf(m.slot.x - s.mag_x) < m.w.tl * 0.6 + 2.0: m.dead = true
            say(("Magazine flooded aboard the %s: the turret above is out of action." if s.side == 0 else "The %s floods a magazine.") % s.rec.name, 2.5)
        elif s.mag_fire <= 0: _log("detonation (fire)"); detonate(s); return
    if s.eng_out > 0: s.eng_out = maxf(0.0, s.eng_out - dt * dc); if s.eng_out == 0 and s.side == 0: say("The %s has steam again." % s.rec.name, 2.0)
    if s.eng < 0.8: s.eng = minf(0.8, s.eng + dt * 0.002 * dc)
    if s.jam > 0: s.jam = maxf(0.0, s.jam - dt * dc)
    if s.steer < 0.85: s.steer = minf(0.85, s.steer + dt * 0.002 * dc)
    if s.list != 0.0: s.list = move_toward(s.list, 0.0, dt * 0.0025 * dc)   # counter-flooding brings her upright, slowly
    if s.fc < 0.85: s.fc = minf(0.85, s.fc + dt * 0.002 * dc)

## A hit leaves a scorch (and a hole for shells) in ship space; heavier hits may start a fire or knock out a mount.
func mark_hit(s: CShip, wp: Vector2, sz: float, hole: bool, fire_k := 1.0) -> void:
    if not s.alive: return
    var l = (wp - s.pos).rotated(-s.a)
    var x = clampf(l.x, -s.d.L * 0.46, s.d.L * 0.46); var hh = hull_half(s.d, x) * 0.85; var y = clampf(l.y, -hh, hh)
    # a heavy hit that gets in tears a gash in the plating (jagged, with a torn rim) instead of a neat hole; near the
    # deck edge it takes a bite out of the ship's side. Either throws wreckage clear of the ship.
    var big: bool = hole and sz >= 2.0
    var edge: bool = big and absf(y) > hh * 0.62
    s.marks.append({"x": x, "y": y, "r": (1.5 + sz * 2.2) * (0.7 + randf() * 0.6), "v": randi() % 4, "hole": hole, "gash": big, "edge": edge, "sd": randi() % 1000, "side": signf(y) if y != 0.0 else 1.0})
    if s.marks.size() > 70: s.marks.pop_front()
    if big: wreckage(s, wp, int(1 + sz), sz)
    if randf() < 0.12 * sz * fire_k: s.fires.append({"x": x, "y": y, "t": 60.0 + randf() * 180.0, "r": 0.8 + sz * 0.9, "st": 0.0})
    for m in s.mounts:
        if m.dead or m.w.kind == "sam" or m.w.kind == "ssm": continue
        if Vector2(m.slot.x - x, m.slot.y - y).length() < m.w.get("tw", 2.5) * 0.9 + 1 and randf() < 0.1 * sz:
            m.dead = true
            s.marks.append({"x": float(m.slot.x), "y": float(m.slot.y), "r": float(m.w.get("tw", 2.5)) * 1.5 + 1.5, "v": randi() % 4, "hole": false, "gash": false, "edge": false, "sd": randi() % 1000, "side": 1.0, "wreck": true})
            wreckage(s, world_pt(s, m.slot.x, m.slot.y), 2, 1.5)   # the shield, the sights, the ready-use lockers
            if s.side == 0: say("A " + m.w.name + " mount on the " + s.rec.name + " is knocked out!", 2.0)

## Wreckage thrown off a ship by a heavy hit (the modern effects): plating, boats, davits, gun shields. Each piece
## flies clear, falls into the sea with a splash, and floats where it fell as the ship steams on, until it sinks.
var wrecks: Array = []
func wreckage(s: CShip, wp: Vector2, n: int, sz: float) -> void:
    if not modern: return
    var out: Vector2 = (wp - s.pos); out = out.normalized() if out.length() > 1.0 else rdir()
    for i in n:
        var dir: Vector2 = (out + rdir() * 0.9).normalized()
        wrecks.append({"pos": wp, "vel": dir * (18.0 + randf() * 30.0 + sz * 5.0) + Vector2.from_angle(s.a) * s.v * 0.6, "a": randf() * TAU, "spin": randf_range(-6.0, 6.0),
            "sz": (0.5 + randf() * 0.9) * (0.7 + sz * 0.2), "air": 0.5 + randf() * 0.9, "t": 0.0, "life": 35.0 + randf() * 30.0, "sd": randi() % 1000, "burn": randf() < 0.3})
    while wrecks.size() > 140: wrecks.pop_front()
func _wrecks(dtv: float) -> void:
    for i in range(wrecks.size() - 1, -1, -1):
        var w: Dictionary = wrecks[i]; w.t += dtv
        if w.air > 0.0:
            w.pos += w.vel * dtv; w.a += w.spin * dtv; w.air -= dtv
            if w.burn and randf() < dtv * 14.0: part(P.SMOKE, w.pos, 0.8, 1.2, Vector2.ZERO, true)
            if w.air <= 0.0: fx_splash(w.pos, 0.5 + w.sz * 0.25); w.vel *= 0.15; w.spin *= 0.1
        else:
            w.pos += w.vel * dtv; w.vel *= pow(0.2, dtv); w.a += w.spin * dtv
            if w.t > w.life: wrecks.remove_at(i)
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

## Where a ship of yours belongs in the standing formation, in the flagship's frame (x ahead, y to starboard).
func station(s: CShip) -> Vector2:
    var mine: Array = []
    for x in ships: if x.side == 0 and x != flag and active(x): mine.append(x)
    var idx: int = maxi(0, mine.find(s)); var wing: float = 1.0 if idx % 2 else -1.0; var rank: float = floor(idx / 2.0)
    match order:
        "abreast": return Vector2(0.0, wing * 500.0 * (rank + 1.0))
        "screen":
            # the light ships fan out ahead in an arc; the heavier ones follow the flagship in column
            var light: Array = mine.filter(func(x): return x.d.L < 150.0 and x.d.kind != "carrier" and x.d.kind != "merchant")
            var li: int = light.find(s)
            if li >= 0:
                var ang: float = (1.0 if li % 2 else -1.0) * (0.35 + 0.5 * floor(li / 2.0)) if light.size() > 1 else 0.0
                return Vector2.from_angle(ang) * 1400.0
            var heavy_: Array = mine.filter(func(x): return not light.has(x))
            return Vector2(-(heavy_.find(s) + 1) * 450.0, 0.0)
    return Vector2(-300.0, wing * (600.0 + 450.0 * rank))
## Steer and steam to hold a station on the flagship: far off, run for where the station will be; close, take her
## course and speed, easing ahead or astern and in or out to stay on it.
func keep_station(s: CShip, off: Vector2) -> void:
    var fd := Vector2.from_angle(flag.a); var g: Vector2 = flag.pos + off.rotated(flag.a); var dd := s.pos.distance_to(g)
    var along: float = (g - s.pos).dot(fd); var cross: float = (g - s.pos).dot(Vector2(-fd.y, fd.x))   # ahead of us, and to starboard of us
    if dd > 350.0:
        if along < -100.0 and absf(cross) < 800.0 and flag.v > 2.0:   # the station is astern of us: ease down and let it come up, edging across, rather than circling back
            s.rudder = helm(s, steer_avoid(s, flag.a + clampf(cross / 400.0, -0.5, 0.5))); s.throttle = 4; s.v_cmd = maxf(2.0, flag.v * 0.45); return
        var aim: Vector2 = g + fd * flag.v * clampf(dd / maxf(s.v, 8.0), 0.0, 45.0)
        s.rudder = helm(s, steer_avoid(s, (aim - s.pos).angle())); s.throttle = 4; return
    s.rudder = helm(s, steer_avoid(s, flag.a + clampf(cross / 260.0, -0.55, 0.55) * (1.0 if flag.v > 1.0 or dd > 60.0 else 0.0)))
    s.throttle = 4; s.v_cmd = maxf(0.0, flag.v + clampf(along * 0.035, -5.0, 5.0))
    if flag.v < 1.0 and dd < 120.0: s.v_cmd = 0.0   # she has stopped and we are on station: stop too

func ai_ship(s: CShip, dt: float) -> void:
    if s.struck: s.throttle = 0; s.rudder = 0; return
    s.v_cmd = -1.0
    # smoke: a ship that is running, or badly hurt with the enemy in sight, covers herself (and those behind her)
    if not s.smoke_on and s.smoke_left > SMOKE_CHARGE * 0.8 and can_smoke(s) and ((s.flee if s.side == 1 else order == "retreat") or s.hull / s.max_hull < 0.4):
        if nearest_enemy(s.pos, s.side, 10000.0) != null: make_smoke(s, true)
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
    if s.side == 0 and order == "line" and flag != null and flag != s:
        # line ahead: each ship follows in the wake of the one ahead of her, the flagship leading; guns fire as they bear
        var col: Array = []
        for x in ships: if x.side == 0 and x != flag and active(x) and x.d.kind != "carrier" and x.d.kind != "merchant" and not x.sub: col.append(x)
        var idx := col.find(s)
        if idx >= 0:
            var lead: CShip = flag if idx == 0 else col[idx - 1]
            var gap: float = lead.d.L * 0.5 + s.d.L * 0.5 + 350.0
            # steer for the point astern of the leader on her track (her trail), or straight astern if she has none yet
            var goal: Vector2 = lead.pos - Vector2.from_angle(lead.a) * gap; var run := 0.0; var prev: Vector2 = lead.pos
            for i in range(lead.trail.size() - 1, -1, -1):
                var tp: Vector2 = lead.trail[i].p; run += prev.distance_to(tp); prev = tp
                if run >= gap * 0.75: goal = tp; break
            var dd := s.pos.distance_to(goal)
            s.rudder = helm(s, steer_avoid(s, (goal - s.pos).angle() if dd > 120.0 else lead.a))
            # a leader who has stopped (ordered, or her engines out): close up to station slowly and stop there,
            # instead of creeping on into her stern
            var halted: bool = lead.throttle == 0 or lead.eng_out > 0 or lead.v < 2.5
            if halted: s.throttle = 0 if (dd < 250.0 or s.pos.distance_to(lead.pos) < gap + 200.0) else (3 if dd > 900.0 else 1)   # near enough is on station: a ship cannot hit a point exactly, and would circle it
            else: s.throttle = 4 if dd > 500.0 else (clampi(lead.throttle + (1 if dd > 200.0 else 0), 1, 4) if dd > 80.0 else maxi(1, lead.throttle - 1))
            return
    if s.side == 0 and flag != null and flag != s and (order == "escort" or order == "abreast" or order == "screen"):
        # formations: every ship has a station on the flagship and keeps it, turning and changing speed with her.
        # "Form on flag" breaks off to fight what comes within 3 km; line abreast and the screen hold station and
        # fire as their guns bear.
        var close = nearest_enemy(s.pos, s.side, 3000.0) if order == "escort" else null
        if close == null:
            keep_station(s, station(s)); return
        tg = close
    if tg == null:
        var lost: CShip = nearest_any(s.pos, s.side) if limited() else null   # out of sight: close the enemy's last reported position
        if lost != null and s.d.kind != "merchant" and s.d.kind != "carrier": s.throttle = 3; s.rudder = helm(s, steer_avoid(s, (lost.pos - s.pos).angle())); return
        s.throttle = 2; s.rudder = helm(s, s.a); return
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
    var asw: bool = tg.sub and submerged(tg) and s.d.get("sonar", false) and not s.sub and s.dc_left > 0
    if asw: desired = to   # a submerged contact: run in over it so the depth charges fall on it
    var mg: float = s.d.td + 800.0
    if s.pos.x < mg or s.pos.x > AW - mg or s.pos.y < mg or s.pos.y > AH - mg: desired = (Vector2(AW, AH) / 2 - s.pos).angle()
    s.rudder = helm(s, steer_avoid(s, desired))
    s.throttle = 4 if d > pref + 1500 or asw else 3
    if s.d.kind == "carrier" and not (hold_fire and s.side == 0): launch_strike(s, nearest_enemy(s.pos, s.side, 30000.0, func(o: CShip) -> bool: return not submerged(o)))

func launch_strike(s: CShip, tg: CShip) -> bool:
    if tg == null or s.sub: return false
    if int(wx.sea) >= 3 or wx.fog or (wx.night and not s.tech.has("jets")):   # no flying in a storm or fog, and only jets by night
        if s.side == 0 and s == flag: say("Aircraft cannot fly: " + ("a storm." if int(wx.sea) >= 3 else ("fog." if wx.fog else "it is night, and only jets fly by night.")), 2.5)
        return false
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
                    if hit: mark_hit(tg, bp, 3.0, true); hit_systems(tg, bp, 260 if q.jet else 230, "bomb"); damage(tg, 260 if q.jet else 230, "bomb"); fx_boom(bp, 26.0, 0.8)
                    else: fx_splash(bp, 22.0)
                q.state = "home"; sound("hit_big", tg.pos, 0.4)
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
    _radar_plot(dt); _smoke_tick(dt)
    for s in ships:
        if not s.alive: s.sink += dtv; continue
        if s.escaped: continue
        s.reveal_t = maxf(0.0, s.reveal_t - dt); s.ram_t = maxf(0.0, s.ram_t - dt); s.lit_t += dt
        # AI ships think four times a battle second and work their weapons ten times; your flagship every step
        if s == flag:
            if player_rudder != 0.0: waypoints.clear()   # taking the helm yourself cancels the waypoints
            while not waypoints.is_empty() and s.pos.distance_to(waypoints[0]) < maxf(150.0, s.d.L * 1.2): waypoints.pop_front()
            s.rudder = player_rudder if waypoints.is_empty() else helm(s, steer_avoid(s, (waypoints[0] - s.pos).angle()))
        else:
            s.ai_acc += dt
            if s.ai_acc >= 0.25: ai_ship(s, s.ai_acc); s.ai_acc = 0.0
        if s.sub: s.dive = clampf(s.dive + (dt / 30.0 if s.want_dive else -dt / 30.0), 0.0, 1.0)
        s.wpn_acc += dt
        if s == flag or s.wpn_acc >= 0.1: update_weapons(s, s.wpn_acc); s.wpn_acc = 0.0
        var sm = submerged(s)
        # engines: way builds slowly in a big ship and bleeds off slower still; a hard turn scrubs off up to a third
        var top: float = (s.d.get("subKn", s.d.kn * 0.4) if sm else s.d.kn) * KN * speed_mult(s)
        top *= (1.0 - 0.25 * absf(s.list)) * s.ld_speed
        var want: float = top * TELEGRAPH[s.throttle] * (1 - 0.3 * absf(s.rud) * minf(1.0, s.v / maxf(1.0, top)))
        if s.v_cmd >= 0.0 and s != flag: want = minf(want, s.v_cmd)
        var t_acc: float = 40.0 + s.d.L * 0.6
        if top <= 0.0: s.v = maxf(0.0, s.v - s.d.kn * KN / (t_acc * 1.4) * dt)   # engines stopped: she loses way
        else: s.v += clampf(want - s.v, -top / (t_acc * 1.4) * dt, top / t_acc * dt)
        # helm: about 10 s to put the rudder hard over, then the ship settles into a turn on its tactical diameter
        if s.jam > 0: s.rud = s.jam_r   # steering gear out: the rudder stays where it jammed
        else: s.rud += clampf(s.rudder - s.rud, -dt / 10.0, dt / 10.0)
        systems_tick(s, dt)
        # a listing ship pulls to her low side; worn steering gear and a list both cut how hard she can turn
        var w_target: float = (s.rud + 0.22 * s.list) * s.v / (s.d.td / 2) * (1 + 0.1 * s.sk.helm) * (0.8 if sm else 1.0) * s.steer * (1.0 - 0.3 * absf(s.list)) * s.ld_turn
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
        if retreating and not s.struck:
            var o = nearest_any(s.pos, s.side)   # seen or not: darkness alone is not an escape
            var edge = s.pos.x < 200 or s.pos.x > AW - 200 or s.pos.y < 200 or s.pos.y > AH - 200
            if edge or o == null or s.pos.distance_to(o.pos) > escape_r:
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
        if modern and not s.sub and s.v > 2.0 and active(s):   # bow spray flung out at speed, the stern churning
            var sk := clampf(s.v / (s.d.kn * KN), 0.0, 1.0)
            if randf() < dtv * 14.0 * sk:
                var sd := 1.0 if randf() < 0.5 else -1.0; var bx: float = s.d.L * 0.38
                var q = part(P.SPRAY, world_pt(s, bx, sd * hull_half(s.d, bx)), 0.5 + randf() * 0.5, s.d.B * (0.04 + 0.04 * sk), Vector2.from_angle(s.a + sd * (1.3 + randf() * 0.4)) * (6.0 + s.v * (0.8 + randf()))); q.drag = 0.2
            if randf() < dtv * 6.0 * sk:
                var c = part(P.CHURN, world_pt(s, -s.d.L * 0.5, (randf() - 0.5) * s.d.B * 0.5), 2.5 + randf() * 2.0, s.d.B * (0.25 + randf() * 0.2), -Vector2.from_angle(s.a) * s.v * 0.3); c.a = randf() * TAU; c.spin = (randf() - 0.5) * 0.6
        if not s.sub and s.d.p.has("fun") and s.d.p.fun.size():
            s.smoke_t -= dtv
            if s.smoke_t <= 0:
                s.smoke_t = 0.2
                for f in s.d.p.fun:
                    var fp: Vector2 = world_pt(s, f[0], f[3] if f.size() > 3 else 0.0)
                    if s.eng_out > 0:   # engines stopped: no draught in the funnels, steam blowing off instead
                        if modern and randf() < 0.5: part(P.STEAM, fp + rdir() * s.d.B * 0.2, 4.0 + randf() * 2.0, 2.5 + s.d.B * 0.2, rdir() * 3.0, true)
                    else:
                        part(P.FUNNEL, fp, 5.0, 2.0 + s.d.B * 0.14, -Vector2.from_angle(s.a) * 3.0, true)
                        if s.eng < 0.75 and randf() < (0.9 - s.eng): part(P.SMOKE, fp, 6.0 + randf() * 3.0, 2.5 + s.d.B * 0.2, -Vector2.from_angle(s.a) * 3.0, true)   # damaged boilers smoke black
        # fires burn where they started, move with the ship and pour smoke downwind until damage control puts them out
        if s.hull / s.max_hull < 0.4 and s.fires.size() < 3 and randf() < dt * 0.01: mark_hit(s, s.pos + Vector2((randf() - 0.5) * s.d.L * 0.4, 0).rotated(s.a), 2.0, false)
        for i in range(s.fires.size() - 1, -1, -1):
            var f: Dictionary = s.fires[i]; f.t -= dt * (1 + 0.3 * s.sk.dc) * (1.3 if s.tech.has("dc") else 1.0)
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
            var res := shell_result(hit, sh); _log("shell " + res.kind)
            mark_hit(hit, sh.pos, sz * (1.0 if res.kind == "pen" else 0.5), res.kind != "rico", float(res.get("fire", 1.0)))
            if res.kind == "pen": hit_systems(hit, sh.pos, sh.dmg, "shell")
            damage(hit, sh.dmg * res.k, "resolved")
            if res.kind == "rico": part(P.SPARK, sh.pos, 0.5, 2 + sz, Vector2.from_angle((sh.e - sh.s).angle() + (randf() - 0.5) * 1.2) * 120.0)
            else: fx_boom(sh.pos, 7 * sz * (1.0 if res.kind == "pen" else 0.6), 0.6)
            var mine: bool = sh.side == 0 or hit.side == 0
            if mine: hit_marks.append({"pos": sh.pos, "text": res.text, "kind": res.kind, "t": 1.8, "ours": hit.side == 0})
            for k2 in (8 if modern else 3): part(P.SPARK, sh.pos, 0.4 + randf() * 0.4, 1 + sz * 0.6, Vector2(randf() - 0.5, randf() - 0.5) * (160.0 if modern else 60.0))
            sound("hit", sh.pos, 0.14 * sz)
        elif land_at(sh.pos): part(P.DUST, sh.pos, 1.6, 9 * sz)
        else: fx_splash(sh.pos, 6 * sz); sound("splash", sh.pos, 0.05 * sz)
    # torpedoes
    for i in range(torps.size() - 1, -1, -1):
        var tp: Dictionary = torps[i]; tp.life -= dt; tp.arm -= dt
        if tp.homing and tp.arm <= 0:
            var tpa: float = tp.a; var tpp: Vector2 = tp.pos
            var tg = nearest_enemy(tp.pos, tp.side, 1200.0, func(o: CShip) -> bool: return absf(ang_diff((o.pos - tpp).angle(), tpa)) < 0.7)  # homers hear submerged boats too
            if tg != null: tp.a += clampf(ang_diff((tg.pos - tp.pos).angle(), tp.a), -0.15 * dt, 0.15 * dt)
        tp.pos += Vector2.from_angle(tp.a) * tp.speed * dt
        var gone: bool = tp.life <= 0
        if not gone and land_at(tp.pos): gone = true; fx_boom(tp.pos, 20.0)
        if not gone and tp.arm <= 0:
            for s in ships:
                if s.side == tp.side or not active(s) or (submerged(s) and not tp.homing): continue
                var l: Vector2 = (tp.pos - s.pos).rotated(-s.a)
                if absf(l.x) < s.d.L / 2 and absf(l.y) < s.d.B / 2 + 2:
                    mark_hit(s, tp.pos, 4.0, false); hit_systems(s, tp.pos, tp.dmg, "torp"); damage(s, tp.dmg, "torp"); part(P.GEYSER, tp.pos, 1.6, 40.0); part(P.WASH if modern else P.FOAM, tp.pos, 16.0 if modern else 12.0, 45.0 if modern else 60.0)
                    sound("torp_hit", tp.pos, 0.55); gone = true; break
        if not gone and randf() < dtv * 4: part(P.TWAKE, tp.pos, 4.0, 1.5)
        if gone: torps.remove_at(i)
    # missiles
    for i in range(missiles.size() - 1, -1, -1):
        var m: Dictionary = missiles[i]
        if m.get("dead", false): missiles.remove_at(i); continue
        if m.delay > 0: m.delay -= dt; continue
        var age: float = m.get("age", -1.0)
        if age < 0.0: # leaving the rail: a burst of flame, a white cloud and some dark smoke from the booster
            var back = Vector2.from_angle(m.a + PI)
            part(P.FIRE, m.pos + back * 3.0, 0.6, 7.0 if m.kind == "ssm" else 4.0)
            var f = part(P.FLASH, m.pos, 0.18, 6.0 if m.kind == "ssm" else 3.5); f.a = m.a + PI
            part(P.MTRAIL, m.pos + back * 4.0, 4.0, 9.0 if m.kind == "ssm" else 5.0)
            for k2 in 3: part(P.GUNSMOKE, m.pos + back * (2.0 + k2 * 3.0) + Vector2(randf() - 0.5, randf() - 0.5) * 6.0, 3.0 + randf() * 2.0, 4.0 + randf() * 3.0, Vector2(randf() - 0.5, randf() - 0.5) * 8.0, true)
            sound("launch", m.pos, 0.35 if m.kind == "ssm" else 0.2)
            age = 0.0
        m.age = age + dt
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
            if m.kind == "ssm" and d < maxf(20.0, m.target.d.B) and m.target.tech.has("ecm") and not m.get("ecm_tried", false):
                m.ecm_tried = true
                if randf() < 0.25:   # electronic countermeasures: the seeker is decoyed and the missile runs on into the sea
                    fx_splash(m.pos + Vector2.from_angle(m.a) * 80.0, 14.0); missiles.remove_at(i); continue
            if m.kind == "ssm" and d < maxf(20.0, m.target.d.B):
                mark_hit(m.target, m.pos, 4.0, false); mark_hit(m.target, m.pos, 3.0, false); hit_systems(m.target, m.pos, m.dmg, "missile"); damage(m.target, m.dmg, "missile")
                fx_boom(m.pos, 40.0, 0.9); part(P.FIRE, m.pos, 2.0, 12.0); sound("hit_big", m.pos, 0.55); missiles.remove_at(i); continue
        m.pos += Vector2.from_angle(m.a) * m.v * dt
        if modern:   # smoke laid every few metres of flight, so the trail is one unbroken line however fast she flies
            var step_m: float = m.v * dt; var n_p := clampi(int(ceil(step_m / 3.5)), 1, 12); var back_v: Vector2 = Vector2.from_angle(m.a)
            for k in n_p:
                var tp = part(P.MTRAIL, m.pos - back_v * (6.0 + step_m * k / n_p) + Vector2(randf() - 0.5, randf() - 0.5) * 2.0, (1.1 if m.kind == "sam" else 2.0) + randf() * 0.5, 3.6 + randf() * 1.5, Vector2.ZERO, true)
                tp.a = randf() * TAU
        elif randf() < dtv * 30: part(P.MTRAIL, m.pos, 1.0 if m.kind == "sam" else 2.0, 4.0)
        if m.age < 1.6: # the booster burning: flame at the tail, darker smoke mixed into the trail
            part(P.FIRE, m.pos - Vector2.from_angle(m.a) * 2.0, 0.12, 2.5 if m.kind == "ssm" else 1.6)
            if randf() < dtv * 10: part(P.SMOKE, m.pos - Vector2.from_angle(m.a) * 4.0, 2.5, 3.0, Vector2.ZERO, true)
        if m.life <= 0:
            if m.kind == "ssm": fx_splash(m.pos, 14.0)
            missiles.remove_at(i)
    update_air(dt)
    for i in range(dcs.size() - 1, -1, -1):
        var q = dcs[i]; q.t -= dt
        if q.t > 0: continue
        dcs.remove_at(i); sound("depth", q.pos, 0.3)
        if modern:   # spray flung out of the dome, a ring across the water, and the foam it leaves
            for j in 9:
                var sp = part(P.SPRAY, q.pos + rdir() * 8.0, 0.8 + randf() * 0.9, 7.0 + randf() * 6.0, rdir() * (40.0 + randf() * 110.0)); sp.drag = 0.2
            part(P.WRING, q.pos, 2.2, 90.0); var fm = part(P.WASH if modern else P.FOAM, q.pos, 18.0, 40.0 if modern else 55.0); fm.a = randf() * TAU; fm.spin = (randf() - 0.5) * 0.08
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
    _wrecks(dtv)
    if modern:   # a badly hurt ship trails oil, and one sinking leaves her boats, rafts and wreckage on the water
        for s in ships:
            if s.alive and not s.escaped and s.hull / s.max_hull < 0.35 and s.v > 1.0 and randf() < dtv * 0.8: part(P.OIL, s.pos - Vector2.from_angle(s.a) * s.d.L * 0.3, 26.0, s.d.B * (0.8 + randf() * 0.8))
            if not s.alive and s.sink < 3.0 and randf() < dtv * 3.0: wreckage(s, s.pos + Vector2((randf() - 0.5) * s.d.L * 0.7, (randf() - 0.5) * s.d.B).rotated(s.a), 1, 2.0)
    for i in range(parts.size() - 1, -1, -1):
        var q = parts[i]; q.life += dtv
        if q.wind and q.life > 0: q.pos += WIND * dtv
        if q.vel != Vector2.ZERO:
            q.pos += q.vel * dtv; q.vel *= pow(q.drag, dtv)
        if q.spin != 0.0: q.a += q.spin * dtv
        if q.t == P.DEBRIS and q.spin != 0.0 and q.life > 0.0 and randf() < dtv * 22.0:   # a burning fragment leaves a thread of smoke
            var tr = part(P.SMOKE, q.pos, 0.9 + randf() * 0.8, q.size * (1.2 + randf()), q.vel * 0.05, true); tr.a = randf() * TAU
        if q.life >= q.mx: parts.remove_at(i)
    flash = maxf(0.0, flash - dtv * 1.4)
    if parts.size() > 3200:
        parts.reverse(); parts.resize(3200); parts.reverse()
    for i in range(hit_marks.size() - 1, -1, -1):
        hit_marks[i].t -= dtv
        if hit_marks[i].t <= 0: hit_marks.remove_at(i)
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
