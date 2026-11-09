// Candidate worlds for the owner to choose from: node tools/worldgen/candidates.js <out dir> <seed> [seed ...]
// Writes <seed>_mask.png (red = land) and <seed>.json (labels, channels, options) for preview.py to draw.
'use strict';
const fs = require('fs'), path = require('path');
const { blueprint } = require('./blueprint');
const { generate, CW, CH } = require('./generate');
const { encodeRGBA } = require('./png');
const [out, ...seeds] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
for (const s of seeds.map(Number)) {
  const t = Date.now(); const bp = blueprint(s); const w = generate(bp);
  const rgba = new Uint8Array(CW * CH * 4); for (let k = 0; k < w.mask.length; k++) { rgba[k * 4] = w.mask[k] * 255; rgba[k * 4 + 3] = 255; }
  fs.writeFileSync(path.join(out, s + '_mask.png'), encodeRGBA(CW, CH, rgba));
  fs.writeFileSync(path.join(out, s + '.json'), JSON.stringify({ seed: s, opts: bp.opts, labels: bp.labels, channels: w.channels, stats: w.stats }));
  console.log('seed', s, bp.opts, w.stats, (Date.now() - t) + ' ms');
}
