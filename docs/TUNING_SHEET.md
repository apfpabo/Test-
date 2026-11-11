# Tuning sheet: the first hours of a campaign

*A report for the owner's tuning pass (11 Nov 2026). All figures are measured, untuned, and his to judge. One change has been made since the first sheet, at his word: a 30-day grace from bounty squadrons for a new captain (see "The first change"). The tables are measured with it.*

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

## What stands out

For the owner to judge. The grace above is the only change made.

- **Most lone starts are still lost within 240 days** (20 of 32). The killers have moved later and changed. Bounty squadrons now come after day 30, and the Academy's corvette meets one between day 67 and day 200. The Survivor and the Defector are run down by their origins' hunters (all eight runs lost by day 114). Raiders and patrols take the rest.
- **Income only beats wages for a trader.** Per day afloat in the first 120 days:
  - The Merchant made about 360 from trade and 90 from contracts, against 50 in wages.
  - The Smuggler and the Privateer made 160–170 from trade, plus 20–100 from contracts and 10–50 commission pay, against about 105 in wages.
  - The Hijacker lives on contracts once his freighter is gone (230 a day against 7 in wages).
  - The Disgraced Officer made about 120 against 160 in wages. The Survivor made about 250 against 140, but repairs, stores and losses still emptied his purse.
  - The Defector earned about 190, mostly from early prizes, against 230 in wages for his cruiser, and his purse ran down to nothing.
- **Battles pay little early.** Prizes, bounty and salvage come to under 25 a day for every origin but the Defector (134 a day, from his early wins).
- **A destroyer is in reach at once for four origins, a heavy cruiser seldom.** The cheapest destroyer (17,000) is affordable on day 1 for the Merchant, the Smuggler, the Privateer and the Defector. The Hijacker reaches it on day 32 to 199 (one run never), the Academy on day 51 to 135 (one run never). The Disgraced Officer and the Survivor never do. The cheapest heavy cruiser (62,000) was within reach in 8 of 32 runs, between days 74 and 230. A battleship (105,000) was within reach once, the Merchant on day 121. A fleet carrier never was.
- **Prices are steady, the spread between ports is wide.** Port medians hardly move over the eight months. The cheapest and dearest ports differ by four to five times for medicine, munitions and electronics, so the first ton often shows a margin over 100%. But each ton bought raises the price by 0.3% and each ton sold lowers it as much, so a full hold earns far less than that first ton suggests.
- **Two hours of play falls between day 95 and day 220.** By the model under "How it was measured", the Survivor reaches two hours about day 95 and the Hijacker (16 battles) about day 112. A quiet trader would be past day 220. Battles are most of the player's time.

## At a glance

| Origin | Starts with | Credits at start | Purse day 30 | Day 60 | Day 120 | Day 240 | Battles (won) in 240 days | 1 h / 2 h of play at 2× (day) | at 4× (day) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| The Merchant Captain | fr_victory | 45,000 | 44,713 | 41,863 | 83,405 | 87,456 | 1.0 (0.2) · squadron lost on day 41, 142, 127 | 207 / – | 235 / – |
| The Hijacker | fr_liberty, pt_elco | 9,000 | 11,407 | 25,721 | 38,968 | 58,908 | 15.8 (0.8) · squadron lost on day 148, 143 | 52 / 112 | 54 / 113 |
| The Smuggler | dd_soldati | 28,000 | 31,214 | 35,088 | 31,930 | 46,889 | 4.2 (1.0) · squadron lost on day 175 | 114 / 220 | 121 / 218 |
| The Privateer | dd_soldati | 20,000 | 19,480 | 27,501 | 43,096 | 53,382 | 5.5 (0.2) | 79 / 184 | 82 / 184 |
| The Disgraced Officer | dd_fletcher | 14,000 | 8,836 | 7,819 | 928 | 5,480 | 4.0 (0.5) · squadron lost on day 89, 16 | 98 / 167 | 104 / 175 |
| The Survivor of the Lost Fleet | dd_fletcher | 6,000 | 1,687 | 3,476 | 0 | – | 6.8 (0.0) · squadron lost on day 50, 114, 107, 17 | 53 / 94 | 54 / 100 |
| The Defector | cl_cleveland | 20,000 | 7,992 | 2,192 | – | – | 3.8 (1.8) · squadron lost on day 87, 34, 43, 23 | 83 / – | 84 / – |
| The Academy Cast-Off | co_flower | 15,000 | 13,210 | 16,335 | 24,660 | 22,988 | 7.8 (0.2) · squadron lost on day 152, 200, 153, 67 | 95 / 140 | 103 / 142 |

