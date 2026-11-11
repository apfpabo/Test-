# Builds the game's recorded sound effects from free sources (CC0, public domain and one CC BY 4.0 recording) into
# godot/assets/sfx/, and writes godot/assets/sfx/CREDITS.md. Every source, its author and licence is listed in SOURCES.
#
#   python3 -I tools/build_sfx.py <download dir>
#
# Needs ffmpeg and numpy (and py7zr for the two .7z archives). Downloads go into the given directory, which should be
# a fresh, empty one; nothing from it is executed. Sounds the game can't get from recordings (light AA and CIWS fire)
# are assembled here from recorded transients repeated at each weapon's rate of fire.
import os, sys, json, subprocess, zipfile, urllib.request, ssl
import numpy as np

OGA = 'https://opengameart.org/sites/default/files/'
COMMONS = 'https://upload.wikimedia.org/wikipedia/commons/'
SOURCES = {
    'cannon_fire.ogg': (OGA + 'cannon_fire_0.ogg', 'Cannon fire', 'thimras', 'CC0', 'https://opengameart.org/content/cannon-fire'),
    'cannon_hit_ship_short.ogg': (OGA + 'cannon_hit_ship_short.ogg', 'Battle at sea', 'thimras', 'CC0', 'https://opengameart.org/content/battle-at-sea'),
    'ship_destroyed_short.ogg': (OGA + 'ship_destroyed_short.ogg', 'Battle at sea', 'thimras', 'CC0', 'https://opengameart.org/content/battle-at-sea'),
    'naval.7z': (OGA + 'qubodup-NavalBattleSoundSet-cc0_0.7z', 'Tiny Naval Battle Sounds Set (made from US military public-domain recordings)', 'Iwan Gabovitch (qubodup)', 'CC0', 'https://opengameart.org/content/tiny-naval-battle-sounds-set'),
    'launch.7z': (OGA + 'launch.7z', 'Rocket launch', 'Iwan Gabovitch (qubodup)', 'CC0', 'https://opengameart.org/content/rocket-launch'),
    'explosion_dull.flac': (OGA + 'explosion_dull.flac', 'Dull explosion', 'Iwan Gabovitch (qubodup)', 'CC0', 'https://opengameart.org/content/dull-explosion'),
    'chunky_explosion.mp3': (OGA + 'Chunky%20Explosion.mp3', 'Chunky Explosion', 'Joth', 'CC0', 'https://opengameart.org/content/chunky-explosion'),
    'sfx100.zip': (OGA + '100-CC0-SFX_0.zip', '100 CC0 SFX', 'rubberduck', 'CC0', 'https://opengameart.org/content/100-cc0-sfx'),
    'gull_1.wav': (OGA + 'Seagull%20Ambient%201.wav', 'Solo Seagull Sound Effects', 'rango-mango', 'CC0', 'https://opengameart.org/content/solo-seagull-sound-effects'),
    'gull_2.wav': (OGA + 'Seagull%20Ambient%202.wav', 'Solo Seagull Sound Effects', 'rango-mango', 'CC0', 'https://opengameart.org/content/solo-seagull-sound-effects'),
    'gull_3.wav': (OGA + 'Seagull%20Ambient%203.wav', 'Solo Seagull Sound Effects', 'rango-mango', 'CC0', 'https://opengameart.org/content/solo-seagull-sound-effects'),
    'gull_5.wav': (OGA + 'Seagull%20Ambient%205.wav', 'Solo Seagull Sound Effects', 'rango-mango', 'CC0', 'https://opengameart.org/content/solo-seagull-sound-effects'),
    'gull_6.wav': (OGA + 'Seagull%20Ambient%206.wav', 'Solo Seagull Sound Effects', 'rango-mango', 'CC0', 'https://opengameart.org/content/solo-seagull-sound-effects'),
    'waves_1.flac': (OGA + 'wave_01_cc0-18363__jasinski__alkaibeach.flac', 'Beach Ocean Waves (from jasinski, CC0)', 'Iwan Gabovitch (qubodup)', 'CC0', 'https://opengameart.org/content/beach-ocean-waves'),
    'waves_2.flac': (OGA + 'wave_02_cc0-18363__jasinski__alkaibeach.flac', 'Beach Ocean Waves (from jasinski, CC0)', 'Iwan Gabovitch (qubodup)', 'CC0', 'https://opengameart.org/content/beach-ocean-waves'),
    'waves_3.flac': (OGA + 'wave_03_cc0-18363__jasinski__alkaibeach.flac', 'Beach Ocean Waves (from jasinski, CC0)', 'Iwan Gabovitch (qubodup)', 'CC0', 'https://opengameart.org/content/beach-ocean-waves'),
    'waves_4.flac': (OGA + 'wave_04_cc0-18363__jasinski__alkaibeach.flac', 'Beach Ocean Waves (from jasinski, CC0)', 'Iwan Gabovitch (qubodup)', 'CC0', 'https://opengameart.org/content/beach-ocean-waves'),
    'kuna_engine.ogg': (COMMONS + '7/7a/WWS_IcebreakerKunashipsengine.ogg', 'The engine of the icebreaker Kuna (Work With Sounds)', 'Work With Sounds / Museum of Municipal Engineering', 'CC BY 4.0', 'https://commons.wikimedia.org/wiki/File:WWS_IcebreakerKunashipsengine.ogg'),
}
RATE = 32000
UA = 'IronMeridian/1.0 (indie game asset build)'

