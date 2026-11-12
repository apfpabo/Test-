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
| The Merchant Captain | fr_victory | 45,000 | 46,924 | 61,821 | 44,968 | 60,246 | 1.8 (0.8) · squadron lost on day 133, 66, 31 | 205 / – | – / – |
| The Hijacker | fr_liberty, pt_elco | 9,000 | 21,796 | 20,305 | 28,693 | 48,444 | 13.0 (1.2) · squadron lost on day 101, 58 | 77 / 131 | 77 / 137 |
| The Smuggler | dd_soldati | 28,000 | 29,869 | 28,143 | 29,636 | 29,484 | 2.5 (0.2) | 160 / – | 154 / – |
| The Privateer | dd_soldati | 20,000 | 20,045 | 31,917 | 33,226 | 52,740 | 6.8 (0.8) | 89 / 209 | 101 / 212 |
| The Disgraced Officer | dd_fletcher | 14,000 | 11,972 | 15,012 | 24,868 | 27,540 | 4.0 (0.5) · squadron lost on day 161 | 122 / 187 | 134 / 222 |
| The Survivor of the Lost Fleet | dd_fletcher | 14,000 | 6,969 | 5,261 | 3,300 | 6,606 | 4.0 (0.5) · squadron lost on day 53 | 145 / – | 131 / – |
| The Defector | cl_cleveland | 30,000 | 25,886 | 28,624 | 2,079 | 0 | 6.8 (3.0) · squadron lost on day 116, 54, 71 | 97 / 166 | 97 / 168 |
| The Academy Cast-Off | co_flower | 15,000 | 13,492 | 15,593 | 23,391 | 33,842 | 2.0 (0.2) · squadron lost on day 44 | 152 / – | 156 / – |

## The Merchant Captain

Starts at Cape Ombra with fr_victory and 45,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 43,607 | -93 | -675 | 0 | 0 | 0 | -5 | −470 | −0 | −243 |
| 16–30 | 46,924 | 221 | 4,168 | 0 | 0 | 788 | -15 | −624 | −0 | −1,000 |
| 31–60 | 61,821 | 511 | 13,907 | 1,825 | 0 | 2,750 | -1,680 | −1,048 | −346 | −511 |
| 61–90 | 60,415 | -112 | -3,519 | 0 | 0 | 0 | -840 | −1,203 | −0 | −610 |
| 91–120 | 44,968 | -431 | 0 | 0 | 0 | 0 | -2,166 | −1,646 | −5,368 | −1,726 |
| 121–180 | 42,280 | -192 | 8,381 | 0 | 0 | 0 | -6,380 | −3,186 | −0 | −1,502 |
| 181–240 | 60,246 | 43 | 9,516 | 0 | 0 | 0 | -2,447 | −2,567 | −0 | −2,113 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (7,600) | 0.2 | 0.0 | 0.2 (0.2) | 3.0 | 234 (234) | 0.2 | 0.0 |
| 31–60 | 4 | 1.8 (7,642) | 1.2 | 0.5 | 0.8 (0.5) | 2.6 | 431 (844) | 1.0 | 0.5 |
| 61–90 | 3 | 2.0 (7,656) | 0.7 | 0.3 | 0.3 (0.0) | 4.0 | 3,520 (3,520) | 0.7 | 0.3 |
| 91–120 | 2 | 2.5 (7,684) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 121–180 | 2 | 2.5 (7,684) | 0.5 | 0.0 | 0.5 (0.0) | 4.0 | 1,185 (1,185) | 0.0 | 0.5 |
| 181–240 | 1 | 3.0 (167) | 2.0 | 1.0 | 1.0 (0.0) | 4.5 | 4,761 (6,320) | 0.0 | 1.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 25, destroyer 6, corvette 4, submarine 2.

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
| Escort carrier | cve_casa | 58,000 | 32, 54, 37, never |
| Heavy cruiser | ca_zara | 62,000 | never, 54, 37, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Hijacker

