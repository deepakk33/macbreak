# break-overlay Specification

## Purpose

The full-screen blocker shown when a break is due. It has to be impossible to
ignore, because a reminder that can be dismissed by reflex is not a break.

## Requirements

### Requirement: Full-Screen Opaque Overlay On Every Display

When a break fires the system SHALL present a borderless, opaque window covering
the full frame of every attached display.

#### Scenario: Two displays attached

- **WHEN** a break fires with two displays connected
- **THEN** both displays are fully covered by an overlay window

### Requirement: Overlay Floats Above All Windows

Overlay windows SHALL use `NSWindow.Level.screenSaver` and a collection
behaviour of `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary` and
`ignoresCycle`, so the overlay stays visible across Spaces and over full-screen
apps.

#### Scenario: Break fires while a full-screen app is frontmost

- **WHEN** a break fires while the user is in a full-screen app
- **THEN** the overlay is drawn above that app

### Requirement: Overlay Holds Focus

The overlay SHALL take key window status and re-assert itself roughly every 0.7
seconds while visible, so that focus stolen by another app is reclaimed.

#### Scenario: Another app activates during a break

- **WHEN** a background app activates itself while the overlay is showing
- **THEN** within about a second the overlay is frontmost and key again

### Requirement: Keystrokes Are Swallowed

The overlay content view SHALL consume key events rather than forwarding them,
so typing during a break cannot reach the application underneath.

#### Scenario: User keeps typing

- **WHEN** the user types while the overlay is showing
- **THEN** no characters reach the previously focused application

### Requirement: Break Instruction Is Displayed

The overlay SHALL show a heading, one randomly chosen stretch or eye-rest
instruction, and a supporting hint line.

#### Scenario: Overlay appears

- **WHEN** the overlay is shown
- **THEN** it displays "TIME FOR A BREAK" and one prompt drawn from the prompt list

### Requirement: Done And Snooze Controls

The overlay SHALL provide exactly two buttons. "Done" SHALL dismiss the overlay
and schedule the next break at the full break interval. "Snooze" SHALL dismiss
the overlay and schedule the next break at the snooze interval, and its title
SHALL name the current snooze length in minutes.

#### Scenario: User presses Done

- **WHEN** the user presses "Done"
- **THEN** the overlay closes and the next break is scheduled one full interval later

#### Scenario: User presses Snooze

- **WHEN** the user presses "Snooze (10 min)" with a 10 minute snooze configured
- **THEN** the overlay closes and the next break is scheduled 600 seconds later

### Requirement: Overlay Is Not Re-Entrant

The system SHALL NOT present a second overlay while one is already visible.

#### Scenario: Take Break Now during a break

- **WHEN** "Take Break Now" is invoked while the overlay is already showing
- **THEN** nothing changes and no duplicate window is created
