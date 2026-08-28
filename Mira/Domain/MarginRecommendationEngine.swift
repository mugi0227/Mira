import Foundation

struct MarginRecommendationEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func recommend(
        month: Date,
        items: [CalendarItemSnapshot],
        comfort: MarginComfortLevel
    ) -> MarginRecommendation {
        let key = MonthKey(date: month, calendar: calendar)
        let events = items.filter {
            key.interval.contains($0.startDate) && $0.kind == .confirmed
        }
        let loadTotal = events.reduce(0) { $0 + $1.loadClass.score }
        let heavyCount = events.filter { $0.loadClass >= .heavy }.count
        let veryHeavyCount = events.filter { $0.loadClass == .veryHeavy }.count
        let busyWeekendCount = busyWeekends(in: key, events: events)
        let consecutiveBusy = maximumConsecutiveBusyDays(in: key, events: events)

        let standardRest = clamp(
            2 + Int(ceil(Double(loadTotal) / 360.0)) + heavyCount / 3 + veryHeavyCount / 2,
            2,
            8
        )
        let standardFreeEvenings = clamp(
            6 + heavyCount / 2 + max(0, consecutiveBusy - 2),
            4,
            12
        )
        let standardReading = clamp(2 + (busyWeekendCount >= 3 ? 1 : 0), 1, 4)
        let standardSolo = clamp(2 + (heavyCount >= 5 ? 1 : 0), 1, 5)
        let standardProject = clamp(events.count <= 10 ? 2 : 1, 1, 3)

        let base: [MarginKind: Int] = [
            .rest: standardRest,
            .freeEvening: standardFreeEvenings,
            .reading: standardReading,
            .solo: standardSolo,
            .personalProject: standardProject,
            .importantPeople: 2
        ]
        let adjusted = base.mapValues { value in
            max(1, Int((Double(value) * comfort.multiplier).rounded()))
        }

        var reasons: [String] = []
        if heavyCount > 0 { reasons.append("重い予定が\(heavyCount)件あります") }
        if consecutiveBusy >= 3 { reasons.append("最大\(consecutiveBusy)日連続で予定があります") }
        if busyWeekendCount >= 2 { reasons.append("週末が\(busyWeekendCount)週ぶん埋まっています") }
        if reasons.isEmpty { reasons.append("今月の予定負荷は比較的穏やかです") }
        reasons.append("余白量は「\(comfort.title)」で計算")

        return MarginRecommendation(
            month: key.firstDay,
            comfortLevel: comfort,
            targets: adjusted,
            reasons: reasons
        )
    }

    private func busyWeekends(in key: MonthKey, events: [CalendarItemSnapshot]) -> Int {
        var weekKeys: Set<String> = []
        for event in events {
            let weekday = calendar.component(.weekday, from: event.startDate)
            guard weekday == 1 || weekday == 7 else { continue }
            let week = calendar.component(.weekOfYear, from: event.startDate)
            let year = calendar.component(.yearForWeekOfYear, from: event.startDate)
            weekKeys.insert("\(year)-\(week)")
        }
        return weekKeys.count
    }

    private func maximumConsecutiveBusyDays(in key: MonthKey, events: [CalendarItemSnapshot]) -> Int {
        let busyDays = Set(events.map { calendar.startOfDay(for: $0.startDate) })
        var cursor = key.firstDay
        var current = 0
        var maximum = 0
        while cursor < key.interval.end {
            if busyDays.contains(cursor) {
                current += 1
                maximum = max(maximum, current)
            } else {
                current = 0
            }
            cursor = cursor.addingDays(1, calendar: calendar)
        }
        return maximum
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(upper, max(lower, value))
    }
}

