extends Node
## Tales: hand-written encounters and story beats (autoload `Tales`). The owner writes them as plain text in
## `godot/data/tales/*.txt`, in the format described in docs/WRITING_TALES.md; this script reads them, decides when one
## comes up (each day at sea, or on arriving in a harbour), keeps what has happened in `G.tales`, and applies what a
## choice does. The chart (world_map.gd: `_open_tale`) shows a tale as a page of text with a button per choice.
##
## A tale is: an id, a few settings (when, where, how often, what it needs) and scenes. A scene is text, effects
## (lines starting with "!") and choices (lines starting with "*", "-> scene" at the end). Nothing in here knows any
## particular tale: every story lives in the text files.

signal ready_tale(id: String)   # a tale has come up at sea: the chart opens it

const DIR := "res://data/tales"
const WHEN := ["at sea", "arriving"]
const SETTINGS := ["title", "when", "where", "days", "chance", "needs", "repeat", "art"]
const OPS := [">=", "<=", "!=", ">", "<", "="]

var T: Dictionary = {}          # id -> tale: {id, title, when, where, days, chance, needs, repeat, art, scenes: {name: scene}, first, file, line}
var order: Array = []           # ids in the order they were read (the first that qualifies comes up first)
var errors: Array = []          # "file:line: what is wrong", for the test and the chart's warning
var warned := false
var at_port := ""              # the harbour an arriving tale came up in ({port} names it)

func _ready() -> void: load_all()

# ------------------------------------------------------------------ reading the files
func load_all() -> void:
	T = {}; order = []; errors = []
	var d := DirAccess.open(DIR)
	if d == null: return
	var files: Array = []
	for f in d.get_files():
		if f.ends_with(".txt"): files.append(f)
	files.sort()
	for f in files: parse(FileAccess.get_file_as_string(DIR + "/" + f), f)
	check()

## Reads one file of tales. `fname` is used only to say where an error is.
func parse(text: String, fname := "text") -> void:
	var cur = null; var scene = null; var n := 0
	for raw in text.split("\n"):
		n += 1
		var line: String = raw.strip_edges()
		if line.begins_with("#"): continue
		if line.begins_with("==="):
			var id := line.substr(3).strip_edges()
			if id == "" or id.contains(" "): _err(fname, n, "a tale's name is one word (use _ between words): \"%s\"" % id); cur = null; continue
			if T.has(id): _err(fname, n, "there is already a tale called \"%s\" (%s)" % [id, T[id].file])
			cur = {"id": id, "title": id.capitalize(), "when": "at sea", "where": [], "days": [0, 1000000], "chance": 1.0, "needs": [],
				"repeat": 0, "art": "", "scenes": {}, "first": "", "file": fname, "line": n}
			T[id] = cur; order.append(id); scene = null; continue
		if cur == null:
			if line != "": _err(fname, n, "text before the first tale (a tale starts with a line \"=== name\")")
			continue
		if line.begins_with("---"):
			var sn := line.substr(3).strip_edges()
			if sn == "": sn = "start"
			if cur.scenes.has(sn): _err(fname, n, "the scene \"%s\" is written twice" % sn)
			scene = {"name": sn, "text": [], "do": [], "choices": [], "line": n}
			cur.scenes[sn] = scene
			if cur.first == "": cur.first = sn
			continue
		if scene == null:   # the settings, before the first scene
			if line == "": continue
			var c := line.find(":")
			if c < 0: _err(fname, n, "a setting is \"name: value\" (or start a scene with \"--- name\")"); continue
			_setting(cur, line.substr(0, c).strip_edges().to_lower(), line.substr(c + 1).strip_edges(), fname, n)
			continue
		if line.begins_with("!"):
			var e := _effect(line.substr(1).strip_edges(), fname, n)
			if not e.is_empty(): scene.do.append(e)
		elif line.begins_with("*"):
			var ch := _choice(line.substr(1).strip_edges(), fname, n)
			if not ch.is_empty(): scene.choices.append(ch)
		elif line == "":
			if not scene.text.is_empty() and scene.text[-1] != "": scene.text.append("")
		elif not scene.text.is_empty() and scene.text[-1] != "": scene.text[-1] += " " + line   # lines of a paragraph run on
		else: scene.text.append(line)

