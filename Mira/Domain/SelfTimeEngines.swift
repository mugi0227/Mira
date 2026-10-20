import Foundation

// MARK: - Intent

struct IntentInterpreter: Sendable {
    static let fallbackOptions: [PlanningIntent] = [
        .increaseSelfTime(scope: .nextWeek, kind: nil),
        .protectEvenings(scope: .nextWeek),
        .increaseSelfTime(scope: .thisWeek, kind: nil)
    ]

    private static let selfTimeWords = [
        "自分の時間", "自分時間", "自分のための時間", "余白", "休息", "休み", "休む", "ゆっくり", "のんびり",
        "一人の時間", "ひとりの時間", "一人時間", "読書", "趣味", "勉強", "学習", "やりたいこと", "リフレッシュ"
    ]
    private static let wishWords = [
        "増やしたい", "ふやしたい", "欲しい", "ほしい", "確保", "取りたい", "とりたい", "作りたい", "つくりたい",
        "守りたい", "空けたい", "あけたい", "したい", "休みたい", "増やして", "作って", "確保して", "空けて"
    ]
    /// Plans with other people stay with the regular scheduling flow.
    private static let otherPeopleWords = ["友達", "友だち", "恋人", "家族", "同僚", "先輩", "後輩", "誘", "飲み", "ご飯", "ランチ", "会う", "と一緒"]

    /// Only clear wishes about one's own time; anything else keeps the existing chat behaviour.
    func interpret(_ text: String) -> PlanningIntent {
        let normalized = text.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "　", with: "")
        guard !normalized.isEmpty,
              !Self.otherPeopleWords.contains(where: normalized.contains),
              Self.wishWords.contains(where: normalized.contains) else { return .unknown }
        let scope: WeekScope = normalized.contains("今週") ? .thisWeek : .nextWeek

        if normalized.contains("夜"), ["空け", "あけ", "予定のない", "守"].contains(where: normalized.contains) {
            return .protectEvenings(scope: scope)
        }
        guard Self.selfTimeWords.contains(where: normalized.contains) else { return .unknown }
        return .increaseSelfTime(scope: scope, kind: kind(in: normalized))
    }

    private func kind(in text: String) -> MarginKind? {
        if text.contains("読書") { return .reading }
        if ["趣味", "勉強", "学習", "やりたいこと"].contains(where: text.contains) { return .personalProject }
        if ["休", "ゆっくり", "のんびり", "一人", "ひとり"].contains(where: text.contains) { return .rest }
        return nil
    }
}

// MARK: - Self-time planning

