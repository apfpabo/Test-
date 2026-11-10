# Refits by weight

Step 3 of the owner's order of work (10 Nov 2026), after his direction to take a page from Rule the Waves 3 and Ultimate Admiral: Dreadnoughts. Hulls and mount positions stay as the real ships had them; what is fitted to them is the player's, within what the hull can carry. Rules: `godot/scripts/battle_sim.gd` (`TONS`, `HEIGHT`, `UPGRADES` with `tons` and `top`, `loading`, `weapon_tons`, `system_tons`). Screen: the Refit tab in port (`world_map._refit`, `_weights`, `_systems`). Checked by section ten of `tests/review_test.tscn`.

## The ledger

- Every weapon weighs so many tons (a 20 mm gun 1, a quadruple Bofors 11, a twin 5-inch 45, a triple 8-inch 310, a triple 16-inch 1,700, a bank of torpedo tubes 20, and so on), and every mark of a ship system weighs a share of her displacement.
- A ship was designed round her standard fit. Beyond it she has a **margin** of 1.2% of her displacement (at least 8 tons).
- Past the margin she is **overweight**: 2% slower and 1.5% slower on the helm for every 1% of her displacement over.
- At 3% of her displacement over the margin the yard will not pass the refit.
- Landing weight below her standard fit makes her a little faster, up to 3%.

## Topweight

- Weight counts for more the higher it sits: guns on deck 1, anti-aircraft mounts 1.5, launch cells 0.8, torpedoes 0.9; armour, machinery and torpedo protection low in the hull; directors and radar high on the masts.
- Up to 110% of her designed topweight she rides easily. Beyond that her salvos spread, 2% wider for each 1% more, and half as much again for each step of the sea state.
- At 130% the yard will not pass her.

## Systems

| System | Each mark gives | Weight of a mark |
| --- | --- | --- |
| Machinery | +4% speed | 0.8% of displacement |
| Hull and armour | +8% hull, +10% armour | 2.2% |
| Torpedo protection (new) | torpedo damage -15%, a third less flooding | 1.8% |
| Magazine protection | fewer magazine fires | 0.6% |
| Turret machinery (new) | guns reload 6% faster | 0.4% |
| Fire control | salvos 12% tighter | 0.2%, carried high |
| Radar | +6% gun range | 0.15%, carried high |
| Sonar | +30% sonar range | 0.1% |

So armour on a destroyer eats her whole margin and more, and the way to pay for it is the way navies did: land the torpedoes, or a gun mount.

## Money

Weapons cost what they did and sell back for half; on top the yard charges 12 for every ton landed or shipped.

## What it does not do yet

- Refits are still done at once: no time in the yard.
- Armour is one figure, not set by belt, deck and turrets; there is no choice of machinery for a design speed, and no trim fore and aft.
- Other navies' ships are held to the same rules (owner's decision), but they sail in their designers' standard fits, which are all within weight, so today it changes nothing for them. It will once they carry variant fits or system upgrades.
- The chart speed of a squadron ignores loading; it tells in battle only.
- No new construction to your own design.
