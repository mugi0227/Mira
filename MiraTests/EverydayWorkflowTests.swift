import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class EverydayWorkflowTests: XCTestCase {
    func testApprovedOverlapUndoRestoresMarginAndUnconfirmsTheWholeCase() async throws {
        let store = try makeStore()
        let margin = TestFixtures.event(day: 10, hour: 9, duration: 12, kind: .margin, marginKind: .rest)
        let previousEvent = TestFixtures.event(title: "先に決まった予定", day: 10, hour: 18)
        let (session, conversationCase) = insertCase(in: store, title: "オンライン相談", status: .waiting)
        store.context.insert(CalendarItemEntity(snapshot: margin))
        store.context.insert(CalendarItemEntity(snapshot: previousEvent))
        store.context.insert(MarginGoalEntity(snapshot: TestFixtures.goal(.rest, count: 1)))
        try store.context.save()
        try store.refresh()
        let previousItems = Set(store.items)
        let previousCandidates = session.candidates
        let previousState = conversationCase.state
        let candidate = try XCTUnwrap(session.candidates.first)
        let prepared = await store.prepareCandidateConfirmation(sessionID: session.id, candidateID: candidate.id)
        let approval = try XCTUnwrap(prepared)
        XCTAssertTrue(approval.conflicts.contains("確定予定と重なっています"))
        XCTAssertEqual(approval.impact.protectionLevel, .finalDefense)

        let confirmed = await store.confirmCandidate(sessionID: session.id, candidateID: candidate.id, approval: approval)
        XCTAssertTrue(confirmed)
        XCTAssertFalse(store.items.contains { $0.id == margin.id })
        XCTAssertTrue(store.items.contains { $0.id == previousEvent.id })
        XCTAssertEqual(session.status, .confirmed)
        XCTAssertEqual(conversationCase.kind, .confirmedEvent)
        XCTAssertEqual(conversationCase.state.relatedItemID, approval.event.id)
        XCTAssertEqual(session.candidates.filter { $0.status == .released }.count, 1)
        XCTAssertNotNil(store.undoEntry)

        await store.undoLastCalendarMutation()

        XCTAssertEqual(Set(store.items), previousItems)
        XCTAssertFalse(store.items.contains { $0.id == approval.event.id })
        XCTAssertEqual(session.status, .waiting)
        XCTAssertEqual(session.candidates, previousCandidates)
        XCTAssertEqual(conversationCase.kind, .adjustment)
        XCTAssertEqual(conversationCase.status, .waiting)
        XCTAssertEqual(conversationCase.state, previousState)
        XCTAssertNil(store.undoEntry)
    }

    func testUndoDoesNotRewindAnotherCasesInterveningSentState() async throws {
        let store = try makeStore()
        let (otherSession, otherCase) = insertCase(in: store, title: "別件のランチ", status: .draft)
        try store.context.save()
        try store.refresh()
        let event = TestFixtures.event(title: "新しく追加した予定", day: 16, hour: 18)
        XCTAssertTrue(store.commitAdvisedEvent(event, impact: .none, resolution: .exception))
        XCTAssertNotNil(store.undoEntry)
        let sent = await store.markAdjustmentSent(otherSession)
        XCTAssertTrue(sent)
        XCTAssertEqual(otherSession.status, .waiting)
        XCTAssertEqual(otherCase.status, .waiting)
        let sentTurns = otherCase.turns

        await store.undoLastCalendarMutation()

        XCTAssertTrue(store.items.contains { $0.id == event.id }, "Reject the stale Undo instead of partially restoring an older workflow")
        XCTAssertEqual(otherSession.status, .waiting)
        XCTAssertEqual(otherCase.status, .waiting)
        XCTAssertEqual(otherCase.turns, sentTurns)
        XCTAssertNil(store.undoEntry)
        XCTAssertNil(store.persistenceIssue)
    }

    func testNewNormalBootstrapUsesRealClockWithoutSeedingDemoEvents() async throws {
        try XCTSkipIf(ProcessInfo.processInfo.arguments.contains("-reset-demo"), "This test covers a normal launch, not an explicit demo-reset launch")
        let store = try makeStore()
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<AppSettingsEntity>()).isEmpty)
        // Prevent a previous Simulator run's optional calendar connection from importing
        // real events. Restore the exact prior preference after this isolated bootstrap.
        let preferenceKey = "mira.calendar.enabled"
        let previousPreference = UserDefaults.standard.object(forKey: preferenceKey)
        store.deviceCalendarService.enabled = false
        defer {
            if let previousPreference { UserDefaults.standard.set(previousPreference, forKey: preferenceKey) }
            else { UserDefaults.standard.removeObject(forKey: preferenceKey) }
        }
        let before = Date()

        await store.bootstrap()

        XCTAssertTrue(store.isReady)
        XCTAssertFalse(store.demoModeEnabled)
        XCTAssertEqual(store.settingsEntity?.demoModeEnabled, false)
        XCTAssertTrue(store.clock is SystemClock)
        XCTAssertGreaterThanOrEqual(store.selectedDate, before)
        XCTAssertLessThanOrEqual(store.selectedDate, Date())
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.adjustments.isEmpty)
        XCTAssertTrue(store.pendingInvitations.isEmpty)
        XCTAssertTrue(store.conversationCases.isEmpty)
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<CalendarItemEntity>()).isEmpty)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<AppSettingsEntity>()).count, 1)
    }

    private func insertCase(in store: MiraStore, title: String, status: AdjustmentStatus) -> (AdjustmentEntity, ConversationCaseEntity) {
        let caseID = UUID()
        let candidates = [10, 12].map {
            CandidateSlotSnapshot(startDate: TestFixtures.date(day: $0, hour: 18), endDate: TestFixtures.date(day: $0, hour: 20), timeOfDay: .evening)
        }
        let session = AdjustmentEntity(title: title, status: status, candidates: candidates,
            generatedMessage: "候補日の相談です", conversationCaseID: caseID)
        let state = ConversationCaseState(
            relatedAdjustmentID: session.id, dateRangeStart: candidates.first?.startDate,
            dateRangeEnd: candidates.last?.endDate, durationBucket: .short,
            allowedTimeBands: [.evening], candidates: candidates, lastIntent: .findDates
        )
        let conversationCase = ConversationCaseEntity(id: caseID, title: title, kind: .adjustment,
            status: status == .waiting ? .waiting : .active, state: state)
        store.context.insert(session)
        store.context.insert(conversationCase)
        return (session, conversationCase)
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
