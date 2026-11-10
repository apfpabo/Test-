# Sensors: lookouts, radar and sonar

Owner request, 10 Nov 2026: show how far radar and sonar reach, explain how sighting works on the chart and in battle, check whether real sets look all round or in one direction, and animate the radar's sweep (toggle). Rules: `godot/scripts/battle_sim.gd` (`has_radar`, `phased`, `sonar_range`, `eye_sees`, `_radar_plot`, `visible_to`), `campaign.gd` (`sight_radius`, `found_radius`, `_sighting`). Display: `battle.gd` (`_sensors`), `world_map.gd` (`Marks._sensors`). Toggle: **R** on the chart and in battle, or Settings, "Sensor ranges". Checked by `tests/review_test.tscn`; screenshots from `tests/shot_sensors.tscn` (chart) and `tests/shot_weather.tscn -- <dir> night 0.06` (battle).

## What the real sets did

| Set | How it looks | Sources |
| --- | --- | --- |
| Wartime search radar (SG, SK, Type 271 and the like) | **Directional.** One narrow beam on an aerial that turns mechanically round the horizon, 4 to 12 turns a minute for the SG. The plan position indicator (the round screen with the turning line) paints each echo as the beam crosses it, and the echo fades until the beam comes round again. So it covers 360°, but it sees any one bearing only once a turn. The SG reached about 15 nautical miles (28 km) against a destroyer; big ships show farther. | [SG radar](https://en.wikipedia.org/wiki/SG_radar), [US radar of WW2 (NavWeaps)](https://navweaps.com/Weapons/WNUS_Radar_WWII.php) |
| Fire-control radar | Directional and narrow: it is trained on one target with the director, and sees nothing else. | [NavWeaps](https://navweaps.com/Weapons/WNUS_Radar_WWII.php) |
| Cold War search radar | Still a rotating aerial: seen "once during each 360 degree rotation of the antenna". | [AN/SPY-1 (FAS)](https://man.fas.org/dod-101/sys/ship/weaps/an-spy-1.htm) |
| Phased arrays (SPY-1 of the Aegis ships, later AESA sets) | **All round at once.** Four fixed faces steer their beams electronically, with no turning aerial: search and tracking in every direction continuously. | [AN/SPY-1 (FAS)](https://man.fas.org/dod-101/sys/ship/weaps/an-spy-1.htm), [GlobalSecurity](https://www.globalsecurity.org/military/systems/ship/systems/an-spy-1.htm) |
| Wartime active sonar (ASDIC, QC) | **Directional.** A "searchlight" beam trained by hand and stepped round a sector ping by ping; contact was lost as the ship ran in over the boat to drop her charges. | [History of sonar (DTIC)](https://apps.dtic.mil/sti/pdfs/ADA517563.pdf) |
| Scanning sonar (post-war hull sets, cylindrical arrays) | **All round**: a cylinder of elements transmits and listens in every direction, except the arc astern masked by the ship's own screws (the baffles). | [History of sonar (DTIC)](https://apps.dtic.mil/sti/pdfs/ADA517563.pdf) |
| Submarines | Listen far more than they ping (hydrophones, later bow and flank arrays). Wartime boats did carry a small surface radar when surfaced. | general reference; not checked against a source this round |

The search results did not give a firm figure for the astern blind arc of any one sonar, so none is quoted here.

## In battle

| | |
| --- | --- |
| Lookouts | By day in a calm or moderate sea there is no limit. Otherwise the eye reaches as far as the weather and the light allow (docs/WEATHER.md: rough 9 km, storm 5 km, fog 2.5 km, night 3 to 5.2 km). A ship that has just fired or is burning shows at twice that. Pale ring. |
| Radar | A surface ship of a side that has the Fire-control radar research (or a radar fitted in Refit) sees 9.5 km whatever the light (7.6 km in a storm; more with Mk II radar and a data link). **Submarines carry no radar** (owner's decision). Green ring. |
| The sweep | Sets of the first two eras turn: one turn every ten battle seconds (six a minute). An enemy inside radar range but beyond the eye's reach is not a ship in sight but **a contact on the plot**: she shows as the beam crosses her bearing and fades until it comes round again, with a green mark where she was last painted. She has no wake or shadow you can see. Your guns still use the plot: she can be targeted throughout. |
| Phased arrays | With the Aegis research the arrays look every way at once: no beam turns, and a radar contact is held all the time. |
| Sonar | A ship with sonar hears a submerged boat within 1.5 km (2.4 km with the Sonar research, more with helicopters and a better set fitted); a submarine hears another at 1.4 times that; anything within 500 m is found. All round: the game does not model the wartime searchlight beam or the baffles astern (see "For the owner"). Blue ring. |

The rings are drawn for every ship of yours that is in action, the flagship's brighter and labelled.

## On the chart

| | |
| --- | --- |
| You see fleets within | Green ring: about 550 km on a clear day, less in weather and darkness, more with radar in the murk and far more with a carrier's search aircraft. Fleets beyond it are hidden unless a friend, a port or a structure of yours has them in sight. With the radar research a beam turns inside it. |
| A hostile force finds you within | Red dashed ring: how far off a force hostile to you notices you and gives chase, with lookouts alone. The dotted ring is the same for a force with radar (a power of Era II or later), when that is farther. Both shrink in weather and darkness; running dark and slow steaming shrink them further, and a wireless call widens them for a day. |

## For the owner

- On a clear day a hostile force notices you at about 890 km while you see fleets at 555 km, so a patrol can be steering for you before you can see it. The numbers are the existing rules (`160` and `SIGHT = 100` map units); I have only drawn them. Say if you want them matched.
- Wartime sonar could be made directional (a beam the escort has to sweep, and a blind arc astern), and wartime submarines could be given a short-range surface radar. Both would change how submarine actions play, so they are left for you to decide.
