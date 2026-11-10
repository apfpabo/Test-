// Builds the campaign world for the Godot game from tools/worldgen/world.json:
//   godot/data/land_mask.png     red = land, green = pilotage waters within two cells of land
//   godot/data/nav_nodes.bin     sea-lane points (float32 x, y)    nav_edges.bin: lane links (int32 pairs)
//   godot/data/nav_routes.json   the route between every pair of ports
//   godot/data/campaign.json     geography (ports, sites, theatres, channels, coastlines, ice currents) merged into the
//                                existing campaign tables, which keep coming from tools/bake_world.js
//   godot/data/terrain.png       shaded land texture for the chart (see terrain.js)
// Run: node tools/worldgen/build.js   (about a minute; most of it is the port-to-port routes)
'use strict';
const fs = require('fs'), path = require('path');
const { blueprint } = require('./blueprint');
const { generate, DEG, LAT0, MW, MH, MASK_RES, CW, CH } = require('./generate');
const { encodeRGBA } = require('./png');
const { bakeTerrain } = require('./terrain');

const ROOT = path.resolve(__dirname, '../..'), DATA = path.join(ROOT, 'godot', 'data');
const W = JSON.parse(fs.readFileSync(path.join(__dirname, 'world.json'), 'utf8'));
const lonX = lon => (lon + 180) * DEG, latY = lat => (LAT0 - lat) * DEG;
const wrapX = x => ((x % MW) + MW) % MW;
const wdx = (ax, bx) => { let d = bx - ax; d -= MW * Math.round(d / MW); return d; };
const r2 = v => Math.round(v * 100) / 100;

const t0 = Date.now(); const log = (...a) => console.log(((Date.now() - t0) / 1000).toFixed(1) + 's', ...a);
const bp = blueprint(W.seed); const world = generate(bp, W.edits || {}); const { mask, field } = world;
log('land generated', world.stats);
if (world.stats.leaks.length) { console.error('choke points fail:', world.stats.leaks); process.exit(1); }

// ------------------------------------------------------------------ land queries (as in campaign.gd)
const onLand = (x, y) => { if (y < 2 || y >= MH - 2) return true; return mask[Math.floor(y / MASK_RES) * CW + Math.floor(wrapX(x) / MASK_RES)] === 1; };
const landNear = (x, y, pad) => { if (onLand(x, y)) return true; if (!pad) return false; for (let k = 0; k < 8; k++) { const a = k * Math.PI / 4; if (onLand(x + Math.cos(a) * pad, y + Math.sin(a) * pad)) return true; } return false; };
function nearestWater(x, y, maxR = 60) {
  if (!onLand(x, y)) return { x: wrapX(x), y };
  for (let r = 1; r <= maxR; r++) for (let k = 0; k < 24; k++) { const a = k / 24 * Math.PI * 2; const nx = x + Math.cos(a) * r, ny = y + Math.sin(a) * r; if (!landNear(nx, ny, 1.5)) return { x: wrapX(nx), y: ny }; }
  return { x: wrapX(x), y };
}
function sightLine(ax, ay, bx, by) {
  const dx = wdx(ax, bx), dy = by - ay, len = Math.hypot(dx, dy), steps = Math.ceil(len / (MASK_RES * 0.4));
  const nx = -dy / (len || 1) * 1.2, ny = dx / (len || 1) * 1.2;
  for (let i = 1; i < steps; i++) { const t = i / steps, x = ax + dx * t, y = ay + dy * t; if (onLand(x, y) || onLand(x + nx, y + ny) || onLand(x - nx, y - ny)) return false; }
  return true;
}

// ------------------------------------------------------------------ the land mask, with the pilotage band
const near = new Uint8Array(CW * CH), tmp = new Uint8Array(CW * CH);
for (let y = 0; y < CH; y++) for (let x = 0; x < CW; x++) if (mask[y * CW + x]) for (let d = -2; d <= 2; d++) tmp[y * CW + (x + d + CW) % CW] = 1;
for (let y = 0; y < CH; y++) for (let x = 0; x < CW; x++) if (tmp[y * CW + x]) for (let d = -2; d <= 2; d++) { const yy = y + d; if (yy >= 0 && yy < CH) near[yy * CW + x] = 1; }
const rgba = new Uint8Array(CW * CH * 4);
for (let k = 0; k < mask.length; k++) { rgba[k * 4] = mask[k] * 255; rgba[k * 4 + 1] = near[k] * 255; rgba[k * 4 + 3] = 255; }
fs.writeFileSync(path.join(DATA, 'land_mask.png'), encodeRGBA(CW, CH, rgba));
log('land mask');

