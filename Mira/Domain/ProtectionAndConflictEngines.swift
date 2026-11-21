import Foundation

struct ProtectionEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func analyze(
        proposedEvent: CalendarItemSnapshot,
        month: Date,
        items: [CalendarItemSnapshot],
        goals: [MarginGoalSnapshot],
        relocationCandidates: [Date]
    ) -> ScheduleImpact {
        let monthKey = MonthKey(date: month, calendar: calendar)
        let overlapping = items.filter {
            $0.kind == .margin && $0.occupiedInterval.intersects(proposedEvent.occupiedInterval)
        }
        guard !overlapping.isEmpty else { return .none }

        var deficits: [MarginKind: Int] = [:]
        var worst: ProtectionLevel = .flexible

        for kind in Set(overlapping.compactMap(\.marginKind)) {
            if kind == .custom {
                for goal in goals where goal.kind == .custom && goal.isEnabled
                    && goal.year == monthKey.year && goal.month == monthKey.month {
                    let consumed = overlapping.filter { goal.matches($0) && monthKey.interval.contains($0.startDate) }.count
                    guard consumed > 0 else { continue }
                    let current = items.filter { goal.matches($0) && monthKey.interval.contains($0.startDate) }.count
                    let after = max(0, current - consumed)
                    deficits[kind, default: 0] += max(0, goal.targetCount - after)
                    let level: ProtectionLevel = after == 0 && goal.targetCount > 0 ? .finalDefense
                        : (after < goal.targetCount ? .strong : (after == goal.targetCount ? .caution : .flexible))
                    worst = maxLevel(worst, level)
                }
                continue
            }
            let target = goals.first(where: { $0.kind == kind })?.targetCount ?? 0
            let current = items.filter {
                $0.kind == .margin && $0.marginKind == kind && monthKey.interval.contains($0.startDate)
            }.count
            let consumed = overlapping.filter {
                $0.marginKind == kind && monthKey.interval.contains($0.startDate)
            }.count
            let after = max(0, current - consumed)
            let deficit = max(0, target - after)
            deficits[kind] = deficit

            let level: ProtectionLevel
            if after == 0 && target > 0 {
                level = .finalDefense
            } else if after < target {
                level = .strong
            } else if after == target {
                level = .caution
            } else {
                level = .flexible
            }
            worst = maxLevel(worst, level)
        }

        let firstKind = overlapping.first?.title ?? "余白"
        let message: String
        switch worst {
        case .flexible:
            message = "この予定を入れると、\(firstKind)を別日に移す必要があります。"
        case .caution:
            message = "この予定で、\(firstKind)が目標ぎりぎりになります。"
        case .strong:
            message = "この予定を入れると、今月ほしい余白を下回ります。"
        case .finalDefense:
            message = "これを入れると、今月の\(firstKind)が0になってしまいます。"
        }

        return ScheduleImpact(
            overlappingMargins: overlapping,
            freeEveningDelta: -1,
            projectedGoalDeficits: deficits,
            relocationCandidates: relocationCandidates,
            protectionLevel: worst,
            message: message
        )
    }

    private func maxLevel(_ lhs: ProtectionLevel, _ rhs: ProtectionLevel) -> ProtectionLevel {
        let rank: [ProtectionLevel: Int] = [.flexible: 0, .caution: 1, .strong: 2, .finalDefense: 3]
        return (rank[rhs] ?? 0) > (rank[lhs] ?? 0) ? rhs : lhs
    }
}

