extends Node2D
## The battle screen: builds the scene, feeds input to the simulation, and draws it. Drawing is split across layers so
## that wakes and spray sit under ships, smoke drifts over them, and flashes and fires add light.

const Sim := preload("res://scripts/battle_sim.gd")
const HUD := preload("res://scripts/battle_hud.gd")
const P := BattleSim.P

var sim: BattleSim
var speeds = [0.5, 1.0, 2.0, 4.0, 8.0]
var speed_i = 1
var paused = false
var cam_free = false
var drag = {}
var world: Node2D
var camera: Camera2D
var water: ColorRect
var water_mat: ShaderMaterial
var layers = {}
var hud: Control
var views: Array = []
var light_shader: Shader = preload("res://shaders/ship_light.gdshader")

func _ready() -> void:
    var cfg: Dictionary = GameData.pending
    sim = BattleSim.new()
    sim.on_boom = _boom
    var pt: Array = cfg.get("player_tech", []); var et: Array = cfg.get("enemy_tech", [])
    var mine: Array = cfg.get("player", ["dd_fletcher", "dd_fletcher"]); var theirs: Array = cfg.get("enemy", ["dd_narvik", "dd_narvik"])
    var efac: String = cfg.get("enemy_fac", "directorate")
    sim.setup(_recs(mine, "player", pt), _recs(theirs, efac, et), pt, et, cfg.get("islands", randi_range(0, 4)))
    # sea
    var bg = CanvasLayer.new(); bg.layer = -10; add_child(bg)
    water = ColorRect.new(); water.set_anchors_preset(Control.PRESET_FULL_RECT); water.mouse_filter = Control.MOUSE_FILTER_IGNORE
    water_mat = ShaderMaterial.new(); water_mat.shader = preload("res://shaders/water.gdshader"); water.material = water_mat; bg.add_child(water)
    # world layers, bottom to top
    world = Node2D.new(); world.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; add_child(world)
    for n in ["islands", "below", "shadows", "ships", "above", "light", "overlay"]:
        var node: Node2D
        if n == "ships": node = Node2D.new()
        else: node = Drawer.new(); node.battle = self; node.kind = n
        if n == "light": var mat = CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; node.material = mat
        world.add_child(node); layers[n] = node
    for s in sim.ships: _add_view(s)
    camera = Camera2D.new(); world.add_child(camera); camera.make_current()
    camera.zoom = Vector2.ONE * clampf(minf(get_viewport_rect().size.x, get_viewport_rect().size.y) / 3200.0, 0.14, 0.4)
    camera.position = sim.flag.pos
    var hl = CanvasLayer.new(); hl.layer = 10; add_child(hl)
    hud = HUD.new(); hud.battle = self; hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; hl.add_child(hud)

func _recs(ids: Array, pal: String, tech: Array) -> Array:
    var out = []; var pool: Array = GameData.names.get(pal, GameData.names.player).duplicate(); pool.shuffle()
    for i in ids.size():
        var d: Dictionary = GameData.hulls[ids[i]]
        out.append({"type": ids[i], "name": pool[i % pool.size()], "hullFrac": 1.0, "fit": BattleSim.default_fit(d, tech), "pal": pal})
    return out

func _add_view(s: BattleSim.CShip) -> void:
    var v = ShipView.new(); v.battle = self; v.s = s; layers.ships.add_child(v); v.build(); s.view = v; views.append(v)

func _boom(p: Vector2, vol: float, freq: float, rate: float) -> void:
    var d = p.distance_to(camera.position) * camera.zoom.x
    Sfx.boom(vol * clampf(1.0 - d / 1400.0, 0.0, 1.0), freq, rate)

func zoom() -> float: return camera.zoom.x
func combat_speed() -> float: return speeds[speed_i]

# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
    var dt = minf(delta, 0.05)
    sim.msg_t -= dt # messages fade on the real clock, whatever the battle speed
    sim.mouse_world = world.get_global_mouse_position()
    var r = 0.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): r -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): r += 1.0
    sim.player_rudder = r
    if not paused and not sim.finished:
        var cs = combat_speed(); var n = maxi(1, int(round(cs))); var v = dt * minf(1.0, cs)
        var sub = int(ceil(v * BattleSim.BT / 0.04))
        for i in n * sub: sim.step(v / sub)
        sim.fx(dt * cs)
        if sim.flag != null and not cam_free:
            var f = sim.flag; var look = minf(get_viewport_rect().size.x, get_viewport_rect().size.y) * 0.18 / zoom()
            camera.position = camera.position.lerp(f.pos + Vector2.from_angle(f.a) * look, minf(1.0, dt * cs * 1.5))
    if sim.finished and not hud.results_shown: hud.show_results()
    var vs = get_viewport_rect().size
    water_mat.set_shader_parameter("cam", camera.position); water_mat.set_shader_parameter("zoom", zoom())
    water_mat.set_shader_parameter("screen", vs); water_mat.set_shader_parameter("t", sim.t)
    for v in views: v.refresh()
    for n in layers: if layers[n] is Drawer: layers[n].queue_redraw()
    hud.queue_redraw()

# ------------------------------------------------------------------ input
func _unhandled_input(e: InputEvent) -> void:
    if sim.finished: return
    if e is InputEventMouseButton:
        var mb = e as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if mb.pressed:
                var before = world.get_global_mouse_position()
                var z = clampf(zoom() * (1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.12), 0.035, 2.5)
                camera.zoom = Vector2(z, z); camera.force_update_scroll()
                if cam_free: camera.position += before - world.get_global_mouse_position()
            return
        if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
            if mb.pressed: drag = {"at": mb.position, "cam": camera.position, "moved": false, "btn": mb.button_index}
            else:
                if not drag.is_empty() and not drag.moved and drag.btn == MOUSE_BUTTON_RIGHT:
                    if not _lock_at_mouse() and (sim.lock != null or sim.autofire): sim.lock = null; sim.autofire = false; sim.say("Check fire.", 1.4)
                drag = {}
            return
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                if not _lock_at_mouse(): sim.mouse_down = true # click an enemy to engage it; hold on open water to fire there
            else: sim.mouse_down = false
    elif e is InputEventMouseMotion and not drag.is_empty():
        var mm = e as InputEventMouseMotion; var dlt: Vector2 = mm.position - drag.at
        if not drag.moved and dlt.length() < 6: return
        drag.moved = true; cam_free = true
        camera.position = (drag.cam - dlt / zoom()).clamp(Vector2.ZERO, Vector2(sim.AW, sim.AH))
    elif e is InputEventKey and e.pressed and not e.echo:
        _key(e.keycode)

func _lock_at_mouse() -> bool:
    var m = world.get_global_mouse_position(); var best: BattleSim.CShip = null; var bd = INF
    for o in sim.ships:
        if o.side != 1 or not sim.engageable(o) or not sim.visible_to(o, 0): continue
        var d = o.pos.distance_to(m)
        if d < maxf(30.0 / zoom(), o.d.L * 0.6) and d < bd: bd = d; best = o
    if best != null: sim.lock = best; sim.autofire = true; sim.say("Main battery: engage " + best.rec.name + "!", 1.6)
    return best != null

