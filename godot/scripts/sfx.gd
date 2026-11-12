extends Node
## Recorded sound effects (godot/assets/sfx, built by tools/build_sfx.py from CC0 and CC BY sources; see CREDITS.md
## there): gun reports by calibre, hits, splashes, blasts, missile launches, CIWS and light AA bursts, and the sea and
## engine-room loops. Each event plays a recording, varied a little in pitch, louder the nearer the camera.
## Synthesised sound, rendered once at start-up and played through a small pool of players, louder the nearer the
## camera. A gun report is three parts: a low pressure thump (a falling sine), a sharp crack (bright noise, a few
## milliseconds) and a rolling tail (low-passed noise); heavier guns have a deeper thump and a longer tail. Light AA
## fire is a short pop. A looping engine-and-sea rumble follows the speed of the ships near the camera. A compressor
## and limiter on the master bus give the reports weight without clipping.

const RATE := 22050
var _cut: Array[float] = [160.0, 220.0, 350.0, 520.0, 700.0, 900.0, 1200.0, 1400.0]
var _banks: Array = []          # per cutoff: a few variations
var _pop: Array = []            # light AA pops
var _gat: Array = []            # CIWS gatling bursts
var _oer: Array = []            # Oerlikon rattles
var _bof: Array = []            # Bofors pom-poms
var _pool: Array[AudioStreamPlayer] = []
var _next = 0
var _engine: AudioStreamPlayer
var _recent: Array[float] = []   # start times of recent reports, to keep a big gunfight from turning to mush
var _rec: Dictionary = {}       # recorded banks by event: Array of AudioStream
var _room: AudioStreamPlayer     # engine room under the sea ambience
var _bed: AudioStreamPlayer      # open sea (Ambience bus)
var _bed2: AudioStreamPlayer
var _gull_p: AudioStreamPlayer
var _gulls: Array = []
var _gull_t := 4.0
var _amb := 0.0                  # ambience level asked for, 0..1
var _coast := 0.0                # how much land is near, 0..1: gulls call more often
var muted = false:
	set(v):
		muted = v
		if _engine: _engine.stream_paused = v
		if _room: _room.stream_paused = v
		AudioServer.set_bus_mute(0, v)   # everything, the sea and gulls included