## The Merchant Captain

Starts at Cape Ombra with fr_victory and 45,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 42,604 | -160 | -1,174 | 0 | 0 | 0 | 0 | −740 | −0 | −483 |
| 16–30 | 44,713 | 141 | 3,415 | 0 | 0 | 0 | -0 | −740 | −0 | −566 |
| 31–60 | 41,863 | -14 | -1,615 | 2,975 | 0 | 0 | -46 | −1,286 | −638 | −2,240 |
| 61–90 | 62,916 | 935 | 27,565 | 1,767 | 0 | 0 | -306 | −1,698 | −0 | −1,321 |
| 91–120 | 83,405 | 710 | 20,041 | 6,000 | 0 | 0 | -2,465 | −1,712 | −0 | −1,376 |
| 121–180 | 78,197 | -528 | -1,269 | 0 | 0 | 0 | -625 | −2,000 | −0 | −1,314 |
| 181–240 | 87,456 | 202 | 15,157 | 9,500 | 0 | 0 | -5,340 | −4,357 | −0 | −3,429 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (7,600) | 0.2 | 0.2 | 0.0 (0.0) | 3.0 | 209 (209) | 0.0 | 0.0 |
| 31–60 | 4 | 1.2 (7,958) | 0.5 | 0.0 | 0.5 (0.2) | 1.5 | 2,036 (2,641) | 0.0 | 0.2 |
| 61–90 | 3 | 1.3 (8,077) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 91–120 | 3 | 1.3 (8,077) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 121–180 | 3 | 1.3 (8,077) | 0.7 | 0.0 | 0.7 (0.0) | 5.5 | 8,694 (11,442) | 0.0 | 0.7 |
| 181–240 | 1 | 2.0 (9,030) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 8, destroyer 5, corvette 2, light cruiser 1, submarine 1.

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
| Escort carrier | cve_casa | 58,000 | never, 83, 74, 100 |
| Heavy cruiser | ca_zara | 62,000 | never, 83, 74, 100 |
| Battleship | bb_scharnhorst | 105,000 | never, never, 121, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Hijacker

Starts at Kesselport with fr_liberty, pt_elco and 9,000 credits. Two hours of play fall about day 112 with the chart at 2×, day 113 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 9,419 | 28 | -130 | 0 | 0 | 1,625 | 83 | −515 | −296 | −349 |
| 16–30 | 11,407 | 158 | -74 | 2,125 | 0 | 0 | -5 | −45 | −85 | −25 |
| 31–60 | 25,721 | 532 | 351 | 11,750 | 2,298 | 0 | 111 | −105 | −44 | −90 |
| 61–90 | 30,416 | 204 | 338 | 4,675 | 0 | 0 | -125 | −97 | −40 | −71 |
| 91–120 | 38,968 | 304 | -48 | 8,750 | 0 | 0 | -4 | −110 | −53 | −106 |
| 121–180 | 44,436 | 99 | 224 | 5,625 | 0 | 0 | -5 | −150 | −157 | −68 |
| 181–240 | 58,908 | 238 | 140 | 13,400 | 0 | 0 | -17 | −186 | −226 | −276 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (50) | 3.5 | 0.5 | 3.0 (0.5) | 2.6 | 3,200 (9,440) | 1.0 | 1.0 |
| 16–30 | 4 | 1.0 (50) | 2.8 | 2.0 | 0.8 (0.0) | 3.2 | 3,674 (14,492) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (50) | 7.0 | 3.8 | 3.2 (0.0) | 3.0 | 8,091 (25,540) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (50) | 8.8 | 4.5 | 4.2 (0.2) | 2.5 | 5,667 (22,184) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (50) | 4.2 | 3.0 | 1.2 (0.0) | 3.6 | 8,334 (24,800) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (50) | 5.8 | 4.0 | 1.8 (0.0) | 2.5 | 6,610 (15,910) | 0.0 | 0.5 |
| 181–240 | 2 | 1.0 (50) | 8.5 | 5.5 | 3.0 (0.0) | 2.9 | 7,208 (24,450) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 170, destroyer 95, freighter 72, corvette 53, submarine 14, light cruiser 11.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | never, 199, 52, 32 |
| Submarine | ss_vii | 26,000 | never, 199, 57, 48 |
| Freighter | fr_liberty | 22,000 | never, 199, 57, 48 |
| Fleet oiler | ao_t2 | 24,000 | never, 199, 57, 48 |
| Ammunition ship | ae_hood | 38,000 | never, 237, 69, 54 |
| Repair ship | ar_diver | 26,000 | never, 199, 57, 48 |
| Light cruiser | cl_agano | 36,000 | never, 237, 69, 54 |
| Escort carrier | cve_casa | 58,000 | never, never, 93, 147 |
| Heavy cruiser | ca_zara | 62,000 | never, never, 93, 147 |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Smuggler

