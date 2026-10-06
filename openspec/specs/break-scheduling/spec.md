# break-scheduling Specification

## Purpose

Tracks time between breaks and decides when the break overlay is shown. This is
the clock at the centre of MacBreak: every other capability either reads from it
or resets it.

## Requirements

### Requirement: Default Break Interval

The system SHALL schedule the first break 30 minutes after launch when no stored
preference exists, and SHALL use the stored preference when one does.

#### Scenario: First launch with no stored preference

- **WHEN** MacBreak starts and no break interval has been saved
- **THEN** the next break is scheduled 1800 seconds from launch

#### Scenario: Launch with a stored preference

- **WHEN** MacBreak starts and a break interval of N minutes has been saved
- **THEN** the next break is scheduled N × 60 seconds from launch

### Requirement: Timer Runs In Common Run Loop Mode

The break timer SHALL be registered in the `.common` run loop mode so that it
continues to fire while the user is tracking a menu or dragging a window.

#### Scenario: Menu held open past the deadline

- **WHEN** the user holds the menu bar menu open across the scheduled break time
- **THEN** the overlay still appears

### Requirement: Countdown Deadline Is Observable

The system SHALL expose the remaining time until the next break so the menu bar
can render a live countdown.

#### Scenario: Countdown ticks down

- **WHEN** a break is scheduled and one second elapses
- **THEN** the reported remaining time decreases by one second

### Requirement: Pause Suspends Scheduling

The system SHALL support pausing, which cancels the pending break without
scheduling a replacement, and resuming, which schedules a fresh full interval.

#### Scenario: Pause then resume

- **WHEN** the user pauses and later resumes
- **THEN** no break fires while paused, and on resume a full break interval is scheduled

### Requirement: Test Override Via Environment

The system SHALL honour a `MACBREAK_BREAK_SECONDS` environment variable that
overrides both break and snooze intervals, so the overlay can be demonstrated
without waiting for a full interval.

#### Scenario: Short interval for a demo

- **WHEN** MacBreak is launched with `MACBREAK_BREAK_SECONDS=10`
- **THEN** the overlay appears 10 seconds after launch