Starts at Kesselport with fr_liberty, pt_elco and 9,000 credits. Two hours of play fall about day 131 with the chart at 2×, day 137 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 11,358 | 157 | 551 | 0 | 1,725 | 1,362 | 1 | −606 | −315 | −361 |
| 16–30 | 21,796 | 851 | 0 | 11,700 | 0 | 0 | -1,078 | −376 | −10 | −14 |
| 31–60 | 20,305 | -58 | 441 | 0 | 237 | 1,412 | 254 | −939 | −1,714 | −1,183 |
| 61–90 | 29,745 | 87 | 242 | 3,533 | 0 | 783 | -1,447 | −202 | −164 | −73 |
| 91–120 | 28,693 | -147 | -261 | 0 | 0 | 900 | -21 | −79 | −1,426 | −163 |
| 121–180 | 38,555 | -10 | 34 | 0 | 0 | 0 | -9 | −259 | −150 | −204 |
| 181–240 | 48,444 | 203 | 224 | 10,500 | 0 | 0 | -19 | −234 | −345 | −206 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 2.0 (5,685) | 2.8 | 1.2 | 1.5 (0.2) | 2.9 | 4,169 (14,584) | 0.5 | 0.5 |
| 16–30 | 4 | 1.8 (3,885) | 1.5 | 1.0 | 0.5 (0.0) | 2.8 | 7,016 (22,400) | 0.0 | 0.2 |
| 31–60 | 4 | 2.0 (3,898) | 6.2 | 4.8 | 1.5 (0.2) | 2.2 | 3,044 (23,600) | 0.5 | 0.8 |
| 61–90 | 3 | 1.3 (67) | 11.0 | 6.7 | 4.3 (0.3) | 2.5 | 4,988 (25,092) | 0.3 | 0.7 |
| 91–120 | 3 | 1.7 (420) | 7.0 | 2.7 | 4.3 (0.7) | 2.0 | 2,120 (15,740) | 0.3 | 1.0 |
| 121–180 | 2 | 1.0 (50) | 7.5 | 4.5 | 3.0 (0.0) | 2.5 | 2,875 (14,984) | 0.0 | 0.0 |
| 181–240 | 2 | 1.0 (50) | 8.0 | 5.0 | 3.0 (0.0) | 3.0 | 9,079 (22,184) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 139, corvette 71, freighter 49, destroyer 38, submarine 15, light cruiser 2.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 18, never, never, 14 |
| Submarine | ss_vii | 26,000 | 23, never, never, 30 |
| Freighter | fr_liberty | 22,000 | 23, never, never, 30 |
| Fleet oiler | ao_t2 | 24,000 | 23, never, never, 30 |
| Ammunition ship | ae_hood | 38,000 | 23, never, never, never |
| Repair ship | ar_diver | 26,000 | 23, never, never, 30 |
| Light cruiser | cl_agano | 36,000 | 23, never, never, never |
| Escort carrier | cve_casa | 58,000 | 226, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | 226, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Smuggler

Starts at Port Saffron with dd_soldati and 28,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 30,442 | 163 | 3,978 | 0 | 0 | 0 | -30 | −1,394 | −0 | −112 |
| 16–30 | 29,869 | -38 | 900 | 0 | 0 | 0 | 0 | −1,434 | −0 | −39 |
| 31–60 | 28,143 | -57 | 1,122 | 2,050 | 0 | 0 | -600 | −3,056 | −86 | −1,158 |
| 61–90 | 27,945 | -5 | 1,495 | 1,875 | 375 | 0 | -111 | −3,216 | −33 | −584 |
| 91–120 | 29,636 | 50 | 1,788 | 4,600 | 375 | 0 | -831 | −3,161 | −14 | −1,066 |
| 121–180 | 29,495 | -9 | 4,062 | 4,750 | 754 | 0 | -651 | −6,448 | −924 | −2,021 |
| 181–240 | 29,484 | -5 | 4,610 | 3,950 | 750 | 0 | -2,045 | −5,619 | −421 | −1,425 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.2 | 0.0 | 0.2 (0.0) | 3.0 | 125 (125) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 0.8 | 0.8 | 0.0 (0.0) | 4.3 | 2,679 (3,597) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 0.8 | 0.5 | 0.2 (0.0) | 3.7 | 2,431 (3,237) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 2.0 | 1.8 | 0.2 (0.0) | 2.9 | 5,853 (24,680) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 3.0 | 1.2 | 1.8 (0.2) | 2.2 | 3,354 (6,641) | 0.0 | 0.2 |
| 181–240 | 4 | 1.0 (1,830) | 0.8 | 0.8 | 0.0 (0.0) | 6.0 | 1,063 (2,587) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 40, corvette 28, destroyer 21, freighter 4, submarine 2.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 1, 1, 1, 1 |
| Freighter | fr_liberty | 22,000 | 1, 1, 1, 1 |
| Fleet oiler | ao_t2 | 24,000 | 1, 1, 1, 1 |
| Ammunition ship | ae_hood | 38,000 | never, never, 102, 41 |
| Repair ship | ar_diver | 26,000 | 1, 1, 1, 1 |
| Light cruiser | cl_agano | 36,000 | never, never, 102, 38 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Privateer