func _setting(t: Dictionary, k: String, v: String, fname: String, n: int) -> void:
	match k:
		"title": t.title = v
		"art": t.art = v
		"when":
			if not WHEN.has(v.to_lower()): _err(fname, n, "when is one of: %s" % ", ".join(WHEN)); return
			t.when = v.to_lower()
		"where":
			for part in v.split(","):
				var w := _where(part.strip_edges(), fname, n)
				if not w.is_empty(): t.where.append(w)
		"days":
			var a := v.replace(" ", "").split("-")
			if a.size() == 1 and a[0].ends_with("+"): t.days = [int(a[0].trim_suffix("+")), 1000000]
			elif a.size() == 2 and a[0].is_valid_int() and a[1].is_valid_int(): t.days = [int(a[0]), int(a[1])]
			else: _err(fname, n, "days is a range such as 20-200, or 30+")
		"chance":
			var s := v.replace(" ", "")
			if s.ends_with("%") and s.trim_suffix("%").is_valid_float(): t.chance = float(s.trim_suffix("%")) / 100.0
			elif s.is_valid_float(): t.chance = float(s)
			else: _err(fname, n, "chance is a percentage such as 10%")
		"needs":
			for part in _split_conds(v):
				var c := _cond(part, fname, n)
				if not c.is_empty(): t.needs.append(c)
		"repeat":
			var s := v.to_lower()
			if s == "no" or s == "once": t.repeat = 0
			elif s.begins_with("every"):
				var num := s.replace("every", "").replace("days", "").replace("day", "").strip_edges()
				if num.is_valid_int(): t.repeat = int(num)
				else: _err(fname, n, "repeat is \"no\" or \"every 60 days\"")
			else: _err(fname, n, "repeat is \"no\" or \"every 60 days\"")
		_: _err(fname, n, "unknown setting \"%s\" (the settings are: %s)" % [k, ", ".join(SETTINGS)])

## Where a tale may come up: "anywhere", "sea <name>" (one of the chart's seas), "near <port> [km]", "port <name>",
## "power <power>" (a harbour or the waters of that power).
func _where(s: String, fname: String, n: int) -> Dictionary:
	var lo := s.to_lower()
	if lo == "anywhere" or lo == "": return {}
	var sp := s.find(" ")
	var k := lo.substr(0, sp) if sp > 0 else lo; var rest := s.substr(sp + 1).strip_edges() if sp > 0 else ""
	match k:
		"sea":
			for th in Campaign.C.get("THEATERS", []): if String(th[0]).to_lower() == rest.to_lower(): return {"k": "sea", "v": String(th[0])}
			_err(fname, n, "no sea called \"%s\" on the chart" % rest)
		"near":
			var km := 300.0; var nm := rest
			var last := rest.get_slice(" ", rest.get_slice_count(" ") - 1)
			if last.is_valid_float(): km = float(last); nm = rest.substr(0, rest.length() - last.length()).strip_edges()
			if _port_named(nm).is_empty(): _err(fname, n, "no harbour called \"%s\"" % nm); return {}
			return {"k": "near", "v": nm, "km": km}
		"port":
			if _port_named(rest).is_empty(): _err(fname, n, "no harbour called \"%s\"" % rest); return {}
			return {"k": "port", "v": rest}
		"power":
			var f := _power(rest)
			if f == "": _err(fname, n, "no power called \"%s\"" % rest); return {}
			return {"k": "power", "v": f}
		_: _err(fname, n, "where is: anywhere, sea <name>, near <harbour> [km], port <harbour>, or power <power>")
	return {}

func _split_conds(v: String) -> Array:
	var out := []
	for p in v.split(","):
		if p.strip_edges() != "": out.append(p.strip_edges())
	return out

