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
        b.call("Start again" if battle.sim.editor else "Restart battle", func(): get_tree().reload_current_scene())
        if not battle.sim.editor: b.call("Battle setup", func(): get_tree().change_scene_to_file("res://scenes/skirmish.tscn"))
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

## Items joined with " · " into as few lines as fit the width.
func _wrap(items: PackedStringArray, width: float, fs: int) -> Array:
    var out: Array = []; var cur := ""
    for it in items:
        var nxt: String = it if cur == "" else cur + " · " + it
        if cur != "" and font.get_string_size(nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width: out.append(cur); cur = it
        else: cur = nxt
    if cur != "": out.append(cur)
    return out

func _bar(p: Vector2, w: float, h: float, f: float, col: Color) -> void:
    draw_rect(Rect2(p, Vector2(w, h)), Color(0.02, 0.06, 0.08, 0.85)); draw_rect(Rect2(p, Vector2(w * clampf(f, 0, 1), h)), col)

func to_screen(p: Vector2) -> Vector2:
    return (p - battle.camera.position) * battle.zoom() + size / 2

## A carrier's air wing as a row of small aircraft, a group to each squadron: gold = aboard and ready, dull = aboard
## and rearming, outlined = in the air, a red stroke = lost. Returns the row's width.
func _wing(at: Vector2, s, u: float) -> float:
    var x: float = at.x
    for e in battle.sim.wing(s):
        for k in int(e.full):
            var c := Vector2(x + u * 0.5, at.y + u * 0.5)
            var tri := PackedVector2Array([c + Vector2(0, -u * 0.5), c + Vector2(u * 0.5, u * 0.5), c + Vector2(-u * 0.5, u * 0.5)])
            if k < int(e.aboard): draw_colored_polygon(tri, Color(0.5, 0.5, 0.44) if e.rearm else GOLD)
            elif k < int(e.aboard) + int(e.air): tri.append(tri[0]); draw_polyline(tri, Color(0.72, 0.86, 0.92), 1.0)
            else: draw_line(c + Vector2(-u * 0.35, 0), c + Vector2(u * 0.35, 0), Color(RED, 0.85), 1.5)
            x += u + 1.0
        x += u * 0.7
    return x - at.x

var rows: Array = []        # [rect on screen, ship] for each of your ships in the list, for clicks (battle._pick_own)
func _draw() -> void:
    var sim: BattleSim = battle.sim; var W = size.x; var H = size.y
    rows.clear()
    # name plates and hull bars over each visible ship
    for s in sim.ships:
        if not sim.active(s) or (s.side == 1 and not sim.visible_to(s, 0)): continue
        var sp = to_screen(s.pos); var off: float = s.d.L * 0.5 * battle.zoom() + 18
        if sp.x < -100 or sp.x > W + 100 or sp.y < -100 or sp.y > H + 100: continue
        var w = maxf(44.0, s.d.L * 0.55 * battle.zoom())
        if s.side == 0 and battle.sel.has(s):   # picked out for orders of her own: a gold ring
            draw_arc(sp, s.d.L * 0.5 * battle.zoom() + 12.0, 0, TAU, 48, Color(GOLD, 0.85), 1.5)
        if s.side == 0 and s.ord == "goto": draw_dashed_line(sp, to_screen(s.ord_pt), Color(GOLD, 0.45), 1.0, 6.0); draw_arc(to_screen(s.ord_pt), 6.0, 0, TAU, 16, Color(GOLD, 0.7), 1.5)
        if s == sim.lock:
            var rr: float = s.d.L * 0.5 * battle.zoom() + 10
            for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
                var corner = sp + Vector2(c.x * rr, c.y * rr * 0.6)
                draw_line(corner, corner - Vector2(c.x * 8, 0), GOLD, 2); draw_line(corner, corner - Vector2(0, c.y * 8), GOLD, 2)
        _bar(sp + Vector2(-w / 2, -off), w, 4, s.hull / s.max_hull, RED if s.side else GREEN)
        _bar(sp + Vector2(-w / 2, -off + 5), w, 2, s.armor / maxf(1.0, s.d.armor), Color(0.62, 0.67, 0.67))
        var tag = " · STRUCK" if s.struck else (" · fleeing" if s.flee else (" · submerged" if sim.submerged(s) else ""))
        # what is wrong with her, where anyone can see it: machinery, steering, a list, smoke
        var ail: Array = []
        if s.eng_out > 0: ail.append("engines stopped")
        elif s.eng < 0.6: ail.append("engines %d%%" % int(s.eng * 100))
        if s.jam > 0: ail.append("rudder jammed")
        elif s.steer < 0.7: ail.append("steering damaged")
        if absf(s.list) >= 0.3: ail.append("listing to " + ("starboard" if s.list > 0 else "port"))
        if s.deck_out > 0: ail.append("flight deck out")
        if s.side == 0 and not s.squads.is_empty(): _wing(sp + Vector2(-_wing(Vector2(-1000, -1000), s, 6.0) / 2.0, -off + 10), s, 6.0)   # centred under her bars
        if s.smoke_on: ail.append("making smoke")
        if ail.size(): _text(sp + Vector2(-150, -off - 18), " · ".join(ail), Color(0.93, 0.5, 0.36) if not (ail.size() == 1 and s.smoke_on) else Color(0.8, 0.82, 0.8), 11, HORIZONTAL_ALIGNMENT_CENTER, 300)
        _text(sp + Vector2(-150, -off - 4), s.rec.name + tag, Color(0.95, 0.75, 0.71) if s.side else (GOLD if s == sim.flag else Color(0.84, 0.86, 0.85)), 12, HORIZONTAL_ALIGNMENT_CENTER, 300)
    # orders and help
    # squadron orders, in a row: the standing order in gold
    var orders = [["1", "Engage", "engage"], ["2", "Form on flag", "escort"], ["4", "Line ahead", "line"], ["6", "Line abreast", "abreast"], ["7", "Screen", "screen"], ["3", "Withdraw", "retreat"]]
    var ox := 16.0
    var nsel: int = battle._sel().size()
    _text(Vector2(ox, 28), ("PICKED · %d" % nsel) if nsel > 0 else "SQUADRON", GOLD if nsel > 0 else DIM, 11); ox += 74.0
    for i in orders.size():
        var on: bool = (sim.order == orders[i][2]) if nsel == 0 else battle.sel.all(func(x): return sim.ord_of(x) == orders[i][2]); var lbl: String = orders[i][0] + " " + orders[i][1]
        var wd: float = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
        draw_rect(Rect2(ox, 13, wd, 21), Color(GOLD, 0.16) if on else Color(1, 1, 1, 0.04)); if on: draw_rect(Rect2(ox, 13, wd, 21), Color(GOLD, 0.7), false, 1)
        _text(Vector2(ox + 8, 28), lbl, GOLD if on else Color(INK, 0.6)); ox += wd + 6.0
    var hl := "5 Hold fire" + (" · HOLDING" if sim.hold_fire else "")
    var hw: float = font.get_string_size(hl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
    draw_rect(Rect2(ox + 10, 13, hw, 21), Color(RED, 0.2) if sim.hold_fire else Color(1, 1, 1, 0.04)); if sim.hold_fire: draw_rect(Rect2(ox + 10, 13, hw, 21), Color(RED, 0.8), false, 1)
    _text(Vector2(ox + 18, 28), hl, RED if sim.hold_fire else Color(INK, 0.6))
    var smk: bool = sim.ships.any(func(x): return x.side == 0 and x.smoke_on); ox += hw + 16.0
    var sl := "8 Smoke · K yours" + (" · LAYING" if smk else "")
    var sw: float = font.get_string_size(sl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16.0
    draw_rect(Rect2(ox, 13, sw, 21), Color(GOLD, 0.16) if smk else Color(1, 1, 1, 0.04)); if smk: draw_rect(Rect2(ox, 13, sw, 21), Color(GOLD, 0.7), false, 1)
    _text(Vector2(ox + 8, 28), sl, GOLD if smk else Color(INK, 0.6))
    _text(Vector2(16, 54), {"engage": "Each ship picks her own target and fights at her best range.", "escort": "Ships keep station round the flagship and engage what comes near.", "abreast": "Ships hold station abeam of the flagship, turning and changing speed with her; guns fire as they bear.", "screen": "Light ships hold an arc ahead of the flagship, the heavier ones follow her in column.", "line": "Ships follow in the flagship's wake: steer the line and every gun bears together.", "retreat": "All ships turn away and open the range to break contact."}[sim.order] + ("  Only the flagship fires; AA still defends." if sim.hold_fire else ""), DIM, 12)
    var clock = "%d:%02d" % [int(sim.t / 60), int(fmod(sim.t, 60))]
    # the keys, wrapped to the width of the window (it ran off the right-hand edge of anything narrower than 2,000 px)
    var hy := 86.0
    for ln in _wrap(("Battle clock " + clock + " · time ×" + str(int(battle.combat_speed() * BattleSim.BT)) + " (−/=) · W/S engines · A/D rudder · Ctrl+click: waypoint (Ctrl+right-click clears) · click enemy to engage · hold on water to fire there · right-click water: cease fire" + " · " + "Right-drag: pan · Space: recentre · X autofire" + (" (ON)" if sim.autofire else "") + " · T torpedoes · Q missiles · F air strike · C dive · Tab next ship · V shells · Z depth charges · H hide the interface · K smoke · G star shell · B damage control · N flood magazine · J counter-flood · 9 torpedo attack · 0 rejoin · F1 light ships F2 heavy F3 none · Shift+click picks a ship · Ctrl+click sends those picked · R sensors · P pause · Esc menu · M mute").split(" · "), W - 32.0, 12):
        _text(Vector2(16, hy), ln, Color(INK, 0.45), 12); hy += 15.0
    if sim.limited() or sim.wx.night or int(sim.wx.sea) >= 2 or sim.wx.fog:
        var mine_radar: bool = sim.ships.any(func(x): return x.side == 0 and sim.active(x) and sim.has_radar(x))
        _text(Vector2(16, hy), "%s%s" % [sim.wx.text, (" · lookouts see %.1f km%s · a ship that fires or burns shows at twice that" % [float(sim.wx.vis) / 1000.0, (" · your radar %.1f km" % (float(sim.wx.radar) / 1000.0)) if mine_radar else " · no radar"]) if sim.limited() else " · gunnery suffers"], GOLD, 12)
    var ry = hy + (20.0 if (sim.limited() or sim.wx.night or int(sim.wx.sea) >= 2 or sim.wx.fog) else 12.0)
    # ten ships a side must fit above the shell panel on a small window: the rows close up rather than drop ships
    var step := 16.0; var room: float = (H - 396.0) - ry - 52.0
    if sim.ships.size() * step > room: step = maxf(11.0, room / sim.ships.size())
    for side in [0, 1]:
        _text(Vector2(16, ry), "Enemy" if side else "Your squadron · click a ship to give her orders of her own", Color(0.95, 0.75, 0.71) if side else INK); ry += 18
        for s in sim.ships:
            if s.side != side: continue
            if side == 1 and sim.active(s) and not sim.visible_to(s, 0): _text(Vector2(16, ry), "? contact lost", Color(INK, 0.35)); ry += step; continue
            var col = Color(INK, 0.3) if not s.alive else (Color(INK, 0.45) if s.escaped else (GOLD if s == sim.flag else INK))
            var own: String = ""
            if side == 0 and s != sim.flag and sim.active(s):
                rows.append([Rect2(10, ry - 13, 300, step), s])
                if battle.sel.has(s): draw_rect(Rect2(10, ry - 13, 300, step), Color(GOLD, 0.16)); draw_rect(Rect2(10, ry - 13, 3, step), GOLD)
                if s.ord != "": own = " · " + String({"engage": "engaging", "escort": "on the flag", "line": "line ahead", "abreast": "line abreast", "screen": "screen", "retreat": "withdrawing", "goto": "to a point", "torp": "torpedo attack"}.get(s.ord, s.ord))
                if s.hold: own += " · holding fire"
            _text(Vector2(16, ry), ("★ " if s == sim.flag else "") + s.rec.name + " · " + s.d.name + (" · sunk" if not s.alive else (" · withdrew" if s.escaped else (" · struck" if s.struck else own))), GOLD if (side == 0 and battle.sel.has(s)) else col)
            if sim.active(s): _bar(Vector2(240, ry - 9), 60, 5, s.hull / s.max_hull, RED if side else GREEN)
            ry += step
        ry += 8
    # flagship panel
    var f = sim.flag
    if f == null or sim.finished: _hide_mirror()
    if f != null:
        var x = 16.0; var y = H - 152.0; var w = 420.0; var h = 138.0
        draw_rect(Rect2(x, y, w, h), PANEL); draw_rect(Rect2(x, y, w, h), Color(GOLD, 0.55), false, 1)
        _text(Vector2(x + 10, y + 26), f.rec.name.to_upper(), GOLD, 20)
        var hdg = int(round(fposmod(rad_to_deg(f.a + PI / 2), 360))); var rud = int(round(f.rud * 35))
        var line = f.d.dn + " class · " + ["All stop", "Slow ahead", "Half ahead", "Full ahead", "Flank speed"][f.throttle] + " · %d kn · course %03d° · rudder " % [int(round(f.v / BattleSim.KN)), hdg] + (("%d° " % absi(rud)) + ("port" if rud < 0 else "stbd") if rud else "amidships")
        if f.sub: line += " · SUBMERGED" if sim.submerged(f) else (" · diving" if f.want_dive else " · surfaced")
        line += " · %s crew" % String(BattleSim.CREW[f.cq].name)
        _text(Vector2(x + 10, y + 46), line, DIM, 12)
        _text(Vector2(x + 10, y + 64), "Hull", DIM, 12); _bar(Vector2(x + 60, y + 56), 350, 7, f.hull / f.max_hull, GREEN)
        _text(Vector2(x + 10, y + 78), "Armour", DIM, 12); _bar(Vector2(x + 60, y + 72), 350, 5, f.armor / maxf(1.0, f.d.armor), Color(0.62, 0.67, 0.67))
        # damaged subsystems, shown only when something is wrong
        var sysl = []
        if f.mag_fire > 0: sysl.append("MAGAZINE FIRE %d s · N floods it" % int(f.mag_fire))
        if absf(f.list) >= 0.15: sysl.append("list %d%% to %s · J counter-floods" % [int(absf(f.list) * 100), "starboard" if f.list > 0 else "port"])
        if f.ballast > 0.01: sysl.append("flooded to stay level: %d%% slower" % int(round(f.ballast * 30)))
        if f.dc_pri != "": sysl.append("damage control: " + String(BattleSim.DC_PRI[f.dc_pri]))
        if f.eng_out > 0: sysl.append("engines out %d s" % int(f.eng_out))
        elif f.eng < 0.95: sysl.append("power %d%%" % int(f.eng * 100))
        if f.jam > 0: sysl.append("rudder jammed %d s" % int(f.jam))
        if f.fc < 0.95: sysl.append("director %d%%" % int(f.fc * 100))
        if f.steer < 0.8: sysl.append("steering %d%%" % int(f.steer * 100))
        if sysl.size(): _text(Vector2(x + 10, y - 3), " · ".join(sysl), Color(0.85, 0.38, 0.29) if f.mag_fire > 0 or f.eng_out > 0 else GOLD, 12, HORIZONTAL_ALIGNMENT_LEFT, w - 10)
        var groups = {}
        for m in f.mounts: if not groups.has(m.w.name): groups[m.w.name] = []
        for m in f.mounts: groups[m.w.name].append(m)
        var many: bool = groups.size() > 4   # five weapon groups (Yamato, the missile ships): three closer rows, so none goes unshown
        var gx = x + 10; var gy = y + (93 if many else 98)
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
            _bar(Vector2(gx, gy + (3 if many else 4)), 130, 2 if many else 3, fill, GREEN if ready == live and live > 0 else GOLD)
            if live > 0 and ms[0].w.kind != "aa" and cap > 0 and left > 0:
                _text(Vector2(gx + 134, gy + (6 if many else 8)), "ready" if ready == live else ("%d s" % ceili(secs)), GREEN if ready == live else GOLD, 9 if many else 10, HORIZONTAL_ALIGNMENT_LEFT, 60)
            gx += 200
            if gx > x + 330: gx = x + 10; gy += 16 if many else 22
            if gy > y + h - 6: break
        if f.d.get("sonar", false) and not f.sub: # depth charges: patterns left and the racks reloading (Z drops a pattern)
            var dct: float = f.dc_t if f.dc_t > 0 else 0.0
            var lab := "Depth charges · %d pattern%s" % [f.dc_left, "" if f.dc_left == 1 else "s"] + (" · reloading %d s" % ceili(dct) if dct > 0 and f.dc_left > 0 else (" · ready (Z)" if f.dc_left > 0 else ""))
            _text(Vector2(x + w - 210, y + 26), lab, RED if f.dc_left == 0 else (GOLD if dct > 0 else Color(0.84, 0.86, 0.85)), 12, HORIZONTAL_ALIGNMENT_RIGHT, 200)
            _bar(Vector2(x + w - 110, y + 30), 100, 3, 1.0 - dct / 25.0 if f.dc_left > 0 else 0.0, GREEN if dct <= 0 else GOLD)
        if not f.squads.is_empty():
            # the air wing, machine by machine: aboard and ready, rearming, in the air, lost
            var have := 0; var full := 0
            for e in sim.wing(f): have += int(e.aboard) + int(e.air); full += int(e.full)
            var note: String = "Air wing %d of %d" % [have, full]
            if f.deck_out > 0: note += " · flight deck out %d s" % ceili(f.deck_out)
            elif not sim.deck_ok(f): note += " · no flying: " + sim.deck_why(f)
            _text(Vector2(x + w - 10 - 300, y + 26), note, RED if not sim.deck_ok(f) else Color(0.84, 0.86, 0.85), 12, HORIZONTAL_ALIGNMENT_RIGHT, 300)
            _wing(Vector2(x + w - 10 - _wing(Vector2(-1000, -1000), f, 8.0), y + 3), f, 8.0)   # above the note, clear of the ship's name
        _schematic(f, Rect2(x, y - 134, w, 120))   # the three boxes stand 14 px apart
        if f.mounts.any(func(m): return m.w.kind == "gun" and m.w.size != "A"): _shell_panel(f, Rect2(x, y - 134 - 14 - 90, w, 90))
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
    var ss: String = sim.sol_state(sim.flag, sim.lock) if lock else ""
    if ss != "": lines.append("Fire control: " + ("straddling her: salvos are on" if ss == "straddling" else "finding the range: watch the fall of shot"))
    if not sim.autofire and not sim.mouse_down and lock: lines.append("Click the target or press X to open fire")
    for i in lines.size():
        var tw = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
        draw_rect(Rect2(sp + Vector2(22, 4 + i * 16), Vector2(tw + 8, 16)), Color(0.02, 0.06, 0.08, 0.7))
        _text(sp + Vector2(26, 17 + i * 16), lines[i], INK if i == 0 else col, 12)

func show_results() -> void:
    results_shown = true
    var sim: BattleSim = battle.sim; var r: Dictionary = sim.result
    var mine_n: int = sim.ships.filter(func(x): return x.side == 0).size()
    var kind: String = "victory" if r.victory else ("disengaged" if r.lost.size() < mine_n else "defeat")
    # the chart's panel: a dimmed scene, a flat panel with a gold rule under a condensed title, sections and buttons
    var shade := ColorRect.new(); shade.color = Color(0.016, 0.047, 0.063, 0.55); shade.set_anchors_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_STOP; shade.theme = UI.theme(); add_child(shade)
    var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); shade.add_child(center)
    var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(620, 0); center.add_child(panel)
    var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box)
    var title := UI.title({"victory": "Victory", "disengaged": "Action broken off", "defeat": "Defeat"}[kind])
    if kind == "defeat": title.add_theme_color_override("font_color", UI.RED)
    box.add_child(title)
    var lead: String = {"victory": "The enemy is sunk, struck or driven off, and the sea is yours.", "disengaged": "You have broken off the action. The enemy holds the water.", "defeat": "Your squadron is lost."}[kind]
    box.add_child(UI.label(lead, UI.INK, 15, true))
    box.add_child(UI.label("%s · the action lasted %d:%02d" % [str(sim.wx.text), int(r.time / 60), int(fmod(r.time, 60))], UI.DIM, 13))
    var section := func(head: String, names: Array, col: Color) -> void:
        if names.is_empty(): return
        box.add_child(UI.label(head, UI.DIM, 12))
        for nm in names: box.add_child(UI.label(str(nm), col, 14))
    section.call("ENEMY SUNK", r.sunk, UI.GREEN)
    section.call("STRUCK THEIR COLOURS", r.struck, UI.GOLD)
    section.call("ESCAPED", r.escaped, UI.DIM)
    section.call("YOUR LOSSES", r.lost, UI.RED)
    # your squadron as it stands
    var afloat: Array = sim.ships.filter(func(x): return x.side == 0 and x.alive)
    if not afloat.is_empty():
        box.add_child(UI.label("YOUR SQUADRON", UI.DIM, 12))
        for x in afloat:
            var hp: float = clampf(x.hull / x.max_hull, 0.0, 1.0)
            var nm := UI.label(x.rec.name, UI.INK, 14); nm.custom_minimum_size.x = 170
            var cl := UI.label(x.d.name, UI.DIM, 13); cl.custom_minimum_size.x = 150   # one column for the class, so the bars line up
            box.add_child(UI.row([nm, cl, UI.bar(hp, 120.0, UI.GREEN if hp > 0.5 else (UI.GOLD if hp > 0.25 else UI.RED)), UI.label("hull %d%% · magazines %d%%%s" % [int(hp * 100), int(sim.ammo_frac(x) * 100), " · withdrew" if x.escaped else ""], UI.DIM, 13)]))
    if GameData.pending.get("campaign", false): # back to the chart, where prizes, prize money and losses are settled
        box.add_child(UI.label("Prizes, prize money, casualties and research are settled on the chart.", UI.DIM, 13))
        box.add_child(UI.row([UI.button("Return to the chart", func(): Campaign.apply_battle(battle.sim); Campaign.show_aftermath = true; get_tree().change_scene_to_file("res://scenes/world_map.tscn"), true)]))
        return
    box.add_child(UI.row([UI.button("Fight again", func(): get_tree().reload_current_scene(), true), UI.button("Back to battle setup", func(): get_tree().change_scene_to_file("res://scenes/skirmish.tscn"))]))

## Damage display for the flagship, in the manner of War Thunder's: the ship's own plan as a grey silhouette where
## only damage shows (parts going red as they are hurt, black when destroyed, fires flickering orange, magazines
## flashing while they burn and blue once flooded), and below it a row of badges with a value each: crew, fires,
## machinery, ammunition, steering and fire control. A badge turns red when its system is in trouble.
## The shell the main battery is loading: a drawing of it with its head in the colour of its kind (armour-piercing,
## high explosive or incendiary), what it does, the rounds left, and the choices (V cycles them).
const SHELL_INFO := {
    "ap": ["ARMOUR-PIERCING", "Defeats the armour it can beat and bursts inside the ship. Passes clean through light ships.", Color(0.16, 0.2, 0.26), Color(0.62, 0.66, 0.7)],
    "he": ["HIGH EXPLOSIVE", "Bursts on contact: wrecks light ships and upperworks and starts fires. Only splinters against armour.", Color(0.86, 0.72, 0.2), Color(0.5, 0.52, 0.42)],
    "inc": ["INCENDIARY", "Sets a ship alight: four times the fires, little else. For merchants and wooden decks.", Color(0.78, 0.22, 0.16), Color(0.55, 0.5, 0.46)]}
func _shell(c: Vector2, hgt: float, kind: String, dim := false) -> void:
    var info: Array = SHELL_INFO[kind]; var w := hgt * 0.3; var a := 0.4 if dim else 1.0
    var body_top := c.y - hgt * 0.12; var base := c.y + hgt * 0.5; var x0 := c.x - w / 2
    # a round body lit from the upper left: bright a third of the way across, falling away to a dark far edge
    var shade := func(t: float) -> float: return 0.62 + 0.62 * exp(-pow((t - 0.3) / 0.24, 2.0)) - 0.3 * smoothstep(0.6, 1.0, t)
    var n := 12
    for i in n:
        var t := (i + 0.5) / n; var k: float = shade.call(t); var col: Color = info[3]
        draw_rect(Rect2(x0 + w * i / n, body_top, w / n + 0.5, base - body_top), Color(col.r * k, col.g * k, col.b * k, a))
        draw_rect(Rect2(x0 + w * i / n, base - hgt * 0.1, w / n + 0.5, hgt * 0.035), Color(0.72 * k, 0.5 * k, 0.24 * k, a))   # copper driving band
        if kind == "inc": draw_rect(Rect2(x0 + w * i / n, body_top + hgt * 0.06, w / n + 0.5, hgt * 0.05), Color(0.95 * k, 0.85 * k, 0.3 * k, a))   # yellow band
        if kind == "ap": draw_rect(Rect2(x0 + w * i / n, body_top - hgt * 0.06, w / n + 0.5, hgt * 0.065), Color(0.3 * k, 0.36 * k, 0.44 * k, a))   # the cap's shoulder
    draw_rect(Rect2(x0, base - hgt * 0.035, w, hgt * 0.035), Color(0.08, 0.09, 0.1, a))                                       # the base, in shadow
    draw_line(Vector2(x0, base + 1.0), Vector2(x0 + w + hgt * 0.1, base + 1.0), Color(0, 0, 0, 0.35 * a), maxf(1.0, hgt * 0.03))   # the shadow it stands on
    # the head: an ogive in the colour of its kind, shaded the same way in strips that follow its curve
    var top := body_top - (hgt * 0.06 if kind == "ap" else 0.0); var hh := hgt * 0.38
    var half := func(v: float) -> float: return w / 2 * sqrt(maxf(0.0, 1.0 - pow(v, 1.7)))   # half-width at height v (0 at the shoulder, 1 at the tip)
    var rows := maxi(4, int(hh / 1.5))
    for j in rows:
        var v0 := float(j) / rows; var v1 := float(j + 1) / rows; var hw0: float = half.call(v0); var hw1: float = half.call(v1)
        for i in n:
            var t0 := float(i) / n; var t1 := float(i + 1) / n; var k: float = shade.call((t0 + t1) / 2); var col: Color = info[2]
            draw_colored_polygon(PackedVector2Array([Vector2(c.x - hw0 + 2 * hw0 * t0, top - hh * v0), Vector2(c.x - hw0 + 2 * hw0 * t1 + 0.4, top - hh * v0),
                Vector2(c.x - hw1 + 2 * hw1 * t1 + 0.4, top - hh * v1 - 0.4), Vector2(c.x - hw1 + 2 * hw1 * t0, top - hh * v1 - 0.4)]), Color(minf(1.0, col.r * k), minf(1.0, col.g * k), minf(1.0, col.b * k), a))
    if kind == "he": draw_circle(Vector2(c.x, top - hh * 0.93), w * 0.13, Color(0.8, 0.8, 0.74, a)); draw_circle(Vector2(c.x - w * 0.04, top - hh * 0.95), w * 0.05, Color(1, 1, 1, 0.7 * a))   # nose fuze
    draw_line(Vector2(c.x - w * 0.2, body_top + hgt * 0.04), Vector2(c.x - w * 0.2, base - hgt * 0.14), Color(1, 1, 1, 0.16 * a), maxf(1.0, w * 0.06))   # a glint down the lit side
func _shell_panel(f, r: Rect2) -> void:
    draw_rect(r, PANEL); draw_rect(r, Color(GOLD, 0.35), false, 1)
    var mode: String = f.shell_mode; var cur: String = mode if mode != "auto" else (f.last_shell if f.last_shell != "" else "ap")
    var info: Array = SHELL_INFO[cur]
    _shell(Vector2(r.position.x + 30, r.position.y + r.size.y * 0.56), 66.0, cur)
    var tx := r.position.x + 62
    _text(Vector2(tx, r.position.y + 15), "MAIN BATTERY · SHELL LOADED" + ("  (chosen by target)" if mode == "auto" else "  (your order)"), DIM, 11)
    _text(Vector2(tx, r.position.y + 36), info[0], GOLD, 19)
    draw_multiline_string(font, Vector2(tx, r.position.y + 52), info[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 150, 11, 2, Color(0.84, 0.86, 0.85))
    # rounds left in the main battery
    var left := 0; var cap := 0
    for m in f.mounts: if m.w.kind == "gun" and m.w.size == f.main_sz and m.ammo_max > 0: left += maxi(0, m.ammo); cap += m.ammo_max
    if cap > 0:
        var frac := float(left) / cap; var col: Color = RED if left == 0 else (GOLD if frac < 0.2 else GREEN)
        _text(Vector2(tx, r.position.y + r.size.y - 9), "%s of %s rounds" % [Campaign.fmt(left), Campaign.fmt(cap)], col, 12)
        _bar(Vector2(tx + 130, r.position.y + r.size.y - 16), 110, 5, frac, col)
    # the choices
    var cx := r.position.x + r.size.x - 78; var cy := r.position.y + 12
    for i in BattleSim.SHELL_MODES.size():
        var k: String = BattleSim.SHELL_MODES[i]; var on: bool = k == mode; var yy := cy + i * 17.0
        draw_rect(Rect2(cx, yy - 10, 68, 15), Color(GOLD, 0.16) if on else Color(1, 1, 1, 0.03)); if on: draw_rect(Rect2(cx, yy - 10, 68, 15), Color(GOLD, 0.7), false, 1)
        if k != "auto": _shell(Vector2(cx + 9, yy - 2.5), 13.0, k, not on)
        _text(Vector2(cx + (18 if k != "auto" else 6), yy + 2), {"auto": "AUTO", "ap": "AP", "he": "HE", "inc": "INCEND."}[k], GOLD if on else DIM, 11)
    _text(Vector2(cx, r.position.y + r.size.y - 5), "V to change", Color(DIM, 0.8), 10)

func _schematic(f, r: Rect2) -> void:
    draw_rect(r, PANEL); draw_rect(r, Color(GOLD, 0.35), false, 1)
    var d: Dictionary = f.d; var info: Dictionary = GameData.sprites.ships[f.rec.type]
    var sil := Rect2(r.position + Vector2(10, 4), Vector2(r.size.x - 20, r.size.y - 50))
    var k: float = minf(sil.size.x / float(info.w), sil.size.y / float(info.h))   # pixels per metre
    var c := sil.get_center()
    var mouse := get_local_mouse_position()
    if sil.has_point(mouse): _tip = TIPS.map
    var at = func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
    # the ship herself, in her paint, as she is now: hull and deck here, then the mounts at their bearings and the
    # superstructure in layers above (MirrorLayer), then the damage over them
    draw_texture_rect(GameData.ship_tex(f.rec.type, f.pal, "base"), Rect2(c - Vector2(info.w, info.h) * k / 2, Vector2(info.w, info.h) * k), false)
    _mirror(f, c, k)
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

## The layers of the flagship's mirror over the status panel: mounts on the deck, the superstructure, superfiring
## mounts, then the damage. Each is a child so the mounts can use the mount shader.
var _layers: Array = []
func _mirror(f, c: Vector2, k: float) -> void:
    if _layers.is_empty():
        for kind in ["top", "mounts0", "mounts1", "damage"]:   # as in the battle view: every mount stands above the superstructure layer
            var l := MirrorLayer.new(); l.kind = kind; l.mouse_filter = Control.MOUSE_FILTER_IGNORE; l.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(l); _layers.append(l)
    for l in _layers:
        if l.kind.begins_with("mounts") and l.pal != f.pal: l.material = GameData.mount_material(f.pal); l.pal = f.pal
        l.f = f; l.c = c; l.k = k; l.queue_redraw()

func _hide_mirror() -> void:
    for l in _layers: l.f = null; l.queue_redraw()

class MirrorLayer extends Control:
    var kind := ""
    var f = null
    var c := Vector2.ZERO
    var k := 1.0
    var pal := ""
    func _draw() -> void:
        if f == null: return
        var d: Dictionary = f.d; var info: Dictionary = GameData.sprites.ships[f.rec.type]
        var at = func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
        match kind:
            "top": draw_texture_rect(GameData.ship_tex(f.rec.type, f.pal, "top"), Rect2(c - Vector2(info.w, info.h) * k / 2, Vector2(info.w, info.h) * k), false)
            "mounts0", "mounts1":
                var style := GameData.style_of(f.rec.type)
                for m in f.mounts:
                    if (m.lvl > 0) != (kind == "mounts1") or not GameData.sprites.mounts.has(m.wid) or m.w.kind == "ssm" or m.w.kind == "sam": continue
                    if d.kind == "sub" and m.w.kind == "torp": continue
                    var mi: Dictionary = GameData.sprites.mounts[m.wid]; var sc: float = k / mi.spr * GameData.mount_scale(f.rec.type, m.wid)
                    draw_set_transform(at.call(float(m.slot.x), float(m.slot.y)), m.ta, Vector2(sc, sc))
                    var o = -Vector2(mi.ox, mi.oy) * mi.spr; var code := GameData.mount_code(Vector2(0.55, 0.85).rotated(-m.ta), m.lvl, m.dead)
                    if mi.get("split", false): draw_texture(GameData.mount_img(m.wid, style, true), o, code)
                    draw_texture(GameData.mount_img(m.wid, style), o, code)
                draw_set_transform(Vector2.ZERO)
            "damage":
                var L: float = d.L
                for mk in f.marks:   # shell holes and soot where the hits landed
                    var r: float = maxf(1.5, float(mk.r) * k)
                    draw_texture_rect(GameData.fx_tex("cloud%d" % int(mk.v)), Rect2(at.call(float(mk.x), float(mk.y)) - Vector2(r, r), Vector2(r, r) * 2), false, Color(0.08, 0.06, 0.05, 0.6))
                var hurt = func(v: float) -> Color: return Color(0.85, 0.2, 0.15, clampf((1.0 - v) * 1.4, 0.0, 0.7))
                if f.eng_out > 0 or f.eng < 0.97:   # machinery spaces: a red wash and outline, darker when the engines are stopped
                    var mr := Rect2(at.call(-L * 0.18, -d.B * 0.2), Vector2(L * 0.36, d.B * 0.4) * k)
                    draw_rect(mr, Color(0.6, 0.05, 0.03, 0.5) if f.eng_out > 0 else Color(0.85, 0.2, 0.15, clampf((1.0 - f.eng) * 0.6, 0.08, 0.3)))
                    draw_rect(mr, Color(0.95, 0.3, 0.22, 0.8), false, 1.0)
                if f.jam > 0: draw_rect(Rect2(at.call(-L * 0.48, -d.B * 0.14), Vector2(L * 0.07, d.B * 0.28) * k), Color(0.85, 0.2, 0.15, 0.85))
                var sup: Array = d.p.get("sup", [])
                if not sup.is_empty() and f.fc < 0.97: draw_circle(at.call(float(sup[0][0]), 0.0), maxf(3.0, float(sup[0][2]) * 0.3 * k), hurt.call(f.fc))
                for m in f.mounts:
                    var sl: Dictionary = m.slot; var mp: Vector2 = at.call(float(sl.x), float(sl.y))
                    var sz: float = maxf(2.5, float(m.w.get("tw", 2.5)) * 0.5 * k)
                    for fx in f.flooded: if absf(fx - sl.x) < 1.0 and m.w.kind == "gun": draw_rect(Rect2(mp - Vector2(sz * 1.3, sz * 1.1), Vector2(sz * 2.6, sz * 2.2)), Color(0.35, 0.6, 0.85, 0.55))
                    if m.dead:
                        draw_line(mp - Vector2(sz, sz), mp + Vector2(sz, sz), Color(0.95, 0.3, 0.22), 1.8); draw_line(mp + Vector2(-sz, sz), mp + Vector2(sz, -sz), Color(0.95, 0.3, 0.22), 1.8)
                    elif m.ammo == 0: draw_arc(mp, sz * 0.8, 0, TAU, 16, Color(0.9, 0.62, 0.2, 0.95), 1.5)

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