struct SelfTimePlanner: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func propose(
        week: WeekKey,
        kind: MarginKind?,
        eveningsOnly: Bool = false,
        now: Date,
        items: [CalendarItemSnapshot],
        baseRules: [BaseAvailabilityRule],
        trend: TimeTrend?,
        count: Int
    ) -> [SuggestedMargin] {
        let occupied = items.filter { $0.kind != .birthday }.map(\.occupiedInterval)
        let candidates = week.days.flatMap { day in
            windows(on: day, eveningsOnly: eveningsOnly, occupied: occupied, baseRules: baseRules, notBefore: now)
                .map { (day, $0.0, $0.1) }
        }
        .map { day, interval, band in
            (day, interval, band, score(interval: interval, band: band, items: items, trend: trend))
        }
        .sorted {
            if $0.3 == $1.3 { return $0.1.start < $1.1.start }
            return $0.3 > $1.3
        }

        var usedDays = Set<Date>()
        var result: [SuggestedMargin] = []
        for (day, interval, band, _) in candidates where result.count < count {
            let key = calendar.startOfDay(for: day)
            guard !usedDays.contains(key) else { continue }
            usedDays.insert(key)
            result.append(SuggestedMargin(
                kind: resolvedKind(kind, eveningsOnly: eveningsOnly, band: band, day: day),
                startDate: interval.start,
                endDate: interval.end
            ))
        }
        return result.sorted { $0.startDate < $1.startDate }
    }

    func selfTimeHours(in week: WeekKey, items: [CalendarItemSnapshot]) -> Double {
        let range = week.interval(calendar: calendar)
        return items.filter { $0.kind == .margin }.reduce(0) { total, item in
            let start = max(item.startDate, range.start)
            let end = min(item.endDate, range.end)
            return total + max(0, end.timeIntervalSince(start)) / 3600
        }
    }

    /// Each day takes its own month's goals, so a week spanning two months is measured fairly.
    func weeklyTargetHours(for week: WeekKey, goals: [MarginGoalSnapshot]) -> Double {
        let total = week.days.reduce(0.0) { sum, day in
            let key = MonthKey(date: day, calendar: calendar)
            let monthHours = goals
                .filter { $0.year == key.year && $0.month == key.month && $0.isEnabled && $0.kind != .importantPeople }
                .reduce(0) { $0 + Double($1.targetCount * $1.effectiveDurationMinutes) / 60 }
            let days = Double(calendar.range(of: .day, in: .month, for: key.firstDay)?.count ?? 30)
            return sum + monthHours / days
        }
        return max(6, total.rounded())
    }

    /// Real free gaps of the day (after events, buffers, margins and base rules), cut to a comfortable length
    /// and anchored at the preferred start times when the gap allows it.
    private func windows(
        on day: Date,
        eveningsOnly: Bool,
        occupied: [DateInterval],
        baseRules: [BaseAvailabilityRule],
        notBefore: Date
    ) -> [(DateInterval, TimeOfDayKind)] {
        let weekday = calendar.component(.weekday, from: day)
        let isWeekend = weekday == 1 || weekday == 7
        let range: (Int, Int)
        let preferredStarts: [Int]
        let length: Double
        if eveningsOnly {
            range = (18, 23); preferredStarts = [18, 19]; length = 4
        } else if isWeekend {
            range = (9, 23); preferredStarts = [13, 9, 18]; length = 4
        } else {
            range = (7, 23); preferredStarts = [19, 18, 20]; length = 3
        }

        let dayRange = interval(day, range.0, range.1)
        let busy = (occupied + baseRuleIntervals(on: day, rules: baseRules)).filter { $0.intersects(dayRange) }
        var result: [(DateInterval, TimeOfDayKind)] = []
        for gap in freeGaps(in: dayRange, busy: busy, notBefore: notBefore) {
            let starts = preferredStarts.map { day.setting(hour: $0, calendar: calendar) } + [roundedUpToHour(gap.start)]
            for start in starts where start >= gap.start && start < gap.end {
                let end = min(gap.end, start.addingTimeInterval(length * 3600))
                guard end.timeIntervalSince(start) >= Self.minimumHours * 3600 else { continue }
                let candidate = DateInterval(start: start, end: end)
                guard !result.contains(where: { $0.0 == candidate }) else { continue }
                result.append((candidate, band(for: start)))
            }
        }
        return result
    }

    static let minimumHours = 2.0

    private func freeGaps(in range: DateInterval, busy: [DateInterval], notBefore: Date) -> [DateInterval] {
        var cursor = max(range.start, roundedUpToHour(notBefore))
        var gaps: [DateInterval] = []
        for interval in busy.sorted(by: { $0.start < $1.start }) {
            if interval.start > cursor { gaps.append(DateInterval(start: cursor, end: min(interval.start, range.end))) }
            cursor = max(cursor, interval.end)
            if cursor >= range.end { break }
        }
        if cursor < range.end { gaps.append(DateInterval(start: cursor, end: range.end)) }
        return gaps.filter { $0.duration > 0 }
    }

    private func baseRuleIntervals(on day: Date, rules: [BaseAvailabilityRule]) -> [DateInterval] {
        let weekday = calendar.component(.weekday, from: day)
        return rules.filter { $0.weekday == weekday }.map { rule in
            let start = calendar.startOfDay(for: day).addingTimeInterval(Double(rule.startMinute) * 60)
            let end = calendar.startOfDay(for: day).addingTimeInterval(Double(rule.endMinute) * 60)
            return DateInterval(start: start, end: max(start, end))
        }
    }

    private func roundedUpToHour(_ date: Date) -> Date {
        let components = calendar.dateComponents([.minute, .second], from: date)
        guard (components.minute ?? 0) > 0 || (components.second ?? 0) > 0 else { return date }
        let floored = date.setting(hour: calendar.component(.hour, from: date), calendar: calendar)
        return floored.addingTimeInterval(3600)
    }

    private func band(for start: Date) -> TimeOfDayKind {
        switch calendar.component(.hour, from: start) {
        case ..<12: .morning
        case 12..<17: .afternoon
        default: .evening
        }
    }

    private func interval(_ day: Date, _ startHour: Int, _ endHour: Int) -> DateInterval {
        DateInterval(start: day.setting(hour: startHour, calendar: calendar), end: day.setting(hour: endHour, calendar: calendar))
    }

    private func resolvedKind(_ kind: MarginKind?, eveningsOnly: Bool, band: TimeOfDayKind, day: Date) -> MarginKind {
        if let kind { return kind }
        return .rest
    }

    private func score(interval: DateInterval, band: TimeOfDayKind, items: [CalendarItemSnapshot], trend: TimeTrend?) -> Double {
        let weekday = calendar.component(.weekday, from: interval.start)
        var value = 100.0
        if weekday == 1 || weekday == 7 {
            value += band == .afternoon ? 10 : 4
        } else if band != .evening {
            value -= 8
        }
        value += min(interval.duration / 3600, 4)

        let previousDay = interval.start.addingDays(-1, calendar: calendar)
        if items.contains(where: { calendar.isDate($0.startDate, inSameDayAs: previousDay) && $0.loadClass >= .heavy }) {
            value += 15
        }
        if items.contains(where: { calendar.isDate($0.startDate, inSameDayAs: interval.start) && $0.kind == .confirmed }) {
            value -= 10
        }
        if let trend { value += trend.bonus(for: interval, band: band, calendar: calendar) }
        return value
    }
}

