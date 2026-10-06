# menu-bar-control Specification

## Purpose

The only visible surface of MacBreak between breaks: a status item showing when
the next rest lands, and a preferences panel for every interval.

## Requirements

### Requirement: Accessory Activation Policy

The application SHALL run with `NSApplication.ActivationPolicy.accessory` and
declare `LSUIElement`, so it appears in neither the Dock nor the Force Quit
window.

#### Scenario: App is running

- **WHEN** MacBreak is running
- **THEN** it has no Dock tile and no Force Quit entry

### Requirement: Status Item Stays Quiet Until A Break Is Close

The menu bar belongs to the user, so the status item SHALL show only the glyph
of whichever break lands first while that break is further away than the
configured threshold — 5 minutes by default. Within the threshold it SHALL
append the remaining time, formatted `mm:ss`, refreshed every second.

#### Scenario: Next break is far off

- **WHEN** the nearest break is 24 minutes away
- **THEN** the status item reads "☕" with no countdown

#### Scenario: Next break is within the threshold

- **WHEN** the nearest break is 4 minutes 21 seconds away and the threshold is 5 minutes
- **THEN** the status item reads "☕ 04:21"

#### Scenario: A walk is the nearer break

- **WHEN** a walk is 2 minutes away and a look-away is 25 minutes away
- **THEN** the status item reads "🚶 02:00"

#### Scenario: Paused

- **WHEN** MacBreak is paused
- **THEN** the status item reads "☕ ⏸"

#### Scenario: Break in progress

- **WHEN** an overlay is showing with 18 seconds of rest left
- **THEN** the status item shows that kind's glyph and "00:18" regardless of the threshold

### Requirement: Menu Lists Both Countdowns

The menu SHALL show two disabled lines — time until the next look-away and time
until the next walk — above the actions.

#### Scenario: Opening the menu

- **WHEN** the user opens the menu
- **THEN** it reads "Look away in mm:ss" and "Walk in h:mm:ss"

### Requirement: Menu Actions

The menu SHALL offer "Look Away Now", "Take Walk Break Now", a pause toggle
whose title reflects state, "Preferences…" and "Quit MacBreak".

#### Scenario: Taking a walk break early

- **WHEN** the user selects "Take Walk Break Now"
- **THEN** the walk overlay appears immediately

#### Scenario: Pause toggle title

- **WHEN** the user selects "Pause"
- **THEN** the item title becomes "Resume"

### Requirement: Preferences Panel

The preferences window SHALL expose seven numeric fields — look-away interval
in minutes, look-away duration in seconds, walk interval in minutes, walk
duration in minutes, snooze length in minutes, screen-lock reset threshold in
minutes, and the menu bar countdown threshold in minutes — plus a "Start at
login" checkbox and a Save button. Opening it SHALL
populate every control from current state.

#### Scenario: Opening preferences

- **WHEN** the user opens preferences
- **THEN** all seven fields show stored values and the checkbox reflects whether the launch agent is installed

### Requirement: Saving Restarts Both Countdowns

Saving SHALL persist each value greater than zero, ignore invalid input, apply
the login-at-startup choice, and restart both schedules unless the app is
paused or a break is in progress.

#### Scenario: Walk interval changed to 90 minutes

- **WHEN** the user enters 90 for the walk interval and presses Save
- **THEN** 90 minutes is persisted and the walk countdown restarts from 1:30:00

#### Scenario: Non-numeric input

- **WHEN** the user enters "abc" in a field and presses Save
- **THEN** that stored value is left unchanged

### Requirement: Preferences Window Hides Rather Than Closing

Closing the preferences window SHALL hide it and keep the instance alive.

#### Scenario: Close and reopen

- **WHEN** the user closes the preferences window and reopens it
- **THEN** the same window reappears, repopulated from current state
