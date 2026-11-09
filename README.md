# Iron Meridian

> **North star:** [docs/CREATIVE_DIRECTION.md](docs/CREATIVE_DIRECTION.md) sets the creative direction. [docs/ROADMAP.md](docs/ROADMAP.md) tracks how the build compares to it.

A naval fleet-command game in the spirit of Starsector, set on a fictional sea from 1942 into the missile age. It runs in the browser as one file with no dependencies.

**Play:** the game is a Godot 4 project in `godot/`; see [The Godot build](#the-godot-build). The old browser build (`index.html`) still opens, but it no longer gets updates.

## The campaign

- **Alternate Earth.** The game opens on 1 March 1946, with the whole world's oceans as the map. Coastlines come from Natural Earth 1:50m data. The map wraps east-west, so the Pacific is continuous. Straits and canals (Gibraltar, the Bosporus, Suez, Panama, Kiel, the Danish straits) are navigable, and the five theatres (Atlantic and Arctic, Mediterranean and Black Sea, Indian Ocean, Pacific, Southern Ocean) are named on the chart.
- **Factions.** The Atlantic Concord (legacy empire), the Eurasian Directorate (successor state still fighting the unfinished war), the Pacific Federation (rising industrial power), the Meridian Combine (corporate consortium), the Iberian Free Republic (breakaway regime), the Freeport Syndicate (pirate havens), the Halvard Enclaves (research stations), and Black Flag raiders. Together they hold 32 real ports.
- **Movement.** Click a destination and the task force plots a sea route around the coasts. It gathers way, swings onto each new course at its own turn rate, slows in confined waters, and leaves a wake. A journey from Norfolk to Portsmouth takes about ten days.
- **Seasons and ice.** Pack ice advances and retreats through the year, and the Gulf Stream keeps the Norwegian Sea open. Sailing in ice is slow, burns more fuel and grinds at your hulls.
- **Salvage and surveys.** Survey wreck fields from the Great War, abandoned bases and black sites for research points, salvage and occasionally a derelict ship. Someone else may be there first.
- **Story.** Five Concord Admiralty missions out of Norfolk, plus bounties on raider captains.
- **Technology eras.** Spend research points (RP) to move from late-war gunnery (Era I) through jets and guided missiles (Era II) to CIWS and area air defence (Era III). The Halvard Enclaves sell research data.
- **Economy.** Six trade goods with local surpluses and shortages that vary by faction. Fuel is burned while underway, crew eat food and draw wages, and undermanned ships fight worse.
- **Ships and shipbuilders.** 13 ship classes in 50 designs from seven fictional yards (Tidewater, Clydemouth & Tyne, Ostsee-Werke, Neva Admiralty, Seto Arsenal, Cantieri del Tirreno, Combine Marine). Each design is modelled on a real ship, such as the Iowa, Yamato, Bismarck, King George V, Littorio, Fletcher, Kagero, Liberty ship or Forrestal, under a fictional class name. Each has its real length, beam, displacement, speed, belt armour and turning circle. Every flag buys from its own yards, newer designs unlock as your research reaches each era, and enemy squadrons mix older designs with their newest ones. Fleets hold up to 10 ships.
- **Refits, officers and prizes.** Choose the weapon in each mount. Officers level up and specialise. Enemies battered below 12% hull strike their colours, and you can take them as prizes.

## Chart controls

| Input | Action |
| --- | --- |
| Click the sea, a port or a survey site | Plot a sea route there |
| Click a fleet | Lock an intercept course. You steer for where it is heading and make contact automatically |
| Drag, or arrow keys / WASD | Pan the chart (camera unlocks from your fleet) |
| C / Home, or **Centre** | Recentre on your fleet |
| Wheel, or + / − | Zoom from the whole world down to ship level (beyond 2× every ship in a fleet is drawn) |
| Space, or 1 / 2 / 3 / 4 | Pause, or time ×1 / ×2 / ×4 / ×8 (also the buttons in the top bar) |

A day lasts 10 seconds at ×1.

## Combat

Combat is real-time and top-down, at true scale: one unit is one metre. Ships make their real speed in knots, take minutes to work up to full power, need about ten seconds to put the rudder over, and turn on their real tactical diameter, losing way in a hard turn. A dashed track ahead of your flagship shows where the present rudder will take her. The battle clock runs at twice real time by default, and you can set it from real time to ×16. Gun ranges are compressed to about a fifth of real maximum range (16-inch guns reach 6 km) so that a fight fits a readable chart. Reload times are the real ones, and turrets train at their real rates. A battleship's main battery takes the best part of a minute to swing across. Squadrons sight each other about 9 km apart. A ship that opens the range beyond 11 km escapes, and an action with no hits for fifteen battle minutes ends with contact lost. Turrets traverse on their own, within their firing arcs, and lead your locked target. Shells fly in arcs and land with dispersion, so a target showing you its long side is easier to hit. Armour stops small shells. Torpedoes, carrier strikes (torpedo bombers and dive bombers), anti-ship missiles with SAM and CIWS interception, submarines that can dive, and depth charges from sonar ships are all modelled.

| Key | Action |
| --- | --- |
| W / S, A / D | Engine telegraph, rudder |
| Click an enemy | Lock it and open fire with the main battery (secondaries pick their own targets) |
| Hold click on open water | Fire the main battery at that spot · right-click open water to cease fire |
| X | Main-gun autofire at the locked target |
| T / Q / F | Torpedoes at the cursor / missiles at the target / carrier air strike |
| C | Dive or surface (submarines) |
| 1 / 2 / 3 | Fleet orders: engage / escort / retreat (open the range and break contact) |
| Tab | Take command of another ship |
| Right- or middle-drag · Space / Home | Pan the battle chart · recentre on your flagship (the wheel zooms about the cursor) |
| P, wheel | Pause, zoom |
| − / = | Battle clock ×1 (real time) / ×2 / ×4 / ×8 / ×16 |

## Art

Ships are drawn as top-down deck plans at true proportions, in the spirit of Rule the Waves 3. Every plan is generated in code from its design's data (`DESIGN_LIST` and `drawPlan` in `src/game.html`). That data covers the hull form (bow entry, cruiser or transom stern), teak, linoleum or steel decks, tiered superstructure, funnels, tripod, pole or lattice masts, boats, cranes, catapults, flight decks with ranged aircraft, and submarine sails. Turrets, AA mounts and torpedo tubes are drawn to scale as separate parts so they can train. Each flag has one muted paint scheme that covers hull, superstructure and turrets alike. Light comes from directly overhead, and shadows on the water are cast in world space, so lighting stays consistent at any heading. Plans are pre-rendered once per design and flag (`hullSprite`). Swapping in PNG art later only means replacing that function.

## Development

The game lives in `src/game.html`, an HTML fragment. `./build.sh` wraps it into the standalone `index.html`.

The coastline data is embedded in `src/game.html` as `<script id="land-data">`. It is Natural Earth 1:50m land (public domain) from the `world-atlas@2` npm package, simplified to 0.05°, delta-encoded, with rings that cross the 180° meridian unwrapped. Narrow straits and canals that the data cannot resolve are carved open by hand in `CHANNELS`, and unnavigable waters are filled in via `LAND_PATCHES`.

## The Godot build

The whole game now runs in Godot 4. `godot/` is a Godot 4.3 project:

- **Open it** in Godot 4.3 or later (Project Manager → Import → `godot/project.godot`) and press Play. The title screen offers the campaign (three starts, or continue a saved game) and quick battles with eight preset engagements or squadrons you pick yourself.
- **Saves** go to Godot's user data folder and are written at ports, after battles and every few days at sea.
- **Over the browser build:** GPU water and ship-lighting shaders, scene nodes per ship, native UI, fast native pathfinding over a precomputed sea-lane network, desktop export.
- **Art and data pipeline:** ship plans, mounts and effect textures are still drawn by the browser renderer and baked to images by `node tools/bake_assets.js`; `node tools/bake_world.js` bakes the coastlines, land mask, sea lanes and campaign tables. Hand-made art can replace the baked images later without code changes.
- **Checks:** `godot --headless --path godot res://tests/run_presets.tscn` plays every preset battle; `res://tests/campaign_test.tscn` exercises routing, a month at sea, a battle and save/load.
