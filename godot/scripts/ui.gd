class_name UI
extends RefCounted
## The shared look: dark, flat naval-command panels with crisp hairline borders and a gold accent, Barlow for text
## and Barlow Condensed for headings (both OFL, assets/fonts). Modern strategy and naval games were the reference
## (the owner asked for a more modern interface): few boxes, clear hierarchy, uppercase condensed headers, underlined
## tabs, flat buttons that light up on hover. UI.setup() (called by the Settings autoload at start) puts Barlow
## behind every draw_string in the game and the theme on the root window, so every screen shares it.

const GOLD := Color(0.89, 0.7, 0.24)
const INK := Color(0.9, 0.92, 0.9)
const DIM := Color(0.6, 0.66, 0.67)
const RED := Color(0.88, 0.4, 0.31)
const GREEN := Color(0.5, 0.78, 0.58)
const PANEL := Color(0.043, 0.071, 0.086)
const PANEL2 := Color(0.078, 0.114, 0.133)
const LINE := Color(0.165, 0.235, 0.267)
const HOVER := Color(0.11, 0.16, 0.185)

static var _fonts := {}
static func font(k: String) -> Font:
	if _fonts.is_empty(): _load_fonts()
	return _fonts.get(k, ThemeDB.fallback_font)

static func _load_fonts() -> void:
	var base: Font = ThemeDB.fallback_font   # Godot's own font stays behind Barlow for symbols it lacks (★ ◎ ⚑ ■)
	for k in [["regular", "Barlow-Regular"], ["medium", "Barlow-Medium"], ["semi", "Barlow-SemiBold"], ["cond", "BarlowCondensed-SemiBold"], ["cond_med", "BarlowCondensed-Medium"]]:
		var path := "res://assets/fonts/%s.ttf" % k[1]
		if not ResourceLoader.exists(path): continue
		var f: FontFile = load(path)
		var v := FontVariation.new(); v.base_font = f; v.fallbacks = [base]
		if k[0].begins_with("cond"): v.spacing_glyph = 1   # a little air between condensed capitals
		_fonts[k[0]] = v

## At start: Barlow for every label, button and draw_string; the theme on the root window (popups inherit it).
static func setup(root: Window) -> void:
	if font("regular") != ThemeDB.fallback_font: ThemeDB.fallback_font = font("regular")
	root.theme = theme()

