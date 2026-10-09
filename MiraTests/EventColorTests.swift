import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class EventColorTests: XCTestCase {
    func testColorSurvivesPersistenceRoundTrip() throws {
        var event = TestFixtures.event(title: "友達とご飯", day: 12)
        event.colorTag = .sakura
        let entity = CalendarItemEntity(snapshot: event)
        XCTAssertEqual(entity.snapshot.colorTag, .sakura)

        event.colorTag = nil
        entity.apply(event)
        XCTAssertNil(entity.snapshot.colorTag)
    }

    func testSetColorUpdatesItemAndCanBeUndone() async throws {
        let store = try makeStore()
        let event = TestFixtures.event(title: "映画", day: 14)
        store.context.insert(CalendarItemEntity(snapshot: event))
        try store.context.save()
        try store.refresh()

        store.setColor(itemID: event.id, to: .lavender)
        XCTAssertEqual(store.items.first { $0.id == event.id }?.colorTag, .lavender)
        XCTAssertNotNil(store.undoEntry)

        await store.undoLastCalendarMutation()
        XCTAssertNil(store.items.first { $0.id == event.id }?.colorTag)
    }

    func testSuggestedColorPrefersExactTitleThenSimilarTitle() throws {
        let store = try makeStore()
        var dinner = TestFixtures.event(title: "友達とご飯", day: 3)
        dinner.colorTag = .sakura
        var work = TestFixtures.event(title: "会社の飲み会", day: 5)
        work.colorTag = .gray
        for item in [dinner, work] { store.context.insert(CalendarItemEntity(snapshot: item)) }
        try store.context.save()
        try store.refresh()

        XCTAssertEqual(store.suggestedColor(forTitle: "友達とご飯"), .sakura)
        XCTAssertEqual(store.suggestedColor(forTitle: "飲み会"), .gray)
        XCTAssertNil(store.suggestedColor(forTitle: "歯医者"))
        XCTAssertNil(store.suggestedColor(forTitle: "友"))
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
