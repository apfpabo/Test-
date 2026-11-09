extends Node
## Synthesised sound, rendered once at start-up and played through a small pool of players, louder the nearer the
## camera. A gun report is three parts: a low pressure thump (a falling sine), a sharp crack (bright noise, a few
## milliseconds) and a rolling tail (low-passed noise); heavier guns have a deeper thump and a longer tail. Light AA
## fire is a short pop. A looping engine-and-sea rumble follows the speed of the ships near the camera. A compressor
## and limiter on the master bus give the reports weight without clipping.

const RATE := 22050
var _cut: Array[float] = [160.0, 220.0, 350.0, 520.0, 700.0, 900.0, 1200.0, 1400.0]
var _banks: Array = []          # per cutoff: a few variations
var _pop: Array = []            # light AA pops
var _pool: Array[AudioStreamPlayer] = []
var _next = 0
var _engine: AudioStreamPlayer
var _recent: Array[float] = []   # start times of recent reports, to keep a big gunfight from turning to mush
var muted = false:
	set(v): muted = v; if _engine: _engine.stream_paused = v

func _ready() -> void:
	for c in _cut:
		var vars = []
		for k in 2: vars.append(_report(c))
		_banks.append(vars)
	for k in 3: _pop.append(_aa_pop())
	for i in 24:
		var p = AudioStreamPlayer.new(); add_child(p); _pool.append(p)
	_engine = AudioStreamPlayer.new(); _engine.stream = _engine_loop(); _engine.volume_db = -80.0; add_child(_engine)
	var comp = AudioEffectCompressor.new(); comp.threshold = -16.0; comp.ratio = 4.0; comp.attack_us = 2000.0; comp.release_ms = 250.0; comp.gain = 4.0
	AudioServer.add_bus_effect(0, comp)
	var lim = AudioEffectHardLimiter.new() if ClassDB.class_exists("AudioEffectHardLimiter") else AudioEffectLimiter.new()
	AudioServer.add_bus_effect(0, lim)

