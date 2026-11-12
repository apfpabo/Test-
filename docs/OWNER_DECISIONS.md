# Waiting for the owner

Decisions the agent has left for the owner, with what each choice would mean. Newest first. Strike one out (or move it
to the roadmap) once it is decided.

## 1. Should the yard refuse a badly overweight fit? (12 Nov 2026)

**What happens now.** A hull has a margin of 1.2% of her displacement for extra weight; past it she is slower, turns
worse and rolls more. The yard refuses a fit only when it is more than a further 3% of her displacement over that
margin, or her topweight passes 130% (`BattleSim.loading`, `ok`). For the Iowa (45,000 t) that is a 540 t margin and
then 1,350 t more. In the refit reel, a 20-inch twin was tried in the
Iowa's aft turret: 1,251 t over her margin, 6% slower, 4% slower on the helm, salvos spread 39% wider in a calm sea,
and the yard still passed it.

**The choices.**
- **Keep it as it is.** The player may make bad ships; the ledger shows the price plainly. (Rule the Waves lets you build
  an unbalanced design and lets the sea punish it.)
- **Refuse sooner.** Lower the limit, for example to 1.5% over the margin instead of 3%, so a fit like the 20-inch aft is
  refused with the reason shown. Safer, but less freedom.
- **Warn and ask.** Let it through, but only after a "This fit is far over her margin: confirm anyway?" step.

Where it lives: `BattleSim.loading` (`limit`, `ok`), `world_map._refit` (the Confirm button and the refusal line),
[`REFIT.md`](REFIT.md).

## 2. The new shell splash, after playing with it (12 Nov 2026)

**What happens now.** The new splash is the default (a sunken bowl, a column by calibre that casts its shadow, a falling
curtain, a lacy slick; shells landing together join one splash). Settings > Shell splashes > Classic brings back the old
look unchanged; `Settings.SPLASH_DEFAULT` makes either the default; the code before the change is the local tag
`splash-classic` (commit fcae2e2).

**To decide after playing it.** Keep the new look, ask for changes (column size and height, bowl depth, how long the
slick lasts, the look at night), or go back to Classic. Nothing more will be changed until the owner has played it.

Where it lives: `BattleSim.fx_splash_new`, `battle._columns`, `_laces`, `_sinks`, `shaders/sink.gdshader`; see the
"new splash" note in `CLAUDE.md`.

## Older lists still open

- The realism review of 11 Nov 2026 (gun and torpedo ranges, a few designs' armament): [`ROADMAP.md`](ROADMAP.md),
  "Realism review".
- Torpedo and CIWS ranges, held for the owner's tuning pass; every number marked "untuned" in the docs.
- The tuning sheet's open questions: [`TUNING_SHEET.md`](TUNING_SHEET.md).
