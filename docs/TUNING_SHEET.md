# Tuning sheet: the first hours of a campaign

*A report for the owner's tuning pass (11 Nov 2026). All figures are measured, untuned, and his to judge. Four changes have been made since the first sheet, at his word: a 30-day grace from bounty squadrons, bounty squadrons and hunters sized to the captain's own squadron, half pay with better prize money, and more starting money for the navy origins (see the four "change" sections). The tables are measured with all four.*

## How it was measured

`tests/tune_probe.tscn` is the soak test's unattended captain (`tests/soak_test.gd`: real weather and calendar, every hostile contact fought out by the battle simulation as the battle screen sets it up) with **honest money**: the purse is never topped up and none of the soak's scripted events (reinforcements, a flag, the bomb) are run. In port he sells his cargo, repairs and rearms if he can pay, hires crew to need, buys fuel to the bunkers' room and food for forty days, takes contracts, commissions and story orders as the soak does, and rests a tired squadron. Before sailing he buys the good with the best margin at the port he is bound for, as many tons as still pay (prices move ton by ton). He is prudent, as a player would be: from any force that is not clearly weaker (the contact panel's strength ratio over 0.8, "an even fight" or worse) he tries to break off at the panel's own odds; caught all the same and outgunned, he orders a withdrawal; and until he has three ships he takes only peaceful contracts (deliveries, surveys, escorts, smuggling), no hunts, war contracts, strikes or story orders. He takes prizes, but **buys no ships**, so "affordable" below is read off his purse: the first day his money covers the cheapest design of that class he could order with the research he holds. He does no research of his own, and goes looking for a fight only once he has three ships.

Each origin was played for up to 240 days on four seeds (11, 23, 37, 51), the navy origins for the Concord. A run ends when the squadron is lost. Figures are the mean of the runs still afloat in that period (the "Afloat" column says how many).

**Days into hours.** A chart day lasts 10 s at 1×. The sheet assumes a battle takes 8 minutes of the player's time, a port call 1.5 minutes and any other contact 20 seconds, and reads off the day at which one and two hours are reached with the chart running at 2× and at 4×. These are assumptions, not measurements: the day columns are the measurement.

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

## At a glance

| Origin | Starts with | Credits at start | Purse day 30 | Day 60 | Day 120 | Day 240 | Battles (won) in 240 days | 1 h / 2 h of play at 2× (day) | at 4× (day) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| The Merchant Captain | fr_victory | 45,000 | 46,136 | 65,793 | 57,124 | 74,851 | 3.2 (1.2) · squadron lost on day 133 | 185 / – | 199 / – |
| The Hijacker | fr_liberty, pt_elco | 9,000 | 10,095 | 12,990 | 29,907 | 47,964 | 16.5 (1.2) · squadron lost on day 225, 150, 59, 213 | 82 / 120 | 88 / 127 |
| The Smuggler | dd_soldati | 28,000 | 29,949 | 30,990 | 26,106 | 24,500 | 2.2 (0.5) | 174 / – | 187 / – |
| The Privateer | dd_soldati | 20,000 | 18,681 | 22,358 | 32,277 | 23,280 | 2.0 (0.2) | 176 / – | 205 / – |
| The Disgraced Officer | dd_fletcher | 14,000 | 12,218 | 23,280 | 12,520 | 4,670 | 2.2 (0.5) · squadron lost on day 87, 39 | 155 / – | 166 / – |
| The Survivor of the Lost Fleet | dd_fletcher | 14,000 | 9,443 | 12,572 | 18,086 | 23,364 | 5.5 (0.2) | 155 / 149 | 169 / 149 |
| The Defector | cl_cleveland | 30,000 | 17,427 | 12,047 | 14,266 | – | 3.0 (2.0) · squadron lost on day 94, 149, 56, 151 | 147 / – | – / – |
| The Academy Cast-Off | co_flower | 15,000 | 13,480 | 15,320 | 23,391 | 33,842 | 2.0 (0.2) · squadron lost on day 82 | 152 / – | 156 / – |

## The Merchant Captain

