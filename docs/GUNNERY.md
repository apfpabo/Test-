# Gunnery by salvos, and crews

From the owner's list for after the roadmap, done at his request before tuning (10 Nov 2026). Rules: `godot/scripts/battle_sim.gd` ("finding the range": `solution`, `spot`, `sol_state`, `PATTERN`, `CREW`, `crew_level`), `campaign.gd` (`crew_xp`, `crew_name`). Checked by section thirteen of `tests/review_test.tscn`.

## Finding the range

- A ship that opens fire on a target has only an estimate of the range and of how far to lay off for the target's movement. Her whole salvo shares that error: it falls together, short or over, left or right.
- The first estimate is out by up to about 8% of the range at long range, less close in, less with radar and good fire control, more with a green crew.
- Each salvo whose fall is spotted takes off about half the error (radar: nearly two thirds; at night without radar and with no flare over the target: under a quarter; through smoke or beyond sight, on the radar plot alone: under a third, and without radar almost nothing).
- A target that turns, and a firing ship that turns, put a little error back each salvo, so weaving under fire is worth something.
- A salvo is much tighter round its own centre than single shells used to scatter (45% of the old spread). Once the error is inside that pattern she is straddling and hits come regularly.
- A solution is kept for each target and is lost after 35 seconds without firing on her.
- Fire you lay by hand on a point of the sea has no target, so no solution: it scatters as it always did. Fire on a ship you have locked ranges in like any other.
- The gun-laying readout says "finding the range" or "straddling her".

## Crews

A ship's company has a quality from the actions it has fought:

| Quality | Actions fought | First estimate | Spotting | Loading | Damage control |
| --- | --- | --- | --- | --- | --- |
| Green | none | 30% worse | 15% slower to correct | 8% slower | 20% slower |
| Trained | 1 | standard | standard | standard | standard |
| Seasoned | 3 | 10% better | 8% quicker | 4% faster | 12% faster |
| Veteran | 6 | 20% better | 15% quicker | 8% faster | 25% faster |
| Crack | 10 | 28% better | 20% quicker | 12% faster | 40% faster |

- A new ship's crew is trained. A prize is manned by a scratch crew: green.
- Each action a ship comes through adds one; heavy damage in it costs up to half of what the crew had learned (casualties thin it).
- Other navies' crews follow their captain: a green captain's are green, a renowned one's veterans or crack.
- The Fleet page and the flagship panel in battle show a crew's quality.

## Not done

- Hiring replacements in port does not dilute a crew, and there is no training outside action.
- The numbers are first settings and want tuning with the rest.
