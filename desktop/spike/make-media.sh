#!/usr/bin/env bash
# Test streams for the format check: 6 s each, different video/audio codecs.
set -euo pipefail
out="${1:?usage: make-media.sh <dir>}"; mkdir -p "$out"; cd "$out"
V="-f lavfi -i testsrc2=size=640x360:rate=25 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 6"
mk() { name=$1; shift; ffmpeg -hide_banner -loglevel error -y $V "$@" "$name"; echo "made $name"; }
mk h264_aac.ts   -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac        -f mpegts
mk h264_ac3.ts   -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a ac3        -f mpegts
mk h264_eac3.ts  -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a eac3       -f mpegts
mk hevc_aac.ts   -c:v libx265 -preset ultrafast -pix_fmt yuv420p -tag:v hvc1 -c:a aac -f mpegts
mk mpeg2_mp2.ts  -c:v mpeg2video -pix_fmt yuv420p -c:a mp2                      -f mpegts
mk h264_aac.mp4  -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac -movflags +faststart
# HLS (TS segments), the way most providers serve live streams.
mkdir -p hls_aac hls_ac3
ffmpeg -hide_banner -loglevel error -y $V -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac -f hls -hls_time 2 -hls_list_size 0 -hls_playlist_type vod hls_aac/index.m3u8
ffmpeg -hide_banner -loglevel error -y $V -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a ac3 -f hls -hls_time 2 -hls_list_size 0 -hls_playlist_type vod hls_ac3/index.m3u8
echo "made hls_aac, hls_ac3"
