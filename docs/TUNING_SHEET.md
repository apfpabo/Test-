# Tuning sheet: the first hours of a campaign

*A report for the owner's tuning pass (11 Nov 2026). No number in the game was changed to make it. All figures are measured, untuned, and his to judge.*

## How it was measured

`tests/tune_probe.tscn` is the soak test's unattended captain (`tests/soak_test.gd`: real weather and calendar, every hostile contact fought out by the battle simulation as the battle screen sets it up) with **honest money**: the purse is never topped up and none of the soak's scripted events (reinforcements, a flag, the bomb) are run. In port he sells his cargo, repairs and rearms if he can pay, hires crew to need, buys fuel to the bunkers' room and food for forty days, takes contracts, commissions and story orders as the soak does, and rests a tired squadron. Before sailing he buys the good with the best margin at the port he is bound for, as many tons as still pay (prices move ton by ton). He is prudent, as a player would be: from any force that is not clearly weaker (the contact panel's strength ratio over 0.8, "an even fight" or worse) he tries to break off at the panel's own odds; caught all the same and outgunned, he orders a withdrawal; and until he has three ships he takes only peaceful contracts (deliveries, surveys, escorts, smuggling), no hunts, war contracts, strikes or story orders. He takes prizes, but **buys no ships**, so "affordable" below is read off his purse: the first day his money covers the cheapest design of that class he could order with the research he holds. He does no research of his own, and goes looking for a fight only once he has three ships.

Each origin was played for up to 240 days on four seeds (11, 23, 37, 51), the navy origins for the Concord. A run ends when the squadron is lost. Figures are the mean of the runs still afloat in that period (the "Afloat" column says how many).

**Days into hours.** A chart day lasts 10 s at 1×. The sheet assumes a battle takes 8 minutes of the player's time, a port call 1.5 minutes and any other contact 20 seconds, and reads off the day at which one and two hours are reached with the chart running at 2× and at 4×. These are assumptions, not measurements: the day columns are the measurement.

## What stands out

For the owner to judge; nothing below has been changed in the game.

- **A lone start rarely lives to day 240.** 15 of 32 runs lost their squadron, even though the captain broke off from any even fight and withdrew when caught. Every Defector run was lost by day 61, and every Survivor run by day 114. The Academy Cast-Off was lost on day 2, 5 and 15 in three of four runs. Merchant runs ended on days 2, 41, 127 and 142.
- **Bounty squadrons are what kill the youngest starts.** These are the raider squadrons with a price on them (`spawn_fleet("bounty")`, captain 4–7, eight in ten ships a refitted variant). In the first fortnight they met a lone corvette, freighter or destroyer at 6 to 18 times its strength: the Academy on days 2, 5 and 10, the Merchant on day 2, the Privateer on day 8. Breaking off fails often enough at the panel's odds (40% for equal speed, less for a slow freighter). One meeting ends the run.
- **Income only beats wages for a trader.** In the first 120 days, per day afloat:
  - The Merchant made about 410 from trade against 50 in wages.
  - The Smuggler and the Privateer made 140–180 from trade, plus 20–70 from contracts, against about 105 in wages.
  - The Disgraced Officer, the Survivor and the Defector earned 60–180 from contracts and commission pay against 140–240 in wages, and their purses ran down to nothing. The Defector's cruiser costs 240 a day before stores.
  - The Hijacker lives on contracts once his freighter is gone (140 a day against 8 in wages for a torpedo boat).
- **Battles pay almost nothing early.** Prizes, bounty and salvage came to under 15 a day for every origin but the Defector (121 a day, from two early wins).
- **A destroyer is in reach at once; a heavy cruiser rarely.** The cheapest destroyer (17,000) is affordable on day 1 for the Merchant, the Smuggler, the Privateer and the Defector. The Hijacker needed 8 to 199 days. The Disgraced Officer reached it once (day 69), the Survivor never, the Academy once (day 99). The cheapest heavy cruiser (62,000) was within reach in 4 of 32 runs, between days 74 and 230. A battleship (105,000) was within reach once, the Merchant on day 121. A fleet carrier never was.
- **Prices are steady, the spread between ports is wide.** Port medians hardly move over the eight months (steel about 31, munitions 43–83, electronics 86–115). The cheapest and dearest ports differ by four to five times for medicine, munitions and electronics, so the first ton often shows a margin over 100%. But each ton bought raises the price by 0.3% and each ton sold lowers it as much, so a full hold earns far less than that first ton suggests.
- **Two hours of play is somewhere between day 95 and day 230.** By the model under "How it was measured", the Survivor reaches two hours about day 95, and the Hijacker (13 battles) about day 130. A quiet trader would be past day 200. Battles are most of the player's time.