## A condition: credits / rp / crew / day / era / ships / fuel... >= N, standing <power> >= N, cargo <good> >= N,
## flag <name>, done <tale>, origin <id>, navy <power>, class <class>, war <power>, commission <power>; "not" in front
## turns any of them about.
func _cond(s: String, fname: String, n: int) -> Dictionary:
	var neg := false; var w := s.strip_edges()
	if w.to_lower().begins_with("not "): neg = true; w = w.substr(4).strip_edges()
	var op := ""; var lhs := w; var rhs := ""
	for o in OPS:
		var i := w.find(o)
		if i > 0: op = o; lhs = w.substr(0, i).strip_edges(); rhs = w.substr(i + o.length()).strip_edges(); break
	var words := lhs.split(" ", false)
	if words.is_empty(): _err(fname, n, "an empty condition"); return {}
	var k := words[0].to_lower(); var arg := " ".join(words.slice(1))
	var c := {"k": k, "a": arg, "op": op, "n": float(rhs) if rhs.is_valid_float() else 0.0, "not": neg, "src": s}
	if op != "" and not rhs.is_valid_float(): _err(fname, n, "\"%s\": the number after %s is missing" % [s, op]); return {}
	match k:
		"credits", "rp", "crew", "day", "era", "ships", "kills", "ports", "year":
			if op == "": _err(fname, n, "\"%s\" needs a comparison, e.g. %s >= 100" % [s, k]); return {}
		"standing":
			c.a = _power(arg)
			if c.a == "": _err(fname, n, "\"%s\": no power called \"%s\"" % [s, arg]); return {}
			if op == "": _err(fname, n, "\"%s\" needs a comparison, e.g. standing %s >= 10" % [s, arg]); return {}
		"cargo":
			if not _good(arg): _err(fname, n, "\"%s\": no good called \"%s\"" % [s, arg]); return {}
			if op == "": c.op = ">="; c.n = 1.0
		"flag", "done", "origin", "class":
			if arg == "": _err(fname, n, "\"%s\": a name is missing" % s); return {}
			if k == "origin" and not Origins.INFO.has(arg): _err(fname, n, "no origin called \"%s\" (%s)" % [arg, ", ".join(Origins.LIST)]); return {}
			if k == "class" and not Campaign.C.DESIGNS_OF.has(arg): _err(fname, n, "no class called \"%s\"" % arg); return {}
		"navy", "war", "commission":
			c.a = _power(arg)
			if c.a == "": _err(fname, n, "\"%s\": no power called \"%s\"" % [s, arg]); return {}
		_:
			_err(fname, n, "unknown condition \"%s\"" % s); return {}
	return c

## An effect: credits / rp / crew / fuel / food / <good> +N, standing <power> +N, hull -N%, ship <class or design>
## ["name"], flag <name>, clear <name>, log <text>, fight <power> <class> <class>... ["name"] [-> scene if won].
func _effect(s: String, fname: String, n: int) -> Dictionary:
	var then := ""
	var ar := s.find("->")
	if ar >= 0: then = s.substr(ar + 2).strip_edges(); s = s.substr(0, ar).strip_edges()
	var nm := ""
	var q := s.find("\"")
	if q >= 0: nm = s.substr(q).replace("\"", "").strip_edges(); s = s.substr(0, q).strip_edges()
	var words := s.split(" ", false)
	if words.is_empty(): _err(fname, n, "an empty effect"); return {}
	var k := words[0].to_lower(); var args: Array = Array(words.slice(1))
	var e := {"k": k, "args": args, "name": nm, "then": then, "line": n}
	var num := func(x: String) -> bool: return x.trim_suffix("%").is_valid_float()
	match k:
		"credits", "rp", "crew":
			if args.size() != 1 or not num.call(args[0]): _err(fname, n, "\"%s\": a number is missing, e.g. %s +500" % [s, k]); return {}
			e.n = float(args[0])
		"standing":
			if args.size() != 2 or _power(args[0]) == "" or not num.call(args[1]): _err(fname, n, "\"%s\": standing <power> +N" % s); return {}
			e.fac = _power(args[0]); e.n = float(args[1])
		"hull":
			if args.size() != 1 or not num.call(args[0]): _err(fname, n, "\"%s\": hull -N%%" % s); return {}
			e.n = float(args[0].trim_suffix("%"))
		"ship":
			if args.size() != 1 or not _ship_type(args[0]): _err(fname, n, "\"%s\": ship <class or design>, e.g. ship dd" % s); return {}
		"flag", "clear":
			if args.size() != 1: _err(fname, n, "\"%s\": %s <one-word name>" % [s, k]); return {}
		"log":
			if nm == "" and args.is_empty(): _err(fname, n, "log needs some words"); return {}
			e.text = nm if nm != "" else " ".join(args)
		"fight":
			if args.size() < 2 or _power(args[0]) == "": _err(fname, n, "\"%s\": fight <power> <class> <class>... (e.g. fight raiders dd pt pt)" % s); return {}
			e.fac = _power(args[0])
			for a in args.slice(1): if not _ship_type(a): _err(fname, n, "\"%s\": no class or design called \"%s\"" % [s, a]); return {}
		_:
			if _good(k):
				if args.size() != 1 or not num.call(args[0]): _err(fname, n, "\"%s\": %s +N (tons)" % [s, k]); return {}
				e.good = k; e.k = "cargo"; e.n = float(args[0])
			else: _err(fname, n, "unknown effect \"%s\"" % s); return {}
	if then != "" and k != "fight": _err(fname, n, "only fight takes \"-> scene\" (where the tale goes on if you win)")
	return e

