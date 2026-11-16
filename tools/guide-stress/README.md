# TV guide stress test

Measures how smooth the TV guide is on a real device.

1. Build with the frame logger on:
   `flutter build apk --release --dart-define=OPENIPTV_GUIDE_PERF=true`
2. Install, open Live TV, go into the guide (focus on a programme cell).
3. `tools/guide-stress/stress.sh <seed> <keys> <delay>` sends random
   D-pad presses over adb (`ADB_SERIAL` selects the device) and prints one
   `[OTV-perf]` line per 60 frames: slow frames (>33 ms), build/raster times.

Reference on the Chromecast (200 random keys, 50 ms apart): before the
2026-11 rework 20-40 % of frames were slow with 150-400 ms builds; after it
about 5-10 % with a 30-40 ms 95th percentile.
