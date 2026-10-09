import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class WeekStartTests: XCTestCase {
    func testWeekStartSurvivesRelaunch() async throws {
        let container = try makeContainer()
        let first = makeStore(container)
        await first.bootstrap()
        XCTAssertEqual(first.weekStartDay, .monday)

        first.setWeekStartDay(.sunday)
        let relaunched = makeStore(container)
        await relaunched.bootstrap()
        XCTAssertEqual(relaunched.weekStartDay, .sunday)
    }

    func testOnboardingChoiceIsWhatTheStoreReports() async throws {
        let store = makeStore(try makeContainer())
        await store.bootstrap()
        store.finishOnboarding(targets: [.rest: 4], baseRules: [], weekStartDay: .sunday)
        XCTAssertEqual(store.weekStartDay, .sunday)
        XCTAssertEqual(store.settingsEntity?.weekStartRaw, WeekStartDay.sunday.rawValue)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        return try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func makeStore(_ container: ModelContainer) -> MiraStore {
        MiraStore(container: container, classifier: RuleBasedSemanticClassifier(),
            conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
    }
}