## At a glance

| Origin | Starts with | Credits at start | Purse day 30 | Day 60 | Day 120 | Day 240 | Battles (won) in 240 days | 1 h / 2 h of play at 2× (day) | at 4× (day) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| The Merchant Captain | fr_victory | 45,000 | 44,938 | 39,434 | 87,369 | – | 1.0 (0.0) · squadron lost on day 41, 142, 127, 2 | – / – | – / – |
| The Hijacker | fr_liberty, pt_elco | 9,000 | 17,790 | 26,100 | 28,356 | 53,227 | 12.8 (0.8) · squadron lost on day 148 | 70 / 130 | 72 / 130 |
| The Smuggler | dd_soldati | 28,000 | 31,366 | 34,582 | 32,886 | 42,678 | 3.2 (0.8) · squadron lost on day 175 | 107 / 222 | 115 / – |
| The Privateer | dd_soldati | 20,000 | 19,612 | 21,175 | 36,018 | 46,236 | 5.2 (0.0) · squadron lost on day 21 | 80 / 182 | 82 / 192 |
| The Disgraced Officer | dd_fletcher | 14,000 | 8,224 | 6,801 | 3,938 | 0 | 3.2 (0.2) · squadron lost on day 170, 89 | 117 / 210 | 127 / 200 |
| The Survivor of the Lost Fleet | dd_fletcher | 6,000 | 1,687 | 3,476 | 0 | – | 6.8 (0.0) · squadron lost on day 50, 114, 107, 17 | 53 / 94 | 54 / 100 |
| The Defector | cl_cleveland | 20,000 | 7,990 | 5,022 | – | – | 3.0 (1.5) · squadron lost on day 61, 34, 43, 23 | – / – | – / – |
| The Academy Cast-Off | co_flower | 15,000 | 13,286 | 11,813 | 26,061 | 39,996 | 3.0 (0.2) · squadron lost on day 5, 2, 15 | 36 / 197 | 39 / 229 |

## The Merchant Captain

Starts at Cape Ombra with fr_victory and 45,000 credits. Two hours of play fall about day – with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 43,770 | -87 | -427 | 0 | 0 | 0 | -0 | −567 | −0 | −236 |
| 16–30 | 44,938 | 104 | 2,960 | 0 | 0 | 0 | -0 | −740 | −0 | −659 |
| 31–60 | 39,434 | -79 | -3,600 | 0 | 0 | 0 | -0 | −1,150 | −0 | −754 |
| 61–90 | 73,829 | 1,537 | 43,100 | 2,650 | 0 | 0 | -99 | −1,380 | −0 | −1,230 |
| 91–120 | 87,369 | 451 | 16,380 | 3,400 | 0 | 0 | -3,619 | −1,479 | −0 | −1,142 |
| 121–180 | 79,333 | -796 | -7,091 | 0 | 0 | 0 | -0 | −666 | −0 | −280 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (7,600) | 0.2 | 0.0 | 0.2 (0.0) | 5.0 | 14,583 (14,583) | 0.0 | 0.2 |
| 16–30 | 3 | 1.0 (7,600) | 0.3 | 0.3 | 0.0 (0.0) | 3.0 | 209 (209) | 0.0 | 0.0 |
| 31–60 | 3 | 1.0 (7,600) | 0.3 | 0.0 | 0.3 (0.0) | 2.0 | 2,641 (2,641) | 0.0 | 0.3 |
| 61–90 | 2 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 91–120 | 2 | 1.0 (7,600) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 121–180 | 2 | 1.0 (7,600) | 1.0 | 0.0 | 1.0 (0.0) | 5.5 | 8,694 (11,442) | 0.0 | 1.0 |
| 181–240 | 0 | | | | | | | | |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 11, destroyer 6, light cruiser 2, corvette 1, submarine 1.

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
| Escort carrier | cve_casa | 58,000 | never, 83, 74, never |
| Heavy cruiser | ca_zara | 62,000 | never, 83, 74, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, 121, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Hijacker

