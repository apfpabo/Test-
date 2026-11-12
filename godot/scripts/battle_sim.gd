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
    CORE, FIREBALL, RING, DEBRIS, EMBER, SPRAY, WRING, GLOW, CHURN, FLARE, SOOT, WASH, STEAM, DIRT, COLUMN, LACE }   # the modern effects (Settings.fx_modern)

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
    var radar_on := true    # her search radar radiating (off: she sees by eye alone, and no one hears her set)
    var sonar_on := true    # her active sonar pinging (off: she only listens; a boat starts so)
    var ping_t := 0.0       # until her next ping
    var held_t := 99.0      # a submerged boat: seconds since a ping last found her
    var heard_t := 99.0     # seconds since an enemy heard her ping (it gives her away)
    var lit_t = 99.0       # seconds since her own guns last fired: gun flashes give a ship away in the dark
    var radar_only := false   # an enemy held by your radar alone, beyond the eye's reach (see BattleSim._radar_plot)
    var paint_t := 99.0       # battle seconds since a radar sweep last painted her
    var paint_pos := Vector2.ZERO
    var torp_run_t = 0.0
    var ai_acc = 0.0
    var wpn_acc = 0.0
    var mounts: Array[Mount] = []
    var squads: Array = []
    var deck_out := 0.0      # seconds until the flight deck is patched and flying can go on
    var deck_t := 0.0        # until the deck is clear for the next machine
    var deck_ops: Array = [] # machines taking off or landing at this moment (drawn one by one)
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
    var sheer = null       # a ship she has just struck: she steers clear of her for `sheer_t` seconds
    var sheer_t := 0.0
    var brake := -1.0      # a speed not to exceed while another ship is close ahead (keeping clear), or -1
    var ord = ""           # her own order, if she has been given one apart from the squadron's (see ord_of)
    var ord_pt := Vector2.ZERO   # where "goto" sends her
    var ord_tgt: CShip = null    # whom a torpedo attack is made on (or the nearest enemy)
    var hold = false       # her own hold-fire
    var ai_off = false     # (editor) she keeps her helm and engines as set: her captain does nothing
    var force_tgt: CShip = null   # (editor) the ship she is to fire on, whatever its flag
    var god = false        # (editor) takes no damage
    var star_t = 0.0       # seconds until she can fire star shell again
    var sol: Dictionary = {}   # her gunnery solutions, one for each ship she is firing on (see solution)
    var cq = 1             # how good her crew is: 0 green, 1 trained, 2 seasoned, 3 veteran, 4 crack (see CREW)
    var dc_pri = ""        # where her damage-control parties are sent first: "" (evenly), "fire", "flood" or "mach"
    var ballast = 0.0      # water let in to right a list: it stays aboard and slows her
    var foul_by: CShip = null   # a friend lying in the track of the torpedoes she would fire (see torp_fouls)
    var foul_at := -99.0        # when that was last found (battle seconds)
    var foul_since := 0.0       # when her torpedoes were first held for it
    var foul_said := false      # (a torpedo attack) she has said why she is holding
    var dc_held_at := -99.0     # when she last held a pattern for a friend (a measure: see sys_log)
    var fp := 0                 # floatplanes aboard on her catapults (see launch_spotter)
    var blown := false          # lost to her own magazine: nothing left to raise (Campaign wrecks)
    var tm := "steady"          # her captain's temper: "bold", "steady" or "cautious" (Campaign.TEMPERS, temper_k)
    var fp_t := 0.0             # until her captain will next think of flying one off
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
    var over := false   # foam thrown over a ship: drawn above her while it is young
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
## Set by the battle screen when it is zoomed far out (under 0.35): funnel smoke and missile trails are laid half as
## thick in bigger puffs, which look the same from there (a ten-ship action spent ten milliseconds a frame on nearly
## two thousand puffs a few pixels across; 12 Nov 2026). The simulation itself is untouched by it.
var fx_far := false
var twakes: Array = []      # the wakes of torpedoes that have run out or struck, fading where they lie
const TWAKE_LIFE := 3.5     # seconds a torpedo's wake lasts on the sea (some 120 m behind her: the owner found 10 s too long)
var missiles: Array = []
var air: Array = []
var parts: Array[Part] = []
var modern := true                 # the modern effects: layered explosions, light, spray (Settings.fx_modern); false = classic
var splash_new := true             # the new shell splashes (Settings.splash): column, curtain and lacy slick; false = the classic splash
var flash := 0.0                   # a magazine going up lights the whole sky for a moment
var wx: Dictionary = Weather.CLEAR  # the weather and light the battle is fought in (Weather.battle): sea, fog, night, moon, vis, radar
var tracers: Array = []
var hit_marks: Array = []        # floating hit results for the HUD: {pos, text, col, t, ours}
var islands: Array = []
var order = "engage"
## Orders to single ships and divisions (owner's order of work: battle depth). A ship of yours with her own order
## (`ord`) follows it instead of the squadron's; formations are made among the ships that share an order, so three
## destroyers told to form line abreast do so by themselves. "goto" sends her to a point to hold there; "torp" is a
## torpedo attack: run in, turn and fire, then take the squadron's order again.
func ord_of(s: CShip) -> String: return s.ord if s.side == 0 and s.ord != "" else order
func holding(s: CShip) -> bool: return (s.side == 0 and hold_fire) or s.hold
func has_torps(s: CShip) -> bool:
    for m in s.mounts: if m.w.kind == "torp" and m.ammo != 0: return true
    return false
var hold_fire := false            # squadron order: every ship but the flagship holds her fire (to stay unseen at night, or save shells)
var t = 0.0        # battle clock
var vt = 0.0       # visual clock
static var rclock := 0.0   # the battle screen's drawing clock (seconds of frames drawn), for flicker and sway
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
var ff_dmg := 0.0   # hull points taken off ships by their own side's shells (a measure, shown nowhere)
var ff_dmg_t := 0.0   # ... by their own side's torpedoes
var ff_dmg_dc := 0.0  # ... by their own side's depth charges
var ff_care := true   # captains and pilots look for friends before torpedoes and depth charges (false only to measure what the rule saves)
var ff_ok := {}       # the player has been warned that a friend is in danger: {"kind": "torp"|"dc", "t": battle time}; a second press within FF_CONFIRM fires
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

## Her mounts from her record's fit (at the start, and again when the editor refits her in mid-action).
func fit_mounts(s: CShip) -> void:
    var d: Dictionary = s.d; var rec: Dictionary = s.rec
    s.mounts.clear()
    for i in d.slots.size():
        var wid: String = rec.fit[i] if rec.fit[i] != null else ""
        if wid == "" or not GameData.weapons.has(wid): continue
        var m = Mount.new(); m.slot = d.slots[i]; m.wid = wid; m.w = GameData.weapons[wid]; m.ta = m.slot.arcs[0][0]; m.cd = randf() * m.w.rel * 0.5
        m.ammo_max = full_ammo(wid, m.w); m.ammo = int(round(m.ammo_max * float(rec.get("ammo", 1.0)))) if m.ammo_max > 0 else -1
        s.mounts.append(m)
    var best := -1
    for m in s.mounts: if m.w.kind == "gun": best = maxi(best, GUN_SIZES.find(m.w.size))
    s.main_sz = GUN_SIZES[maxi(best, 0)]
    var ld := loading(d, rec.fit, s.up); s.ld_speed = ld.speed; s.ld_turn = ld.turn; s.ld_spread = ld.spread
# ------------------------------------------------------------------ the editor (owner's request: a mode to stage and record actions)
## In editor mode the action never ends by itself, every ship is in sight unless `reveal` is put off, and ships can
## be put on the sea, taken off it, refitted, commanded and set on one another whatever their flags.
var editor := false
var reveal := true
func spawn(type: String, side: int, at: Vector2, heading: float, tech: Array) -> CShip:
    var names: Array = GameData.names.get("player" if side == 0 else "directorate", GameData.names.player)
    var rec := {"id": str(randi()), "type": type, "name": names.pick_random(), "hullFrac": 1.0, "fit": default_fit(GameData.hulls[type], tech), "pal": "player" if side == 0 else "directorate"}
    var s := make_ship(rec, side, at, heading, tech); ships.append(s)
    if flag == null and side == 0: flag = s
    return s
func despawn(s: CShip) -> void:
    ships.erase(s)
    for i in range(air.size() - 1, -1, -1): if air[i].home == s: air.remove_at(i)   # her aircraft go with her: they would circle for ever, with no deck to work them
    s.deck_ops.clear()
    for x in ships:
        if x.force_tgt == s: x.force_tgt = null
        if x.target == s: x.target = null
        if x.ord_tgt == s: x.ord_tgt = null
        for m in x.mounts: if m.tgt == s: m.tgt = null
    if lock == s: lock = null
    if flag == s:
        flag = null
        for x in ships: if x.side == 0 and active(x): flag = x; break
func set_side(s: CShip, side: int) -> void:
    s.side = side; s.pal = "player" if side == 0 else str(s.rec.get("pal", "directorate")); s.target = null; s.flee = false
    for m in s.mounts: m.tgt = null

func make_ship(rec: Dictionary, side: int, p: Vector2, a: float, tech: Array) -> CShip:
    var s = CShip.new(); var d: Dictionary = GameData.hulls[rec.type]
    s.rec = rec; s.d = d; s.pal = rec.pal if side == 1 else "player"; s.side = side; s.pos = p; s.a = a
    s.up = rec.get("up", {})   # other navies' ships carry their refits into action too
    s.eng = 1.0 - 0.2 * clampf(float(rec.get("wear", 0.0)), 0.0, 1.0)   # worn machinery (Campaign.WEAR_ENG): damage control can bring it to 0.8 at best, as for a hit
    s.tech = tech
    var cap: int = 1 if drone_ship(d, tech) else d.get("p", {}).get("cat", []).size()
    s.fp = clampi(int(rec.get("fp", cap)), 0, cap); s.fp_t = 20.0 + randf() * 40.0
    s.v = d.kn * KN * 0.6; s.max_hull = d.hull * (1.0 + 0.08 * upg(s, "hull")) * (0.85 if rec.get("defects", []).has("hull") else 1.0); s.hull = s.max_hull * rec.hullFrac; s.armor = d.armor * (1.0 + 0.1 * upg(s, "hull")) * (0.6 + 0.4 * rec.hullFrac)
    s.pref_side = 1 if randf() < 0.5 else -1; s.tech = tech; s.sub = d.kind == "sub"
    s.sonar_on = not s.sub; s.ping_t = randf() * PING_PERIOD   # a boat listens and keeps quiet until told to ping
    s.cq = crew_level(float(rec.get("xp", 1.0)))
    # what she is loaded with tells at sea, whoever's she is (owner's decision: other navies are held to the same rules)
    fit_mounts(s)
    if d.get("sonar", false) and d.kind != "sub": s.dc_left = int(round(6 * float(rec.get("ammo", 1.0))))
    # aircraft aboard: a campaign carrier may be short of planes lost in earlier strikes (rec.air)
    var aboard: int = int(rec.get("air", int(d.get("hangar", 0)) * 6))
    for i in int(d.get("hangar", 0)):
        var n := clampi(aboard - i * 6, 0, 6)
        s.squads.append({"state": "ready" if n > 0 else "lost", "t": 0.0, "n": n, "n0": 6})
    if side == 1 and d.kind == "merchant": s.flee = true
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

## A boat that has dived is found by sound alone (owner's direction, 11 Nov 2026), and sound cuts both ways.
## *Active*: a ship with sonar switched on pings every PING_PERIOD seconds; the ping runs out as a ring (`pings`) and a
## submerged boat it reaches inside `sonar_range` is held for PING_HOLD seconds. But a ping is heard PING_HEAR times as
## far as it finds: every hydrophone of the other side in that distance knows where the pinger is (`heard_t`), a
## surface ship lost in the dark or a boat that pings herself alike. *Passive*: with the set silent a ship only
## listens, and hears a boat close to and by the noise she makes: a boat creeping is all but silent, one running fast
## submerged is heard some way off; a listener steaming hard hears less. A ship with no sonar has only her lookouts,
## for a periscope close aboard.
const PING_PERIOD := 8.0
const PING_SPEED := 650.0   # how fast the ring runs out, metres a battle second (it is drawn, and found by, as it passes)
const PING_HOLD := 14.0
const PING_HEAR := 2.5
const HEARD_FOR := 12.0
const RADAR_HEARD := 1.25   # a radiating set is picked up this many times as far as it sees, by a ship that has a set of her own
var pings: Array = []       # {pos, r, max, side, who, echo}: rings on the water, for finding and for drawing
## Research levels (the owner's request, 12 Nov 2026): a technology's further levels are carried in the same list as
## "<id>+2" and "<id>+3", so `tech.has(id)` still means "researched". `tech_lv` is 0 to 3, `tech_up` the levels past
## the first (0 to 2), by which each effect below grows a step.
static func tech_lv(tech: Array, id: String) -> int:
    if tech.has(id + "+3"): return 3
    if tech.has(id + "+2"): return 2
    return 1 if tech.has(id) else 0
static func tech_up(tech: Array, id: String) -> int: return maxi(0, tech_lv(tech, id) - 1)
func radar_fitted(s: CShip) -> bool: return not s.sub and (s.tech.has("radar") or upg(s, "radar") > 0)
func has_sonar(s: CShip) -> bool: return s.sub or bool(s.d.get("sonar", false))
func pinging(s: CShip) -> bool: return has_sonar(s) and s.sonar_on and active(s)
## How far a listener hears a submerged boat with her set silent.
func passive_range(o: CShip, sb: CShip) -> float:
    if not has_sonar(o): return 250.0
    var top: float = float(sb.d.get("subKn", sb.d.kn * 0.4)) * KN
    var noise: float = 0.4 + 1.7 * clampf(sb.v / maxf(top, 0.1), 0.0, 1.0)
    var own: float = clampf(o.v / maxf(float(o.d.kn) * KN, 0.1), 0.0, 1.0)
    return 420.0 * (1.4 if o.sub else 1.0) * noise * (0.6 if own > 0.7 else 1.0) * (1.0 + 0.3 * upg(o, "sonar"))
func detected_by(sb: CShip, side: int) -> bool:
    if not submerged(sb) or sb.reveal_t > 0: return true
    if sb.held_t < PING_HOLD or sb.heard_t < HEARD_FOR: return true   # found by a ping, or given away by her own
    for o in ships:
        if o.side != side or not active(o): continue
        if o.pos.distance_to(sb.pos) < passive_range(o, sb): return true
    return false
## The pings: sent, running out, finding boats and being heard. Each step.
func _sonar_tick(dt: float) -> void:
    for s in ships:
        s.held_t += dt; s.heard_t += dt
        if not pinging(s): continue
        s.ping_t -= dt
        if s.ping_t > 0.0: continue
        s.ping_t = PING_PERIOD
        pings.append({"pos": s.pos, "r": 0.0, "max": sonar_range(s), "side": s.side, "who": s, "echo": false})
        # every ping is heard, fading with distance from the camera: your flagship's loudest, your other ships less, an enemy's
        # faint as if through the water (only the flagship's used to sound; the owner saw silent rings, 12 Nov 2026)
        sound("ping", s.pos, 0.5 if s == flag else (0.3 if s.side == 0 else 0.16))
    for i in range(pings.size() - 1, -1, -1):
        var p: Dictionary = pings[i]; var r0: float = p.r; p.r += PING_SPEED * dt * (0.6 if p.echo else 1.0)
        if p.echo:
            if p.r > 260.0: pings.remove_at(i)
            continue
        for o in ships:
            if o.side == p.side or not active(o): continue
            var d: float = o.pos.distance_to(p.pos)
            if d <= r0 or d > p.r: continue   # the ring passes her this step
            if submerged(o) and d <= float(p.max):
                o.held_t = 0.0; pings.append({"pos": o.pos, "r": 0.0, "max": 260.0, "side": p.side, "who": o, "echo": true})   # the echo comes back
            if has_sonar(o) and p.who != null: (p.who as CShip).heard_t = 0.0   # and she has heard who sent it
        if p.r > float(p.max) * PING_HEAR: pings.remove_at(i)

## Whether a side can see a ship. Submarines as before (sonar). In bad visibility or at night a surface ship is seen
## only within sight of some ship of that side: the eye's reach in this weather, or the radar's for a ship that has
## one. A ship that has just fired, or is burning, shows at twice the distance: she lights herself up.
## Radar (docs/SENSORS.md). A surface ship of a side that has researched it carries a search set; submarines carry
## none (they listen: sonar). Sets of the first two eras turn a beam round the horizon, about six turns a minute, and
## see a contact once each turn; phased arrays (the Aegis research) look every way at once.
const RADAR_PERIOD := 10.0   # battle seconds for one turn of a rotating aerial
func has_radar(s: CShip) -> bool: return s.radar_on and radar_fitted(s)   # a set switched off sees nothing (and is not heard)
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
    var base: float = 1500.0 * ((1.6 + 0.2 * tech_up(o.tech, "sonar") if sonar_tech else 1.0) * (1.4 + 0.15 * tech_up(o.tech, "helo") if helo_tech else 1.0) if o.side == 0 else (1.6 if enemy_era >= 2 else 1.0) * (1.4 if enemy_era >= 3 else 1.0))
    if o.sub: return base * 1.4
    return base * (1.0 + 0.3 * upg(o, "sonar")) if o.d.get("sonar", false) else 0.0
## Whether the lookouts of a side have a surface ship in sight by eye alone (no radar): within sight in this weather
## and light of one of its ships; twice as far if she has just fired or is burning.
func eye_sees(s: CShip, side: int) -> bool:
    var lim := limited()
    if not lim and screens.is_empty(): return true
    var r: float = float(wx.vis) * (2.0 if (s.lit_t < 6.0 or not s.fires.is_empty() or s.mag_fire > 0) else 1.0)
    if lim and not flares.is_empty() and star_lit(s.pos): r = maxf(r, STAR_REACH * (0.35 if wx.get("fog", false) else 1.0))
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
        if e.paint_t > 0.0 and (_radar_heard(e, 0) or e.heard_t < HEARD_FOR): e.paint_t = 0.0; e.paint_pos = e.pos   # her own set, or her ping, gives a steady bearing

