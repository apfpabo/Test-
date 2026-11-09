# Land structures

Step 4 of the owner's plan: land structures, enemy and allied, that can be attacked from the air in an auto-resolved battle (carrier operations) and captured for passive income (money, food, steel). Built so that step 5 (found your own flag, claim territory) can grow out of them. Done 9 Nov 2026.

Rules: `godot/scripts/structures.gd` (autoload `Structures`), tuning in `godot/data/structures.json`. Drawing: `godot/scripts/installation_art.gd` (map symbols, installations, countryside), `godot/scripts/air_raid.gd` (the raid view), panels in `world_map.gd` (`open_struct`). Places: `LAND_SITES` and `INSTALLATIONS` in `campaign.json`, from `tools/worldgen/build.js`. Checks: `godot --headless --path godot res://tests/structures_test.tscn`; screenshots `xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_structures.tscn -- <dir>`.

## The owner's answers (9 Nov 2026)

| Question | Answer |
| --- | --- |
| Kinds | All proposed: economic works (farms, steelworks, oil, industry), airfields, coastal batteries, radar stations and naval bases |
| Capture | Surrender once the defences are silenced and the fleet lies off the coast, built so troop transports can replace it later |
| Income | Monthly; money paid to you, food and steel to a warehouse at the nearest port |
| Retaking | Yes: the powers fight over structures in their wars, and send forces to retake yours |
| Strike view | A summary panel, a short watchable raid with a skip button, then a report |
| Chart look | Map symbols at normal zoom, drawn installations close in |

## The structures

