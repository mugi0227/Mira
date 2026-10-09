import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class MiraChatTests: XCTestCase {
    func testProposalDoesNotTouchTheCalendarUntilApproved() async throws {
        let store = try makeStore()
        let before = store.items
        let start = TestFixtures.date(day: 15, hour: 19)
        let result = await store.toolProposeEvent(title: "友達とご飯", start: start, end: start.addingTimeInterval(7200), isAllDay: false)
        XCTAssertEqual(store.items, before)

        let message = ChatMessage(role: .assistant, text: "案", cards: [try XCTUnwrap(result.card)])
        store.chatMessages = [message]
        XCTAssertTrue(store.applyChatCard(messageID: message.id, cardID: message.cards[0].id))
        XCTAssertTrue(store.items.contains { $0.title == "友達とご飯" })
        XCTAssertNotNil(store.undoEntry)

        // A card can only be applied once.
        XCTAssertFalse(store.applyChatCard(messageID: message.id, cardID: message.cards[0].id))
        XCTAssertEqual(store.items.filter { $0.title == "友達とご飯" }.count, 1)
    }

    func testOpenSlotsAvoidProtectedMargins() throws {
        let store = try makeStore()
        let margin = TestFixtures.event(day: 15, hour: 9, duration: 14, kind: .margin, marginKind: .rest)
        store.context.insert(CalendarItemEntity(snapshot: margin))
        try store.context.save()
        try store.refresh()

        let result = store.toolFindOpenSlots(
            purpose: "ご飯",
            from: TestFixtures.date(day: 14, hour: 0),
            to: TestFixtures.date(day: 17, hour: 0),
            duration: .short,
            bands: [.evening]
        )
        guard case .openSlots(let slots) = result.card else { return XCTFail("expected slots") }
        XCTAssertFalse(slots.slots.isEmpty)
        XCTAssertFalse(slots.slots.contains { Calendar.mira.isDate($0.start, inSameDayAs: margin.startDate) })
    }

    func testMoveProposalLeavesTheEventInPlace() throws {
        let store = try makeStore()
        let event = TestFixtures.event(title: "会社の飲み会", day: 18, hour: 19)
        store.context.insert(CalendarItemEntity(snapshot: event))
        try store.context.save()
        try store.refresh()

        let result = store.toolProposeMove(titleQuery: "飲み会", to: TestFixtures.date(day: 19, hour: 0))
        guard case .moveProposal(let proposal) = result.card else { return XCTFail("expected move") }
        XCTAssertEqual(proposal.preview.itemID, event.id)
        XCTAssertEqual(store.items.first { $0.id == event.id }?.startDate, event.startDate)
    }

    func testRuleBasedAgentWritesADeclineDraft() async throws {
        let store = try makeStore()
        store.chatAgent = RuleBasedChatAgent()
        await store.sendChat("土曜の飲み会の誘いを断りたい")
        let reply = try XCTUnwrap(store.chatMessages.last)
        XCTAssertEqual(reply.role, .assistant)
        XCTAssertFalse(reply.isStreaming)
        XCTAssertFalse(reply.text.isEmpty)
        XCTAssertTrue(reply.cards.contains { if case .message = $0 { return true } else { return false } })
    }

    func testRuleBasedAgentAnswersBalanceQuestions() async throws {
        let store = try makeStore()
        store.context.insert(MarginGoalEntity(snapshot: TestFixtures.goal(.rest, count: 4)))
        try store.context.save()
        try store.refresh()
        store.chatAgent = RuleBasedChatAgent()
        await store.sendChat("今月ちゃんと休めてる？")
        let reply = try XCTUnwrap(store.chatMessages.last)
        XCTAssertTrue(reply.cards.contains { if case .balance = $0 { return true } else { return false } })
        XCTAssertFalse(reply.activities.isEmpty)
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
        return MiraStore(container: container, classifier: RuleBasedSemanticClassifier(),
            conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
    }
}

final class ChatTitleTests: XCTestCase {
    func testRequestPhrasesAreStrippedFromPlanTitles() {
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "、友達とご飯に行ける日を探して"), "友達とご飯")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "来週友達と焼肉行きたい"), "友達と焼肉")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "カフェを予定に追加して"), "カフェ")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "探して"), "探して")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: ""), "予定")
    }
}
