# Lore

Material written by the project owner for the world of Iron Meridian, kept word for word. Part of it is in the game today; the rest is for when the world is more lived in. Read it alongside [`CREATIVE_DIRECTION.md`](CREATIVE_DIRECTION.md). The in-game copy of the origins (shown on the title screen) is `godot/data/lore.json` and must match this text.

## Starting origins

The owner's text, verbatim:

### 1. The Disgraced Officer (Faction Captain)

You were a commissioned officer in one of the major navies. After a disastrous engagement (or a political purge), you were stripped of rank, given a worn-out destroyer or light cruiser as a “pension,” and quietly pushed out.

**World reaction:** Your former navy treats you with cold professionalism or quiet hostility. Rival powers see a potentially useful defector. Ports of your old flag may still offer limited services, but trust is low.

**Feel:** You start with decent skills, a proper warship, and some contacts, but also a stain on your name and people who would prefer you disappeared.

### 2. The Hijacker (Lone Terrorist / Pirate)

You and a small crew seized a freighter or light warship in a bloody action. You are now a wanted man with a price on your head.

**World reaction:** Most legitimate ports will fire on you or refuse entry. Pirate havens and freeports are your only real safe harbors at first. Bounty hunters and naval patrols actively hunt you.

**Feel:** High-risk, high-freedom start. You begin with a ship and almost no friends, forced to live by raiding, smuggling, and carefully choosing when to show a flag.

### 3. The Merchant Captain

You own (or co-own) a modest freighter or armed merchantman. The unfinished war and shifting trade routes have left you scrambling for profitable, dangerous contracts.

**World reaction:** Generally tolerated or ignored by the great powers. Traders and freeports are friendly. Navies may conscript or “request” your services. Pirates see easy prey.

**Feel:** Classic trader start. Weaker combat power at the beginning, but better economic options and more neutral standing.

### 4. The Survivor of the Lost Fleet

You were part of a major task force that was annihilated in a decisive (and possibly covered-up) battle. You escaped in a damaged ship with a handful of survivors and whatever you could scavenge.

**World reaction:** Depends on which side the lost fleet belonged to. Your old navy may view you as a living embarrassment or a useful witness. The winning side may want you silenced. Independent captains and salvage crews treat you with a mix of respect and pity.

**Feel:** Strong narrative hook, good starting combat skills, limited resources, and a personal mystery/revenge thread.

### 5. The Privateer

You hold (or claim to hold) a letter of marque from a secondary power or breakaway state. You are legally a pirate to some and a legitimate combatant to others.

**World reaction:** Your sponsoring power is friendly and may offer contracts and safe harbor. Their enemies treat you as a hostile combatant. Neutrals are wary.

**Feel:** A middle ground between lawful officer and outlaw. You have a thin veneer of legitimacy and a clear early employer, but you’re still mostly on your own.

### 6. The Defector

You were an officer or senior enlisted in a major navy and deliberately switched sides (or went independent) with a valuable ship and sensitive knowledge.

**World reaction:** Your old flag wants you dead or captured. Your new patrons are interested but don’t fully trust you. Intelligence services on all sides take notice.

**Feel:** You start with a solid ship and useful intelligence, but also active hunters and a reputation for treachery that follows you.

### 7. The Smuggler / Black-Market Runner

You specialize in moving restricted goods, people, and information through blockades and contested waters. Your ship is fast, discreet, and lightly armed.

**World reaction:** Most navies view you as a nuisance or criminal. Freeports, criminal syndicates, and certain intelligence agencies are potential customers or protectors.

**Feel:** Stealth, speed, and information-focused start. Weaker in open battle, strong in evasion, contacts, and early money-making.

### 8. The Academy Cast-Off / Junior Officer

A recent graduate (or near-graduate) of a naval academy who was given a minor command as a political favor, punishment, or because of heavy losses. You have training but almost no real experience or political cover.

**World reaction:** Treated as green and insignificant by the major powers. Easier to be ignored or underestimated. Some older officers may take a mentorship interest (or try to use you).