struct RebalanceEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func propose(
        month: Date,
        items: [CalendarItemSnapshot],
        goals: [MarginGoalSnapshot],
        baseRules: [BaseAvailabilityRule],
        scheduler: SchedulerEngine
    ) -> RebalanceProposal? {
        let key = MonthKey(date: month, calendar: calendar)
        let monthItems = items.filter { key.interval.contains($0.startDate) }
        let margins = monthItems.filter { $0.kind == .margin }
        let events = monthItems.filter { $0.kind != .margin }
        let deficits = goalDeficits(goals: goals, items: monthItems, month: key)
        let overloadedMargins = margins.filter { margin in
            events.contains { event in
                calendar.isDate(event.startDate, inSameDayAs: margin.startDate) && event.loadClass >= .heavy
            }
        }

        var moves: [RebalanceMove] = []

        for margin in overloadedMargins.prefix(2) {
            let candidates = scheduler.relocationCandidates(
                for: margin,
                month: month,
                events: events,
                otherMargins: margins,
                baseRules: baseRules
            )
            guard let candidate = candidates.first,
                  !calendar.isDate(candidate, inSameDayAs: margin.startDate) else { continue }
            moves.append(RebalanceMove(
                marginItemID: margin.id,
                title: margin.title,
                from: margin.startDate,
                to: candidate,
                benefit: "重い予定と余白を分けます"
            ))
        }

        for (kind, missing) in deficits where missing > 0 && kind != .importantPeople && kind != .freeEvening {
            let duration = kind.defaultDurationHours
            let temporary = CalendarItemSnapshot(
                id: UUID(),
                title: kind.title,
                startDate: key.firstDay.setting(hour: kind == .rest ? 9 : 13),
                endDate: key.firstDay.setting(hour: kind == .rest ? 21 : 13 + duration),
                isAllDay: kind == .rest,
                kind: .margin,
                marginKind: kind,
                loadClass: .light,
                loadReason: "不足している余白",
                bufferBeforeMinutes: 0,
                bufferAfterMinutes: 0,
                isImportantTime: false,
                sourceID: nil
            )
            let candidates = scheduler.relocationCandidates(
                for: temporary,
                month: month,
                events: events,
                otherMargins: margins,
                baseRules: baseRules
            )
            for candidate in candidates.prefix(min(missing, 2)) {
                moves.append(RebalanceMove(
                    marginItemID: UUID(),
                    title: kind.title,
                    from: key.firstDay,
                    to: candidate,
                    benefit: "不足している\(kind.title)を1枠戻します"
                ))
            }
        }

        guard !moves.isEmpty else { return nil }
        let stateHash = stableStateHash(items: monthItems, goals: goals)
        let summary = moves.count == 1
            ? "この1枠を動かすと、今月の余白が整います。"
            : "この\(moves.count)枠を組み直すと、今月の余白が整います。"
        return RebalanceProposal(month: key.firstDay, moves: Array(moves.prefix(4)), summary: summary, stateHash: stateHash)
    }

    private func goalDeficits(
        goals: [MarginGoalSnapshot],
        items: [CalendarItemSnapshot],
        month: MonthKey
    ) -> [MarginKind: Int] {
        var result: [MarginKind: Int] = [:]
        for goal in goals where goal.isEnabled {
            let current: Int
            switch goal.kind {
            case .importantPeople:
                current = items.filter { $0.isImportantTime }.count
            case .freeEvening:
                let engine = FreeEveningEngine()
                let days = daysInMonth(month)
                current = Int(days.reduce(0.0) { total, date in
                    total + engine.value(
                        for: date,
                        items: items.filter {
                            calendar.isDate($0.startDate, inSameDayAs: date) && $0.kind != .margin
                        }
                    )
                }.rounded(.down))
            default:
                current = items.filter { $0.kind == .margin && $0.marginKind == goal.kind }.count
            }
            let missing = max(0, goal.targetCount - current)
            if missing > 0 { result[goal.kind] = missing }
        }
        return result
    }

    private func daysInMonth(_ key: MonthKey) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: key.firstDay) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: key.firstDay) }
    }

    private func stableStateHash(items: [CalendarItemSnapshot], goals: [MarginGoalSnapshot]) -> String {
        let itemPart = items.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            "\($0.id.uuidString):\(Int($0.startDate.timeIntervalSince1970)):\(Int($0.endDate.timeIntervalSince1970)):\($0.loadClass.rawValue):\($0.kind.rawValue)"
        }.joined(separator: "|")
        let goalPart = goals.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            "\($0.kind.rawValue):\($0.targetCount):\($0.isEnabled)"
        }.joined(separator: "|")
        return fnv1a64(itemPart + "#" + goalPart)
    }

    private func fnv1a64(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(hash, radix: 16)
    }
}
