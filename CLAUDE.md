# Iron Meridian — Agent Engineering & Architecture Reference (`CLAUDE.md`)

> **North Star:** Always read [docs/CREATIVE_DIRECTION.md](docs/CREATIVE_DIRECTION.md) before any design, art, balance, or feature work. Never edit the owner's text in [docs/CREATIVE_DIRECTION.md](docs/CREATIVE_DIRECTION.md), [docs/LORE.md](docs/LORE.md), [docs/lore/foundational_lore.md](docs/lore/foundational_lore.md), or owner-written tales in `godot/data/tales/*.txt` without explicit instruction. Open design questions belong in [docs/OWNER_DECISIONS.md](docs/OWNER_DECISIONS.md); historical session logs and restore tags live in [docs/CHANGELOG.md](docs/CHANGELOG.md). **The full system-by-system notes this file replaced (13 Nov 2026) are kept in [docs/AGENT_NOTES.md](docs/AGENT_NOTES.md): read the part on a system before changing it, and add to it when you build something.**

## 1. Standing Code & Style Rules

* **Language & Copy:** Use British spelling (`armour`, `harbour`, `calibre`, `manoeuvre`, `colours`) across player-facing text and comments. Write player-facing strings as natural sentences rather than chains of colons or semicolons; format ship counts in plain English via `world_map._counts`.
* **GDScript Typing & Syntax:**
  * GDScript cannot infer static types directly from untyped `Dictionary` lookups; declare those variables untyped (`var x = dict.key`) or with an explicit type (`var x: float = float(dict.get("key", 0.0))`).
  * **Never** place a `#` comment in the middle of a single-line semicolon-chained statement (`a(); # comment; b()`), as GDScript truncates everything after `#` on that line.
  * Load newly added scripts that may run before an editor re-import by path (`preload("res://scripts/...")` or `load(...)`) rather than relying on global `class_name` registration (`flags.gd`, `guide.gd`, `plane_art.gd`, `chart_globe.gd`, `battle_editor.gd`, `nuke_view.gd`).
* **UI Theme Helpers (`scripts/ui.gd`):** Always construct controls via `UI.title`, `UI.label` (all-caps at size <= 12 becomes a section header), `UI.button`, `UI.tabs`, `UI.row`, `UI.bar`, and `UI.font(...)` using Barlow / Barlow Condensed (`assets/fonts/`) rather than ad-hoc styling.

## 2. Project Architecture & Autoloads

The game is a **Godot 4.3** project (`godot/`, `gl_compatibility` renderer, `1400x860` viewport). Simulation logic is strictly separated from rendering and input so campaigns and battles can run headlessly at high speed.

| Script / Autoload | Role & Boundaries |
| :--- | :--- |
| `GameData` (`scripts/game_data.gd`) | Loads baked JSON tables (`data/game_data.json`, `data/campaign.json`, `data/sprites.json`, `data/lore.json`) and textures |
| `Settings` (`scripts/settings.gd`) | Audio bus levels (`OUTPUT := 1.0`), minimap size, effect style (`modern`/`classic`), splash style (`new`/`classic`), and key rebinding (`Settings.ACTIONS`, `binds`, `key()`, `held()`) in `user://settings.cfg` |
| `Sfx` (`scripts/sfx.gd`) | Plays levelled audio cues (`Sfx.cue`), continuous frame layers (`Sfx.layer`), and crossfading screen music (`Sfx.music`) |
| `Campaign` (`scripts/campaign.gd`) | Pure campaign state (`G`), `AStar2D` sea-lane pathfinding, economy, sighting, fleet sizing, refit/wear ledgers, and threaded autosaves. **No drawing** |
| `world_map.gd` (`scenes/world_map.tscn`) | Campaign chart rendering, `Overlay` priority labels, non-modal Command drawer, port/refit/encounter panels, and input routing |
| `chart_globe.gd` + `globe.gdshader` | Orthographic 3D globe overview on CanvasLayer 4 (`world_map.GLOBE_AT := 0.42`); delegates all clicks/menus to `world_map.order_at` and `menu_at` |
| `BattleSim` (`scripts/battle_sim.gd`) | Pure real-time combat simulation (`1 unit = 1 m`, `KN := 0.5144`, `BT := 2.0`). Ships, mounts, ballistics, armour, sensors, AI, aircraft, and particle spawning. **No drawing** |
| `battle.gd` + `battle_hud.gd` | Renders `BattleSim` (`ShipView`, `Keel`, `BoxLayer`, `Detail`, `MountLayer`, `Fires`, `Drawer`), handles combat input, shell camera (`E`), and HUD |
| `Diplomacy` (`scripts/diplomacy.gd`) | Relations (`-100..100`), coalitions, wars/armistices, sieges, commissions, letters of marque, and port contract boards (`data/diplomacy.json`, `data/stories.json`) |
| `Structures` (`scripts/structures.gd`) | 384 coastal/inland installations (`data/structures.json`), carrier air strikes (`air_raid.gd`), coastal bombardment, troop landings, land-based air raids, and nuclear plants/warheads (`nuke_view.gd`) |
| `Flag` (`scripts/flag.gd`) | Player-founded faction (`fac == "player"`), storming/holding ports, Chancery treaties, works, guard squadrons, and custom ensign (`flags.gd`) |
| `Weather` (`scripts/weather.gd`) | Deterministic weather and day/night cycle derived from latitude, longitude, and calendar day (nothing saved) |
| `Tales` (`scripts/tales.gd`) | Parses and runs plain-text narrative encounters in `godot/data/tales/*.txt` using its own RNG stream |