**Feel:** Classic “young captain with something to prove.” Lower starting skills/resources, but cleaner reputation and more room to define yourself.

## In the game today

Each origin is a start on the title screen (`godot/scripts/origins.gd`). The origins tied to a navy let the player pick which of the three great navies: the Hesperian Concord, the Vargan Directorate or the Halcyon Federation. That choice decides the ship, the home port, and who the enemy in the unfinished war is.

- **The Disgraced Officer:**
  - Ship: a worn destroyer of the chosen navy (70% hull).
  - Captain: level 3.
  - Money: 14,000, little else.
  - Old navy: cold (−5, not hostile). Its ports sell stores and repair at a premium, but their shipyard, officers' mess and Admiralty are closed (limited services).
  - The other great navies see a useful defector (+10).
- **The Hijacker:**
  - Ships: a seized Liberty freighter and a torpedo boat, both knocked about.
  - Crew: a small hard crew (85%).
  - Money: 9,000.
  - Standing: the legitimate flags are hostile (Combine worst, since you took their freighter); the freeports are friendly (+15).
  - Hunted: bounty hunters for about eight months, and a Combine reprisal squadron for five.
  - Start: Kesselport.
- **The Merchant Captain:**
  - Ship: a Victory-type freighter.
  - Money: 45,000, with a mixed cargo.
  - Trade: 6% better buying and selling.
  - Standing: friendly with the Combine and the freeports, neutral with everyone else.
  - Start: Cape Ombra.
- **The Survivor of the Lost Fleet:**
  - Ship: a destroyer of the chosen navy at 45% hull.
  - Crew: short-handed (70%).
  - Captain: level 3.
  - Money: 6,000, fuel and food low.
  - Standing: the old navy is neutral (0); the victors are hostile and send one hunter group for about six months; freeports and enclaves +10.
  - Start: a neutral bolt-hole (Halvardsby, Isfjell or Sanpo).
- **The Privateer:**
  - Sponsor: a letter of marque from the Tarsene Free Republic against the Vargan Directorate (Republic +30, Directorate −40, the other powers wary at −5).
  - Ship: a fast Corvo destroyer.
  - Prize money: 30% more against the Directorate.
  - Start: Puerto Corvo.