Starts at Kesselport with fr_liberty, pt_elco and 9,000 credits. Two hours of play fall about day 130 with the chart at 2×, day 130 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 15,747 | 450 | -168 | 6,450 | 0 | 1,625 | 83 | −556 | −333 | −353 |
| 16–30 | 17,790 | 163 | -71 | 2,125 | 0 | 0 | -3 | −46 | −47 | −11 |
| 31–60 | 26,100 | 318 | 170 | 5,925 | 2,298 | 0 | 111 | −105 | −35 | −98 |
| 61–90 | 26,080 | -1 | 340 | 0 | 0 | 0 | -123 | −105 | −48 | −101 |
| 91–120 | 28,356 | 76 | 189 | 2,350 | 0 | 0 | -4 | −111 | −44 | −104 |
| 121–180 | 33,730 | 96 | 234 | 5,625 | 0 | 0 | -6 | −187 | −184 | −109 |
| 181–240 | 53,227 | 202 | 392 | 11,233 | 0 | 0 | -17 | −194 | −195 | −261 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (50) | 4.2 | 1.5 | 2.8 (0.5) | 3.1 | 6,442 (24,692) | 1.0 | 1.0 |
| 16–30 | 4 | 1.0 (50) | 2.5 | 1.8 | 0.8 (0.0) | 3.1 | 3,860 (14,492) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (50) | 4.8 | 2.5 | 2.2 (0.0) | 2.9 | 6,607 (24,616) | 0.0 | 0.0 |
| 61–90 | 4 | 1.0 (50) | 4.5 | 2.0 | 2.5 (0.2) | 2.2 | 7,225 (16,230) | 0.0 | 0.0 |
| 91–120 | 4 | 1.0 (50) | 2.0 | 1.5 | 0.5 (0.0) | 3.1 | 7,461 (17,400) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (50) | 8.2 | 6.5 | 1.8 (0.0) | 2.7 | 8,393 (23,650) | 0.0 | 0.2 |
| 181–240 | 3 | 1.0 (50) | 7.7 | 4.7 | 3.0 (0.0) | 3.2 | 7,676 (24,450) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 147, destroyer 82, freighter 74, corvette 38, light cruiser 14, submarine 11.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | never, 199, 8, 32 |
| Submarine | ss_vii | 26,000 | never, 199, 8, 48 |
| Freighter | fr_liberty | 22,000 | never, 199, 8, 48 |
| Fleet oiler | ao_t2 | 24,000 | never, 199, 8, 48 |
| Ammunition ship | ae_hood | 38,000 | never, 237, 191, 54 |
| Repair ship | ar_diver | 26,000 | never, 199, 8, 48 |
| Light cruiser | cl_agano | 36,000 | never, 237, 191, 54 |
| Escort carrier | cve_casa | 58,000 | never, never, never, 147 |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, 147 |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Smuggler

Starts at Port Saffron with dd_soldati and 28,000 credits. Two hours of play fall about day 222 with the chart at 2×, day – at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 31,298 | 220 | 5,470 | 0 | 0 | 0 | 0 | −1,664 | −258 | −250 |
| 16–30 | 31,366 | -2 | 2,404 | 0 | 0 | 0 | -374 | −1,608 | −70 | −284 |
| 31–60 | 34,582 | 107 | 6,030 | 2,625 | 375 | 425 | -2,231 | −3,161 | −110 | −738 |
| 61–90 | 33,362 | -40 | 2,542 | 0 | 375 | 875 | -1,011 | −3,216 | −54 | −731 |
| 91–120 | 32,886 | -0 | 4,372 | 0 | 375 | 0 | -809 | −3,105 | −81 | −752 |
| 121–180 | 34,364 | 24 | 8,790 | 0 | 1,042 | 0 | -374 | −6,294 | −113 | −1,573 |
| 181–240 | 42,678 | 93 | 7,249 | 6,933 | 1,000 | 1,183 | -2,121 | −6,082 | −1,254 | −1,752 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 0.5 | 0.2 | 0.2 (0.0) | 2.5 | 1,362 (2,625) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 1.0 | 0.5 | 0.5 (0.0) | 2.8 | 3,769 (14,800) | 0.0 | 0.0 |
| 31–60 | 4 | 1.0 (1,830) | 1.8 | 1.2 | 0.5 (0.2) | 4.0 | 3,650 (10,448) | 0.2 | 0.0 |
| 61–90 | 4 | 1.0 (1,830) | 1.0 | 0.5 | 0.5 (0.2) | 2.8 | 2,119 (3,060) | 0.5 | 0.0 |
| 91–120 | 4 | 1.0 (1,830) | 2.0 | 1.8 | 0.2 (0.0) | 3.6 | 10,639 (15,800) | 0.0 | 0.0 |
| 121–180 | 4 | 1.0 (1,830) | 3.5 | 2.8 | 0.8 (0.0) | 3.6 | 7,436 (22,940) | 0.2 | 0.2 |
| 181–240 | 3 | 1.0 (1,830) | 1.3 | 0.7 | 0.7 (0.3) | 3.2 | 4,474 (10,448) | 0.7 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 63, destroyer 31, corvette 31, light cruiser 13, freighter 6, submarine 3.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | 1, 1, 1, 1 |
| Freighter | fr_liberty | 22,000 | 1, 1, 1, 1 |
| Fleet oiler | ao_t2 | 24,000 | 1, 1, 1, 1 |
| Ammunition ship | ae_hood | 38,000 | 188, 47, 146, never |
| Repair ship | ar_diver | 26,000 | 1, 1, 1, 1 |
| Light cruiser | cl_agano | 36,000 | 188, 47, 146, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Privateer

