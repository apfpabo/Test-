# Writing tales

A **tale** is a hand-written encounter or story beat: some text, then a choice or two, and what each choice does. You
write tales as plain text files in `godot/data/tales/`. Any file there that ends in `.txt` is read when the game
starts. Name the files however you like, one per power or one per story, for example `directorate.txt` or
`lost_fleet.txt`. Tales are read in file-name order, then in the order they are written. When two tales could come up
at the same moment, the first one wins.

The game shows a tale as a page on the chart, with an illustration, the title, the text, and one button for each
choice. The clock stops while it is open.

`godot/data/tales/examples.txt` holds two working examples. I wrote them from the lore's hooks to show the format.
Rewrite them or delete them.

## A tale at a glance

```
=== lights_in_the_rain
title: Lights in the Rain
when: at sea
where: sea Saffron Sea, sea Hesperian Ocean
days: 15+
chance: 4%
repeat: every 90 days

--- start
In a rain squall after midnight the lookouts report a cluster of dim lights...

* Turn towards them and open fire -> fight
* Turn away into the squall and run dark -> run
* [credits >= 3000] Signal an offer: a "toll" (3,000) -> toll

--- run
For an hour the lights hang on; then the rain takes them.
! fuel -20
* Carry on -> end
```

- **`=== name`** starts a tale. The name is one word (use `_` between words). It is never shown to the player; other
  tales use it to refer to this one.
- **Settings** (`key: value`) come next, before the first scene. All of them are optional.
- **`--- scene`** starts a scene. The tale opens on the first scene written, whatever it is called.
- **Text** is everything else in a scene. Lines run together into a paragraph; a blank line starts a new paragraph.
- **`! effect`** lines happen as soon as the scene opens. Each one is shown to the player in gold under the text,
  e.g. "+600 · Standing with the Concord +6".
- **`* choice -> scene`** lines become buttons. `-> end` closes the tale. A scene with no choices gets one button,
  "Carry on", which closes the tale.
- **`# a note`**: a line starting with `#` is for you. The game skips it.

## Settings

