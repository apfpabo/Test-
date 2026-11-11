extends Node
## The music never cuts: asked for another piece, the one playing fades out while the new one fades in.
## godot --headless --path godot res://tests/music_test.tscn
var bad := 0
func ok(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: bad += 1
func _ready() -> void:
	ok(Sfx._mus_streams.size() == 3 and AudioServer.get_bus_index("Music") >= 0, "the three pieces are loaded and the Music bus exists")
	Sfx.music("menu")
	for i in 30: Sfx._music_tick(0.1)
	var a: AudioStreamPlayer = Sfx._mus[Sfx._mus_on]
	ok(a.playing and a.volume_db > -12.0 and a.stream == Sfx._mus_streams["menu"], "asked for the menu's piece, it is playing three seconds on (%.1f dB)" % a.volume_db)
	Sfx.music("chart"); Sfx._music_tick(0.1)
	var b: AudioStreamPlayer = Sfx._mus[Sfx._mus_on]
	ok(b != a and a.playing and b.playing and b.volume_db < -30.0 and a.volume_db > -12.0, "asked for the chart's, the menu's is still sounding and the chart's has only begun (%.1f and %.1f dB)" % [a.volume_db, b.volume_db])
	var steps := 0; var jump := 0.0; var last := db_to_linear(a.volume_db)
	while a.playing and steps < 100:
		Sfx._music_tick(0.1); steps += 1
		var now := db_to_linear(a.volume_db) if a.playing else 0.0
		jump = maxf(jump, absf(now - last)); last = now
	ok(steps >= 25 and steps <= 35 and jump < 0.08, "the old piece goes out over about three seconds with no step (%d ticks, largest step %.3f of full level)" % [steps, jump])
	for i in 12: Sfx._music_tick(0.1)
	ok(b.playing and b.volume_db > -4.5, "and the new one is fully in a second later (%.1f dB)" % b.volume_db)
	Sfx.music("battle"); Sfx.music("chart"); Sfx._music_tick(0.1)
	ok(Sfx._mus[Sfx._mus_on] == b and b.playing, "asking for a piece and then for the one already playing changes nothing")
	Sfx.music("")
	for i in 40: Sfx._music_tick(0.1)
	ok(not a.playing and not b.playing, "asked for none, it fades to silence")
	print("MUSIC TEST PASSED" if bad == 0 else "MUSIC TEST FAILED (%d)" % bad); get_tree().quit(0 if bad == 0 else 1)