func sight(o: CShip) -> float:
    var v: float = float(wx.vis)
    if has_radar(o): v = maxf(v, float(wx.radar) * (1.0 + 0.15 * upg(o, "radar")) * (1.15 + 0.05 * tech_up(o.tech, "datalink") if o.tech.has("datalink") else 1.0))
    return v
func limited() -> bool: return float(wx.vis) > 0.0
## What a captain sends out (emission control). Other navies' captains choose, as you do for your own ships (a side
## with no flagship, in tests and recordings, is run the same way). By day in clear weather nothing is lost by it:
## everything is on. In the dark or the murk:
##   *Sonar*: a ship keeps silent and listens, unless her side has had word of a submarine in the last three minutes
##   (a boat seen, heard, or a torpedo track): then the ships near where she was last known ping to find her; or unless
##   the ship is in the enemy's sight anyway, when silence hides nothing. A boat pings only to hunt another boat, and
##   only with no hunter near enough to hear her.
##   *Radar*: a ship that is not yet seen, and whose side has nothing in sight, runs with her set off and closes
##   unobserved; one ship (the first that carries a set) looks round with hers for twenty seconds in every ninety, so
##   the force is not blind. Once she is seen, or there is an enemy to shoot at within reach of her guns, the set goes on.
var sub_alarm := [999.0, 999.0]            # seconds since each side last knew of an enemy submarine
var sub_seen := [Vector2.ZERO, Vector2.ZERO]   # and where
var _emcon_t := 0.0
func _emcon(dt: float) -> void:
    sub_alarm[0] += dt; sub_alarm[1] += dt
    for sb in ships:
        if not sb.sub or not active(sb): continue
        var other: int = 1 - sb.side
        if (submerged(sb) and detected_by(sb, other)) or (not submerged(sb) and visible_to(sb, other)): sub_alarm[other] = 0.0; sub_seen[other] = sb.pos
    _emcon_t -= dt
    if _emcon_t > 0.0 or editor: return
    _emcon_t = 1.5
    var dark: bool = limited()
    for side in 2:
        if side == 0 and flag != null: continue   # your ships: your switches
        var has_contact := false; var picket: CShip = null
        for o in ships:
            if o.side != side and engageable(o) and visible_to(o, side): has_contact = true
            if o.side == side and active(o) and picket == null and radar_fitted(o): picket = o
        for s in ships:
            if s.side != side or not active(s) or s.ai_off: continue
            var seen: bool = visible_to(s, 1 - side) if dark else true
            if has_sonar(s):
                var was: bool = s.sonar_on
                if s.sub:
                    var hunter_near := false
                    for o in ships: if o.side != side and active(o) and not o.sub and has_sonar(o) and o.pos.distance_to(s.pos) < sonar_range(s) * PING_HEAR: hunter_near = true
                    s.sonar_on = submerged(s) and sub_alarm[side] < 180.0 and not hunter_near and s.pos.distance_to(sub_seen[side]) < 5000.0
                elif not dark: s.sonar_on = true
                else: s.sonar_on = seen or (sub_alarm[side] < 180.0 and s.pos.distance_to(sub_seen[side]) < 4500.0)
                if s.sonar_on and not was: s.ping_t = randf() * 2.0
            if radar_fitted(s):
                if not dark or seen: s.radar_on = true
                elif has_contact: s.radar_on = nearest_enemy(s.pos, side, max_gun_range(s) * 1.05, func(o: CShip) -> bool: return visible_to(o, side)) != null
                else: s.radar_on = s == picket and fmod(t, 90.0) < 20.0

## Is a ship's radiating radar picked up by a side? By any of its ships that carries a set (on or off), within
## RADAR_HEARD times the distance her radar sees.
func _radar_heard(s: CShip, side: int) -> bool:
    if not has_radar(s) or submerged(s): return false
    var r: float = sight(s) * RADAR_HEARD
    for o in ships: if o.side == side and active(o) and radar_fitted(o) and o.pos.distance_squared_to(s.pos) < r * r: return true
    return false
# ------------------------------------------------------------------ star shell
## At night a ship with guns can fire star shell: a flare that hangs over a patch of sea for half a minute and shows
## every ship under it as daylight would, to both sides. The ship that fires it gives herself away by the flash.
const STAR_LIFE := 32.0
const STAR_R := 1300.0
const STAR_REACH := 9000.0
var flares: Array = []      # {p, t (seconds burning; negative while the shell is on its way), v}
func can_star(s: CShip) -> bool:
    if not active(s) or s.sub or submerged(s): return false
    for m in s.mounts: if m.w.kind == "gun" and not m.dead: return true
    return false
func fire_star(s: CShip, at: Vector2) -> bool:
    if not can_star(s) or s.star_t > 0.0: return false
    var d := s.pos.distance_to(at)
    if d > STAR_REACH: at = s.pos + (at - s.pos) / d * STAR_REACH; d = STAR_REACH
    flares.append({"p": at, "t": -d / 600.0, "v": randi() % 4}); s.star_t = 18.0; s.lit_t = 0.0
    sound("gun_M", s.pos, 0.3); return true
func _star_tick(dt: float) -> void:
    for s in ships: if s.star_t > 0.0: s.star_t -= dt
    var i := 0
    while i < flares.size():
        var f: Dictionary = flares[i]; f.t += dt
        if float(f.t) > 0.0: f.p += WIND * 0.15 * dt
        if float(f.t) > STAR_LIFE: flares.remove_at(i); continue
        i += 1
## Is this point lit by a flare?
func star_lit(p: Vector2) -> bool:
    for f in flares: if float(f.t) > 0.0 and p.distance_squared_to(f.p) < STAR_R * STAR_R: return true
    return false
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
    if s.side == side or (editor and reveal): return true
    if s.sub and not detected_by(s, side): return false
    var lim := limited()
    if not lim and screens.is_empty(): return true
    if s.heard_t < HEARD_FOR or _radar_heard(s, side): return true   # what she sends out, sound or radar, tells where she is
    if not submerged(s) and spotter_over(side, s.pos): return true   # a floatplane overhead sees over the smoke
    var show: float = 2.0 if (s.lit_t < 6.0 or not s.fires.is_empty() or s.mag_fire > 0) else 1.0
    var eye: float = float(wx.vis) * show
    if lim and not flares.is_empty() and star_lit(s.pos): eye = maxf(eye, STAR_REACH * (0.35 if wx.get("fog", false) else 1.0))   # under a flare she shows as by day
    for o in ships:
        if o.side != side or not active(o): continue
        var d2: float = o.pos.distance_squared_to(s.pos)
        var rr: float = sight(o) * (0.75 - 0.05 * tech_up(s.tech, "stealth") if s.tech.has("stealth") else 1.0)   # (stealth shaping, Era IV: a smaller echo)
        if has_radar(o) and not submerged(o) and d2 < rr * rr: return true   # radar looks through the dark and through smoke
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
    "g203t": 250, "g203": 310, "g203r": 350, "g283": 750, "g356t": 900, "g356": 1150, "g356q": 1500, "g381t": 1020, "g381": 1500, "g406": 1700, "g460": 2500, "g381q": 2000, "g406t": 1150, "g510t": 2700,
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
    if s.rec.get("defects", []).has("shafts"): return _speed_mult(s) * 0.92   # a raised wreck's bent shafts (Campaign.DEFECTS)
    return _speed_mult(s)
func _speed_mult(s: CShip) -> float:
    return (1.0 - (0.05 * int(wx.sea) if s.d.t < 3000.0 and not submerged(s) else 0.015 * int(wx.sea))) * (1.2 + 0.05 * tech_up(s.tech, "snorkel") if s.sub and s.tech.has("snorkel") and submerged(s) else 1.0) * s.fuel_k * (1 + 0.04 * upg(s, "eng")) * (1 + 0.06 * s.sk.helm) * (0.75 + 0.25 * s.cf) * (0.6 + 0.4 * s.hull / s.max_hull) * (0.0 if s.eng_out > 0 else 0.25 + 0.75 * s.eng)

func gun_range(s: CShip, w: Dictionary) -> float:
    return w.range * ((1.15 + 0.05 * tech_up(s.tech, "radar") if s.tech.has("radar") else 1.0) * (1.0 + 0.06 * upg(s, "radar")) if w.kind == "gun" else 1.0) * (1.4 + 0.1 * tech_up(s.tech, "aegis") if w.kind == "sam" and s.tech.has("aegis") else 1.0) \
        * (1.15 + 0.05 * tech_up(s.tech, "datalink") if w.kind == "ssm" and s.tech.has("datalink") else 1.0) * (1.4 + 0.1 * tech_up(s.tech, "precision") if w.kind == "ssm" and s.tech.has("precision") else 1.0) \
        * (1.0 + 0.05 * tech_up(s.tech, "missiles") if w.kind == "ssm" or w.kind == "sam" else 1.0)

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

## Her half-breadth at x (metres from amidships), on the very curves her plan was drawn with (`hullPath` in
## src/game.html: Bézier bow and stern, `bowK`, a transom, or a hull traced from a drawing, `p.outline`), so that what
## is worked out from it (her side when she lists, the sea over her deck, spray, hits at the edge) meets the picture.
## It was a square-root rule, close for the old bows but well off a fine one (the owner saw daylight between the deck
## and the side of the A-150's bow when she listed, 12 Nov 2026). Sampled once per design.
static var _halves := {}
func hull_half(d: Dictionary, x: float) -> float:
    var p: Dictionary = d.get("p", {})
    if d.get("kind", "") == "sub" or p.is_empty():   # submarines keep their own rounded form
        var h0: float = d.L / 2; var fe0: float = p.get("bow", 0.33) * d.L; var fr0: float = p.get("run", 0.2) * d.L; var half: float = d.B / 2
        if x > h0 - fe0: half *= sqrt(maxf(0.0, (h0 - x) / fe0))
        elif x < -h0 + fr0: half *= maxf(p.get("tw", 0.5) if p.get("stern", "c") == "t" else 0.15, sqrt(maxf(0.0, (x + h0) / fr0)))
        return half
    # a uniform table of 129 half-breadths from stern to bow, built once per design: a lookup is an index and a lerp
    # (it was a text key and a walk along the curve on every call, and the battle step grew half again slower)
    var tab: PackedFloat32Array = _halves.get(d.get("id", ""), PackedFloat32Array())
    if tab.is_empty(): tab = _hull_uniform(d); _halves[d.get("id", "")] = tab
    var h: float = d.L * 0.5
    if x <= -h or x >= h: return 0.0
    var u: float = (x + h) / d.L * 128.0; var i: int = mini(int(u), 127)
    return lerpf(tab[i], tab[i + 1], u - i)
static func _hull_uniform(d: Dictionary) -> PackedFloat32Array:
    var e: PackedVector2Array = _hull_table(d); var out := PackedFloat32Array(); out.resize(129)
    var h: float = d.L * 0.5
    for k in 129:
        var x: float = -h + d.L * k / 128.0; var y := 0.0
        if x >= e[0].x: y = e[0].y
        elif x <= e[e.size() - 1].x: y = e[e.size() - 1].y
        else:
            for i in range(1, e.size()):
                if x >= e[i].x:
                    var a2: Vector2 = e[i - 1]; var c: Vector2 = e[i]
                    y = c.y if is_equal_approx(a2.x, c.x) else lerpf(c.y, a2.y, (x - c.x) / (a2.x - c.x)); break
        out[k] = y
    if out[0] < 0.0: out[0] = 0.0
    return out
static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
    var u := 1.0 - t; return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
## The starboard edge from bow to stern as (x, half-breadth), x falling.
static func _hull_table(d: Dictionary) -> PackedVector2Array:
    var p: Dictionary = d.p; var h: float = d.L / 2; var b: float = d.B / 2; var out := PackedVector2Array()
    if p.has("outline"):
        for q in p.outline: out.append(Vector2(float(q[0]), float(q[1])))
        return out
    var fe: float = float(p.get("bow", 0.33)) * d.L; var fr: float = float(p.get("run", 0.2)) * d.L; var xb: float = h - fe; var xs: float = -h + fr
    var tw: float = float(p.get("tw", 0.5)) if p.get("stern", "c") == "t" else 0.0
    var bk: Array = p.get("bowK", [0.42, 0.5])
    for i in 33: out.append(_bez(Vector2(h, 0), Vector2(h - fe * 0.12, b * float(bk[0])), Vector2(xb + fe * float(bk[1]), b), Vector2(xb, b), i / 32.0))
    for i in 33:
        if tw > 0.0: out.append(_bez(Vector2(xs, b), Vector2(xs - fr * 0.6, b), Vector2(-h, b * minf(1.0, tw + 0.3)), Vector2(-h, b * tw), i / 32.0))
        else: out.append(_bez(Vector2(xs, b), Vector2(xs - fr * 0.55, b), Vector2(-h, b * 0.6), Vector2(-h, 0), i / 32.0))
    # a Bézier need not run monotonically in x at its ends: keep the edge falling, taking the widest where it doubles back
    var mono := PackedVector2Array([out[0]])
    for i in range(1, out.size()):
        var q: Vector2 = out[i]; var last: Vector2 = mono[mono.size() - 1]
        if q.x < last.x - 0.001: mono.append(q)
        else: mono[mono.size() - 1] = Vector2(last.x, maxf(last.y, q.y))
    return mono

# ------------------------------------------------------------------ effects
func part(type: int, p: Vector2, mx: float, size: float, vel := Vector2.ZERO, wind := false, life := 0.0) -> Part:
    var q = Part.new(); q.t = type; q.pos = p; q.mx = mx; q.size = size; q.vel = vel; q.wind = wind; q.life = life; q.v = randi() % 4
    parts.append(q); return q

func rdir() -> Vector2: return Vector2.from_angle(randf() * TAU)
## A particle of this type still young (under `young` of its life) whose disc covers this point, or null.
## The splash of this kind nearest `p` within `reach` times the larger of the two sizes, no older than `age` seconds.
func _near_part(list: Array, p: Vector2, size: float, reach: float, age: float) -> Part:
    var best: Part = null; var bd := INF
    for q in list:
        if q.life < 0.0 or q.life > age or q.life >= q.mx: continue
        var d: float = q.pos.distance_to(p)
        if d < maxf(q.size, size) * reach and d < bd: bd = d; best = q
    return best
func _young_near(type: int, p: Vector2, size: float, young: float) -> Part:
    for i in range(parts.size() - 1, maxi(-1, parts.size() - 400), -1):   # the newest few hundred: a fall of shot is recent
        var q: Part = parts[i]
        if q.t != type or q.life < 0.0 or q.life > q.mx * young: continue
        if q.pos.distance_to(p) < maxf(q.size, size) * 0.6: return q
    return null

## An explosion. Modern: a white-hot core, rolling fireballs, a shockwave ring, debris streaking out, embers drifting
## downwind and a pool of light on the water and hulls around it. Classic: a soft flash and smoke.
## An aircraft shot down (the owner asked for more than an orange puff, 12 Nov 2026): a flash and a fireball where she
## was hit, pieces and burning fuel flung on along her line of flight, a burst of black smoke; then the wreck falls for
## a few seconds, tumbling, burning and trailing smoke (`falling`, drawn by the battle screen), and goes into the sea
## with a splash and a burning slick. The classic style keeps the old puff.
var falling: Array = []     # {p, v, t, T, a, spin, jet, side}: aircraft going down
func fx_plane_down(p: Vector2, vel: Vector2, jet := false, side := 0) -> void:
    if not modern: part(P.FALL, p, 1.4, 6.0); return
    part(P.CORE, p, 0.16, 6.0); part(P.GLOW, p, 0.9, 30.0)
    for i in 3:
        var fb = part(P.FIREBALL, p + rdir() * 2.0, 0.7 + randf() * 0.5, 4.5 + randf() * 3.0, vel * 0.35 + rdir() * (4.0 + randf() * 8.0)); fb.size *= 1.5
        fb.a = randf() * TAU; fb.spin = (randf() - 0.5) * 3.0; fb.drag = 0.6
    for i in 9:   # the pieces carry on with her speed and spread
        var d = part(P.DEBRIS, p, 0.5 + randf() * 1.0, 0.35 + randf() * 0.45, vel * (0.4 + randf() * 0.5) + rdir() * (15.0 + randf() * 45.0)); d.drag = 0.4
    for i in 5:
        var e = part(P.EMBER, p + rdir() * 3.0, 1.2 + randf() * 1.4, 0.7 + randf() * 0.6, vel * 0.3 + rdir() * (6.0 + randf() * 14.0), true); e.drag = 0.5
    var sm = part(P.SOOT, p, 2.6, 10.5, vel * 0.15, true); sm.a = randf() * TAU
    falling.append({"p": p, "v": vel * 0.55, "t": 0.0, "T": 2.4 + randf() * 1.8, "a": vel.angle(), "spin": (randf() - 0.5) * 5.0, "jet": jet, "side": side, "sm": 0.0})
