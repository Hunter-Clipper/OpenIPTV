#!/bin/bash
# Makes a 60 s live-style MPEG-TS test stream where every frame carries its own
# frame number, drawn three times (top, middle, bottom) as 12 green blocks,
# plus a fast white bar for motion. A torn frame (part of the picture from one
# video frame, part from another) then shows up as different numbers in the
# three places. Used by tear.py (#157). Needs ffmpeg.
#
#   tools/tear-test/make-stream.sh out.ts
set -euo pipefail
out=${1:?usage: make-stream.sh out.ts}
vf="drawbox=x='mod(t*60*37\,1200)':y=0:w=80:h=720:color=white:t=fill"
for y in 20 330 640; do
  for k in $(seq 0 11); do
    vf="$vf,drawbox=x=$((20+k*40)):y=$y:w=36:h=60:color=lime:t=fill:enable='eq(mod(floor(t*60/$((1<<k)))\,2)\,1)'"
  done
done
ffmpeg -loglevel error -y -f lavfi -i "color=c=black:s=1280x720:r=60,format=yuv420p" \
  -f lavfi -i "sine=frequency=440:sample_rate=48000" -t 60 -vf "$vf" \
  -c:v libx264 -preset veryfast -g 120 -pix_fmt yuv420p -b:v 6M -c:a aac -b:a 96k \
  -f mpegts "$out"
echo "wrote $out — serve it over HTTP and add it to a test M3U playlist"
