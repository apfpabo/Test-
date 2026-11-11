# Tuning sheet: the first hours of a campaign

*A report for the owner's tuning pass (11 Nov 2026). All figures are measured, untuned, and his to judge. Three changes have been made since the first sheet, at his word: a 30-day grace from bounty squadrons, bounty squadrons and hunters sized to the captain's own squadron, and half pay with better prize money (see "The first change", "The second change" and "The third change"). The tables are measured with all three.*

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

## What stands out

For the owner to judge. The three changes above are the only ones made.

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
| The Merchant Captain | fr_victory | 45,000 | 46,028 | 52,213 | 72,898 | 96,134 | 2.0 (0.2) | 172 / – | 176 / – |
| The Hijacker | fr_liberty, pt_elco | 9,000 | 12,876 | 12,500 | 20,068 | 35,877 | 14.2 (0.8) · squadron lost on day 231, 178 | 94 / 126 | 96 / 145 |
| The Smuggler | dd_soldati | 28,000 | 31,460 | 39,467 | 48,074 | 49,386 | 2.8 (0.2) · squadron lost on day 214 | 98 / 224 | 106 / – |
| The Privateer | dd_soldati | 20,000 | 18,800 | 22,891 | 27,978 | 34,995 | 4.2 (0.8) | 115 / 205 | 120 / 212 |
| The Disgraced Officer | dd_fletcher | 14,000 | 8,539 | 8,742 | 7,031 | 418 | 3.8 (0.5) · squadron lost on day 148 | 94 / 186 | 110 / 202 |
| The Survivor of the Lost Fleet | dd_fletcher | 6,000 | 0 | 3,913 | 1,762 | 7,672 | 12.0 (0.0) · squadron lost on day 137, 154 | 104 / 131 | 108 / 131 |
| The Defector | cl_cleveland | 20,000 | 10,128 | 14,657 | 0 | 0 | 4.2 (2.5) · squadron lost on day 222, 136, 88, 66 | 106 / 208 | 120 / 222 |
| The Academy Cast-Off | co_flower | 15,000 | 14,005 | 16,915 | 21,530 | 28,560 | 6.8 (0.2) · squadron lost on day 47, 129 | 121 / 199 | 130 / 218 |

## The Merchant Captain

Starts at Cape Ombra with fr_victory and 45,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 43,519 | -99 | -495 | 0 | 0 | 0 | -10 | −500 | −0 | −476 |
| 16–30 | 46,028 | 167 | 3,886 | 0 | 0 | 0 | -10 | −700 | −0 | −668 |
| 31–60 | 52,213 | 206 | 7,514 | 2,325 | 0 | 0 | -1,172 | −1,479 | −0 | −1,003 |
| 61–90 | 50,882 | -50 | 4,940 | 0 | 0 | 825 | -3,963 | −1,318 | −561 | −1,255 |
| 91–120 | 72,898 | 734 | 21,544 | 2,150 | 0 | 588 | -0 | −1,479 | −0 | −786 |
| 121–180 | 82,274 | 166 | 15,100 | 0 | 0 | 2,762 | -3,684 | −2,760 | −21 | −2,022 |
| 181–240 | 96,134 | 216 | 15,100 | 4,375 | 0 | 1,388 | -3,387 | −2,835 | −646 | −1,834 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (7,600) | 1.2 | 0.0 | 1.2 (0.0) | 1.2 | 1,549 (1,646) | 0.2 | 0.0 |
| 91–120 | 4 | 1.0 (7,600) | 0.5 | 0.2 | 0.2 (0.0) | 4.5 | 2,972 (3,239) | 0.2 | 0.0 |
| 121–180 | 4 | 1.0 (7,600) | 0.8 | 0.5 | 0.2 (0.2) | 4.0 | 1,238 (3,463) | 1.0 | 0.0 |
| 181–240 | 4 | 1.0 (7,600) | 0.2 | 0.0 | 0.2 (0.0) | 3.0 | 953 (953) | 0.5 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 17, submarine 7, corvette 4, destroyer 2.

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
| Escort carrier | cve_casa | 58,000 | 107, 38, 120, 96 |
| Heavy cruiser | ca_zara | 62,000 | 111, 43, 120, 96 |
| Battleship | bb_scharnhorst | 105,000 | 196, 183, 205, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Hijacker

