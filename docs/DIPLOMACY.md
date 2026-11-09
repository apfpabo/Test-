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

## Second pass (9 Nov 2026)

- **Two new flags** (placeholder names, for the owner to rename or rewrite; their text is mine, not the owner's):
  - The **Ombrian Protectorate** (`ombria`): the Directorate's client regime on the Ombrian shore, the southern half of the Continental Compact. Sefira (capital), Ilmaro, Duras. Allied with the Directorate. It flies Directorate paint and buys from the Korvagrad and Strelsk yards.
  - The **Outer Isles League** (`isles`): the island states of the Oceanic Entente outside the Federation. Tamaru (capital), Corrin, Greywater. Allied with the Concord, cordial with the Federation. Federation paint; Tidewater and Combine Marine ships.
  - A new flag borrows a baked paint scheme through `paint` in its FAC entry (`GameData.paint`), so no art re-bake is needed.
- **Coalitions and alliances:** the Oceanic Entente (Concord, Federation, Outer Isles) and the Continental Compact (Directorate, Protectorate). When war breaks out, each side's allies (relations 50+) join at once; coalition members who are only cordial (20+) join half the time, or declare neutrality. Friends of both sides stay out. When the war ends, the allies' wars end with it.
- **Ports change hands:** in a war, about every 25 days one side moves on the other's nearest harbour (never a capital). The odds come from the fleets within about 900 units of the port, weighted by each navy's quality (the Concord still the strongest), against the harbour's defences and garrison (Gatehold and Strelsk hold out three times as well). A port retaken by an ally of its 1946 owner is handed back. Occupied ports stay occupied after an armistice. Your squadron counts for the flag you serve when you are near.
- **Escort contracts:** a convoy sails from the issuing port to another; it moves only while you keep station within about 45 units, and part way along raiders try it. Pay on arrival; failed if the convoy is lost or the deadline passes.
- **Smuggling contracts:** contraband (medicine, electronics, munitions) for a harbour of a power the issuer dislikes, or one closed to you. Docking at an open harbour runs it past customs automatically; at a closed harbour you get a night landing. Risk: 30% (45% at a closed harbour), plus 4% per ship beyond two, less your evasion. Caught: the cargo is seized, that flag's standing falls by 12, and at a closed harbour it is an incident. Freeports post them most.
- **Story missions from every power:** three-mission chains at the capitals of the Directorate (Naval Staff), Federation (Federation Council), Combine (Security Board), Republic (Tarsene Admiralty), Syndicate (Brokers' Table) and Enclaves (Halvard Moot), as well as the Concord Admiralty's five, in `data/stories.json`. They draw on the lore's hooks: the occupied isle, the Black Archives, Dry Dock Zero, the Quiet Race, the Austral Barrier signals. Missions against a power are deniable: the ships fly no colours. One set of orders at a time; the Missions & diplomacy tab lists where orders are waiting.

## Land structures (9 Nov 2026)

Strike contracts (silence an enemy installation from the air) on the boards of powers at war; structures change hands in wars and follow their port when it falls. See [`LAND_STRUCTURES.md`](LAND_STRUCTURES.md).

## Not yet

- The new flags have no owner-written lore; the codex shows only the owner's seven powers.
- Peace treaties beyond the armistice, and you claiming ports (step 5, found your own flag).
- Story missions from the Protectorate and the Outer Isles.
