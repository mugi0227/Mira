import Foundation
@testable import Mira

enum TestFixtures {
    static let calendar = Calendar.mira
    static let september = MonthKey(year: 2026, month: 9).firstDay

    static func date(day: Int, hour: Int = 9) -> Date {
        let base = calendar.date(byAdding: .day, value: day - 1, to: september) ?? september
        return base.setting(hour: hour, calendar: calendar)
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        )) ?? .now
    }

    static func event(
        title: String = "予定",
        day: Int,
        hour: Int = 18,
        duration: Int = 2,
        load: LoadClass = .normal,
        kind: CalendarItemKind = .confirmed,
        marginKind: MarginKind? = nil
    ) -> CalendarItemSnapshot {
        let start = date(day: day, hour: hour)
        return CalendarItemSnapshot(
            id: UUID(),
            title: title,
            startDate: start,
            endDate: calendar.date(byAdding: .hour, value: duration, to: start) ?? start,
            isAllDay: false,
            kind: kind,
            marginKind: marginKind,
            loadClass: load,
            loadReason: "test",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )
    }

    static func goal(_ kind: MarginKind, count: Int, priority: Int? = nil) -> MarginGoalSnapshot {
        MarginGoalSnapshot(
            id: UUID(),
            year: 2026,
            month: 9,
            kind: kind,
            targetCount: count,
            durationHours: kind.defaultDurationHours,
            priority: priority ?? kind.defaultPriority,
            isEnabled: true
        )
    }
}
