extends Node
## An escort contract on the chart: the convoy, the beacon on its destination and the line between them.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_escort.tscn -- <dir>
var map: Node
var f := 0
func _ready() -> void:
	Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("commission"); Settings.sensors = false
	var G: Dictionary = Campaign.G; var P: Dictionary = G.player
	var near: Array = G.ports.duplicate(); near.sort_custom(func(a, b): return Campaign.mdist(P.x, P.y, a.sx, a.sy) < Campaign.mdist(P.x, P.y, b.sx, b.sy))
	var d: Dictionary = near[1]
	var fl := {"id": G.nextId, "kind": "convoy", "fac": "concord", "h": 0.0, "v": 0.0, "tx": null, "ty": null, "cool": 0.0, "ships": [Campaign.new_ship("freighter", null, "concord", [])], "cargo": {}, "x": P.x + 14, "y": P.y + 10, "home": {"x": P.x, "y": P.y}, "name": "Concord convoy", "escort": 99, "dest": int(d.id), "vis": true}
	G.nextId += 1; G.fleets.append(fl)
	G.contracts.append({"id": 99, "kind": "escort", "title": "Escort a convoy to " + d.name, "fac": "concord", "port": 0, "dest": int(d.id), "deadline": G.day + 60, "reward": 1000, "text": "See the convoy safe into port."})
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	map.free_cam = true; map.cam = Vector2((P.x + d.x) * 0.5, (P.y + d.y) * 0.5); map.zoom = clampf(700.0 / maxf(50.0, Campaign.mdist(P.x, P.y, d.x, d.y)), 0.3, 3.0); Campaign.paused = true
func _process(_d: float) -> void:
	f += 1
	if f == 14: get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/escort.png")
	if f == 16: get_tree().quit()
