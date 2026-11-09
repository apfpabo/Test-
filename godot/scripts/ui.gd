class_name UI
extends RefCounted
## Shared look for panels and buttons: grey-steel signal panels with a gold edge, as in the browser build.

const GOLD := Color(0.89, 0.7, 0.24)
const INK := Color(0.89, 0.91, 0.89)
const DIM := Color(0.62, 0.67, 0.67)
const RED := Color(0.85, 0.38, 0.29)
const GREEN := Color(0.5, 0.75, 0.56)
const PANEL := Color(0.086, 0.149, 0.172)
const PANEL2 := Color(0.118, 0.2, 0.227)
const LINE := Color(0.212, 0.314, 0.353)

static func theme() -> Theme:
    var t := Theme.new()
    t.default_font_size = 15
    var flat := func(bg: Color, border: Color, bw := 1, top := 0) -> StyleBoxFlat:
        var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border
        s.border_width_left = bw; s.border_width_right = bw; s.border_width_bottom = bw; s.border_width_top = maxi(bw, top)
        s.corner_radius_top_left = 3; s.corner_radius_top_right = 3; s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
        s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 6; s.content_margin_bottom = 6
        return s
    var card: StyleBoxFlat = flat.call(PANEL, LINE, 1, 3); card.border_color = LINE
    card.content_margin_left = 22; card.content_margin_right = 22; card.content_margin_top = 18; card.content_margin_bottom = 18
    card.shadow_color = Color(0, 0, 0, 0.5); card.shadow_size = 18
    t.set_stylebox("panel", "PanelContainer", card)
    t.set_stylebox("normal", "Button", flat.call(PANEL2, LINE))
    t.set_stylebox("hover", "Button", flat.call(PANEL2, GOLD))
    t.set_stylebox("pressed", "Button", flat.call(GOLD.darkened(0.2), GOLD))
    t.set_stylebox("disabled", "Button", flat.call(PANEL2.darkened(0.3), LINE.darkened(0.3)))
    t.set_stylebox("focus", "Button", flat.call(Color(0, 0, 0, 0), GOLD, 2))
    t.set_color("font_color", "Button", INK); t.set_color("font_hover_color", "Button", Color.WHITE); t.set_color("font_disabled_color", "Button", DIM.darkened(0.3))
    t.set_color("font_color", "Label", INK)
    t.set_stylebox("normal", "OptionButton", flat.call(PANEL2, LINE)); t.set_stylebox("hover", "OptionButton", flat.call(PANEL2, GOLD))
    t.set_stylebox("panel", "TabContainer", flat.call(PANEL, LINE))
    t.set_stylebox("panel", "ItemList", flat.call(PANEL2, LINE))
    return t

static func label(text: String, col := INK, size := 15, wrap := false) -> Label:
    var l := Label.new(); l.text = text; l.add_theme_color_override("font_color", col); l.add_theme_font_size_override("font_size", size)
    if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 200
    return l

static func title(text: String) -> Label:
    return label(text, GOLD, 30)

static func button(text: String, cb: Callable, primary := false, disabled := false) -> Button:
    var b := Button.new(); b.text = text; b.disabled = disabled; b.pressed.connect(cb)
    if primary:
        var s := StyleBoxFlat.new(); s.bg_color = GOLD; s.corner_radius_top_left = 3; s.corner_radius_top_right = 3; s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
        s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 6; s.content_margin_bottom = 6
        b.add_theme_stylebox_override("normal", s); var h := s.duplicate(); h.bg_color = GOLD.lightened(0.15); b.add_theme_stylebox_override("hover", h)
        b.add_theme_color_override("font_color", Color(0.1, 0.08, 0.02)); b.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.02))
    return b

static func row(children: Array) -> HBoxContainer:
    var r := HBoxContainer.new(); r.add_theme_constant_override("separation", 8)
    for c in children: r.add_child(c)
    return r

static func bar(f: float, w := 80.0, col := GREEN) -> Control:
    var c := ColorRect.new(); c.color = Color(0.04, 0.09, 0.1); c.custom_minimum_size = Vector2(w, 7)
    var i := ColorRect.new(); i.color = col if f >= 0.4 else RED; i.size = Vector2(w * clampf(f, 0, 1), 7); c.add_child(i)
    return c
