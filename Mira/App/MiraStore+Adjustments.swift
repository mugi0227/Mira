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

        var updated = session.candidates.map { slot -> CandidateSlotSnapshot in
            var copy = slot
            copy.status = slot.id == candidateID ? .confirmed : .released
            return copy
        }
        session.candidates = updated
        session.status = .confirmed

        let prepared = await prepareEvent(
            title: session.title,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            isAllDay: candidate.timeOfDay == .allDay,
            isImportant: false
        )
        context.insert(CalendarItemEntity(snapshot: prepared))
        try? context.save()
        try? refresh()
        await NotificationService.shared.cancelAdjustmentReminder(id: sessionID)
        toast = "日程を確定して、ほかの候補を解放したにゃ"
    }

    func convertPendingToAdjustment(_ invitation: PendingInvitationEntity) {
        createAdjustment(
            title: invitation.title,
            contact: invitation.contactName ?? "",
            dates: invitation.candidates.map(\.startDate),
            timeOfDay: invitation.candidates.first?.timeOfDay ?? .evening,
            deadline: invitation.replyDeadline
        )
        invitation.status = .adjustment
        try? context.save()
        try? refresh()
    }

    func heldCandidates(excluding sessionID: UUID? = nil) -> [CandidateSlotSnapshot] {
        adjustments
            .filter { $0.id != sessionID && $0.status == .waiting }
            .flatMap(\.candidates)
            .filter { $0.status == .held }
    }

    func conflictMessages(for candidate: CandidateSlotSnapshot, excluding sessionID: UUID? = nil) -> [String] {
        ConflictEngine().conflicts(
            candidate: candidate,
            events: items,
            otherCandidates: heldCandidates(excluding: sessionID)
        )
    }

    func acceptPending(_ invitation: PendingInvitationEntity) async {
        guard let candidate = invitation.candidates.first else { return }
        let event = await prepareEvent(
            title: invitation.title,
            startDate: candidate.startDate,
            endDate: candidate.endDate,
            isAllDay: candidate.timeOfDay == .allDay,
            isImportant: false
        )
        let impact = previewImpact(for: event)
        commitEvent(event, impact: impact, resolution: .exception)
        invitation.status = .accepted
        try? context.save()
        try? refresh()
    }

    func markPending(_ invitation: PendingInvitationEntity, as status: InvitationStatus) {
        invitation.status = status
        try? context.save()
        try? refresh()
    }

    func declinePending(_ invitation: PendingInvitationEntity) {
        markPending(invitation, as: .declined)
        toast = "今回は見送ることにしたにゃ"
    }

    func archivePending(_ invitation: PendingInvitationEntity) {
        invitation.status = .archived
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
        try? context.save()
        try? refresh()
        await NotificationService.shared.cancelAdjustmentReminder(id: session.id)
        toast = "候補日を解放したにゃ"
    }
}
