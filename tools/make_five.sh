#!/bin/bash
# Five staged portrait clips with no interface (godot/tests/reel_five.gd).   tools/make_five.sh <out dir> [clips]
# Each is recorded frame by frame at 30 fps with the game's sound, given the in-development tag and levelled to -14 LUFS.
out=$(realpath "$1"); shift; mkdir -p "$out"
clips="$@"; [ -z "$clips" ] && clips="shell eras yamato sinking night"
cd "$(dirname "$0")/../godot"
FONT=/usr/share/fonts/opentype/inter/Inter-SemiBold.otf
for c in $clips; do
  XDG_DATA_HOME="$out/xdg_$c" xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --resolution 1080x1920 \
    --fixed-fps 30 --write-movie "$out/$c.avi" res://tests/reel_five.tscn -- $c 2>&1 | grep -i "SCRIPT ERROR\|Parse Error" -A2
  ffmpeg -v error -y -i "$out/$c.avi" -vf "eq=contrast=1.06:saturation=1.12,drawbox=x=230:y=1561:w=620:h=62:color=black@0.6:t=fill,drawtext=fontfile=$FONT:text='IN DEVELOPMENT  ·  FOOTAGE NOT FINAL':fontsize=30:fontcolor=white@0.95:x=(w-text_w)/2:y=1581" \
    -af loudnorm=I=-14:TP=-1.5:LRA=11 -c:v libx264 -crf 18 -preset medium -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart "$out/iron_meridian_$c.mp4"
  echo "$c done"
done
