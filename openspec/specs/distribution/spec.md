# distribution Specification

## Purpose

How a stranger gets MacBreak onto their machine. A utility nobody can install in
under a minute is a utility nobody installs.

## Requirements

### Requirement: Homebrew Cask

MacBreak SHALL be installable via a Homebrew cask served from a personal tap,
which installs `MacBreak.app` into `/Applications` from a tagged GitHub release.

#### Scenario: Installing with Homebrew

- **WHEN** a user runs `brew install --cask deepakk33/tap/macbreak`
- **THEN** `MacBreak.app` is placed in `/Applications` and reported as installed

### Requirement: Cask Clears The Download Quarantine

Because release builds are not code-signed or notarised, the cask SHALL clear
the `com.apple.quarantine` attribute after installing, so the app opens without
a Gatekeeper refusal.

#### Scenario: Opening a Homebrew-installed copy

- **WHEN** the user opens MacBreak after a cask install
- **THEN** it launches without a "damaged" or "unidentified developer" dialog

### Requirement: Cask Uninstall Stops The App

The cask SHALL quit the running app, boot out the launchd job and delete the
launch agent on uninstall, and SHALL additionally remove stored preferences when
zapped.

#### Scenario: Uninstalling with Homebrew

- **WHEN** a user runs `brew uninstall --cask macbreak`
- **THEN** the app is removed, the launchd job is booted out and the agent plist is deleted

### Requirement: One-Line Source Install

A bootstrap script SHALL be runnable with a single `curl | bash`, cloning the
repository to a known location, building from source and registering the login
agent. It SHALL refuse to run on a non-macOS system or without Swift tooling,
naming the fix.

#### Scenario: Installing on a clean Mac

- **WHEN** a user pipes `scripts/bootstrap.sh` into bash
- **THEN** the source is cloned, compiled and installed, with no pre-built binary downloaded

#### Scenario: Swift tooling missing

- **WHEN** the bootstrap runs without `swiftc` available
- **THEN** it exits with an error naming `xcode-select --install`

#### Scenario: Re-running the bootstrap

- **WHEN** the bootstrap runs with the source already cloned
- **THEN** it fast-forwards the existing clone and rebuilds rather than failing

### Requirement: Tagged Releases Carry A Zipped Bundle

Each release SHALL attach a zipped `MacBreak.app` built from the tagged source,
whose checksum the cask pins.

#### Scenario: Publishing a version

- **WHEN** version 1.2.0 is released
- **THEN** a `MacBreak-1.2.0.zip` asset is attached and its SHA-256 appears in the cask

### Requirement: Explainer Page

The project SHALL ship a single self-contained HTML page under `site/`,
deployable as a static site, that explains both break types, why the overlay
cannot be dismissed early, and both installation routes.

#### Scenario: Visiting the page

- **WHEN** someone opens the deployed page
- **THEN** it describes both cadences and gives the Homebrew and source install commands
