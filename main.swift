import Cocoa

// MARK: - Constants

enum Const {
    static let agentLabel = "com.user.macbreak"
    static let bundleID = "com.user.macbreak"
    /// Posted by a second launch (Spotlight) to tell the running copy to show preferences.
    static let showPrefsNotification = Notification.Name("com.user.macbreak.showPreferences")
    /// How often the overlay re-asserts itself over other apps while visible.
    static let raiseInterval: TimeInterval = 0.7
}

enum Defaults {
    static let lookAwayIntervalMinutes = 30
    static let lookAwayDurationSeconds = 30
    static let walkIntervalMinutes = 120
    static let walkDurationMinutes = 10
    static let snoozeMinutes = 10
    static let lockResetMinutes = 5
}

// MARK: - Break kinds

enum BreakKind {
    case lookAway
    case walk

    var heading: String {
        switch self {
        case .lookAway: return "LOOK AWAY"
        case .walk:     return "TIME FOR A WALK"
        }
    }

    var prompts: [String] {
        switch self {
        case .lookAway:
            return [
                "Focus on something 20 feet away",
                "Look out of the nearest window",
                "Let your eyes rest on the far wall",
                "Blink slowly, then look into the distance"
            ]
        case .walk:
            return [
                "Stand up and walk it off",
                "Take a lap — stairs count",
                "Go refill your water, the long way",
                "Step outside for a few minutes"
            ]
        }
    }

    var hint: String {
        switch self {
        case .lookAway: return "Unclench your jaw · Drop your shoulders · Breathe"
        case .walk:     return "Move your legs · Roll your shoulders · Get some air"
        }
    }

    var accent: NSColor {
        switch self {
        case .lookAway: return NSColor(calibratedRed: 0.42, green: 0.85, blue: 0.72, alpha: 1.0)
        case .walk:     return NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.35, alpha: 1.0)
        }
    }

    var glyph: String {
        switch self {
        case .lookAway: return "☕"
        case .walk:     return "🚶"
        }
    }

    /// How long the overlay holds the screen before "Done" unlocks.
    var duration: TimeInterval {
        switch self {
        case .lookAway: return Prefs.lookAwayDuration
        case .walk:     return Prefs.walkDuration
        }
    }
}

// MARK: - Preferences

/// Thin UserDefaults wrapper. Human units on the surface, seconds for the timers.
enum Prefs {
    private static let lookAwayIntervalKey = "macbreak.lookAwayIntervalMinutes"
    private static let lookAwayDurationKey = "macbreak.lookAwayDurationSeconds"
    private static let walkIntervalKey = "macbreak.walkIntervalMinutes"
    private static let walkDurationKey = "macbreak.walkDurationMinutes"
    private static let snoozeKey = "macbreak.snoozeMinutes"
    private static let lockResetKey = "macbreak.lockResetMinutes"

    private static func read(_ key: String, fallback: Int) -> Int {
        let stored = UserDefaults.standard.integer(forKey: key)
        return stored > 0 ? stored : fallback
    }

    private static func write(_ key: String, _ value: Int) {
        UserDefaults.standard.set(max(1, value), forKey: key)
    }

    static var lookAwayIntervalMinutes: Int {
        get { read(lookAwayIntervalKey, fallback: Defaults.lookAwayIntervalMinutes) }
        set { write(lookAwayIntervalKey, newValue) }
    }

    static var lookAwayDurationSeconds: Int {
        get { read(lookAwayDurationKey, fallback: Defaults.lookAwayDurationSeconds) }
        set { write(lookAwayDurationKey, newValue) }
    }

    static var walkIntervalMinutes: Int {
        get { read(walkIntervalKey, fallback: Defaults.walkIntervalMinutes) }
        set { write(walkIntervalKey, newValue) }
    }

    static var walkDurationMinutes: Int {
        get { read(walkDurationKey, fallback: Defaults.walkDurationMinutes) }
        set { write(walkDurationKey, newValue) }
    }

    static var snoozeMinutes: Int {
        get { read(snoozeKey, fallback: Defaults.snoozeMinutes) }
        set { write(snoozeKey, newValue) }
    }

    static var lockResetMinutes: Int {
        get { read(lockResetKey, fallback: Defaults.lockResetMinutes) }
        set { write(lockResetKey, newValue) }
    }