Starts at Kesselport with fr_liberty, pt_elco and 9,000 credits. Two hours of play fall about day 126 with the chart at 2×, day 145 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 13,249 | 283 | -320 | 2,675 | 0 | 2,988 | 32 | −489 | −329 | −308 |
| 16–30 | 12,876 | -27 | -56 | 0 | 0 | 0 | -8 | −216 | −45 | −48 |
| 31–60 | 12,500 | -12 | 430 | 0 | 0 | 0 | -108 | −236 | −124 | −339 |
| 61–90 | 15,397 | 103 | 100 | 3,075 | 0 | 0 | -10 | −112 | −78 | −78 |
| 91–120 | 20,068 | 175 | 260 | 4,800 | 0 | 0 | -9 | −113 | −145 | −122 |
| 121–180 | 30,885 | 197 | 454 | 10,900 | 0 | 0 | -11 | −223 | −136 | −166 |
| 181–240 | 35,877 | 49 | 709 | 2,500 | 0 | 0 | -14 | −187 | −210 | −170 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.2 (1,850) | 3.5 | 1.8 | 1.8 (0.5) | 2.6 | 5,907 (22,184) | 1.0 | 0.8 |
| 16–30 | 4 | 1.2 (1,850) | 1.2 | 0.8 | 0.5 (0.0) | 3.0 | 8,596 (23,365) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (50) | 6.5 | 4.5 | 2.0 (0.0) | 3.0 | 8,057 (23,830) | 0.0 | 0.2 |
| 61–90 | 4 | 1.0 (50) | 4.0 | 3.0 | 1.0 (0.0) | 2.1 | 6,325 (24,740) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (50) | 10.8 | 8.2 | 2.5 (0.2) | 2.5 | 7,054 (22,184) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (50) | 10.2 | 7.2 | 3.0 (0.0) | 3.0 | 6,484 (25,200) | 0.0 | 0.2 |
| 181–240 | 3 | 1.0 (50) | 11.7 | 7.0 | 4.7 (0.0) | 2.6 | 4,935 (24,200) | 0.0 | 0.3 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 199, corvette 107, freighter 99, destroyer 56, light cruiser 13, submarine 9, heavy cruiser 4.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 5, 70, 120, 150 |
| Submarine | ss_vii | 26,000 | 115, 145, 125, never |
| Freighter | fr_liberty | 22,000 | 115, 145, 124, 150 |
| Fleet oiler | ao_t2 | 24,000 | 115, 145, 124, never |
| Ammunition ship | ae_hood | 38,000 | never, 169, never, never |
| Repair ship | ar_diver | 26,000 | 115, 145, 125, never |
| Light cruiser | cl_agano | 36,000 | never, 169, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Smuggler

Starts at Port Saffron with dd_soldati and 28,000 credits. Two hours of play fall about day 224 with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 30,183 | 146 | 4,071 | 0 | 0 | 0 | -40 | −1,454 | −130 | −265 |
| 16–30 | 31,460 | 85 | 2,332 | 1,125 | 0 | 0 | 0 | −1,664 | −43 | −473 |
| 31–60 | 39,467 | 285 | 10,359 | 2,050 | 750 | 0 | -1,230 | −3,161 | −63 | −700 |
| 61–90 | 43,719 | 136 | 5,700 | 3,025 | 750 | 0 | -1,148 | −3,216 | −100 | −759 |
| 91–120 | 48,074 | 154 | 4,773 | 3,750 | 750 | 838 | -1,751 | −3,161 | −59 | −786 |
| 121–180 | 49,421 | 23 | 6,510 | 3,325 | 1,205 | 0 | -2,003 | −6,377 | −0 | −1,312 |
| 181–240 | 49,386 | -19 | 2,734 | 3,000 | 2,250 | 0 | -963 | −5,573 | −36 | −1,448 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.2 | 0.2 | 0.0 (0.0) | 1.0 | 1,830 (1,830) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 0.5 | 0.5 | 0.0 (0.0) | 3.5 | 1,850 (1,875) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 1.2 | 0.8 | 0.5 (0.0) | 2.4 | 1,461 (1,825) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 1.2 | 0.8 | 0.5 (0.0) | 3.4 | 7,308 (24,800) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 1.0 | 0.5 | 0.5 (0.2) | 2.0 | 1,710 (3,009) | 0.2 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 3.5 | 2.8 | 0.8 (0.0) | 2.8 | 5,503 (16,490) | 0.0 | 0.0 |
| 181–240 | 4 | 1.0 (1,830) | 1.8 | 1.2 | 0.5 (0.0) | 3.1 | 6,322 (20,696) | 0.0 | 0.2 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 47, destroyer 26, corvette 17, freighter 8, light cruiser 4, submarine 4.

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
| Light cruiser | cl_agano | 36,000 | 51, 45, 18, 42 |
| Escort carrier | cve_casa | 58,000 | never, 94, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, 94, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Privateer

