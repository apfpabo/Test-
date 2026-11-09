extends Node
## Player settings, kept in user://settings.cfg: sound volumes (master, effects, ambience), the battle minimap size and
## the battle effects style (modern or classic).
## Effects and Ambience are audio buses feeding Master, created here at start-up; Sfx plays through them.

const PATH := "user://settings.cfg"
var master := 0.8
var effects := 1.0
var ambience := 0.8
var minimap := 1                  # 0 small, 1 medium, 2 large
var fx_modern := true             # battle effects: modern (layered explosions, light, spray) or classic
const MINIMAP_W := [190.0, 280.0, 400.0]

func _ready() -> void:
	UI.setup(get_tree().root)   # Barlow and the shared theme for every screen
	for b in ["Effects", "Ambience"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus(); var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b); AudioServer.set_bus_send(i, "Master")
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		master = cf.get_value("sound", "master", master); effects = cf.get_value("sound", "effects", effects)
		ambience = cf.get_value("sound", "ambience", ambience); minimap = cf.get_value("battle", "minimap", minimap)
		fx_modern = cf.get_value("battle", "fx_modern", fx_modern)
	apply()

func apply() -> void:
	for pair in [["Master", master], ["Effects", effects], ["Ambience", ambience]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0: AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(pair[1]), 0.0001))); AudioServer.set_bus_mute(i, float(pair[1]) <= 0.001)

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("sound", "master", master); cf.set_value("sound", "effects", effects); cf.set_value("sound", "ambience", ambience); cf.set_value("battle", "minimap", minimap); cf.set_value("battle", "fx_modern", fx_modern)
	cf.save(PATH)

func minimap_width() -> float: return MINIMAP_W[clampi(minimap, 0, 2)]

## The settings controls, for the title screen and the pause menu. Changes apply at once and are saved.
func panel() -> Control:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8)
	box.add_child(UI.label("Settings", UI.GOLD, 24))
	for row in [["Master volume", "master"], ["Effects (guns, hits, engines)", "effects"], ["Ambience (sea, gulls)", "ambience"]]:
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
	return box