## 3. Campaign & Strategic Layer Invariants

* **Map Coordinates & Navigation:**
  * Equirectangular projection from `82°N` to `78°S`, wrapping east-west (`MW = 7200`, `MH = 3200`, `1 unit = 0.05° ≈ 5.55 km`).
  * Always use `Campaign.wdx`, `mdist`, and `mang` for wrapped distances and bearings.
  * Sea lanes (`data/nav_nodes.bin`, `nav_edges.bin`, `nav_routes.json`) stay `EDGE` (6 cells) clear of top/bottom borders. Use `Campaign.on_land` for collision, `open_sea(x, y)` for valid water points, `off_edge(o)` to rescue edge-stranded fleets, and `nearest_open_port()` (which measures actual route length, not straight-line distance).
* **Fleet Count & Supply (`docs/SUPPLY.md`):**
  * Always check `Campaign.can_add_ship(design_id)` (`""` = allowed) before adding a ship.
  * Use `Campaign.all_ships()` when counting across every owned ship (crew, cargo holds, troop berths, supply) and `G.fleet` for the active sailing/fighting squadron (`SHIPS_MAX = 20`, `BATTLE_MAX = 10` non-reserve ships in battle).
  * After removing any ship, always call **both** `Campaign.trim_cargo()` and `Structures.trim_troops()`.
* **Player Faction Loops (`docs/OWN_FLAG.md`):**
  * Founding a flag inserts `"player"` into `GameData.fac`. Any loop over `GameData.fac` meant only for NPC powers **must** skip `fac == "player"` (and usually `fac == "raiders"`).
  * `Flag.treaty(fac)` must immediately halt all hostile acts by that power.
  * Whenever standing (`G.rep`) changes, call `Campaign.rep_note("<reason>")` immediately afterward so the standing hover ledger (`G.repLog`) records the cause.
* **Economy & Prices (`docs/ECONOMY.md`):**
  * Mutate port shortages only via `Campaign.shortage(p, goods, amount, why)`.
  * Read prices exclusively through `world_map.port_price` (which applies `Campaign.supply_mult(p, gid)`). Destroyed convoys must call `Campaign.convoy_lost(f)`.
* **Sighting, Grace & Force Scaling:**
  * Sighting is symmetric and captain-driven (`Campaign.watch`, `your_watch`, `fleet_watch`, `f.capt`). Never hardcode a fixed sighting distance for one side.
  * Always use `Campaign.known_pos(f)` when marking or steering toward a fleet that may only have a last-known position (`seenX`/`seenY`), and respect `f.vis` when drawing or listing fleets.
  * New captains receive `BOUNTY_GRACE` (30 days) from both `"bounty"` and `"raiders"` fleets (`Campaign.bounty_grace(f)`).
  * Bounty squadrons scale to `BOUNTY_SIZE` × `strength(G.fleet)` (clamped to `BOUNTY_FLOOR..BOUNTY_CEIL`); origin hunters scale to `HUNT_K` × `strength(G.fleet)` after `HUNT_GRACE` (45 days; `Campaign.hunt_k()` rises from `HUNT_K` 1.15 by `HUNT_RAMP` 0.30 over 400 days), capped by the origin's growing budget, via `Campaign.build_to_strength`.
