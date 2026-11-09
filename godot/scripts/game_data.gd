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

func mount_tex(wid: String, p: String) -> Texture2D:
	return tex("res://assets/mounts/%s/%s.webp" % [wid, p])

func fx_tex(n: String) -> Texture2D:
	return tex("res://assets/fx/%s.png" % n)

func color(hex: String) -> Color:
	return Color(hex)

## Set by the battle setup screen and read by the battle scene.
var pending: Dictionary = {}
