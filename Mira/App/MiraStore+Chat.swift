import Foundation

/// What a tool hands back: a compact text for the model, plus what the
/// person sees in the chat.
struct MiraToolResult: Sendable {
    var summary: String
    var activity: ChatActivity
    var card: ChatCard?
}

@MainActor
extension MiraStore {
    // MARK: - Conversation

    func sendChat(_ rawText: String) async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isChatResponding else { return }
        isChatResponding = true
        defer { isChatResponding = false }

        chatMessages.append(ChatMessage(role: .user, text: text, createdAt: now))
        let reply = ChatMessage(role: .assistant, text: "", isStreaming: true, createdAt: now)
        chatMessages.append(reply)
        let sink = ChatTurnSink(store: self, messageID: reply.id)

        do {
            try await currentChatAgent().respond(to: text, store: self, sink: sink)
        } catch {
            sink.setText(sink.text.isEmpty ? "ごめんね、うまく考えられなかったにゃ。もう一度言い方を変えてみてね。" : sink.text)
        }
        if sink.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sink.setText(sink.hasCards ? "こんな感じでどうかにゃ？" : "うまく読み取れなかったにゃ。日付や相手を入れてもう一度教えてね。")
        }
        updateChatMessage(reply.id) { $0.isStreaming = false }
    }

    func resetChat() {
        chatMessages = []
        chatAgent = nil
    }

    func currentChatAgent() -> any MiraChatAgent {
        if let chatAgent { return chatAgent }
        let agent = MiraChatAgentFactory.make()
        chatAgent = agent
        return agent
    }

    func updateChatMessage(_ id: UUID, _ change: (inout ChatMessage) -> Void) {
        guard let index = chatMessages.firstIndex(where: { $0.id == id }) else { return }
        change(&chatMessages[index])
    }

    // MARK: - Cards

    @discardableResult
    func applyChatCard(messageID: UUID, cardID: UUID) -> Bool {
        guard let message = chatMessages.first(where: { $0.id == messageID }),
              let card = message.cards.first(where: { $0.id == cardID }) else { return false }
        switch card {
        case .eventProposal(var proposal):
            guard proposal.state == .pending else { return false }
            // Re-check against the calendar as it is now, not as it was when proposed.
            let impact = previewImpact(for: proposal.event)
            let saved = commitAdvisedEvent(proposal.event, impact: impact, resolution: .exception)
            guard saved else { return false }
            proposal.state = .applied
            replaceChatCard(messageID: messageID, with: .eventProposal(proposal))
            return true
        case .moveProposal(var proposal):
            guard proposal.state == .pending else { return false }
            do {
                guard let entity = try entity(id: proposal.preview.itemID),
                      entity.snapshot == proposal.preview.before else {
                    toast = "予定が変わったので、もう一度お願いしてね"
                    return false
                }
                var preview = proposal.preview
                preview.impact = previewImpact(for: preview.after, excludingItemID: preview.itemID)
                try commitChange(preview, to: entity, undoTitle: "予定の移動")
                proposal.state = .applied
                replaceChatCard(messageID: messageID, with: .moveProposal(proposal))
                toast = "\(preview.title)を動かしたにゃ"
                return true
            } catch {
                context.rollback()
                toast = "移動できませんでした"
                return false
            }
        default:
            return false
        }
    }

    func dismissChatCard(messageID: UUID, cardID: UUID) {
        guard let message = chatMessages.first(where: { $0.id == messageID }),
              let card = message.cards.first(where: { $0.id == cardID }) else { return }
        switch card {
        case .eventProposal(var proposal):
            proposal.state = .dismissed
            replaceChatCard(messageID: messageID, with: .eventProposal(proposal))
        case .moveProposal(var proposal):
            proposal.state = .dismissed
            replaceChatCard(messageID: messageID, with: .moveProposal(proposal))
        default:
            break
        }
    }

    private func replaceChatCard(messageID: UUID, with card: ChatCard) {
        updateChatMessage(messageID) { message in
            guard let index = message.cards.firstIndex(where: { $0.id == card.id }) else { return }
            message.cards[index] = card
        }
    }

    // MARK: - Tools (read or propose only; never mutate)

    func toolListSchedule(from start: Date, to end: Date) -> MiraToolResult {
        let range = DateInterval(start: start, end: max(end, start))
        let found = items
            .filter { range.intersects(DateInterval(start: $0.startDate, end: max($0.endDate, $0.startDate))) }
            .sorted { $0.startDate < $1.startDate }
        let label = rangeLabel(start, end)
        let lines = found.prefix(24).map { item in
            let kind = item.kind == .margin ? "余白" : (item.kind == .birthday ? "誕生日" : "予定")
            return "- \(item.startDate.japaneseShortDate) \(item.timeDescription) [\(kind)] \(item.title)"
        }
        let summary = found.isEmpty
            ? "\(label)：予定も余白もありません。"
            : "\(label)：\(found.count)件\n" + lines.joined(separator: "\n")
        return MiraToolResult(
            summary: summary,
            activity: ChatActivity(symbol: "calendar", text: "\(label)の予定を確認"),
            card: found.isEmpty ? nil : .schedule(ChatScheduleSummary(title: label, items: Array(found.prefix(12))))
        )
    }

    func toolFindOpenSlots(
        purpose: String,
        from start: Date,
        to end: Date,
        duration: DurationBucket,
        bands: [SchedulingTimeBand]
    ) -> MiraToolResult {
        let held = adjustments
            .filter { $0.status == .draft || $0.status == .waiting }
            .flatMap(\.candidates)
        let range = DateInterval(start: start, end: max(end, start.addingTimeInterval(3600)))
        let candidates = schedulingRecommendationEngine.recommendations(
            title: purpose,
            dateRange: range,
            duration: duration,
            timeBands: bands,
            items: items,
            heldCandidates: held,
            baseRules: fetchBaseRules(),
            notBefore: now
        )
        let clean = candidates
            .filter { $0.conflicts.isEmpty }
            .sorted { $0.score > $1.score }
            .prefix(5)
        let slots = clean.map { candidate in
            let interval = candidate.timeBand.representativeInterval(on: candidate.day, duration: candidate.durationBucket, calendar: .mira)
            return ChatOpenSlot(start: interval.start, end: interval.end, band: candidate.timeBand, note: candidate.reasons.first)
        }
        let label = rangeLabel(start, end)
        let summary = slots.isEmpty
            ? "\(label)に、余白や基本時間とぶつからない候補は見つかりませんでした。"
            : "\(label)の候補（余白・基本時間とぶつからない順）：\n" + slots.map {
                "- \($0.start.japaneseShortDate) \($0.band.title) \(timeText($0.start))–\(timeText($0.end))"
            }.joined(separator: "\n")
        return MiraToolResult(
            summary: summary,
            activity: ChatActivity(symbol: "sparkle.magnifyingglass", text: "\(label)の空きを探索"),
            card: slots.isEmpty ? nil : .openSlots(ChatOpenSlots(purpose: purpose, slots: Array(slots)))
        )
    }

    func toolProposeEvent(title: String, start: Date, end: Date, isAllDay: Bool) async -> MiraToolResult {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeEnd = end > start ? end : start.addingTimeInterval(2 * 3600)
        var event = await prepareEvent(title: cleanTitle.isEmpty ? "予定" : cleanTitle, startDate: start, endDate: safeEnd, isAllDay: isAllDay, isImportant: false)
        event.colorTag = suggestedColor(forTitle: event.title)
        let impact = previewImpact(for: event)
        let conflicts = eventEntryConflicts(for: event)
        let proposal = ChatEventProposal(event: event, impact: impact, conflicts: conflicts)
        var notes = conflicts
        if !impact.overlappingMargins.isEmpty {
            notes.append("余白「\(impact.overlappingMargins.map(\.title).joined(separator: "、"))」と重なります")
        }
        let summary = "提案カードを作成：\(event.title) \(event.startDate.japaneseShortDate) \(event.timeDescription)。負荷：\(event.loadClass.title)。"
            + (notes.isEmpty ? "問題なし。" : "注意：" + notes.joined(separator: "／"))
            + " まだ保存していません。本人がカードで決めます。"
        return MiraToolResult(
            summary: summary,
            activity: ChatActivity(symbol: "calendar.badge.plus", text: "「\(event.title)」の影響をチェック"),
            card: .eventProposal(proposal)
        )
    }

    func toolProposeMove(titleQuery: String, to newDay: Date) -> MiraToolResult {
        let query = titleQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = items
            .filter { $0.kind == .confirmed && $0.deviceEvent == nil && $0.endDate > now }
            .filter { query.isEmpty ? false : ($0.title.contains(query) || query.contains($0.title)) }
            .sorted { $0.startDate < $1.startDate }
        guard let item = matches.first else {
            return MiraToolResult(
                summary: "「\(query)」に当たる今後の予定が見つかりませんでした。",
                activity: ChatActivity(symbol: "magnifyingglass", text: "「\(query)」を検索"),
                card: nil
            )
        }
        let time = Calendar.mira.dateComponents([.hour, .minute], from: item.startDate)
        let newStart = newDay.setting(hour: time.hour ?? 9, minute: time.minute ?? 0)
        var after = item
        after.startDate = newStart
        after.endDate = newStart.addingTimeInterval(item.endDate.timeIntervalSince(item.startDate))
        let impact = previewImpact(for: after, excludingItemID: item.id)
        let conflicts = eventEntryConflicts(for: after, excludingItemID: item.id)
        let preview = ChangePreview(caseID: item.conversationCaseID, itemID: item.id, title: item.title,
            before: item, after: after, conflicts: conflicts, impact: impact)
        let summary = "移動案：\(item.title) \(item.startDate.japaneseShortDate) → \(newStart.japaneseShortDate)。"
            + (conflicts.isEmpty && impact.overlappingMargins.isEmpty ? "問題なし。" : "注意：" + (conflicts + impact.overlappingMargins.map { "余白「\($0.title)」と重なる" }).joined(separator: "／"))
            + " まだ動かしていません。"
        return MiraToolResult(
            summary: summary,
            activity: ChatActivity(symbol: "arrow.left.arrow.right", text: "「\(item.title)」の移動先をチェック"),
            card: .moveProposal(ChatMoveProposal(preview: preview))
        )
    }

    func toolMonthBalance(month: Date) -> MiraToolResult {
        let key = MonthKey(date: month)
        let monthGoals = goals.filter { $0.year == key.year && $0.month == key.month }
            .sorted { $0.priority > $1.priority }
        let lines = monthGoals.map { goal -> ChatBalanceLine in
            let value = progress(for: goal)
            return ChatBalanceLine(kind: goal.kind, current: value.current, target: value.target)
        }
        let busy = items.filter { $0.kind == .confirmed && key.interval.contains($0.startDate) }
        let heavy = busy.filter { $0.loadClass >= .heavy }.count
        let summary = "\(month.japaneseMonthTitle)：予定\(busy.count)件（重め\(heavy)件）。"
            + lines.map { "\($0.kind.title) \($0.current)/\($0.target)" }.joined(separator: "、")
        return MiraToolResult(
            summary: summary,
            activity: ChatActivity(symbol: "leaf", text: "\(month.japaneseMonthTitle)の余白バランスを確認"),
            card: lines.isEmpty ? nil : .balance(ChatBalanceSummary(month: month, lines: lines))
        )
    }

    func toolDraftMessage(purpose: String, text: String) -> MiraToolResult {
        MiraToolResult(
            summary: "メッセージ案をカードにしました（コピーして使えます）。",
            activity: ChatActivity(symbol: "text.bubble", text: "\(purpose)の文面を作成"),
            card: .message(ChatMessageDraft(purpose: purpose, text: text))
        )
    }

    func declineDraftText(title: String, person: String?, audience: DeclineAudience) async -> String {
        await declineGenerator.generate(title: title, person: person, previous: nil, softer: false,
            audience: audience, generationIndex: 0).text
    }

    // MARK: - Helpers

    func rangeLabel(_ start: Date, _ end: Date) -> String {
        let calendar = Calendar.mira
        let lastDay = end > start ? end.addingTimeInterval(-1) : start
        if calendar.isDate(start, inSameDayAs: lastDay) { return start.japaneseShortDate }
        return "\(start.japaneseShortDate)〜\(lastDay.japaneseShortDate)"
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle.mira.hour().minute())
    }
}

/// Streams one assistant turn into the chat as it is produced.
@MainActor
final class ChatTurnSink {
    private unowned let store: MiraStore
    let messageID: UUID
    private(set) var text = ""
    private(set) var hasCards = false

    init(store: MiraStore, messageID: UUID) {
        self.store = store
        self.messageID = messageID
    }

    func setText(_ value: String) {
        text = value
        store.updateChatMessage(messageID) { $0.text = value }
    }

    func record(_ result: MiraToolResult) {
        store.updateChatMessage(messageID) { message in
            message.activities.append(result.activity)
            if let card = result.card { message.cards.append(card) }
        }
        if result.card != nil { hasCards = true }
    }
}
