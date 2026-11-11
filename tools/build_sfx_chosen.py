# The sounds the owner chose on the listening page (11 Nov 2026): the recorded sonar ping, the battle-stations siren,
# the gong, the paper for pages, the propeller aircraft, fire, rain, thunder, storm wind and the bubbles of a ship
# going down. Built into godot/assets/sfx/ beside the others; their sources are added to CREDITS.md.
#
#   python3 -I tools/build_sfx_chosen.py <download dir>        (run after build_sfx.py: that one rewrites CREDITS.md)
#
# Needs ffmpeg and numpy. Downloads go into the given (fresh, empty) directory; nothing from it is executed.
import os, sys, subprocess, zipfile, urllib.request, ssl
import numpy as np
OGA = 'https://opengameart.org/sites/default/files/'
SOURCES = {   # file: (url, title, author, licence, page)
    'sonar_ping.mp3': (OGA + 'sonar_ping_0.mp3', 'Sonar Ping', 'Spiceman', 'CC0', 'https://opengameart.org/content/sonar-ping'),
    'siren.mp3': (OGA + 'siren_0.mp3', 'Sirens and Alarm Noise', 'aquinn', 'CC0', 'https://opengameart.org/content/sirens-and-alarm-noise'),
    'sfx100.zip': (OGA + '100-CC0-SFX_0.zip', '100 CC0 SFX', 'rubberduck', 'CC0', 'https://opengameart.org/content/100-cc0-sfx'),
    'sfx_loops.zip': (OGA + 'sfx_loops.zip', '30 CC0 SFX loops', 'rubberduck', 'CC0', 'https://opengameart.org/content/30-cc0-sfx-loops'),
    'prop.ogg': (OGA + 'airplane_prop_0.ogg', 'Airplane Prop Loop', 'AntumDeluge', 'CC BY 3.0', 'https://opengameart.org/content/airplane-prop-loop'),
    'fire.ogg': (OGA + 'fire-1_0.ogg', 'Fire Crackling', 'AntumDeluge', 'CC0', 'https://opengameart.org/content/fire-crackling'),
    'rain_night.ogg': (OGA + 'Dark_Rainy_Night%28ambience%29.ogg', 'rain and thunders', 'kindland', 'CC0', 'https://opengameart.org/content/rain-and-thunders'),
    'storm_siren.ogg': (OGA + 'storm_3_siren.ogg', 'Storm & Siren', 'TinyWorlds', 'CC0', 'https://opengameart.org/content/storm-siren'),
    'bubbles.wav': (OGA + 'bubbles-loop1-amp.wav', 'Bubble Sound Effects', 'BMacZero', 'CC0', 'https://opengameart.org/content/bubble-sound-effects'),
}
USED = {'ping': 'sonar_ping.mp3', 'siren': 'siren.mp3', 'gong': 'sfx100.zip', 'paper': 'sfx100.zip', 'rain_loop': 'sfx_loops.zip', 'prop_loop': 'prop.ogg', 'fire_loop': 'fire.ogg',
        'thunder_loop': 'rain_night.ogg', 'storm_loop': 'storm_siren.ogg', 'bubbles_loop': 'bubbles.wav'}
RATE = 32000
def fetch(dl):
    ctx = ssl.create_default_context(cafile='/root/.ccr/ca-bundle.crt') if os.path.exists('/root/.ccr/ca-bundle.crt') else ssl.create_default_context()
    for name, (url, *_ ) in SOURCES.items():
        p = os.path.join(dl, name)
        if os.path.exists(p): continue
        with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (game asset build)'}), context=ctx, timeout=180) as r: open(p, 'wb').write(r.read())
    for z in ['sfx100.zip', 'sfx_loops.zip']: zipfile.ZipFile(os.path.join(dl, z)).extractall(os.path.join(dl, 'x_' + z[:-4]))
def find(dl, sub, name):
    for root, _, files in os.walk(os.path.join(dl, sub)):
        if name in files: return os.path.join(root, name)
    raise FileNotFoundError(name)
