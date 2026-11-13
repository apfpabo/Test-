extends Control
## Battle setup: pick a preset engagement or build both squadrons from the design registers.
## Quick battles outside the campaign.

const ERA_TECH := {1: [], 2: ["radar", "sonar", "homing", "aa_prox", "dc", "amphib", "missiles", "jets", "nuclear", "snorkel"], 3: ["radar", "sonar", "homing", "aa_prox", "dc", "amphib", "missiles", "jets", "nuclear", "snorkel", "helo", "ecm", "ciws", "aegis", "vls", "reactors", "datalink"]}
const PRESETS := [
    {"name": "Destroyer action", "desc": "Three Tidewater destroyers against three Strelsk destroyers. Fast, close, torpedoes in the water.", "player": ["dd_fletcher", "dd_fletcher", "dd_gearing"], "enemy": ["dd_narvik", "dd_narvik", "dd_narvik"], "fac": "directorate", "era": 1},
    {"name": "Cruiser action", "desc": "A Sovereign-class heavy cruiser and an Arbiter-class light cruiser with a destroyer screen against two Feldherr-class cruisers.", "player": ["ca_baltimore", "cl_cleveland", "dd_fletcher", "dd_fletcher"], "enemy": ["ca_hipper", "ca_hipper", "dd_narvik", "dd_narvik"], "fac": "directorate", "era": 1},
    {"name": "Battle line", "desc": "Constellation- and Monarch-class battleships against a Hochmeister-class battleship and her cruisers. Heavy shells at 6 km.", "player": ["bb_iowa", "bb_kgv", "ca_baltimore", "dd_fletcher", "dd_fletcher"], "enemy": ["bb_bismarck", "ca_hipper", "ca_hipper", "dd_narvik", "dd_narvik"], "fac": "directorate", "era": 1},
    {"name": "The long lances", "desc": "An Arbiter-class cruiser and destroyers against a Halcyon Federation squadron armed with long-range torpedoes.", "player": ["cl_cleveland", "dd_fletcher", "dd_fletcher", "dd_fletcher"], "enemy": ["cl_agano", "dd_kagero", "dd_kagero", "dd_kagero"], "fac": "pacific", "era": 1},
    {"name": "The Amaterasu sorties", "desc": "Two Constellation-class battleships against the largest battleship afloat and her screen.", "player": ["bb_iowa", "bb_iowa", "dd_fletcher", "dd_fletcher"], "enemy": ["bb_yamato", "ca_takao", "dd_kagero", "dd_kagero"], "fac": "pacific", "era": 1},
    {"name": "Convoy raid", "desc": "One submarine against a Combine convoy and its corvette.", "player": ["ss_gato"], "enemy": ["fr_liberty", "fr_liberty", "fr_victory", "co_castle"], "fac": "combine", "era": 1},
    {"name": "Carrier strike", "desc": "An escort carrier and destroyers against a heavy cruiser group. Launch with F.", "player": ["cve_casa", "dd_fletcher", "dd_fletcher"], "enemy": ["ca_hipper", "dd_narvik", "dd_narvik"], "fac": "directorate", "era": 1},
    {"name": "Missile age", "desc": "Era III: a Bastion-class missile cruiser group against a Gromoboi-class group, with nuclear submarines on both sides.", "player": ["cg_tico", "ddg_adams", "ssn_skipjack"], "enemy": ["cg_slava", "ddg_kashin", "ssn_november"], "fac": "directorate", "era": 3},
]
var mine: Array = []
var theirs: Array = []
var mine_mods: Array = []    # one per ship in `mine`: {} or {fit, up} chosen in the ship editor
var theirs_mods: Array = []
var editor_box: VBoxContainer   # the ship editor, under the lists
var design_pick: OptionButton
var fac_pick: OptionButton
var era_pick: OptionButton
var wx_pick: OptionButton
var hour_pick: OptionButton
var mine_list: ItemList
var theirs_list: ItemList
var ids: Array = []

