extends Node
## Player settings, kept in user://settings.cfg: sound volumes (master, effects, ambience), the battle minimap size and
## the battle effects style (modern or classic).
## Effects and Ambience are audio buses feeding Master, created here at start-up; Sfx plays through them.

const PATH := "user://settings.cfg"
var master := 0.8
var effects := 1.0
var ambience := 0.8
var music := 0.6                 # the Music bus (three pieces chosen by the owner, 11 Nov 2026)
var minimap := 1                  # 0 small, 1 medium, 2 large
var fx_modern := true             # battle effects: modern (layered explosions, light, spray) or classic
## Shell splashes in the modern effects (the owner's choice of 12 Nov 2026, with a way back): "new" (a column that stands
## by its calibre and casts its shadow, a falling curtain, a lacy slick) or "classic" (the look before it, untouched;
## the commit before the change is tagged splash-classic). SPLASH_DEFAULT is what a fresh install starts with.
const SPLASH_DEFAULT := "new"
var splash := SPLASH_DEFAULT
var sensors := true               # show sensor ranges and the radar sweep (R on the chart and in battle)
const MINIMAP_W := [190.0, 280.0, 400.0]
## Key bindings (12 Nov 2026): each action keeps its first key in the code (the default); `binds` holds the keys the player
## has chosen instead, per screen ("battle", "chart"), as {default keycode: chosen keycode}. `key(ctx, pressed)` turns a
## pressed key back into the default it stands for (KEY_NONE for a default key now given to nothing), `held(ctx, default)`
## asks whether an action's key is down. Arrow keys, Esc, Home, + and - always work as before.
const ACTIONS := {
	"battle": [[KEY_W, "Ahead faster"], [KEY_S, "Slower / astern"], [KEY_A, "Rudder to port"], [KEY_D, "Rudder to starboard"],
		[KEY_T, "Fire torpedoes"], [KEY_Q, "Fire missiles"], [KEY_F, "Fly off aircraft or floatplane"], [KEY_C, "Dive / surface (a boat)"], [KEY_V, "Shell: cycle AP, HE, incendiary"], [KEY_X, "Main guns: autofire on / off"], [KEY_Z, "Drop depth charges"],
		[KEY_1, "Order: engage"], [KEY_2, "Order: form on the flagship"], [KEY_3, "Order: withdraw"], [KEY_4, "Order: line ahead"], [KEY_5, "Hold fire / open fire"], [KEY_6, "Order: line abreast"], [KEY_7, "Order: screen"], [KEY_8, "Squadron: make smoke"], [KEY_9, "Torpedo attack"], [KEY_0, "Back under squadron orders"],
		[KEY_F1, "Pick out the light ships"], [KEY_F2, "Pick out the heavy ships"], [KEY_F3, "Orders to the whole squadron"],
		[KEY_G, "Star shell"], [KEY_B, "Damage control priority"], [KEY_N, "Flood a burning magazine"], [KEY_J, "Counter-flood"], [KEY_K, "Flagship: make smoke"],
		[KEY_Y, "Radar on / off"], [KEY_U, "Sonar on / off"], [KEY_R, "Sensor ranges shown / hidden"], [KEY_H, "Hide the interface"], [KEY_P, "Pause"], [KEY_M, "Sound on / off"], [KEY_TAB, "Next ship"], [KEY_SPACE, "Camera back on the flagship"]],
	"chart": [[KEY_W, "Pan north"], [KEY_S, "Pan south"], [KEY_A, "Pan west"], [KEY_D, "Pan east"], [KEY_SPACE, "Pause the clock"], [KEY_Q, "Engines slower"], [KEY_E, "Engines faster"],
		[KEY_1, "Clock 1×"], [KEY_2, "Clock 2×"], [KEY_3, "Clock 4×"], [KEY_4, "Clock 8×"], [KEY_C, "Camera back on your squadron"], [KEY_R, "Sensor ranges shown / hidden"], [KEY_H, "Hide the interface"]],
}
var binds := {"battle": {}, "chart": {}}
func bound(ctx: String, default_key: int) -> int: return int(binds.get(ctx, {}).get(default_key, default_key))
func key(ctx: String, pressed: int) -> int:
	var b: Dictionary = binds.get(ctx, {})
	if b.is_empty(): return pressed
	for dk in b: if int(b[dk]) == pressed: return int(dk)
	if b.has(pressed): return KEY_NONE   # its own action now has another key, and nothing else was given this one
	return pressed
