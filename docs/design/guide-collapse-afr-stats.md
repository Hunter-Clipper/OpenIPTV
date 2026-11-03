# Guide category collapse, auto frame rate, anonymous stats (#148, #149, #150)

Status: owner decisions recorded 2026-11-03. Each item can ship on its own.

## #148 Collapse the category column in the TV guide — DONE (0.14.49)

Built and confirmed by the owner on TV and phone, 2026-11-03.

When focus moves right into the guide, the category column shrinks (icons or
nothing) so the time grid gets the room. Moving Left back to the column
expands it. Lives in `TvGuideScreen`; the shared time offset and row focus
logic should not change, only the column width (animated, like the keyboard
tray).

**Decided:** icons only while collapsed; TV only.

## #149 Auto frame rate / auto resolution (TV and capable devices) — frame rate DONE (0.14.50)

Frame rate matching built as `FrameRateMatcher.kt` plus Settings → Playback → Match Frame Rate (off by default), confirmed by the owner on the Chromecast, 2026-11-03. Resolution switching is still to do. The text below is the original plan.

- Frame rate: Media3 can ask the display to match the video's frame rate
  (`setVideoChangeFrameRateStrategy`, Android 11+). Needs a Settings →
  Playback option: Off / Seamless only / Always, default Off until tested on
  the Chromecast and a 4K display.
- Resolution: choose a `Display.Mode` through the window's preferred display
  mode. Riskier (screen blanks on a switch), so ship frame rate first.
- Related: #140 (tearing on non-4K streams on a 4K display) may be linked.
  It is tabled until the reporter sends more detail.

**Decided:** one global setting; frame rate first, resolution later; don't
wait for #140. Still to check on device: does the Chromecast report usable
modes over HDMI?

## #150 Optional anonymous stats and crash reports

Owner requirements (from the issue): 100% anonymous, OFF by default for
everyone, one-time prompt for updating users, one-time step in the new-user
wizard, plain explanation, and the code must be small, well commented and
easy to audit (its own folder).

Principles to keep: collect nothing that identifies a person, playlist,
provider or stream. No URLs, hostnames, logins, channel or title names, IP
logging on the receiving side. The payload is shown to the user in-app
("See exactly what is sent") before they enable it.

**Decided:**
1. Collect only what is needed to fix problems: app version, Android version,
   device model, crash traces. Never URLs, hostnames, logins, channel or
   title names.
2. Self-hosted receiver, stored in a Cloudflare R2 bucket.
3. Only the owner can see it; kept 90 days (bucket lifecycle rule).
4. Settings shows exactly what is sent, before and after opting in.
5. A Settings toggle as well as the two one-time prompts (updating users,
   new-user wizard).

Still to design: the receiving endpoint (a small Cloudflare Worker writing to
R2 is the obvious fit), abuse limits, and the exact payload fields.
