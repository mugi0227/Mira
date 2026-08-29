import SwiftData
import XCTest
@testable import Mira

@MainActor
final class PendingInvitationWorkflowTests: XCTestCase {
    func testInvitationWithoutCandidateMovesFromConsideringToAdjustment() throws {
        let store = try makeStore()

        store.createPendingInvitation(
            title: "飲み会の誘い",
            contact: "友達",
            candidateDate: nil,
            timeOfDay: .evening,
            deadline: nil
        )

        let invitation = try XCTUnwrap(store.pendingInvitations.first)
        XCTAssertEqual(invitation.status, .considering)
        XCTAssertTrue(invitation.candidates.isEmpty)

        store.convertPendingToAdjustment(invitation)

        XCTAssertEqual(invitation.status, .adjustment)
        XCTAssertEqual(store.adjustments.count, 1)
        XCTAssertTrue(store.adjustments[0].candidates.isEmpty)
    }

    private func makeStore() throws -> MiraStore {
        let schema = Schema([
            AppSettingsEntity.self,
            CalendarItemEntity.self,
            MarginGoalEntity.self,
            BaseRuleEntity.self,
            AdjustmentEntity.self,
            PendingInvitationEntity.self,
            LoadRuleEntity.self,
            ImportantPersonEntity.self,
            ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return MiraStore(container: container)
    }
}
