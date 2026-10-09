# Power User Tools (issue #41)

Settings → **Advanced** → **Power User Tools**, at the very bottom of
Settings, admin profiles only. Tools for people who want to diagnose or
tune their connection to a provider. Everything works on phones, tablets
and TVs (D-pad friendly), and nothing leaves the device unless the user
taps a button that says where it goes.

## Phase 1 — Network info ✅

An info area answering "what is my device's connection right now?", for
diagnosing provider problems (IP bans, a wrong network, DNS blocks, a VPN
that isn't on):

| Row | Source |
|---|---|
| Connection | Wi-Fi / Ethernet / Mobile data / None (Android `ConnectivityManager`, active network) |
| VPN | On / Off (active network has `TRANSPORT_VPN`) |
| Device IP address | IPv4 / IPv6 of the real (non-VPN) network (`LinkProperties`) — the address on the local network |
| VPN address | The tunnel's own address, only while a VPN is on |
| Public IP address | Only on tap of **Check**: one HTTPS request to `api.ipify.org`, which returns the address providers see. Never automatic (no-telemetry promise). |
| DNS servers | From `LinkProperties` — helps spot DNS-based provider blocks |

Tap a row to copy it (phones). Refresh button re-reads everything.

## Phase 2 — Buffer size picker ✅

Presets **Fast start** (default: 1 s / 2 s), **Balanced** (2.5 s / 5 s)
and **Smooth** (up to 120 s ahead, 4 s / 8 s), prefs `buffer_preset`.
ExoPlayer's LoadControl is fixed at build time, so `open()` carries the
preset and the native player rebuilds only when it changes. The stream
watchdog's patience follows the preset (freeze 4/7/12 s, connect 8/11/16 s)
so it never reconnects while a bigger buffer refills.

## Phase 3 — Speed test ✅

Two measurements, both on tap:
1. **To your provider** — download from the active playlist's own server
   for ~10 s (e.g. a live stream) and report Mbit/s. This is the number that
   matters for buffering, and it contacts no one but the provider.
2. **General internet** — 25 MB from `speed.cloudflare.com` (named on
   screen; it refuses larger single downloads).

## Phase 4 — Built-in VPN (WireGuard ✅, OpenVPN ✅)

- **WireGuard ✅:** import a `.conf` file, connect/disconnect, live
  traffic + last handshake, route only OpenIPTV (default) or the whole
  device, connect when the app opens. `VpnController.kt` + the official
  `com.wireguard.android:tunnel` (Apache-2.0). Profile in secure storage.
  Adds ~11 MB to the universal APK. QR import: not yet.
- **OpenVPN ✅:** OpenVPN 3 core under its MPL-2.0 option (ics-openvpn is
  GPL-2.0-only, so not usable), mbed TLS, built from pinned sources by
  `android/openvpn-deps.sh` + CMake (`android/app/src/main/cpp`), JNI bridge
  → `OpenVpnService` (VpnService). Import .ovpn, optional username/password
  (secure storage, "Change OpenVPN login"), same routing and auto-connect
  as WireGuard; one VPN at a time. ~10 MB more APK; the first build fetches
  the sources and compiles for ~6 min (cached after). Licences:
  `docs/THIRD_PARTY_NATIVE.md`.
- TVs: VpnService works on Android TV; import via file (adb/Downloads) since
  TVs can't scan QR codes.
