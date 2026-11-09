# Roadmap

How the current build lines up with [`CREATIVE_DIRECTION.md`](CREATIVE_DIRECTION.md) (the north star), plus standing art and design notes from playtest feedback. Update this file as features land.

## Standing design notes (owner feedback)

- **Grounded, not arcade.** Map fleets need momentum: they accelerate and turn gradually, and the bow must not snap to a new heading. Combat pace should feel like steel ships, not fighters.
- **Art reference: Rule the Waves 3.** Realistic top-down ship plans at true proportions, with one consistent paint and lighting scheme across hull, superstructure and turrets. No cartoon outlines or bright decorative colours. Wakes on both the map and in battle.
- **Ship variety by era and manufacturer** (first pass done), as in Starsector. Several yards each field their own design per class, modelled on real ships (Iowa, Yamato, Bismarck, KGV, Fletcher and so on) under fictional names.
- **No boarding.** Capturing ships that strike their colours is fine.
- **Chart usability (done):** time acceleration, a draggable chart with recentre, deep zoom to ship level, one-click intercept lock, slower map pace.

## Current build vs. the creative direction

| Pillar | Current state | Gap |
| --- | --- | --- |
| Alternate Earth, global oceans | **Done (first pass):** a global ocean map from real coastlines, wrapping east-west, with 5 theatres, 32 real ports, 7 factions plus raiders, 16 survey sites (wrecks, abandoned bases, black sites), seasonal pack ice and A* sea routes | Port control and capture, more points of interest, regional weather, hand-crafted sites |
| Start 1944–52 tech, research-driven eras | 3 eras, 8 techs; RP from kills, captures and missions; enemies modernise over time | A 4th Modern era; RP from salvage, captured officers and documents, surveys and research enclaves; regional tech disparity |
| Ship classes | **Done (first pass):** 13 classes in 50 designs from 7 fictional yards, each modelled on a real ship (Iowa, Yamato, Bismarck, KGV, Littorio, Vanguard, Fletcher, Kagero, Narvik, Forrestal and others) with real dimensions, speed, armour and turning circle. Each flag buys from its own yards, and designs unlock by era | Battlecruisers, auxiliaries (tankers, ammunition ships, repair ships, troop transports), more Era III designs, a Modern era |
| Combat feel | **Pace rework done:** true-scale battles (1 unit = 1 m) with real knots, acceleration, rudder lag, speed loss in turns and real tactical diameters. Real reload times and turret training rates, a battle clock from ×1 to ×16 (default ×2), gun ranges compressed to about a fifth of real, salvo dispersion mostly in range, escape by opening the range, contact lost after 15 quiet minutes. Also turrets with arcs, armour, torpedoes, aircraft, missiles with SAM/CIWS, sonar | Ammunition types and magazine depth, weather, time of day, radar horizon and visibility, formation orders (line ahead, turn together) |
| Logistics | Fuel, food, crew, wages, repairs | Ammunition supply, crew fatigue, supply lines, auxiliaries that resupply at sea |
| Factions and diplomacy | 7 factions modeled on the direction's archetypes, per-faction reputation, a fixed list of wars | Inter-faction relations, wars and ceasefires, commissions, betrayal, corporations, revolutionaries, enclaves |
| Found your own flag | Not started | Claim ports, run them, attract officers and ships |
| Campaign | 5 story missions at one port; bounties | Contracts at every port, a mission tracker, dynamic convoys, seasonal weather and ice, points of interest |
| Map movement | **Done:** momentum along planned routes, limited turn rate, pilotage speed in confined waters, wakes | — |

## Engine move (in progress)

The owner chose to move from the browser to **Godot 4**, battle first. Status:

- **Done:** Godot project in `godot/` with the full battle simulation ported (`battle_sim.gd`), battle screen with a water shader, ship lighting shader, wakes, smoke, damage, HUD, reticle, minimap, sound, camera panning, and a battle setup screen with presets and a custom squadron builder. Art and data are baked from the browser build by `tools/bake_assets.js`.
- **Next:** port the world map, ports, missions and campaign state; then retire `src/game.html`. Choose a display font and a UI theme. Desktop export presets. Consider moving the plan renderer itself into Godot so art no longer depends on the browser.

## Suggested order of work

0. **World map (done):** Alternate Earth oceans, ports, factions, surveys, ice, sea routes, map momentum and wakes.
1. **Feel and art pass (done):** Rule the Waves 3-style deck plans at real scale, 7 yards and 50 era designs, combat rebuilt on real knots and turning circles. Follow-ups: playtest the ×2 default clock and the 1/5 range scale, add formation orders, and give the player helm orders by course as well as by rudder.
2. **Missions and diplomacy (next):** port contract boards, a mission tracker, faction relations with wars and ceasefires, commissions, NPC fleets fighting each other.
3. **Logistics depth:** ammunition and magazines, auxiliaries, crew fatigue, supply.
4. **World depth:** weather, more points of interest, regional technology disparity.
5. **Endgame:** found your own flag and claim ports. Add the Modern era.
