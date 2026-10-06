import Cocoa

// MARK: - Constants

enum Const {
    static let agentLabel = "com.user.macbreak"
    static let defaultBreakMinutes = 30
    static let defaultSnoozeMinutes = 10
    /// How often the overlay re-asserts itself over other apps while visible.
    static let raiseInterval: TimeInterval = 0.7
}

let breakPrompts = [
    "Look 20 feet away for 20 seconds",
    "Roll your shoulders back, slowly",
    "Rotate your neck — left, then right",
    "Stand up and stretch your spine",
    "Unclench your jaw. Drop your shoulders.",
    "Blink hard ten times, then look out a window",
    "Open your hands wide, stretch the fingers"
]

// MARK: - Preferences

/// Thin UserDefaults wrapper. Minutes on the surface, seconds for the timers.
enum Prefs {
    private static let breakKey = "macbreak.breakMinutes"
    private static let snoozeKey = "macbreak.snoozeMinutes"

    static var breakMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: breakKey)
            return stored > 0 ? stored : Const.defaultBreakMinutes
        }
        set { UserDefaults.standard.set(max(1, newValue), forKey: breakKey) }
    }

    static var snoozeMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: snoozeKey)
            return stored > 0 ? stored : Const.defaultSnoozeMinutes
        }
        set { UserDefaults.standard.set(max(1, newValue), forKey: snoozeKey) }
    }

    /// Testing hook: MACBREAK_BREAK_SECONDS=8 ./MacBreak overrides the break interval.
    private static var envOverride: TimeInterval? {
        guard let raw = ProcessInfo.processInfo.environment["MACBREAK_BREAK_SECONDS"],
              let seconds = Double(raw), seconds > 0 else { return nil }
        return seconds
    }

    static var breakInterval: TimeInterval { envOverride ?? TimeInterval(breakMinutes * 60) }
    static var snoozeInterval: TimeInterval { envOverride ?? TimeInterval(snoozeMinutes * 60) }
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
        _ = run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    static func uninstall() {
        _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(Const.agentLabel)"])
        try? FileManager.default.removeItem(at: plistURL)
    }

    /// Boots the launchd job out, which also terminates this process.
    static func bootout() {
        _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(Const.agentLabel)"])
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}

