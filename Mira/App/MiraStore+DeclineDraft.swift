import Foundation

@MainActor
extension MiraStore {
    func prepareDeclineDraftFromInvitation(_ invitation: PendingInvitationEntity) async {
        let draft = await declineGenerator.generate(
            title: invitation.title,
            person: invitation.contactName,
            previous: nil,
            softer: false,
            generationIndex: 0
        )
        var value = draft
        value.caseID = invitation.conversationCaseID
        activeDeclineDraft = value

        if let caseEntity = conversationCase(id: invitation.conversationCaseID) {
            caseEntity.appendTurn(role: .assistant, text: value.text, at: now)
            try? context.save()
            try? refresh()
        }
    }
}
