# OpenIPTV desktop shell (phase 0 spike)

An Electron window around the Flutter web build, with the browser's CORS and
mixed-content limits lifted for this app's own requests. Plan:
`docs/design/desktop.md` (on the `feature/27-windows-client` branch).

The format check reads hls.js / mpegts.js from the web client's `web/lib`, so
it needs the web client (PR #45) in the same checkout.

This is a **spike**: it exists to answer "does Electron play what IPTV
needs?", not to ship.

```
cd desktop && npm install
# 1. build the web app and point the shell at it
flutter build web --release        # from the repo root
OPENIPTV_WEB_ROOT=../build/web npx electron . --no-sandbox

# 2. format check (needs ffmpeg and a virtual display on a headless box)
spike/make-media.sh /tmp/otv-media
xvfb-run -a node spike/formats.mjs /tmp/otv-media

# 3. the real app against a provider that sends no CORS headers
xvfb-run -a node spike/app.mjs ../build/web http://<provider> /tmp
```

`--no-sandbox` is only for running inside a container or CI box; a shipped
build keeps Chromium's sandbox on.
