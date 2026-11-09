extends Control
## Battle HUD: fleet orders, ship lists, the flagship panel, name plates, the gun-laying reticle, the minimap,
## messages, and the result card when the action ends.

var battle
var results_shown = false
var font: Font
const GOLD := Color(0.89, 0.7, 0.24)
const INK := Color(0.89, 0.91, 0.89)
const DIM := Color(0.62, 0.67, 0.67)
const RED := Color(0.85, 0.38, 0.29)
const GREEN := Color(0.5, 0.75, 0.56)
const PANEL := Color(0.055, 0.1, 0.12, 0.9)

var menu: Control
var _tip := ""   # explanation for whatever the mouse is over, drawn last
const TIPS := {
    "crew": "Crew fit for duty. Losses slow the guns' reloading, damage control and the ship's speed.",
    "fire": "Fires burning aboard: they eat at the hull until damage control puts them out. MAG means a fire has reached a magazine: unless it is flooded in time, it explodes.",
    "engine": "Machinery: the power for speed. Hits amidships cut it; a heavy hit stops the engines for a while (STOP). Damage control gets some of it back.",
    "ammo": "Main-battery shells left. Every mount has a magazine; refill them in port (Rearm).",
    "helm": "Steering gear, right aft. A hit can jam the rudder where it lies (JAM) until it is cleared.",
    "fc": "Fire control: the directors and rangefinders in the bridge. Damage to them widens your salvos.",
    "map": "Damage shows on the plan only where it is. Red: machinery (amidships), steering (aft) or fire control (bridge) damaged, deeper red is worse. Black with a red cross: a wrecked mount. Amber dot: a mount out of ammunition. Orange: a fire. Flashing box: a burning magazine. Blue box: a flooded magazine (its turret is out of action).",
}

func _ready() -> void:
    font = ThemeDB.fallback_font
    _build_menu()

