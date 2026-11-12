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
- Between her margin and the yard's limit the yard asks before it does the work (the owner's decision, 12 Nov 2026): a fit that leaves her over her margin or top-heavy, and worse off than she is, shows what it costs her and a "Refit anyway" button.

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

## Armour, reconstruction and sister ships (12 Nov 2026)

The owner gave the go-ahead to extending refits instead of building a free designer.

**Armour by place.** On the refit page, plate can be added to or landed from three places, in steps of a twentieth of
what she was built with (at least 5 mm), up to six steps on and three off:

- the belt
- the armoured deck
- the main turrets' faces

How it is weighed:

- **Steel weight:** 7.85 t per cubic metre.
- **Belt:** both sides of her citadel, about a hundredth of her length deep (2 to 4.5 m). 10 mm more on an Iowa is 82 t.
- **Deck:** the citadel's length by 85% of her beam. 10 mm more on an Iowa is 357 t.
- **Turrets:** 80 m² for each main turret.
- **Topweight factors:** belt 0.25, deck 0.55, turrets 1.0.
- **Code:** `BattleSim.armour_tons`, `armour_step`, `ARM_UP`, `ARM_DOWN`; the ledger's fourth argument (`loading(d, fit, up, arm)`).

Cost and effect:

- New plate costs `ARMOUR_PER_TON` (45) a ton, plus the yard's 12 a ton labour. Plate landed is scrap: only the labour is paid.
- It is kept on the ship record as `arm` (mm added per place). `BattleSim.armour_of(d, rec)` adds it, so she fights with it.

**Reconstruction.** A ship ten years old or more can be rebuilt (`Campaign.reconstruct`):

- She then wears as a ship two years old: `built` is set two years back, so her wear floor and rate fall.
- Cost: a third of her design's price.
- Her readiness falls to `RDY_MIN`.

**Sister ships.** At a yard that builds her design, a new ship of the same design can be ordered built to the fit planned
on the page: weapons, armour, and the systems her sister carries. The price (`world_map.sister_price`) is the yard's price
plus:

- the plan's weapons beyond the standard fit,
- the plate added,
- the systems.

Checks: review_test `_rebuilds`. `tests/shot_refit.tscn` pictures `refit_armour.png` and `refit_rebuild.png`. Untuned.
