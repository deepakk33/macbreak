# app-launch Specification

## Purpose

How MacBreak is launched and found. A background utility with no Dock tile is
easy to lose, so it ships as a real app bundle that Spotlight indexes and that
opens its preferences when the user goes looking for it.

## Requirements

### Requirement: Ships As An App Bundle

The build SHALL produce `MacBreak.app` containing a hand-written `Info.plist`
with the bundle identifier `com.user.macbreak`, `LSUIElement` set to true, and
the compiled executable at `Contents/MacOS/MacBreak`. No Xcode project is
required.

#### Scenario: Running the build script

- **WHEN** `./build.sh` runs
- **THEN** both a bare `MacBreak` binary and a `MacBreak.app` bundle are produced

### Requirement: Installed Where Spotlight Indexes It

Installation SHALL copy the bundle to `/Applications` when writable and to
`~/Applications` otherwise, and SHALL ask Spotlight to index it immediately.

#### Scenario: Searching after install

- **WHEN** the user presses Cmd-Space and types "macbreak" after installing
- **THEN** MacBreak.app is offered as a result

### Requirement: Launch Agent Points At The Bundle

The login agent SHALL run the executable inside the installed bundle, so that
the launchd copy and the Spotlight copy are the same application.

#### Scenario: Inspecting the agent

- **WHEN** the installed launch agent is read
- **THEN** its program argument is the installed bundle's `Contents/MacOS/MacBreak`

### Requirement: Single Instance

When launched while another copy with the same bundle identifier is already
running, the new process SHALL post a show-preferences notification and exit
immediately, rather than starting a second scheduler.

#### Scenario: Spotlight launch while already running

- **WHEN** the user opens MacBreak from Spotlight while the agent copy is running
- **THEN** the preferences window of the running copy appears and the process count stays at one

### Requirement: Opening The App Shows Preferences

A copy started from Finder or Spotlight — that is, bundled and not started by
launchd — SHALL open the preferences window on launch, because the user
deliberately went looking for the app.

#### Scenario: First launch from Spotlight with nothing running

- **WHEN** the user opens MacBreak from Spotlight and no copy is running
- **THEN** it starts scheduling and shows the preferences window

#### Scenario: Started by launchd at login

- **WHEN** launchd starts MacBreak at login
- **THEN** no window is shown and only the status item appears

#### Scenario: Bare binary run from a terminal

- **WHEN** the unbundled binary is run from a shell for a demo
- **THEN** no preferences window is shown
