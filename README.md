# Broadside Reach

An age-of-sail fleet game in the spirit of Starsector, with sailing ships in place of spaceships. It runs in the browser as one file with no dependencies.

**Play:** open `index.html` in a browser.

## What's in it

- **The chart (campaign map).** A procedurally generated archipelago with League ports and corsair havens. Click to sail, and remember that wind direction sets your speed. Provisions run down every day.
- **Trade.** Every port has goods that are plentiful or in demand. Prices drift over time and react to how much you buy and sell.
- **Shipyards.** Seven hulls, from the Cutter up to the Ship of the Line, plus a steam Ironclad Ram that ignores the wind. You can command up to 8 ships.
- **Encounters.** Corsairs chase you when they think they can win. You can fight or try to slip away. League convoys are neutral, but attacking one costs reputation, and if your standing drops low enough League ports turn you away.
- **Bounties.** Named corsair captains roam the map, and the League pays for sinking their whole squadron.
- **Real-time naval battles.** You steer your flagship and the rest of your fleet follows your orders. Broadsides fire in fixed arcs. Armor soaks small shot. Ships need way on to turn, and damaged ships slow down. Islands block both ships and cannonballs, and the ironclad can ram. Once a battle is won you can refloat some of the wrecks.

## Battle controls

| Key | Action |
| --- | --- |
| W / S | More / less sail |
| A / D | Rudder |
| Click / Space | Fire the broadside facing the cursor (or the bow chaser if the cursor is ahead) |
| Q / E / F | Port broadside / starboard broadside / bow chaser |
| 1 / 2 / 3 | Fleet orders: engage / escort flagship / retreat (off the south edge) |
| Tab | Take command of another ship |
| P | Pause · mouse wheel zooms |

On the chart, Space pauses. The game autosaves when you dock and after each battle.

## Development

The game lives in `src/game.html`, an HTML fragment. `./build.sh` wraps it into the standalone `index.html`.
