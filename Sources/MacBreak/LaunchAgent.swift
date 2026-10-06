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
        run(["bootstrap", "gui/\(getuid())", plistURL.path])
        log("launch agent installed")
    }

    static func uninstall() {
        run(["bootout", "gui/\(getuid())/\(Const.agentLabel)"])
        try? FileManager.default.removeItem(at: plistURL)
        log("launch agent removed")
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
