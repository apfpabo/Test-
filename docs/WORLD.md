# The world

The campaign world of Iron Meridian is fictional land on our planet's frame: equirectangular, 82°N to 78°S, wrapping east–west, 1 map unit = 0.05°. Climate still runs on latitude (pack ice, seasons). Ships stay modelled on real designs; the land, the place names and the factions' homelands are invented. The owner chose this world (candidate C, seed 16) from four generated candidates on 9 Nov 2026.

## The theatres

| Role in the creative direction | In this world |
| --- | --- |
| North Atlantic and Arctic routes | The **Hesperian Ocean**, between Varga (west) and Hallandia (east). The boreal island **Skarn** splits the way north into the **Skarn Passages**; above them lies **the Rime**. A warm current keeps the Vargan north-west coast open far north. |
| Mediterranean and Black Sea choke points | The **Cradle Sea**, enclosed by Varga and Ombria. Its only doors: the **Tarsene Gate** to the Hesperian Ocean, **the Throat** to the inner **Sable Sea**, and the **Kessel Canal** to the Long Gulf, which leaves through the **Hakar Strait** into the Gulf of Monsoons. |
| Indian Ocean trade arteries | The **Monsoon Ocean**: the Gulf of Monsoons (with the **Amber Narrows** to an oil gulf), the Kesh peninsula and the Bay of Kesh, and the **Lantern Strait** into the Lantern Sea. |
| Pacific island chains and resource archipelagos | The **Halcyon Ocean**, wrapping across the map's edge: the Amakura Isles (Halcyon Federation home), the Arcs and the Lantern Isles, the Stepping Stones in the north, the Anvil Chain and scattered reefs. |
| Southern Ocean / Antarctic approaches | The **Howling Seas**, round the polar Austral Barrier, with a few remote rocks (Grimvik, Sudrhavn). |

Other deliberate choke points: the **Corvo Canal** across the isthmus joining Hallandia and Austrine (Panama role), and the **Strelsk Sounds** guarding the gulf of the Directorate's capital. The generator checks that every enclosed basin is cut off when its channels are shut, so no strait can be sailed round.

**Landmasses:** Varga (the great northern continent), Ombria (its southern lobe), Hallandia and Austrine (joined at the Corvo isthmus), Skarn, Coralind, the Austral Barrier, plus named island groups.

**Factions and homes:** Hesperian Concord (Calder Roads, Hallandia; Gatehold on the Tarsene Gate's eastern mouth), Vargan Directorate (Strelsk, Varga; Sefira, its Ombrian client harbour), Halcyon Federation (Amakura, the Amakura Isles; Senkai Station in the Stepping Stones), Meridian Combine (Kotaraya, at the Lantern Strait), Tarsene Free Republic (Tarsa, on the Gate's western mouth), Freeport Syndicate (Port Saffron, Saffron Isle), Halvard Enclaves (Halvardsby in the Rime Isles, Grimvik on Skarn), Ombrian Protectorate (Sefira, Ilmaro and Duras on Ombria; Sefira was the Directorate's client harbour), Outer Isles League (Tamaru, Corrin and Greywater in the southern Halcyon reefs). 39 ports in all; in a war they can change hands ([`DIPLOMACY.md`](DIPLOMACY.md)). The owner's foundational lore ([`lore/foundational_lore.md`](lore/foundational_lore.md)) sets who holds what; [`LORE.md`](LORE.md) lists what was moved to follow it.

## How it is built

`tools/worldgen/`:

- `blueprint.js`: the large shapes that give each theatre its role, laid out from a seed (continent spines, the inner sea, bridges at the choke points, channels, island arcs). Seed 16 is mirrored east–west.
- `generate.js`: turns the blueprint into the land mask: warped and roughened coasts (warp damped near the choke points so they stay where they are carved), hand edits, carved channels, filled lakes, dropped specks, and the choke-point check.
- `terrain.js`: the shaded land texture (`godot/data/terrain.png`) in the battle islands' palette, with climate by latitude (desert belts, boreal forest, tundra, polar ice).
- `world.json`: **the world file**: seed, hand edits (`islands`, `carve`, `channels`), names of the straits, ice currents, theatres, ports, survey sites, landmasses, island groups, faction-text overrides, and the place names in the story missions and legacy starts.
- `build.js`: writes everything Godot reads, in the formats it always read: `campaign.json` (geography merged into the campaign tables), `land_mask.png`, `nav_nodes.bin`, `nav_edges.bin`, `nav_routes.json`, `terrain.png`. About 25 seconds.
- `candidates.js` and `preview.py`: render candidate worlds for a seed range (how the four candidates were made).
- `fmt.py`: keeps `world.json` readable after a scripted edit.

To change the world: edit `world.json`, run `node tools/worldgen/build.js`, let Godot re-import (`godot --headless --path godot --editor --quit`), and check with `campaign_test.tscn` and `shot_map.tscn` (world, default, close zoom, the Tarsene Gate and the Kessel Canal). Ports snap to the nearest coast within 3° of the given point; the build stops and lists any that find none.

`node tools/bake_world.js` still exports the non-geographic campaign tables (goods, technology, story, yards) from the browser build, then runs the world build so its place names are applied again.

## Ready for land structures

Step four of the plan (land structures that can be struck from the air and captured for income) needs places on land. `campaign.json` already carries them:

- `LAND_SITES`: 266 inland sites about 5° apart, each with a kind (`farm` for food, `mine` for steel, `oil` or `industry` for money), its landmass, its nearest port and its distance from the coast (for carrier strike range).
- `LANDMASSES`, and `land` on every port: which landmass or island group a port or site belongs to.

Nothing in the game uses them yet. The strike reach that now starts fights at sea (`Campaign.strike_reach`: carriers 250–350 km) is the same measure an air strike on a site should use.

## Saves

The new world broke old saves: save version 4. A real-Earth save (version 3 or older) is refused, and the title screen says why.