    /// Testing hooks, so the overlays can be demonstrated without waiting.
    private static func envSeconds(_ name: String) -> TimeInterval? {
        guard let raw = ProcessInfo.processInfo.environment[name],
              let seconds = Double(raw), seconds > 0 else { return nil }
        return seconds
    }

    static var lookAwayInterval: TimeInterval {
        envSeconds("MACBREAK_BREAK_SECONDS") ?? TimeInterval(lookAwayIntervalMinutes * 60)
    }

    static var walkInterval: TimeInterval {
        envSeconds("MACBREAK_WALK_SECONDS") ?? TimeInterval(walkIntervalMinutes * 60)
    }

    static var lookAwayDuration: TimeInterval {
        envSeconds("MACBREAK_DURATION_SECONDS") ?? TimeInterval(lookAwayDurationSeconds)
    }

    static var walkDuration: TimeInterval {
        envSeconds("MACBREAK_DURATION_SECONDS") ?? TimeInterval(walkDurationMinutes * 60)
    }

    static var snoozeInterval: TimeInterval {
        envSeconds("MACBREAK_BREAK_SECONDS") ?? TimeInterval(snoozeMinutes * 60)
    }

    static var lockResetThreshold: TimeInterval {
        envSeconds("MACBREAK_LOCK_RESET_SECONDS") ?? TimeInterval(lockResetMinutes * 60)
    }
}

// MARK: - Clock formatting

enum Clock {
    /// mm:ss, or h:mm:ss once an hour or more remains.
    static func format(_ seconds: Int) -> String {
        let value = max(0, seconds)
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

// MARK: - Launch agent management

/// Installs/removes the launchd agent that starts MacBreak at login.
enum LaunchAgent {
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Const.agentLabel).plist")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// True when this process was spawned by launchd rather than a terminal.
    static var isManagedByLaunchd: Bool {
        ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"]?.contains(Const.agentLabel) ?? false
    }

    static func install() {
        guard let executable = Bundle.main.executablePath else { return }
        let plist: [String: Any] = [
            "Label": Const.agentLabel,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Interactive",
            "StandardOutPath": "/tmp/macbreak.out.log",
            "StandardErrorPath": "/tmp/macbreak.err.log"
        ]
        let directory = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist,
                                                             format: .xml,
                                                             options: 0) else { return }
        try? data.write(to: plistURL)
        // Already-running instance keeps running; this only registers it for next login.
        run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    static func uninstall() {
        run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(Const.agentLabel)"])
        try? FileManager.default.removeItem(at: plistURL)
    }

    /// Boots the launchd job out, which also terminates this process.
    static func bootout() {
        run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(Const.agentLabel)"])
    }

    private static func run(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

// MARK: - Overlay windows

/// Borderless windows refuse key status by default; we need focus so the user
/// cannot keep typing into whatever is underneath.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Swallows every key event so stray typing never reaches the app behind.
final class OverlayContentView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) { NSSound.beep() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true }
}

/// The controls on one screen's overlay that need updating every second.
private struct OverlayChrome {
    let countdown: NSTextField
    let done: NSButton
}

// MARK: - App

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

        // Launched from Spotlight or Finder rather than by launchd: the user
        // went looking for the app, so show them something.
        if Bundle.main.bundleIdentifier != nil && !LaunchAgent.isManagedByLaunchd {
            openPreferences()
        }
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

    // MARK: Scheduling

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

    // MARK: Screen lock

