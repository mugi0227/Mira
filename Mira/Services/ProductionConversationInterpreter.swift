import Foundation

/// Production interpreter that keeps the on-device model bounded by deterministic
/// scheduling rules and restores the previous case conditions for short follow-ups.
struct ProductionConversationInterpreter: ConversationInterpreting {
    private let base = RobustConversationInterpreter()
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func interpret(
        text: String,
        now: Date,
        pinnedContext: ContextSearchResult?,
        searchCandidates: [ContextSearchResult],
        recentTurns: [ConversationTurnSnapshot]
    ) async -> ConversationInterpretation {
        let normalized = normalize(text)
        var result = await base.interpret(
            text: normalized,
            now: now,
            pinnedContext: pinnedContext,
            searchCandidates: searchCandidates,
            recentTurns: recentTurns
        )

        applySupplementalDates(from: normalized, now: now, to: &result)
        applyExactTime(from: normalized, now: now, pinnedContext: pinnedContext, to: &result)
        applyColloquialDefaults(text: normalized, to: &result)

        let resolvedContext = pinnedContext ?? uniquelyResolvedContext(searchCandidates)
        if resolvedContext != nil && containsConcreteUpdate(normalized) {
            result.intent = .updateExisting
            result.needsClarification = false
            result.clarificationQuestion = nil
            result.clarificationOptions = []
        }

        guard let resolvedContext,
              isFollowUp(normalized),
              let previousText = recentTurns.reversed().first(where: { $0.role == .user })?.text else {
            return result
        }

        let previous = await RuleBasedConversationInterpreter(calendar: calendar).interpret(
            text: normalize(previousText),
            now: now,
            pinnedContext: resolvedContext,
            searchCandidates: [resolvedContext],
            recentTurns: []
        )

        result.title = resolvedContext.title
        result.matchedContextID = resolvedContext.id
        result.durationBucket = result.durationBucket ?? previous.durationBucket

        if !containsExplicitDate(normalized) {
            result.candidateDates = previous.candidateDates
            result.dateRangeStart = previous.dateRangeStart ?? resolvedContext.startDate
            result.dateRangeEnd = previous.dateRangeEnd ?? resolvedContext.endDate
        }

        if result.timeBands.isEmpty {
            result.timeBands = previous.timeBands
        }
        applyExclusions(from: result.explicitConstraints, to: &result.timeBands)

        if result.timeBands.isEmpty, let duration = result.durationBucket {
            result.timeBands = duration.selectableBands.filter { band in
                !isExcluded(band, by: result.explicitConstraints)
            }
            result.inferredFields.insert("timeBands")
        }

        result.intent = resolvedContext.kind == .invitation ? .checkInvitation : .findDates
        result.needsClarification = result.durationBucket == nil || result.timeBands.isEmpty
        if result.needsClarification {
            result.clarificationQuestion = result.durationBucket == nil
                ? "どのくらいの予定になりそう？"
                : "朝・昼・夜のどこなら行けそう？"
            result.clarificationOptions = result.durationBucket == nil
                ? DurationBucket.allCases.map(\.title)
                : (result.durationBucket ?? .short).selectableBands
                    .filter { !isExcluded($0, by: result.explicitConstraints) }
                    .map(\.title)
        } else {
            result.clarificationQuestion = nil
            result.clarificationOptions = []
        }
        result.source += " + CaseContinuation"
        return result
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(
                options: [.widthInsensitive, .caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "ja_JP")
            )
            .replacingOccurrences(of: "／", with: "/")
            .replacingOccurrences(of: "：", with: ":")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applySupplementalDates(
        from text: String,
        now: Date,
        to result: inout ConversationInterpretation
    ) {
        let dates = relativeDates(in: text, now: now) + slashDates(in: text, now: now)
        guard !dates.isEmpty else { return }
        result.candidateDates = uniqueDays(result.candidateDates + dates)
        result.dateRangeStart = result.candidateDates.min()
        result.dateRangeEnd = result.candidateDates.max()?.setting(hour: 23, minute: 59)
        result.inferredFields.remove("dateRange")
    }

    private func applyExactTime(
        from text: String,
        now: Date,
        pinnedContext: ContextSearchResult?,
        to result: inout ConversationInterpretation
    ) {
        guard let (hour, minute) = exactClockTime(in: text) else { return }
        let day = result.candidateDates.first
            ?? pinnedContext?.startDate
            ?? result.dateRangeStart
            ?? now
        let start = day.setting(hour: hour, minute: minute, calendar: calendar)
        let durationMinutes = result.durationBucket?.representativeMinutes ?? 120
        result.exactStartDate = start
        result.exactEndDate = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    private func applyColloquialDefaults(
        text: String,
        to result: inout ConversationInterpretation
    ) {
        if text.contains("飲まん") || text.contains("飲みに") {
            result.intent = .checkInvitation
            if result.durationBucket == nil {
                result.durationBucket = .short
                result.inferredFields.insert("duration")
            }
            if result.timeBands.isEmpty {
                result.timeBands = [.evening]
                result.inferredFields.insert("timeBands")
            }
            result.needsClarification = false
            result.clarificationQuestion = nil
            result.clarificationOptions = []
        }
    }

    private func uniquelyResolvedContext(
        _ candidates: [ContextSearchResult]
    ) -> ContextSearchResult? {
        guard let first = candidates.first else { return nil }
        let secondScore = candidates.dropFirst().first?.score ?? 0
        return first.score >= 75 && first.score - secondScore >= 18 ? first : nil
    }

    private func isFollowUp(_ text: String) -> Bool {
        let cues = [
            "夜は", "昼は", "朝は", "午前", "午後", "土曜", "日曜", "平日",
            "やっぱ", "じゃあ", "それで", "その件", "この件", "候補", "断る文",
            "来週なら", "別の日", "時間は", "何時", "なしで", "外して", "無理"
        ]
        return cues.contains(where: text.contains)
    }

    private func containsConcreteUpdate(_ text: String) -> Bool {
        ["になった", "に変更", "からになった", "へずら", "にずら", "確定した"].contains(where: text.contains)
    }

    private func containsExplicitDate(_ text: String) -> Bool {
        if ["今日", "明日", "明後日", "今週", "来週", "再来週", "今月", "来月"].contains(where: text.contains) {
            return true
        }
        if text.range(of: "(?:[0-9]{1,2}月)?[0-9]{1,2}日", options: .regularExpression) != nil {
            return true
        }
        if text.range(of: "[0-9]{1,2}/[0-9]{1,2}", options: .regularExpression) != nil {
            return true
        }
        return ["月曜", "火曜", "水曜", "木曜", "金曜", "土曜", "日曜"].contains(where: text.contains)
    }

    private func relativeDates(in text: String, now: Date) -> [Date] {
        if text.contains("明後日") { return [now.addingDays(2, calendar: calendar)] }
        if text.contains("明日") { return [now.addingDays(1, calendar: calendar)] }
        if text.contains("今日") { return [now] }
        return []
    }

    private func slashDates(in text: String, now: Date) -> [Date] {
        guard let regex = try? NSRegularExpression(pattern: "(?<![0-9])([0-9]{1,2})[/-]([0-9]{1,2})(?![0-9])") else {
            return []
        }
        let nsText = text as NSString
        let currentYear = calendar.component(.year, from: now)
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard let month = Int(nsText.substring(with: match.range(at: 1))),
                  let day = Int(nsText.substring(with: match.range(at: 2))) else { return nil }
            var components = DateComponents(year: currentYear, month: month, day: day)
            guard var date = calendar.date(from: components) else { return nil }
            if date < calendar.startOfDay(for: now) {
                components.year = currentYear + 1
                date = calendar.date(from: components) ?? date
            }
            return date
        }
    }

    private func exactClockTime(in text: String) -> (Int, Int)? {
        let patterns = [
            "(?<![0-9])([0-9]{1,2}):([0-9]{2})(?![0-9])",
            "(?<![0-9])([0-9]{1,2})時(半|[0-9]{1,2}分)?"
        ]
        let nsText = text as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
                  let hour = Int(nsText.substring(with: match.range(at: 1))) else { continue }
            var minute = 0
            if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound {
                let token = nsText.substring(with: match.range(at: 2))
                if token == "半" {
                    minute = 30
                } else {
                    minute = Int(token.replacingOccurrences(of: "分", with: "")) ?? 0
                }
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { continue }
            return (hour, minute)
        }
        return nil
    }

    private func uniqueDays(_ dates: [Date]) -> [Date] {
        Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
    }

    private func applyExclusions(
        from constraints: [String],
        to bands: inout [SchedulingTimeBand]
    ) {
        bands.removeAll { isExcluded($0, by: constraints) }
    }

    private func isExcluded(
        _ band: SchedulingTimeBand,
        by constraints: [String]
    ) -> Bool {
        if constraints.contains("夜を除外"), band == .evening { return true }
        return false
    }
}
