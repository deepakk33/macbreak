import Cocoa

/// MacBreak uses SF Rounded rather than the default system face. The overlay is
/// asking someone to relax; geometric sans-serif at 64pt does not.
enum Typography {

    static func rounded(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded),
              let font = NSFont(descriptor: descriptor, size: size) else { return base }
        return font
    }

    /// Rounded, but with digits that do not jitter as the countdown ticks.
    static func roundedMonospacedDigits(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded),
              let font = NSFont(descriptor: descriptor, size: size) else { return base }
        return font
    }
}
