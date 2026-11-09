extends Node
## Game data exported from the design registers (tools/bake_assets.js) and the baked ship and mount images.

var hulls: Dictionary = {}      # design id -> design (dimensions, speed, armour, slots, plan)
var weapons: Dictionary = {}
var pal: Dictionary = {}        # paint schemes by flag
var classes: Dictionary = {}
var makers: Dictionary = {}
var fac_makers: Dictionary = {}
var fac: Dictionary = {}
var names: Dictionary = {}
var hull_order: Array = []
var sprites: Dictionary = {}    # baked image sizes and scales
var _tex: Dictionary = {}

func _ready() -> void:
	var d: Dictionary = _json("res://data/game_data.json")
	hulls = d.HULLS; weapons = d.WEAPONS; pal = d.PAL; classes = d.CLASSES; makers = d.MAKERS
	fac_makers = d.FAC_MAKERS; fac = d.FAC; names = d.NAMES; hull_order = d.HULL_ORDER
	sprites = _json("res://data/sprites.json")

func _json(path: String) -> Dictionary:
	var f = FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

## Textures are loaded once, with mipmaps so ships stay sharp at every zoom.
func tex(path: String) -> Texture2D:
	if _tex.has(path): return _tex[path]
	var t: Texture2D = load(path)
	if t == null: return null
	var img = t.get_image()
	if img.is_compressed(): img.decompress()
	img.fix_alpha_edges()   # transparent pixels take their neighbours' colour, so smaller mip levels don't bleed black or white
	img.generate_mipmaps()
	var it = ImageTexture.create_from_image(img)
	_tex[path] = it
	return it

## The paint scheme a flag wears: its own, or the one it borrows (a client state in its patron's colours).
func paint(p: String) -> String: return fac.get(p, {}).get("paint", p)

## Paint scheme actually baked for a design: its flag's if available, otherwise the raiders' scheme.
func ship_pal(id: String, p: String) -> String:
	var q := paint(p)
	return q if sprites.ships[id].pals.has(q) else "raiders"

func ship_tex(id: String, p: String, layer: String) -> Texture2D:
	if layer.ends_with("shadow"): return tex("res://assets/ships/%s/%s.webp" % [id, layer])
	return tex("res://assets/ships/%s/%s_%s.webp" % [id, ship_pal(id, p), layer])

## Turret style follows the ship's builder (American, British, German, Soviet, Japanese, Italian).
func style_of(id: String) -> String:
	return sprites.get("yard_style", {}).get(hulls[id].yard, "us")

## A mount's housing (or its barrels) in a national style: neutral grey with height packed in, for mount_light.gdshader.
func mount_img(wid: String, style: String, barrels := false) -> Texture2D:
	var info: Dictionary = sprites.mounts[wid]
	var key: String = style if info.get("styled", false) else "all"
	return tex("res://assets/mounts/%s/%s%s.png" % [wid, key, "_barrels" if barrels else ""])

## A mount's soft contact shadow.
func mount_ao(wid: String) -> Texture2D:
	return tex("res://assets/mounts/%s/ao.webp" % wid)

## Height map of a design's superstructure (grey = metres / h_max).
func ship_h(id: String) -> Texture2D:
	return tex("res://assets/ships/%s/top_h.png" % id)

## Turret height above its own base in metres, by gun size (matches the bake).
func turret_h(w: Dictionary) -> float:
	return {"H": 3.4, "L": 2.9, "M": 2.5}.get(w.get("size", "S"), 2.1 if w.get("kind", "") == "gun" else 1.4)

## Mount paint: the flag's superstructure colour (the shader divides out the reference grey the mounts are baked in).
func mount_tint(p: String) -> Vector3:
	var c := Color(pal.get(paint(p), pal.player).sup)
	return Vector3(c.r, c.g, c.b)

var mount_shader: Shader = preload("res://shaders/mount_light.gdshader")
func mount_material(p: String) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = mount_shader
	m.set_shader_parameter("tint", mount_tint(p)); m.set_shader_parameter("h_max", float(sprites.get("h_max", 40)))
	m.set_shader_parameter("sun_k", Vector2(0.55, 0.85).length())
	return m

## Vertex colour for a mount draw: the sun's direction in the mount's own frame, and the level (or 0 if wrecked).
func mount_code(sun_tex: Vector2, lvl: int, dead := false, alpha := 1.0) -> Color:
	var d := sun_tex.normalized()
	return Color(d.x * 0.5 + 0.5, d.y * 0.5 + 0.5, 0.0 if dead else 0.5 + 0.1 * lvl, alpha)

func fx_tex(n: String) -> Texture2D:
	return tex("res://assets/fx/%s.png" % n)

## Soft light for the modern effects, drawn additively: a glow that falls off smoothly, and a thin bright ring for
## shockwaves. Made once, in code.
var _glow: Texture2D
var _ring: Texture2D
func glow_tex() -> Texture2D:
	if _glow == null: _glow = _radial([0.0, 0.12, 0.35, 0.65, 1.0], [1.0, 0.75, 0.32, 0.08, 0.0])
	return _glow
func ring_tex() -> Texture2D:
	if _ring == null: _ring = _radial([0.0, 0.62, 0.8, 0.88, 0.94, 1.0], [0.0, 0.0, 0.3, 1.0, 0.35, 0.0])
	return _ring
func _radial(offs: Array, alphas: Array) -> Texture2D:
	var gr := Gradient.new(); gr.offsets = PackedFloat32Array(offs)
	var cols := PackedColorArray()
	for a in alphas: cols.append(Color(1, 1, 1, a))
	gr.colors = cols
	var t := GradientTexture2D.new(); t.gradient = gr; t.width = 128; t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL; t.fill_from = Vector2(0.5, 0.5); t.fill_to = Vector2(1.0, 0.5)
	return t

func color(hex: String) -> Color:
	return Color(hex)

## Set by the battle setup screen and read by the battle scene.
var pending: Dictionary = {}