// MARK: - Request & proactive suggestions

struct SuggestionEngine: Sendable {
    static let maxVisiblePending = 3

    private let planner: SelfTimePlanner
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
        self.planner = SelfTimePlanner(calendar: calendar)
    }

    func suggestion(
        for intent: PlanningIntent,
        now: Date,
        items: [CalendarItemSnapshot],
        baseRules: [BaseAvailabilityRule],
        trend: TimeTrend?
    ) -> Suggestion? {
        let scope: WeekScope
        let kind: MarginKind?
        let eveningsOnly: Bool
        switch intent {
        case .increaseSelfTime(let s, let k):
            scope = s; kind = k; eveningsOnly = false
        case .protectEvenings(let s):
            scope = s; kind = .rest; eveningsOnly = true
        case .unknown:
            return nil
        }

        let requested = WeekKey(containing: now, calendar: calendar).adding(weeks: scope == .nextWeek ? 1 : 0, calendar: calendar)
        // When the requested week has no room, the following week is offered instead of a dead end.
        for (offset, week) in [requested, requested.adding(weeks: 1, calendar: calendar)].enumerated() {
            let margins = planner.propose(
                week: week,
                kind: kind,
                eveningsOnly: eveningsOnly,
                now: now,
                items: items,
                baseRules: baseRules,
                trend: trend,
                count: eveningsOnly ? 3 : 2
            )
            guard !margins.isEmpty else { continue }

            let hours = Int(margins.reduce(0) { $0 + $1.hours }.rounded())
            let weekTitle = offset == 0 ? scope.title : "その次の週"
            var reason = offset == 0
                ? "\(weekTitle)の空いている時間から、予定とぶつからない\(margins.count)枠を選びました。"
                : "\(scope.title)は置ける時間がなかったので、その次の週で\(margins.count)枠を選びました。"
            if let summary = trend?.summary { reason += "最近の傾向から：\(summary)。" }
            return Suggestion(
                origin: .request,
                title: "\(weekTitle)の自分の時間 +\(hours)時間",
                reason: reason,
                weekStart: week.start,
                margins: margins,
                usesTrend: trend?.summary != nil,
                createdAt: now
            )
        }
        return nil
    }

    func proactiveSuggestion(
        now: Date,
        items: [CalendarItemSnapshot],
        goals: [MarginGoalSnapshot],
        baseRules: [BaseAvailabilityRule],
        history: [Suggestion],
        lastWeekSatisfaction: Satisfaction?,
        trend: TimeTrend?
    ) -> Suggestion? {
        let week = WeekKey(containing: now, calendar: calendar).adding(weeks: 1, calendar: calendar)
        guard !history.contains(where: { $0.origin == .proactive && $0.weekStart == week.start }) else { return nil }

        let boost = lastWeekSatisfaction == .low ? 1.25 : 1.0
        let target = (planner.weeklyTargetHours(for: week, goals: goals) * boost).rounded()
        let current = planner.selfTimeHours(in: week, items: items)
        let deficit = target - current
        guard deficit > 0.5 else { return nil }

        let count = min(3, max(1, Int((deficit / 3).rounded(.up))))
        let margins = planner.propose(
            week: week,
            kind: nil,
            now: now,
            items: items,
            baseRules: baseRules,
            trend: trend,
            count: count
        )
        guard !margins.isEmpty else { return nil }

        var reason = "来週の自分の時間が目標より約\(Int(deficit.rounded()))時間少なめです。"
        if lastWeekSatisfaction == .low { reason += "先週が「しんどかった」ので、少し多めにしています。" }
        if let summary = trend?.summary { reason += "最近の傾向から：\(summary)。" }
        let hours = Int(margins.reduce(0) { $0 + $1.hours }.rounded())
        return Suggestion(
            origin: .proactive,
            title: "来週の自分の時間 +\(hours)時間",
            reason: reason,
            weekStart: week.start,
            margins: margins,
            usesTrend: trend?.summary != nil,
            createdAt: now
        )
    }

    /// Margins that would now collide with something already on the calendar are dropped before applying.
    func applicableMargins(of suggestion: Suggestion, items: [CalendarItemSnapshot]) -> [SuggestedMargin] {
        let occupied = items.filter { $0.kind != .birthday }.map(\.occupiedInterval)
        return suggestion.margins.filter { margin in !occupied.contains(where: { $0.intersects(margin.interval) }) }
    }

    func visiblePending(_ suggestions: [Suggestion]) -> [Suggestion] {
        Array(suggestions.filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(Self.maxVisiblePending))
    }
}