func _key(k: int) -> void:
    var s = sim.flag
    match k:
        KEY_W, KEY_UP: if s: s.throttle = mini(4, s.throttle + 1)
        KEY_S, KEY_DOWN: if s: s.throttle = maxi(0, s.throttle - 1)
        KEY_T:
            sim.want_torp = true
            if s and not sim.has_kind(s, "torp"): sim.say("No torpedo tubes on this ship.", 1.2)
        KEY_Q:
            sim.want_msl = true
            if s and not sim.has_kind(s, "ssm"): sim.say("No missile launchers on this ship.", 1.2)
        KEY_F:
            if s:
                if s.squads.is_empty(): sim.say("This ship carries no aircraft.", 1.2)
                else:
                    var tg: BattleSim.CShip = sim.lock if (sim.lock != null and sim.engageable(sim.lock)) else sim.nearest_enemy(sim.mouse_world, 0, INF, func(o): return not sim.submerged(o))
                    if not sim.launch_strike(s, tg): sim.say("No squadrons ready.", 1.2)
        KEY_C:
            if s and s.sub: s.want_dive = not s.want_dive; sim.say("Dive, dive, dive!" if s.want_dive else "Surfacing.", 1.2)
        KEY_X:
            sim.autofire = not sim.autofire
            sim.say("Main-gun autofire " + ("on" if sim.autofire else "off") + (". Lock a target first." if sim.autofire and sim.lock == null else ""), 1.5)
        KEY_1: sim.order = "engage"; sim.say("All ships: engage.", 1.5)
        KEY_2: sim.order = "escort"; sim.say("All ships: form on the flagship.", 1.5)
        KEY_3: sim.order = "retreat"; sim.say("All ships withdraw! Open the range and break contact.", 2.5)
        KEY_P, KEY_ESCAPE: paused = not paused
        KEY_SPACE, KEY_HOME: cam_free = false; sim.say("Camera on the " + (s.rec.name if s else "flagship") + ".", 1.0)
        KEY_EQUAL, KEY_KP_ADD, KEY_PERIOD: speed_i = mini(speeds.size() - 1, speed_i + 1); sim.say("Time ×" + str(int(combat_speed() * BattleSim.BT)), 1.0)
        KEY_MINUS, KEY_KP_SUBTRACT, KEY_COMMA: speed_i = maxi(0, speed_i - 1); sim.say("Time ×" + str(int(combat_speed() * BattleSim.BT)) + (" (real time)" if combat_speed() < 1 else ""), 1.0)
        KEY_TAB:
            var mine: Array = []
            for x in sim.ships: if x.side == 0 and sim.engageable(x): mine.append(x)
            if mine.size() > 1: sim.flag = mine[(mine.find(sim.flag) + 1) % mine.size()]; sim.say("You take command of the " + sim.flag.rec.name + ".", 1.5)
        KEY_M: Sfx.muted = not Sfx.muted

# ================================================================== ship view
class ShipView extends Node2D:
    var battle
    var s: BattleSim.CShip
    var base: Sprite2D
    var top: Sprite2D
    var top_sh: Sprite2D
    var detail: Node2D
    var lit_base: ShaderMaterial
    var lit_top: ShaderMaterial
    var spr = 1.0
    var size_m = Vector2.ONE

    func build() -> void:
        var id: String = s.rec.type; var info: Dictionary = GameData.sprites.ships[id]
        spr = info.spr; size_m = Vector2(info.w, info.h)
        base = _sprite(GameData.ship_tex(id, s.pal, "base"), 1.0 / spr)
        lit_base = ShaderMaterial.new(); lit_base.shader = battle.light_shader; base.material = lit_base
        detail = Detail.new(); detail.view = self; detail.scale = Vector2(spr, spr); base.add_child(detail)
        base.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # soot and holes stay on the hull
        top_sh = _sprite(GameData.ship_tex(id, s.pal, "top_shadow"), 3.0 / spr); top_sh.modulate = Color(1, 1, 1, 0.5)
        top = _sprite(GameData.ship_tex(id, s.pal, "top"), 1.0 / spr)
        lit_top = ShaderMaterial.new(); lit_top.shader = battle.light_shader; top.material = lit_top
        var mounts = Mounts.new(); mounts.view = self; add_child(mounts)
        var fires = Fires.new(); fires.view = self; var mat = CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; fires.material = mat; add_child(fires)
        for m in [lit_base, lit_top]:
            m.set_shader_parameter("size_m", size_m); m.set_shader_parameter("beam", float(s.d.B))

    func _sprite(t: Texture2D, sc: float) -> Sprite2D:
        var sp = Sprite2D.new(); sp.texture = t; sp.scale = Vector2(sc, sc); add_child(sp); return sp

    func refresh() -> void:
        var sm = s.dive if s.sub else 0.0
        var alpha = 1.0; var k = 0.0
        if not s.alive: k = minf(1.0, s.sink / 4.0); alpha = 1.0 - k
        elif sm > 0: alpha = 1.0 - 0.65 * sm
        visible = alpha > 0.02 and not s.escaped and (s.side == 0 or not s.sub or s.dive < 0.3 or battle.sim.detected_by(s, 0) or not s.alive)
        position = s.pos; rotation = s.a + k * 0.25; scale = Vector2.ONE * (1.0 - 0.2 * k); modulate.a = alpha
        var sun_local = BattleSim.SUN.rotated(-s.a)
        var hgt: float = 6.0 if s.d.kind == "carrier" else clampf(s.d.B * 0.22, 1.2, 7.0)
        top_sh.position = sun_local * hgt
        var soot = clampf((1.0 - s.hull / s.max_hull - 0.25) * 1.4, 0.0, 1.0)
        for m in [lit_base, lit_top]: m.set_shader_parameter("sun_local", sun_local); m.set_shader_parameter("soot", soot)
        for c in get_children(): if c is Node2D and not (c is Sprite2D): c.queue_redraw()
        detail.queue_redraw()