func _ready() -> void:
    Sfx.music("menu")
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var bg = ColorRect.new(); bg.color = Color(0.06, 0.12, 0.14); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
    var scroll = ScrollContainer.new(); scroll.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(scroll)
    var margin = MarginContainer.new(); margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for s in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + s, 28)
    scroll.add_child(margin)
    var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 10); margin.add_child(col)
    var title = Label.new(); title.text = "IRON MERIDIAN · BATTLE"; title.add_theme_font_size_override("font_size", 34); title.add_theme_color_override("font_color", Color(0.89, 0.7, 0.24)); col.add_child(title)
    var sub = Label.new(); sub.text = "Pick an engagement, or build both squadrons below. The campaign is on the title screen."; sub.add_theme_color_override("font_color", Color(0.62, 0.67, 0.67)); col.add_child(sub)
    var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); col.add_child(grid)
    for pr in PRESETS:
        var b = Button.new(); b.text = pr.name + "\n" + pr.desc; b.custom_minimum_size = Vector2(320, 92); b.autowrap_mode = TextServer.AUTOWRAP_WORD; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(func(): _start(pr.player, pr.enemy, pr.fac, pr.era)); grid.add_child(b)
    col.add_child(HSeparator.new())
    var h = Label.new(); h.text = "Custom engagement"; h.add_theme_font_size_override("font_size", 20); col.add_child(h)
    var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); col.add_child(row)
    design_pick = OptionButton.new(); design_pick.custom_minimum_size = Vector2(560, 0); row.add_child(design_pick)
    for cls in GameData.hull_order:
        for id in GameData.hulls:
            var d: Dictionary = GameData.hulls[id]
            if d.klass != cls: continue
            ids.append(id); design_pick.add_item("%s · %s class (%s, %d) · after the %s · %d t, %s kn" % [d.name, d.dn, GameData.makers[d.yard].short, d.year, d.model, d.t, str(d.kn)])
    var add_m = Button.new(); add_m.text = "Add to my squadron"; add_m.pressed.connect(func(): _add(mine)); row.add_child(add_m)
    var add_t = Button.new(); add_t.text = "Add to the enemy"; add_t.pressed.connect(func(): _add(theirs)); row.add_child(add_t)
    var row2 = HBoxContainer.new(); row2.add_theme_constant_override("separation", 8); col.add_child(row2)
    var l1 = Label.new(); l1.text = "Enemy flag"; row2.add_child(l1)
    fac_pick = OptionButton.new(); for f in ["directorate", "pacific", "concord", "combine", "republic", "freeport", "raiders"]: fac_pick.add_item(GameData.fac[f].name); fac_pick.set_item_metadata(fac_pick.item_count - 1, f)
    row2.add_child(fac_pick)
    var l2 = Label.new(); l2.text = "   Technology"; row2.add_child(l2)
    era_pick = OptionButton.new(); era_pick.add_item("Era I · Late war"); era_pick.add_item("Era II · Jet age"); era_pick.add_item("Era III · Missile age"); row2.add_child(era_pick)
    var l3 = Label.new(); l3.text = "   Weather"; row2.add_child(l3)
    wx_pick = OptionButton.new(); for n in ["Calm", "Moderate sea", "Rough sea", "Storm", "Fog"]: wx_pick.add_item(n)
    row2.add_child(wx_pick)
    var l4 = Label.new(); l4.text = "   Hour"; row2.add_child(l4)
    hour_pick = OptionButton.new(); for n in ["Day", "Night, full moon", "Night, no moon"]: hour_pick.add_item(n)
    row2.add_child(hour_pick)
    var lists = HBoxContainer.new(); lists.add_theme_constant_override("separation", 12); col.add_child(lists)
    mine_list = _list(lists, "My squadron (click a ship to refit her)", mine, mine_mods); theirs_list = _list(lists, "Enemy (click a ship to refit her)", theirs, theirs_mods)
    editor_box = VBoxContainer.new(); editor_box.add_theme_constant_override("separation", 6); col.add_child(editor_box)
    var go = Button.new(); go.text = "Battle stations"; go.custom_minimum_size = Vector2(220, 44)
    go.pressed.connect(func(): if mine.size() and theirs.size(): _start(mine, theirs, fac_pick.get_item_metadata(fac_pick.selected), era_pick.selected + 1))
    col.add_child(go)
    var back := Button.new(); back.text = "Back to the title screen"; back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn")); col.add_child(back)

