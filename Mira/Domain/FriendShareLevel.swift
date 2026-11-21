import Foundation

enum FriendShareLevel: String, CaseIterable {
    case hidden, freeOnly, busyTimes, titles

    var title: String {
        switch self {
        case .hidden: "見せない"
        case .freeOnly: "空きだけ"
        case .busyTimes: "埋まりだけ"
        case .titles: "予定名まで"
        }
    }

    var explanation: String {
        switch self {
        case .hidden: "予定を共有しません。"
        case .freeOnly: "朝 8–12時・昼 12–18時・夜 18–24時。予定や仕事は「予定」と表示します。"
        case .busyTimes: "埋まっている時間だけを表示します。予定名は表示しません。"
        case .titles: "確定予定の名前と時間を表示します。余白は「予定あり」と表示します。"
        }
    }
}

struct FriendDayContent {
    let lines: [String]

    init(date: Date, items: [CalendarItemSnapshot], baseRules: [BaseAvailabilityRule] = [], level: FriendShareLevel = .freeOnly, calendar: Calendar = .mira) {
        guard level != .hidden else { lines = []; return }
        if level == .freeOnly {
            let availability = FriendAvailability(date: date, items: items, baseRules: baseRules, calendar: calendar)
            lines = availability.hasAllDayEvent || availability.bands.allSatisfy { !$0.isBusy }
                ? [availability.summary] : availability.bands.map(\.label)
            return
        }
        let start = calendar.startOfDay(for: date)
        let end = start.addingDays(1, calendar: calendar)
        let formatter = DateFormatter.mira("HH:mm")
        func range(_ from: Date, _ to: Date) -> String {
            "\(formatter.string(from: max(start, from)))–\(to >= end ? "24:00" : formatter.string(from: to))"
        }
        var entries: [(Date, String)] = items.filter {
            $0.kind != .birthday && $0.overlapsDay(date, calendar: calendar)
        }.map { item in
            let title = level == .titles && item.kind == .confirmed ? item.title : "予定あり"
            return (item.startDate, "\(item.isAllDay ? "終日" : range(item.startDate, item.endDate)) \(title)")
        }
        for rule in baseRules where rule.weekday == calendar.component(.weekday, from: start) {
            let from = start.addingTimeInterval(Double(rule.startMinute) * 60)
            let to = start.addingTimeInterval(Double(rule.endMinute) * 60)
            entries.append((from, "\(range(from, to)) 予定あり"))
        }
        lines = entries.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
