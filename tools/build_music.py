# The game's music, chosen by the owner on the listening page (11 Nov 2026): three pieces by Kevin MacLeod
# (incompetech.com, CC BY 4.0: the credit is on the main menu and in godot/assets/music/CREDITS.md).
#
#   python3 -I tools/build_music.py <download dir>        (needs ffmpeg; nothing downloaded is executed)
#
# Each is levelled to the same loudness (-20 LUFS) and given a short fade at each end, so that a piece never starts
# or stops with a step; the game fades between pieces itself (Sfx.music).
import os, sys, subprocess, urllib.request, urllib.parse, ssl
BASE = 'https://incompetech.com/music/royalty-free/mp3-royaltyfree/'
TRACKS = {'lost_frontier': ('Lost Frontier', 'the main menu'), 'long_note_two': ('Long Note Two', 'the chart'), 'steel_and_seething': ('Steel and Seething', 'battle')}
def main():
    dl = sys.argv[1]; os.makedirs(dl, exist_ok=True)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'assets', 'music'); os.makedirs(out, exist_ok=True)
    ctx = ssl.create_default_context(cafile='/root/.ccr/ca-bundle.crt') if os.path.exists('/root/.ccr/ca-bundle.crt') else ssl.create_default_context()
    for key, (title, where) in TRACKS.items():
        src = os.path.join(dl, key + '.mp3')
        if not os.path.exists(src):
            req = urllib.request.Request(BASE + urllib.parse.quote(title) + '.mp3', headers={'User-Agent': 'Mozilla/5.0 (game asset build)'})
            with urllib.request.urlopen(req, context=ctx, timeout=300) as r: open(src, 'wb').write(r.read())
        dur = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', src], capture_output=True, text=True).stdout.strip())
        af = 'loudnorm=I=-20:TP=-2:LRA=20,afade=t=in:d=0.4,afade=t=out:st=%.2f:d=1.2' % max(0.0, dur - 1.2)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', src, '-af', af, '-ar', '44100', '-ac', '2', '-c:a', 'libvorbis', '-q:a', '5', os.path.join(out, key + '.ogg')], check=True)
        print('%-20s %.0f s  for %s' % (key, dur, where))
    lines = ['# Music credits', '', 'Built by `tools/build_music.py`. Chosen by the owner, 11 Nov 2026.', '', '| File here | Piece | Composer | Licence | Used |', '| --- | --- | --- | --- | --- |']
    for key, (title, where) in TRACKS.items(): lines.append('| `%s` | "%s" | Kevin MacLeod (incompetech.com) | CC BY 4.0 | %s |' % (key, title, where))
    lines += ['', 'Licensed under Creative Commons: By Attribution 4.0, https://creativecommons.org/licenses/by/4.0/ (levelled and faded at the ends).']
    open(os.path.join(out, 'CREDITS.md'), 'w').write('\n'.join(lines) + '\n')
if __name__ == '__main__': main()
