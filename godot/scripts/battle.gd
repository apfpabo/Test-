extends Node2D
## The battle screen: builds the scene, feeds input to the simulation, and draws it. Drawing is split across layers so
## that wakes and spray sit under ships, smoke drifts over them, and flashes and fires add light.

const Sim := preload("res://scripts/battle_sim.gd")
const HUD := preload("res://scripts/battle_hud.gd")
const P := BattleSim.P

var sim: BattleSim
var speeds = [0.5, 1.0, 2.0, 4.0, 8.0, 16.0]   # times BattleSim.BT: real time, x2 ... x32 (owner's request)
var speed_i = 1
var paused = false
var cam_free = false
var sel: Array = []          # ships of yours picked out to be given their own orders (empty: orders go to the whole squadron)
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
    Sfx.music("battle")
    var cfg: Dictionary = GameData.pending
    if Settings.fx_modern and Settings.splash != "classic": GameData.lace_tex(0)   # the new splash's foam, made before the first shell lands
    sim = BattleSim.new(); sim.modern = Settings.fx_modern
    sim.on_boom = _boom
    sim.on_sound = func(kind: String, p: Vector2, vol: float): Sfx.event(kind, vol * _near(p)); if (kind == "gun_H" or kind == "blast") and vol >= 0.4: shake = maxf(shake, vol * _near(p) * _near(p) * 6.0)
    sim.on_pop = func(p: Vector2, vol: float, wid: String): Sfx.auto_fire(wid, vol * _near(p))
    var pt: Array = cfg.get("player_tech", []); var et: Array = cfg.get("enemy_tech", [])
    var mine: Array = cfg.get("player", ["dd_fletcher", "dd_fletcher"]); var theirs: Array = cfg.get("enemy", ["dd_narvik", "dd_narvik"])
    var efac: String = cfg.get("enemy_fac", "directorate")
    sim.wx = cfg.get("weather", Weather.CLEAR)
    if cfg.has("player_recs"): # a campaign action: your own ships, officers and crew against the fleet you met
        # contact made at missile or carrier reach opens the action at longer range (chart km to battle metres, 1:10)
        sim.sep = clampf(float(cfg.get("range_km", 90)) * 100.0, 9000.0, 18000.0)
        sim.setup(cfg.player_recs, cfg.enemy_recs, pt, et, cfg.get("islands", 1))
        for sh in sim.ships:
            if sh.side == 0:
                sh.cf = cfg.get("crew_frac", 1.0) * (0.7 + 0.3 * Campaign.readiness(sh.rec))   # a tired ship fights as if short-handed
                if cfg.get("no_fuel", false): sh.fuel_k = 0.25   # dry bunkers: emergency reserves give steerage way, little more
                for o in cfg.get("officers", []): if o.ship == sh.rec.id: sh.sk = o.sk; sh.tm = Campaign.temper(o)
            else:
                sh.sk = {"gun": mini(2, int(Campaign.G.day / 80)), "helm": 0, "dc": 0, "ord": 0}
                # their captains have tempers too: a bounty squadron's or a hunter group's are bold, a convoy's escorts careful
                var fk: String = String(Campaign._fleet(cfg.get("fleet_id", -1)).get("kind", "")) if Campaign._fleet(cfg.get("fleet_id", -1)) != null else ""
                sh.tm = Campaign.pick_temper(0.6, 0.1) if (fk == "bounty" or fk == "hunter" or fk == "mission") else (Campaign.pick_temper(0.1, 0.5) if fk == "convoy" else Campaign.pick_temper())
        if cfg.get("no_fuel", false): sim.say("Bunkers are dry: your ships can make steerage way on emergency reserves, little more.", 4.0)
    else:
        sim.setup(_recs(mine, "player", pt), _recs(theirs, efac, et), pt, et, cfg.get("islands", randi_range(0, 4)))
    # sea
    var bg = CanvasLayer.new(); bg.layer = -10; add_child(bg)
    water = ColorRect.new(); water.set_anchors_preset(Control.PRESET_FULL_RECT); water.mouse_filter = Control.MOUSE_FILTER_IGNORE
    water_mat = ShaderMaterial.new(); water_mat.shader = preload("res://shaders/water.gdshader"); water.material = water_mat; bg.add_child(water)
    # world layers, bottom to top
    world = Node2D.new(); world.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; add_child(world)
    for n in ["islands", "wash", "below", "shadows", "ships", "washtop", "bursts", "above", "light", "overlay"]:   # water columns stand above the ships they rise beside: a torpedo's burst goes up over her side, not under her
        var node: Node2D
        if n == "ships": node = Node2D.new()
        else: node = Drawer.new(); node.battle = self; node.kind = n; node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
        if n == "light":   # fire and flashes: their own canvas layer, following the camera, so the darkness of night (CanvasModulate) does not dim them
            var mat = CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; node.material = mat
            var ll := CanvasLayer.new(); ll.layer = 1; ll.follow_viewport_enabled = true; add_child(ll); ll.add_child(node); layers[n] = node; continue
        if n == "overlay":   # range rings and aiming lines stay readable at night too
            var ol := CanvasLayer.new(); ol.layer = 2; ol.follow_viewport_enabled = true; add_child(ol); ol.add_child(node); layers[n] = node; continue
        if n == "washtop": node.material = wash_mat   # the same foam, over the ships, for a burst hard against one
        if n == "wash": wash_mat = ShaderMaterial.new(); wash_mat.shader = preload("res://shaders/wash.gdshader"); wash_mat.set_shader_parameter("sun", BattleSim.SUN.normalized()); node.material = wash_mat
        if n == "bursts": burst_mat = ShaderMaterial.new(); burst_mat.shader = preload("res://shaders/burst.gdshader"); burst_mat.set_shader_parameter("sun", BattleSim.SUN.normalized()); node.material = burst_mat
        world.add_child(node); layers[n] = node
    for is_ in sim.islands: _add_island(is_)
    for s in sim.ships: _add_view(s)
    camera = Camera2D.new(); world.add_child(camera); camera.make_current()
    camera.zoom = Vector2.ONE * clampf(minf(get_viewport_rect().size.x, get_viewport_rect().size.y) / 3200.0, 0.14, 0.4)
    camera.position = sim.flag.pos
    # the light of the hour and the weather over the scene: night and storm darken it, and a veil hides what is out of sight
    cmod = CanvasModulate.new(); add_child(cmod)
    var vl = CanvasLayer.new(); vl.layer = 4; add_child(vl)
    veil = ColorRect.new(); veil.set_anchors_preset(Control.PRESET_FULL_RECT); veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    veil_mat = ShaderMaterial.new(); veil_mat.shader = preload("res://shaders/veil.gdshader"); veil.material = veil_mat; vl.add_child(veil)
    apply_weather()
    if not sim.editor and not GameData.pending.get("quiet", false): Sfx.cue("siren", 0.45)   # battle stations
    var w: Dictionary = sim.wx
    if sim.limited() or w.night or int(w.sea) >= 2 or w.fog:
        sim.say("%s. %s" % [w.text, ("Lookouts see about %.1f km%s." % [float(w.vis) / 1000.0, "; radar ships see farther" if sim.ships.any(func(x): return x.side == 0 and sim.has_radar(x)) else ""]) if sim.limited() else "Gunnery suffers in this sea."], 6.0)
    # bloom over the finished picture (modern effects only), under the HUD
    var bl = CanvasLayer.new(); bl.layer = 5; add_child(bl)
    bloom = ColorRect.new(); bloom.set_anchors_preset(Control.PRESET_FULL_RECT); bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bm := ShaderMaterial.new(); bm.shader = preload("res://shaders/bloom.gdshader"); bloom.material = bm; bl.add_child(bloom)
    var hl = CanvasLayer.new(); hl.layer = 10; add_child(hl)
    hud = HUD.new(); hud.battle = self; hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; hl.add_child(hud)
    if Guide.active() and cfg.has("player_recs") and int(Campaign.G.guide.get("battle", 0)) < Guide.BATTLE.size():   # the guide's first action
        var gd = Guide.new(); gd.host = self; gd.in_battle = true; add_child(gd)
    if cfg.get("editor", false):   # the editor: a panel for staging actions, more paces of time, and an action that never ends by itself
        sim.editor = true; speeds = [0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]; speed_i = 3
        editor = Editor.new(); editor.battle = self; hl.add_child(editor)

const Editor = preload("res://scripts/battle_editor.gd")
const Flags = preload("res://scripts/flags.gd")
const Guide = preload("res://scripts/guide.gd")
const PlaneArt = preload("res://scripts/plane_art.gd")
var editor = null           # the editor's panel, in editor mode
var clean := false          # H: nothing on the screen but the picture (for recording)
## Hide or show everything that is not the picture: the HUD, the rings and aiming lines, the editor's panel.
func set_clean(on: bool) -> void:
    clean = on; hud.visible = not on   # (the overlay layer stays: shells, missiles, aircraft and tracer are drawn in it; only its rings and lines go)
    if editor != null: editor.visible = not on
func remove_view(s: BattleSim.CShip) -> void:
    var v = s.view
    if v != null and is_instance_valid(v): views.erase(v); v.queue_free()
    s.view = null
func rebuild_view(s: BattleSim.CShip) -> void:
    remove_view(s); _add_view(s)
var cmod: CanvasModulate
## The look of the hour and the weather, from sim.wx (set once at the start; the editor changes it in mid-action).
func apply_weather() -> void:
    var w: Dictionary = sim.wx
    var day_col: Color = Color(0.9, 0.92, 0.94) if w.fog else (Color(0.72, 0.75, 0.79) if int(w.sea) >= 3 else (Color(0.86, 0.88, 0.9) if int(w.sea) >= 2 else Color.WHITE))
    cmod.color = day_col.lerp(Color(0.38, 0.44, 0.6).lerp(Color(0.52, 0.58, 0.74), float(w.moon)), 1.0 if w.night else 0.0)
    veil.visible = sim.limited() or w.fog or int(w.sea) >= 2
    veil_mat.set_shader_parameter("murk_a", (0.74 if w.night else 0.62) if sim.limited() else 0.0)
    veil_mat.set_shader_parameter("murk", Color(0.015, 0.025, 0.05) if w.night else (Color(0.5, 0.54, 0.57) if w.fog else Color(0.2, 0.24, 0.27)))
    veil_mat.set_shader_parameter("fog", (0.3 if w.night else 0.42) if w.fog else 0.0)
    veil_mat.set_shader_parameter("fog_col", Color(0.16, 0.19, 0.25) if w.night else Color(0.66, 0.7, 0.72))
    veil_mat.set_shader_parameter("rain", [0.0, 0.0, 0.45, 1.0][int(w.sea)])
    water_mat.set_shader_parameter("sea_state", float(w.sea)); water_mat.set_shader_parameter("night", 1.0 if w.night else 0.0); water_mat.set_shader_parameter("moon", float(w.moon))
var bloom: ColorRect
var burst_mat: ShaderMaterial
var wash_mat: ShaderMaterial
var veil: ColorRect
var veil_mat: ShaderMaterial
## Each frame: the pools of sight round your ships (and round enemies that are seen), in screen pixels, for the veil.
func _veil_spots() -> void:
    if veil == null or not veil.visible: return
    var vs := get_viewport_rect().size; var z := zoom(); var arr := []; var ct := get_viewport().get_canvas_transform()
    for f in sim.flares:   # star shell clears a pool in the dark for as long as it burns
        if float(f.t) <= 0.0 or arr.size() >= 8: continue
        var fp: Vector2 = ct * f.p; var fk: float = clampf(float(f.t) / 1.5, 0.0, 1.0) * clampf((BattleSim.STAR_LIFE - float(f.t)) / 5.0, 0.0, 1.0)
        arr.append(Vector4(fp.x, fp.y, BattleSim.STAR_R * 1.1 * z * fk, 0.0))
    for s in sim.ships:
        if not sim.active(s) or arr.size() >= 24: continue
        var r := 0.0
        if s.side == 0: r = maxf(float(sim.wx.vis), 1200.0) if sim.limited() else 1e6
        elif sim.visible_to(s, 0) and not s.radar_only: r = 420.0
        else: continue
        var sp: Vector2 = ct * s.pos
        arr.append(Vector4(sp.x, sp.y, r * z, 0.0))
    var n := arr.size()
    while arr.size() < 24: arr.append(Vector4(0, 0, 0, 0))
    veil_mat.set_shader_parameter("spots", arr); veil_mat.set_shader_parameter("n_spots", n)
    veil_mat.set_shader_parameter("screen", vs); veil_mat.set_shader_parameter("rt", Time.get_ticks_msec() / 1000.0)
func _recs(ids: Array, pal: String, tech: Array) -> Array:
    var out = []; var pool: Array = GameData.names.get(pal, GameData.names.player).duplicate(); pool.shuffle()
    for i in ids.size():
        var d: Dictionary = GameData.hulls[ids[i]]
        out.append({"type": ids[i], "name": pool[i % pool.size()], "hullFrac": 1.0, "fit": BattleSim.default_fit(d, tech), "pal": pal})
    return out

var island_mats: Array = []
var island_shader: Shader = preload("res://shaders/island.gdshader")
## An island drawn by island.gdshader on a quad over it, its coastline the island's own outline.
func _add_island(is_: Dictionary) -> void:
    var rad: Array = is_.rad; var rmax := 0.0
    for v in rad: rmax = maxf(rmax, v)
    var img := Image.create(rad.size(), 1, false, Image.FORMAT_RF)
    for i in rad.size(): img.set_pixel(i, 0, Color(float(rad[i]) / rmax, 0, 0))
    var mat := ShaderMaterial.new(); mat.shader = island_shader
    mat.set_shader_parameter("center", is_.c); mat.set_shader_parameter("rad", ImageTexture.create_from_image(img))
    mat.set_shader_parameter("r_max", rmax); mat.set_shader_parameter("seed", randf() * 10.0); mat.set_shader_parameter("sun_dir", -BattleSim.SUN.normalized())
    var v := IslandView.new(); v.c = is_.c; v.ext = rmax * 1.45; v.material = mat; layers.islands.add_child(v); island_mats.append(mat)

class IslandView extends Node2D:
    var c := Vector2.ZERO
    var ext := 100.0
    func _draw() -> void: draw_rect(Rect2(c - Vector2(ext, ext), Vector2(ext, ext) * 2.0), Color.WHITE)

func _add_view(s: BattleSim.CShip) -> void:
    var v = ShipView.new(); v.battle = self; v.s = s; layers.ships.add_child(v); v.build(); s.view = v; views.append(v)

var shake := 0.0
## How near a point is to the listener, 1 at the camera, 0 out of earshot. Measured in metres, with the earshot
## at least 2.5 km and growing with the view, so zooming in on a ship doesn't silence what is going on around it.
func _near(p: Vector2) -> float:
    var vs := get_viewport_rect().size / camera.zoom.x
    var reach := maxf(2500.0, vs.length() * 0.6)
    return clampf(1.0 - p.distance_to(camera.position) / reach, 0.0, 1.0)
func _boom(p: Vector2, vol: float, freq: float, rate: float) -> void:
    var k := _near(p)
    Sfx.boom(vol * k, freq, rate)
    if freq <= 360.0 and vol >= 0.4: shake = maxf(shake, vol * k * k * 6.0) # heavy guns and big blasts jolt the view

func _exit_tree() -> void: Sfx.engine(0.0); Sfx.ambience(0.0)
func zoom() -> float: return camera.zoom.x
func combat_speed() -> float: return speeds[speed_i]
## The new splash's columns and slicks in view, gathered in one walk of the particles a frame for both layers that draw
## them (each walk of nearly two thousand particles costs about a millisecond).
var _sp_frame := -1
var _sp_lists := [[], []]
func splash_parts() -> Array:
    var fr := Engine.get_process_frames()
    if fr != _sp_frame:
        _sp_frame = fr; _sp_lists = [[], []]
        if sim.modern and sim.splash_new:
            var vr: Rect2 = view_rect().grow(400)
            for q in sim.parts:
                if (q.t == BattleSim.P.COLUMN or q.t == BattleSim.P.LACE) and q.life >= 0.0 and vr.has_point(q.pos): _sp_lists[0 if q.t == BattleSim.P.COLUMN else 1].append(q)
    return _sp_lists

# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
    sim.modern = Settings.fx_modern   # the effects style can change in the pause menu
    sim.splash_new = Settings.splash != "classic"
    sim.fx_far = zoom() < 0.35   # far out, smoke is laid thinner in bigger puffs (BattleSim.fx_far)
    bloom.visible = sim.modern
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
    shake = maxf(0.0, shake - dt * 14.0)
    camera.offset = Vector2(randf() - 0.5, randf() - 0.5) * shake / zoom() if shake > 0.05 else Vector2.ZERO
    # engines and sea: the ships under the camera, louder the faster they steam
    var eng := 0.0
    if not paused and not sim.finished:
        for x in sim.ships:
            if x.alive and not x.escaped: eng = maxf(eng, _near(x.pos) * clampf(x.v / maxf(1.0, x.d.kn * 0.5144), 0.0, 1.0) * clampf(x.d.L / 200.0, 0.35, 1.0))
    Sfx.engine(eng)
    Sfx.ambience(0.0 if paused else 0.6, 0.35 if not sim.islands.is_empty() else 0.0)
    if not paused:   # what is near the camera, and the weather (the owner's chosen sounds)
        var prop := 0.0; var fire := 0.0; var bub := 0.0
        for q in sim.air: if not q.jet and q.up > 0 and (q.side == 0 or not sim.limited()): prop = maxf(prop, _near(q.pos) * minf(1.0, 0.4 + 0.15 * q.up))
        for x in sim.ships:
            for op in x.deck_ops: if not op.q.jet: prop = maxf(prop, _near(op.pos) * 0.6)
            if x.side == 1 and not sim.visible_to(x, 0): continue
            if x.alive and not x.escaped and not x.fires.is_empty(): fire = maxf(fire, _near(x.pos) * minf(1.0, 0.4 + 0.2 * x.fires.size()))
            if not x.alive and sim.sink_k(x) < 1.0: bub = maxf(bub, _near(x.pos))
        Sfx.layer("prop", prop); Sfx.layer("fire", fire * 0.8); Sfx.layer("bubbles", bub * 0.9)
        var sea: int = int(sim.wx.get("sea", 0))
        if sea == 2: Sfx.layer("rain", 0.6)
        elif sea >= 3: Sfx.layer("storm", 0.8); Sfx.layer("thunder", 0.7)
    var vs = get_viewport_rect().size
    water_mat.set_shader_parameter("cam", camera.position); water_mat.set_shader_parameter("zoom", zoom())
    water_mat.set_shader_parameter("screen", vs); water_mat.set_shader_parameter("t", sim.t); water_mat.set_shader_parameter("rt", Time.get_ticks_msec() / 1000.0)
    for m in island_mats: m.set_shader_parameter("rt", Time.get_ticks_msec() / 1000.0)
    _veil_spots()
    for v in views: v.refresh()
    for n in layers: if layers[n] is Drawer: layers[n].queue_redraw()
    hud.queue_redraw()

