# Tuning sheet: the first hours of a campaign

*A report for the owner's tuning pass (11 Nov 2026). All figures are measured, untuned, and his to judge. Two changes have been made since the first sheet, at his word: a 30-day grace from bounty squadrons for a new captain, and bounty squadrons and hunters sized to the captain's own squadron (see "The first change" and "The second change"). The tables are measured with both.*

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

## What stands out

For the owner to judge. The two changes above are the only ones made.

- **Fewer lone starts are lost** (15 of 32 by day 240, from 20). What still sinks them is mostly the navy origins' poverty, then patrols and raiders. Bounty squadrons and hunters are now fights a captain can choose to take or avoid.
- **Income only beats wages for traders.** Per day afloat in the first 120 days:
  - The Merchant made about 280 from trade and 55 from contracts, against 50 in wages.
  - The Smuggler made about 230 from trade and 80 from contracts. The Privateer made about 110 from trade and 70 from contracts and commission pay. Both pay about 105 in wages.
  - The Hijacker lives on contracts (140 a day against 16 in wages).
  - The Disgraced Officer made about 150 against 160 in wages, and the Survivor about 215 against 135. Repairs, stores and losses still empty both purses.
  - The Defector made about 220, mostly from prizes, against 230 in wages for his cruiser and 50 in repairs, and his purse ran down to nothing.
- **Battles pay little early.** Prizes, bounty and salvage come to under 25 a day for every origin but the Defector (165 a day).
- **A destroyer is in reach at once for four origins.** The cheapest destroyer (17,000) is affordable on day 1 for the Merchant, the Smuggler, the Privateer and the Defector. The Hijacker reaches it between day 5 and day 124, and the Academy in three runs (days 40–195). The Disgraced Officer reaches it once (day 32) and the Survivor never. The cheapest heavy cruiser (62,000) is within reach for every Merchant (days 43–140) and one Smuggler (day 94). A battleship (105,000) is within reach for three Merchants (days 183–238). A fleet carrier never is.
- **Prices are steady, the spread between ports is wide.** Port medians hardly move over the eight months. The cheapest and dearest ports differ by four to five times for medicine, munitions and electronics, so the first ton often shows a margin over 100%. But each ton bought raises the price by 0.3% and each ton sold lowers it as much, so a full hold earns far less than that first ton suggests.
- **Two hours of play falls between day 130 and day 230.** By the model under "How it was measured", the Hijacker (15 battles) reaches two hours about day 130 and the Survivor about day 140; a quiet trader is past day 240.

## At a glance

| Origin | Starts with | Credits at start | Purse day 30 | Day 60 | Day 120 | Day 240 | Battles (won) in 240 days | 1 h / 2 h of play at 2× (day) | at 4× (day) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| The Merchant Captain | fr_victory | 45,000 | 45,768 | 51,953 | 70,586 | 100,376 | 2.0 (0.5) | 166 / – | 120 / – |
| The Hijacker | fr_liberty, pt_elco | 9,000 | 12,036 | 14,774 | 25,539 | 36,283 | 15.0 (0.2) · squadron lost on day 231, 191 | 95 / 130 | 96 / 138 |
| The Smuggler | dd_soldati | 28,000 | 31,290 | 39,297 | 48,118 | 52,817 | 2.5 (0.2) · squadron lost on day 214 | 98 / 224 | 106 / – |
| The Privateer | dd_soldati | 20,000 | 18,800 | 22,891 | 27,516 | 42,502 | 5.0 (1.0) · squadron lost on day 162 | 115 / 200 | 121 / 196 |
| The Disgraced Officer | dd_fletcher | 14,000 | 8,194 | 7,949 | 6,476 | 298 | 3.5 (0.2) · squadron lost on day 93, 194 | 72 / 208 | 77 / 230 |
| The Survivor of the Lost Fleet | dd_fletcher | 6,000 | 0 | 3,913 | 0 | 0 | 8.8 (0.5) · squadron lost on day 137, 104, 98 | 101 / 140 | 102 / 141 |
| The Defector | cl_cleveland | 20,000 | 6,459 | 5,118 | 0 | – | 4.8 (1.8) · squadron lost on day 100, 63, 118, 74 | 105 / – | 105 / – |
| The Academy Cast-Off | co_flower | 15,000 | 13,430 | 16,340 | 20,843 | 28,240 | 6.8 (0.2) · squadron lost on day 47, 129 | 121 / 199 | 130 / 218 |

