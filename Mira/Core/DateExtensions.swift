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
        formatted(Date.FormatStyle.mira.year().month(.wide))
    }

    var japaneseDayTitle: String {
        formatted(Date.FormatStyle.mira.month().day().weekday(.wide))
    }

    var japaneseShortDate: String {
        formatted(Date.FormatStyle.mira.month().day().weekday(.abbreviated))
    }
}

extension Date.FormatStyle {
    /// All scheduling math runs on `Calendar.mira`, so display must use the
    /// same time zone; otherwise a 9:00 plan reads 0:00 on a UTC device.
    static var mira: Date.FormatStyle {
        Date.FormatStyle(locale: Locale(identifier: "ja_JP"), calendar: .mira, timeZone: Calendar.mira.timeZone)
    }
}

extension DateFormatter {
    static func mira(_ format: String, locale: Locale = Locale(identifier: "ja_JP")) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = .mira
        formatter.timeZone = Calendar.mira.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }
}

extension DateInterval {
    func overlapsOrTouches(_ other: DateInterval) -> Bool {
        start <= other.end && other.start <= end
    }
}
