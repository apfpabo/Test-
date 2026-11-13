# The Sea Shadow's art, from the owner's model

The Umbra (`co_shadow`) is drawn from a 3D model of the Sea Shadow (IX-529) that the owner sent on 13 Nov 2026. The model
itself is not in the repository; with it in hand:

```bash
python3 -I tools/sea_shadow/read_obj.py <Sea_Shadow_IX-529.obj> /tmp/ss_tri
python3 -I tools/sea_shadow/to_ship_axes.py /tmp/ss_tri.npy /tmp/ss
python3 -I tools/sea_shadow/bake.py /tmp/ss_ship.npy /tmp/ssb 4.4 /tmp/ss_tri_obj.npy
```

`bake.py` looks down on the model cut at the waterline (4.4 m above the keel, her real draught) and writes a picture (her
paint, the creases between plates, the band of glass round the bow), a height map, and her outline, in `/tmp/ssb.json`.
Those go into `SHADOW_ART` and the design's `outline` in `src/game.html`; then `./build.sh` and
`ONLY=co_shadow node tools/bake_assets.js`.
