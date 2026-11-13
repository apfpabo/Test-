extends Node
## Every design with every weapon each of her mounts can take (the owner's request, 13 Nov 2026): one mount changed at
## a time from her standard fit, and the housing's place checked against the hull's edge, her funnels, the other mounts
## on the same level and the upper works beside it. Prints what it finds, the standard fit's own faults first.
##   godot --headless --path godot res://tests/fit_audit.tscn [-- <out.json>]
const TECH := ["radar", "sonar", "homing", "missiles", "ciws", "jets", "aegis", "vls", "ecm", "datalink", "stealth", "netcentric", "precision", "railgun", "helo", "nuclear"]
func _core(w: Dictionary, k: float) -> float:   # the housing's half width: a circle that is surely steel whatever way it is trained
	return 0.5 * float(w.get("tw", 2.0)) * k   # (half her width: half the lesser side under-reported a long house)
var _img := {}
func _deck(id: String, x: float, y: float) -> bool:
	if not _img.has(id):
		var l := []
		for layer in ["base", "top"]:
			var t: Texture2D = GameData.ship_tex(id, "player", layer); var im: Image = t.get_image() if t != null else null
			if im != null and im.is_compressed(): im.decompress()
			if im != null: l.append(im)
		_img[id] = l
	var info: Dictionary = GameData.sprites.ships[id]
	for im in _img[id]:
		var px := int((x / float(info.w) + 0.5) * im.get_width()); var py := int((y / float(info.h) + 0.5) * im.get_height())
		if px >= 0 and py >= 0 and px < im.get_width() and py < im.get_height() and im.get_pixel(px, py).a > 0.5: return true
	return false