## The Merchant Captain

Starts at Cape Ombra with fr_victory and 45,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 43,289 | -114 | -495 | 0 | 0 | 0 | 0 | −740 | −0 | −476 |
| 16–30 | 45,768 | 165 | 3,886 | 0 | 0 | 0 | -0 | −740 | −0 | −668 |
| 31–60 | 51,953 | 206 | 7,514 | 2,325 | 0 | 0 | -1,172 | −1,479 | −0 | −1,003 |
| 61–90 | 55,293 | 130 | 9,984 | 0 | 0 | 375 | -3,963 | −1,318 | −561 | −1,178 |
| 91–120 | 70,586 | 510 | 13,081 | 4,275 | 0 | 288 | -0 | −1,479 | −0 | −871 |
| 121–180 | 88,667 | 316 | 23,012 | 0 | 0 | 1,525 | -1,659 | −2,810 | −21 | −1,966 |
| 181–240 | 100,376 | 180 | 8,478 | 4,375 | 0 | 5,938 | -3,875 | −2,976 | −8 | −1,922 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (7,600) | 1.2 | 0.0 | 1.2 (0.0) | 1.2 | 1,549 (1,646) | 0.2 | 0.0 |
| 91–120 | 4 | 1.0 (7,600) | 0.5 | 0.2 | 0.2 (0.0) | 4.5 | 2,972 (3,239) | 0.2 | 0.0 |
| 121–180 | 4 | 1.0 (7,600) | 0.5 | 0.2 | 0.2 (0.2) | 5.0 | 125 (125) | 1.0 | 0.0 |
| 181–240 | 4 | 1.0 (7,600) | 0.2 | 0.0 | 0.2 (0.2) | 1.0 | 25 (25) | 0.2 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 16, submarine 6, corvette 3, destroyer 1.

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
| Escort carrier | cve_casa | 58,000 | 107, 43, 120, 117 |
| Heavy cruiser | ca_zara | 62,000 | 111, 43, 140, 117 |
| Battleship | bb_scharnhorst | 105,000 | 196, 183, 238, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Hijacker

Starts at Kesselport with fr_liberty, pt_elco and 9,000 credits. Two hours of play fall about day 130 with the chart at 2×, day 138 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 12,534 | 236 | -271 | 2,675 | 0 | 2,638 | 32 | −920 | −329 | −290 |
| 16–30 | 12,036 | -35 | 38 | 0 | 0 | 0 | 25 | −487 | −46 | −29 |
| 31–60 | 14,774 | 102 | 502 | 2,900 | 0 | 0 | 212 | −337 | −202 | −337 |
| 61–90 | 17,606 | 101 | 20 | 3,075 | 0 | 0 | -9 | −107 | −65 | −82 |
| 91–120 | 25,539 | 292 | 335 | 8,025 | 0 | 0 | -9 | −107 | −190 | −121 |
| 121–180 | 34,318 | 161 | 478 | 8,500 | 375 | 0 | -14 | −215 | −148 | −197 |
| 181–240 | 36,283 | 40 | 582 | 1,875 | 0 | 0 | -10 | −150 | −158 | −132 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.5 (3,650) | 2.8 | 1.2 | 1.5 (0.2) | 3.1 | 6,300 (22,184) | 1.8 | 0.5 |
| 16–30 | 4 | 1.2 (1,850) | 1.0 | 0.5 | 0.5 (0.0) | 2.5 | 9,000 (23,365) | 0.0 | 0.2 |
| 31–60 | 4 | 1.0 (50) | 7.2 | 4.8 | 2.5 (0.0) | 2.4 | 7,869 (24,616) | 0.0 | 0.2 |
| 61–90 | 4 | 1.0 (50) | 4.2 | 3.2 | 1.0 (0.0) | 2.5 | 8,629 (24,740) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (50) | 8.5 | 6.2 | 2.2 (0.0) | 2.6 | 5,012 (22,184) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (50) | 13.0 | 9.8 | 3.2 (0.0) | 2.9 | 6,207 (25,200) | 0.0 | 0.0 |
| 181–240 | 4 | 1.0 (50) | 9.5 | 5.5 | 4.0 (0.0) | 2.7 | 5,334 (25,092) | 0.0 | 0.5 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 196, corvette 115, freighter 94, destroyer 58, light cruiser 15, submarine 14, heavy cruiser 4.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 5, 70, 124, 42 |
| Submarine | ss_vii | 26,000 | 115, 145, 125, 111 |
| Freighter | fr_liberty | 22,000 | 115, 145, 124, 42 |
| Fleet oiler | ao_t2 | 24,000 | 115, 145, 125, 42 |
| Ammunition ship | ae_hood | 38,000 | never, 169, never, 111 |
| Repair ship | ar_diver | 26,000 | 115, 145, 125, 111 |
| Light cruiser | cl_agano | 36,000 | never, 169, never, 111 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Smuggler

