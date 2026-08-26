import Foundation

protocol MiraClock: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
}

struct SystemClock: MiraClock {
    var now: Date { .now }
    var calendar: Calendar { .mira }
}

struct DemoClock: MiraClock {
    let now: Date
    var calendar: Calendar { .mira }

    static let standard: DemoClock = {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 1
        components.hour = 10
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return DemoClock(now: Calendar.mira.date(from: components) ?? .now)
    }()
}
