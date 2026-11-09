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
- **Playtest feedback, round 4 (done):**
  - Settings (title screen and pause menu): master, effects and ambience volume; battle minimap small, medium or large.
  - Sound:
    - Chart engine sound is quieter.
    - Ship sounds fade instead of stopping dead.
    - Earshot in battle is measured in metres, so zooming in no longer cuts sounds off.
    - A sea bed and gulls play on the chart (more gulls near land) and at sea in battle.
  - Barrels in a salvo fire further apart.
  - Struck ships cease fire.
  - The flagship panel shows depth-charge patterns and rack reloading.
  - Hovering the damage display explains each badge and the damage colours.
  - Battle islands are shaded terrain (beach, scrub, woods, rock, peaks, shallows and surf), with the coastline kept to the collision outline.
  - Shell ballistics:
    - Each shell's penetration depends on its weight and range.
    - It meets belt armour made thicker by the angle of impact, or the thinner deck when it plunges.
    - Results: ricochet, no penetration (splinters), over-penetration, or penetration (full damage, subsystems).
    - Markers name the result on hits by and on your ships.
- **Starting origins (done):** the eight origins the owner wrote ([`LORE.md`](LORE.md)) replace the three old starts. Each has its own ships, money, standing, captain and lasting conditions (limited services at an old flag, hunter groups, trade, evasion and prize perks, intelligence as research points). Navy origins let the player choose the navy. LORE.md lists what the origins promise but the game doesn't do yet.
- **Playtest feedback, round 5 (done, 9 Nov 2026):**
  - A fictional world replaces the real Earth (the owner chose candidate C of four). Old saves are refused (save version 4) with a note on the title screen.
  - Regional faction names follow the new map (owner's decision): Hesperian Concord, Vargan Directorate, Halcyon Federation, Tarsene Free Republic. The yards that named real places are renamed too (Calder & Wexmouth, Strelsk-Werke, Korvagrad Admiralty, Amakura Arsenal, Cantieri del Corvo).
  - Realistic engagement radius on the chart: contact at each side's reach instead of on collision. Guns about 90 km, anti-ship missiles about 120 km, escort carriers 250 km, fleet carriers 350 km. Your reach and hostile missile or carrier groups' reach show as dashed rings; the contact panel says at what range and whose ships found whom. A force that has been met stays quiet until the range opens past its reach again. Follow-up: battles still open at the usual distance, so a missile or carrier contact doesn't yet start the battle at long range.
  - The chart's land is shaded terrain in the battle islands' palette (owner's question: could the islands' look be used on the world map?), with climate by latitude and fine detail when zoomed in.
- **Foundational lore (done, 9 Nov 2026):** the owner's lore for the new world is in the game: a codex (title screen and Command panel), 1946 backstories on the origin screens, faction descriptions and attitudes, the mysteries as survey sites and port rumours, raider grounds and garrisons from the March 1946 situation. [`LORE.md`](LORE.md) lists where lore and game still differ (the armistice above all).
- **Playtest feedback, round 6 (done, 9 Nov 2026):**
  - Chart movement: fleets now move the way their bows point and steer onto the route through a turning circle, so they no longer slide sideways while the bow swings. A hard turn costs about a third of the speed instead of nearly all of it. `tests/move_test.tscn` checks slip, speed in a turn and a long passage without grounding.
  - Contact: any hostile force inside gun range makes contact, even one met earlier (a chasing raider could sit alongside without a fight).
  - Esc on the chart opens a pause menu: resume, Command, Codex, settings, save and exit to title, save and quit.
  - The Sound button mutes everything (sea and gulls included) and says whether sound is on.
  - Chart sound is quieter: the sea bed at about half, engines at half.
  - The Command panel labels the hull bar ("Hull 70%"), with a tooltip, and the bar no longer stretches into a dark box.
  - Pack ice reads as ice: a broken white edge, loose floes off it, and a "PACK ICE · MAR LIMIT" label that follows the season.
  - Gunnery: director-style salvos. Turrets fire together, rippling fore to aft a fraction of a second apart, in alternating half-salvos (one gun of each turret, then the others half a reload later), as 1940s battleships fired while spotting the fall of shot.
  - The world follows the owner's lore: see [`LORE.md`](LORE.md) ("Changed to follow the lore").
  - The armistice (owner approved): warships engage you on sight only at standing -60, after an incident (you opened fire on that flag: three months), or as an origin's declared target. Ports close below -10. The standing list says which flags are at war with you, which ports are closed, and for how long an incident lasts.
  - Question answered: the lines that stop short of the range ring in battle are shells still in flight (the white dots at their heads); the ring is the guns' maximum range.
- **Builds for the owner:** Windows 11. Send a zipped `.exe` from the Godot export.
- **Chart usability (done):** time acceleration, a draggable chart with recentre, deep zoom to ship level, one-click intercept lock, slower map pace.

## Current build vs. the creative direction

| Pillar | Current state | Gap |
| --- | --- | --- |
| Alternate Earth, global oceans | **Done (fictional world, 9 Nov 2026):** a generated and hand-tuned world (seed 16, chosen by the owner) that keeps the theatres' strategic shapes: the Hesperian Ocean and the Rime, the enclosed Cradle and Sable Seas behind the Tarsene Gate, the Throat and the Kessel Canal, the Monsoon Ocean, the Halcyon Ocean's island chains and the Howling Seas. Named straits and canals, shaded terrain, 34 fictional ports, 7 factions plus raiders, 20 survey sites (including the mysteries of the owner's lore), seasonal pack ice bent by currents, A* sea routes. 266 inland sites recorded for future land structures. See [`WORLD.md`](WORLD.md) | Port control and capture, land structures, more points of interest, regional weather, hand-crafted sites |
| Start 1944–52 tech, research-driven eras | 3 eras, 8 techs; RP from kills, captures and missions; enemies modernise over time | A 4th Modern era; RP from salvage, captured officers and documents, surveys and research enclaves; regional tech disparity |
| Ship classes | **Done (first pass):** 13 classes in 50 designs from 7 fictional yards, each modelled on a real ship (Iowa, Yamato, Bismarck, KGV, Littorio, Vanguard, Fletcher, Kagero, Narvik, Forrestal and others) with real dimensions, speed, armour and turning circle. Each flag buys from its own yards, and designs unlock by era | Battlecruisers, auxiliaries (tankers, ammunition ships, repair ships, troop transports), more Era III designs, a Modern era |
| Combat feel | **Subsystems done:** location-based hits on magazines (fire, flooding or detonation), machinery (power loss, engines stopped), steering gear (jammed rudder), fire control and crew spaces, repaired in part by damage control. **Pace rework done:** true-scale battles (1 unit = 1 m) with real knots, acceleration, rudder lag, speed loss in turns and real tactical diameters. Real reload times and turret training rates, a battle clock from ×1 to ×16 (default ×2), gun ranges compressed to about a fifth of real, salvo dispersion mostly in range, escape by opening the range, contact lost after 15 quiet minutes. Also turrets with arcs, armour, torpedoes, aircraft, missiles with SAM/CIWS, sonar | Ammunition types (AP/HE), weather, time of day, radar horizon and visibility, formation orders (line ahead, turn together) |
| Logistics | Fuel, food, crew, wages, repairs, rearming in port | Ammunition supply at sea, crew fatigue, supply lines, auxiliaries that resupply at sea |
| Factions and diplomacy | **Done (second pass, 9 Nov 2026):** nine powers (the Ombrian Protectorate and Outer Isles League added); relations that drift and react to lore events; the Oceanic Entente and Continental Compact coalitions, with allies joining wars; wars that wear down into armistices; ports changing hands in sieges; fleets of warring powers, patrols and raiders fighting at sea; contracts (deliveries, raider hunts, surveys, war patrols, escorts, smuggling); commissions and letters of marque with betrayal; story chains from seven powers. See [`DIPLOMACY.md`](DIPLOMACY.md) | Owner lore for the two new flags; peace treaties; claiming ports yourself (step 5) |
| Found your own flag | Not started | Claim ports, run them, attract officers and ships |
| Campaign | Story chains from seven powers (the Concord's five, three each from six others); bounties; contracts at every port with a tracker and gold markers on the chart | Dynamic convoys, seasonal weather, more hand-crafted points of interest |
| Map movement | **Done:** momentum along planned routes, limited turn rate, pilotage speed in confined waters, wakes | — |

## Engine move (done)

The owner chose to move from the browser to **Godot 4**. The port is complete: battles, the world chart, ports (market, shipyard, refit, repairs and crew, officers, Admiralty, research), the command panel, encounters, surveys, aftermath and prizes, missions, saves, and a quick-battle screen. The browser build (`src/game.html`) now only serves as the art and data source for the bake tools.

Follow-ups: a display font and UI polish; touch controls; moving the plan renderer itself into Godot so art no longer depends on the browser (the height-map lighting already lives in Godot shaders, so this is now mostly a port of the canvas drawing code).

## Suggested order of work

**The fictional world map is done** ([`WORLD.md`](WORLD.md)), so is the owner's foundational lore, and the first pass of diplomacy and contracts ([`DIPLOMACY.md`](DIPLOMACY.md)). **Next up: land structures** (step 4) **and more factions**, then diplomacy and contracts, then land structures (air strikes, capture for passive income) and claiming territory. **Art pass 2 is done** (turret separation, national turret styles, superstructures by school). Open art items: per-design superstructure overrides where the school's procedural form misses a class's signature (Takao's trunked funnel, KGV's hangar), tower shadows falling across turrets, and a playtest of the shadow strength. Next up is missions and diplomacy (item 2).

0. **World map (done):** a fictional world from a seeded generator, hand-tuned ([`WORLD.md`](WORLD.md)), with ports, factions, surveys, ice, sea routes, map momentum and wakes. The owner's four-step plan from here: factions with lore, then diplomacy and contracts, then land structures (air strikes, auto-resolved; capture for money, food and steel). The map is ready for structures: `LAND_SITES` in `campaign.json`.
1. **Feel and art passes (done):** art pass 2 lit turrets and superstructures from height maps, with national styles. Before it: Rule the Waves 3-style deck plans at real scale, 7 yards and 50 era designs, combat rebuilt on real knots and turning circles. Follow-ups: playtest the ×2 default clock and the 1/5 range scale, add formation orders, and give the player helm orders by course as well as by rudder.
2. **Missions and diplomacy (done):** port contract boards (six kinds), a mission tracker, nine powers with relations, coalitions, wars, armistices and sieges, commissions and letters of marque, NPC fleets fighting each other, story chains from seven powers ([`DIPLOMACY.md`](DIPLOMACY.md)).
3. **Logistics depth:** ammunition and magazines, auxiliaries, crew fatigue, supply.
4. **World depth:** weather, more points of interest, regional technology disparity.
5. **Endgame:** found your own flag and claim ports. Add the Modern era.