Starts at Cape Ombra with fr_victory and 45,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 43,607 | -93 | -675 | 0 | 0 | 0 | -5 | −470 | −0 | −243 |
| 16–30 | 46,136 | 169 | 4,168 | 0 | 0 | 0 | -15 | −624 | −0 | −1,000 |
| 31–60 | 65,793 | 655 | 12,410 | 1,825 | 0 | 9,862 | -2,369 | −1,664 | −0 | −408 |
| 61–90 | 56,037 | -289 | -2,844 | 0 | 0 | 662 | -2,355 | −1,777 | −614 | −996 |
| 91–120 | 57,124 | 18 | 3,462 | 2,525 | 0 | 0 | -1,707 | −1,838 | −663 | −691 |
| 121–180 | 56,214 | -92 | 2,942 | 2,550 | 0 | 0 | -1,350 | −2,998 | −90 | −1,964 |
| 181–240 | 74,851 | 150 | 8,160 | 3,567 | 0 | 3,467 | -2,075 | −3,095 | −430 | −793 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.2 (7,623) | 1.0 | 0.0 | 1.0 (1.0) | 2.0 | 140 (276) | 1.8 | 0.2 |
| 61–90 | 4 | 1.2 (7,623) | 0.2 | 0.0 | 0.2 (0.0) | 2.0 | 819 (819) | 0.2 | 0.0 |
| 91–120 | 4 | 1.2 (7,623) | 1.2 | 0.8 | 0.5 (0.0) | 1.0 | 769 (769) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (5,723) | 2.0 | 1.2 | 0.8 (0.0) | 3.0 | 1,128 (2,026) | 0.0 | 0.5 |
| 181–240 | 3 | 1.0 (5,097) | 1.7 | 0.7 | 1.0 (0.3) | 3.0 | 1,666 (3,020) | 1.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 35, submarine 12, corvette 4, destroyer 3.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 1, 1, 1, 1 |
| Freighter | fr_liberty | 22,000 | 1, 1, 1, 1 |
| Fleet oiler | ao_t2 | 24,000 | 1, 1, 1, 1 |
| Ammunition ship | ae_hood | 38,000 | 1, 1, 1, 1 |
| Repair ship | ar_diver | 26,000 | 1, 1, 1, 1 |
| Light cruiser | cl_agano | 36,000 | 1, 1, 1, 1 |
| Escort carrier | cve_casa | 58,000 | 32, 44, 37, 35 |
| Heavy cruiser | ca_zara | 62,000 | never, 107, 37, 35 |
| Battleship | bb_scharnhorst | 105,000 | never, never, 207, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Hijacker

Starts at Kesselport with fr_liberty, pt_elco and 9,000 credits. Two hours of play fall about day 120 with the chart at 2×, day 127 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 11,860 | 191 | -626 | 2,150 | 0 | 2,588 | 1 | −627 | −269 | −357 |
| 16–30 | 10,095 | -118 | 0 | 0 | 0 | 0 | -1,075 | −690 | −0 | −0 |
| 31–60 | 12,990 | 100 | 711 | 4,275 | 33 | 2,725 | -687 | −926 | −1,505 | −1,731 |
| 61–90 | 19,292 | 89 | -6 | 3,933 | 0 | 0 | -296 | −189 | −1,232 | −87 |
| 91–120 | 29,907 | 366 | -153 | 11,233 | 0 | 0 | -4 | −121 | −235 | −104 |
| 121–180 | 45,298 | 372 | 77 | 14,267 | 0 | 1,533 | -19 | −170 | −190 | −107 |
| 181–240 | 47,964 | -2 | 122 | 0 | 0 | 0 | -2 | −101 | −66 | −32 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 2.0 (5,685) | 1.8 | 0.8 | 1.0 (0.5) | 3.3 | 8,675 (21,692) | 1.0 | 0.5 |
| 16–30 | 4 | 2.0 (5,685) | 1.2 | 1.0 | 0.2 (0.0) | 4.0 | 5,130 (14,984) | 0.0 | 0.0 |
| 31–60 | 4 | 1.5 (3,650) | 5.8 | 2.5 | 3.2 (0.2) | 2.4 | 4,878 (22,965) | 1.0 | 1.0 |
| 61–90 | 3 | 1.3 (67) | 6.7 | 4.0 | 2.7 (0.0) | 2.7 | 5,327 (24,692) | 0.0 | 0.3 |
| 91–120 | 3 | 1.3 (67) | 11.0 | 7.0 | 4.0 (0.0) | 2.3 | 5,950 (25,092) | 0.0 | 0.0 |
| 121–180 | 3 | 1.7 (97) | 15.0 | 9.3 | 5.7 (0.7) | 2.1 | 3,723 (24,090) | 0.7 | 1.0 |
| 181–240 | 2 | 1.0 (50) | 9.5 | 4.0 | 5.5 (0.0) | 2.3 | 3,968 (16,890) | 0.0 | 1.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 171, freighter 70, corvette 63, destroyer 53, submarine 9, heavy cruiser 2.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 118, 96, never, 14 |
| Submarine | ss_vii | 26,000 | never, 123, never, 49 |
| Freighter | fr_liberty | 22,000 | 129, 96, never, 49 |
| Fleet oiler | ao_t2 | 24,000 | 129, 96, never, 49 |
| Ammunition ship | ae_hood | 38,000 | never, 137, never, 108 |
| Repair ship | ar_diver | 26,000 | never, 123, never, 49 |
| Light cruiser | cl_agano | 36,000 | never, 137, never, 108 |
| Escort carrier | cve_casa | 58,000 | never, never, never, 133 |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, 156 |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Smuggler

