<h1 align="center">MacBreak</h1>

<p align="center">
  <b>A break reminder for macOS that you can't click away.</b><br>
  Rest your eyes every 30 minutes. Get out of your chair every 2 hours.<br>
  <a href="https://macbreak.vercel.app">macbreak.vercel.app</a>
</p>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey">
  <img alt="language" src="https://img.shields.io/badge/Swift-AppKit-orange">
  <img alt="dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen">
  <img alt="xcode" src="https://img.shields.io/badge/Xcode-not%20required-blue">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-black">
</p>

---

MacBreak is a free, open-source **eye strain and RSI break timer** for Mac. It is
a single background app — no Dock icon, no Electron, no account, no telemetry —
that takes the screen when it is time to rest, and gives it back when you have
actually rested.

It follows the **20-20-20 rule** for eyes and adds a longer movement break for
the rest of you:

| Break | Default cadence | Default length | What you see |
| --- | --- | --- | --- |
| 👁️ **Look away** | every 30 min | 30 seconds | *"Look at something 20 metres away"* |
| 🚶 **Walk** | every 2 hours | 10 minutes | *"Take a lap — stairs count double"* |

```
MENU BAR (quiet until a break is close):

  ☕                      ← more than 5 minutes away
  ☕ 04:21                ← under 5 minutes, now it speaks up

  ┌────────────────────────┐        ┌──────────────────────────────────────┐
  │ Look away in 28:14     │        │  MacBreak Preferences                │
  │ Walk in 1:42:09        │        │                                      │
  ├────────────────────────┤        │  Look away every          [ 30 ] min │
  │ Look Away Now          │        │  Look away for            [ 30 ] sec │
  │ Take Walk Break Now    │        │  Walk break every        [ 120 ] min │
  │ Pause                  │        │  Walk for                 [ 10 ] min │
  ├────────────────────────┤        │  Snooze length            [ 10 ] min │
  │ Preferences…           │        │  Screen lock resets after  [ 5 ] min │
  │ Quit MacBreak          │        │  Show menu bar timer under [ 5 ] min │
  └────────────────────────┘        │  ☑ Start at login                    │
                                    │                          [ Save ]    │
                                    └──────────────────────────────────────┘

THE OVERLAY (blurred desktop behind it, SF Rounded, muted colours):

  ╭────────────────────────────────────────────────────╮
  │                                                    │
  │                 Rest your eyes                     │
  │        Roll your eyes slowly — clockwise           │
  │                                                    │
  │                    00:23                           │
  │                                                    │
  │   Unclench your jaw · Drop your shoulders · Breathe│
  │                                                    │
  │      [ Done in 23s ]      [ Snooze 10 min ]        │
  │         ^ locked until the rest is over            │
  ╰────────────────────────────────────────────────────╯
```

## Why another break timer

Most break reminders are a notification you dismiss without reading. MacBreak
takes the screen instead, and **does not give it back early**:

- **Done stays locked** until the rest countdown reaches zero. The countdown is the point.
- **It never auto-dismisses.** Walk away for the full ten minutes and it is still waiting when you return — no missed break, no guessing.
- Covers **every display**, at `NSWindow.Level.screenSaver`, across all Spaces and over full-screen apps.
- Re-asserts focus every 0.7s, so an app that steals focus doesn't win.
- Swallows keystrokes, so reflex typing doesn't reach the app underneath.

Snooze is always one click away. This is a nudge with teeth, not a kiosk lock.

### It knows when you've already rested

Locking your screen **is** a break. If the screen was locked for five minutes or
more, unlocking restarts both clocks — no look-away thirty seconds after you sit
back down from lunch. Shorter locks leave the clocks alone.

Finishing a walk resets the eye clock too. Finishing a look-away leaves the walk
clock running.

### It stays out of the menu bar

The status item is just `☕` most of the day. It only shows a countdown once a
break is within five minutes — configurable, or set it high if you like watching
numbers.

## Install

### Homebrew

```bash
brew install --cask deepakk33/tap/macbreak
open -a MacBreak     # then tick "Start at login"
```

### One line, built from source

```bash
curl -fsSL https://raw.githubusercontent.com/deepakk33/macbreak/main/scripts/bootstrap.sh | bash
```

Clones into `~/.local/share/macbreak`, compiles, and registers the login agent.
Nothing pre-built is downloaded, so there is no Gatekeeper prompt and nothing to
trust that you cannot read first.

### From a clone

```bash
git clone https://github.com/deepakk33/macbreak.git
cd macbreak
make install
```

All three compile the sources (or, with Homebrew, fetch a release build), put
`MacBreak.app` in `/Applications`, and leave you with a menu bar app that starts
at login.

**Requirements:** macOS 13+ and Swift tooling. `xcode-select --install` is
enough — the full Xcode app is not needed, and there is no `.xcodeproj` here.

## Use

**Cmd-Space → "macbreak"** opens Preferences. It won't start a second copy; the
launch hands off to the running one.

