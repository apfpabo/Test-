# Sound

The agent cannot hear. Sound is handled by measurement, and judged by the owner.

## How sounds are checked

- `python3 tools/audit_sfx.py [files]` measures each sound: length, loudness (LUFS), peak, leading and trailing silence, where its energy lies (brightness, share below 150 Hz), and clipping. Run it on anything new before it goes in.
- The game's own mix is measured from a recorded clip (`tools/make_reels.sh` records the game's audio with the picture): `ffmpeg -i clip.mp4 -af ebur128=peak=true -f null -`.
- Taste is the owner's. Candidates go to him as short clips levelled to the same loudness, side by side, with what was measured and the licence beside each (11 Nov 2026: a listening page, "Iron Meridian Sound Review").

## What measurement found (11 Nov 2026)

- **Two gull calls were wind rumble.** `gull_1` and `gull_2` had 98% of their energy below 150 Hz (the source recordings are so). Everything under 900 Hz is now removed (assets and `build_sfx.py`); the third call was 6 dB louder than the rest and is levelled.
- **The missile launch began with a second of near silence**, so the missile had left before it was heard. Trimmed.
- **The game is quiet.** A recorded battleship duel sits at about -39 LUFS with peaks near -25 dB; games usually sit between -16 and -23. `Settings.OUTPUT` (0.165) is where the level is set; it was raised twice at the owner's request. Left for him to choose (three levels are on the listening page). Reels clips are raised 20 dB under a limiter.
- No file clips. Hits and blasts begin at once (the "attack" figure in the audit is the time to the loudest moment, which for a long explosion is late: look at the shape before trusting it).

## What has no sound of its own

Sonar ping (synthesised in `sfx.gd`), battle stations, the ship's bell and telegraph, interface clicks, aircraft, fire aboard, weather (rain, storm, thunder), a ship going down, and music (none at all). Candidates for each, with sources and licences, are on the listening page and in `tools/sound_candidates.json`; none is in the game until the owner has chosen.

## What the owner chose (11 Nov 2026)

From the listening page: the level 20 dB up under a limiter (`Settings.OUTPUT` is now 1.0 and `Sfx.PRE_GAIN_DB` 4.4 ahead of the limiter; a recorded duel measures -19.5 LUFS, peaks -6 dB); the recorded sonar ping; the siren for battle stations; the gong for the bell (alongside in port, an engine order on the chart); paper for a page turned (a new panel or Command page); the propeller loop near aircraft; fire crackling near a burning ship; bubbles by a ship going down; rain in a rough sea, storm wind and thunder in a storm (battle and chart). Not chosen: the interface switches, the alarms, the bells. Built by `tools/build_sfx_chosen.py`; played through `Sfx.cue(name)` (one-shots) and `Sfx.layer(name, level)` (loops: ask every frame, a loop nobody asks for fades out).

**Music, chosen 11 Nov 2026** (second round): "Lost Frontier" on the main menu, "Long Note Two" on the chart, "Steel and Seething" in battle, all by Kevin MacLeod (CC BY 4.0: credited on the main menu; `godot/assets/music`, built by `tools/build_music.py`, each levelled to -20 LUFS). `Sfx.music("menu" | "chart" | "battle" | "")` says which should play; the owner asked that nothing cut in when going between screens, so the old piece fades out over three seconds while the new fades in over three and a half, and a piece that has run its length rests in silence before it comes again (`Sfx.MUSIC`: file, level, rest). The Music bus has its own slider in Settings (default 60%). Reels are recorded without music. `tests/music_test.tscn` checks the crossfade has no step.

**Music, first round**: the first round (adventure and fantasy orchestral) was turned down: "too adventure-like, didn't seem to represent the tone of the game". The second round looks for the sombre and restrained.

## Rules

Only CC0, public-domain or CC BY sources (`godot/assets/sfx/CREDITS.md`; every source goes into `tools/build_sfx.py`'s `SOURCES`). Generated audio (an AI service) is not on that list: ask the owner first.