Starts at Puerto Corvo with dd_soldati and 20,000 credits. Two hours of play fall about day 209 with the chart at 2×, day 212 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 17,962 | -136 | -76 | 0 | 0 | 0 | 0 | −1,664 | −0 | −298 |
| 16–30 | 20,045 | 144 | 1,959 | 0 | 0 | 0 | 1,945 | −1,608 | −0 | −212 |
| 31–60 | 31,917 | 410 | 3,166 | 8,150 | 4,495 | 0 | -55 | −3,216 | −0 | −666 |
| 61–90 | 34,321 | 88 | -289 | 5,775 | 2,000 | 0 | -1,215 | −3,050 | −36 | −781 |
| 91–120 | 33,226 | -34 | 562 | 1,900 | 2,000 | 0 | -1,550 | −3,133 | −0 | −874 |
| 121–180 | 47,325 | 245 | 5,582 | 10,600 | 4,000 | 3,150 | -490 | −6,404 | −613 | −1,727 |
| 181–240 | 52,740 | 99 | 5,966 | 2,900 | 4,000 | 4,188 | -3,508 | −6,189 | −492 | −1,450 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.5 | 0.2 | 0.2 (0.0) | 6.0 | 1,232 (1,232) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 0.8 | 0.2 | 0.5 (0.0) | 3.3 | 2,205 (2,692) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 2.2 | 1.5 | 0.8 (0.0) | 3.4 | 6,929 (22,584) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 2.5 | 0.8 | 1.8 (0.0) | 3.2 | 5,836 (15,292) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 1.5 | 0.8 | 0.8 (0.0) | 2.5 | 4,005 (15,384) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 2.5 | 1.0 | 1.5 (0.5) | 3.3 | 4,897 (24,200) | 1.0 | 0.0 |
| 181–240 | 4 | 1.2 (1,842) | 2.5 | 1.2 | 1.2 (0.2) | 3.1 | 8,217 (22,184) | 0.5 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 98, destroyer 22, freighter 19, corvette 9, submarine 8, light cruiser 7, heavy cruiser 1.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 43, 59, 53, 181 |
| Freighter | fr_liberty | 22,000 | 43, 55, 53, 149 |
| Fleet oiler | ao_t2 | 24,000 | 43, 59, 53, 151 |
| Ammunition ship | ae_hood | 38,000 | 48, 154, 67, never |
| Repair ship | ar_diver | 26,000 | 43, 59, 53, 181 |
| Light cruiser | cl_agano | 36,000 | 48, 136, 67, never |
| Escort carrier | cve_casa | 58,000 | 176, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | 177, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Disgraced Officer

Starts at Halbrook with dd_fletcher and 14,000 credits. Two hours of play fall about day 187 with the chart at 2×, day 222 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 10,056 | -263 | -109 | 0 | 0 | 0 | -60 | −2,105 | −1,262 | −407 |
| 16–30 | 11,972 | 127 | 594 | 0 | 2,500 | 1,712 | -124 | −2,394 | −46 | −326 |
| 31–60 | 15,012 | 130 | 869 | 7,275 | 1,748 | 1,562 | 199 | −4,524 | −2,086 | −2,003 |
| 61–90 | 19,800 | 164 | 320 | 6,075 | 2,995 | 1,950 | -580 | −4,996 | −0 | −976 |
| 91–120 | 24,868 | 182 | 1,412 | 7,425 | 2,500 | 0 | -254 | −4,826 | −0 | −1,188 |
| 121–180 | 22,725 | -47 | 1,441 | 3,000 | 4,611 | 0 | -396 | −8,801 | −82 | −1,916 |
| 181–240 | 27,540 | 75 | 1,007 | 17,133 | 3,671 | 0 | -5,841 | −8,302 | −482 | −2,691 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.5 | 0.0 | 0.5 (0.0) | 5.0 | 309 (309) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 1.0 | 0.2 | 0.8 (0.2) | 3.8 | 954 (3,015) | 0.5 | 0.0 |
| 31–60 | 4 | 1.0 (2,050) | 1.2 | 0.2 | 1.0 (0.0) | 4.0 | 2,326 (3,455) | 0.5 | 0.0 |
| 61–90 | 4 | 1.0 (2,050) | 1.0 | 0.5 | 0.5 (0.2) | 3.5 | 2,206 (3,799) | 0.2 | 0.0 |
| 91–120 | 4 | 1.0 (2,050) | 0.8 | 0.5 | 0.2 (0.0) | 3.3 | 3,016 (3,799) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (2,050) | 1.8 | 0.8 | 1.0 (0.0) | 1.9 | 1,798 (3,215) | 0.0 | 0.2 |
| 181–240 | 3 | 1.0 (2,050) | 0.7 | 0.7 | 0.0 (0.0) | 4.5 | 2,612 (3,804) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 61, destroyer 18, corvette 7, submarine 5.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 78, 68, 33, 30 |
| Submarine | ss_vii | 26,000 | 100, 186, 54, never |
| Freighter | fr_liberty | 22,000 | 90, 186, 54, never |
| Fleet oiler | ao_t2 | 24,000 | 100, 186, 54, never |
| Ammunition ship | ae_hood | 38,000 | never, 202, 112, never |
| Repair ship | ar_diver | 26,000 | 100, 186, 54, never |
| Light cruiser | cl_agano | 36,000 | never, 202, 112, never |
| Escort carrier | cve_casa | 58,000 | never, never, 150, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Survivor of the Lost Fleet

