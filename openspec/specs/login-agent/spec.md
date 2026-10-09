# login-agent Specification

## Purpose

Keeps MacBreak running without the user thinking about it, via a launchd user
agent. Also defines how the app gets out of the way when the user quits it,
since a KeepAlive job would otherwise respawn immediately.

## Requirements

### Requirement: Launch Agent Definition

The system SHALL install a launchd property list labelled `com.user.macbreak` in
`~/Library/LaunchAgents/`, with `RunAtLoad` and `KeepAlive` set to true, a
`ProcessType` of `Interactive`, and `ProgramArguments` pointing at the absolute
path of the running executable.

#### Scenario: Installing from preferences

- **WHEN** the user ticks "Start at login" and saves
- **THEN** the plist is written with the current executable path, and launchd loads it at the next login

### Requirement: Enabling Start At Login Does Not Start A Second Copy

Ticking "Start at login" SHALL write the plist without bootstrapping it.
Bootstrapping would make launchd start a second copy immediately; that copy
defers to the running one and exits, and `KeepAlive` respawns it about every ten
seconds, each time raising the preferences window.

#### Scenario: Ticking the box while MacBreak is running

- **WHEN** the user ticks "Start at login" and saves while MacBreak is running
- **THEN** exactly one MacBreak process exists afterwards and no `com.user.macbreak` job is loaded until the next login

### Requirement: Start At Login Survives Package Upgrades

The user's choice SHALL be stored in preferences as well as expressed by the
plist. On launch from an app bundle, an existing plist SHALL mark the choice as
on, and a missing plist SHALL be rewritten when the choice is on — because
`brew upgrade` runs the old cask's uninstall, which deletes the agent, before it
reopens the new app. A bare demo binary SHALL never write the agent.

#### Scenario: Upgrading with Homebrew

- **WHEN** start at login is on and `brew upgrade --cask macbreak` replaces the app and reopens it
- **THEN** the plist is back in `~/Library/LaunchAgents/`, pointing at the installed app

#### Scenario: Running a demo build

- **WHEN** `make demo-eye` runs the bare binary while the choice is on and no plist exists
- **THEN** no plist is written

### Requirement: User Agent, Not System Daemon

MacBreak SHALL be installed as a per-user LaunchAgent rather than a
LaunchDaemon, because the overlay requires a GUI session that daemons do not
have.

#### Scenario: Deciding install location

- **WHEN** the agent is installed
- **THEN** the plist lands in `~/Library/LaunchAgents/`, not `/Library/LaunchDaemons/`

### Requirement: Uninstall Removes Job And File

Unticking "Start at login" SHALL delete the plist and record the choice as off.
It SHALL boot the job out of the GUI domain only when the running process is not
that job, since booting out its own job would kill the app the user is looking
at.

#### Scenario: Disabling start at login

- **WHEN** the user unticks "Start at login" and saves in a copy launched from Spotlight
- **THEN** the job is no longer listed by launchctl and the plist file is gone

#### Scenario: Disabling start at login under launchd

- **WHEN** the user unticks "Start at login" and saves in a copy started by launchd
- **THEN** the plist file is gone and MacBreak keeps running until quit

### Requirement: Quit Defeats KeepAlive

Because `KeepAlive` is true, quitting SHALL boot the launchd job out when the
process was started by launchd, so that quitting actually stops the app.

#### Scenario: Quit while running under launchd

- **WHEN** the user selects "Quit MacBreak" in a launchd-started instance
- **THEN** the job is booted out and no replacement process is spawned

#### Scenario: Quit while running from a terminal

- **WHEN** the user selects "Quit MacBreak" in an instance launched from a shell
- **THEN** the process exits and no launchd job is touched

### Requirement: Uninstall Removes The App Bundle Too

The uninstall script SHALL remove the launch agent and the installed
`MacBreak.app` from both `/Applications` and `~/Applications`, while leaving
stored preferences in place.

#### Scenario: Running the uninstall script

- **WHEN** `./uninstall.sh` runs
- **THEN** the agent and both bundle locations are removed and preferences in the `com.user.macbreak` domain survive
