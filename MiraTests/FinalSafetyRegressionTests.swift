import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class FinalSafetyRegressionTests: XCTestCase {
    func testUndoAlsoRemovesTheRuleLearnedByLoadCorrection() async throws {
        let store = try makeStore()
        let event = TestFixtures.event(title: "オンライン相談", day: 10)
        let existingRule = LoadRuleEntity(keyword: "旅行", loadClass: .heavy)
        store.context.insert(CalendarItemEntity(snapshot: event))
        store.context.insert(existingRule)
        try store.context.save()
        try store.refresh()

        store.correctLoad(itemID: event.id, to: .light, rememberKeyword: true)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<LoadRuleEntity>()).count, 2)
        await store.undoLastCalendarMutation()

        XCTAssertEqual(store.items, [event])
        let remaining = try store.context.fetch(FetchDescriptor<LoadRuleEntity>())
        XCTAssertEqual(remaining.map(\.id), [existingRule.id])
        XCTAssertEqual(remaining.first?.keyword, "旅行")
    }

    func testUndoDoesNotEraseAnInterveningLearnedRule() async throws {
        let store = try makeStore()
        let event = TestFixtures.event(day: 10)
        XCTAssertTrue(store.commitAdvisedEvent(event, impact: .none, resolution: .exception))
        store.context.insert(LoadRuleEntity(keyword: "あとから学習", loadClass: .heavy))
        try store.context.save()

        await store.undoLastCalendarMutation()

        XCTAssertTrue(store.items.contains { $0.id == event.id })
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<LoadRuleEntity>()).count, 1)
        XCTAssertNil(store.undoEntry)
    }

    func testRelocationWithoutAReviewedDestinationDoesNotSave() throws {
        let store = try makeStore()
        let event = TestFixtures.event(day: 10)
        XCTAssertFalse(store.commitAdvisedEvent(event, impact: .none, resolution: .relocate))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(store.undoEntry)
    }

    func testMultipleMarginsCannotBeMovedToOneSlotButMayBeConsumedAfterApproval() throws {
        let store = try makeStore()
        let first = TestFixtures.event(day: 10, hour: 9, duration: 3, kind: .margin, marginKind: .rest)
        let second = TestFixtures.event(day: 10, hour: 18, duration: 3, kind: .margin, marginKind: .rest)
        let event = TestFixtures.event(title: "終日の予定", day: 10, hour: 9, duration: 12)
        store.context.insert(CalendarItemEntity(snapshot: first))
        store.context.insert(CalendarItemEntity(snapshot: second))
        store.context.insert(MarginGoalEntity(snapshot: TestFixtures.goal(.rest, count: 2)))
        try store.context.save()
        try store.refresh()
        let impact = store.previewImpact(for: event)

        XCTAssertEqual(impact.overlappingMargins.count, 2)
        XCTAssertTrue(impact.relocationCandidates.isEmpty)
        XCTAssertEqual(impact.protectionLevel, .finalDefense)
        XCTAssertEqual(impact.projectedGoalDeficits[.rest], 2)
        XCTAssertFalse(store.commitAdvisedEvent(event, impact: impact, resolution: .relocate,
            chosenRelocationDate: TestFixtures.date(day: 16)))
        XCTAssertEqual(Set(store.items), Set([first, second]))
        XCTAssertTrue(store.commitAdvisedEvent(event, impact: impact, resolution: .exception))
        XCTAssertEqual(store.items, [event])
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
        return MiraStore(container: container, classifier: RuleBasedSemanticClassifier())
    }
}
