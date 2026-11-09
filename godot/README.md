# Iron Meridian · Godot build

Godot 4.3 project, GL Compatibility renderer. This is the game; the browser build in `../src` only supplies baked art and data.

| Path | What it is |
| --- | --- |
| `scenes/main_menu.tscn` | Title: continue, new campaign (three starts), quick battle (main scene) |
| `scenes/world_map.tscn` | The chart and its panels: ports, command, encounters, surveys, aftermath |
| `scenes/skirmish.tscn` | Quick battles: preset engagements and a custom squadron builder |
| `scenes/battle.tscn` | The battle screen |
| `scripts/battle_sim.gd` | Battle simulation, no drawing. 1 unit = 1 m, real knots and turning circles, battle clock ×2 by default |
| `scripts/battle.gd` | Builds the scene, draws ships, wakes and effects, handles input and camera |
| `scripts/battle_hud.gd` | Orders, ship lists, flagship panel, gun reticle, minimap, results |
| `scripts/campaign.gd` | Autoload: campaign state and rules, routes, saves (no drawing) |
| `scripts/world_map.gd` | The chart, port and command panels, encounters, aftermath |
| `scripts/ui.gd` | Shared panel and button look |
| `scripts/game_data.gd` | Autoload: design, weapon and paint data, texture loading with mipmaps |
| `scripts/sfx.gd` | Autoload: synthesised gunfire and explosions |
| `shaders/water.gdshader` | The sea: swell, chop, light, glints, vignette |
| `shaders/ship_light.gdshader` | Sun-side light and shade on ship plans, soot on damaged hulls |
| `assets/`, `data/` | Baked by `node ../tools/bake_assets.js` and `bake_world.js` from the browser build; do not edit by hand |
| `tests/` | `run_presets.tscn`, `campaign_test.tscn` (headless); `shot_battle`, `shot_turrets`, `shot_map`, `full_loop` (screenshots) |
