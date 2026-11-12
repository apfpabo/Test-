# Armour by place

The owner gave the go-ahead on 12 Nov 2026 ("go ahead with this as proposed"). This brings the damage model closer to
Rule the Waves.

## Armour figures

Each design has its own armour:

- **Belt** (`armor`, as before).
- **Armoured deck** (`deck`).
- **Main turret faces** (`tur`).
- **Citadel** (`cit`): the share of her length the belt and deck cover.

The figures are in `ARMOUR` in `src/game.html`, taken from published figures and rounded, for 33 armoured designs.

A design with no figures of its own gets:

- a deck of 0.4 of her belt,
- turrets as thick as her belt,
- a citadel of 0.6 of her length.

All of this is read through `BattleSim.armour_of(d, rec)`. A ship's refit armour, in `rec.arm`, adds to each place.

## Where a shell strikes

Handled by `shell_result`:

- **Turret.** If the shell lands on a main turret, it strikes the turret face (three times in four). A face that is beaten puts the turret out of action. A face that holds keeps the turret safe from that hit's knock-out roll.
- **Deck.** The deck is struck more often the steeper the shell falls. The shell's fall angle runs from 3° close in to 35° at the limit of a heavy gun's range (`fall_angle`). The chance of a deck hit compares her deck, as the shell sees it, against her side above the water (`deck_share`). For the Iowa that is 17% close in and 67% at the limit.
- **Side.** The belt within the citadel. Beyond it, the side plating is 0.15 of the belt.
- **Thickness the shell meets.**
  - Deck: the plate divided by the sine of the fall angle. A flat hit can glance off.
  - Side: the plate divided by the cosine of the side angle and the cosine of the fall angle.
  - Deck at the ends: 0.35 of the armoured deck.
- **Hit at an end.** Penetrating at the bow or stern does 0.6 of the damage. A heavy shell there also gives her a small list, from water let in. Over-penetration is likely.
- **Wear.** Plate is weakened only where it was holed: belt, deck or turret.

## Penetration by calibre and range

Handled by `shell_pen`, with `frac` the shell's range as a share of the gun's range:

- **Heavy guns:** calibre × (2.0 − 1.3 × frac). The 16-inch beats 812 mm close in, 548 mm at half range and 284 mm at the limit.
- **Cruiser guns:** calibre × (1.7 − 1.15 × frac).
- **Medium guns:** calibre × (1.5 − 1.0 × frac).
- **Light guns:** calibre × (1.0 − 0.6 × frac).
- **Guns with no calibre in their id:** penetration by shell weight, as before.

## Bombs

Bombs come down on the deck. The deck now stands where the belt stood in the bomb reckoning, weighted so the results are about the same.

## Measured

Measured with `tests/armour_measure.tscn`: six seeds each, one ship against one, by day. Times are the median before → after.

| Duel | Time | Wins |
| --- | --- | --- |
| Iowa v Yamato | 597 → 577 s | Yamato still wins every time |
| KGV v Bismarck | 846 → 532 s | KGV wins 5 of 6, up from 2 of 6 (before, neither could pierce the other's belt) |
| Baltimore v Hipper | 391 → 384 s | |
| Cleveland v Sverdlov | 409 → 330 s | |
| Iowa v Des Moines | 352 → 353 s | |

Untuned.

## Checks and display

- **Checks:** review_test `_armour`.
- **Battle screen:** the flagship panel shows belt, deck and turrets separately.
- **Yard and refit pages:** list all three.