func _ready() -> void:
	for c in _cut:
		var vars = []
		for k in 2: vars.append(_report(c))
		_banks.append(vars)
	for k in 3: _pop.append(_aa_pop())
	for k in 2: _gat.append(_auto(75.0, 0.45, 0.012, 900.0, true))
	for k in 2: _oer.append(_auto(7.5, 0.5, 0.03, 1400.0, false))
	for k in 2: _bof.append(_auto(4.0, 0.62, 0.06, 500.0, false))
	for i in 24:
		var p = AudioStreamPlayer.new(); p.bus = "Effects"; add_child(p); _pool.append(p)
	var names = {"gun_H": ["gun_heavy_1", "gun_heavy_2"], "gun_L": ["gun_heavy_1", "gun_heavy_2"], "gun_M": ["gun_medium"], "gun_S": ["gun_small"],
		"ping": ["ping"], "hit": ["hit_1", "hit_2"], "hit_big": ["hit_big"], "splash": ["splash_1", "splash_2", "splash_3", "splash_4"], "blast": ["blast"], "launch": ["launch"],
		"ciws": ["ciws_1", "ciws_2"], "aa20": ["oerlikon"], "aa40": ["bofors"]}
	for k in names:
		var bank = []
		for n in names[k]:
			var st = load("res://assets/sfx/%s.ogg" % n)
			if st != null: bank.append(st)
		if not bank.is_empty(): _rec[k] = bank
	_engine = AudioStreamPlayer.new(); _engine.volume_db = -80.0; _engine.bus = "Effects"; add_child(_engine)
	var amb = load("res://assets/sfx/sea_ambient.ogg")
	if amb: amb.loop = true; _engine.stream = amb
	else: _engine.stream = _engine_loop()
	_room = AudioStreamPlayer.new(); _room.volume_db = -80.0; _room.bus = "Effects"; add_child(_room)
	var er = load("res://assets/sfx/engine_room.ogg")
	if er: er.loop = true; _room.stream = er
	# the open sea and gulls, on the Ambience bus
	_bed = AudioStreamPlayer.new(); _bed.volume_db = -80.0; _bed.bus = "Ambience"; add_child(_bed)
	var bed = load("res://assets/sfx/sea_bed.ogg")
	if bed: bed.loop = true; _bed.stream = bed
	_bed2 = AudioStreamPlayer.new(); _bed2.volume_db = -80.0; _bed2.bus = "Ambience"; add_child(_bed2)
	var amb2 = load("res://assets/sfx/sea_ambient.ogg")
	if amb2: amb2.loop = true; _bed2.stream = amb2
	for i in 5:
		var g = load("res://assets/sfx/gull_%d.ogg" % (i + 1))
		if g: _gulls.append(g)
	_gull_p = AudioStreamPlayer.new(); _gull_p.bus = "Ambience"; add_child(_gull_p)
	var comp = AudioEffectCompressor.new(); comp.threshold = -16.0; comp.ratio = 4.0; comp.attack_us = 2000.0; comp.release_ms = 250.0; comp.gain = 4.0
	AudioServer.add_bus_effect(0, comp)
	# the level the owner chose (Settings.OUTPUT): the last of the 20 dB is made up here, ahead of a limiter that holds the peaks
	if ClassDB.class_exists("AudioEffectHardLimiter"):
		var lim = ClassDB.instantiate("AudioEffectHardLimiter"); lim.set("pre_gain_db", PRE_GAIN_DB); lim.set("ceiling_db", -1.0)
		AudioServer.add_bus_effect(0, lim)
	else:
		var amp = AudioEffectAmplify.new(); amp.volume_db = PRE_GAIN_DB; AudioServer.add_bus_effect(0, amp)
		AudioServer.add_bus_effect(0, AudioEffectLimiter.new())
	for i in 2:
		var mp := AudioStreamPlayer.new(); mp.bus = "Music"; mp.volume_db = -60.0; mp.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(mp); _mus.append(mp)
	for k in MUSIC:
		var mpath := "res://assets/music/%s.ogg" % MUSIC[k][0]
		if ResourceLoader.exists(mpath):
			var ms = load(mpath); ms.loop = false; _mus_streams[k] = ms
	# the sounds the owner chose (11 Nov 2026): one-shots (`cue`) and loops that follow what is on the screen (`layer`)
	for n in ["siren", "gong", "paper", "coins", "refit", "typewriter", "horn"]:   # (the last four chosen on 12 Nov 2026)
		var st = load("res://assets/sfx/%s.ogg" % n) if ResourceLoader.exists("res://assets/sfx/%s.ogg" % n) else null
		if st != null: _cues[n] = st
	for n in LAYERS:
		var path := "res://assets/sfx/%s_loop.ogg" % n
		if not ResourceLoader.exists(path): continue
		var st2 = load(path); st2.loop = true
		var pl := AudioStreamPlayer.new(); pl.stream = st2; pl.volume_db = -80.0; pl.bus = "Ambience" if LAYERS[n] else "Effects"; add_child(pl); _layers[n] = pl; _layer_want[n] = 0.0

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

## A recorded event: kind is gun_H / gun_L / gun_M / gun_S, hit, hit_big, splash, blast, launch, depth, torp_hit,
## ciws, aa20 or aa40. Falls back to the synthesised sounds if the recordings are missing.
func event(kind: String, vol: float, rate := 1.0) -> void:
	if muted or vol < 0.01: return
	match kind:
		"ping": _play(_rec.ping[0] if _rec.has("ping") else _ping_wav(), vol, rate); return   # the recorded ping (the owner's choice), else the synthesised one
		"depth": if _rec.has("splash"): _play(_rec.splash.pick_random(), vol, 0.55 * rate); if _rec.has("hit_big"): _play(_rec.hit_big[0], vol * 0.6, 0.6); return
		"torp_hit": if _rec.has("splash"): _play(_rec.splash.pick_random(), vol, 0.7 * rate); if _rec.has("hit_big"): _play(_rec.hit_big[0], vol, 0.8); return
	if not _rec.has(kind):
		boom(vol, {"gun_H": 160.0, "gun_L": 350.0, "gun_M": 520.0, "gun_S": 700.0, "hit": 600.0, "hit_big": 220.0, "blast": 160.0, "launch": 1200.0}.get(kind, 420.0), rate); return
	# the 8-inch and other L guns use the heavy report a little higher
	if kind == "gun_L": rate *= 1.15
	_play(_rec[kind].pick_random(), vol, rate)

## vol 0..1, freq picks the nearest bank (lower is heavier), rate scales playback speed.
## A sonar ping: a clear tone that rings and dies away, and a fainter one after it as if come back off the deep.
var _ping_s: AudioStreamWAV
func _ping_wav() -> AudioStreamWAV:
	if _ping_s != null: return _ping_s
	var n = int(RATE * 1.6); var out = PackedFloat32Array(); out.resize(n)
	for i in n:
		var t = float(i) / RATE
		var v = sin(TAU * 1450.0 * t) * exp(-t * 4.2) * minf(1.0, t * 400.0)
		if t > 0.5: v += sin(TAU * 1450.0 * (t - 0.5)) * exp(-(t - 0.5) * 5.0) * 0.22
		out[i] = v * 0.5
	_ping_s = _wav(out); return _ping_s

