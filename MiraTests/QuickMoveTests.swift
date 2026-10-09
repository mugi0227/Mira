import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class QuickMoveTests: XCTestCase {
    func testDragToFreeDayMovesImmediatelyAndCanBeUndone() async throws {
        let store = try makeStore()
        let event = TestFixtures.event(title: "映画", day: 10, hour: 18)
        store.context.insert(CalendarItemEntity(snapshot: event))
        try store.context.save()
        try store.refresh()

        store.moveItem(id: event.id, to: TestFixtures.date(day: 11, hour: 0))

        XCTAssertNil(store.pendingChangePreview)
        let moved = try XCTUnwrap(store.items.first { $0.id == event.id })
        XCTAssertTrue(Calendar.mira.isDate(moved.startDate, inSameDayAs: TestFixtures.date(day: 11, hour: 0)))
        XCTAssertEqual(Calendar.mira.component(.hour, from: moved.startDate), 18)
        XCTAssertNotNil(store.undoEntry)

        await store.undoLastCalendarMutation()
        XCTAssertEqual(store.items.first { $0.id == event.id }?.startDate, event.startDate)
    }

    func testDragOntoMarginStillAsksFirst() throws {
        let store = try makeStore()
        let event = TestFixtures.event(title: "飲み会", day: 10, hour: 18)
        let margin = TestFixtures.event(day: 12, hour: 9, duration: 12, kind: .margin, marginKind: .rest)
        store.context.insert(CalendarItemEntity(snapshot: event))
        store.context.insert(CalendarItemEntity(snapshot: margin))
        try store.context.save()
        try store.refresh()

        store.moveItem(id: event.id, to: TestFixtures.date(day: 12, hour: 0))

        XCTAssertNotNil(store.pendingChangePreview)
        XCTAssertEqual(store.items.first { $0.id == event.id }?.startDate, event.startDate)
        XCTAssertTrue(store.items.contains { $0.id == margin.id })
    }

    func testDropOnSameDayDoesNothing() throws {
        let store = try makeStore()
        let event = TestFixtures.event(title: "映画", day: 10, hour: 18)
        store.context.insert(CalendarItemEntity(snapshot: event))
        try store.context.save()
        try store.refresh()

        store.moveItem(id: event.id, to: TestFixtures.date(day: 10, hour: 0))

        XCTAssertNil(store.pendingChangePreview)
        XCTAssertNil(store.undoEntry)
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

@MainActor
final class RescheduleTimeTests: XCTestCase {
    func testChangingTimeOnTheSameDaySavesWithUndo() async throws {
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
        let event = TestFixtures.event(title: "カフェ", day: 10, hour: 14, duration: 2)
        store.context.insert(CalendarItemEntity(snapshot: event))
        try store.context.save()
        try store.refresh()

        store.rescheduleItem(id: event.id, toStart: event.startDate.addingTimeInterval(45 * 60))

        let moved = try XCTUnwrap(store.items.first { $0.id == event.id })
        XCTAssertEqual(Calendar.mira.component(.minute, from: moved.startDate), 45)
        XCTAssertEqual(moved.endDate.timeIntervalSince(moved.startDate), 2 * 3600)
        XCTAssertEqual(store.undoEntry?.title, "時間の変更")
        XCTAssertNil(store.pendingChangePreview)
    }
}
