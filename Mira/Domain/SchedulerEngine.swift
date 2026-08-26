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
        baseRules: [BaseAvailabilityRule]
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
                    !occupied.contains(where: { $0.intersects(candidate) })
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
                    isAllDay: goal.kind == .rest,
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
        limit: Int = 3
    ) -> [Date] {
        guard let kind = margin.marginKind else { return [] }
        let key = MonthKey(date: month, calendar: calendar)
        let duration = max(1, Int(margin.endDate.timeIntervalSince(margin.startDate) / 3600))
        let syntheticGoal = MarginGoalSnapshot(
            id: margin.sourceID ?? UUID(),
            year: key.year,
            month: key.month,
            kind: kind,
            targetCount: 1,
            durationHours: duration,
            priority: kind.defaultPriority,
            isEnabled: true
        )
        let occupied = (events + otherMargins.filter { $0.id != margin.id }).map(\.occupiedInterval)
        return candidateIntervals(for: syntheticGoal, month: key, baseRules: baseRules)
            .filter { candidate in !occupied.contains(where: { $0.intersects(candidate) }) }
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
        return range.compactMap { day -> DateInterval? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: month.firstDay) else { return nil }
            let interval = interval(for: goal.kind, on: date, durationHours: goal.durationHours)
            guard !isBlockedByBaseRule(interval, rules: baseRules) else { return nil }
            return interval
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
        let weekday = calendar.component(.weekday, from: interval.start)
        let relevant = rules.filter { $0.weekday == weekday }
        guard !relevant.isEmpty else { return false }

        let startComponents = calendar.dateComponents([.hour, .minute], from: interval.start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: interval.end)
        let startMinute = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinute = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)

        return relevant.contains { rule in
            startMinute < rule.endMinute && rule.startMinute < endMinute
        }
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