Starts at Port Saffron with dd_soldati and 28,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 29,843 | 123 | 3,609 | 0 | 0 | 0 | -40 | −1,414 | −116 | −196 |
| 16–30 | 29,949 | 7 | 1,926 | 0 | 0 | 0 | 0 | −1,584 | −16 | −220 |
| 31–60 | 30,990 | 37 | 3,321 | 2,050 | 0 | 0 | -176 | −3,101 | −112 | −942 |
| 61–90 | 27,108 | -133 | 796 | 0 | 0 | 0 | -714 | −3,272 | −45 | −647 |
| 91–120 | 26,106 | -35 | 3,246 | 0 | 0 | 0 | -0 | −3,272 | −0 | −976 |
| 121–180 | 27,245 | 15 | 6,911 | 0 | 0 | 2,412 | -720 | −6,266 | −72 | −1,464 |
| 181–240 | 24,500 | -48 | 4,605 | 2,575 | 375 | 0 | -2,389 | −6,183 | −57 | −1,672 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 0.5 | 0.2 | 0.2 (0.0) | 4.5 | 1,153 (2,064) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 0.5 | 0.5 | 0.0 (0.0) | 3.5 | 1,458 (2,840) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 0.2 | 0.2 | 0.0 (0.0) | 3.0 | 192 (192) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 1.8 | 0.8 | 1.0 (0.5) | 2.7 | 2,705 (7,213) | 0.8 | 0.0 |
| 181–240 | 4 | 1.0 (1,830) | 2.5 | 1.5 | 1.0 (0.0) | 3.9 | 5,846 (18,400) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 44, destroyer 15, corvette 15, light cruiser 2, freighter 1.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 1, 1, 1, 1 |
| Freighter | fr_liberty | 22,000 | 1, 1, 1, 1 |
| Fleet oiler | ao_t2 | 24,000 | 1, 1, 1, 1 |
| Ammunition ship | ae_hood | 38,000 | never, never, never, 53 |
| Repair ship | ar_diver | 26,000 | 1, 1, 1, 1 |
| Light cruiser | cl_agano | 36,000 | never, never, never, 38 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Privateer

