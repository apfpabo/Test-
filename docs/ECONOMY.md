# The economy: prices that answer to the world

Step 2 of the owner's order of work (10 Nov 2026). Rules: `godot/scripts/campaign.gd` ("the economy": `shortage`, `supply_mult`, `market_notes`, `convoy_landed`, `convoy_lost`, `econ_day`), `diplomacy.gd` (`price_mult`, `_siege`, `capture`), `flag.gd` (storming a port). Shown on a port's Market page. Checked by section seven of `tests/review_test.tscn`; a year of `tests/soak_test.tscn` passed with it.

## What a price is made of

`base price × the port's own level (mod) × your trading (drift) × the world (supply_mult)`. The last factor is new and is kept between 0.6 and 2.4.

| Cause | Effect | Lasts |
| --- | --- | --- |
| The flag is at war | Munitions and fuel 25% dearer, medicine 15%, steel 12%, in all its ports | While the war lasts |
| A convoy makes port | What it carried gets 7% cheaper there, down to a glut of 15% under normal | Wears off |
| A convoy is lost (to you, to raiders, to an enemy squadron) | What it carried gets 12% dearer where it was bound; past 30% the news reports a shortage | Wears off |
| An attack on the port is beaten off | Food, fuel, medicine and munitions 20% dearer | Wears off |
| The port changes hands (a siege, or you storm it) | Everything 30% dearer | Wears off |
| Hostile ships lie within about 330 km: raiders, an enemy squadron in a war, a relief force off a port of yours, or you while at war with its flag | Food, fuel and medicine 3% dearer for each day they stay | Wears off once they leave |
| The flag's works are burning, taken or destroyed | The good they make is dearer in every port of the flag, up to 40% with all of them gone: farms feed food, steelworks steel, oil works fuel, industry and nuclear plants munitions and electronics | Until they are repaired or retaken |
| You hold works yourself | Their good is 6% cheaper per works in your own harbours, to 30% | While you hold them |

"Wears off" means a twentieth of the shortage goes each day: a third of it is left after three weeks.

## What follows from it

- Half of all convoys now sail for whichever port in reach is shortest of goods, so a starved port draws traffic, and that traffic is worth escorting or raiding.
- Blockade works for you too: lie off an enemy port in a war and its prices climb; sink the convoys bound for it and they climb faster.
- A cargo of food or medicine run into a besieged port sells at the shortage price.
- The Market page says why ("Supply: a convoy bound here was lost; the Vargan Directorate is at war").

## Not done yet

- The supply-based fleet limit (next).
- Standing gained for relieving a besieged port; shortages shown on the chart itself; contracts that pay more for cargo to a short port.
