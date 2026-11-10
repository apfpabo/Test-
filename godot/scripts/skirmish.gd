extends Control
## Battle setup: pick a preset engagement or build both squadrons from the design registers.
## Quick battles outside the campaign.

const ERA_TECH := {1: [], 2: ["radar", "sonar", "homing", "aa_prox", "dc", "amphib", "missiles", "jets", "nuclear", "snorkel"], 3: ["radar", "sonar", "homing", "aa_prox", "dc", "amphib", "missiles", "jets", "nuclear", "snorkel", "helo", "ecm", "ciws", "aegis", "vls", "reactors", "datalink"]}
const PRESETS := [
    {"name": "Destroyer action", "desc": "Three Tidewater destroyers against three Strelsk destroyers. Fast, close, torpedoes in the water.", "player": ["dd_fletcher", "dd_fletcher", "dd_gearing"], "enemy": ["dd_narvik", "dd_narvik", "dd_narvik"], "fac": "directorate", "era": 1},
    {"name": "Cruiser action", "desc": "A Baltimore-type and a Cleveland-type with a destroyer screen against two Hipper-types.", "player": ["ca_baltimore", "cl_cleveland", "dd_fletcher", "dd_fletcher"], "enemy": ["ca_hipper", "ca_hipper", "dd_narvik", "dd_narvik"], "fac": "directorate", "era": 1},
    {"name": "Battle line", "desc": "Iowa- and King George V-types against a Bismarck-type and her cruisers. Heavy shells at 6 km.", "player": ["bb_iowa", "bb_kgv", "ca_baltimore", "dd_fletcher", "dd_fletcher"], "enemy": ["bb_bismarck", "ca_hipper", "ca_hipper", "dd_narvik", "dd_narvik"], "fac": "directorate", "era": 1},
    {"name": "The long lances", "desc": "A Cleveland-type and destroyers against a Halcyon Federation squadron armed with long-range torpedoes.", "player": ["cl_cleveland", "dd_fletcher", "dd_fletcher", "dd_fletcher"], "enemy": ["cl_agano", "dd_kagero", "dd_kagero", "dd_kagero"], "fac": "pacific", "era": 1},
    {"name": "Yamato sorties", "desc": "Two Iowa-types against the largest battleship afloat and her screen.", "player": ["bb_iowa", "bb_iowa", "dd_fletcher", "dd_fletcher"], "enemy": ["bb_yamato", "ca_takao", "dd_kagero", "dd_kagero"], "fac": "pacific", "era": 1},
    {"name": "Convoy raid", "desc": "One submarine against a Combine convoy and its corvette.", "player": ["ss_gato"], "enemy": ["fr_liberty", "fr_liberty", "fr_victory", "co_castle"], "fac": "combine", "era": 1},
    {"name": "Carrier strike", "desc": "An escort carrier and destroyers against a heavy cruiser group. Launch with F.", "player": ["cve_casa", "dd_fletcher", "dd_fletcher"], "enemy": ["ca_hipper", "dd_narvik", "dd_narvik"], "fac": "directorate", "era": 1},
    {"name": "Missile age", "desc": "Era III: an Aegis cruiser group against a Slava-type group, with nuclear submarines on both sides.", "player": ["cg_tico", "ddg_adams", "ssn_skipjack"], "enemy": ["cg_slava", "ddg_kashin", "ssn_november"], "fac": "directorate", "era": 3},
]
var mine: Array = []
var theirs: Array = []
var design_pick: OptionButton
var fac_pick: OptionButton
var era_pick: OptionButton
var wx_pick: OptionButton
var hour_pick: OptionButton
var mine_list: ItemList
var theirs_list: ItemList
var ids: Array = []

func _ready() -> void:
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
    era_pick = OptionButton.new(); era_pick.add_item("Era I · Late war"); era_pick.add_item("Era II · Early Cold War"); era_pick.add_item("Era III · Late Cold War"); row2.add_child(era_pick)
    var l3 = Label.new(); l3.text = "   Weather"; row2.add_child(l3)
    wx_pick = OptionButton.new(); for n in ["Calm", "Moderate sea", "Rough sea", "Storm", "Fog"]: wx_pick.add_item(n)
    row2.add_child(wx_pick)
    var l4 = Label.new(); l4.text = "   Hour"; row2.add_child(l4)
    hour_pick = OptionButton.new(); for n in ["Day", "Night, full moon", "Night, no moon"]: hour_pick.add_item(n)
    row2.add_child(hour_pick)
    var lists = HBoxContainer.new(); lists.add_theme_constant_override("separation", 12); col.add_child(lists)
    mine_list = _list(lists, "My squadron (click to remove)", mine); theirs_list = _list(lists, "Enemy (click to remove)", theirs)
    var go = Button.new(); go.text = "Battle stations"; go.custom_minimum_size = Vector2(220, 44)
    go.pressed.connect(func(): if mine.size() and theirs.size(): _start(mine, theirs, fac_pick.get_item_metadata(fac_pick.selected), era_pick.selected + 1))
    col.add_child(go)
    var back := Button.new(); back.text = "Back to the title screen"; back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn")); col.add_child(back)

func _list(parent: Control, label: String, arr: Array) -> ItemList:
    var box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(box)
    var l = Label.new(); l.text = label; box.add_child(l)
    var il = ItemList.new(); il.custom_minimum_size = Vector2(0, 160); box.add_child(il)
    il.item_clicked.connect(func(i, _p, _b): arr.remove_at(i); _refresh())
    return il

func _add(arr: Array) -> void:
    if arr.size() < 10: arr.append(ids[design_pick.selected]); _refresh()

func _refresh() -> void:
    for pair in [[mine_list, mine], [theirs_list, theirs]]:
        pair[0].clear()
        for id in pair[1]: pair[0].add_item(GameData.hulls[id].name + " · " + GameData.hulls[id].dn + " class")

func _start(p: Array, e: Array, fac: String, era: int) -> void:
    var w := {"sea": mini(wx_pick.selected, 3) if wx_pick.selected < 4 else 0, "fog": wx_pick.selected == 4, "night": hour_pick.selected > 0, "moon": 1.0 if hour_pick.selected == 1 else 0.1}
    GameData.pending = {"player": p.duplicate(), "enemy": e.duplicate(), "enemy_fac": fac, "player_tech": ERA_TECH[era], "enemy_tech": ERA_TECH[era], "islands": randi_range(0, 4), "weather": Weather.battle(w)}
    get_tree().change_scene_to_file("res://scenes/battle.tscn")
