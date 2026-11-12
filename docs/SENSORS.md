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

Your own rings only (owner's request, 10 Nov 2026); R toggles them.

| | |
| --- | --- |
| Your lookouts see | Pale ring: about 555 km on a clear day under an average captain, much less at night, in fog or in heavy weather. |
| Your radar sees | Green ring with the turning beam, once you have the Fire-control radar research: at least 80% of the clear-day distance whatever the light (60% in a storm). On a clear day it is the same ring as the lookouts'; its worth shows at night and in the murk. |
| Your search aircraft see | Blue dashed ring, with a carrier in company and when aircraft can fly: three times her strike reach. |
| The captain | How sharp a watch is kept follows the captain of your flagship (owner's decision: sighting is not fixed, for you or for anyone else): level 1 sees 87% of the base distance, level 4 108%, level 8 136%; a flagship with no captain 80%. It scales the lookouts' and the radar's rings. The WEATHER chip's tooltip says who he is and what he is worth; the contact panel says the same of the other side's captain. |
| Being found | A hostile force notices you and gives chase at the same base distance times its own captain's watch, its weather and radar, and your signature (speed, running dark, a wireless call). This is no longer drawn; the Run dark button shows your signature as a percentage. |

## For the owner

- Wartime sonar could be made directional (a beam the escort has to sweep, and a blind arc astern), and wartime submarines could be given a short-range surface radar. Both would change how submarine actions play, so they are left for you to decide.

## Electronic war (12 Nov 2026)

The owner approved this from the comparison with Sea Power and NEBULOUS. Everything here needs the ECM research
(`BattleSim.can_jam`); submarines and motor torpedo boats carry none of it.

### Jamming

A ship's `jam_on` turns her jammer on.

- **Cover:** enemy radar sees her, and every ship of her side within `JAM_COVER` (2.5 km), at `JAM_K` (0.6) of its reach (`jam_mult`, used in `visible_to`).
- **Seekers:** an active seeker coming at a ship under that cover is 30% more easily led off, by the ECM roll and by chaff.
- **Cost:** a jammer is heard by any enemy set at `JAM_HEARD` (1.6) times its sight (`_radar_heard`), farther than a radar.
- **Other navies:** their captains jam once enemy radar has found them and there is a contact or missiles coming (`_emcon`).
- **Your ships:** switched from the ship menu (right-click). The flagship panel shows JAMMING.

### Chaff

Each ship carries `CHAFF_ROUNDS` (6).

- **When it fires:** by itself, when an anti-ship missile comes within `CHAFF_AT` (3 km), no more than once every `CHAFF_COOL` (10 s) (`fire_chaff`).
- **The cloud:** it hangs off her beam for `CHAFF_LIFE` (30 s), drawn as a drifting grey cloud.
- **The lure:** a missile closing within 1.5 km of her, with a cloud of her side within 700 m of her, is led off with chance `CHAFF_LURE` (0.4), less for a better seeker.
- **Better seekers:** the firer's `sk` is 0.1 per level of precision strike, plus 0.1 for cooperative engagement. Seeker quality also lowers the old ECM decoy roll.
- **A missile led off:** she runs on to the cloud and into the sea.

### Missile profiles

Each anti-ship missile is flown either as a sea-skimmer or as a high diver (`missile_profile`).

- **Sea-skimmer:** cannot be engaged by a SAM until she is within `SKIM_SEEN` (2.2 km) of the ship.
- **High diver:** seen far out, but close-in guns hit her at `HIGH_PD` (0.7) of their chance.
- **Which one is chosen:** a high dive at a ship with close-in guns and no SAMs; low over the sea otherwise.

### Not done

Radar modes, such as search against fire-control radar or a narrow search sector, are not done. They would add switching
for little in a game at this scale. This is for the owner to judge.

### Checks and measurements

- **Checks:** review_test `_ew`.
- **Measurement:** `tests/ew_measure.tscn` plays missile ships against each other with and without ECM.
  - 4 seeds: Burke and Sovremenny pairs fired 68 rounds of chaff, which led off 2 missiles; Adams and Kashin pairs fired 65 rounds, which led off 14.
  - Battle lengths were about the same with and without ECM.
- Untuned.
