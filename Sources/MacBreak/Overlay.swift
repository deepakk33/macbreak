import Cocoa

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
struct OverlayChrome {
    let countdown: NSTextField
    let gauge: RestGauge
}

enum OverlayPalette {
    /// Not fully opaque: enough of the desktop shows through the blur to feel
    /// like a pause rather than a crash, while staying unusable for work.
    static let tintAlpha: CGFloat = 0.72
    static let windowAlpha: CGFloat = 0.98

    static let tint = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: tintAlpha)
    static let primaryText = NSColor(calibratedWhite: 0.97, alpha: 1.0)
    static let secondaryText = NSColor(calibratedWhite: 0.62, alpha: 1.0)
    static let countdownText = NSColor(calibratedWhite: 1.0, alpha: 0.88)

    static let snooze = NSColor(calibratedWhite: 1.0, alpha: 0.12)
}
