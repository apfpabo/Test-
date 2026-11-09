// Shaded land texture for the chart, in the battle islands' palette (godot/shaders/island.gdshader): beach, scrub,
// grass, woods, rock and peaks, lit from the north-west, with climate by latitude (desert belts, boreal forest, tundra
// and polar ice). One texel per 0.1° land-mask cell; the chart maps it onto the coastline polygons.
'use strict';
const fs = require('fs');
const { rng, perlin3, cylFbm } = require('./noise');
const { CW, CH, lonOf, latOf } = require('./generate');
const { encodeRGBA } = require('./png');

const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
const ss = (e0, e1, x) => { const t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };
const SAND = [0.79, 0.71, 0.52], GRASS = [0.42, 0.5, 0.29], SCRUB = [0.5, 0.5, 0.33], FOREST = [0.24, 0.34, 0.2], ROCK = [0.5, 0.48, 0.42], PEAK = [0.66, 0.64, 0.58];
const DESERT = [0.76, 0.66, 0.47], STEPPE = [0.6, 0.57, 0.4], TUNDRA = [0.55, 0.55, 0.47], ICE = [0.78, 0.81, 0.82], JUNGLE = [0.2, 0.32, 0.18];

function bakeTerrain(world, out, seed = 1) {
  const { field, mask } = world; const n1 = perlin3(rng(seed * 31 + 7)), n2 = perlin3(rng(seed * 57 + 3));
  // height: distance inland from the field, plus ridged mountain chains that rise away from the coast
  const h = new Float32Array(CW * CH);
  for (let j = 0; j < CH; j++) for (let i = 0; i < CW; i++) {
    const k = j * CW + i; if (!mask[k]) continue;
    const lo = lonOf(i), la = latOf(j), inland = ss(0, 0.45, field[k]);
    const ridge = 1 - Math.abs(cylFbm(n1, lo, la, 1 / 14, 5)) * 2.2;
    const belt = ss(0.08, 0.3, cylFbm(n2, lo + 200, la, 1 / 40, 3));      // mountains only in a few long belts
    h[k] = Math.min(1, inland * 0.35 + Math.max(0, ridge) ** 3 * belt * ss(0.05, 0.3, field[k]) * 0.85 + cylFbm(n2, lo, la, 1 / 3, 3) * 0.06);
  }
  const rgba = new Uint8Array(CW * CH * 4);
  for (let j = 0; j < CH; j++) {
    const la = latOf(j), al = Math.abs(la);
    for (let i = 0; i < CW; i++) {
      const k = j * CW + i; if (!mask[k]) { // water texels take the neighbouring land colour so filtering doesn't darken coasts
        continue;
      }
      const lo = lonOf(i), hk = h[k];
      const e = 1, hx = h[j * CW + (i + e) % CW] - h[j * CW + (i - e + CW) % CW], hy = h[Math.min(CH - 1, j + e) * CW + i] - h[Math.max(0, j - e) * CW + i];
      const light = Math.max(0.8, Math.min(1.12, 1 + (-hx * 0.7 - hy * 0.7) * 6));   // sun from the north-west
      const wet = cylFbm(n2, lo + 50, la, 1 / 12, 4);      // patchy rainfall
      // climate by latitude: wet tropics, dry belts near 25°, temperate woods, boreal forest, tundra, ice
      const arid = ss(12, 20, al) * (1 - ss(30, 38, al)) * ss(-0.15, 0.2, -wet + 0.05);
      let c = mix(SCRUB, GRASS, ss(0.05, 0.25, hk));
      c = mix(c, FOREST, ss(0.48, 0.6, cylFbm(n1, lo + 11, la, 1 / 4, 4) + 0.5 + wet * 0.4) * (1 - ss(0.5, 0.7, hk)));
      c = mix(c, JUNGLE, (1 - ss(8, 16, al)) * ss(-0.1, 0.15, wet) * (1 - ss(0.5, 0.7, hk)));
      c = mix(c, mix(STEPPE, DESERT, ss(0.3, 0.7, arid)), ss(0.15, 0.5, arid));
      c = mix(c, mix(FOREST, TUNDRA, ss(60, 66, al)), ss(52, 58, al) * 0.85);
      c = mix(c, ROCK, ss(0.55, 0.75, hk + cylFbm(n2, lo, la, 1 / 1.5, 2) * 0.08));
      c = mix(c, PEAK, ss(0.82, 0.95, hk));
      c = mix(c, ICE, ss(70, 75, al + hk * 4 + cylFbm(n1, lo, la, 1 / 3, 3) * 3));
      c = mix(c, SAND, ss(0.035, 0.0, field[k] + cylFbm(n2, lo, la, 1 / 0.6, 2) * 0.02) * (1 - ss(62, 68, al)));
      c = mix(c, [0.79, 0.73, 0.58], 0.22);
      const grain = 0.95 + 0.1 * (cylFbm(n1, lo, la, 1 / 0.35, 2) + 0.5);
      for (let q = 0; q < 3; q++) rgba[k * 4 + q] = Math.max(0, Math.min(255, Math.round(c[q] * light * grain * 255)));
      rgba[k * 4 + 3] = 255;
    }
  }
  // bleed land colours one cell into the water so the texture's edge matches the smooth coastline polygons
  for (let pass = 0; pass < 2; pass++) {
    const src = rgba.slice();
    for (let j = 1; j < CH - 1; j++) for (let i = 0; i < CW; i++) {
      const k = j * CW + i; if (src[k * 4 + 3]) continue; let r = 0, g = 0, b = 0, n = 0;
      for (const q of [k - 1, k + 1, k - CW, k + CW]) if (src[q * 4 + 3]) { r += src[q * 4]; g += src[q * 4 + 1]; b += src[q * 4 + 2]; n++; }
      if (n) { rgba[k * 4] = r / n; rgba[k * 4 + 1] = g / n; rgba[k * 4 + 2] = b / n; rgba[k * 4 + 3] = 255; }
    }
  }
  fs.writeFileSync(out, encodeRGBA(CW, CH, rgba));
}

module.exports = { bakeTerrain };
