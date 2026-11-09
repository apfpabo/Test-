# Diplomacy

Step 3 of the owner's plan (after the world map and the foundational lore). Rules in `godot/scripts/diplomacy.gd` (autoload `Diplomacy`), tables in `godot/data/diplomacy.json`, written from the owner's lore ([`lore/foundational_lore.md`](lore/foundational_lore.md)). Checked by `godot --headless --path godot res://tests/diplomacy_test.tscn` (a simulated year, every contract, a commission and a betrayal, a forced war, save/load); screenshots by `res://tests/shot_diplomacy.tscn`.

## Between the powers

- **Relations** between each pair of the seven powers, from -100 to 100, start where the lore leaves them in March 1946: the Concord and the Directorate at -60 (an armistice, barely), the Directorate hostile to the Federation and the Republic, the Concord cordial with the Federation, the Republic and the freeports friendly, the Combine on good terms with everyone, the Enclaves neutral and respected.
- **They drift** a little each day back toward those values.
- **Events** move them, about every twelve days, picked from the lore: Concord hardliners and moderates, the Concord's demands on the Tarsene Gate, the Combine selling to both sides, Directorate breakouts past the Throat, Halcyon balance-of-power deals, Halvard mediation in the Skarn Passages, the Quiet Race, freeport raids. No event repeats within six weeks. They appear as news (toasts and the Missions & diplomacy tab).
- **Bands:** war at -82 or below; an armistice returns above -60; hostile below -30; cool below -5; cordial from 20; allied from 50.
- **War** breaks out when a pair crosses the war line. Their fleets fight wherever they meet, munitions and fuel cost 25% more in their ports, and their boards post war contracts. A war wears both sides down: the longer it lasts, the more relations drift toward a new armistice. In a test year, the Concord and the Directorate went to war once, around month six, for about six weeks.
- **At sea:** fleets of powers at war fight on contact; patrols and convoys fight raiders; under the armistice, hostile patrols that meet sometimes trade fire (an incident: the pair's relations fall). Actions are settled without you (the stronger side usually wins). You hear of those within about 600 units, and of all incidents.

## You and the powers

- **Standing** with each flag (as before): ports close below -10; a flag's warships engage you on sight at -60, for 90 days after you open fire on its ships (an incident), or when your origin makes you its target.
- **Thanks:** sinking ships of a power earns standing with that power's enemies (hostile or at war, now from live relations, not a fixed list); with the flag you serve, twice over.
- **Contracts** on every open port's board (three offers, renewed every twelve days; up to three active):
  - *Delivery*: the goods are loaded when you sign; dock at the destination with them before the deadline.
  - *Raider hunt*: a flotilla, sized to the pay, waits in the issuer's waters; sink it.
  - *Survey*: survey the named site; the report goes by wireless.
  - *War patrol* (only while the issuer is at war): sink or take three of the enemy's ships. Signing makes you a combatant to that enemy until the deadline.
  - Pay and standing on completion; failing or abandoning costs 8 standing. Targets are marked in gold on the chart.
- **Commissions** at a power's capital, from standing 20, one at a time:
  - Concord reserve commission (4,000 a month), Directorate auxiliary warrant (3,500), Federation scouting charter (3,000), Combine security contract (5,000), Tarsene letter of marque against the Directorate (2,000), Syndicate letter of marque against the Concord (1,500).
  - Your flag's wars become yours; a letter of marque makes you a combatant to its target. Double standing for sinking your flag's enemies.
  - Resign for -10 standing. Withdrawn if your standing with the flag falls below zero.
  - **Betrayal:** opening fire on the flag you serve tears up the commission, costs 40 standing, and that flag never offers service again.
  - The privateer origin starts with the Tarsene letter of marque.

## Not yet

- Factions beyond the seven powers (the Ombrian clients and island states of the lore have ports but no flags of their own).
- Escort contracts, smuggling into closed ports, intelligence trading.
- Peace treaties beyond the armistice, alliances that bring third parties into a war, territorial change (ports changing hands): that comes with land structures and claiming territory (step 4).
- The story missions still come only from the Concord Admiralty.
