import Foundation

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

    /// Writes the plist and stops there: launchd loads it at the next login.
    /// Bootstrapping it now would start a second copy, which sees this one,
    /// exits, and is respawned by KeepAlive every ten seconds, forever.
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
        Prefs.startAtLogin = true
        log("launch agent installed")
    }

    static func uninstall() {
        try? FileManager.default.removeItem(at: plistURL)
        Prefs.startAtLogin = false
        // Booting out our own job would kill this very process. With the file
        // gone, launchd simply will not start it at the next login.
        if !isManagedByLaunchd {
            run(["bootout", "gui/\(getuid())/\(Const.agentLabel)"])
        }
        log("launch agent removed")
    }

    /// `brew upgrade` runs the old cask's uninstall, which deletes the agent,
    /// then reopens the new app. The choice is remembered separately from the
    /// file, so the agent comes back instead of silently switching off.
    static func restoreIfWanted() {
        // A bare demo binary must never become the login item.
        guard Bundle.main.bundleIdentifier != nil else { return }
        if isInstalled {
            Prefs.startAtLogin = true
        } else if Prefs.startAtLogin {
            log("launch agent missing - restoring it")
            install()
        }
    }

    /// Boots the launchd job out, which also terminates this process.
    static func bootout() {
        run(["bootout", "gui/\(getuid())/\(Const.agentLabel)"])
    }

    private static func run(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
