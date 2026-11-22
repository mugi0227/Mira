import Foundation

/// A whole-day feeling of breathing room, not a goal score or a countdown.
/// Until sleep has its own setting, waking hours are explicitly 07:00–23:00.
struct DayWhitespace: Equatable, Sendable {
    let availableMinutes: Int
    let awakeMinutes: Int

    var fraction: Double {
        awakeMinutes > 0 ? Double(availableMinutes) / Double(awakeMinutes) : 0
    }

    var durationText: String {
        let hours = availableMinutes / 60
        let minutes = availableMinutes % 60
        return minutes == 0 ? "\(hours)時間" : "\(hours)時間\(minutes)分"
    }

    init(date: Date, items: [CalendarItemSnapshot], baseRules: [BaseAvailabilityRule], calendar: Calendar = .mira, workDays: WorkDayResolver = WorkDayResolver()) {
        let day = calendar.startOfDay(for: date)
        let start = day.setting(hour: 7, calendar: calendar)
        let end = day.setting(hour: 23, calendar: calendar)
        awakeMinutes = Int(end.timeIntervalSince(start) / 60)
        let baseIntervals = workDays.intervals(on: day, rules: baseRules, calendar: calendar)
        // Buffers are reserved breathing room, so only the actual event time
        // reduces this meter. Margins remain the person's own time.
        let events = items.filter(\.countsAgainstWhitespace).compactMap { item -> DateInterval? in
            guard item.endDate > item.startDate else { return nil }
            return DateInterval(start: item.startDate, end: item.endDate)
        }
        let intervals = (baseIntervals + events).compactMap { interval -> DateInterval? in
            let from = max(start, interval.start)
            let to = min(end, interval.end)
            return to > from ? DateInterval(start: from, end: to) : nil
        }.sorted { $0.start < $1.start }
        var merged: [DateInterval] = []
        for interval in intervals {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        let occupiedSeconds = merged.reduce(0) { $0 + $1.duration }
        availableMinutes = max(0, awakeMinutes - Int((occupiedSeconds / 60).rounded()))
    }
}
