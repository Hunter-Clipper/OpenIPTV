# Power User Tools (issue #41)

Settings → **Advanced** → **Power User Tools**, at the very bottom of
Settings, admin profiles only. Tools for people who want to diagnose or
tune their connection to a provider. Everything works on phones, tablets
and TVs (D-pad friendly), and nothing leaves the device unless the user
taps a button that says where it goes.

## Phase 1 — Network info (this PR)

An info area answering "what is my device's connection right now?", for
diagnosing provider problems (IP bans, a wrong network, DNS blocks, a VPN
that isn't on):

| Row | Source |
|---|---|
| Connection | Wi-Fi / Ethernet / Mobile data / None (Android `ConnectivityManager`, active network) |
| VPN | On / Off (active network has `TRANSPORT_VPN`) |
| Device IP address | IPv4 / IPv6 of the active network (`LinkProperties`) — the address on the local network |
| Public IP address | Only on tap of **Check**: one HTTPS request to `api.ipify.org`, which returns the address providers see. Never automatic (no-telemetry promise). |
| DNS servers | From `LinkProperties` — helps spot DNS-based provider blocks |

Tap a row to copy it (phones). Refresh button re-reads everything.

## Phase 2 — Buffer size picker

Today the player uses fixed `DefaultLoadControl` values (start after 1 s,
resume after 2 s of rebuffer). A picker with plain-English presets —
**Fast start** (current), **Balanced**, **Smooth** (larger buffer for
unstable connections) — stored in prefs and applied when the native player
is created. Live streams keep a cap so they don't drift far from live.

## Phase 3 — Speed test

Two measurements, both on tap:
1. **To your provider** — download from the active playlist's own server
   for ~10 s (e.g. a live stream) and report Mbit/s. This is the number that
   matters for buffering, and it contacts no one but the provider.
2. **General internet** (optional) — a public speed-test file. Needs an
   owner decision on which service (it's a third party).

## Phase 4 — Built-in VPN (needs decisions)

- **WireGuard:** import a `.conf` file or QR code, connect/disconnect,
  status. Uses Android's `VpnService` with the official WireGuard Android
  library (`com.wireguard.android:tunnel`, Apache-2.0 — compatible with
  GPL-3.0). Can route only OpenIPTV or the whole device.
- **OpenVPN:** the common Android library (ics-openvpn) is GPL-2.0-only,
  which can't be combined with this GPL-3.0 app. Options: OpenVPN 3 core
  (AGPL/commercial), handing `.ovpn` files to the official OpenVPN Connect
  app, or WireGuard only. **Owner decision needed.**
- TVs: VpnService works on Android TV; import via file (adb/Downloads) since
  TVs can't scan QR codes.