## A small label drawn in the battle's world by one of its layers, kept the same size on screen at any zoom.
func hud_text(ci: CanvasItem, at: Vector2, text: String, col: Color, mn: float) -> void:
    var fnt: Font = ThemeDB.fallback_font; var w := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
    ci.draw_set_transform(at, 0.0, Vector2(mn, mn))
    ci.draw_string(fnt, Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
    ci.draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ input
func _unhandled_input(e: InputEvent) -> void:
    if sim.finished: return
    if hud != null and is_instance_valid(hud.menu) and hud.menu.visible:   # the pause menu is up: nothing reaches the battle but Esc
        if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE: hud.toggle_menu()
        sim.mouse_down = false
        return
    if e is InputEventMouseButton:
        var mb = e as InputEventMouseButton
        if editor != null and editor.over(mb.position): sim.mouse_down = false; return   # the panel takes its own clicks
        if editor != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and editor.click(world.get_global_mouse_position(), mb.alt_pressed): return
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            if mb.pressed:
                var before = world.get_global_mouse_position()
                var z = clampf(zoom() * (1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.12), 0.035, 6.5)   # close enough to read a destroyer's deck (owner's request)
                camera.zoom = Vector2(z, z); camera.force_update_scroll()
                if cam_free: camera.position += before - world.get_global_mouse_position()
            return
        if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _pick_own(mb.position, mb.shift_pressed): return   # a ship of yours picked from the list, or Shift+clicked on the sea
        if mb.pressed and mb.ctrl_pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _sel().is_empty():   # send the ships picked out to a point
            var pt: Vector2 = world.get_global_mouse_position().clamp(Vector2(200, 200), Vector2(sim.AW - 200, sim.AH - 200))
            for x in _sel(): x.ord = "goto"; x.ord_pt = pt + Vector2((_sel().find(x) % 3 - 1) * 260.0, floor(_sel().find(x) / 3.0) * 260.0)
            sim.say("%s: make for the point and hold there." % _sel_names(), 1.8); return
        if mb.pressed and mb.ctrl_pressed and mb.button_index == MOUSE_BUTTON_LEFT and sim.flag != null:   # a waypoint for the flagship
            sim.waypoints.append(world.get_global_mouse_position().clamp(Vector2(200, 200), Vector2(sim.AW - 200, sim.AH - 200)))
            if sim.waypoints.size() == 1: sim.say("Helm: steering for the waypoint. A/D takes the helm back.", 1.6)
            return
        if mb.pressed and mb.ctrl_pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
            if not sim.waypoints.is_empty(): sim.waypoints.clear(); sim.say("Waypoints cleared.", 1.2)
            return
        if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
            if mb.pressed: drag = {"at": mb.position, "cam": camera.position, "moved": false, "btn": mb.button_index}
            else:
                if not drag.is_empty() and not drag.moved and drag.btn == MOUSE_BUTTON_RIGHT:
                    var own = _own_at_mouse()
                    if own != null and not sim.editor: _ship_menu(own, mb.position)   # a ship of yours: her radar and sonar
                    elif not _lock_at_mouse() and (sim.lock != null or sim.autofire): sim.lock = null; sim.autofire = false; sim.say("Check fire.", 1.4)
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

## The ships picked out that can still take an order (the flagship is yours to steer and takes none).
func _sel() -> Array:
    sel = sel.filter(func(x): return sim.active(x) and x != sim.flag)
    return sel
func _sel_names() -> String:
    var n: Array = _sel().map(func(x): return x.rec.name)
    return ", ".join(n) if n.size() <= 3 else "%d ships" % n.size()
## A click on a row of your squadron's list picks that ship (Shift adds or drops her); Shift+click picks a ship on the sea.
func _pick_own(at: Vector2, shift: bool) -> bool:
    var hit: BattleSim.CShip = null
    for r in hud.rows: if (r[0] as Rect2).has_point(at): hit = r[1]
    if hit == null and shift:
        var m: Vector2 = world.get_global_mouse_position(); var bd := INF
        for o in sim.ships:
            if o.side != 0 or not sim.active(o) or o == sim.flag: continue
            var d: float = o.pos.distance_to(m)
            if d < maxf(30.0 / zoom(), o.d.L * 0.6) and d < bd: bd = d; hit = o
    if hit == null: return false
    if hit == sim.flag or not sim.active(hit): return true
    if shift:
        if sel.has(hit): sel.erase(hit)
        else: sel.append(hit)
    else: sel = [] if (sel.size() == 1 and sel[0] == hit) else [hit]
    return true
## An order from the keys: to the ships picked out if there are any, otherwise to the squadron.
func _order(o: String, all_msg: String, what: String) -> void:
    if _sel().is_empty(): sim.order = o; sim.say(all_msg, 2.0); return
    for x in _sel(): x.ord = o
    sim.say("%s: %s." % [_sel_names(), what], 2.0)

## The ship of yours under the pointer (the flagship too), or null.
func _own_at_mouse():
    var m: Vector2 = world.get_global_mouse_position(); var best = null; var bd := INF
    for o in sim.ships:
        if o.side != 0 or not sim.active(o): continue
        var d: float = o.pos.distance_to(m)
        if d < maxf(26.0 / zoom(), o.d.L * 0.55) and d < bd: bd = d; best = o
    return best
## Radar and sonar, ship by ship or for the squadron (right-click a ship of yours; Y and U do the same from the keys).
## Radar off: she sees by eye alone, but no enemy set picks hers up. Sonar passive: she only listens, and hears a
## boat close to; pinging finds a dived boat far off and tells every hydrophone about where the pinger is.
var ship_menu: PopupMenu
func _ship_menu(s: BattleSim.CShip, at: Vector2) -> void:
    if ship_menu == null:
        ship_menu = PopupMenu.new(); ship_menu.theme = UI.theme(); hud.add_child(ship_menu)
        ship_menu.id_pressed.connect(func(id: int): _sensor_cmd(id, ship_menu.get_meta("ship")))
    ship_menu.clear(); ship_menu.set_meta("ship", s)
    ship_menu.add_separator(s.rec.name)
    if sim.radar_fitted(s): ship_menu.add_item("Radar: switch off (seen by eye alone; her set is not picked up)" if s.radar_on else "Radar: switch on", 1)
    else: ship_menu.add_item("No radar" if not s.sub else "No radar (a boat listens)", 90); ship_menu.set_item_disabled(ship_menu.get_item_count() - 1, true)
    if sim.has_sonar(s): ship_menu.add_item("Sonar: go passive (listen only; nothing hears her)" if s.sonar_on else "Sonar: start pinging (finds dived boats; gives her away)", 2)
    else: ship_menu.add_item("No sonar", 91); ship_menu.set_item_disabled(ship_menu.get_item_count() - 1, true)
    ship_menu.add_separator("The squadron")
    ship_menu.add_item("All radar off", 3); ship_menu.add_item("All radar on", 4); ship_menu.add_item("All sonar passive", 5); ship_menu.add_item("All sonar pinging", 6)
    ship_menu.position = Vector2i(at) + Vector2i(get_window().position if not get_window().is_embedded() else Vector2i.ZERO); ship_menu.reset_size(); ship_menu.popup()
func _sensor_cmd(id: int, s) -> void:
    var all: Array = sim.ships.filter(func(o): return o.side == 0 and sim.active(o))
    match id:
        1:
            if s != null: s.radar_on = not s.radar_on; sim.say("%s: radar %s." % [s.rec.name, "on" if s.radar_on else "off"], 1.6)
        2:
            if s != null: s.sonar_on = not s.sonar_on; s.ping_t = 0.0; sim.say("%s: %s." % [s.rec.name, "pinging" if s.sonar_on else "sonar silent, listening"], 1.6)
        3, 4:
            for o in all: o.radar_on = id == 4
            sim.say("All ships: radar %s." % ("on" if id == 4 else "off"), 1.6)
        5, 6:
            for o in all:
                if sim.has_sonar(o): o.sonar_on = id == 6; o.ping_t = randf() * 2.0
            sim.say("All ships: %s." % ("pinging" if id == 6 else "sonar silent, listening"), 1.6)

func _lock_at_mouse() -> bool:
    var m = world.get_global_mouse_position(); var best: BattleSim.CShip = null; var bd = INF
    for o in sim.ships:
        if (o.side != 1 and not sim.editor) or o == sim.flag or not sim.engageable(o) or not sim.visible_to(o, 0): continue   # (in the editor any ship can be locked)
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
            if s and not sim.has_kind(s, "torp"): sim.say("No torpedo tubes on this ship.", 1.2)
            elif sim.ff_confirm("torp"): sim.want_torp = true   # a friend in the track: the first press only warns
        KEY_Q:
            sim.want_msl = true
            if s and not sim.has_kind(s, "ssm"): sim.say("No missile launchers on this ship.", 1.2)
        KEY_F:
            if s:
                if s.squads.is_empty():   # a cruiser's or battleship's floatplane: off the catapult to spot for her guns
                    var why: String = sim.spotter_why(s)
                    if why != "": sim.say(why, 1.4)
                    else: sim.launch_spotter(s)
                else:
                    var tg: BattleSim.CShip = sim.lock if (sim.lock != null and sim.engageable(sim.lock) and sim.visible_to(sim.lock, 0)) else sim.nearest_enemy(sim.mouse_world, 0, INF, func(o): return not sim.submerged(o))
                    var can_fly: bool = tg != null and sim.deck_ok(s) and not (int(sim.wx.sea) >= 3 or sim.wx.fog or (sim.wx.night and not s.tech.has("jets")))
                    if tg == null: sim.say("No target in sight for a strike.", 1.5)
                    elif not sim.launch_strike(s, tg) and can_fly: sim.say("No squadrons ready.", 1.2)   # otherwise the sim has said why
        KEY_C:
            if s and s.sub: s.want_dive = not s.want_dive; sim.say("Dive, dive, dive!" if s.want_dive else "Surfacing.", 1.2)
        KEY_V:
            if s:
                s.shell_mode = BattleSim.SHELL_MODES[(BattleSim.SHELL_MODES.find(s.shell_mode) + 1) % BattleSim.SHELL_MODES.size()]
                sim.say("Load " + {"auto": "by target (auto: AP against armour, HE against light ships, incendiary against merchants)", "ap": "armour-piercing", "he": "high explosive", "inc": "incendiary"}[s.shell_mode] + ".", 2.0)
        KEY_X:
            sim.autofire = not sim.autofire
            sim.say("Main-gun autofire " + ("on" if sim.autofire else "off") + (". Lock a target first." if sim.autofire and sim.lock == null else ""), 1.5)
        KEY_1: _order("engage", "All ships: engage.", "engage")
        KEY_2: _order("escort", "All ships: form on the flagship.", "form on the flagship")
        KEY_3: _order("retreat", "All ships withdraw! Open the range and break contact.", "withdraw")
        KEY_4: _order("line", "Form line ahead: follow in the flagship's wake.", "form line ahead")
        KEY_6: _order("abreast", "Form line abreast on the flagship.", "form line abreast")
        KEY_7: _order("screen", "Form a screen: light ships ahead, the rest astern of the flagship.", "form a screen")
        KEY_9:   # a torpedo attack: by the ships picked out, or by every light ship with torpedoes; on the ship you have locked, or the nearest
            var who: Array = _sel() if not _sel().is_empty() else sim.ships.filter(func(x): return x.side == 0 and x != sim.flag and sim.active(x) and x.d.L < 150.0)
            who = who.filter(func(x): return sim.has_torps(x))
            for x in who: x.ord = "torp"; x.ord_tgt = sim.lock; x.hold = false
            sim.say(("%s: torpedo attack%s!" % [", ".join(who.map(func(x): return x.rec.name)) if who.size() <= 3 else "%d ships" % who.size(), (" on the " + sim.lock.rec.name) if sim.lock != null else ""]) if who.size() else "No ship there has torpedoes to fire.", 2.2)
        KEY_0:   # back under the squadron's orders
            var back: Array = _sel() if not _sel().is_empty() else sim.ships.filter(func(x): return x.side == 0)
            for x in back: x.ord = ""; x.ord_tgt = null; x.hold = false
            sim.say("%s: rejoin the squadron's orders." % (_sel_names() if not _sel().is_empty() else "All ships"), 1.8)
        KEY_F1: sel = sim.ships.filter(func(x): return x.side == 0 and x != sim.flag and sim.active(x) and x.d.L < 150.0); sim.say("Light ships picked out (%d)." % sel.size(), 1.2)
        KEY_F2: sel = sim.ships.filter(func(x): return x.side == 0 and x != sim.flag and sim.active(x) and x.d.L >= 150.0); sim.say("Heavy ships picked out (%d)." % sel.size(), 1.2)
        KEY_F3: sel = []; sim.say("Orders go to the whole squadron.", 1.2)
        KEY_8:
            var n := 0
            for x in (_sel() if not _sel().is_empty() else sim.ships): if x.side == 0 and x != sim.flag and sim.make_smoke(x, true): n += 1
            sim.say("Squadron: make smoke!" if n > 0 else "No ship of the squadron has smoke to make.", 2.0)
        KEY_G:   # star shell over the point of aim
            if s == null or not sim.can_star(s): sim.say("This ship has no gun to fire star shell.", 1.2)
            elif not sim.wx.get("night", false): sim.say("Star shell is for the dark: it is daylight.", 1.4)
            elif sim.fire_star(s, world.get_global_mouse_position()): sim.say("Star shell!", 1.2)
            else: sim.say("The star-shell gun is reloading.", 1.0)
        KEY_B:   # where the flagship's damage-control parties go first
            if s:
                var pr: Array = ["", "fire", "flood", "mach"]; s.dc_pri = pr[(pr.find(s.dc_pri) + 1) % pr.size()]
                sim.say("Damage control: %s." % BattleSim.DC_PRI[s.dc_pri], 1.6)
        KEY_N:
            if s and sim.flood_magazine(s): sim.say("Flood the magazine! The turret above it is out of action; the ship is safe.", 2.5)
            elif s: sim.say("No magazine is burning.", 1.0)
        KEY_J:
            if s and sim.counter_flood(s): sim.say("Counter-flooding: she comes upright, and sits deeper for it.", 2.2)
            elif s: sim.say("She has no list worth righting.", 1.0)
        KEY_H: set_clean(not clean)
        KEY_Y, KEY_U:   # radar (Y) and sonar (U): the ships picked out, else the flagship
            var who: Array = _sel() if not _sel().is_empty() else ([s] if s else [])
            for o in who:
                if k == KEY_Y and sim.radar_fitted(o): _sensor_cmd(1, o)
                elif k == KEY_U and sim.has_sonar(o): _sensor_cmd(2, o)
                else: sim.say("%s has no %s." % [o.rec.name, "radar" if k == KEY_Y else "sonar"], 1.2)
        KEY_F9: if editor != null: editor.panel.visible = not editor.panel.visible
        KEY_K:
            if s == null or not sim.can_smoke(s): sim.say("This ship cannot make smoke.", 1.2)
            elif s.smoke_on: sim.make_smoke(s, false); sim.say("Stop making smoke.", 1.2)
            elif sim.make_smoke(s, true): sim.say("Make smoke! (%d s in the generators)" % int(s.smoke_left), 1.5)
            else: sim.say("The smoke generators are recharging.", 1.2)
        KEY_5:
            if _sel().is_empty(): sim.hold_fire = not sim.hold_fire; sim.say("Squadron: hold your fire." if sim.hold_fire else "Squadron: open fire.", 2.0)
            else:
                var on: bool = not _sel()[0].hold
                for x in _sel(): x.hold = on
                sim.say("%s: %s." % [_sel_names(), "hold your fire" if on else "open fire"], 2.0)
        KEY_P: paused = not paused
        KEY_ESCAPE: hud.toggle_menu()
        KEY_Z:
            if s == null or s.sub or not s.d.get("sonar", false): sim.say("This ship carries no depth charges.", 1.2)
            elif s.dc_left <= 0: sim.say("No depth charges left.", 1.2)
            elif s.dc_t > 0.0: sim.say("The racks are reloading.", 1.0)
            elif sim.ff_confirm("dc"): sim.drop_dcs(s)   # a friend (or she herself) within the burst: the first press only warns
        KEY_SPACE, KEY_HOME: cam_free = false; sim.say("Camera on the " + (s.rec.name if s else "flagship") + ".", 1.0)
        KEY_EQUAL, KEY_KP_ADD, KEY_PERIOD: speed_i = mini(speeds.size() - 1, speed_i + 1); sim.say("Time ×" + str(int(combat_speed() * BattleSim.BT)), 1.0)
        KEY_MINUS, KEY_KP_SUBTRACT, KEY_COMMA: speed_i = maxi(0, speed_i - 1); sim.say("Time ×" + str(int(combat_speed() * BattleSim.BT)) + (" (real time)" if combat_speed() < 1 else ""), 1.0)
        KEY_TAB:
            var mine: Array = []
            for x in sim.ships: if (x.side == 0 or sim.editor) and sim.engageable(x): mine.append(x)   # (in the editor: every ship in turn)
            if mine.size() > 1 or (sim.flag == null and mine.size() > 0):
                sim.waypoints.clear()
                if sim.flag != null: sim.flag.shell_mode = "auto"
                sim.flag = mine[(mine.find(sim.flag) + 1) % mine.size()]; sim.say("You take command of the " + sim.flag.rec.name + ".", 1.5)
        KEY_M: Sfx.muted = not Sfx.muted
        KEY_R: Settings.sensors = not Settings.sensors; Settings.save(); sim.say("Sensor ranges and radar sweep " + ("shown." if Settings.sensors else "hidden."), 1.5)

# ================================================================== ship view
class ShipView extends Node2D:
    var battle
    var s: BattleSim.CShip
    var base: Sprite2D
    var top: Sprite2D
    var style := "us"
    var detail: Node2D
    var detail_top
    var lit_base: ShaderMaterial
    var lit_top: ShaderMaterial
    var spr = 1.0
    var size_m = Vector2.ONE
    var edge: Array = []   # Vector2(x along the ship, half beam there)
    var mount_mat: ShaderMaterial
    var lean := 0.0        # metres carried towards her low side per metre of height
    var freeboard := 4.0
    var deck_shift := 0.0  # how far the deck is carried to her low side by the heel, metres

    ## How far she is heeled, -1..1 (+ to starboard): her list, and as she sinks she rolls further onto that side.
    func heel() -> float:
        var k: float = battle.sim.sink_k(s)
        if k <= 0.0: return s.list
        return (signf(s.list) if s.list != 0.0 else 1.0) * maxf(absf(s.list), minf(1.0, k * 1.6))

    func build() -> void:
        var id: String = s.rec.type; var info: Dictionary = GameData.sprites.ships[id]
        spr = info.spr; size_m = Vector2(info.w, info.h)
        for i in 41:   # the deck edge, sampled along her length: for the list and the sea coming over her side
            var hx: float = lerpf(-float(s.d.L) * 0.5, float(s.d.L) * 0.5, i / 40.0); edge.append(Vector2(hx, battle.sim.hull_half(s.d, hx)))
        var keel = Keel.new(); keel.view = self; add_child(keel)
        base = _sprite(GameData.ship_tex(id, s.pal, "base"), 1.0 / spr)
        lit_base = ShaderMaterial.new(); lit_base.shader = battle.light_shader; base.material = lit_base
        detail = Detail.new(); detail.view = self; detail.scale = Vector2(spr, spr); base.add_child(detail)
        base.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # soot and holes stay on the hull
        top = _sprite(GameData.ship_tex(id, s.pal, "top"), 1.0 / spr)
        lit_top = ShaderMaterial.new(); lit_top.shader = battle.light_shader; top.material = lit_top
        # the same damage on the superstructure, kept to its outline: a gash in the bridge shows as one, not hidden under it
        detail_top = Detail.new(); detail_top.view = self; detail_top.upper = true; detail_top.scale = Vector2(spr, spr); top.add_child(detail_top)
        top.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
        style = GameData.style_of(id)
        var mmat = GameData.mount_material(s.pal); mount_mat = mmat
        for lvl in range(0, s.max_lvl + 1):
            for lit in [false, true]:
                var ml = MountLayer.new(); ml.view = self; ml.lvl = lvl; ml.lit = lit
                if lit: ml.material = mmat
                add_child(ml)
        var fires = Fires.new(); fires.view = self; var mat = CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; fires.material = mat; add_child(fires)
        var hm = GameData.ship_h(id)
        for m in [lit_base, lit_top]:
            m.set_shader_parameter("size_m", size_m); m.set_shader_parameter("beam", float(s.d.B))
            m.set_shader_parameter("hmap", hm); m.set_shader_parameter("use_h", hm != null); m.set_shader_parameter("h_max", float(GameData.sprites.get("h_max", 40)))
        lit_top.set_shader_parameter("is_top", true)

    func _sprite(t: Texture2D, sc: float) -> Sprite2D:
        var sp = Sprite2D.new(); sp.texture = t; sp.scale = Vector2(sc, sc); add_child(sp); return sp

    func refresh() -> void:
        var sm = s.dive if s.sub else 0.0
        var alpha = 1.0; var k = 0.0
        if not s.alive: k = battle.sim.sink_k(s); alpha = 1.0 - smoothstep(0.6, 1.0, k)   # she settles first, and only then goes from sight
        elif sm > 0: alpha = 1.0 - 0.65 * sm
        visible = alpha > 0.02 and not s.escaped and (s.side == 0 or not s.sub or s.dive < 0.3 or battle.sim.detected_by(s, 0) or not s.alive)
        if visible and s.side == 1 and s.alive and (battle.sim.limited() or not battle.sim.screens.is_empty()) and not battle.sim.visible_to(s, 0): visible = false   # lost in the dark, the murk or behind smoke
        # held by radar alone: an echo on the plot, bright as the beam passes her and fading until it comes round again
        if s.side == 1 and s.alive and s.radar_only: alpha *= clampf(1.0 - s.paint_t / BattleSim.RADAR_PERIOD, 0.0, 1.0)
        position = s.pos; rotation = s.a + k * 0.25; scale = Vector2(1.0, 1.0 - 0.13 * absf(s.list)) * (1.0 - 0.2 * k); modulate.a = alpha   # a listing ship shows less of her beam
        var sun_local = BattleSim.SUN.rotated(-s.a)
        var soot = clampf((1.0 - s.hull / s.max_hull - 0.25) * 1.4, 0.0, 1.0)
        for m in [lit_base, lit_top]: m.set_shader_parameter("sun_local", sun_local); m.set_shader_parameter("soot", soot)
        # a heeled ship seen from above: everything that stands above the waterline is carried over towards her low
        # side, the more the higher it stands - the deck by her freeboard, the superstructure and each level of
        # turrets further still - so the whole ship leans, not the hull alone
        var ln: float = heel() * 0.6
        var fb: float = 0.6 if s.d.kind == "sub" else (10.0 if s.d.kind == "carrier" else clampf(float(s.d.B) * 0.25, 1.2, 8.0))
        deck_shift = ln * fb
        lean = ln; freeboard = fb
        base.position.y = deck_shift; top.position.y = deck_shift
        lit_top.set_shader_parameter("lean", ln)
        mount_mat.set_shader_parameter("lean", ln); mount_mat.set_shader_parameter("sun_ship", sun_local)   # each point of the upper works is carried over by its own height, in the shader
        for c in get_children():
            if c is Fires: c.position.y = ln * (fb + 1.0)
            if c is Node2D and not (c is Sprite2D): c.queue_redraw()
        detail.queue_redraw(); detail_top.queue_redraw()

## What a heel shows from above: along the high side, the plating of her side and below it the red of her bottom,
## rolled up out of the water.
class Keel extends Node2D:
    var view
    func _draw() -> void:
        var h: float = view.heel()
        if absf(h) < 0.08 or view.battle.zoom() * view.s.d.L < 25 or (view.s.sub and view.s.dive > 0.1): return
        var hi: float = -signf(h); var B: float = view.s.d.B; var off: float = absf(h) * B * 0.3; var e: Array = view.edge
        for i in e.size() - 1:
            var a: Vector2 = e[i]; var b: Vector2 = e[i + 1]
            var ka: float = sqrt(clampf(a.y / (B * 0.5), 0.0, 1.0)); var kb: float = sqrt(clampf(b.y / (B * 0.5), 0.0, 1.0))
            var sh: float = absf(view.deck_shift) + 0.4   # the deck edge has moved in from the waterline by this much: her side shows between
            var a0 := Vector2(a.x, hi * (a.y - sh)); var b0 := Vector2(b.x, hi * (b.y - sh))
            var a1 := Vector2(a.x, hi * (a.y + off * 0.25 * ka)); var b1 := Vector2(b.x, hi * (b.y + off * 0.25 * kb))
            var a2 := Vector2(a.x, hi * (a.y + off * ka)); var b2 := Vector2(b.x, hi * (b.y + off * kb))
            var grey := Color(0.3, 0.32, 0.34); var red := Color(0.5, 0.15, 0.12); var deep := Color(0.3, 0.1, 0.09)
            draw_primitive(PackedVector2Array([a0, b0, b1, a1]), PackedColorArray([grey, grey, grey.darkened(0.25), grey.darkened(0.25)]), PackedVector2Array())
            draw_primitive(PackedVector2Array([a1, b1, b2, a2]), PackedColorArray([red, red, deep, deep]), PackedVector2Array())
            draw_line(a1, b1, Color(0.08, 0.08, 0.08, 0.8), 0.25)   # the boot-topping

class Detail extends Node2D:   # soot and shell holes, kept where they struck
    var view
    var upper := false   # the copy over the superstructure: gashes and wrecked mounts, a little soot
    func _draw() -> void:
        var s: BattleSim.CShip = view.s
        if view.battle.zoom() * s.d.L < 25: return
        var h: float = view.heel()
        if not upper and absf(h) >= 0.08:   # the sea over her low side: green water on the deck and a line of foam where it stops
            var lo: float = signf(h); var kk: float = view.battle.sim.sink_k(s); var tm: float = Time.get_ticks_msec() * 0.001
            var e: Array = view.edge; var foam := PackedVector2Array()
            var sea := Color(0.04, 0.17, 0.22, 0.62 + 0.3 * absf(h))
            var ins: Array = []
            for i in e.size():
                var p: Vector2 = e[i]
                # (at her ends, where she is narrow, the water still comes a fair way in: a share of her full beam, not of the beam there)
                var wd: float = minf(2.0 * p.y + 0.5, maxf(p.y, float(s.d.B) * 0.22) * (absf(h) * 0.75 + kk * 2.4) + 0.25 * sin(p.x * 0.45 + tm * 1.3) * absf(h))
                ins.append(Vector2(p.x, lo * (p.y - maxf(0.0, wd)))); foam.append(ins[i])
            for i in e.size() - 1:
                var a: Vector2 = e[i]; var b: Vector2 = e[i + 1]
                draw_primitive(PackedVector2Array([Vector2(a.x, lo * (a.y + float(s.d.B))), Vector2(b.x, lo * (b.y + float(s.d.B))), ins[i + 1], ins[i]]), PackedColorArray([sea, sea, Color(sea, sea.a * 0.75), Color(sea, sea.a * 0.75)]), PackedVector2Array())
            draw_polyline(foam, Color(0.9, 0.96, 0.96, 0.75), 0.4)
            draw_polyline(foam, Color(0.9, 0.96, 0.96, 0.22), 1.4)
        if s.marks.is_empty(): return
        var sunl: Vector2 = BattleSim.SUN.rotated(-s.a).normalized()   # the sun, in the ship's own frame: torn edges catch it
        for m in s.marks:
            var tx = GameData.fx_tex("cloud%d" % m.v); var r: float = m.r; var c := Vector2(m.x, m.y)
            if upper and not m.get("gash", false): continue
            if upper:   # on a heeled ship a mark on her upper works is carried over with the plating it is in, by that plating's height
                if not m.has("h"): m["h"] = GameData.ship_h_at(s.rec.type, m.x, m.y)
                draw_set_transform(Vector2(0, view.lean * float(m.h)))
            draw_texture_rect(tx, Rect2(m.x - r, m.y - r, 2 * r, 2 * r), false, Color(0.09, 0.07, 0.05, 0.3 if upper else 0.45))
            if m.get("wreck", false):   # a mount knocked out: burnt round it, plating buckled, bits of the shield strewn about
                draw_texture_rect(tx, Rect2(m.x - r * 1.2, m.y - r * 1.2, 2.4 * r, 2.4 * r), false, Color(0.03, 0.03, 0.03, 0.55))
                for k in 5:
                    var a: float = float(m.sd) * 0.37 + k * 1.31; var p: Vector2 = c + Vector2.from_angle(a) * r * (0.5 + 0.12 * k)
                    draw_line(p, p + Vector2.from_angle(a * 2.3) * r * 0.3, Color(0.2, 0.2, 0.2, 0.9), maxf(0.12, r * 0.06))
            elif m.get("gash", false):
                # a gash: a ragged tear, black inside, its rim of bent plate bright where it faces the sun and a
                # streak of soot blown aft from it; at the deck edge, a bite out of the ship's side
                var n := 9; var pts := PackedVector2Array(); var g: float = r * 0.55
                for k in n:
                    var a: float = k * TAU / n; var jag: float = 0.55 + 0.6 * fposmod(sin(float(m.sd) * 0.13 + k * 2.7) * 43.7, 1.0)
                    pts.append(c + Vector2(cos(a) * 1.5, sin(a) * 0.8) * g * jag)
                if m.get("edge", false) and not upper:
                    var side: float = float(m.get("side", 1.0)); var bite := PackedVector2Array()
                    for k in 7: bite.append(c + Vector2((k - 3) * g * 0.55, side * g * (0.2 + 0.5 * fposmod(sin(float(m.sd) * 0.31 + k * 1.9) * 12.3, 1.0))))
                    bite.append(c + Vector2(g * 1.9, side * g * 3.2)); bite.append(c + Vector2(-g * 1.9, side * g * 3.2))
                    draw_colored_polygon(bite, Color(0.07, 0.15, 0.18, 0.92))   # the sea where her side was
                    # what the plating hid: the deck below, cut off short, and the frames standing out of it
                    var shelf := PackedVector2Array(); for k in 7: shelf.append(bite[k])
                    for k in range(6, -1, -1): shelf.append(bite[k] + Vector2(0, side * g * 0.75))
                    draw_colored_polygon(shelf, Color(0.13, 0.13, 0.14, 0.95))
                    for k in 7:
                        draw_line(bite[k], bite[k] + Vector2(0, side * g * (0.95 + 0.3 * fposmod(sin(float(m.sd) + k * 2.1) * 5.7, 1.0))), Color(0.3, 0.28, 0.26), maxf(0.12, g * 0.07))
                    draw_polyline(shelf.slice(7, 14), Color(0.34, 0.32, 0.3, 0.9), maxf(0.1, g * 0.06))
                draw_texture_rect(tx, Rect2(m.x - r * 2.2, m.y - r * 0.7, r * 2.4, r * 1.4), false, Color(0.05, 0.04, 0.03, 0.4))   # soot aft
                draw_colored_polygon(pts, Color(0.03, 0.03, 0.03, 0.95))
                # inside the tear: the deck below a shade lighter where the light reaches it, the frames across the
                # ship and a girder along her, cut to the shape of the hole
                var low := PackedVector2Array(); for p in pts: low.append(c + (p - c) * 0.78 - sunl * g * 0.12)
                draw_colored_polygon(low, Color(0.1, 0.1, 0.11, 0.95))
                var sp_: float = maxf(0.9, g * 0.42); var fx: float = ceilf((c.x - g * 1.6) / sp_) * sp_
                while fx < c.x + g * 1.6:
                    var cut: Vector2 = _cut(pts, fx, true)
                    if cut.y - cut.x > 0.2: draw_line(Vector2(fx, cut.x), Vector2(fx, cut.y), Color(0.27, 0.25, 0.23), maxf(0.1, g * 0.07))
                    fx += sp_
                var gy: float = c.y + g * 0.15 * (1.0 if m.sd % 2 else -1.0); var gc: Vector2 = _cut(pts, gy, false)
                if gc.y - gc.x > 0.2: draw_line(Vector2(gc.x, gy), Vector2(gc.y, gy), Color(0.33, 0.31, 0.29), maxf(0.14, g * 0.1))
                for k in n:
                    var p0: Vector2 = pts[k]; var p1: Vector2 = pts[(k + 1) % n]; var nrm: Vector2 = (p0 + p1) * 0.5 - c
                    var lit: float = clampf(nrm.normalized().dot(-sunl), 0.0, 1.0)
                    draw_line(p0, p1, Color(0.35, 0.35, 0.36).lerp(Color(0.85, 0.84, 0.8), lit), maxf(0.1, g * 0.14))
                    if k % 3 == 0: draw_line(p0, p0 + nrm.normalized() * g * 0.5, Color(0.25, 0.25, 0.25, 0.8), maxf(0.08, g * 0.08))   # plate peeled back
            elif m.hole:
                # a shell hole: not a punched disc but torn plate - a ragged, lopsided opening, a lip that catches the
                # light on the side away from the sun, and a crack or two running out of it
                var hr: float = r * 0.22; var sd: float = float(m.get("sd", 0)); var tilt: float = sd * 0.7
                var hp := PackedVector2Array()
                for k in 8:
                    var a: float = k * TAU / 8.0 + 0.25 * sin(sd * 0.9 + k * 2.3)
                    var rad: float = hr * (0.6 + 0.7 * fposmod(sin(sd * 0.37 + k * 1.93) * 31.7, 1.0))
                    hp.append(c + (Vector2(cos(a) * 1.25, sin(a) * 0.8) * rad).rotated(tilt))
                draw_colored_polygon(hp, Color(0.04, 0.04, 0.04, 0.92))
                for k in 8:
                    var p0: Vector2 = hp[k]; var p1: Vector2 = hp[(k + 1) % 8]
                    var lit: float = clampf(((p0 + p1) * 0.5 - c).normalized().dot(-sunl), 0.0, 1.0)
                    if lit > 0.35: draw_line(p0, p1, Color(0.7, 0.7, 0.68, 0.55 * lit), maxf(0.06, hr * 0.12))
                for k in 2:
                    var ca: float = sd * 1.3 + k * 2.6; var from: Vector2 = c + Vector2.from_angle(ca) * hr * 0.8
                    draw_line(from, from + Vector2.from_angle(ca + 0.4 * sin(sd + k)) * hr * (0.7 + 0.5 * k), Color(0.05, 0.05, 0.05, 0.7), maxf(0.05, hr * 0.1))
        if upper: draw_set_transform(Vector2.ZERO)

    ## Where the line x = v (or y = v) crosses a polygon: the least and greatest of the other coordinate.
    func _cut(pts: PackedVector2Array, v: float, vertical: bool) -> Vector2:
        var lo := INF; var hi := -INF; var n: int = pts.size()
        for k in n:
            var a: Vector2 = pts[k]; var b: Vector2 = pts[(k + 1) % n]
            var a0: float = a.x if vertical else a.y; var b0: float = b.x if vertical else b.y
            if (a0 - v) * (b0 - v) > 0.0 or a0 == b0: continue
            var w: float = lerpf(a.y if vertical else a.x, b.y if vertical else b.x, (v - a0) / (b0 - a0))
            lo = minf(lo, w); hi = maxf(hi, w)
        return Vector2(lo, hi) if hi > lo else Vector2.ZERO

class MountLayer extends Node2D:   # turrets of one level: their contact and cast shadows, or the lit mounts themselves
    var view
    var lvl := 0
    var lit := false
    ## The barrels texture drawn strip by strip, one strip per barrel, so each recoils on its own.
    func _barrels(tex: Texture2D, m, info: Dictionary, o: Vector2, col: Color) -> void:
        var n := int(m.w.get("barrels", 1)); var spr: float = info.spr; var g: float = float(m.w.get("gap", 0.0)); var hpx: float = tex.get_height()
        for i in n:
            var y0: float = 0.0 if i == 0 else (float(info.oy) + (i - 0.5 - (n - 1) / 2.0) * g) * spr
            var y1: float = hpx if i == n - 1 else (float(info.oy) + (i + 0.5 - (n - 1) / 2.0) * g) * spr
            var r: float = m.rec[i] if i < m.rec.size() else m.recoil
            var rc: float = pow(r, 0.6) * float(m.w.get("bl", 0.0)) * 0.22 * spr   # slams back at once, runs out slowly
            var src = Rect2(0, y0, tex.get_width(), y1 - y0)
            draw_texture_rect_region(tex, Rect2(o + Vector2(-rc, y0), src.size), src, col)
    func _visible_mount(s: BattleSim.CShip, m) -> bool:
        return m.lvl == lvl and m.w.kind != "ssm" and m.w.kind != "sam" and not (s.sub and m.w.kind == "torp") and GameData.sprites.mounts.has(m.wid)
    func _draw() -> void:
        var s: BattleSim.CShip = view.s
        if (s.sub and s.dive > 0.1) or view.battle.zoom() * s.d.L < 30: return
        var sun: Vector2 = BattleSim.SUN.rotated(-s.a)
        var style: String = view.style
        for m in s.mounts:
            if not _visible_mount(s, m): continue
            var info: Dictionary = GameData.sprites.mounts[m.wid]
            var sc: float = (1.0 + 0.035 * lvl) / info.spr * GameData.mount_scale(s.rec.type, m.wid)
            var p = Vector2(m.slot.x, m.slot.y); var o = -Vector2(info.ox, info.oy) * info.spr
            var split: bool = info.get("split", false)
            var bt: Texture2D = GameData.mount_img(m.wid, style, true) if split else null
            # heeled, a turret is the solid it is: its foot is carried over with the deck it stands on, and the mount
            # shader carries every point of it further by its own height (the same rule as the superstructure)
            var ln: float = view.lean; var foot: float = ln * (view.freeboard + 2.8 * lvl)
            p.y += foot
            if not lit:
                # a soft contact shadow round the foot, then a crisp shadow cast from the roof's height (raised turrets cast further)
                draw_set_transform(p, m.ta, Vector2(sc, sc) * 1.04)
                draw_texture(GameData.mount_ao(m.wid), o, Color(1, 1, 1, 0.75))
                var reach: float = GameData.turret_h(m.w) * 0.85 + 2.8 * lvl
                draw_set_transform(p + sun * reach, m.ta, Vector2(sc, sc))
                var shc = Color(0, 0, 0, 0.42 if lvl else 0.36)
                if split: _barrels(bt, m, info, o, shc)
                draw_texture(GameData.mount_img(m.wid, style), o, shc)
            else:
                var code: Color = GameData.mount_code(sun.rotated(-m.ta), lvl, m.dead)
                draw_set_transform(p, m.ta, Vector2(sc, sc))
                if split: _barrels(bt, m, info, o, code) # only the barrels run back on recoil, each on its own
                var mt: Texture2D = GameData.mount_img(m.wid, style)
                if absf(ln) > 0.01:   # room round the plan for what leans out past its edge
                    var pad := Vector2.ONE * 4.0 * float(info.spr)
                    draw_texture_rect_region(mt, Rect2(o - pad, mt.get_size() + pad * 2.0), Rect2(-pad, mt.get_size() + pad * 2.0), code)
                else: draw_texture(mt, o, code)
        draw_set_transform(Vector2.ZERO)
        if lit and lvl == s.max_lvl and s.struck: _white_flag(s)

    ## A ship that has struck her colours flies a white flag from the stern: a staff, and a flag rippling downwind
    ## with its shadow on the deck and the sea. Drawn larger than life (about 14 m) so it reads at battle zoom.
    func _white_flag(s) -> void:
        # under way the wind over the deck comes from ahead, so the flag streams astern, out over the water
        var tn := Time.get_ticks_msec() / 1000.0; var st := Vector2(-s.d.L / 2 + 1.5, 0.0)
        var tw := (BattleSim.WIND.normalized()).rotated(-s.a)
        var wind := (Vector2(-1, 0) * clampf(s.v / 6.0, 0.3, 1.0) + tw * 0.4).normalized()
        var side := Vector2(-wind.y, wind.x); var L := 8.0; var H := 5.5; var n := 9
        var top := PackedVector2Array(); var bot := PackedVector2Array()
        for i in n:
            var k := float(i) / (n - 1); var wave := sin(tn * 7.0 - k * 6.0) * 0.9 * k
            top.append(st + wind * L * k + side * (H * 0.5 + wave)); bot.append(st + wind * L * k + side * (-H * 0.5 + wave))
        var sh := BattleSim.SUN.rotated(-s.a) * 4.0
        for i in n - 1:   # each strip of the cloth, darker where it turns away from the light: the ripple shows
            var q := PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]])
            var shade := 0.5 + 0.5 * cos(tn * 7.0 - (float(i) + 0.5) / (n - 1) * 6.0)
            var qs := PackedVector2Array(); for v in q: qs.append(v + sh)
            if Geometry2D.triangulate_polygon(qs).size() > 0: draw_colored_polygon(qs, Color(0, 0, 0, 0.22))
            if Geometry2D.triangulate_polygon(q).size() > 0: draw_colored_polygon(q, Color(0.97, 0.97, 0.94).darkened(0.18 * shade))
        draw_line(st + side * 3.6, st - side * 3.6, Color(0.22, 0.2, 0.18), 0.9)   # the staff