Starts at Puerto Corvo with dd_soldati and 20,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 17,841 | -144 | -92 | 0 | 0 | 0 | 0 | −1,664 | −80 | −323 |
| 16–30 | 18,681 | 56 | 1,091 | 0 | 0 | 712 | 1,999 | −1,667 | −896 | −399 |
| 31–60 | 22,358 | 124 | 3,221 | 2,550 | 2,000 | 0 | -406 | −3,187 | −0 | −501 |
| 61–90 | 37,017 | 498 | 2,520 | 13,950 | 1,893 | 0 | 198 | −3,261 | −14 | −627 |
| 91–120 | 32,277 | -167 | 1,032 | 0 | 2,003 | 0 | -2,999 | −3,059 | −611 | −1,106 |
| 121–180 | 26,113 | -106 | 634 | 0 | 4,006 | 0 | -2,183 | −6,021 | −794 | −1,806 |
| 181–240 | 23,280 | -49 | 3,410 | 1,250 | 4,000 | 0 | -2,658 | −5,732 | −365 | −2,740 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.2 (1,853) | 0.2 | 0.0 | 0.2 (0.2) | 1.0 | 92 (92) | 0.2 | 0.0 |
| 31–60 | 4 | 1.2 (1,853) | 2.0 | 1.2 | 0.8 (0.0) | 3.4 | 4,629 (22,184) | 0.0 | 0.0 |
| 61–90 | 4 | 1.2 (1,853) | 0.2 | 0.2 | 0.0 (0.0) | 2.0 | 1,538 (1,538) | 0.0 | 0.0 |
| 91–120 | 4 | 1.2 (1,853) | 0.5 | 0.5 | 0.0 (0.0) | 3.5 | 8,898 (14,584) | 0.0 | 0.0 |
| 121–180 | 4 | 1.2 (1,853) | 0.8 | 0.5 | 0.2 (0.0) | 3.3 | 2,601 (3,494) | 0.0 | 0.0 |
| 181–240 | 4 | 1.2 (1,853) | 1.8 | 1.0 | 0.8 (0.0) | 3.1 | 4,899 (17,092) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 37, destroyer 12, corvette 9, freighter 7, submarine 4.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | never, 87, 53, 68 |
| Freighter | fr_liberty | 22,000 | never, 87, 53, 68 |
| Fleet oiler | ao_t2 | 24,000 | never, 87, 53, 68 |
| Ammunition ship | ae_hood | 38,000 | never, never, 68, 87 |
| Repair ship | ar_diver | 26,000 | never, 87, 53, 68 |
| Light cruiser | cl_agano | 36,000 | never, never, 62, 87 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Disgraced Officer

Starts at Halbrook with dd_fletcher and 14,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 10,238 | -251 | 149 | 0 | 0 | 0 | -60 | −2,165 | −1,298 | −388 |
| 16–30 | 12,218 | 132 | 896 | 1,800 | 2,500 | 0 | 0 | −2,540 | −75 | −601 |
| 31–60 | 23,280 | 485 | 202 | 4,775 | 1,875 | 8,850 | 0 | −4,035 | −0 | −605 |
| 61–90 | 16,542 | -402 | 1,195 | 2,833 | 1,671 | 0 | -2,473 | −4,164 | −3,522 | −4,699 |
| 91–120 | 12,520 | -62 | 234 | 0 | 3,499 | 0 | -169 | −4,816 | −0 | −498 |
| 121–180 | 10,417 | -36 | 1,392 | 6,000 | 7,277 | 0 | -2,440 | −9,152 | −0 | −5,180 |
| 181–240 | 4,670 | -104 | 2,594 | 0 | 4,877 | 0 | -285 | −8,376 | −200 | −4,358 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.8 (2,523) | 0.8 | 0.0 | 0.8 (0.5) | 3.3 | 759 (1,850) | 1.8 | 0.5 |
| 61–90 | 3 | 2.0 (2,681) | 1.3 | 0.3 | 1.0 (0.0) | 3.2 | 2,021 (2,083) | 0.7 | 1.3 |
| 91–120 | 2 | 1.0 (2,050) | 0.5 | 0.5 | 0.0 (0.0) | 4.0 | 1,851 (1,851) | 0.0 | 0.0 |
| 121–180 | 2 | 1.0 (2,050) | 1.5 | 1.0 | 0.5 (0.0) | 6.0 | 2,902 (3,149) | 0.0 | 0.0 |
| 181–240 | 2 | 1.0 (2,050) | 1.5 | 0.5 | 1.0 (0.0) | 3.3 | 2,046 (2,987) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 38, destroyer 8, corvette 6, submarine 3.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 39, 61, never, never |
| Submarine | ss_vii | 26,000 | 40, never, never, never |
| Freighter | fr_liberty | 22,000 | 39, 90, never, never |
| Fleet oiler | ao_t2 | 24,000 | 39, 90, never, never |
| Ammunition ship | ae_hood | 38,000 | 40, never, never, never |
| Repair ship | ar_diver | 26,000 | 40, never, never, never |
| Light cruiser | cl_agano | 36,000 | 40, never, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Survivor of the Lost Fleet

