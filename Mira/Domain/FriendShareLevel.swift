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
    let gridLines: [String]

    init(date: Date, items: [CalendarItemSnapshot], baseRules: [BaseAvailabilityRule] = [], level: FriendShareLevel = .freeOnly, calendar: Calendar = .mira) {
        guard level != .hidden else { lines = []; gridLines = []; return }
        if level == .freeOnly {
            let availability = FriendAvailability(date: date, items: items, baseRules: baseRules, calendar: calendar)
            lines = availability.hasAllDayEvent || availability.bands.allSatisfy { !$0.isBusy }
                ? [availability.summary] : availability.bands.map(\.label)
            gridLines = lines
            return
        }
        let start = calendar.startOfDay(for: date)
        let end = start.addingDays(1, calendar: calendar)
        let formatter = DateFormatter.mira("HH:mm")
        func range(_ from: Date, _ to: Date) -> String {
            "\(formatter.string(from: max(start, from)))–\(to >= end ? "24:00" : formatter.string(from: to))"
        }
        func compactTime(_ date: Date) -> String {
            let minute = calendar.component(.minute, from: date)
            return minute == 0 ? String(calendar.component(.hour, from: date)) : DateFormatter.mira("H:mm").string(from: date)
        }
        func compactRange(_ interval: DateInterval) -> String {
            "\(compactTime(interval.start))–\(interval.end >= end ? "24" : compactTime(interval.end))"
        }
        let dayItems = items.filter { ($0.kind == .margin || $0.countsAgainstWhitespace) && $0.overlapsFriendShareDay(date, calendar: calendar) }
        let relevant = dayItems.filter(\.exactTimeKnown)
        let bodyItems = relevant.filter { $0.overlapsDay(date, calendar: calendar) }
        let undetermined = dayItems.filter { !$0.exactTimeKnown }
        func clipped(_ from: Date, _ to: Date) -> DateInterval {
            DateInterval(start: max(start, from), end: min(end, to))
        }
        let eventRanges = bodyItems.map { $0.isAllDay ? DateInterval(start: start, end: end) : clipped($0.startDate, $0.endDate) }
        let occupiedRanges = relevant.map { $0.isAllDay ? DateInterval(start: start, end: end) : clipped($0.occupiedInterval.start, $0.occupiedInterval.end) }
        let work = baseRules.filter {
            $0.weekday == calendar.component(.weekday, from: start) && $0.endMinute > $0.startMinute
        }.map {
            clipped(start.addingTimeInterval(Double($0.startMinute) * 60), start.addingTimeInterval(Double($0.endMinute) * 60))
        }
        func merged(_ intervals: [DateInterval]) -> [DateInterval] {
            intervals.sorted { $0.start < $1.start }.reduce(into: []) { result, interval in
                if let last = result.last, last.end >= interval.start {
                    result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
                } else {
                    result.append(interval)
                }
            }
        }
        if level == .busyTimes {
            let unknown = undetermined.isEmpty ? [] : ["時間未定 予定あり"]
            if relevant.contains(where: \.isAllDay) {
                lines = ["終日 予定あり"] + unknown
                gridLines = ["終日"] + unknown
            } else {
                let intervals = merged(occupiedRanges + work)
                lines = intervals.map { "\(range($0.start, $0.end)) 予定あり" } + unknown
                gridLines = intervals.map(compactRange) + unknown
            }
            return
        }
        var entries: [(date: Date, text: String, grid: String)] = zip(bodyItems, eventRanges).map { item, interval in
            let title = item.kind == .confirmed ? item.title : "予定あり"
            let grid = item.kind == .confirmed
                ? "\(item.isAllDay ? "終日" : compactTime(interval.start)) \(title)"
                : (item.isAllDay ? "終日 予定あり" : compactRange(interval))
            return (interval.start, "\(item.isAllDay ? "終日" : range(interval.start, interval.end)) \(title)", grid)
        }
        let covered = merged(eventRanges)
        for interval in merged(work + occupiedRanges) {
            var cursor = interval.start
            for body in covered where body.end > cursor && body.start < interval.end {
                if body.start > cursor {
                    let gap = DateInterval(start: cursor, end: body.start)
                    entries.append((gap.start, "\(range(gap.start, gap.end)) 予定あり", compactRange(gap)))
                }
                cursor = max(cursor, body.end)
            }
            if cursor < interval.end {
                let gap = DateInterval(start: cursor, end: interval.end)
                entries.append((gap.start, "\(range(gap.start, gap.end)) 予定あり", compactRange(gap)))
            }
        }
        entries.sort { $0.date < $1.date }
        let unknown = undetermined.map { "時間未定 \($0.kind == .confirmed ? $0.title : "予定あり")" }
        lines = entries.map(\.text) + unknown
        gridLines = entries.map(\.grid) + unknown
    }
}

extension CalendarItemSnapshot {
    func overlapsFriendShareDay(_ date: Date, calendar: Calendar = .mira) -> Bool {
        if !exactTimeKnown || isAllDay { return overlapsDay(date, calendar: calendar) }
        let start = calendar.startOfDay(for: date)
        let end = start.addingDays(1, calendar: calendar)
        return occupiedInterval.start < end && occupiedInterval.end > start
    }
}
