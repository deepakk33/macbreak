import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    // Schedule
    private var lookAwayDue: Date?
    private var walkDue: Date?
    private var isPaused = false

    // Active break
    private var activeKind: BreakKind?
    private var breakEndsAt: Date?
    private var doneUnlocked = false

    // Screen lock
    private var lockedAt: Date?

    // Timers
    private var tickTimer: Timer?
    private var raiseTimer: Timer?

    // Overlay
    private var overlayWindows: [NSWindow] = []
    private var overlayChrome: [OverlayChrome] = []

    // Menu bar
    private var statusItem: NSStatusItem!
    private var lookAwayItem: NSMenuItem!
    private var walkItem: NSMenuItem!
    private var pauseItem: NSMenuItem!

    // Preferences
    private var prefsWindow: NSWindow?
    private var fields: [String: NSTextField] = [:]
    private var loginCheckbox: NSButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildStatusItem()
        observeScreenLock()
        observeShowPreferences()
        resetAllSchedules()
        startTicking()
        log("started (launchd: \(LaunchAgent.isManagedByLaunchd))")

        // Launched from Spotlight or Finder rather than by launchd: the user
        // went looking for the app, so show them something.
        if Bundle.main.bundleIdentifier != nil && !LaunchAgent.isManagedByLaunchd {
            openPreferences()
        }
    }

    /// LaunchServices does not start a second process when the app is already
    /// running; it sends a reopen event to the live copy instead. Without this
    /// the Spotlight launch is silently dropped.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        log("reopen event received - showing preferences")
        openPreferences()
        return true
    }

    private func observeShowPreferences() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showPreferencesRequested),
            name: Const.showPrefsNotification,
            object: nil
        )
    }

    @objc private func showPreferencesRequested() {
        openPreferences()
    }

    // MARK: - Scheduling

    private func resetAllSchedules() {
        lookAwayDue = Date().addingTimeInterval(Prefs.lookAwayInterval)
        walkDue = Date().addingTimeInterval(Prefs.walkInterval)
    }

    private func rescheduleLookAway(after seconds: TimeInterval) {
        lookAwayDue = Date().addingTimeInterval(seconds)
    }

    private func rescheduleWalk(after seconds: TimeInterval) {
        walkDue = Date().addingTimeInterval(seconds)
    }

    /// A single 1 Hz tick drives both schedules, the countdown and the menu bar.
    /// Simpler than juggling four one-shot timers, and it cannot drift apart.
    private func startTicking() {
        tickTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
        tick()
    }

    private func tick() {
        let now = Date()

        if activeKind != nil {
            updateBreakCountdown(now: now)
        } else if !isPaused {
            // A walk supersedes a look-away when both come due together: the
            // walk is the longer rest and resets the look-away anyway.
            if let due = walkDue, now >= due {
                beginBreak(.walk)
            } else if let due = lookAwayDue, now >= due {
                beginBreak(.lookAway)
            }
        }

        refreshStatus(now: now)
    }

    // MARK: - Screen lock

    private func observeScreenLock() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(screenLocked),
                           name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        center.addObserver(self, selector: #selector(screenUnlocked),
                           name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func screenLocked() {
        lockedAt = Date()
    }

    @objc private func screenUnlocked() {
        defer { lockedAt = nil }
        guard let lockedAt = lockedAt else { return }
        let away = Date().timeIntervalSince(lockedAt)
        guard away >= Prefs.lockResetThreshold else { return }

        // The user has already been away from the screen for long enough to
        // count as a break, so both clocks start over.
        log("screen was locked for \(Int(away))s - resetting both schedules")
        if activeKind != nil { closeOverlay() }
        isPaused = false
        pauseItem.title = "Pause"
        resetAllSchedules()
        refreshStatus(now: Date())
    }

    // MARK: - Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = BreakKind.lookAway.glyph

        let menu = NSMenu()

        lookAwayItem = NSMenuItem(title: "Look away in --:--", action: nil, keyEquivalent: "")
        lookAwayItem.isEnabled = false
        menu.addItem(lookAwayItem)

        walkItem = NSMenuItem(title: "Walk in --:--", action: nil, keyEquivalent: "")
        walkItem.isEnabled = false
        menu.addItem(walkItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Look Away Now", action: #selector(lookAwayNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Take Walk Break Now", action: #selector(walkNow), keyEquivalent: ""))

        pauseItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(pauseItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit MacBreak", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    /// The menu bar is the user's workspace, not ours: show the glyph alone
    /// until a break is close enough to be worth knowing about.
    private func refreshStatus(now: Date) {
        if let kind = activeKind, let endsAt = breakEndsAt {
            let remaining = Int(endsAt.timeIntervalSince(now).rounded())
            statusItem.button?.title = remaining > 0
                ? "\(kind.glyph) \(Clock.format(remaining))"
                : kind.glyph
            lookAwayItem.title = kind == .walk ? "Walk break in progress" : "Look-away break in progress"
            walkItem.title = remaining > 0 ? "Resting for \(Clock.format(remaining))" : "Press Done when ready"
            return
        }

        guard !isPaused else {
            statusItem.button?.title = "\(BreakKind.lookAway.glyph) ⏸"
            lookAwayItem.title = "Paused"
            walkItem.title = "Paused"
            return
        }

        let lookAwayLeft = remaining(until: lookAwayDue, now: now)
        let walkLeft = remaining(until: walkDue, now: now)
        lookAwayItem.title = "Look away in \(Clock.format(lookAwayLeft))"
        walkItem.title = "Walk in \(Clock.format(walkLeft))"

        // Whichever break lands first decides both the glyph and whether we speak up.
        let nextIsWalk = walkLeft < lookAwayLeft
        let soonest = min(lookAwayLeft, walkLeft)
        let glyph = nextIsWalk ? BreakKind.walk.glyph : BreakKind.lookAway.glyph

        statusItem.button?.title = TimeInterval(soonest) <= Prefs.statusTimerThreshold
            ? "\(glyph) \(Clock.format(soonest))"
            : glyph
    }

    private func remaining(until date: Date?, now: Date) -> Int {
        guard let date = date else { return 0 }
        return max(0, Int(date.timeIntervalSince(now).rounded()))
    }

    // MARK: - Menu actions

    @objc private func lookAwayNow() { beginBreak(.lookAway) }

    @objc private func walkNow() { beginBreak(.walk) }

    @objc private func togglePause() {
        isPaused.toggle()
        if isPaused {
            lookAwayDue = nil
            walkDue = nil
            pauseItem.title = "Resume"
        } else {
            pauseItem.title = "Pause"
            resetAllSchedules()
        }
        refreshStatus(now: Date())
    }

    @objc private func quitApp() {
        // KeepAlive would respawn us, so unload the job instead of plain exit.
        if LaunchAgent.isManagedByLaunchd {
            LaunchAgent.bootout()
        }
        NSApp.terminate(nil)
    }

    // MARK: - Break lifecycle

    private func beginBreak(_ kind: BreakKind) {
        guard activeKind == nil else { return }

        activeKind = kind
        breakEndsAt = Date().addingTimeInterval(kind.duration)
        doneUnlocked = false
        log("break started: \(kind == .walk ? "walk" : "look-away")")

        let prompt = kind.prompts.randomElement() ?? kind.prompts[0]

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            // Translucent rather than a black wall: the blurred desktop behind
            // reads as a pause, not a crash.
            window.isOpaque = false
            window.backgroundColor = .clear
            window.alphaValue = OverlayPalette.windowAlpha
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.contentView = makeOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size),
                                                 kind: kind, prompt: prompt)
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        overlayWindows.first?.makeKeyAndOrderFront(nil)
        overlayWindows.first?.makeFirstResponder(overlayWindows.first?.contentView)

        startRaising()
        updateBreakCountdown(now: Date())
    }

    /// Ticks the on-overlay countdown and unlocks "Done" when it reaches zero.
    private func updateBreakCountdown(now: Date) {
        guard let endsAt = breakEndsAt else { return }
        let remaining = max(0, Int(endsAt.timeIntervalSince(now).rounded()))

        for chrome in overlayChrome {
            chrome.countdown.stringValue = Clock.format(remaining)
            if remaining > 0 {
                chrome.done.isEnabled = false
                style(chrome.done, title: "Done in \(Clock.compact(remaining))", enabled: false)
            } else if !doneUnlocked {
                chrome.done.isEnabled = true
                chrome.done.layer?.backgroundColor = OverlayPalette.doneEnabled.cgColor
                style(chrome.done, title: "Done", enabled: true)
            }
        }

        if remaining == 0 { doneUnlocked = true }
    }

    @objc private func doneTapped() {
        // Completing a walk counts as a look-away too, so both clocks restart.
        let finished = activeKind
        closeOverlay()
        rescheduleLookAway(after: Prefs.lookAwayInterval)
        if finished == .walk {
            rescheduleWalk(after: Prefs.walkInterval)
        }
        refreshStatus(now: Date())
    }

    @objc private func snoozeTapped() {
        let snoozed = activeKind
        closeOverlay()
        if snoozed == .walk {
            rescheduleWalk(after: Prefs.snoozeInterval)
            // Keep the eyes on schedule even while the walk is deferred.
            if let due = lookAwayDue, due < Date().addingTimeInterval(Prefs.snoozeInterval) {
                rescheduleLookAway(after: Prefs.snoozeInterval)
            }
        } else {
            rescheduleLookAway(after: Prefs.snoozeInterval)
        }
        refreshStatus(now: Date())
    }

    private func closeOverlay() {
        stopRaising()
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
        overlayChrome.removeAll()
        activeKind = nil
        breakEndsAt = nil
        doneUnlocked = false
        NSApp.hide(nil)
    }

    /// Keeps the overlay in front even if something else tries to take focus.
    private func startRaising() {
        raiseTimer?.invalidate()
        let timer = Timer(timeInterval: Const.raiseInterval, repeats: true) { [weak self] _ in
            guard let self = self, !self.overlayWindows.isEmpty else { return }
            NSApp.activate(ignoringOtherApps: true)
            for window in self.overlayWindows { window.orderFrontRegardless() }
        }
        RunLoop.main.add(timer, forMode: .common)
        raiseTimer = timer
    }

    private func stopRaising() {
        raiseTimer?.invalidate()
        raiseTimer = nil
    }

    // MARK: - Overlay view

    private func makeOverlayView(frame: NSRect, kind: BreakKind, prompt: String) -> NSView {
        let root = OverlayContentView(frame: frame)
        root.wantsLayer = true

        // Blurred desktop, then a dark tint over it.
        let blur = NSVisualEffectView(frame: frame)
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .vibrantDark)
        blur.autoresizingMask = [.width, .height]
        root.addSubview(blur)

        let tint = NSView(frame: frame)
        tint.wantsLayer = true
        tint.layer?.backgroundColor = OverlayPalette.tint.cgColor
        tint.autoresizingMask = [.width, .height]
        root.addSubview(tint)

        let centerX = frame.midX
        let centerY = frame.midY

        let title = makeLabel(text: kind.heading, font: Typography.rounded(58, weight: .medium),
                              color: kind.accent, width: frame.width)
        title.frame.origin = NSPoint(x: 0, y: centerY + 170)
        root.addSubview(title)

        let subtitle = makeLabel(text: prompt, font: Typography.rounded(30, weight: .light),
                                 color: OverlayPalette.primaryText, width: frame.width)
        subtitle.frame.origin = NSPoint(x: 0, y: centerY + 100)
        root.addSubview(subtitle)

        let countdown = makeLabel(text: Clock.format(Int(kind.duration)),
                                  font: Typography.roundedMonospacedDigits(104, weight: .ultraLight),
                                  color: OverlayPalette.countdownText, width: frame.width)
        countdown.frame.origin = NSPoint(x: 0, y: centerY - 50)
        root.addSubview(countdown)

        let hint = makeLabel(text: kind.hint, font: Typography.rounded(17, weight: .regular),
                             color: OverlayPalette.secondaryText, width: frame.width)
        hint.frame.origin = NSPoint(x: 0, y: centerY - 100)
        root.addSubview(hint)

        let buttonWidth: CGFloat = 240
        let buttonHeight: CGFloat = 62
        let gap: CGFloat = 28
        let buttonY = centerY - 210

        let done = makeFlatButton(action: #selector(doneTapped),
                                  background: OverlayPalette.doneEnabled.withAlphaComponent(0.35))
        done.isEnabled = false
        style(done, title: "Done in \(Clock.compact(Int(kind.duration)))", enabled: false)
        done.frame = NSRect(x: centerX - buttonWidth - gap / 2, y: buttonY,
                            width: buttonWidth, height: buttonHeight)
        root.addSubview(done)

        let snooze = makeFlatButton(action: #selector(snoozeTapped), background: OverlayPalette.snooze)
        style(snooze, title: "Snooze \(Prefs.snoozeMinutes) min", enabled: true)
        snooze.frame = NSRect(x: centerX + gap / 2, y: buttonY,
                              width: buttonWidth, height: buttonHeight)
        root.addSubview(snooze)

        overlayChrome.append(OverlayChrome(countdown: countdown, done: done))
        return root
    }

    private func makeLabel(text: String, font: NSFont, color: NSColor, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.frame = NSRect(x: 0, y: 0, width: width, height: font.pointSize * 1.5)
        return label
    }

    private func makeFlatButton(action: Selector, background: NSColor) -> NSButton {
        let button = NSButton(title: "", target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = background.cgColor
        button.layer?.cornerRadius = 14
        return button
    }

    /// NSButton ignores `isEnabled` for attributed titles, so dim it ourselves.
    private func style(_ button: NSButton, title: String, enabled: Bool) {
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: enabled
                    ? OverlayPalette.primaryText
                    : NSColor(calibratedWhite: 1.0, alpha: 0.4),
                .font: Typography.rounded(20, weight: .medium)
            ]
        )
        button.layer?.opacity = enabled ? 1.0 : 0.6
    }

    // MARK: - Preferences window

    @objc private func openPreferences() {
        log("openPreferences")
        if let window = prefsWindow {
            loadPrefsIntoFields()
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 352),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacBreak Preferences"
        window.isReleasedWhenClosed = false
        window.delegate = self
        // An accessory app's window must be pulled onto whichever Space the user
        // is looking at, or it opens out of sight.
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        window.contentView = makePrefsView()
        prefsWindow = window

        loadPrefsIntoFields()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func makePrefsView() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 352))
        var y: CGFloat = 304

        func addRow(key: String, label: String, unit: String) {
            let caption = NSTextField(labelWithString: label)
            caption.frame = NSRect(x: 24, y: y + 2, width: 230, height: 20)
            root.addSubview(caption)

            let input = NSTextField(frame: NSRect(x: 262, y: y, width: 64, height: 24))
            input.alignment = .right
            root.addSubview(input)
            fields[key] = input

            let suffix = NSTextField(labelWithString: unit)
            suffix.frame = NSRect(x: 334, y: y + 2, width: 60, height: 20)
            root.addSubview(suffix)

            y -= 34
        }

        addRow(key: "lookAwayInterval", label: "Look away every", unit: "min")
        addRow(key: "lookAwayDuration", label: "Look away for", unit: "sec")
        addRow(key: "walkInterval", label: "Walk break every", unit: "min")
        addRow(key: "walkDuration", label: "Walk for", unit: "min")
        addRow(key: "snooze", label: "Snooze length", unit: "min")
        addRow(key: "lockReset", label: "Screen lock resets after", unit: "min")
        addRow(key: "statusTimer", label: "Show menu bar timer under", unit: "min")

        let checkbox = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)
        checkbox.frame = NSRect(x: 24, y: y - 4, width: 200, height: 22)
        root.addSubview(checkbox)
        loginCheckbox = checkbox

        let note = NSTextField(labelWithString: "Saving restarts both countdowns.")
        note.font = NSFont.systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 24, y: 26, width: 240, height: 18)
        root.addSubview(note)

        let save = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 300, y: 20, width: 96, height: 32)
        root.addSubview(save)

        return root
    }

    private func loadPrefsIntoFields() {
        fields["lookAwayInterval"]?.stringValue = String(Prefs.lookAwayIntervalMinutes)
        fields["lookAwayDuration"]?.stringValue = String(Prefs.lookAwayDurationSeconds)
        fields["walkInterval"]?.stringValue = String(Prefs.walkIntervalMinutes)
        fields["walkDuration"]?.stringValue = String(Prefs.walkDurationMinutes)
        fields["snooze"]?.stringValue = String(Prefs.snoozeMinutes)
        fields["lockReset"]?.stringValue = String(Prefs.lockResetMinutes)
        fields["statusTimer"]?.stringValue = String(Prefs.statusTimerMinutes)
        loginCheckbox?.state = LaunchAgent.isInstalled ? .on : .off
    }

    @objc private func savePreferences() {
        func value(_ key: String) -> Int? {
            guard let raw = fields[key]?.stringValue, let parsed = Int(raw), parsed > 0 else { return nil }
            return parsed
        }

        if let v = value("lookAwayInterval") { Prefs.lookAwayIntervalMinutes = v }
        if let v = value("lookAwayDuration") { Prefs.lookAwayDurationSeconds = v }
        if let v = value("walkInterval") { Prefs.walkIntervalMinutes = v }
        if let v = value("walkDuration") { Prefs.walkDurationMinutes = v }
        if let v = value("snooze") { Prefs.snoozeMinutes = v }
        if let v = value("lockReset") { Prefs.lockResetMinutes = v }
        if let v = value("statusTimer") { Prefs.statusTimerMinutes = v }

        let wantsLogin = loginCheckbox?.state == .on
        if wantsLogin && !LaunchAgent.isInstalled {
            LaunchAgent.install()
        } else if !wantsLogin && LaunchAgent.isInstalled {
            LaunchAgent.uninstall()
        }

        loadPrefsIntoFields()
        if !isPaused && activeKind == nil { resetAllSchedules() }
        refreshStatus(now: Date())
        prefsWindow?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
