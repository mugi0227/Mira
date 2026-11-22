import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class MiraChatTests: XCTestCase {
    func testPreviouslyAddedDinnerCanProduceDeclineDraft() async throws {
        let store = try makeStore()
        store.chatAgent = RuleBasedChatAgent(interpreter: ProductionConversationInterpreter(base: RuleBasedConversationInterpreter()))
        await store.sendChat("明日の19時に追加した食事の誘いを断る文を作って")
        let reply = try XCTUnwrap(store.chatMessages.last)
        XCTAssertTrue(reply.cards.contains { if case .message = $0 { return true }; return false })
        XCTAssertFalse(reply.cards.contains { if case .eventProposal = $0 { return true }; return false })
    }
    func testExplicitAddOverridesColloquialDrinksInvitation() async throws {
        let store = try makeStore()
        store.chatAgent = FailingChatAgent()
        for ending in ["して", "してね", "してよ！", "してください。", "してほしい", "してほしいです！"] {
            await store.sendChat("明日の19時に友達と飲みに行く予定を追加\(ending)")
            guard case .eventProposal(let proposal) = store.chatMessages.last?.cards.first else { return XCTFail("expected event proposal, not slots: \(ending)") }
            XCTAssertEqual(proposal.event.startDate, store.now.addingDays(1).setting(hour: 19))
        }
    }
    func testTerseDatedEventCreatesProposal() async throws {
        let store = try makeStore()
        store.chatAgent = FailingChatAgent()
        await store.sendChat("今日の20時に読書")
        guard case .eventProposal(let proposal) = store.chatMessages.last?.cards.first else { return XCTFail("expected proposal") }
        XCTAssertEqual(proposal.event.title, "読書")
        XCTAssertEqual(proposal.event.startDate, store.now.setting(hour: 20))
    }

    func testDatedQuestionsDoNotBecomeAddRequests() async {
        let interpreter = ProductionConversationInterpreter(base: RuleBasedConversationInterpreter())
        for text in ["今日の20時の予定は？", "今日の20時に何がある", "今日の20時の予定を教えて",
                     "明日の19時は空いてますか", "明日の19時はあいてる", "明日の19時は暇ですか"] {
            let result = await interpreter.interpret(text: text, now: TestFixtures.date(day: 15),
                pinnedContext: nil, searchCandidates: [], recentTurns: [])
            XCTAssertNotEqual(result.intent, .addEvent)
        }
    }
    func testNegatedRelativeDayIsNotProposed() async throws {
        let store = try makeStore()
        for request in ["明日ではなく明後日の19時に夕食を追加して", "明日じゃなくて明後日の19時に夕食を追加して"] {
            await store.sendChat(request)
            guard case .eventProposal(let proposal) = store.chatMessages.last?.cards.first else { return XCTFail("expected proposal") }
            XCTAssertEqual(proposal.event.startDate, store.now.addingDays(2).setting(hour: 19))
        }
    }
    func testExplicitEventPreservesMinutesAndSlashDate() async throws {
        let store = try makeStore()
        store.chatAgent = FailingChatAgent()
        for (request, expected) in [
            ("明日の19時30分に夕食を追加して", store.now.addingDays(1).setting(hour: 19, minute: 30)),
            ("12/1の19時に夕食を追加して", Calendar.mira.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 19))!)
        ] {
            await store.sendChat(request)
            guard case .eventProposal(let proposal) = store.chatMessages.last?.cards.first else { return XCTFail("expected proposal") }
            XCTAssertEqual(proposal.event.startDate, expected)
        }
    }
    func testExplicitEventBypassesFailingModelAndOnlyProposes() async throws {
        let store = try makeStore()
        store.chatAgent = FailingChatAgent()
        let before = store.items
        await store.sendChat("明日の19時に友達と夕食を追加して")
        let reply = try XCTUnwrap(store.chatMessages.last)
        guard case .eventProposal(let proposal) = reply.cards.first else { return XCTFail("expected event proposal") }
        XCTAssertEqual(proposal.event.title, "友達と夕食")
        let tomorrow = Calendar.mira.startOfDay(for: store.now).addingDays(1)
        XCTAssertEqual(proposal.event.startDate, tomorrow.setting(hour: 19, minute: 0))
        XCTAssertEqual(store.items, before)
        XCTAssertFalse(reply.text.contains("うまく考えられなかった"))
    }

    func testModelFailureShowsClearErrorWithoutCards() async throws {
        let store = try makeStore()
        store.chatAgent = FailingChatAgent()
        await store.sendChat("今月ちゃんと休めてる？")
        let reply = try XCTUnwrap(store.chatMessages.last)
        XCTAssertEqual(reply.text, ChatAnswer.failure)
        XCTAssertEqual(reply.failure, .aiUnavailable)
        XCTAssertTrue(reply.cards.isEmpty)
        XCTAssertTrue(reply.activities.isEmpty)
        XCTAssertFalse(reply.isStreaming)
    }

    func testModelFailureReplacesPartialTextAndCards() async throws {
        for (text, hasCard) in [("途中の返事", false), ("", true), ("途中の返事", true)] {
            let store = try makeStore()
            store.chatAgent = FailingChatAgent(partialText: text, producesCard: hasCard)
            await store.sendChat("今月ちゃんと休めてる？")
            let reply = try XCTUnwrap(store.chatMessages.last)
            XCTAssertEqual(reply.text, ChatAnswer.failure)
            XCTAssertEqual(reply.failure, .aiUnavailable)
            XCTAssertTrue(reply.cards.isEmpty)
            XCTAssertTrue(reply.activities.isEmpty)
            XCTAssertFalse(reply.isStreaming)
        }
    }

    func testEmptyChatDoesNothing() async throws {
        let store = try makeStore()
        await store.sendChat("  ")
        XCTAssertTrue(store.chatMessages.isEmpty)
    }

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

    func testAllDayChatProposalExplicitlyOccupiesTimeAndReviewsMargins() async throws {
        let store = try makeStore()
        let margin = TestFixtures.event(title: "読書", day: 15, kind: .margin, marginKind: .reading)
        store.context.insert(CalendarItemEntity(snapshot: margin))
        try store.context.save()
        try store.refresh()
        let result = await store.toolProposeEvent(title: "会議",
            start: TestFixtures.date(day: 15, hour: 9),
            end: TestFixtures.date(day: 15, hour: 21), isAllDay: true)
        guard case .eventProposal(let proposal) = try XCTUnwrap(result.card) else {
            return XCTFail("Expected an event proposal")
        }
        XCTAssertEqual(proposal.event.occupiesTime, true)
        XCTAssertTrue(proposal.event.countsAgainstWhitespace)
        XCTAssertTrue(proposal.conflicts.contains { $0.contains("読書") })
        XCTAssertEqual(proposal.impact.overlappingMargins.map(\.id), [margin.id])
        XCTAssertEqual(store.items.map(\.id), [margin.id])
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
    func testDurationIsNotAClockTime() async {
        let base = RuleBasedConversationInterpreter()
        let now = TestFixtures.date(day: 15)
        let local = await base.interpret(text: "明日2時間映画", now: now,
            pinnedContext: nil, searchCandidates: [], recentTurns: [])
        XCTAssertNil(local.exactStartDate)
        let production = await ProductionConversationInterpreter(base: base).interpret(
            text: "明日2時間映画", now: now, pinnedContext: nil, searchCandidates: [], recentTurns: [])
        XCTAssertNil(production.exactStartDate)
        XCTAssertNotEqual(production.intent, .addEvent)
    }
    func testClockPrefixDoesNotEatDurationTitles() {
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "24時間テレビを追加して"), "24時間テレビ")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "明日の19時30分に夕食を追加して"), "夕食")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "12/1の19時に夕食を追加して"), "夕食")
    }
    func testRelativeEventTitle() {
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "明日の19時に友達と夕食を追加して"), "友達と夕食")
    }

    func testRelativeDateAndInvalidHour() async {
        let interpreter = RuleBasedConversationInterpreter()
        let now = TestFixtures.date(day: 15, hour: 10)
        for (word, offset) in [("今日", 0), ("明日", 1), ("明後日", 2)] {
            let result = await interpreter.interpret(text: "\(word)の19時に夕食を追加して", now: now,
                pinnedContext: nil, searchCandidates: [], recentTurns: [])
            XCTAssertEqual(result.exactStartDate, now.addingDays(offset).setting(hour: 19, minute: 0))
        }
        let invalid = await interpreter.interpret(text: "明日の29時に夕食を追加して", now: now,
            pinnedContext: nil, searchCandidates: [], recentTurns: [])
        XCTAssertNil(invalid.exactStartDate)
    }
    func testRequestPhrasesAreStrippedFromPlanTitles() {
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "、友達とご飯に行ける日を探して"), "友達とご飯")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "来週友達と焼肉行きたい"), "友達と焼肉")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "カフェを予定に追加して"), "カフェ")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "はなび大会"), "はなび大会")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: "探して"), "探して")
        XCTAssertEqual(RuleBasedChatAgent.planTitle(from: ""), "予定")
    }
}

