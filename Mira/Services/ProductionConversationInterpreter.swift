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
        var result = await base.interpret(
            text: text,
            now: now,
            pinnedContext: pinnedContext,
            searchCandidates: searchCandidates,
            recentTurns: recentTurns
        )

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        applyColloquialDefaults(text: normalized, to: &result)

        let resolvedContext = pinnedContext ?? uniquelyResolvedContext(searchCandidates)
        guard let resolvedContext,
              isFollowUp(normalized),
              let previousText = recentTurns.reversed().first(where: { $0.role == .user })?.text else {
            return result
        }

        let previous = await RuleBasedConversationInterpreter(calendar: calendar).interpret(
            text: previousText,
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

    private func containsExplicitDate(_ text: String) -> Bool {
        if ["今日", "明日", "今週", "来週", "再来週", "今月", "来月"].contains(where: text.contains) {
            return true
        }
        if text.range(of: "(?:[0-9０-９]{1,2}月)?[0-9０-９]{1,2}日", options: .regularExpression) != nil {
            return true
        }
        if text.range(of: "[0-9０-９]{1,2}/[0-9０-９]{1,2}", options: .regularExpression) != nil {
            return true
        }
        return ["月曜", "火曜", "水曜", "木曜", "金曜", "土曜", "日曜"].contains(where: text.contains)
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
