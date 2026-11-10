# Weather and night

`godot/scripts/weather.gd` (autoload `Weather`). Nothing is saved: weather and light come from the place and the calendar. Checked by `tests/weather_test.tscn`; screenshots from `tests/shot_weather.tscn -- <dir> <night|moon|storm|fog> [zoom]`.

## The model

- **Sea state** 0 to 3 (calm, moderate, rough, storm) from slow noise drifting east: rougher in high latitudes and in each hemisphere's winter, with a monsoon in the tropics in summer. Over a year about half the sea is calm, a third moderate, an eighth rough and 3% storm.
- **Fog** over quiet water, commoner in the cold.
- **Day and night** from the longitude and the hour, with day length by latitude and season, and an hour of twilight. The **moon** runs a 29.5-day round.
- `Weather.at(x, y)` gives all of it; `Weather.force` fixes it for tests and quick battles.

## On the chart

| | |
| --- | --- |
| Speed | Rough: 95% (90% with a ship under 2,500 tons). Storm: 80% (65%). |
| Fuel | +12% rough, +35% in a storm. |
| Storm damage | Ships under 2,500 tons lose 1 to 3% of hull for each day under way in a storm. |
| Contact | Each side finds the other only as far as it sees: by eye a share of the clear-day distance (26% on a dark night, 16% in fog), by radar at least 80% (60% in a storm). You have radar with the Fire-control radar research; a power has it from Era II; raiders never. A hunter that cannot see you does not chase. |
| Aircraft | No flying in a storm or fog, and only jets by night: a carrier then reaches no farther than the guns, and strikes on structures are refused. |
| Display | Cloud, storm and fog and the night side of the world over the chart (`shaders/chart_weather.gdshader`, from a grid refreshed every eighth of a day); a WEATHER chip in the top bar with the effects on hover; the reach rings shrink with visibility. |

## In battle

A battle is fought in the weather and light of the place where contact was made (`Weather.battle`, passed as `weather` in the battle's setup and kept in `BattleSim.wx`).

- **Sight.** By day in a calm or moderate sea there is no limit. Rough 9 km, storm 5 km, fog 2.5 km; at night 3 km (no moon) to 5.2 km (full), less in bad weather. A ship is seen by a side only within that distance of one of its ships, or within radar range (9.5 km) of one that has radar. A ship that has fired in the last six seconds, or is on fire, shows at twice the distance.
- **Unseen ships** are not drawn, cannot be targeted, and drop off the lists and the minimap. A side with nothing in sight steers for the enemy's last position (`nearest_any`).
- **Gunnery.** Spread +10% for each step of sea state, and +35% at night for a ship without radar.
- **Speed.** Ships under 3,000 tons lose 5% for each step of sea state.
- **Aircraft** as on the chart.
- **Look.** The sea darkens to blue-black with the moon's path on it, steepens and shows whitecaps as it rises (`water.gdshader`: `sea_state`, `night`, `moon`); the scene is darkened by a `CanvasModulate` while fire, flashes and aiming marks keep their own canvas layers; `shaders/veil.gdshader` hides what lies beyond your ships' sight, with fog banks and driving rain.
- Quick battles choose the weather and the hour on their screen.