class Fires extends Node2D:
    var view
    func _draw() -> void:
        var s: BattleSim.CShip = view.s; var z: float = view.battle.zoom(); var tn = Time.get_ticks_msec() / 1000.0
        var puff = GameData.fx_tex("puff")
        for f in s.fires:
            var fl = 0.7 + 0.3 * sin(tn * 23 + f.x * 3) * sin(tn * 9 + f.y)
            var r1 = maxf(f.r * 2.2, 2.0 / z); var r2 = maxf(f.r * 0.9, 1.0 / z)
            if view.battle.sim.modern:   # a pool of firelight on the deck and the sea, and flames that lick and jump
                var rg = maxf(f.r * 11.0, 8.0 / z)
                draw_texture_rect(GameData.glow_tex(), Rect2(f.x - rg, f.y - rg, 2 * rg, 2 * rg), false, Color(1, 0.48, 0.16, 0.4 * fl))
                for j in 3:
                    var off = Vector2(sin(tn * (7.0 + j * 2.3) + f.x + j), cos(tn * (5.0 + j * 1.7) + f.y * 2.0 + j)) * f.r * 0.6
                    var rt = r2 * (0.7 + 0.3 * sin(tn * (17.0 + j * 4.0) + j * 2.0))
                    draw_texture_rect(puff, Rect2(f.x + off.x - rt, f.y + off.y - rt, 2 * rt, 2 * rt), false, Color(1, 0.62, 0.2, 0.7 * fl))
            draw_texture_rect(puff, Rect2(f.x - r1, f.y - r1, 2 * r1, 2 * r1), false, Color(1, 0.43, 0.12, 0.55 * fl))
            draw_texture_rect(puff, Rect2(f.x - r2, f.y - r2, 2 * r2, 2 * r2), false, Color(1, 0.78, 0.47, 0.8 * fl))
            if view.battle.sim.modern: var rc = maxf(f.r * 0.4, 0.6 / z); draw_texture_rect(puff, Rect2(f.x - rc, f.y - rc, 2 * rc, 2 * rc), false, Color(1, 0.97, 0.85, 0.9 * fl))

