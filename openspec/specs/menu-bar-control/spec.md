# menu-bar-control Specification

## Purpose

The only visible surface of MacBreak between breaks: a status item that shows
when the next break lands and a preferences panel for changing the intervals.

## Requirements

### Requirement: Accessory Activation Policy

The application SHALL run with `NSApplication.ActivationPolicy.accessory`, so it
appears in neither the Dock nor the Force Quit window.

#### Scenario: App is running

- **WHEN** MacBreak is running
- **THEN** it has no Dock tile and no Force Quit entry

### Requirement: Menu Bar Countdown

The system SHALL show a status item whose title is a coffee glyph followed by the
time remaining until the next break, formatted `mm:ss`, refreshed every second.

#### Scenario: 28 minutes 14 seconds remain

- **WHEN** 28 minutes and 14 seconds remain until the next break
- **THEN** the status item reads "☕ 28:14"

#### Scenario: Paused

- **WHEN** MacBreak is paused
- **THEN** the status item reads "☕ paused"

#### Scenario: Break in progress

- **WHEN** the overlay is showing
- **THEN** the status item reads "☕ break"

### Requirement: Menu Actions

The status item menu SHALL contain a disabled countdown line, "Take Break Now",
a pause toggle whose title reflects state, "Preferences…" and "Quit MacBreak".

#### Scenario: Take Break Now

- **WHEN** the user selects "Take Break Now"
- **THEN** the overlay appears immediately

#### Scenario: Pause toggle title

- **WHEN** the user selects "Pause"
- **THEN** the item title becomes "Resume"

### Requirement: Preferences Panel

The system SHALL provide a preferences window with a break interval field in
minutes, a snooze length field in minutes, a "Start at login" checkbox and a
Save button. Opening the panel SHALL populate every control from current state.

#### Scenario: Opening preferences

- **WHEN** the user selects "Preferences…"
- **THEN** the fields show the stored intervals and the checkbox reflects whether the launch agent is installed

### Requirement: Saving Preferences Restarts The Countdown

Saving SHALL persist values greater than zero, ignore invalid input, apply the
login-at-startup choice, and reschedule the pending break using the new break
interval unless the app is paused.

#### Scenario: Interval changed to 45 minutes

- **WHEN** the user enters 45 and presses Save
- **THEN** 45 minutes is persisted and the countdown restarts from 45:00

#### Scenario: Non-numeric input

- **WHEN** the user enters "abc" and presses Save
- **THEN** the stored interval is left unchanged

### Requirement: Preferences Window Hides Rather Than Closing

Closing the preferences window SHALL hide it and keep the instance alive, so
reopening is immediate and state is preserved.

#### Scenario: Close and reopen

- **WHEN** the user closes the preferences window and reopens it
- **THEN** the same window reappears, repopulated from current state