| Menu item | Effect |
| --- | --- |
| **Look Away Now** | Eye-rest overlay immediately |
| **Take Walk Break Now** | Walk overlay immediately |
| **Pause** / **Resume** | Clears both clocks / restarts both from full |
| **Preferences…** | All seven intervals, plus start-at-login |
| **Quit MacBreak** | Boots the launchd job out, so `KeepAlive` doesn't respawn it |

Preferences are stored in `UserDefaults` under `com.user.macbreak`.

## Try it without waiting 30 minutes

```bash
make demo-eye     # look-away overlay after 6s, lasting 5s
make demo-walk    # walk overlay after 6s, lasting 5s
```

Five environment variables shorten the schedule:

| Variable | Overrides |
| --- | --- |
| `MACBREAK_BREAK_SECONDS` | Look-away interval and snooze length |
| `MACBREAK_WALK_SECONDS` | Walk interval |
| `MACBREAK_DURATION_SECONDS` | Both rest durations |
| `MACBREAK_LOCK_RESET_SECONDS` | Screen-lock reset threshold |
| `MACBREAK_STATUS_TIMER_SECONDS` | When the menu bar starts showing a countdown |

## Uninstall

```bash
brew uninstall --cask macbreak        # if installed with Homebrew
brew uninstall --zap --cask macbreak  # ...and forget the saved intervals

make uninstall                        # if installed from source
defaults delete com.user.macbreak     # optional: forget the saved intervals
```

## Repository layout

```
Sources/MacBreak/
  main.swift            Entry point and single-instance handoff
  AppDelegate.swift     Scheduling, menu bar, overlay, preferences
  BreakKind.swift       The two break types and their message pools
  Preferences.swift     UserDefaults wrapper and environment overrides
  Overlay.swift         Overlay window, key-swallowing view, palette
  Typography.swift      SF Rounded helpers
  LaunchAgent.swift     launchd install/uninstall
  Clock.swift           mm:ss / h:mm:ss formatting
  Logging.swift         Timestamped stdout, which launchd captures

Resources/Info.plist    Bundle metadata; LSUIElement keeps it off the Dock
launchd/                Launch agent template
scripts/                build.sh, install.sh, uninstall.sh, bootstrap.sh
site/                   One-page explainer, deployed to macbreak.vercel.app
openspec/specs/         Behaviour specifications
Makefile                build · install · uninstall · demo-eye · demo-walk · spec
```

### Specifications

Behaviour is specified in [`openspec/specs/`](openspec/specs/) rather than left
implicit in the code — five capabilities, in [OpenSpec](https://github.com/Fission-AI/OpenSpec)
format:

| Capability | Covers |
| --- | --- |
| [`break-scheduling`](openspec/specs/break-scheduling/spec.md) | Both cadences, walk precedence, screen-lock reset, pause, test overrides |
| [`break-overlay`](openspec/specs/break-overlay/spec.md) | The blocker, rest countdown, locked Done, styling, snooze |
| [`menu-bar-control`](openspec/specs/menu-bar-control/spec.md) | Status item, quiet threshold, menu, preferences panel |
| [`app-launch`](openspec/specs/app-launch/spec.md) | App bundle, Spotlight, single instance, reopen events |
| [`login-agent`](openspec/specs/login-agent/spec.md) | launchd install/uninstall, quitting a KeepAlive job |

```bash
make spec    # openspec validate --all
```

## How it works

One 1 Hz timer drives everything: both deadlines, the overlay countdown and the
menu bar title. Fewer moving parts than a pile of one-shot timers, and the two
clocks cannot drift apart.

The app runs with `NSApplication.ActivationPolicy.accessory` and declares
`LSUIElement`, so it has no Dock tile and no Force Quit entry. `launchd` keeps it
alive with `KeepAlive`; the Quit menu item boots the job out rather than exiting,
or `launchd` would simply start it again.

The overlay is a borderless window per screen with an `NSVisualEffectView`
behind a dark tint, so the desktop blurs through rather than disappearing.

## FAQ

**Does it work with multiple monitors?** Yes — every display is covered, each
with its own countdown and buttons.

**Does it send anything anywhere?** No. There is no network code in this repo.

**Is it notarised / code-signed?** No. The Homebrew cask clears the download
quarantine for you; building from source avoids the question entirely.

**Can I just use it for eyes, not walks?** Set the walk interval very high in
Preferences.

**Where are the logs?** `/tmp/macbreak.out.log` and `/tmp/macbreak.err.log`.

**Can I kill it?** `kill` makes `KeepAlive` respawn it. Use the Quit menu item or
`make uninstall`.

## Related

If MacBreak is not what you want, look at Time Out, Stretchly, Workrave, or
BreakTimer. MacBreak's niche is being tiny, native, dependency-free and strict
about the rest actually happening.

## License

MIT — see [LICENSE](LICENSE).