Starts at Halvardsby with dd_fletcher and 14,000 credits. Two hours of play fall about day 149 with the chart at 2×, day 149 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 8,876 | -342 | -180 | 0 | 0 | 0 | -51 | −1,833 | −1,731 | −1,330 |
| 16–30 | 9,443 | 38 | 704 | 1,650 | 2,000 | 0 | -17 | −2,359 | −591 | −820 |
| 31–60 | 12,572 | 108 | 407 | 6,900 | 1,500 | 0 | 0 | −4,996 | −0 | −682 |
| 61–90 | 15,173 | 69 | 788 | 4,300 | 2,887 | 662 | -712 | −4,664 | −221 | −935 |
| 91–120 | 18,086 | 94 | 118 | 7,500 | 1,689 | 0 | 352 | −4,218 | −0 | −2,527 |
| 121–180 | 22,340 | 77 | 2,554 | 9,600 | 3,000 | 0 | 350 | −9,327 | −24 | −1,904 |
| 181–240 | 23,364 | 20 | 1,749 | 10,500 | 238 | 0 | -215 | −9,344 | −30 | −1,696 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 0.2 | 0.2 | 0.0 (0.0) | 6.0 | 2,630 (2,630) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (2,050) | 1.2 | 1.2 | 0.0 (0.0) | 3.6 | 1,161 (1,924) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (2,050) | 1.2 | 1.0 | 0.2 (0.2) | 3.6 | 1,427 (2,175) | 0.2 | 0.0 |
| 91–120 | 4 | 1.0 (2,050) | 1.5 | 0.5 | 1.0 (0.0) | 3.8 | 753 (2,680) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (2,050) | 4.5 | 1.0 | 3.5 (0.0) | 4.0 | 734 (3,752) | 0.0 | 0.0 |
| 181–240 | 4 | 1.0 (2,050) | 1.2 | 0.5 | 0.8 (0.0) | 4.6 | 2,595 (4,825) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 134, submarine 9, destroyer 9, corvette 8.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 200, 49, never, 56 |
| Submarine | ss_vii | 26,000 | 206, 211, never, 73 |
| Freighter | fr_liberty | 22,000 | 206, 49, never, 73 |
| Fleet oiler | ao_t2 | 24,000 | 206, 211, never, 73 |
| Ammunition ship | ae_hood | 38,000 | never, never, never, 180 |
| Repair ship | ar_diver | 26,000 | 206, 211, never, 73 |
| Light cruiser | cl_agano | 36,000 | never, never, never, 90 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Defector

Starts at Strelsk with cl_cleveland and 30,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 30,389 | 26 | 332 | 0 | 1 | 7,338 | -12 | −3,475 | −861 | −2,934 |
| 16–30 | 17,427 | -1,074 | 96 | 0 | 3,682 | 4,050 | -732 | −3,025 | −8,663 | −8,370 |
| 31–60 | 12,047 | -243 | 590 | 4,800 | 7,242 | 1,088 | -2,073 | −6,779 | −1,306 | −9,693 |
| 61–90 | 13,333 | 28 | 0 | 5,167 | 6,776 | 0 | -1,135 | −5,499 | −0 | −4,483 |
| 91–120 | 14,266 | 3 | 0 | 2,167 | 4,288 | 0 | 624 | −3,806 | −0 | −2,339 |
| 121–180 | 20,155 | 24 | 0 | 0 | 0 | 7,150 | -15 | −4,536 | −520 | −1,320 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.8 (14,510) | 1.5 | 0.5 | 1.0 (1.0) | 2.8 | 10,835 (24,280) | 1.5 | 0.2 |
| 16–30 | 4 | 2.2 (15,818) | 0.5 | 0.0 | 0.5 (0.5) | 2.0 | 3,801 (4,046) | 0.8 | 0.0 |
| 31–60 | 4 | 2.5 (16,472) | 0.8 | 0.2 | 0.5 (0.2) | 2.3 | 4,361 (4,666) | 0.2 | 0.8 |
| 61–90 | 3 | 2.3 (16,844) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 91–120 | 3 | 2.3 (16,844) | 0.3 | 0.0 | 0.3 (0.0) | 2.0 | 9,960 (9,960) | 0.0 | 1.0 |
| 121–180 | 2 | 3.0 (18,180) | 2.5 | 1.0 | 1.5 (0.5) | 3.0 | 5,794 (8,580) | 2.0 | 3.0 |
| 181–240 | 0 | | | | | | | | |

