# Next: a fictional world map

> **Done (9 Nov 2026).** The owner chose candidate C (seed 16). What was built, and how to change it: [`WORLD.md`](WORLD.md). This brief is kept for its reasoning.

Brief for the next working session (written 9 Nov 2026). Read [`CREATIVE_DIRECTION.md`](CREATIVE_DIRECTION.md) (never edit it), [`ROADMAP.md`](ROADMAP.md) and [`LORE.md`](LORE.md) first.

## The owner's request

The campaign chart uses the real Earth today. The owner wants **fictional land**. It's the first of four future items they raised:

1. A fictional world map (this task).
2. Land structures, enemy and allied, that can be attacked from the air in an auto-resolved battle (carrier operations) and captured for passive income (money, food, steel).
3. More factions.
4. Better lore.

The agreed order: map first, because factions, structures and lore all hang off geography. Then factions with lore, then diplomacy and contracts, then land structures and claiming territory.

**Start by showing the owner a few candidate worlds from a seeded generator, and let them choose before building anything else.**

## Design goals

- **Keep the strategic shapes of the creative direction's theatres**, so the world reads as an alternate Earth without being Earth:
  - an Atlantic-like ocean with Arctic routes;
  - an enclosed sea with choke points (Mediterranean or Black Sea role);
  - an Indian-like ocean of trade arteries;
  - island chains and resource archipelagos (Pacific role);
  - a dangerous southern ocean.
- **Straits and canals matter** (sea control is the currency). Make a few deliberate choke points.
- **Climate still runs on latitude** (pack ice, the seasons), so keep a latitude frame even though the land is invented.
- **Ships stay modelled on real designs.** Only the land, the place names and, later, the factions' homelands change.
- **Look:** grounded, chart-like, Rule the Waves 3 restraint. The chart's current land style (sand fill, darker outline, shallow-water glow) can stay.
- **Generate from a seed, then hand-tune.** Keep the chosen seed and any manual edits so the world is reproducible.

## How the world is built today (what has to be replaced)

- **Coastlines:** Natural Earth 1:50m, embedded in `src/game.html` (the old browser build, now only an art and data source): see the comment near line 98 and `LAND` around line 1212. Also there: `CHANNELS` (hand-carved straits) and `LAND_PATCHES`.
- **Ports, survey sites and theatres:** defined in `src/game.html` (`genWorld` around line 1365 and `THEATERS` around line 1283), with real names and lon/lat positions.
- **The bake:** `node tools/bake_world.js` (runs the browser build headless in Playwright) exports everything Godot reads into `godot/data/`:
  - `campaign.json`: ports with sea positions `sx, sy`, sites, theatres, wars, goods, tech, story, starts, pools, `channels`, `land` polygons;
  - `land_mask.png`: red = land, green = pilotage waters within two cells of land;
  - `nav_nodes.bin`, `nav_edges.bin`: the sea-lane network;
  - `nav_routes.json`: precomputed routes between every pair of ports.
- **Godot reads only those files** (`scripts/campaign.gd` loads them; `scripts/world_map.gd` draws land as Polygon2D from `C.land`). Map units: 1 unit = 0.05°, equirectangular projection from 82°N to 78°S, wrapping east–west (`Campaign.lon_x`, `lat_y`, `wdx`, `mdist`, `mang`, `on_land`).
- **Recommendation:** write the generator as a new standalone tool (Python, or a Godot headless script) that writes the **same files in the same formats**. Then the chart, routing, ice, wakes, encounters and saves keep working unchanged. Only `bake_world.js`'s campaign-table export, or a replacement for it, needs to keep supplying the non-geographic tables.

## Real places to rename or replace

- **Ports:** 32 real ports in `campaign.json`, such as Norfolk, Kiel, Yokosuka, Port Said, Cape Town and Reykjavík.
- **`godot/scripts/origins.gd`:** each navy's home and second port, its neutral bolt-hole, and the hijacker's, merchant's, privateer's and smuggler's start ports are named.
- **`world_map.gd`:** the Concord Admiralty mission text mentions places.
- **Story missions and theatres:** their names, in the campaign tables.
- **The owner's lore** (`docs/LORE.md`) is written without real place names, so it needs no changes. Never edit the owner's text.
- **Factions** are fictional already: Atlantic Concord, Eurasian Directorate, Pacific Federation, Meridian Combine, Iberian Free Republic, Freeport Syndicate, Halvard Enclaves, Black Flag raiders. Some names point at real regions ("Atlantic", "Eurasian", "Pacific", "Iberian"). Ask the owner whether those should change with the new map, since more factions are coming anyway.

## Checks

- `godot --headless --path godot res://tests/campaign_test.tscn`: routes between ports (it names real ports; update it), a month at sea, a battle applied to the campaign, save and load.
- `res://tests/origins_test.tscn`: every origin starts at a valid port and sails for 20 days. Run it alone; it takes about 3 minutes.
- `xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_map.tscn -- <dir>`: chart screenshots at world, default and close zoom. `map_zoom_perf.tscn` times zooming; keep land as static geometry, which made zooming fast.
- `run_presets.tscn` for battles (unaffected by the map, but run it before any commit).
- **Old saves** store port ids and positions. Decide with the owner whether a new world means a save break: bump `G.v` and say so in the main menu.
- **Export for the owner** (Windows 11): `godot --headless --path godot --export-release "Windows Desktop" ../build/IronMeridian.exe`, then zip and send it. In a fresh container, fetch Godot 4.3 and the Windows template first (`tools/fetch_from_zip.py`).