// ------------------------------------------------------------------ coastlines: marching squares on the field, simplified
function coastlines(tol) {
  const v = k => mask[k] ? Math.max(field[k], 0.02) : Math.min(field[k], -0.02);
  const pt = new Map(), link = new Map();
  const edgePt = (id) => {   // id: 2 * cell + (0 = towards the cell to the east, 1 = towards the cell below)
    if (pt.has(id)) return; const c = id >> 1, i = c % CW, j = (c / CW) | 0, k2 = id & 1 ? c + CW : j * CW + (i + 1) % CW;
    const a = v(c), b = v(k2), t = a / (a - b);
    pt.set(id, id & 1 ? [(i + 0.5) * MASK_RES, (j + 0.5 + t) * MASK_RES] : [(i + 0.5 + t) * MASK_RES, (j + 0.5) * MASK_RES]);
  };
  const join = (p, q) => { edgePt(p); edgePt(q); (link.get(p) || link.set(p, []).get(p)).push(q); (link.get(q) || link.set(q, []).get(q)).push(p); };
  for (let j = 0; j < CH - 1; j++) for (let i = 0; i < CW; i++) {
    const i1 = (i + 1) % CW, a = j * CW + i, b = j * CW + i1, c = (j + 1) * CW + i1, d = (j + 1) * CW + i;
    const cs = mask[a] * 8 + mask[b] * 4 + mask[c] * 2 + mask[d]; if (cs === 0 || cs === 15) continue;
    const T = 2 * a, R = 2 * b + 1, B = 2 * d, L = 2 * a + 1;
    switch (cs) {
      case 1: case 14: join(L, B); break;
      case 2: case 13: join(B, R); break;
      case 3: case 12: join(L, R); break;
      case 4: case 11: join(T, R); break;
      case 6: case 9: join(T, B); break;
      case 7: case 8: join(L, T); break;
      case 5: case 10: { const centre = v(a) + v(b) + v(c) + v(d) > 0; // saddle: join by the centre's side
        if ((cs === 5) === centre) { join(L, T); join(B, R); } else { join(L, B); join(T, R); } break; }
    }
  }
  const seen = new Set(), loops = [];
  for (const start of link.keys()) {
    if (seen.has(start)) continue; const loop = []; let prev = -1, cur = start;
    while (!seen.has(cur)) { seen.add(cur); const p = pt.get(cur); if (loop.length) { const q = loop[loop.length - 1]; p[0] = q[0] + wdx(q[0], p[0]); } loop.push(p); const n = link.get(cur); const nx = n[0] !== prev ? n[0] : n[1]; prev = cur; cur = nx; if (cur === undefined) break; }
    if (loop.length >= 4) loops.push(loop);
  }
  const dp = (pts, a, b, out) => { // Douglas-Peucker between pts[a] and pts[b], appending kept points after a
    let best = -1, bi = -1; const [ax, ay] = pts[a], [bx, by] = pts[b], dx = bx - ax, dy = by - ay, L = Math.hypot(dx, dy) || 1e-9;
    for (let i = a + 1; i < b; i++) { const d = Math.abs((pts[i][0] - ax) * dy - (pts[i][1] - ay) * dx) / L; if (d > best) { best = d; bi = i; } }
    if (best > tol) { dp(pts, a, bi, out); dp(pts, bi, b, out); } else out.push(pts[b]);
  };
  const polys = [];
  for (const lp of loops) {
    const m = lp.length >> 1, out = [lp[0]]; dp(lp, 0, m, out); dp([...lp, lp[0]], m, lp.length, out); out.pop();
    if (out.length < 4) continue;
    const flat = [];
    for (const [x, y] of out) flat.push(r2(x), r2(y < 4 ? 0 : y > MH - 4 ? MH : y)); // polar edges run along the chart's border
    polys.push(flat);
  }
  return polys;
}
const land = coastlines(0.7);
let minX = Infinity, maxX = -Infinity; for (const p of land) for (let i = 0; i < p.length; i += 2) { minX = Math.min(minX, p[i]); maxX = Math.max(maxX, p[i]); }
log('coastlines:', land.length, 'polygons,', land.reduce((s, p) => s + p.length / 2, 0), 'points');