class Detail extends Node2D:   # soot and shell holes, kept where they struck
    var view
    func _draw() -> void:
        var s: BattleSim.CShip = view.s
        if s.marks.is_empty() or view.battle.zoom() * s.d.L < 25: return
        for m in s.marks:
            var tx = GameData.fx_tex("cloud%d" % m.v); var r: float = m.r
            draw_texture_rect(tx, Rect2(m.x - r, m.y - r, 2 * r, 2 * r), false, Color(0.09, 0.07, 0.05, 0.45))
            if m.hole: draw_circle(Vector2(m.x, m.y), r * 0.22, Color(0.04, 0.04, 0.04, 0.9))

class Mounts extends Node2D:   # turrets, with their shadows cast in the world's light direction
    var view
    func _draw() -> void:
        var s: BattleSim.CShip = view.s
        if (s.sub and s.dive > 0.1) or view.battle.zoom() * s.d.L < 30: return
        var off = BattleSim.SUN.rotated(-s.a) * 1.4
        for pass_ in [1, 0]:
            for m in s.mounts:
                if m.w.kind == "ssm" or m.w.kind == "sam": continue
                if s.sub and m.w.kind == "torp": continue
                var info: Dictionary = GameData.sprites.mounts.get(m.wid, {})
                if info.is_empty(): continue
                var tx = GameData.mount_tex(m.wid, "shadow" if pass_ == 1 else s.pal)
                var sc: float = 1.0 / info.spr
                var p = Vector2(m.slot.x, m.slot.y) + (off if pass_ == 1 else Vector2.ZERO)
                var recoil = -Vector2.from_angle(m.ta) * m.recoil * (m.w.get("bl", 0.0) * 0.12)
                draw_set_transform(p + (recoil if pass_ == 0 else Vector2.ZERO), m.ta, Vector2(sc, sc))
                draw_texture(tx, -Vector2(info.ox, info.oy) * info.spr, Color(0.3, 0.27, 0.25) if m.dead else Color.WHITE)
        draw_set_transform(Vector2.ZERO)
        if s.struck: draw_rect(Rect2(-s.d.L / 2 - 6, -2, 5, 4), Color(0.91, 0.91, 0.88))

class Fires extends Node2D:
    var view
    func _draw() -> void:
        var s: BattleSim.CShip = view.s; var z: float = view.battle.zoom(); var tn = Time.get_ticks_msec() / 1000.0
        var puff = GameData.fx_tex("puff")
        for f in s.fires:
            var fl = 0.7 + 0.3 * sin(tn * 23 + f.x * 3) * sin(tn * 9 + f.y)
            var r1 = maxf(f.r * 2.2, 2.0 / z); var r2 = maxf(f.r * 0.9, 1.0 / z)
            draw_texture_rect(puff, Rect2(f.x - r1, f.y - r1, 2 * r1, 2 * r1), false, Color(1, 0.43, 0.12, 0.55 * fl))
            draw_texture_rect(puff, Rect2(f.x - r2, f.y - r2, 2 * r2, 2 * r2), false, Color(1, 0.78, 0.47, 0.8 * fl))