Starts at Puerto Corvo with dd_soldati and 20,000 credits. Two hours of play fall about day 182 with the chart at 2×, day 192 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 18,256 | -116 | 140 | 0 | 0 | 0 | 0 | −1,636 | −0 | −249 |
| 16–30 | 19,612 | 25 | 395 | 800 | 0 | 0 | 1,445 | −1,275 | −0 | −238 |
| 31–60 | 21,175 | 25 | 4,477 | 0 | 2,000 | 0 | -333 | −2,984 | −1,186 | −1,126 |
| 61–90 | 33,150 | 406 | 6,103 | 7,933 | 2,000 | 0 | -74 | −3,253 | −0 | −735 |
| 91–120 | 36,018 | 93 | 5,937 | 0 | 2,000 | 0 | -1,012 | −3,253 | −0 | −804 |
| 121–180 | 41,017 | 90 | 6,493 | 4,233 | 4,000 | 0 | -1,999 | −6,247 | −21 | −1,460 |
| 181–240 | 46,236 | 94 | 9,427 | 3,200 | 4,000 | 0 | -3,873 | −6,063 | −0 | −1,473 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (1,830) | 1.2 | 0.2 | 1.0 (0.0) | 2.6 | 3,525 (10,448) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (1,830) | 1.8 | 0.8 | 1.0 (0.0) | 3.1 | 6,356 (10,448) | 0.0 | 0.2 |
| 31–60 | 3 | 1.0 (1,830) | 1.0 | 0.3 | 0.7 (0.0) | 1.7 | 1,170 (1,972) | 0.0 | 0.0 |
| 61–90 | 3 | 1.0 (1,830) | 0.7 | 0.3 | 0.3 (0.0) | 3.5 | 13,238 (14,583) | 0.0 | 0.0 |
| 91–120 | 3 | 1.0 (1,830) | 1.0 | 0.7 | 0.3 (0.0) | 2.3 | 1,799 (2,692) | 0.0 | 0.0 |
| 121–180 | 3 | 1.0 (1,830) | 3.0 | 1.3 | 1.7 (0.0) | 3.4 | 4,585 (11,800) | 0.0 | 0.0 |
| 181–240 | 3 | 1.0 (1,830) | 3.3 | 2.0 | 1.3 (0.0) | 3.7 | 11,621 (24,292) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 57, destroyer 31, freighter 14, corvette 10, light cruiser 7, submarine 3.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | 1, 1, 1, 1 |
| Submarine | ss_vii | 26,000 | never, 83, 69, 185 |
| Freighter | fr_liberty | 22,000 | never, 83, 39, 31 |
| Fleet oiler | ao_t2 | 24,000 | never, 83, 62, 185 |
| Ammunition ship | ae_hood | 38,000 | never, 121, 80, never |
| Repair ship | ar_diver | 26,000 | never, 83, 69, 185 |
| Light cruiser | cl_agano | 36,000 | never, 117, 80, never |
| Escort carrier | cve_casa | 58,000 | never, never, 211, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, 230, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## The Disgraced Officer