Starts at Puerto Corvo with dd_soldati and 20,000 credits. Two hours of play fall about day 205 with the chart at 2×, day 212 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 18,148 | -123 | 30 | 0 | 0 | 0 | 0 | −1,664 | −0 | −218 |
| 16–30 | 18,800 | 43 | 618 | 0 | 0 | 0 | 2,000 | −1,664 | −0 | −304 |
| 31–60 | 22,891 | 145 | 6,071 | 0 | 2,000 | 0 | -111 | −3,216 | −24 | −628 |
| 61–90 | 24,868 | 68 | 4,010 | 0 | 2,000 | 0 | -111 | −3,216 | −0 | −706 |
| 91–120 | 27,978 | 121 | 2,126 | 2,400 | 2,000 | 975 | -360 | −2,967 | −265 | −798 |
| 121–180 | 34,074 | 103 | 10,084 | 2,125 | 4,000 | 700 | -909 | −6,532 | −904 | −2,468 |
| 181–240 | 34,995 | 18 | 8,059 | 1,475 | 3,386 | 0 | -3,858 | −6,243 | −46 | −1,853 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.2 | 0.0 | 0.2 (0.0) | 5.0 | 175 (175) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 0.2 | 0.2 | 0.0 (0.0) | 4.0 | 1,174 (1,174) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 0.5 | 0.2 | 0.2 (0.0) | 3.0 | 3,830 (7,384) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 0.8 | 0.5 | 0.2 (0.0) | 3.3 | 6,715 (14,584) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 2.5 | 0.8 | 1.8 (0.5) | 2.6 | 4,921 (14,050) | 0.2 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 1.2 | 0.5 | 0.8 (0.2) | 3.2 | 7,933 (14,050) | 0.2 | 0.2 |
| 181–240 | 4 | 1.0 (1,830) | 2.0 | 1.0 | 1.0 (0.0) | 3.4 | 7,418 (23,534) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 54, destroyer 15, corvette 7, freighter 6, heavy cruiser 4, light cruiser 4, submarine 4.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 121, 161, 50, 181 |
| Freighter | fr_liberty | 22,000 | 61, 138, 36, 113 |
| Fleet oiler | ao_t2 | 24,000 | 91, 153, 46, 123 |
| Ammunition ship | ae_hood | 38,000 | never, 227, 102, never |
| Repair ship | ar_diver | 26,000 | 121, 161, 50, 181 |
| Light cruiser | cl_agano | 36,000 | never, 227, 102, 217 |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Disgraced Officer

