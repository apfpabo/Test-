## The first change: a new captain's grace

At the owner's word after the first sheet, bounty squadrons leave a new captain alone for his first 30 days (`Campaign.BOUNTY_GRACE`). In that time one in sight keeps its distance as it would from a stronger force, and none is placed within 300 units of him at the start. Sail into one and it still fights. The same 32 runs, before and after:

| Origin | Squadron lost on day, before | After | What sank them, after |
|---|---|---|---|
| The Merchant Captain | 41, 142, 127, 2 | 41, 142, 127, survived | raiders, a bounty squadron, raiders |
| The Hijacker | 148, three survived | 148, 143, two survived | the hunters sent after him, a convoy's escort |
| The Smuggler | 175, three survived | 175, three survived | raiders |
| The Privateer | 21, three survived | all four survived | |
| The Disgraced Officer | 170, 89, two survived | 89, 16, two survived | a bounty squadron, raiders |
| The Survivor of the Lost Fleet | 50, 114, 107, 17 | unchanged | the hunters, a patrol, raiders |
| The Defector | 61, 34, 43, 23 | 87, 34, 43, 23 | the hunters, a patrol |
| The Academy Cast-Off | 5, survived, 2, 15 | 152, 200, 153, 67 | bounty squadrons, all four |

**What it did.** No bounty squadron was met in the first 30 days (there had been 12 meetings), and the deaths in the first fortnight are gone. The Academy Cast-Off now lives 67 to 200 days instead of 2 to 15, and saves 12,000 to 64,000 credits doing it. Every Privateer survives.

**What it did not do.** 20 runs of 32 still end before day 240, the same count as before. Once the grace is over, bounty squadrons find the Academy's lone corvette as before. The Survivor and the Defector are run down by the hunters their origins send after them, or by patrols, whatever the grace. (The first sheet said 15 of 32 runs were lost. That was a miscount; it was 20.)

## The second change: forces that come looking for you are sized to you

At the owner's word, after the first change:
- **Bounty squadrons** are posted at 0.8 to 2.5 times your squadron's strength, a random point in that range, so some can be taken and some should be left alone. The bounty is never less than 15,000 nor more than 2,500,000 credits' worth of ships (`BOUNTY_SIZE`, `BOUNTY_FLOOR`, `BOUNTY_CEIL`). It may draw cruisers and battleships, so it can match a big fleet.
- **The hunters an origin sends after you** come at 1.5 times your strength (`HUNT_K`), never bigger than the origin's own budget for them. None comes before day 40 (`HUNT_GRACE`).
- Patrols, raiders and the navies are not scaled.

The same 32 runs, squadron lost on day:

| Origin | Before either change | With the grace | With the grace and the sizing | What sank them, last column |
|---|---|---|---|---|
| The Merchant Captain | 41, 142, 127, 2 | 41, 142, 127, survived | all four survived | |
| The Hijacker | 148, three survived | 148, 143, two survived | 231, 191, two survived | patrols |
| The Smuggler | 175, three survived | 175, three survived | 214, three survived | raiders |
| The Privateer | 21, three survived | all four survived | 162, three survived | a patrol |
| The Disgraced Officer | 170, 89, two survived | 89, 16, two survived | 93, 194, two survived | bounty squadrons |
| The Survivor of the Lost Fleet | 50, 114, 107, 17 | unchanged | 137, 104, 98, survived | hunters, a bounty squadron |
| The Defector | 61, 34, 43, 23 | 87, 34, 43, 23 | 100, 63, 118, 74 | hunters, raiders, a bounty squadron |
| The Academy Cast-Off | 5, survived, 2, 15 | 152, 200, 153, 67 | 47, 129, two survived | a bounty squadron, raiders |
| **Runs lost of 32** | **20** | **20** | **15** | |

**What it did.** Bounty squadrons and hunters now come at 0.6 to 2.2 times the squadron they meet, where before they came at 6 to 22 times. Every Merchant now survives and grows rich enough for a heavy cruiser (days 43–140) and, in three runs, a battleship (days 183–238). The Survivor lives to day 98–137 instead of 17–114, and one run lives out the 240 days. The Defector lives to day 63–118 instead of 23–87.

**What it did not do.** The Survivor's and the Defector's purses are empty by about day 60–120 in every run. Their ships go unrepaired and their crews unpaid, and they lose fights they would otherwise win. That is the wages-against-income problem, the next step. The Academy now loses to patrols and raiders as often as to bounties.

## The third change: half pay, and better prize money