// ------------------------------------------------------------------ ports and survey sites
let bad = 0;
function coastPoint(lon, lat) {
  const ci = Math.floor(lonX(lon) / MASK_RES), cj = Math.floor(latY(lat) / MASK_RES); let best = null, bd = 1e9;
  for (let dj = -30; dj <= 30; dj++) for (let di = -30; di <= 30; di++) {
    const j = cj + dj, i = ((ci + di) % CW + CW) % CW; if (j < 1 || j >= CH - 1) continue; const k = j * CW + i;
    if (!mask[k] || (mask[k + 1 - (i === CW - 1 ? CW : 0)] && mask[k - 1 + (i === 0 ? CW : 0)] && mask[k - CW] && mask[k + CW])) continue;
    const d = di * di + dj * dj; if (d < bd) { bd = d; best = [(i + 0.5) * MASK_RES, (j + 0.5) * MASK_RES]; }
  }
  if (!best) { console.error('no coast within 3° of', lon, lat); bad++; return [lonX(lon), latY(lat)]; }
  return best;
}
const ports = W.ports.map((p, id) => {
  const [x, y] = coastPoint(p.at[0], p.at[1]); const s = nearestWater(x, y, 80);
  return { id, name: p.name, fac: p.fac, capital: !!p.capital, x, y, sx: r2(s.x), sy: r2(s.y), ...(p.rumour ? { rumour: p.rumour } : {}), ...(p.garrison ? { garrison: p.garrison } : {}) };
});
if (bad) process.exit(1);
const pois = W.pois.map((q, id) => { const w = nearestWater(lonX(q.at[0]), latY(q.at[1]), 80); return { id, name: q.name, type: q.type, x: r2(w.x), y: r2(w.y), ...(q.text ? { text: q.text } : {}) }; });

