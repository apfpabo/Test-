// The world's blueprint: the large shapes that give each theatre of the creative direction its strategic role, laid out
// from a seed. Coordinates are [lon, lat] in degrees; `r` is the coast's distance from the spine (degrees, per point).
// The generator (generate.js) adds coastline noise, then forces the bridges to land and carves the channels open.
//
// Roles kept from the creative direction (names are placeholders until the world is chosen and named):
//   western ocean     - Atlantic role: a long north-south ocean with Arctic routes round a boreal island
//   inner sea         - Mediterranean role: enclosed, one strait to the western ocean, a canal to the monsoon ocean,
//                       and a second basin behind narrows (Black Sea role)
//   monsoon ocean     - Indian Ocean role: trade arteries between the inner sea's canal, a great peninsula and the straits
//                       of the eastern archipelago
//   great ocean       - Pacific role: wide, wrapping, with island arcs and resource archipelagos
//   southern ocean    - circumpolar, stormy, with polar land in two parts and a few remote islands
'use strict';
const { rng } = require('./noise');

function blueprint(seed) {
  const rand = rng(seed * 7919 + 13);
  const J = (v, a) => v + (rand() * 2 - 1) * a;
  const pick = a => a[Math.floor(rand() * a.length)];
  const land = [], sea = [], bridges = [], channels = [], labels = [];
  const L = (pts, r, o = {}) => land.push({ pts, r, ...o });
  const S = (pts, r, o = {}) => sea.push({ pts, r, ...o });
  const B = (pts, r) => bridges.push({ pts, r });
  const C = (name, role, pts, w) => channels.push({ name, role, pts, w });
  const T = (text, lon, lat) => labels.push({ text, lon, lat });
  const opts = { mirror: rand() < 0.5, west: pick(['isthmus', 'strait', 'isthmus']), southLobe: J(1, 0.18), eastIsles: pick(['continent', 'scattered']) };

  // ---------------------------------------------------------------- the western continent (two halves)
  const wN = J(-92, 6), wS = J(-62, 6), wLat = J(12, 3);
  L([[J(-108, 5), 71], [J(-100, 4), J(58, 3)], [wN, J(44, 3)], [wN + J(4, 3), J(30, 3)], [wN + J(2, 3), wLat + 7]], [J(15, 3), J(19, 3), J(16, 3), J(11, 2), J(5, 1)]);
  L([[J(-78, 4), J(57, 3)], [J(-64, 4), J(51, 3)], [J(-57, 3), J(47, 2)]], [J(9, 2), J(7, 2), 3.5]);              // the north-east lobe
  L([[wS - 10, wLat - 4], [wS, J(-4, 3)], [wS + J(8, 3), J(-14, 3)], [wS + J(2, 3), J(-30, 3)], [wS - J(6, 2), J(-44, 3)], [wS - J(9, 2), J(-54, 2)]], [J(6, 1), J(14, 2), J(12, 2), J(11, 2), J(6, 1), 2.6]);
  const ithA = [wN + 2, wLat + 6], ithB = [wS - 10, wLat - 4];
  if (opts.west === 'isthmus') {   // joined by a narrow isthmus with a canal across it (Panama role)
    const mid = [(ithA[0] + ithB[0]) / 2 + J(0, 2), (ithA[1] + ithB[1]) / 2];
    B([ithA, mid, ithB], 2.2);
    C('western canal', 'canal', [[mid[0] - 3.5, mid[1] + 3.5], [mid[0] + 3.5, mid[1] - 3.5]], 4);
  } else {                          // parted by a strait with stepping-stone islands
    const mid = [(ithA[0] + ithB[0]) / 2, (ithA[1] + ithB[1]) / 2];
    L([mid], 1.6); L([[mid[0] - 4, mid[1] + 2]], 1.1);
  }
  // the warm sea between the halves and its island screen (Caribbean role)
  const cx = wN + J(18, 3), cy = wLat + J(6, 2);
  for (let i = 0; i < 9; i++) { const t = i / 8; L([[cx + t * J(20, 2), cy + 6 - t * J(10, 2)]], J(1.4, 0.7) * (i === 1 ? 2.2 : 1)); }
  T('WARM SEA', cx + 4, cy - 3);

  // ---------------------------------------------------------------- the boreal island and the Arctic passages
  const bx = J(-38, 5);
  L([[bx - 6, 80], [bx, J(73, 2)], [bx - 3, J(64, 2)]], [J(9, 2), J(10, 2), 4]);
  L([[J(-17, 3), J(65, 1.5)]], J(3.2, 0.7));                                                     // mid-ocean isle
  L([[J(-8, 3), J(71, 1)]], 0.9);

  // ---------------------------------------------------------------- the eastern continent, north part
  const eS = J(44, 2);                                      // latitude of the inner sea's north shore
  L([[J(-4, 3), J(51, 2)], [J(14, 4), J(56, 2)], [J(40, 5), J(60, 2)], [J(72, 5), J(61, 2)], [J(102, 5), J(60, 2)], [J(132, 4), J(57, 2)], [J(152, 4), J(63, 2)]],
    [J(7, 1.5), J(11, 2), J(14, 2), J(17, 2), J(17, 2), J(13, 2), J(8, 2)]);
  L([[J(28, 4), J(69, 1.5)], [J(62, 4), J(71, 1.5)], [J(98, 4), J(73, 1.5)], [J(128, 4), J(70, 1.5)]], [6, 7, 6, 5]);
  L([[J(8, 3), J(60, 2)], [J(15, 3), J(66, 2)], [J(24, 3), J(70, 1)]], [J(5, 1), J(6, 1), 4]);    // northern peninsula
  L([[J(-2, 2), eS + 2], [J(18, 3), eS + J(3, 1)], [J(36, 3), eS + 1]], [J(6, 1), J(7, 1), J(6, 1)]);
  L([[J(44, 3), J(38, 2)], [J(66, 4), J(34, 2)], [J(92, 4), J(31, 2)], [J(116, 4), J(32, 2)], [J(130, 3), J(38, 2)]], [J(10, 2), J(11, 2), J(11, 2), J(9, 2), J(7, 1)]);
  // the great peninsula (India role) and a long southern finger toward the archipelago
  const gp = J(76, 5);
  L([[gp, 28], [gp + J(1, 2), J(17, 2)], [gp + J(2, 2), J(8, 2)]], [J(9, 1.5), J(6.5, 1), 2.4]);
  L([[J(104, 3), 26], [J(103, 2), J(14, 2)], [J(104, 2), J(4, 1.5)]], [J(6, 1), J(3.5, 0.6), 1.8]);
  L([[J(128, 3), J(42, 1)], [J(129, 2), J(35, 1)]], [3, 2]);

  // ---------------------------------------------------------------- the southern lobe and the inner sea
  const sl = opts.southLobe;
  L([[J(-2, 3), J(29, 2)], [J(14, 3), J(20, 2)], [J(28, 3), J(6, 2)], [J(30, 3), J(-10, 3) * sl], [J(24, 3), J(-24, 2) * sl], [J(20, 2), -34 * sl]],
    [J(11, 2), J(15, 2), J(15, 2), J(12, 2), J(10, 2) * sl, J(5, 1) * sl]);
  L([[J(40, 2), J(11, 1.5)], [J(50, 2), J(10, 1.5)]], [J(4.5, 1), 2]);                             // the horn
  L([[J(46, 2), J(25, 2)], [J(53, 2), J(20, 2)], [J(56, 1), J(17, 1)]], [J(7, 1), J(6, 1), 3]);   // the dry peninsula
  B([[-6, 30], [-6.5, 36], [-6, eS - 1]], 3.4);                                  // the west gate of the inner sea
  B([[33, 24], [34.5, 31], [35.5, eS - 2]], 5);
  B([[29, 29.5], [39, 31]], 3);                                  // the land bridge at its east end
  S([[-3, 36.5], [J(8, 2), J(37.5, 1)], [J(20, 2), J(36, 1)], [30, 35]], [3.2, J(5.6, 0.6), J(5.2, 0.6), 3.4]);
  S([[J(29, 1), eS + 1.5], [J(37, 1.5), eS + 1.5]], [2.6, 2.8]);                 // the inner basin (Black Sea role)
  C('west gate', 'strait', [[-10.5, 35.6], [-8, 36.3], [-5.5, 36.1], [-3, 36.6]], 7);
  C('narrows', 'strait', [[J(26, 0.5), 37.5], [26.8, 40], [28.2, eS - 1], [29, eS + 1]], 5);
  C('eastern canal', 'canal', [[29.6, 34.6], [32.5, 31.5], [35.5, 29], [38, 27.6]], 4);
  S([[38.3, 27.3], [J(41.5, 0.7), J(20, 1)], [44, 12.8]], [1.1, 1.7, 1.0]);          // the long gulf to the monsoon ocean
  C('gulf mouth', 'strait', [[43.2, 13.6], [45.5, 11.4]], 5);
  S([[48, 29.5], [53, 26.5], [56, 25.5]], [1.8, 2.2, 1.0]);                    // a second gulf behind a strait
  C('oil gulf narrows', 'strait', [[55.5, 26], [57.5, 24.5]], 5);
  const basins = [{ name: 'inner sea', at: [J(8, 2) * (opts.mirror ? -1 : 1), 37.5] }, { name: 'inner basin', at: [33 * (opts.mirror ? -1 : 1), eS + 1.5] }];
  T('INNER SEA', 14, 36.5); T('INNER BASIN', 33, eS + 1.5);

  // ---------------------------------------------------------------- the eastern archipelago and the south-east land
  L([[J(98, 2), J(2, 1)], [J(106, 2), J(-4, 1)]], [J(3, 0.6), J(2.6, 0.5)]);                      // the strait island
  C('archipelago strait', 'strait', [[J(101, 0.5), 6], [J(102, 0.5), 2], [J(104, 0.5), -2]], 6);
  for (const [lo, la, r] of [[112, -7, 2.2], [119, -8, 1.6], [126, -7, 1.6], [114, 1, 3.8], [124, 0, 2.0], [127, 8, 2.4], [122, 14, 1.8], [134, -3, 4.2]]) L([[J(lo, 1.5), J(la, 1.2)], [J(lo + 3, 1.5), J(la + 0.5, 1)]], J(r, r * 0.25));
  const se = opts.eastIsles === 'continent' ? 1 : 0.7;
  L([[J(124, 3), J(-22, 2)], [J(136, 3), J(-24, 2)], [J(146, 3), J(-30, 2)]], [J(10, 2) * se, J(12, 2) * se, J(6, 1) * se]);
  L([[J(166, 3), J(-40, 2)], [J(172, 2), J(-45, 2)]], [J(2.4, 0.5), J(2.2, 0.5)]);

  // ---------------------------------------------------------------- island chains of the great ocean
  const arc = (a, b, n, r0, r1, bend) => {   // a chain of islands along a bent arc
    for (let i = 0; i < n; i++) {
      const t = (i + rand() * 0.6) / n, bx2 = a[0] + (b[0] - a[0]) * t + Math.sin(t * Math.PI) * bend[0], by2 = a[1] + (b[1] - a[1]) * t + Math.sin(t * Math.PI) * bend[1];
      const r = r0 + (r1 - r0) * rand(), ang = rand() * Math.PI, len = r * (0.5 + rand());
      L([[bx2 - Math.cos(ang) * len, by2 - Math.sin(ang) * len], [bx2 + Math.cos(ang) * len, by2 + Math.sin(ang) * len]], r, { h: 1.25 });
    }
  };
  arc([J(134, 2), J(31, 2)], [J(150, 2), J(48, 2)], 6, 1.0, 2.6, [4, -1]);        // the home islands off the east coast
  arc([J(158, 2), J(52, 1)], [J(198, 2), J(53, 1)], 10, 0.6, 1.1, [0, -3]);      // the northern stepping stones
  arc([J(140, 2), J(10, 2)], [J(165, 3), J(-4, 2)], 9, 0.6, 1.6, [0, 4]);          // the resource archipelago
  arc([J(158, 3), J(-10, 2)], [J(-165, 3), J(-20, 2)], 8, 0.4, 1.4, [0, 3]);
  arc([J(-168, 3), J(26, 2)], [J(-150, 3), J(18, 2)], 6, 0.4, 1.3, [0, 2]);        // mid-ocean volcanic chain
  arc([J(-150, 4), J(-12, 3)], [J(-128, 4), J(-24, 3)], 6, 0.3, 0.8, [0, 2]);
  T('GREAT OCEAN', -150, 2); T('NORTHERN GREAT OCEAN', -165, 40); T('SOUTHERN GREAT OCEAN', -132, -32); T('ISLAND ARCS', 150, 18);

  // ---------------------------------------------------------------- the far south
  const pl = J(-71, 1.5);
  L([[-176, pl - 4], [-120, pl], [-60, pl + J(2, 1.5)], [J(-50, 4), J(-64, 1)]], [J(6, 1), J(7, 1), J(6, 1), 2.6]);
  L([[-40, pl - 2], [20, pl + J(1, 1)], [90, pl], [140, pl + J(1, 1)], [176, pl - 4]], [J(6, 1), J(7, 1), J(7, 1), J(6, 1), J(5, 1)]);
  for (const [lo, la, r] of [[-37, -54.5, 1.3], [J(4, 4), J(-54, 1), 0.7], [J(70, 4), J(-49, 1), 1.5], [J(-75, 3), J(-52, 1), 0.8]]) L([[lo, la]], r);
  T('SOUTHERN OCEAN', 40, -57); T('SOUTHERN OCEAN', -110, -60); T('SOUTHERN OCEAN', 150, -58);
  T('WESTERN OCEAN', J(-35, 3), 40); T('ARCTIC ROUTES', 15, 76); T('SOUTH WESTERN OCEAN', -18, -24);
  T('MONSOON OCEAN', 78, -16); T('GULF OF MONSOONS', 63, 12); T('EASTERN BAY', 90, 14); T('ARCHIPELAGO SEA', 114, 10);

  // ---------------------------------------------------------------- break up the outlines: peninsulas and bays
  // Each large shape grows a few lobes and loses a few bites, so no coast keeps a familiar silhouette.
  const big = land.filter(s => s.pts.length > 1 && Math.max(...[].concat(s.r)) > 6);
  for (const s of big) {
    const n = 2 + Math.floor(rand() * 3);
    for (let k = 0; k < n; k++) {
      const i = Math.floor(rand() * s.pts.length), p = s.pts[i], r = [].concat(s.r)[Math.min(i, [].concat(s.r).length - 1)];
      const a = rand() * Math.PI * 2, len = r * (0.9 + rand() * 0.8), w = Math.max(1.6, r * (0.18 + rand() * 0.22));
      const tip = [p[0] + Math.cos(a) * len, p[1] + Math.sin(a) * len * 0.8];
      if (Math.abs(tip[1] - eS + 6) < 9 && tip[0] > -12 && tip[0] < 40) continue;   // leave the inner sea's shores alone
      if (rand() < 0.55) L([p, [(p[0] + tip[0]) / 2 + J(0, 2), (p[1] + tip[1]) / 2 + J(0, 2)], tip], [w * 1.4, w, w * 0.55]);
      else S([tip, [p[0] + (tip[0] - p[0]) * 0.35, p[1] + (tip[1] - p[1]) * 0.35]], [w * 0.8, w * 0.5]);
    }
  }
  if (opts.mirror) {
    for (const g of [land, sea, bridges, channels]) for (const p of g) p.pts = p.pts.map(q => [-q[0], q[1]]);  // fresh arrays: shapes share points
    for (const t of labels) t.lon = -t.lon;
  }
  return { seed, opts, land, sea, bridges, channels, labels, basins };
}

module.exports = { blueprint };
