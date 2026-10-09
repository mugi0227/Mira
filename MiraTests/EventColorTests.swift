import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class EventColorTests: XCTestCase {
    func testColorSurvivesPersistenceRoundTrip() throws {
        var event = TestFixtures.event(title: "友達とご飯", day: 12)
        event.colorTag = .sky
        let entity = CalendarItemEntity(snapshot: event)
        XCTAssertEqual(entity.snapshot.colorTag, .sky)

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

        store.setColor(itemID: event.id, to: .skyLight)
        XCTAssertEqual(store.items.first { $0.id == event.id }?.colorTag, .skyLight)
        XCTAssertNotNil(store.undoEntry)

        await store.undoLastCalendarMutation()
        XCTAssertNil(store.items.first { $0.id == event.id }?.colorTag)
    }

    func testSuggestedColorPrefersExactTitleThenSimilarTitle() throws {
        let store = try makeStore()
        var dinner = TestFixtures.event(title: "友達とご飯", day: 3)
        dinner.colorTag = .sky
        var work = TestFixtures.event(title: "会社の飲み会", day: 5)
        work.colorTag = .redLight
        for item in [dinner, work] { store.context.insert(CalendarItemEntity(snapshot: item)) }
        try store.context.save()
        try store.refresh()

        XCTAssertEqual(store.suggestedColor(forTitle: "友達とご飯"), .sky)
        XCTAssertEqual(store.suggestedColor(forTitle: "飲み会"), .redLight)
        XCTAssertNil(store.suggestedColor(forTitle: "歯医者"), "standard profile has no word rules")
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

    func testStandardProfileOnlyLearnsFromPastPlans() throws {
        XCTAssertNil(ColorProfile.standard.suggestedColor(forTitle: "歯医者"))
        XCTAssertNil(ColorProfile.standard.fallbackColor)
    }

    func testMiraProfileFollowsHerColorCode() {
        let mira = ColorProfile.mira
        XCTAssertEqual(mira.suggestedColor(forTitle: "有馬記念"), .green)
        XCTAssertEqual(mira.suggestedColor(forTitle: "年末ジャンボ宝くじ"), .black)
        XCTAssertEqual(mira.suggestedColor(forTitle: "レポート提出"), .purple)
        XCTAssertEqual(mira.suggestedColor(forTitle: "ゆいちゃん誕生日"), .white)
        XCTAssertEqual(mira.suggestedColor(forTitle: "推しのライブ"), .skyLight)
        XCTAssertEqual(mira.suggestedColor(forTitle: "シフト"), .redLight)
        XCTAssertEqual(mira.suggestedColor(forTitle: "皮膚科"), .greenLight)
        XCTAssertEqual(mira.suggestedColor(forTitle: "友達と焼肉"), .sky)
        XCTAssertNil(mira.suggestedColor(forTitle: "なにか"))
        XCTAssertEqual(mira.defaultLabels[.black], "宝くじ")
    }

    func testTurningOnAProfileKeepsLabelsThePersonWrote() throws {
        let store = try makeStore()
        store.resetColorPreferences()
        defer { store.resetColorPreferences() }
        store.setLabel("推し活", for: .skyLight)
        store.setColorProfile(.mira)
        XCTAssertEqual(store.label(for: .skyLight), "推し活")
        XCTAssertEqual(store.label(for: .green), "競馬")
        XCTAssertEqual(store.suggestedColor(forTitle: "歯医者"), .greenLight)
        XCTAssertEqual(store.displayName(for: .orange), "オレンジ")
    }

    func testPaletteHasSevenHuesInThreeTonesPlusNeutrals() {
        XCTAssertEqual(EventColorTag.allCases.count, 24)
        XCTAssertEqual(EventColorTag.allCases.filter { $0.tone == .light }.count, 7)
        XCTAssertEqual(EventColorTag.allCases.filter { $0.tone == .deep }.count, 7)
        XCTAssertEqual(EventColorTag.skyLight.title, "うすい水色")
        XCTAssertEqual(EventColorTag.white.barHex, 0xCFCFCF)
    }
}