## "* [condition, condition] What the captain says -> scene" (or "-> end").
func _choice(s: String, fname: String, n: int) -> Dictionary:
	var conds := []
	if s.begins_with("["):
		var j := s.find("]")
		if j < 0: _err(fname, n, "a choice's [conditions] are not closed"); return {}
		for p in _split_conds(s.substr(1, j - 1)):
			var c := _cond(p, fname, n)
			if not c.is_empty(): conds.append(c)
		s = s.substr(j + 1).strip_edges()
	var ar := s.rfind("->")
	if ar < 0: _err(fname, n, "a choice ends with \"-> scene\" (or \"-> end\")"); return {}
	var to := s.substr(ar + 2).strip_edges()
	return {"text": s.substr(0, ar).strip_edges(), "to": to, "needs": conds, "line": n}

## After reading: every choice leads to a scene that exists, every scene can be reached, every tale has a scene.
func check() -> void:
	for id in order:
		var t: Dictionary = T[id]
		if t.scenes.is_empty(): _err(t.file, t.line, "the tale \"%s\" has no scenes (start one with \"--- start\")" % id); continue
		var reach := {t.first: true}; var stack := [t.first]
		while not stack.is_empty():
			var sc: Dictionary = t.scenes[stack.pop_back()]
			for to in _exits(sc):
				if to == "end": continue
				if not t.scenes.has(to): _err(t.file, sc.line, "\"-> %s\": there is no scene called \"%s\" in this tale" % [to, to]); continue
				if not reach.has(to): reach[to] = true; stack.append(to)
		for sn in t.scenes:
			if not reach.has(sn): _err(t.file, t.scenes[sn].line, "the scene \"%s\" cannot be reached from \"%s\"" % [sn, t.first])
		for c in t.needs: if c.k == "done" and not T.has(c.a): _err(t.file, t.line, "needs \"done %s\": there is no such tale" % c.a)

func _exits(sc: Dictionary) -> Array:
	var out := []
	for ch in sc.choices: out.append(ch.to)
	for e in sc.do: if e.k == "fight" and e.then != "": out.append(e.then)
	return out

func _err(fname: String, n: int, what: String) -> void: errors.append("%s:%d: %s" % [fname, n, what])

func _port_named(nm: String) -> Dictionary:
	for p in Campaign.C.get("ports", []): if String(p.name).to_lower() == nm.to_lower(): return p
	return {}
func _power(s: String) -> String:
	var lo := s.to_lower().strip_edges()
	if lo == "raiders": return "raiders"
	for f in GameData.fac:
		if f == "player": continue
		if lo == f or lo == String(GameData.fac[f].short).to_lower() or lo == String(GameData.fac[f].name).to_lower(): return f
	return ""
func _good(s: String) -> bool:
	for g in Campaign.C.GOODS: if g.id == s: return true
	return false
func _ship_type(s: String) -> bool: return Campaign.C.DESIGNS_OF.has(s) or GameData.hulls.has(s)

# ------------------------------------------------------------------ the campaign's side
## What has happened, kept in the save: tales done (id -> day), story flags, the tale open now and the scene a won
## fight goes on to.
func st() -> Dictionary:
	var G: Dictionary = Campaign.G
	if not G.has("tales"): G.tales = {"done": {}, "flags": {}, "open": "", "scene": "", "resume": {}}
	return G.tales

## Each day at sea (Campaign.new_day): the first tale of "at sea" whose place, days and needs hold and whose chance
## comes up is opened. A tale's own random draw, so tales never shift the rest of the game's dice.
func new_day() -> void:
	if T.is_empty() or Campaign.G.is_empty() or Campaign.G.get("docked", false): return
	if st().open != "": return
	for id in order:
		var t: Dictionary = T[id]
		if t.when != "at sea" or not eligible(id): continue
		if roll(id): open(id); ready_tale.emit(id); return

## On arriving in a harbour (the chart asks before it opens the port's page): a tale of "arriving" whose
## conditions hold there. Returns its id, or "".
func on_arrive(p: Dictionary) -> String:
	if T.is_empty() or st().open != "": return ""
	for id in order:
		var t: Dictionary = T[id]
		if t.when == "arriving" and eligible(id, p) and roll(id): open(id); at_port = String(p.name); return id
	return ""

