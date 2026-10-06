# break-overlay Specification

## Purpose

The full-screen blocker shown when a break is due, in two flavours: a short
look-away and a long walk. It has to be impossible to ignore, because a
reminder that can be dismissed by reflex is not a break.

## Requirements

### Requirement: Full-Screen Opaque Overlay On Every Display

When a break fires the system SHALL present a borderless, opaque window covering
the full frame of every attached display.

#### Scenario: Two displays attached

- **WHEN** a break fires with two displays connected
- **THEN** both displays are fully covered, each with its own countdown and buttons

### Requirement: Overlay Floats Above All Windows

Overlay windows SHALL use `NSWindow.Level.screenSaver` and a collection
behaviour of `canJoinAllSpaces`, `fullScreenAuxiliary`, `stationary` and
`ignoresCycle`.

#### Scenario: Break fires while a full-screen app is frontmost

- **WHEN** a break fires while the user is in a full-screen app
- **THEN** the overlay is drawn above that app

### Requirement: Overlay Holds Focus

The overlay SHALL take key window status and re-assert itself roughly every 0.7
seconds while visible.

#### Scenario: Another app activates during a break

- **WHEN** a background app activates itself while the overlay is showing
- **THEN** within about a second the overlay is frontmost and key again

### Requirement: Keystrokes Are Swallowed

The overlay content view SHALL consume key events rather than forwarding them.

#### Scenario: User keeps typing

- **WHEN** the user types while the overlay is showing
- **THEN** no characters reach the previously focused application

### Requirement: Two Break Flavours

The overlay SHALL render differently per break kind. A look-away break SHALL
read "LOOK AWAY" in green with an eye-rest prompt; a walk break SHALL read
"TIME FOR A WALK" in amber with a movement prompt. Each SHALL show one randomly
chosen prompt and a supporting hint line.

#### Scenario: Look-away break

- **WHEN** a look-away break is shown
- **THEN** the heading is "LOOK AWAY" and the prompt comes from the eye-rest list

#### Scenario: Walk break

- **WHEN** a walk break is shown
- **THEN** the heading is "TIME FOR A WALK" and the prompt comes from the movement list

### Requirement: Rest Countdown

The overlay SHALL display a large monospaced countdown of the rest remaining,
starting at the break duration — 30 seconds for a look-away, 10 minutes for a
walk by default — and ticking down once per second to `00:00`.

#### Scenario: Look-away countdown

- **WHEN** a look-away break starts with a 30 second duration
- **THEN** the overlay shows `00:30` and counts down one second at a time

### Requirement: Done Unlocks Only When The Rest Is Over

"Done" SHALL be disabled and dimmed while the countdown runs, titled
"Done in Ns", and SHALL become enabled and titled "Done" when the countdown
reaches zero. Pressing it SHALL dismiss the overlay and restart the relevant
clocks.

#### Scenario: Pressing Done early is not possible

- **WHEN** 12 seconds remain on a look-away break
- **THEN** the button reads "Done in 12s" and does not respond to clicks

#### Scenario: A long break counts down

- **WHEN** 9 minutes 56 seconds remain on a walk break
- **THEN** the button reads "Done in 9:56" rather than a raw second count

#### Scenario: Countdown reaches zero

- **WHEN** the countdown reaches `00:00`
- **THEN** the button reads "Done" and dismisses the overlay when pressed

### Requirement: Overlay Does Not Auto-Dismiss

The overlay SHALL remain on screen after the countdown ends until the user
acknowledges it, so a break taken away from the desk is not missed on return.

#### Scenario: User walks away for the whole break

- **WHEN** the countdown ends with no one at the machine
- **THEN** the overlay is still showing, with Done enabled, when the user returns

### Requirement: Snooze Is Always Available

"Snooze" SHALL stay enabled throughout, name the configured snooze length, and
defer the break by that length. Snoozing a walk SHALL NOT let the eyes drift
past the snooze window.

#### Scenario: Snoozing a look-away

- **WHEN** the user presses "Snooze (10 min)" on a look-away break
- **THEN** the overlay closes and the next look-away is due in 10 minutes

#### Scenario: Snoozing a walk

- **WHEN** the user presses "Snooze (10 min)" on a walk break
- **THEN** the walk is deferred 10 minutes and the next look-away is no later than that

### Requirement: Calm Visual Treatment

The overlay SHALL be translucent rather than a solid black wall: an
`NSVisualEffectView` blurs the desktop behind a dark tint, so the screen reads
as a pause rather than a crash. Type SHALL be set in SF Rounded with the
countdown using rounded monospaced digits, and accent colours SHALL be muted
rather than saturated.

#### Scenario: Overlay appears

- **WHEN** a break overlay is shown
- **THEN** the desktop is visible but blurred behind a dark tint, and all type is rounded

#### Scenario: Countdown ticks

- **WHEN** the countdown moves from `00:10` to `00:09`
- **THEN** the digits do not shift position

### Requirement: Varied Prompts

Each break kind SHALL draw from a pool of at least eight differently worded
prompts, so the overlay does not become wallpaper the user stops reading. Eye
prompts SHALL cover distance focus, eye rolling, palming, blinking and closing
the eyes.

#### Scenario: Repeated look-away breaks

- **WHEN** several look-away breaks occur in a session
- **THEN** the prompt varies between them, drawn at random from the eye-rest pool

### Requirement: Overlay Windows Are Not Released On Close

Overlay windows SHALL set `isReleasedWhenClosed` to false. AppKit releases a
closed window by default, and the app also holds each overlay in its own
collection, so leaving the default in place double-releases the window and the
next CoreAnimation flush dereferences freed memory.

#### Scenario: Dismissing a break

- **WHEN** the user presses Done and the overlay windows are closed
- **THEN** the application keeps running and the menu bar item remains

#### Scenario: Many breaks in one session

- **WHEN** several breaks are shown and dismissed in succession
- **THEN** the application survives every cycle

### Requirement: Overlay Is Not Re-Entrant

The system SHALL NOT present a second overlay while one is already visible.

#### Scenario: Menu action during a break

- **WHEN** "Look Away Now" is invoked while an overlay is already showing
- **THEN** nothing changes and no duplicate window is created
