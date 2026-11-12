#!/bin/bash
# Records the Reels clips (godot/tests/reel.gd) upright at 1080x1920 and turns them into MP4.
# (The game was raised 20 dB on 11 Nov 2026 at the owner's choice: clips need no gain of their own now.)
#   tools/make_reels.sh <out dir> [clips...]      (needs xvfb-run, ffmpeg; about three minutes a clip without a GPU)
#   UI=1 tools/make_reels.sh ...                 records with the interface on (files end in _ui); "chart" is the chart clip
set -e
out=$(realpath "$1"); shift; mkdir -p "$out"
clips=${@:-duel night destroyers torpedo fleet carrier_launch carrier_strike carrier_landing carrier_jets sub_attack sub_hunt}
cd "$(dirname "$0")/../godot"
for c in $clips; do
  sfx=""; mode=""; [ -n "$UI" ] && { sfx="_ui"; mode="ui"; }
  if [ "$c" = chart ]; then scene=res://tests/reel_chart.tscn; args="14 $mode"; else scene=res://tests/reel.tscn; args="$c 14 $mode"; fi
  XDG_DATA_HOME="$out/xdg" xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --resolution 1080x1920 \
    --fixed-fps 30 --write-movie "$out/$c.avi" $scene -- $args 2>&1 | grep -i "SCRIPT ERROR\|frames at" || true
  ffmpeg -v error -y -i "$out/$c.avi" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart "$out/iron_meridian_$c$sfx.mp4"
  rm -f "$out/$c.avi"; echo "$c done"
done
