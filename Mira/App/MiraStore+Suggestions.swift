import Foundation
import SwiftData

@MainActor
extension MiraStore {
    enum RequestOutcome: Equatable {
        case suggested(Suggestion)
        case needsChoice([PlanningIntent])
        case nothingFits(scope: WeekScope, currentHours: Int)
    }

    var visibleSuggestions: [Suggestion] {
        suggestionEngine.visiblePending(suggestions)
    }

    var suggestionHistory: [Suggestion] {
        Array(suggestions.filter { $0.status != .pending }.prefix(8))
    }

    var currentTrend: TimeTrend? {
        TrendAnalyzer().analyze(suggestions, enabled: trendSuggestionsEnabled)
    }

    var currentWeek: WeekKey { WeekKey(containing: now) }

    func weeklyReview(for week: WeekKey) -> WeeklyReviewSummary {
        WeeklyReviewEngine().summary(
            week: week,
            items: items,
            goals: goals,
            suggestions: suggestions,
            satisfaction: reflections[week.start]
        )
    }

    /// Turns a vague wish into a pending suggestion. Nothing on the calendar changes until the user applies it.
    func submitRequest(_ text: String) -> RequestOutcome {
        let intent = IntentInterpreter().interpret(text)
        guard intent != .unknown else { return .needsChoice(IntentInterpreter.fallbackOptions) }
        return submitIntent(intent)
    }

    func submitIntent(_ intent: PlanningIntent) -> RequestOutcome {
        guard let suggestion = suggestionEngine.suggestion(
            for: intent,
            now: now,
            items: items,
            baseRules: fetchBaseRules(),
            trend: currentTrend
        ) else {
            let scope: WeekScope
            switch intent {
            case .increaseSelfTime(let s, _), .protectEvenings(let s): scope = s
            case .unknown: scope = .nextWeek
            }
            let week = currentWeek.adding(weeks: scope == .nextWeek ? 1 : 0)
            let hours = Int(SelfTimePlanner().selfTimeHours(in: week, items: items).rounded())
            return .nothingFits(scope: scope, currentHours: hours)
        }
        save(suggestion, isNew: true)
        return .suggested(suggestions.first { $0.id == suggestion.id } ?? suggestion)
    }

    /// Looks for a proactive suggestion for next week and notifies once per day at most.
    func refreshProactiveSuggestions() async {
        let lastWeek = currentWeek.adding(weeks: -1)
        guard let suggestion = suggestionEngine.proactiveSuggestion(
            now: now,
            items: items,
            goals: goals,
            baseRules: fetchBaseRules(),
            history: suggestions,
            lastWeekSatisfaction: reflections[lastWeek.start] ?? reflections[currentWeek.start],
            trend: currentTrend
        ) else { return }
        save(suggestion, isNew: true)

        let lastNotifiedAt = settingsEntity?.lastSuggestionNotifiedAt
        guard notificationPolicy.shouldNotify(
            suggestion,
            notificationsEnabled: notificationsEnabled,
            lastNotifiedAt: lastNotifiedAt,
            now: Date()
        ) else { return }
        let content = notificationPolicy.content(for: suggestion, catVoice: characterNotificationsEnabled && theme == .pixelCat)
        await NotificationService.shared.scheduleSuggestion(
            id: suggestion.id,
            title: content.title,
            body: content.body,
            at: notificationPolicy.deliveryDate(now: Date())
        )
        settingsEntity?.lastSuggestionNotifiedAt = Date()
        try? context.save()
    }

    func applySuggestion(id: UUID) {
        guard var suggestion = suggestions.first(where: { $0.id == id }), suggestion.status == .pending else { return }
        let applicable = suggestionEngine.applicableMargins(of: suggestion, items: items)
        guard !applicable.isEmpty else {
            toast = "もう空いていなかったので、置けませんでした"
            return
        }
        applicable.forEach { context.insert(CalendarItemEntity(snapshot: $0.calendarItem())) }
        suggestion.status = .applied
        suggestion.resolvedAt = now
        suggestion.appliedMarginIDs = applicable.map(\.id)
        save(suggestion, isNew: false)
        toast = applicable.count == suggestion.margins.count
            ? "自分の時間を置いたにゃ"
            : "空いていた\(applicable.count)枠だけ置いたにゃ"
    }

    func dismissSuggestion(id: UUID) {
        guard var suggestion = suggestions.first(where: { $0.id == id }), suggestion.status == .pending else { return }
        suggestion.status = .dismissed
        suggestion.resolvedAt = now
        save(suggestion, isNew: false)
        toast = "今回は見送ったにゃ"
    }

    func undoSuggestion(id: UUID) {
        guard var suggestion = suggestions.first(where: { $0.id == id }), suggestion.status == .applied else { return }
        do {
            for marginID in suggestion.appliedMarginIDs {
                if let entity = try entity(id: marginID) { context.delete(entity) }
            }
            suggestion.status = .undone
            suggestion.resolvedAt = now
            save(suggestion, isNew: false)
            toast = "元に戻したにゃ"
        } catch {
            toast = "取り消せませんでした"
        }
    }

    func setSatisfaction(_ satisfaction: Satisfaction, for week: WeekKey) {
        do {
            let start = week.start
            var descriptor = FetchDescriptor<WeeklyReflectionEntity>(predicate: #Predicate { $0.weekStart == start })
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                existing.satisfactionRaw = satisfaction.rawValue
                existing.updatedAt = .now
            } else {
                context.insert(WeeklyReflectionEntity(weekStart: start, satisfaction: satisfaction))
            }
            try context.save()
            try refresh()
        } catch {
            toast = "ふりかえりを保存できませんでした"
        }
    }

    func setTrendSuggestionsEnabled(_ enabled: Bool) {
        trendSuggestionsEnabled = enabled
        settingsEntity?.trendSuggestionsEnabled = enabled
        try? context.save()
    }

    func shareDays(rule: AvailabilityShareRule) -> [PublicDay] {
        AvailabilityShareEngine().publicDays(rule: rule, items: items, baseRules: fetchBaseRules())
    }

    private func save(_ suggestion: Suggestion, isNew: Bool) {
        do {
            if isNew {
                // The demo clock is frozen, so real time keeps the newest suggestion first.
                var stamped = suggestion
                stamped.createdAt = Date()
                context.insert(SuggestionEntity(suggestion: stamped))
            } else {
                let targetID = suggestion.id
                var descriptor = FetchDescriptor<SuggestionEntity>(predicate: #Predicate { $0.id == targetID })
                descriptor.fetchLimit = 1
                try context.fetch(descriptor).first?.apply(suggestion)
            }
            try context.save()
            try refresh()
        } catch {
            toast = "提案を保存できませんでした"
        }
    }
}
