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

## Which pictures are women and which first names are (owner's decision, 10 Nov 2026: a face should fit the name).
## A picture added later counts as a woman's if its file name starts with "f_"; a name on neither list takes any face.
const WOMEN := ["p02", "p06", "p09", "p12", "p16", "p19", "p22"]
const NAMES_F := ["Ada", "Celia", "Edda", "Greta", "Ines", "Kasia", "Mira", "Oriana", "Rhea", "Tamsin", "Vera"]
const NAMES_M := ["Bram", "Dorian", "Felix", "Jonas", "Leon", "Nils", "Piet", "Soren", "Ulric", "Wim"]
static func is_woman(path: String) -> bool:
	var n: String = path.get_file().get_basename()
	return WOMEN.has(n) or n.begins_with("f_")
## "f", "m" or "" (either) for an officer: `sex` if he or she has one, otherwise by the first name.
static func sex_of(o: Dictionary) -> String:
	if o.has("sex"): return str(o.sex)
	var first: String = str(o.get("name", "")).get_slice(" ", 0)
	return "f" if NAMES_F.has(first) else ("m" if NAMES_M.has(first) else "")
static func _fits(path: String, sex: String) -> bool:
	return sex == "" or is_woman(path) == (sex == "f")

static func faces() -> Array:
	if not _scanned: _scanned = true; _faces = _images("res://assets/portraits")
	return _faces

## An officer's portrait, or null if there are none. The face fits the name (a woman's name, a woman's face) and
## is kept once given (`face`, a file name, saved with the officer), so adding pictures later does not change the
## faces already in a campaign; one that does not fit the name is chosen again.
static func portrait(o: Dictionary) -> Texture2D:
	var all: Array = faces()
	if all.is_empty(): return null
	var sex := sex_of(o)
	var path := "res://assets/portraits/" + str(o.get("face", ""))
	if not o.has("face") or not all.has(path) or not _fits(path, sex):
		var pool: Array = all.filter(func(p): return _fits(p, sex))
		if pool.is_empty(): pool = all
		path = pool[abs(hash(str(o.get("id", o.get("name", ""))))) % pool.size()]; o.face = path.get_file()
	return load(path) as Texture2D

## A scene illustration by key ("victory", "defeat", "contact", "port", "capital", "storm", "landing", "bomb",
## "survey", "flag", "title"), or null if that file is not there.
static func scene(key: String) -> Texture2D:
	for e in EXT:
		var p := "res://assets/scenes/%s.%s" % [key, e]
		if ResourceLoader.exists(p): return load(p) as Texture2D
	return null
