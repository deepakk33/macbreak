import Cocoa

enum BreakKind {
    case lookAway
    case walk

    var heading: String {
        switch self {
        case .lookAway: return "Rest your eyes"
        case .walk:     return "Time for a walk"
        }
    }

    /// One of these is drawn at random, so the overlay does not become wallpaper.
    var prompts: [String] {
        switch self {
        case .lookAway:
            return [
                "Look at something 20 metres away",
                "Roll your eyes slowly — clockwise, then back",
                "Cup your palms over your eyes and sit in the dark",
                "Find the furthest thing you can see, and hold it",
                "Blink hard ten times, then look out of a window",
                "Trace the edge of the room with your eyes",
                "Look far, then near, then far again — five times",
                "Close your eyes and let them rest completely",
                "Soften your focus and let the screen go blurry",
                "Look up at the ceiling, then down at the floor"
            ]
        case .walk:
            return [
                "Stand up and walk it off",
                "Take a lap — stairs count double",
                "Go refill your water, the long way round",
                "Step outside and look at the sky",
                "Walk to the furthest window and back",
                "Roll your shoulders, then go find a corridor",
                "Put your feet on the floor and move them",
                "Stretch your back, then take the long route somewhere"
            ]
        }
    }

    var hint: String {
        switch self {
        case .lookAway: return "Unclench your jaw  ·  Drop your shoulders  ·  Breathe out slowly"
        case .walk:     return "Move your legs  ·  Loosen your neck  ·  Get some air"
        }
    }

    /// Muted, low-saturation accents — a break screen should not shout.
    var accent: NSColor {
        switch self {
        case .lookAway: return NSColor(calibratedRed: 0.56, green: 0.81, blue: 0.74, alpha: 1.0)
        case .walk:     return NSColor(calibratedRed: 0.91, green: 0.76, blue: 0.55, alpha: 1.0)
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
