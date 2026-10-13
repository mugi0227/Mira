import Foundation

/// Coarse availability only. Titles and calendar identifiers never enter the shared view.
struct FriendAvailability: Sendable {
    struct Band: Identifiable, Sendable {
        let title: String
        let isBusy: Bool
        var id: String { title }
        var label: String { "\(title) \(isBusy ? "予定" : "空き")" }
    }
    let bands: [Band]
    let hasAllDayEvent: Bool
    var summary: String {
        if hasAllDayEvent { return "終日予定" }
        if bands.allSatisfy({ !$0.isBusy }) { return "終日空き" }
        return bands.map(\.label).joined(separator: "、")
    }

    init(date: Date, items: [CalendarItemSnapshot], baseRules: [BaseAvailabilityRule] = [], calendar: Calendar = .mira) {
        let day = calendar.startOfDay(for: date)
        let nextDay = day.addingDays(1, calendar: calendar)
        let relevant = items.filter { $0.kind != .birthday && $0.startDate < nextDay && $0.endDate > day }
        hasAllDayEvent = relevant.contains { $0.isAllDay }
        let allDay = hasAllDayEvent
        let weekday = calendar.component(.weekday, from: day)
        let work = baseRules.filter { $0.weekday == weekday }.map {
            DateInterval(start: day.addingTimeInterval(Double($0.startMinute) * 60),
                         end: day.addingTimeInterval(Double($0.endMinute) * 60))
        }
        bands = [("朝", 8, 12), ("昼", 12, 18), ("夜", 18, 24)].map { title, start, end in
            let interval = DateInterval(start: day.setting(hour: start, calendar: calendar),
                                        end: end == 24 ? nextDay : day.setting(hour: end, calendar: calendar))
            let occupied = relevant.map(\.occupiedInterval) + work
            return Band(title: title, isBusy: allDay || occupied.contains {
                $0.start < interval.end && $0.end > interval.start
            })
        }
    }
}

extension CalendarItemSnapshot {
    func overlapsDay(_ date: Date, calendar: Calendar = .mira) -> Bool {
        let start = calendar.startOfDay(for: date)
        return startDate < start.addingDays(1, calendar: calendar) && endDate > start
    }
}