At the owner's word:
- **Half pay.** Officers draw half their pay (`HALF_PAY`) while you serve no one: no commission, no contract in hand and no flag of your own. The fleet page says so beside the wages.
- **Better prize money.** Prize money for a ship sunk is 15–25% of what she was worth (`PRIZE_MONEY`); it was 7–13%.

The same 32 runs, squadron lost on day:

| Origin | With the first two changes | With the third as well | Purse at the end, third (thousands) |
|---|---|---|---|
| The Merchant Captain | all four survived | all four survived | 109, 103, 113, 60 |
| The Hijacker | 231, 191, two survived | 231, 178, two survived | 27, 48, 33, 24 |
| The Smuggler | 214, three survived | 214, three survived | 43, 69, 44, 42 |
| The Privateer | 162, three survived | all four survived | 27, 41, 39, 34 |
| The Disgraced Officer | 93, 194, two survived | 148, three survived | 0, 1, 0, 0 |
| The Survivor of the Lost Fleet | 137, 104, 98, survived | 137, 154, two survived | 0, 0, 15, 0 |
| The Defector | 100, 63, 118, 74 | 222, 136, 88, 66 | 0, 0, 5, 14 |
| The Academy Cast-Off | 47, 129, two survived | 47, 129, two survived | 12, 38, 22, 19 |
| **Runs lost of 32** | **15** | **12** | |

**What it did.** The Defector's battles now pay about 260 a day, and his squadron lasts longer (to day 66–222). The Disgraced Officer and the Survivor each lose one run fewer.

**What it did not do.** The three navy origins still go broke:
- The Survivor is broke by day 4 to 11, before pay matters. He starts with 6,000 credits and spends about 105 a day on fuel, food and hiring crew.
- The Disgraced Officer is broke by day 62 to 83. He holds a contract most of the time, so his officers are seldom on half pay.
- The Defector's cruiser costs about 460 a day in wages, repairs and stores together.

Half pay as built helps a captain only between jobs.

## The fourth change: the navy origins' starting money

At the owner's word, numbers only; the origins' text is untouched:
- **The Disgraced Officer** draws a half-pay pension of 2,500 every 30 days for his first year (perk `pension`).
- **The Defector** starts with 30,000 instead of 20,000, and his new patrons pay a debriefing retainer of 4,500 every 30 days for his first half year.
- **The Survivor** starts with 14,000 instead of 6,000, 85% of his crew instead of 70%, and fuel and food for about a month.

The same seeds, these three origins:

| Origin | Lost on day, before | After | Broke on day, before | After | Purse at the end, after (thousands) |
|---|---|---|---|---|---|
| The Disgraced Officer | 148, three survived | 87, three survived | 76, never, 83, 62 | never, never, never, 88 | 6, 20, 41, 15 |
| The Survivor of the Lost Fleet | 137, 154, two survived | 227, 9, two survived | 4, 11, 9, 7 | 53, never, never, 181 | 0, 55, 13, 0 |
| The Defector | 222, 136, 88, 66 | 183, 139, 81, survived | 91, 94, 38, 50 | never, never, never, 55 | 36, 10, 12, 0 |

All 32 runs: 11 lost by day 240 (12 before this change, 20 before any). Most navy captains now stay solvent. They are still lost more often than traders, now in battle rather than to bankruptcy. The Survivor lost on day 9 was caught by raiders before his first port.

## Measured again: 12 Nov 2026, after the features since

No numbers changed; the same 32 runs on the same seeds, now with everything added since the fourth change: ships that age
and wear, wrecks raised, air raids from the land, points of interest, officers' tempers, Era IV, research by levels
(the other powers' technologies now reach levels II and III as their eras advance), the super battleships, and the
first-day changes since (Steer to meet, the autosave).

| Origin | Lost on day, after the fourth change | Now | What sank them, now |
|---|---|---|---|
| The Merchant Captain | all four survived | 133, 66, survived, 31 | raiders, raiders, a bounty squadron (day 31, the day after the grace) |
| The Hijacker | 231, 178, two survived | survived, 101, 58, survived | a patrol, the hunters |
| The Smuggler | 214, three survived | all four survived | |
| The Privateer | all four survived | all four survived | |
| The Disgraced Officer | 87, three survived | 161, three survived | raiders |
| The Survivor of the Lost Fleet | 227, 9, two survived | three survived, 53 | raiders |
| The Defector | 183, 139, 81, survived | 116, survived, 54, 71 | the hunters, patrols |
| The Academy Cast-Off | 47, 129, two survived | survived, 44, two survived | a bounty squadron |
| **Runs lost of 32** | **11** | **11** | |

**What stands out.** The total is unchanged, but the Merchant, the safest start before, now loses three runs of four. Each
time a few motor torpedo boats, with a corvette or a destroyer, catch her lone freighter; she tries to break off, fails,
and is sunk. To test whether ageing was the cause (wear slows a ship), the four Merchant seeds were run again with wear
switched off: she was still lost three times (days 83, 149, 58). So it is not wear. The likeliest causes are the other
powers' research levels (raiders' torpedoes and guns a step better) and chance: four seeds an origin is a small sample,
and every new random draw since (points of interest, tempers) changes what each seed meets. For the owner: whether a
merchant's first freighter should be able to outrun or outlast a few torpedo boats, or whether that is a fair danger
of the trade.

