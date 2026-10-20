import SwiftData
import XCTest
@testable import Mira

// Loop goals S1/S2 at the store level: suggestions never change the calendar until applied, and can be undone.
@MainActor
final class MiraStoreSuggestionTests: XCTestCase {
    private func makeStore() async throws -> MiraStore {
        let schema = Schema([
            AppSettingsEntity.self,
            CalendarItemEntity.self,
            MarginGoalEntity.self,
            BaseRuleEntity.self,
            AdjustmentEntity.self,
            PendingInvitationEntity.self,
            LoadRuleEntity.self,
            ImportantPersonEntity.self,
            SuggestionEntity.self,
            WeeklyReflectionEntity.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let store = MiraStore(container: container, classifier: RuleBasedSemanticClassifier())
        await store.bootstrap()
        return store
    }

    func testRequestCreatesPendingSuggestionWithoutTouchingCalendar() async throws {
        let store = try await makeStore()
        let before = store.items
        guard case .suggested(let suggestion) = store.submitRequest("来週は自分の時間を増やしたい") else {
            return XCTFail("expected a suggestion")
        }
        XCTAssertEqual(suggestion.status, .pending)
        XCTAssertEqual(store.items, before)
        XCTAssertEqual(store.visibleSuggestions.first?.id, suggestion.id)
    }

    func testRequestStillFindsTimeAfterOnboardingPlacedMargins() async throws {
        let store = try await makeStore()
        store.finishOnboarding(
            targets: [.rest: 4, .freeEvening: 8, .reading: 2, .solo: 2, .importantPeople: 2],
            baseRules: store.fetchBaseRules()
        )
        guard case .suggested(let suggestion) = store.submitRequest("来週は自分の時間を増やしたい") else {
            return XCTFail("expected a suggestion after onboarding")
        }
        XCTAssertFalse(suggestion.margins.isEmpty)
    }

    func testApplyAddsOnlyMarginsAndUndoRemovesThem() async throws {
        let store = try await makeStore()
        let confirmedBefore = store.items.filter { $0.kind != .margin }
        guard case .suggested(let suggestion) = store.submitRequest("来週は自分の時間を増やしたい") else {
            return XCTFail("expected a suggestion")
        }

        store.applySuggestion(id: suggestion.id)
        XCTAssertEqual(store.items.filter { $0.kind != .margin }, confirmedBefore)
        let applied = try XCTUnwrap(store.suggestions.first { $0.id == suggestion.id })
        XCTAssertEqual(applied.status, .applied)
        XCTAssertFalse(applied.appliedMarginIDs.isEmpty)
        XCTAssertTrue(applied.appliedMarginIDs.allSatisfy { id in store.items.contains { $0.id == id && $0.kind == .margin } })

        store.undoSuggestion(id: suggestion.id)
        XCTAssertEqual(store.suggestions.first { $0.id == suggestion.id }?.status, .undone)
        XCTAssertTrue(applied.appliedMarginIDs.allSatisfy { id in !store.items.contains { $0.id == id } })
        XCTAssertEqual(store.items.filter { $0.kind != .margin }, confirmedBefore)
    }

    func testUnknownRequestAsksWithChoices() async throws {
        let store = try await makeStore()
        XCTAssertEqual(store.submitRequest("ラーメン"), .needsChoice(IntentInterpreter.fallbackOptions))
        XCTAssertTrue(store.suggestions.isEmpty)
    }

    func testDismissedProactiveSuggestionIsNotOfferedAgain() async throws {
        let store = try await makeStore()
        await store.refreshProactiveSuggestions()
        guard let proactive = store.suggestions.first(where: { $0.origin == .proactive }) else {
            return // next week already meets the target with the demo data
        }
        store.dismissSuggestion(id: proactive.id)
        await store.refreshProactiveSuggestions()
        XCTAssertEqual(store.suggestions.filter { $0.origin == .proactive }.count, 1)
        XCTAssertTrue(store.visibleSuggestions.isEmpty)
    }

    func testSatisfactionIsStoredPerWeek() async throws {
        let store = try await makeStore()
        store.setSatisfaction(.low, for: store.currentWeek)
        XCTAssertEqual(store.weeklyReview(for: store.currentWeek).satisfaction, .low)
        store.setSatisfaction(.good, for: store.currentWeek)
        XCTAssertEqual(store.weeklyReview(for: store.currentWeek).satisfaction, .good)
    }
}