func boom(vol: float, freq := 420.0, rate := 1.0) -> void:
	if muted or vol < 0.01: return
	var best = 0
	for i in _cut.size(): if absf(_cut[i] - freq) < absf(_cut[best] - freq): best = i
	_play(_banks[best].pick_random(), vol, rate)

## Automatic fire: a train of individual reports at a rate of fire (rounds a second), each a sharp crack over a
## short thump; a gatling also has a continuous low growl and the whine of the rotating barrels.
func _auto(rate: float, dur: float, shot: float, cutoff: float, gatling: bool) -> AudioStreamWAV:
	var n = int(RATE * dur); var out = PackedFloat32Array(); out.resize(n)
	var a = exp(-TAU * cutoff / RATE); var y = 0.0; var hp = 0.0; var prev = 0.0; var nxt = 0.0; var t0 = -1.0; var ph = 0.0
	for i in n:
		var t = float(i) / RATE
		if t >= nxt and t < dur - shot * 2.0: t0 = t; nxt = t + (1.0 / rate) * randf_range(0.92, 1.08)
		var nz = randf_range(-1, 1); y = (1.0 - a) * nz + a * y; hp = 0.5 * (hp + nz - prev); prev = nz
		var u = t - t0; var e = exp(-u / shot) if t0 >= 0.0 else 0.0
		ph += TAU * (110.0 if gatling else 70.0) / RATE
		var v = (hp * 0.8 + y * 2.2) * e + sin(ph) * e * 0.5
		if gatling:
			var env = minf(1.0, t * 30.0) * minf(1.0, (dur - t) * 30.0)
			v = v * 0.7 + (y * 1.6 + sin(TAU * 960.0 * t) * 0.05) * env * 0.5   # the growl and the barrels' whine
		out[i] = clampf(v * 0.8, -1.0, 1.0)
	return _wav(out)

## A CIWS burst, an Oerlikon rattle or a Bofors pom-pom: wid picks which.
func auto_fire(wid: String, vol: float) -> void:
	if muted or vol < 0.01: return
	if _rec.has(wid): _play(_rec[wid].pick_random(), vol, randf_range(0.96, 1.04)); return
	var bank: Array = _gat if wid == "ciws" else (_bof if wid == "aa40" else _oer)
	_play(bank.pick_random(), vol, randf_range(0.95, 1.05))

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
## Ship sounds, level 0..1: the sea along the hull and the engine room under it, rising with speed. They fade in
## and out rather than starting or stopping dead. Called every frame by the battle and the chart.
## Engines and the sea play at this share of their level: the output level went up by half for the guns' sake, and
## the owner wanted engines and sea a tenth quieter than they were (1.5 x 0.6 = 0.9).
const BED := 0.49
var _eng_level := 0.0
func engine(level: float) -> void: _eng_level = clampf(level, 0.0, 1.0)

