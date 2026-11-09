// Bakes the ship plans, mounts and effect textures from the browser build into image files for the Godot project,
// and exports the game data (designs, weapons, paint schemes) as JSON. Run: node tools/bake_assets.js
// Needs Playwright with Chromium. Output goes to godot/assets and godot/data.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'godot');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file://' + path.join(ROOT, 'index.html')); await p.waitForTimeout(800);
  const data = await p.evaluate(() => ({ HULLS, WEAPONS, PAL, YARD_STYLE, CLASSES, MAKERS, FAC_MAKERS, FAC, NAMES, HULL_ORDER, TEAK, LINO }));
  fs.mkdirSync(path.join(OUT, 'data'), { recursive: true });
  fs.writeFileSync(path.join(OUT, 'data', 'game_data.json'), JSON.stringify(data, null, 1));
  // which paint schemes each design can appear in: the player's and the raiders' (any), plus each flag that buys from its yard
  // (a flag that borrows another's paint, FAC.paint, needs none of its own; auxiliaries are bought by everyone, so they come in every scheme)
  const combos = {}; for (const [id, d] of Object.entries(data.HULLS)) { const set = new Set(['player', 'raiders']);
    for (const [f, mk] of Object.entries(data.FAC_MAKERS)) if (mk && (mk.includes(d.yard) || ['ap', 'ao', 'ae', 'ar'].includes(d.klass))) set.add((data.FAC[f] && data.FAC[f].paint) || f);
    combos[id] = [...set].filter(k => data.PAL[k]); }
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
      // the height map of everything standing above the deck (grey = metres / H_MAX), the same for every paint scheme:
      // Godot lights each change of level from it and casts the shadows of towers and decks across the ship
      const hm = mk(g => { HM.on = true; try { drawPlan(g, d, PAL.player, 'top'); } finally { HM.on = false; } });
      const hb0 = document.createElement('canvas'); hb0.width = hm.width; hb0.height = hm.height; const h0 = hb0.getContext('2d'); h0.fillStyle = '#000'; h0.fillRect(0, 0, hb0.width, hb0.height); h0.drawImage(hm, 0, 0);
      out.img.top_h = hb0.toDataURL('image/png');
      const half = c0 => { const m = document.createElement('canvas'); m.width = Math.ceil(c0.width / 3); m.height = Math.ceil(c0.height / 3); m.getContext('2d').drawImage(c0, 0, 0, m.width, m.height); return m; }; // shadows are blurred, so a third of the resolution loses nothing
      const hs = mk(g => { g.fillStyle = '#000'; if (d.p.fd) { const f = d.p.fd; g.fillRect((f.x || 0) - d.L * f.len / 2, -f.w / 2, d.L * f.len, f.w); } hullPath(g, d); g.fill(); for (const [x, len, ww] of d.p.sup || []) g.fillRect(x - len / 2, -ww / 2, len, ww); });
      const hb = document.createElement('canvas'); hb.width = hs.width; hb.height = hs.height; const hg = hb.getContext('2d'); hg.filter = 'blur(' + Math.max(2, Math.round(d.B * 0.12 * spr)) + 'px)'; hg.drawImage(hs, 0, 0);
      out.img.hull_shadow = half(hb).toDataURL('image/webp', 0.8);
      return out;
    }, [id, pals]);
    manifest.ships[id] = { spr: res.spr, w: res.w, h: res.h, pals };
    for (const [k, url] of Object.entries(res.img)) save('ships/' + id + '/' + k + (url.startsWith('data:image/png') ? '.png' : '.webp'), url);
  }
  // gun mounts, AA and torpedo tubes, in each national style (the shipbuilder's), baked in neutral grey and tinted
  // with the flag's paint in Godot. Each image packs the grey in R and B, the height in metres / H_MAX in G, and alpha.
  // Guns are baked as housing and barrels apart, so only the barrels run back on recoil; ao is a soft contact shadow.
  const mres = await p.evaluate(() => {
    const out = {}, S = 20;
    for (const [wid, w] of Object.entries(WEAPONS)) {
      if (w.kind === 'ssm' || w.kind === 'sam') continue;
      const len = w.kind === 'gun' ? w.tl * 0.42 + w.bl + 1 : w.kind === 'torp' ? 6 : 4.5, back = w.kind === 'gun' ? w.tl * 0.62 + 1 : w.kind === 'torp' ? 5 : 3, half = w.kind === 'gun' ? Math.max(w.tw * 0.62, 1.5) + 0.6 : 2.6;
      const cv = () => { const c = document.createElement('canvas'); c.width = Math.ceil((len + back) * S); c.height = Math.ceil(half * 2 * S); return c; };
      const draw = (c, st, part, hm, shadow) => { const g = c.getContext('2d'); g.translate(back * S, half * S); g.scale(S, S); HM.on = hm; try { drawMount(g, wid, 0, REF_PAL, 0, false, shadow, part, st); } finally { HM.on = false; } };
      const pack = (st, part) => { const a = cv(), hc = cv(); draw(a, st, part, false); draw(hc, st, part, true);
        const ad = a.getContext('2d').getImageData(0, 0, a.width, a.height), hd = hc.getContext('2d').getImageData(0, 0, a.width, a.height).data, px = ad.data;
        for (let i = 0; i < px.length; i += 4) { const lum = Math.round(px[i] * 0.3 + px[i + 1] * 0.59 + px[i + 2] * 0.11); px[i] = lum; px[i + 2] = lum; px[i + 1] = hd[i + 3] ? hd[i] : 0; }
        a.getContext('2d').putImageData(ad, 0, 0); return a.toDataURL('image/png'); };
      const split = w.kind === 'gun', styled = split;
      out[wid] = { spr: S, ox: back, oy: half, w: len + back, h: half * 2, split, styled, img: {} };
      for (const st of styled ? STYLES : ['us']) { const key = styled ? st : 'all';
        out[wid].img[key] = pack(st, split ? 'house' : undefined); if (split) out[wid].img[key + '_barrels'] = pack(st, 'barrels'); }
      // contact shadow: the housing silhouette, blurred
      const sc = cv(); draw(sc, 'us', split ? 'house' : undefined, false, true); const ao = cv(), ag = ao.getContext('2d'); ag.filter = 'blur(' + Math.round(S * 0.5) + 'px)'; ag.drawImage(sc, 0, 0);
      out[wid].img.ao = ao.toDataURL('image/webp', 0.8);
    }
    return out;
  });
  for (const [wid, m] of Object.entries(mres)) { manifest.mounts[wid] = { spr: m.spr, ox: m.ox, oy: m.oy, w: m.w, h: m.h, split: m.split, styled: m.styled }; for (const [k, url] of Object.entries(m.img)) save('mounts/' + wid + '/' + k + (url.startsWith('data:image/png') ? '.png' : '.webp'), url); }
  manifest.yard_style = await p.evaluate(() => YARD_STYLE); manifest.h_max = await p.evaluate(() => H_MAX);
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
