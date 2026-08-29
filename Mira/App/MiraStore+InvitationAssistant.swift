import Foundation

@MainActor
extension MiraStore {
    func prepareDeclineDraft(for invitation: PendingInvitationEntity) async {
        let caseEntity: ConversationCaseEntity
        if let existing = conversationCase(id: invitation.conversationCaseID) {
            caseEntity = existing
        } else {
            let first = invitation.candidates.first
            let state = ConversationCaseState(
                relatedInvitationID: invitation.id,
                person: invitation.contactName,
                dateRangeStart: first?.startDate,
                dateRangeEnd: first?.endDate,
                durationBucket: first.map { $0.displayDuration },
                allowedTimeBands: first.map { [$0.displayTimeBand] } ?? [],
                candidates: invitation.candidates,
                lastIntent: .declineInvitation
            )
            let created = ConversationCaseEntity(
                title: invitation.title,
                kind: .invitation,
                status: .active,
                state: state
            )
            context.insert(created)
            invitation.conversationCaseID = created.id
            try? context.save()
            try? refresh()
            caseEntity = conversationCase(id: created.id) ?? created
        }

        activeConversationCaseID = caseEntity.id
        let generated = await declineGenerator.generate(
            title: invitation.title,
            person: invitation.contactName,
            previous: nil,
            softer: false,
            audience: .friend,
            generationIndex: 0
        )
        var draft = generated
        draft.caseID = caseEntity.id
        activeDeclineDraft = draft
        caseEntity.appendTurn(role: .assistant, text: draft.text, at: now)
        try? context.save()
        try? refresh()
    }
}
