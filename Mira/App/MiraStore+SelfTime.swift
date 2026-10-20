import Foundation
import SwiftData

extension Notification.Name {
    static let miraOpenChat = Notification.Name("mira.open-chat")
}

/// Suggestions for the person's own time. Mira proposes in the chat and only
/// changes the calendar when the person taps the card (PR-004).
@MainActor
extension MiraStore {
    static let openChatRequestKey = "mira.open-chat.pending"

    var currentWeek: WeekKey { WeekKey(containing: now) }

    var currentTrend: TimeTrend? {
        TrendAnalyzer().analyze(selfTimeLog.suggestions, enabled: trendSuggestionsEnabled)
    }

    func weeklyReview(for week: WeekKey) -> WeeklyReviewSummary {
        loadSelfTimeLogIfNeeded()
        return WeeklyReviewEngine().summary(
            week: week,
            items: items,
            goals: goals,
            suggestions: selfTimeLog.suggestions,
            satisfaction: selfTimeLog.reflections[week.start]
        )
    }

    // MARK: - Chat

    /// Clear wishes about one's own time are answered deterministically, on every device.
    func selfTimeIntent(in text: String) -> PlanningIntent? {
        let intent = IntentInterpreter().interpret(text)
        return intent == .unknown ? nil : intent
    }

    func respondToSelfTimeRequest(_ intent: PlanningIntent, sink: ChatTurnSink) {
        loadSelfTimeLogIfNeeded()
        let activity = ChatActivity(symbol: "leaf", text: "空いている時間と、守っている余白を確認")
        guard let suggestion = SuggestionEngine().suggestion(
            for: intent,
            now: now,
            items: items,
            baseRules: fetchBaseRules(),
            trend: currentTrend
        ) else {
            let hours = Int(SelfTimePlanner().selfTimeHours(in: currentWeek.adding(weeks: 1), items: items).rounded())
            sink.record(MiraToolResult(summary: "置ける時間なし", activity: activity, card: nil))
            sink.setText("来週もその次の週も、予定とぶつからずに置ける時間が見つからなかったにゃ。来週はもう自分の時間が\(hours)時間あるよ。どれかの予定を動かす相談もできるにゃ。")
            return
        }
        record(suggestion)
        sink.record(MiraToolResult(
            summary: suggestion.title,
            activity: activity,
            card: .selfTime(ChatSelfTimeProposal(suggestion: suggestion))
        ))
        sink.setText(suggestion.usesTrend
            ? "最近のあなたの選び方も見て、置けそうな時間を選んだにゃ。いらない枠はチップをタップして外してね。"
            : "予定とぶつからない時間を選んだにゃ。いらない枠はチップをタップして外してね。")
    }

    // MARK: - Proactive

    /// Checks next week once and, when own time runs short, leaves a suggestion in the chat.
    func refreshProactiveSelfTimeSuggestion() async {
        loadSelfTimeLogIfNeeded()
        guard onboardingCompleted else { return }
        restoreChatIfNeeded()
        let lastWeek = currentWeek.adding(weeks: -1)
        guard let suggestion = SuggestionEngine().proactiveSuggestion(
            now: now,
            items: items,
            goals: goals,
            baseRules: fetchBaseRules(),
            history: selfTimeLog.suggestions,
            lastWeekSatisfaction: selfTimeLog.reflections[lastWeek.start] ?? selfTimeLog.reflections[currentWeek.start],
            trend: currentTrend
        ) else { return }
        record(suggestion)

        let catVoice = theme == .pixelCat
        chatMessages.append(ChatMessage(
            role: .assistant,
            text: catVoice
                ? "来週、自分の時間がちょっと少なめだにゃ。こんな置き方はどう？決めるのはあなただよ。"
                : "来週は自分の時間が少なめです。こんな置き方はどうでしょう。決めるのはあなたです。",
            activities: [ChatActivity(symbol: "bell.badge", text: "来週の予定と自分の時間を確認")],
            cards: [.selfTime(ChatSelfTimeProposal(suggestion: suggestion))],
            createdAt: now,
            isProactive: true
        ))
        persistChat()
        hasUnreadMiraSuggestion = true

        let policy = SuggestionNotificationPolicy()
        let wallClock = Date()
        guard !demoModeEnabled, policy.shouldNotify(
            suggestion,
            notificationsEnabled: notificationsEnabled,
            lastNotifiedAt: selfTimeLog.lastNotifiedAt,
            now: wallClock
        ) else { return }
        let content = policy.content(for: suggestion, catVoice: characterNotificationsEnabled && catVoice)
        await NotificationService.shared.scheduleSuggestion(
            id: suggestion.id,
            title: content.title,
            body: content.body,
            at: policy.deliveryDate(now: wallClock)
        )
        selfTimeLog.lastNotifiedAt = wallClock
        persistSelfTimeLog()
    }

    func markMiraSuggestionsRead() {
        hasUnreadMiraSuggestion = false
        UserDefaults.standard.removeObject(forKey: Self.openChatRequestKey)
    }

    // MARK: - Cards