- **The Defector:**
  - Ship: a cruiser of the chosen navy.
  - Intelligence: 40 research points.
  - Standing: the old navy at −60; the new patrons (the old navy's enemy in the war) at +5; everyone else wary at −5.
  - Hunted: up to two intelligence squadrons for about ten months.
  - Start: the new patrons' main port.
- **The Smuggler:**
  - Ship: a fast Corvo destroyer stripped of her torpedoes.
  - Cargo: medicine and electronics in the hold.
  - Perks: 3% better trade and 15 points more chance to break off.
  - Standing: freeports +25; the navies see a nuisance (−5 to −10).
  - Start: Port Saffron.
- **The Academy Cast-Off:**
  - Ship: a corvette or torpedo boat of the chosen navy.
  - Captain: a level 1 officer.
  - Money: 15,000.
  - Standing: a clean name (own navy +10; only the navy's war enemy is hostile).

Hunter groups are hostile whatever your standing with their flag. They appear some way off and cast about where you were last reported, until their time runs out.

## Hooks for when the world is more lived in

Things the origins promise that the game doesn't do yet:

- **Disgraced Officer:** old contacts who still help quietly, and those who "would prefer you disappeared" (assassins, framed charges). A chance to clear your name.
- **Hijacker:** a visible price on your head that rises with your raids. Ports that fire on you rather than merely refusing entry. Raising a false flag ("carefully choosing when to show a flag").
- **Merchant Captain:** navies conscripting or "requesting" your services (requisitioned cargo space, escort duty). Pirates targeting you more often. Trade contracts.
- **Survivor of the Lost Fleet:** the mystery and revenge thread. Where the lost fleet died (a wreck field to survey), who covered it up, survivors to find. Your old navy deciding whether you are an embarrassment or a witness.
- **Privateer:** contracts and safe harbour from the sponsor. The letter of marque's legal standing: neutrals treating you as a pirate if you strike outside it. The sponsor revoking it.
- **Defector:** intelligence services on all sides taking notice. Missions to sell or trade what you know. Your new patrons' trust growing (or failing) with service.
- **Smuggler:** contraband goods and blockades to run. Inspections. Criminal syndicates and intelligence agencies as customers and protectors.
- **Academy Cast-Off:** being underestimated (enemies less wary of you). Mentors among older officers, who may also try to use you.

## Foundational lore (9 Nov 2026)

The owner's world-building for the fictional map, kept word for word in [`lore/foundational_lore.md`](lore/foundational_lore.md): the world in brief, the unfinished Meridian War (1939–1945) between the Continental Compact and the Oceanic Entente, the seven powers in 1946 with their profiles, the mysteries, the Quiet Race, and a 1946 backstory for each origin. Never edit that file; `python3 tools/lore_to_json.py` slices it, unchanged, into the `world` part of `godot/data/lore.json`.

### In the game today

- **Codex:** the title screen's "The world" button and the Command panel's Codex tab show the world in brief, the unfinished war, March 1946, the official history of the Meridian War, every power with its profile, the mysteries and the Quiet Race.
- **Origins:** each origin screen (title screen and the first chart panel) adds its 1946 backstory under the owner's origin text. The hijacker's freighter is the *Ashen Wake*; the merchant's is the *Southern Trader*.
- **Factions:** each flag's description is the opening of its entry (shown on its name under Missions & standing), and every port shows its flag's attitude toward independents.
- **Mysteries on the chart:** survey sites carry the owner's text: the Lost Squadron of the Central Hesperian, the Skarn Strait Wreck Fields, the Throat Research Anchorage (inner Sable Sea), the Corvo Canal Zone, and two Austral Barrier stations. Amakura and Port Saffron show their rumours (the Black Archives, Dry Dock Zero) in the port panel.
- **March 1946:** raiders gather in the Saffron Sea, the approaches to the Tarsene Gate and the open Hesperian; Concord patrols put out from Gatehold, and Directorate patrols from Strelsk, three times as often as from other ports.
- **Wars:** the fixed hostilities (Concord and Halcyon against the Directorate) match the two coalitions.

### Where the lore and the game differ (for the owner)

- **The armistice.** The lore makes 1946 a nervous peace ("one serious incident away from open war"); the game still has Concord and Halcyon ships fight the Directorate on sight. Turning that into an armistice with incidents belongs to diplomacy (step 3).
- **The Tarsene Gate's sides.** The lore puts the Republic on the Gate's western side; on the map the Gate runs east–west, with Tarsa on its northern shore and the Concord's Gatehold on the southern.
- **Ombrian clients.** The Directorate's Ombrian clients don't exist on the map yet: Ombria's ports belong to the Concord and the Combine. A candidate for the new factions.
- **Halcyon in the Entente.** The lore calls the Federation wary of both sides and fond of profitable neutrality, but also a member of the Entente; the game keeps it at war with the Directorate.
- **Privateer sponsor.** The lore offers a Tarsene or a Syndicate letter of marque; the game has only the Republic's.
- **Survivor's lost fleet.** The lore names the Concord's Central Hesperian squadron and the Directorate's 4th Battle Division; the Halcyon navy has no named lost fleet.

### Hooks

- The Lost Squadron wreck site is where the survivor's mystery thread should lead.
- The Amakura Black Archives and Dry Dock Zero as story missions; the Halvards restricting access to the Skarn Strait wrecks; signals from the Throat anchorage and the Austral Barrier stations.
- The Quiet Race: research as intelligence that makes you interesting to every service on the map.
- Hardliners and moderates in the Concord; the Concord's aim to absorb the Republic; the Combine selling to both sides.