func _falling(dt: float) -> void:
    for i in range(falling.size() - 1, -1, -1):
        var w: Dictionary = falling[i]
        w.t = float(w.t) + dt; w.p += w.v * dt; w.v *= maxf(0.0, 1.0 - 0.35 * dt); w.a = float(w.a) + float(w.spin) * dt
        w.sm = float(w.sm) - dt
        if float(w.sm) <= 0.0 and modern:   # fire and a ribbon of smoke behind her as she goes down
            w.sm = 0.07
            var q = part(P.SMOKE, w.p, 2.2 + randf(), 2.2 + randf() * 1.2, Vector2.ZERO, true); q.a = randf() * TAU
            part(P.FIRE, w.p, 0.25, 1.6 + randf())
        if float(w.t) >= float(w.T):   # into the sea
            fx_splash(w.p, 7.0); part(P.OIL, w.p, 25.0, 9.0); part(P.FIRE, w.p, 3.5, 3.0); part(P.SMOKE, w.p, 5.0, 5.0, Vector2.ZERO, true)
            falling.remove_at(i)
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
## A shell on an island (owner's request): earth and dust go up whatever she was; high explosive bursts as well;
## incendiary sets the ground alight, with black smoke, for half a minute or so. Each leaves a scar (`scars`).
var scars: Array = []       # {p, r, burn (seconds of fire left), st, v}
func fx_land(p: Vector2, sz: float, ammo: String) -> void:
    scars.append({"p": p, "r": (3.0 + 2.2 * sz) * (1.5 if ammo == "he" else 1.0), "burn": (22.0 + randf() * 22.0) if ammo == "inc" else 0.0, "st": 0.0, "v": randi() % 4})
    if scars.size() > 160: scars.pop_front()
    for i in 3 + int(sz * 1.5):   # the earth thrown up, hanging as dust and drifting
        var q = part(P.DUST, p + rdir() * sz * 1.5, 2.4 + randf() * 1.8, (4.0 + 3.0 * sz) * (0.6 + randf() * 0.6), rdir() * (3.0 + randf() * 7.0), true, -i * 0.04); q.a = randf() * TAU
    if modern:
        for i in 6 + int(sz * 3.0):   # clods and stones flying out
            var c = part(P.DIRT, p, 0.6 + randf() * 0.9, 0.5 + sz * 0.4 * randf(), rdir() * (sz * 16.0 + randf() * sz * 44.0)); c.drag = 0.4; c.wind = false
    match ammo:
        "he":
            fx_boom(p, 6.0 * sz, 0.6)
            for i in 2 + int(sz): var q2 = part(P.DUST, p + rdir() * sz * 3.0, 3.0 + randf() * 2.0, (6.0 + 4.0 * sz) * (0.7 + randf() * 0.5), rdir() * (6.0 + randf() * 10.0), true, -0.1 - i * 0.05); q2.a = randf() * TAU
        "inc":
            for i in 3: part(P.FIRE, p + rdir() * sz * 2.0, 0.9 + randf() * 0.8, 2.5 + sz * 1.5, rdir() * 2.0)
            for i in 2: part(P.SMOKE, p + rdir() * sz * 2.0, 6.0 + randf() * 3.0, 3.0 + sz * 2.0, Vector2.ZERO, true, -i * 0.1)
            if modern: part(P.GLOW, p, 0.8, 30.0 + sz * 18.0)
        _: part(P.SPARK, p, 0.3, 1.5 + sz, rdir() * 60.0)
    sound("hit", p, 0.07 * sz)
## Ground an incendiary set alight goes on burning and smoking.
func _scars_fx(dtv: float) -> void:
    for c in scars:
        if float(c.burn) <= 0.0: continue
        c.burn -= dtv; c.st -= dtv
        if float(c.st) > 0.0: continue
        c.st = 0.28
        part(P.FIRE, c.p + rdir() * float(c.r) * 0.5, 0.7 + randf() * 0.7, float(c.r) * (0.5 + randf() * 0.4), Vector2.ZERO)
        if randf() < 0.6: part(P.SMOKE, c.p + rdir() * float(c.r) * 0.3, 7.0 + randf() * 4.0, float(c.r) * 0.9, Vector2.ZERO, true)

## The new splash (the owner's choice, 12 Nov 2026; Settings.splash, "classic" keeps the look before): a column of water
## that rises in about 1.6 s and stands by its calibre (`col_stand`) before it falls back as a curtain of spray, drawn by
## the battle screen with its height and its shadow on the sea; and a thin lacy slick of foam over paler churned water,
## drifting downwind and fading over 15 to 35 s. `size` is as the classic splash takes it (a shell's is 6 to 20).
static func col_stand(size: float) -> float: return 0.25 * size
## A gun's calibre in millimetres, read from its id (g356 is 356 mm); 0 for anything else.
static func calibre_mm(wid: String) -> int:
    if not wid.begins_with("g"): return 0
    var d := ""
    for ch in wid.substr(1):
        if ch < "0" or ch > "9": break
        d += ch
    return int(d) if d != "" else 0
## How big a shell's splash is. The classic style and guns under 300 mm go by the size class as before; in the new style
## a heavy gun's splash goes by its calibre (the owner's request, 12 Nov 2026): a 14-inch about 18, a 16-inch about 20,
## an 18-inch about 23, the 20-inch about 26, against 20.4 for every heavy gun before.
func shell_splash(sh: Dictionary, sz: float) -> float:
    var mm: int = int(sh.get("mm", 0))
    if modern and splash_new and mm >= 300: return 20.4 * float(mm) / 406.0
    return 6.0 * sz
static func col_life(size: float) -> float: return 1.6 + col_stand(size) + 2.4
## The new splash's columns and slicks, kept apart from the particle list as well (so neither the drawing nor the
## joining of shells has to walk every particle for them: that cost a ten-ship action two milliseconds a frame)
var splash_cols: Array = []
var splash_laces: Array = []
func fx_splash_new(p: Vector2, size: float) -> void:
    # shells falling together, or one spot hit again and again, make one splash, not a stack of them (a stress picture of
    # the new style showed crossed rims and a column that shrank and rose again at every hit, 12 Nov 2026): a shell
    # within a column's width of a young one joins it; a column already up stays up (it does not start rising again)
    # and grows a little; the sea's bowl stays one bowl, kept deep while the hits go on
    var merged: Part = _near_part(splash_cols, p, size, 1.0, 1.6 + col_stand(size) + 0.4)
    if merged != null:
        merged.size = minf(maxf(merged.size, size) * 1.06, maxf(merged.size, size) * 1.5)
        if merged.life > 1.6: merged.life = 1.6   # standing again, from the top of its rise: no shrinking, no jump
        merged.mx = col_life(merged.size)
    else:
        var c := part(P.COLUMN, p, col_life(size), size, Vector2.ZERO, true); c.v = randi() % 4; c.a = randf() * TAU; c.side = randi() % 997; splash_cols.append(c)   # (side: its own seed for the drawing; it drifts with the wind, so its place cannot be one)
    var fl: Part = _near_part(splash_laces, p, size, 2.7, 5.0)   # a salvo's shells, tens of metres apart, sink one stretch of sea
    if fl != null:
        var d: float = fl.pos.distance_to(p)
        fl.pos = fl.pos.lerp(p, 0.35)   # centred among the shells that made it
        fl.size = minf(maxf(fl.size, size) * 1.02 + d * 0.1, maxf(fl.size, size) * 1.25)   # (it grew to swallow the salvo)
        fl.life = minf(fl.life, 2.0)   # the bowl held deep while the shells keep coming; its slick starts when they stop
    else: var l := part(P.LACE, p, 10.0 + size * 1.2, size, Vector2.ZERO, true); l.v = randi() % 3; l.a = randf() * TAU; l.side = randi() % 997; splash_laces.append(l)
    for i in 3 + int(size * 0.25):   # droplets thrown out at the first instant
        var q = part(P.SPRAY, p + rdir() * size * 0.15, 0.6 + randf() * 0.7, size * (0.18 + randf() * 0.16), rdir() * (size * 1.2 + randf() * size * 3.0)); q.drag = 0.18
func fx_splash(p: Vector2, size: float) -> void:
    if modern and splash_new: fx_splash_new(p, size); return
    # shells falling together on one spot make one column, not a stack of them (the owner: "the water columns look weird
    # when multiple shots are fired in the same position"): a splash inside a young column of the same fall swells and
    # renews it instead of drawing another over it, and its foam joins that column's foam
    var merged: Part = _young_near(P.SPLASH, p, size, 0.4)
    if merged != null:
        merged.size = minf(maxf(merged.size, size) * 1.08, maxf(merged.size, size) * 1.6); merged.life = minf(merged.life, merged.mx * 0.12)
    else: part(P.SPLASH, p, 2.0 if modern else 1.8, size)
    if not modern: part(P.FOAM, p, 10.0, size * 1.5)
    if modern:
        # the foam patch and the trough it leaves (shaders/wash.gdshader), on the sea: a shell's splash alongside no longer
        # washes over the ship's decks (the owner found the foam drawn inside the hull); only a torpedo's burst does
        var fw: Part = _young_near(P.WASH, p, size * 1.5, 0.15)
        if fw != null: fw.size = minf(fw.size * 1.05, size * 2.4)
        else: part(P.WASH, p, 9.0 + size * 0.4, size * 1.5)
        for i in 4 + int(size * 0.35):
            var q = part(P.SPRAY, p + rdir() * size * 0.15, 0.7 + randf() * 0.9, size * (0.22 + randf() * 0.2), rdir() * (size * 1.2 + randf() * size * 4.0)); q.drag = 0.18
        part(P.WRING, p, 1.4 + size / 25.0, size * 2.4)

## Is this point on (or within `pad` of) any ship's hull? (Foam belongs on the sea, not on a deck.)
func on_a_hull(p: Vector2, pad := 0.0) -> bool:
    for s in ships:
        if not active(s) or submerged(s): continue
        var l: Vector2 = (p - s.pos).rotated(-s.a)
        if absf(l.x) < s.d.L * 0.5 + pad and absf(l.y) < hull_half(s.d, l.x) + pad: return true
    return false

func fx_muzzle(p: Vector2, ang: float, size: String, barrels: int) -> void:
    var S: float = {"S": 5.5, "M": 9.5, "L": 15.0, "H": 24.0}[size]
    var n: int = {"S": 3, "M": 4, "L": 7, "H": 11}[size] + barrels
    var f = part(P.FLASH, p, 0.26, S * (1 + barrels * 0.12)); f.a = ang
    if modern:
        part(P.GLOW, p + Vector2.from_angle(ang) * S, 0.35, S * 6.0)
        var c = part(P.CORE, p + Vector2.from_angle(ang) * S * 0.4, 0.07, S * 0.9); c.a = ang
    var bl = part(P.BLAST, p, 1.5 if modern else 0.9, S * (3.4 if modern else 3.0)); bl.a = ang
    var fp: Vector2 = p + Vector2.from_angle(ang) * S * 0.6
    if (size == "H" or size == "L") and not on_a_hull(fp, S * 0.8): part(P.FOAM, fp, 2.0, S * 1.1)   # the blast flattens the sea ahead of the muzzle (on open water only: fired across the deck, there is no sea there)
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
## Is a ship of her own side lying where a salvo aimed at `aim` would fall? (Shells hurt friends too: a captain checks
## his fire. The hand-laid guns of the flagship are the player's own affair.)
func friend_near(s: CShip, aim: Vector2, tgt: CShip = null) -> bool:
    for o in ships:
        if o == s or o == tgt or o.side != s.side or not active(o) or submerged(o): continue
        var l: Vector2 = (aim - o.pos).rotated(-o.a)
        if absf(l.x) < o.d.L / 2 + FRIEND_CLEAR and absf(l.y) < o.d.B / 2 + FRIEND_CLEAR: return true
    return false

func fire_gun(s: CShip, m: Mount, aim: Vector2, w: Dictionary, tgt: CShip = null) -> void:
    var n := int(w.get("barrels", 1))
    var order := 0   # this turret's place, bow to stern, among the ship's guns of its calibre
    for o in s.mounts:
        if o == m: break
        if o.w.kind == "gun" and o.w.size == w.size: order += 1
    var t0: float = order * TURRET_STEP[w.size]
    if n == 1: m.queue.append({"i": 0, "t": t0, "aim": aim, "tgt": tgt})
    else:
        m.half = 1 - m.half
        var first := []; var second := []
        for i in n: (first if i % 2 == m.half else second).append(i)
        for k in first.size(): m.queue.append({"i": first[k], "t": t0 + k * COIL, "aim": aim, "tgt": tgt})
        for k in second.size(): m.queue.append({"i": second[k], "t": t0 + float(w.rel) * 0.5 + k * COIL, "aim": aim, "tgt": tgt})
    if m.queue.size() > n * 2: m.queue = m.queue.slice(m.queue.size() - n)
    _ripple(s, m, 0.0)

func _ripple(s: CShip, m: Mount, dt: float) -> void:
    for j in range(m.queue.size() - 1, -1, -1):
        var q: Dictionary = m.queue[j]; q.t -= dt
        if q.t <= 0.0: m.queue.remove_at(j); fire_barrel(s, m, q.aim, int(q.i), q.get("tgt"))

# ------------------------------------------------------------------ finding the range
## Gunnery by salvos, as it was done (owner's list: "gunnery that finds the range over several salvos"). A ship
## opening fire on a target has only an estimate of her range and of how far to lay off for her movement: the whole
## salvo falls together, short or over, left or right, by that error (`r` a share of the range, `a` an angle). Each
## salvo whose fall is spotted takes most of the error off; a target that turns, or a firing ship that turns, puts
## some back. Radar ranges well from the first; by night without it, or through smoke, spotting is poor. Once the
## error is inside the spread of the salvo she is straddling, and hits come by the pattern's share of the target.
## Fire laid by hand on a point of the sea (no target) has no solution: it scatters as it always did.
const SOL_STALE := 35.0
const FRIEND_CLEAR := 45.0   # a captain holds a salvo that would fall this near a friend's hull (m)
const PATTERN := 0.45      # how tight a salvo is round its own centre, against the old scatter of single shells
func solution(s: CShip, tg: CShip, rel_range: float, fc: float, spread: float) -> Dictionary:
    var k: int = tg.get_instance_id()
    if s.sol.has(k) and t - float(s.sol[k].t) < SOL_STALE: return s.sol[k]
    # a first estimate: worse the further off she is, better with radar and a good director (fc), worst with a green crew
    var q: float = fc * CREW[s.cq].gun * (0.45 + 0.55 * rel_range)
    var so := {"r": (randf() * 2.0 - 1.0) * 0.085 * q, "a": (randf() * 2.0 - 1.0) * spread * 1.6, "n": 0, "t": t, "next": 0.0}
    if s.sol.size() > 6: s.sol.clear()
    s.sol[k] = so; return so
## A salvo's fall has been seen: correct. Called as shells land, but counted once a salvo.
func spot(s: CShip, tg: CShip, reload: float) -> void:
    if s == null or tg == null or not s.alive: return
    var so = s.sol.get(tg.get_instance_id())
    if so == null or t < float(so.next): return
    so.next = t + reload * 0.6; so.n = int(so.n) + 1; so.t = t
    var keep := 0.5                                             # of the error left after one good spotting
    if has_radar(s): keep = 0.36
    elif wx.get("night", false) and not star_lit(tg.pos): keep = 0.78
    if not eye_sees(tg, s.side): keep = maxf(keep, 0.7 if has_radar(s) else 0.92)   # behind smoke or beyond sight: the plot alone
    if spotter_over(s.side, tg.pos): keep *= SPOT_HELP   # her floatplane is over the target, calling the fall of shot
    if s.tech.has("netcentric"): keep *= 0.8 - 0.05 * tech_up(s.tech, "netcentric")   # cooperative engagement (Era IV): the squadron's picture, whoever spots
    keep = clampf(keep * CREW[s.cq].spot, 0.2, 0.95)
    so.r = float(so.r) * keep; so.a = float(so.a) * keep
    # the target's helm and ours spoil the reckoning a little each time
    var stir: float = absf(tg.w) * 0.5 + absf(s.w) * 0.3
    so.r = float(so.r) + (randf() * 2.0 - 1.0) * (0.004 + stir); so.a = float(so.a) + (randf() * 2.0 - 1.0) * (0.001 + stir * 0.25)
## "" (no solution), "ranging" or "straddling": for the gun-laying readout.
func sol_state(s: CShip, tg: CShip) -> String:
    if s == null or tg == null: return ""
    var so = s.sol.get(tg.get_instance_id())
    if so == null or t - float(so.t) > SOL_STALE: return ""
    return "straddling" if absf(float(so.r)) < 0.012 and int(so.n) > 0 else "ranging"
## Crews (owner's list: "crew quality"): what a ship's company is worth at her guns, at spotting, at the loading
## trays and in damage control, by how much action it has seen.
const CREW := [
    {"name": "green", "gun": 1.3, "spot": 1.15, "rel": 0.92, "dc": 0.8},
    {"name": "trained", "gun": 1.0, "spot": 1.0, "rel": 1.0, "dc": 1.0},
    {"name": "seasoned", "gun": 0.9, "spot": 0.92, "rel": 1.04, "dc": 1.12},
    {"name": "veteran", "gun": 0.8, "spot": 0.85, "rel": 1.08, "dc": 1.25},
    {"name": "crack", "gun": 0.72, "spot": 0.8, "rel": 1.12, "dc": 1.4},
]
## Battles a crew has fought, to its quality.
static func crew_level(xp: float) -> int: return 0 if xp < 1.0 else (1 if xp < 3.0 else (2 if xp < 6.0 else (3 if xp < 10.0 else 4)))

