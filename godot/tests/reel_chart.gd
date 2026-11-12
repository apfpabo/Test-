extends Node
## A Reels clip of the chart (the owner's request, 12 Nov 2026): a campaign some weeks on, the clock at its fastest,
## fleets, convoys and wars moving under the weather; a slow push in on your squadron, then the world as a globe,
## turning. Recorded upright like the battle clips; with the interface ("ui") or without (the chart's H).
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1080x1920 --fixed-fps 30 \
##     --write-movie <out.avi> res://tests/reel_chart.tscn -- [seconds] [ui]
var map: Node
var t := 0.0
var f := 0
var length := 15.0
var ui := false
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: length = float(a[0])
	ui = a.size() > 1 and a[1] == "ui"
	seed(7); Settings.sensors = false; Weather.force = null
	Campaign.new_game("privateer")
	var G: Dictionary = Campaign.G
	# some weeks on, without stopping for contacts: the powers' fleets, convoys and wars about their business
	for i in 4200:
		G.player.cool = 1.0e6; Campaign.paused = false; Campaign.update(0.1)
	G.player.cool = 4.0
	# somewhere to be going: the farthest friendly harbour, so the squadron is under way on the chart
	var P: Dictionary = G.player; var best = null
	for p in G.ports: if not Campaign.hostile(p.fac) and (best == null or Campaign.mdist(p.sx, p.sy, P.x, P.y) > Campaign.mdist(best.sx, best.sy, P.x, P.y)) and Campaign.mdist(p.sx, p.sy, P.x, P.y) < 2500.0: best = p
	if best != null: Campaign.set_course(P, best.sx, best.sy)
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	Sfx.music("")
func _process(d: float) -> void:
	f += 1
	if f == 2:
		if map.panel_open: map.close_panel()
		map.ui.visible = ui; map._speed(8); Campaign.paused = false
		map.free_cam = true; map.cam = Vector2(Campaign.G.player.x, Campaign.G.player.y); map.zoom = 0.72
	if f < 3: return
	if map.panel_open: map.close_panel()   # contacts and harbours are not stopped for: the clock keeps running
	Campaign.paused = false
	t += d
	var P: Dictionary = Campaign.G.player
	if t < 9.5:   # a slow push in from the sea area to the squadron under way
		var k: float = smoothstep(0.0, 9.5, t)
		map.cam = map.cam.lerp(Vector2(P.x, P.y), 0.03); map.zoom = lerpf(0.72, 1.9, k)
	elif t < 10.0:
		if not map.globe.is_open(): map.zoom = 0.22; map.globe.open()
	else:
		map.globe.spin = Vector2(0.22, 0.0); map.globe.k = lerpf(map.globe.k, 1.25, 0.01)
	if t >= length: get_tree().quit()
