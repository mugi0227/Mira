import Foundation

/// Adds deterministic guardrails around the on-device model so common scheduling
/// phrases remain reliable even when Foundation Models is unavailable or unsure.
struct RobustConversationInterpreter: ConversationInterpreting {
    private let hybrid = HybridConversationInterpreter()
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
        var value = await hybrid.interpret(
            text: text,
            now: now,
            pinnedContext: pinnedContext,
            searchCandidates: searchCandidates,
            recentTurns: recentTurns
        )

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasContext = pinnedContext != nil || value.matchedContextID != nil || !searchCandidates.isEmpty
        let parsedDates = slashDates(in: normalized, now: now) + weekdayDates(in: normalized, now: now)
        if !parsedDates.isEmpty {
            value.candidateDates = uniqueDays(value.candidateDates + parsedDates)
            if value.dateRangeStart == nil { value.dateRangeStart = value.candidateDates.min() }
            if value.dateRangeEnd == nil { value.dateRangeEnd = value.candidateDates.max() }
            value.inferredFields.remove("dateRange")
        }

        if isInvitationMessage(normalized) {
            value.intent = .checkInvitation
            value.needsClarification = false
            value.clarificationQuestion = nil
            value.clarificationOptions = []
        }

        if hasContext && containsSchedulingCorrection(normalized) {
            value.intent = .findDates
            value.needsClarification = false
            value.clarificationQuestion = nil
            value.clarificationOptions = []
        }

        if hasContext && containsConcreteUpdate(normalized) {
            value.intent = .updateExisting
            value.needsClarification = false
            value.clarificationQuestion = nil
            value.clarificationOptions = []
        }

        if normalized.contains("夜は無理") || normalized.contains("夜なし") || normalized.contains("夜はなし") {
            value.timeBands.removeAll { $0 == .evening }
            if !value.explicitConstraints.contains("夜を除外") {
                value.explicitConstraints.append("夜を除外")
            }
        }
        if normalized.contains("昼がいい") || normalized.contains("昼なら") {
            value.timeBands = [.midday]
            value.inferredFields.remove("timeBands")
        }
        if normalized.contains("朝がいい") || normalized.contains("朝なら") {
            value.timeBands = [.morning]
            value.inferredFields.remove("timeBands")
        }

        if value.durationBucket == nil, canSafelyAssumeShort(normalized) {
            value.durationBucket = .short
            value.inferredFields.insert("duration")
        }
        if value.timeBands.isEmpty, let duration = value.durationBucket, !value.needsClarification {
            value.timeBands = inferredBands(text: normalized, duration: duration)
            value.inferredFields.insert("timeBands")
        }

        if value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.title == normalized {
            value.title = inferredTitle(from: normalized, context: pinnedContext ?? searchCandidates.first)
        }
        value.confidence = max(value.confidence, deterministicConfidence(for: normalized, value: value))
        value.source = value.source + " + Harness"
        return value
    }

    private func isInvitationMessage(_ text: String) -> Bool {
        let hasDateCue = text.contains("来週") || text.contains("今週") || text.contains("日") || text.contains("曜") || text.contains("/ ") || text.contains("/")
        let invitationEndings = ["行かん", "行かない", "行く？", "どう？", "どうかな", "飲まん", "食べん", "空いてる？", "来れる？"]
        return hasDateCue && invitationEndings.contains(where: text.contains)
    }

    private func containsSchedulingCorrection(_ text: String) -> Bool {
        ["は無理", "はなし", "なしで", "外して", "だけで", "ならいける", "なら行ける"].contains(where: text.contains)
    }

    private func containsConcreteUpdate(_ text: String) -> Bool {
        ["になった", "に変更", "からになった", "へずら", "にずら", "確定した"].contains(where: text.contains)
    }

    private func canSafelyAssumeShort(_ text: String) -> Bool {
        ["焼肉", "飲み", "ご飯", "カフェ", "ランチ", "美容院", "病院", "面談", "打ち合わせ", "映画"].contains(where: text.contains)
    }

    private func inferredBands(text: String, duration: DurationBucket) -> [SchedulingTimeBand] {
        if duration == .fullDay { return [.allDay] }
        if duration == .halfDay { return [.firstHalf, .secondHalf] }
        if text.contains("焼肉") || text.contains("飲み") || text.contains("ディナー") { return [.evening] }
        if text.contains("カフェ") || text.contains("ランチ") || text.contains("美容院") { return [.midday] }
        return [.morning, .midday, .evening]
    }

    private func inferredTitle(from text: String, context: ContextSearchResult?) -> String {
        if let context { return context.title }
        var value = text
        let removals = [
            "来週", "今週", "再来週", "来月", "今月", "いついけそう", "いつ行けそう",
            "行けそう", "いけそう", "どっちか", "どう？", "どうかな", "誘われた", "これ"
        ]
        for removal in removals {
            value = value.replacingOccurrences(of: removal, with: "")
        }
        value = value
            .replacingOccurrences(of: "(?:(\\d{1,2})月)?(\\d{1,2})日", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\d{1,2}/\\d{1,2}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[月火水木金土日]曜(日)?", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[?？!！]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "新しい予定" : String(value.prefix(36))
    }

    private func slashDates(in text: String, now: Date) -> [Date] {
        guard let regex = try? NSRegularExpression(pattern: "(?<!\\d)(\\d{1,2})[/-](\\d{1,2})(?!\\d)") else { return [] }
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

    private func weekdayDates(in text: String, now: Date) -> [Date] {
        let mapping: [(String, Int)] = [
            ("日曜", 1), ("月曜", 2), ("火曜", 3), ("水曜", 4),
            ("木曜", 5), ("金曜", 6), ("土曜", 7)
        ]
        return mapping.compactMap { label, weekday in
            guard text.contains(label) else { return nil }
            let base: Date
            if text.contains("再来週") {
                base = startOfWeek(now).addingDays(14, calendar: calendar)
            } else if text.contains("来週") {
                base = startOfWeek(now).addingDays(7, calendar: calendar)
            } else {
                base = calendar.startOfDay(for: now)
            }
            let baseWeekday = calendar.component(.weekday, from: base)
            var delta = (weekday - baseWeekday + 7) % 7
            if delta == 0, !text.contains("来週"), !text.contains("再来週") { delta = 7 }
            return base.addingDays(delta, calendar: calendar)
        }
    }

    private func startOfWeek(_ date: Date) -> Date {
        var value = calendar
        value.firstWeekday = 2
        let components = value.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return value.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func uniqueDays(_ dates: [Date]) -> [Date] {
        Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
    }

    private func deterministicConfidence(for text: String, value: ConversationInterpretation) -> Double {
        var score = 0.45
        if value.intent != .unknown { score += 0.16 }
        if value.durationBucket != nil { score += 0.10 }
        if !value.timeBands.isEmpty { score += 0.10 }
        if !value.candidateDates.isEmpty || value.dateRangeStart != nil { score += 0.10 }
        if text.count >= 4 { score += 0.04 }
        return min(0.95, score)
    }
}
