extends Node
## Weather and the time of day (autoload `Weather`). Both come from the place and the calendar alone, so nothing is
## saved: storm systems are slow noise drifting east, rougher in high latitudes and in each hemisphere's winter, with
## a monsoon in the tropics in summer; fog lies over cold, quiet water; the sun follows the longitude and the season.
## The chart reads it for speed, fuel, storm damage and how far a force can see; a battle is fought in the weather
## of the place where contact was made (`battle()`). See docs/WEATHER.md.

const SEA := ["calm", "a moderate sea", "a rough sea", "a storm"]
const SEA_SHORT := ["Calm", "Moderate", "Rough", "Storm"]
var _n := FastNoiseLite.new()
var _f := FastNoiseLite.new()
var force = null       # tests and quick battles: a fixed {sea, fog, night, moon} instead of the model

func _ready() -> void:
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; _n.frequency = 1.0; _n.seed = 41; _n.fractal_octaves = 3
	_f.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; _f.frequency = 1.0; _f.seed = 97; _f.fractal_octaves = 2

func now() -> float:
	var G: Dictionary = Campaign.G
	return float(G.get("day", 1)) + float(G.get("dayF", 0.0)) if not G.is_empty() else 1.0

## How wintry it is at this latitude on this day, -1 (high summer) to 1 (midwinter). The calendar starts 1 March.
func winter(y: float, t: float) -> float:
	var yr := fposmod((t + 59.0) / 365.0, 1.0)             # 0 at 1 January
	var north := cos(yr * TAU - 0.26)                       # 1 in mid-January
	return north if Campaign.y_lat(y) >= 0.0 else -north

## Storminess 0..1 at a place and time.
func storm(x: float, y: float, t: float) -> float:
	var lat := absf(Campaign.y_lat(y)); var w := winter(y, t)
	var base := 0.3 + 0.22 * smoothstep(30.0, 62.0, lat) + 0.12 * w * smoothstep(20.0, 45.0, lat) + 0.14 * maxf(0.0, -w) * (1.0 - smoothstep(8.0, 24.0, lat))
	# the pattern is periodic in x so it joins across the chart's east-west seam
	var a: float = (x - t * 55.0) / float(Campaign.MW) * TAU; var r: float = float(Campaign.MW) / TAU / 620.0
	var n := _n.get_noise_3d(cos(a) * r, sin(a) * r + y / 620.0, t / 5.0 + y / 4000.0)
	return clampf(base + n * 0.62, 0.0, 1.0)
func sea(x: float, y: float, t: float) -> int:
	var v := storm(x, y, t)
	return 0 if v < 0.38 else (1 if v < 0.58 else (2 if v < 0.76 else 3))
## Fog as a smooth field (for the chart), and whether it is foggy at a place (above one half).
func fog_v(x: float, y: float, t: float) -> float:
	var lat := absf(Campaign.y_lat(y)); var a: float = (x - t * 20.0) / float(Campaign.MW) * TAU; var r: float = float(Campaign.MW) / TAU / 380.0
	var n := _f.get_noise_3d(cos(a) * r, sin(a) * r + y / 380.0, t / 2.5)
	return clampf((n - (0.5 - 0.22 * smoothstep(35.0, 65.0, lat))) * 5.0 + 0.5, 0.0, 1.0) * (1.0 - smoothstep(0.5, 0.6, storm(x, y, t)))
func fog(x: float, y: float, t: float) -> bool: return fog_v(x, y, t) > 0.5

## Local time in hours at a longitude, and the hours of sunrise and sunset at a latitude and season.
func hour(x: float, t: float) -> float: return fposmod(fposmod(t, 1.0) * 24.0 + Campaign.x_lon(x) / 15.0, 24.0)
func half_day(y: float, t: float) -> float: return clampf(6.0 - 4.2 * winter(y, t) * sin(deg_to_rad(absf(Campaign.y_lat(y)))) , 1.5, 10.5)
## Darkness 0 (day) to 1 (night), with an hour of twilight either side.
func dark(x: float, y: float, t: float) -> float:
	var h := hour(x, t); var hd := half_day(y, t)
	return smoothstep(hd - 0.5, hd + 0.7, absf(h - 12.0))