Starts at Halvardsby with dd_fletcher and 14,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 9,207 | -320 | 56 | 0 | 0 | 0 | -36 | −1,758 | −1,731 | −1,324 |
| 16–30 | 6,969 | -149 | 98 | 0 | 0 | 0 | -0 | −2,063 | −22 | −252 |
| 31–60 | 5,261 | 11 | 15 | 1,825 | 31 | 2,288 | 60 | −3,860 | −1,130 | −935 |
| 61–90 | 1,792 | -33 | 0 | 0 | 2,533 | 0 | 31 | −3,537 | −0 | −0 |
| 91–120 | 3,300 | 50 | 1,102 | 4,867 | 1,489 | 5,433 | -839 | −3,472 | −2,227 | −4,845 |
| 121–180 | 4,053 | 13 | 336 | 4,333 | 4,758 | 0 | 210 | −7,891 | −0 | −993 |
| 181–240 | 6,606 | 47 | 227 | 7,433 | 8,255 | 0 | 569 | −7,687 | −821 | −5,425 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.2 | 0.2 | 0.0 (0.0) | 4.0 | 2,487 (2,487) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.5 (2,069) | 2.2 | 0.2 | 2.0 (0.2) | 2.7 | 2,347 (2,810) | 0.8 | 0.8 |
| 61–90 | 3 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 91–120 | 3 | 1.3 (2,081) | 1.0 | 0.7 | 0.3 (0.3) | 1.3 | 1,142 (1,621) | 0.7 | 0.0 |
| 121–180 | 3 | 1.3 (2,081) | 4.3 | 2.3 | 2.0 (0.0) | 3.2 | 1,830 (5,570) | 0.0 | 0.0 |
| 181–240 | 3 | 1.3 (2,081) | 2.0 | 1.7 | 0.3 (0.0) | 3.7 | 4,724 (5,570) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 49, destroyer 19, corvette 16, submarine 11.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | never, never, never, never |
| Submarine | ss_vii | 26,000 | never, never, never, never |
| Freighter | fr_liberty | 22,000 | never, never, never, never |
| Fleet oiler | ao_t2 | 24,000 | never, never, never, never |
| Ammunition ship | ae_hood | 38,000 | never, never, never, never |
| Repair ship | ar_diver | 26,000 | never, never, never, never |
| Light cruiser | cl_agano | 36,000 | never, never, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Defector

Starts at Strelsk with cl_cleveland and 30,000 credits. Two hours of play fall about day 166 with the chart at 2×, day 168 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 30,040 | 3 | 426 | 0 | 1 | 7,312 | -24 | −3,527 | −1,111 | −3,038 |
| 16–30 | 25,886 | -339 | 167 | 0 | 3,386 | 11,312 | 536 | −3,504 | −5,724 | −10,328 |
| 31–60 | 28,624 | 73 | 0 | 2,500 | 4,984 | 8,000 | -999 | −8,090 | −408 | −3,249 |
| 61–90 | 17,862 | -281 | 0 | 2,300 | 1,503 | 1,733 | -1,983 | −5,895 | −2,358 | −4,198 |
| 91–120 | 2,079 | -433 | 794 | 0 | 5,169 | 10,400 | -3,098 | −4,551 | −12,216 | −6,467 |
| 121–180 | 4,335 | 3 | 3,198 | 0 | 19,110 | 0 | 932 | −14,406 | −0 | −8,657 |
| 181–240 | 0 | -76 | 2,076 | 0 | 6,488 | 0 | 723 | −8,293 | −198 | −5,131 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (11,800) | 1.2 | 0.5 | 0.8 (0.5) | 2.8 | 11,106 (24,280) | 1.2 | 0.2 |
| 16–30 | 4 | 1.0 (11,800) | 1.0 | 0.0 | 1.0 (0.8) | 2.0 | 2,791 (4,046) | 1.8 | 0.5 |
| 31–60 | 4 | 1.8 (13,219) | 1.0 | 0.0 | 1.0 (0.8) | 2.2 | 4,036 (4,790) | 1.0 | 0.2 |
| 61–90 | 3 | 2.0 (13,277) | 1.0 | 0.0 | 1.0 (0.0) | 1.3 | 8,787 (9,630) | 0.3 | 1.7 |
| 91–120 | 2 | 3.0 (15,135) | 9.5 | 4.0 | 5.5 (1.5) | 1.7 | 7,813 (14,860) | 2.5 | 1.5 |
| 121–180 | 1 | 5.0 (23,570) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 181–240 | 1 | 1.0 (11,800) | 4.0 | 2.0 | 2.0 (1.0) | 3.2 | 16,518 (19,180) | 0.0 | 5.0 |