Starts at Port Saffron with dd_soldati and 28,000 credits. Two hours of play fall about day 220 with the chart at 2×, day 218 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 31,298 | 220 | 5,470 | 0 | 0 | 0 | 0 | −1,664 | −258 | −250 |
| 16–30 | 31,214 | -12 | 2,231 | 0 | 0 | 0 | -374 | −1,608 | −70 | −262 |
| 31–60 | 35,088 | 131 | 6,347 | 2,625 | 375 | 850 | -2,259 | −3,133 | −156 | −775 |
| 61–90 | 35,181 | 3 | 3,145 | 0 | 375 | 875 | -373 | −3,216 | −37 | −676 |
| 91–120 | 31,930 | -94 | 2,554 | 0 | 375 | 0 | -1,710 | −3,161 | −81 | −751 |
| 121–180 | 38,498 | 116 | 8,901 | 2,275 | 3,661 | 0 | -374 | −6,238 | −51 | −1,606 |
| 181–240 | 46,889 | 73 | 8,590 | 4,067 | 1,000 | 1,783 | -2,694 | −5,934 | −1,249 | −1,709 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.5 | 0.2 | 0.2 (0.0) | 2.5 | 1,362 (2,625) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 1.0 | 0.5 | 0.5 (0.0) | 2.8 | 3,769 (14,800) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 1.8 | 1.2 | 0.5 (0.2) | 4.0 | 3,650 (10,448) | 0.5 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 1.2 | 0.8 | 0.5 (0.2) | 2.8 | 3,780 (10,423) | 0.5 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 1.2 | 1.2 | 0.0 (0.0) | 3.4 | 10,754 (15,800) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 3.5 | 2.5 | 1.0 (0.0) | 3.3 | 7,551 (22,940) | 0.2 | 0.2 |
| 181–240 | 3 | 1.0 (1,830) | 3.7 | 1.7 | 2.0 (0.7) | 3.0 | 7,773 (19,732) | 1.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 56, corvette 38, destroyer 34, light cruiser 12, freighter 7, submarine 5, heavy cruiser 2.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 1, 1, 1, 1 |
| Freighter | fr_liberty | 22,000 | 1, 1, 1, 1 |
| Fleet oiler | ao_t2 | 24,000 | 1, 1, 1, 1 |
| Ammunition ship | ae_hood | 38,000 | 148, 47, 146, never |
| Repair ship | ar_diver | 26,000 | 1, 1, 1, 1 |
| Light cruiser | cl_agano | 36,000 | 52, 47, 146, never |
| Escort carrier | cve_casa | 58,000 | 224, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Privateer

