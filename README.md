# Iron Meridian

> **North star:** [docs/CREATIVE_DIRECTION.md](docs/CREATIVE_DIRECTION.md) sets the creative direction. [docs/ROADMAP.md](docs/ROADMAP.md) tracks how the build compares to it.

A naval fleet-command game in the spirit of Starsector, set on a fictional sea from 1942 into the missile age. It runs in the browser as one file with no dependencies.

**Play:** open `index.html` in a browser.

## The campaign

- **Alternate Earth.** The game opens on 1 March 1946, with the whole world's oceans as the map. Coastlines come from Natural Earth 1:50m data. The map wraps east-west, so the Pacific is continuous. Straits and canals (Gibraltar, the Bosporus, Suez, Panama, Kiel, the Danish straits) are navigable, and the five theatres (Atlantic and Arctic, Mediterranean and Black Sea, Indian Ocean, Pacific, Southern Ocean) are named on the chart.
- **Factions.** The Atlantic Concord (legacy empire), the Eurasian Directorate (successor state still fighting the unfinished war), the Pacific Federation (rising industrial power), the Meridian Combine (corporate consortium), the Iberian Free Republic (breakaway regime), the Freeport Syndicate (pirate havens), the Halvard Enclaves (research stations), and Black Flag raiders. Together they hold 32 real ports.
- **Movement.** Click a destination and the task force plots a sea route around the coasts. It gathers way, swings onto each new course at its own turn rate, slows in confined waters, and leaves a wake. A journey from Norfolk to Portsmouth takes about ten days.
- **Seasons and ice.** Pack ice advances and retreats through the year, and the Gulf Stream keeps the Norwegian Sea open. Sailing in ice is slow, burns more fuel and grinds at your hulls.
- **Salvage and surveys.** Survey wreck fields from the Great War, abandoned bases and black sites for research points, salvage and occasionally a derelict ship. Someone else may be there first.
- **Story.** Five Concord Admiralty missions out of Norfolk, plus bounties on raider captains.
- **Technology eras.** Spend research points (RP) to move from late-war gunnery (Era I) through jets and guided missiles (Era II) to CIWS and area air defence (Era III). The Halvard Enclaves sell research data.
- **Economy.** Six trade goods with local surpluses and shortages that vary by faction. Fuel is burned while underway, crew eat food and draw wages, and undermanned ships fight worse.
- **Ships.** 13 hulls modeled on real designs. Fleets hold up to 10 ships.
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

Combat is real-time and top-down. Turrets traverse on their own, within their firing arcs, and lead your locked target. Shells fly in arcs and land with dispersion, so a target showing you its long side is easier to hit. Armour stops small shells. Torpedoes, carrier strikes (torpedo bombers and dive bombers), anti-ship missiles with SAM and CIWS interception, submarines that can dive, and depth charges from sonar ships are all modelled.

| Key | Action |
| --- | --- |
| W / S, A / D | Engine telegraph, rudder |
| Mouse, hold click | Aim and fire main guns. Clicking an enemy locks it as the target. |
| X | Main-gun autofire at the locked target |
| T / Q / F | Torpedoes at the cursor / missiles at the target / carrier air strike |
| C | Dive or surface (submarines) |
| 1 / 2 / 3 | Fleet orders: engage / escort / retreat off the south edge |
| Tab | Take command of another ship |
| P, wheel | Pause, zoom |
| − / = | Battle time ½× / 1× / 2× / 4× |

## Art

All ship sprites are drawn in code as top-down vector art, and turrets are separate parts so they can rotate. Each faction gets its own palette. Sprites are pre-rendered once per hull and palette (`hullSprite` and `drawHullArt` in `src/game.html`), so swapping in PNG art later only means replacing those functions.

## Development

The game lives in `src/game.html`, an HTML fragment. `./build.sh` wraps it into the standalone `index.html`.

The coastline data is embedded in `src/game.html` as `<script id="land-data">`. It is Natural Earth 1:50m land (public domain) from the `world-atlas@2` npm package, simplified to 0.05°, delta-encoded, with rings that cross the 180° meridian unwrapped. Narrow straits and canals that the data cannot resolve are carved open by hand in `CHANNELS`, and unnavigable waters are filled in via `LAND_PATCHES`.
