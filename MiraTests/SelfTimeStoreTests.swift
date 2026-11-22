import Foundation
import SwiftData
import XCTest
@testable import Mira

// Loop goals S1, S2, S6, S7 at the store level (docs/loop-goals.md).
@MainActor
final class SelfTimeStoreTests: XCTestCase {
    func testChatRequestReturnsChipCardWithoutTouchingTheCalendar() async throws {
        let store = try makeStore()
        let before = store.items
        await store.sendChat("来週は自分の時間を増やしたい")
        let reply = try XCTUnwrap(store.chatMessages.last)
        let proposal = try XCTUnwrap(selfTimeCard(in: reply))
        XCTAssertEqual(proposal.state, .pending)
        XCTAssertFalse(proposal.suggestion.margins.isEmpty)
        XCTAssertFalse(proposal.suggestion.reason.isEmpty)
        XCTAssertEqual(store.items, before)
        XCTAssertEqual(store.selfTimeLog.suggestions.first?.id, proposal.suggestion.id)
    }

    func testOtherChatRequestsKeepTheirExistingBehaviour() async throws {
        let store = try makeStore()
        store.chatAgent = RuleBasedChatAgent()
        await store.sendChat("土曜の飲み会の誘いを断りたい")
        let reply = try XCTUnwrap(store.chatMessages.last)
        XCTAssertNil(selfTimeCard(in: reply))
        XCTAssertTrue(reply.cards.contains { if case .message = $0 { return true } else { return false } })
    }

    func testApplyingPlacesOnlyChosenMarginsAndLeavesOtherPlansAlone() async throws {
        let store = try makeStore()
        let dinner = TestFixtures.event(title: "友達とご飯", day: 9, hour: 19)
        store.context.insert(CalendarItemEntity(snapshot: dinner))
        try store.context.save()
        try store.refresh()
        let othersBefore = store.items.filter { $0.kind != .margin }

        await store.sendChat("来週は自分の時間を増やしたい")
        let message = try XCTUnwrap(store.chatMessages.last)
        var proposal = try XCTUnwrap(selfTimeCard(in: message))
        XCTAssertGreaterThanOrEqual(proposal.suggestion.margins.count, 2)

        // Switch one chip off before applying.
        let skipped = proposal.suggestion.margins[0]
        store.toggleSelfTimeSlot(messageID: message.id, proposal: proposal, marginID: skipped.id)
        proposal = try XCTUnwrap(selfTimeCard(in: try XCTUnwrap(store.chatMessages.last)))
        XCTAssertEqual(proposal.excludedMarginIDs, [skipped.id])

        XCTAssertTrue(store.applyChatCard(messageID: message.id, cardID: proposal.id))
        XCTAssertEqual(store.items.filter { $0.kind != .margin }, othersBefore)
        XCTAssertFalse(store.items.contains { $0.id == skipped.id })
        let applied = try XCTUnwrap(selfTimeCard(in: try XCTUnwrap(store.chatMessages.last)))
        XCTAssertEqual(applied.state, .applied)
        XCTAssertTrue(applied.appliedMarginIDs.allSatisfy { id in store.items.contains { $0.id == id && $0.kind == .margin } })
        XCTAssertNotNil(store.undoEntry)
        XCTAssertEqual(store.selfTimeLog.suggestions.first?.status, .applied)

        // A card applies once, and its own undo removes exactly what it placed.
        XCTAssertFalse(store.applyChatCard(messageID: message.id, cardID: proposal.id))
        store.undoSelfTimeCard(messageID: message.id, proposal: applied)
        XCTAssertTrue(applied.appliedMarginIDs.allSatisfy { id in !store.items.contains { $0.id == id } })
        XCTAssertEqual(store.items.filter { $0.kind != .margin }, othersBefore)
        XCTAssertEqual(selfTimeCard(in: try XCTUnwrap(store.chatMessages.last))?.state, .undone)
    }

    func testSlotTakenAfterTheSuggestionIsNotPlaced() async throws {
        let store = try makeStore()
        await store.sendChat("来週は自分の時間を増やしたい")
        let message = try XCTUnwrap(store.chatMessages.last)
        let proposal = try XCTUnwrap(selfTimeCard(in: message))
        let first = proposal.suggestion.margins[0]
        var clash = TestFixtures.event(title: "急な打ち合わせ", day: 1)
        clash = CalendarItemSnapshot(
            id: UUID(), title: "急な打ち合わせ", startDate: first.startDate, endDate: first.endDate, isAllDay: false,
            kind: .confirmed, marginKind: nil, loadClass: .normal, loadReason: "test",
            bufferBeforeMinutes: 0, bufferAfterMinutes: 0, isImportantTime: false, sourceID: nil
        )
        store.context.insert(CalendarItemEntity(snapshot: clash))
        try store.context.save()
        try store.refresh()

        XCTAssertTrue(store.applyChatCard(messageID: message.id, cardID: proposal.id))
        XCTAssertFalse(store.items.contains { $0.id == first.id })
    }

