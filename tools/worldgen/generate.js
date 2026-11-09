// Turns a blueprint into the land mask: smooth shapes, warped and roughened with noise, then the bridges forced to
// land, the channels carved, inland water filled and specks of land dropped. Grid: 0.1° cells (MASK_RES = 2 map units),
// 3600 x 1600, 82°N to 78°S, wrapping east-west.
'use strict';
const { rng, perlin3, cylFbm } = require('./noise');

const DEG = 20, LAT0 = 82, MW = 360 * DEG, MH = 160 * DEG, MASK_RES = 2;
const CW = MW / MASK_RES, CH = MH / MASK_RES, CELL = MASK_RES / DEG;   // cells, and degrees per cell
const COARSE = 4;                                                         // base shapes at 0.4°
const lonOf = i => -180 + (i + 0.5) * CELL, latOf = j => LAT0 - (j + 0.5) * CELL;
const wrapD = d => d - 360 * Math.round(d / 360);

// Unwrap a polyline so each point lies within 180° of the one before it.
function unwrap(pts) { const out = [pts[0].slice()]; for (let i = 1; i < pts.length; i++) out.push([out[i - 1][0] + wrapD(pts[i][0] - out[i - 1][0]), pts[i][1]]); return out; }

// Rasterise a capsule chain into grid `g` (w x h cells of `cell` degrees), calling fn(index, distance/radius).
function rasterCapsules(shape, w, h, cell, reach, fn) {
  const pts = unwrap(shape.pts), rs = pts.map((_, i) => Array.isArray(shape.r) ? shape.r[i] : shape.r);
  const segs = pts.length === 1 ? [[0, 0]] : pts.slice(1).map((_, i) => [i, i + 1]);
  for (const [a, b] of segs) {
    const [ax, ay] = pts[a], [bx, by] = pts[b], ra = rs[a], rb = rs[b], rmax = Math.max(ra, rb) * reach;
    const x0 = Math.min(ax, bx) - rmax, x1 = Math.max(ax, bx) + rmax, y0 = Math.min(ay, by) - rmax, y1 = Math.max(ay, by) + rmax;
    const i0 = Math.floor((x0 + 180) / cell), i1 = Math.ceil((x1 + 180) / cell), j0 = Math.max(0, Math.floor((LAT0 - y1) / cell)), j1 = Math.min(h - 1, Math.ceil((LAT0 - y0) / cell));
    const dx = bx - ax, dy = by - ay, L2 = dx * dx + dy * dy || 1e-9;
    for (let j = j0; j <= j1; j++) {
      const y = LAT0 - (j + 0.5) * cell;
      for (let ii = i0; ii <= i1; ii++) {
        const x = -180 + (ii + 0.5) * cell; const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / L2));
        const d = Math.hypot(x - ax - dx * t, y - ay - dy * t), r = ra + (rb - ra) * t;
        if (d < r * reach) fn(j * w + ((ii % w) + w) % w, d / r);
      }
    }
  }
}

const smooth = t => t <= 0 ? 0 : t >= 1 ? 1 : t * t * (3 - 2 * t);