// MARK: - Trend

struct TrendAnalyzer: Sendable {
    static let minimumSamples = 3

    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    /// Only Mira's own suggestion history is used. Returns nil when disabled or there is too little signal.
    func analyze(_ history: [Suggestion], enabled: Bool) -> TimeTrend? {
        guard enabled else { return nil }
        let resolved = history.filter { $0.status != .pending }
        guard resolved.count >= Self.minimumSamples else { return nil }

        var weekdays: [Int: Double] = [:]
        var bands: [TimeOfDayKind: Double] = [:]
        for suggestion in resolved {
            let weight: Double
            switch suggestion.status {
            case .applied: weight = 1
            case .dismissed, .undone: weight = -0.5
            case .pending: weight = 0
            }
            for margin in suggestion.margins {
                weekdays[calendar.component(.weekday, from: margin.startDate), default: 0] += weight
                bands[margin.timeOfDay, default: 0] += weight
            }
        }
        let scale = max(1, (weekdays.values.map(abs) + bands.values.map(abs)).max() ?? 1)
        return TimeTrend(
            weekdayScores: weekdays.mapValues { $0 / scale },
            bandScores: bands.mapValues { $0 / scale },
            sampleCount: resolved.count
        )
    }
}

// MARK: - Notifications

struct SuggestionNotificationPolicy: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func shouldNotify(_ suggestion: Suggestion, notificationsEnabled: Bool, lastNotifiedAt: Date?, now: Date) -> Bool {
        guard notificationsEnabled, suggestion.origin == .proactive, suggestion.status == .pending else { return false }
        guard let lastNotifiedAt else { return true }
        return !calendar.isDate(lastNotifiedAt, inSameDayAs: now)
    }

    /// Quiet hours are 22:00–8:00; a suggestion found then is delivered at 8:00.
    func deliveryDate(now: Date) -> Date {
        let hour = calendar.component(.hour, from: now)
        if (8..<22).contains(hour) { return now.addingTimeInterval(60) }
        let day = hour >= 22 ? now.addingDays(1, calendar: calendar) : now
        return day.setting(hour: 8, calendar: calendar)
    }

    func content(for suggestion: Suggestion, catVoice: Bool) -> (title: String, body: String) {
        (
            catVoice ? "Miraから提案があるにゃ" : "Miraから提案があります",
            "\(suggestion.title)。見るだけでも大丈夫です。"
        )
    }
}

// MARK: - Weekly review

struct WeeklyReviewEngine: Sendable {
    private let planner: SelfTimePlanner

    init(calendar: Calendar = .mira) {
        planner = SelfTimePlanner(calendar: calendar)
    }

    func summary(
        week: WeekKey,
        items: [CalendarItemSnapshot],
        goals: [MarginGoalSnapshot],
        suggestions: [Suggestion],
        satisfaction: Satisfaction?
    ) -> WeeklyReviewSummary {
        let weekSuggestions = suggestions.filter { $0.weekStart == week.start }
        return WeeklyReviewSummary(
            week: week,
            selfTimeHours: planner.selfTimeHours(in: week, items: items),
            targetHours: planner.weeklyTargetHours(for: week, goals: goals),
            appliedSuggestions: weekSuggestions.filter { $0.status == .applied }.count,
            dismissedSuggestions: weekSuggestions.filter { $0.status == .dismissed }.count,
            satisfaction: satisfaction
        )
    }
}