    func testProactiveSuggestionArrivesInTheChatOncePerWeek() async throws {
        let store = try makeStore()
        store.onboardingCompleted = true
        store.context.insert(MarginGoalEntity(snapshot: TestFixtures.goal(.rest, count: 4)))
        try store.context.save()
        try store.refresh()
        let before = store.items

        await store.refreshProactiveSelfTimeSuggestion()
        let message = try XCTUnwrap(store.chatMessages.last)
        XCTAssertEqual(message.isProactive, true)
        XCTAssertEqual(selfTimeCard(in: message)?.suggestion.origin, .proactive)
        XCTAssertTrue(store.hasUnreadMiraSuggestion)
        XCTAssertEqual(store.currentAssistantMessage.actionTitle, "提案を見る")
        XCTAssertEqual(store.items, before)

        // Dismissed or not, the same week is not suggested again.
        let card = try XCTUnwrap(selfTimeCard(in: message))
        store.dismissChatCard(messageID: message.id, cardID: card.id)
        XCTAssertEqual(store.selfTimeLog.suggestions.first?.status, .dismissed)
        let count = store.chatMessages.count
        await store.refreshProactiveSelfTimeSuggestion()
        XCTAssertEqual(store.chatMessages.count, count)

        store.markMiraSuggestionsRead()
        XCTAssertFalse(store.hasUnreadMiraSuggestion)
    }

    func testNoProactiveSuggestionBeforeOnboarding() async throws {
        let store = try makeStore()
        store.context.insert(MarginGoalEntity(snapshot: TestFixtures.goal(.rest, count: 4)))
        try store.context.save()
        try store.refresh()
        await store.refreshProactiveSelfTimeSuggestion()
        XCTAssertTrue(store.chatMessages.isEmpty)
    }

    func testTrendToggleTurnsTrendOff() throws {
        let store = try makeStore()
        store.selfTimeLog.suggestions = (0..<3).map { index in
            let start = TestFixtures.date(day: 4 + index * 7, hour: 19)
            var suggestion = Suggestion(
                origin: .request, title: "t", reason: "r", weekStart: WeekKey(containing: start).start,
                margins: [SuggestedMargin(kind: .rest, startDate: start, endDate: start.addingTimeInterval(3 * 3600))],
                usesTrend: false, createdAt: start
            )
            suggestion.status = .applied
            return suggestion
        }
        store.selfTimeLogLoaded = true
        XCTAssertNotNil(store.currentTrend)
        store.setTrendSuggestionsEnabled(false)
        XCTAssertNil(store.currentTrend)
    }

    func testSatisfactionIsKeptPerWeek() throws {
        let store = try makeStore()
        store.setSatisfaction(.low, for: store.currentWeek)
        XCTAssertEqual(store.weeklyReview(for: store.currentWeek).satisfaction, .low)
        store.setSatisfaction(.good, for: store.currentWeek)
        XCTAssertEqual(store.weeklyReview(for: store.currentWeek).satisfaction, .good)
        XCTAssertNil(store.weeklyReview(for: store.currentWeek.adding(weeks: 1)).satisfaction)
    }

    func testShareTextUsesOnlyFreeBands() throws {
        let store = try makeStore()
        let secret = TestFixtures.event(title: "転職面談", day: 2, hour: 19)
        store.context.insert(CalendarItemEntity(snapshot: secret))
        try store.context.save()
        try store.refresh()
        let text = store.friendAvailabilityText()
        XCTAssertFalse(text.contains("転職面談"))
        XCTAssertTrue(text.contains("空いている時間帯"))
    }

    private func selfTimeCard(in message: ChatMessage) -> ChatSelfTimeProposal? {
        for card in message.cards {
            if case .selfTime(let proposal) = card { return proposal }
        }
        return nil
    }

    private func makeStore() throws -> MiraStore {
        let schema = Schema([
            AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        let container = try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let store = MiraStore(container: container, classifier: RuleBasedSemanticClassifier(),
            conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
        store.chatMessages = []
        store.chatHistoryRestored = true
        return store
    }
}