* **Chart UI & Command Drawer:**
  * The Command drawer (`world_map.show_command`, `drawer_open`) is non-modal and does **not** pause the campaign clock; pages re-render via `_rerender()`.
  * Chart top bar, telegraph, and tabs refresh at 5 Hz (`_hud_t`), not every frame; colour overrides go through `_tc`.
  * All chart labels draw through `Overlay._t` with explicit priority `pr` (`10` player squadron down to `1` sensor captions; `-1` always drawn) to prevent overprinting.
* **Autosaves & Save Slots:**
  * Periodic autosaves (`Campaign.save(false)` every 3rd day) copy state and write on a background worker thread; `load_game`, `has_save`, and quit must await `_save_wait()`. Named slots live in `user://saves/` (`slot_save`, `slots`, `slot_load`, `slot_delete`).

## 4. Tactical Combat Invariants (`BattleSim` & `battle.gd`)

* **Clocks & Coordinates:**
  * All simulation timers run in battle seconds (`dt`). Visual effects that flicker or sway must read `BattleSim.rclock` (never `Time.get_ticks_msec()`, which strobes during frame-by-frame video capture), and drifting particles (`wind`) must use their own stored seed rather than world coordinates.
  * Draw small battle primitives around their local origin via `draw_set_transform(pos, rot, scale)` rather than building small polygons in world coordinates (which fail triangulation far from `(0, 0)`). Never draw a zero-length line/polygon.
* **Orders, Divisions & Flagship Control:**
  * Read a ship's order with `sim.ord_of(s)` and hold-fire state with `sim.holding(s)`—never read `s.ord` or `s.hold` directly.
  * Respect `s.own` (`O` key / "your orders stand", managed via `sim.set_own(s, on)` and preserved across `take_command` `Tab` flag shifts) and division leaders (`sim.lead_of(s)`).
  * Every AI helm adjustment must pass through `steer_avoid` (`_clear_of_ships`).
* **Sensors, Submarines & Electronic Warfare (`docs/SENSORS.md`):**
  * Submerged submarines (`submerged(s)`) are detected **only** by sound (`pings`, `held_t`, `passive_range`, `detected_by`). Guns never target a submerged submarine.
  * `has_radar(s)` means fitted **and** switched on (`s.radar_on`); use `radar_fitted(s)` to check equipment alone.
  * Any check for whether a ship is seen must go through `visible_to` or `eye_sees`, and screen-hiding checks must test `sim.limited() or not sim.screens.is_empty()`.
* **Friendly Fire & Munitions Care:**
  * Shells, torpedoes, and depth charges damage any hull they strike (friend or foe, except the firing ship for shells/straight torpedoes).
  * AI captains must check `friend_near` (gunfire), `torp_fouls` (torpedo spreads/homers), and `dc_fouls` (depth-charge patterns) before firing; player torpedo/DC foul warnings require a second press within `FF_CONFIRM` (4 s).
* **Carriers, Spotters & Aircraft:**
  * An air group's `n` is total aircraft, `up` is airborne aircraft, `dk` is deck-parked, and `ops` is taking off/landing (`_fly_op`). Anything firing at aircraft must test `up`, never `n`.
  * Do not end a battle while a ship is still sinking (`sink_k(s)` < 1.0; never compare `s.sink` to a raw number). Surviving aircraft from a sunk carrier divert to `other_deck` as a `guest` squadron.
* **Refits, Weight & Armour by Place (`docs/REFIT.md`, `docs/ARMOUR.md`):**
  * Every new weapon requires an entry in `BattleSim.TONS`; every upgrade requires `tons` and `top` in `UPGRADES`. All standard ship fits across all eras must pass `BattleSim.loading(d, fit, up)` within weight and topweight limits.
  * After changing a ship's weapons, systems, or armour in campaign, always call `Campaign.ship_refitted(s)` to clear the cached `ldv` speed.

