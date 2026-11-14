#!/usr/bin/env python3
# Joins the shots recorded from godot/tests/reel_trio.gd into the three upright clips (the owner's request, 14 Nov 2026):
# long crossfades between shots (no quick cuts), the game's battle music under the game's own sound, a fade from and to
# black, the in-development tag, -14 LUFS.   python3 tools/make_trio.py <shots dir> <out dir> [clip ...]
import subprocess, sys, os, json
CLIPS = {
    "trailer": ["t_bismarck", "t_vanguard", "t_line", "t_kgv", "t_yamato"],
    "fletchers": ["f_column", "f_a150", "f_straddle", "f_end"],
    "generations": ["g_iowa", "g_montana", "g_tico", "g_thunder"],
}
XF = 1.2           # seconds each crossfade lasts
FONT = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"
MUSIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "music", "steel_and_seething.ogg")

def dur(f):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", f], capture_output=True, text=True).stdout
    return float(json.loads(out)["format"]["duration"])

def build(src, out, name):
    shots = [os.path.join(src, s + ".avi") for s in CLIPS[name]]
    lens = [dur(f) for f in shots]
    total = sum(lens) - XF * (len(shots) - 1)
    args = ["ffmpeg", "-v", "error", "-y"]
    for f in shots: args += ["-i", f]
    args += ["-i", MUSIC]
    fc = []
    for i in range(len(shots)):   # trim the first few frames of each recording (the scene being set up)
        fc.append(f"[{i}:v]trim=start=0.1,setpts=PTS-STARTPTS,fps=30,format=yuv420p[v{i}]")
        fc.append(f"[{i}:a]atrim=start=0.1,asetpts=PTS-STARTPTS,aresample=48000[a{i}]")
    lens = [l - 0.1 for l in lens]
    v, a, off = "v0", "a0", 0.0
    for i in range(1, len(shots)):
        off += lens[i - 1] - XF
        fc.append(f"[{v}][v{i}]xfade=transition=fade:duration={XF}:offset={off:.3f}[vx{i}]")
        fc.append(f"[{a}][a{i}]acrossfade=d={XF}:c1=tri:c2=tri[ax{i}]")
        v, a = f"vx{i}", f"ax{i}"
    total = off + lens[-1]
    tag = (f"drawbox=x=230:y=1561:w=620:h=62:color=black@0.6:t=fill,"
           f"drawtext=fontfile={FONT}:text='IN DEVELOPMENT  ·  FOOTAGE NOT FINAL':fontsize=30:fontcolor=white@0.95:x=(w-text_w)/2:y=1581")
    fc.append(f"[{v}]eq=contrast=1.06:saturation=1.12,{tag},fade=t=in:st=0:d=0.8,fade=t=out:st={total - 1.2:.3f}:d=1.2[vout]")
    # the music a little under the guns, faded in and out with the picture
    fc.append(f"[{len(shots)}:a]atrim=0:{total:.3f},asetpts=PTS-STARTPTS,aresample=48000,volume=0.55,"
              f"afade=t=in:st=0:d=1.5,afade=t=out:st={total - 2.0:.3f}:d=2.0[mus]")
    fc.append(f"[{a}]volume=1.0[game]")
    fc.append(f"[game][mus]amix=inputs=2:normalize=0:duration=first,afade=t=out:st={total - 1.2:.3f}:d=1.2,"
              f"loudnorm=I=-14:TP=-1.5:LRA=11[aout]")
    args += ["-filter_complex", ";".join(fc), "-map", "[vout]", "-map", "[aout]", "-t", f"{total:.3f}",
             "-c:v", "libx264", "-crf", "18", "-preset", "medium", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", os.path.join(out, f"iron_meridian_{name}.mp4")]
    subprocess.run(args, check=True)
    print(f"{name}: {total:.1f} s from {len(shots)} shots")

if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
    for n in (sys.argv[3:] or list(CLIPS)): build(src, out, n)