    func applySelfTimeCard(messageID: UUID, proposal: ChatSelfTimeProposal) -> Bool {
        guard proposal.state == .pending else { return false }
        loadSelfTimeLogIfNeeded()
        var proposal = proposal
        let chosen = proposal.chosenMargins
        guard !chosen.isEmpty else {
            toast = "置く枠を1つ以上選んでね"
            return false
        }
        var limited = proposal.suggestion
        limited.margins = chosen
        let applicable = SuggestionEngine().applicableMargins(of: limited, items: items)
        guard !applicable.isEmpty else {
            toast = "もう空いていなかったので、置けませんでした"
            return false
        }
        let undo = captureCalendarUndo(title: "自分の時間の提案")
        do {
            applicable.forEach { context.insert(CalendarItemEntity(snapshot: $0.calendarItem())) }
            try context.save()
            try refresh()
            finishCalendarMutation(undo)
        } catch {
            context.rollback()
            try? refresh()
            toast = "自分の時間を置けませんでした"
            return false
        }
        proposal.state = .applied
        proposal.appliedMarginIDs = applicable.map(\.id)
        replaceSelfTimeCard(messageID: messageID, with: proposal)
        updateSuggestion(proposal.suggestion.id) {
            $0.status = .applied
            $0.resolvedAt = now
            $0.margins = applicable
            $0.appliedMarginIDs = applicable.map(\.id)
        }
        recalculateBalance(for: applicable[0].startDate)
        toast = applicable.count == chosen.count
            ? "自分の時間を\(applicable.count)枠置いたにゃ"
            : "空いていた\(applicable.count)枠だけ置いたにゃ"
        return true
    }

    func dismissSelfTimeCard(messageID: UUID, proposal: ChatSelfTimeProposal) {
        guard proposal.state == .pending else { return }
        var proposal = proposal
        proposal.state = .dismissed
        replaceSelfTimeCard(messageID: messageID, with: proposal)
        updateSuggestion(proposal.suggestion.id) {
            $0.status = .dismissed
            $0.resolvedAt = now
        }
    }

    func toggleSelfTimeSlot(messageID: UUID, proposal: ChatSelfTimeProposal, marginID: UUID) {
        guard proposal.state == .pending else { return }
        var proposal = proposal
        if let index = proposal.excludedMarginIDs.firstIndex(of: marginID) {
            proposal.excludedMarginIDs.remove(at: index)
        } else {
            proposal.excludedMarginIDs.append(marginID)
        }
        replaceSelfTimeCard(messageID: messageID, with: proposal)
    }

    /// Removes only the margins this card added, and only while they are unchanged.
    func undoSelfTimeCard(messageID: UUID, proposal: ChatSelfTimeProposal) {
        guard proposal.state == .applied else { return }
        var proposal = proposal
        do {
            for marginID in proposal.appliedMarginIDs {
                if let entity = try entity(id: marginID), entity.kindRaw == CalendarItemKind.margin.rawValue {
                    context.delete(entity)
                }
            }
            try context.save()
            try refresh()
        } catch {
            context.rollback()
            try? refresh()
            toast = "取り消せませんでした"
            return
        }
        proposal.state = .undone
        replaceSelfTimeCard(messageID: messageID, with: proposal)
        updateSuggestion(proposal.suggestion.id) {
            $0.status = .undone
            $0.resolvedAt = now
        }
        toast = "元に戻したにゃ"
    }

    private func replaceSelfTimeCard(messageID: UUID, with proposal: ChatSelfTimeProposal) {
        updateChatMessage(messageID) { message in
            guard let index = message.cards.firstIndex(where: { $0.id == proposal.id }) else { return }
            message.cards[index] = .selfTime(proposal)
        }
        persistChat()
    }

    // MARK: - Reflection and settings

    func setSatisfaction(_ satisfaction: Satisfaction, for week: WeekKey) {
        loadSelfTimeLogIfNeeded()
        selfTimeLog.reflections[week.start] = satisfaction
        persistSelfTimeLog()
    }

    func setTrendSuggestionsEnabled(_ enabled: Bool) {
        trendSuggestionsEnabled = enabled
        settingsEntity?.trendSuggestionsEnabled = enabled
        try? context.save()
    }

    func friendAvailabilityText() -> String {
        FriendAvailabilityText.text(from: now, items: items, baseRules: fetchBaseRules())
    }

    // MARK: - Storage

    private func record(_ suggestion: Suggestion) {
        selfTimeLog.upsert(suggestion)
        persistSelfTimeLog()
    }

    private func updateSuggestion(_ id: UUID, _ change: (inout Suggestion) -> Void) {
        guard var suggestion = selfTimeLog.suggestions.first(where: { $0.id == id }) else { return }
        change(&suggestion)
        record(suggestion)
    }

    func loadSelfTimeLogIfNeeded() {
        guard !selfTimeLogLoaded else { return }
        selfTimeLogLoaded = true
        guard let url = selfTimeLogURL, let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(SelfTimeLog.self, from: data) else { return }
        selfTimeLog = saved
    }

    func persistSelfTimeLog() {
        guard let url = selfTimeLogURL, let data = try? JSONEncoder().encode(selfTimeLog) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func resetSelfTimeLog() {
        selfTimeLog = SelfTimeLog()
        selfTimeLogLoaded = true
        hasUnreadMiraSuggestion = false
        if let url = selfTimeLogURL { try? FileManager.default.removeItem(at: url) }
    }

    /// In-memory stores (tests, emergency storage) keep the log in memory only.
    private var selfTimeLogURL: URL? {
        guard !container.configurations.allSatisfy({ $0.isStoredInMemoryOnly }) else { return nil }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Mira", isDirectory: true)
            .appendingPathComponent("self-time-log.json")
    }
}
