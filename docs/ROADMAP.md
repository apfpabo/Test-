# Roadmap

How the current build lines up with [`CREATIVE_DIRECTION.md`](CREATIVE_DIRECTION.md) (the north star), plus standing art and design notes from playtest feedback. Update this file as features land.

## Standing design notes (owner feedback)

- **Grounded, not arcade.** Map fleets need momentum: they accelerate and turn gradually, and the bow must not snap to a new heading. Combat pace should feel like steel ships, not fighters.
- **Art reference: Rule the Waves 3.** Realistic top-down ship plans at true proportions, with one consistent paint and lighting scheme across hull, superstructure and turrets. No cartoon outlines or bright decorative colours. Wakes on both the map and in battle.
- **Ship variety by era and manufacturer** (first pass done), as in Starsector. Several yards each field their own design per class, modelled on real ships (Iowa, Yamato, Bismarck, KGV, Fletcher and so on) under fictional names.
- **No boarding.** Capturing ships that strike their colours is fine.
- **Turrets and superstructures (art pass 2, done 10 Nov 2026):** after feedback that adjacent turrets blended together, turrets lacked national character and superstructures were low-detail. Turrets and superstructures are now baked with height maps that Godot lights from the sun's direction, with shadows cast between levels. Gun mounts follow the shipbuilder's national style, and superstructures are built up by national school. Brief and notes: [`NEXT_ART_PASS.md`](NEXT_ART_PASS.md).
- **Playtest feedback, 10 Nov 2026 (done):** map zoom lag fixed; refit is planned and confirmed (undo, standard fit, weapon cards with stats); punchier gun sound and visuals, light AA no longer silent, engine and sea sound; wakes for every ship on the chart; damageable subsystems (magazines, machinery, steering, fire control, crew).
- **Playtest feedback, round 2 (done):**
  - "Battle stations" replaces "Action stations"; the aiming readout says "turning to bear" and "blocked by own ship".
  - The sea moves: travelling swell on the real clock, glints that ride it, cloud shadows.
  - Muzzle blasts spread outboard only, not back across the ship.
  - Guns fire barrel by barrel.
  - Gun reports have more bass, and crowd control keeps big fights distinct.
  - Ship engines and the sea along the hull are now audible in battle and on the chart.
  - Ships in a column follow the leader's track, so they stay off the land.
  - A damage schematic of the flagship shows mounts, magazines, machinery, steering and fire control.
  - The owner is sending a reference picture for the damage display; match it when it arrives.
- **Playtest feedback, round 3 (done):**
  - Pause menu on Esc: resume; restart or set up the battle again (quick battles); break off or quit (campaign).
  - Finite ammunition: shells per gun by calibre, AA bursts, one torpedo reload, missile salvos, SAM rounds, depth-charge patterns. Campaign ships keep what they have left; rearm in port.
  - Submarines: homing torpedoes can attack submerged boats; boats hear each other on passive sonar; escorts with sonar run in over a submerged contact to depth-charge it; Z drops depth charges by hand.
  - Missile launches show flame, a white cloud and dark smoke, and the booster burns for the first second and a half.
  - CIWS, Oerlikon and Bofors each have their own rate-of-fire sound.
  - The damage display follows War Thunder's: damage-only silhouette plus a badge row (crew, fires, machinery, ammunition, steering, fire control).
  - Recorded sound effects (owner approved CC0 and CC BY) replace the synthesised ones: gun reports by calibre, hits, splashes on misses, blasts, missile launches, depth charges, sea and engine-room loops; CIWS and light AA are built from recorded transients at each weapon's rate of fire. Sources: `godot/assets/sfx/CREDITS.md`.
- **Builds for the owner:** Windows 11. Send a zipped `.exe` from the Godot export.
- **Chart usability (done):** time acceleration, a draggable chart with recentre, deep zoom to ship level, one-click intercept lock, slower map pace.

## Current build vs. the creative direction