Starts at Puerto Corvo with dd_soldati and 20,000 credits. Two hours of play fall about day 184 with the chart at 2×, day 184 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 18,077 | -128 | -33 | 0 | 0 | 0 | 0 | −1,636 | −0 | −254 |
| 16–30 | 19,480 | 79 | 1,079 | 0 | 0 | 0 | 2,000 | −1,608 | −0 | −299 |
| 31–60 | 27,501 | 271 | 4,408 | 5,175 | 2,000 | 638 | -166 | −3,161 | −187 | −685 |
| 61–90 | 38,425 | 375 | 7,071 | 5,950 | 2,000 | 0 | -166 | −3,161 | −0 | −770 |
| 91–120 | 43,096 | 161 | 6,075 | 825 | 2,000 | 0 | -379 | −3,188 | −0 | −661 |
| 121–180 | 49,738 | 117 | 4,856 | 7,050 | 4,000 | 0 | -1,379 | −6,349 | −16 | −1,521 |
| 181–240 | 53,382 | 67 | 8,453 | 1,175 | 4,000 | 488 | -2,866 | −6,044 | −0 | −1,562 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 1.0 | 0.2 | 0.8 (0.0) | 2.2 | 1,794 (5,200) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 0.8 | 0.5 | 0.2 (0.0) | 3.0 | 4,317 (7,384) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 1.0 | 0.2 | 0.8 (0.2) | 2.2 | 3,762 (7,784) | 0.2 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 1.8 | 1.2 | 0.5 (0.0) | 3.3 | 3,151 (3,660) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 1.8 | 1.0 | 0.8 (0.0) | 2.3 | 6,382 (22,184) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 2.8 | 1.8 | 1.0 (0.0) | 3.5 | 8,417 (22,584) | 0.0 | 0.0 |
| 181–240 | 4 | 1.0 (1,830) | 2.5 | 1.0 | 1.5 (0.0) | 4.4 | 10,084 (24,692) | 0.2 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 81, destroyer 28, freighter 20, corvette 7, light cruiser 6, submarine 6.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 41, 83, 69, 129 |
| Freighter | fr_liberty | 22,000 | 41, 83, 39, 48 |
| Fleet oiler | ao_t2 | 24,000 | 41, 83, 62, 129 |
| Ammunition ship | ae_hood | 38,000 | 53, 121, 80, never |
| Repair ship | ar_diver | 26,000 | 41, 83, 69, 129 |
| Light cruiser | cl_agano | 36,000 | 53, 117, 80, 236 |
| Escort carrier | cve_casa | 58,000 | 99, never, 211, never |
| Heavy cruiser | ca_zara | 62,000 | 179, never, 230, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Disgraced Officer

Starts at Halbrook with dd_fletcher and 14,000 credits. Two hours of play fall about day 167 with the chart at 2×, day 175 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 9,749 | -283 | 192 | 0 | 0 | 0 | -0 | −2,540 | −1,400 | −502 |
| 16–30 | 8,836 | -61 | 1,320 | 0 | 0 | 0 | -0 | −1,905 | −0 | −328 |
| 31–60 | 7,819 | -33 | 1,192 | 5,167 | 296 | 650 | -186 | −4,806 | −1,153 | −2,054 |
| 61–90 | 4,588 | -106 | 1,205 | 0 | 1,372 | 0 | -13 | −4,691 | −0 | −995 |
| 91–120 | 928 | -231 | 189 | 0 | 243 | 1,900 | -505 | −4,387 | −2,014 | −1,380 |
| 121–180 | 0 | -17 | 0 | 7,200 | 5,724 | 0 | -135 | −8,326 | −0 | −5,391 |
| 181–240 | 5,480 | 96 | 0 | 9,000 | 6,701 | 0 | -1,077 | −7,305 | −0 | −1,840 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.5 | 0.5 | 0.0 (0.0) | 3.0 | 1,856 (1,947) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 0.2 | 0.0 | 0.2 (0.0) | 1.0 | 1,750 (1,750) | 0.0 | 0.2 |
| 31–60 | 3 | 1.3 (2,507) | 1.7 | 1.0 | 0.7 (0.3) | 3.8 | 6,062 (11,347) | 0.3 | 0.0 |
| 61–90 | 3 | 1.3 (2,507) | 1.3 | 0.3 | 1.0 (0.0) | 5.2 | 8,668 (11,347) | 0.3 | 0.7 |
| 91–120 | 2 | 1.0 (2,050) | 2.0 | 0.0 | 2.0 (0.5) | 3.5 | 6,192 (11,297) | 1.0 | 0.0 |
| 121–180 | 2 | 1.0 (2,050) | 2.5 | 0.0 | 2.5 (0.0) | 5.0 | 7,753 (11,347) | 0.0 | 0.0 |
| 181–240 | 2 | 1.0 (2,050) | 1.5 | 1.0 | 0.5 (0.0) | 1.7 | 6,774 (6,922) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 53, destroyer 22, light cruiser 12, corvette 4.

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

