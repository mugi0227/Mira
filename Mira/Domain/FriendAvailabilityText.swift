import Foundation

/// Share text follows the recipient's level; margins never reveal titles or kinds.
enum FriendAvailabilityText {
    static let bandHours: [(title: String, end: Int)] = [("朝", 12), ("昼", 18), ("夜", 24)]

    static func text(
        from now: Date,
        days: Int = 14,
        items: [CalendarItemSnapshot],
        baseRules: [BaseAvailabilityRule] = [],
        level: FriendShareLevel = .freeOnly,
        calendar: Calendar = .mira
    ) -> String {
        guard level != .hidden else { return "" }
        guard days > 0 else { return "" }
        if level != .freeOnly {
            let formatter = DateFormatter.mira("M/d(E)")
            let header = "この\(days / 7)週間の予定です（\(level.title)）。" + (level == .titles ? "余白は「予定あり」と表示します。" : "")
            let lines = (0..<days).map { offset in
                let day = calendar.startOfDay(for: now).addingDays(offset, calendar: calendar)
                let content = FriendDayContent(date: day, items: items, baseRules: baseRules, level: level, calendar: calendar)
                return "・\(formatter.string(from: day)) \(content.lines.isEmpty ? "予定なし" : content.lines.joined(separator: "、"))"
            }
            return ([header] + lines).joined(separator: "\n")
        }
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