static func _flat(bg: Color, border: Color, bw := 1, radius := 2, mx := 12, my := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(bw); s.set_corner_radius_all(radius)
	s.content_margin_left = mx; s.content_margin_right = mx; s.content_margin_top = my; s.content_margin_bottom = my
	s.anti_aliasing = true
	return s

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("regular"); t.default_font_size = 15
	# panels: near-black, a hairline border and a gold rule along the top
	var card := _flat(Color(PANEL, 0.97), LINE, 1, 3, 26, 22); card.border_width_top = 2; card.border_color = LINE
	card.shadow_color = Color(0, 0, 0, 0.55); card.shadow_size = 28
	var card_top := card.duplicate(); card_top.border_color = LINE
	t.set_stylebox("panel", "PanelContainer", card)
	# buttons: flat, light up on hover; the pressed state is the accent
	t.set_stylebox("normal", "Button", _flat(PANEL2, LINE))
	t.set_stylebox("hover", "Button", _flat(HOVER, Color(GOLD, 0.75)))
	t.set_stylebox("pressed", "Button", _flat(GOLD.darkened(0.35), GOLD))
	t.set_stylebox("disabled", "Button", _flat(Color(PANEL2, 0.45), Color(LINE, 0.5)))
	t.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), Color(GOLD, 0.6), 1))
	t.set_font("font", "Button", font("medium"))
	t.set_color("font_color", "Button", INK); t.set_color("font_hover_color", "Button", Color.WHITE); t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.5))
	t.set_color("font_color", "Label", INK)
	for k in ["normal", "hover", "pressed", "disabled", "focus"]: t.set_stylebox(k, "OptionButton", t.get_stylebox(k, "Button"))
	t.set_font("font", "OptionButton", font("medium"))
	t.set_stylebox("panel", "TabContainer", _flat(PANEL, LINE))
	t.set_stylebox("panel", "ItemList", _flat(PANEL2, LINE))
	# popup menus and tooltips
	var pop := _flat(Color(PANEL, 0.98), LINE, 1, 3, 6, 6); pop.shadow_color = Color(0, 0, 0, 0.5); pop.shadow_size = 12
	t.set_stylebox("panel", "PopupMenu", pop); t.set_stylebox("hover", "PopupMenu", _flat(HOVER, Color(GOLD, 0.6), 1, 2, 8, 4))
	t.set_color("font_color", "PopupMenu", INK); t.set_color("font_hover_color", "PopupMenu", Color.WHITE); t.set_color("font_disabled_color", "PopupMenu", Color(DIM, 0.5))
	t.set_color("font_separator_color", "PopupMenu", GOLD); t.set_font("font_separator", "PopupMenu", font("cond"))
	t.set_stylebox("separator", "PopupMenu", StyleBoxEmpty.new())
	t.set_constant("v_separation", "PopupMenu", 8)
	var tip := _flat(Color(0.03, 0.05, 0.06, 0.97), Color(GOLD, 0.45), 1, 3, 12, 9)
	t.set_stylebox("panel", "TooltipPanel", tip); t.set_color("font_color", "TooltipLabel", INK); t.set_font_size("font_size", "TooltipLabel", 14)
	# check boxes: a hairline box, filled gold with a dark tick when ticked
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed"]: t.set_stylebox(k, "CheckBox", _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 2, 4, 4))
	t.set_icon("unchecked", "CheckBox", _check_icon(false)); t.set_icon("checked", "CheckBox", _check_icon(true))
	t.set_color("font_color", "CheckBox", INK); t.set_color("font_hover_color", "CheckBox", Color.WHITE); t.set_color("font_pressed_color", "CheckBox", INK)
	# separators and slim scrollbars
	var sep := StyleBoxLine.new(); sep.color = LINE; sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep); t.set_constant("separation", "HSeparator", 14)
	for sb in ["VScrollBar", "HScrollBar"]:
		var track := _flat(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 3, 3, 3)
		var grab := _flat(Color(LINE, 0.9), Color(0, 0, 0, 0), 0, 3, 3, 3)
		t.set_stylebox("scroll", sb, track); t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, _flat(Color(GOLD, 0.6), Color(0, 0, 0, 0), 0, 3, 3, 3)); t.set_stylebox("grabber_pressed", sb, _flat(GOLD, Color(0, 0, 0, 0), 0, 3, 3, 3))
	return t