func fire_barrel(s: CShip, m: Mount, aim: Vector2, i: int, tgt: CShip = null) -> void:
    if not use_round(m): return
    var w: Dictionary = m.w; var n := int(w.get("barrels", 1))
    var ang = s.a + m.ta; var off: float = (i - (n - 1) / 2.0) * float(w.get("gap", 0.0))
    var p = world_pt(s, m.slot.x, m.slot.y) + Vector2.from_angle(ang + PI / 2) * off
    var rng: float = gun_range(s, w); var d = minf(rng, p.distance_to(aim))
    var fc = (0.6 - 0.05 * tech_up(s.tech, "radar") if s.tech.has("radar") else 1.0) * (1 - 0.12 * s.sk.gun) * (1 - 0.12 * upg(s, "fc")) * (1.0 + (s.ld_spread - 1.0) * (1.0 + 0.5 * int(wx.sea))) * (1.0 + 0.7 * absf(s.list)) * (1.15 if s.side == 1 else 1.0) * (0.85 - 0.05 * tech_up(s.tech, "datalink") if s.tech.has("datalink") else 1.0)
    fc *= 1.0 + 0.1 * int(wx.sea)                                         # a moving platform
    if s.rec.get("defects", []).has("fc"): fc *= 1.15                     # a raised wreck's fire control, never quite true again
    if wx.night and not has_radar(s): fc *= 1.35                           # spotting the fall of shot by eye in the dark
    s.lit_t = 0.0
    var spread: float = w.spread * fc / maxf(0.3, s.fc) * CREW[s.cq].gun
    var a: float; var dd: float
    if tgt != null and tgt.alive:   # a salvo on a target: the solution's error, shared by every shell, and a tight pattern round it
        var so := solution(s, tgt, clampf(d / rng, 0.0, 1.0), fc / maxf(0.3, s.fc), spread)
        a = ang + float(so.a) + (randf() - 0.5) * 2 * spread * PATTERN
        dd = maxf(60.0, d * (1 + float(so.r) + (randf() - 0.5) * 0.06 * fc * PATTERN))
    else:
        a = ang + (randf() - 0.5) * 2 * spread
        dd = maxf(60.0, d * (1 + (randf() - 0.5) * 0.06 * fc))
    # penetration in mm of armour, from the shell's weight, falling off with range; fall: how steeply it comes down
    var pen: float = float(w.dmg) * 1.9 * (1.0 - 0.45 * clampf(dd / rng, 0.0, 1.0))
    var kind := shell_for(s, aim, pen)
    s.last_shell = kind
    pen *= SHELLS[kind].pen
    shells.append({"s": p, "e": p + Vector2.from_angle(a) * dd, "pos": p, "t": 0.0, "T": dd / w.speed, "dmg": w.dmg, "side": s.side, "size": w.size, "pen": pen, "fall": clampf(dd / rng, 0.0, 1.0), "who": s, "ammo": kind, "tgt": tgt, "rel": float(w.rel), "mm": calibre_mm(m.wid)})
    if m.rec.size() != n: m.rec.resize(n)
    m.rec[i] = 1.0; m.recoil = 1.0
    fx_muzzle(p + Vector2.from_angle(ang) * (w.tl * 0.42 + w.bl), ang, w.size, 1)
    sound("gun_" + w.size, p, {"S": 0.2, "M": 0.3, "L": 0.45, "H": 0.75}[w.size])

func fire_torps(s: CShip, m: Mount, aim: Vector2) -> void:
    if not use_round(m): return
    var w = m.w; var p = world_pt(s, m.slot.x, m.slot.y); var base = (aim - p).angle()
    var en: float = maxf(150.0, p.distance_to(aim) - HOMER_SHORT) / w.speed   # a homer's seeker comes on short of the aim point
    for i in int(w.count):
        var a: float = base + (i - (w.count - 1) / 2.0) * 0.06
        torps.append({"pos": p, "a": a, "speed": w.speed, "life": gun_range(s, w) / w.speed, "dmg": w.dmg, "side": s.side, "homing": w.get("homing", false), "arm": 150.0 / w.speed, "en": en, "who": s, "ear": homer_ear(s)})
    boom(p, 0.1, 900.0)
    if s.sub: s.reveal_t = 20.0

func fire_missile(s: CShip, m: Mount, tg: CShip) -> void:
    if not use_round(m): return
    var w = m.w; var p = world_pt(s, m.slot.x, m.slot.y)
    for i in int(w.count) + (1 + (1 if tech_lv(s.tech, "vls") >= 2 else 0) if s.tech.has("vls") else 0):   # vertical launch: one more round in each salvo
        missiles.append({"pos": p, "a": s.a + (randf() - 0.5) * 0.6, "v": 80.0, "speed": w.speed, "life": gun_range(s, w) / w.speed * 1.4, "dmg": w.dmg, "side": s.side, "target": tg, "kind": "ssm", "delay": i * 2.0})
    if s.sub: s.reveal_t = 25.0

func fire_sam(s: CShip, m: Mount, tg) -> void:
    if not use_round(m): return
    var p = world_pt(s, m.slot.x, m.slot.y); var tp: Vector2 = tg.pos
    missiles.append({"pos": p, "a": (tp - p).angle(), "v": 200.0, "speed": m.w.speed, "life": gun_range(s, m.w) / m.w.speed * 1.5, "dmg": 0, "side": s.side, "target": tg, "kind": "sam", "p": m.w.pd, "delay": 0.0})

func reload_mult(s: CShip, w: Dictionary) -> float:
    var r = (0.5 + 0.5 * s.cf) * CREW[s.cq].rel
    if w.kind == "gun": r *= (1 + 0.08 * s.sk.gun) * (1 + 0.06 * upg(s, "turret"))
    if w.kind == "torp" or w.kind == "ssm": r *= 1 + 0.12 * s.sk.ord
    return r

func nearest_air(side: int, p: Vector2, rng: float):
    var best = null; var bd = rng
    for q in air:
        if q.side == side or q.up <= 0: continue   # machines on the deck are not in the sky to be shot at
        var dd: float = p.distance_to(q.pos)
        if dd < bd: bd = dd; best = q
    for q in spotters:   # a floatplane over the action is fair game too
        if q.side == side or int(q.n) <= 0: continue
        var dd: float = p.distance_to(q.pos)
        if dd < bd: bd = dd; best = q
    return best

# ------------------------------------------------------------------ floatplanes
## A cruiser's or a battleship's floatplanes (the owner: the planes painted on their catapults could not be used). One
## a catapult, drawn on the rail as the carriers' piston aircraft are drawn (PlaneArt). Flown off by day in fair
## weather (F for yours; other captains do it themselves once the enemy is in sight), she goes out over the enemy and
## circles there: her ship's salvos fall where she can see them (spotting takes more of the error off, SPOT_HELP), and
## her side sees what lies within SPOT_SEE of her, over smoke as well. Anti-aircraft fire can bring her down; at the
## end of her endurance she comes home and is hoisted in. A ship lost with her plane aloft loses it.
const SPOT_SEE := 4000.0     # how far a floatplane's observer sees ships on the sea about her (m)
const SPOT_HELP := 0.6       # the error left after a spotted salvo is multiplied by this when she is over the target
const SPOT_ENDURE := 900.0   # battle seconds aloft before she must come home
const SPOT_V := 55.0         # her speed, m/s
const SPOT_ORBIT := 2500.0   # how far off the target she circles (outside the light flak, inside the heavy)
var spotters: Array = []
func cats_of(s: CShip) -> Array: return s.d.get("p", {}).get("cat", [])
## Drones (Era IV, "Unmanned aircraft"): every warship of destroyer size and more without a catapult carries one; it
## flies by night and in fog as well as by day (not in a storm), and longer than a floatplane.
static func drone_ship(d: Dictionary, tech: Array) -> bool: return tech.has("drones") and d.kind == "war" and float(d.t) >= 2000.0 and d.get("p", {}).get("cat", []).is_empty()
func spot_cap(s: CShip) -> int: return 1 if drone_ship(s.d, s.tech) else cats_of(s).size()
## Why she cannot fly a floatplane off now, or "".
func spotter_why(s: CShip) -> String:
    var drone: bool = drone_ship(s.d, s.tech)
    if spot_cap(s) == 0: return "This ship carries no aircraft."
    if s.fp <= 0: return "Her drone is away." if drone else "Her floatplanes are all away."
    if int(wx.sea) >= 3 or (not drone and (wx.fog or wx.night)): return "Her floatplane cannot fly: " + ("the sea is too rough." if int(wx.sea) >= 3 else ("fog." if wx.fog else "it is night."))
    if not s.alive or s.struck or s.eng_out > 0 and s.v < 1.0: return "She cannot launch now."
    return ""
func launch_spotter(s: CShip) -> bool:
    if spotter_why(s) != "": return false
    var drone: bool = drone_ship(s.d, s.tech)
    var c: Array = [-float(s.d.L) * 0.42, 0.0] if drone else cats_of(s)[maxi(0, s.fp - 1)]; var cy: float = float(c[1])
    var a: float = s.a + signf(cy) * 0.32 if cy != 0.0 else s.a + PI / 2 * (1.0 if randf() < 0.5 else -1.0)   # along her catapult (a centreline one trained to the beam)
    s.fp -= 1
    spotters.append({"ship": s, "side": s.side, "pos": world_pt(s, float(c[0]), cy), "a": a, "v": SPOT_V * 0.6, "t": 0.0, "home": false, "n": 1, "up": 1, "jet": false, "alt": 30.0, "ph": randf() * TAU, "drone": drone, "du": tech_up(s.tech, "drones") if drone else 0})
    boom(world_pt(s, float(c[0]), cy), 0.05, 700.0)
    if s.side == 0: say("The %s flies off her %s to spot for her guns." % [s.rec.name, "drone" if drone else "floatplane"], 1.8)
    return true
## Is a floatplane of this side over (within SPOT_SEE of) this point, in light she can see by?
func spotter_over(side: int, p: Vector2) -> bool:
    for q in spotters:
        if q.side != side or int(q.n) <= 0 or q.home or ((wx.night or wx.fog) and not q.get("drone", false)): continue   # a drone sees by night too
        if p.distance_to(q.pos) < SPOT_SEE: return true
    return false
func _spotters(dt: float) -> void:
    for s in ships:   # captains fly theirs off once the enemy is in sight (the flagship's is the player's to fly)
        if s.fp <= 0 or (s.side == 0 and s == flag) or s.ai_off: continue
        s.fp_t -= dt
        if s.fp_t > 0.0: continue
        s.fp_t = 30.0
        if spotters.any(func(q): return q.ship == s): continue   # one aloft at a time
        if nearest_enemy(s.pos, s.side, 25000.0, func(x: CShip) -> bool: return not submerged(x)) != null: launch_spotter(s)
    for i in range(spotters.size() - 1, -1, -1):
        var q: Dictionary = spotters[i]; var sh: CShip = q.ship
        if int(q.n) <= 0:   # shot down
            fx_plane_down(q.pos, Vector2.from_angle(float(q.a)) * float(q.get("v", 40.0)), false, int(q.side)); spotters.remove_at(i)
            if q.side == 0: say("A floatplane of ours is shot down.", 1.5)
            continue
        q.t = float(q.t) + dt; q.alt = minf(150.0, float(q.alt) + dt * 6.0); q.v = minf(SPOT_V, float(q.v) + dt * 4.0)
        if float(q.t) > SPOT_ENDURE * (2.0 + 0.5 * float(q.get("du", 0)) if q.get("drone", false) else 1.0) or not sh.alive or ((wx.night or wx.fog) and not q.get("drone", false)): q.home = true
        var goal: Vector2
        if q.home:
            if not sh.alive: goal = q.pos + Vector2.from_angle(q.a) * 500.0   # her ship is gone: she flies on until her fuel is out
            else: goal = sh.pos
            if sh.alive and q.pos.distance_to(sh.pos) < 160.0: sh.fp += 1; spotters.remove_at(i); continue   # landed alongside and hoisted in
            if not sh.alive and float(q.t) > SPOT_ENDURE * 1.4: spotters.remove_at(i); continue
        else:
            var tg: CShip = nearest_enemy(sh.pos if sh.alive else q.pos, q.side, INF, func(x: CShip) -> bool: return not submerged(x))
            if tg == null: tg = nearest_any(q.pos, q.side)
            if tg == null: q.home = true; goal = sh.pos
            else: goal = tg.pos + Vector2.from_angle(float(q.t) * SPOT_V / SPOT_ORBIT + float(q.ph)) * SPOT_ORBIT
        q.a = float(q.a) + clampf(ang_diff((goal - q.pos).angle(), float(q.a)), -0.35 * dt, 0.35 * dt)
        q.pos += Vector2.from_angle(float(q.a)) * float(q.v) * dt

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
    if randf() < chance * (0.6 if sq.jet else 1.0) * (1.35 + 0.1 * tech_up(s.tech, "aa_prox") if s.tech.has("aa_prox") else 1.0):   # proximity fuzes
        sq.n = maxi(0, int(sq.n) - 1); fx_plane_down(sq.pos + Vector2(randf() - 0.5, randf() - 0.5) * 30.0, Vector2.from_angle(float(sq.get("a", 0.0))) * (220.0 if sq.jet else 75.0) * 0.6, bool(sq.jet), int(sq.side))

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
                    if s.force_tgt != null and engageable(s.force_tgt):   # (editor) set on one ship, whatever her flag
                        m.tgt = s.force_tgt if (p.distance_to(s.force_tgt.pos) < rng and mount_arc(m, ang_diff((s.force_tgt.pos - p).angle(), s.a)).x > 0) else null; m.tgt_t = 1.0
                    elif m.tgt_t <= 0 or m.tgt == null or not engageable(m.tgt) or submerged(m.tgt) or not visible_to(m.tgt, s.side):   # (a gun cannot reach a dived boat: she is the depth charges' business)
                        m.tgt_t = 3.0; m.tgt = null
                        var pri: CShip = null
                        if s.target != null and engageable(s.target) and not submerged(s.target) and visible_to(s.target, s.side) and p.distance_to(s.target.pos) < rng and mount_arc(m, ang_diff((s.target.pos - p).angle(), s.a)).x > 0: pri = s.target
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
                    elif not m.air.is_empty() and m.air.up > 0: aim = m.air.pos; aim_air = m.air
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
                if holding(s) and not manual and aim_air == null: trigger = false   # holding fire (the AA guns still defend the ship)
                if trigger and not manual and aim_air == null and friend_near(s, aim, m.tgt): trigger = false   # a friend lies where the salvo would fall: check fire
                if manual:
                    m.st = "arc" if ac.x == 0 else "range" if not in_range else "train" if not aligned else "reload" if m.cd > 0 else "ready"
                    m.err = absf(ang_diff(want, m.ta)); gun_aim = {"pos": aim, "lock": aim_lock}
                if aligned and in_range and trigger and m.cd <= 0:
                    m.cd = w.rel
                    if aim_air != null: flak(s, m, aim_air, w.aa * 1.2)
                    else: fire_gun(s, m, aim, w, (lock if aim_lock else null) if manual else m.tgt)
            "aa":
                if sm or m.cd > 0: continue
                var done = false
                var ms = nearest_missile(s.side, p, w.range)
                if ms != null:
                    m.ta = ang_diff((ms.pos - p).angle(), s.a); m.cd = w.rel; aa_shot(s, m, p, ms.pos)
                    if randf() < w.pd * (1.0 + 0.1 * tech_up(s.tech, "ciws") if m.wid == "ciws" else 1.0): kill_missile(ms)
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
                if holding(s): continue   # holding fire: no torpedoes from the rest of the squadron
                # straight-running torpedoes pass over a submerged boat; acoustic homers can go after one that is held on sonar
                var homer: bool = w.get("homing", false)
                var ok_t = func(x: CShip) -> bool: return not submerged(x) or homer
                var reach_k: float = temper_k(s, 0.9, 0.75, 0.6)   # how far off her captain will fire (a bold one sooner, a cautious one only close in)
                var tg: CShip = s.target if (s.target != null and engageable(s.target) and visible_to(s.target, s.side) and ok_t.call(s.target)) else nearest_enemy(s.pos, s.side, rng * reach_k, ok_t)
                if tg == null or p.distance_to(tg.pos) > rng * reach_k: continue
                var lp = lead_point(p, tg, w.speed); var want = ang_diff((lp - p).angle(), s.a)
                var ac = arc_check(m.slot, want)
                if ac.x == 0: m.ta += ang_diff(ac.y, m.ta) * minf(1.0, dt * 2); continue
                if s.foul_by != null and t - s.foul_at < 1.0: continue   # held for a friend a moment ago: look again shortly
                var fo: CShip = torp_fouls(s, p, lp, w, tg) if ff_care else null
                if fo != null:   # a friend lies in the track or will cross it: hold the torpedoes
                    if s.foul_by == null or t - s.foul_at > 3.0: s.foul_since = t; _log("torpedoes held for a friend")
                    s.foul_by = fo; s.foul_at = t; continue
                s.foul_by = null; s.foul_said = false
                m.ta = want; m.cd = w.rel; fire_torps(s, m, lp); s.torp_run_t = 60.0
            "ssm":
                if m.cd > 0: continue
                var rng = gun_range(s, w)
                if is_player:
                    if not want_msl: continue
                    var tg: CShip = lock if (lock != null and engageable(lock) and visible_to(lock, 0) and not submerged(lock)) else nearest_enemy(mouse_world, 0, 3000.0, func(x: CShip) -> bool: return not submerged(x))
                    if tg == null or p.distance_to(tg.pos) > rng: continue
                    m.cd = w.rel; fire_missile(s, m, tg); continue
                if holding(s): continue
                var tg2: CShip = s.target if (s.target != null and engageable(s.target) and visible_to(s.target, s.side) and not submerged(s.target)) else nearest_enemy(s.pos, s.side, rng, func(x: CShip) -> bool: return not submerged(x))
                if tg2 != null and p.distance_to(tg2.pos) < rng: m.cd = w.rel * (0.8 + randf() * 0.5); fire_missile(s, m, tg2)
    if s.d.get("sonar", false) and not s.sub:
        s.dc_t -= dt
        if s.dc_t <= 0:
            # a boat she holds on sonar, where a pattern dropped now would come down on her (it used to be any boat within 260 m)
            var sb = nearest_enemy(s.pos, s.side, 700.0, func(o: CShip) -> bool: return o.sub and submerged(o) and detected_by(o, s.side))
            if sb != null and dc_on(s, sb):
                if not ff_care or dc_fouls(s) == null: drop_dcs(s)   # never where a friend (or she herself) would be hurt
                else:
                    if t - s.dc_held_at > 10.0: _log("pattern held for a friend")
                    s.dc_held_at = t

