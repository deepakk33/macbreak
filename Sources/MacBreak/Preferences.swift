import Foundation

enum Const {
    static let agentLabel = "com.user.macbreak"
    static let bundleID = "com.user.macbreak"
    /// Posted by a second launch to tell the running copy to show preferences.
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
    static let statusTimerMinutes = 5
}

/// Thin UserDefaults wrapper. Human units on the surface, seconds for the timers.
enum Prefs {
    private static let lookAwayIntervalKey = "macbreak.lookAwayIntervalMinutes"
    private static let lookAwayDurationKey = "macbreak.lookAwayDurationSeconds"
    private static let walkIntervalKey = "macbreak.walkIntervalMinutes"
    private static let walkDurationKey = "macbreak.walkDurationMinutes"
    private static let snoozeKey = "macbreak.snoozeMinutes"
    private static let lockResetKey = "macbreak.lockResetMinutes"
    private static let statusTimerKey = "macbreak.statusTimerMinutes"
    private static let startAtLoginKey = "macbreak.startAtLogin"

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

    /// The menu bar stays quiet until a break is this close.
    static var statusTimerMinutes: Int {
        get { read(statusTimerKey, fallback: Defaults.statusTimerMinutes) }
        set { write(statusTimerKey, newValue) }
    }

    /// Whether the user wants the login agent, kept apart from the agent file
    /// itself because package upgrades delete that file.
    static var startAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: startAtLoginKey) }
        set { UserDefaults.standard.set(newValue, forKey: startAtLoginKey) }
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

    static var statusTimerThreshold: TimeInterval {
        envSeconds("MACBREAK_STATUS_TIMER_SECONDS") ?? TimeInterval(statusTimerMinutes * 60)
    }
}
