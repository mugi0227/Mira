import Foundation

@MainActor
extension MiraStore {
    func linkContextRecord(
        _ contextResult: ContextSearchResult?,
        to caseID: UUID
    ) {
        guard let contextResult else { return }

        if let adjustmentID = contextResult.relatedAdjustmentID,
           let adjustment = adjustments.first(where: { $0.id == adjustmentID }) {
            adjustment.conversationCaseID = caseID
            adjustment.updatedAt = now
        }

        if let invitationID = contextResult.relatedInvitationID,
           let invitation = pendingInvitations.first(where: { $0.id == invitationID }) {
            invitation.conversationCaseID = caseID
            invitation.updatedAt = now
        }

        if let itemID = contextResult.relatedItemID,
           let itemEntity = try? entity(id: itemID) {
            itemEntity.conversationCaseID = caseID
            itemEntity.updatedAt = now
        }
    }
}