Enemy ships met in 240 days, by class (all seeds): corvette 21, destroyer 20, escort carrier 15, light cruiser 7, motor torpedo boat 7, freighter 4, submarine 3, heavy cruiser 3.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 1, 1, 1, 1 |
| Freighter | fr_liberty | 22,000 | 1, 1, 1, 1 |
| Fleet oiler | ao_t2 | 24,000 | 1, 1, 1, 1 |
| Ammunition ship | ae_hood | 38,000 | 20, 57, 8, 6 |
| Repair ship | ar_diver | 26,000 | 1, 1, 1, 1 |
| Light cruiser | cl_agano | 36,000 | 20, 57, 8, 6 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Academy Cast-Off

Starts at Calder Roads with co_flower and 15,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 14,341 | -44 | 0 | 0 | 0 | 0 | -15 | −531 | −56 | −56 |
| 16–30 | 13,492 | -57 | 0 | 0 | 0 | 0 | -5 | −751 | −32 | −61 |
| 31–60 | 15,593 | 62 | -7 | 3,700 | 0 | 0 | 58 | −1,332 | −8 | −310 |
| 61–90 | 20,300 | 130 | 21 | 5,500 | 0 | 0 | 77 | −1,547 | −0 | −273 |
| 91–120 | 23,391 | 113 | -14 | 4,900 | 0 | 0 | 77 | −1,343 | −0 | −528 |
| 121–180 | 32,710 | 166 | 1,680 | 9,433 | 0 | 2,100 | 187 | −2,712 | −709 | −787 |
| 181–240 | 33,842 | 21 | 774 | 3,100 | 0 | 0 | 419 | −2,261 | −0 | −900 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (940) | 0.2 | 0.0 | 0.2 (0.0) | 4.0 | 1,174 (1,174) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (940) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (940) | 0.8 | 0.0 | 0.8 (0.0) | 2.0 | 1,630 (4,840) | 0.0 | 0.2 |
| 61–90 | 3 | 1.0 (940) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 91–120 | 3 | 1.0 (940) | 0.3 | 0.0 | 0.3 (0.0) | 2.0 | 142 (142) | 0.0 | 0.0 |
| 121–180 | 3 | 1.3 (957) | 1.3 | 0.3 | 1.0 (0.3) | 3.0 | 1,675 (2,490) | 0.7 | 0.0 |
| 181–240 | 3 | 1.3 (957) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 15, corvette 6, submarine 2, destroyer 1.

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
| 1–15 | 8 (6–13) | 15 (7–41) | 31 (13–58) | 102 (47–155) | 59 (29–122) | 108 (46–226) |
| 16–30 | 7 (5–14) | 14 (6–33) | 32 (16–59) | 86 (45–153) | 74 (28–115) | 89 (46–226) |
| 31–60 | 8 (5–14) | 18 (6–41) | 32 (13–59) | 82 (41–154) | 63 (25–121) | 89 (41–267) |
| 61–90 | 8 (6–15) | 14 (7–28) | 33 (14–61) | 82 (48–157) | 74 (28–118) | 94 (40–228) |
| 91–120 | 8 (5–14) | 12 (6–41) | 30 (17–55) | 98 (48–171) | 66 (28–113) | 112 (41–225) |
| 121–180 | 8 (5–13) | 16 (6–35) | 33 (17–56) | 76 (39–203) | 62 (27–117) | 98 (46–240) |
| 181–240 | 8 (6–14) | 16 (6–31) | 36 (17–62) | 81 (36–173) | 58 (30–135) | 89 (49–227) |