function generate(bp, edits = {}) {
  const rand = rng(bp.seed), noise = perlin3(rand), warpN = perlin3(rand), detailN = perlin3(rand);
  const bw = CW / COARSE, bh = CH / COARSE, bcell = CELL * COARSE;
  // ---- base shapes: 1 inside, 0.5 on the coast (distance = r), 0 at 1.6 r
  const base = new Float32Array(bw * bh);
  const landShapes = [...bp.land, ...(edits.land || [])], seaShapes = [...bp.sea, ...(edits.sea || [])];
  for (const s of landShapes) { const hgt = s.h ?? 1; rasterCapsules(s, bw, bh, bcell, 1.6, (k, q) => { const v = hgt * smooth((1.6 - q) / 1.2); if (v > base[k]) base[k] = v; }); }
  for (const s of seaShapes) rasterCapsules(s, bw, bh, bcell, 1.6, (k, q) => { const v = smooth((1.6 - q) / 1.2); base[k] = Math.min(base[k], 1 - v * 1.1); });
  // ---- warp offsets (degrees) at coarse resolution, damped near the channels and bridges so the choke points
  // stay exactly where the blueprint carves them
  const keep = [];
  for (const c of [...bp.channels, ...(edits.channels || []), ...bp.bridges, ...(edits.bridges || [])]) for (const q of c.pts) keep.push(q);
  for (const b of bp.basins || []) keep.push(b.at);
  const wx = new Float32Array(bw * bh), wy = new Float32Array(bw * bh);
  for (let j = 0; j < bh; j++) for (let i = 0; i < bw; i++) {
    const lo = -180 + (i + 0.5) * bcell, la = LAT0 - (j + 0.5) * bcell;
    let dk = 1e9; for (const q of keep) dk = Math.min(dk, Math.hypot(wrapD(lo - q[0]), la - q[1]));
    const damp = smooth((dk - 6) / 16);
    wx[j * bw + i] = damp * (cylFbm(warpN, lo, la, 1 / 40, 2) * 15 + cylFbm(warpN, lo + 11, la - 5, 1 / 11, 3) * 3.5);
    wy[j * bw + i] = damp * (cylFbm(warpN, lo + 77, la + 33, 1 / 40, 2) * 8 + cylFbm(warpN, lo - 41, la + 17, 1 / 11, 3) * 2.5);
  }
  const bil = (g, fx, fy) => { // bilinear sample of a coarse grid at fractional cell coords (wraps x, clamps y)
    fx -= 0.5; fy = Math.max(0, Math.min(bh - 1.001, fy - 0.5)); const i = Math.floor(fx), j = Math.floor(fy), tx = fx - i, ty = fy - j;
    const i0 = ((i % bw) + bw) % bw, i1 = (i0 + 1) % bw, j1 = Math.min(bh - 1, j + 1);
    return (g[j * bw + i0] * (1 - tx) + g[j * bw + i1] * tx) * (1 - ty) + (g[j1 * bw + i0] * (1 - tx) + g[j1 * bw + i1] * tx) * ty;
  };
  // ---- the fine field: warped base, minus the coast level, plus fractal roughness
  const amp = edits.roughness ?? 0.42;
  const field = new Float32Array(CW * CH);
  for (let j = 0; j < CH; j++) {
    const la = latOf(j), fy = j / COARSE + 0.5 / COARSE;
    for (let i = 0; i < CW; i++) {
      const fx = i / COARSE + 0.5 / COARSE; const dx = bil(wx, fx, fy), dy = bil(wy, fx, fy);
      const b = bil(base, fx + dx / bcell, fy - dy / bcell);
      if (b < 0.08) { field[j * CW + i] = b - 0.5; continue; } // open ocean: skip the detail noise
      const lo = lonOf(i);
      field[j * CW + i] = b - 0.5 + amp * (cylFbm(detailN, lo, la, 1 / 9, 7, 0.52) + 0.35 * cylFbm(noise, lo, la, 1 / 1.6, 3));
    }
  }
  // ---- bridges (guaranteed land with a natural edge), then channels (carved water)
  for (const s of [...bp.bridges, ...(edits.bridges || [])]) rasterCapsules(s, CW, CH, CELL, 1.0, (k, q) => {
    const i = k % CW, j = (k / CW) | 0; const v = 0.25 * (1 - q) - 0.06 + 0.12 * cylFbm(detailN, lonOf(i), latOf(j), 1 / 1.5, 3);
    if (v > field[k]) field[k] = v;
  });
  const channels = [...bp.channels, ...(edits.channels || [])];
  for (const c of channels) {
    const half = c.w / 2 * CELL;
    rasterCapsules({ pts: c.pts, r: half }, CW, CH, CELL, 1.0, (k, q) => { field[k] = Math.min(field[k], -0.2 - 0.3 * (1 - q)); });
  }
  for (const p of edits.fill || []) rasterCapsules(p, CW, CH, CELL, 1.0, k => { field[k] = Math.max(field[k], 0.2); });
  for (const p of edits.carve || []) rasterCapsules(p, CW, CH, CELL, 1.0, k => { field[k] = Math.min(field[k], -0.2); });
  // ---- keep the 180° meridian at sea so no coastline crosses the seam
  for (let j = 0; j < CH; j++) for (const i of [CW - 1, CW - 2, CW - 3, 0, 1, 2]) field[j * CW + i] = Math.min(field[j * CW + i], -0.1);
  const mask = new Uint8Array(CW * CH);
  for (let k = 0; k < mask.length; k++) mask[k] = field[k] > 0 ? 1 : 0;
  for (let i = 0; i < CW; i++) { mask[i] = 0; mask[(CH - 1) * CW + i] = 0; }
  const stats = cleanMask(mask, field);
  stats.leaks = chokeCheck(mask, channels, bp.basins || []);
  return { field, mask, channels, stats };
}

