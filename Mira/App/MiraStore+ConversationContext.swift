import Foundation

@MainActor
extension MiraStore {
    func enrichConversationInterpretation(
        _ interpretation: ConversationInterpretation,
        text: String,
        contextResult: ContextSearchResult?
    ) -> ConversationInterpretation {
        guard let caseID = contextResult?.relatedCaseID,
              let conversationCase = conversationCase(id: caseID) else {
            return interpretation
        }

        var value = interpretation
        let state = conversationCase.state
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.count <= 28 || value.title == normalized || value.title == "新しい予定" {
            value.title = conversationCase.title
        }
        value.person = value.person ?? state.person
        value.matchedContextID = conversationCase.id

        if !containsExplicitDuration(normalized), let stored = state.durationBucket {
            value.durationBucket = stored
            value.inferredFields.remove("duration")
        }

        if !containsExplicitDate(normalized) {
            value.dateRangeStart = state.dateRangeStart ?? value.dateRangeStart
            value.dateRangeEnd = state.dateRangeEnd ?? value.dateRangeEnd
            value.candidateDates = []
        }

        var constraints = Array(Set(state.explicitConstraints + value.explicitConstraints))
        if normalized.contains("夜は無理") || normalized.contains("夜なし") || normalized.contains("夜はなし") {
            appendUnique("夜を除外", to: &constraints)
        }
        if normalized.contains("土曜は外して") || normalized.contains("土曜なし") || normalized.contains("土曜は無理") {
            appendUnique("土曜を除外", to: &constraints)
        }
        if normalized.contains("日曜は外して") || normalized.contains("日曜なし") || normalized.contains("日曜は無理") {
            appendUnique("日曜を除外", to: &constraints)
        }
        value.explicitConstraints = constraints

        let explicitlyMentionedBands = explicitBands(in: normalized, duration: value.durationBucket ?? state.durationBucket)
        if !explicitlyMentionedBands.isEmpty,
           !normalized.contains("なし"),
           !normalized.contains("無理"),
           !normalized.contains("外して") {
            value.timeBands = explicitlyMentionedBands
            value.inferredFields.remove("timeBands")
        } else if !state.allowedTimeBands.isEmpty {
            value.timeBands = state.allowedTimeBands
        }

        if constraints.contains("夜を除外") {
            value.timeBands.removeAll { $0 == .evening }
        }

        if isSchedulingFollowUp(normalized), contextResult?.kind == .adjustment || contextResult?.kind == .invitation {
            value.intent = state.lastIntent == .checkInvitation ? .checkInvitation : .findDates
            value.needsClarification = value.durationBucket == nil || value.timeBands.isEmpty
            if value.timeBands.isEmpty {
                value.clarificationQuestion = "朝・昼・夜のどこなら行けそう？"
                value.clarificationOptions = (value.durationBucket ?? .short).selectableBands
                    .filter { $0 != .evening || !constraints.contains("夜を除外") }
                    .map(\.title)
            }
        }

        return value
    }

    func applySchedulingConstraints(
        _ draft: SchedulingDraft,
        constraints: [String]
    ) -> SchedulingDraft {
        var value = draft
        let filtered = value.recommendations.filter { recommendation in
            let weekday = Calendar.mira.component(.weekday, from: recommendation.day)
            if constraints.contains("土曜を除外"), weekday == 7 { return false }
            if constraints.contains("日曜を除外"), weekday == 1 { return false }
            if constraints.contains("夜を除外"), recommendation.timeBand == .evening { return false }
            return true
        }
        let survivingIDs = Set(filtered.map(\.id))
        value.recommendations = filtered
        value.selectedRecommendationIDs.formIntersection(survivingIDs)
        return value
    }

    private func isSchedulingFollowUp(_ text: String) -> Bool {
        let words = [
            "夜は", "昼は", "朝は", "午前", "午後", "土曜", "日曜",
            "来週なら", "再来週", "候補", "送る文", "なし", "無理", "外して"
        ]
        return words.contains(where: text.contains)
    }

    private func containsExplicitDuration(_ text: String) -> Bool {
        if text.contains("終日") || text.contains("一日") || text.contains("半日") { return true }
        return text.range(of: "[0-9０-９]{1,2}\\s*(時間|h|H)", options: .regularExpression) != nil
    }

    private func containsExplicitDate(_ text: String) -> Bool {
        if ["今日", "明日", "今週", "来週", "再来週", "今月", "来月"].contains(where: text.contains) {
            return true
        }
        if text.range(of: "(?:[0-9０-９]{1,2}月)?[0-9０-９]{1,2}日", options: .regularExpression) != nil {
            return true
        }
        return ["月曜", "火曜", "水曜", "木曜", "金曜", "土曜", "日曜"].contains(where: text.contains)
    }

    private func explicitBands(in text: String, duration: DurationBucket?) -> [SchedulingTimeBand] {
        var bands: [SchedulingTimeBand] = []
        if text.contains("朝") { bands.append(.morning) }
        if text.contains("昼") { bands.append(duration == .halfDay ? .secondHalf : .midday) }
        if text.contains("夜") { bands.append(.evening) }
        if text.contains("午前") { bands.append(duration == .halfDay ? .firstHalf : .morning) }
        if text.contains("午後") { bands.append(duration == .halfDay ? .secondHalf : .midday) }
        if text.contains("終日") { bands = [.allDay] }
        return Array(Set(bands)).sorted { $0.rawValue < $1.rawValue }
    }

    private func appendUnique(_ value: String, to values: inout [String]) {
        if !values.contains(value) { values.append(value) }
    }
}