def load(path, t0=0.0, t1=None):
    cmd = ['ffmpeg', '-v', 'quiet', '-ss', str(t0)] + (['-t', str(t1 - t0)] if t1 else []) + ['-i', path, '-ac', '1', '-ar', str(RATE), '-f', 'f32le', '-']
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32).astype(np.float64)
def fade(x, fin=0.005, fout=0.2):
    x = x.copy(); a, b = min(int(fin * RATE), len(x) // 4), min(int(fout * RATE), len(x) // 2)
    if a: x[:a] *= np.linspace(0, 1, a)
    if b: x[-b:] *= np.linspace(1, 0, b)
    return x
def level(x, rms_db=-20.0, peak=0.89):
    # to a set loudness (RMS), but never past the peak allowed
    r = np.sqrt(np.mean(x * x)) + 1e-9; g = (10 ** (rms_db / 20.0)) / r
    return x * min(g, peak / (np.abs(x).max() + 1e-9))
def loop(x, xf=0.6):
    # the tail is faded into the head, so the end runs into the beginning without a step
    f = min(int(xf * RATE), len(x) // 3); k = np.linspace(0, 1, f); y = x[f:].copy(); y[-f:] = y[-f:] * (1 - k) + x[:f] * k
    return y
def highpass(x, hz):
    X = np.fft.rfft(x); fr = np.fft.rfftfreq(len(x), 1.0 / RATE); X *= 1.0 / (1.0 + (hz / np.maximum(fr, 1.0)) ** 4); return np.fft.irfft(X, len(x))
def write(out, name, x):
    raw = np.clip(x, -1, 1).astype(np.float32).tobytes()
    subprocess.run(['ffmpeg', '-v', 'quiet', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', '5', os.path.join(out, name + '.ogg')], input=raw, check=True)
def main():
    dl = sys.argv[1]; out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'assets', 'sfx')
    os.makedirs(dl, exist_ok=True); fetch(dl); made = {}
    made['ping'] = fade(level(load(os.path.join(dl, 'sonar_ping.mp3')), -20.0), 0.003, 0.3)
    made['siren'] = fade(level(load(os.path.join(dl, 'siren.mp3'), 0.0, 7.0), -18.0), 0.05, 1.2)          # the first rise of it: battle stations
    made['gong'] = fade(level(load(find(dl, 'x_sfx100', 'gong_01.ogg')), -20.0), 0.002, 0.4)
    made['paper'] = fade(level(load(find(dl, 'x_sfx100', 'paper_01.ogg')), -24.0), 0.002, 0.1)
    made['rain_loop'] = level(loop(load(find(dl, 'x_sfx_loops', 'rain.ogg')), 0.5), -24.0)
    made['prop_loop'] = level(loop(load(os.path.join(dl, 'prop.ogg')), 0.4), -20.0)
    made['fire_loop'] = level(loop(highpass(load(os.path.join(dl, 'fire.ogg')), 120.0), 0.4), -24.0)
    made['thunder_loop'] = level(loop(load(os.path.join(dl, 'rain_night.ogg'), 20.0, 62.0), 2.0), -22.0)   # forty seconds of rain with thunder in it
    made['storm_loop'] = level(loop(highpass(load(os.path.join(dl, 'storm_siren.ogg'), 40.0, 72.0), 60.0), 2.0), -22.0)   # after the siren in the recording has died away
    made['bubbles_loop'] = level(loop(load(os.path.join(dl, 'bubbles.wav')), 0.5), -22.0)
    for name, x in made.items(): print('%-13s %.2f s' % (name, len(x) / RATE)); write(out, name, x)
    cp = os.path.join(out, 'CREDITS.md'); txt = open(cp).read(); mark = '\n## Chosen by the owner, 11 Nov 2026\n'
    txt = txt.split(mark)[0].rstrip('\n') + '\n'
    lines = [mark.strip('\n'), '', 'Built by `tools/build_sfx_chosen.py`.', '', '| File here | Source | Author | Licence |', '| --- | --- | --- | --- |']
    for f, s in USED.items():
        url, title, author, lic, page = SOURCES[s]; lines.append('| `%s` | [%s](%s) | %s | %s |' % (f, title, page, author, lic))
    lines += ['', 'CC BY 3.0: https://creativecommons.org/licenses/by/3.0/']
    open(cp, 'w').write(txt + '\n' + '\n'.join(lines) + '\n')
    print('built', len(made), 'chosen sounds into', out)
if __name__ == '__main__': main()
