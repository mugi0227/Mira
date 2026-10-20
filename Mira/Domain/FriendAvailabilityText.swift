import Foundation

/// The text version of the friend share: only which coarse bands are free.
/// Like the image, it never contains titles, margin kinds or calendar names.
enum FriendAvailabilityText {
    static let bandHours: [(title: String, end: Int)] = [("朝", 12), ("昼", 18), ("夜", 24)]

    static func text(
        from now: Date,
        days: Int = 14,
        items: [CalendarItemSnapshot],
        baseRules: [BaseAvailabilityRule] = [],
        calendar: Calendar = .mira
    ) -> String {
        let formatter = DateFormatter.mira("M/d(E)")
        let today = calendar.startOfDay(for: now)
        let lines: [String] = (0..<days).compactMap { offset in
            let day = today.addingDays(offset, calendar: calendar)
            let availability = FriendAvailability(date: day, items: items, baseRules: baseRules, calendar: calendar)
            guard !availability.hasAllDayEvent else { return nil }
            let free = zip(availability.bands, bandHours).filter { band, hours in
                let end = hours.end == 24 ? day.addingDays(1, calendar: calendar) : day.setting(hour: hours.end, calendar: calendar)
                return !band.isBusy && end > now
            }.map(\.0.title)
            guard !free.isEmpty else { return nil }
            let label = free.count == bandHours.count ? "終日" : free.joined(separator: "・")
            return "・\(formatter.string(from: day)) \(label)"
        }
        guard !lines.isEmpty else { return "この\(days / 7)週間は、空いている時間帯が見つかりませんでした。" }
        return (["この\(days / 7)週間で空いている時間帯です（朝 8–12時・昼 12–18時・夜 18–24時）。"] + lines)
            .joined(separator: "\n")
    }
}