Starts at Port Saffron with dd_soldati and 28,000 credits. Two hours of play fall about day 224 with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 30,013 | 134 | 4,071 | 0 | 0 | 0 | 0 | −1,664 | −130 | −265 |
| 16–30 | 31,290 | 85 | 2,332 | 1,125 | 0 | 0 | 0 | −1,664 | −43 | −473 |
| 31–60 | 39,297 | 285 | 10,359 | 2,050 | 750 | 0 | -1,230 | −3,161 | −63 | −700 |
| 61–90 | 43,549 | 136 | 5,700 | 3,025 | 750 | 0 | -1,148 | −3,216 | −100 | −759 |
| 91–120 | 48,118 | 162 | 4,894 | 3,750 | 750 | 462 | -1,282 | −3,161 | −59 | −786 |
| 121–180 | 52,497 | 75 | 7,494 | 5,550 | 1,205 | 0 | -1,948 | −6,432 | −18 | −1,471 |
| 181–240 | 52,817 | -13 | 3,880 | 3,000 | 1,875 | 0 | -1,581 | −5,517 | −36 | −1,300 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.2 | 0.2 | 0.0 (0.0) | 1.0 | 1,830 (1,830) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 0.5 | 0.5 | 0.0 (0.0) | 3.5 | 1,850 (1,875) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 1.2 | 0.8 | 0.5 (0.0) | 2.4 | 1,461 (1,825) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 1.2 | 0.8 | 0.5 (0.0) | 3.4 | 7,308 (24,800) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 1.0 | 0.5 | 0.5 (0.2) | 2.0 | 1,710 (3,009) | 0.2 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 4.2 | 3.8 | 0.5 (0.0) | 3.3 | 6,573 (16,490) | 0.0 | 0.0 |
| 181–240 | 4 | 1.0 (1,830) | 1.5 | 1.0 | 0.5 (0.0) | 3.0 | 5,729 (20,696) | 0.0 | 0.2 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 49, destroyer 28, corvette 24, freighter 8, light cruiser 5, submarine 5.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 1, 1, 1, 1 |
| Freighter | fr_liberty | 22,000 | 1, 1, 1, 1 |
| Fleet oiler | ao_t2 | 24,000 | 1, 1, 1, 1 |
| Ammunition ship | ae_hood | 38,000 | 55, 75, 37, 42 |
| Repair ship | ar_diver | 26,000 | 1, 1, 1, 1 |
| Light cruiser | cl_agano | 36,000 | 51, 57, 18, 42 |
| Escort carrier | cve_casa | 58,000 | never, 94, never, 166 |
| Heavy cruiser | ca_zara | 62,000 | never, 94, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Privateer