Enemy ships met in 240 days, by class (all seeds): corvette 22, destroyer 11, light cruiser 5, freighter 5, motor torpedo boat 2.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 1, 1, 1, 1 |
| Freighter | fr_liberty | 22,000 | 1, 1, 1, 1 |
| Fleet oiler | ao_t2 | 24,000 | 1, 1, 1, 1 |
| Ammunition ship | ae_hood | 38,000 | never, never, 8, 6 |
| Repair ship | ar_diver | 26,000 | 1, 1, 1, 1 |
| Light cruiser | cl_agano | 36,000 | never, 149, 8, 6 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Academy Cast-Off

Starts at Calder Roads with co_flower and 15,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 14,378 | -42 | 0 | 0 | 0 | 0 | -15 | −536 | −43 | −28 |
| 16–30 | 13,480 | -60 | 0 | 0 | 0 | 0 | -5 | −751 | −32 | −109 |
| 31–60 | 15,320 | 59 | 35 | 3,700 | 0 | 0 | 31 | −1,530 | −13 | −385 |
| 61–90 | 17,810 | 82 | 16 | 4,125 | 0 | 0 | 58 | −1,437 | −0 | −270 |
| 91–120 | 23,391 | 113 | -14 | 4,900 | 0 | 0 | 77 | −1,343 | −0 | −528 |
| 121–180 | 32,710 | 166 | 1,680 | 9,433 | 0 | 2,100 | 187 | −2,712 | −709 | −787 |
| 181–240 | 33,842 | 21 | 774 | 3,100 | 0 | 0 | 419 | −2,261 | −0 | −900 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (940) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (940) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (940) | 0.8 | 0.0 | 0.8 (0.0) | 2.0 | 1,652 (4,840) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (940) | 0.5 | 0.2 | 0.2 (0.0) | 4.0 | 5,071 (5,071) | 0.0 | 0.2 |
| 91–120 | 3 | 1.0 (940) | 0.3 | 0.0 | 0.3 (0.0) | 2.0 | 142 (142) | 0.0 | 0.0 |
| 121–180 | 3 | 1.3 (957) | 1.3 | 0.3 | 1.0 (0.3) | 3.0 | 1,675 (2,490) | 0.7 | 0.0 |
| 181–240 | 3 | 1.3 (957) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 14, corvette 9, destroyer 3, submarine 2.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | never, never, 51, 71 |
| Submarine | ss_vii | 26,000 | never, never, 54, 128 |
| Freighter | fr_liberty | 22,000 | never, never, 54, 128 |
| Fleet oiler | ao_t2 | 24,000 | never, never, 54, 128 |
| Ammunition ship | ae_hood | 38,000 | never, never, 97, 151 |
| Repair ship | ar_diver | 26,000 | never, never, 54, 128 |
| Light cruiser | cl_agano | 36,000 | never, never, 97, 151 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## Prices in port

Port prices (before the 6% buying and 7% selling spread) seen by all captains when they made harbour, as median (lowest–highest).

| Days | Fuel | Food | Steel | Medicine | Munitions | Electronics |
|---|---:|---:|---:|---:|---:|---:|
| 1–15 | 8 (6–14) | 16 (6–41) | 32 (17–59) | 76 (47–155) | 54 (35–122) | 112 (46–224) |
| 16–30 | 8 (6–14) | 15 (6–33) | 32 (18–58) | 84 (45–162) | 63 (28–115) | 103 (44–238) |
| 31–60 | 7 (5–13) | 15 (6–36) | 33 (14–58) | 81 (44–155) | 69 (25–118) | 89 (47–267) |
| 61–90 | 7 (5–14) | 16 (6–33) | 34 (14–61) | 80 (46–159) | 63 (26–112) | 89 (48–224) |
| 91–120 | 8 (5–15) | 14 (7–35) | 30 (15–59) | 93 (44–160) | 64 (26–114) | 95 (45–215) |
| 121–180 | 8 (5–14) | 16 (6–34) | 32 (17–60) | 82 (40–164) | 58 (25–116) | 104 (44–227) |
| 181–240 | 8 (5–15) | 16 (6–38) | 33 (17–58) | 81 (40–156) | 84 (25–120) | 80 (43–224) |


## The Defector's and the Hijacker's hunters (13 Nov 2026, measured; nothing in the game changed)

`tests/tune_probe.tscn` now takes two test-only settings from the environment: `HUNT_SCALE` rebuilds every hunter group
at that multiple of the strength the game gave it, and `HUNT_MAX` caps how many groups of one origin may be out at once.
It also records each hunter group as it appears (`hunters` in the JSON). Each origin was played for 240 days on eight
seeds (11, 23, 37, 51, 61, 73, 89, 97), the Defector for the Concord, the honest-money captain as above, four ways:

