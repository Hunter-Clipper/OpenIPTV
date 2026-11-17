#!/usr/bin/env bash
# Release gate: the APK must bundle SQLCipher (libsqlcipher.so) for every ABI.
# A build with plain SQLite cannot open anyone's encrypted database.
#   tools/check-apk-sqlcipher.sh [path/to/app-release.apk]
set -euo pipefail
apk="${1:-build/app/outputs/flutter-apk/app-release.apk}"
listing="$(unzip -l "$apk")"
fail=0
for abi in arm64-v8a armeabi-v7a x86_64; do
  if grep -q "lib/$abi/libsqlcipher.so" <<<"$listing"; then
    echo "ok   $abi has libsqlcipher.so"
  else
    echo "FAIL $abi has no libsqlcipher.so"; fail=1
  fi
done
if grep -q "lib/.*/libsqlite3.so" <<<"$listing"; then
  echo "FAIL plain libsqlite3.so is bundled"; fail=1
fi
exit $fail