func _list(parent: Control, label: String, arr: Array, mods: Array) -> ItemList:
    var box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(box)
    var l = Label.new(); l.text = label; box.add_child(l)
    var il = ItemList.new(); il.custom_minimum_size = Vector2(0, 160); box.add_child(il)
    il.item_clicked.connect(func(i, _p, _b): _edit(arr, mods, i))
    return il

func _add(arr: Array) -> void:
    if arr.size() < 10:
        arr.append(ids[design_pick.selected]); (mine_mods if is_same(arr, mine) else theirs_mods).append({}); _refresh()

## The research a side's ship is fitted from: the era picked, or her own if she is newer (as _start reckons it).
func _tech_for(id: String) -> Array:
    return ERA_TECH[maxi(era_pick.selected + 1, mini(3, int(GameData.hulls[id].get("era", 1))))]

## The ship editor (the owner, 13 Nov 2026): a weapon for each mount, the marks of each system, her weight against what
## her hull can carry, and Remove. What is chosen goes into the battle with her (battle.gd _recs).
func _edit(arr: Array, mods: Array, i: int) -> void:
    for c in editor_box.get_children(): c.queue_free()
    if i < 0 or i >= arr.size(): return
    var id: String = arr[i]; var d: Dictionary = GameData.hulls[id]; var tech := _tech_for(id)
    while mods.size() < arr.size(): mods.append({})
    var m: Dictionary = mods[i]
    if not m.has("fit"): m.fit = BattleSim.default_fit(d, tech)
    if not m.has("up"): m.up = {}
    var h := Label.new(); h.text = "%s · %s class · %s" % [d.name, d.dn, "your squadron" if is_same(arr, mine) else "the enemy"]; h.add_theme_font_size_override("font_size", 18); h.add_theme_color_override("font_color", Color(0.89, 0.7, 0.24)); editor_box.add_child(h)
    var ld: Dictionary = BattleSim.loading(d, m.fit, m.up)
    var wl := Label.new(); wl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.3) if not ld.ok else Color(0.62, 0.67, 0.67))
    wl.text = "Weight: %d t carried against %d t designed, %s%s" % [int(ld.tons), int(ld.std), ("%d t in hand" % int(-float(ld.over_t))) if float(ld.over_t) <= 0.0 else ("%d t over her margin, %d%% slower" % [int(ld.over_t), int(round((1.0 - float(ld.speed)) * 100))]), "" if ld.ok else ". A yard would not pass this fit."]
    editor_box.add_child(wl)
    var grid := GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 10); editor_box.add_child(grid)
    var sizes := {"S": "Small gun", "M": "Medium gun", "L": "Large gun", "H": "Heavy gun", "A": "AA / close-in", "T": "Torpedoes", "V": "Launch cells"}
    for si in d.slots.size():
        var sl: Dictionary = d.slots[si]
        var lab := Label.new(); lab.text = "%s · %s" % [sizes.get(sl.s, sl.s), "fwd" if sl.x > 10 else ("aft" if sl.x < -10 else "mid")]; lab.custom_minimum_size.x = 150; grid.add_child(lab)
        var ob := OptionButton.new(); ob.add_item("(empty)"); ob.set_item_metadata(0, ""); ob.custom_minimum_size.x = 250
        for wid in GameData.weapons:
            var w: Dictionary = GameData.weapons[wid]
            if not _fits(wid, sl.s) or (w.has("tech") and not tech.has(w.tech)): continue
            ob.add_item(String(w.name)); ob.set_item_metadata(ob.item_count - 1, wid)
            if wid == m.fit[si]: ob.selected = ob.item_count - 1
        var sx: int = si
        ob.item_selected.connect(func(j): m.fit[sx] = ob.get_item_metadata(j); _edit(arr, mods, i))
        grid.add_child(ob)
    var sh := Label.new(); sh.text = "Ship systems"; sh.add_theme_color_override("font_color", Color(0.62, 0.67, 0.67)); editor_box.add_child(sh)
    var g2 := GridContainer.new(); g2.columns = 4; g2.add_theme_constant_override("h_separation", 10); editor_box.add_child(g2)
    for k in BattleSim.UPGRADES:
        var u: Dictionary = BattleSim.UPGRADES[k]
        if u.get("needs_sonar", false) and not d.get("sonar", false): continue
        var lab2 := Label.new(); lab2.text = String(u.name); lab2.tooltip_text = "%s a mark" % u.per; lab2.mouse_filter = Control.MOUSE_FILTER_PASS; lab2.custom_minimum_size.x = 150; g2.add_child(lab2)
        var ob2 := OptionButton.new(); ob2.add_item("Standard"); ob2.add_item("Mk I")
        if u.get("mk2", "") == "" or tech.has(u.mk2): ob2.add_item("Mk II")
        ob2.selected = mini(int(m.up.get(k, 0)), ob2.item_count - 1)
        var kk: String = k
        ob2.item_selected.connect(func(j):
            m.up[kk] = j
            if j == 0: m.up.erase(kk)
            _edit(arr, mods, i))
        g2.add_child(ob2)
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); editor_box.add_child(row)
    var std := Button.new(); std.text = "Standard fit"; std.pressed.connect(func(): mods[i] = {}; _edit(arr, mods, i)); row.add_child(std)
    var rm := Button.new(); rm.text = "Remove her"; rm.pressed.connect(func(): arr.remove_at(i); mods.remove_at(i); _refresh(); _close_editor()); row.add_child(rm)
    var done := Button.new(); done.text = "Done"; done.pressed.connect(func(): _refresh(); _close_editor()); row.add_child(done)

