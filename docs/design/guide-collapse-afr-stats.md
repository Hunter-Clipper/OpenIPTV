# Guide category collapse, auto frame rate, anonymous stats (#148, #149, #150)

Status: plan only. Nothing is built yet. Each item can ship on its own.

## #148 Collapse the category column in the TV guide

When focus moves right into the guide, the category column shrinks (icons or
nothing) so the time grid gets the room. Moving Left back to the column
expands it. Lives in `TvGuideScreen`; the shared time offset and row focus
logic should not change, only the column width (animated, like the keyboard
tray).

Open questions: show icons while collapsed, or hide it completely? Should it
also collapse on the phone-sized tablet layout? (Default: TV only.)

## #149 Auto frame rate / auto resolution (TV and capable devices)

- Frame rate: Media3 can ask the display to match the video's frame rate
  (`setVideoChangeFrameRateStrategy`, Android 11+). Needs a Settings →
  Playback option: Off / Seamless only / Always, default Off until tested on
  the Chromecast and a 4K display.
- Resolution: choose a `Display.Mode` through the window's preferred display
  mode. Riskier (screen blanks on a switch), so ship frame rate first.
- Related: #140 (tearing on non-4K streams on a 4K display) may be linked.
  It is tabled until the reporter sends more detail.

Open questions: per-playlist or global setting? Does the Chromecast report
usable modes over HDMI?

## #150 Optional anonymous stats and crash reports

Owner requirements (from the issue): 100% anonymous, OFF by default for
everyone, one-time prompt for updating users, one-time step in the new-user
wizard, plain explanation, and the code must be small, well commented and
easy to audit (its own folder).

Principles to keep: collect nothing that identifies a person, playlist,
provider or stream. No URLs, hostnames, logins, channel or title names, IP
logging on the receiving side. The payload is shown to the user in-app
("See exactly what is sent") before they enable it.

Open questions (owner decisions needed before any code):
1. What is collected? Suggested minimum: app version, Android version and
   device model, crash stack traces with URLs and names stripped.
2. Where does it go and who stores it? Options: a self-hosted endpoint, or a
   third-party crash service. A third party means a new privacy policy and a
   service dependency, so a self-hosted receiver is the likely fit for an
   open-source, no-tracking project.
3. Wording of the two prompts, and a way to turn it off and view the payload
   in Settings.
4. Retention period and who can see the data.