def fetch(dl):
    ctx = ssl.create_default_context(cafile='/root/.ccr/ca-bundle.crt') if os.path.exists('/root/.ccr/ca-bundle.crt') else ssl.create_default_context()
    for name, (url, *_ ) in SOURCES.items():
        p = os.path.join(dl, name)
        if os.path.exists(p): continue
        with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': UA}), context=ctx, timeout=180) as r: open(p, 'wb').write(r.read())
    import py7zr
    for a in ['naval.7z', 'launch.7z']:
        with py7zr.SevenZipFile(os.path.join(dl, a)) as z: z.extractall(os.path.join(dl, 'x_' + a[:-3]))
    zipfile.ZipFile(os.path.join(dl, 'sfx100.zip')).extractall(os.path.join(dl, 'x_sfx100'))

def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'quiet', '-i', path, '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)

def seg(x, t0, t1=None): return x[max(0, int(t0 * RATE)): None if t1 is None else int(t1 * RATE)]
def fade(x, fin=0.003, fout=0.1):
    x = x.copy(); a, b = min(int(fin * RATE), len(x) // 4), min(int(fout * RATE), len(x) // 2)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x
def norm(x, peak=0.89): return x * (peak / (np.abs(x).max() + 1e-9))
def mix(*parts):
    n = max(int(o * RATE) + len(s) for s, o, g in parts); out = np.zeros(n)
    for s, o, g in parts: i = int(o * RATE); out[i:i + len(s)] += s * g
    return out
def lowpass(x, hz):
    a = np.exp(-2 * np.pi * hz / RATE); y = np.zeros_like(x); v = 0.0
    for i in range(len(x)): v = (1 - a) * x[i] + a * v; y[i] = v
    return y
def loop(x, xf=0.6):
    n = int(xf * RATE); head, tail = x[:n], x[-n:]; k = np.linspace(0, 1, n)
    return np.concatenate([tail * (1 - k) + head * k, x[n:-n]])
def onset(x, thr=0.2):
    i = np.where(np.abs(x) > thr * np.abs(x).max())[0]; return i[0] / RATE if i.size else 0.0

## Automatic fire: a recorded transient repeated at a rate of fire, each round slightly varied in level and timing.
def auto(trans, rate, dur, seed, jitter=0.08, tail=0.25):
    rng = np.random.default_rng(seed); out = np.zeros(int((dur + tail) * RATE)); t = 0.0
    while t < dur:
        i = int(t * RATE); g = 1.0 - rng.random() * 0.25; s = trans[: len(out) - i]
        out[i:i + len(s)] += s * g; t += (1.0 / rate) * (1 + (rng.random() - 0.5) * jitter)
    return out

def write(out_dir, name, x):
    tmp = os.path.join(out_dir, name + '.wav'); dst = os.path.join(out_dir, name + '.ogg')
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2').tobytes()
    import wave
    with wave.open(tmp, 'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(pcm)
    subprocess.run(['ffmpeg', '-v', 'quiet', '-y', '-i', tmp, '-c:a', 'libvorbis', '-q:a', '5', dst], check=True); os.remove(tmp)

def main():
    dl = sys.argv[1]; root = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); out = os.path.join(root, 'godot', 'assets', 'sfx')
    os.makedirs(dl, exist_ok=True); os.makedirs(out, exist_ok=True); fetch(dl)
    nv = os.path.join(dl, 'x_naval', 'qubodup-NavalBattleSoundSet-cc0')
    cannon = load(os.path.join(dl, 'cannon_fire.ogg')); shot = load(os.path.join(nv, 'GunShot.wav')); shot_v = load(os.path.join(nv, 'GunShotGverb.wav'))
    so, svo = onset(shot, 0.5), onset(shot_v, 0.5)   # the report's attack, not the quiet lead-in
    made = {}
    # big guns: the deep report of the cannon recording with the naval gun's crack on its front edge
    made['gun_heavy_1'] = fade(norm(mix((seg(cannon, onset(cannon) - 0.005), 0, 1.0), (seg(shot_v, svo - 0.005), 0, 0.45))), 0.002, 0.6)
    made['gun_heavy_2'] = fade(norm(mix((seg(cannon, onset(cannon) - 0.005), 0, 1.0), (seg(shot, so - 0.005), 0.01, 0.55))), 0.002, 0.6)
    made['gun_medium'] = fade(norm(seg(shot_v, svo - 0.005, svo + 1.3)), 0.002, 0.5)
    made['gun_small'] = fade(norm(seg(shot, so - 0.005, so + 0.45)), 0.002, 0.15)
    # hits, splashes and big explosions
    hit = load(os.path.join(dl, 'cannon_hit_ship_short.ogg')); made['hit_1'] = fade(norm(seg(hit, onset(hit) - 0.005)), 0.002, 0.8)
    met = load(os.path.join(nv, 'ExplosionMetal.wav')); made['hit_2'] = fade(norm(seg(met, onset(met) - 0.005)), 0.002, 0.4)
    for i, n in enumerate([1, 2, 3, 4]):
        w = load(os.path.join(nv, 'WaterSurfaceExplosion0%d.wav' % n)); made['splash_%d' % (i + 1)] = fade(norm(seg(w, onset(w, 0.1) - 0.01), 0.8), 0.003, 0.5)
    big = load(os.path.join(dl, 'ship_destroyed_short.ogg')); made['blast'] = fade(norm(seg(big, onset(big) - 0.01, onset(big) + 8.0)), 0.003, 2.5)
    ch = load(os.path.join(dl, 'chunky_explosion.mp3')); made['hit_big'] = fade(norm(seg(ch, onset(ch) - 0.01)), 0.003, 1.0)
    # missile launch: ignition and the booster's roar
    la = load(os.path.join(dl, 'x_launch', 'launch', 'launch.wav')); made['launch'] = fade(norm(seg(la, 1.55, 5.0), 0.8), 0.12, 1.2)   # (from 1.55 s: the first second of the recording is near silence, and the missile had left before it was heard)
    # automatic weapons from recorded transients at their rate of fire
    dull = load(os.path.join(dl, 'explosion_dull.flac')); dull = seg(dull, onset(dull) - 0.002)
    crack = load(os.path.join(dl, 'x_sfx100', 'shot_02.ogg')); crack = seg(crack, onset(crack) - 0.002)
    t20 = mix((dull, 0, 1.0), (crack, 0, 0.8))
    made['ciws_1'] = norm(fade(lowpass(auto(t20, 75.0, 0.42, 1, 0.03, 0.15), 7000), 0.004, 0.12))       # Phalanx: ~4,500 rounds a minute
    made['ciws_2'] = norm(fade(lowpass(auto(t20, 75.0, 0.42, 2, 0.03, 0.15), 7000), 0.004, 0.12))
    made['oerlikon'] = norm(fade(auto(t20, 7.6, 0.5, 3), 0.002, 0.15))                                       # 20 mm: ~450 a minute
    pom = seg(shot, so - 0.003, so + 0.35)
    made['bofors'] = norm(fade(mix((auto(pom, 4.0, 0.55, 4, 0.12, 0.35), 0, 1.0)), 0.002, 0.2))            # quad 40 mm: two pairs a second
    # engines and the sea: the battleship ambience over the Kuna's engine room heard through the hull
    amb = load(os.path.join(nv, 'BattleShipMovementAmbient.wav')); made['sea_ambient'] = norm(loop(amb, 0.8), 0.7)
    kuna = load(os.path.join(dl, 'kuna_engine.ogg')); k = seg(kuna, 30.0, 52.0); made['engine_room'] = norm(loop(lowpass(k, 900), 1.0), 0.7)
    # the open sea for the chart: the four wave recordings run together into one loop; gulls as separate calls
    wv = [load(os.path.join(dl, 'waves_%d.flac' % i)) for i in range(1, 5)]; xf = int(0.8 * RATE); bed = wv[0]
    for w in wv[1:]: k = np.linspace(0, 1, xf); bed = np.concatenate([bed[:-xf], bed[-xf:] * (1 - k) + w[:xf] * k, w[xf:]])
    made['sea_bed'] = norm(loop(bed, 1.5), 0.6)
    for i, n in enumerate([1, 2, 3, 5, 6]):
        g = load(os.path.join(dl, 'gull_%d.wav' % n))
        # two of these recordings are nearly all wind rumble below 150 Hz (measured: 98% of their energy, the call itself 30 dB down):
        # everything under 900 Hz is taken off, which leaves the gull and nothing else
        G = np.fft.rfft(g); fr = np.fft.rfftfreq(len(g), 1.0 / RATE); G *= 1.0 / (1.0 + (900.0 / np.maximum(fr, 1.0)) ** 8); g = np.fft.irfft(G, len(g))
        made['gull_%d' % (i + 1)] = fade(norm(seg(g, max(0.0, onset(g, 0.05) - 0.05)), 0.7), 0.01, 0.4)
    for name, x in made.items(): print('%-12s %.2f s' % (name, len(x) / RATE)); write(out, name, x)
    used = {'gun_heavy_1': ['cannon_fire.ogg', 'naval.7z'], 'gun_heavy_2': ['cannon_fire.ogg', 'naval.7z'], 'gun_medium': ['naval.7z'], 'gun_small': ['naval.7z'],
            'hit_1': ['cannon_hit_ship_short.ogg'], 'hit_2': ['naval.7z'], 'splash_1..4': ['naval.7z'], 'blast': ['ship_destroyed_short.ogg'], 'hit_big': ['chunky_explosion.mp3'],
            'launch': ['launch.7z'], 'ciws_1/2, oerlikon': ['explosion_dull.flac', 'sfx100.zip'], 'bofors': ['naval.7z'], 'sea_ambient': ['naval.7z'], 'engine_room': ['kuna_engine.ogg'], 'sea_bed': ['waves_1.flac'], 'gull_1..5': ['gull_1.wav']}
    lines = ['# Sound credits', '', 'Built by `tools/build_sfx.py` from these recordings (trimmed, mixed, filtered and looped). CC0 and public-domain sources need no credit; they are listed so every file can be traced. The one CC BY 4.0 recording must be credited wherever the game is distributed.', '',
             '| File(s) here | Source | Author | Licence |', '| --- | --- | --- | --- |']
    for f, srcs in used.items():
        for sname in srcs:
            url, title, author, lic, page = SOURCES[sname]
            lines.append('| `%s` | [%s](%s) | %s | %s |' % (f, title, page, author, lic))
    lines += ['', 'CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ · CC0: https://creativecommons.org/publicdomain/zero/1.0/']
    open(os.path.join(out, 'CREDITS.md'), 'w').write('\n'.join(lines) + '\n')
    print('built', len(made), 'sounds into', out)

if __name__ == '__main__': main()