func _wav(data: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var b = PackedByteArray(); b.resize(data.size() * 2)
	for i in data.size(): b.encode_s16(i * 2, clampi(int(data[i] * 32767.0), -32767, 32767))
	var w = AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = b
	if loop: w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = data.size()
	return w

## One gun report or explosion. cutoff sets the weight: low = heavy gun or big blast.
func _report(cutoff: float) -> AudioStreamWAV:
	var heavy = clampf((900.0 - cutoff) / 740.0, 0.0, 1.0)       # 1 for the heaviest, 0 for light guns
	var dur = lerpf(0.55, 2.4, heavy); var n = int(RATE * dur)
	var out = PackedFloat32Array(); out.resize(n)
	var f0 = lerpf(150.0, 70.0, heavy); var f1 = lerpf(60.0, 28.0, heavy)
	var a = exp(-TAU * cutoff / RATE); var y = 0.0; var y2 = 0.0; var hp = 0.0; var prev = 0.0; var ph = 0.0
	for i in n:
		var t = float(i) / RATE
		var att = minf(1.0, t * 900.0)
		# thump: a sine falling in pitch, gone in a fraction of a second
		var f = f1 + (f0 - f1) * exp(-t * 18.0); ph += TAU * f / RATE
		var thump = sin(ph) * exp(-t * lerpf(16.0, 7.0, heavy)) * att
		# body: a second, lower sine that lingers, the weight felt rather than heard (most of it 40-90 Hz)
		var body = sin(ph * 0.55) * exp(-t * lerpf(9.0, 3.2, heavy)) * att * lerpf(0.35, 0.9, heavy)
		# crack: bright noise for the first few milliseconds
		var nz = randf_range(-1, 1); hp = 0.6 * (hp + nz - prev); prev = nz
		var crack = hp * exp(-t * lerpf(60.0, 35.0, heavy))
		# tail: low-passed rumble that rolls on
		y = (1.0 - a) * nz + a * y; y2 = (1.0 - a) * y + a * y2
		var tail = y2 * 3.4 * exp(-t * lerpf(6.0, 1.6, heavy)) * minf(1.0, t * 60.0)
		out[i] = clampf(thump * lerpf(0.75, 1.0, heavy) + body + crack * lerpf(0.6, 0.35, heavy) + tail * 0.9, -1.0, 1.0) * 0.8
	return _wav(out)

## A light AA round: a short pop.
func _aa_pop() -> AudioStreamWAV:
	var n = int(RATE * 0.16); var out = PackedFloat32Array(); out.resize(n); var ph = 0.0; var y = 0.0
	for i in n:
		var t = float(i) / RATE; var nz = randf_range(-1, 1); y = 0.5 * y + 0.5 * nz
		ph += TAU * (220.0 - t * 600.0) / RATE
		out[i] = clampf((sin(ph) * 0.6 + y * 0.7) * exp(-t * 38.0) * minf(1.0, t * 1500.0), -1.0, 1.0)
	return _wav(out)

## Engine and sea: a slow-breathing low rumble that loops without a seam.
func _engine_loop() -> AudioStreamWAV:
	var n = RATE * 4; var out = PackedFloat32Array(); out.resize(n); var y = 0.0; var y2 = 0.0; var bw = 0.0; var a = exp(-TAU * 90.0 / RATE)
	for i in n:
		var t = float(i) / RATE; var nz = randf_range(-1, 1); y = (1.0 - a) * nz + a * y; y2 = (1.0 - a) * y + a * y2
		var hum = sin(TAU * 42.0 * t) * 0.18 + sin(TAU * 84.0 * t) * 0.1 + sin(TAU * 126.0 * t) * 0.07 + sin(TAU * 252.0 * t) * 0.03  # shafts, turbines, blowers
		var swell = 0.75 + 0.25 * sin(TAU * t / 4.0)                          # the sea, once round the loop
		bw = 0.92 * bw + 0.08 * nz; var wash = (nz - bw) * 0.22 * (0.6 + 0.4 * sin(TAU * t / 2.0 + 1.0))  # bow wave hiss
		out[i] = (y2 * 5.0 * swell + hum * (1.0 + 0.15 * sin(TAU * 3.0 * t)) + wash) * 0.7
	# cross-fade the ends so the loop is seamless
	var fade = RATE / 4
	for i in fade:
		var k = float(i) / fade; out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
	out.resize(n - fade)
	return _wav(out, true)

## vol 0..1, freq picks the nearest bank (lower is heavier), rate scales playback speed.
func boom(vol: float, freq := 420.0, rate := 1.0) -> void:
	if muted or vol < 0.01: return
	var best = 0
	for i in _cut.size(): if absf(_cut[i] - freq) < absf(_cut[best] - freq): best = i
	_play(_banks[best].pick_random(), vol, rate)

## Light AA and point-defence fire.
func pop(vol: float) -> void:
	if muted or vol < 0.01: return
	_play(_pop.pick_random(), vol, randf_range(0.85, 1.2))

func _play(stream: AudioStream, vol: float, rate: float) -> void:
	# a crowd of reports at once: each new one is quieter, and faint ones are dropped, so the loudest stay distinct
	var now := Time.get_ticks_msec() / 1000.0
	while not _recent.is_empty() and now - _recent[0] > 0.35: _recent.pop_front()
	var crowd := _recent.size()
	if crowd > 4 and vol < 0.15: return
	vol /= sqrt(1.0 + crowd * 0.35)
	_recent.append(now)
	# far reports arrive muffled and a touch lower
	if vol < 0.2: rate *= 0.88
	var p = _pool[_next]; _next = (_next + 1) % _pool.size()
	p.stream = stream; p.pitch_scale = rate * randf_range(0.92, 1.08); p.volume_db = linear_to_db(clampf(vol, 0.0, 1.0)) + 2.0; p.play()

## Engine level 0..1 (0 silences it). Called every frame by the battle.
func engine(level: float) -> void:
	if not _engine: return
	if level <= 0.01: if _engine.playing: _engine.stop()
	else:
		if not _engine.playing and not muted: _engine.play()
		_engine.volume_db = lerpf(_engine.volume_db, linear_to_db(clampf(0.25 + level * 0.75, 0.0, 1.0)) - 3.0, 0.1)
		_engine.pitch_scale = 0.8 + 0.4 * level
