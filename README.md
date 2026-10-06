# MacBreak

A break reminder for macOS that you cannot ignore. No Xcode, no app bundle, no
dependencies — one Swift file compiled with `swiftc`, run as a launchd user
agent.

Every 30 minutes it blacks out every display, tells you to look away from the
screen, and waits for you to press **Done** or **Snooze**. Between breaks it is
a single countdown in the menu bar.

```
MENU BAR:  ☕ 28:14

  ┌────────────────────────┐        ┌──────────────────────────────┐
  │ Next break in 28:14    │        │  MacBreak Preferences        │
  ├────────────────────────┤        │                              │
  │ Take Break Now         │        │  Break interval   [ 30 ] min │
  │ Pause                  │        │  Snooze length    [ 10 ] min │
  ├────────────────────────┤        │  ☑ Start at login            │
  │ Preferences…           │        │                              │
  │ Quit MacBreak          │        │            [ Save ]          │
  └────────────────────────┘        └──────────────────────────────┘
```

## Why it works

Most break reminders are a notification you swat away without reading. MacBreak
takes the screen instead:

- A borderless opaque window on **every** display, at `NSWindow.Level.screenSaver`
- Joins all Spaces and floats over full-screen apps
- Re-asserts focus every 0.7s, so an app that steals focus does not win
- Swallows keystrokes, so reflex typing does not reach whatever is underneath

The only ways out are the two buttons.

## Install

```bash
git clone https://github.com/deepakk33/macbreak.git
cd macbreak
./install.sh
```

`install.sh` compiles the binary, writes `~/Library/LaunchAgents/com.user.macbreak.plist`
with the absolute path of that binary, and bootstraps it into your GUI session.
It starts immediately and at every login after that.

Requires macOS with Swift tooling available (`xcode-select --install` is enough —
the full Xcode app is not needed).

## Use

The menu bar item shows time until the next break.

| Action | Effect |
| --- | --- |
| **Take Break Now** | Shows the overlay immediately |
| **Pause** / **Resume** | Cancels the pending break / schedules a fresh full interval |
| **Preferences…** | Break interval, snooze length, start-at-login |
| **Quit MacBreak** | Boots the launchd job out, so `KeepAlive` does not respawn it |

On the overlay:

- **Done** — restarts the full break interval
- **Snooze (N min)** — restarts a shorter interval

Preferences are stored in `UserDefaults` under the `MacBreak` domain. Saving
restarts the current countdown.

## See it without waiting 30 minutes

`MACBREAK_BREAK_SECONDS` overrides both intervals:

```bash
./build.sh
MACBREAK_BREAK_SECONDS=10 ./MacBreak
```

The overlay appears after 10 seconds. Press **Done**, then `Ctrl-C` in the
terminal. Run `./install.sh` afterwards to get the normal agent back.

## Uninstall

```bash
./uninstall.sh          # stops it, removes the launch agent
defaults delete MacBreak   # optional: forget the saved intervals
```

## Layout

```
main.swift                 Entire application (~550 lines, AppKit)
build.sh                   swiftc main.swift -o MacBreak
install.sh                 Build + register the launch agent + start
uninstall.sh               Boot out + remove the plist
com.user.macbreak.plist    Agent template; install.sh fills in the binary path
openspec/specs/            Behaviour specs (OpenSpec format)
```

### Specs

Behaviour is specified in [`openspec/specs/`](openspec/specs/), four capabilities
and 22 requirements:

| Capability | Covers |
| --- | --- |
| [`break-scheduling`](openspec/specs/break-scheduling/spec.md) | The timer, pause/resume, countdown, test override |
| [`break-overlay`](openspec/specs/break-overlay/spec.md) | The blocker window, focus handling, Done/Snooze |
| [`menu-bar-control`](openspec/specs/menu-bar-control/spec.md) | Status item, menu actions, preferences panel |
| [`login-agent`](openspec/specs/login-agent/spec.md) | launchd install/uninstall, quitting a KeepAlive job |

Validate them with [OpenSpec](https://github.com/Fission-AI/OpenSpec):

```bash
openspec validate --all
```

## Notes and caveats

- **LaunchAgent, not LaunchDaemon.** The plist lives in `~/Library/LaunchAgents/`.
  A daemon in `/Library/LaunchDaemons/` runs before login with no GUI session,
  so the overlay would never draw.
- **`KeepAlive` is true.** `kill`ing the process respawns it. Use the Quit menu
  item or `./uninstall.sh`.
- **Not code-signed, no bundle.** It is a bare Mach-O executable. There is no
  Dock tile and no Force Quit entry (`.accessory` activation policy).
- **It does not block `Cmd-Q` or a hard power-off.** It is a nudge with teeth,
  not a kiosk lock.
- Logs: `/tmp/macbreak.out.log` and `/tmp/macbreak.err.log`.

## License

MIT
