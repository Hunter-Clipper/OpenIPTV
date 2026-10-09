#!/usr/bin/env bash
# Fetches the pinned sources for OpenIPTV's built-in OpenVPN client
# (android/app/src/main/cpp) into android/.ovpn-deps (git-ignored).
# Gradle runs this automatically before the native build; run it by hand
# to pre-fetch. Every source is upstream and unmodified, except asio, which
# gets the patches OpenVPN ships in openvpn3/deps/vcpkg-ports/asio.
#
# Licences: openvpn3 (used under its MPL-2.0 option), asio BSL-1.0,
# fmt MIT, lz4 BSD-2, xxHash BSD-2, mbed TLS Apache-2.0.
set -euo pipefail

DEST="${1:-$(cd "$(dirname "$0")" && pwd)/.ovpn-deps}"
STAMP_VALUE="v1"
[ -f "$DEST/.ready" ] && [ "$(cat "$DEST/.ready")" = "$STAMP_VALUE" ] && exit 0

fetch() { # name url commit
  local dir="$DEST/$1"
  rm -rf "$dir"
  git init -q "$dir"
  git -C "$dir" remote add origin "$2"
  git -C "$dir" fetch -q --depth 1 origin "$3"
  git -C "$dir" checkout -q FETCH_HEAD
}

mkdir -p "$DEST"
fetch openvpn3 https://github.com/OpenVPN/openvpn3.git 2f74c607f56294e39c9fab253f6dd87a2ed6e9ab
fetch asio https://github.com/chriskohlhoff/asio.git 8806a6803cde7054c3049d3666d3ec36786568c5
fetch fmt https://github.com/fmtlib/fmt.git 123913715afeb8a437e6388b4473fcc4753e1c9a
fetch lz4 https://github.com/lz4/lz4.git ebb370ca83af193212df4dcbadcc5d87bc0de2f0
fetch xxHash https://github.com/Cyan4973/xxHash.git e626a72bc2321cd320e953a0ccf1584cad60f363
fetch mbedtls https://github.com/Mbed-TLS/mbedtls.git c765c831e5c2a0971410692f92f7a81d6ec65ec2
git -C "$DEST/mbedtls" submodule update -q --init --depth 1

for p in "$DEST"/openvpn3/deps/vcpkg-ports/asio/0*.patch; do
  (cd "$DEST/asio" && patch -p1 -s < "$p")
done

echo "$STAMP_VALUE" > "$DEST/.ready"