func _ready() -> void:
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	var out := []; var n_fit := 0
	var foe: Dictionary = Campaign.new_ship("dd_narvik", "X", "raiders", [])
	for id in GameData.hulls:
		var d: Dictionary = GameData.hulls[id]
		var base: Dictionary = Campaign.new_ship(id, "A", "player", TECH)
		var std: Array = base.fit.duplicate()
		for i in range(-1, d.slots.size()):
			var opts: Array = [""]
			if i >= 0:
				opts = []
				for wid in GameData.weapons:
					var w: Dictionary = GameData.weapons[wid]
					if String(w.size) == String(d.slots[i].s) and wid != std[i] and (not w.get("rail", false) or d.get("power", false)) and BattleSim.room_for(d.slots[i], wid): opts.append(wid)   # (only what a yard would fit there)
			for alt in opts:
				var rec: Dictionary = base.duplicate(true); rec.fit = std.duplicate()
				if i >= 0: rec.fit[i] = alt
				var sim := BattleSim.new(); sim.setup([rec], [foe], TECH, [], 0)
				var s: BattleSim.CShip = sim.ships[0]; n_fit += 1
				for m in s.mounts:
					if i >= 0 and m.slot != d.slots[i]: continue          # only the mount that was changed (all of them for the standard fit)
					if m.w.kind == "ssm" or m.w.kind == "sam": continue   # cells lie flush
					var k: float = GameData.mount_scale(id, m.wid); var r: float = _core(m.w, k)
					var x: float = float(m.slot.x); var y: float = float(m.slot.y); var why := []
					# is there deck drawn under her? (the ship's own picture: a carrier's sponsons and gallery decks count)
					var off := 0
					for a in 8: if not _deck(id, x + cos(a * TAU / 8) * r * 0.85, y + sin(a * TAU / 8) * r * 0.85): off += 1
					if off >= 2: why.append("hangs off the deck (%d of 8 points over the water)" % off)
					# the fittings her plan lists: boats in their crutches, cranes, catapults, the helicopter deck
					var pl: Dictionary = d.get("p", {})
					for b in pl.get("boats", []): if absf(x - float(b[0])) < 9.0 + r * 0.5 and absf(absf(y) - float(d.B) * 0.31) < 2.4 + r * 0.6: why.append("on the boats at x %d" % int(b[0]))
					for c in pl.get("crane", []): if Vector2(x, y).distance_to(Vector2(float(c[0]), float(c[1]))) < 1.2 + r: why.append("on the crane at x %d" % int(c[0]))
					for c in pl.get("cat", []): if absf(x - float(c[0])) < 7.0 + r * 0.5 and absf(y - float(c[1])) < 1.3 + r * 0.7: why.append("on the catapult at x %d" % int(c[0]))
					for c in pl.get("helo", []): if Vector2(x, y).distance_to(Vector2(float(c[0]), 0.0)) < float(c[1]) * 0.8 + r * 0.5: why.append("on the helicopter deck")
					# her barrels, trained to every bearing she is allowed: do they pass through the upper works or another mount?
					if m.w.kind == "gun" and float(m.w.get("bl", 0.0)) > 0.5:
						var muzzle: float = maxf(GameData.ship_h_at(id, x, y), 2.8 * m.lvl) + 1.8
						var bad := 0; var tot := 0; var what := ""
						for bi in BattleSim.BINS:
							var ang: float = sim.bin_angle(bi)
							if (not m.clear.is_empty() and not m.clear[bi]) or (m.clear.is_empty() and sim.arc_check(m.slot, ang).x <= 0.0): continue
							tot += 1; var hit := ""
							for kk in [0.45, 0.75, 1.0]:
								var pt: Vector2 = Vector2(x, y) + Vector2.from_angle(ang) * (float(m.w.get("tl", 2.0)) * 0.5 * k + float(m.w.bl) * kk * k)
								if not _deck(id, pt.x, pt.y): continue
								if GameData.ship_h_at(id, pt.x, pt.y) > muzzle + 2.5: hit = "the upper works"
								for o in s.mounts:
									if o != m and o.lvl >= m.lvl and o.w.kind != "ssm" and o.w.kind != "sam" and pt.distance_to(Vector2(float(o.slot.x), float(o.slot.y))) < _core(o.w, GameData.mount_scale(id, o.wid)) * 0.9: hit = "the %s at x %d" % [o.w.name, int(o.slot.x)]
							if hit != "": bad += 1; what = hit
						if bad > 0: why.append("barrels pass through %s on %d of %d bearings" % [what, bad, tot])
					for f in d.get("p", {}).get("fun", []):
						var fy: float = float(f[3]) if f.size() > 3 else 0.0
						var q := Vector2((x - float(f[0])) / (float(f[1]) + r * 0.7), (y - fy) / (float(f[2]) + r * 0.7))
						if q.length() < 1.0: why.append("in the funnel at x %d" % int(f[0]))
					for o in s.mounts:
						if o == m or o.lvl != m.lvl or o.w.kind == "ssm" or o.w.kind == "sam": continue
						var ro: float = _core(o.w, GameData.mount_scale(id, o.wid))
						var gap: float = Vector2(x, y).distance_to(Vector2(float(o.slot.x), float(o.slot.y))) - (r + ro)
						if gap < -0.5: why.append("into the %s at x %d (%.1f m)" % [o.w.name, int(o.slot.x), -gap])
					if m.lvl == 0 and m.w.kind != "torp":   # the upper works beside a mount on the deck
						var hi := 0.0
						for a in 8: hi = maxf(hi, GameData.ship_h_at(id, x + cos(a * TAU / 8) * r * 0.9, y + sin(a * TAU / 8) * r * 0.9))
						var own: float = GameData.ship_h_at(id, x, y)
						if hi > own + 5.0 and hi > 7.0: why.append("into upper works %.0f m high" % hi)
					if not why.is_empty(): out.append({"id": id, "name": String(d.get("dn", id)), "slot": int(d.slots.find(m.slot)), "x": x, "y": y, "weapon": m.wid, "std": i < 0, "why": why})
	var seen := {}
	var std_n := 0; var alt_n := 0
	for std_pass in [true, false]:
		print("\n== %s ==" % ("THE STANDARD FIT" if std_pass else "ANOTHER WEAPON IN ONE MOUNT"))
		for e in out:
			if e.std != std_pass: continue
			var key := "%s/%d/%s" % [e.id, e.slot, ",".join(e.why)]
			if not std_pass and seen.has("%s/%d" % [e.id, e.slot]): continue   # the standard fit already has this mount's fault
			if std_pass: seen["%s/%d" % [e.id, e.slot]] = true; std_n += 1
			else: alt_n += 1
			print("%-22s slot %2d (%4d,%5.1f) %-8s %s" % [e.id, e.slot, int(e.x), e.y, e.weapon, "; ".join(e.why)])
	print("\n%d fits tried on %d designs: %d faults in standard fits, %d with another weapon" % [n_fit, GameData.hulls.size(), std_n, alt_n])
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		var f := FileAccess.open(a[0], FileAccess.WRITE); f.store_string(JSON.stringify(out)); f.close()
	get_tree().quit()
