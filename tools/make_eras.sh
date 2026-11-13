#!/bin/bash
# The eras clip (godot/tests/reel_eras.gd): a ship in the middle of the screen, firing, replaced by her successor from
# each era. No interface. Landscape, 1920x1080.   tools/make_eras.sh <out dir>
set -e
out=$(realpath "$1"); mkdir -p "$out"
cd "$(dirname "$0")/../godot"
XDG_DATA_HOME="$out/xdg" xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
  --fixed-fps 30 --write-movie "$out/eras.avi" res://tests/reel_eras.tscn 2>&1 | grep -i "SCRIPT ERROR\|frames at" || true
ffmpeg -v error -y -i "$out/eras.avi" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart "$out/iron_meridian_eras.mp4"
rm -f "$out/eras.avi"; echo "eras done"