// MARK: - Overlay

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

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    // Timers
    private var breakTimer: Timer?
    private var tickTimer: Timer?
    private var raiseTimer: Timer?
    private var deadline: Date?
    private var isPaused = false

    // Overlay
    private var overlayWindows: [NSWindow] = []

    // Menu bar
    private var statusItem: NSStatusItem!
    private var countdownItem: NSMenuItem!
    private var pauseItem: NSMenuItem!

    // Preferences
    private var prefsWindow: NSWindow?
    private var breakField: NSTextField?
    private var snoozeField: NSTextField?
    private var loginCheckbox: NSButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildStatusItem()
        scheduleBreak(after: Prefs.breakInterval)
        startTicking()
    }

    // MARK: Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "☕ --:--"

        let menu = NSMenu()

        countdownItem = NSMenuItem(title: "Next break in --:--", action: nil, keyEquivalent: "")
        countdownItem.isEnabled = false
        menu.addItem(countdownItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Take Break Now",
                                action: #selector(takeBreakNow),
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

    private func startTicking() {
        tickTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshCountdown()
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
        refreshCountdown()
    }

    private func refreshCountdown() {
        guard !isPaused else {
            statusItem.button?.title = "☕ paused"
            countdownItem.title = "Paused"
            return
        }
        guard overlayWindows.isEmpty else {
            statusItem.button?.title = "☕ break"
            countdownItem.title = "On a break"
            return
        }
        guard let deadline = deadline else { return }
        let remaining = max(0, Int(deadline.timeIntervalSinceNow.rounded()))
        let clock = String(format: "%02d:%02d", remaining / 60, remaining % 60)
        statusItem.button?.title = "☕ \(clock)"
        countdownItem.title = "Next break in \(clock)"
    }

    // MARK: Timer

    private func scheduleBreak(after seconds: TimeInterval) {
        breakTimer?.invalidate()
        deadline = Date().addingTimeInterval(seconds)
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            self?.showOverlay()
        }
        // .common keeps the timer alive during menu tracking / window drags.
        RunLoop.main.add(timer, forMode: .common)
        breakTimer = timer
        refreshCountdown()
    }

    // MARK: Menu actions

    @objc private func takeBreakNow() {
        showOverlay()
    }

    @objc private func togglePause() {
        isPaused.toggle()
        if isPaused {
            breakTimer?.invalidate()
            breakTimer = nil
            deadline = nil
            pauseItem.title = "Resume"
        } else {
            pauseItem.title = "Pause"
            scheduleBreak(after: Prefs.breakInterval)
        }
        refreshCountdown()
    }

    @objc private func quitApp() {
        // KeepAlive would respawn us, so unload the job instead of plain exit.
        if LaunchAgent.isManagedByLaunchd {
            LaunchAgent.bootout()
        }
        NSApp.terminate(nil)
    }

    // MARK: Overlay lifecycle

    private func showOverlay() {
        guard overlayWindows.isEmpty else { return }

        let prompt = breakPrompts.randomElement() ?? breakPrompts[0]

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
                                                 prompt: prompt)
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        overlayWindows.first?.makeKeyAndOrderFront(nil)
        overlayWindows.first?.makeFirstResponder(overlayWindows.first?.contentView)

        startRaising()
        refreshCountdown()
    }

    private func dismissOverlay(nextInterval: TimeInterval) {
        stopRaising()
        for window in overlayWindows {
            window.orderOut(nil)
            window.close()
        }
        overlayWindows.removeAll()
        NSApp.hide(nil)
        isPaused = false
        pauseItem.title = "Pause"
        scheduleBreak(after: nextInterval)
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

    @objc private func doneTapped() {
        dismissOverlay(nextInterval: Prefs.breakInterval)
    }

    @objc private func snoozeTapped() {
        dismissOverlay(nextInterval: Prefs.snoozeInterval)
    }

    // MARK: Overlay view

    private func makeOverlayView(frame: NSRect, prompt: String) -> NSView {
        let root = OverlayContentView(frame: frame)
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1.0).cgColor

        let centerX = frame.midX
        let centerY = frame.midY

        let title = makeLabel(text: "TIME FOR A BREAK",
                              size: 72,
                              weight: .bold,
                              color: NSColor(calibratedRed: 0.42, green: 0.85, blue: 0.72, alpha: 1.0),
                              width: frame.width)
        title.frame.origin = NSPoint(x: 0, y: centerY + 110)
        root.addSubview(title)

        let subtitle = makeLabel(text: prompt,
                                 size: 34,
                                 weight: .medium,
                                 color: NSColor(calibratedWhite: 0.92, alpha: 1.0),
                                 width: frame.width)
        subtitle.frame.origin = NSPoint(x: 0, y: centerY + 30)
        root.addSubview(subtitle)

        let hint = makeLabel(text: "Stand up · Look away · Breathe",
                             size: 20,
                             weight: .regular,
                             color: NSColor(calibratedWhite: 0.55, alpha: 1.0),
                             width: frame.width)
        hint.frame.origin = NSPoint(x: 0, y: centerY - 20)
        root.addSubview(hint)

        let buttonWidth: CGFloat = 240
        let buttonHeight: CGFloat = 64
        let gap: CGFloat = 32
        let buttonY = centerY - 140

        let done = makeFlatButton(title: "Done",
                                  action: #selector(doneTapped),
                                  background: NSColor(calibratedRed: 0.20, green: 0.70, blue: 0.52, alpha: 1.0))
        done.frame = NSRect(x: centerX - buttonWidth - gap / 2, y: buttonY,
                            width: buttonWidth, height: buttonHeight)
        root.addSubview(done)

        let snooze = makeFlatButton(title: "Snooze (\(Prefs.snoozeMinutes) min)",
                                    action: #selector(snoozeTapped),
                                    background: NSColor(calibratedWhite: 0.22, alpha: 1.0))
        snooze.frame = NSRect(x: centerX + gap / 2, y: buttonY,
                              width: buttonWidth, height: buttonHeight)
        root.addSubview(snooze)

        return root
    }

    private func makeLabel(text: String,
                           size: CGFloat,
                           weight: NSFont.Weight,
                           color: NSColor,
                           width: CGFloat) -> NSTextField {
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
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 22, weight: .semibold)
            ]
        )
        return button
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 210),
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
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 210))

        let breakLabel = NSTextField(labelWithString: "Break interval")
        breakLabel.frame = NSRect(x: 24, y: 152, width: 150, height: 20)
        root.addSubview(breakLabel)

        let breakInput = NSTextField(frame: NSRect(x: 190, y: 150, width: 70, height: 24))
        breakInput.alignment = .right
        root.addSubview(breakInput)
        breakField = breakInput

        let breakUnit = NSTextField(labelWithString: "min")
        breakUnit.frame = NSRect(x: 268, y: 152, width: 50, height: 20)
        root.addSubview(breakUnit)

        let snoozeLabel = NSTextField(labelWithString: "Snooze length")
        snoozeLabel.frame = NSRect(x: 24, y: 114, width: 150, height: 20)
        root.addSubview(snoozeLabel)

        let snoozeInput = NSTextField(frame: NSRect(x: 190, y: 112, width: 70, height: 24))
        snoozeInput.alignment = .right
        root.addSubview(snoozeInput)
        snoozeField = snoozeInput

        let snoozeUnit = NSTextField(labelWithString: "min")
        snoozeUnit.frame = NSRect(x: 268, y: 114, width: 50, height: 20)
        root.addSubview(snoozeUnit)

        let checkbox = NSButton(checkboxWithTitle: "Start at login", target: nil, action: nil)
        checkbox.frame = NSRect(x: 24, y: 70, width: 200, height: 22)
        root.addSubview(checkbox)
        loginCheckbox = checkbox

        let save = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 240, y: 20, width: 96, height: 32)
        root.addSubview(save)

        let note = NSTextField(labelWithString: "Saving restarts the current countdown.")
        note.font = NSFont.systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 24, y: 26, width: 220, height: 18)
        root.addSubview(note)

        return root
    }

    private func loadPrefsIntoFields() {
        breakField?.stringValue = String(Prefs.breakMinutes)
        snoozeField?.stringValue = String(Prefs.snoozeMinutes)
        loginCheckbox?.state = LaunchAgent.isInstalled ? .on : .off
    }

    @objc private func savePreferences() {
        if let value = Int(breakField?.stringValue ?? ""), value > 0 {
            Prefs.breakMinutes = value
        }
        if let value = Int(snoozeField?.stringValue ?? ""), value > 0 {
            Prefs.snoozeMinutes = value
        }

        let wantsLogin = loginCheckbox?.state == .on
        if wantsLogin && !LaunchAgent.isInstalled {
            LaunchAgent.install()
        } else if !wantsLogin && LaunchAgent.isInstalled {
            LaunchAgent.uninstall()
        }

        loadPrefsIntoFields()
        if !isPaused { scheduleBreak(after: Prefs.breakInterval) }
        prefsWindow?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
