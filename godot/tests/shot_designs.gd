extends Node
## A poster of every ship design, grouped by class, all at one scale (so sizes compare truly), each in the paint of
## a power that builds it, with its builder, year, the real ship it is modelled on and its figures.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_designs.tscn -- <out.png>
const PX_PER_M := 4.5
const W := 4000
var vp: SubViewport
var f := 0
func _ready() -> void:
	vp = SubViewport.new(); vp.size = Vector2i(W, 6000); vp.transparent_bg = false; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(vp)
	var root := PanelContainer.new(); root.theme = UI.theme(); root.custom_minimum_size = Vector2(W, 0)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color("#0d1b21"); bg.content_margin_left = 60; bg.content_margin_right = 60; bg.content_margin_top = 50; bg.content_margin_bottom = 60
	root.add_theme_stylebox_override("panel", bg); vp.add_child(root)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 18); root.add_child(col)
	var t := UI.label("IRON MERIDIAN · THE SHIPS", UI.GOLD, 64); t.add_theme_font_override("font", UI.font("cond")); col.add_child(t)
	col.add_child(UI.label("Every design in the game, %d in all, drawn to one scale (%.1f pixels to the metre), grouped by class. Each is shown in the paint of a power whose yards build her, with turrets trained fore and aft." % [GameData.hulls.size(), PX_PER_M], UI.DIM, 22, true))
	var pal_of := func(id: String) -> String:
		for fac in GameData.fac_makers:
			var mk = GameData.fac_makers[fac]
			if mk is Array and mk.has(GameData.hulls[id].yard) and fac != "raiders": return fac
		return "player"
	for k in GameData.hull_order:
		var ids: Array = GameData.hulls.keys().filter(func(id): return GameData.hulls[id].klass == k)
		if ids.is_empty(): continue
		ids.sort_custom(func(a, b): return GameData.hulls[a].year < GameData.hulls[b].year)
		var h := UI.label(String(GameData.classes[k].name).to_upper() + "  ·  %d" % ids.size(), UI.GOLD, 34); h.add_theme_font_override("font", UI.font("cond"))
		var rule := StyleBoxFlat.new(); rule.bg_color = Color(0, 0, 0, 0); rule.border_color = Color(UI.GOLD, 0.35); rule.border_width_bottom = 2; rule.content_margin_top = 18; rule.content_margin_bottom = 6
		h.add_theme_stylebox_override("normal", rule); col.add_child(h)
		var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 50); flow.add_theme_constant_override("v_separation", 28); col.add_child(flow)
		for id in ids:
			var d: Dictionary = GameData.hulls[id]; var info: Dictionary = GameData.sprites.ships[id]
			var card := VBoxContainer.new(); card.add_theme_constant_override("separation", 4)
			var thumb = preload("res://scripts/world_map.gd").ShipThumb.new()
			thumb.id = id; thumb.pal = pal_of.call(id)
			thumb.fit = null
			var w: float = float(info.w) * PX_PER_M
			thumb.custom_minimum_size = Vector2(w, float(info.h) * PX_PER_M + 4); thumb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			card.add_child(thumb)
			var nm := UI.label("%s class · %s" % [d.dn, GameData.makers[d.yard].name], UI.INK, 22); nm.add_theme_font_override("font", UI.font("semi")); card.add_child(nm)
			var fig := UI.label("%d · modelled on the %s · %s t · %d m · %s kn · belt %d mm%s" % [int(d.year), d.model, Campaign.fmt(d.t), int(d.L), str(d.kn), int(d.armor), (" · era %d" % int(d.era)) if int(d.era) > 1 else ""], UI.DIM, 17)
			card.add_child(fig)
			card.custom_minimum_size.x = maxf(w, 420.0)
			flow.add_child(card)
func _process(_d: float) -> void:
	f += 1
	if f == 4:   # fit the image to the poster's height
		var root: Control = vp.get_child(0); vp.size = Vector2i(W, int(root.get_combined_minimum_size().y) + 10)
	if f == 12:
		var img := vp.get_texture().get_image(); img.save_png(OS.get_cmdline_user_args()[0]); print("saved ", img.get_size()); get_tree().quit()