// ------------------------------------------------------------------ sea routes: A* over the mask (as the browser build did)
const N = { g: new Float32Array(CW * CH), from: new Int32Array(CW * CH), stamp: new Uint32Array(CW * CH), closed: new Uint32Array(CW * CH), cur: 0, hf: new Float64Array(1 << 16), hi: new Int32Array(1 << 16), hn: 0 };
function heapPush(f, i) {
  if (N.hn >= N.hf.length) { const f2 = new Float64Array(N.hf.length * 2); f2.set(N.hf); const i2 = new Int32Array(N.hi.length * 2); i2.set(N.hi); N.hf = f2; N.hi = i2; }
  const hf = N.hf, hi = N.hi; let k = N.hn++;
  while (k > 0) { const p = (k - 1) >> 1; if (hf[p] <= f) break; hf[k] = hf[p]; hi[k] = hi[p]; k = p; }
  hf[k] = f; hi[k] = i;
}
function heapPop() {
  const hf = N.hf, hi = N.hi; const top = hi[0]; const n = --N.hn; if (n <= 0) return top;
  const f = hf[n], i = hi[n]; let k = 0;
  for (;;) { let c = 2 * k + 1; if (c >= n) break; if (c + 1 < n && hf[c + 1] < hf[c]) c++; if (hf[c] >= f) break; hf[k] = hf[c]; hi[k] = hi[c]; k = c; }
  hf[k] = f; hi[k] = i; return top;
}
const cellOf = (x, y) => [Math.floor(wrapX(x) / MASK_RES), Math.max(0, Math.min(CH - 1, Math.floor(y / MASK_RES)))];
const DX = [1, -1, 0, 0, 1, 1, -1, -1], DY = [0, 0, 1, -1, 1, -1, 1, -1];
function findPath(x0, y0, x1, y1) {
  N.cur++; N.hn = 0; const cur = N.cur;
  const w0 = nearestWater(x0, y0, 40), w1 = nearestWater(x1, y1, 40); const [sx, sy] = cellOf(w0.x, w0.y), [gx, gy] = cellOf(w1.x, w1.y);
  const start = sy * CW + sx, goal = gy * CW + gx;
  const h = (cx, cy) => { let dx = Math.abs(cx - gx); dx = Math.min(dx, CW - dx); const dy = Math.abs(cy - gy); return (Math.max(dx, dy) + 0.414 * Math.min(dx, dy)) * 1.6; };
  N.g[start] = 0; N.stamp[start] = cur; N.from[start] = -1; heapPush(h(sx, sy), start);
  let found = false, expanded = 0;
  while (N.hn > 0) {
    const i = heapPop(); if (N.closed[i] === cur) continue; N.closed[i] = cur;
    if (i === goal) { found = true; break; }
    if (++expanded > 3000000) break;
    const cx = i % CW, cy = (i / CW) | 0, gi = N.g[i];
    for (let k = 0; k < 8; k++) {
      const dx = DX[k], dy = DY[k], ny = cy + dy; if (ny < 0 || ny >= CH) continue;
      const nx = (cx + dx + CW) % CW, j = ny * CW + nx;
      if (mask[j] || N.closed[j] === cur) continue;
      if (dx && dy && (mask[cy * CW + nx] || mask[ny * CW + cx])) continue;
      const ng = gi + (dx && dy ? 1.414 : 1) * (near[j] ? 2.5 : 1);
      if (N.stamp[j] !== cur || ng < N.g[j]) { N.stamp[j] = cur; N.g[j] = ng; N.from[j] = i; heapPush(ng + h(nx, ny), j); }
    }
  }
  if (!found) return null;
  const cells = []; for (let i = goal; i !== -1; i = N.from[i]) cells.push(i); cells.reverse();
  const pts = cells.map(i => ({ x: (i % CW + 0.5) * MASK_RES, y: (((i / CW) | 0) + 0.5) * MASK_RES }));
  const out = []; let a = { x: x0, y: y0 }, k = 0;
  while (k < pts.length - 1) {
    let far = k + 1;
    for (let j = Math.min(pts.length - 1, k + 400); j > k + 1; j--) if (sightLine(a.x, a.y, pts[j].x, pts[j].y)) { far = j; break; }
    out.push(pts[far]); a = pts[far]; k = far;
  }
  if (out.length && sightLine(out[out.length - 1].x, out[out.length - 1].y, x1, y1)) out.push({ x: wrapX(x1), y: y1 });
  return out;
}

