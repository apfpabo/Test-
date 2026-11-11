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