func held(ctx: String, default_key: int) -> bool: return Input.is_key_pressed(bound(ctx, default_key))
## Give an action a new key. An action of the same screen that had that key takes this one's old key (a swap).
func rebind(ctx: String, default_key: int, new_key: int) -> void:
	var old := bound(ctx, default_key)
	for a in ACTIONS[ctx]:
		var dk: int = a[0]
		if dk != default_key and bound(ctx, dk) == new_key: _set_bind(ctx, dk, old)
	_set_bind(ctx, default_key, new_key); save()
func _set_bind(ctx: String, dk: int, k: int) -> void:
	if k == dk: binds[ctx].erase(dk)
	else: binds[ctx][dk] = k
func reset_keys() -> void: binds = {"battle": {}, "chart": {}}; save()
## Everything plays through this fixed output level: the owner found the game far too loud, so 100% on the sliders
## is now what 10% used to be. Settings saved before the change are carried over at the same loudness.
## The game's output level. The owner chose 20 dB above the old level (11 Nov 2026: a recorded gun duel measured -39 LUFS,
## peaks near -25 dB; he picked the version raised 20 dB under a limiter, about -19 LUFS). The old level was a master
## gain of 0.165 (-15.6 dB); the new one is unity here plus Sfx.PRE_GAIN_DB (+4.4 dB) ahead of the limiter, which
## holds the peaks. Sfx.BED keeps engines and sea down.
const OUTPUT := 1.0

func _ready() -> void:
	UI.setup(get_tree().root)   # Barlow and the shared theme for every screen
	for b in ["Effects", "Ambience", "Music"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus(); var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b); AudioServer.set_bus_send(i, "Master")
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		master = cf.get_value("sound", "master", master); effects = cf.get_value("sound", "effects", effects); music = cf.get_value("sound", "music", music)
		ambience = cf.get_value("sound", "ambience", ambience); minimap = cf.get_value("battle", "minimap", minimap)
		fx_modern = cf.get_value("battle", "fx_modern", fx_modern); splash = String(cf.get_value("battle", "splash", splash)); sensors = cf.get_value("battle", "sensors", sensors)
		for ctx in ["battle", "chart"]:
			var b = cf.get_value("keys", ctx, {})
			if b is Dictionary: for dk in b: binds[ctx][int(dk)] = int(b[dk])
		if int(cf.get_value("sound", "scale", 1)) < 2:   # saved on the old, ten-times-louder scale: keep the same loudness
			effects = minf(1.0, effects * 10.0); ambience = minf(1.0, ambience * 10.0)
			save()
	apply()

func apply() -> void:
	for pair in [["Master", master * OUTPUT], ["Effects", effects], ["Ambience", ambience], ["Music", music]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0: AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(pair[1]), 0.0001))); AudioServer.set_bus_mute(i, float(pair[1]) <= 0.001)

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("sound", "scale", 2); cf.set_value("sound", "master", master); cf.set_value("sound", "effects", effects); cf.set_value("sound", "ambience", ambience); cf.set_value("sound", "music", music); cf.set_value("battle", "minimap", minimap); cf.set_value("battle", "fx_modern", fx_modern); cf.set_value("battle", "splash", splash)
	cf.set_value("battle", "sensors", sensors)
	for ctx in binds: cf.set_value("keys", ctx, binds[ctx])
	cf.save(PATH)

func minimap_width() -> float: return MINIMAP_W[clampi(minimap, 0, 2)]

