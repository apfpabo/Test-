# Your own flag

Step 5 of the owner's plan: found your own flag and claim ports and territory. This is the first part. Rules are in `godot/scripts/flag.gd` (autoload `Flag`), the screens in `world_map.gd`, the check in `tests/flag_test.tscn`, screenshots from `tests/shot_flag.tscn`.

## What is in

| | |
| --- | --- |
| Founding | Command, Holdings. Needs a naval base you hold, or any three structures, and 30,000. You name the flag. It ends any commission. The top bar shows the flag instead of "Independent". |
| Storming a port | Needs a flag, troops embarked and the fleet off the harbour. A closed harbour offers it as you close it; an open one under Repairs & crew. The panel shows the defenders and the odds first. |
| Defenders | 400 men times the port's garrison weight (doubled at a capital), plus 220 for every battery or naval base of the port that still stands. Silence those first and their crews stay out of it. |
| Consequences | War with the owner: standing -40, an incident, their ships engage on sight. Powers at war with the owner think a little better of you, the others a little worse. |
| A port of yours | Market, yard (the old owner's designs and anything you have captured and measured, 15% cheaper), refit, repairs, officers, and a Governor tab. No contract board. Every structure of the port comes with it. |
| Garrison and dues | A port wants 250 men times its weight. Dues are 3,500 a month times its weight, paid on the 30th, less if the garrison is under strength. Garrisons draw wages like the men in your structures. |
| Relief forces | The old owner sends escorts and two or three troopships, the first after about a month, then now and again. They show in the orders box. Sink the transports, or the landing is fought against your garrison and the port's batteries. |
| Giving it up | The Governor tab hands the port back to the flag you took it from. |

## How it is stored

- `G.flag = {name, short, day}`. `Flag.apply()` puts a `"player"` entry into `GameData.fac` on a new game, a load and on founding, so a port with `fac == "player"` reads like any power's.
- A port of yours: `fac = "player"`, `from` (the old owner), `men`, `took`.
- A relief force is a fleet of kind `assault` with `portAssault = <port id>` and `tgt`; `Campaign.update` lands it through `Flag.relief_lands`.
- Loops over `GameData.fac` that mean "the powers" skip `"player"` (`maintain_fleets`, the standing list).

## Not yet

- Your flag as a power in diplomacy: relations, treaties, recognition, the powers reacting to how large you grow.
- Patrols and convoys of your own from your ports, and a contract board you post work on.
- Officers and ships drawn to a rising flag.
- Building in a port: batteries, a bigger yard, a garrison that recruits by itself.
- The powers taking your ports in their own sieges (today only the old owner comes back for it).