Starts at Puerto Corvo with dd_soldati and 20,000 credits. Two hours of play fall about day 200 with the chart at 2×, day 196 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 18,148 | -123 | 30 | 0 | 0 | 0 | 0 | −1,664 | −0 | −218 |
| 16–30 | 18,800 | 43 | 618 | 0 | 0 | 0 | 2,000 | −1,664 | −0 | −304 |
| 31–60 | 22,891 | 145 | 6,071 | 0 | 2,000 | 0 | -111 | −3,216 | −24 | −628 |
| 61–90 | 24,868 | 68 | 4,010 | 0 | 2,000 | 0 | -111 | −3,216 | −0 | −706 |
| 91–120 | 27,516 | 104 | 2,127 | 2,400 | 2,000 | 512 | -360 | −2,967 | −265 | −798 |
| 121–180 | 31,982 | 70 | 9,931 | 925 | 4,000 | 400 | -1,396 | −6,094 | −904 | −2,396 |
| 181–240 | 42,502 | 114 | 9,895 | 4,700 | 3,333 | 900 | -4,252 | −6,156 | −469 | −1,835 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.2 | 0.0 | 0.2 (0.0) | 5.0 | 175 (175) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 0.2 | 0.2 | 0.0 (0.0) | 4.0 | 1,174 (1,174) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 0.5 | 0.2 | 0.2 (0.0) | 3.0 | 3,830 (7,384) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 0.8 | 0.5 | 0.2 (0.0) | 3.3 | 6,715 (14,584) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 2.5 | 0.8 | 1.8 (0.5) | 2.6 | 4,921 (14,050) | 0.2 | 0.0 |
| 121–180 | 4 | 1.2 (2,065) | 2.2 | 1.0 | 1.2 (0.2) | 3.3 | 8,394 (22,984) | 0.2 | 0.2 |
| 181–240 | 3 | 1.0 (1,830) | 4.0 | 2.3 | 1.7 (0.3) | 4.8 | 6,548 (23,534) | 0.3 | 0.3 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 78, corvette 20, destroyer 17, freighter 10, submarine 5, heavy cruiser 4, light cruiser 4.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 121, 161, 50, never |
| Freighter | fr_liberty | 22,000 | 61, 138, 36, 131 |
| Fleet oiler | ao_t2 | 24,000 | 91, 153, 46, never |
| Ammunition ship | ae_hood | 38,000 | never, 227, 102, never |
| Repair ship | ar_diver | 26,000 | 121, 161, 50, never |
| Light cruiser | cl_agano | 36,000 | never, 227, 102, never |
| Escort carrier | cve_casa | 58,000 | never, never, 211, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Disgraced Officer

Starts at Halbrook with dd_fletcher and 14,000 credits. Two hours of play fall about day 208 with the chart at 2×, day 230 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 9,859 | -276 | 190 | 0 | 0 | 0 | -0 | −2,540 | −1,340 | −450 |
| 16–30 | 8,194 | -112 | 1,361 | 0 | 0 | 0 | -0 | −2,456 | −28 | −542 |
| 31–60 | 7,949 | -77 | 1,082 | 2,800 | 1,615 | 0 | -1,827 | −4,826 | −0 | −952 |
| 61–90 | 8,801 | 32 | 1,061 | 3,200 | 1,842 | 0 | -97 | −4,597 | −0 | −558 |
| 91–120 | 6,476 | -79 | 661 | 1,700 | 994 | 0 | -100 | −3,416 | −0 | −2,164 |
| 121–180 | 3,589 | -87 | 1,383 | 0 | 3,690 | 0 | -24 | −8,764 | −36 | −1,294 |
| 181–240 | 298 | -58 | 3,112 | 0 | 2,831 | 567 | -400 | −6,115 | −0 | −3,286 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.2 | 0.2 | 0.0 (0.0) | 1.0 | 1,525 (1,525) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 1.2 | 0.8 | 0.5 (0.0) | 5.0 | 1,619 (1,967) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (2,050) | 1.8 | 0.8 | 1.0 (0.0) | 3.9 | 2,803 (5,155) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (2,050) | 1.2 | 0.5 | 0.8 (0.0) | 4.0 | 2,301 (5,155) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (2,050) | 1.0 | 0.2 | 0.8 (0.0) | 2.5 | 1,878 (1,966) | 0.0 | 0.2 |
| 121–180 | 3 | 1.0 (2,050) | 0.3 | 0.3 | 0.0 (0.0) | 5.0 | 4,241 (4,241) | 0.0 | 0.0 |
| 181–240 | 3 | 1.0 (2,050) | 2.0 | 1.3 | 0.7 (0.3) | 3.8 | 2,253 (5,560) | 0.7 | 0.3 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 74, destroyer 27, corvette 7, submarine 3.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | never, 32, never, never |
| Submarine | ss_vii | 26,000 | never, 45, never, never |
| Freighter | fr_liberty | 22,000 | never, 45, never, never |
| Fleet oiler | ao_t2 | 24,000 | never, 45, never, never |
| Ammunition ship | ae_hood | 38,000 | never, never, never, never |
| Repair ship | ar_diver | 26,000 | never, 45, never, never |
| Light cruiser | cl_agano | 36,000 | never, never, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Survivor of the Lost Fleet

