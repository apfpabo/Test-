# Handover: ships, troopships and research round (in progress)

Paste the "Starter prompt" below into a new chat on branch `claude/serene-dirac-1gppx0`.

## Starter prompt

> Continue work on Iron Meridian (Godot 4 project in `godot/`, branch `claude/serene-dirac-1gppx0`). Read `CLAUDE.md`, `docs/CREATIVE_DIRECTION.md`, `docs/ROADMAP.md` and this file (`docs/HANDOVER.md`) first. Finish the round described under "The owner's request" below, starting from "Still to do". Commit and push as you go. When done, run all the checks, update ROADMAP and CLAUDE.md, export the Windows build, zip it, send it to me and delete this handover file.

## The owner's request (verbatim)

- Add Era 3 Missile Destroyers, Nuclear subs and carriers, based on real life counterparts; add big subs, based on the soviet submarines and attack subs era 2-onwards
- Add flattop carriers like the Japanese carriers from WW2
- Add troop carriers for armies, that will be used to invade land structures
- Add more WW2 and Modern-era ships
- Look for real world references, top down views of actual ships and revise the designs so they ressemble the original models, more specifically on the superstructure, I'm attaching one for the Iowa as an example
- Add battleship Nelson please
- Clarify conditions to move to another era on the Research screen; I also believe that research should be either define by levels with the current research options we have right now, or either add more research options

(The Iowa reference was a recognition-manual side and top plan. Main turrets sit at about +56 m, +34 m and −65 m from midships. The superstructure runs from about +24 m to −54 m. It has two funnels and fore and aft directors.)

## Done (commit c855aad)

- **Research.**
  - `src/game.html` has a new `TECH` table and `ERA_GATE = 3`:
    - Era 1: radar, sonar, homing, aa_prox, dc, amphib
    - Era 2: jets, missiles, nuclear, snorkel, helo, ecm
    - Era 3: ciws, aegis, vls, reactors, datalink
  - `campaign.gd` has `ERA_GATE`, `era_count`, `era_of` (an era opens after 3 technologies of the one before) and updated `enemy_tech`.
  - The battle effects are in `battle_sim.gd`:
    - snorkel: submerged speed
    - datalink: missile range and gun spread
    - vls: an extra missile per salvo
    - aa_prox: flak
    - dc: damage control
    - ecm: decoys
    - helo: sonar range
  - The Research screen (`world_map.gd` `_research`) shows per-era headers, "X of 3 researched" progress, and "Opens with Era X" on locked techs.
  - `skirmish.gd` `ERA_TECH` is updated.
  - **The new TECH table is NOT yet baked into `godot/data/campaign.json`.**
- **Troops (rules only).** `structures.gd` has:
  - `troops()` and `troop_capacity()` (the sum of each hull's `troops` field)
  - `TROOP_COST` (40) and `TROOP_WAGE` (0.2 a day)
  - `defenders(s)`, `can_invade(s)` and `invade(s)`, which returns `{name, men, lost, won, odds, defenders}`. The amphib tech gives +25%.
  - `take()` draws the garrison from troops first.
  - `campaign.gd` pays troop wages and feeds the troops.

## Still to do

1. **Troopships.**
   - Add an `ap` class ("Troop Transport", merchant-like, tech `amphib`) to `CLASSES` and `HULL_ORDER` in `src/game.html`.
   - Designs with a `troops` field: an attack transport modelled on the Haskell class and an LST (yard tidewater, era 1), plus a modern one.
   - Port UI to embark and disembark troops at `TROOP_COST`, limited by `troop_capacity()`.
   - A "Land the troops" button on the structure panel (`world_map.gd` `open_struct`) with a report from `Structures.invade`.
   - Show troops in the top bar or the fleet display.
   - Extend `tests/structures_test.gd`.
2. **Unlock WW2 carriers.**
   - Remove `tech: 'jets'` from `CLASSES.cv`.
   - Support an islandless flight deck: `drawIslandTop`, `spriteWide` and HULLS `island` all assume `fd.isl`.
3. **New designs in `DESIGN_LIST`.** Use fictional names, `model:` the real class, and plans from real top-down drawings.
   - Era I:
     - Nelson (clydemouth bb, all three turrets forward, the tower bridge aft of them)
     - Scharnhorst (ostsee bb)
     - Shokaku (seto cv)
     - Ryujo (seto, flattop with no island)
     - Essex (tidewater cv)
     - Fubuki (seto dd)
     - Atlanta (tidewater cl)
   - Era II: Foxtrot (neva ss), Tang (tidewater ss), Charlie SSGN (neva)
   - Era III:
     - Arleigh Burke and Sovremenny (ddg, tech `vls`)
     - Los Angeles and Akula (ssn, `reactors`)
     - Oscar and Typhoon big subs (`reactors`)
     - Nimitz CVN (`reactors`)
     - Kirov (cg)
   - Then add the new designs to `YARDS`, `PATROL_POOL`, `ESCORT_POOL` and `FAC_MAKERS` as needed.
4. **Superstructure revision.**
   - Re-lay Iowa from the plan figures above.
   - Then KGV, Bismarck, Yamato, Littorio and Vanguard: turret x positions, `sup` blocks, `fun` and directors.
   - Superstructures are drawn per national school in `supMain`/`supAft`.
5. **Bake.**
   - `./build.sh`
   - `node tools/bake_assets.js`
   - `node tools/bake_world.js` (it also runs the worldgen, ~45 s)
   - `godot --headless --path godot --editor --quit`
6. **Checks.**
   - Headless tests: `run_presets`, `campaign_test`, `diplomacy_test`, `move_test`, `structures_test`, `escort_test`, `waypoint_test`, `fuel_test`, `origins_test`. The presets and `LEGACY` reference design ids, so keep the existing ids.
   - Screenshots: Research screen, new designs (`shot_art`), poster (`shot_designs docs/ship_designs.jpg`), an invasion.
7. **Docs and delivery.**
   - Update `ROADMAP.md`, `CLAUDE.md` and `LAND_STRUCTURES.md` (move "Troop transports" out of "Not yet").
   - Export: `godot --headless --path godot --export-release "Windows Desktop" ../build/IronMeridian.exe`, zip it to `build/IronMeridian.zip` and send it.

## Gotchas

- GDScript can't infer types from Dictionary values: declare `var x: float = ...`.
- `--check-only` on autoload scripts reports "Identifier not found: Campaign". That is harmless; run the real tests instead.
- `bake_assets.js` loads `index.html`, so run `./build.sh` after editing `game.html`.
