# Iron Meridian · Godot build

Godot 4.3 project, GL Compatibility renderer. Battle first: the campaign still runs in the browser build (`../index.html`).

| Path | What it is |
| --- | --- |
| `scenes/skirmish.tscn` | Battle setup: preset engagements and a custom squadron builder (main scene) |
| `scenes/battle.tscn` | The battle screen |
| `scripts/battle_sim.gd` | Battle simulation, no drawing. 1 unit = 1 m, real knots and turning circles, battle clock ×2 by default |
| `scripts/battle.gd` | Builds the scene, draws ships, wakes and effects, handles input and camera |
| `scripts/battle_hud.gd` | Orders, ship lists, flagship panel, gun reticle, minimap, results |
| `scripts/game_data.gd` | Autoload: design, weapon and paint data, texture loading with mipmaps |
| `scripts/sfx.gd` | Autoload: synthesised gunfire and explosions |
| `shaders/water.gdshader` | The sea: swell, chop, light, glints, vignette |
| `shaders/ship_light.gdshader` | Sun-side light and shade on ship plans, soot on damaged hulls |
| `assets/`, `data/` | Baked by `node ../tools/bake_assets.js` from the browser build; do not edit by hand |
| `tests/` | `run_presets.tscn` (headless, plays every preset to the end), `shot_battle.tscn` (screenshots) |
