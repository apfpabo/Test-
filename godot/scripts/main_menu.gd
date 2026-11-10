extends Control
## Title screen: continue the campaign, start a new one, or fight a quick battle.

var pc: PanelContainer
var home: Control
var test_mode := false
var _busy := false

## A page change: the panel fades out, the page is changed, and the panel fades back in as it settles, so pages
## don't snap from one to the next.
func go(change: Callable) -> void:
    if _busy: return
    _busy = true
    var tw := create_tween(); tw.tween_property(pc, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_IN)
    tw.tween_callback(func():
        change.call()
        pc.pivot_offset = Vector2(pc.size.x / 2, 0); pc.scale = Vector2(0.985, 0.985)
        var t2 := create_tween().set_parallel(true)
        t2.tween_property(pc, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
        t2.tween_property(pc, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
        t2.chain().tween_callback(func(): _busy = false))

func _back(box: Control, main: Control) -> void: go(func(): box.queue_free(); main.visible = true)

func _ready() -> void:
    theme = UI.theme(); set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # fill the window, whatever its size
    # a dark sea with a little light at its heart
    var bg = TextureRect.new(); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.stretch_mode = TextureRect.STRETCH_SCALE
    var gt := GradientTexture2D.new(); gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.42); gt.fill_to = Vector2(1.15, 1.1)
    var gr := Gradient.new(); gr.colors = PackedColorArray([Color(0.07, 0.17, 0.2), Color(0.02, 0.04, 0.05)]); gt.gradient = gr; bg.texture = gt; add_child(bg)
    # the title stays where it is while the pages below it change: a column from a fixed top margin, centred across
    var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 14); col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(col)
    var top := Control.new(); top.custom_minimum_size.y = maxf(30.0, get_viewport_rect().size.y * 0.07); col.add_child(top)
    col.add_child(_iron_title())
    var tag := UI.label("A NAVAL CAMPAIGN · 1946", Color(UI.INK, 0.65), 18); tag.add_theme_font_override("font", UI.font("cond_med")); tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; col.add_child(tag)
    pc = PanelContainer.new(); pc.custom_minimum_size = Vector2(560, 0); pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; col.add_child(pc)
    _home()

## The home page: a short introduction and the five ways in.
func _home() -> void:
    for c in pc.get_children(): c.queue_free()
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); pc.add_child(box); home = box
    var intro := UI.label("The Meridian War ended in an armistice nobody honours. Legacy empires, successor states, corporations and pirates contest the world's oceans, and sea control is the only currency that counts. You are a free captain with one tired ship.", UI.DIM, 15, true)
    intro.custom_minimum_size.x = 500; box.add_child(intro)
    if Campaign.has_save() and Campaign.save_version() < Campaign.SAVE_VERSION:
        box.add_child(UI.label("The world has been redrawn: your saved campaign was played on the old chart of the real Earth and cannot be continued. A new campaign replaces the old save.", UI.GOLD, 14, true))
    var can_go: bool = Campaign.has_save() and Campaign.save_version() >= Campaign.SAVE_VERSION
    var btns := [
        UI.button("Continue campaign", func():
            if Campaign.load_game(): get_tree().change_scene_to_file("res://scenes/world_map.tscn"), true, not can_go),
        UI.button("New campaign", func(): go(_new_campaign), not can_go),
        UI.button("Quick battle", func(): get_tree().change_scene_to_file("res://scenes/skirmish.tscn")),
        UI.button("The world", func(): go(func(): _codex(pc, home))),
        UI.button("Settings", func(): go(func(): _settings(pc, home)))]
    for b in btns: b.custom_minimum_size = Vector2(0, 42); b.add_theme_font_size_override("font_size", 17); box.add_child(b)
    if not can_go: btns[0].visible = false
    # required by the CC BY 4.0 licence of the engine-room recording; the other sounds are CC0 (assets/sfx/CREDITS.md)
    var cr := UI.label("Sound: engine room of the icebreaker Kuna, recorded by Work With Sounds / Museum of Municipal Engineering (CC BY 4.0; trimmed, filtered and looped). Other sound effects are CC0, by thimras, qubodup, Joth, rubberduck and rango-mango on OpenGameArt.", Color(UI.DIM, 0.7), 11, true)
    cr.custom_minimum_size.x = 500; box.add_child(cr)