## A pattern of depth charges rolled and thrown off the stern; they sink and burst a few seconds later.
## Depth charges (reworked 11 Nov 2026 at the owner's word: she dropped whenever a boat was anywhere within 260 m, and the
## charges burst close under her stern). A pattern is six charges: four rolled off the stern rails one after another
## as she runs on, so they lie along her track, and one thrown out on each quarter. Each sinks for DC_SINK battle seconds
## before it bursts, by which time she is a hundred metres and more beyond it. So she must drop *ahead of time*: for
## where the boat will be when the charges reach her depth, not where she is now.
const DC_ROLL := 1.1      # battle seconds between one charge off the rails and the next
const DC_SINK := 6.0      # battle seconds a charge sinks before it bursts
const DC_THROW := 42.0    # how far a thrower puts its charge out on the quarter, metres
const DC_HIT := 60.0      # a burst this near a boat hurts her
const DC_CLOSE := 18.0    # and this near does its worst
## Where the middle of a pattern dropped now would lie, and when it would burst (seconds from now).
func dc_pattern(s: CShip) -> Array:
    var mid_t: float = DC_ROLL * 1.5
    return [world_pt(s, -s.d.L / 2, 0) + Vector2.from_angle(s.a) * s.v * mid_t, mid_t + DC_SINK]
## Where a boat will be that many seconds on, if she holds her course and speed.
func dc_lead(sb: CShip, secs: float) -> Vector2: return sb.pos + Vector2.from_angle(sb.a) * sb.v * secs
## Would a pattern dropped now fall on this boat? (The captain's judgement: within the pattern's own spread.)
func dc_on(s: CShip, sb: CShip) -> bool:
    var pt: Array = dc_pattern(s)
    return dc_lead(sb, float(pt[1])).distance_to(pt[0]) < 55.0
func drop_dcs(s: CShip) -> bool:
    if s.dc_left <= 0 or s.dc_t > 0.0: return false   # none left, or the racks still reloading
    s.dc_left -= 1; s.dc_t = 25.0
    for i in 4: dcs.append({"ship": s, "rel": i * DC_ROLL, "lat": (randf() - 0.5) * 8.0, "side": s.side, "t": -1.0})   # off the rails, one by one
    for sd in [-1.0, 1.0]: dcs.append({"ship": s, "rel": DC_ROLL * 1.5, "lat": sd * DC_THROW, "side": s.side, "t": -1.0})   # the throwers
    if s.side == 0 and s == flag: say("Depth charges away · %d patterns left." % s.dc_left, 1.5)
    return true

## Torpedoes and depth charges hurt friends too (the owner's word, 11 Nov 2026), as shells and rams already did. A
## torpedo strikes the first hull in her path whatever its flag (a straight runner passes under a dived boat, and never
## turns back on the ship that fired her); a burst hurts every boat within DC_HIT and every hull within DC_SHIP of it,
## the dropper's own included. So a captain looks before he fires or drops (torp_fouls, dc_fouls), and the player is
## warned and must press again (FF_CONFIRM). Homing torpedoes run straight for an enabling run set to bring them up short
## of the target (HOMER_SHORT), then hear for the nearest ship in their cone, whatever her flag: a seeker cannot tell a
## friend's screws from an enemy's, so she is fired only where no friend will be nearer to her than the target is.
const TORP_CLEAR := 60.0     # a captain holds his torpedoes if a friend's hull would come this near one of them (m)
const HOMER_EAR := 1200.0    # how far a homing torpedo's seeker hears a ship ahead of her (m)
## Her seeker's reach with the firer's homing research: a seventh farther for each level past the first.
func homer_ear(s: CShip) -> float: return HOMER_EAR * (1.0 + 0.15 * (tech_up(s.tech, "homing") if s != null else 0))
const HOMER_CONE := 0.7      # and how wide its cone is either side of her heading (radians)
const HOMER_SHORT := 700.0   # her seeker is switched on this far short of the point she was aimed at (m)
const DC_SHIP := 30.0        # a burst this near a surface ship's hull hurts her (shock under the keel)
const DC_SHIP_DMG := 110.0   # and this is the worst it does, hard under her
const DC_MARGIN := 15.0      # a captain keeps his friends this much farther than that from a pattern
const TORP_GIVEUP := 40.0    # a ship sent on a torpedo attack gives it up after holding this long for a friend in the track
const FF_CONFIRM := 4.0      # battle seconds the player has to press again to fire or drop over a warning

## How far a point lies from a ship's hull (0 inside it), she being at `at` on her heading.
func hull_dist(o: CShip, at: Vector2, pt: Vector2) -> float:
    var h: float = maxf(0.0, o.d.L * 0.5 - o.d.B * 0.5); var u := Vector2.from_angle(o.a)
    var a := at - u * h; var b := at + u * h; var ab := b - a
    var k: float = clampf((pt - a).dot(ab) / maxf(0.0001, ab.dot(ab)), 0.0, 1.0)
    return maxf(0.0, pt.distance_to(a + ab * k) - o.d.B * 0.5)

## Would torpedoes fired now from `p` at `aim` run into one of the firer's own side? Each friend is carried on along her
## course and speed while the spread runs out its whole length; the spread is a fan whose width grows with the run. A
## homer is also tested, once her seeker is on, for a friend she would hear before the target. Returns the friend, or null.
func torp_fouls(s: CShip, p: Vector2, aim: Vector2, w: Dictionary, tgt: CShip = null) -> CShip:
    var speed: float = float(w.speed); var homer: bool = w.get("homing", false)
    var run: float = gun_range(s, w) if s != null and w.has("range") else float(w.get("run", 2000.0))
    var dir := (aim - p).normalized(); var half_fan: float = (int(w.get("count", 1)) - 1) / 2.0 * 0.06 + 0.02
    var en: float = maxf(150.0, p.distance_to(aim) - HOMER_SHORT)
    var side: int = s.side if s != null else int(w.get("side", 0))
    var step := 30.0
    for o in ships:
        if o == s or o == tgt or o.side != side or not active(o): continue
        if submerged(o) and not homer: continue   # a straight runner passes over a dived boat
        var ov: Vector2 = Vector2.from_angle(o.a) * o.v
        if o.pos.distance_to(p) > run + o.v * run / speed + o.d.L + (homer_ear(s) if homer else 0.0): continue
        var dd := 0.0
        while dd <= run:
            var tt: float = dd / speed; var tp: Vector2 = p + dir * dd; var op: Vector2 = o.pos + ov * tt
            if hull_dist(o, op, tp) < TORP_CLEAR + dd * half_fan: return o
            if homer and dd >= en:
                var rel := op - tp
                if rel.length() < homer_ear(s) and absf(ang_diff(rel.angle(), dir.angle())) < HOMER_CONE:
                    var tg_d: float = (tgt.pos + Vector2.from_angle(tgt.a) * tgt.v * tt).distance_to(tp) if tgt != null else INF
                    if rel.length() < tg_d: return o
            dd += step
    return null

## Where each charge of a pattern dropped now would burst, and when (seconds from now): [[pos, t], ...], she holding on.
func dc_bursts(s: CShip) -> Array:
    var u := Vector2.from_angle(s.a); var st: Vector2 = world_pt(s, -s.d.L / 2, 0); var out := []
    for i in 4: out.append([st + u * s.v * i * DC_ROLL, i * DC_ROLL + DC_SINK])
    for sd in [-1.0, 1.0]: out.append([st + u * s.v * DC_ROLL * 1.5 + u.orthogonal() * sd * DC_THROW, DC_ROLL * 1.5 + DC_SINK])
    return out
## Would a pattern dropped now hurt a ship of her own side, or herself? Returns the ship, or null.
func dc_fouls(s: CShip) -> CShip:
    var bursts := dc_bursts(s)
    for o in ships:
        if o.side != s.side or not active(o): continue
        if o.pos.distance_to(s.pos) > s.d.L + 600.0: continue
        var ov: Vector2 = Vector2.from_angle(o.a) * o.v
        for b in bursts:
            var op: Vector2 = o.pos + ov * float(b[1])
            if (op.distance_to(b[0]) < DC_HIT + DC_MARGIN) if o.sub else (hull_dist(o, op, b[0]) < DC_SHIP + DC_MARGIN): return o
    return null
## Damage a burst does to a ship or boat: boats within DC_HIT (the full blow inside DC_CLOSE), hulls within DC_SHIP.
func dc_harm(o: CShip, burst: Vector2) -> float:
    if o.sub:
        var bd: float = o.pos.distance_to(burst)
        return 160.0 * clampf((DC_HIT - bd) / (DC_HIT - DC_CLOSE), 0.15, 1.0) if bd < DC_HIT else 0.0
    var hd: float = hull_dist(o, o.pos, burst)
    return DC_SHIP_DMG * clampf(1.0 - hd / DC_SHIP, 0.15, 1.0) if hd < DC_SHIP else 0.0

## The player's flagship: the friend her loaded tubes would endanger fired at the cursor now, or null.
func player_torp_foul() -> CShip:
    var s := flag
    if s == null or not s.alive: return null
    for m in s.mounts:
        if m.w.kind != "torp" or m.dead or m.ammo == 0 or m.cd > 0: continue
        if not arc_check(m.slot, ang_diff((mouse_world - s.pos).angle(), s.a)).x > 0: continue
        return torp_fouls(s, world_pt(s, m.slot.x, m.slot.y), mouse_world, m.w, null)
    return null
## A warning for the player before he fires or drops with a friend in danger: "" if none; else what to say. The first
## press only warns; a second press of the same key within FF_CONFIRM goes ahead.
func ff_warning(kind: String) -> String:
    var f: CShip = player_torp_foul() if kind == "torp" else (dc_fouls(flag) if flag != null and flag.alive else null)
    if f == null: return ""
    if kind == "torp": return "Check fire: the %s lies in the torpedo track. T again to fire." % f.rec.name
    if f == flag: return "Too slow to clear her own charges: they would burst under her. Z again to drop."
    return "Check fire: the %s is within the burst of a pattern. Z again to drop." % f.rec.name
func ff_confirm(kind: String) -> bool:   # true: go ahead (no danger, or the player has been warned and pressed again)
    var wn := ff_warning(kind)
    if wn == "": return true
    if ff_ok.get("kind", "") == kind and t - float(ff_ok.get("t", -99.0)) < FF_CONFIRM: ff_ok = {}; return true
    ff_ok = {"kind": kind, "t": t}; say(wn, FF_CONFIRM); return false

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
    if not s.alive or s.god: return
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
    if s.side == 1 and not s.flee and s.hull / s.max_hull < temper_k(s, 0.1, 0.25, 0.45) and randf() < temper_k(s, 0.2, 0.3, 0.5): s.flee = true   # a bold captain fights on, a cautious one breaks off early
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
    # the flight deck: a bomb or a shell through it stops all flying until it is patched
    if s.d.kind == "carrier" and kind != "torp" and absf(l.x) < L * 0.46 and randf() < (0.5 if kind == "bomb" else 0.22 * heavy):
        if s.deck_out <= 0.0:
            _log("flight deck out")
            say(("The %s's flight deck is holed: no aircraft can take off or land until it is patched." if ours else "The %s's flight deck is torn open.") % nm, 3.0)
        s.deck_out = minf(240.0, s.deck_out + (50.0 + randf() * 70.0) * maxf(0.6, heavy))
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
    s.blown = true
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
## Where the damage-control parties go first (the flagship's to choose; other ships work evenly): the chosen work
## goes twice as fast and the rest at six tenths.
const DC_PRI := {"": "evenly", "fire": "fires first", "flood": "flooding first", "mach": "machinery and steering first"}
func dc_k(s: CShip, what: String) -> float: return 1.0 if s.dc_pri == "" else (2.0 if s.dc_pri == what else 0.6)
## Flood the burning magazine now: the turret above it is lost, the ship is not.
func flood_magazine(s: CShip) -> bool:
    if s.mag_fire <= 0: return false
    s.mag_fire = 0.0; _log("magazine flooded"); s.flooded.append(s.mag_x)
    for m in s.mounts: if m.w.kind == "gun" and m.slot.y == 0 and absf(m.slot.x - s.mag_x) < m.w.tl * 0.6 + 2.0: m.dead = true
    return true
## Counter-flood: let the sea into the high side to bring her upright at once. She fights level again, but the water
## stays aboard and she is slower for it for the rest of the action.
func counter_flood(s: CShip) -> bool:
    if absf(s.list) < 0.15: return false
    s.ballast = minf(0.5, s.ballast + absf(s.list) * 0.35); s.list *= 0.25; _log("counter-flooded")
    return true
func systems_tick(s: CShip, dt: float) -> void:
    var dc: float = (1.0 + 0.3 * s.sk.dc) * (1.3 + 0.1 * tech_up(s.tech, "dc") if s.tech.has("dc") else 1.0) * CREW[s.cq].dc   # damage control schools, and the crew's own worth
    if s.deck_out > 0.0:
        s.deck_out = maxf(0.0, s.deck_out - dt * dc * dc_k(s, "fire"))
        if s.deck_out <= 0.0 and s.side == 0: say("The %s's flight deck is patched: she can fly again." % s.rec.name, 2.5)
    if s != flag and absf(s.list) > 0.6 and s.alive: counter_flood(s)   # other captains right a bad list themselves
    if s.mag_fire > 0:
        s.mag_fire -= dt
        if randf() < dt * 0.08 * dc * dc_k(s, "fire") * (0.6 + 0.4 * s.cf):
            flood_magazine(s)
            say(("Magazine flooded aboard the %s: the turret above is out of action." if s.side == 0 else "The %s floods a magazine.") % s.rec.name, 2.5)
        elif s.mag_fire <= 0: _log("detonation (fire)"); detonate(s); return
    var dm: float = dc * dc_k(s, "mach")
    if s.eng_out > 0: s.eng_out = maxf(0.0, s.eng_out - dt * dm); if s.eng_out == 0 and s.side == 0: say("The %s has steam again." % s.rec.name, 2.0)
    if s.eng < 0.8: s.eng = minf(0.8, s.eng + dt * 0.002 * dm)
    if s.jam > 0: s.jam = maxf(0.0, s.jam - dt * dm)
    if s.steer < 0.85: s.steer = minf(0.85, s.steer + dt * 0.002 * dm)
    if s.list != 0.0: s.list = move_toward(s.list, 0.0, dt * 0.0025 * dc * dc_k(s, "flood"))   # counter-flooding brings her upright, slowly
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
    var r: float = (1.5 + sz * 2.2) * (0.7 + randf() * 0.6)
    if big:   # a heavy hit beside an older gash widens that one: two tears are never drawn across each other
        for o in s.marks:
            if not o.get("gash", false): continue
            if absf(o.x - x) < (o.r + r) * 0.9 and absf(o.y - y) < (o.r + r) * 0.52:
                o.r = minf(float(o.r) * 1.12, maxf(float(o.r), 4.0 + float(s.d.B) * 0.3)); big = false; edge = false; hole = false; wreckage(s, wp, 1, sz); break
    s.marks.append({"x": x, "y": y, "r": r, "v": randi() % 4, "hole": hole, "gash": big, "edge": edge, "sd": randi() % 1000, "side": signf(y) if y != 0.0 else 1.0})
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
            if w.air <= 0.0: fx_splash(w.pos, 0.5 + w.sz * 0.25); w.vel *= 0.15; w.spin = 0.0   # it lies where it fell, and does not turn
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
    return _clear_of_ships(s, desired)

## Collisions and ramming (reworked 11 Nov 2026 at the owner's word: ramming hurts, friend or foe). A hull is a long
## thing, not a circle: each ship is taken as her centreline with half her beam round it, so two ships touch where
## their sides or stems really would. A touch at a crawl only fends them off. With way on, both are hurt by how fast
## they came together and by the other's weight; the ship that strikes with her stem is hurt less than the one struck in
## the side, who is also holed there and takes a list to that side. A boat running shallow (periscope depth) can be
## rammed; a boat gone deep is passed over.
const RAM_SLOW := 1.5      # closing speeds under this (m/s) do no damage
const RAM_K := 0.95        # damage for each m/s of closing speed and each root-ton of the other ship
const RAM_DEEP := 0.8      # a boat dived deeper than this is under the keels of surface ships
func ram_hull(s: CShip) -> Array:   # the two ends of her centreline (stern, stem) and the half beam
    var h: float = maxf(0.0, s.d.L * 0.5 - s.d.B * 0.5); var u := Vector2.from_angle(s.a)
    return [s.pos - u * h, s.pos + u * h, s.d.B * 0.5]
## The nearest points of two segments: [point on the first, point on the second, how far along the first (0 stern .. 1 stem), along the second].
func _seg_near(p1: Vector2, q1: Vector2, p2: Vector2, q2: Vector2) -> Array:
    var d1 := q1 - p1; var d2 := q2 - p2; var r := p1 - p2
    var a := d1.dot(d1); var e := d2.dot(d2); var f := d2.dot(r); var sN := 0.0; var tN := 0.0
    if a <= 0.0001 and e <= 0.0001: return [p1, p2, 0.5, 0.5]
    if a <= 0.0001: tN = clampf(f / e, 0.0, 1.0)
    else:
        var c := d1.dot(r)
        if e <= 0.0001: sN = clampf(-c / a, 0.0, 1.0)
        else:
            var bb := d1.dot(d2); var den := a * e - bb * bb
            sN = clampf((bb * f - c * e) / den, 0.0, 1.0) if den > 0.0001 else 0.5
            tN = (bb * sN + f) / e
            if tN < 0.0: tN = 0.0; sN = clampf(-c / a, 0.0, 1.0)
            elif tN > 1.0: tN = 1.0; sN = clampf((bb - c) / a, 0.0, 1.0)
    return [p1 + d1 * sN, p2 + d2 * tN, sN, tN]
