#!/bin/bash
# The "wolves hunt in packs" clip (godot/tests/reel_wolfpack.gd), recorded upright and captioned.
#   tools/make_wolfpack.sh <out dir> <Poppins-Bold.ttf>     (needs xvfb-run and ffmpeg)
set -e
out=$(realpath "$1"); font=$(realpath "$2"); mkdir -p "$out"
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/godot"
XDG_DATA_HOME="$out/xdg" xvfb-run -a -s "-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --resolution 1080x1920 \
  --fixed-fps 30 --write-movie "$out/wolf.avi" res://tests/reel_wolfpack.tscn 2>&1 | grep -i "SCRIPT ERROR\|frames at" || true
tag="$root/godot/assets/fonts/BarlowCondensed-SemiBold.ttf"
# captions fade in and out; the tag stays (white, with a dark border, as on the earlier clips)
cap() { echo "drawtext=fontfile='$font':text='$1':fontsize=84:fontcolor=white:borderw=7:bordercolor=black@0.9:x=(w-text_w)/2:y=$2:alpha='if(lt(t,$3),0,if(lt(t,$3+0.7),(t-$3)/0.7,if(lt(t,$4),1,if(lt(t,$4+0.9),1-(t-$4)/0.9,0))))'"; }
vf="$(cap 'Keep your fleet' 330 0.7 10.3),$(cap 'protected' 440 0.7 10.3),$(cap 'Because wolves' 330 16.4 99),$(cap 'hunt in packs' 440 16.4 99)"
vf="$vf,drawbox=x=(iw-380)/2:y=150:w=380:h=62:color=black@0.55:t=fill,drawbox=x=(iw-380)/2:y=150:w=380:h=62:color=0xE3B23C@0.9:t=2,drawtext=fontfile='$tag':text='IN DEVELOPMENT':fontsize=40:fontcolor=0xE3B23C:x=(w-text_w)/2:y=161"
ffmpeg -v error -y -i "$out/wolf.avi" -vf "$vf" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -af "afade=t=in:d=0.4,afade=t=out:st=21.0:d=0.9" -c:a aac -b:a 160k -movflags +faststart "$out/iron_meridian_wolfpack.mp4"
echo "wolfpack done"