## The open sea all round: level 0..1, and coast 0..1 for how much land is near (gulls call more often there).
const PRE_GAIN_DB := 4.4
## Music (the owner's three pieces, 11 Nov 2026; assets/music, Music bus). `music("menu" | "chart" | "battle" | "")`
## says which should be playing; it is never cut: the piece that was playing fades out over some three seconds while
## the new one fades in, so going from the menu to the chart to a battle and back runs one into the next. A piece
## plays through, rests for a while in silence, and comes again (file, level in dB, seconds of rest).
const MUSIC := {"menu": ["lost_frontier", -3.0, 12.0], "chart": ["long_note_two", -4.0, 75.0], "battle": ["steel_and_seething", -8.0, 40.0]}
const MUSIC_IN := 3.5     # seconds for a piece to come in
const MUSIC_OUT := 3.0    # and to go out
var _mus: Array = []      # two players: one coming in or playing, one going out
var _mus_k := [0.0, 0.0]  # how far each is faded in, 0..1
var _mus_on := 0          # which of the two holds the piece wanted
var _mus_name := ""       # the piece wanted ("" for none)
var _mus_playing := ""    # the piece the wanted player was last given
var _mus_rest := 0.0
var _mus_streams := {}
func music(name: String) -> void: _mus_name = name if MUSIC.has(name) else ""
func _music_tick(dt: float) -> void:
	if _mus.is_empty(): return
	var cur: AudioStreamPlayer = _mus[_mus_on]
	if _mus_name != _mus_playing:   # another piece is wanted: this one starts on its way out, and the other player takes the new one
		_mus_on = 1 - _mus_on; cur = _mus[_mus_on]; _mus_playing = _mus_name; _mus_rest = 0.0
		cur.stop(); _mus_k[_mus_on] = 0.0
		if _mus_name != "" and _mus_streams.has(_mus_name): cur.stream = _mus_streams[_mus_name]; cur.volume_db = -60.0; cur.play()
	for i in 2:
		var pl: AudioStreamPlayer = _mus[i]; var want: bool = i == _mus_on and _mus_name != ""
		_mus_k[i] = move_toward(_mus_k[i], 1.0 if want else 0.0, dt / (MUSIC_IN if want else MUSIC_OUT))
		if pl.playing:
			var gain: float = float(MUSIC[_mus_name][1]) if want else float(pl.get_meta("gain", -4.0))
			if want: pl.set_meta("gain", gain)
			pl.volume_db = gain + linear_to_db(maxf(_mus_k[i] * _mus_k[i], 0.0001))   # the square: a fade that sounds even
			if not want and _mus_k[i] <= 0.0: pl.stop()
	# the piece has run its length: a rest, then it comes again (faded in afresh)
	if _mus_name != "" and not cur.playing and _mus_streams.has(_mus_name):
		_mus_rest += dt
		if _mus_rest >= float(MUSIC[_mus_name][2]): _mus_rest = 0.0; _mus_k[_mus_on] = 0.0; cur.volume_db = -60.0; cur.play()
var _cues := {}                  # one-shot sounds by name: siren (battle stations), gong (the bell: port and engine orders), paper (pages)
## name: true if it belongs to the weather (Ambience bus), false if to things on the screen (Effects bus)
const LAYERS := {"prop": false, "fire": false, "bubbles": false, "rain": true, "thunder": true, "storm": true}
var _layers := {}
var _layer_want := {}
## A one-shot: "siren", "gong", "paper", "coins" (a trade), "refit" (yard work done), "typewriter" (saved), "horn" (a ship joins).
func cue(name: String, vol := 0.5) -> void:
	if muted or not _cues.has(name): return
	_play(_cues[name], vol, 1.0)
## How loud a loop should be this frame, 0..1: "prop" (propeller aircraft near), "fire" (a ship burning near),
## "bubbles" (a ship going down), "rain", "thunder", "storm" (the weather). Ask every frame: a loop nobody asks for fades out.
func layer(name: String, level: float) -> void:
	if _layer_want.has(name): _layer_want[name] = maxf(float(_layer_want[name]), clampf(level, 0.0, 1.0))

func ambience(level: float, coast := 0.0) -> void: _amb = clampf(level, 0.0, 1.0); _coast = clampf(coast, 0.0, 1.0)

func _fade(pl: AudioStreamPlayer, lin: float, rate: float, dt: float, pitch := 1.0) -> void:
	if pl == null or pl.stream == null: return
	var target := linear_to_db(maxf(lin, 0.0001))
	if lin > 0.001 and not pl.playing and not muted: pl.volume_db = -60.0; pl.play()
	if not pl.playing: return
	pl.volume_db = move_toward(pl.volume_db, target, rate * dt * (2.5 if target > pl.volume_db else 1.0))
	pl.pitch_scale = pitch
	if lin <= 0.001 and pl.volume_db <= -55.0: pl.stop()

func _process(dt: float) -> void:
	_music_tick(dt)
	for n in _layers:   # the loops asked for since the last frame; then the asking starts again
		_fade(_layers[n], float(_layer_want[n]) * 0.5, 14.0, dt); _layer_want[n] = 0.0
	var e := _eng_level * BED
	_fade(_engine, e * 0.7, 18.0, dt, 0.85 + 0.25 * e)
	_fade(_room, e * 0.35, 18.0, dt, 0.9 + 0.2 * e)
	_fade(_bed, _amb * 0.55 * BED, 12.0, dt)
	_fade(_bed2, _amb * 0.3 * BED, 12.0, dt)
	if _amb > 0.05 and not _gulls.is_empty() and not muted:
		_gull_t -= dt * (0.2 + _coast * 1.6)
		if _gull_t <= 0.0:
			_gull_t = randf_range(6.0, 16.0)
			_gull_p.stream = _gulls.pick_random(); _gull_p.pitch_scale = randf_range(0.9, 1.1)
			_gull_p.volume_db = linear_to_db(_amb * (0.15 + 0.45 * _coast) * randf_range(0.6, 1.0)); _gull_p.play()