@MainActor
private final class FailingChatAgent: MiraChatAgent {
    let displayName = "Failing model"
    let partialText: String
    let producesCard: Bool

    init(partialText: String = "", producesCard: Bool = false) {
        self.partialText = partialText
        self.producesCard = producesCard
    }

    func respond(to text: String, store: MiraStore, sink: ChatTurnSink) async throws {
        sink.setText(partialText)
        if producesCard {
            sink.record(store.toolDraftMessage(purpose: "お断り", text: "また今度お願いします"))
        }
        throw CocoaError(.coderInvalidValue)
    }
}

@MainActor
final class ChatHistoryTests: XCTestCase {
    override func tearDown() {
        if let url = MiraStore.chatHistoryURL { try? FileManager.default.removeItem(at: url) }
        super.tearDown()
    }

    func testChatHistoryRoundTripsWithCards() throws {
        let start = TestFixtures.date(day: 10, hour: 19)
        let proposal = ChatEventProposal(event: TestFixtures.event(title: "映画", day: 10, hour: 19), impact: .none, conflicts: [])
        let messages = [
            ChatMessage(role: .user, text: "映画いける？"),
            ChatMessage(role: .assistant, text: "よさそうです",
                activities: [ChatActivity(symbol: "calendar", text: "確認")],
                cards: [.eventProposal(proposal), .openSlots(ChatOpenSlots(purpose: "映画", slots: [
                    ChatOpenSlot(start: start, end: start.addingTimeInterval(7200), band: .evening)
                ]))])
        ]
        let data = try JSONEncoder().encode(messages)
        let decoded = try JSONDecoder().decode([ChatMessage].self, from: data)
        XCTAssertEqual(decoded, messages)
    }

    func testStoreRestoresOnlyFinishedTurns() throws {
        let schema = Schema([
            AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        let container = try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let first = MiraStore(container: container, classifier: RuleBasedSemanticClassifier(),
            conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
        first.chatMessages = [
            ChatMessage(role: .user, text: "こんにちは"),
            ChatMessage(role: .assistant, text: "途中", isStreaming: true)
        ]
        first.persistChat()

        let second = MiraStore(container: container, classifier: RuleBasedSemanticClassifier(),
            conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
        second.restoreChatIfNeeded()
        XCTAssertEqual(second.chatMessages.map(\.text), ["こんにちは"])
    }
}
