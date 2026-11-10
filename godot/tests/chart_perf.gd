extends Node
## Times the chart with the clock running: xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/chart_perf.tscn -- [speed]
## Prints the mean and worst frame, the time scripts take in a frame (the chart's own work: the campaign tick at the
## chosen time acceleration, the top bar, the drawing code), and the cost of one campaign tick by itself.
var map: Node
var f := 0
var times: Array = []
var last := 0
var proc := 0.0
var stage := 0
func _ready() -> void:
	seed(4); Weather.force = {"sea": 0, "fog": false, "night": false, "moon": 0.5}
	Campaign.new_game("commission")
	var P: Dictionary = Campaign.G.player
	Campaign.encounter.connect(func(fl): fl.cool = 30.0; Campaign.G.player.cool = 30.0)
	var t0 := Time.get_ticks_usec()
	Campaign.set_course(P, Campaign.lon_x(30), Campaign.lat_y(40))
	for i in 2000:
		Campaign.update(1.0 / 60.0)
		if Campaign.paused: Campaign.paused = false
	print("campaign tick alone: %.2f ms (%d fleets)" % [(Time.get_ticks_usec() - t0) / 2000.0 / 1000.0, Campaign.G.fleets.size()])
	map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
	Campaign.map_speed = int(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 8
	Campaign.paused = false
func _process(_d: float) -> void:
	f += 1
	var now := Time.get_ticks_usec()
	if f > 20: times.append((now - last) / 1000.0); proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	last = now
	if map.panel_open: map.close_panel()
	if Campaign.paused and stage == 0: Campaign.paused = false
	if f == 260:
		var s := 0.0; var mx := 0.0
		for t in times: s += t; mx = maxf(mx, t)
		print("chart at %dx: frame mean %.1f ms, worst %.1f ms, scripts %.1f ms a frame" % [Campaign.map_speed, s / times.size(), mx, proc / times.size()])
		if stage == 0: stage = 1; f = 0; times.clear(); proc = 0.0; Campaign.paused = true; map._user_pause = true
		else: get_tree().quit()
	if stage == 1 and f == 259: print("(the next line is the chart paused)")
