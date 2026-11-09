# Next: land structures

Brief for the next working session (written 9 Nov 2026). Read [`CREATIVE_DIRECTION.md`](CREATIVE_DIRECTION.md) (never edit it), [`ROADMAP.md`](ROADMAP.md), [`LORE.md`](LORE.md) and [`lore/foundational_lore.md`](lore/foundational_lore.md) (the owner's text, never edit), [`WORLD.md`](WORLD.md) and [`DIPLOMACY.md`](DIPLOMACY.md) first.

## The owner's request

Step 4 of the owner's plan (after the world map, factions and lore, diplomacy and contracts, all done):

> Land structures, enemy and allied, that can be attacked from the air in an auto-resolved battle (carrier operations) and captured for passive income (money, food, steel).

After it comes step 5: found your own flag and claim ports and territory. Build structures so that step can grow out of them.

## What is already there to build on

- **Sites on land:** `campaign.json` `LAND_SITES`: 266 inland sites about 5° apart, made by `tools/worldgen/build.js`. Each has `kind` (`farm` → food, `mine` → steel, `oil` or `industry` → money), `land` (landmass or island group), `port` (nearest port id), `coastKm` (distance inland, for strike range) and map position `x, y`. Nothing uses them yet. They can be regenerated or hand-placed in `tools/worldgen/world.json`.
- **Landmasses:** `LANDMASSES` and `land` on every port (Varga, Ombria, Hallandia, Austrine, Skarn, Coralind, island groups).
- **Air reach:** `Campaign.strike_reach(ships)` already gives carriers a reach (250 km escort carriers, 350 km fleet carriers, in map units via `Campaign.KM_PER_UNIT` = 5.55 km). Carriers carry squadrons in battle (`hangar` on the design, `s.squads` in `battle_sim.gd`).
- **Ownership and war:** nine powers with relations, coalitions, wars, sieges that move ports between owners (`Diplomacy.capture`), commissions and letters of marque. A structure's owner would naturally follow its nearest port, or be held on its own.
- **Contracts:** `Diplomacy._make` builds contract offers per port (delivery, hunt, survey, war patrol, escort, smuggling). Strike, defend and capture contracts would slot in there.
- **Economy:** six goods (fuel, food, steel, medicine, munitions, electronics), market prices per port, wages and food per day in `Campaign.new_day`.
- **The chart:** `world_map.gd` draws ports, survey sites, fleets, contract markers (`Diplomacy.marks`), the orders box (top right) and panels via `open_panel(build, blocking, width, key)`.
- **Auto-resolved fights:** `Diplomacy._fight` settles NPC fleet actions from strength; an air-strike resolver could follow the same pattern (air strength against the site's AA and fighters).

## Questions to ask the owner first

1. Which kinds of structure (for example: airfield, coastal battery, oil works, steelworks, farms and depots, radar station, naval base)? What does each do beyond income: AA cover, coastal guns that threaten ships, fighters, a repair yard?
2. How is a structure captured, given "no boarding": after an air strike knocks out its defences, by landing troops from transports (auxiliaries aren't in the game yet), by a surrender when the defences are gone, or by a contract with a power's army?
3. Income: paid monthly, delivered as goods to a port, or a share sold automatically? Does it need protecting (supply convoys, raids)?
4. Can the powers retake structures, and do they attack yours? Should structures change hands in wars on their own?
5. How should a strike look: a short summary panel (like an encounter) or a small watchable air raid?
6. Visuals on the chart: icons, or small drawn installations on the terrain at close zoom?

## How this project is run

- The game is the Godot 4.3 project in `godot/` (GDScript, GL Compatibility). In a fresh container, fetch Godot 4.3 (Linux) and the Windows export template (`tools/fetch_from_zip.py`, see `CLAUDE.md`), then `godot --headless --path godot --editor --quit` to import.
- Checks (see `CLAUDE.md`): `run_presets`, `campaign_test`, `diplomacy_test`, `move_test`, `origins_test` (about 3 minutes, run alone), and screenshot tests (`shot_map`, `shot_diplomacy`, `shot_refit`, `shot_fx`, `shot_battle`). Add a test and a screenshot test for structures.
- The owner plays on Windows 11: export, zip and send the `.exe` after each round of work, with screenshots of what changed.
- The owner gives feedback as screenshots and short videos, often several points at once. Fix each, and answer questions plainly.
- Keep `ROADMAP.md` current. Keep the owner's text word for word. No real place names on the map.
- Backups: the session can only push its own branch (pushing a tag was refused), so record restore points as commits in `ROADMAP.md`. The last pre-effects version is commit `3dbf780`. The battle effects have a Modern/Classic switch in Settings.
