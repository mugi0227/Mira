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
        let standardReading = clamp(2 + (busyWeekendCount >= 3 ? 1 : 0), 1, 4)
        let standardProject = clamp(events.count <= 10 ? 2 : 1, 1, 3)

        let base: [MarginKind: Int] = [
            .rest: standardRest,
            .reading: standardReading,
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
        scheduler: SchedulerEngine,
        notBefore: Date? = nil
    ) -> RebalanceProposal? {
        let key = MonthKey(date: month, calendar: calendar)
        let monthItems = items.filter { key.interval.contains($0.startDate) }
        let margins = monthItems.filter { $0.kind == .margin }
        let events = items.filter { $0.kind != .margin }
        let monthGoals = goals.filter { $0.year == key.year && $0.month == key.month }
        let deficits = goalDeficits(goals: monthGoals, items: monthItems, month: key)
        let overloadedMargins = margins.filter { margin in
            !margin.isImportantTime && (notBefore.map { margin.startDate >= $0 } ?? true) && events.contains { event in
                calendar.isDate(event.startDate, inSameDayAs: margin.startDate) && event.loadClass >= .heavy
            }
        }.sorted {
            if $0.startDate == $1.startDate { return $0.id.uuidString < $1.id.uuidString }
            return $0.startDate < $1.startDate
        }

        var moves: [RebalanceMove] = []
        // Reserve each proposed interval before looking for the next one. This
        // also includes margins/events crossing either boundary of this month.
        var workingMargins = items.filter { $0.kind == .margin }

        for margin in overloadedMargins.prefix(2) {
            let candidates = scheduler.relocationCandidates(
                for: margin,
                month: month,
                events: events,
                otherMargins: workingMargins,
                baseRules: baseRules,
                limit: 62,
                notBefore: notBefore
            )
            guard let candidate = candidates.first(where: {
                !calendar.isDate($0, inSameDayAs: margin.startDate)
            }) else { continue }
            let duration = margin.endDate.timeIntervalSince(margin.startDate)
            moves.append(RebalanceMove(
                marginItemID: margin.id,
                title: margin.title,
                from: margin.startDate,
                to: candidate,
                benefit: "重い予定と余白を分けます",
                durationSeconds: duration,
                marginKind: margin.marginKind,
                isAllDay: margin.isAllDay
            ))
            var relocated = margin
            relocated.startDate = candidate
            relocated.endDate = candidate.addingTimeInterval(duration)
            workingMargins.removeAll { $0.id == margin.id }
            workingMargins.append(relocated)
        }

        let orderedGoals = monthGoals.filter { $0.isEnabled }.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.id.uuidString < $1.id.uuidString
        }
        var proposedKinds: Set<MarginKind> = []
        for goal in orderedGoals {
            let kind = goal.kind
            guard moves.count < 4, let missing = deficits[kind], missing > 0,
                  kind != .importantPeople, kind != .freeEvening,
                  goal.durationHours > 0, proposedKinds.insert(kind).inserted else { continue }
            let duration = Double(goal.durationHours) * 60 * 60
            let temporary = CalendarItemSnapshot(
                id: UUID(),
                title: kind.title,
                startDate: key.firstDay,
                endDate: key.firstDay.addingTimeInterval(duration),
                isAllDay: kind == .rest && duration >= 10 * 60 * 60,
                kind: .margin,
                marginKind: kind,
                loadClass: .light,
                loadReason: "不足している余白",
                bufferBeforeMinutes: 0,
                bufferAfterMinutes: 0,
                isImportantTime: false,
                sourceID: nil
            )
            for _ in 0..<min(missing, 2, 4 - moves.count) {
                guard let candidate = scheduler.relocationCandidates(
                    for: temporary,
                    month: month,
                    events: events,
                    otherMargins: workingMargins,
                    baseRules: baseRules,
                    limit: 1,
                    notBefore: notBefore
                ).first else { break }
                let newID = UUID()
                moves.append(RebalanceMove(
                    marginItemID: newID,
                    title: kind.title,
                    from: key.firstDay,
                    to: candidate,
                    benefit: "不足している\(kind.title)を1枠戻します",
                    durationSeconds: duration,
                    marginKind: kind,
                    isAllDay: temporary.isAllDay
                ))
                // The placeholder ID must differ for each addition so that the
                // next relocation search does not exclude an earlier new slot.
                workingMargins.append(CalendarItemSnapshot(
                    id: newID, title: kind.title,
                    startDate: candidate, endDate: candidate.addingTimeInterval(duration),
                    isAllDay: temporary.isAllDay, kind: .margin, marginKind: kind,
                    loadClass: .light, loadReason: temporary.loadReason,
                    bufferBeforeMinutes: 0, bufferAfterMinutes: 0,
                    isImportantTime: false, sourceID: goal.id
                ))
            }
        }

        guard !moves.isEmpty else { return nil }
        guard let stateHash = stableStateHash(
            month: key.firstDay, items: items, goals: monthGoals, baseRules: baseRules, moves: moves
        ) else { return nil }
        let summary = moves.count == 1
            ? "この1枠を動かすと、今月の余白が整います。"
            : "この\(moves.count)枠を組み直すと、今月の余白が整います。"
        return RebalanceProposal(month: key.firstDay, moves: moves, summary: summary, stateHash: stateHash)
    }

    /// Random proposal/addition IDs are not scheduling state. Everything the
    /// user reviews (including the exact interval) must still match.
    func matches(_ reviewed: RebalanceProposal, _ current: RebalanceProposal, items: [CalendarItemSnapshot]) -> Bool {
        reviewed.month == current.month
            && reviewed.stateHash == current.stateHash
            && moveSignatures(reviewed.moves, items: items) == moveSignatures(current.moves, items: items)
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

    private struct MoveSignature: Codable, Equatable {
        var existingMarginID: UUID?
        var title: String
        var from: Date
        var to: Date
        var durationSeconds: TimeInterval?
        var marginKind: MarginKind?
        var isAllDay: Bool?
    }

    private struct GoalSignature: Codable {
        var id: UUID
        var year: Int
        var month: Int
        var kind: MarginKind
        var targetCount: Int
        var durationHours: Int
        var priority: Int
        var isEnabled: Bool
    }

    private struct StateSignature: Codable {
        var month: Date
        var items: [CalendarItemSnapshot]
        var goals: [GoalSignature]
        var baseRules: [[Int]]
        var moves: [MoveSignature]
    }

    private func moveSignatures(_ moves: [RebalanceMove], items: [CalendarItemSnapshot]) -> [MoveSignature] {
        let existingIDs = Set(items.map(\.id))
        return moves.map {
            MoveSignature(
                existingMarginID: existingIDs.contains($0.marginItemID) ? $0.marginItemID : nil,
                title: $0.title, from: $0.from, to: $0.to,
                durationSeconds: $0.durationSeconds, marginKind: $0.marginKind, isAllDay: $0.isAllDay
            )
        }
    }

    private func stableStateHash(
        month: Date, items: [CalendarItemSnapshot], goals: [MarginGoalSnapshot],
        baseRules: [BaseAvailabilityRule], moves: [RebalanceMove]
    ) -> String? {
        let state = StateSignature(
            month: month,
            items: items.sorted { $0.id.uuidString < $1.id.uuidString },
            goals: goals.sorted { $0.id.uuidString < $1.id.uuidString }.map {
                GoalSignature(id: $0.id, year: $0.year, month: $0.month, kind: $0.kind,
                              targetCount: $0.targetCount, durationHours: $0.durationHours,
                              priority: $0.priority, isEnabled: $0.isEnabled)
            },
            baseRules: baseRules.map { [$0.weekday, $0.startMinute, $0.endMinute] }.sorted {
                $0.lexicographicallyPrecedes($1)
            },
            moves: moveSignatures(moves, items: items)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state), let value = String(data: data, encoding: .utf8) else { return nil }
        return fnv1a64(value)
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