func roll(id: String) -> bool:
	var t: Dictionary = T[id]
	if t.chance >= 1.0: return true
	var r := RandomNumberGenerator.new(); r.seed = hash([id, int(Campaign.G.day), int(Campaign.G.get("nextId", 0))])
	return r.randf() < t.chance

## Whether a tale may come up now (at `port` if given, else where the squadron is).
func eligible(id: String, port = null) -> bool:
	var t: Dictionary = T[id]; var G: Dictionary = Campaign.G; var s := st()
	if s.done.has(id) and (t.repeat <= 0 or int(G.day) - int(s.done[id]) < t.repeat): return false
	if int(G.day) < t.days[0] or int(G.day) > t.days[1]: return false
	if not t.where.is_empty() and not t.where.any(func(w): return _at(w, port)): return false
	for c in t.needs: if not test(c): return false
	return true

func _at(w: Dictionary, port) -> bool:
	var P: Dictionary = Campaign.G.player
	match String(w.k):
		"port": return port != null and String(port.name).to_lower() == String(w.v).to_lower()
		"near":
			var p := {}
			for q in Campaign.G.ports: if String(q.name).to_lower() == String(w.v).to_lower(): p = q
			return not p.is_empty() and Campaign.mdist(P.x, P.y, p.sx, p.sy) * 5.5 <= float(w.km)
		"power":
			if port != null: return port.fac == w.v
			var np = Campaign.nearest_port(110.0)   # within about 600 km of one of its harbours
			return np != null and np.fac == w.v
		"sea": return sea_of(P.x, P.y) == w.v
	return true

## The chart's sea nearest a point (the labels of THEATERS), as Diplomacy.where names it.
func sea_of(x: float, y: float) -> String:
	var bt := ""; var bd := INF
	for th in Campaign.C.THEATERS:
		var d := Campaign.mdist(x, y, Campaign.lon_x(th[1]), Campaign.lat_y(th[2]))
		if d < bd: bd = d; bt = th[0]
	return bt

func test(c: Dictionary) -> bool:
	var G: Dictionary = Campaign.G; var v := 0.0; var yes := false; var cmp := true
	match String(c.k):
		"credits": v = float(G.credits)
		"rp": v = float(G.rp)
		"crew": v = float(G.crew)
		"day": v = float(G.day)
		"era": v = float(Campaign.player_era())
		"ships": v = float(Campaign.all_ships().size())
		"kills": v = float(G.get("kills", 0))
		"ports": v = float(Flag.ports().size()) if Flag.founded() else 0.0   # harbours under your own flag
		"year": v = float(Campaign.year())
		"standing": v = float(G.rep.get(c.a, 0))
		"cargo": v = float(G.cargo.get(c.a, 0.0))
		_:
			cmp = false
			match String(c.k):
				"flag": yes = st().flags.has(c.a)
				"done": yes = st().done.has(c.a)
				"origin": yes = String(G.get("origin", "")) == c.a
				"navy": yes = String(G.get("navy", "")) == c.a
				"class": yes = Campaign.all_ships().any(func(s): return Campaign.hull(s).klass == c.a)
				"war": yes = Campaign.at_war(c.a)
				"commission": yes = G.get("commission") != null and G.commission.get("fac", "") == c.a
	if cmp:
		match String(c.op):
			">=": yes = v >= c.n
			"<=": yes = v <= c.n
			">": yes = v > c.n
			"<": yes = v < c.n
			"=": yes = is_equal_approx(v, c.n)
			"!=": yes = not is_equal_approx(v, c.n)
	return yes != bool(c.not)

func open(id: String, scene := "") -> void:
	var s := st(); s.open = id; s.scene = scene if scene != "" else String(T[id].first)

## The scene open now, with its text filled in and its effects applied once (`entered`). Returns {} if none.
func current() -> Dictionary:
	var s := st()
	if s.open == "" or not T.has(s.open): return {}
	var t: Dictionary = T[s.open]
	if not t.scenes.has(s.scene): return {}
	return t.scenes[s.scene]

## Enter the open scene: apply its effects. Returns the lines to show after the text (what the effects did), and the
## fleet to fight if the scene starts one (`fight`).
func enter() -> Dictionary:
	var sc := current(); var out := {"notes": [], "fight": null}
	if sc.is_empty(): return out
	for e in sc.do: _apply(e, out)
	return out

func choices() -> Array:
	var sc := current(); var out := []
	if sc.is_empty(): return out
	for ch in sc.choices: out.append({"text": fill(ch.text), "to": ch.to, "ok": ch.needs.all(func(c): return test(c)), "why": ", ".join(ch.needs.filter(func(c): return not test(c)).map(func(c): return c.src))})
	return out