Starts at Halvardsby with dd_fletcher and 6,000 credits. Two hours of play fall about day 140 with the chart at 2×, day 141 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 93 | -394 | 1,392 | 0 | 1,276 | 0 | 95 | −2,357 | −2,344 | −3,970 |
| 16–30 | 0 | -6 | 402 | 0 | 2,095 | 0 | 22 | −2,188 | −163 | −261 |
| 31–60 | 3,913 | 130 | 548 | 6,775 | 3,424 | 0 | -49 | −3,870 | −0 | −2,914 |
| 61–90 | 0 | -140 | 0 | 0 | 2,923 | 0 | -333 | −3,812 | −0 | −2,691 |
| 91–120 | 0 | 0 | 1,944 | 0 | 2,334 | 0 | -12 | −2,323 | −62 | −1,881 |
| 121–180 | 0 | 0 | 0 | 0 | 3,796 | 1,850 | -967 | −4,035 | −0 | −644 |
| 181–240 | 0 | 0 | 1,482 | 15,600 | 4,947 | 9,300 | -5,367 | −8,688 | −9,557 | −7,717 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (2,050) | 0.2 | 0.2 | 0.0 (0.0) | 4.0 | 2,385 (2,385) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (2,050) | 3.5 | 2.2 | 1.2 (0.0) | 2.5 | 1,968 (3,040) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (2,050) | 6.2 | 3.2 | 3.0 (0.0) | 2.2 | 2,243 (2,692) | 0.2 | 0.5 |
| 121–180 | 2 | 1.0 (2,050) | 13.5 | 5.5 | 8.0 (0.0) | 1.4 | 1,348 (8,165) | 1.0 | 0.5 |
| 181–240 | 1 | 1.0 (2,050) | 3.0 | 1.0 | 2.0 (2.0) | 2.0 | 627 (1,782) | 3.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 68, destroyer 34, submarine 31, corvette 5, freighter 1.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | never, never, 60, 44 |
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

Starts at Strelsk with cl_cleveland and 20,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 14,639 | -357 | 122 | 0 | 0 | 3,500 | 6 | −3,951 | −1,440 | −3,598 |
| 16–30 | 6,459 | -356 | 0 | 0 | 52 | 0 | 65 | −3,887 | −79 | −1,338 |
| 31–60 | 5,118 | -48 | 0 | 0 | 1,902 | 6,788 | -269 | −6,838 | −778 | −2,146 |
| 61–90 | 4,619 | -89 | 0 | 0 | 1,265 | 3,038 | -193 | −3,435 | −491 | −682 |
| 91–120 | 0 | -158 | 420 | 0 | 1,830 | 0 | 144 | −3,002 | −0 | −971 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (11,800) | 0.8 | 0.2 | 0.5 (0.5) | 2.7 | 8,949 (22,800) | 1.2 | 0.0 |
| 16–30 | 4 | 1.0 (11,800) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.2 (12,308) | 0.8 | 0.0 | 0.8 (0.8) | 2.3 | 3,574 (4,550) | 1.5 | 0.0 |
| 61–90 | 4 | 1.8 (12,998) | 1.2 | 0.0 | 1.2 (0.5) | 2.8 | 6,108 (8,225) | 0.8 | 0.8 |
| 91–120 | 2 | 1.0 (11,800) | 6.5 | 2.0 | 4.5 (0.0) | 2.1 | 8,892 (13,190) | 1.0 | 2.5 |
| 121–180 | 0 | | | | | | | | |
| 181–240 | 0 | | | | | | | | |

Enemy ships met in 240 days, by class (all seeds): corvette 27, destroyer 7, motor torpedo boat 7, escort carrier 7, submarine 3, freighter 3, light cruiser 2.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 8, never, never, never |
| Freighter | fr_liberty | 22,000 | 8, never, never, never |
| Fleet oiler | ao_t2 | 24,000 | 8, never, never, never |
| Ammunition ship | ae_hood | 38,000 | never, never, never, never |
| Repair ship | ar_diver | 26,000 | 8, never, never, never |
| Light cruiser | cl_agano | 36,000 | never, never, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Academy Cast-Off

