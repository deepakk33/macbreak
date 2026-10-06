# MacBreak

A break reminder for macOS that you cannot ignore. No Xcode, no dependencies —
one Swift file compiled with `swiftc`, wrapped in a hand-written app bundle and
run as a launchd user agent.

Two cadences, because eyes and legs need different things:

- **Every 30 minutes** — a 30 second look-away. Focus on something far away.
- **Every 2 hours** — a 10 minute walk. Stand up and move.

Each one blacks out every display and holds the screen for the full rest. **Done**
stays locked until the countdown reaches zero. Between breaks MacBreak is a
single countdown in the menu bar.

```
MENU BAR:  ☕ 28:14

  ┌────────────────────────┐        ┌────────────────────────────────────┐
  │ Look away in 28:14     │        │  MacBreak Preferences              │
  │ Walk in 1:42:09        │        │                                    │
  ├────────────────────────┤        │  Look away every        [ 30 ] min │
  │ Look Away Now          │        │  Look away for          [ 30 ] sec │
  │ Take Walk Break Now    │        │  Walk break every      [ 120 ] min │
  │ Pause                  │        │  Walk for               [ 10 ] min │
  ├────────────────────────┤        │  Snooze length          [ 10 ] min │
  │ Preferences…           │        │  Screen lock resets after [ 5 ] min│
  │ Quit MacBreak          │        │  ☑ Start at login                  │
  └────────────────────────┘        │                        [ Save ]    │
                                    └────────────────────────────────────┘

OVERLAY:
            ┌──────────────────────────────────────────┐
            │              LOOK AWAY                   │
            │     Focus on something 20 feet away      │
            │                                          │
            │                 00:23                    │
            │  Unclench your jaw · Drop your shoulders │
            │                                          │
            │    [ Done in 23s ]   [ Snooze (10 min) ] │
            │       ^ locked                           │
            └──────────────────────────────────────────┘
```

## Why it works

Most break reminders are a notification you swat away without reading. MacBreak
takes the screen instead:

- A borderless opaque window on **every** display, at `NSWindow.Level.screenSaver`
- Joins all Spaces and floats over full-screen apps
- Re-asserts focus every 0.7s, so an app that steals focus does not win
- Swallows keystrokes, so reflex typing does not reach whatever is underneath
- **Done is disabled until the rest is actually over** — the countdown is the point
- It does **not** auto-dismiss, so a break taken away from the desk is still there when you get back

Snooze stays available throughout. This is a nudge with teeth, not a kiosk lock.

## Time already spent away counts

Locking your screen is a break. If the screen was locked for **5 minutes or
more**, unlocking restarts both clocks from full — no look-away thirty seconds
after you sit back down from lunch. Shorter locks leave the clocks alone.

A completed walk resets the look-away clock too. A completed look-away leaves the
walk clock running.

## Install

```bash
git clone https://github.com/deepakk33/macbreak.git
cd macbreak
./install.sh
```

That compiles the binary, assembles `MacBreak.app`, installs it to
`/Applications` (or `~/Applications` if that is not writable), registers
`~/Library/LaunchAgents/com.user.macbreak.plist`, and starts it. It runs at every
login after that.

Requires macOS with Swift tooling (`xcode-select --install` is enough — the full
Xcode app is not needed).

## Use

**Cmd-Space → "macbreak"** opens Preferences. It will not start a second copy;
the launch hands off to the running one and exits.

| Menu item | Effect |
| --- | --- |
| **Look Away Now** | 30 second eye-rest overlay immediately |
| **Take Walk Break Now** | 10 minute walk overlay immediately |
| **Pause** / **Resume** | Clears both clocks / restarts both from full |
| **Preferences…** | All six intervals, plus start-at-login |
| **Quit MacBreak** | Boots the launchd job out, so `KeepAlive` does not respawn it |

The status item shows whichever break lands first — `☕` for the look-away, `🚶`
for the walk. Preferences live in `UserDefaults` under `com.user.macbreak`.

## See it without waiting 30 minutes

Four environment variables shorten the schedule:

```bash
./build.sh

# Look-away after 8s, lasting 5s
MACBREAK_BREAK_SECONDS=8 MACBREAK_DURATION_SECONDS=5 ./MacBreak

# Walk break after 10s, lasting 5s
MACBREAK_WALK_SECONDS=10 MACBREAK_DURATION_SECONDS=5 ./MacBreak
```

| Variable | Overrides |
| --- | --- |
| `MACBREAK_BREAK_SECONDS` | Look-away interval and snooze length |
| `MACBREAK_WALK_SECONDS` | Walk interval |
| `MACBREAK_DURATION_SECONDS` | Both rest durations |
| `MACBREAK_LOCK_RESET_SECONDS` | Screen-lock reset threshold |

Press **Done** when it unlocks, then `Ctrl-C`. Run `./install.sh` afterwards to
get the normal agent back.

## Uninstall

```bash
./uninstall.sh                      # stops it, removes the agent and the app
defaults delete com.user.macbreak   # optional: forget the saved intervals
```

## Layout

```
main.swift                 Entire application (~850 lines, AppKit)
Info.plist                 Bundle metadata; LSUIElement keeps it off the Dock
build.sh                   swiftc + assemble MacBreak.app
install.sh                 Build + install the app + register the agent + start
uninstall.sh               Boot out + remove the agent and the app
com.user.macbreak.plist    Agent template; install.sh fills in the binary path
openspec/specs/            Behaviour specs (OpenSpec format)
```

### Specs

Behaviour is specified in [`openspec/specs/`](openspec/specs/) — five
capabilities, 33 requirements:

| Capability | Covers |
| --- | --- |
| [`break-scheduling`](openspec/specs/break-scheduling/spec.md) | Both cadences, walk precedence, screen-lock reset, pause, test overrides |
| [`break-overlay`](openspec/specs/break-overlay/spec.md) | The blocker, the rest countdown, locked Done, snooze |
| [`menu-bar-control`](openspec/specs/menu-bar-control/spec.md) | Status item, menu, preferences panel |
| [`app-launch`](openspec/specs/app-launch/spec.md) | App bundle, Spotlight, single instance |
| [`login-agent`](openspec/specs/login-agent/spec.md) | launchd install/uninstall, quitting a KeepAlive job |

Validate with [OpenSpec](https://github.com/Fission-AI/OpenSpec):

```bash
openspec validate --all
```

## Notes and caveats

- **LaunchAgent, not LaunchDaemon.** The plist lives in `~/Library/LaunchAgents/`.
  A daemon in `/Library/LaunchDaemons/` runs before login with no GUI session, so
  the overlay would never draw.
- **`KeepAlive` is true.** `kill`ing the process respawns it. Use the Quit menu
  item or `./uninstall.sh`.
- **Not code-signed.** First launch from Finder may need a right-click → Open.
- **It does not block `Cmd-Q` or the power button.** Snooze is always one click away.
- Logs: `/tmp/macbreak.out.log` and `/tmp/macbreak.err.log`.

## License

MIT
