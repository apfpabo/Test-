# Waiting for the owner

Decisions the agent has left for the owner, with what each choice would mean. Newest first. Strike one out (or move it
to the roadmap) once it is decided.

## ~~4. Tuning, round 1: three proposals~~ Decided 12 Nov 2026: all three, made and measured (TUNING_SHEET.md, "Tuning round 1")

The owner asked for proposals to pick from while he plays. None is made yet. Each comes with what it would change and
the agent's prediction. The figures are from [`TUNING_SHEET.md`](TUNING_SHEET.md) and from 12 further Merchant runs.

**A. The Merchant can run.** She now breaks off from torpedo boats one time in ten: the odds rest on the speed
difference, and a 15-knot freighter against 40-knot boats gets the floor of 10%. The Smuggler has a +15 evasion perk;
the Merchant has none.

- **Change:** give the Merchant `evade: 25` ("a merchant master knows when to run"). Break-off against a torpedo-boat flotilla rises to about 35%.
- **Prediction:** she was lost in 11 of 16 runs, nearly all in her first fight. Losses would fall to about 5–7 of 16.
- **Where:** `Origins.build`.

**B. A new captain's grace covers raiders too.** Bounty squadrons keep their distance for the first 30 days. Four of the
eleven Merchant losses came on days 29–38, three of them to raider flotillas.

- **Change:** raider flotillas also keep their distance from a new captain for the first 30 days (`bounty_grace` widened to raiders).
- **Prediction:** losses before day 40 fall from 4 of 16 Merchant runs to about 1. The Academy Cast-Off (lost on day 44) and the Survivor gain too.
- **Where:** `Campaign.bounty_grace`, `BOUNTY_GRACE`.

**C. The Survivor's back pay.** The Survivor starts with a destroyer at 45% hull, and repairing her eats his purse. He
had about 7,000 left on day 30 and 3,300 on day 120, and one run was lost on day 53.

- **Change:** his navy pays what it owes him: 2,000 every 30 days for 180 days, as the Disgraced Officer's pension does (2,500 for 360 days).
- **Prediction:** about 9,000 more by day 120; his purse rises instead of falling. Battles would still decide whether he survives.
- **Where:** `Origins.build` (`perks.pension`).

The agent's suggestion: all three. A and C each touch one origin; B touches every start for one month. To pick, say
which letters. The agent then runs the 32 tuning runs again and reports.

## ~~3. The Merchant's first freighter against torpedo boats~~ Decided 12 Nov 2026: change A of round 1 (she can run); she is already armed as the real ships were

Measured again with everything added since the last tuning round (no numbers changed): the Merchant, the safest start
before, is now lost in three of four runs, each time to a few motor torpedo boats (with a corvette or destroyer) that
catch her lone freighter when she tries to break off. Not caused by wear (tested). Choices: let a merchant break off
from small raiders more often, give her first freighter a light gun or two, keep raiders' torpedo boats off the trade
lanes for the first weeks, or keep it as a fair danger of the trade. **The owner (12 Nov 2026):** run more seeds first;
if it holds, the agent's proposal is to arm her as the real ships were (a gun aft, one forward, light AA). The figures: [`TUNING_SHEET.md`](TUNING_SHEET.md),
"Measured again".

## ~~1. Should the yard refuse a badly overweight fit?~~ Decided 12 Nov 2026: warn and ask

The hard limit stays where it was. A fit that leaves her over her margin or top-heavy, and worse than she is now, gets a
second step: the yard's naval architect says what it costs her (tons over, speed, helm, salvo spread) and asks "Refit
anyway?" (`world_map._refit`, `refit_warn`; pictured by `tests/shot_refit.tscn` as `refit_warn.png`).

## 2. The new shell splash, after playing with it (12 Nov 2026): the owner will play it and report