func _close_editor() -> void:
    for c in editor_box.get_children(): c.queue_free()

## A weapon fits a mount of its own size class, or one size larger (as the refit page has it).
func _fits(wid: String, slot: String) -> bool:
    var w: Dictionary = GameData.weapons[wid]; var gs = ["S", "M", "L", "H"]
    if gs.has(slot): return gs.has(w.size) and gs.find(w.size) <= gs.find(slot) and gs.find(w.size) >= gs.find(slot) - 1
    return w.size == slot

func _refresh() -> void:
    for pair in [[mine_list, mine], [theirs_list, theirs]]:
        pair[0].clear()
        var mods: Array = mine_mods if is_same(pair[1], mine) else theirs_mods
        for k in pair[1].size():
            var id: String = pair[1][k]; var refit: bool = k < mods.size() and not mods[k].is_empty()
            pair[0].add_item(GameData.hulls[id].name + " · " + GameData.hulls[id].dn + " class" + (" · refitted" if refit else ""))

func _start(p: Array, e: Array, fac: String, era: int) -> void:
    var w := {"sea": mini(wx_pick.selected, 3) if wx_pick.selected < 4 else 0, "fog": wx_pick.selected == 4, "night": hour_pick.selected > 0, "moon": 1.0 if hour_pick.selected == 1 else 0.1}
    # each side has at least the research its newest ship was built round: a missile submarine picked in an earlier era
    # went to sea with empty launch tubes (the owner, 13 Nov 2026)
    var side_era := func(ids: Array) -> int:
        var e2 := era
        for id in ids: e2 = maxi(e2, mini(3, int(GameData.hulls[id].get("era", 1))))
        return e2
    GameData.pending = {"player": p.duplicate(), "enemy": e.duplicate(), "player_mods": (mine_mods if is_same(p, mine) else []).duplicate(true), "enemy_mods": (theirs_mods if is_same(e, theirs) else []).duplicate(true), "enemy_fac": fac, "player_tech": ERA_TECH[side_era.call(p)], "enemy_tech": ERA_TECH[side_era.call(e)], "islands": randi_range(0, 4), "weather": Weather.battle(w)}
    get_tree().change_scene_to_file("res://scenes/battle.tscn")
