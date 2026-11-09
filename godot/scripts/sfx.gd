extends Node
## Gunfire and explosions: decaying noise bursts through a low-pass filter, rendered once at start-up at a few
## pitches and played through a small pool of players, louder the nearer the camera.

const RATE := 22050
var _banks: Array[AudioStreamWAV] = []
var _cut: Array[float] = [160.0, 220.0, 350.0, 520.0, 700.0, 900.0, 1200.0, 1400.0]
var _pool: Array[AudioStreamPlayer] = []
var _next = 0
var muted = false

func _ready() -> void:
	for c in _cut: _banks.append(_burst(c, 1.1 if c < 400.0 else 0.6))
	for i in 16:
		var p = AudioStreamPlayer.new(); add_child(p); _pool.append(p)

func _burst(cutoff: float, dur: float) -> AudioStreamWAV:
	var n = int(RATE * dur); var data = PackedByteArray(); data.resize(n * 2)
	var a = exp(-TAU * cutoff / RATE); var y = 0.0; var y2 = 0.0
	for i in n:
		var t = float(i) / RATE
		var env = exp(-t * (3.5 if cutoff < 400.0 else 7.0)) * (minf(1.0, t * 200.0))
		y = (1.0 - a) * randf_range(-1, 1) + a * y; y2 = (1.0 - a) * y + a * y2
		var s = clampi(int(y2 * env * 3.2 * 32767.0), -32767, 32767)
		data.encode_s16(i * 2, s)
	var w = AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = data
	return w

## vol 0..1, freq picks the nearest bank (lower is heavier), rate scales playback speed.
func boom(vol: float, freq := 420.0, rate := 1.0) -> void:
	if muted or vol < 0.01: return
	var best = 0
	for i in _cut.size(): if absf(_cut[i] - freq) < absf(_cut[best] - freq): best = i
	var p = _pool[_next]; _next = (_next + 1) % _pool.size()
	p.stream = _banks[best]; p.pitch_scale = rate * randf_range(0.9, 1.1); p.volume_db = linear_to_db(clampf(vol, 0.0, 1.0)); p.play()
