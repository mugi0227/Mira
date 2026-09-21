import Foundation

struct SchedulerEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func propose(
        month: Date,
        goals: [MarginGoalSnapshot],
        events: [CalendarItemSnapshot],
        existingMargins: [CalendarItemSnapshot],
        baseRules: [BaseAvailabilityRule],
        notBefore: Date? = nil
    ) -> MarginPlacementProposal {
        let monthKey = MonthKey(date: month, calendar: calendar)
        var occupied = events
            .filter { $0.kind != .birthday }
            .map(\.occupiedInterval)
        occupied.append(contentsOf: existingMargins.map(\.occupiedInterval))

        var placed: [CalendarItemSnapshot] = []
        var unmet: [MarginKind: Int] = [:]
        var totalScore = 0.0

        let activeGoals = goals
            .filter { $0.isEnabled && $0.kind != .importantPeople }
            .sorted {
                if $0.priority == $1.priority { return $0.kind.rawValue < $1.kind.rawValue }
                return $0.priority > $1.priority
            }

        for goal in activeGoals {
            let existingCount = existingMargins.filter {
                $0.marginKind == goal.kind && monthKey.interval.contains($0.startDate)
            }.count
            let remaining = max(0, goal.targetCount - existingCount)
            guard remaining > 0 else { continue }

            for index in 0..<remaining {
                let candidates = candidateIntervals(
                    for: goal,
                    month: monthKey,
                    baseRules: baseRules
                )
                .filter { candidate in
                    (notBefore.map { candidate.start >= $0 } ?? true) && !occupied.contains(where: { $0.intersects(candidate) })
                }
                .map { interval in
                    (interval, score(
                        interval: interval,
                        kind: goal.kind,
                        existing: existingMargins + placed,
                        events: events,
                        ordinal: index
                    ))
                }
                .sorted {
                    if $0.1 == $1.1 { return $0.0.start < $1.0.start }
                    return $0.1 > $1.1
                }

                guard let best = candidates.first else {
                    unmet[goal.kind, default: 0] += 1
                    continue
                }

                let item = CalendarItemSnapshot(
                    id: UUID(),
                    title: goal.kind.title,
                    startDate: best.0.start,
                    endDate: best.0.end,
                    isAllDay: goal.kind == .rest && best.0.duration >= 10 * 60 * 60,
                    kind: .margin,
                    marginKind: goal.kind,
                    loadClass: .light,
                    loadReason: "自分のために先に確保した余白",
                    bufferBeforeMinutes: 0,
                    bufferAfterMinutes: 0,
                    isImportantTime: false,
                    sourceID: goal.id
                )
                placed.append(item)
                occupied.append(best.0)
                totalScore += best.1
            }
        }

        return MarginPlacementProposal(slots: placed, unmetGoals: unmet, score: totalScore)
    }

    func relocationCandidates(
        for margin: CalendarItemSnapshot,
        month: Date,
        events: [CalendarItemSnapshot],
        otherMargins: [CalendarItemSnapshot],
        baseRules: [BaseAvailabilityRule],
        limit: Int = 3,
        notBefore: Date? = nil
    ) -> [Date] {
        guard let kind = margin.marginKind else { return [] }
        let key = MonthKey(date: month, calendar: calendar)
        let duration = margin.endDate.timeIntervalSince(margin.startDate)
        guard duration.isFinite, duration > 0, limit > 0,
              let days = calendar.range(of: .day, in: .month, for: key.firstDay) else { return [] }
        let occupied = (events + otherMargins.filter { $0.id != margin.id }).map(\.occupiedInterval)
        let candidates = days.flatMap { day -> [DateInterval] in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: key.firstDay) else { return [] }
            let preferred = interval(for: kind, on: date, durationHours: 1).start
            var starts = [preferred]
            if kind == .rest && !margin.isAllDay {
                let evening = date.setting(hour: 18, calendar: calendar)
                if !starts.contains(evening) { starts.append(evening) }
            }
            // Relocation preserves exact minutes/seconds; auto-placement's shorter
            // evening fallback must never silently shorten a previously saved margin.
            return starts.map { DateInterval(start: $0, duration: duration) }
        }
        return candidates.filter { candidate in
                let occupiedCandidate = DateInterval(
                    start: candidate.start.addingTimeInterval(-Double(margin.bufferBeforeMinutes) * 60),
                    end: candidate.end.addingTimeInterval(Double(margin.bufferAfterMinutes) * 60)
                )
                return (notBefore.map { candidate.start >= $0 } ?? true)
                    && candidate.end <= key.interval.end
                    && !isBlockedByBaseRule(occupiedCandidate, rules: baseRules)
                    && !occupied.contains(where: { $0.intersects(occupiedCandidate) })
            }
            .map { interval in
                (interval.start, score(
                    interval: interval,
                    kind: kind,
                    existing: otherMargins,
                    events: events,
                    ordinal: 0
                ))
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
                return lhs.1 > rhs.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private func candidateIntervals(
        for goal: MarginGoalSnapshot,
        month: MonthKey,
        baseRules: [BaseAvailabilityRule]
    ) -> [DateInterval] {
        guard let range = calendar.range(of: .day, in: .month, for: month.firstDay) else { return [] }
        return range.flatMap { day -> [DateInterval] in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: month.firstDay) else { return [] }
            let preferred = interval(for: goal.kind, on: date, durationHours: goal.durationHours)
            var intervals = isBlockedByBaseRule(preferred, rules: baseRules) ? [] : [preferred]

            if goal.kind == .rest {
                let eveningStart = date.setting(hour: 18, calendar: calendar)
                let eveningEnd = calendar.date(byAdding: .hour, value: 4, to: eveningStart) ?? eveningStart
                let evening = DateInterval(start: eveningStart, end: eveningEnd)
                if !isBlockedByBaseRule(evening, rules: baseRules), !intervals.contains(evening) {
                    intervals.append(evening)
                }
            }
            return intervals
        }
    }

    private func interval(for kind: MarginKind, on date: Date, durationHours: Int) -> DateInterval {
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let startHour: Int
        let effectiveDuration: Int

        switch kind {
        case .rest:
            startHour = 9
            effectiveDuration = max(durationHours, 12)
        case .freeEvening, .solo:
            startHour = 18
            effectiveDuration = max(durationHours, 5)
        case .reading, .personalProject, .custom:
            startHour = isWeekend ? 13 : 18
            effectiveDuration = max(durationHours, isWeekend ? 5 : 4)
        case .importantPeople:
            startHour = 12
            effectiveDuration = max(durationHours, 5)
        }

        let start = date.setting(hour: startHour, calendar: calendar)
        let end = calendar.date(byAdding: .hour, value: effectiveDuration, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func isBlockedByBaseRule(_ interval: DateInterval, rules: [BaseAvailabilityRule]) -> Bool {
        guard !rules.isEmpty else { return false }
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            let weekday = calendar.component(.weekday, from: day)
            for rule in rules where rule.weekday == weekday {
                let start = calendar.date(byAdding: .minute, value: rule.startMinute, to: day) ?? day
                let end = calendar.date(byAdding: .minute, value: rule.endMinute, to: day) ?? day
                // Calendar intervals are half-open: a base rule ending at 18:00
                // leaves a slot beginning exactly at 18:00 available.
                if end > start && start < interval.end && end > interval.start { return true }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { return true }
            day = next
        }
        return false
    }

    private func score(
        interval: DateInterval,
        kind: MarginKind,
        existing: [CalendarItemSnapshot],
        events: [CalendarItemSnapshot],
        ordinal: Int
    ) -> Double {
        let weekday = calendar.component(.weekday, from: interval.start)
        let isWeekend = weekday == 1 || weekday == 7
        var value = 100.0

        if kind == .rest && isWeekend { value += 30 }
        if kind == .rest && interval.duration < 8 * 60 * 60 { value -= 18 }
        if (kind == .reading || kind == .personalProject) && isWeekend { value += 16 }
        if (kind == .freeEvening || kind == .solo) && !isWeekend { value += 12 }

        let sameKind = existing.filter { $0.marginKind == kind }
        if let nearest = sameKind.map({ abs($0.startDate.timeIntervalSince(interval.start)) }).min() {
            let days = nearest / 86_400
            value += min(days, 10) * 4
            if days < 3 { value -= 45 }
        }

        let previousDay = calendar.date(byAdding: .day, value: -1, to: interval.start) ?? interval.start
        let nextDay = calendar.date(byAdding: .day, value: 1, to: interval.start) ?? interval.start
        if events.contains(where: { calendar.isDate($0.startDate, inSameDayAs: previousDay) && $0.loadClass >= .heavy }) {
            value += kind == .rest ? 26 : 8
        }
        if events.contains(where: { calendar.isDate($0.startDate, inSameDayAs: nextDay) && $0.loadClass >= .heavy }) {
            value += kind == .rest ? 14 : 4
        }

        let day = calendar.component(.day, from: interval.start)
        value -= Double(max(0, day - 24)) * 1.5
        value -= Double(ordinal) * 0.01
        return value
    }
}
