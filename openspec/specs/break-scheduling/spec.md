# break-scheduling Specification

## Purpose

Tracks two independent rest cadences — frequent short eye rests and infrequent
long walks — and decides which overlay to show when. Also defines when time
already spent away from the screen counts as rest.

## Requirements

### Requirement: Two Independent Cadences

The system SHALL maintain two schedules: a look-away break every 30 minutes by
default, and a walk break every 120 minutes by default. Both SHALL be
configurable.

#### Scenario: Fresh install

- **WHEN** MacBreak starts with no stored preferences
- **THEN** a look-away break is due in 30 minutes and a walk break in 120 minutes

#### Scenario: Look-away does not disturb the walk clock

- **WHEN** a look-away break completes
- **THEN** the look-away clock restarts and the walk clock keeps counting down

### Requirement: Walk Supersedes Look-Away

When both breaks come due at the same tick the system SHALL present the walk
break only, because the walk is the longer rest and resets the eyes anyway.

#### Scenario: Both due together at the two-hour mark

- **WHEN** the walk and look-away deadlines both pass in the same second
- **THEN** one walk overlay is shown and no look-away overlay is queued

#### Scenario: Completing a walk

- **WHEN** a walk break completes
- **THEN** both the walk clock and the look-away clock restart from full

### Requirement: Single Tick Drives Everything

Scheduling SHALL be driven by one repeating one-second timer registered in the
`.common` run loop mode, which evaluates both deadlines, the on-overlay
countdown and the menu bar title.

#### Scenario: Menu held open past a deadline

- **WHEN** the user holds the menu bar menu open across a scheduled break time
- **THEN** the overlay still appears

### Requirement: Screen Lock Counts As Rest

The system SHALL observe `com.apple.screenIsLocked` and
`com.apple.screenIsUnlocked`. When the screen was locked for at least the reset
threshold — 5 minutes by default — unlocking SHALL restart both schedules from
full, dismiss any overlay that is showing, and clear a paused state.

#### Scenario: Locked for ten minutes

- **WHEN** the user locks the screen, waits 10 minutes and unlocks
- **THEN** the look-away and walk clocks both restart from full

#### Scenario: Locked for one minute

- **WHEN** the user locks the screen, waits 1 minute and unlocks
- **THEN** both clocks continue from where they were

#### Scenario: Locked while an overlay is showing

- **WHEN** the screen is locked during a break and unlocked after the threshold
- **THEN** the overlay is dismissed and both clocks restart from full

### Requirement: Pause Suspends Both Schedules

Pausing SHALL clear both deadlines without scheduling replacements. Resuming
SHALL restart both from full.

#### Scenario: Pause then resume

- **WHEN** the user pauses and later resumes
- **THEN** no break fires while paused, and on resume both clocks start from full

### Requirement: Test Overrides Via Environment

The system SHALL honour environment variables that shorten the schedule so the
overlays can be demonstrated without waiting: `MACBREAK_BREAK_SECONDS` for the
look-away interval and snooze length, `MACBREAK_WALK_SECONDS` for the walk
interval, `MACBREAK_DURATION_SECONDS` for both break durations, and
`MACBREAK_LOCK_RESET_SECONDS` for the lock threshold.

#### Scenario: Short intervals for a demo

- **WHEN** MacBreak is launched with `MACBREAK_BREAK_SECONDS=10 MACBREAK_DURATION_SECONDS=5`
- **THEN** a look-away overlay appears after 10 seconds and unlocks Done after 5
