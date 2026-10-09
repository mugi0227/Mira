import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class EventColorTests: XCTestCase {
    func testColorSurvivesPersistenceRoundTrip() throws {
        var event = TestFixtures.event(title: "友達とご飯", day: 12)
        event.colorTag = .play
        let entity = CalendarItemEntity(snapshot: event)
        XCTAssertEqual(entity.snapshot.colorTag, .play)

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

        store.setColor(itemID: event.id, to: .otaku)
        XCTAssertEqual(store.items.first { $0.id == event.id }?.colorTag, .otaku)
        XCTAssertNotNil(store.undoEntry)

        await store.undoLastCalendarMutation()
        XCTAssertNil(store.items.first { $0.id == event.id }?.colorTag)
    }

    func testSuggestedColorPrefersExactTitleThenSimilarTitle() throws {
        let store = try makeStore()
        var dinner = TestFixtures.event(title: "友達とご飯", day: 3)
        dinner.colorTag = .play
        var work = TestFixtures.event(title: "会社の飲み会", day: 5)
        work.colorTag = .work
        for item in [dinner, work] { store.context.insert(CalendarItemEntity(snapshot: item)) }
        try store.context.save()
        try store.refresh()

        XCTAssertEqual(store.suggestedColor(forTitle: "友達とご飯"), .play)
        XCTAssertEqual(store.suggestedColor(forTitle: "飲み会"), .work)
        XCTAssertEqual(store.suggestedColor(forTitle: "歯医者"), .care, "falls back to Mira's word rules")
        XCTAssertNil(store.suggestedColor(forTitle: "ぼんやり"))
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

    func testWordRulesFollowMirasColorCode() {
        XCTAssertEqual(EventColorTag.suggested(forTitle: "有馬記念"), .keiba)
        XCTAssertEqual(EventColorTag.suggested(forTitle: "年末ジャンボ宝くじ発売"), .lottery)
        XCTAssertEqual(EventColorTag.suggested(forTitle: "レポート提出"), .deadline)
        XCTAssertEqual(EventColorTag.suggested(forTitle: "ゆいちゃん誕生日"), .birthday)
        XCTAssertEqual(EventColorTag.suggested(forTitle: "推しのライブ"), .otaku)
        XCTAssertEqual(EventColorTag.suggested(forTitle: "シフト"), .work)
        XCTAssertEqual(EventColorTag.suggested(forTitle: "皮膚科"), .care)
        XCTAssertEqual(EventColorTag.suggested(forTitle: "友達と焼肉"), .play)
        XCTAssertNil(EventColorTag.suggested(forTitle: "なにか"))
    }
}
