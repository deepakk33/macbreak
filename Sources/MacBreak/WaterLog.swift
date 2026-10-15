import Foundation

enum WaterAction: String, Codable {
    case drink, skip
}

struct WaterEvent: Codable {
    let date: Date
    let action: WaterAction
}

enum WaterLog {
    private static let key = "macbreak.waterLog"

    static func record(_ action: WaterAction) {
        var events = load()
        events.append(WaterEvent(date: Date(), action: action))
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        events = events.filter { $0.date > cutoff }
        save(events)
    }

    static func load() -> [WaterEvent] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let events = try? JSONDecoder().decode([WaterEvent].self, from: data) else {
            return []
        }
        return events
    }

    private static func save(_ events: [WaterEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func todayStats() -> (drinks: Int, skips: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let todayEvents = load().filter { $0.date >= today }
        let drinks = todayEvents.filter { $0.action == .drink }.count
        let skips = todayEvents.filter { $0.action == .skip }.count
        return (drinks, skips)
    }

    static func suggestion(currentInterval: Int) -> String? {
        let events = load()
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let recent = events.filter { $0.date > weekAgo }
        guard recent.count >= 10 else { return nil }

        let skips = recent.filter { $0.action == .skip }.count
        let skipRate = Double(skips) / Double(recent.count)

        if skipRate > 0.6 {
            let suggested = min(120, currentInterval + 15)
            return "You skip often — try \(suggested) min?"
        } else if skipRate < 0.2 {
            return "Great hydration habit!"
        }
        return nil
    }
}