struct ConflictEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func conflicts(
        candidate: CandidateSlotSnapshot,
        events: [CalendarItemSnapshot],
        otherCandidates: [CandidateSlotSnapshot],
        baseRules: [BaseAvailabilityRule] = []
    ) -> [String] {
        var result: [String] = []
        if events.contains(where: { $0.kind == .confirmed && $0.occupiedInterval.intersects(candidate.interval) }) {
            result.append("確定予定と重なっています")
        }
        if events.contains(where: { $0.kind == .margin && $0.occupiedInterval.intersects(candidate.interval) }) {
            result.append("守っている余白と重なっています")
        }
        if otherCandidates.contains(where: {
            $0.status == .held && $0.id != candidate.id && coarseCandidatesConflict($0, candidate)
        }) {
            result.append("別の日程調整でも候補になっています")
        }
        if overlapsBaseRule(candidate.interval, rules: baseRules) {
            result.append("基本的に予定を入れない時間と重なっています")
        }
        return result
    }

    struct Detail: Identifiable {
        var id: String { "\(start.timeIntervalSince1970)-\(text)-\(itemID?.uuidString ?? "")" }
        let start: Date
        let text: String
        var itemID: UUID? = nil
        var baseRuleInterval: DateInterval? = nil
    }

    func conflictDetails(
        candidate: CandidateSlotSnapshot,
        events: [CalendarItemSnapshot],
        otherCandidates: [CandidateSlotSnapshot],
        candidateTitles: [UUID: String] = [:],
        baseRules: [BaseAvailabilityRule] = []
    ) -> [String] {
        let details = conflictDetailEntries(candidate: candidate, events: events,
            otherCandidates: otherCandidates, candidateTitles: candidateTitles, baseRules: baseRules)
        var lines = details.prefix(2).map(\.text)
        if details.count > 2 { lines.append("ほか\(details.count - 2)件") }
        return lines
    }

    func conflictDetailEntries(
        candidate: CandidateSlotSnapshot,
        events: [CalendarItemSnapshot],
        otherCandidates: [CandidateSlotSnapshot],
        candidateTitles: [UUID: String] = [:],
        baseRules: [BaseAvailabilityRule] = []
    ) -> [Detail] {
        var details: [Detail] = []
        for event in events where (event.kind == .confirmed || event.kind == .margin)
            && event.occupiedInterval.intersects(candidate.interval) {
            let kind = event.kind == .margin ? "守っている余白" : "確定予定"
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = title.isEmpty ? kind : title
            let time = !event.exactTimeKnown ? event.timeDescription
                : (event.isAllDay ? "終日" : timeRange(event.startDate, event.endDate))
            details.append(Detail(start: event.startDate, text: "\(time)『\(label)』（\(kind)）と重なっています", itemID: event.id))
        }
        for other in otherCandidates where other.status == .held && other.id != candidate.id
            && coarseCandidatesConflict(other, candidate) {
            let title = candidateTitles[other.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = title.flatMap { $0.isEmpty ? nil : $0 } ?? "別の日程調整"
            let time = other.exactTimeKnown == false ? other.displayTimeBand.title : timeRange(other.startDate, other.endDate)
            details.append(Detail(start: other.startDate, text: "\(time)『\(label)』（仮押さえ）と重なっています"))
        }
        var day = calendar.startOfDay(for: candidate.startDate)
        while day < candidate.endDate {
            for rule in baseRules where rule.weekday == calendar.component(.weekday, from: day) {
                guard let start = calendar.date(byAdding: .minute, value: rule.startMinute, to: day),
                      let end = calendar.date(byAdding: .minute, value: rule.endMinute, to: day),
                      start < end, start < candidate.endDate, candidate.startDate < end else { continue }
                details.append(Detail(start: start, text: "\(timeRange(start, end))『基本時間（予定を入れない時間）』と重なっています", baseRuleInterval: DateInterval(start: start, end: end)))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return details.sorted { $0.start == $1.start ? $0.text < $1.text : $0.start < $1.start }
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter.mira("HH:mm")
        return "\(formatter.string(from: start))〜\(formatter.string(from: end))"
    }

    private func coarseCandidatesConflict(
        _ lhs: CandidateSlotSnapshot,
        _ rhs: CandidateSlotSnapshot
    ) -> Bool {
        guard calendar.isDate(lhs.startDate, inSameDayAs: rhs.startDate) else { return false }
        let lhsExact = lhs.exactTimeKnown ?? true
        let rhsExact = rhs.exactTimeKnown ?? true
        if !lhsExact || !rhsExact {
            let lhsBand = lhs.displayTimeBand
            let rhsBand = rhs.displayTimeBand
            return lhsBand == .allDay || rhsBand == .allDay || lhsBand == rhsBand
        }
        return lhs.interval.intersects(rhs.interval)
    }

    private func overlapsBaseRule(
        _ interval: DateInterval,
        rules: [BaseAvailabilityRule]
    ) -> Bool {
        guard !rules.isEmpty else { return false }

        let startDay = calendar.startOfDay(for: interval.start)
        let endProbe = interval.end.addingTimeInterval(-1)
        let endDay = calendar.startOfDay(for: max(endProbe, interval.start))
        var day = startDay

        while day <= endDay {
            let weekday = calendar.component(.weekday, from: day)
            for rule in rules where rule.weekday == weekday {
                guard let ruleStart = calendar.date(byAdding: .minute, value: rule.startMinute, to: day),
                      let ruleEnd = calendar.date(byAdding: .minute, value: rule.endMinute, to: day),
                      ruleStart < ruleEnd else { continue }

                // Calendar ranges are treated as [start, end): an event beginning
                // exactly when work ends should remain selectable.
                let overlapStart = max(ruleStart, interval.start)
                let overlapEnd = min(ruleEnd, interval.end)
                if overlapStart < overlapEnd {
                    return true
                }
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return false
    }
}

struct FreeEveningEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func value(for date: Date, items: [CalendarItemSnapshot]) -> Double {
        let start = date.setting(hour: 18, calendar: calendar)
        let end = date.addingDays(1, calendar: calendar).setting(hour: 0, calendar: calendar)
        let evening = DateInterval(start: start, end: end)
        let confirmedItems = items.filter { $0.kind == .confirmed }
        let occupiedSeconds = confirmedItems
            .filter { $0.occupiedInterval.intersects(evening) }
            .reduce(0.0) { partial, item in
                let intersectionStart = max(item.occupiedInterval.start, evening.start)
                let intersectionEnd = min(item.occupiedInterval.end, evening.end)
                return partial + max(0, intersectionEnd.timeIntervalSince(intersectionStart))
            }
        let freeHours = max(0, 6 - occupiedSeconds / 3600)
        let hasHeavy = confirmedItems.contains {
            $0.loadClass >= .heavy && $0.occupiedInterval.intersects(evening)
        }
        if freeHours >= 4, !hasHeavy { return 1 }
        if freeHours >= 2.5, !hasHeavy { return 0.5 }
        return 0
    }
}

struct AssistantEngine: Sendable {
    func message(
        theme: AppThemeKind,
        month: Date,
        goals: [MarginGoalSnapshot],
        items: [CalendarItemSnapshot],
        calendar: Calendar = .mira
    ) -> AssistantMessage {
        let key = MonthKey(date: month, calendar: calendar)
        let marginItems = items.filter { $0.kind == .margin && key.interval.contains($0.startDate) }
        let restTarget = goals.first(where: { $0.kind == .rest })?.targetCount ?? 0
        let restActual = marginItems.filter { $0.marginKind == .rest }.count

        if restActual == 0, restTarget > 0 {
            return AssistantMessage(
                title: theme == .pixelCat ? "おやすみがないにゃ" : "休息日がありません",
                body: theme == .pixelCat ? "今月のおやすみを1日、先に置いておくと安心だにゃ。" : "今月の休息日を1日、先に確保するのがおすすめです。",
                mood: .warning,
                severity: 3,
                actionTitle: "余白を整える"
            )
        }

        let heavyDays = Set(items.filter { $0.loadClass >= .heavy && key.interval.contains($0.startDate) }
            .map { calendar.startOfDay(for: $0.startDate) }).count
        if heavyDays >= 5 {
            return AssistantMessage(
                title: theme == .pixelCat ? "今月ちょっとぎゅうぎゅうだにゃ" : "今月は予定が多めです",
                body: theme == .pixelCat ? "重めの日が続いてるにゃ。次の予定は来週へずらすと、のんびりできそう。" : "重い予定が続いています。次の予定を来週へ移すと余白を残せます。",
                mood: .tired,
                severity: 2,
                actionTitle: "再配置を見る"
            )
        }

        let remaining = max(0, restTarget - restActual)
        if remaining > 0 {
            return AssistantMessage(
                title: theme == .pixelCat ? "あと\(remaining)日だにゃ" : "休息日があと\(remaining)日必要です",
                body: theme == .pixelCat ? "おやすみをあと\(remaining)日置けると、いい感じだにゃ。" : "休息日をあと\(remaining)日確保すると、今月の目標を満たせます。",
                mood: .thinking,
                severity: 1,
                actionTitle: "おすすめ配置"
            )
        }

        return AssistantMessage(
            title: theme == .pixelCat ? "いい感じだにゃ" : "今月はいいバランスです",
            body: theme == .pixelCat ? "予定も余白も、ちゃんと居場所があるにゃ。" : "予定と自分の時間をバランスよく確保できています。",
            mood: .relaxed,
            severity: 0,
            actionTitle: nil
        )
    }
}