## 5. Art, Shaders & Data Bake Pipeline

* **Source of Truth (`src/game.html`):**
  * `src/game.html` is no longer played in the browser; it serves exclusively as the procedural ship-plan renderer and master data table (`DESIGN_LIST`, `WEAPONS`, `ARMOUR`, `TECH`).
  * Run `node tools/bake_assets.js` (or `DATA_ONLY=1 node tools/bake_assets.js` for JSON-only, `ONLY=id1,id2`, `MOUNTS=w1,w2`) to export `godot/data/game_data.json`, `sprites.json`, and ship/mount textures + height maps (`top_h.png`).
  * Run `node tools/bake_world.js` to export `campaign.json` and invoke `tools/worldgen/build.js` (which reads frozen structure coordinates from `tools/worldgen/sites.lock.json`). Follow with `godot --headless --path godot --editor --quit` when new textures are added.
* **Heeling & 2.5D Shader Extrusion:**
  * When a ship lists (`ShipView.heel()`), `Keel` draws her exposed hull side and red boot-topping, `BoxLayer` slides deck containers, and `ship_light.gdshader` / `mount_light.gdshader` extrude superstructures and turrets using `lean` and `sun_ship`. Any new visual element standing on a ship must offset by `view.lean` and its height.
  * To hide the battle UI (`H` / `battle.set_clean`), test `battle.clean` inside `battle._overlay`—never hide the `overlay` CanvasLayer itself, as shells, tracers, missiles, and aircraft render on that layer.

## 6. Verification & Headless Test Suite

Run headless checks via `tools/run_tests.sh <log_dir> [tests]` (which isolates `XDG_DATA_HOME` per worker so parallel save/load tests never collide on `user://iron_meridian_save.json`):

* **Core Regression Suite:** `review_test.tscn` (keep section counter updated when adding checks), `run_presets.tscn`, `campaign_test.tscn`, `diplomacy_test.tscn`, `structures_test.tscn`, `flag_test.tscn`, `aux_test.tscn`, `orders_test.tscn`, `move_test.tscn`, `route_stress.tscn`, `air_stress.tscn`, `tales_test.tscn`.
* **Soak & Balance Probes:**
  * `godot --headless --path godot res://tests/soak_test.tscn -- [days] [origin] [navy] [seed]` (run 365 days after touching `campaign.gd`, `flag.gd`, `structures.gd`, or `diplomacy.gd`).
  * `godot --headless --path godot res://tests/tune_probe.tscn -- <days> <origin> <navy> <seed> <out.json>` followed by `python3 tools/tuning_sheet.py <runs_dir> docs/TUNING_SHEET.md`.
  * `godot --headless --path godot res://tests/duel_measure.tscn -- [ids]` for equal-cost 1v1 hull pricing.
* **Windows 11 Export:**
  * `godot --headless --path godot --export-release "Windows Desktop" ../build/IronMeridian.exe`
  * `python3 tools/set_exe_icon.py build/IronMeridian.exe godot/icon.png`

## 7. Added with the realism and hunter patch (13 Nov 2026)

* **Balance preset (the owner's):** `Campaign.EVADE_FLOOR` (0.22) is the least chance of breaking off (the encounter panel and `tests/tune_probe` both read it); `PT_STRENGTH_MULT` (2.0) counts motor torpedo boats double in `Campaign.strength()` on either side; raider packs made only of torpedo boats start within `PT_TETHER` (60 units) of a den or harbour and roam no further (a fleet's `tether`). Torpedo ranges are 2,000 / 4,200 / 2,600 m (`tor`, `tor93`, `torh`), `HOMER_SHORT` 450; CIWS reaches 900 m (`pd` 0.28) inside the Bofors' 1,250 m.
* **Officer traits:** `Campaign.OFFICER_TRAITS`, `grant_officer_trait(o)` at levels 3 and 5 (`TRAIT_LEVELS`; two at most; `o.traits`), `traits(o)`, `flag_trait(id)`, `trait_evade()`. In battle a `CShip`'s `traits` (set beside `tm` in `battle.gd` and the soak), read with `BattleSim.has_trait(s, id)`; what each is worth is in the `TRAIT_*` constants. Shown by `world_map._trait_labels(o)`. review_test `_traits`.
* **Turret shadows from the upper works:** `mount_light.gdshader` marches the ship's height map (`ship_hmap`, `ship_size_m`, `freeboard`) from each turret pixel towards the sun. The pixel's place in the ship's frame comes from `MODEL_MATRIX * VERTEX` through `ship_ix`/`ship_iy`/`ship_io` (the inverse of the `ShipView`'s transform, set in `refresh()`): `VERTEX` alone is the mount's own rectangle. `GameData.mount_material()` already makes a material per call, so each ship has her own.
* **Tales:** `godot/data/tales/iron_meridian_tales.txt` is the owner's pack (10 tales): never alter it unasked.

