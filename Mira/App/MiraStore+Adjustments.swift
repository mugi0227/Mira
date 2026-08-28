import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func createPendingInvitation(
        title: String,
        contact: String,
        candidateDate: Date,
        timeOfDay: TimeOfDayKind,
        deadline: Date?
    ) {
        let slot = candidate(on: candidateDate, timeOfDay: timeOfDay)
        context.insert(PendingInvitationEntity(
            title: title,
            contactName: contact.isEmpty ? nil : contact,
            replyDeadline: deadline,
            candidates: [slot]
        ))
        try? context.save()
        try? refresh()
    }

    func createAdjustment(
        title: String,
        contact: String,
        dates: [Date],
        timeOfDay: TimeOfDayKind,
        deadline: Date?
    ) {
        let candidates = dates.sorted().map { candidate(on: $0, timeOfDay: timeOfDay) }
        let message = DemoSeeder.message(title: title, candidates: candidates)
        let entity = AdjustmentEntity(
            title: title,
            contactName: contact.isEmpty ? nil : contact,
            responseDeadline: deadline,
            candidates: candidates,
            generatedMessage: message
        )
        context.insert(entity)
        try? context.save()
        try? refresh()
        if let deadline, notificationsEnabled {
            Task {
                await NotificationService.shared.scheduleAdjustmentReminder(
                    id: entity.id,
                    title: title,
                    deadline: deadline,
                    catVoice: characterNotificationsEnabled && theme == .pixelCat
                )
            }
        }
    }

    func confirmCandidate(sessionID: UUID, candidateID: UUID) async {
        guard let session = adjustments.first(where: { $0.id == sessionID }),
              let candidate = session.candidates.first(where: { $0.id == candidateID }) else { return }

        let updated = session.candidates.map { slot -> CandidateSlotSnapshot in
            var copy = slot
            copy.status = slot.id == candidateID ? .confirmed : .released
            return copy
        }
        session.candidates = updated
        session.status = .confirmed

        var prepared = await prepareEvent(
            title: session.title,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            isAllDay: candidate.timeOfDay == .allDay,
            isImportant: false
        )
        prepared.schedulingTimeBand = candidate.schedulingTimeBand ?? candidate.displayTimeBand
        prepared.durationBucket = candidate.durationBucket ?? candidate.displayDuration
        prepared.exactTimeKnown = candidate.exactTimeKnown ?? true
        prepared.conversationCaseID = session.conversationCaseID
        let impact = previewImpact(for: prepared)

        commitAdvisedEvent(prepared, impact: impact, resolution: .exception)

        if let caseEntity = conversationCase(id: session.conversationCaseID) {
            caseEntity.kind = .confirmedEvent
            caseEntity.status = .confirmed
            var state = caseEntity.state
            state.relatedItemID = prepared.id
            state.relatedAdjustmentID = session.id
            state.dateRangeStart = prepared.startDate
            state.dateRangeEnd = prepared.endDate
            state.durationBucket = prepared.durationBucket
            state.allowedTimeBands = prepared.schedulingTimeBand.map { [$0] } ?? []
            state.candidates = updated
            caseEntity.state = state
            caseEntity.appendTurn(role: .assistant, text: "この日で確定して、ほかの候補を解放したにゃ", at: now)
        }

        try? context.save()
        try? refresh()
        updateMarginRecommendation(for: prepared.startDate)
        recalculateBalance(for: prepared.startDate)
        await NotificationService.shared.cancelAdjustmentReminder(id: sessionID)
        toast = "日程を確定して、ほかの候補を解放したにゃ"
    }

    func convertPendingToAdjustment(_ invitation: PendingInvitationEntity) {
        let message = DemoSeeder.message(title: invitation.title, candidates: invitation.candidates)
        let entity = AdjustmentEntity(
            title: invitation.title,
            contactName: invitation.contactName,
            responseDeadline: invitation.replyDeadline,
            candidates: invitation.candidates,
            generatedMessage: message,
            conversationCaseID: invitation.conversationCaseID
        )
        context.insert(entity)
        invitation.status = .adjustment
        if let caseEntity = conversationCase(id: invitation.conversationCaseID) {
            caseEntity.kind = .adjustment
            caseEntity.status = .waiting
            var state = caseEntity.state
            state.relatedAdjustmentID = entity.id
            state.relatedInvitationID = invitation.id
            state.candidates = invitation.candidates
            caseEntity.state = state
        }
        try? context.save()
        try? refresh()
    }

    func heldCandidates(excluding sessionID: UUID? = nil) -> [CandidateSlotSnapshot] {
        adjustments
            .filter { $0.id != sessionID && ($0.status == .draft || $0.status == .waiting) }
            .flatMap(\.candidates)
            .filter { $0.status == .held }
    }

    func conflictMessages(for candidate: CandidateSlotSnapshot, excluding sessionID: UUID? = nil) -> [String] {
        ConflictEngine().conflicts(
            candidate: candidate,
            events: items,
            otherCandidates: heldCandidates(excluding: sessionID),
            baseRules: fetchBaseRules()
        )
    }

    func acceptPending(_ invitation: PendingInvitationEntity) async {
        guard let candidate = invitation.candidates.first else { return }
        var event = await prepareEvent(
            title: invitation.title,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            isAllDay: candidate.timeOfDay == .allDay,
            isImportant: false
        )
        event.schedulingTimeBand = candidate.schedulingTimeBand ?? candidate.displayTimeBand
        event.durationBucket = candidate.durationBucket ?? candidate.displayDuration
        event.exactTimeKnown = candidate.exactTimeKnown ?? true
        event.conversationCaseID = invitation.conversationCaseID
        let impact = previewImpact(for: event)
        commitAdvisedEvent(event, impact: impact, resolution: .exception)
        invitation.status = .accepted
        if let caseEntity = conversationCase(id: invitation.conversationCaseID) {
            caseEntity.kind = .confirmedEvent
            caseEntity.status = .confirmed
            var state = caseEntity.state
            state.relatedItemID = event.id
            state.relatedInvitationID = invitation.id
            state.dateRangeStart = event.startDate
            state.dateRangeEnd = event.endDate
            caseEntity.state = state
        }
        try? context.save()
        try? refresh()
        updateMarginRecommendation(for: event.startDate)
        recalculateBalance(for: event.startDate)
    }

    func markPending(_ invitation: PendingInvitationEntity, as status: InvitationStatus) {
        invitation.status = status
        try? context.save()
        try? refresh()
    }

    func declinePending(_ invitation: PendingInvitationEntity) {
        markPending(invitation, as: .declined)
        if let caseEntity = conversationCase(id: invitation.conversationCaseID) {
            caseEntity.status = .completed
            caseEntity.appendTurn(role: .assistant, text: "今回は見送ることにしたにゃ", at: now)
            try? context.save()
            try? refresh()
        }
        toast = "今回は見送ることにしたにゃ"
    }

    func archivePending(_ invitation: PendingInvitationEntity) {
        invitation.status = .archived
        if let caseEntity = conversationCase(id: invitation.conversationCaseID) {
            caseEntity.status = .archived
        }
        try? context.save()
        try? refresh()
    }

    func cancelAdjustment(_ session: AdjustmentEntity) async {
        session.status = .cancelled
        session.candidates = session.candidates.map { candidate in
            var copy = candidate
            copy.status = .released
            return copy
        }
        if let caseEntity = conversationCase(id: session.conversationCaseID) {
            caseEntity.status = .completed
            caseEntity.appendTurn(role: .assistant, text: "候補日を解放したにゃ", at: now)
        }
        try? context.save()
        try? refresh()
        await NotificationService.shared.cancelAdjustmentReminder(id: session.id)
        toast = "候補日を解放したにゃ"
    }
}