# ================================================================== world layers
class Drawer extends Node2D:
    var battle
    var kind = ""
    func _draw() -> void:
        match kind:
            "islands": _islands()
            "below": _scars(); _wakes(); _parts(0); _laces(); _wreckage(); _torpedoes()
            "bursts": _bursts()
            "wash": _wash()
            "washtop": _wash(true)
            "shadows": _shadows()
            "above": _columns(); _parts(1); _screens()
            "light": _parts(2); _flares()
            "overlay": _overlay()

    func _puff(tex: Texture2D, p: Vector2, r: float, c: Color) -> void:
        if c.a <= 0.01 or r * battle.zoom() < 0.6: return
        draw_texture_rect(tex, Rect2(p.x - r, p.y - r, 2 * r, 2 * r), false, c)

    func _islands() -> void:  # islands are IslandView nodes with their own shader (see Battle._add_island)
        pass

    # Wakes: overlapping soft foam stamps. The churned band starts the width of the stern and spreads; the bow wave
    # hugs the forward hull and runs on into the Kelvin arms, which open at about 19.5 degrees to the track.
    var wake_a := {}   # each ship's wake alpha, eased (see below)
    func _wakes() -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom(); var foam = GameData.fx_tex("foam"); var now = sim.vt
        var min_step = 2.2 / z; var view: Rect2 = battle.view_rect()
        for s in sim.ships:
            if s.trail.size() < 2: continue
            if s.sub and s.side == 1 and not sim.detected_by(s, 0): continue
            # an enemy's wake fades with her: in sight it is all there, held by radar alone it fades with the echo between
            # sweeps, out of sight it is gone; eased, so it never blinks out under a hull still on the screen (the owner
            # saw it vanish for a second under a ship held only by radar, 12 Nov 2026)
            var want := 1.0
            if s.side == 1 and (sim.limited() or not sim.screens.is_empty()):
                if s.radar_only: want = clampf(1.0 - s.paint_t / BattleSim.RADAR_PERIOD, 0.0, 1.0)
                elif not sim.visible_to(s, 0): want = 0.0
            var wa: float = move_toward(float(wake_a.get(s, want)), want, get_process_delta_time() * 2.0); wake_a[s] = wa
            if wa < 0.02: continue
            # nothing of this wake on the screen: leave it (the trail runs some hundreds of metres astern)
            if not view.grow(900.0 + s.d.L).has_point(s.pos) and not view.grow(200.0).has_point(s.trail[0].p): continue
            var pts: Array = []
            if sim.active(s): pts.append(sim.trail_point(s))
            # far out, every second or fourth point of the trail is plenty
            var stride: int = 1 if z > 0.3 else (2 if z > 0.14 else 4); var last_i: int = s.trail.size() - 1
            for i in range(last_i, -1, -1):
                var q: Dictionary = s.trail[i]
                if not q.sm and ((last_i - i) % stride == 0 or i == 0): pts.append(q)
            if sim.modern and s.sub:
                # a boat running submerged leaves no churned wake, but the sea over her is not quite still: a faint,
                # narrow track of disturbed water in the same foam as every other wake (it was a string of rings)
                var deep: Array = []
                if sim.active(s) and sim.submerged(s): deep.append(sim.trail_point(s))
                for i in range(last_i, -1, -1):
                    var q: Dictionary = s.trail[i]
                    if q.sm and ((last_i - i) % stride == 0 or i == 0): deep.append(q)
                if deep.size() >= 2: _ribbon(deep, 0, s.d.B, 0.32 * clampf(float(deep[0].v) / 6.0, 0.2, 1.0), now, float(s.d.B) * 2.4, Color(0.84, 0.94, 0.94))
            if pts.size() < 2: continue
            var B: float = s.d.B; var strength = clampf(pts[0].v / 10.0, 0.1, 1.0) * wa
            if sim.modern:
                # the churned track astern: a broad mottled ribbon, bright at the screws, greening and fading as it widens
                _ribbon(pts, 0, B, strength, now, B * 5.0, Color(0.9, 0.97, 0.96))
                if B * z > 0.8:   # the bright core, the bow waves and the glints are finer than a pixel when the whole action is in view
                    _ribbon(pts, 1, B, strength, now, B * 2.2, Color(1, 1, 1))
                    # the bow waves: two feathered crests opening astern at the Kelvin angle
                    _ribbon(pts, 2, B, strength, now, B * 3.0, Color(0.93, 0.98, 0.98)); _ribbon(pts, 3, B, strength, now, B * 3.0, Color(0.93, 0.98, 0.98))
                    _glints(pts, B, now, foam)
            else:
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

    ## Sun glints twinkling in the churned water of a wake: points along the track that flash and fade.
    func _glints(pts: Array, B: float, now: float, foam: Texture2D) -> void:
        var z: float = battle.zoom(); var tn := Time.get_ticks_msec() / 1000.0
        for i in mini(pts.size(), 60):
            var q: Dictionary = pts[i]; var age: float = now - q.t
            if age > 12.0: break
            for j in 3:
                var h := fposmod(sin(q.t * 91.7 + j * 13.1) * 43758.55, 1.0)
                var tw := pow(maxf(0.0, sin(tn * (2.0 + h * 3.0) + h * 40.0)), 12.0) * (1.0 - age / 12.0)
                if tw < 0.05: continue
                var off := Vector2(-sin(q.a), cos(q.a)) * (h - 0.5) * B * (0.6 + age * 0.12)
                var r := maxf(B * 0.05, 1.2 / z)
                _puff(foam, q.p + off, r * (1.0 + tw), Color(1, 1, 1, 0.9 * tw))

    ## A ribbon of foam along a track: feathered at both edges, textured with churned water that stays put on the sea.
    ## One triangle array for the whole ribbon. `mode`: 0 the broad churned track, 1 its bright core at the screws,
    ## 2 and 3 the port and starboard bow waves opening astern at the Kelvin angle. (The shapes are written out here
    ## rather than passed in as functions: with twenty ships this runs for some seven thousand points a frame, and
    ## calling back for each cost more than everything else the battle draws put together.)
    const RIB_F := [-1.0, -0.42, 0.42, 1.0]
    func _ribbon(pts: Array, mode: int, B: float, strength: float, now: float, tile: float, col: Color) -> void:
        var n := pts.size()
        if n < 2: return
        var X := PackedVector2Array(); X.resize(n)
        if mode < 2:
            for i in n: X[i] = pts[i].p
        else:
            var sd: float = -1.0 if mode == 2 else 1.0; var key: String = "l" if mode == 2 else "r"
            for i in n:
                var q: Dictionary = pts[i]; var qa: float = q.a
                X[i] = q[key] + Vector2(-sin(qa), cos(qa)) * (sd * (now - q.t) * q.v * BattleSim.BT * 0.354)
        var V := PackedVector2Array(); var C := PackedColorArray(); var U := PackedVector2Array(); var I := PackedInt32Array()
        V.resize(n * 4); C.resize(n * 4); U.resize(n * 4); I.resize((n - 1) * 18)
        var clear := Color(col, 0.0)
        for i in n:
            var q: Dictionary = pts[i]; var age: float = now - q.t
            var dir: Vector2 = X[maxi(i - 1, 0)] - X[mini(i + 1, n - 1)]
            if dir.length_squared() < 0.0001: dir = Vector2.from_angle(q.a)
            dir = dir.normalized(); var nor := Vector2(-dir.y, dir.x)
            var w: float; var a: float
            match mode:
                0: w = B * (0.5 + age * 0.085); a = 0.62 * strength * pow(maxf(0.0, 1.0 - age / 18.0), 1.25) * minf(1.0, 0.35 + age * 0.5)
                1: w = B * (0.22 + age * 0.03); a = 0.55 * strength * pow(maxf(0.0, 1.0 - age / 7.0), 1.5)
                _: w = B * 0.16 + age * 1.5; a = 0.5 * strength * pow(maxf(0.0, 1.0 - age / 14.0), 1.6)
            if i == 0: a = 0.0   # the ribbon grows out of the hull
            a *= clampf(float(n - 1 - i) / 7.0, 0.0, 1.0)   # and thins away at its far end, where the track begins
            var u: float = q.t * 9.0 / tile   # by the time each point was laid, so the foam stays put on the sea
            var x: Vector2 = X[i]; var o := i * 4; var lit := Color(col, a)
            for k in 4:
                var f: float = RIB_F[k]
                V[o + k] = x + nor * (w * f); U[o + k] = Vector2(u, 0.5 + f * 0.5); C[o + k] = lit if k == 1 or k == 2 else clear
            if i > 0:
                var bb := (i - 1) * 4; var io := (i - 1) * 18
                for k in 3:
                    var j := io + k * 6; var v0 := bb + k
                    I[j] = v0; I[j + 1] = v0 + 1; I[j + 2] = v0 + 4; I[j + 3] = v0 + 1; I[j + 4] = v0 + 5; I[j + 5] = v0 + 4
        RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), I, V, C, U, PackedInt32Array(), PackedFloat32Array(), GameData.wake_tex().get_rid())

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
            if s.escaped or (s.sub and s.dive > 0.05) or (not s.alive and sim.sink_k(s) >= 1.0): continue
            if s.side == 1 and (s.radar_only or not sim.visible_to(s, 0)): continue   # a ship out of sight casts no shadow you can see
            var info: Dictionary = GameData.sprites.ships[s.rec.type]; var tx = GameData.ship_tex(s.rec.type, s.pal, "hull_shadow")
            var fb: float = 0.6 if s.d.kind == "sub" else (10.0 if s.d.kind == "carrier" else clampf(s.d.B * 0.25, 1.2, 8.0))
            var k = sim.sink_k(s)
            draw_set_transform(s.pos + BattleSim.SUN * fb, s.a + k * 0.25, Vector2.ONE * 3.0 / info.spr)
            draw_texture(tx, -tx.get_size() / 2, Color(1, 1, 1, 0.38 * (1.0 - k)))
        draw_set_transform(Vector2.ZERO)

    ## A texture turned to an angle (smoke and fire roll as they rise).
    func _rpuff(tex: Texture2D, p: Vector2, r: float, ang: float, c: Color) -> void:
        if c.a <= 0.01 or r * battle.zoom() < 0.6: return
        draw_set_transform(p, ang); draw_texture_rect(tex, Rect2(-r, -r, 2 * r, 2 * r), false, c); draw_set_transform(Vector2.ZERO)

    ## A streak along a particle's motion: spray, sparks and debris read as fast things, not dots.
    func _streak(q, k: float, col: Color, mn: float, glow: bool) -> void:
        var v: Vector2 = q.vel; var sp := v.length()
        var len := clampf(sp * 0.07, q.size * 1.5, q.size * 22.0); var dir := v / maxf(sp, 0.001)
        draw_line(q.pos, q.pos - dir * len, col, maxf(q.size * 0.6, mn * 1.1))
        if glow: _puff(GameData.glow_tex(), q.pos, maxf(q.size * 2.5, 2.0 * mn), Color(col, col.a * 0.6))

    ## The new splash (Settings.splash "new"; BattleSim.fx_splash_new). A column seen from above: its top, white, with a lit
    ## crown and a shaded side, leaning downwind as it stands, and its shadow laid across the sea away from the sun as
    ## long as it is tall; as it falls, a ragged curtain of spray ringing out and a low surge running on beyond it.
    func _night_k(p: Vector2) -> float:
        var sim: BattleSim = battle.sim
        return 0.45 if (sim.wx.get("night", false) and not sim.star_lit(p)) else 1.0
    static func _hash(a: float, b: float) -> float: return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)
    func _columns() -> void:
        var sim: BattleSim = battle.sim
        if not sim.modern: return
        var z: float = battle.zoom(); var mn: float = 1.0 / z
        var sun: Vector2 = BattleSim.SUN.normalized(); var wind: Vector2 = BattleSim.WIND.normalized()
        for q in battle.splash_parts()[0]:
            var e: float = q.life; var sz: float = q.size; var R: float = sz; var H: float = sz * 3.8; var stand: float = BattleSim.col_stand(sz)
            var rise: float = minf(1.0, e / 1.6); var fallK: float = clampf((e - 1.6 - stand) / 2.4, 0.0, 1.0)
            var h: float = H * sin(rise * PI * 0.5) * (1.0 - fallK)
            var nk: float = _night_k(q.pos); var cl: Texture2D = GameData.fx_tex("cloud%d" % int(maxi(0, q.v) % 4))
            var big: bool = R * z > 2.0     # far out a column is a few pixels: no shadow
            var fine: bool = R * z > 5.0    # and only a column of some size on the screen has a crown, a curtain and a surge
            # its shadow on the sea (a sun some 35 degrees up: the shadow is about 1.35 times the height)
            if big and h > 1.0:   # an ellipse laid away from the sun, a soft rim round a firmer body
                var L: float = h * 1.35; var sa: float = (1.0 if nk > 0.9 else 0.3) * minf(1.0, h / (H * 0.3))
                for layer in [[1.18, 0.14], [1.0, 0.3]]:
                    var pts := PackedVector2Array()
                    for i in 20:
                        var an: float = i * TAU / 20.0; var rag: float = 1.0 + 0.12 * (_hash(float(i), float(q.v)) - 0.5)
                        pts.append(q.pos + (sun * L * 0.5) + (sun * cos(an) * L * 0.55 + Vector2(-sun.y, sun.x) * sin(an) * R * 0.8) * float(layer[0]) * rag)
                    draw_colored_polygon(pts, Color(0.0, 0.03, 0.05, float(layer[1]) * sa))
            # the curtain and the surge as it falls
            if fine and fallK > 0.0:
                var rr: float = R * (1.1 + 2.2 * fallK)
                for i in 14:
                    var an: float = i * TAU / 14.0 + float(q.v); var jag: float = _hash(float(i), float(q.v) + q.pos.x * 0.01)
                    var r1: float = rr * (0.85 + 0.3 * jag)
                    _rpuff(cl, q.pos + Vector2.from_angle(an) * r1, R * 0.36 * (1.0 - fallK * 0.5), an * 2.0, Color(0.93 * nk, 0.97 * nk, 0.96 * nk, 0.55 * (1.0 - fallK) * (0.5 + jag)))
                var sk: float = clampf((e - 1.6 - stand) / 6.0, 0.0, 1.0)
                if sk < 1.0:
                    var r2: float = R * (2.0 + 5.0 * sk); var w: float = maxf(2.2 * (1.0 - sk) + 0.4, 1.0 * mn)
                    for j in 24:
                        if _hash(float(j), float(q.v) * 3.1 + floor(sk * 4.0)) < 0.35: continue   # broken, not a ring
                        var a0: float = j * TAU / 24.0; var rj: float = r2 * (0.9 + 0.2 * _hash(float(j) + 7.0, float(q.v)))
                        draw_arc(q.pos, rj, a0, a0 + TAU / 24.0, 4, Color(0.86 * nk, 0.93 * nk, 0.92 * nk, 0.28 * (1.0 - sk)), w * 0.8)
            # the column's top, leaning downwind; a mist of spray about it
            if h > 0.5:
                var lean: Vector2 = wind * h * 0.08; var c: Vector2 = q.pos + lean; var r: float = R * (0.75 + 0.35 * rise) * (1.0 + 0.6 * fallK)
                var a: float = clampf(h / (H * 0.15), 0.0, 1.0)
                _rpuff(cl, c, r * 1.3, q.a, Color(0.62 * nk, 0.74 * nk, 0.76 * nk, 0.35 * a))
                if fine:   # a lumpy crown of thrown water, not a ball: puffs round the middle, each its own size
                    for i in 9:
                        var j: float = _hash(float(i) + 3.0, float(q.v) + q.pos.y * 0.013); var j2: float = _hash(float(i) + 11.0, q.pos.x * 0.017)
                        var an: float = q.a + i * TAU / 9.0 + (j2 - 0.5) * 0.9
                        _rpuff(GameData.fx_tex("cloud%d" % (i % 4)), c + Vector2.from_angle(an) * r * (0.2 + 0.45 * j), r * (0.3 + 0.35 * j2), an * 1.7, Color(0.9 * nk, 0.95 * nk, 0.95 * nk, (0.6 + 0.3 * j) * a))
                _rpuff(cl, c, r * 0.8, q.a + 1.0, Color(0.95 * nk, 0.98 * nk, 0.97 * nk, 0.95 * a))
                if fine:
                    _rpuff(cl, c + sun * r * 0.25, r * 0.65, q.a + 2.0, Color(0.47 * nk, 0.58 * nk, 0.63 * nk, 0.4 * a))   # its shaded side
                    _rpuff(cl, c - sun * r * 0.22, r * 0.45, q.a + 3.0, Color(nk, nk, nk, 0.7 * a))                    # its lit crown

    ## What the new splash leaves on the sea: paler churned water, then a thin lace of foam with dark water between,
    ## stretched downwind, drifting and fading (GameData.lace_tex). Drawn on the sea, under the ships.
    func _laces() -> void:
        var sim: BattleSim = battle.sim
        if not sim.modern: return
        var glow: Texture2D = GameData.glow_tex(); var wind: Vector2 = BattleSim.WIND.normalized()
        for q in battle.splash_parts()[1]:
            var e: float = q.life; var k: float = clampf(e / q.mx, 0.0, 1.0); var sz: float = q.size; var nk: float = _night_k(q.pos)
            var ak: float = minf(1.0, e / 1.5) * (1.0 - k)
            _puff(glow, q.pos, sz * (1.8 + 0.05 * e), Color(0.25 * nk, 0.55 * nk, 0.52 * nk, 0.3 * ak))   # aerated water, paler green
            var t0: float = (1.6 + BattleSim.col_stand(sz)) * 0.8
            if e > t0:
                var la: float = minf(1.0, (e - t0) / 2.5) * pow(1.0 - k, 1.4) * 0.85; var r: float = sz * (3.0 + 2.5 * k)
                if la > 0.01 and r * battle.zoom() > 1.0:
                    draw_set_transform(q.pos, wind.angle() + q.a * 0.15, Vector2(1.45, 0.85))
                    draw_texture_rect(GameData.lace_tex(maxi(0, q.v) % 3), Rect2(-r, -r, 2 * r, 2 * r), false, Color(0.92 * nk, 0.97 * nk, 0.95 * nk, la))
                    draw_set_transform(Vector2.ZERO)

    ## Columns of water thrown up by shells and depth charges: one quad each, drawn by shaders/burst.gdshader (the
    ## progress, a seed and whether it is a depth charge ride in the quad's colour).
    func _bursts() -> void:
        var sim: BattleSim = battle.sim
        if not sim.modern: return
        var vr: Rect2 = battle.view_rect().grow(300); var mn: float = 1.0 / battle.zoom()
        for q in sim.parts:
            if q.life < 0 or (q.t != P.SPLASH and q.t != P.GEYSER and q.t != P.DC) or not vr.has_point(q.pos): continue
            var deep: bool = q.t == P.DC; var R: float = maxf(q.size * (1.5 if deep else 1.0), 2.0 * mn)
            draw_rect(Rect2(q.pos - Vector2(R, R) * 4.0, Vector2(R, R) * 8.0), Color(clampf(q.life / q.mx, 0.0, 1.0), fposmod(q.pos.x * 0.0137 + q.pos.y * 0.0071, 1.0), 1.0 if deep else 0.0, clampf((q.size / mn - 1.5) / 3.0, 0.0, 1.0)))

    ## Star shell: a hard white light hanging over the sea, flickering, and the pool it throws on the water.
    func _flares() -> void:
        var sim: BattleSim = battle.sim
        if sim.flares.is_empty(): return
        var glow: Texture2D = GameData.glow_tex(); var tn: float = Time.get_ticks_msec() / 1000.0; var mn: float = 1.0 / battle.zoom()
        for f in sim.flares:
            var t: float = f.t
            if t <= 0.0: continue
            var k: float = clampf(t / 1.5, 0.0, 1.0) * clampf((BattleSim.STAR_LIFE - t) / 5.0, 0.0, 1.0) * (0.85 + 0.15 * sin(tn * 23.0 + float(f.v)))
            _puff(glow, f.p, BattleSim.STAR_R * 1.25, Color(0.75, 0.8, 0.7, 0.2 * k))       # the pool of light on the sea
            _puff(glow, f.p, BattleSim.STAR_R * 0.5, Color(0.9, 0.92, 0.8, 0.16 * k))
            # the flare itself: a point of light hanging over the pool, the same few pixels at any zoom (it was at least 60 m
            # across, and close in two or three of them whited out the screen through the bloom; 12 Nov 2026)
            _puff(glow, f.p, 46.0 * mn, Color(1.0, 0.96, 0.82, 0.32 * k))   # its halo in the murk
            _puff(glow, f.p, 14.0 * mn, Color(1.0, 0.98, 0.9, 0.95 * k))
            _puff(glow, f.p, 5.0 * mn, Color(1.0, 1.0, 1.0, k))

    ## Scars shells have left on the islands: churned, blackened earth (and scorched where an incendiary burned).
    func _scars() -> void:
        var sim: BattleSim = battle.sim
        if sim.scars.is_empty(): return
        var vr: Rect2 = battle.view_rect().grow(100)
        for c in sim.scars:
            if not vr.has_point(c.p): continue
            var tex: Texture2D = GameData.fx_tex("cloud%d" % int(c.v)); var r: float = float(c.r)
            _rpuff(tex, c.p, r * 1.7, float(c.v) * 1.9, Color(0.17, 0.13, 0.09, 0.6))
            _rpuff(tex, c.p, r * 0.9, float(c.v) * 0.7 + 1.0, Color(0.05, 0.04, 0.03, 0.75))
            if float(c.burn) > 0.0: _puff(GameData.glow_tex(), c.p, r * 3.0, Color(1.0, 0.45, 0.12, 0.25))

    ## Smoke screens: each cell of BattleSim.screens as a bank of pale smoke over the ships (it hides what is in it).
    func _screens() -> void:
        var sim: BattleSim = battle.sim
        if sim.screens.is_empty(): return
        var vr: Rect2 = battle.view_rect().grow(400)
        for c in sim.screens:
            if not vr.has_point(c.p): continue
            var tex: Texture2D = GameData.fx_tex("cloud%d" % int(c.v)); var t: float = c.t; var r: float = float(c.r) * 1.35
            var a: float = 0.78 * minf(1.0, t / 3.0) * clampf((BattleSim.SMOKE_LIFE - t) / 18.0, 0.0, 1.0)
            var ang: float = float(c.v) * 1.3 + t * 0.03
            _rpuff(tex, c.p, r, ang, Color(0.5, 0.52, 0.53, a))                      # grey, below what the bloom pass picks up
            _rpuff(tex, c.p - BattleSim.SUN * r * 0.12, r * 0.72, ang + 1.1, Color(0.66, 0.68, 0.68, a * 0.5))
            _rpuff(tex, c.p + BattleSim.SUN * r * 0.16, r * 0.8, ang + 2.3, Color(0.3, 0.32, 0.34, a * 0.35))   # its shaded side

    ## What a shell leaves on the sea: a foam patch and a spreading trough, one quad each (shaders/wash.gdshader).
    ## The foam on the sea. `top`: the pass over the ships, which draws only the young foam of a burst against a ship's
    ## side and lets it go (the fade is carried in the quad's blue, 0..0.49) as it settles back onto the sea.
    func _wash(top := false) -> void:
        var sim: BattleSim = battle.sim
        if not sim.modern: return
        var vr: Rect2 = battle.view_rect().grow(300); var mn: float = 1.0 / battle.zoom()
        for q in sim.parts:
            if q.life < 0 or not vr.has_point(q.pos): continue
            if q.t == P.BLAST:   # a gun's blast on the sea: the quad is turned to the line of fire
                if top: continue
                var rb: float = maxf(q.size, 2.0 * mn)
                draw_set_transform(q.pos, q.a, Vector2.ONE)
                draw_rect(Rect2(-Vector2(rb, rb) * 2.0, Vector2(rb, rb) * 4.0), Color(clampf(q.life / q.mx, 0.0, 1.0), fposmod(q.pos.x * 0.0211 + q.pos.y * 0.0133, 1.0), 1.0, clampf((q.size / mn - 2.0) / 4.0, 0.0, 1.0)))
                draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE); continue
            if q.t != P.WASH: continue
            var age: float = clampf(q.life / q.mx, 0.0, 1.0); var gone := 0.0
            if top:
                if not q.over or age > 0.28: continue
                gone = smoothstep(0.08, 0.28, age) * 0.49
            var R: float = maxf(q.size, 1.5 * mn)
            draw_rect(Rect2(q.pos - Vector2(R, R) * 4.0, Vector2(R, R) * 8.0), Color(age, fposmod(q.pos.x * 0.0173 + q.pos.y * 0.0091, 1.0), gone, clampf((q.size / mn - 1.5) / 3.0, 0.0, 1.0)))

    ## An aircraft in plan, in metres (nose along +x): a shadow on the sea first, then the machine in its service
    ## paint with the light on one wing, its canopy, markings, and the propeller's disc or the jet's exhaust.
    func _aircraft(p: Vector2, a: float, sc: float, jet: bool, side: int, torp: bool, sun: Vector2) -> void:
        PlaneArt.draw(self, p, a, sc, jet, side, torp, sun)

    ## A missile in plan (nose along +x): its shadow, the body with wings and fins, and the motor's flame.
    func _missile(m, sc: float, sun: Vector2) -> void:
        var sam: bool = m.kind == "sam"; var L: float = 5.6 if sam else 7.2; var body: Color = Color(0.86, 0.88, 0.87) if sam else (Color(0.78, 0.76, 0.72) if m.side else Color(0.8, 0.82, 0.84))
        var alt: float = 70.0 if sam else 12.0
        var shape := PackedVector2Array([Vector2(L / 2, 0), Vector2(L / 2 - 1.3, -0.36), Vector2(-L / 2, -0.36), Vector2(-L / 2, 0.36), Vector2(L / 2 - 1.3, 0.36)])
        var wings := [PackedVector2Array([Vector2(0.6, -0.3), Vector2(-0.8, -1.5), Vector2(-1.6, -1.5), Vector2(-1.2, -0.3)]), PackedVector2Array([Vector2(0.6, 0.3), Vector2(-1.2, 0.3), Vector2(-1.6, 1.5), Vector2(-0.8, 1.5)]),
            PackedVector2Array([Vector2(-L / 2 + 1.0, -0.3), Vector2(-L / 2 + 0.1, -1.05), Vector2(-L / 2, -1.05), Vector2(-L / 2, -0.3)]), PackedVector2Array([Vector2(-L / 2 + 1.0, 0.3), Vector2(-L / 2, 0.3), Vector2(-L / 2, 1.05), Vector2(-L / 2 + 0.1, 1.05)])]
        draw_set_transform(m.pos + sun * alt * 0.5, m.a, Vector2(sc, sc))
        draw_colored_polygon(shape, Color(0, 0.03, 0.05, 0.3)); for w in wings: draw_colored_polygon(w, Color(0, 0.03, 0.05, 0.3))
        draw_set_transform(m.pos, m.a, Vector2(sc, sc))
        var fl: float = 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.06 + m.pos.x)
        # the flame: a white-hot core in a long orange tongue, and its glow on the smoke behind
        draw_texture_rect(GameData.glow_tex(), Rect2(-L / 2 - 9.0, -4.5, 11.0, 9.0), false, Color(1, 0.55, 0.2, 0.5 * fl))
        draw_colored_polygon(PackedVector2Array([Vector2(-L / 2, -0.42), Vector2(-L / 2 - 4.6 * fl, 0), Vector2(-L / 2, 0.42)]), Color(1, 0.62, 0.22, 0.9))
        draw_colored_polygon(PackedVector2Array([Vector2(-L / 2, -0.24), Vector2(-L / 2 - 2.2 * fl, 0), Vector2(-L / 2, 0.24)]), Color(1, 0.96, 0.8, 0.95))
        var rs: Vector2 = sun.rotated(-m.a)
        for i in wings.size(): draw_colored_polygon(wings[i], body.darkened(0.3 if (rs.y > 0.0) == (i % 2 == 1) else 0.12))
        draw_colored_polygon(shape, body)
        draw_line(Vector2(L / 2 - 1.4, -0.12 * signf(rs.y)), Vector2(-L / 2, -0.12 * signf(rs.y)), body.lightened(0.35), 0.16)       # the lit flank
        draw_line(Vector2(L / 2 - 1.4, 0.24 * signf(rs.y)), Vector2(-L / 2, 0.24 * signf(rs.y)), body.darkened(0.35), 0.14)         # the shaded one
        draw_colored_polygon(PackedVector2Array([Vector2(L / 2, 0), Vector2(L / 2 - 1.3, -0.36), Vector2(L / 2 - 1.3, 0.36)]), Color(0.75, 0.3, 0.2) if m.side else Color(0.9, 0.82, 0.45))   # the nose in its side's colour
        draw_line(Vector2(0.2, -0.36), Vector2(0.2, 0.36), Color(0.15, 0.16, 0.17), 0.14)                                           # a joint band

    func _parts(layer: int) -> void:
        if battle.sim.modern: _parts_modern(layer)
        else: _parts_classic(layer)

    ## The modern effects. Water (layer 0) and smoke (layer 1) blend normally; layer 2 is additive light: fire, flashes,
    ## shockwaves, sparks and the pools of light they throw on the sea and the hulls.
    func _parts_modern(layer: int) -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom(); var mn = 1.0 / z
        var vr: Rect2 = battle.view_rect().grow(400)
        var puff = GameData.fx_tex("puff"); var glow = GameData.glow_tex(); var ring = GameData.ring_tex()
        var clouds = [GameData.fx_tex("cloud0"), GameData.fx_tex("cloud1"), GameData.fx_tex("cloud2"), GameData.fx_tex("cloud3")]
        var tn = Time.get_ticks_msec() / 1000.0; var sun: Vector2 = -BattleSim.SUN.normalized()
        if layer == 2 and sim.flash > 0.0: draw_rect(vr, Color(1, 0.78, 0.5, 0.12 * sim.flash * sim.flash))
        # far out, a puff of smoke is a few pixels across: its lit side and shadow are drawn only from close in, and a
        # particle under a quarter of a pixel is not drawn at all (a ten-ship action at the widest zoom spent ten
        # milliseconds a frame drawing nearly two thousand of them, most twice or three times; 12 Nov 2026)
        var lod: bool = z < 0.35; var tiny: float = 0.25 / z
        for q in sim.parts:
            if q.life < 0 or q.size < tiny or not vr.has_point(q.pos): continue
            var k: float = q.life / q.mx; var cl: Texture2D = clouds[q.v]
            if layer == 0:
                match q.t:
                    P.FOAM: if z >= 0.12: _rpuff(cl, q.pos, q.size * (1 + k), q.a, Color(0.88, 0.94, 0.94, 0.34 * (1 - k) * (0.85 + 0.15 * sin(tn * 1.7 + q.pos.x * 0.05))))
                    P.CHURN: _rpuff(cl, q.pos, q.size * (1 + k * 1.6), q.a, Color(0.9, 0.95, 0.95, 0.22 * (1 - k) * minf(1.0, q.life * 3.0)))
                    P.SPRAY:   # a cloud of droplets thrown out, drawn out along its flight
                        var v: Vector2 = q.vel; var st := 1.0 + clampf(v.length() * 0.02, 0.0, 1.4)
                        draw_set_transform(q.pos, v.angle(), Vector2(st, 1.0))
                        var r := maxf(q.size * (0.8 + k * 0.9), mn); draw_texture_rect(cl, Rect2(-r, -r, 2 * r, 2 * r), false, Color(0.96, 0.99, 0.99, 0.8 * pow(1 - k, 1.5)))
                        draw_set_transform(Vector2.ZERO)
                    P.WRING: _puff(ring, q.pos, maxf(q.size * (0.12 + sqrt(k)), 2 * mn), Color(0.9, 0.96, 0.96, 0.32 * (1 - k) * (1 - k)))
                    _: pass
                if q.t in [P.OIL, P.SWAKE, P.TWAKE]: _part_classic(0, q, k, cl, puff, foam_tex(), mn, z, tn)   # (a gun's blast on the sea is drawn by the wash layer)
            elif layer == 1:
                match q.t:
                    P.DIRT: _streak(q, k, Color(0.2, 0.16, 0.11, 1.0 - k * k), mn, false)   # clods thrown up from a hit on land
                    P.SMOKE, P.GUNSMOKE, P.FUNNEL, P.STEAM, P.DUST:
                        # shaded smoke: a body that rolls as it rises, lit on the sun's side; fresh smoke over a fire glows
                        var base: Color; var hi: Color; var a: float; var grow: float
                        if q.t == P.SMOKE: base = Color(0.2, 0.2, 0.21); hi = Color(0.5, 0.5, 0.5); a = 0.55 * (1 - k) * minf(1.0, q.life * 4); grow = 1 + k * 2.4
                        elif q.t == P.DUST: base = Color(0.4, 0.33, 0.23); hi = Color(0.74, 0.66, 0.5); a = 0.7 * minf(1.0, q.life * 6) * pow(1 - k, 1.2); grow = 1 + sqrt(k) * 2.6
                        elif q.t == P.STEAM: base = Color(0.82, 0.84, 0.85); hi = Color(1, 1, 1); a = 0.5 * minf(1.0, q.life * 5) * pow(1 - k, 1.4); grow = 1 + sqrt(k) * 2.6
                        elif q.t == P.GUNSMOKE: base = Color(0.24, 0.21, 0.17); hi = Color(0.55, 0.5, 0.42); a = 0.72 * minf(1.0, q.life * 6) * pow(1 - k, 1.3); grow = 1 + sqrt(k) * 3.4
                        else: base = Color(0.3, 0.3, 0.32); hi = Color(0.62, 0.62, 0.64); a = 0.24 * (1 - k); grow = 1 + k * 2.2
                        var warm := clampf(1.0 - q.life / 1.4, 0.0, 1.0) if q.t == P.SMOKE else 0.0
                        base = base.lerp(Color(0.45, 0.24, 0.1), warm * 0.7); var r: float = q.size * grow
                        var ang: float = q.a + q.v * 1.3 + q.life * (0.15 if q.v % 2 else -0.15)
                        _rpuff(cl, q.pos, r, ang, Color(base, a))
                        if not lod: _rpuff(cl, q.pos + sun * r * 0.14, r * 0.72, ang + 0.8, Color(hi, a * 0.28))
                    P.MTRAIL:   # a missile's smoke trail: white, lit on the sun's side, curling as it spreads
                        var r: float = maxf(q.size, 1.2 * mn) * (0.7 + k * 2.6); var a: float = 0.6 * pow(1 - k, 1.2) * minf(1.0, q.life * 10.0)
                        var ang: float = q.v * 1.3 + q.life * (0.5 if q.v % 2 else -0.5)
                        _rpuff(cl, q.pos, r, ang, Color(0.86, 0.87, 0.86, a))
                        if not lod: _rpuff(cl, q.pos + sun * r * 0.14, r * 0.7, ang + 0.9, Color(1, 1, 1, a * 0.35)); _rpuff(cl, q.pos - sun * r * 0.16, r * 0.75, ang - 0.7, Color(0.45, 0.47, 0.5, a * 0.3))
                    P.SOOT:   # the black heart of a big explosion: oily smoke boiling up through the fire, lit red from inside at first
                        var r: float = q.size * (0.7 + 2.6 * sqrt(k)); var a := 0.82 * minf(1.0, q.life * 5.0) * pow(1 - k, 0.9)
                        var hot := clampf(1.0 - q.life / 0.9, 0.0, 1.0)
                        _rpuff(cl, q.pos, r, q.a, Color(Color(0.07, 0.065, 0.06).lerp(Color(0.5, 0.16, 0.04), hot * 0.8), a))
                        if not lod: _rpuff(cl, q.pos + sun * r * 0.16, r * 0.66, q.a + 1.1, Color(0.36, 0.34, 0.32, a * 0.3))
                    _: _part_classic(1, q, k, cl, puff, foam_tex(), mn, z, tn)
            else:
                match q.t:
                    P.CORE:
                        var r = maxf(q.size, 3 * mn)
                        _puff(glow, q.pos, r * (0.55 + k * 0.8), Color(1, 0.9, 0.72, 0.62 * pow(1 - k, 1.5)))
                        _puff(puff, q.pos, r * 0.36 * (1 - k), Color(1, 1, 1, 1 - k))
                    P.FIREBALL:
                        var c: Color
                        if k < 0.12: c = Color(1, 0.9, 0.66).lerp(Color(1, 0.55, 0.18), k / 0.12)
                        elif k < 0.5: c = Color(1, 0.55, 0.18).lerp(Color(0.7, 0.18, 0.05), (k - 0.12) / 0.38)
                        else: c = Color(0.7, 0.18, 0.05).lerp(Color(0.15, 0.04, 0.02), (k - 0.5) / 0.5)
                        var fr: float = maxf(q.size, 2 * mn) * (0.55 + 1.15 * sqrt(k))
                        _rpuff(cl, q.pos, fr, q.a, Color(c, 0.5 * pow(1 - k, 1.2)))
                        _rpuff(clouds[(q.v + 1) % 4], q.pos, fr * 0.6, -q.a * 1.7, Color(c.lightened(0.25), 0.34 * pow(1 - k, 2.0)))   # a brighter, tighter lobe turning the other way
                    P.FLARE:   # glare: a thin streak of light across the burst, and a shorter one down it
                        var r = maxf(q.size, 6 * mn) * (0.7 + 0.6 * k); var al := pow(1 - k, 2.0)
                        draw_set_transform(q.pos, 0.0, Vector2(3.2, 0.09)); draw_texture_rect(glow, Rect2(-r, -r, 2 * r, 2 * r), false, Color(1, 0.93, 0.8, 0.85 * al))
                        draw_set_transform(q.pos, 0.0, Vector2(0.07, 1.1)); draw_texture_rect(glow, Rect2(-r, -r, 2 * r, 2 * r), false, Color(1, 0.9, 0.75, 0.5 * al))
                        draw_set_transform(Vector2.ZERO)
                    P.RING: _puff(ring, q.pos, maxf(q.size * (0.08 + 1.0 - pow(1 - k, 3)), 2 * mn), Color(1, 0.86, 0.62, 0.38 * (1 - k) * (1 - k)))
                    P.DEBRIS: _streak(q, k, Color(1, 0.72 - k * 0.3, 0.32 - k * 0.2, 1 - k), mn, true)
                    P.SPARK: _streak(q, k, Color(1, 0.8, 0.45, 1 - k), mn, false)
                    P.EMBER: _puff(puff, q.pos, maxf(q.size, mn), Color(1, 0.5, 0.15, (1 - k) * (0.55 + 0.45 * sin(tn * 19 + q.pos.x * 0.3))))
                    P.GLOW: _puff(glow, q.pos, q.size * (0.8 + 0.3 * k), Color(1, 0.56, 0.24, 0.24 * pow(1 - k, 1.6)))
                    P.FIRE:
                        var r = maxf(q.size, 1.5 * mn); var fl = 0.75 + 0.25 * sin(tn * 31 + q.pos.x)
                        _puff(glow, q.pos, r * 3.0, Color(1, 0.5, 0.18, 0.18 * (1 - k) * fl))
                        _part_classic(2, q, k, cl, puff, foam_tex(), mn, z, tn)
                    _: _part_classic(2, q, k, cl, puff, foam_tex(), mn, z, tn)

    func foam_tex() -> Texture2D: return GameData.fx_tex("foam")

    ## The classic look for one particle (also used by the modern renderer for kinds it doesn't change).
    func _part_classic(layer: int, q, k: float, cl: Texture2D, puff: Texture2D, foam: Texture2D, mn: float, z: float, tn: float) -> void:
        _one(layer, q, k, cl, puff, mn, z, tn)

    func _parts_classic(layer: int) -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom(); var mn = 1.0 / z
        var vr: Rect2 = battle.view_rect().grow(300)
        var puff = GameData.fx_tex("puff"); var foam = GameData.fx_tex("foam")
        var clouds = [GameData.fx_tex("cloud0"), GameData.fx_tex("cloud1"), GameData.fx_tex("cloud2"), GameData.fx_tex("cloud3")]
        var tn = Time.get_ticks_msec() / 1000.0
        for q in sim.parts:
            if q.life < 0 or not vr.has_point(q.pos): continue
            var k = q.life / q.mx; var cl: Texture2D = clouds[q.v]
            _one(layer, q, k, cl, puff, mn, z, tn)

    ## One particle in the classic look.
    func _one(layer: int, q, k: float, cl: Texture2D, puff: Texture2D, mn: float, z: float, tn: float) -> void:
        if layer == 0:
            match q.t:
                P.FOAM: if z >= 0.12: _puff(cl, q.pos, q.size * (1 + k), Color(0.86, 0.93, 0.93, 0.3 * (1 - k)))
                P.OIL: _puff(cl, q.pos, q.size * (0.6 + k * 0.8), Color(0.05, 0.06, 0.07, 0.45 * (1 - k * k)))
                P.SWAKE: draw_arc(q.pos, q.size * (1 + k * 2), 0, TAU, 24, Color(0.88, 0.94, 0.94, 0.12 * (1 - k)), maxf(mn, 1.5))
                P.TWAKE: _puff(puff, q.pos, maxf(q.size * (1 + k * 2), 0.9 * mn), Color(0.85, 0.93, 0.93, 0.28 * (1 - k) * minf(1.0, q.life * 2.0)))
                P.SPLASH, P.GEYSER:
                    var r = maxf(q.size, 2 * mn)
                    _puff(puff, q.pos, r * (0.5 + 0.9 * sqrt(k)), Color(0.97, 0.99, 0.99, 0.95 * (1 - k) * (1 - k)))
                    draw_arc(q.pos, r * (0.4 + k * 1.6), 0, TAU, 32, Color(0.92, 0.97, 0.97, 0.6 * (1 - k)), maxf(mn, r * 0.08))
                P.BLAST: # the muzzle blast pressing on the sea: a half ring spreading out along the line of fire, not back across the ship
                    draw_arc(q.pos, q.size * (0.3 + k), q.a - 1.25, q.a + 1.25, 24, Color(0.88, 0.93, 0.93, 0.45 * (1 - k)), maxf(mn, q.size * 0.1 * (1 - k)))
                    _puff(puff, q.pos + Vector2.from_angle(q.a) * q.size * (0.2 + 0.4 * k), q.size * (0.25 + k * 0.6), Color(0.82, 0.89, 0.9, 0.25 * (1 - k)))
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

    ## Torpedoes run a few metres down: a dark shape seen through the water, a paler body that comes and goes with
    ## the swell (warm-tinted for the enemy's, so they can still be picked out), under the ships, not over them.
    const TWAKE_B := 2.2   # a torpedo's wake is drawn as for a hull this wide (metres)
    func _torpedoes() -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom(); var mn = 1.0 / z; var tn = Time.get_ticks_msec() / 1000.0
        if sim.modern:   # the wakes of torpedoes already gone, fading where they lie
            for tr in sim.twakes:
                var pts: Array = []
                for i in range(tr.size() - 1, -1, -1): pts.append(tr[i])
                _ribbon(pts, 0, TWAKE_B, 0.3, sim.vt, TWAKE_B * 6.0, Color(0.88, 0.96, 0.96))
        for tp in sim.torps:
            var vis: bool = tp.side == 0 or tp.arm < -20 or (sim.flag != null and tp.pos.distance_to(sim.flag.pos) < 2500)
            if not vis: continue
            var d := Vector2.from_angle(tp.a); var nr := Vector2(-d.y, d.x); var tl := maxf(7.0, 9.0 * mn); var w := maxf(0.8, 1.6 * mn)
            var shim := 0.75 + 0.25 * sin(tn * 3.0 + tp.pos.x * 0.05)
            var core: Color = Color(0.85, 0.62, 0.52) if tp.side else Color(0.62, 0.8, 0.8)
            if not sim.modern:
                draw_line(tp.pos + d * tl * 0.1, tp.pos - d * tl * 1.1, Color(0.02, 0.08, 0.1, 0.45), w * 2.2)   # the shadow in the water
                draw_line(tp.pos, tp.pos - d * tl, Color(core, 0.38 * shim), w); continue
            # A torpedo running a few metres down. The light bends through the swell above it, so the body wavers and
            # breaks into pieces; its shadow lies deeper, away from the sun; a pale sheen follows it on the surface; and
            # the exhaust comes up astern as a thread of bubbles that widens and fades.
            var glow: Texture2D = GameData.glow_tex(); var foam: Texture2D = GameData.fx_tex("foam")
            var sun: Vector2 = -BattleSim.SUN.normalized(); var ph: float = tp.pos.x * 0.031 + tp.pos.y * 0.017
            var wob := func(k: float) -> Vector2: return nr * sin(tn * 4.2 + ph + k * 2.3) * w * 0.7
            # her wake (the owner: like a ship's, but smaller and more discreet): a narrow ribbon of the same foam, from
            # where she is back along her track (it used to be a string of bubble puffs)
            var pts: Array = [{"p": tp.pos, "t": sim.vt, "a": tp.a, "v": float(tp.speed)}]
            var tr: Array = tp.get("trail", [])
            for i in range(tr.size() - 1, -1, -1): pts.append(tr[i])
            if pts.size() >= 2: _ribbon(pts, 0, TWAKE_B, 0.3, sim.vt, TWAKE_B * 6.0, Color(0.88, 0.96, 0.96))
            _puff(glow, tp.pos - d * tl * 0.5 - sun * w * 3.0, tl * 0.95, Color(0.0, 0.03, 0.05, 0.42))                  # the shadow, deeper and down-sun
            draw_set_transform(tp.pos - d * tl * 0.5, tp.a, Vector2(1.0, 0.34)); draw_texture_rect(glow, Rect2(-tl * 1.2, -tl * 1.2, tl * 2.4, tl * 2.4), false, Color(0.45, 0.78, 0.8, 0.13 * shim)); draw_set_transform(Vector2.ZERO)   # the sheen of the water over it
            var segs := 6   # the body, in short lengths that shift with the swell (refraction)
            for i in segs:
                var k0 := float(i) / segs; var k1 := float(i + 1) / segs
                var a0: Vector2 = tp.pos - d * tl * k0 + wob.call(k0); var a1: Vector2 = tp.pos - d * tl * k1 + wob.call(k1)
                var al := (0.55 if i % 2 == 0 else 0.4) * shim * (1.0 - 0.5 * k0)
                draw_line(a0, a1, Color(core.darkened(0.25), al), w * (1.25 - 0.5 * k0))
            draw_circle(tp.pos + wob.call(0.0), w * 0.62, Color(core.lightened(0.2), 0.55 * shim))                            # the warhead, the brightest part
            var gl := pow(maxf(0.0, sin(tn * 2.6 + ph * 3.0)), 10.0)                                                        # now and then a ripple above it catches the sun
            if gl > 0.05: _puff(foam, tp.pos - d * tl * 0.4 + nr * w, maxf(w * 1.4, 1.5 * mn) * (1.0 + gl), Color(1, 1, 1, 0.55 * gl))

    ## Sensors (R, docs/SENSORS.md): for each of your ships the reach of her lookouts in this weather (pale), of her
    ## radar (green, with the turning beam of a rotating set; a phased array has none) and of her sonar (blue). Radar
    ## contacts beyond the eye's reach are marked where the beam last painted them, whether or not the rings are shown.
    func _sensors(sim: BattleSim, mn: float) -> void:
        var green := Color(0.45, 0.95, 0.55); var blue := Color(0.45, 0.75, 1.0); var pale := Color(0.93, 0.94, 0.92)
        for e in sim.ships:
            if e.side != 1 or not sim.active(e) or not e.radar_only or not sim.visible_to(e, 0): continue
            var k: float = clampf(1.0 - e.paint_t / BattleSim.RADAR_PERIOD, 0.0, 1.0)
            var p: Vector2 = e.paint_pos; var r: float = 7.0 * mn
            draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Color(green, 0.25 + 0.6 * k))
            draw_arc(p, r * (1.6 + 1.2 * (1.0 - k)), 0, TAU, 20, Color(green, 0.5 * k), 1.2 * mn)
        # sonar pings running out over the sea: yours always; the enemy's when your hydrophones have heard them; the
        # echo off a dived boat (blue: a boat you have found; red, on a boat of yours: she has been found)
        for p in sim.pings:
            var mine_p: bool = p.side == 0
            if p.echo:
                var kk: float = clampf(1.0 - float(p.r) / 260.0, 0.0, 1.0); var ec: Color = blue if mine_p else Color(1.0, 0.45, 0.35)
                draw_arc(p.pos, float(p.r) * 0.5 + 6.0 * mn, 0, TAU, 28, Color(ec, 0.85 * kk), 1.6 * mn)
                draw_arc(p.pos, float(p.r) + 8.0 * mn, 0, TAU, 32, Color(ec, 0.4 * kk), 1.0 * mn)
                continue
            if not mine_p and (p.who == null or p.who.heard_t > BattleSim.HEARD_FOR): continue
            var r: float = p.r; var mx: float = p.max; var col: Color = blue if mine_p else Color(1.0, 0.6, 0.4)
            # strong while it can still find a boat, a ghost of itself beyond (where it is only heard)
            var a: float = (0.85 * (1.0 - 0.5 * r / mx)) if r <= mx else 0.2 * clampf(1.0 - (r - mx) / (mx * (BattleSim.PING_HEAR - 1.0)), 0.0, 1.0)
            if a <= 0.01 or r < 4.0: continue
            for j in 3:
                var rj: float = r - j * 26.0
                if rj > 2.0: draw_arc(p.pos, rj, 0, TAU, clampi(int(rj * battle.zoom() * 0.5), 24, 160), Color(col, a * (1.0 - j * 0.33)), (2.2 - 0.5 * j) * mn)
        if not Settings.sensors: return
        var ang := sim.radar_angle(); var labelled := false
        for o in sim.ships:
            if o.side != 0 or not sim.active(o): continue
            var mine: bool = o == sim.flag
            if sim.limited(): draw_arc(o.pos, float(sim.wx.vis), 0, TAU, 96, Color(pale, 0.22 if mine else 0.1), mn)
            if sim.has_radar(o) and not sim.submerged(o):
                var rr := sim.sight(o) if sim.limited() else float(sim.wx.radar)
                var ro: Vector2 = sim.radar_pos(o)   # the aerial on her foremast (or island): the ring and the beam turn about it
                draw_arc(ro, rr, 0, TAU, 128, Color(green, 0.4 if mine else 0.16), (1.5 if mine else 1.0) * mn)
                if not sim.phased(o):   # the beam, with its afterglow trailing behind it
                    var n := 14; var span := 0.7; var pts := PackedVector2Array([ro]); var cols := PackedColorArray([Color(green, 0.0)])
                    for i in n + 1:
                        var a := ang - span * (1.0 - float(i) / n); var kk := float(i) / n
                        pts.append(ro + Vector2.from_angle(a) * rr); cols.append(Color(green, (0.26 if mine else 0.08) * kk * kk))
                    draw_polygon(pts, cols)
                    draw_line(ro, ro + Vector2.from_angle(ang) * rr, Color(green, 0.55 if mine else 0.22), 1.2 * mn)
                if mine:
                    battle.hud_text(self, ro + Vector2(0, -rr - 8.0 * mn), "RADAR %.1f km%s" % [rr / 1000.0, " · phased array" if sim.phased(o) else ""], Color(green, 0.8), mn)
            var sr := sim.sonar_range(o) if o.sonar_on else 0.0   # silent: no ring (she hears only close to)
            if sr > 0.0:
                draw_arc(o.pos, sr, 0, TAU, 64, Color(blue, 0.45 if mine else 0.2), mn)
                if mine: battle.hud_text(self, o.pos + Vector2(0, sr + 16.0 * mn), "SONAR %.1f km" % (sr / 1000.0), Color(blue, 0.85), mn)
            if mine and sim.limited(): battle.hud_text(self, o.pos + Vector2(0, -float(sim.wx.vis) - 8.0 * mn), "LOOKOUTS %.1f km" % (float(sim.wx.vis) / 1000.0), Color(pale, 0.6), mn)

    ## Tracer from the light guns (modern effects): each burst is a handful of rounds flying out along the line, a
    ## white-hot point with a short coloured streak and a glow. The 20 mm throws a quick close string of small red
    ## rounds, the 40 mm slower, heavier amber ones in fours, and a CIWS a near-solid thread of them.
    func _tracers(sim: BattleSim, mn: float) -> void:
        var glow: Texture2D = GameData.glow_tex(); var z: float = battle.zoom()
        for tr in sim.tracers:
            var a: Vector2 = tr.a; var b: Vector2 = tr.b; var d: Vector2 = b - a; var D: float = d.length()
            if D < 1.0: continue
            var dir: Vector2 = d / D; var nrm: Vector2 = dir.orthogonal()
            var w: String = tr.get("w", ""); var k: float = 1.0 - float(tr.life) / float(tr.get("L", 0.12))   # 0 at the muzzle, 1 at the target
            var n := 4; var gap := 0.11; var sz := 1.0; var col := Color(1.0, 0.36, 0.22); var streak := 0.05
            if w == "aa40": n = 4; gap = 0.16; sz = 1.7; col = Color(1.0, 0.72, 0.3); streak = 0.07
            elif w == "ciws": n = 9; gap = 0.055; sz = 0.9; col = Color(1.0, 0.86, 0.6); streak = 0.05
            elif w != "aa20" and w != "": n = 3; gap = 0.18; sz = 1.4; col = Color(1.0, 0.7, 0.35)
            if int(tr.get("side", 0)) == 1: col = col.lerp(Color(0.75, 1.0, 0.55), 0.35)   # theirs burn a greener tracer, as many navies' did
            var wd: float = maxf(sz * 1.1, 1.6 * mn); var core: Color = col.lerp(Color(1.0, 0.97, 0.9), 0.55)
            draw_line(a, a + d * minf(1.0, k * 1.3), Color(col, 0.07 * (1.0 - k)), wd * 1.6)   # the faint smoke of the burst along its path
            for j in n:
                var t: float = k * 1.35 - j * gap + float(tr.get("ph", 0.0)) * gap * 0.5
                if t < 0.0 or t > 1.0: continue
                var head: Vector2 = a + d * t; var tail: Vector2 = head - dir * minf(D * streak, D * t)
                if head.distance_to(tail) > 0.05:   # (a streak just fired has no length: no shape to draw; drawn about its own place, as small shapes must be)
                    draw_set_transform(head)
                    draw_polygon(PackedVector2Array([tail - head, nrm * wd * 0.5, dir * wd * 0.6, -nrm * wd * 0.5]), PackedColorArray([Color(col, 0.0), Color(core, 0.95), Color(core, 0.95), Color(core, 0.95)]))
                    draw_set_transform(Vector2.ZERO)
                if z > 0.1: _puff(glow, head, wd * 4.5, Color(col, 0.6)); _puff(glow, head, wd * 1.6, Color(1.0, 0.97, 0.9, 0.8))

    ## Wreckage on the water and in the air: dark, ragged pieces, tumbling while they fly (with a shadow that closes
    ## on them as they fall) and then awash, each with a little ring of foam, fading as it sinks.
    func _wreckage() -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom()
        if sim.wrecks.is_empty() or z < 0.12: return
        var view: Rect2 = battle.view_rect().grow(50.0)
        for w in sim.wrecks:
            if not view.has_point(w.pos): continue
            var up: bool = w.air > 0.0; var sz: float = maxf(float(w.sz), 1.3 / z) * (1.0 + (0.5 * float(w.air) if up else 0.0))   # never smaller than a pixel or two: a smaller piece flickers as it moves
            var fade: float = 1.0 if up else clampf((float(w.life) - float(w.t)) / 8.0, 0.0, 1.0)
            # each piece is drawn about its own place: built out in the battle's coordinates, thousands of metres from
            # the origin, a shape this small often failed to triangulate and the piece blinked in and out
            var pts := PackedVector2Array(); var n := 5
            for k in n:
                var a: float = float(w.a) + k * TAU / n; pts.append(Vector2.from_angle(a) * sz * (0.6 + 0.8 * fposmod(sin(float(w.sd) * 0.7 + k * 3.1) * 7.3, 1.0)))
            if up:
                draw_set_transform(w.pos + BattleSim.SUN * (4.0 + 14.0 * float(w.air)))
                draw_colored_polygon(pts, Color(0, 0, 0, 0.22))
            else: draw_set_transform(Vector2.ZERO); _puff(GameData.fx_tex("cloud%d" % (int(w.sd) % 4)), w.pos, sz * 2.6, Color(0.88, 0.95, 0.95, 0.22 * fade))   # a little foam round it, soft, not a hard ring
            draw_set_transform(w.pos)
            draw_colored_polygon(pts, Color(0.16, 0.15, 0.14, 0.95 * fade) if not w.burn or not up else Color(0.3, 0.15, 0.09, 0.95))
            if sz * z > 3.0: draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2]]), Color(0.5, 0.5, 0.48, 0.7 * fade), maxf(0.15, 0.8 / z))
            if w.burn and up: draw_set_transform(Vector2.ZERO); _puff(GameData.glow_tex(), w.pos, sz * 2.2, Color(1.0, 0.6, 0.25, 0.5))   # a burning piece glows as it goes
        draw_set_transform(Vector2.ZERO)

    func _overlay() -> void:
        var sim: BattleSim = battle.sim; var z: float = battle.zoom(); var mn = 1.0 / z
        var ui: bool = not battle.clean   # with the interface hidden (H) only what is really on the sea and in the air is drawn
        if ui and sim.flag != null and not sim.waypoints.is_empty():   # the flagship's waypoints (Ctrl+Click)
            var prev: Vector2 = sim.flag.pos
            for wp in sim.waypoints:
                draw_line(prev, wp, Color(0.93, 0.94, 0.92, 0.55), 1.5 * mn); prev = wp
            for i in sim.waypoints.size():
                var wp: Vector2 = sim.waypoints[i]
                draw_circle(wp, 7.0 * mn, Color(0.05, 0.1, 0.12, 0.8)); draw_arc(wp, 7.0 * mn, 0, TAU, 20, Color(0.93, 0.94, 0.92, 0.95), 2.0 * mn)
        if ui: _sensors(sim, mn)
        # torpedo tracks, shells, missiles, aircraft and tracers
        var z0s: float = battle.zoom()
        for sh in sim.shells:
            var k: float = sh.t / sh.T; var hgt = sin(PI * k) * minf(600.0, sh.s.distance_to(sh.e) * 0.08)
            var r = maxf(1.2 * mn, {"S": 1.6, "M": 2.0, "L": 2.6, "H": 3.4}[sh.size])
            draw_circle(sh.pos, r * 0.8, Color(0, 0, 0, 0.25))
            var hc: Color = Color("#ffb38a") if sh.side else Color("#fff1c0")
            if sim.modern:
                # a hot shell with its tracer burning in the base: a white-hot head, a streak that tapers and cools to
                # red behind it along the curve of its flight, a glow that flickers as the shell spins, and close in
                # the shell itself
                var head: Vector2 = sh.pos - Vector2(0, hgt); var dir: Vector2 = (sh.e - sh.s).normalized()
                var big: float = {"S": 0.0, "M": 0.35, "L": 0.7, "H": 1.0}[sh.size]
                var tail_len: float = r * (10.0 + 10.0 * big)
                var back: Vector2 = head - dir * tail_len + Vector2(0, (sin(PI * minf(1.0, (sh.t + 0.05) / sh.T)) - sin(PI * k)) * minf(600.0, sh.s.distance_to(sh.e) * 0.08))
                var axis: Vector2 = (head - back).normalized(); var nrm: Vector2 = axis.orthogonal(); var mid: Vector2 = back.lerp(head, 0.55)
                var hot := Color(1.0, 0.97, 0.86); var cool := Color(1.0, 0.45, 0.2) if sh.side else Color(1.0, 0.62, 0.25)
                # outer glow of the streak, then its core
                # (drawn about the shell's own place: small shapes built in world coordinates fail to triangulate far out)
                var bk: Vector2 = back - head; var md: Vector2 = mid - head
                draw_set_transform(head)
                draw_polygon(PackedVector2Array([bk, md + nrm * r * 1.5, nrm * r * 1.1, -nrm * r * 1.1, md - nrm * r * 1.5]),
                    PackedColorArray([Color(cool, 0.0), Color(cool, 0.12), Color(hc, 0.3), Color(hc, 0.3), Color(cool, 0.12)]))
                draw_polygon(PackedVector2Array([bk, md + nrm * r * 0.55, nrm * r * 0.6, -nrm * r * 0.6, md - nrm * r * 0.55]),
                    PackedColorArray([Color(cool, 0.0), Color(hc, 0.55), Color(hot, 0.95), Color(hot, 0.95), Color(hc, 0.55)]))
                draw_set_transform(Vector2.ZERO)
                var fl: float = 0.8 + 0.2 * sin(sim.vt * 47.0 + sh.s.x * 0.37)   # the tracer flickers as the shell spins
                _puff(GameData.glow_tex(), head, r * (4.5 + 2.5 * big) * fl, Color(hc, 0.32 + 0.12 * big))
                _puff(GameData.glow_tex(), head, r * 1.8, Color(hot, 0.7))
                if z0s > 0.7:   # close in: the shell, base towards us, nose down her line of flight
                    var bl: float = {"S": 0.6, "M": 0.9, "L": 1.3, "H": 1.9}[sh.size]; var bw: float = bl * 0.3
                    draw_set_transform(head)
                    draw_colored_polygon(PackedVector2Array([axis * bl, axis * bl * 0.35 + nrm * bw, -axis * bl * 0.6 + nrm * bw, -axis * bl * 0.6 - nrm * bw, axis * bl * 0.35 - nrm * bw]), Color(0.16, 0.15, 0.14, 0.95))
                    draw_set_transform(Vector2.ZERO)
                    draw_circle(head - axis * bl * 0.6, bw * 0.8, hot)
                else: draw_circle(head, r * 0.75, hot)
            else: draw_circle(sh.pos - Vector2(0, hgt), r, hc)
        var z0: float = battle.zoom(); var sun_s: Vector2 = BattleSim.SUN.normalized()
        for m in sim.missiles:
            if m.delay > 0: continue
            if z0 < 0.3 or not sim.modern:   # far out, or the classic style: a mark that reads at any size
                var ms = maxf(1.0, 1.5 * mn)
                draw_set_transform(m.pos, m.a, Vector2(ms, ms))
                draw_rect(Rect2(-5, -1.3, 10, 2.6), Color("#dfe4e2") if m.kind == "sam" else (Color("#ffb38a") if m.side else Color("#fff1c0")))
                draw_circle(Vector2(-6, 0), 2.2, Color(1, 0.78, 0.35, 0.9))
                if sim.modern: draw_texture_rect(GameData.glow_tex(), Rect2(-22, -9, 18, 18), false, Color(1, 0.6, 0.25, 0.5))
                continue
            _missile(m, maxf(1.0, 1.1 * mn), sun_s)
        draw_set_transform(Vector2.ZERO)
        for q in sim.air:
            var far: bool = z0 < 0.3 or not sim.modern
            var col = Color("#e8a08a") if q.side else Color("#f3e2a8"); var ps = maxf(1.0, 1.6 * mn)
            for k in int(q.up):
                var row = ceili(k / 2.0); var sd = 1.0 if k % 2 else -1.0
                if far:
                    var p: Vector2 = q.pos + Vector2(-row * 14 * ps, sd * row * 12 * ps).rotated(q.a)
                    draw_set_transform(p, q.a, Vector2(ps, ps))
                    if q.jet: draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(-5, -6), Vector2(-3, 0), Vector2(-5, 6)]), col)
                    else: draw_rect(Rect2(-5, -1, 11, 2), col); draw_rect(Rect2(0, -7, 2.5, 14), col); draw_rect(Rect2(-5, -3, 1.5, 6), col)
                else:   # close in: the aircraft themselves, in loose formation, with their shadows on the sea
                    var sc: float = maxf(1.0, 0.8 * mn)
                    var wob: float = sin(Time.get_ticks_msec() * 0.0013 + k * 1.7) * 3.0
                    var pp: Vector2 = q.pos + Vector2(-row * 26.0 * sc, sd * row * 22.0 * sc + wob).rotated(q.a)
                    _aircraft(pp, q.a + sin(Time.get_ticks_msec() * 0.0009 + k) * 0.03, sc, q.jet, q.side, q.type == "tb", sun_s)
        # aircraft going down: the machine itself, charred and tumbling, a little smaller as she drops towards the sea
        # (her fire and smoke are particles; BattleSim.fx_plane_down)
        if sim.modern and z0 >= 0.3:
            for w in sim.falling:
                var kf: float = clampf(float(w.t) / float(w.T), 0.0, 1.0)
                PlaneArt.draw(self, w.p, float(w.a), maxf(1.0, 0.8 * mn) * (1.0 - 0.35 * kf), bool(w.jet), int(w.side), false, sun_s, 30.0 * (1.0 - kf), Color(0.17, 0.15, 0.13))
        # machines taking off and landing, one at a time: down the deck and up to the formation ahead, or round
        # from the formation astern, onto the deck and forward to the lift
        for cv in sim.ships:
            if cv.deck_ops.is_empty() or (cv.side == 1 and (sim.limited() or not sim.screens.is_empty()) and not sim.visible_to(cv, 0)): continue
            for op in cv.deck_ops:   # each is flown by the simulation (BattleSim._fly_op): here it is only drawn where it is
                var pp: Vector2 = op.pos; var pa: float = op.a; var alt: float = op.alt
                if z0 < 0.3 or not sim.modern:
                    var ps = maxf(1.0, 1.6 * mn); draw_set_transform(pp, pa, Vector2(ps, ps) * 0.7)
                    draw_rect(Rect2(-5, -1, 11, 2), Color("#e8a08a") if cv.side else Color("#f3e2a8")); draw_rect(Rect2(0, -7, 2.5, 14), Color("#e8a08a") if cv.side else Color("#f3e2a8"))
                else: PlaneArt.draw(self, pp, pa, maxf(1.0, 0.8 * mn), op.q.jet, cv.side, op.q.type == "tb", sun_s, alt)
        # floatplanes: on their catapults (with the ship's heel), and those aloft spotting
        if sim.modern and z0 >= 0.3:
            for sh in sim.ships:
                if sh.fp <= 0 or not sh.alive or sh.view == null or (sh.side == 1 and (sim.limited() or not sim.screens.is_empty()) and not sim.visible_to(sh, 0)): continue
                var cats: Array = sim.cats_of(sh); var dsh: float = sh.view.deck_shift + sh.view.lean * 2.5
                for ci in mini(sh.fp, cats.size()):
                    var c: Array = cats[ci]; var cy: float = float(c[1])
                    var ca: float = sh.a + (signf(cy) * 0.32 if cy != 0.0 else PI / 2)
                    var along: float = 7.0 if cy != 0.0 else 2.0   # out along her rail: on twin catapults, which splay outward, this keeps the two planes' wings clear of each other
                    var cp: Vector2 = sh.pos + Vector2(float(c[0]) + along * cos(ca - sh.a), cy + dsh + along * sin(ca - sh.a)).rotated(sh.a)
                    PlaneArt.draw(self, cp, ca, 1.0, false, sh.side, false, sun_s, 4.0, null, true)
        # ensigns: each ship flies her flag at the stern (yours the device you chose), streaming aft, close in
        if sim.modern and z0 >= 0.9:
            for sh in sim.ships:
                if not sh.alive or sh.sub or sh.view == null or (sh.side == 1 and (sim.limited() or not sim.screens.is_empty()) and not sim.visible_to(sh, 0)): continue
                var stern: Vector2 = sh.pos + Vector2(-sh.d.L * 0.5 + 1.2, sh.view.deck_shift + sh.view.lean * 6.0).rotated(sh.a)
                var flap: float = sin(Time.get_ticks_msec() * 0.006 + sh.pos.x) * 0.06
                draw_set_transform(stern, sh.a + PI + flap, Vector2.ONE)
                Flags.draw(self, "player" if sh.side == 0 else String(sh.pal), Rect2(0.4, -1.25, 4.0, 2.5))
            draw_set_transform(Vector2.ZERO)
        for q in sim.spotters:
            if q.side == 1 and not sim.spotter_over(1, q.pos) and (sim.limited() or not sim.screens.is_empty()) and q.pos.distance_to(sim.flag.pos if sim.flag != null else q.pos) > 3000.0: continue
            if z0 < 0.3 or not sim.modern:
                var ps2 = maxf(1.0, 1.6 * mn); draw_set_transform(q.pos, q.a, Vector2(ps2, ps2) * 0.7)
                var qc: Color = Color("#e8a08a") if q.side else Color("#f3e2a8")
                draw_rect(Rect2(-5, -1, 11, 2), qc); draw_rect(Rect2(0, -7, 2.5, 14), qc)
            else: PlaneArt.draw(self, q.pos, q.a, maxf(1.0, 0.8 * mn), false, q.side, false, sun_s, float(q.alt))
        draw_set_transform(Vector2.ZERO)
        if not sim.modern:
            for tr in sim.tracers: draw_line(tr.a, tr.b, Color(1, 0.86, 0.55, tr.life * 6), mn)
        else: _tracers(sim, mn)
        # flagship: station ring, gun range, predicted track and where each main turret is laid
        var s = sim.flag
        if ui and s != null and s.alive:
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