| Setting | What it means | Example |
| --- | --- | --- |
| `title` | Shown at the top of the page | `title: Space Requested` |
| `when` | `at sea` (checked once a day while sailing) or `arriving` (checked when you enter a harbour, before the harbour's page) | `when: arriving` |
| `where` | Where it can happen; list several with commas. See below. Leave it out for anywhere | `where: near Strelsk 400` |
| `days` | Days of the campaign it can happen in: `20-200`, or `30+` for any day from 30 on | `days: 30+` |
| `chance` | The chance it comes up each time the rest holds: each day at sea, or each arrival | `chance: 10%` |
| `needs` | Conditions that must all hold, separated by commas. See below | `needs: origin survivor, not flag met_halloran` |
| `repeat` | `no` means once a campaign (the default). `every 60 days` means it can come back 60 days after it last ended | `repeat: every 60 days` |
| `art` | A picture across the top: one of the scene pictures in `godot/assets/scenes`, without `.jpg` (`port`, `capital`, `storm`, `survey`, `contact`, `flag`, `landing`, `bomb`, `defeat`, `disengaged`...) | `art: storm` |

With no `chance`, a tale comes up the first time everything else holds. That suits story beats; give chance encounters
a small chance, between 2% and 10% a day.

### Where

| Write | Means |
| --- | --- |
| `anywhere` | Anywhere, the same as leaving `where` out |
| `sea <name>` | In one of the chart's seas, whichever sea name is nearest: Hesperian Ocean, South Hesperian, The Rime, Skarn Passages, Saffron Sea, Cradle Sea, Sable Sea, Gulf Of Monsoons, Bay Of Kesh, Monsoon Ocean, Lantern Sea, The Arcs, North Halcyon, South Halcyon, Coral Reach, Howling Seas |
| `near <harbour> <km>` | Within that many kilometres of a harbour (300 if you leave the number out) |
| `port <harbour>` | In that harbour (for `when: arriving`) |
| `power <power>` | In any harbour of that power, or at sea within about 600 km of one |

### Conditions

Use these in `needs:` and in front of a choice in square brackets. Put `not` in front of any of them to reverse it.

| Condition | True when |
| --- | --- |
| `credits >= 5000` | You have at least that much money. Also `<=`, `>`, `<`, `=`, `!=` |
| `rp >= 50`, `crew >= 200`, `day >= 90`, `era >= 2`, `ships >= 3`, `kills >= 5`, `ports >= 1`, `year >= 1950` | The same, for research points, crew, the day, your era, ships you own, ships you have sunk, harbours under your own flag, the calendar year |
| `standing directorate >= 20` | Your standing with that power |
| `cargo munitions >= 50` | Tons of a good in your holds (`cargo munitions` alone means at least one ton) |
| `flag broker_list` | A story flag you set with `! flag` (see effects) |
| `done lights_in_the_rain` | That tale has been played to its end |
| `origin survivor` | The captain's origin: disgraced, hijacker, merchant, survivor, privateer, defector, smuggler, academy |
| `navy concord` | The navy a navy origin started in |
| `class cv` | You own a ship of that class |
| `war directorate` | You are at war with that power |
| `commission pacific` | You hold that power's commission |

A choice whose conditions are not met is still shown, greyed out, and hovering over it says what it needs. The player
sees what a richer or better-standing captain could have done.

## Effects

| Effect | What it does |
| --- | --- |
| `! credits +2000` / `! credits -500` | Money (it never goes below nothing) |
| `! rp +10` | Research points |
| `! crew -20` | Sailors |
| `! fuel +50`, `! food -10`, `! steel +20`... | Tons of a good: fuel, food, steel, medicine, munitions, electronics |
| `! standing concord +5` | Standing with a power (it shows in the standing ledger as "A tale: <its title>") |
| `! hull -10%` | Damage to (or, with +, repairs on) every ship of your squadron |
| `! ship dd "Kestrel"` | A ship joins you: a class (`pt`, `corvette`, `dd`, `ss`, `cl`, `ca`, `bb`, `cv`, `freighter`...) or an exact design. The name in quotes is optional. If your supply cannot take her, the player is told why |
| `! flag broker_list` | Sets a story flag, which later tales can test |
| `! clear broker_list` | Removes a story flag |
| `! log "Met the Broker's man in Kesselport"` | A line in the captain's log |
| `! fight raiders pt pt dd "Lantern Wolf" -> won` | A battle: that power's ships, by class; the first one carries the name in quotes. The page shows "Battle stations". If the player wins, the tale goes on at the scene after `->`. If they lose or break off, it ends there. Leave out `-> scene` and it ends either way |

Powers are written by their one-word name: `concord`, `directorate`, `pacific` (the Halcyon Federation), `combine`,
`republic`, `freeport`, `enclave`, `ombria`, `isles`, `raiders`.

## Words filled in

| Write | Becomes |
| --- | --- |
| `{flagship}` | Your flagship's name |
| `{port}` | The harbour you have just entered, or the nearest one at sea |
| `{sea}` | The sea you are in |
| `{date}` | The date |
| `{credits}` | Your money |

## Chains: a story told over several tales

Tie tales together with flags and `done`:

```
=== lost_fleet_1
when: arriving
where: port Halbrook
needs: origin survivor
--- start
An old signalman recognises you on the quay...
! flag halloran_named
* Carry on -> end

=== lost_fleet_2
when: at sea
where: sea Hesperian Ocean
needs: flag halloran_named, day >= 40
chance: 5%
--- start
...
```

## When you make a mistake

The game checks every file when it starts. Each mistake is reported with its file and line, for example
`examples.txt:14: no harbour called "Strelsk Bay"`. The first one is shown on the chart when a campaign opens, and the
test (`godot --headless --path godot res://tests/tales_test.tscn`) lists them all. It catches:

- unknown settings, effects and conditions
- harbours, seas, powers, goods and classes that do not exist
- a choice that leads to a scene that is not there
- a scene nothing leads to

## What I can do with your outlines

Send me outlines or key beats, as rough as you like ("survivor meets a signalman in Halbrook who names the officer who
gave the order; later at sea his ship turns up in a squall"). I will draft the tales in this format from your lore, for
you to read and change before they go in. Your words stay yours: I will not alter text you have written without
asking.
