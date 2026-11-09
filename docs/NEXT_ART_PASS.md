# Next: art pass 2 — turrets and superstructures

Brief for the next working session. Written from the owner's feedback after playing the Godot build (9 Nov 2026). Read [`CREATIVE_DIRECTION.md`](CREATIVE_DIRECTION.md) and [`ROADMAP.md`](ROADMAP.md) first; the art reference remains **Rule the Waves 3**: realistic top-down plans at true proportions, one consistent paint and lighting scheme, no cartoon outlines or bright decorative colours.

## Owner's feedback

1. **Turrets blend into each other.** Adjacent turrets (e.g. A and B on a battleship) read as one grey mass. They need separation: shading, shadows, edge definition, whatever it takes, without cartoon outlines.
2. **Each nation's turrets should look like that nation's.** Japanese turrets looked different from American ones; reproduce the national styles.
3. **Superstructures are low-detail.** Revisit them in the manner of Rule the Waves 3.

## Where the art lives today

- Ship plans and mounts are drawn by the browser renderer in `src/game.html`: `drawPlan` (hull and deck), `drawPlanTop` (superstructure, funnels, masts, boats, cranes, catapults), `detailDeck`, `detailSup`, `drawFlightDeck`/`drawIslandTop`, `drawSails`, and `drawMount` (guns, AA, torpedo tubes; `part` = `'barrels'` or `'house'`).
- `node tools/bake_assets.js` bakes them into `godot/assets/` (per design and paint scheme: `*_base`, `*_top`, `top_shadow`, `hull_shadow`; per weapon and scheme: house, `_barrels`, `shadow`). Then `./build.sh` and `godot --headless --path godot --editor --quit` to re-import.
- In Godot, `godot/scripts/battle.gd` draws ships: `ShipView` (base and top sprites with `shaders/ship_light.gdshader`, top shadow cast on the deck), `Mounts` (draws mounts level by level; superfiring mounts from `BattleSim.superfiring` are drawn larger with a deeper shadow), `Detail` (damage marks, clipped to the hull).
- Design data: `DESIGN_LIST` in `src/game.html`. Each design has a `yard`; each weapon in `WEAPONS` has turret dimensions `tw` (width), `tl` (length), `bl` (barrel length), `bw`, `gap`.

A larger option worth weighing: move the plan renderer itself into Godot (the roadmap already lists it), so turret and superstructure art can use real shaders and no longer depends on the browser. If the pass stays in the browser renderer, keep the bake pipeline.

## 1. Turret separation (ideas to try, judge by screenshots)

- A thin darker rim where the turret house meets the deck or barbette (ambient occlusion), and a visible barbette ring around each turret.
- Roof bevel: a lighter band along the sun-facing roof edge and a darker one on the far edge, computed in Godot from the sun direction like `ship_light.gdshader`, so it stays correct at any heading. Mounts are currently drawn without a shader.
- Per-turret cast shadow on the deck and onto the turret behind (exists, but too soft and short to separate A from B; superfiring shadows can be longer and crisper).
- Slight value difference between the roof and the sloped face/sides, as real turrets catch light differently on each plane.
- Check at three zooms: close (about 2.5×), default battle zoom, and zoomed out.

## 2. National turret styles

Style follows the **shipbuilder** (`yard`), not the flag: Tidewater = American, Clydemouth = British, Ostsee = German, Neva = Soviet, Seto = Japanese, Tirreno = Italian, Combine Marine = generic merchant/escort fittings. Research each from top-down photographs and plans before drawing; the notes below are starting points to verify, not facts to copy:

- **American (Tidewater)**: e.g. Iowa, Baltimore, Cleveland, 5"/38 twins. Rounded or slab-sided houses with a flat, near-vertical face plate; rangefinder hoods at the rear sides; 5"/38 twin mounts are compact boxes with rounded rear.
- **Japanese (Seto)**: e.g. Yamato, Takao, Kagero. Angular, faceted houses with sloped sides and face; Yamato's main turrets are very large, long-overhanging at the rear, with a wide rangefinder across the rear roof; destroyer and cruiser twin mounts have a distinctive shaped gunhouse.
- **British (Clydemouth)**: e.g. King George V quadruple and twin 14", 4.5"/5.25" twins. Box-like houses with a sloped front, roof sighting hoods, rangefinder at the rear.
- **German (Ostsee)**: e.g. Bismarck twin 15", Hipper twin 8". Flat-faced, angular houses with prominent rangefinder "ears" on the sides towards the rear.
- **Italian (Tirreno)**: e.g. Littorio triple 15", Zara twin 8". Rounded, smooth-sided houses.
- **Soviet (Neva)**: e.g. Sverdlov triple 6", Skory twin 130 mm. Follow the type's own layout.

Implementation hint: give `drawMount` (or its Godot replacement) a style key from the ship's `yard`, and bake mounts per style as well as per paint scheme (the bake currently keys mounts by weapon and scheme only).

## 3. Superstructures, after Rule the Waves 3

Today each block is a stack of rounded rectangles (`p.sup`: `[x, length, width, tiers]`) with a few fittings. RTW3 plans read as built-up structures. To study and reproduce:

- Distinct bridge forms: enclosed bridge with wings, open compass platform, conning tower ahead of the bridge.
- Tower forms by school: Japanese pagoda masts (Yamato, Takao), German tower bridges (Bismarck), British box bridges (KGV), American tower or tripod (Iowa, Cleveland, Fletcher).
- Fire-control directors and rangefinders on top, searchlight platforms, AA platforms and tubs around the funnels, boat decks with davits, signal yards.
- Clear changes in level: each deck lighter and set back, with the contact shadow between levels crisp enough to read.

This probably needs richer design data per block (shape kind, platforms, director positions) rather than one generic rectangle, so `DESIGN_LIST` plans will grow.

## Checks

- Screenshot comparisons in Godot: `xvfb-run -a godot --path godot --rendering-driver opengl3 res://tests/shot_turrets.tscn -- <out.png>` (turret close-up), `res://tests/arcs_test.tscn -- <out.png>` (several ships), `res://tests/shot_battle.tscn -- <preset> <dir>`.
- After changing turret footprints or superstructure blocks, run `godot --headless --path godot -s res://tests/overlap_audit.gd` (gun mounts must not overlap superstructure, except deliberate gun-house mounts) and the arcs test; `BattleSim.clear_bearings` derives firing arcs from the same blocks.
- `godot --headless --path godot res://tests/run_presets.tscn` must still play every preset to the end.
- Export for the owner (Windows 11): `godot --headless --path godot --export-release "Windows Desktop" ../build/IronMeridian.exe`, then zip and send it. The Windows template is in `~/.local/share/godot/export_templates/4.3.stable/`; in a fresh container run `tools/fetch_from_zip.py` (usage in its header) to pull only `windows_release_x86_64.exe` out of the 1 GB export-templates archive.