**What happens now.** The new splash is the default (a sunken bowl, a column by calibre that casts its shadow, a falling
curtain, a lacy slick; shells landing together join one splash). Settings > Shell splashes > Classic brings back the old
look unchanged; `Settings.SPLASH_DEFAULT` makes either the default; the code before the change is the local tag
`splash-classic` (commit fcae2e2).

**To decide after playing it.** Keep the new look, ask for changes (column size and height, bowl depth, how long the
slick lasts, the look at night), or go back to Classic. Nothing more will be changed until the owner has played it.

Where it lives: `BattleSim.fx_splash_new`, `battle._columns`, `_laces`, `_sinks`, `shaders/sink.gdshader`; see the
"new splash" note in `CLAUDE.md`.

## 5. The sound gaps (12 Nov 2026). Chosen: C2 coins, R4 the press, S1 the typewriter, W4 the horn (in the game); jamming none; jets: the Saab Draken's pass and diving: a sound of his own, both sent by him (13 Nov 2026) and in the game

Seven things are silent: jet aircraft, a boat diving or surfacing, trade, a refit done, saving, a ship joining, and
jamming. Candidates, levelled to one loudness, are on the listening page "Iron Meridian Sound Gaps"
(https://claude.ai/artifact/PZL2UfbDwiHdz4hAXYCh3T) and in `tools/sound_candidates.json` ("gaps_12_nov"). None is in
the game until the owner has chosen.

## 6. More Era III and Era IV designs, by shipyard (13 Nov 2026). Decided and built: the whole table, frigates a class of their own

Only Tidewater and Korvagrad build past Era II (Calder has one Era IV corvette). Proposed, each after a real design, in the
classes the game has (a frigate goes in as a missile destroyer or corvette, a light carrier as a carrier):

| Yard | Era III | Era IV |
|---|---|---|
| Calder & Wexmouth (British) | Type 42 destroyer; Invincible light carrier; Trafalgar attack submarine | Type 45 destroyer; Queen Elizabeth carrier (two islands); Astute attack submarine |
| Strelsk-Werke (German) | Bremen frigate; Type 206 coastal submarine; Gepard missile boat | Sachsen air-defence frigate; Type 212 submarine (the quietest boat in the game); Braunschweig corvette |
| Korvagrad (Soviet) | Kuznetsov carrier (the Directorate has none past Era II) | Yasen attack submarine; Karakurt missile corvette; Steregushchiy corvette |
| Amakura (Japanese) | Kongo destroyer; Hatsuyuki destroyer; Harushio submarine | Mogami stealth frigate; Izumo light carrier; Soryu submarine |
| Cantieri del Corvo (Italian) | Garibaldi light carrier; Maestrale frigate; Sparviero hydrofoil missile boat | Andrea Doria destroyer; Thaon di Revel patrol ship; Cavour carrier |
| Combine Marine (merchant) | container ship; replenishment ship (oil and ammunition in one hull) | landing platform dock; offshore patrol vessel |
| Tidewater (American) | Oliver Hazard Perry frigate (a cheap escort); Tarawa assault ship | Independence trimaran; San Antonio landing ship; a rail-gun cruiser (a paper design: the second hull with the power) |

Suggested first batch, one or two a yard so every flag has something past Era II: Type 42 and Type 45 (Calder), Bremen and
Type 212 (Strelsk), Kuznetsov and Yasen (Korvagrad), Kongo and Mogami (Amakura), Maestrale and Andrea Doria (Corvo), the
container ship (Combine Marine), Perry and Independence (Tidewater). **To decide:** which of these, and whether the
frigates should be a class of their own.

## 7. Prices of the new designs (13 Nov 2026). Moved twice by measurement; his to judge

`tests/duel_measure.tscn` fights each new warship against an established design of her era at about equal money, four
times, and reports what each side has left. Two passes moved these prices (hull only, before guns):

| Design | First guess | Now | Why |
|---|---|---|---|
| Wraith (Zumwalt) | 260,000 | 215,000 | two lost to three Guardians at equal money; one beats one |
| Umbra (Sea Shadow) | 95,000 | 45,000 | no guns: she loses any duel; she is a stealth missile boat, not a fighter |
| Trident (Independence) | 120,000 | 60,000 | lightly armed for her size, as the real ship |
| Kasumi (Mogami) | 130,000 | 90,000 | lost at equal money |
| Ammiraglio (Thaon di Revel) | 165,000 | 88,000 | lost heavily |
| Thunderhead (rail-gun cruiser) | 420,000 | 240,000 | lost to two Bastions; the rail gun itself went from 45 damage every 12 s to 55 every 9 s |
| Luchs, Falchetto (missile boats) | 45,000, 30,000 | 33,000, 18,000 | now even against destroyers at equal money |
| Wayfarer (patrol vessel) | 40,000 | 12,000 | anti-aircraft guns only |
| Steadfast, Borough, Hansa, Skorpion | 70,000, 95,000, 80,000, 85,000 | 100,000, 125,000, 110,000, 115,000 | each beat her peer at equal money |

**The Directorate's big ships, after the 130 mm automatic gun and the heavy missile (13 Nov 2026).** Fought at equal
money against their American peers, all three won heavily (they kept 91–94% of their worth), so their hulls were
re-priced until the fights were even: Bastion-type destroyer (Sovremenny) 135,000 to 210,000; Slava 185,000 to 225,000;
Kirov 320,000 to 500,000. After: Sovremenny 40% left against the Burkes' 43%; Slava 24% against 16%; Kirov 38% against
11% (still a shade cheap). The Kuznetsov and the two submarines that carry the heavy missile were not measured (a
carrier's and a boat's worth do not show in a gun-and-missile duel).

**Re-measured 13 Nov 2026 with three times the sample** (`DUEL_RUNS=12 godot --headless --path godot
res://tests/duel_measure.tscn`; nothing changed). Share of each side's money left afloat, the new design first:

| Verdict | Designs (her share left against her peer's) |
|---|---|
| Fair (within 30 points) | Kirov 64/40, Slava 40/22, Sovremenny 37/37, Braunschweig 36/50, Karakurt 45/36, Sparviero 19/30, Steregushchiy 3/17, Visby 15/44, Doria 91/100, Hatsuyuki 70/50, Maestrale 28/56, Sachsen 93/97, Kongo 100/100, Type 45 98/100 |
| Dear for what she is | Thunderhead 8/59, Gepard 11/49, Wayfarer (OPV) 5/100, Umbra (Sea Shadow) 0/37, Gorshkov 0/95, Trident (Independence) 0/83, Kasumi (Mogami) 2/71, Ammiraglio (Thaon) 0/94 |
| Cheap for what she is | Type 42 96/5, Wraith (Zumwalt) 71/6, Bremen 97/28, Perry 87/50 |

Two notes. The Gorshkov is still priced against the old Sovremenny: since the Sovremenny was raised to 210,000 and given
the 130 mm automatic and the heavy missile, three Gorshkovs lose outright to two of her. Where both sides keep nearly
everything (Kongo, Type 45, Sachsen, Doria against the Burke) the missiles were all shot down and the fight never came
to a decision, so those pairs say little about price. The Wayfarer and the Umbra carry no guns that fight ships, as
noted above.

Four fights a pair is a small sample, and submarines cannot be priced this way (a boat that meets destroyers in the open
loses). **To decide:** whether these stand, and whether any of the losers should be given more to fight with instead of
being made cheaper.

## ~~8. A lone ship and the raiders~~ Decided 13 Nov 2026 (his "Realism + Hunter Fix" preset): (b) and (d), and more

Built: torpedo-boat packs tethered within 60 units of a den or harbour (b); torpedo boats count double in strength (d);
the least chance of breaking off 22% (was 10%); hunters at 1.15 times your strength rising to 1.45, none before day 45
(was 1.5 and day 40); torpedoes reach 2,000 / 4,200 / 2,600 m (were 4,500 / 9,000 / 5,000), inside a 5-inch gun's
range; CIWS 900 m inside the Bofors' 1,250 m. Not yet measured by test campaigns. Still open from his realism table:
national 5-inch mounts (`g127_jp`, `g133_uk`) and the Typhoon's loadout, which his prompt did not ask for.

**Measured after the preset (32 campaigns, 13 Nov 2026):** 11 lost, against 16 in the round before (and 11 and 15 in
the two before that, so the count alone is within chance). What moved clearly is when: the earliest loss was day 62
(before: day 23), and seven of the eleven came after day 150 (before: one of sixteen). Raiders ended 4 (before: 8),
hunters 4 (before: 2), patrols 3. The Survivor and the Disgraced Officer lost none (before: 2 each); the Defector lost
all four, to hunters and patrols, though on days 72 to 234 rather than 23 to 76; the Hijacker three of four.
Break-off succeeded in about half of the attempts in both rounds. **Open:** the Defector's and the Hijacker's hunters.

**Measured 13 Nov 2026 (64 campaigns, details in [`TUNING_SHEET.md`](TUNING_SHEET.md), last section):** weaker or fewer
hunters barely change the losses (8 of 8 for each origin as the game is; 6 to 8 of 8 with hunters at three-quarters
strength, one group at a time, or both). The causes lie elsewhere: the Defector's prizes leave his squadron short of
crew (as low as a tenth of what it needs), and the Hijacker's two torpedo boats count double, so his panel calls a
hunter group of corvettes the weaker side and he fights and loses. Half the losses are to patrols, before any hunter
sails. **To decide:** (1) torpedo boats count double only in a pack that attacks, not when they are the hunted;
(2) refuse or warn against a prize crew there are not the men for, or have the Defector's patrons find him crew;
(3) leave the hunters as they are.

What was found, for the record:

Thirty-two unattended campaigns of 240 days (eight origins, four seeds, the honest-money captain) were played three
times as the routes and the test captain were mended. Campaigns lost: 11, 15 and 16 of 32. The differences between
rounds are within chance; what is steady is this:

- **Raiders end half of the lost campaigns** (8 of 16 in the last round; bounty squadrons 3, patrols 3, hunters 2).
  Raiders are not sized to the captain. A lone ship that meets a pack with torpedo boats cannot break off (the odds of
  getting away follow speed, and the boats are faster: one chance in ten), and then loses even at a reckoned strength
  near her own: a 2,050 t destroyer was sunk three times by three motor torpedo boats.
- The Hijacker (one 50 t boat) was lost in three campaigns of four; the Smuggler, who trades and avoids, in none.
- The Defector's losses in the last round were squadrons of raised wrecks (a fifth of their hull, with defects) sent
  into action by the test captain: his fault, not the game's.
- Money is not the trouble: captains who lived made 20,000 to 95,000 in the eight months.

**To decide:** nothing was changed. Choices, from least to most: (a) leave it (a lone small ship is prey, and the
answer is company); (b) keep packs made only of torpedo boats within reach of a harbour or den (boats of 50 t far out
at sea are not grounded anyway); (c) size raiders to the captain for his first months, as bounty squadrons are;
(d) count torpedo boats for more in the strength shown on the contact panel, so "an even fight" is honest.
The agent's recommendation: (b) and (d).

## Older lists still open

- The realism review of 11 Nov 2026 (gun and torpedo ranges, a few designs' armament): [`ROADMAP.md`](ROADMAP.md),
  "Realism review".
- ~~Torpedo and CIWS ranges~~ (set by the owner, 13 Nov 2026). Every number marked "untuned" in the docs is still open.
- The tuning sheet's open questions: [`TUNING_SHEET.md`](TUNING_SHEET.md).
