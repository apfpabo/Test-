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
  return { id, name: p.name, fac: p.fac, capital: !!p.capital, x, y, sx: r2(s.x), sy: r2(s.y) };
});
if (bad) process.exit(1);
const pois = W.pois.map((q, id) => { const w = nearestWater(lonX(q.at[0]), latY(q.at[1]), 80); return { id, name: q.name, type: q.type, x: r2(w.x), y: r2(w.y) }; });

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
  land, landMinX: minX, landMaxX: maxX,
});
for (const [k, v] of Object.entries(W.starts || {})) if (camp.STARTS[k]) Object.assign(camp.STARTS[k], v);
(W.story || []).forEach((s, i) => { if (camp.STORY[i]) Object.assign(camp.STORY[i], s); });
fs.writeFileSync(campPath, JSON.stringify(camp));
log('campaign.json');

bakeTerrain(world, path.join(DATA, 'terrain.png'));
log('terrain texture; done');
