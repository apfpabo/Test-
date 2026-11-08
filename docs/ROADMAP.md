# Roadmap

How the current build lines up with [`CREATIVE_DIRECTION.md`](CREATIVE_DIRECTION.md) (the north star), plus standing art and design notes from playtest feedback. Update this file as features land.

## Standing design notes (owner feedback)

- **Grounded, not arcade.** Map fleets need momentum: they accelerate and turn gradually, and the bow must not snap to a new heading. Combat pace should feel like steel ships, not fighters.
- **Art reference: Rule the Waves 3.** Realistic top-down ship plans at true proportions, with one consistent paint and lighting scheme across hull, superstructure and turrets. No cartoon outlines or bright decorative colours. Wakes on both the map and in battle.
- **Ship variety by era and manufacturer**, as in Starsector. Several yards each field their own design per class, modelled on real ships (Iowa, Yamato, Bismarck, KGV, Fletcher and so on) under fictional names.
- **No boarding.** Capturing ships that strike their colours is fine.
- **Chart usability (done):** time acceleration, a draggable chart with recentre, deep zoom to ship level, one-click intercept lock, slower map pace.

## Current build vs. the creative direction

| Pillar | Current state | Gap |
| --- | --- | --- |
| Alternate Earth, global oceans | **Done (first pass):** a global ocean map from real coastlines, wrapping east-west, with 5 theatres, 32 real ports, 7 factions plus raiders, 16 survey sites (wrecks, abandoned bases, black sites), seasonal pack ice and A* sea routes | Port control and capture, more points of interest, regional weather, hand-crafted sites |
| Start 1944–52 tech, research-driven eras | 3 eras, 8 techs; RP from kills, captures and missions; enemies modernise over time | A 4th Modern era; RP from salvage, captured officers and documents, surveys and research enclaves; regional tech disparity |
| Ship classes | Escorts, cruisers, battleship, carriers, subs, freighter. One design per class, no yards | Battlecruisers, auxiliaries (tankers, ammunition ships, repair ships, troop transports), several manufacturers per class |
| Combat feel | Turrets with arcs, shell dispersion, armour (belt wears to no less than 40%), size-aware target choice for heavy guns, torpedoes, aircraft, missiles with SAM/CIWS, sonar detection. Interim pace fix: ships at 45% speed with slower turning, 60% slower reloads, ½×–4× battle time | Ammunition types and magazine depth, weather, time of day, radar horizon, formation discipline. A full pace rework built on real knots and turning circles |
| Logistics | Fuel, food, crew, wages, repairs | Ammunition supply, crew fatigue, supply lines, auxiliaries that resupply at sea |
| Factions and diplomacy | 7 factions modeled on the direction's archetypes, per-faction reputation, a fixed list of wars | Inter-faction relations, wars and ceasefires, commissions, betrayal, corporations, revolutionaries, enclaves |
| Found your own flag | Not started | Claim ports, run them, attract officers and ships |
| Campaign | 5 story missions at one port; bounties | Contracts at every port, a mission tracker, dynamic convoys, seasonal weather and ice, points of interest |
| Map movement | **Done:** momentum along planned routes, limited turn rate, pilotage speed in confined waters, wakes | — |

## Suggested order of work

0. **World map (done):** Alternate Earth oceans, ports, factions, surveys, ice, sea routes, map momentum and wakes.
1. **Feel and art pass (next):** Rule the Waves 3-style sprites at real scale, manufacturers and era designs per class, slower combat built on real knots and turning circles.
2. **Missions and diplomacy:** port contract boards, a mission tracker, faction relations with wars and ceasefires, commissions, NPC fleets fighting each other.
3. **Logistics depth:** ammunition and magazines, auxiliaries, crew fatigue, supply.
4. **World depth:** weather, more points of interest, regional technology disparity.
5. **Endgame:** found your own flag and claim ports. Add the Modern era.
