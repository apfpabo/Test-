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
| Giving it up | The Governor tab hands the port back to the flag you took it from (a port ceded to you by treaty goes back to its 1946 owner). Its guard squadron is paid off, as it is when the port is lost. The militia of the structures that came with a stormed port stays ashore: it cannot be embarked as crew. |

## How it is stored

- `G.flag = {name, short, day}`. `Flag.apply()` puts a `"player"` entry into `GameData.fac` on a new game, a load and on founding, so a port with `fac == "player"` reads like any power's.
- A port of yours: `fac = "player"`, `from` (the old owner), `men`, `took`.
- A relief force is a fleet of kind `assault` with `portAssault = <port id>` and `tgt`; `Campaign.update` lands it through `Flag.relief_lands`.
- Loops over `GameData.fac` that mean "the powers" skip `"player"` (`maintain_fleets`, the standing list).

## Second part (done)

| | |
| --- | --- |
| The Chancery | Command, Holdings. Every power takes one of four stances toward your flag: at war, unrecognised, recognised, or bound by treaty. Your standing with each is the standing you always had. |
| Recognition | Standing 10, a port, no port of theirs in your hands, 20,000. Their merchants use your harbours (dues up a tenth for each recognising power, to five) and your convoys are paid half as much again in their ports. Withdrawn if they go to war with you. |
| Treaty of non-aggression | Recognition, standing 25, 40,000. A year: your growth does not alarm that power and it sends nothing against your ports. Broken by war (standing -20). |
| Peace | From a power at war with you: 30,000, plus 40,000 for each port of theirs you keep. They cede those ports (no more relief forces), recall any force at sea, and the armistice holds again. A power your origin made your enemy will not treat. |
| Alarm | Past two small ports' worth, every power not bound by treaty loses standing with you each month (up to 4). Enough of it closes their ports. |
| Other powers' attacks | Any power at war with you with a harbour within reach may send a force against a port of yours, not only its old owner. |
| Works | Governor tab. Harbour battery (up to three), barracks (the garrison recruits 15 a week), customs house (dues up three tenths), building slip (the yard lays down battleships and fleet carriers). Each costs money and takes 20 to 45 days. |
| Guard squadron | Governor tab. Warships of your own, built in the port's yard, cruising off it; 60 a day. It meets a relief force before it lands (stronger, it sinks half the transports; weaker, it loses a ship) and fights raiders and enemies that come near. |
| Convoys | Each port sends merchants to the nearest harbour that will have them and is paid on arrival. Raiders and enemies can sink them; you can meet and trade with them like any convoy. |
| Men and ships drawn to you | Mid-month an officer may offer his sword, and now and then a ship comes over with her crew and lies in one of your ports until you commission her for a bounty (Governor tab) or send her away. |

Fleets of your flag have `fac == "player"`, `guardOf` or `convoyOf` (the port's id). `Diplomacy.clash_tick` makes them fight the powers you are at war with and pass the rest. `G.flag.recog`, `G.flag.treaty` (the day it ends), `G.flag.trade`; a port's `works` (days each is ready) and `volunteers`.

## Not yet

- A contract board you post work on, and bounties of your own on raiders.
- Alliances and wars declared between your flag and the powers as a tenth power in their coalitions.
- A capital of your own, a flag device on the chart and in the paint of your ships.
- Garrisons and works for the structures you hold (today only ports have works).