| Pillar | Current state | Gap |
| --- | --- | --- |
| Alternate Earth, global oceans | **Done (first pass):** a global ocean map from real coastlines, wrapping east-west, with 5 theatres, 32 real ports, 7 factions plus raiders, 16 survey sites (wrecks, abandoned bases, black sites), seasonal pack ice and A* sea routes | Port control and capture, more points of interest, regional weather, hand-crafted sites |
| Start 1944–52 tech, research-driven eras | 3 eras, 8 techs; RP from kills, captures and missions; enemies modernise over time | A 4th Modern era; RP from salvage, captured officers and documents, surveys and research enclaves; regional tech disparity |
| Ship classes | **Done (first pass):** 13 classes in 50 designs from 7 fictional yards, each modelled on a real ship (Iowa, Yamato, Bismarck, KGV, Littorio, Vanguard, Fletcher, Kagero, Narvik, Forrestal and others) with real dimensions, speed, armour and turning circle. Each flag buys from its own yards, and designs unlock by era | Battlecruisers, auxiliaries (tankers, ammunition ships, repair ships, troop transports), more Era III designs, a Modern era |
| Combat feel | **Subsystems done:** location-based hits on magazines (fire, flooding or detonation), machinery (power loss, engines stopped), steering gear (jammed rudder), fire control and crew spaces, repaired in part by damage control. **Pace rework done:** true-scale battles (1 unit = 1 m) with real knots, acceleration, rudder lag, speed loss in turns and real tactical diameters. Real reload times and turret training rates, a battle clock from ×1 to ×16 (default ×2), gun ranges compressed to about a fifth of real, salvo dispersion mostly in range, escape by opening the range, contact lost after 15 quiet minutes. Also turrets with arcs, armour, torpedoes, aircraft, missiles with SAM/CIWS, sonar | Ammunition types, weather, time of day, radar horizon and visibility, formation orders (line ahead, turn together) |
| Logistics | Fuel, food, crew, wages, repairs, rearming in port | Ammunition supply at sea, crew fatigue, supply lines, auxiliaries that resupply at sea |
| Factions and diplomacy | 7 factions modeled on the direction's archetypes, per-faction reputation, a fixed list of wars | Inter-faction relations, wars and ceasefires, commissions, betrayal, corporations, revolutionaries, enclaves |
| Found your own flag | Not started | Claim ports, run them, attract officers and ships |
| Campaign | 5 story missions at one port; bounties | Contracts at every port, a mission tracker, dynamic convoys, seasonal weather and ice, points of interest |
| Map movement | **Done:** momentum along planned routes, limited turn rate, pilotage speed in confined waters, wakes | — |

## Engine move (done)

The owner chose to move from the browser to **Godot 4**. The port is complete: battles, the world chart, ports (market, shipyard, refit, repairs and crew, officers, Admiralty, research), the command panel, encounters, surveys, aftermath and prizes, missions, saves, and a quick-battle screen. The browser build (`src/game.html`) now only serves as the art and data source for the bake tools.

Follow-ups: a display font and UI polish; touch controls; moving the plan renderer itself into Godot so art no longer depends on the browser (the height-map lighting already lives in Godot shaders, so this is now mostly a port of the canvas drawing code).

## Suggested order of work

**Art pass 2 is done** (turret separation, national turret styles, superstructures by school). Open art items: per-design superstructure overrides where the school's procedural form misses a class's signature (Takao's trunked funnel, KGV's hangar), tower shadows falling across turrets, and a playtest of the shadow strength. Next up is missions and diplomacy (item 2).

0. **World map (done):** Alternate Earth oceans, ports, factions, surveys, ice, sea routes, map momentum and wakes.
1. **Feel and art passes (done):** art pass 2 lit turrets and superstructures from height maps, with national styles. Before it: Rule the Waves 3-style deck plans at real scale, 7 yards and 50 era designs, combat rebuilt on real knots and turning circles. Follow-ups: playtest the ×2 default clock and the 1/5 range scale, add formation orders, and give the player helm orders by course as well as by rudder.
2. **Missions and diplomacy (next):** port contract boards, a mission tracker, faction relations with wars and ceasefires, commissions, NPC fleets fighting each other.
3. **Logistics depth:** ammunition and magazines, auxiliaries, crew fatigue, supply.
4. **World depth:** weather, more points of interest, regional technology disparity.
5. **Endgame:** found your own flag and claim ports. Add the Modern era.
