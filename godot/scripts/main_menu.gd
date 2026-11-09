extends Control
## Title screen: continue the campaign, start a new one, or fight a quick battle.

func _ready() -> void:
    theme = UI.theme(); set_anchors_preset(Control.PRESET_FULL_RECT)
    var bg = ColorRect.new(); bg.color = Color(0.086, 0.227, 0.267); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
    var center = CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(center)
    var pc = PanelContainer.new(); pc.custom_minimum_size = Vector2(900, 0); center.add_child(pc)
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); pc.add_child(box)
    box.add_child(UI.label("Iron Meridian", UI.GOLD, 52))
    box.add_child(UI.label("1946. The Great War of the 1940s ended in an armistice nobody honours. Legacy empires, successor states, corporations and pirates contest the world's oceans, and sea control is the only currency that counts. You are a free captain with one tired ship. Trade, salvage, fight and research your way from late-war gunnery towards the missile age, and serve a flag or stay your own master.", UI.DIM, 15, true))
    if Campaign.has_save():
        box.add_child(UI.button("Continue campaign", func():
            if Campaign.load_game(): get_tree().change_scene_to_file("res://scenes/world_map.tscn"), true))
    box.add_child(UI.label("CHOOSE YOUR START", UI.DIM, 12))
    var grid = GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 10); box.add_child(grid)
    for key in Campaign.C.STARTS:
        var st: Dictionary = Campaign.C.STARTS[key]
        var b = Button.new(); b.text = st.label + "\n\n" + st.blurb; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.custom_minimum_size = Vector2(280, 170); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(func(): Campaign.new_game(key); get_tree().change_scene_to_file("res://scenes/world_map.tscn")); grid.add_child(b)
    box.add_child(UI.row([UI.button("Quick battle", func(): get_tree().change_scene_to_file("res://scenes/skirmish.tscn"))]))
    # required by the CC BY 4.0 licence of the engine-room recording; the other sounds are CC0 (assets/sfx/CREDITS.md)
    box.add_child(UI.label("Sound: engine room of the icebreaker Kuna, recorded by Work With Sounds / Museum of Municipal Engineering (CC BY 4.0; trimmed, filtered and looped). Other sound effects are CC0, by thimras, qubodup, Joth and rubberduck on OpenGameArt.", UI.DIM, 11, true))
