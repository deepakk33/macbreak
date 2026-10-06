import Cocoa

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
        // Posting is asynchronous; exiting immediately can drop the message.
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        exit(0)
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
