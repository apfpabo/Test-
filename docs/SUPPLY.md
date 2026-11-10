# Supply: how big a fleet you can keep at sea

Step 2 of the owner's order of work, second half (10 Nov 2026): the cap of ten ships is gone; the fleet is limited by what can supply it. Rules: `godot/scripts/campaign.gd` ("supply": `supply_weight`, `supply_need`, `supply_parts`, `supply_cap`, `supply_over`, `supply_upkeep`, `rdy_cap`, `can_add_ship`, `supply_text`). Shown as SUPPLY in the chart's top bar (hover for the breakdown) and at the head of the Fleet page. Checked by section eight of `tests/review_test.tscn`.

## What a ship weighs

| Weight | Ships |
| --- | --- |
| 1 | torpedo boats, corvettes, freighters, oilers, ammunition ships, repair ships |
| 2 | destroyers, submarines, troopships |
| 3 | light cruisers, missile destroyers, nuclear submarines |
| 4 | heavy cruisers, escort carriers |
| 5 | missile cruisers |
| 6 | battleships |
| 7 | fleet carriers |

Every ship you own counts, a detached division included.

## What the supply train can carry

| Source | Points |
| --- | --- |
| Your flagship's staff and stores | 16 |
| Each oiler in company | +5 |
| Each ammunition ship | +4 |
| Each repair ship | +4 |
| Each freighter | +2 |
| A commission or letter of marque from a navy | +8 |
| Each port under your flag | +5 |
| Each working naval base you hold | +6 |

The limit is never more than 60.

## Over the limit

- Tenders are hired at 120 a day for each point over.
- Readiness cannot be kept at 100%: the best a fleet can hold falls in step with how far over it is, to 50% at half as much again. Crews fresher than that waste away by 2% a day.
- At half as much again over the limit, no yard, prize court or wreck gives you another ship; you are told why.

## Hard limits that remain

- Twenty ships in all: one flag officer cannot handle more.
- Ten ships fight in one action (the battle screen and its lists are laid out for ten a side). They are the first ten in the Fleet page's order that are not in reserve; the rest stand off as the reserve does.

## Not done

- Enemy fleets are not bound by supply (they are at most six ships).
- Battles laid out for more than ten ships a side.