Starts at Halbrook with dd_fletcher and 14,000 credits. Two hours of play fall about day 210 with the chart at 2×, day 200 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 9,774 | -282 | 108 | 0 | 0 | 0 | -0 | −2,540 | −1,357 | −437 |
| 16–30 | 8,224 | -103 | 1,506 | 0 | 0 | 0 | -0 | −2,540 | −0 | −516 |
| 31–60 | 6,801 | -51 | 735 | 4,850 | 222 | 488 | -309 | −4,790 | −865 | −1,754 |
| 61–90 | 5,667 | -38 | 821 | 1,875 | 1,751 | 0 | 24 | −4,732 | −0 | −874 |
| 91–120 | 3,938 | -125 | 631 | 0 | 1,202 | 0 | -117 | −4,471 | −0 | −863 |
| 121–180 | 0 | -71 | 177 | 0 | 4,493 | 0 | 24 | −7,689 | −0 | −943 |
| 181–240 | 0 | 0 | 1,441 | 0 | 7,168 | 0 | 701 | −7,152 | −0 | −2,158 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (2,050) | 0.5 | 0.2 | 0.2 (0.0) | 3.5 | 1,991 (2,217) | 0.0 | 0.0 |
| 16–30 | 4 | 1.0 (2,050) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 31–60 | 4 | 1.2 (2,392) | 0.5 | 0.0 | 0.5 (0.2) | 4.0 | 6,371 (11,347) | 0.2 | 0.0 |
| 61–90 | 4 | 1.2 (2,392) | 0.8 | 0.2 | 0.5 (0.0) | 5.7 | 10,961 (11,347) | 0.2 | 0.5 |
| 91–120 | 3 | 1.0 (2,050) | 0.3 | 0.3 | 0.0 (0.0) | 3.0 | 3,380 (3,380) | 0.0 | 0.0 |
| 121–180 | 3 | 1.0 (2,050) | 2.3 | 0.0 | 2.3 (0.0) | 4.1 | 6,817 (11,347) | 0.3 | 0.3 |
| 181–240 | 2 | 1.0 (2,050) | 1.5 | 1.0 | 0.5 (0.0) | 1.7 | 6,774 (6,922) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 38, destroyer 17, light cruiser 10, corvette 3, submarine 1.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | never, never, never, 69 |
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
| 1–15 | 10,948 | -603 | 115 | 0 | 3 | 2,862 | 101 | −4,035 | −2,434 | −5,664 |
| 16–30 | 7,990 | -218 | 0 | 0 | 902 | 0 | -152 | −2,870 | −101 | −737 |
| 31–60 | 5,022 | 166 | 63 | 3,100 | 1,171 | 2,467 | -0 | −3,072 | −1,258 | −579 |
| 61–90 | 8,489 | 0 | 0 | 0 | 0 | 0 | 0 | −0 | −0 | −0 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 2.2 (18,158) | 1.2 | 0.0 | 1.2 (0.8) | 3.8 | 10,877 (22,800) | 0.8 | 0.8 |
| 16–30 | 4 | 2.0 (12,065) | 1.8 | 1.5 | 0.2 (0.0) | 2.6 | 5,296 (8,530) | 0.0 | 0.8 |
| 31–60 | 3 | 3.0 (15,165) | 2.7 | 1.0 | 1.7 (1.0) | 3.2 | 7,817 (10,448) | 0.7 | 3.3 |
| 61–90 | 1 | 1.0 (11,800) | 1.0 | 0.0 | 1.0 (0.0) | 4.0 | 6,050 (6,050) | 0.0 | 1.0 |
| 91–120 | 0 | | | | | | | | |
| 121–180 | 0 | | | | | | | | |
| 181–240 | 0 | | | | | | | | |

Enemy ships met in 240 days, by class (all seeds): destroyer 27, corvette 18, motor torpedo boat 9, light cruiser 8, freighter 3, submarine 2.

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

Starts at Calder Roads with co_flower and 15,000 credits. Two hours of play fall about day 197 with the chart at 2×, day 229 at 4×.

**Money** (credits in each period; mean of the seeds)

| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 14,552 | -43 | 0 | 0 | 0 | 0 | 0 | −448 | −0 | −0 |
| 16–30 | 13,286 | -84 | 0 | 0 | 0 | 0 | -211 | −580 | −3 | −128 |
| 31–60 | 11,813 | -49 | 421 | 0 | 0 | 0 | 0 | −1,582 | −0 | −312 |
| 61–90 | 11,084 | -27 | 322 | 0 | 0 | 1,800 | -158 | −2,184 | −7 | −501 |
| 91–120 | 26,061 | 535 | 2,162 | 16,000 | 0 | 0 | -186 | −2,597 | −0 | −403 |
| 121–180 | 36,722 | 178 | 3,610 | 13,600 | 0 | 0 | 0 | −5,565 | −0 | −984 |
| 181–240 | 39,996 | 57 | 3,762 | 6,800 | 0 | 0 | -1,146 | −5,194 | −0 | −948 |

¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.


**The sea** (hostile contacts in each period)

| Days | Afloat (of 4) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1–15 | 4 | 1.0 (940) | 1.5 | 0.0 | 1.5 (0.0) | 4.2 | 7,513 (13,675) | 0.0 | 0.8 |
| 16–30 | 1 | 1.0 (940) | 4.0 | 0.0 | 4.0 (0.0) | 2.8 | 731 (2,625) | 0.0 | 0.0 |
| 31–60 | 1 | 1.0 (940) | 2.0 | 2.0 | 0.0 (0.0) | 2.0 | 2,625 (2,625) | 0.0 | 0.0 |
| 61–90 | 1 | 1.0 (940) | 2.0 | 0.0 | 2.0 (1.0) | 3.5 | 1,845 (3,665) | 1.0 | 0.0 |
| 91–120 | 1 | 1.0 (940) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 121–180 | 1 | 1.0 (940) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |
| 181–240 | 1 | 1.0 (940) | 0.0 | 0.0 | 0.0 (0.0) | – | – (–) | 0.0 | 0.0 |

Enemy ships met in 240 days, by class (all seeds): motor torpedo boat 32, destroyer 9, light cruiser 4, submarine 1, corvette 1.

**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)

| Class | Cheapest design | Price | Affordable on day |
|---|---|---:|---|
| Motor torpedo boat | pt_mas | 4,000 | 1, 1, 1, 1 |
| Corvette | co_flower | 9,000 | 1, 1, 1, 1 |
| Destroyer | dd_kclass | 17,000 | never, 99, never, never |
| Submarine | ss_vii | 26,000 | never, 99, never, never |
| Freighter | fr_liberty | 22,000 | never, 99, never, never |
| Fleet oiler | ao_t2 | 24,000 | never, 99, never, never |
| Ammunition ship | ae_hood | 38,000 | never, 130, never, never |
| Repair ship | ar_diver | 26,000 | never, 99, never, never |
| Light cruiser | cl_agano | 36,000 | never, 130, never, never |
| Escort carrier | cve_casa | 58,000 | never, never, never, never |
| Heavy cruiser | ca_zara | 62,000 | never, never, never, never |
| Battleship | bb_scharnhorst | 105,000 | never, never, never, never |
| Fleet carrier | cv_shokaku | 150,000 | never, never, never, never |

## Prices in port

Port prices (before the 6% buying and 7% selling spread) seen by all captains when they made harbour, as median (lowest–highest).

| Days | Fuel | Food | Steel | Medicine | Munitions | Electronics |
|---|---:|---:|---:|---:|---:|---:|
| 1–15 | 8 (6–14) | 15 (6–40) | 31 (13–59) | 87 (46–157) | 60 (28–122) | 104 (44–234) |
| 16–30 | 7 (6–14) | 13 (6–41) | 32 (13–57) | 85 (45–150) | 83 (27–116) | 94 (49–228) |
| 31–60 | 7 (5–14) | 15 (5–33) | 30 (13–62) | 98 (46–177) | 50 (27–120) | 115 (44–228) |
| 61–90 | 8 (6–13) | 16 (6–34) | 33 (13–59) | 82 (41–157) | 67 (29–120) | 86 (48–243) |
| 91–120 | 7 (6–13) | 14 (6–31) | 32 (17–57) | 92 (44–155) | 61 (27–119) | 90 (57–220) |
| 121–180 | 8 (5–15) | 13 (6–37) | 31 (17–63) | 107 (45–162) | 70 (26–117) | 93 (48–241) |
| 181–240 | 8 (5–14) | 16 (7–34) | 30 (17–63) | 98 (43–160) | 43 (27–113) | 110 (48–235) |