func can_collide(s: CShip) -> bool: return active(s) and (not s.sub or s.dive < RAM_DEEP)
func _collisions() -> void:
    var live: Array[CShip] = []
    for s in ships: if can_collide(s): live.append(s)
    for i in live.size():
        for j in range(i + 1, live.size()):
            var a: CShip = live[i]; var b: CShip = live[j]
            if a.pos.distance_squared_to(b.pos) > pow((a.d.L + b.d.L) * 0.5 + 10.0, 2.0): continue
            var ha: Array = ram_hull(a); var hb: Array = ram_hull(b)
            var n: Array = _seg_near(ha[0], ha[1], hb[0], hb[1]); var gap: float = (n[0] as Vector2).distance_to(n[1]); var reach: float = float(ha[2]) + float(hb[2])
            if gap >= reach: continue
            var nrm: Vector2 = ((n[1] as Vector2) - (n[0] as Vector2)) / gap if gap > 0.01 else (b.pos - a.pos).normalized()
            var ov: float = (reach - gap) * 0.5
            a.pos -= nrm * ov; b.pos += nrm * ov   # they cannot lie in one another
            var closing: float = (Vector2.from_angle(a.a) * a.v - Vector2.from_angle(b.a) * b.v).dot(nrm)
            # one collision is one collision: the same two do not grind on each other every few seconds (they did, until one
            # sank). Having struck, each sheers off from the other, and they are not counted as striking again for half a minute.
            if closing < RAM_SLOW or a.ram_t > 0 or b.ram_t > 0 or (a.sheer == b and a.sheer_t > 0.0): continue
            a.sheer = b; b.sheer = a; a.sheer_t = 30.0; b.sheer_t = 30.0
            # who struck whom: a stem (the last tenth of her length forward) against anything but another stem is a ram
            var a_stem: bool = float(n[2]) > 0.9; var b_stem: bool = float(n[3]) > 0.9
            var ka := 1.0; var kb := 1.0
            if a_stem and not b_stem: ka = 0.45
            elif b_stem and not a_stem: kb = 0.45
            if a.sub: ka *= 1.5   # a boat's pressure hull is no match for a stem
            if b.sub: kb *= 1.5
            var at: Vector2 = ((n[0] as Vector2) + (n[1] as Vector2)) * 0.5
            var da: float = RAM_K * closing * sqrt(float(b.d.t)) * ka; var db: float = RAM_K * closing * sqrt(float(a.d.t)) * kb
            a.ram_t = 6.0; b.ram_t = 6.0
            for pr in [[a, b, da, a_stem and not b_stem], [b, a, db, b_stem and not a_stem]]:
                var me: CShip = pr[0]; var other: CShip = pr[1]
                if not pr[3]:   # struck in the side: holed there, and she lists to it
                    var ly: float = (at - me.pos).rotated(-me.a).y
                    me.list = clampf(me.list + signf(ly) * clampf(float(pr[2]) / me.max_hull, 0.05, 0.4), -1.0, 1.0)
                    mark_hit(me, at, 3.0, true, 0.2)
                else: mark_hit(me, at, 1.5, false, 0.0)   # her stem crumpled
                damage(me, float(pr[2]), "ram")
            # way comes off both, most off the lighter
            var ma: float = float(a.d.t); var mb: float = float(b.d.t)
            a.v *= clampf(1.0 - 0.7 * mb / (ma + mb), 0.25, 0.9); b.v *= clampf(1.0 - 0.7 * ma / (ma + mb), 0.25, 0.9)
            sound("hit_big", at, 0.7); part(P.SMOKE, at, 5.0, 10.0, Vector2.ZERO, true)
            if modern: wreckage(a if a.alive else b, at, 4, 2.0); fx_splash(at, 18.0)
            var rammer: CShip = a if (a_stem and not b_stem) else (b if (b_stem and not a_stem) else null)
            var victim: CShip = b if rammer == a else a
            if rammer != null: say(("The %s rams the %s!" if rammer.side != victim.side else "Collision! The %s has run into the %s.") % [rammer.rec.name, victim.rec.name], 3.0)
            else: say("Collision! The %s and the %s have struck." % [a.rec.name, b.rec.name], 3.0)
            _log("collision" if a.side != b.side else "collision between friends")
## A captain keeps clear of other ships: if she and another (not a boat gone deep) are closing and would pass within a
## ship's length in the next half minute, he alters to pass under her stern. Your flagship is yours to con.
func _clear_of_ships(s: CShip, desired: float) -> float:
    if s.sheer_t > 0.0 and s.sheer != null and (s.sheer as CShip).alive and s.pos.distance_to((s.sheer as CShip).pos) < (s.d.L + (s.sheer as CShip).d.L) * 0.75 + 60.0:
        s.brake = maxf(s.v * 0.5, 2.0)   # she has just struck her: away from her, easy
        return (s.pos - (s.sheer as CShip).pos).angle()
    var vs := Vector2.from_angle(desired) * maxf(s.v, 3.0)
    var worst = null; var worst_t := 30.0
    for o in ships:
        if o == s or not can_collide(o) or (o.sub and submerged(o)): continue
        var rel: Vector2 = o.pos - s.pos; var dist: float = rel.length()
        if dist > 900.0 + s.d.L: continue
        var rv: Vector2 = Vector2.from_angle(o.a) * o.v - vs
        var rv2: float = rv.length_squared()
        if rv2 < 1.0: continue
        var tc: float = -rel.dot(rv) / rv2
        if tc <= 0.0 or tc > worst_t: continue
        if (rel + rv * tc).length() < (s.d.L + o.d.L) * 0.5 + 25.0: worst = o; worst_t = tc
    if worst == null: return desired
    var o2: CShip = worst
    # close, and she is ahead of us: ease down as well as turn (two ships making for the same boat, or a leader who has lost way)
    if worst_t < 16.0 and absf(ang_diff((o2.pos - s.pos).angle(), s.a)) < 1.1: s.brake = maxf(0.0, o2.v * 0.5) if worst_t > 6.0 else 0.0
    # turn away from where she will be: towards her stern if she is crossing, else simply away from her bearing
    var to_stern: Vector2 = (o2.pos - Vector2.from_angle(o2.a) * (o2.d.L * 0.5 + s.d.L)) - s.pos
    var away: float = signf(ang_diff(to_stern.angle(), desired)); if away == 0.0: away = float(s.pref_side)
    return desired + away * clampf(1.4 - worst_t / 30.0, 0.5, 1.3)

func yaw_lag(s: CShip) -> float: return 3.0 + s.d.L / 45.0

## Conning: order rudder towards a heading, easing it off early because the ship keeps swinging.
func helm(s: CShip, desired: float) -> float:
    return clampf((ang_diff(desired, s.a) - s.w * (yaw_lag(s) + 4.0)) * 4.0, -1.0, 1.0)

## Where a ship of yours belongs in the standing formation, in the flagship's frame (x ahead, y to starboard).
func station(s: CShip) -> Vector2:
    var mine: Array = []
    var o: String = ord_of(s)
    for x in ships: if x.side == 0 and x != flag and active(x) and ord_of(x) == o: mine.append(x)   # a formation is made by the ships that share the order
    var idx: int = maxi(0, mine.find(s)); var wing: float = 1.0 if idx % 2 else -1.0; var rank: float = floor(idx / 2.0)
    match o:
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

## Her captain's temper as a factor: one value for a bold captain, one for a steady one, one for a cautious one.
func temper_k(s: CShip, bold: float, steady: float, cautious: float) -> float: return bold if s.tm == "bold" else (cautious if s.tm == "cautious" else steady)
func ai_ship(s: CShip, dt: float) -> void:
    if s.struck: s.throttle = 0; s.rudder = 0; return
    s.v_cmd = -1.0; s.brake = -1.0
    # a cautious captain of yours, badly hurt and left to fight as he sees fit, takes his ship out of it
    if s.side == 0 and s != flag and s.tm == "cautious" and s.hull / s.max_hull < 0.35 and ord_of(s) == "engage":
        s.ord = "retreat"; say("The %s's captain takes her out of the fight: she is badly hurt." % s.rec.name, 2.0)
    # smoke: a ship that is running, or badly hurt with the enemy in sight, covers herself (and those behind her)
    if not s.smoke_on and s.smoke_left > SMOKE_CHARGE * 0.8 and can_smoke(s) and ((s.flee if s.side == 1 else ord_of(s) == "retreat") or s.hull / s.max_hull < temper_k(s, 0.2, 0.4, 0.6)):
        if nearest_enemy(s.pos, s.side, 10000.0) != null: make_smoke(s, true)
    if s.sub: s.want_dive = nearest_enemy(s.pos, s.side, 8000.0) != null
    var o: String = ord_of(s)
    var retreat = (o == "retreat") if s.side == 0 else s.flee
    if retreat:
        var ne = nearest_enemy(s.pos, s.side)
        var home = PI / 2 if s.side == 0 else -PI / 2
        var away = (s.pos - ne.pos).angle() if ne != null else home
        var goal = away if absf(ang_diff(away, home)) < 1.4 else home + clampf(ang_diff(away, home), -0.9, 0.9)
        s.rudder = helm(s, steer_avoid(s, goal)); s.throttle = 4; return
    s.tgt_t -= dt
    if s.force_tgt != null and engageable(s.force_tgt): s.target = s.force_tgt; s.tgt_t = 1.0
    if s.tgt_t <= 0 or s.target == null or not engageable(s.target) or not visible_to(s.target, s.side):
        s.tgt_t = 10.0; s.target = best_target(s.pos, s.side, INF, Callable(), true) if heavy_guns(s) else nearest_enemy(s.pos, s.side)
    var tg = s.target
    if s.side == 0 and o == "goto":   # sent to a point: go there and lie there, firing as her guns bear
        var gd := s.pos.distance_to(s.ord_pt)
        if gd > 250.0: s.rudder = helm(s, steer_avoid(s, (s.ord_pt - s.pos).angle())); s.throttle = 4 if gd > 1500.0 else 2
        else: s.throttle = 0; s.rudder = 0.0
        return
    if s.side == 0 and o == "torp":   # a torpedo attack: run in at speed, turn beam on inside range, fire, and rejoin
        var tt: CShip = s.ord_tgt if (s.ord_tgt != null and engageable(s.ord_tgt) and visible_to(s.ord_tgt, 0)) else nearest_enemy(s.pos, 0)
        var loaded := false; var reach := 0.0
        var tubes := false   # tubes still in action (a mount knocked out on the run in cannot fire: she used to circle there for ever)
        for m in s.mounts:
            if m.w.kind != "torp" or m.dead: continue
            tubes = true; reach = maxf(reach, float(m.w.range))
            if m.cd <= 0 and m.ammo != 0: loaded = true
        if tt == null or not loaded:
            s.ord = ""; s.ord_tgt = null; o = ord_of(s)
            if s.alive: say("The %s has %s and rejoins." % [s.rec.name, ("fired her torpedoes" if tubes else "lost her tubes") if tt != null else "no target for her torpedoes"], 1.8)
        elif s.foul_by != null and t - s.foul_at < 3.0 and t - s.foul_since > TORP_GIVEUP:
            # she has held her torpedoes this long for a friend in the track: she gives the attack up rather than circle for ever
            if s.alive: say("The %s gives up her torpedo attack: the %s stays in the track. She rejoins." % [s.rec.name, s.foul_by.rec.name], 2.5)
            s.ord = ""; s.ord_tgt = null; s.foul_by = null; s.foul_said = false; o = ord_of(s)
        else:
            if s.foul_by != null and t - s.foul_at >= 3.0: s.foul_by = null; s.foul_said = false
            if s.foul_by != null and not s.foul_said: s.foul_said = true; say("The %s holds her torpedoes: the %s is in the track." % [s.rec.name, s.foul_by.rec.name], 2.2)
            s.target = tt; var td := s.pos.distance_to(tt.pos); var bearing := (tt.pos - s.pos).angle()
            if td > reach * 0.6: s.rudder = helm(s, steer_avoid(s, bearing)); s.throttle = 4
            else: s.rudder = helm(s, steer_avoid(s, bearing - s.pref_side * PI / 2)); s.throttle = 3   # beam on: the tubes bear
            return
    if s.side == 0 and o == "line" and flag != null and flag != s and flag.side == 0:
        # line ahead: each ship follows in the wake of the one ahead of her, the flagship leading; guns fire as they bear
        var col: Array = []
        for x in ships: if x.side == 0 and x != flag and active(x) and ord_of(x) == "line" and x.d.kind != "carrier" and x.d.kind != "merchant" and not x.sub: col.append(x)
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
    if s.side == 0 and flag != null and flag != s and flag.side == 0 and (o == "escort" or o == "abreast" or o == "screen"):
        # formations: every ship has a station on the flagship and keeps it, turning and changing speed with her.
        # "Form on flag" breaks off to fight what comes within 3 km; line abreast and the screen hold station and
        # fire as their guns bear.
        var close = nearest_enemy(s.pos, s.side, 3000.0) if o == "escort" else null
        if close == null:
            keep_station(s, station(s)); return
        tg = close
    if tg == null:
        var lost: CShip = nearest_any(s.pos, s.side) if limited() else null   # out of sight: close the enemy's last reported position
        # by night, with the enemy somewhere inside gun range and nothing in sight: star shell over where he is thought to be
        if lost != null and wx.get("night", false) and not holding(s) and s.star_t <= 0.0 and s.pos.distance_to(lost.pos) < minf(STAR_REACH, max_gun_range(s) * 1.2) and not star_lit(lost.pos) and s != flag:
            fire_star(s, lost.pos + rdir() * 400.0)
        if lost != null and s.d.kind != "merchant" and s.d.kind != "carrier": s.throttle = 3; s.rudder = helm(s, steer_avoid(s, (lost.pos - s.pos).angle())); return
        s.throttle = 2; s.rudder = helm(s, s.a); return
    var d = s.pos.distance_to(tg.pos); var to = (tg.pos - s.pos).angle()
    var pref = 0.0
    if s.d.kind == "carrier": pref = 15000.0
    elif s.d.kind == "merchant": pref = 9000.0
    elif s.sub or s.d.kind == "pt": pref = 6000.0 if s.torp_run_t > 0 else 2600.0
    elif has_kind(s, "ssm"): pref = 9000.0
    else: pref = max_gun_range(s) * 0.78
    if s.d.kind != "carrier" and s.d.kind != "merchant": pref *= maxf(0.5, 1 - t / 1500.0) * temper_k(s, 0.75, 1.0, 1.2)   # a bold captain closes, a cautious one keeps the range open
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
    if asw:   # a submerged contact: run in over where she will be when the charges get down to her, so that the pattern falls on her
        var run_t: float = d / maxf(s.v, 4.0) + DC_ROLL * 1.5 + DC_SINK
        var aim: Vector2 = dc_lead(tg, minf(run_t, 60.0)) + Vector2.from_angle(s.a) * (s.d.L * 0.5 - s.v * DC_ROLL * 1.5)   # it is her stern that must pass over the place
        desired = (aim - s.pos).angle() if aim.distance_to(s.pos) > 30.0 else s.a
    var mg: float = s.d.td + 800.0
    if s.pos.x < mg or s.pos.x > AW - mg or s.pos.y < mg or s.pos.y > AH - mg: desired = (Vector2(AW, AH) / 2 - s.pos).angle()
    s.rudder = helm(s, steer_avoid(s, desired))
    s.throttle = 4 if d > pref + 1500 or asw else 3
    # a boat that is being hunted goes quiet: found by a ping, or with a pinging ship close by, she creeps (a creeping
    # boat is all but silent to a listener) unless she is on her run in to fire
    if s.sub and submerged(s) and s.torp_run_t <= 0 and (s.side == 1 or flag == null or s != flag):
        var hunted: bool = s.held_t < PING_HOLD
        if not hunted:
            for hn in ships: if hn.side != s.side and active(hn) and not hn.sub and has_sonar(hn) and hn.pos.distance_to(s.pos) < (sonar_range(hn) * 1.3 if hn.sonar_on else 900.0): hunted = true; break
        if hunted and d > 1400.0: s.throttle = 1
        # and when a hunter is running in on her she does not wait for the pattern: the charges take seconds to sink, so she
        # turns hard across the hunter's track and puts on speed, to be somewhere else when they get down to her
        var runner: CShip = null
        for hn2 in ships:
            if hn2.side == s.side or not active(hn2) or hn2.sub or hn2.dc_left <= 0 or not has_sonar(hn2): continue
            var hd: float = hn2.pos.distance_to(s.pos)
            if hd < 480.0 and absf(ang_diff((s.pos - hn2.pos).angle(), hn2.a)) < 0.6 and (runner == null or hd < runner.pos.distance_to(s.pos)): runner = hn2
        if runner != null and s.held_t < PING_HOLD + 20.0:
            var side_: float = signf((s.pos - runner.pos).rotated(-runner.a).y); if side_ == 0.0: side_ = float(s.pref_side)
            s.rudder = helm(s, steer_avoid(s, runner.a + side_ * PI / 2)); s.throttle = 4
    if s.d.kind == "carrier" and not holding(s): launch_strike(s, nearest_enemy(s.pos, s.side, 30000.0, func(o: CShip) -> bool: return not submerged(o)))

