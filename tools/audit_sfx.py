#!/usr/bin/env python3
"""Measures every sound in godot/assets/sfx (or the files given): length, loudness, peak, how much silence leads and
trails it, how bright it is, and whether it clips. The agent cannot hear; this is how the sounds are checked.
  python3 tools/audit_sfx.py [files...]      (needs ffmpeg and numpy)"""
import sys, subprocess, glob, os
import numpy as np
RATE = 44100
def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)
def lufs(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    i = tp = None
    for line in out.splitlines():
        s = line.strip()
        if s.startswith("I:") and "LUFS" in s: i = float(s.split()[1])
        if s.startswith("Peak:") and "dBFS" in s: tp = float(s.split()[1])
    return i, tp
def measure(path):
    x = load(path)
    if len(x) == 0: return None
    peak = float(np.max(np.abs(x))); rms = float(np.sqrt(np.mean(x * x)))
    thr = max(peak * 0.02, 1e-4); loud = np.nonzero(np.abs(x) > thr)[0]
    lead = loud[0] / RATE if len(loud) else 0.0; tail = (len(x) - 1 - loud[-1]) / RATE if len(loud) else 0.0
    n = 1 << 14; seg = x[:n * (len(x) // n)].reshape(-1, n) if len(x) >= n else np.pad(x, (0, n - len(x))).reshape(1, n)
    sp = np.mean(np.abs(np.fft.rfft(seg * np.hanning(n), axis=1)) ** 2, axis=0); f = np.fft.rfftfreq(n, 1 / RATE)
    cen = float(np.sum(f * sp) / max(np.sum(sp), 1e-12)); low = float(np.sum(sp[f < 150]) / max(np.sum(sp), 1e-12))
    att = 0.0   # time from the first sound to the loudest 10 ms
    if len(loud):
        env = np.convolve(np.abs(x), np.ones(441) / 441, mode="same"); att = (int(np.argmax(env)) - loud[0]) / RATE
    i, tp = lufs(path)
    return {"len": len(x) / RATE, "peak_db": 20 * np.log10(max(peak, 1e-9)), "rms_db": 20 * np.log10(max(rms, 1e-9)), "lufs": i, "tp": tp, "lead": lead, "tail": tail,
            "centroid": cen, "low": low, "attack": max(att, 0.0), "clip": int(np.sum(np.abs(x) > 0.999)), "dc": float(np.mean(x))}
if __name__ == "__main__":
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "sfx", "*.ogg")))
    print("%-18s %6s %7s %7s %7s %6s %6s %7s %5s %7s %5s" % ("file", "len s", "LUFS", "peak dB", "rms dB", "lead", "tail", "bright", "<150", "attack", "clip"))
    for p in files:
        m = measure(p)
        if m is None: print("%-18s (empty)" % os.path.basename(p)); continue
        print("%-18s %6.2f %7s %7.1f %7.1f %6.2f %6.2f %6.0fHz %4.0f%% %6.0fms %5d" % (os.path.basename(p)[:18], m["len"], ("%.1f" % m["lufs"]) if m["lufs"] is not None else "-", m["peak_db"], m["rms_db"], m["lead"], m["tail"], m["centroid"], m["low"] * 100, m["attack"] * 1000, m["clip"]))
