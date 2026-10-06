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
- **THEN** the plist is written with the current executable path and bootstrapped into the GUI domain

### Requirement: User Agent, Not System Daemon

MacBreak SHALL be installed as a per-user LaunchAgent rather than a
LaunchDaemon, because the overlay requires a GUI session that daemons do not
have.

#### Scenario: Deciding install location

- **WHEN** the agent is installed
- **THEN** the plist lands in `~/Library/LaunchAgents/`, not `/Library/LaunchDaemons/`

### Requirement: Uninstall Removes Job And File

Unticking "Start at login" SHALL boot the job out of the GUI domain and delete
the plist.

#### Scenario: Disabling start at login

- **WHEN** the user unticks "Start at login" and saves
- **THEN** the job is no longer listed by launchctl and the plist file is gone

### Requirement: Quit Defeats KeepAlive

Because `KeepAlive` is true, quitting SHALL boot the launchd job out when the
process was started by launchd, so that quitting actually stops the app.

#### Scenario: Quit while running under launchd

- **WHEN** the user selects "Quit MacBreak" in a launchd-started instance
- **THEN** the job is booted out and no replacement process is spawned

#### Scenario: Quit while running from a terminal

- **WHEN** the user selects "Quit MacBreak" in an instance launched from a shell
- **THEN** the process exits and no launchd job is touched