## The Survivor of the Lost Fleet

Starts at Halvardsby with dd_fletcher and 6,000 credits. Two hours of play fall about day 94 with the chart at 2×, day 100 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 0 | -400 | 410 | 0 | 1,359 | 0 | 137 | −2,353 | −2,333 | −3,220 |
| 16–30 | 1,687 | 112 | 0 | 1,825 | 1,555 | 0 | -49 | −1,644 | −0 | −0 |
| 31–60 | 3,476 | 90 | 0 | 3,600 | 7,654 | 0 | -1,353 | −3,428 | −0 | −5,247 |
| 61–90 | 0 | 0 | 0 | 0 | 3,761 | 0 | -31 | −3,730 | −0 | −0 |
| 91–120 | 0 | 0 | 180 | 0 | 2,111 | 0 | -6 | −2,105 | −0 | −179 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.2 | 0.2 | 0.0 (0.0) | 4.0 | 3,195 (3,195) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 2.0 | 0.5 | 1.5 (0.0) | 2.1 | 2,492 (5,292) | 0.0 | 0.2 |
| 31–60 | 3 | 1.0 (2,050) | 4.7 | 2.3 | 2.3 (0.0) | 2.2 | 3,342 (11,347) | 0.0 | 0.3 |
| 61–90 | 2 | 1.0 (2,050) | 6.5 | 2.5 | 4.0 (0.0) | 2.5 | 4,280 (5,292) | 0.0 | 0.0 |
| 91–120 | 2 | 1.0 (2,050) | 12.0 | 9.0 | 3.0 (0.0) | 2.0 | 3,238 (5,292) | 0.5 | 1.0 |
| 121–180 | 0 | | | | | | | | |
| 181–240 | 0 | | | | | | | | |

Enemy ships met in 240 days, by class (all seeds): destroyer 56, motor torpedo boat 44, submarine 28, corvette 3, light cruiser 1.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 48, 50, never, never |
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
| 1–15 | 11,009 | -599 | 115 | 0 | 3 | 2,862 | 101 | −4,035 | −2,434 | −5,603 |
| 16–30 | 7,992 | -207 | 0 | 0 | 902 | 0 | -18 | −3,004 | −83 | −814 |
| 31–60 | 2,192 | 72 | 63 | 0 | 1,287 | 2,467 | 52 | −3,176 | −1,258 | −376 |
| 61–90 | 0 | 0 | 61 | 0 | 1,670 | 5,300 | -36 | −3,099 | −1,264 | −2,632 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 2.2 (18,158) | 0.8 | 0.0 | 0.8 (0.8) | 3.7 | 11,163 (22,800) | 0.8 | 0.8 |
| 16–30 | 4 | 2.0 (12,065) | 1.5 | 1.2 | 0.2 (0.0) | 2.3 | 5,171 (8,530) | 0.0 | 0.8 |
| 31–60 | 3 | 3.0 (15,165) | 2.3 | 0.7 | 1.7 (1.0) | 3.0 | 8,071 (14,860) | 0.7 | 3.3 |
| 61–90 | 1 | 1.0 (11,800) | 6.0 | 0.0 | 6.0 (1.0) | 2.7 | 12,665 (14,860) | 1.0 | 1.0 |
| 91–120 | 0 | | | | | | | | |
| 121–180 | 0 | | | | | | | | |
| 181–240 | 0 | | | | | | | | |

Enemy ships met in 240 days, by class (all seeds): destroyer 22, corvette 20, light cruiser 10, motor torpedo boat 5, freighter 3, submarine 2.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | never, never, never, never |
| Freighter | fr_liberty | 22,000 | never, never, 10, 16 |
| Fleet oiler | ao_t2 | 24,000 | never, never, never, never |
| Ammunition ship | ae_hood | 38,000 | never, never, never, never |
| Repair ship | ar_diver | 26,000 | never, never, never, never |
| Light cruiser | cl_agano | 36,000 | never, never, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Academy Cast-Off

