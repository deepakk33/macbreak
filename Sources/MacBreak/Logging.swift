import Foundation

/// launchd redirects stdout to /tmp/macbreak.out.log, which is the only way to
/// see what a Dock-less background app is doing.
func log(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    print("[\(stamp)] \(message)")
    fflush(stdout)
}
