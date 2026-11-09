// Seeded random numbers and 3D gradient noise, sampled on a cylinder so the world wraps east-west without a seam.
'use strict';

function rng(seed) { // mulberry32
  let a = seed >>> 0;
  return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

const G3 = [[1, 1, 0], [-1, 1, 0], [1, -1, 0], [-1, -1, 0], [1, 0, 1], [-1, 0, 1], [1, 0, -1], [-1, 0, -1], [0, 1, 1], [0, -1, 1], [0, 1, -1], [0, -1, -1]];
function perlin3(rand) {
  const p = new Uint8Array(512), perm = [...Array(256).keys()];
  for (let i = 255; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [perm[i], perm[j]] = [perm[j], perm[i]]; }
  for (let i = 0; i < 512; i++) p[i] = perm[i & 255];
  const fade = t => t * t * t * (t * (t * 6 - 15) + 10);
  const dot = (h, x, y, z) => { const g = G3[h % 12]; return g[0] * x + g[1] * y + g[2] * z; };
  return (x, y, z) => {
    const X = Math.floor(x), Y = Math.floor(y), Z = Math.floor(z); x -= X; y -= Y; z -= Z;
    const xi = X & 255, yi = Y & 255, zi = Z & 255; const u = fade(x), v = fade(y), w = fade(z);
    const A = p[xi] + yi, AA = p[A] + zi, AB = p[A + 1] + zi, B = p[xi + 1] + yi, BA = p[B] + zi, BB = p[B + 1] + zi;
    const l = (a, b, t) => a + (b - a) * t;
    return l(l(l(dot(p[AA], x, y, z), dot(p[BA], x - 1, y, z), u), l(dot(p[AB], x, y - 1, z), dot(p[BB], x - 1, y - 1, z), u), v),
      l(l(dot(p[AA + 1], x, y, z - 1), dot(p[BA + 1], x - 1, y, z - 1), u), l(dot(p[AB + 1], x, y - 1, z - 1), dot(p[BB + 1], x - 1, y - 1, z - 1), u), v), w);
  };
}

// Fractal noise at (lon, lat) in degrees; freq is cycles per degree for the first octave. Periodic in longitude.
function cylFbm(noise, lon, lat, freq, octaves, gain = 0.5) {
  let sum = 0, amp = 1, norm = 0, f = freq; const th = lon * Math.PI / 180, c = Math.cos(th), s = Math.sin(th);
  for (let o = 0; o < octaves; o++) {
    const R = 360 * f / (2 * Math.PI);
    sum += amp * noise(c * R + o * 17.3, s * R + o * 31.7, lat * f + o * 7.1); norm += amp; amp *= gain; f *= 2;
  }
  return sum / norm;
}

module.exports = { rng, perlin3, cylFbm };