## The captain chose `to`: the tale goes on there, or ends.
func choose(to: String) -> void:
	var s := st()
	if to == "end" or not T.has(s.open) or not T[s.open].scenes.has(to): finish(); return
	s.scene = to

func finish() -> void:
	var s := st()
	if s.open != "": s.done[s.open] = int(Campaign.G.day); Campaign.log_ev("Tale: " + String(T[s.open].title) if T.has(s.open) else s.open)
	s.open = ""; s.scene = ""; at_port = ""

## After a battle a tale started: if it was won and the fight named a scene, the tale goes on there.
func after_battle(won: bool) -> String:
	var s := st()
	if s.resume.is_empty(): return ""
	var r: Dictionary = s.resume; s.resume = {}
	if won and T.has(r.id) and T[r.id].scenes.has(r.scene): open(r.id, r.scene); return r.id
	return ""

func _apply(e: Dictionary, out: Dictionary) -> void:
	var G: Dictionary = Campaign.G
	match String(e.k):
		"credits":
			G.credits = maxi(0, int(round(float(G.credits) + e.n))); out.notes.append("%s%s" % ["+" if e.n >= 0 else "-", Campaign.fmt(absf(e.n))])
		"rp": G.rp = maxi(0, int(G.rp) + int(e.n)); out.notes.append("%+d RP" % int(e.n))
		"crew": G.crew = maxi(0, int(G.crew) + int(e.n)); out.notes.append("%+d crew" % int(e.n))
		"cargo":
			G.cargo[e.good] = maxf(0.0, float(G.cargo.get(e.good, 0.0)) + e.n); out.notes.append("%+d t %s" % [int(e.n), e.good])
		"standing":
			G.rep[e.fac] = clampi(int(G.rep.get(e.fac, 0)) + int(e.n), -100, 100); Campaign.rep_note("A tale: " + String(T[st().open].title))
			out.notes.append("Standing with the %s %+d" % [GameData.fac[e.fac].short if GameData.fac.has(e.fac) else e.fac, int(e.n)])
		"hull":
			for sh in G.fleet: sh.hullFrac = clampf(float(sh.hullFrac) + e.n / 100.0, 0.05, 1.0)
			out.notes.append("Hulls %+d%%" % int(e.n))
		"ship":
			var sh: Dictionary = Campaign.new_ship(e.args[0], e.name if e.name != "" else null, "player", G.tech)
			var why: String = Campaign.can_add_ship(sh.type)
			if why == "": sh.built = int(G.day); G.fleet.append(sh); out.notes.append("The %s joins your squadron." % sh.name)
			else: out.notes.append("You cannot take her on: %s" % why)
		"flag": st().flags[e.args[0]] = int(G.day)
		"clear": st().flags.erase(e.args[0])
		"log": Campaign.log_ev(fill(e.text))
		"fight":
			var ships := []
			for i in range(1, e.args.size()): ships.append([e.args[i], e.name] if i == 1 and e.name != "" else [e.args[i]])
			var np = Campaign.nearest_port(100000.0)
			var f: Dictionary = Campaign.spawn_fleet("mission", e.fac, false, {"fac": e.fac, "title": e.name if e.name != "" else String(T[st().open].title), "ships": ships, "near": np.name})
			f.x = Campaign.wrap_x(G.player.x + 6); f.y = G.player.y; f.tale = st().open
			if e.then != "": st().resume = {"id": st().open, "scene": e.then}
			out.fight = f

## Words in braces are filled in: {flagship}, {port} (the harbour you arrived in, or the nearest), {sea}, {date}, {credits}.
func fill(s: String) -> String:
	if not s.contains("{"): return s
	var G: Dictionary = Campaign.G; var np = Campaign.nearest_port(100000.0)
	return s.replace("{flagship}", String(G.fleet[0].name) if not G.fleet.is_empty() else "your ship") \
		.replace("{port}", at_port if at_port != "" else (String(np.name) if np != null else "port")).replace("{sea}", sea_of(G.player.x, G.player.y).capitalize()) \
		.replace("{date}", Campaign.date_str(int(G.day))).replace("{credits}", Campaign.fmt(float(G.credits)))

func text() -> String:
	var sc := current()
	if sc.is_empty(): return ""
	return "\n\n".join(sc.text.filter(func(l): return l != "").map(func(l): return fill(l)))
