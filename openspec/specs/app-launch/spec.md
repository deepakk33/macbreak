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

### Requirement: Reopen Events Show Preferences

Because LaunchServices sends a reopen event to a running application rather
than starting a second process, the application SHALL implement
`applicationShouldHandleReopen` and show the preferences window in response.

#### Scenario: Opening from Spotlight while the agent copy runs

- **WHEN** the user opens MacBreak from Spotlight, the Dock or Finder while it is already running
- **THEN** the running copy receives a reopen event and shows its preferences window

### Requirement: Preferences Window Follows The Active Space

The preferences window SHALL use a `moveToActiveSpace` collection behaviour and
be ordered front regardless of activation state, so an app with no Dock tile
cannot open its window out of sight.

#### Scenario: Opened from a different Space

- **WHEN** preferences are requested while the user is on a Space other than the one the window was created on
- **THEN** the window appears on the user's current Space

### Requirement: Diagnostic Log

The application SHALL log launch and preferences events to standard output,
which launchd redirects to `/tmp/macbreak.out.log`.

#### Scenario: Inspecting why a launch did nothing

- **WHEN** the user opens the app and checks the log
- **THEN** it records that a reopen event was received and preferences were shown