// lane grid: half-degree points in open water, joined where the straight leg stays at sea
const S = 20, gw = MW / S, gh = MH / S, nodes = [], idx = new Int32Array(gw * gh).fill(-1), edges = [];
for (let j = 0; j < gh; j++) for (let i = 0; i < gw; i++) { const x = (i + 0.5) * S, y = (j + 0.5) * S; if (!landNear(x, y, 4)) { idx[j * gw + i] = nodes.length; nodes.push([x, y]); } }
for (let j = 0; j < gh; j++) for (let i = 0; i < gw; i++) {
  const a = idx[j * gw + i]; if (a < 0) continue;
  for (const [di, dj] of [[1, 0], [0, 1], [1, 1], [-1, 1]]) {
    const ii = (i + di + gw) % gw, jj = j + dj; if (jj >= gh) continue; const b = idx[jj * gw + ii]; if (b < 0) continue;
    if (sightLine(nodes[a][0], nodes[a][1], nodes[b][0], nodes[b][1])) edges.push(a, b);
  }
}
log('lane grid:', nodes.length, 'points');
const routes = {}; let missing = 0;
for (let a = 0; a < ports.length; a++) for (let c = a + 1; c < ports.length; c++) {
  const r = findPath(ports[a].sx, ports[a].sy, ports[c].sx, ports[c].sy);
  routes[a + '>' + c] = r ? [[ports[a].sx, ports[a].sy], ...r.map(q => [r2(q.x), r2(q.y)])] : null; if (!r) { missing++; console.warn('no route', ports[a].name, '->', ports[c].name); }
}
log('port routes:', Object.keys(routes).length, missing ? missing + ' missing' : 'all found');
const key = (x, y) => Math.round(x * 4) + ',' + Math.round(y * 4), seen = new Map();
const tie = (k, x, y) => { const ci = Math.floor(wrapX(x) / S), cj = Math.floor(y / S); for (let dj = -2; dj <= 2; dj++) for (let di = -2; di <= 2; di++) { const ii = (ci + di + gw) % gw, jj = cj + dj; if (jj < 0 || jj >= gh) continue; const g = idx[jj * gw + ii]; if (g >= 0 && sightLine(x, y, nodes[g][0], nodes[g][1])) edges.push(k, g); } };
const nodeFor = (x, y) => { const kk = key(wrapX(x), y); if (seen.has(kk)) return seen.get(kk); const id = nodes.length; nodes.push([wrapX(x), y]); seen.set(kk, id); tie(id, x, y); return id; };
for (const r of Object.values(routes)) { if (!r) continue; let prev = -1; for (const [x, y] of r) { const id = nodeFor(x, y); if (prev >= 0 && prev !== id) edges.push(prev, id); prev = id; } }
fs.writeFileSync(path.join(DATA, 'nav_nodes.bin'), Buffer.from(new Float32Array(nodes.map(([x, y]) => [r2(x), r2(y)]).flat()).buffer));
fs.writeFileSync(path.join(DATA, 'nav_edges.bin'), Buffer.from(new Int32Array(edges).buffer));
fs.writeFileSync(path.join(DATA, 'nav_routes.json'), JSON.stringify({ S, routes }));
log('lanes:', nodes.length, 'points,', edges.length / 2, 'links');

