extends Control
## Editor mode (owner's request): a panel over a battle for staging and recording actions. Put ships of any design on
## the sea under either flag, take them off, refit them where they lie, take command of any of them, set any ship on
## any other, mend or wreck them, and change the hour, the weather and the pace. Loaded by path from battle.gd.
## H hides everything on the screen but the picture; F9 hides this panel alone.

var battle
var pick = null             # the ship the panel is working on (Alt+click a ship, or choose her from the list)
var mode := ""              # "": nothing armed; "place": the next click puts a ship there; "target": the next click names her target
var side := 0
var design := "dd_fletcher"
var panel: PanelContainer
var box: VBoxContainer
var _sig := ""

const WEATHERS := [["Day", {"sea": 0, "fog": false, "night": false, "moon": 0.5}], ["Moonlit night", {"sea": 0, "fog": false, "night": true, "moon": 0.9}], ["Dark night", {"sea": 0, "fog": false, "night": true, "moon": 0.0}],
    ["Rough", {"sea": 2, "fog": false, "night": false, "moon": 0.5}], ["Storm", {"sea": 3, "fog": false, "night": false, "moon": 0.5}], ["Fog", {"sea": 0, "fog": true, "night": false, "moon": 0.5}]]

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE; theme = UI.theme()
    panel = PanelContainer.new(); add_child(panel)
    # right-hand side, between the orders row and the minimap (the far edges first: an anchor cannot pass its opposite)
    panel.set_anchor_and_offset(SIDE_RIGHT, 1.0, -12); panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -262); panel.set_anchor_and_offset(SIDE_LEFT, 1.0, -372); panel.set_anchor_and_offset(SIDE_TOP, 0.0, 118)
    var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(sc)
    box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.custom_minimum_size.x = 320; box.add_theme_constant_override("separation", 6); sc.add_child(box)
    rebuild()

## Is the pointer over the panel? (The battle reads clicks before the interface does, so it must ask.)
func over(at: Vector2) -> bool: return visible and panel.visible and panel.get_global_rect().has_point(at)

func _ship_at(w: Vector2):
    var best = null; var bd := INF; var sim = battle.sim
    for o in sim.ships:
        if not o.alive: continue
        var d: float = o.pos.distance_to(w)
        if d < maxf(30.0 / battle.zoom(), o.d.L * 0.6) and d < bd: bd = d; best = o
    return best

## A click on the sea, offered to the editor first. True if it was used.
func click(w: Vector2, alt: bool) -> bool:
    var sim = battle.sim
    if mode == "place": _place(w); return true
    if mode == "target":
        var tg = _ship_at(w)
        if tg != null and pick != null and tg != pick: pick.force_tgt = tg; sim.say("%s: engage the %s." % [pick.rec.name, tg.rec.name], 1.6)
        mode = ""; rebuild(); return true
    if alt:
        var s2 = _ship_at(w)
        if s2 != null: pick = s2; rebuild()
        return true
    return false

func _process(_d: float) -> void:
    if battle == null or not visible: return
    var vs: Vector2 = get_viewport_rect().size   # fill the screen (a Control straight under a CanvasLayer does not size itself)
    if size != vs: position = Vector2.ZERO; size = vs
    var sim = battle.sim
    if pick != null and not sim.ships.has(pick): pick = null
    var sig := "%d|%s|%s|%d" % [sim.ships.size(), str(pick.get_instance_id()) if pick != null else "-", mode, int(pick.alive) if pick != null else 0]
    if sig != _sig: rebuild()

func _fits(wid: String, slot: String) -> bool:
    var w: Dictionary = GameData.weapons[wid]; var gs := ["S", "M", "L", "H"]
    if gs.has(slot): return gs.has(w.size) and gs.find(w.size) <= gs.find(slot) and gs.find(w.size) >= gs.find(slot) - 1
    return w.size == slot

func _lab(text: String, col: Color, sz := 12) -> Label:
    var l := UI.label(text, col, sz); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 60; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return l
func _btn(text: String, cb: Callable, on := false, off := false) -> Button:
    var b := UI.button(text, cb, on, off); b.focus_mode = Control.FOCUS_NONE; b.add_theme_font_size_override("font_size", 12); b.custom_minimum_size.y = 26; return b
func _flow(items: Array) -> HFlowContainer:
    var f := HFlowContainer.new(); f.add_theme_constant_override("h_separation", 4); f.add_theme_constant_override("v_separation", 4)
    for it in items: f.add_child(it)
    return f

func _place(at: Vector2) -> void:
    var sim = battle.sim
    var s = sim.spawn(design, side, at.clamp(Vector2(200, 200), Vector2(sim.AW - 200, sim.AH - 200)), -PI / 2 if side == 0 else PI / 2, [])
    battle._add_view(s); pick = s; rebuild()