## Tuning round 1: three changes the owner chose (12 Nov 2026)

The owner picked all three proposals (A, B, C in [`OWNER_DECISIONS.md`](OWNER_DECISIONS.md)):

- **A.** The Merchant gets an evasion perk of 25.
- **B.** Raider flotillas keep a new captain's 30-day grace and are never placed on top of a new captain.
- **C.** The Survivor gets back pay: 2,000 every 30 days for 180 days.

The same 32 runs were made on the same seeds. Everything added since the last measurement is in them too: tales,
armour by place, refits with armour, electronic war, save slots.

| Origin | Lost on day, before | Now | What sank them, now |
|---|---|---|---|
| The Merchant Captain | 133, 66, survived, 31 | 133, three survived | raiders |
| The Survivor of the Lost Fleet | three survived, 53 | all four survived | |
| The Academy Cast-Off | survived, 44, two survived | three survived, 82 | raiders |
| The Hijacker | survived, 101, 58, survived | 225, 150, 59, 213 | the hunters |
| The Defector | 116, survived, 54, 71 | 94, 149, 56, 151 | patrols, the hunters, a story force |
| The Disgraced Officer | 161, three survived | 87, survived, 39, survived | a story force, raiders |
| The Smuggler | all four survived | all four survived | |
| The Privateer | all four survived | all four survived | |
| **Runs lost of 32** | **11** | **12** | |

**What it did.**

- **Two of the changes did what they were for.** The Merchant now loses one run in four instead of three, on day 133 to raiders, as before on that seed. The Survivor lives out all four runs, and his purse rises to between 21,000 and 35,000 by the end in three of them; the fourth ended with nothing.
- **The total did not fall.** The Hijacker and the Defector lost more. Neither was touched by these changes. Both now lose to the forces their origins send after them (the hunters) and to patrols, mostly after day 90. The Disgraced Officer lost two runs, one to a story force on day 87.
- **Likeliest cause:** chance moving with the new random draws. The grace changes where raiders are placed at the start, and every draw after that differs. Four seeds an origin is still a small sample.

**For the owner, if he wants a second round:** whether the Hijacker's and the Defector's hunters, now the main danger to
them, should come less often or later. They come at 1.5 times the squadron's strength from day 40.

## What stands out

For the owner to judge. The four changes above are the only ones made. (The figures below were measured before the fourth change; the table above has the navy origins after it.)

- **Fewer lone starts are lost** (12 of 32 by day 240, from 20). Bounty squadrons and hunters are now fights a captain can choose. What still ends the navy origins is money.
- **The navy origins cannot pay their way.** Per day afloat in the first 120 days:
  - The Disgraced Officer made about 150 against 155 in wages and 50 in repairs and stores.
  - The Survivor made about 230 against 130 in wages and 125 in repairs and stores, and was broke within his first fortnight.
  - The Defector made about 310, mostly prizes, against 240 in wages and 220 in repairs and stores.
- **Traders do well.** The Merchant made about 310 a day from trade against 45 in wages, and the Smuggler about 330 from trade and contracts against 105. The Privateer made about 180 against 105. The Hijacker made about 115, mostly contracts, against 10.
- **A destroyer is in reach at once for four origins, a heavy cruiser for the Merchant only.** The cheapest destroyer (17,000) is affordable on day 1 for the Merchant, the Smuggler, the Privateer and the Defector. A heavy cruiser (62,000) is affordable for every Merchant by about day 140, and a battleship (105,000) for three of them by day 240.
- **Prices are steady, the spread between ports is wide.** Port medians hardly move over the eight months. The cheapest and dearest ports differ by four to five times for medicine, munitions and electronics, so the first ton often shows a margin over 100%. But each ton bought raises the price by 0.3% and each ton sold lowers it as much, so a full hold earns far less than that first ton suggests.
- **Two hours of play falls between day 130 and day 230.** That is by the model under "How it was measured"; battles are most of the player's time.