Starts at Halbrook with dd_fletcher and 14,000 credits. Two hours of play fall about day 186 with the chart at 2×, day 202 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 10,204 | -253 | 190 | 0 | 0 | 0 | -60 | −2,135 | −1,340 | −450 |
| 16–30 | 8,539 | -112 | 1,361 | 0 | 0 | 0 | -0 | −2,456 | −28 | −542 |
| 31–60 | 8,742 | -61 | 1,530 | 2,800 | 1,615 | 0 | -1,827 | −4,826 | −0 | −952 |
| 61–90 | 8,891 | 6 | 1,061 | 3,200 | 1,315 | 0 | -92 | −4,656 | −0 | −679 |
| 91–120 | 7,031 | -63 | 661 | 1,700 | 1,591 | 888 | -140 | −4,410 | −0 | −2,150 |
| 121–180 | 2,782 | -84 | 1,536 | 0 | 2,967 | 0 | -2 | −7,236 | −89 | −1,426 |
| 181–240 | 418 | -58 | 2,042 | 0 | 7,273 | 1,033 | -868 | −7,981 | −0 | −4,790 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.2 | 0.2 | 0.0 (0.0) | 1.0 | 1,525 (1,525) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 1.2 | 0.8 | 0.5 (0.0) | 5.0 | 1,619 (1,967) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (2,050) | 1.8 | 0.8 | 1.0 (0.0) | 3.9 | 2,803 (5,155) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (2,050) | 1.5 | 0.5 | 1.0 (0.0) | 4.0 | 2,120 (5,155) | 0.0 | 0.0 |
| 91–120 | 4 | 1.2 (2,285) | 1.0 | 0.2 | 0.8 (0.2) | 2.8 | 1,678 (1,966) | 0.2 | 0.0 |
| 121–180 | 4 | 1.2 (2,285) | 0.5 | 0.2 | 0.2 (0.0) | 4.5 | 3,558 (4,241) | 0.2 | 0.5 |
| 181–240 | 3 | 1.0 (2,050) | 0.7 | 0.3 | 0.3 (0.3) | 3.5 | 2,826 (5,560) | 0.3 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 69, destroyer 23, corvette 9, submarine 3.

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

Starts at Halvardsby with dd_fletcher and 6,000 credits. Two hours of play fall about day 131 with the chart at 2×, day 131 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 220 | -385 | 1,392 | 0 | 1,065 | 0 | 36 | −1,806 | −2,344 | −4,124 |
| 16–30 | 0 | -15 | 402 | 0 | 1,990 | 0 | 23 | −2,211 | −163 | −260 |
| 31–60 | 3,913 | 130 | 46 | 6,775 | 3,265 | 0 | -132 | −3,808 | −0 | −2,233 |
| 61–90 | 155 | -135 | 0 | 2,300 | 2,580 | 0 | -297 | −4,145 | −0 | −4,196 |
| 91–120 | 1,762 | 57 | 1,364 | 3,425 | 2,817 | 0 | 141 | −3,728 | −62 | −2,351 |
| 121–180 | 6,664 | 93 | 1,082 | 7,750 | 5,779 | 0 | -909 | −5,598 | −26 | −3,176 |
| 181–240 | 7,672 | -105 | 4,232 | 0 | 2,242 | 0 | -1,074 | −7,781 | −94 | −3,180 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (2,050) | 0.5 | 0.2 | 0.2 (0.0) | 3.5 | 2,138 (2,385) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (2,050) | 2.2 | 1.5 | 0.8 (0.0) | 2.0 | 2,257 (2,692) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (2,050) | 8.0 | 4.8 | 3.2 (0.0) | 2.0 | 2,208 (2,876) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (2,050) | 10.8 | 4.5 | 6.2 (0.0) | 2.0 | 2,555 (21,784) | 0.0 | 0.5 |
| 181–240 | 2 | 1.0 (2,050) | 4.0 | 1.5 | 2.5 (0.0) | 2.6 | 3,568 (7,160) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 93, destroyer 65, submarine 29, corvette 8, freighter 3.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | never, 136, 60, 44 |
| Destroyer | dd_kclass | 17,000 | never, never, 153, never |
| Submarine | ss_vii | 26,000 | never, never, never, never |
| Freighter | fr_liberty | 22,000 | never, never, 153, never |
| Fleet oiler | ao_t2 | 24,000 | never, never, never, never |
| Ammunition ship | ae_hood | 38,000 | never, never, never, never |
| Repair ship | ar_diver | 26,000 | never, never, never, never |
| Light cruiser | cl_agano | 36,000 | never, never, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Defector