func _mend(p) -> void:
    p.hull = p.max_hull; p.armor = p.d.armor; p.fires.clear(); p.eng = 1.0; p.eng_out = 0.0; p.jam = 0.0; p.steer = 1.0; p.list = 0.0; p.ballast = 0.0; p.mag_fire = 0.0; p.struck = false; p.deck_out = 0.0
    for m in p.mounts: m.dead = false; m.ammo = m.ammo_max
func _all(what: String) -> void:
    var sim = battle.sim
    match what:
        "idle": for o in sim.ships: o.ai_off = true
        "act": for o in sim.ships: o.ai_off = false
        "cease":
            sim.hold_fire = true
            for o in sim.ships: o.force_tgt = null; o.hold = true
        "fire":
            sim.hold_fire = false
            for o in sim.ships: o.hold = false
        "mend": for o in sim.ships: if o.alive: _mend(o)
        "off":
            for o in sim.ships.duplicate(): battle.remove_view(o); sim.despawn(o)
            pick = null
    rebuild()

func rebuild() -> void:
    var sim = battle.sim
    _sig = "%d|%s|%s|%d" % [sim.ships.size(), str(pick.get_instance_id()) if pick != null else "-", mode, int(pick.alive) if pick != null else 0]
    for c in box.get_children(): c.queue_free()
    var ttl := UI.label("EDITOR", UI.GOLD, 20); ttl.add_theme_font_override("font", UI.font("cond")); box.add_child(ttl)
    box.add_child(_lab("H hides the whole interface for recording · F9 hides this panel · Alt+click picks a ship · Tab takes command of the next", UI.DIM, 12))
    # ---- ships on the sea
    box.add_child(UI.label("PUT A SHIP ON THE SEA", UI.DIM, 12))
    var ob := OptionButton.new(); ob.focus_mode = Control.FOCUS_NONE; ob.fit_to_longest_item = false; ob.clip_text = true;  ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var ids: Array = GameData.hulls.keys(); ids.sort_custom(func(a, b): return [GameData.hulls[a].klass, GameData.hulls[a].t, a] < [GameData.hulls[b].klass, GameData.hulls[b].t, b])
    for id in ids:
        var h: Dictionary = GameData.hulls[id]
        ob.add_item("%s · %s (%s)" % [String(h.klass).to_upper(), h.dn, h.name]); ob.set_item_metadata(ob.item_count - 1, id)
        if id == design: ob.selected = ob.item_count - 1
    ob.item_selected.connect(func(i): design = ob.get_item_metadata(i))
    box.add_child(ob)
    box.add_child(_flow([_btn("Yours", func(): side = 0; rebuild(), side == 0), _btn("Enemy", func(): side = 1; rebuild(), side == 1),
        _btn("Click to place" if mode != "place" else "Placing: click the sea", func(): mode = "" if mode == "place" else "place"; rebuild(), mode == "place"),
        _btn("At the centre", func(): _place(battle.camera.position))]))
    # ---- the ship picked
    box.add_child(UI.label("THE SHIP PICKED", UI.DIM, 12))
    var sl := OptionButton.new(); sl.focus_mode = Control.FOCUS_NONE; sl.fit_to_longest_item = false; sl.clip_text = true;  sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sl.add_item("(none: Alt+click one, or choose here)"); sl.set_item_metadata(0, null)
    for o in sim.ships:
        sl.add_item("%s%s · %s · %s" % ["★ " if o == sim.flag else "", o.rec.name, o.d.name, "yours" if o.side == 0 else "enemy"] + ("" if o.alive else " · sunk")); sl.set_item_metadata(sl.item_count - 1, o)
        if o == pick: sl.selected = sl.item_count - 1
    sl.item_selected.connect(func(i): pick = sl.get_item_metadata(i); rebuild())
    box.add_child(sl)
    if pick != null:
        var p = pick
        box.add_child(_lab("%s · %s class · hull %d%%%s%s" % [p.rec.name, p.d.dn, int(100.0 * p.hull / p.max_hull), " · her captain is idle" if p.ai_off else "", (" · set on the " + p.force_tgt.rec.name) if p.force_tgt != null else ""], UI.INK, 13))
        box.add_child(_flow([
            _btn("Command her", func(): sim.waypoints.clear(); sim.flag = p; battle.cam_free = false; rebuild(), p == sim.flag),
            _btn("Change flag", func(): sim.set_side(p, 1 - p.side); battle.rebuild_view(p); rebuild()),
            _btn("Captain idle" if not p.ai_off else "Captain acts", func(): p.ai_off = not p.ai_off; rebuild(), p.ai_off),
            _btn("Stop", func(): p.ai_off = true; p.throttle = 0; p.rudder = 0.0; rebuild()),
            _btn("Attack… (click a target)" if mode != "target" else "Click her target", func(): mode = "" if mode == "target" else "target"; rebuild(), mode == "target"),
            _btn("Cease", func(): p.force_tgt = null; rebuild(), false, p.force_tgt == null)]))
        box.add_child(_flow([
            _btn("Mend", func(): _mend(p); rebuild()),
            _btn("Hit 25%", func(): var g: bool = p.god; p.god = false; sim.damage(p, p.max_hull * 0.25, "resolved"); p.god = g; rebuild()),
            _btn("Set afire", func(): sim.mark_hit(p, p.pos + Vector2((randf() - 0.5) * p.d.L * 0.5, 0).rotated(p.a), 3.0, false, 20.0)),
            _btn("Torpedo her", func(): var g2: bool = p.god; p.god = false; sim.hit_systems(p, p.pos + Vector2(0, p.d.B * 0.4).rotated(p.a), 400.0, "torp"); sim.damage(p, 400.0, "torp"); sim.part(BattleSim.P.GEYSER, p.pos, 1.6, 40.0); sim.sound("torp_hit", p.pos, 0.7); p.god = g2; rebuild()),
            _btn("Engines out", func(): p.eng_out = 60.0), _btn("Jam rudder", func(): p.jam = 60.0; p.jam_r = 0.8),
            _btn("Cannot be hurt" if not p.god else "Can be hurt", func(): p.god = not p.god; rebuild(), p.god),
            _btn("Sink", func(): p.god = false; sim.damage(p, p.max_hull * 10.0, "resolved"); rebuild()),
            _btn("Take off the sea", func(): battle.remove_view(p); sim.despawn(p); pick = null; rebuild())]))
        box.add_child(UI.label("HER WEAPONS (changed where she lies)", UI.DIM, 12))
        var names := {"S": "Small gun", "M": "Medium gun", "L": "Large gun", "H": "Heavy gun", "A": "AA", "T": "Torpedoes", "V": "Launch cells"}
        for i in p.d.slots.size():
            var slot: Dictionary = p.d.slots[i]; var cur: String = p.rec.fit[i] if p.rec.fit[i] != null else ""
            var wb := OptionButton.new(); wb.focus_mode = Control.FOCUS_NONE; wb.fit_to_longest_item = false; wb.clip_text = true;  wb.custom_minimum_size.x = 200; wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            wb.add_item("(empty)"); wb.set_item_metadata(0, "")
            for wid in GameData.weapons:
                if not _fits(wid, slot.s) or not BattleSim.room_for(slot, wid) or (GameData.weapons[wid].get("power", false) and not p.d.get("power", false)): continue
                wb.add_item(GameData.weapons[wid].name); wb.set_item_metadata(wb.item_count - 1, wid)
                if wid == cur: wb.selected = wb.item_count - 1
            var idx: int = i
            wb.item_selected.connect(func(j): p.rec.fit[idx] = wb.get_item_metadata(j); sim.fit_mounts(p); battle.rebuild_view(p))
            var lb := UI.label("%s %s" % [names[slot.s], "fwd" if slot.x > 10 else ("aft" if slot.x < -10 else "mid")], UI.DIM, 12); lb.custom_minimum_size.x = 100
            box.add_child(UI.row([lb, wb]))
    # ---- the sea and the clock
    box.add_child(UI.label("THE HOUR AND THE WEATHER", UI.DIM, 12))
    var wr := []
    for wv in WEATHERS:
        var spec: Dictionary = wv[1]
        wr.append(_btn(wv[0], func(): sim.wx = Weather.battle(spec); battle.apply_weather(); rebuild()))
    box.add_child(_flow(wr))
    box.add_child(UI.label("THE ACTION", UI.DIM, 12))
    box.add_child(_flow([
        _btn("All in sight" if sim.reveal else "Sight as in play", func(): sim.reveal = not sim.reveal; rebuild(), sim.reveal),
        _btn("Slower", func(): battle.speed_i = maxi(0, battle.speed_i - 1); sim.say("Time ×%s" % str(battle.combat_speed() * BattleSim.BT), 1.0)),
        _btn("Faster", func(): battle.speed_i = mini(battle.speeds.size() - 1, battle.speed_i + 1); sim.say("Time ×%s" % str(battle.combat_speed() * BattleSim.BT), 1.0)),
        _btn("Pause (P)", func(): battle.paused = not battle.paused),
        _btn("All captains idle", func(): _all("idle")), _btn("All captains act", func(): _all("act")),
        _btn("All cease fire", func(): _all("cease")), _btn("Fire at will", func(): _all("fire")), _btn("Mend all", func(): _all("mend")),
        _btn("Clear the sea of wrecks and smoke", func(): sim.screens.clear(); sim.scars.clear(); sim.wrecks.clear(); sim.flares.clear(); sim.parts.clear()),
        _btn("Take every ship off", func(): _all("off"))]))
