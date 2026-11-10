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

## Done at once, paid for in readiness

The owner did not want to wait on a yard (10 Nov 2026), so a refit is done on the spot, as in Starsector, and the ship pays in readiness while her crew work up what has changed: moving a twentieth of her displacement costs 30% (the most any one job costs), a small job two or three per cent. Readiness comes back with rest in port, as ever. The refit screen shows the readiness she will be left with before you confirm.

## On the chart

A squadron's speed on passage follows loading too: an overloaded ship holds the rest back, a lightened one does not (`Campaign.load_speed`, kept on the ship as `ldv`; call `Campaign.ship_refitted(s)` whenever a fit or a system changes).

## Other navies

They are held to the same rules, and they refit: about three patrol ships in ten, half a mission force, eight in ten of a bounty hunter's ships, and a few raiders and convoy escorts carry one to three system upgrades, chosen so that the ship stays within her weight and topweight; cruisers and battleships may land torpedoes to pay for them (`Campaign.make_variant`). Their refits count in battle and in what a force is reckoned to be worth, and the contact panel says what the glasses show ("2 of them have been refitted (hull and armour, fire control).").

## What it does not do yet

- Armour by place (belt, deck, turrets), machinery chosen for a design speed, and trim fore and aft: left open by the owner, who is not sure how far into realism to go.
- No new construction to your own design.
