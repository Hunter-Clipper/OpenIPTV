#!/usr/bin/env bash
# Upload a release's APKs to the Cloudflare R2 mirror (bucket openiptv-mirror).
# The in-app updater falls back to <mirror>/latest/<file> when GitHub fails
# (lib/core/services/update_service.dart). Run on EVERY release, after the
# GitHub release exists:   tools/mirror-release.sh vX.Y.Z
# Needs ~/.openiptv-cloudflare/env (CLOUDFLARE_API_TOKEN + ACCOUNT_ID).
# Only the newest release is kept: after uploading, every earlier version's
# copy (<oldtag>/...) is deleted (owner rule, 2026-11-16: no copy of the
# previous release in R2). Wrangler can't list a bucket, so the old versions
# come from CHANGELOG.md (mirroring began 2026-11-03); deleting a key that
# isn't there is harmless.
set -euo pipefail
tag="${1:?usage: tools/mirror-release.sh vX.Y.Z}"
root="$(cd "$(dirname "$0")/.." && pwd)"
apk="$root/build/app/outputs/flutter-apk/app-release.apk"
addon="$root/build/carvideo/outputs/apk/release/carvideo-release.apk"
set -a; . "$HOME/.openiptv-cloudflare/env"; set +a
cd "$root/tools/stats-worker"
put() { npx wrangler r2 object put "openiptv-mirror/$1" --file "$2" \
  --content-type application/vnd.android.package-archive --remote; }
# Must be the very files attached to the GitHub release (sizes are compared
# by the app).
want=$(gh release view "$tag" --json assets -q '.assets[]|select(.name=="app-release.apk").size')
[ "$(stat -c %s "$apk")" = "$want" ] || { echo "app-release.apk differs from the $tag release asset"; exit 1; }
put latest/app-release.apk "$apk"
put "$tag/app-release.apk" "$apk"
if [ -f "$addon" ]; then
  put latest/OpenIPTV-car-video.apk "$addon"
  put "$tag/OpenIPTV-car-video.apk" "$addon"
fi
# Delete the previous releases' copies.
del() { npx wrangler r2 object delete "openiptv-mirror/$1" --remote >/dev/null 2>&1 || true; }
for old in $(awk '/^## [0-9]+\.[0-9]+\.[0-9]+ — /{ if ($4 >= "2026-11-03") print "v"$2 }' "$root/CHANGELOG.md"); do
  [ "$old" = "$tag" ] && continue
  echo "removing $old from the mirror"
  del "$old/app-release.apk"
  del "$old/OpenIPTV-car-video.apk"
done
for h in https://openiptv-mirror.hunterclipper.com https://pub-0edfbe67bad843dea3904e2a16a01d62.r2.dev; do
  echo "$h: $(curl -sI -m 20 "$h/latest/app-release.apk" | grep -iE '^HTTP|content-length' | tr -d '\r' | tr '\n' ' ')"
done