// ------------------------------------------------------------------ landmasses and land sites (ready for land structures)
// Every land cell gets the landmass it belongs to (named in world.json); then a spread of inland sites is chosen where
// a later structure could stand: farmland (food), mines (steel), or oil and industry (money), each tied to its
// nearest port. The game doesn't use them yet: they are the hooks for air strikes and capture.
const comp = new Int32Array(CW * CH).fill(-1), compSize = []; {
  const st = new Int32Array(CW * CH);
  for (let s0 = 0; s0 < mask.length; s0++) {
    if (!mask[s0] || comp[s0] >= 0) continue; const id = compSize.length; let sp = 0, n = 0; st[sp++] = s0; comp[s0] = id;
    while (sp) { const k = st[--sp]; n++; const i = k % CW, j = (k / CW) | 0;
      for (const q of [j * CW + (i + 1) % CW, j * CW + (i - 1 + CW) % CW, j > 0 ? k - CW : -1, j < CH - 1 ? k + CW : -1]) if (q >= 0 && mask[q] && comp[q] < 0) { comp[q] = id; st[sp++] = q; } }
    compSize.push(n);
  }
}
const massPts = new Map();   // component -> named points on it (a landmass joined by an isthmus has several)
for (const m of W.landmasses || []) {
  const x = lonX(m.at[0]), y = latY(m.at[1]), k = Math.floor(y / MASK_RES) * CW + Math.floor(x / MASK_RES);
  if (comp[k] >= 0) (massPts.get(comp[k]) || massPts.set(comp[k], []).get(comp[k])).push({ name: m.name, x, y }); else console.warn('landmass point at sea:', m.name);
}
const landOf = k => {
  const pts = massPts.get(comp[k]);
  if (!pts) {   // an island: the group whose box holds it, if any
    const lo = ((k % CW) + 0.5) * MASK_RES / DEG - 180, la = LAT0 - (((k / CW) | 0) + 0.5) * MASK_RES / DEG;
    const g = (W.islandGroups || []).find(g => lo >= g.box[0] && la >= g.box[1] && lo <= g.box[2] && la <= g.box[3]);
    return g ? g.name : compSize[comp[k]] > 4000 ? 'unnamed land' : 'island';
  }
  const x = (k % CW + 0.5) * MASK_RES, y = (((k / CW) | 0) + 0.5) * MASK_RES; let best = pts[0], bd = 1e18;
  for (const p of pts) { const d = Math.hypot(wdx(p.x, x), p.y - y); if (d < bd) { bd = d; best = p; } }
  return best.name;
};
// The world ocean: the largest body of connected water. Enclosed water (a lake left by the hand edits, a basin behind a
// carved channel that does not reach the sea) is not the sea: a fleet cannot lie off it.
const ocean = new Uint8Array(CW * CH); {
  const comp = new Int32Array(CW * CH).fill(-1); let best = -1, bestN = 0, nc = 0;
  for (let k0 = 0; k0 < mask.length; k0++) { if (mask[k0] || comp[k0] >= 0) continue;
    let n = 0; const st = [k0]; comp[k0] = nc;
    while (st.length) { const k = st.pop(); n++; const i = k % CW, j = (k / CW) | 0;
      for (const q of [j * CW + (i + 1) % CW, j * CW + (i - 1 + CW) % CW, j > 0 ? k - CW : -1, j < CH - 1 ? k + CW : -1]) if (q >= 0 && !mask[q] && comp[q] < 0) { comp[q] = nc; st.push(q); } }
    if (n > bestN) { bestN = n; best = nc; } nc++; }
  let enclosed = 0; for (let k = 0; k < mask.length; k++) if (!mask[k]) { if (comp[k] === best) ocean[k] = 1; else enclosed++; }
  console.log('ocean: ' + nc + ' bodies of water, ' + enclosed + ' cells enclosed');
}
// distance to the open sea in cells (up to 250, about 2,700 km): what a structure's "km inland" reports
const seaDist = new Uint8Array(CW * CH).fill(255); {
  let front = []; for (let k = 0; k < mask.length; k++) if (ocean[k]) { seaDist[k] = 0; front.push(k); }
  for (let d = 1; d <= 250 && front.length; d++) { const next = [];
    for (const k of front) { const i = k % CW, j = (k / CW) | 0;
      for (const q of [j * CW + (i + 1) % CW, j * CW + (i - 1 + CW) % CW, j > 0 ? k - CW : -1, j < CH - 1 ? k + CW : -1]) if (q >= 0 && seaDist[q] === 255) { seaDist[q] = d; next.push(q); } }
    front = next; }
}
// distance from any water in cells (up to 40): used to choose where sites go (kept as it was, so the world's sites
// stay where they are)
const inland = new Uint8Array(CW * CH).fill(255); {
  let front = []; for (let k = 0; k < mask.length; k++) if (!mask[k]) { inland[k] = 0; front.push(k); }
  for (let d = 1; d <= 40 && front.length; d++) { const next = [];
    for (const k of front) { const i = k % CW, j = (k / CW) | 0;
      for (const q of [j * CW + (i + 1) % CW, j * CW + (i - 1 + CW) % CW, j > 0 ? k - CW : -1, j < CH - 1 ? k + CW : -1]) if (q >= 0 && inland[q] === 255) { inland[q] = d; next.push(q); } }
    front = next; }
}
const landSites = []; {
  const r = require('./noise').rng(W.seed * 101 + 5), cand = [];
  for (let j = 0; j < CH; j += 5) for (let i = 0; i < CW; i += 5) { const k = j * CW + i, la = LAT0 - (j + 0.5) * MASK_RES / DEG;
    if (mask[k] && inland[k] >= 4 && inland[k] <= 30 && Math.abs(la) < 64) cand.push([r(), k]); }
  cand.sort((a, b) => a[0] - b[0]);
  const minD = 5 * DEG;   // about 5° apart
  for (const [, k] of cand) {
    const x = (k % CW + 0.5) * MASK_RES, y = (((k / CW) | 0) + 0.5) * MASK_RES;
    if (landSites.some(q => Math.hypot(wdx(q.x, x), q.y - y) < minD)) continue;
    const lat = LAT0 - y / DEG, al = Math.abs(lat), f = field[k];
    const kind = f > 0.38 ? 'mine' : (al > 15 && al < 34) ? 'oil' : (inland[k] < 10 && landSites.length % 3 === 0) ? 'industry' : 'farm';
    let port = -1, pd = 1e9; for (const p of ports) { const d = Math.hypot(wdx(p.x, x), p.y - y); if (d < pd) { pd = d; port = p.id; } }
    landSites.push({ id: landSites.length, kind, yields: { farm: 'food', mine: 'steel', oil: 'money', industry: 'money' }[kind], x: r2(x), y: r2(y), land: landOf(k), port, coastKm: Math.round(seaDist[k] * 0.1 * 111) });
  }
}
for (const q of landSites) if (q.land === 'unnamed land') console.log('  unnamed land at', (q.x / DEG - 180).toFixed(1), (LAT0 - q.y / DEG).toFixed(1));