Starts at Strelsk with cl_cleveland and 20,000 credits. Two hours of play fall about day 208 with the chart at 2×, day 222 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 18,055 | -130 | 120 | 0 | 0 | 6,562 | -24 | −3,451 | −1,440 | −3,712 |
| 16–30 | 10,128 | -339 | 0 | 0 | 0 | 0 | -10 | −3,850 | −0 | −1,095 |
| 31–60 | 14,657 | 167 | 0 | 0 | 1,541 | 14,775 | -347 | −7,310 | −1,698 | −2,432 |
| 61–90 | 5,352 | -391 | 0 | 0 | 725 | 1,375 | -441 | −5,246 | −2,242 | −3,476 |
| 91–120 | 0 | -47 | 0 | 0 | 5,078 | 5,025 | 180 | −6,650 | −3,003 | −1,946 |
| 121–180 | 0 | 0 | 2,447 | 0 | 5,884 | 3,275 | 1,037 | −5,967 | −636 | −6,040 |
| 181–240 | 0 | 0 | 1,590 | 0 | 6,347 | 11,100 | -2,309 | −6,511 | −7,390 | −2,827 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (11,800) | 0.8 | 0.2 | 0.5 (0.5) | 2.7 | 8,949 (22,800) | 1.2 | 0.0 |
| 16–30 | 4 | 1.0 (11,800) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.2 (12,308) | 1.8 | 0.0 | 1.8 (1.0) | 2.6 | 3,248 (5,620) | 3.2 | 0.2 |
| 61–90 | 4 | 1.8 (13,088) | 0.8 | 0.0 | 0.8 (0.2) | 3.0 | 5,762 (8,225) | 0.2 | 1.2 |
| 91–120 | 2 | 1.5 (12,645) | 0.5 | 0.0 | 0.5 (0.5) | 2.0 | 3,380 (3,380) | 0.5 | 0.0 |
| 121–180 | 2 | 1.5 (15,900) | 1.0 | 0.0 | 1.0 (0.5) | 3.0 | 7,005 (10,080) | 1.0 | 1.0 |
| 181–240 | 1 | 2.0 (20,000) | 2.0 | 0.0 | 2.0 (1.0) | 4.5 | 3,224 (6,172) | 4.0 | 2.0 |

Enemy ships met in 240 days, by class (all seeds): corvette 21, destroyer 13, motor torpedo boat 11, freighter 3, submarine 2, escort carrier 1, light cruiser 1.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 8, 38, never, never |
| Freighter | fr_liberty | 22,000 | 8, 35, never, never |
| Fleet oiler | ao_t2 | 24,000 | 8, 38, never, never |
| Ammunition ship | ae_hood | 38,000 | never, never, never, never |
| Repair ship | ar_diver | 26,000 | 8, 38, never, never |
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
| 1–15 | 14,312 | -46 | 0 | 0 | 0 | 0 | -20 | −546 | −66 | −55 |
| 16–30 | 14,005 | -23 | -34 | 0 | 0 | 675 | -26 | −765 | −20 | −136 |
| 31–60 | 16,915 | 99 | 357 | 2,400 | 1,799 | 0 | -66 | −1,306 | −0 | −274 |
| 61–90 | 23,205 | 167 | 1,648 | 5,133 | 0 | 0 | -35 | −1,547 | −51 | −448 |
| 91–120 | 21,530 | -61 | 466 | 0 | 0 | 0 | -106 | −1,477 | −0 | −558 |
| 121–180 | 21,279 | -37 | 3,022 | 0 | 0 | 0 | -601 | −2,031 | −19 | −623 |
| 181–240 | 28,560 | 126 | 1,108 | 6,450 | 3,521 | 0 | -53 | −2,875 | −30 | −1,026 |

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
| Fleet oiler | ao_t2 | 24,000 | never, 90, 40, never |
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
| 1–15 | 8 (6–14) | 15 (6–38) | 32 (14–59) | 83 (44–150) | 66 (36–119) | 92 (46–227) |
| 16–30 | 8 (6–15) | 13 (6–38) | 30 (12–58) | 88 (39–166) | 73 (27–124) | 96 (46–219) |
| 31–60 | 7 (6–14) | 15 (6–35) | 31 (14–58) | 85 (40–161) | 64 (28–116) | 90 (43–253) |
| 61–90 | 7 (5–14) | 15 (6–34) | 31 (13–62) | 86 (44–159) | 48 (28–117) | 103 (46–238) |
| 91–120 | 7 (5–14) | 16 (7–37) | 30 (13–59) | 94 (43–159) | 62 (25–117) | 91 (43–234) |
| 121–180 | 8 (5–14) | 16 (6–32) | 34 (13–65) | 83 (41–171) | 58 (26–131) | 97 (47–237) |
| 181–240 | 8 (5–14) | 16 (6–35) | 32 (11–61) | 86 (38–166) | 67 (26–135) | 84 (45–232) |

