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

## Paint scheme actually baked for a design: its own flag if available, otherwise the raiders' scheme.
func ship_pal(id: String, p: String) -> String:
	return p if sprites.ships[id].pals.has(p) else "raiders"

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
	var c := Color(pal.get(p, pal.player).sup)
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

func color(hex: String) -> Color:
	return Color(hex)

## Set by the battle setup screen and read by the battle scene.
var pending: Dictionary = {}