Starts at Calder Roads with co_flower and 15,000 credits. Two hours of play fall about day 199 with the chart at 2×, day 218 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 14,087 | -61 | 0 | 0 | 0 | 0 | 0 | −791 | −66 | −55 |
| 16–30 | 13,430 | -46 | -34 | 0 | 0 | 325 | -26 | −765 | −20 | −136 |
| 31–60 | 16,340 | 99 | 357 | 2,400 | 1,799 | 0 | -66 | −1,306 | −0 | −274 |
| 61–90 | 22,518 | 167 | 1,648 | 5,133 | 0 | 0 | -35 | −1,547 | −51 | −448 |
| 91–120 | 20,843 | -61 | 466 | 0 | 0 | 0 | -106 | −1,477 | −0 | −558 |
| 121–180 | 20,566 | -37 | 3,022 | 0 | 0 | 0 | -601 | −2,057 | −19 | −623 |
| 181–240 | 28,240 | 126 | 1,108 | 6,450 | 3,521 | 0 | -53 | −2,875 | −30 | −1,026 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (940) | 0.8 | 0.2 | 0.5 (0.0) | 3.0 | 1,501 (2,800) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (940) | 0.5 | 0.0 | 0.5 (0.2) | 1.0 | 698 (1,370) | 0.2 | 0.0 |
| 31–60 | 4 | 1.0 (940) | 1.8 | 0.5 | 1.2 (0.0) | 1.6 | 899 (1,525) | 0.2 | 0.2 |
| 61–90 | 3 | 1.0 (940) | 0.3 | 0.0 | 0.3 (0.0) | 1.0 | 25 (25) | 0.0 | 0.0 |
| 91–120 | 3 | 1.0 (940) | 2.7 | 1.3 | 1.3 (0.0) | 2.8 | 1,569 (3,132) | 0.0 | 0.0 |
| 121–180 | 3 | 1.0 (940) | 4.0 | 0.3 | 3.7 (0.0) | 3.8 | 930 (2,242) | 0.0 | 0.3 |
| 181–240 | 2 | 1.0 (940) | 2.0 | 1.0 | 1.0 (0.0) | 3.8 | 2,087 (5,280) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 75, corvette 18, submarine 8, destroyer 4.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | never, 41, 40, 195 |
| Submarine | ss_vii | 26,000 | never, 90, never, never |
| Freighter | fr_liberty | 22,000 | never, 90, 40, never |
| Fleet oiler | ao_t2 | 24,000 | never, 90, never, never |
| Ammunition ship | ae_hood | 38,000 | never, 225, never, never |
| Repair ship | ar_diver | 26,000 | never, 90, never, never |
| Light cruiser | cl_agano | 36,000 | never, 225, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## Prices in port

Port prices (before the 6% buying and 7% selling spread) seen by all captains when they made harbour, as median (lowest–highest).

| Days | Fuel | Food | Steel | Medicine | Munitions | Electronics |
|---|---:|---:|---:|---:|---:|---:|
| 1–15 | 8 (6–14) | 15 (6–38) | 32 (14–59) | 83 (44–150) | 68 (36–119) | 90 (46–227) |
| 16–30 | 8 (6–15) | 14 (6–38) | 30 (12–58) | 87 (39–166) | 71 (26–124) | 92 (46–230) |
| 31–60 | 7 (6–14) | 15 (6–33) | 30 (14–60) | 85 (40–161) | 63 (26–116) | 96 (43–241) |
| 61–90 | 7 (5–14) | 15 (6–34) | 32 (13–62) | 84 (44–159) | 48 (27–117) | 118 (48–238) |
| 91–120 | 7 (5–14) | 15 (6–37) | 30 (13–57) | 86 (47–163) | 74 (26–117) | 88 (43–234) |
| 121–180 | 7 (5–14) | 15 (6–32) | 33 (13–65) | 80 (37–162) | 73 (27–131) | 91 (44–237) |
| 181–240 | 8 (5–14) | 16 (6–35) | 32 (11–59) | 87 (42–160) | 67 (26–113) | 88 (45–227) |