    private func observeScreenLock() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self,
                           selector: #selector(screenLocked),
                           name: NSNotification.Name("com.apple.screenIsLocked"),
                           object: nil)
        center.addObserver(self,
                           selector: #selector(screenUnlocked),
                           name: NSNotification.Name("com.apple.screenIsUnlocked"),
                           object: nil)
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
        if activeKind != nil { closeOverlay() }
        isPaused = false
        pauseItem.title = "Pause"
        resetAllSchedules()
        refreshStatus(now: Date())
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "☕ --:--"

        let menu = NSMenu()

        lookAwayItem = NSMenuItem(title: "Look away in --:--", action: nil, keyEquivalent: "")
        lookAwayItem.isEnabled = false
        menu.addItem(lookAwayItem)

        walkItem = NSMenuItem(title: "Walk in --:--", action: nil, keyEquivalent: "")
        walkItem.isEnabled = false
        menu.addItem(walkItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Look Away Now",
                                action: #selector(lookAwayNow),
                                keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Take Walk Break Now",
                                action: #selector(walkNow),
                                keyEquivalent: ""))

        pauseItem = NSMenuItem(title: "Pause", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(pauseItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Preferences…",
                                action: #selector(openPreferences),
                                keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit MacBreak",
                                action: #selector(quitApp),
                                keyEquivalent: "q"))

        for item in menu.items where item.action != nil { item.target = self }
        statusItem.menu = menu
    }

    private func refreshStatus(now: Date) {
        if let kind = activeKind, let endsAt = breakEndsAt {
            let remaining = Int(endsAt.timeIntervalSince(now).rounded())
            statusItem.button?.title = remaining > 0
                ? "\(kind.glyph) \(Clock.format(remaining))"
                : "\(kind.glyph) done"
            lookAwayItem.title = kind == .walk ? "Walk break in progress" : "Look-away break in progress"
            walkItem.title = remaining > 0 ? "Resting for \(Clock.format(remaining))" : "Press Done when ready"
            return
        }

        guard !isPaused else {
            statusItem.button?.title = "☕ paused"
            lookAwayItem.title = "Paused"
            walkItem.title = "Paused"
            return
        }

        let lookAwayLeft = remaining(until: lookAwayDue, now: now)
        let walkLeft = remaining(until: walkDue, now: now)
        lookAwayItem.title = "Look away in \(Clock.format(lookAwayLeft))"
        walkItem.title = "Walk in \(Clock.format(walkLeft))"

        // The status item shows whichever break lands first.
        if walkLeft < lookAwayLeft {
            statusItem.button?.title = "\(BreakKind.walk.glyph) \(Clock.format(walkLeft))"
        } else {
            statusItem.button?.title = "\(BreakKind.lookAway.glyph) \(Clock.format(lookAwayLeft))"
        }
    }

    private func remaining(until date: Date?, now: Date) -> Int {
        guard let date = date else { return 0 }
        return max(0, Int(date.timeIntervalSince(now).rounded()))
    }

    // MARK: Menu actions

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

    // MARK: Break lifecycle

    private func beginBreak(_ kind: BreakKind) {
        guard activeKind == nil else { return }

        activeKind = kind
        breakEndsAt = Date().addingTimeInterval(kind.duration)
        doneUnlocked = false

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
            window.isOpaque = true
            window.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1.0)
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.contentView = makeOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size),
                                                 kind: kind,
                                                 prompt: prompt)
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
                setButtonTitle(chrome.done, "Done in \(remaining)s", enabled: false)
            } else if !doneUnlocked {
                chrome.done.isEnabled = true
                setButtonTitle(chrome.done, "Done", enabled: true)
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

    // MARK: Overlay view

    private func makeOverlayView(frame: NSRect, kind: BreakKind, prompt: String) -> NSView {
        let root = OverlayContentView(frame: frame)
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1.0).cgColor

        let centerX = frame.midX
        let centerY = frame.midY

        let title = makeLabel(text: kind.heading, size: 64, weight: .bold,
                              color: kind.accent, width: frame.width)
        title.frame.origin = NSPoint(x: 0, y: centerY + 180)
        root.addSubview(title)

        let subtitle = makeLabel(text: prompt, size: 32, weight: .medium,
                                 color: NSColor(calibratedWhite: 0.92, alpha: 1.0), width: frame.width)
        subtitle.frame.origin = NSPoint(x: 0, y: centerY + 110)
        root.addSubview(subtitle)

        let countdown = makeLabel(text: Clock.format(Int(kind.duration)), size: 110, weight: .thin,
                                  color: NSColor(calibratedWhite: 1.0, alpha: 1.0), width: frame.width)
        countdown.font = NSFont.monospacedDigitSystemFont(ofSize: 110, weight: .thin)
        countdown.frame.origin = NSPoint(x: 0, y: centerY - 40)
        root.addSubview(countdown)

        let hint = makeLabel(text: kind.hint, size: 18, weight: .regular,
                             color: NSColor(calibratedWhite: 0.55, alpha: 1.0), width: frame.width)
        hint.frame.origin = NSPoint(x: 0, y: centerY - 90)
        root.addSubview(hint)

        let buttonWidth: CGFloat = 240
        let buttonHeight: CGFloat = 64
        let gap: CGFloat = 32
        let buttonY = centerY - 200

        let done = makeFlatButton(title: "Done in \(Int(kind.duration))s",
                                  action: #selector(doneTapped),
                                  background: NSColor(calibratedRed: 0.20, green: 0.70, blue: 0.52, alpha: 1.0))
        done.isEnabled = false
        setButtonTitle(done, "Done in \(Int(kind.duration))s", enabled: false)
        done.frame = NSRect(x: centerX - buttonWidth - gap / 2, y: buttonY,
                            width: buttonWidth, height: buttonHeight)
        root.addSubview(done)

        let snooze = makeFlatButton(title: "Snooze (\(Prefs.snoozeMinutes) min)",
                                    action: #selector(snoozeTapped),
                                    background: NSColor(calibratedWhite: 0.22, alpha: 1.0))
        snooze.frame = NSRect(x: centerX + gap / 2, y: buttonY,
                              width: buttonWidth, height: buttonHeight)
        root.addSubview(snooze)

        overlayChrome.append(OverlayChrome(countdown: countdown, done: done))
        return root
    }

    private func makeLabel(text: String, size: CGFloat, weight: NSFont.Weight,
                           color: NSColor, width: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.frame = NSRect(x: 0, y: 0, width: width, height: size * 1.4)
        return label
    }

    private func makeFlatButton(title: String, action: Selector, background: NSColor) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = background.cgColor
        button.layer?.cornerRadius = 12
        setButtonTitle(button, title, enabled: true)
        return button
    }

    /// NSButton ignores `isEnabled` for attributed titles, so dim it ourselves.
    private func setButtonTitle(_ button: NSButton, _ title: String, enabled: Bool) {
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: enabled ? NSColor.white : NSColor(calibratedWhite: 1.0, alpha: 0.45),
                .font: NSFont.systemFont(ofSize: 22, weight: .semibold)
            ]
        )
        button.layer?.opacity = enabled ? 1.0 : 0.55
    }

    // MARK: Preferences window

    @objc private func openPreferences() {
        if let window = prefsWindow {
            loadPrefsIntoFields()
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacBreak Preferences"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.contentView = makePrefsView()
        prefsWindow = window

        loadPrefsIntoFields()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makePrefsView() -> NSView {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 320))
        var y: CGFloat = 272

        func addRow(key: String, label: String, unit: String) {
            let caption = NSTextField(labelWithString: label)
            caption.frame = NSRect(x: 24, y: y + 2, width: 210, height: 20)
            root.addSubview(caption)

            let input = NSTextField(frame: NSRect(x: 244, y: y, width: 64, height: 24))
            input.alignment = .right
            root.addSubview(input)
            fields[key] = input

            let suffix = NSTextField(labelWithString: unit)
            suffix.frame = NSRect(x: 316, y: y + 2, width: 60, height: 20)
            root.addSubview(suffix)

            y -= 34
        }

        addRow(key: "lookAwayInterval", label: "Look away every", unit: "min")
        addRow(key: "lookAwayDuration", label: "Look away for", unit: "sec")
        addRow(key: "walkInterval", label: "Walk break every", unit: "min")
        addRow(key: "walkDuration", label: "Walk for", unit: "min")
        addRow(key: "snooze", label: "Snooze length", unit: "min")
        addRow(key: "lockReset", label: "Screen lock resets after", unit: "min")

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
        save.frame = NSRect(x: 280, y: 20, width: 96, height: 32)
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

// MARK: - Entry point

let app = NSApplication.shared

// Spotlight re-launch while a copy is already running: hand the request to the
// live instance and get out of the way, rather than running two schedulers.
if Bundle.main.bundleIdentifier != nil {
    let others = NSRunningApplication
        .runningApplications(withBundleIdentifier: Const.bundleID)
        .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if !others.isEmpty {
        DistributedNotificationCenter.default().postNotificationName(
            Const.showPrefsNotification, object: nil, userInfo: nil, deliverImmediately: true
        )
        exit(0)
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
