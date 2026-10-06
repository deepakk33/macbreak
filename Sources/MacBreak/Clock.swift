import Foundation

enum Clock {
    /// mm:ss, or h:mm:ss once an hour or more remains.
    static func format(_ seconds: Int) -> String {
        let value = max(0, seconds)
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
        }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    /// For button labels: "42s" under a minute, "9:55" above it. A ten minute
    /// walk counting down in raw seconds reads as a number, not as a duration.
    static func compact(_ seconds: Int) -> String {
        let value = max(0, seconds)
        if value < 60 { return "\(value)s" }
        if value >= 3600 {
            return String(format: "%d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
        }
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