## 8. Later on 13 Nov 2026

* **Launch cells:** `BattleSim.default_fit` empties a V slot without the research only on a design of Era I or II (an old hull given cells later); a design of Era III or IV always carries her missiles (the editor sets no research, and the Umbra's and the Shade's cells did nothing there).
* **Shot camera:** with E held and no shell of hers in the air, the camera rides her newest anti-ship missile (`battle.shot_ms`; a ship's own missiles carry `who`).
* **Stealth designs** (`ShipView.stealth`, `dark`, from the plan's `stealth`): torpedo tubes are drawn as a fixed faceted cover (`MountLayer._tube_cover`), looks only. **Aerials** (`battle.gd` `Aerial`): a search aerial turns on the first two masts of a ship with radar fitted while the set is on (`p.mast`; not derrick posts, submarines or stealth designs).
* **Rain** (`veil.gdshader`): cell numbers are kept small (`rhash`); the old hash lost precision on some graphics cards and rain fell on one side of the screen.
* **Five portrait clips** (`tests/reel_five.gd`, `tools/make_five.sh <dir> [shell eras yamato sinking night]`): no interface, the in-development tag, -14 LUFS. `tests/shot_art` takes `TECH=radar,...`.
* **Guns by era** (the owner, 13 Nov 2026): wartime and modern ships no longer share mounts. `g76a` (76 mm automatic), `g127a` (5-inch/54 automatic) and `g130a` (130 mm automatic twin) are the missile age's guns, carried by every design of Era III and IV that had `g76`, `g127s` or `g130t`; `g76` is now the 3-inch/50 twin of Era II. Rates of fire are real ones (rounds a minute a barrel = 60 / `rel`): a new gun must be given its real rate, and a gun of one age must not be the standard fit of a design of another. Light AA and CIWS fire in bursts and are not reckoned by the round. Ranges are the real ones compressed about six to one.
* **`tests/fit_audit.tscn`**: every design with every weapon each mount can take (deck under the mount, funnels, other mounts, plan fittings, barrels swept through each permitted bearing). Its flags need judging: carriers' gallery mounts, boats (the bake keeps them clear of mounts by rule) and heavy barrels over light AA are not faults.
* **Missiles** (the owner, 13 Nov 2026): `MSL_ARMOUR` (0.4, a belt's most), `MSL_SOFT`/`MSL_SOFT_MM` (more against unarmoured hulls), `_missile_blast` (a fire at every hit; light mounts within `MSL_BLAST` wrecked `MSL_BLAST_K` of the time; the director). `ssmh` is the heavy missile (`heavy`: a missile's `hv`; damage kind "missile_h", `MSL_ARMOUR_H`, `HEAVY_PD`), the standard fit of six Directorate designs.
* **Room in a mount** (`BattleSim.room_for(slot, wid)`): every list of weapons for a mount (campaign yard, quick-battle editor, battle editor) leaves out a gun whose house is much bigger than the standard one there (`ROOM_W`/`ROOM_L` off the centreline, `ROOM_MID_*` on it). A new place that offers weapons for a mount must ask it too.
* **A ship's list is drawn easing over** (`ShipView.heel()` follows `heel_to()` at `HEEL_RATE`; at once while paused). Catapult planes sit abaft the reach of the turret forward of them (`battle._overlay`).