Starts at Calder Roads with co_flower and 15,000 credits. Two hours of play fall about day 140 with the chart at 2×, day 142 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 14,209 | -53 | 0 | 0 | 0 | 0 | 0 | −791 | −0 | −0 |
| 16–30 | 13,210 | -73 | -33 | 0 | 0 | 0 | -66 | −725 | −18 | −156 |
| 31–60 | 16,335 | 117 | 378 | 4,450 | 0 | 312 | -119 | −1,450 | −70 | −377 |
| 61–90 | 21,500 | 152 | 1,810 | 4,875 | 0 | 0 | 0 | −1,213 | −0 | −283 |
| 91–120 | 24,660 | -18 | 1,572 | 0 | 0 | 0 | -172 | −1,420 | −0 | −436 |
| 121–180 | 37,310 | 418 | 4,024 | 11,267 | 0 | 600 | -128 | −2,462 | −0 | −651 |
| 181–240 | 22,988 | 16 | 1,543 | 0 | 0 | 0 | 2 | −994 | −0 | −237 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (940) | 0.2 | 0.0 | 0.2 (0.0) | 2.0 | 2,625 (2,625) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (940) | 1.8 | 0.0 | 1.8 (0.0) | 2.7 | 2,214 (2,625) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (940) | 2.2 | 0.8 | 1.5 (0.2) | 2.8 | 1,386 (3,752) | 0.2 | 0.0 |
| 61–90 | 4 | 1.0 (940) | 0.5 | 0.0 | 0.5 (0.0) | 3.0 | 6,262 (10,473) | 0.0 | 0.2 |
| 91–120 | 3 | 1.0 (940) | 3.0 | 0.0 | 3.0 (0.0) | 3.8 | 1,075 (2,050) | 0.0 | 0.0 |
| 121–180 | 3 | 1.0 (940) | 1.7 | 0.3 | 1.3 (0.0) | 4.8 | 7,943 (12,761) | 0.3 | 0.7 |
| 181–240 | 1 | 1.0 (940) | 4.0 | 2.0 | 2.0 (0.0) | 3.0 | 10,990 (10,990) | 0.0 | 1.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 74, submarine 16, destroyer 13, corvette 11, light cruiser 8.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 51, 83, 135, never |
| Submarine | ss_vii | 26,000 | 59, never, never, never |
| Freighter | fr_liberty | 22,000 | 59, 83, 135, never |
| Fleet oiler | ao_t2 | 24,000 | 59, 83, 139, never |
| Ammunition ship | ae_hood | 38,000 | 92, never, never, never |
| Repair ship | ar_diver | 26,000 | 59, never, never, never |
| Light cruiser | cl_agano | 36,000 | 89, never, never, never |
| Escort carrier | cve_casa | 58,000 | 125, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | 125, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## Prices in port

Port prices (before the 6% buying and 7% selling spread) seen by all captains when they made harbour, as median (lowest–highest).

| Days | Fuel | Food | Steel | Medicine | Munitions | Electronics |
|---|---:|---:|---:|---:|---:|---:|
| 1–15 | 8 (6–14) | 15 (6–40) | 31 (13–59) | 85 (47–161) | 65 (28–118) | 104 (45–234) |
| 16–30 | 8 (6–14) | 16 (6–41) | 32 (16–58) | 82 (45–150) | 70 (27–117) | 100 (49–228) |
| 31–60 | 7 (5–14) | 15 (5–35) | 31 (13–58) | 90 (46–177) | 58 (27–120) | 98 (48–244) |
| 61–90 | 7 (6–13) | 15 (6–34) | 34 (12–59) | 85 (41–157) | 70 (28–120) | 91 (45–243) |
| 91–120 | 7 (5–13) | 13 (6–32) | 33 (17–57) | 86 (43–155) | 67 (26–119) | 94 (56–224) |
| 121–180 | 8 (5–15) | 15 (6–37) | 32 (17–63) | 86 (42–157) | 62 (26–120) | 97 (48–241) |
| 181–240 | 8 (6–14) | 15 (6–34) | 34 (17–63) | 82 (42–157) | 45 (27–115) | 107 (48–234) |