## The pause menu (Esc). Quick battles can be restarted or set up again; a campaign battle can be broken off (an order
## to withdraw, fought out as usual) or abandoned for the main menu, which loses what happened since the last save.
func _build_menu() -> void:
    menu = CenterContainer.new(); menu.set_anchors_preset(Control.PRESET_FULL_RECT); menu.visible = false; menu.theme = UI.theme(); add_child(menu)
    var pc = PanelContainer.new(); pc.custom_minimum_size = Vector2(340, 0); menu.add_child(pc)
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 8); pc.add_child(box)
    box.add_child(UI.label("Paused", UI.GOLD, 28))
    var campaign: bool = GameData.pending.has("player_recs")
    var b = func(t: String, cb: Callable, primary := false): var x = UI.button(t, cb, primary); x.custom_minimum_size = Vector2(300, 40); box.add_child(x)
    b.call("Resume", func(): toggle_menu(), true)
    if campaign:
        b.call("Break off the action", func(): battle.sim.order = "retreat"; battle.sim.say("All ships withdraw! Open the range and break contact.", 2.5); toggle_menu())
        b.call("Quit to main menu", func(): _confirm("Quit to the main menu? This battle and anything since your last save will be lost.", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn")))
    else:
        b.call("Restart battle", func(): get_tree().reload_current_scene())
        b.call("Battle setup", func(): get_tree().change_scene_to_file("res://scenes/skirmish.tscn"))
        b.call("Main menu", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
    b.call("Settings", func(): _menu_settings(box))
    box.add_child(UI.label("Esc resumes · P pauses without this menu", UI.DIM, 12))

func _menu_settings(box: VBoxContainer) -> void:
    for c in box.get_children(): c.visible = false
    var sp = VBoxContainer.new(); box.add_child(sp); sp.add_child(Settings.panel())
    sp.add_child(UI.button("Back", func(): _menu_back(box, sp)))

func _menu_back(box: VBoxContainer, sp: Control) -> void:
    sp.queue_free()
    for c in box.get_children(): if c != sp: c.visible = true

func _confirm(text: String, yes: Callable) -> void:
    var box: VBoxContainer = menu.get_child(0).get_child(0)
    for c in box.get_children(): c.queue_free()
    box.add_child(UI.label(text, UI.INK, 15, true))
    box.add_child(UI.row([UI.button("Quit", yes, true), UI.button("Back", func(): menu.queue_free(); _build_menu(); menu.visible = true)]))

func toggle_menu() -> void:
    menu.visible = not menu.visible
    battle.paused = menu.visible

func _text(p: Vector2, s: String, col := INK, size := 13, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
    draw_string(font, p, s, align, width, size, col)

func _bar(p: Vector2, w: float, h: float, f: float, col: Color) -> void:
    draw_rect(Rect2(p, Vector2(w, h)), Color(0.02, 0.06, 0.08, 0.85)); draw_rect(Rect2(p, Vector2(w * clampf(f, 0, 1), h)), col)

func to_screen(p: Vector2) -> Vector2:
    return (p - battle.camera.position) * battle.zoom() + size / 2

func _draw() -> void:
    var sim: BattleSim = battle.sim; var W = size.x; var H = size.y
    # name plates and hull bars over each visible ship
    for s in sim.ships:
        if not sim.active(s) or (s.side == 1 and not sim.visible_to(s, 0)): continue
        var sp = to_screen(s.pos); var off: float = s.d.L * 0.5 * battle.zoom() + 18
        if sp.x < -100 or sp.x > W + 100 or sp.y < -100 or sp.y > H + 100: continue
        var w = maxf(44.0, s.d.L * 0.55 * battle.zoom())
        if s == sim.lock:
            var rr: float = s.d.L * 0.5 * battle.zoom() + 10
            for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
                var corner = sp + Vector2(c.x * rr, c.y * rr * 0.6)
                draw_line(corner, corner - Vector2(c.x * 8, 0), GOLD, 2); draw_line(corner, corner - Vector2(0, c.y * 8), GOLD, 2)
        _bar(sp + Vector2(-w / 2, -off), w, 4, s.hull / s.max_hull, RED if s.side else GREEN)
        _bar(sp + Vector2(-w / 2, -off + 5), w, 2, s.armor / maxf(1.0, s.d.armor), Color(0.62, 0.67, 0.67))
        var tag = " · STRUCK" if s.struck else (" · fleeing" if s.flee else (" · submerged" if sim.submerged(s) else ""))
        _text(sp + Vector2(-150, -off - 4), s.rec.name + tag, Color(0.95, 0.75, 0.71) if s.side else (GOLD if s == sim.flag else Color(0.84, 0.86, 0.85)), 12, HORIZONTAL_ALIGNMENT_CENTER, 300)
    # orders and help
    var orders = [["1", "Engage", "engage"], ["2", "Escort", "escort"], ["3", "Retreat (break contact)", "retreat"]]
    for i in orders.size():
        var on: bool = sim.order == orders[i][2]
        _text(Vector2(16, 28 + i * 18), ("▸ " if on else "   ") + orders[i][0] + " " + orders[i][1], GOLD if on else Color(INK, 0.55))
    var clock = "%d:%02d" % [int(sim.t / 60), int(fmod(sim.t, 60))]
    _text(Vector2(16, 86), "Battle clock " + clock + " · time ×" + str(int(battle.combat_speed() * BattleSim.BT)) + " (−/=) · W/S engines · A/D rudder · Ctrl+click: waypoint (Ctrl+right-click clears) · click enemy to engage · hold on water to fire there · right-click water: cease fire", Color(INK, 0.45), 12)
    _text(Vector2(16, 101), "Right-drag: pan · Space: recentre · X autofire" + (" (ON)" if sim.autofire else "") + " · T torpedoes · Q missiles · F air strike · C dive · Tab next ship · Z depth charges · P pause · Esc menu · M mute", Color(INK, 0.45), 12)
    var ry = 128.0
    for side in [0, 1]:
        _text(Vector2(16, ry), "Enemy" if side else "Task force", Color(0.95, 0.75, 0.71) if side else INK); ry += 18
        for s in sim.ships:
            if s.side != side: continue
            if side == 1 and sim.active(s) and not sim.visible_to(s, 0): _text(Vector2(16, ry), "? contact lost", Color(INK, 0.35)); ry += 16; continue
            var col = Color(INK, 0.3) if not s.alive else (Color(INK, 0.45) if s.escaped else (GOLD if s == sim.flag else INK))
            _text(Vector2(16, ry), ("★ " if s == sim.flag else "") + s.rec.name + " · " + s.d.name + (" · sunk" if not s.alive else (" · withdrew" if s.escaped else (" · struck" if s.struck else ""))), col)
            if sim.active(s): _bar(Vector2(240, ry - 9), 60, 5, s.hull / s.max_hull, RED if side else GREEN)
            ry += 16
            if ry > H - 300: break
        ry += 8
    # flagship panel
    var f = sim.flag
    if f != null:
        var x = 16.0; var y = H - 152.0; var w = 420.0; var h = 138.0
        draw_rect(Rect2(x, y, w, h), PANEL); draw_rect(Rect2(x, y, w, h), Color(GOLD, 0.55), false, 1)
        _text(Vector2(x + 10, y + 26), f.rec.name.to_upper(), GOLD, 20)
        var hdg = int(round(fposmod(rad_to_deg(f.a + PI / 2), 360))); var rud = int(round(f.rud * 35))
        var line = f.d.dn + " class · " + ["All stop", "Slow ahead", "Half ahead", "Full ahead", "Flank speed"][f.throttle] + " · %d kn · course %03d° · rudder " % [int(round(f.v / BattleSim.KN)), hdg] + (("%d° " % absi(rud)) + ("port" if rud < 0 else "stbd") if rud else "amidships")
        if f.sub: line += " · SUBMERGED" if sim.submerged(f) else (" · diving" if f.want_dive else " · surfaced")
        _text(Vector2(x + 10, y + 46), line, DIM, 12)
        _text(Vector2(x + 10, y + 64), "Hull", DIM, 12); _bar(Vector2(x + 60, y + 56), 350, 7, f.hull / f.max_hull, GREEN)
        _text(Vector2(x + 10, y + 78), "Armour", DIM, 12); _bar(Vector2(x + 60, y + 72), 350, 5, f.armor / maxf(1.0, f.d.armor), Color(0.62, 0.67, 0.67))
        # damaged subsystems, shown only when something is wrong
        var sysl = []
        if f.mag_fire > 0: sysl.append("MAGAZINE FIRE %d s" % int(f.mag_fire))
        if f.eng_out > 0: sysl.append("engines out %d s" % int(f.eng_out))
        elif f.eng < 0.95: sysl.append("power %d%%" % int(f.eng * 100))
        if f.jam > 0: sysl.append("rudder jammed %d s" % int(f.jam))
        if f.fc < 0.95: sysl.append("director %d%%" % int(f.fc * 100))
        if sysl.size(): _text(Vector2(x + 10, y - 4), " · ".join(sysl), Color(0.85, 0.38, 0.29) if f.mag_fire > 0 or f.eng_out > 0 else GOLD, 12, HORIZONTAL_ALIGNMENT_LEFT, w - 10)
        var groups = {}
        for m in f.mounts: if not groups.has(m.w.name): groups[m.w.name] = []
        for m in f.mounts: groups[m.w.name].append(m)
        var gx = x + 10; var gy = y + 98
        for n in groups:
            var ms: Array = groups[n]; var ready = 0; var dead = 0; var left = 0; var cap = 0
            var prog := 0.0; var live := 0; var secs := 0.0   # reload progress over the working mounts, and the longest wait
            for m in ms:
                if m.ammo_max > 0: left += maxi(0, m.ammo); cap += m.ammo_max
                if m.dead: dead += 1
                else:
                    live += 1; prog += 1.0 - clampf(m.cd / maxf(float(m.w.rel), 0.01), 0.0, 1.0)
                    if m.cd > 0: secs = maxf(secs, m.cd / maxf(sim.reload_mult(f, m.w), 0.01))
                    elif m.ammo != 0: ready += 1
            var unit: String = {"gun": "rds", "aa": "bursts", "torp": "salvos", "ssm": "salvos", "sam": "rds"}.get(ms[0].w.kind, "")
            var am: String = (" · empty" if left == 0 else (" · %d%%" % int(100.0 * left / cap) if unit == "bursts" else (" · %s %s" % [("%.1fk" % (left / 1000.0)) if left >= 1000 else str(left), unit]))) if cap > 0 else ""
            _text(Vector2(gx, gy), str(ms.size()) + "× " + n + ((" (" + str(dead) + " out)") if dead else "") + am, RED if cap > 0 and left == 0 else (GOLD if cap > 0 and left < cap * 0.2 else Color(0.84, 0.86, 0.85)), 12, HORIZONTAL_ALIGNMENT_LEFT, 196)
            var fill := prog / maxf(1.0, float(live))
            _bar(Vector2(gx, gy + 4), 130, 3, fill, GREEN if ready == live and live > 0 else GOLD)
            if live > 0 and ms[0].w.kind != "aa" and cap > 0 and left > 0:
                _text(Vector2(gx + 134, gy + 8), "ready" if ready == live else ("%d s" % ceili(secs)), GREEN if ready == live else GOLD, 10, HORIZONTAL_ALIGNMENT_LEFT, 60)
            gx += 200
            if gx > x + 330: gx = x + 10; gy += 22
            if gy > y + h - 6: break
        if f.d.get("sonar", false) and not f.sub: # depth charges: patterns left and the racks reloading (Z drops a pattern)
            var dct: float = f.dc_t if f.dc_t > 0 else 0.0
            var lab := "Depth charges · %d pattern%s" % [f.dc_left, "" if f.dc_left == 1 else "s"] + (" · reloading %d s" % ceili(dct) if dct > 0 and f.dc_left > 0 else (" · ready (Z)" if f.dc_left > 0 else ""))
            _text(Vector2(x + w - 210, y + 26), lab, RED if f.dc_left == 0 else (GOLD if dct > 0 else Color(0.84, 0.86, 0.85)), 12, HORIZONTAL_ALIGNMENT_RIGHT, 200)
            _bar(Vector2(x + w - 110, y + 30), 100, 3, 1.0 - dct / 25.0 if f.dc_left > 0 else 0.0, GREEN if dct <= 0 else GOLD)
        if not f.squads.is_empty():
            var st = ""
            for q in f.squads: st += ("▲" + str(q.n) if q.state == "ready" else ("→" if q.state == "out" else ("…" if q.state == "rearm" else "✕"))) + " "
            _text(Vector2(x + w - 10 - 200, y + 26), "Air: " + st, Color(0.84, 0.86, 0.85), 12, HORIZONTAL_ALIGNMENT_RIGHT, 200)
        _schematic(f, Rect2(x, y - 140, w, 120))
    # hit results: what each shell did, rising from where it struck and fading (hits on your own ships in red)
    for hm in sim.hit_marks:
        var a: float = clampf(hm.t / 0.6, 0.0, 1.0); var sp: Vector2 = to_screen(hm.pos) + Vector2(0, -26 - (1.8 - hm.t) * 18.0)
        var col: Color = RED if hm.ours else ({"pen": INK, "over": GOLD}.get(hm.kind, DIM) as Color)
        _text(sp - Vector2(79, -1), hm.text, Color(0, 0, 0, a * 0.8), 14 if hm.kind == "pen" else 13, HORIZONTAL_ALIGNMENT_CENTER, 160)
        _text(sp - Vector2(80, 0), hm.text, Color(col, a), 14 if hm.kind == "pen" else 13, HORIZONTAL_ALIGNMENT_CENTER, 160)
    _reticle()
    # minimap
    var mw: float = Settings.minimap_width(); var mh = mw * sim.AH / sim.AW; var mx = W - mw - 16; var my = H - mh - 16; var k = mw / sim.AW
    draw_rect(Rect2(mx, my, mw, mh), PANEL); draw_rect(Rect2(mx, my, mw, mh), Color(GOLD, 0.55), false, 1)
    for is_ in sim.islands: draw_circle(Vector2(mx, my) + is_.c * k, is_.r * k, Color("#56703f"))
    for s in sim.ships:
        if not sim.active(s) or (s.side == 1 and not sim.visible_to(s, 0)): continue
        var r = clampf(s.d.L / 60.0, 2, 5)
        draw_rect(Rect2(Vector2(mx, my) + s.pos * k - Vector2(r, r) / 2, Vector2(r, r)), GOLD if s == f else (RED if s.side else GREEN))
    var vr: Rect2 = battle.view_rect()
    draw_rect(Rect2(Vector2(mx, my) + vr.position * k, vr.size * k), Color(INK, 0.4), false, 1)
    # messages and pause
    if sim.msg_t > 0: _text(Vector2(0, 74), sim.msg.to_upper(), Color(INK, minf(1.0, sim.msg_t)), 26, HORIZONTAL_ALIGNMENT_CENTER, W)
    if _tip != "": _draw_tip(_tip); _tip = ""
    if battle.paused:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.06, 0.5))
        if not menu.visible: _text(Vector2(0, H / 2), "PAUSED · P TO RESUME · ESC FOR MENU", INK, 34, HORIZONTAL_ALIGNMENT_CENTER, W)

## Gun-laying reticle at the point the main battery is aimed, with a plain-words state of the guns.
func _reticle() -> void:
    var sim: BattleSim = battle.sim; var s = sim.flag
    if s == null or not s.alive or sim.gun_aim.is_empty(): return
    var ms: Array = []
    for m in s.mounts: if m.w.kind == "gun" and m.w.size == s.main_sz and m.st != "": ms.append(m)
    if ms.is_empty(): return
    var n = func(st: String) -> int: return ms.filter(func(m): return m.st == st).size()
    var bearing: int = n.call("ready") + n.call("reload"); var training: int = n.call("train")
    var a: Vector2 = sim.gun_aim.pos; var lock: bool = sim.gun_aim.lock; var sp = to_screen(a)
    var off = lock and (sp.x < 0 or sp.x > size.x or sp.y < 0 or sp.y > size.y)
    sp = sp.clamp(Vector2(24, 24), size - Vector2(300, 50))
    var col = GREEN if bearing else (GOLD if training else RED)
    draw_arc(sp, 13, 0, TAU, 32, col, 1.5)
    for q in 4:
        var ang = q * PI / 2; draw_line(sp + Vector2.from_angle(ang) * 8, sp + Vector2.from_angle(ang) * 19, col, 1.5)
    var rng = s.pos.distance_to(a); var mx = sim.max_gun_range(s)
    var rel = 999.0; var train = 0.0
    for m in ms:
        if m.st == "reload": rel = minf(rel, m.cd / sim.reload_mult(s, m.w))
        if m.st == "train": train = maxf(train, m.err / BattleSim.TRAV[m.w.size])
    var l1 = ("Target beyond the screen edge · " if off else "") + (("Engaging " if sim.autofire else "Laid on ") + sim.lock.rec.name if lock and sim.lock != null else ("Firing at the point" if sim.mouse_down else "Aiming")) + " · %.1f of %.1f km" % [rng / 1000.0, mx / 1000.0]
    var l2 = "%d of %d turrets bearing" % [bearing, ms.size()] + (" · ready" if n.call("ready") else (" · reloading %d s" % ceili(rel) if bearing else "")) + ((" · %d turning to bear, ~%d s" % [training, ceili(train)]) if training else "") + (" · out of range" if n.call("range") else "") + ((" · %d blocked by own ship" % n.call("arc")) if n.call("arc") else "")
    var lines = [l1, l2]
    if not sim.autofire and not sim.mouse_down and lock: lines.append("Click the target or press X to open fire")
    for i in lines.size():
        var tw = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
        draw_rect(Rect2(sp + Vector2(22, 4 + i * 16), Vector2(tw + 8, 16)), Color(0.02, 0.06, 0.08, 0.7))
        _text(sp + Vector2(26, 17 + i * 16), lines[i], INK if i == 0 else col, 12)

func show_results() -> void:
    results_shown = true
    var r: Dictionary = battle.sim.result
    var panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.custom_minimum_size = Vector2(460, 0)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(panel); panel.position = size / 2 - Vector2(230, 150)
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box)
    var title = Label.new(); title.text = "Victory" if r.victory else ("Disengaged" if r.lost.size() < battle.sim.ships.filter(func(s): return s.side == 0).size() else "Defeat")
    title.add_theme_font_size_override("font_size", 30); title.add_theme_color_override("font_color", GOLD); box.add_child(title)
    var txt = "Battle time %d:%02d\n" % [int(r.time / 60), int(fmod(r.time, 60))]
    if r.sunk.size(): txt += "Sunk: " + ", ".join(r.sunk) + "\n"
    if r.struck.size(): txt += "Struck their colours: " + ", ".join(r.struck) + "\n"
    if r.escaped.size(): txt += "Escaped: " + ", ".join(r.escaped) + "\n"
    if r.lost.size(): txt += "Lost: " + ", ".join(r.lost) + "\n"
    var body = Label.new(); body.text = txt; body.autowrap_mode = TextServer.AUTOWRAP_WORD; body.custom_minimum_size = Vector2(440, 0); box.add_child(body)
    var row = HBoxContainer.new(); box.add_child(row)
    if GameData.pending.get("campaign", false): # back to the chart, where prizes, prize money and losses are settled
        var go = Button.new(); go.text = "Return to the chart"; row.add_child(go)
        go.pressed.connect(func(): Campaign.apply_battle(battle.sim); Campaign.show_aftermath = true; get_tree().change_scene_to_file("res://scenes/world_map.tscn"))
        return
    var again = Button.new(); again.text = "Fight again"; again.pressed.connect(func(): get_tree().reload_current_scene()); row.add_child(again)
    var back = Button.new(); back.text = "Back to battle setup"; back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/skirmish.tscn")); row.add_child(back)

## Damage display for the flagship, in the manner of War Thunder's: the ship's own plan as a grey silhouette where
## only damage shows (parts going red as they are hurt, black when destroyed, fires flickering orange, magazines
## flashing while they burn and blue once flooded), and below it a row of badges with a value each: crew, fires,
## machinery, ammunition, steering and fire control. A badge turns red when its system is in trouble.
func _schematic(f, r: Rect2) -> void:
    draw_rect(r, PANEL); draw_rect(r, Color(GOLD, 0.35), false, 1)
    var d: Dictionary = f.d; var info: Dictionary = GameData.sprites.ships[f.rec.type]
    var sil := Rect2(r.position + Vector2(10, 4), Vector2(r.size.x - 20, r.size.y - 50))
    var k: float = minf(sil.size.x / float(info.w), sil.size.y / float(info.h))   # pixels per metre
    var c := sil.get_center()
    var mouse := get_local_mouse_position()
    if sil.has_point(mouse): _tip = TIPS.map
    var at = func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
    var tex = GameData.ship_tex(f.rec.type, f.pal, "base")
    draw_texture_rect(tex, Rect2(c - Vector2(info.w, info.h) * k / 2, Vector2(info.w, info.h) * k), false, Color(0.42, 0.46, 0.47, 0.95))
    var blink: bool = int(Time.get_ticks_msec() / 250) % 2 == 0
    var hurt = func(v: float) -> Color: return Color(0.85, 0.2, 0.15, clampf((1.0 - v) * 1.6, 0.0, 0.9))
    var L: float = d.L
    # machinery, steering gear and fire control show only once damaged
    if f.eng_out > 0 or f.eng < 0.97: draw_rect(Rect2(at.call(-L * 0.18, -d.B * 0.2), Vector2(L * 0.36, d.B * 0.4) * k), Color(0.12, 0.02, 0.02, 0.9) if f.eng_out > 0 else hurt.call(f.eng))
    if f.jam > 0: draw_rect(Rect2(at.call(-L * 0.48, -d.B * 0.14), Vector2(L * 0.07, d.B * 0.28) * k), Color(0.85, 0.2, 0.15, 0.9))
    var sup: Array = d.p.get("sup", [])
    if not sup.is_empty() and f.fc < 0.97: draw_circle(at.call(float(sup[0][0]), 0.0), maxf(3.0, float(sup[0][2]) * 0.3 * k), hurt.call(f.fc))
    for fi in f.fires: draw_circle(at.call(float(fi.x), float(fi.y)), maxf(2.0, float(fi.r) * k), Color(1.0, 0.55 if blink else 0.4, 0.1, 0.9))
    for m in f.mounts:
        var sl: Dictionary = m.slot; var mp: Vector2 = at.call(float(sl.x), float(sl.y))
        var sz: float = maxf(2.5, float(m.w.get("tw", 2.5)) * 0.5 * k)
        if m.w.kind == "gun" and sl.y == 0 and ["M", "L", "H"].has(m.w.size):
            var mc := Color(0, 0, 0, 0)
            if f.mag_fire > 0 and absf(f.mag_x - sl.x) < 1.0: mc = Color(1.0, 0.45, 0.1) if blink else Color(1.0, 0.85, 0.3)
            for fx in f.flooded: if absf(fx - sl.x) < 1.0: mc = Color(0.35, 0.6, 0.85)
            if mc.a > 0: draw_rect(Rect2(mp - Vector2(sz * 1.3, sz * 1.1), Vector2(sz * 2.6, sz * 2.2)), mc)
        if m.dead:
            if m.w.kind == "gun": draw_rect(Rect2(mp - Vector2(sz, sz * 0.8), Vector2(sz * 2, sz * 1.6)), Color(0.08, 0.06, 0.06))
            else: draw_circle(mp, sz * 0.7, Color(0.08, 0.06, 0.06))
            draw_line(mp - Vector2(sz, sz), mp + Vector2(sz, sz), RED, 1.5); draw_line(mp + Vector2(-sz, sz), mp + Vector2(sz, -sz), RED, 1.5)
        elif m.ammo == 0: draw_circle(mp, sz * 0.6, Color(0.9, 0.62, 0.2, 0.9))
    # badges
    var main_left := 0; var main_cap := 0
    for m in f.mounts: if m.w.kind == "gun" and m.w.size == f.main_sz and m.ammo_max > 0: main_left += maxi(0, m.ammo); main_cap += m.ammo_max
    var badges = [
        ["crew", "%d%%" % int(f.cf * 100), f.cf < 0.6],
        ["fire", str(f.fires.size()) if f.mag_fire <= 0 else "MAG", f.fires.size() > 0 or f.mag_fire > 0],
        ["engine", "STOP" if f.eng_out > 0 else "%d%%" % int(f.eng * 100), f.eng_out > 0 or f.eng < 0.5],
        ["ammo", ("%d%%" % int(100.0 * main_left / main_cap)) if main_cap > 0 else "—", main_cap > 0 and main_left < main_cap * 0.2],
        ["helm", "JAM" if f.jam > 0 else "OK", f.jam > 0],
        ["fc", "%d%%" % int(f.fc * 100), f.fc < 0.6]]
    var bx: float = r.position.x + 30; var by: float = r.position.y + r.size.y - 30; var step: float = (r.size.x - 60) / (badges.size() - 1)
    for b in badges:
        var bad: bool = b[2]; var ctr := Vector2(bx, by)
        if mouse.distance_to(ctr) < 16: _tip = TIPS[b[0]]
        draw_circle(ctr, 13, Color(0.55, 0.12, 0.1, 0.95) if bad else Color(0.16, 0.2, 0.22, 0.95)); draw_arc(ctr, 13, 0, TAU, 24, Color(1, 1, 1, 0.25), 1.0)
        _icon(String(b[0]), ctr, Color(1, 0.88, 0.85) if bad else Color(0.8, 0.84, 0.84))
        _text(ctr + Vector2(-30, 26), b[1], RED if bad else DIM, 11, HORIZONTAL_ALIGNMENT_CENTER, 60)
        bx += step

## Small line-drawn badge icons.
func _icon(kind: String, c: Vector2, col: Color) -> void:
    match kind:
        "crew": draw_circle(c + Vector2(0, -4), 3.2, col); draw_rect(Rect2(c + Vector2(-5, 0), Vector2(10, 6)), col)
        "fire":
            var pts = PackedVector2Array([c + Vector2(0, -8), c + Vector2(5, 0), c + Vector2(3, 6), c + Vector2(-3, 6), c + Vector2(-5, 0), c + Vector2(-1, -3)])
            draw_colored_polygon(pts, col)
        "engine":
            for i in 3: var a := i * TAU / 3.0; draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a) * 8 + Vector2.from_angle(a + 1.6) * 2, c + Vector2.from_angle(a + 0.7) * 7]), col)
            draw_circle(c, 2.0, Color(0.16, 0.2, 0.22))
        "ammo": draw_rect(Rect2(c + Vector2(-2.5, -3), Vector2(5, 9)), col); draw_colored_polygon(PackedVector2Array([c + Vector2(-2.5, -3), c + Vector2(0, -8), c + Vector2(2.5, -3)]), col)
        "helm":
            draw_arc(c, 6, 0, TAU, 20, col, 1.6); draw_circle(c, 1.8, col)
            for i in 6: var a := i * TAU / 6.0; draw_line(c + Vector2.from_angle(a) * 2, c + Vector2.from_angle(a) * 9, col, 1.4)
        "fc": draw_rect(Rect2(c + Vector2(-8, -1.5), Vector2(16, 3)), col); draw_rect(Rect2(c + Vector2(-3, -5), Vector2(6, 8)), col)

## A small explanation box beside the mouse, wrapped to a readable width.
func _draw_tip(t: String) -> void:
    var w := 320.0; var fs := 12
    var hgt: float = font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
    var p := get_local_mouse_position() + Vector2(16, -hgt - 20)
    p.x = clampf(p.x, 8, size.x - w - 24); p.y = clampf(p.y, 8, size.y - hgt - 24)
    draw_rect(Rect2(p, Vector2(w + 16, hgt + 14)), Color(0.04, 0.08, 0.1, 0.96)); draw_rect(Rect2(p, Vector2(w + 16, hgt + 14)), Color(GOLD, 0.6), false, 1)
    draw_multiline_string(font, p + Vector2(8, 8 + fs), t, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, INK)