## Who were you? The eight origins, and test mode.
func _new_campaign() -> void:
    for c in pc.get_children(): c.queue_free()
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); pc.add_child(box); home = box
    box.add_child(UI.title("Who were you?"))
    var grid = GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8); box.add_child(grid)
    for key in Origins.LIST:
        var info: Dictionary = Origins.INFO[key]
        var b = Button.new(); b.text = info.label + "\n\n" + info.short; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.custom_minimum_size = Vector2(212, 150); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(func(): go(func(): _origin(pc, box, key))); grid.add_child(b)
    var tm := CheckBox.new(); tm.text = "Test mode: every technology researched, every design in every shipyard, unlimited money and research points"; tm.button_pressed = test_mode
    tm.toggled.connect(func(on): test_mode = on); box.add_child(tm)
    box.add_child(UI.row([UI.button("Back", func(): go(_home))]))

## The title in iron: brushed steel capitals with a drop shadow, over a riveted rule.
func _iron_title() -> Control:
    var size := 96; var font: Font = UI.font("cond")
    var holder := Control.new(); var w: float = font.get_string_size("IRON MERIDIAN", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 16
    holder.custom_minimum_size = Vector2(w, size * 1.2 + 26); holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var mk = func(col: Color, off: Vector2) -> Label:
        var l := Label.new(); l.text = "IRON MERIDIAN"; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col); l.position = off + Vector2(8, 0); holder.add_child(l); return l
    mk.call(Color(0, 0, 0, 0.55), Vector2(4, 6))      # the shadow it casts
    mk.call(Color(0.1, 0.1, 0.1, 0.9), Vector2(1, 2))  # the dark edge under the bevel
    var iron: Label = mk.call(Color.WHITE, Vector2.ZERO)
    var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/iron_title.gdshader")
    var asc: float = font.get_ascent(size); mat.set_shader_parameter("top_y", asc - size * 0.72); mat.set_shader_parameter("bottom_y", asc)
    iron.material = mat
    var rule := RivetRule.new(); rule.position = Vector2(8, size * 1.2 + 4); rule.size = Vector2(w - 16, 18); holder.add_child(rule)
    return holder

## A plate of iron with a row of rivets: the rule under the title.
class RivetRule extends Control:
    func _draw() -> void:
        draw_rect(Rect2(0, 6, size.x, 6), Color(0.3, 0.31, 0.31)); draw_rect(Rect2(0, 6, size.x, 2), Color(0.55, 0.56, 0.55)); draw_rect(Rect2(0, 11, size.x, 1), Color(0.1, 0.1, 0.1))
        var n := int(size.x / 38.0)
        for i in n + 1:
            var c := Vector2(i * size.x / n, 9)
            draw_circle(c + Vector2(1, 1.5), 4.0, Color(0, 0, 0, 0.5)); draw_circle(c, 4.0, Color(0.42, 0.43, 0.43)); draw_circle(c - Vector2(1.2, 1.2), 1.6, Color(0.75, 0.76, 0.74))

func _codex(pc: PanelContainer, main: Control) -> void:
    main.visible = false
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); pc.add_child(box)
    box.add_child(UI.label("The world of 1946", UI.GOLD, 30))
    box.add_child(Codex.panel(560.0))
    box.add_child(UI.row([UI.button("Back", func(): _back(box, main), true)]))

func _settings(pc: PanelContainer, main: Control) -> void:
    main.visible = false
    var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); pc.add_child(box)
    box.add_child(Settings.panel())
    box.add_child(UI.row([UI.button("Back", func(): _back(box, main), true)]))

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
    box.add_child(UI.row([UI.button("Begin" + (" (test mode)" if test_mode else ""), func(): Campaign.new_game(key, navy, test_mode); get_tree().change_scene_to_file("res://scenes/world_map.tscn"), true), UI.button("Back", func(): _back(box, main))]))