// ------------------------------------------------------------------ military installations (land structures, step 4)
// Coastal batteries, airfields and radar stations round the ports and on both shores of every strait, and naval
// bases (old wartime harbours) on coasts away from the ports. Owners are decided in the game (structures.gd), from
// the nearest port. Hand additions: world.json "installations": [{kind, at: [lon, lat]}].
const installations = []; {
  const r = require('./noise').rng(W.seed * 131 + 9);
  const cellXY = k => [(k % CW + 0.5) * MASK_RES, (((k / CW) | 0) + 0.5) * MASK_RES];
  const taken = [];   // every structure so far, to keep them apart
  for (const q of landSites) taken.push([q.x, q.y]);
  const clear = (x, y, d) => taken.every(([tx, ty]) => Math.hypot(wdx(tx, x), ty - y) >= d);
  // land cells with inland distance in [lo, hi] between rMin and rMax map units of (cx, cy), best first by score
  function pick(cx, cy, rMin, rMax, lo, hi, gap, score) {
    const out = [], c0 = Math.floor(wrapX(cx) / MASK_RES), r0 = Math.floor(cy / MASK_RES), R = Math.ceil(rMax / MASK_RES);
    for (let dj = -R; dj <= R; dj++) for (let di = -R; di <= R; di++) {
      const j = r0 + dj; if (j < 0 || j >= CH) continue;
      const k = j * CW + (c0 + di + CW) % CW; if (!mask[k] || inland[k] < lo || inland[k] > hi) continue;
      const [x, y] = cellXY(k), d = Math.hypot(wdx(cx, x), y - cy);
      if (d < rMin || d > rMax || Math.abs(LAT0 - y / DEG) > 66) continue;
      out.push([score ? score(d, k) : d + r() * rMax * 0.6, k, x, y]);
    }
    out.sort((a, b) => a[0] - b[0]);
    for (const [, k, x, y] of out) if (clear(x, y, gap)) return { k, x, y };
    return null;
  }
  const nearestPort = (x, y) => { let best = -1, bd = 1e9; for (const p of ports) { const d = Math.hypot(wdx(p.x, x), p.y - y); if (d < bd) { bd = d; best = p.id; } } return best; };
  const add = (kind, at, extra = {}) => {
    if (!at) return;
    taken.push([at.x, at.y]);
    installations.push({ id: installations.length, kind, x: r2(at.x), y: r2(at.y), land: landOf(at.k), port: extra.port ?? nearestPort(at.x, at.y), coastKm: Math.round(seaDist[at.k] * 0.1 * 111), ...(extra.strait ? { strait: extra.strait } : {}) });
  };
  for (const p of ports) {
    const fortified = p.fac === 'directorate' || (p.garrison || 1) > 1;   // the Directorate's fortified harbours
    for (let i = 0; i < (fortified ? 2 : 1); i++) add('battery', pick(p.sx, p.sy, 6, 40, 1, 2, 12), { port: p.id });
    if (p.capital || (p.garrison || 1) > 1 || p.fac === 'pacific' || p.id % 2 === 0) add('airfield', pick(p.x, p.y, 25, 110, 4, 16, 18), { port: p.id });
    if (p.capital || (p.garrison || 1) > 1 || (['concord', 'directorate', 'combine'].includes(p.fac) && p.id % 3 === 0)) add('radar', pick(p.sx, p.sy, 15, 70, 1, 3, 14), { port: p.id });
  }
  // both shores of every strait and canal: a battery each side, and a radar
  for (const c of world.channels) {
    const m = c.pts[c.pts.length >> 1], sx = wrapX(lonX(m[0])), sy = latY(m[1]), name = (W.channelNames || {})[c.name] || c.name;
    const a = pick(sx, sy, 2, 45, 1, 2, 6); add('battery', a, { strait: name });
    if (a) add('battery', pick(sx, sy, 2, 45, 1, 2, 6, (d, k) => { const [x, y] = cellXY(k); const o = Math.hypot(wdx(a.x, x), y - a.y); return o < 8 ? 1e9 : d - o * 0.3; }), { strait: name });
    add('radar', pick(sx, sy, 6, 60, 1, 3, 10), { strait: name });
  }
  // naval bases: wartime harbours on quiet coasts, well away from the ports and from each other
  const coast = [];
  for (let j = 0; j < CH; j += 3) for (let i = 0; i < CW; i += 3) { const k = j * CW + i; if (mask[k] && inland[k] === 1 && Math.abs(LAT0 - (j + 0.5) * MASK_RES / DEG) < 58) coast.push([r(), k]); }
  coast.sort((a, b) => a[0] - b[0]);
  const bases = [];
  for (const [, k] of coast) {
    if (bases.length >= 16) break;
    const [x, y] = cellXY(k);
    if (ports.some(p => Math.hypot(wdx(p.x, x), p.y - y) < 6 * DEG)) continue;
    if (bases.some(b => Math.hypot(wdx(b.x, x), b.y - y) < 14 * DEG) || !clear(x, y, 25)) continue;
    const at = { k, x, y }; bases.push(at); add('navalbase', at);
  }
  for (const h of W.installations || []) { const x = wrapX(lonX(h.at[0])), y = latY(h.at[1]), k = Math.floor(y / MASK_RES) * CW + Math.floor(x / MASK_RES); add(h.kind, { k, x, y }); }
}
log('installations:', installations.length, Object.entries(installations.reduce((o, q) => (o[q.kind] = (o[q.kind] || 0) + 1, o), {})).map(e => e.join(' ')).join(', '));
log('land sites:', landSites.length, Object.entries(landSites.reduce((o, q) => (o[q.kind] = (o[q.kind] || 0) + 1, o), {})).map(e => e.join(' ')).join(', '));
for (const p of ports) p.land = landOf(Math.floor(p.y / MASK_RES) * CW + Math.floor(p.x / MASK_RES));