# ================================================================== world layers
class Drawer extends Node2D:
    var battle
    var kind = ""
    func _draw() -> void:
        match kind:
            "islands": _islands()
            "below": _wakes(); _parts(0)
            "shadows": _shadows()
            "above": _parts(1)
            "light": _parts(2)
            "overlay": _overlay()

    func _puff(tex: Texture2D, p: Vector2, r: float, c: Color) -> void:
        if c.a <= 0.01 or r * battle.zoom() < 0.6: return
        draw_texture_rect(tex, Rect2(p.x - r, p.y - r, 2 * r, 2 * r), false, c)

    func _islands() -> void:
        var sim: BattleSim = battle.sim
        for is_ in sim.islands:
            for layer in [[1.0, 26.0, Color(0.31, 0.59, 0.59, 0.18)], [1.0, 10.0, Color(0.39, 0.67, 0.63, 0.22)], [1.0, 0.0, Color("#c2ad7d")], [0.84, 0.0, Color("#56703f")], [0.52, 0.0, Color("#455d34")], [0.24, 0.0, Color("#6c6a52")]]:
                var pts = PackedVector2Array(); var n: int = is_.rad.size()
                for i in n:
                    var a = i / float(n) * TAU; pts.append(is_.c + Vector2.from_angle(a) * (is_.rad[i] * layer[0] + layer[1]))
                draw_colored_polygon(pts, layer[2])

    # Wakes: overlapping soft foam stamps. The churned band starts the width of the stern and spreads; the bow wave
    # hugs the forward hull and runs on into the Kelvin arms, which open at about 19.5 degrees to the track.
    func _wakes() -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom(); var foam = GameData.fx_tex("foam"); var now = sim.vt
        var min_step = 2.2 / z
        for s in sim.ships:
            if s.trail.size() < 2: continue
            if s.sub and s.side == 1 and not sim.detected_by(s, 0): continue
            var pts: Array = []
            if sim.active(s): pts.append(sim.trail_point(s))
            for i in range(s.trail.size() - 1, -1, -1): pts.append(s.trail[i])
            pts = pts.filter(func(q): return not q.sm)
            if pts.size() < 2: continue
            var B: float = s.d.B; var strength = clampf(pts[0].v / 10.0, 0.1, 1.0)
            _walk(pts, func(q): return q.p, func(age): return B * (0.42 + age * 0.06), 0.3 * strength, foam, now, min_step)
            for side in ["l", "r"]:
                var sd = -1.0 if side == "l" else 1.0
                _walk(pts, func(q): return q[side] + Vector2(-sin(q.a), cos(q.a)) * sd * (now - q.t) * q.v * BattleSim.BT * 0.354, func(age): return B * 0.1 + age * 0.9, 0.17 * strength, foam, now, min_step)
            if sim.active(s) and not sim.submerged(s):
                var sk = clampf(s.v / (s.d.kn * BattleSim.KN), 0.0, 1.0); var x: float = s.d.L / 2
                while x > s.d.L * 0.3:
                    for sd in [-1.0, 1.0]:
                        var q = sim.world_pt(s, x, sd * (sim.hull_half(s.d, x) + B * 0.06 * sk))
                        var r = maxf(B * (0.1 + 0.1 * sk), min_step * 0.6)
                        _puff(foam, q, r, Color(1, 1, 1, 0.4 * sk))
                    x -= maxf(B * 0.18, min_step * 0.5)

    func _walk(pts: Array, get: Callable, rad: Callable, alp: float, foam: Texture2D, now: float, min_step: float) -> void:
        for i in pts.size() - 1:
            var p0: Dictionary = pts[i]; var p1: Dictionary = pts[i + 1]
            var x0: Vector2 = get.call(p0); var x1: Vector2 = get.call(p1); var len = x0.distance_to(x1)
            var a0: float = now - p0.t; var a1: float = now - p1.t
            var r0: float = rad.call(a0); var stp = maxf(r0 * 0.4, min_step * 0.5); var n = maxi(1, int(ceil(len / stp)))
            for k in n:
                var f = float(k) / n; var age = lerpf(a0, a1, f)
                if age > 18.0: return
                var r = maxf(rad.call(age), min_step * 0.6)
                _puff(foam, x0.lerp(x1, f), r, Color(1, 1, 1, alp * pow(1.0 - age / 18.0, 1.4) * minf(1.0, 1.6 * stp / maxf(r, 1.0))))

    func _shadows() -> void:  # hull shadows on the water, offset in world space by the height of the deck edge
        var sim: BattleSim = battle.sim
        for s in sim.ships:
            if s.escaped or (s.sub and s.dive > 0.05) or (not s.alive and s.sink > 4): continue
            var info: Dictionary = GameData.sprites.ships[s.rec.type]; var tx = GameData.ship_tex(s.rec.type, s.pal, "hull_shadow")
            var fb: float = 0.6 if s.d.kind == "sub" else (10.0 if s.d.kind == "carrier" else clampf(s.d.B * 0.25, 1.2, 8.0))
            var k = minf(1.0, s.sink / 4.0) if not s.alive else 0.0
            draw_set_transform(s.pos + BattleSim.SUN * fb, s.a + k * 0.25, Vector2.ONE * 3.0 / info.spr)
            draw_texture(tx, -tx.get_size() / 2, Color(1, 1, 1, 0.38 * (1.0 - k)))
        draw_set_transform(Vector2.ZERO)

    func _parts(layer: int) -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom(); var mn = 1.0 / z
        var vr: Rect2 = battle.view_rect().grow(300)
        var puff = GameData.fx_tex("puff"); var foam = GameData.fx_tex("foam")
        var clouds = [GameData.fx_tex("cloud0"), GameData.fx_tex("cloud1"), GameData.fx_tex("cloud2"), GameData.fx_tex("cloud3")]
        var tn = Time.get_ticks_msec() / 1000.0
        for q in sim.parts:
            if q.life < 0 or not vr.has_point(q.pos): continue
            var k = q.life / q.mx; var cl: Texture2D = clouds[q.v]
            if layer == 0:
                match q.t:
                    P.FOAM: if z >= 0.12: _puff(cl, q.pos, q.size * (1 + k), Color(0.86, 0.93, 0.93, 0.3 * (1 - k)))
                    P.OIL: _puff(cl, q.pos, q.size * (0.6 + k * 0.8), Color(0.05, 0.06, 0.07, 0.45 * (1 - k * k)))
                    P.SWAKE: draw_arc(q.pos, q.size * (1 + k * 2), 0, TAU, 24, Color(0.88, 0.94, 0.94, 0.12 * (1 - k)), maxf(mn, 1.5))
                    P.TWAKE: _puff(puff, q.pos, maxf(q.size * (1 + k * 3), 1.2 * mn), Color(0.92, 0.96, 0.96, 0.5 * (1 - k)))
                    P.SPLASH, P.GEYSER:
                        var r = maxf(q.size, 2 * mn)
                        _puff(puff, q.pos, r * (0.5 + 0.9 * sqrt(k)), Color(0.97, 0.99, 0.99, 0.95 * (1 - k) * (1 - k)))
                        draw_arc(q.pos, r * (0.4 + k * 1.6), 0, TAU, 32, Color(0.92, 0.97, 0.97, 0.6 * (1 - k)), maxf(mn, r * 0.08))
                    P.BLAST:
                        draw_arc(q.pos, q.size * (0.3 + k), 0, TAU, 32, Color(0.88, 0.93, 0.93, 0.45 * (1 - k)), maxf(mn, q.size * 0.1 * (1 - k)))
                        _puff(puff, q.pos, q.size * (0.3 + k * 0.8), Color(0.82, 0.89, 0.9, 0.25 * (1 - k)))
                    P.DC: _puff(puff, q.pos, q.size * (0.5 + k * 1.2), Color(0.96, 0.98, 0.98, 0.9 * (1 - k)))
            elif layer == 1:
                match q.t:
                    P.SMOKE: _puff(cl, q.pos, q.size * (1 + k * 2.2), Color(0.24, 0.24, 0.25, 0.5 * (1 - k) * minf(1.0, q.life * 4)))
                    P.GUNSMOKE: _puff(cl, q.pos, q.size * (1 + sqrt(k) * 3.2), Color(0.13, 0.12, 0.11, 0.72 * minf(1.0, q.life * 6) * pow(1 - k, 1.3)))
                    P.FUNNEL: _puff(cl, q.pos, q.size * (1 + k * 2), Color(0.32, 0.32, 0.34, 0.2 * (1 - k)))
                    P.DUST: _puff(cl, q.pos, q.size * (1 + k), Color(0.72, 0.64, 0.49, 0.6 * (1 - k)))
                    P.FLAK: _puff(cl, q.pos, maxf(q.size, 2 * mn) * (0.5 + k), Color(0.13, 0.13, 0.13, 0.75 * (1 - k)))
                    P.MTRAIL: _puff(cl, q.pos, maxf(q.size, 1.2 * mn) * (1 + k * 2), Color(0.9, 0.9, 0.89, 0.5 * (1 - k)))
            else:
                match q.t:
                    P.FLASH:
                        var r = maxf(q.size, 5 * mn); var e = 1.0 - k * k
                        draw_set_transform(q.pos, q.a)
                        _puff(puff, Vector2(r * 0.4, 0), r * (1.1 + k * 0.8), Color(1, 0.67, 0.27, 0.9 * e))
                        draw_set_transform(q.pos, q.a, Vector2(2.6, 1))
                        _puff(puff, Vector2(r * 0.45 / 2.6, 0), r * (0.7 + k * 0.4) / 1.0, Color(1, 0.8, 0.47, e))
                        draw_set_transform(q.pos, q.a)
                        for sd in [-1.0, 1.0]: _puff(puff, Vector2(r * 0.15, sd * r * 0.75), r * 0.6, Color(1, 0.59, 0.24, 0.75 * e))
                        _puff(puff, Vector2(r * 0.25, 0), r * 0.5 * (1 - k), Color(1, 0.99, 0.92, 1 - k))
                        draw_set_transform(Vector2.ZERO)
                    P.BOOM:
                        var r = maxf(q.size, 4 * mn)
                        _puff(puff, q.pos, r * (0.5 + k * 0.9), Color(1, 0.59, 0.2, 1 - k)); _puff(puff, q.pos, r * 0.45 * (1 - k), Color(1, 0.92, 0.75, 1 - k))
                    P.FIRE: _puff(puff, q.pos, maxf(q.size, 1.5 * mn) * (1 - k * 0.4), Color(1, 0.47, 0.12, 0.9 * (1 - k) * (0.75 + 0.25 * sin(tn * 31 + q.pos.x))))
                    P.SPARK: _puff(puff, q.pos, maxf(q.size, 0.8 * mn) * (1 - k * 0.5), Color(1, 0.75, 0.35, 1 - k))
                    P.FALL: _puff(puff, q.pos + Vector2(0, k * 20), maxf(q.size, mn) * (1 - k * 0.5), Color(1, 0.55, 0.2, 1 - k))

    func _overlay() -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom(); var mn = 1.0 / z
        # torpedo tracks, shells, missiles, aircraft and tracers
        for tp in sim.torps:
            var vis: bool = tp.side == 0 or tp.arm < -20 or (sim.flag != null and tp.pos.distance_to(sim.flag.pos) < 2500)
            if not vis: continue
            var tl = maxf(8.0, 10.0 * mn)
            draw_line(tp.pos, tp.pos - Vector2.from_angle(tp.a) * tl, Color(1, 0.67, 0.59, 0.9) if tp.side else Color(0.94, 0.98, 0.98, 0.9), maxf(2 * mn, 0.6))
        for sh in sim.shells:
            var k: float = sh.t / sh.T; var hgt = sin(PI * k) * minf(600.0, sh.s.distance_to(sh.e) * 0.08)
            var r = maxf(1.2 * mn, {"S": 1.6, "M": 2.0, "L": 2.6, "H": 3.4}[sh.size])
            draw_circle(sh.pos, r * 0.8, Color(0, 0, 0, 0.25))
            draw_circle(sh.pos - Vector2(0, hgt), r, Color("#ffb38a") if sh.side else Color("#fff1c0"))
        for m in sim.missiles:
            if m.delay > 0: continue
            var ms = maxf(1.0, 1.5 * mn)
            draw_set_transform(m.pos, m.a, Vector2(ms, ms))
            draw_rect(Rect2(-5, -1.3, 10, 2.6), Color("#dfe4e2") if m.kind == "sam" else (Color("#ffb38a") if m.side else Color("#fff1c0")))
            draw_circle(Vector2(-6, 0), 2.2, Color(1, 0.78, 0.35, 0.9))
        draw_set_transform(Vector2.ZERO)
        for q in sim.air:
            var col = Color("#e8a08a") if q.side else Color("#f3e2a8"); var ps = maxf(1.0, 1.6 * mn)
            for k in int(q.n):
                var row = ceili(k / 2.0); var sd = 1.0 if k % 2 else -1.0
                var p: Vector2 = q.pos + Vector2(-row * 14 * ps, sd * row * 12 * ps).rotated(q.a)
                draw_set_transform(p, q.a, Vector2(ps, ps))
                if q.jet: draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(-5, -6), Vector2(-3, 0), Vector2(-5, 6)]), col)
                else: draw_rect(Rect2(-5, -1, 11, 2), col); draw_rect(Rect2(0, -7, 2.5, 14), col); draw_rect(Rect2(-5, -3, 1.5, 6), col)
        draw_set_transform(Vector2.ZERO)
        for tr in sim.tracers: draw_line(tr.a, tr.b, Color(1, 0.86, 0.55, tr.life * 6), mn)
        # flagship: station ring, gun range, predicted track and where each main turret is laid
        var s = sim.flag
        if s != null and s.alive:
            var gold = Color(0.89, 0.7, 0.24)
            _dashed_circle(s.pos, maxf(s.d.L * 0.6 + 10, 24 * mn), Color(gold, 0.55), 1.5 * mn, 8 * mn)
            draw_arc(s.pos, sim.max_gun_range(s), 0, TAU, 128, Color(gold, 0.18), mn)
            var pp = s.pos; var pa = s.a; var pw = s.w; var pr = s.rud; var track = PackedVector2Array([pp])
            for i in 30:
                var dd = 2.0
                pr += clampf(s.rudder - pr, -dd / 10, dd / 10); pw += (pr * s.v / (s.d.td / 2) - pw) * minf(1.0, dd / sim.yaw_lag(s)); pa += pw * dd
                pp += Vector2.from_angle(pa) * s.v * dd; track.append(pp)
            for i in range(0, track.size() - 1, 2): draw_line(track[i], track[i + 1], Color(gold, 0.35), mn)
            for m in s.mounts:
                if m.w.kind != "gun" or m.w.size != s.main_sz or m.st == "": continue
                var p = sim.world_pt(s, m.slot.x, m.slot.y); var a: float = s.a + m.ta
                var col = Color(0.5, 0.75, 0.56, 0.3) if (m.st == "ready" or m.st == "reload") else (Color(0.89, 0.7, 0.24, 0.3) if m.st == "train" else Color(0.85, 0.38, 0.29, 0.3))
                draw_line(p, p + Vector2.from_angle(a) * sim.gun_range(s, m.w) * 0.5, col, mn)

    func _dashed_circle(c: Vector2, r: float, col: Color, w: float, dash: float) -> void:
        var n = maxi(16, int(TAU * r / (dash * 2)))
        for i in n:
            var a0 = i / float(n) * TAU; var a1 = (i + 0.5) / float(n) * TAU
            draw_arc(c, r, a0, a1, 3, col, w)

func view_rect() -> Rect2:
    var vs = get_viewport_rect().size / zoom()
    return Rect2(camera.position - vs / 2, vs)
