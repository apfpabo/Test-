// Bakes the ship plans, mounts and effect textures from the browser build into image files for the Godot project,
// and exports the game data (designs, weapons, paint schemes) as JSON. Run: node tools/bake_assets.js
// Needs Playwright with Chromium. Output goes to godot/assets and godot/data.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'godot');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file://' + path.join(ROOT, 'index.html')); await p.waitForTimeout(800);
  const data = await p.evaluate(() => ({ HULLS, WEAPONS, PAL, CLASSES, MAKERS, FAC_MAKERS, FAC, NAMES, HULL_ORDER, TEAK, LINO }));
  fs.mkdirSync(path.join(OUT, 'data'), { recursive: true });
  fs.writeFileSync(path.join(OUT, 'data', 'game_data.json'), JSON.stringify(data, null, 1));
  // which paint schemes each design can appear in: the player's and the raiders' (any), plus each flag that buys from its yard
  const combos = {}; for (const [id, d] of Object.entries(data.HULLS)) { combos[id] = ['player', 'raiders']; for (const [f, mk] of Object.entries(data.FAC_MAKERS)) if (mk && mk.includes(d.yard)) combos[id].push(f); }
  const manifest = { ships: {}, mounts: {} }; let bytes = 0;
  const save = (rel, url) => { const f = path.join(OUT, 'assets', rel); fs.mkdirSync(path.dirname(f), { recursive: true }); const buf = Buffer.from(url.split(',')[1], 'base64'); fs.writeFileSync(f, buf); bytes += buf.length; };
  for (const [id, pals] of Object.entries(combos)) {
    const res = await p.evaluate(([id, pals]) => {
      const d = HULLS[id], wide = spriteWide(d), spr = Math.round(clamp(1500 / d.L, 5, 16)), pad = 8;
      const mk = (fn) => { const c = document.createElement('canvas'); c.width = Math.ceil((d.L + pad) * spr); c.height = Math.ceil((wide + pad) * spr); const g = c.getContext('2d'); g.translate(c.width / 2, c.height / 2); g.scale(spr, spr); fn(g); return c; };
      const out = { spr, w: (d.L + pad), h: (wide + pad), img: {} };
      for (const pal of pals) { const P = PAL[pal];
        out.img[pal + '_base'] = mk(g => drawPlan(g, d, P, 'base')).toDataURL('image/webp', 0.92);
        out.img[pal + '_top'] = mk(g => drawPlan(g, d, P, 'top')).toDataURL('image/webp', 0.92); }
      // shadows are the same for every paint scheme: the hull silhouette and the raised-structure silhouette, blurred
      const top = mk(g => drawPlan(g, d, PAL.player, 'top')); const sh = document.createElement('canvas'); sh.width = top.width; sh.height = top.height; const sg = sh.getContext('2d');
      sg.filter = 'blur(' + Math.round(spr * 0.8) + 'px)'; sg.drawImage(top, 0, 0); sg.filter = 'none'; sg.globalCompositeOperation = 'source-in'; sg.fillStyle = '#000'; sg.fillRect(0, 0, sh.width, sh.height);
      const half = c0 => { const m = document.createElement('canvas'); m.width = Math.ceil(c0.width / 3); m.height = Math.ceil(c0.height / 3); m.getContext('2d').drawImage(c0, 0, 0, m.width, m.height); return m; }; // shadows are blurred, so a third of the resolution loses nothing
      out.img.top_shadow = half(sh).toDataURL('image/webp', 0.8);
      const hs = mk(g => { g.fillStyle = '#000'; if (d.p.fd) { const f = d.p.fd; g.fillRect((f.x || 0) - d.L * f.len / 2, -f.w / 2, d.L * f.len, f.w); } hullPath(g, d); g.fill(); for (const [x, len, ww] of d.p.sup || []) g.fillRect(x - len / 2, -ww / 2, len, ww); });
      const hb = document.createElement('canvas'); hb.width = hs.width; hb.height = hs.height; const hg = hb.getContext('2d'); hg.filter = 'blur(' + Math.max(2, Math.round(d.B * 0.12 * spr)) + 'px)'; hg.drawImage(hs, 0, 0);
      out.img.hull_shadow = half(hb).toDataURL('image/webp', 0.8);
      return out;
    }, [id, pals]);
    manifest.ships[id] = { spr: res.spr, w: res.w, h: res.h, pals };
    for (const [k, url] of Object.entries(res.img)) save('ships/' + id + '/' + k + '.webp', url);
  }
  // gun mounts, AA and torpedo tubes: one image per weapon and paint scheme, plus a shadow silhouette
  const mres = await p.evaluate(() => {
    const out = {}, S = 20;
    for (const [wid, w] of Object.entries(WEAPONS)) {
      if (w.kind === 'ssm' || w.kind === 'sam') continue;
      const len = w.kind === 'gun' ? w.tl * 0.42 + w.bl + 1 : w.kind === 'torp' ? 6 : 4.5, back = w.kind === 'gun' ? w.tl * 0.62 + 1 : w.kind === 'torp' ? 5 : 3, half = w.kind === 'gun' ? Math.max(w.tw * 0.6, 1.5) + 0.5 : 2.6;
      const mk = (pal, shadow) => { const c = document.createElement('canvas'); c.width = Math.ceil((len + back) * S); c.height = Math.ceil(half * 2 * S); const g = c.getContext('2d'); g.translate(back * S, half * S); g.scale(S, S); drawMount(g, wid, 0, PAL[pal], 0, false, shadow); return c.toDataURL('image/webp', 0.92); };
      out[wid] = { spr: S, ox: back, oy: half, w: len + back, h: half * 2, img: { shadow: mk('player', true) } };
      for (const pal of Object.keys(PAL)) out[wid].img[pal] = mk(pal, false);
    }
    return out;
  });
  for (const [wid, m] of Object.entries(mres)) { manifest.mounts[wid] = { spr: m.spr, ox: m.ox, oy: m.oy, w: m.w, h: m.h }; for (const [k, url] of Object.entries(m.img)) save('mounts/' + wid + '/' + k + '.webp', url); }
  // effect textures
  const fx = await p.evaluate(() => {
    const out = {}; out.puff = puffSprite('255,255,255').toDataURL('image/png');
    for (let v = 0; v < 4; v++) out['cloud' + v] = puffSprite('255,255,255', v).toDataURL('image/png');
    out.foam = foamSprite().toDataURL('image/png'); return out;
  });
  for (const [k, url] of Object.entries(fx)) save('fx/' + k + '.png', url);
  fs.writeFileSync(path.join(OUT, 'data', 'sprites.json'), JSON.stringify(manifest));
  console.log('baked', Object.keys(manifest.ships).length, 'designs,', Object.keys(manifest.mounts).length, 'mounts,', (bytes / 1e6).toFixed(1), 'MB');
  await b.close();
})();