// Fill water cut off from the world ocean (lakes) and drop islands smaller than a few cells. Keeps `field` in step.
function cleanMask(mask, field, minIsland = 8) {
  const comp = new Int32Array(mask.length).fill(-1), stack = new Int32Array(mask.length); const sizes = [];
  const nb = (k, f) => { const i = k % CW, j = (k / CW) | 0; f(j * CW + (i + 1) % CW); f(j * CW + (i - 1 + CW) % CW); if (j > 0) f(k - CW); if (j < CH - 1) f(k + CW); };
  for (let s = 0; s < mask.length; s++) {
    if (comp[s] >= 0) continue; const id = sizes.length, v = mask[s]; let n = 0, sp = 0; stack[sp++] = s; comp[s] = id;
    while (sp) { const k = stack[--sp]; n++; nb(k, q => { if (comp[q] < 0 && mask[q] === v) { comp[q] = id; stack[sp++] = q; } }); }
    sizes.push([v, n]);
  }
  let ocean = -1, big = 0; for (let c = 0; c < sizes.length; c++) if (sizes[c][0] === 0 && sizes[c][1] > big) { big = sizes[c][1]; ocean = c; }
  let lakes = 0, specks = 0;
  for (let k = 0; k < mask.length; k++) {
    const c = comp[k];
    if (mask[k] === 0 && c !== ocean) { mask[k] = 1; field[k] = 0.05; if (sizes[c][1] > 0) { lakes++; sizes[c][1] = -sizes[c][1]; } }
    else if (mask[k] === 1 && sizes[c][1] > 0 && sizes[c][1] < minIsland) { mask[k] = 0; field[k] = -0.05; specks++; }
  }
  return { lakes, specks };
}

// Each enclosed basin must be water, and cut off from the open ocean once its channels are shut: otherwise a choke
// point can be sailed round. Returns the names of basins that fail.
function chokeCheck(mask, channels, basins) {
  const shut = mask.slice();
  for (const c of channels) rasterCapsules({ pts: c.pts, r: (c.w / 2 + 3) * CELL }, CW, CH, CELL, 1.0, k => { shut[k] = 1; });
  const cell = (lo, la) => Math.floor((LAT0 - la) / CELL) * CW + ((Math.floor((lo + 180) / CELL) % CW) + CW) % CW;
  const ocean = cell(-179.95, 0), fails = [];
  for (const b of basins) {
    const s = cell(b.at[0], b.at[1]); if (mask[s]) { fails.push(b.name + ' (dry)'); continue; }
    const seen = new Uint8Array(mask.length), st = [s]; seen[s] = 1; let leak = false;
    while (st.length && !leak) {
      const k = st.pop(); if (k === ocean) { leak = true; break; } const i = k % CW, j = (k / CW) | 0;
      for (const q of [j * CW + (i + 1) % CW, j * CW + (i - 1 + CW) % CW, j > 0 ? k - CW : -1, j < CH - 1 ? k + CW : -1]) if (q >= 0 && !seen[q] && !shut[q]) { seen[q] = 1; st.push(q); }
    }
    if (leak) fails.push(b.name + ' (leaks)');
  }
  return fails;
}

module.exports = { generate, DEG, LAT0, MW, MH, MASK_RES, CW, CH, CELL, lonOf, latOf };