384 in all: the 266 inland sites of the world build (95 farms, 96 mines, 54 oil works, 21 industrial works) and 118 military installations placed by `build.js`: a coastal battery by every port (two by the Directorate's fortified harbours, Gatehold and Strelsk), batteries on both shores of every strait and canal and a radar station by each, airfields by the capitals, the garrison ports, every Federation port and every other port besides, radar stations by capitals and some great-power ports, and 16 naval bases (old wartime harbours) on quiet coasts away from the ports. Hand additions: `world.json` `"installations": [{"kind": ..., "at": [lon, lat]}]`.

| Kind | Output a month | Defences | Garrison | What else it does |
| --- | --- | --- | --- | --- |
| Farms and grain depots | 60 food | light flak | 30 | |
| Mines and steelworks | 30 steel | 2 flak batteries | 50 | |
| Oil works | 2,500 | 3 flak batteries | 60 | |
| Industrial works | 4,000 and 10 steel | 4 flak batteries | 80 | |
| Airfield | | 3 flak batteries, 3 fighter squadrons | 120 | Its fighters (half strength) defend every structure of its flag and its allies within 300 km. Its search planes find you within 300 km when its flag engages you, and vector that flag's patrols onto you. |
| Coastal battery | | 2 flak batteries, 4 heavy guns | 80 | Shells your ships within 35 km when its flag engages you (a few percent of hull a hit, every third of a day). A dashed red ring shows its reach. |
| Radar station | | 2 flak batteries | 40 | Its flag's flak and fighters within 300 km fight a quarter better. Held by you: warns the moment an assault sails for a structure in its cover, and the garrison fights a quarter better. |
| Naval base | | 4 flak batteries, a fighter squadron, 2 heavy guns | 200 | Held by you: dock there to repair, rearm, refuel and replace aircraft at plain dockyard prices; it keeps the goods of your structures within 900 units. |

- **Owners:** the flag of the nearest port on the same landmass (within 700 units), or of a port just across the water; otherwise unclaimed (56: the Austral Barrier, the empty island groups). When a port changes hands, the structures that belong to it go with it.
- **Doctrine:** the Directorate's flak and guns are 30% stronger (fortified coasts), the Federation's fighters 50% (carrier aviation), the Concord's fighters 20%; the Republic, the freeports, the Enclaves and the island flags are lighter. Flak improves with the enemy's era.
- **Names:** the port, or the strait, and the kind: "Strelsk Airfield", "West Strelsk Steelworks", "the Throat Battery". Far from any port: the landmass ("Austral Barrier Oil Works").

## Striking from the air

- Needs carriers (escort carriers from the Concord, Federation and Combine yards, and second-hand as the Syndicate's improvised carriers in every freeport yard; fleet carriers at the Concord and Federation capitals with jets). Planes aboard: 6 a squadron, tracked per carrier (`air` on the ship record), also in battle.
- Reach: the fleet's strike reach (250 km from an escort carrier, 350 km from a fleet carrier), the same measure that starts carrier fights at sea.
- One strike every half day. On a flag you are not at war with it breaks the armistice (standing -30, an incident: its warships engage you on sight for three months; betrayal if it is the flag you serve), and earns thanks from its enemies. The panel warns first.
- **Settled before it is shown** (`Structures.strike`): the defending fighters (its own and half of each covering airfield's, times the radar) shoot down part of the strike while the escorts (30% of it) shoot some of them down; flak over the target takes its share; each bomber's load against how hard the target is (batteries are hardest) knocks out part of the defences (`dmg`) and wrecks part of the output (`ruin`). Jets do half as much again, and a carrier captain's ordnance skill helps.
- Two escort carriers (30 aircraft) silence a Directorate airfield in two strikes, losing about a third of their aircraft; farms go in one or two.
- **The raid view** (about 16 seconds, Skip/Space/Esc), drawn with the battle's own particle effects in the style chosen in Settings (modern or classic): the strike group in vics coming in from the sea over the countryside, the fighters rising to meet it, flak bursts, aircraft going down trailing smoke, the bombs bursting across the installation as the craters appear, and the survivors turning for home. Then the report: fighters met, losses to fighters and flak, how much of the defences are out of action.
- Replace aircraft in port (Repairs & crew) or at your naval base: 1,500 each, 3,000 once you have jets.
- Defences mend 4% a day; wrecked output 1% a day.

## Bombardment from the sea (owner request)

- Any structure within reach of the fleet's guns or missiles can be shelled without carriers: guns reach ashore at their real range (battle ranges are a fifth of real: about 12 km for small guns, 15–20 km for medium, 23 km for 8-inch, 27–33 km for heavy guns), anti-ship missiles 120 km. Coastal batteries (22 km inland or less), naval bases and coastal works are in reach; most inland works need aircraft.
- An hour's shoot from every ship with a weapon in reach: weight of fire by gun (heavy shells count more against concrete), against how hard the target is. A battleship silences a Directorate battery in about two shoots; a destroyer chips at it.
- Each ship that fires uses a sixth of her magazines. The structure's heavy guns answer, hitting your ships (small ships suffer more). Six hours between shoots. Same armistice rules as a strike. Strike contracts count it.
- Shown like a raid: ranging shots and salvos coming in from the sea, the shore's guns answering with flashes and splashes, then a report.

## Capture: surrender

- When 80% of the defences are out of action and the fleet lies off the coast nearest the structure (within its distance inland plus about 75 km), "Demand its surrender" lands a garrison from your crews. An unclaimed structure needs only the garrison.
- **Seam for troop transports:** `Structures.landing_force()` says what goes ashore (today: your crews). When auxiliaries arrive (roadmap step 3) troopships replace the crews there.
- Taking a structure costs 10 more standing with its old owner, and earns thanks from that owner's enemies.
- Held structures: garrisons draw wages (0.15 a man a day, like crews). Withdraw a garrison with the fleet off the coast (the structure is left unclaimed). If you hold a commission and took the structure from another flag, you can hand it to the flag you serve instead (6,000, or 10,000 for a military installation, and standing +8).

## Income

- On the 30th of every month: money to you; food and steel to your nearest naval base within 900 units, else the nearest port open to you within 900 units, else kept at the structure itself (load it with the fleet off its coast). Output falls with war damage.
- Ports keep your goods in a **Warehouse** tab (load into the hold or sell at the port's price). The Command panel's **Holdings** tab lists what you hold, its yield, where its goods go and what is waiting.

## The powers fight over them

- In a war, about every 33 days one side takes a structure of the other near its own ports, with odds from the strength at sea nearby (as sieges) against the structure's defences.
- **Assault forces against yours:** the flag you took a structure from sends an assault force (escorts and one or two troopships) about every two months for five months, then less often; a power at war with you may try for what you hold near its ports. At most two at a time. It sails from the attacker's nearest port for the coast nearest the structure and is hostile on sight. Your radar there warns as soon as it sails; otherwise lookouts ashore report it 400 units out. Warned assaults appear in red in the orders box (click to intercept). Sink the troopships and the landing is called off; if it lands, the garrison (with the structure's defences and radar) fights it out. Lost, the structure and its garrison are gone.
- **Strike contracts:** boards of powers at war post "Strike the X": silence 70% of an enemy installation's defences from the air (signing makes you a combatant to the target's flag).

## On the chart

- Map symbols (a dark disc ringed in the owner's colour, yours in gold, unclaimed in grey; a pale glyph for the kind): military installations from 0.3 zoom, economic sites from 0.45, yours always. Dimmed when silenced. Names when zoomed in (yours always).
- From 3× zoom: the installations drawn on the terrain (runways and hangars, gun casemates facing the sea, tank farms and derricks, spoil heaps and rolling mills, field patchwork and silos, sawtooth sheds, radar masts, piers and breakwaters), with craters and scorch from strikes and a small flag.
- Click one for its panel: a picture of it in its countryside, what it does, output, defences, fighter cover, and the actions (strike, surrender, course to the coast, withdraw, hand over, base services).

## For step 5 (your own flag)

A structure held by `"player"` already behaves like a small territory: garrison, upkeep, income, a depot, enemies who want it back, radar cover and naval bases you can dock at. Founding a flag can turn `"player"` into a faction id of its own (a `Diplomacy.POWERS` entry with relations), let naval bases grow into ports, and let structures recruit, build and defend themselves.

## Not yet

(Done since: naval bombardment, Syndicate carriers.)


- Troop transports (auxiliaries) to replace landing from the crews.
- Land-based air raids on your fleet (airfields only spot).
- Defend contracts (sink an assault force sailing against a power's structure) and structures changing hands through NPC assault fleets you can watch.
- Investing in your structures (more flak, a radar, rebuilding faster).
