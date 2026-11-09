extends Control
## Title screen: continue the campaign, start a new one, or fight a quick battle.

func _ready() -> void:
    theme = UI.theme(); set_anchors_preset(Control.PRESET_FULL_RECT)
    # a dark sea with a little light at its heart
    var bg = TextureRect.new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.stretch_mode = TextureRect.STRETCH_SCALE
    var gt := GradientTexture2D.new(); gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.42); gt.fill_to = Vector2(1.15, 1.1)
    var gr := Gradient.new(); gr.colors = PackedColorArray([Color(0.07, 0.17, 0.2), Color(0.02, 0.04, 0.05)]); gt.gradient = gr; bg.texture = gt; add_child(bg)
    var center = CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(center)
    var pc = PanelContainer.new(); pc.custom_minimum_size = Vector2(900, 0); center.add_child(pc)
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); pc.add_child(box)
    var hero := UI.label("IRON MERIDIAN", UI.GOLD, 60); hero.add_theme_font_override("font", UI.font("cond")); box.add_child(hero)
    var tag := UI.label("A NAVAL CAMPAIGN · 1946", Color(UI.INK, 0.6), 16); tag.add_theme_font_override("font", UI.font("cond_med")); box.add_child(tag)
    box.add_child(UI.label("1946. The Great War of the 1940s ended in an armistice nobody honours. Legacy empires, successor states, corporations and pirates contest the world's oceans, and sea control is the only currency that counts. You are a free captain with one tired ship. Trade, salvage, fight and research your way from late-war gunnery towards the missile age, and serve a flag or stay your own master.", UI.DIM, 15, true))
    if Campaign.has_save() and Campaign.save_version() < Campaign.SAVE_VERSION:
        box.add_child(UI.label("The world has been redrawn: your saved campaign was played on the old chart of the real Earth and can't be continued. Start a new campaign below (it replaces the old save).", UI.GOLD, 14, true))
    elif Campaign.has_save():
        box.add_child(UI.button("Continue campaign", func():
            if Campaign.load_game(): get_tree().change_scene_to_file("res://scenes/world_map.tscn"), true))
    box.add_child(UI.label("WHO WERE YOU?", UI.DIM, 12))
    var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8); box.add_child(grid)
    for key in Origins.LIST:
        var info: Dictionary = Origins.INFO[key]
        var b = Button.new(); b.text = info.label + "\n\n" + info.short; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.custom_minimum_size = Vector2(212, 150); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(func(): _origin(pc, box, key)); grid.add_child(b)
    box.add_child(UI.row([UI.button("Quick battle", func(): get_tree().change_scene_to_file("res://scenes/skirmish.tscn")), UI.button("The world", func(): _codex(pc, box)), UI.button("Settings", func(): _settings(pc, box))]))
    # required by the CC BY 4.0 licence of the engine-room recording; the other sounds are CC0 (assets/sfx/CREDITS.md)
    box.add_child(UI.label("Sound: engine room of the icebreaker Kuna, recorded by Work With Sounds / Museum of Municipal Engineering (CC BY 4.0; trimmed, filtered and looped). Other sound effects are CC0, by thimras, qubodup, Joth, rubberduck and rango-mango on OpenGameArt.", UI.DIM, 11, true))

func _codex(pc: PanelContainer, main: Control) -> void:
    main.visible = false
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); pc.add_child(box)
    box.add_child(UI.label("The world of 1946", UI.GOLD, 30))
    box.add_child(Codex.panel(560.0))
    box.add_child(UI.row([UI.button("Back", func(): box.queue_free(); main.visible = true, true)]))

func _settings(pc: PanelContainer, main: Control) -> void:
    main.visible = false
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); pc.add_child(box)
    box.add_child(Settings.panel())
    box.add_child(UI.row([UI.button("Back", func(): box.queue_free(); main.visible = true, true)]))

## An origin's page: the owner's text for it, what you start with, a navy to choose where the origin has one, and Begin.
func _origin(pc: PanelContainer, main: Control, key: String, navy := "concord") -> void:
    main.visible = false
    var info: Dictionary = Origins.INFO[key]; var L: Dictionary = Origins.lore(key)
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 8); pc.add_child(box)
    box.add_child(UI.label(L.get("title", info.label) + ((" · " + L.subtitle) if L.get("subtitle", "") != "" else ""), UI.GOLD, 30))
    box.add_child(UI.label(L.get("story", ""), UI.INK, 15, true))
    box.add_child(UI.label("World reaction: " + L.get("world", ""), UI.DIM, 14, true))
    box.add_child(UI.label("Feel: " + L.get("feel", ""), UI.DIM, 14, true))
    if Codex.backstory(key) != "": box.add_child(UI.label("IN 1946", UI.DIM, 12)); box.add_child(Codex.rich(Codex.backstory(key), UI.GOLD, 14))
    if info.navy:
        var row = []
        for n in Origins.NAVIES: row.append(UI.button(GameData.fac[n].name, func(): box.queue_free(); _origin(pc, main, key, n), n == navy))
        box.add_child(UI.label("YOUR NAVY", UI.DIM, 12)); box.add_child(UI.row(row))
    var st: Dictionary = Origins.build(key, navy)
    var h: Dictionary = GameData.hulls[st.fleet[0][0]]
    box.add_child(UI.label("You start with: " + info.start, UI.INK, 14, true))
    box.add_child(UI.label("%s (%s class, modelled on the %s)%s · %s · from %s" % [h.name, h.dn, h.model, (" and %d more" % (st.fleet.size() - 1)) if st.fleet.size() > 1 else "", Campaign.fmt(st.credits), st.port], UI.DIM, 13, true))
    box.add_child(UI.row([UI.button("Begin", func(): Campaign.new_game(key, navy); get_tree().change_scene_to_file("res://scenes/world_map.tscn"), true), UI.button("Back", func(): box.queue_free(); main.visible = true)]))
