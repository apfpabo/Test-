extends Node
## The title as a picture with a transparent background, three times the size it is on the menu:
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_logo.tscn -- <dir>
## Writes logo.png (title and rivet rule) and logo_tagline.png (with "A NAVAL CAMPAIGN · 1946").
const K := 3.0
var vps := []
var f := 0
func _make(tagline: bool) -> SubViewport:
	var mm = load("res://scripts/main_menu.gd").new()
	var holder: Control = mm._iron_title(); var sz: Vector2 = holder.custom_minimum_size + Vector2(8, 10)
	var vp := SubViewport.new(); vp.transparent_bg = true; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var root := Control.new(); root.scale = Vector2(K, K); vp.add_child(root); root.add_child(holder); holder.position = Vector2(12, 8)
	if tagline:
		var tag := Label.new(); tag.text = "A NAVAL CAMPAIGN · 1946"; tag.add_theme_font_override("font", UI.font("cond_med")); tag.add_theme_font_size_override("font_size", 18)
		tag.add_theme_color_override("font_color", Color(UI.INK, 0.9)); tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.position = Vector2(12, sz.y + 14); tag.size = Vector2(sz.x, 26); root.add_child(tag); sz.y += 46
	vp.size = Vector2i(int((sz.x + 24) * K), int((sz.y + 16) * K)); add_child(vp); mm.free()
	return vp
func _ready() -> void: vps = [_make(false), _make(true)]
func _process(_d: float) -> void:
	f += 1
	if f == 6:
		var out: String = OS.get_cmdline_user_args()[0]
		vps[0].get_texture().get_image().save_png(out + "/logo.png"); vps[1].get_texture().get_image().save_png(out + "/logo_tagline.png")
	if f == 8: get_tree().quit()
