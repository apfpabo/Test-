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

func _ready() -> void:
    font = ThemeDB.fallback_font

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
    _text(Vector2(16, 86), "Battle clock " + clock + " · time ×" + str(int(battle.combat_speed() * BattleSim.BT)) + " (−/=) · W/S engines · A/D rudder · click enemy to engage · hold on water to fire there · right-click water: cease fire · right-drag: pan, Space: recentre · X autofire" + (" (ON)" if sim.autofire else "") + " · T torps · Q missiles · F air · C dive · Tab ship · P pause · M mute", Color(INK, 0.45), 12)
    var ry = 116.0
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
        if f.eng_out > 0: sysl.append("engines stopped %d s" % int(f.eng_out))
        elif f.eng < 0.95: sysl.append("machinery %d%%" % int(f.eng * 100))
        if f.jam > 0: sysl.append("rudder jammed %d s" % int(f.jam))
        if f.fc < 0.95: sysl.append("fire control %d%%" % int(f.fc * 100))
        if f.cf < 0.9: sysl.append("crew %d%%" % int(f.cf * 100))
        if sysl.size(): _text(Vector2(x + 10, y - 8), " · ".join(sysl), Color(0.85, 0.38, 0.29) if f.mag_fire > 0 or f.eng_out > 0 else GOLD, 13)
        var groups = {}
        for m in f.mounts: if not groups.has(m.w.name): groups[m.w.name] = []
        for m in f.mounts: groups[m.w.name].append(m)
        var gx = x + 10; var gy = y + 98
        for n in groups:
            var ms: Array = groups[n]; var ready = 0; var dead = 0
            for m in ms:
                if m.dead: dead += 1
                elif m.cd <= 0: ready += 1
            _text(Vector2(gx, gy), str(ms.size()) + "× " + n + ((" (" + str(dead) + " out)") if dead else ""), Color(0.84, 0.86, 0.85), 12)
            _bar(Vector2(gx, gy + 4), 130, 3, float(ready) / ms.size(), GREEN if ready else GOLD)
            gx += 200
            if gx > x + 330: gx = x + 10; gy += 22
            if gy > y + h - 6: break
        if not f.squads.is_empty():
            var st = ""
            for q in f.squads: st += ("▲" + str(q.n) if q.state == "ready" else ("→" if q.state == "out" else ("…" if q.state == "rearm" else "✕"))) + " "
            _text(Vector2(x + w - 10 - 200, y + 26), "Air: " + st, Color(0.84, 0.86, 0.85), 12, HORIZONTAL_ALIGNMENT_RIGHT, 200)
    _reticle()
    # minimap
    var mw = 190.0; var mh = mw * sim.AH / sim.AW; var mx = W - mw - 16; var my = H - mh - 16; var k = mw / sim.AW
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
    if battle.paused:
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.06, 0.5)); _text(Vector2(0, H / 2), "PAUSED · P TO RESUME", INK, 34, HORIZONTAL_ALIGNMENT_CENTER, W)

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
    var l2 = "%d of %d turrets bearing" % [bearing, ms.size()] + (" · ready" if n.call("ready") else (" · reloading %d s" % ceili(rel) if bearing else "")) + ((" · %d training, ~%d s" % [training, ceili(train)]) if training else "") + (" · out of range" if n.call("range") else "") + ((" · %d masked" % n.call("arc")) if n.call("arc") else "")
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
