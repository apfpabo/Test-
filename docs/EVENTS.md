# Random events

Everything in the game that happens by chance, and what it changes. The diplomatic events are in `godot/data/diplomacy.json` (`events`): add a line there to add one. Listed for the owner on request, 10 Nov 2026.

## News events between the powers

One about every twelve days, picked by weight; none repeats within six weeks. Each moves the relations of the powers named (the numbers), which is how wars and armistices come about. They appear as news.

| Event | Weight | Relations moved |
| --- | --- | --- |
| Hardliners carry the vote on the Concord's Admiralty Board. Patrols off the Strelsk Sounds are doubled. | 3 | Concord and Directorate -9 |
| Concord moderates win the argument in Calder Roads: another round of mutual ruin is not worth the Gate. Patrols are told to keep their distance. | 3 | Concord and Directorate +7 |
| The Concord demands "responsible control" of the Tarsene Gate. Tarsa refuses, and says so from the shore batteries. | 2 | Concord and Free Republic -8; Directorate and Free Republic -4 |
| The Tarsene Free Republic, desperate for friends, opens its harbours to Syndicate traders and Federation merchantmen. | 2 | Free Republic and Freeports +6; Free Republic and Federation +4 |
| A Combine tanker convoy is seen bunkering Directorate submarines in the Monsoon Ocean. Kotaraya calls it ordinary commerce. | 2 | Combine and Concord -6; Combine and Directorate +5 |
| The Meridian Combine sells the Concord a squadron of new escorts, cash on delivery. | 2 | Combine and Concord +6; Combine and Directorate -4 |
| Directorate submarines are sighted beyond the Throat, heading for the Monsoon trade. The Entente calls it a breach of the armistice. | 3 | Concord and Directorate -7; Federation and Directorate -5 |
| Amakura signs a fishing and trade convention with Strelsk. The Federation prefers balance to alliances. | 2 | Federation and Directorate +8; Concord and Federation -5 |
| Concord and Federation carriers exercise together off the Arcs. Strelsk protests. | 2 | Concord and Federation +6; Federation and Directorate -5 |
| The Concord boards Syndicate blockade-runners off Port Saffron. The freeports promise long memories. | 2 | Concord and Freeports -8 |
| Halvard mediators convene talks aboard an icebreaker in the Skarn Passages, where the armistice was signed. | 2 | Concord and Directorate +6; Enclaves and Concord +3; Enclaves and Directorate +3 |
| A Directorate garrison on a "temporarily" occupied island in the Halcyon reefs refuses to withdraw. | 2 | Federation and Directorate -7 |
| A Directorate scientist defects to the Concord, with papers on guided weapons. Every intelligence service on the map takes notice. | 2 | Concord and Directorate -5; Combine and Concord -3 |
| Raiders sheltering in the freeports strike Combine shipping in the Saffron Sea. Kotaraya blames Port Saffron. | 2 | Freeports and Combine -6; Freeports and Federation -4 |
| Strikes in the Ombrian ports. The junta in Sefira asks Strelsk for more advisers; some officers ask Calder Roads for something else. | 2 | Protectorate and Directorate -6; Protectorate and Concord +4 |
| The Protectorate's gunboats stop a Tarsene merchantman in the Cradle Sea and send her home without her cargo. | 2 | Protectorate and Concord -6; Protectorate and Free Republic -4 |
| Raiders strike the reef villages of the Outer Isles. The League asks the Concord for escorts and the freeports for the raiders' names. | 2 | Outer Isles and Freeports -6; Outer Isles and Concord +3 |
| The Outer Isles League and the Halcyon Federation sign a coaling agreement. Amakura still hopes they will join the Federation one day. | 2 | Outer Isles and Federation +5 |

## Chance events in a campaign

| Event | When | What happens |
| --- | --- | --- |
| War or armistice | Daily check of each pair's relations | War at -82 or below; an armistice once relations climb back above -60. Allies join at once, cordial coalition members half the time. |
| A harbour changes hands | About 4% a day for each war | One side moves on the other's nearest harbour (never a capital); the odds come from the fleets nearby. |
| A structure changes hands | In a war, about every 33 days | One side takes a structure of the other near its own ports. |
| Patrols trade fire | When hostile patrols meet under the armistice, 5% | An incident: one side loses ships and the pair's relations fall by 4. |
| Fleets fight | When fleets of warring powers meet, or patrols and convoys meet raiders | Settled without you; the stronger side usually wins. You hear of those within about 3,300 km. |
| Bounty posted | 8% a day while fewer than two are out | A named raider captain with a reward on her head. |
| Hunter group | By your origin, while you are hunted | A force sent after you casts about where you were last reported. |
| A hulk afloat | 22% on surveying a wreck or abandoned base | A damaged ship joins you at 22% condition (if you have fewer than ten). |
| Ambush at a site | 18% at a wreck or base, 35% at a black site | Raiders, or a Directorate guard force, appear beside you. |
| Raiders try the convoy | Once, part way along an escort contract | A raider flotilla closes the convoy you are escorting. |
| Customs catch you | 30% running contraband (45% at a closed harbour), more with more ships, less with an evasion perk | Cargo seized, standing -12, and an incident at a closed harbour. |
| Search planes find you | An enemy airfield within reach, every three days | Its flag's patrols within about 3,900 km are vectored onto you. |
| A battery straddles you | Within 35 km of a hostile battery, every third of a day | A ship of yours is hit for a few percent of hull, or the shells fall short. |
| Assault on your structure | 1.6% a day for five months after you took it, then 0.6%; 0.4% from any power at war with you nearby | An assault force with troopships sails for it. None under a treaty. |
| Relief force for your port | 3.5% a day from 25 days after you took it, 1.2% after 160; 0.6% from any power at war with you nearby | Escorts and two or three troopships sail to retake it. None under a treaty. |
| An officer offers his sword | Mid-month with ports of your own, up to 60% | An officer of level 2 to 4 joins you. |
| A ship comes over | Mid-month with ports of your own, up to 45% | A ship lies in one of your ports until you commission her for a bounty or send her away. |
| Your convoy sails | 12% a day for each port of yours without one at sea | Merchants under your flag make for the nearest harbour that will have them; paid on arrival. |
| The powers take alarm | Monthly, once your flag is larger than two small ports' worth | Standing falls with every power not bound by treaty. |
| Storm, fog, night | From the place and the calendar, not from dice | See `WEATHER.md`. |
| A power reaches a new era | When its research points pass 400 and 800 | Its yards field newer ships; intelligence reports it. |
| Retaliation in kind | 20 to 70 days after you use the bomb, if the victim or an ally is of the missile age with a working nuclear plant | It destroys the most valuable thing you hold. |

## In battle

| Event | Chance | What happens |
| --- | --- | --- |
| A hit starts a fire | By the weight of the hit; twice as likely from HE, four times from incendiary | The ship burns until her crew put it out. |
| A mount is knocked out | 10% for each weight of hit landing on it | It fires no more this battle. |
| Magazine, machinery, steering, fire control or crew spaces hit | By where a penetrating hit lands | Fire or flooding in a magazine (it can explode), power lost or engines stopped, a jammed rudder, wider salvoes, slower work. |
| A beaten ship turns to flee | 30% on each hit below a quarter of her hull | She tries to open the range and escape. |
| Ricochet, no penetration, over-penetration | By the shell, the range and the angle of the armour it meets | See the roadmap's note on shell ballistics. |
