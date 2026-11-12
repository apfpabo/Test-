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

## 5. The sound gaps (12 Nov 2026)

Seven things are silent: jet aircraft, a boat diving or surfacing, trade, a refit done, saving, a ship joining, and
jamming. Candidates, levelled to one loudness, are on the listening page "Iron Meridian Sound Gaps"
(https://claude.ai/artifact/PZL2UfbDwiHdz4hAXYCh3T) and in `tools/sound_candidates.json` ("gaps_12_nov"). None is in
the game until the owner has chosen.

## Older lists still open

- The realism review of 11 Nov 2026 (gun and torpedo ranges, a few designs' armament): [`ROADMAP.md`](ROADMAP.md),
  "Realism review".
- Torpedo and CIWS ranges, held for the owner's tuning pass; every number marked "untuned" in the docs.
- The tuning sheet's open questions: [`TUNING_SHEET.md`](TUNING_SHEET.md).