## Flying from a carrier. Aircraft leave the deck and come back to it one at a time: a squadron ordered off forms up
## ahead of the ship as its machines take off ("form"), flies its strike ("out", then "home"), and circles astern
## while they land in turn ("land"). A group's `n` is every machine it still has, `up` those in the air, `dk` those
## not yet flown off, `ops` those on the deck run or the approach at this moment. The flight deck is a system of its
## own: a bomb or shell through it (`deck_out`, seconds until it is patched) or a heavy list stops all flying, and
## machines kept waiting too long run out of fuel and ditch.
const DECK_GAP := 4.0     # seconds between one machine and the next
const DECK_LIST := 0.6    # a list beyond this and nothing can fly
## How far a lost ship has gone down, 0..1. A big ship takes longer about it than a small one (some 20 s for a
## destroyer, over 30 for a battleship, at the battle's ordinary speed): she settles, the sea comes over her low side, and she is gone.
func sink_k(s: CShip) -> float: return 0.0 if s.alive else minf(1.0, s.sink / (14.0 + float(s.d.L) * 0.07))
func deck_ok(s: CShip) -> bool: return s.alive and s.deck_out <= 0.0 and absf(s.list) < DECK_LIST
## Another carrier of the same side for aircraft whose own is lost: the nearest still afloat and in the action.
func other_deck(q: Dictionary) -> CShip:
    var best: CShip = null
    for s in ships:
        if s == q.home or s.side != q.side or not active(s) or s.sub or int(s.d.get("hangar", 0)) <= 0: continue
        if best == null or s.pos.distance_squared_to(q.pos) < best.pos.distance_squared_to(q.pos): best = s
    return best
func deck_why(s: CShip) -> String: return "her flight deck is holed" if s.deck_out > 0.0 else ("she is listing too far" if absf(s.list) >= DECK_LIST else "")
## The ends of the flight deck in the ship's own frame (x aft end, y fore end).
func deck_span(s: CShip) -> Vector2:
    var p: Dictionary = s.d.p
    if p.has("fd"): var fl: float = s.d.L * float(p.fd.len); var fx: float = float(p.fd.get("x", 0.0)); return Vector2(fx - fl / 2.0, fx + fl / 2.0)
    return Vector2(-s.d.L * 0.45, s.d.L * 0.45)
## The air wing, squadron by squadron, for the readouts: machines aboard, in the air, lost, and whether rearming.
func wing(s: CShip) -> Array:
    var out: Array = []
    for sq in s.squads:
        var e := {"aboard": 0, "air": 0, "lost": 0, "rearm": sq.state == "rearm", "full": int(sq.get("n0", 6))}
        if sq.state == "out":
            for q in air:
                if is_same(q.sq, sq): e.air = int(q.up) + int(q.ops); e.aboard = maxi(0, int(q.n) - int(e.air))
        elif sq.state != "lost": e.aboard = int(sq.n)
        e.lost = maxi(0, int(e.full) - int(e.aboard) - int(e.air))
        out.append(e)
    return out

func launch_strike(s: CShip, tg: CShip) -> bool:
    if tg == null or s.sub: return false
    if int(wx.sea) >= 3 or wx.fog or (wx.night and not s.tech.has("jets")):   # no flying in a storm or fog, and only jets by night
        if s.side == 0 and s == flag: say("Aircraft cannot fly: " + ("a storm." if int(wx.sea) >= 3 else ("fog." if wx.fog else "it is night, and only jets fly by night.")), 2.5)
        return false
    if not deck_ok(s):
        if s.side == 0 and s == flag: say("Aircraft cannot fly: " + deck_why(s) + ".", 2.5)
        return false
    var launched = 0
    for q in s.squads:
        if q.state != "ready" or q.n <= 0: continue
        var jet = s.tech.has("jets")
        air.append({"side": s.side, "home": s, "sq": q, "pos": world_pt(s, deck_span(s).y + 150.0, 0.0), "a": s.a, "n": q.n, "n0": q.n, "up": 0, "dk": q.n, "ops": 0, "wait": 0.0,
            "type": "tb" if launched % 2 == 0 else "db", "jet": jet, "ju": tech_up(s.tech, "jets"), "target": tg, "state": "form"})
        q.state = "out"; launched += 1
    if launched and s.side == 0: say(str(launched) + " squadron" + ("s" if launched > 1 else "") + " taking off.", 2.0)
    if launched and s.side == 1: say("Enemy aircraft are taking off!" if visible_to(s, 0) else "Enemy aircraft inbound!", 2.5)
    return launched > 0

func update_air(dt: float) -> void:
    for i in range(air.size() - 1, -1, -1):
        var q: Dictionary = air[i]; var sp = 220.0 if q.jet else 75.0
        var home: CShip = q.home
        var on_deck: bool = q.state == "form" or q.state == "land"
        # gunfire brings down machines in the air, never those still on the deck
        if q.n < q.n0:
            var lost: int = int(q.n0) - int(q.n)
            if on_deck: lost = mini(lost, int(q.up)); q.n = int(q.n0) - lost
            q.up = maxi(0, int(q.up) - lost)
        if not on_deck: q.up = q.n
        if not home.alive:   # the ship is gone under them: those still aboard go with her, those in the air look for another deck
            if on_deck: q.ops = 0; q.dk = 0; q.n = q.up
            var alt: CShip = other_deck(q)
            if q.n > 0 and alt != null:
                # (owner's decision, 11 Nov 2026) they make for another carrier of their own side and join her air wing
                # as a squadron of their own; she strikes them below and rearms them like her own
                var guest := {"state": "out", "t": 0.0, "n": q.n, "n0": q.n, "guest": true}
                q.sq.n = 0; q.sq.state = "lost"; alt.squads.append(guest); q.sq = guest; q.home = alt
                if q.state == "land": q.state = "home"
                elif q.state == "form": q.state = "out"
                if q.side == 0: say("The %s is gone: her aircraft make for the %s." % [home.rec.name, alt.rec.name], 3.0)
                home = alt; on_deck = false
            elif on_deck:
                if q.state == "land": q.n = 0   # nowhere to come down
                q.state = "out"
        q.n0 = q.n
        if q.n <= 0: q.sq.n = 0; q.sq.state = "lost"; air.remove_at(i); continue
        if q.state == "out" and (q.target == null or not engageable(q.target)):
            q.target = nearest_enemy(q.pos, q.side, 40000.0, func(o: CShip) -> bool: return not submerged(o))
            if q.target == null: q.state = "home"
        var g: Vector2
        if q.state == "form":
            if q.dk <= 0 and q.ops <= 0: q.state = "out"
            g = world_pt(home, deck_span(home).y + 650.0, 0.0)
            if q.up <= 0: q.pos = world_pt(home, deck_span(home).y + 150.0, 0.0); q.a = home.a; continue
        elif q.state == "out":
            var tg: CShip = q.target; g = tg.pos; var d: float = q.pos.distance_to(tg.pos)
            if q.type == "tb" and d < 1300 and absf(ang_diff((tg.pos - q.pos).angle(), q.a)) < 0.35 and (not ff_care or torp_fouls(null, q.pos, lead_point(q.pos, tg, 18.0), {"speed": 18.0, "run": 1980.0, "count": int(q.n), "side": q.side}, tg) == null):   # not with a friend in the track
                var lp = lead_point(q.pos, tg, 18.0)
                for k in int(q.n): torps.append({"pos": q.pos + Vector2(randf() - 0.5, randf() - 0.5) * 150.0, "a": (lp - q.pos).angle() + (k - q.n / 2.0) * 0.05, "speed": 18.0, "life": 110.0, "dmg": 520 if q.jet else 420, "side": q.side, "homing": false, "arm": 8.0})
                q.state = "home"; boom(q.pos, 0.1, 900.0)
            elif q.type == "db" and d < 120:
                for k in int(q.n):
                    var hit = randf() < (0.55 if q.jet else 0.4) + 0.05 * int(q.get("ju", 0))
                    var bp = tg.pos + Vector2((randf() - 0.5) * (tg.d.L * 0.4 if hit else 220.0), (randf() - 0.5) * (tg.d.B if hit else 220.0))
                    if hit: mark_hit(tg, bp, 3.0, true); hit_systems(tg, bp, 260 if q.jet else 230, "bomb"); damage(tg, 260 if q.jet else 230, "bomb"); fx_boom(bp, 26.0, 0.8)
                    else: fx_splash(bp, 22.0)
                q.state = "home"; sound("hit_big", tg.pos, 0.4)
        elif q.state == "home":
            if not home.alive: q.n = 0; continue
            g = home.pos
            if q.pos.distance_to(g) < 900.0: q.state = "land"; q.wait = 0.0
        else:   # circling astern while they come down one by one
            g = world_pt(home, deck_span(home).x - 600.0, 0.0)
            if q.up <= 0 and q.ops <= 0:
                q.sq.n = q.n; q.sq.state = "rearm"; q.sq.t = 300.0 / (1 + 0.12 * home.sk.ord); air.remove_at(i); continue
            if not deck_ok(home):   # nowhere to come down: they circle until the tanks run dry
                if q.wait <= 0.0 and q.side == 0: say("The %s cannot land her aircraft: %s. They are circling." % [home.rec.name, deck_why(home)], 3.0)
                q.wait += dt
                if q.wait > 150.0 and q.up > 0:
                    q.wait -= 12.0; q.n -= 1; q.up -= 1; q.n0 = q.n; fx_splash(q.pos + rdir() * 60.0, 3.0)
                    if q.side == 0: say("An aircraft of the %s ditches, out of fuel." % home.rec.name, 2.0)
        if q.up <= 0: continue
        q.a += clampf(ang_diff((g - q.pos).angle(), q.a), -0.3 * dt, 0.3 * dt)
        q.pos += Vector2.from_angle(q.a) * sp * dt
    for s in ships:
        if s.squads.is_empty(): continue
        for sq in s.squads:
            if sq.state == "rearm":
                sq.t -= dt
                if sq.t <= 0: sq.state = "ready"
        if not s.alive: s.deck_ops.clear(); continue
        # the deck: machines already rolling or on the approach finish; the next one goes when the deck is clear
        for j in range(s.deck_ops.size() - 1, -1, -1):
            var op: Dictionary = s.deck_ops[j]; op.t += dt
            if not _fly_op(s, op, dt): continue
            op.q.ops = maxi(0, int(op.q.ops) - 1)
            if op.k == "to": op.q.up += 1
            s.deck_ops.remove_at(j)
        s.deck_t -= dt
        if s.deck_t > 0.0 or not deck_ok(s): continue
        var nxt = null   # landings first: they are the ones short of fuel
        for q in air: if q.home == s and q.state == "land" and q.up > 0: nxt = q; break
        if nxt != null:
            nxt.up -= 1; nxt.ops += 1; s.deck_t = DECK_GAP * 1.5
            s.deck_ops.append({"k": "ld", "ph": "gate", "t": 0.0, "pt": 0.0, "q": nxt, "pos": nxt.pos + Vector2(-26.0 * ceili(nxt.up / 2.0), 0).rotated(nxt.a), "a": nxt.a,
                "v": 220.0 if nxt.jet else 75.0, "alt": 28.0 if nxt.type == "tb" else 60.0})
            continue
        for q in air: if q.home == s and q.state == "form" and q.dk > 0: nxt = q; break
        if nxt != null:
            nxt.dk -= 1; nxt.ops += 1; s.deck_t = DECK_GAP
            s.deck_ops.append({"k": "to", "ph": "run", "t": 0.0, "pt": 0.0, "q": nxt, "pos": world_pt(s, lerpf(deck_span(s).x, deck_span(s).y, 0.4), 0.0), "a": s.a, "v": 0.0, "alt": 2.0})

## One machine taking off or landing, flown as an aircraft is flown: it has a place, a heading and a speed, and it
## turns no faster than an aircraft can, so its path is a curve and never a corner. Taking off: down the deck, straight
## on over the bow as it climbs, then round to join its squadron. Landing: out of the formation, round to a point
## astern of the ship, up her wake onto the deck, and forward to the lift. True when it is done.
const DECK_ROLL := 3.0
func _fly_op(s: CShip, op: Dictionary, dt: float) -> bool:
    var q: Dictionary = op.q; var span: Vector2 = deck_span(s); var dl: float = span.y - span.x
    var cruise: float = 220.0 if q.jet else 75.0; var high: float = 28.0 if q.type == "tb" else 60.0
    op.pt += dt
    match String(op.ph):
        "run":   # the deck run: gathering way to the bow
            var k: float = clampf(op.pt / DECK_ROLL, 0.0, 1.0)
            op.pos = world_pt(s, lerpf(span.x + dl * 0.4, span.y, k * k), 0.0); op.a = s.a; op.alt = 2.0
            if k >= 1.0: op.ph = "fly"; op.pt = 0.0; op.v = s.v + 2.0 * dl * 0.6 / DECK_ROLL
        "fly":   # away over the bow, climbing; then round to the squadron, a little faster than it flies
            op.v = move_toward(op.v, cruise * 1.3, cruise * 0.5 * dt); op.alt = move_toward(op.alt, high, high * 0.3 * dt)
            var slot: Vector2 = q.pos + Vector2(-26.0 * ceili(q.up / 2.0), 0).rotated(q.a) if q.up > 0 else q.pos
            if op.pt > 1.5: op.a += clampf(ang_diff((slot - op.pos).angle(), op.a), -0.7 * dt, 0.7 * dt)
            op.pos += Vector2.from_angle(op.a) * op.v * dt
            return (op.pt > 1.5 and op.pos.distance_to(slot) < maxf(45.0, op.v * 0.35)) or op.pt > 30.0
        "gate":  # out of the formation and round to a point astern of her, slowing and coming down
            var slow: float = maxf(55.0, s.v + 40.0)
            op.v = move_toward(op.v, slow, cruise * 0.4 * dt); op.alt = move_toward(op.alt, 22.0, high * 0.2 * dt)
            var gate: Vector2 = world_pt(s, span.x - 420.0, 0.0)
            op.a += clampf(ang_diff((gate - op.pos).angle(), op.a), -0.8 * dt, 0.8 * dt)
            op.pos += Vector2.from_angle(op.a) * op.v * dt
            if op.pos.distance_to(gate) < maxf(110.0, op.v * 1.3) or op.pt > 40.0: op.ph = "final"; op.pt = 0.0
        "final": # up her wake: lined up with the deck and sinking onto it
            var wire: Vector2 = world_pt(s, span.x + dl * 0.12, 0.0); var d: float = op.pos.distance_to(wire)
            op.v = move_toward(op.v, maxf(40.0, s.v + 28.0), 30.0 * dt); op.alt = minf(op.alt, 2.0 + d * 0.06)
            # aim a little way up the centreline from where she is, so she comes onto it and along it, not across it
            var aim: Vector2 = world_pt(s, span.x + dl * 0.12 - d * 0.55, 0.0) if d > 60.0 else wire
            op.a += clampf(ang_diff((aim - op.pos).angle(), op.a), -1.3 * dt, 1.3 * dt)
            op.pos += Vector2.from_angle(op.a) * op.v * dt
            if d < 22.0 or op.pt > 25.0: op.ph = "roll"; op.pt = 0.0; op.x = span.x + dl * 0.12; op.off = (op.pos - wire).rotated(-s.a); op.da = ang_diff(op.a, s.a)
        "roll":  # on the deck: pulled up by the wires and taxied forward to the lift
            var k: float = clampf(op.pt / DECK_ROLL, 0.0, 1.0); var ease: float = 1.0 - pow(1.0 - k, 2.0)
            var settle: float = 1.0 - clampf(op.pt / 0.6, 0.0, 1.0)   # the last of her drift and swing taken out as she touches
            op.pos = world_pt(s, lerpf(op.x, span.x + dl * 0.5, ease), 0.0) + (op.off * settle).rotated(s.a); op.a = s.a + float(op.da) * settle; op.alt = 2.0
            return k >= 1.0
    return false

