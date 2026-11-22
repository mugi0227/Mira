import Foundation

/// The longest single stretch of free waking time in a day, answering
/// "can this event fit?" rather than the whole-day 余白 feeling.
/// It shares the 余白 meter's waking window (07:00–23:00) and treats the
/// same things as free, but counts event buffers as taken because an event
/// cannot be placed inside another event's travel time.
struct DayFreeSlot: Equatable, Sendable {
    let longestMinutes: Int

    init(
        date: Date,
        items: [CalendarItemSnapshot],
        baseRules: [BaseAvailabilityRule],
        notBefore: Date? = nil,
        calendar: Calendar = .mira,
        workDays: WorkDayResolver = WorkDayResolver()
    ) {
        let day = calendar.startOfDay(for: date)
        let awakeStart = day.setting(hour: 7, calendar: calendar)
        let end = day.setting(hour: 23, calendar: calendar)
        let start = max(awakeStart, notBefore ?? awakeStart)
        guard end > start else {
            longestMinutes = 0
            return
        }

        let baseIntervals = workDays.intervals(on: day, rules: baseRules, calendar: calendar)
        let events = items.filter(\.countsAgainstWhitespace).map(\.occupiedInterval)
        let busy = (baseIntervals + events).compactMap { interval -> DateInterval? in
            let from = max(start, interval.start)
            let to = min(end, interval.end)
            return to > from ? DateInterval(start: from, end: to) : nil
        }.sorted { $0.start < $1.start }

        var cursor = start
        var longest: TimeInterval = 0
        for interval in busy {
            if interval.start > cursor { longest = max(longest, interval.start.timeIntervalSince(cursor)) }
            cursor = max(cursor, interval.end)
        }
        longest = max(longest, end.timeIntervalSince(cursor))
        longestMinutes = Int((longest / 60).rounded(.down))
    }

    func fits(minutes: Int) -> Bool {
        minutes > 0 && longestMinutes >= minutes
    }
}
