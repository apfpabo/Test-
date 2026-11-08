# Iron Meridian

> **North star:** [docs/CREATIVE_DIRECTION.md](docs/CREATIVE_DIRECTION.md) sets the creative direction. [docs/ROADMAP.md](docs/ROADMAP.md) tracks how the build compares to it.

A naval fleet-command game in the spirit of Starsector, set on a fictional sea from 1942 into the missile age. It runs in the browser as one file with no dependencies.

**Play:** open `index.html` in a browser.

## The campaign

- **Factions.** The Concord Republic and the Varsk Dominion are at war, the Free Ports Syndicate trades with both, and Black Flag raiders prey on everyone. Each faction tracks its own reputation. Ports, shipyards and patrols respond to your standing.
- **Story.** Five Admiralty missions at Port Halden: a raider hunt, a submarine pack, capturing a destroyer that carries a codebook, breaking a cruiser blockade, and sinking the battleship *Dominion's Pride*. After the last one the game continues as a sandbox.
- **Technology eras.** Spend research points (RP) to move from big guns (Era I) through jets and guided missiles (Era II) to CIWS and area air defence (Era III). Each step unlocks new hulls and weapons. Enemy fleets modernise as time passes, and also whenever you do.
- **Economy.** Six trade goods with local surpluses and shortages. Fuel is burned while underway, crew eat food and draw wages, and undermanned ships fight worse.
- **Ships.** 13 hulls modeled on real designs: torpedo boat, corvette, destroyer, submarine, freighter, light, heavy and missile cruisers, escort and fleet carriers, battleship, missile destroyer, and nuclear attack sub. Fleets hold up to 10 ships.
- **Refits.** Every hull has typed mounts: small, medium, large and heavy guns, AA/point defence, torpedoes, and vertical launch cells. You choose what goes in each one.
- **Officers.** Hire officers at ports and assign them to ships. They level up from combat and put points into gunnery, ship handling, damage control and ordnance.
- **Prizes.** Enemy ships battered below 12% hull strike their colours, and after the battle you can take them into your fleet.

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

## Art

All ship sprites are drawn in code as top-down vector art, and turrets are separate parts so they can rotate. Each faction gets its own palette. Sprites are pre-rendered once per hull and palette (`hullSprite` and `drawHullArt` in `src/game.html`), so swapping in PNG art later only means replacing those functions.

## Development

The game lives in `src/game.html`, an HTML fragment. `./build.sh` wraps it into the standalone `index.html`.
