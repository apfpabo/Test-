extends RefCounted
## Painted art that is dropped into the project as image files (docs/ART.md): officer portraits in
## res://assets/portraits and scene illustrations in res://assets/scenes. Nothing here draws anything: it finds the
## files that exist and hands out textures; with no files the game shows no portraits or banners, as before.
## Loaded by path: `const Art = preload("res://scripts/art.gd")`.

const EXT := ["png", "jpg", "jpeg", "webp"]
static var _faces: Array = []
static var _scanned := false

## The image files in a folder of the project, by their res:// paths (in an exported game the folder lists the
## ".import" stubs of the images, so those are read as the images they stand for).
static func _images(dir: String) -> Array:
	var out := []; var d := DirAccess.open(dir)
	if d == null: return out
	for f in d.get_files():
		var n: String = f.trim_suffix(".import").trim_suffix(".remap")
		if EXT.has(n.get_extension().to_lower()) and not out.has(dir + "/" + n): out.append(dir + "/" + n)
	out.sort()
	return out

static func faces() -> Array:
	if not _scanned: _scanned = true; _faces = _images("res://assets/portraits")
	return _faces

## An officer's portrait, or null if there are none. He keeps the one he is first given (`face`, a file name, saved
## with him), so adding pictures later does not change the faces already in a campaign.
static func portrait(o: Dictionary) -> Texture2D:
	var all: Array = faces()
	if all.is_empty(): return null
	var path := "res://assets/portraits/" + str(o.get("face", ""))
	if not o.has("face") or not all.has(path):
		path = all[abs(hash(str(o.get("id", o.get("name", ""))))) % all.size()]; o.face = path.get_file()
	return load(path) as Texture2D

## A scene illustration by key ("victory", "defeat", "contact", "port", "capital", "storm", "landing", "bomb",
## "survey", "flag", "title"), or null if that file is not there.
static func scene(key: String) -> Texture2D:
	for e in EXT:
		var p := "res://assets/scenes/%s.%s" % [key, e]
		if ResourceLoader.exists(p): return load(p) as Texture2D
	return null
