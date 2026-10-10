# Native libraries in the Android app

Besides the Dart/Flutter and Android packages listed in `pubspec.yaml` and
`android/app/build.gradle.kts`, the Android app compiles these C/C++
libraries into `libopeniptv_ovpn.so` (the built-in OpenVPN client,
Settings → Power User Tools). They are fetched unmodified at the pinned
commits in [`android/openvpn-deps.sh`](../android/openvpn-deps.sh) and
built from source with every app build.

| Library | Licence | Notes |
|---|---|---|
| [OpenVPN 3 core](https://github.com/OpenVPN/openvpn3) | MPL-2.0 (chosen of its AGPL-3.0 / MPL-2.0 dual licence) | unmodified |
| [Asio](https://github.com/chriskohlhoff/asio) | BSL-1.0 | with the patches OpenVPN ships in `openvpn3/deps/vcpkg-ports/asio` |
| [Mbed TLS](https://github.com/Mbed-TLS/mbedtls) | Apache-2.0 | unmodified |
| [{fmt}](https://github.com/fmtlib/fmt) | MIT | header-only |
| [LZ4](https://github.com/lz4/lz4) | BSD-2-Clause | `lib/lz4.c` |
| [xxHash](https://github.com/Cyan4973/xxHash) | BSD-2-Clause | header-only |

The WireGuard VPN uses the official
[WireGuard Android tunnel library](https://git.zx2c4.com/wireguard-android)
(`com.wireguard.android:tunnel`, Apache-2.0) from Maven Central.

The source for all of the above is available at the links and commits
given; OpenIPTV's own bridge code is in `android/app/src/main/cpp/`.