// ------------------------------------------------------------------ campaign tables: geography in, the rest kept
const campPath = path.join(DATA, 'campaign.json'), camp = JSON.parse(fs.readFileSync(campPath, 'utf8'));
const names = W.channelNames || {};
Object.assign(camp, {
  DEG, LAT0, MW, MH, MASK_RES,
  WORLD: { name: W.name, seed: W.seed },
  ports, pois, THEATERS: W.theaters,
  channels: world.channels.map(c => c.pts.map(([lo, la]) => [r2(lonX(lo)), r2(latY(la))])),
  STRAITS: world.channels.map(c => { const p = c.pts[c.pts.length >> 1]; return { name: names[c.name] || c.name, kind: c.role, x: r2(wrapX(lonX(p[0]))), y: r2(latY(p[1])) }; }),
  ICE_BIAS: W.iceBias,
  RAIDER_GROUNDS: (W.raiderGrounds || []).map(([lo, la, r]) => [r2(lonX(lo)), r2(latY(la)), r * DEG]),
  LANDMASSES: [...new Set((W.landmasses || []).map(m => m.name))], LAND_SITES: landSites, INSTALLATIONS: installations,
  land, landMinX: minX, landMaxX: maxX,
});
for (const [k, v] of Object.entries(W.starts || {})) if (camp.STARTS[k]) Object.assign(camp.STARTS[k], v);
(W.story || []).forEach((s, i) => { if (camp.STORY[i]) Object.assign(camp.STORY[i], s); });
fs.writeFileSync(campPath, JSON.stringify(camp));
log('campaign.json');

bakeTerrain(world, path.join(DATA, 'terrain.png'));
log('terrain texture; done');