func night(x: float, y: float, t: float) -> bool: return dark(x, y, t) > 0.5
## The moon: 0 new to 1 full, on a 29.5-day round.
func moon(t: float) -> float: return 0.5 - 0.5 * cos(t / 29.5 * TAU)

## Everything about the weather at a place and time, for the chart and for a battle fought there.
func at(x: float, y: float, t := -1.0) -> Dictionary:
	if t < 0.0: t = now()
	var w := {"sea": sea(x, y, t), "fog": fog(x, y, t), "night": night(x, y, t), "dark": dark(x, y, t), "moon": moon(t), "hour": hour(x, t)}
	if force != null: w.merge(force, true)
	w.vis_km = vis_km(w); w.text = describe(w)
	return w
## How far a lookout sees, in chart kilometres (a clear day shows a force at the horizon and its smoke beyond).
func vis_km(w: Dictionary) -> float:
	var v: float = [90.0, 75.0, 45.0, 20.0][int(w.sea)]
	if w.fog: v = 12.0
	if w.night: v = minf(v, 18.0 + 22.0 * float(w.moon))
	return v
func describe(w: Dictionary) -> String:
	var s: String = SEA_SHORT[int(w.sea)]
	if w.fog: s += " · fog"
	if w.night: s += " · night" + (" (bright moon)" if float(w.moon) > 0.7 else (" (no moon)" if float(w.moon) < 0.25 else ""))
	return s

# ------------------------------------------------------------------ on the chart
## Speed in this sea as a share of speed in a calm: small ships suffer first.
func speed_mult(w: Dictionary, ships: Array) -> float:
	var small := false
	for s in ships: if float(Campaign.hull(s).t) < 2500.0 and Campaign.hull(s).kind != "sub": small = true
	return [1.0, 1.0, 0.9 if small else 0.95, 0.65 if small else 0.8][int(w.sea)]
func fuel_mult(w: Dictionary) -> float: return [1.0, 1.0, 1.12, 1.35][int(w.sea)]
## How far this side makes contact, as a share of clear daylight: lookouts in the murk, or radar that does not care.
func contact_mult(w: Dictionary, radar: bool) -> float:
	var k := clampf(float(w.vis_km) / 75.0, 0.2, 1.0)
	return maxf(k, 0.8 if int(w.sea) < 3 else 0.6) if radar else k
## Whether aircraft can fly: not in a storm or fog, and by night only the jets of the missile age.
func air_ok(w: Dictionary, jets: bool) -> bool: return int(w.sea) < 3 and not w.fog and (not w.night or jets)

# ------------------------------------------------------------------ in battle
## The weather a battle is fought in: how far the eye and the radar reach in battle metres (0 = no limit).
func battle(w: Dictionary) -> Dictionary:
	var vis := 0.0
	if int(w.sea) == 2: vis = 9000.0
	if int(w.sea) == 3: vis = 5000.0
	if w.fog: vis = 2500.0
	if w.night:
		var nv: float = lerpf(3000.0, 5200.0, float(w.moon)) * [1.0, 0.95, 0.8, 0.6][int(w.sea)] * (0.6 if w.fog else 1.0)
		vis = nv if vis <= 0.0 else minf(vis, nv)
	return {"sea": int(w.sea), "fog": bool(w.fog), "night": bool(w.night), "moon": float(w.moon), "vis": vis, "radar": 9500.0 * (0.8 if int(w.sea) == 3 else 1.0), "text": describe(w)}
const CLEAR := {"sea": 0, "fog": false, "night": false, "moon": 0.5, "vis": 0.0, "radar": 9500.0, "text": "Calm"}
