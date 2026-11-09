// Bakes the campaign world for the Godot build: coastlines, the land mask, the sea-lane network for routing, the
// precomputed routes between every pair of ports, and the campaign tables (ports, sites, goods, technology, story,
// starts). Run: node tools/bake_world.js   (needs Playwright; takes a few minutes for the port-to-port routes)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'godot');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file://' + path.join(ROOT, 'index.html')); await p.waitForTimeout(1200);
  // campaign tables and the world, with port and site sea positions resolved against the land mask
  const camp = await p.evaluate(() => {
    const w = genWorld(1);
    return {
      DEG, LAT0, MW, MH, MASK_RES, START: '1946-03-01',
      ports: w.ports.map(q => ({ id: q.id, name: q.name, fac: q.fac, capital: q.capital, x: q.x, y: q.y, sx: q.sx, sy: q.sy })),
      pois: w.pois.map(q => ({ id: q.id, name: q.name, type: q.type, x: q.x, y: q.y })),
      POI_TEXT, THEATERS, WARS, GOODS, TECH, ERA_NAME, STORY, STARTS, SKILLS, YARDS, PATROL_POOL, ESCORT_POOL, OFFICER_FIRST, OFFICER_LAST, DESIGNS_OF, LEGACY,
      MARKET_BIAS: { directorate: { steel: 0.7, fuel: 0.75 }, combine: { electronics: 0.75, medicine: 0.8 }, enclave: { electronics: 0.6, food: 1.6, fuel: 1.5 }, freeport: { munitions: 0.75 }, pacific: { steel: 0.8, electronics: 0.85 }, republic: { food: 0.75 }, concord: { fuel: 0.85 } },
      channels: CHANNELS.map(ch => ch.map(([lo, la]) => [lonX(lo), latY(la)])),
      land: LAND.polys, landMinX: LAND.minX, landMaxX: LAND.maxX,
    };
  });
  fs.mkdirSync(path.join(OUT, 'data'), { recursive: true });
  fs.writeFileSync(path.join(OUT, 'data', 'campaign.json'), JSON.stringify(camp));
  // land mask: red = land, green = within two cells of land (pilotage waters)
  const mask = await p.evaluate(() => {
    const c = document.createElement('canvas'); c.width = LAND.mw; c.height = LAND.mh; const g = c.getContext('2d'); const img = g.createImageData(LAND.mw, LAND.mh);
    for (let i = 0; i < LAND.mask.length; i++) { img.data[i * 4] = LAND.mask[i] ? 255 : 0; img.data[i * 4 + 1] = NAV.near[i] ? 255 : 0; img.data[i * 4 + 2] = 0; img.data[i * 4 + 3] = 255; }
    g.putImageData(img, 0, 0); return c.toDataURL('image/png');
  });
  fs.writeFileSync(path.join(OUT, 'data', 'land_mask.png'), Buffer.from(mask.split(',')[1], 'base64'));
  // sea lanes: a half-degree grid of open-water points joined where the straight leg stays at sea, plus the exact
  // routes between every pair of ports (which thread the straits and canals), tied into the grid nearby
  const nav = await p.evaluate(async () => {
    const S = 20, gw = MW / S, gh = MH / S, nodes = [], idx = new Int32Array(gw * gh).fill(-1);
    for (let j = 0; j < gh; j++) for (let i = 0; i < gw; i++) { const x = (i + 0.5) * S, y = (j + 0.5) * S; if (!landNear(x, y, 4)) { idx[j * gw + i] = nodes.length; nodes.push([x, y]); } }
    const edges = [];
    for (let j = 0; j < gh; j++) for (let i = 0; i < gw; i++) {
      const a = idx[j * gw + i]; if (a < 0) continue;
      for (const [di, dj] of [[1, 0], [0, 1], [1, 1], [-1, 1]]) {
        const ii = (i + di + gw) % gw, jj = j + dj; if (jj >= gh) continue; const bb = idx[jj * gw + ii]; if (bb < 0) continue;
        if (sightLine(nodes[a][0], nodes[a][1], nodes[bb][0], nodes[bb][1])) edges.push(a, bb);
      }
    }
    const G0 = { ports: genWorld(1).ports }; window.G = G0;
    const routes = {}; const n = G0.ports.length;
    for (let a = 0; a < n; a++) for (let c = a + 1; c < n; c++) {
      const r = findPath(G0.ports[a].sx, G0.ports[a].sy, G0.ports[c].sx, G0.ports[c].sy);
      routes[a + '>' + c] = r ? [[G0.ports[a].sx, G0.ports[a].sy], ...r.map(q => [q.x, q.y])] : null;
    }
    // route waypoints become lane nodes chained along the route and tied to grid points they can see
    const key = (x, y) => Math.round(x * 4) + ',' + Math.round(y * 4), seen = new Map();
    const tie = (k, x, y) => { const ci = Math.floor(wrapX(x) / S), cj = Math.floor(y / S); for (let dj = -2; dj <= 2; dj++) for (let di = -2; di <= 2; di++) { const ii = (ci + di + gw) % gw, jj = cj + dj; if (jj < 0 || jj >= gh) continue; const g = idx[jj * gw + ii]; if (g >= 0 && sightLine(x, y, nodes[g][0], nodes[g][1])) edges.push(k, g); } };
    const nodeFor = (x, y) => { const kk = key(wrapX(x), y); if (seen.has(kk)) return seen.get(kk); const id = nodes.length; nodes.push([wrapX(x), y]); seen.set(kk, id); tie(id, x, y); return id; };
    for (const r of Object.values(routes)) { if (!r) continue; let prev = -1; for (const [x, y] of r) { const id = nodeFor(x, y); if (prev >= 0 && prev !== id) edges.push(prev, id); prev = id; } }
    return { S, nodes: nodes.map(([x, y]) => [Math.round(x * 100) / 100, Math.round(y * 100) / 100]), edges, routes };
  });
  // compact binary for the lane network: float32 x,y per node; int32 pairs per edge
  fs.writeFileSync(path.join(OUT, 'data', 'nav_nodes.bin'), Buffer.from(new Float32Array(nav.nodes.flat()).buffer));
  fs.writeFileSync(path.join(OUT, 'data', 'nav_edges.bin'), Buffer.from(new Int32Array(nav.edges).buffer));
  fs.writeFileSync(path.join(OUT, 'data', 'nav_routes.json'), JSON.stringify({ S: nav.S, routes: nav.routes }));
  console.log('campaign tables, land mask, lanes:', nav.nodes.length, 'nodes,', nav.edges.length / 2, 'edges,', Object.keys(nav.routes).length, 'port routes');
  await b.close();
})();
