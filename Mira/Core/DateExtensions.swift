import Foundation

extension Calendar {
    static var mira: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }
}

extension Date {
    func startOfDay(calendar: Calendar = .mira) -> Date {
        calendar.startOfDay(for: self)
    }

    func addingDays(_ value: Int, calendar: Calendar = .mira) -> Date {
        calendar.date(byAdding: .day, value: value, to: self) ?? self
    }

    func addingMonths(_ value: Int, calendar: Calendar = .mira) -> Date {
        calendar.date(byAdding: .month, value: value, to: self) ?? self
    }

    func setting(hour: Int, minute: Int = 0, calendar: Calendar = .mira) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self
    }

    var japaneseMonthTitle: String {
        formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "ja_JP")))
    }

    var japaneseDayTitle: String {
        formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "ja_JP")))
    }

    var japaneseShortDate: String {
        formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
    }
}

extension DateInterval {
    func overlapsOrTouches(_ other: DateInterval) -> Bool {
        start <= other.end && other.start <= end
    }
}