## The settings controls, for the title screen and the pause menu. Changes apply at once and are saved.
func panel() -> Control:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8)
	box.add_child(UI.label("Settings", UI.GOLD, 24))
	for row in [["Master volume", "master"], ["Effects (guns, hits, engines)", "effects"], ["Ambience (sea, gulls, weather)", "ambience"], ["Music", "music"]]:
		var key: String = row[1]
		var l := UI.label(row[0], UI.INK, 14); l.custom_minimum_size.x = 220
		var sl := HSlider.new(); sl.min_value = 0; sl.max_value = 1; sl.step = 0.05; sl.value = get(key); sl.custom_minimum_size = Vector2(200, 24)
		var pct := UI.label("%d%%" % int(get(key) * 100), UI.DIM, 13); pct.custom_minimum_size.x = 48
		sl.value_changed.connect(func(v): set(key, v); pct.text = "%d%%" % int(v * 100); apply(); save())
		box.add_child(UI.row([l, sl, pct]))
	var ml := UI.label("Battle minimap", UI.INK, 14); ml.custom_minimum_size.x = 220
	var ob := OptionButton.new(); for n in ["Small", "Medium", "Large"]: ob.add_item(n)
	ob.selected = minimap; ob.item_selected.connect(func(i): minimap = i; save())
	box.add_child(UI.row([ml, ob]))
	var fl := UI.label("Battle effects", UI.INK, 14); fl.custom_minimum_size.x = 220
	var fo := OptionButton.new(); for n in ["Modern", "Classic"]: fo.add_item(n)
	fo.selected = 0 if fx_modern else 1; fo.item_selected.connect(func(i): fx_modern = i == 0; save())
	box.add_child(UI.row([fl, fo, UI.label("Classic is the earlier, simpler look.", UI.DIM, 12)]))
	var spl := UI.label("Shell splashes", UI.INK, 14); spl.custom_minimum_size.x = 220
	var spo := OptionButton.new(); for n in ["New", "Classic"]: spo.add_item(n)
	spo.selected = 0 if splash == "new" else 1; spo.item_selected.connect(func(i): splash = "new" if i == 0 else "classic"; save())
	box.add_child(UI.row([spl, spo, UI.label("New: tall columns with shadows, a falling curtain, a lacy slick. Classic: the look before.", UI.DIM, 12)]))
	var sl2 := UI.label("Sensor ranges", UI.INK, 14); sl2.custom_minimum_size.x = 220
	var so := OptionButton.new(); for n in ["Shown", "Hidden"]: so.add_item(n)
	so.selected = 0 if sensors else 1; so.item_selected.connect(func(i): sensors = i == 0; save())
	box.add_child(UI.row([sl2, so, UI.label("Lookout, radar and sonar reach and the radar sweep (R).", UI.DIM, 12)]))
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(640, 260); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var kp := keys_panel(); kp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(kp); box.add_child(sc)   # (a long list: it scrolls in its own box)
	return box

## Key bindings: every action of the battle and the chart with its key; click one, then press the key you want (Esc
## leaves it as it was). A key already in use on that screen swaps over.
func keys_panel() -> Control:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4)
	box.add_child(UI.label("KEYS", UI.DIM, 12))
	box.add_child(UI.label("Click a key, then press the one you want. A key already used on that screen swaps with it. The arrow keys, Esc, Home, + and - always work.", UI.DIM, 12, true))
	for ctx in ["battle", "chart"]:
		box.add_child(UI.label("In battle" if ctx == "battle" else "On the chart", UI.GOLD, 15))
		var grid := GridContainer.new(); grid.columns = 4; grid.add_theme_constant_override("h_separation", 10); box.add_child(grid)
		for a in ACTIONS[ctx]:
			var dk: int = a[0]
			var l := UI.label(a[1], UI.INK, 13); l.custom_minimum_size.x = 200
			var b := UI.button(OS.get_keycode_string(bound(ctx, dk)), func(): pass)
			b.custom_minimum_size.x = 90
			b.pressed.connect(func(): b.text = "press a key"; b.set_meta("wait", true))
			b.gui_input.connect(func(e):
				if not b.get_meta("wait", false) or not (e is InputEventKey) or not e.pressed: return
				b.accept_event(); b.set_meta("wait", false)
				if e.keycode != KEY_ESCAPE: rebind(ctx, dk, e.keycode)
				for g in grid.get_children(): if g is Button and g.has_meta("dk"): g.text = OS.get_keycode_string(bound(ctx, int(g.get_meta("dk")))))
			b.set_meta("dk", dk)
			grid.add_child(l); grid.add_child(b)
	box.add_child(UI.button("Reset all keys", func():
		reset_keys()
		for g in box.get_children(): if g is GridContainer: for c in g.get_children(): if c is Button: c.text = OS.get_keycode_string(int(c.get_meta("dk")))))
	return box