| Setting | The Defector: squadron lost on day | The Hijacker: squadron lost on day |
|---|---|---|
| As the game is (`HUNT_K` 1.15 rising to 1.45) | 56, 157, 70, 16, 74, 91, 228, 163 (8 of 8) | 58, 68, 111, 5, 21, 53, 197, 38 (8 of 8) |
| Hunters three-quarters as strong | 56, 108, 70, 16, 74, 205, 102, survived (7 of 8) | 140, 62, 62, 5, 21, 51, 50, 38 (8 of 8) |
| One hunter group at a time | 56, survived, 70, 16, 74, 91, 156, 176 (7 of 8) | 58, 68, 185, 5, 21, 53, 166, 38 (8 of 8) |
| Both | 56, 173, 70, 16, 74, 88, 102, 133 (8 of 8) | survived, 62, survived, 5, 21, 51, 140, 38 (6 of 8) |

**What sank them, as the game is:** the Defector, patrols 4, hunters 3, raiders 1; the Hijacker, hunters 4, patrols 4.
Half the losses come before the hunters may sail at all (day 45; the Defector's intelligence squadron not before day 60).

**What it shows.**
- **Weaker or fewer hunters change little.** The differences between the four rows are within chance (one or two runs in
  eight). Hunter strength is not the lever.
- **The Defector's hunters are already smaller than he is.** They are capped by his origin's budget, and come at 0.3 to 0.7
  of his squadron's reckoned strength. He loses to them, and to the Concord's patrols at 0.6 to 0.9, because his squadron
  is **short of crew**: he takes prizes, each takes a prize crew, and he cannot hire or pay enough men to fill them. At the
  loss his crew was 146 of 2,110 needed (seed 37), 186 of 2,324 (seed 73), 1,206 of 1,874 (seed 51). A ship short of crew
  steams, reloads and fights fires slowly. One run (seed 97) lost three ships to a bounty squadron of two submarines he
  could not find.
- **The Hijacker's two motor torpedo boats count double** (`PT_STRENGTH_MULT`, the owner's rule for packs of boats). So a
  hunter group of two or three corvettes (2,700 t) reads as 0.7 to 0.8 of his two 50 t boats, "the weaker side", and he
  fights. He lost every such fight but one. Against patrols the panel reads 1.5 to 2.8 and he breaks off, usually
  successfully. He loses his 7,200 t Liberty freighter in the first fortnight in five runs of eight: it is slow, and every
  navy's patrol is hostile to him.

**For the owner:**
1. The Hijacker: should torpedo boats count double only when they attack (a pack), not when they are what is being
   hunted? As it stands his contact panel calls a hunter group of corvettes an easy fight when it is not.
2. The Defector: should a prize crew be refused, or warned against, when there are not the men for it? Or should his
   patrons find him crew (a perk like the retainer)?
3. Both: patrols, not hunters, are the early danger. Nothing was changed.

### After the owner's go-ahead (13 Nov 2026)

Three changes, at his word: your own torpedo boats count at their price in your squadron's strength (`Campaign.own_strength`;
enemy boats still count double); the prize screen says how manned a prize leaves you, and the probe's captain takes a prize
or raises a wreck only if he stays four-fifths manned (`Campaign.manned_with`, the probe's `_will_crew`); the hunters are
left as they were. The same 16 runs, squadron lost on day:

| Origin | Before | After | What sank them, after |
|---|---|---|---|
| The Defector | 56, 157, 70, 16, 74, 91, 228, 163 | 58, 124, 101, 155, 74, 206, 111, 163 | hunters 4, patrols 2, raiders, a bounty squadron |
| The Hijacker | 58, 68, 111, 5, 21, 53, 197, 38 (8 lost) | 140, survived, 15, survived, 199, survived, survived, 47 (4 lost) | hunters 2, convoy escorts 2 |

The Hijacker now breaks off from most hunter groups (58 of 87 contacts), since his panel reads them at about his own strength;
half his runs survive. The Defector lives longer (by a month or more in four runs) but is still lost in all eight. He is still
short-handed at the end in three runs (309 of 1,485, none of 1,255, 532 of 1,438): crew lost in action, not to prizes.
