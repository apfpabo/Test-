extends Node
## Times the chart while zooming in and out with the mouse wheel: prints the mean and worst frame time.
## xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/map_zoom_perf.tscn
var map: Node
var f := 0
var times: Array = []
var last := 0
var proc := 0.0
func _ready() -> void:
    Campaign.new_game("commission")
    map = load("res://scenes/world_map.tscn").instantiate(); add_child(map)
    Campaign.paused = true
func _process(_d: float) -> void:
    f += 1
    var now := Time.get_ticks_usec()
    if f > 10 and f <= 130: times.append((now - last) / 1000.0); proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
    last = now
    if f >= 10 and f < 130:
        var k := (f - 10) % 40
        if OS.get_cmdline_user_args().is_empty(): map._zoom_at(1.12 if k < 20 else 1.0 / 1.12, map.get_viewport_rect().size / 2)
    if f == 131:
        var s := 0.0; var mx := 0.0
        for t in times: s += t; mx = maxf(mx, t)
        print("zoom frames: mean %.1f ms, worst %.1f ms, scripts %.1f ms" % [s / times.size(), mx, proc / times.size()]); get_tree().quit()