static func _check_icon(on: bool) -> Texture2D:
	var n := 18; var img := Image.create(n, n, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var edge := x == 1 or y == 1 or x == n - 2 or y == n - 2
			if x < 1 or y < 1 or x > n - 2 or y > n - 2: continue
			if on: img.set_pixel(x, y, GOLD.darkened(0.1) if edge else GOLD)
			elif edge: img.set_pixel(x, y, Color(0.45, 0.55, 0.58))
			else: img.set_pixel(x, y, Color(0.05, 0.08, 0.1))
	if on:   # the tick
		for p in [[4, 9], [5, 10], [6, 11], [7, 12], [8, 11], [9, 10], [10, 9], [11, 8], [12, 7], [13, 6]]:
			for d in [0, 1]: img.set_pixel(p[0], p[1] + d, Color(0.08, 0.07, 0.03))
	return ImageTexture.create_from_image(img)

## Text. A short all-capitals label at a small size is a section header: condensed, spaced, with a rule under it.
static func label(text: String, col := INK, size := 15, wrap := false) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_color_override("font_color", col); l.add_theme_font_size_override("font_size", size)
	if size <= 12 and text.length() > 2 and text == text.to_upper() and text.to_lower() != text:
		l.add_theme_font_override("font", font("cond")); l.add_theme_font_size_override("font_size", size + 2)
		l.add_theme_color_override("font_color", Color(GOLD, 0.85) if col == DIM else col)
		var rule := StyleBoxFlat.new(); rule.bg_color = Color(0, 0, 0, 0); rule.border_color = Color(LINE, 0.9); rule.border_width_bottom = 1
		rule.content_margin_bottom = 3; rule.content_margin_top = 6; l.add_theme_stylebox_override("normal", rule)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 200
	return l

## A panel's title: condensed capitals in gold over a hairline.
static func title(text: String) -> Label:
	var l := label(text.to_upper(), GOLD, 30)
	l.add_theme_font_override("font", font("cond"))
	var rule := StyleBoxFlat.new(); rule.bg_color = Color(0, 0, 0, 0); rule.border_color = Color(GOLD, 0.35); rule.border_width_bottom = 1
	rule.content_margin_bottom = 6; l.add_theme_stylebox_override("normal", rule)
	return l

static func button(text: String, cb: Callable, primary := false, disabled := false) -> Button:
	var b := Button.new(); b.text = text; b.disabled = disabled; b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		var s := _flat(GOLD, GOLD.lightened(0.1), 1, 2, 16, 7)
		b.add_theme_stylebox_override("normal", s); var h := s.duplicate(); h.bg_color = GOLD.lightened(0.15); b.add_theme_stylebox_override("hover", h)
		var p := s.duplicate(); p.bg_color = GOLD.darkened(0.15); b.add_theme_stylebox_override("pressed", p)
		b.add_theme_color_override("font_color", Color(0.08, 0.07, 0.03)); b.add_theme_color_override("font_hover_color", Color(0.08, 0.07, 0.03)); b.add_theme_color_override("font_pressed_color", Color(0.08, 0.07, 0.03))
		b.add_theme_font_override("font", font("semi"))
	return b

## A tab: no box, condensed capitals, underlined in gold when it is the open one.
static func tab(text: String, cb: Callable, active: bool) -> Button:
	var b := Button.new(); b.text = text.to_upper(); b.pressed.connect(cb); b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", font("cond")); b.add_theme_font_size_override("font_size", 16)
	var s := StyleBoxFlat.new(); s.bg_color = Color(0, 0, 0, 0); s.content_margin_left = 10; s.content_margin_right = 10; s.content_margin_top = 6; s.content_margin_bottom = 7
	s.border_color = GOLD if active else Color(0, 0, 0, 0); s.border_width_bottom = 2
	var h := s.duplicate(); h.border_color = Color(GOLD, 1.0 if active else 0.45); h.bg_color = Color(1, 1, 1, 0.03)
	for k in ["normal", "focus", "disabled"]: b.add_theme_stylebox_override(k, s)
	b.add_theme_stylebox_override("hover", h); b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", GOLD if active else DIM); b.add_theme_color_override("font_hover_color", GOLD if active else INK)
	return b

## A row of tabs over a hairline.
static func tabs(items: Array, cur: String, cb: Callable) -> Control:
	var wrap := PanelContainer.new()
	var line := StyleBoxFlat.new(); line.bg_color = Color(0, 0, 0, 0); line.border_color = LINE; line.border_width_bottom = 1
	wrap.add_theme_stylebox_override("panel", line)
	var r := HBoxContainer.new(); r.add_theme_constant_override("separation", 2); wrap.add_child(r)
	for it in items:
		var key: String = it[0]
		r.add_child(tab(it[1], func(): cb.call(key), key == cur))
	return wrap

static func row(children: Array) -> HBoxContainer:
	var r := HBoxContainer.new(); r.add_theme_constant_override("separation", 8)
	for c in children: r.add_child(c)
	return r

static func bar(f: float, w := 80.0, col := GREEN) -> Control:
	var c := Panel.new(); c.custom_minimum_size = Vector2(w, 6)
	c.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.06, 0.07), Color(LINE, 0.6), 1, 2, 0, 0))
	var i := Panel.new(); i.size = Vector2(maxf(2.0, (w - 2) * clampf(f, 0, 1)), 4); i.position = Vector2(1, 1)
	i.add_theme_stylebox_override("panel", _flat(col if f >= 0.4 else RED, Color(0, 0, 0, 0), 0, 2, 0, 0)); c.add_child(i)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
