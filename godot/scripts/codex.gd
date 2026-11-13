class_name Codex
## The codex: the owner's foundational lore (data/lore.json "world", parsed word for word from
## docs/lore/foundational_lore.md by tools/lore_to_json.py), shown on the title screen and in the Command panel.

const TABS := [["world", "The world"], ["history", "The Meridian War"], ["powers", "The powers"], ["mysteries", "Mysteries"], ["race", "The Quiet Race"], ["horizon", "After 1946"], ["manual", "Manual"]]
## What the owner's expansion (13 Nov 2026) keeps back until the campaign has earned it: a declassified truth is
## shown once you have surveyed its site, or from 1947 on; each period after 1946 once its first year has come. On
## the title screen, with no campaign running, nothing of either is shown.
const TRUTH_SITE := {"lost_squadron": "Lost Squadron", "throat": "Throat"}
static func year_now() -> int:
	return int(Campaign.year()) if not Campaign.G.is_empty() and Campaign.G.has("day") else 0
static func declassified(key: String) -> bool:
	if year_now() == 0: return false
	if year_now() >= 1947: return true
	for q in Campaign.G.get("pois", []):
		if String(q.get("name", "")).contains(String(TRUTH_SITE.get(key, "\u0000"))) and q.get("surveyed", false): return true
	return false
## The Manual (the owner, 13 Nov 2026): how the game's deeper systems work, a short page each (data/manual.json: the
## agent's text, not the owner's lore). `manual_page` is the page shown.
static var _manual: Array = []
static var manual_page := "sight"
static func manual() -> Array:
	if _manual.is_empty():
		var f := FileAccess.open("res://data/manual.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Array: _manual = d
	return _manual
static var _world: Dictionary = {}

static func world() -> Dictionary:
	if _world.is_empty():
		var f := FileAccess.open("res://data/lore.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary: _world = d.get("world", {})
	return _world

## Markdown emphasis and bullets from the owner's text to BBCode.
static func bb(text: String) -> String:
	var t := text.replace("[", "[lb]")
	var re := RegEx.new(); re.compile("\\*\\*(.+?)\\*\\*"); t = re.sub(t, "[b]$1[/b]", true)
	re.compile("\\*(.+?)\\*"); t = re.sub(t, "[i]$1[/i]", true)
	re.compile("(?m)^- "); t = re.sub(t, "•  ", true)
	re.compile("(?m)[ \\t]+$"); t = re.sub(t, "", true)
	return t

static func rich(text: String, col := UI.INK, size := 15) -> RichTextLabel:
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_color_override("default_color", col)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size"]: r.add_theme_font_size_override(k, size)
	r.text = bb(text)
	return r

## An origin's backstory in this world, or "" if the lore has none.
static func backstory(key: String) -> String:
	return world().get("backstories", {}).get(key, {}).get("text", "")

## One faction's profile as short lines (personality, doctrine, goals, attitude to independents).
static func profile(fac: String) -> Dictionary: return world().get("profiles", {}).get(fac, {})

## Fills `box` with one codex tab and a row of tab buttons; `on_tab` is called with the key of the tab chosen.
static func build(box: Container, tab: String, on_tab: Callable) -> void:
	var W := world()
	box.add_child(UI.tabs(TABS, tab, on_tab))
	if tab == "manual":
		var pages: Array = manual(); var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 6); row.add_theme_constant_override("v_separation", 6)
		for pg in pages:
			var id: String = String(pg.id)
			row.add_child(UI.button(String(pg.title), func(): manual_page = id; on_tab.call("manual"), id == manual_page))
		box.add_child(row)
		for pg in pages:
			if String(pg.id) == manual_page: box.add_child(UI.label(String(pg.title), UI.GOLD, 20)); box.add_child(rich(String(pg.text)))
		return
	if W.is_empty(): box.add_child(UI.label("The codex is missing (data/lore.json).", UI.RED)); return
	match tab:
		"world":
			box.add_child(UI.label("THE WORLD IN BRIEF", UI.DIM, 12)); box.add_child(rich(W.brief))
			box.add_child(UI.label("THE UNFINISHED WAR (1939–1945)", UI.DIM, 12)); box.add_child(rich(W.war))
			box.add_child(UI.label("MARCH 1946", UI.DIM, 12)); box.add_child(rich(W.atmosphere))
		"history":
			box.add_child(UI.label(W.history_title, UI.GOLD, 20)); box.add_child(rich(W.history))
		"powers":
			for k in W.powers:
				var p: Dictionary = W.powers[k]; var col := Color(GameData.fac[k].map) if GameData.fac.has(k) else UI.GOLD
				box.add_child(UI.label(p.name, col, 20)); box.add_child(UI.label("Home: " + p.home, UI.DIM, 13))
				if String(p.text) != "": box.add_child(rich(p.text, UI.INK, 14))
				var pr: Dictionary = profile(k)
				for f in pr: box.add_child(rich("**%s:** %s" % [f, pr[f]], UI.DIM, 13))
		"mysteries":
			for m in W.mysteries: box.add_child(UI.label(m.name, UI.GOLD, 17)); box.add_child(rich(m.text, UI.INK, 14))
			var open_now: Array = W.get("declassified", []).filter(func(d): return declassified(String(d.key)))
			if not open_now.is_empty():
				box.add_child(UI.label("DECLASSIFIED", UI.DIM, 12))
				for d in open_now: box.add_child(UI.label(String(d.name), UI.GOLD, 17)); box.add_child(rich(String(d.text), UI.INK, 14))
		"horizon":
			var hz: Dictionary = W.get("horizon", {})
			box.add_child(UI.label("Beyond 1946: The Missile Horizon", UI.GOLD, 20)); box.add_child(rich(String(hz.get("intro", ""))))
			var yn: int = year_now(); var shown := 0
			for y in hz.get("years", []):
				if yn >= int(y.from): box.add_child(UI.label(String(y.title), UI.GOLD, 17)); box.add_child(rich(String(y.text), UI.INK, 14)); shown += 1
			if shown < hz.get("years", []).size(): box.add_child(UI.label("What follows has not happened yet." if yn > 0 else "The years to come are written as a campaign reaches them.", UI.DIM, 13))
		"race":
			box.add_child(rich(W.quiet_race))

## The codex as a scrolling panel of the given height, rebuilt in place when a tab is chosen.
static func panel(height: float, tab := "world") -> ScrollContainer:
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(0, height); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 8); sc.add_child(box)
	var show := func(t, again: Callable):
		for c in box.get_children(): c.queue_free()
		build(box, t, func(k): again.call(k, again)); sc.scroll_vertical = 0
	show.call(tab, show)
	return sc
