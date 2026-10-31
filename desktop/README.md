# OpenIPTV desktop shell

An Electron window around the Flutter web build, with the browser's CORS and
mixed-content limits lifted for this app's own requests. Plan:
`docs/design/desktop.md` (on the `feature/27-windows-client` branch).

This branch is built on the web client's branch, so the web app and the shell
are in one checkout (CI: `.github/workflows/desktop.yml`). The `spike/`
scripts are the phase 0 format check and shell tests.

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

4. window behaviour: `xvfb-run -a node spike/window.mjs ../build/web` (needs
   `xdotool`).

`--no-sandbox` is only for running inside a container or CI box; a shipped
build keeps Chromium's sandbox on.