# ------------------------------------------------------------------ step
func step(dtv: float) -> void:
    if finished: return
    var dt = dtv * BT
    t += dt; vt += dtv
    small_craft = [false, false]
    for s in ships: if active(s) and (s.d.kind == "pt" or s.d.kind == "sub"): small_craft[s.side] = true
    _radar_plot(dt); _smoke_tick(dt); _star_tick(dt); _sonar_tick(dt); _emcon(dt)
    for s in ships:
        if not s.alive: s.sink += dtv; continue
        if s.escaped: continue
        s.reveal_t = maxf(0.0, s.reveal_t - dt); s.ram_t = maxf(0.0, s.ram_t - dt); s.sheer_t = maxf(0.0, s.sheer_t - dt); s.lit_t += dt
        # AI ships think four times a battle second and work their weapons ten times; your flagship every step
        if s == flag:
            if player_rudder != 0.0: waypoints.clear()   # taking the helm yourself cancels the waypoints
            while not waypoints.is_empty() and s.pos.distance_to(waypoints[0]) < maxf(150.0, s.d.L * 1.2): waypoints.pop_front()
            s.rudder = player_rudder if waypoints.is_empty() else helm(s, steer_avoid(s, (waypoints[0] - s.pos).angle()))
        else:
            s.ai_acc += dt
            if s.ai_acc >= 0.25:
                if not s.ai_off: ai_ship(s, s.ai_acc)
                s.ai_acc = 0.0
        if s.sub: s.dive = clampf(s.dive + (dt / 30.0 if s.want_dive else -dt / 30.0), 0.0, 1.0)
        s.wpn_acc += dt
        if s == flag or s.wpn_acc >= 0.1: update_weapons(s, s.wpn_acc); s.wpn_acc = 0.0
        var sm = submerged(s)
        # engines: way builds slowly in a big ship and bleeds off slower still; a hard turn scrubs off up to a third
        var top: float = (s.d.get("subKn", s.d.kn * 0.4) if sm else s.d.kn) * KN * speed_mult(s)
        top *= (1.0 - 0.25 * absf(s.list)) * s.ld_speed * (1.0 - 0.3 * s.ballast)
        var want: float = top * TELEGRAPH[s.throttle] * (1 - 0.3 * absf(s.rud) * minf(1.0, s.v / maxf(1.0, top)))
        if s.v_cmd >= 0.0 and s != flag: want = minf(want, s.v_cmd)
        if s.brake >= 0.0 and s != flag: want = minf(want, s.brake)   # easing down for a ship close ahead
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
        var retreating = (ord_of(s) == "retreat") if s.side == 0 else s.flee
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
        if s.wake_t <= 0 and s.v > 1 and sm and not modern: s.wake_t = 0.4; part(P.SWAKE, world_pt(s, -s.d.L * 0.48, 0), 3.0, s.d.B * 0.5)
        if modern and not s.sub and s.v > 2.0 and active(s):   # bow spray flung out at speed, the stern churning
            var sk := clampf(s.v / (s.d.kn * KN), 0.0, 1.0)
            if not fx_far and randf() < dtv * 14.0 * sk:   # (a third of a pixel from far out: not laid there)
                var sd := 1.0 if randf() < 0.5 else -1.0; var bx: float = s.d.L * 0.38
                var q = part(P.SPRAY, world_pt(s, bx, sd * hull_half(s.d, bx)), 0.5 + randf() * 0.5, s.d.B * (0.04 + 0.04 * sk), Vector2.from_angle(s.a + sd * (1.3 + randf() * 0.4)) * (6.0 + s.v * (0.8 + randf()))); q.drag = 0.2
            if randf() < dtv * (3.0 if fx_far else 6.0) * sk:
                var c = part(P.CHURN, world_pt(s, -s.d.L * 0.5, (randf() - 0.5) * s.d.B * 0.5), 2.5 + randf() * 2.0, s.d.B * (0.25 + randf() * 0.2) * (1.3 if fx_far else 1.0), -Vector2.from_angle(s.a) * s.v * 0.3); c.a = randf() * TAU; c.spin = (randf() - 0.5) * 0.6
        if not s.sub and s.d.p.has("fun") and s.d.p.fun.size():
            s.smoke_t -= dtv
            if s.smoke_t <= 0:
                s.smoke_t = 0.4 if fx_far else 0.2
                for f in s.d.p.fun:
                    var fp: Vector2 = world_pt(s, f[0], f[3] if f.size() > 3 else 0.0)
                    if s.eng_out > 0:   # engines stopped: no draught in the funnels, steam blowing off instead
                        if modern and randf() < 0.5: part(P.STEAM, fp + rdir() * s.d.B * 0.2, 4.0 + randf() * 2.0, 2.5 + s.d.B * 0.2, rdir() * 3.0, true)
                    else:
                        part(P.FUNNEL, fp, 5.0, (2.0 + s.d.B * 0.14) * (1.3 if fx_far else 1.0), -Vector2.from_angle(s.a) * 3.0, true)
                        if s.eng < 0.75 and randf() < (0.9 - s.eng): part(P.SMOKE, fp, 6.0 + randf() * 3.0, 2.5 + s.d.B * 0.2, -Vector2.from_angle(s.a) * 3.0, true)   # damaged boilers smoke black
        # fires burn where they started, move with the ship and pour smoke downwind until damage control puts them out
        if s.hull / s.max_hull < 0.4 and s.fires.size() < 3 and randf() < dt * 0.01: mark_hit(s, s.pos + Vector2((randf() - 0.5) * s.d.L * 0.4, 0).rotated(s.a), 2.0, false)
        for i in range(s.fires.size() - 1, -1, -1):
            var f: Dictionary = s.fires[i]; f.t -= dt * (1 + 0.3 * s.sk.dc) * (1.3 + 0.1 * tech_up(s.tech, "dc") if s.tech.has("dc") else 1.0) * dc_k(s, "fire")
            if f.t <= 0: s.fires.remove_at(i); continue
            f.st -= dtv
            if f.st <= 0: f.st = 0.35; part(P.SMOKE, world_pt(s, f.x, f.y), 8.0 + randf() * 5.0, 3.0 + f.r * 2.5, Vector2.ZERO, true)
    want_torp = false; want_msl = false
    _collisions()
    # shells land
    for i in range(shells.size() - 1, -1, -1):
        var sh: Dictionary = shells[i]; sh.t += dt; var k: float = minf(1.0, sh.t / sh.T); sh.pos = sh.s.lerp(sh.e, k)
        if sh.t < sh.T: continue
        shells.remove_at(i)
        var hit: CShip = null
        for s in ships:
            if s == sh.who or not active(s) or submerged(s): continue   # a shell hurts whatever it lands on, friend or foe (owner's word, 11 Nov 2026)
            var l: Vector2 = (sh.pos - s.pos).rotated(-s.a)
            if absf(l.x) < s.d.L / 2 + 3 and absf(l.y) < s.d.B / 2 + 3: hit = s; break
        var sz: float = {"S": 1.0, "M": 1.5, "L": 2.3, "H": 3.4}[sh.size]
        if sh.get("tgt") != null: spot(sh.who, sh.tgt, float(sh.get("rel", 6.0)))   # the fall of shot is seen and the next salvo corrected
        if hit != null:
            var res := shell_result(hit, sh); _log("shell " + res.kind)
            if hit.side == sh.side: _log("shell on a friend"); ff_dmg += sh.dmg * res.k
            mark_hit(hit, sh.pos, sz * (1.0 if res.kind == "pen" else 0.5), res.kind != "rico", float(res.get("fire", 1.0)))
            if res.kind == "pen": hit_systems(hit, sh.pos, sh.dmg, "shell")
            damage(hit, sh.dmg * res.k, "resolved")
            if res.kind == "rico": part(P.SPARK, sh.pos, 0.5, 2 + sz, Vector2.from_angle((sh.e - sh.s).angle() + (randf() - 0.5) * 1.2) * 120.0)
            else: fx_boom(sh.pos, 7 * sz * (1.0 if res.kind == "pen" else 0.6), 0.6)
            var mine: bool = sh.side == 0 or hit.side == 0
            if mine: hit_marks.append({"pos": sh.pos, "text": res.text, "kind": res.kind, "t": 1.8, "ours": hit.side == 0})
            for k2 in (8 if modern else 3): part(P.SPARK, sh.pos, 0.4 + randf() * 0.4, 1 + sz * 0.6, Vector2(randf() - 0.5, randf() - 0.5) * (160.0 if modern else 60.0))
            sound("hit", sh.pos, 0.14 * sz)
        elif land_at(sh.pos): fx_land(sh.pos, sz, str(sh.get("ammo", "ap")))
        else: fx_splash(sh.pos, shell_splash(sh, sz)); sound("splash", sh.pos, 0.05 * sz)
    # torpedoes
    for i in range(twakes.size() - 1, -1, -1): if vt - float(twakes[i].back().t) > TWAKE_LIFE: twakes.remove_at(i)
    for i in range(torps.size() - 1, -1, -1):
        var tp: Dictionary = torps[i]; tp.life -= dt; tp.arm -= dt; tp.en = float(tp.get("en", 0.0)) - dt
        if tp.homing and tp.arm <= 0 and tp.en <= 0:
            # the seeker hears the nearest ship in her cone, dived boats too, whatever her flag (see torp_fouls)
            var tg: CShip = null; var bd: float = float(tp.get("ear", HOMER_EAR))
            for o in ships:
                if not active(o): continue
                var rel: Vector2 = o.pos - tp.pos; var dd := rel.length()
                if dd < bd and absf(ang_diff(rel.angle(), tp.a)) < HOMER_CONE: bd = dd; tg = o
            if tg != null: tp.a += clampf(ang_diff((tg.pos - tp.pos).angle(), tp.a), -0.15 * dt, 0.15 * dt)
        tp.pos += Vector2.from_angle(tp.a) * tp.speed * dt
        var gone: bool = tp.life <= 0
        if not gone and land_at(tp.pos): gone = true; fx_boom(tp.pos, 20.0)
        if not gone and tp.arm <= 0:
            for s in ships:
                # any hull in her path, friend or foe (only a straight runner never comes back on her own ship)
                if not active(s) or (submerged(s) and not tp.homing) or (s == tp.get("who") and not tp.homing): continue
                var l: Vector2 = (tp.pos - s.pos).rotated(-s.a)
                if absf(l.x) < s.d.L / 2 and absf(l.y) < s.d.B / 2 + 2:
                    if s.side == tp.side: _log("torpedo on a friend"); ff_dmg_t += tp.dmg
                    else: _log("torpedo hit")
                    mark_hit(s, tp.pos, 4.0, false); hit_systems(s, tp.pos, tp.dmg, "torp"); damage(s, tp.dmg, "torp"); part(P.GEYSER, tp.pos, 1.6, 40.0); var tw = part(P.WASH if modern else P.FOAM, tp.pos, 16.0 if modern else 12.0, 45.0 if modern else 60.0); tw.over = modern   # a torpedo's burst throws its water over her decks for a moment
                    sound("torp_hit", tp.pos, 0.55); gone = true; break
        if not gone and not modern and randf() < dtv * 4: part(P.TWAKE, tp.pos, 4.0, 1.5)
        if modern:   # her wake: a narrow track like a ship's, laid point by point (battle.gd draws it as a ribbon)
            if not tp.has("trail"): tp["trail"] = []; tp["tt"] = 0.0
            tp.tt = float(tp.tt) - dtv
            if tp.tt <= 0.0: tp.tt = 0.3; tp.trail.append({"p": tp.pos, "t": vt, "a": tp.a, "v": float(tp.speed)})
            while tp.trail.size() and vt - float(tp.trail[0].t) > TWAKE_LIFE: tp.trail.pop_front()
        if gone:
            if modern and tp.has("trail") and tp.trail.size() >= 2: twakes.append(tp.trail)   # it fades where it lies
            torps.remove_at(i)
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
            if m.kind == "sam": alive = (tg is Dictionary and ((tg.has("n") and tg.up > 0) or (tg.get("kind", "") == "ssm" and not tg.get("dead", false))))
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
                    else: m.target.n = maxi(0, int(m.target.n) - mini(2, int(m.target.up))); fx_plane_down(tpos, Vector2.from_angle(float(m.target.get("a", 0.0))) * (220.0 if m.target.get("jet", false) else 75.0) * 0.6, bool(m.target.get("jet", false)), int(m.target.get("side", 0)))   # only machines in the air can be hit
                part(P.FLAK, m.pos, 0.5, 14.0); missiles.remove_at(i); continue
            if m.kind == "ssm" and d < maxf(20.0, m.target.d.B) and m.target.tech.has("ecm") and not m.get("ecm_tried", false):
                m.ecm_tried = true
                if randf() < 0.25 + 0.08 * tech_up(m.target.tech, "ecm"):   # electronic countermeasures: the seeker is decoyed and the missile runs on into the sea
                    fx_splash(m.pos + Vector2.from_angle(m.a) * 80.0, 14.0); missiles.remove_at(i); continue
            if m.kind == "ssm" and d < maxf(20.0, m.target.d.B):
                mark_hit(m.target, m.pos, 4.0, false); mark_hit(m.target, m.pos, 3.0, false); hit_systems(m.target, m.pos, m.dmg, "missile"); damage(m.target, m.dmg, "missile")
                fx_boom(m.pos, 40.0, 0.9); part(P.FIRE, m.pos, 2.0, 12.0); sound("hit_big", m.pos, 0.55); missiles.remove_at(i); continue
        m.pos += Vector2.from_angle(m.a) * m.v * dt
        if modern:   # smoke laid every few metres of flight, so the trail is one unbroken line however fast she flies
            var step_m: float = m.v * dt; var n_p := clampi(int(ceil(step_m / (8.0 if fx_far else 3.5))), 1, 12); var back_v: Vector2 = Vector2.from_angle(m.a)
            for k in n_p:
                var tp = part(P.MTRAIL, m.pos - back_v * (6.0 + step_m * k / n_p) + Vector2(randf() - 0.5, randf() - 0.5) * 2.0, (1.1 if m.kind == "sam" else 2.0) + randf() * 0.5, (3.6 + randf() * 1.5) * (1.3 if fx_far else 1.0), Vector2.ZERO, true)
                tp.a = randf() * TAU
        elif randf() < dtv * 30: part(P.MTRAIL, m.pos, 1.0 if m.kind == "sam" else 2.0, 4.0)
        if m.age < 1.6: # the booster burning: flame at the tail, darker smoke mixed into the trail
            part(P.FIRE, m.pos - Vector2.from_angle(m.a) * 2.0, 0.12, 2.5 if m.kind == "ssm" else 1.6)
            if randf() < dtv * 10: part(P.SMOKE, m.pos - Vector2.from_angle(m.a) * 4.0, 2.5, 3.0, Vector2.ZERO, true)
        if m.life <= 0:
            if m.kind == "ssm": fx_splash(m.pos, 14.0)
            missiles.remove_at(i)
    update_air(dt)
    _spotters(dt)
    for i in range(dcs.size() - 1, -1, -1):
        var q = dcs[i]
        if q.has("rel"):   # still aboard: it goes over the stern (or out from a thrower) when its turn comes
            q.rel -= dt
            if q.rel > 0.0: continue
            var sh: CShip = q.ship
            if sh == null or not sh.alive: dcs.remove_at(i); continue
            q.pos = world_pt(sh, -sh.d.L / 2, float(q.lat)); q.t = DC_SINK * (0.92 + randf() * 0.16); q.erase("rel"); q["src"] = sh; q.erase("ship")
            var plop = part(P.FOAM, q.pos, 3.0, 5.0)   # the small splash as it goes in
            var b = part(P.DC, q.pos, 1.4, 24.0); b.life = -float(q.t) / BT; b.side = q.side   # the burst, drawn when it comes
            continue
        q.t -= dt
        if q.t > 0: continue
        dcs.remove_at(i); sound("depth", q.pos, 0.3)
        if modern:   # spray flung out of the dome, a ring across the water, and the foam it leaves
            for j in 9:
                var sp = part(P.SPRAY, q.pos + rdir() * 8.0, 0.8 + randf() * 0.9, 7.0 + randf() * 6.0, rdir() * (40.0 + randf() * 110.0)); sp.drag = 0.2
            part(P.WRING, q.pos, 2.2, 90.0); var fm = part(P.WASH if modern else P.FOAM, q.pos, 18.0, 40.0 if modern else 55.0); fm.a = randf() * TAU; fm.spin = (randf() - 0.5) * 0.08
        for s in ships:
            # the nearer the burst the worse: the full blow inside DC_CLOSE, falling away to nothing at DC_HIT (every burst
            # inside 60 m used to do the full damage, which mattered little while the patterns fell wide). Any boat, and any
            # hull close over the burst, whatever her flag: the dropper's own side and the dropper herself (dc_harm)
            if not active(s): continue
            var hd := dc_harm(s, q.pos)
            if hd <= 0.0: continue
            if s.side == q.side: _log("depth charge on a friend"); ff_dmg_dc += hd
            else: _log("depth charge hit")
            damage(s, hd, "dc")
            if s.sub: s.reveal_t = 30.0
    # end of the action: one side gone, or fifteen battle minutes without a hit and nothing in flight
    var mine = 0; var theirs = 0
    for s in ships:
        if engageable(s):
            if s.side == 0: mine += 1
            else: theirs += 1
    var quiet = t - last_hit > 900 and shells.is_empty() and torps.is_empty() and missiles.is_empty() and air.is_empty()
    if (mine == 0 or theirs == 0 or quiet) and not editor:
        end_t += dtv / BT
        if not end_msg:
            end_msg = true; say("The enemy is beaten!" if theirs == 0 else ("Contact lost." if mine and theirs else "Action over."), 3.0)
        # the action is not called over while a ship is still going down: the last one to sink is seen to sink
        # (the report used to come up 2.5 s after she was hit, and froze her a quarter of the way under)
        var going := false
        for s in ships: if not s.alive and sink_k(s) < 1.0: going = true; break
        if end_t > 2.5 and (not going or end_t > 25.0): _finish()

func trail_point(s: CShip) -> Dictionary:
    var sx: float = s.d.L * 0.3; var sy = hull_half(s.d, sx)
    return {"p": world_pt(s, -s.d.L * 0.47, 0), "l": world_pt(s, sx, -sy), "r": world_pt(s, sx, sy), "a": s.a, "t": vt, "v": s.v, "sm": submerged(s)}

## Visual effects advance once per frame, in visual seconds.
func fx(dtv: float) -> void:
    _scars_fx(dtv)
    _falling(dtv)
    _wrecks(dtv)
    if modern:   # a badly hurt ship trails oil, and one sinking leaves her boats, rafts and wreckage on the water
        for s in ships:
            if s.alive and not s.escaped and s.hull / s.max_hull < 0.35 and s.v > 1.0 and randf() < dtv * 0.8: part(P.OIL, s.pos - Vector2.from_angle(s.a) * s.d.L * 0.3, 26.0, s.d.B * (0.8 + randf() * 0.8))
            if not s.alive and sink_k(s) < 0.8 and randf() < dtv * 1.6: wreckage(s, s.pos + Vector2((randf() - 0.5) * s.d.L * 0.7, (randf() - 0.5) * s.d.B).rotated(s.a), 1, 2.0)
    for i in range(parts.size() - 1, -1, -1):
        var q = parts[i]; q.life += dtv
        if q.wind and q.life > 0: q.pos += WIND * dtv
        if q.vel != Vector2.ZERO:
            q.pos += q.vel * dtv; q.vel *= pow(q.drag, dtv)
        if q.spin != 0.0: q.a += q.spin * dtv
        if q.t == P.DEBRIS and q.spin != 0.0 and q.life > 0.0 and randf() < dtv * 22.0:   # a burning fragment leaves a thread of smoke
            var tr = part(P.SMOKE, q.pos, 0.9 + randf() * 0.8, q.size * (1.2 + randf()), q.vel * 0.05, true); tr.a = randf() * TAU
        if q.life >= q.mx:
            parts.remove_at(i)
            if q.t == P.COLUMN: splash_cols.erase(q)
            elif q.t == P.LACE: splash_laces.erase(q)
    flash = maxf(0.0, flash - dtv * 1.4)
    if parts.size() > 3200:
        parts.reverse(); parts.resize(3200); parts.reverse()
        splash_cols = splash_cols.filter(func(q): return parts.has(q)); splash_laces = splash_laces.filter(func(q): return parts.has(q))   # (the oldest dropped: not left frozen in these)
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
