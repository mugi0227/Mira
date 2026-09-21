import Foundation
import SwiftData

@MainActor
extension MiraStore {
    @discardableResult
    func createPendingInvitation(
        title: String,
        contact: String,
        candidateDate: Date?,
        timeOfDay: TimeOfDayKind,
        deadline: Date?
    ) -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let slots = candidateDate.map { [candidate(on: $0, timeOfDay: timeOfDay)] } ?? []
        let invitation = PendingInvitationEntity(
            title: title,
            contactName: contact.isEmpty ? nil : contact,
            replyDeadline: deadline,
            candidates: slots
        )
        context.insert(invitation)
        do {
            try context.save()
            try refresh()
            Task { await refreshInvitationReminder(invitation) }
            return true
        } catch {
            context.rollback()
            toast = "誘いを保存できませんでした"
            return false
        }
    }

    @discardableResult
    func createAdjustment(
        title: String,
        contact: String,
        dates: [Date],
        timeOfDay: TimeOfDayKind,
        deadline: Date?
    ) -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !dates.isEmpty else { return false }
        let candidates = dates.sorted().map { candidate(on: $0, timeOfDay: timeOfDay) }
        let message = DemoSeeder.message(title: title, candidates: candidates)
        let entity = AdjustmentEntity(
            title: title,
            contactName: contact.isEmpty ? nil : contact,
            responseDeadline: deadline,
            status: .draft,
            candidates: candidates,
            generatedMessage: message
        )
        context.insert(entity)
        do {
            try context.save()
            try refresh()
            Task { await refreshAdjustmentReminder(entity) }
            toast = "候補と文章を保存しました。送った後に「送信済み」を押せます"
            return true
        } catch {
            context.rollback()
            toast = "日程調整を保存できませんでした"
            return false
        }
    }

    func prepareCandidateConfirmation(sessionID: UUID, candidateID: UUID) async -> CandidateConfirmationReview? {
        do { try refresh() } catch {
            toast = "最新の予定を確認できませんでした"
            return nil
        }
        guard let session = adjustments.first(where: { $0.id == sessionID }),
              session.status == .draft || session.status == .waiting,
              let candidate = session.candidates.first(where: { $0.id == candidateID && $0.status == .held }) else { return nil }
        let originalTitle = session.title
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
        do { try refresh() } catch { return nil }
        guard session.title == originalTitle,
              session.status == .draft || session.status == .waiting,
              session.candidates.contains(candidate) else {
            toast = "候補が変わりました。もう一度確認してください"
            return nil
        }
        return CandidateConfirmationReview(
            sessionID: sessionID,
            sessionCandidates: Set(session.candidates),
            candidate: candidate,
            event: prepared,
            impact: previewImpact(for: prepared),
            conflicts: eventEntryConflicts(for: prepared, excludingAdjustmentID: sessionID),
            goalDeficits: worsenedGoalDeficits(afterAdding: prepared),
            context: scheduleReviewContext(excludingAdjustmentID: sessionID)
        )
    }

    /// Approval never prevents an intentional overlap. It only binds the save to
    /// the impact the user actually reviewed, without releasing candidates early.
    @discardableResult
    func confirmCandidate(
        sessionID: UUID,
        candidateID: UUID,
        approval: CandidateConfirmationReview? = nil,
        resolution: ImpactResolution = .exception,
        chosenRelocationDate: Date? = nil
    ) async -> Bool {
        do { try refresh() } catch { return false }
        guard let approval,
              approval.sessionID == sessionID,
              approval.candidate.id == candidateID,
              let session = adjustments.first(where: { $0.id == sessionID }),
              session.status == .draft || session.status == .waiting,
              session.title == approval.event.title,
              session.candidates.contains(approval.candidate),
              Set(session.candidates) == approval.sessionCandidates,
              approval.context == scheduleReviewContext(excludingAdjustmentID: sessionID) else {
            toast = "最新の重複と余白への影響を確認してから確定してください"
            return false
        }
        let updated = session.candidates.map { slot -> CandidateSlotSnapshot in
            var copy = slot
            copy.status = slot.id == candidateID ? .confirmed : .released
            return copy
        }
        let prepared = approval.event
        let saved = commitAdvisedEvent(
            prepared,
            impact: previewImpact(for: prepared),
            resolution: resolution,
            chosenRelocationDate: chosenRelocationDate
        ) {
            session.candidates = updated
            session.status = .confirmed
            if let caseEntity = self.conversationCase(id: session.conversationCaseID) {
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
                caseEntity.appendTurn(role: .assistant, text: "この日で確定して、ほかの候補を解放したにゃ", at: self.now)
            }
        }
        guard saved else { return false }
        await NotificationService.shared.cancelAdjustmentReminder(id: sessionID)
        toast = "日程を確定して、ほかの候補を解放したにゃ"
        return true
    }

    @discardableResult
    func convertPendingToAdjustment(_ invitation: PendingInvitationEntity) -> Bool {
        guard invitation.status == .considering else { return false }
        let message = invitation.candidates.isEmpty
            ? "候補日はこれから探します。"
            : DemoSeeder.message(title: invitation.title, candidates: invitation.candidates)
        let entity = AdjustmentEntity(
            title: invitation.title,
            contactName: invitation.contactName,
            responseDeadline: invitation.replyDeadline,
            status: .draft,
            candidates: invitation.candidates,
            generatedMessage: message,
            conversationCaseID: invitation.conversationCaseID
        )
        context.insert(entity)
        invitation.status = .adjustment
        if let caseEntity = conversationCase(id: invitation.conversationCaseID) {
            caseEntity.kind = .adjustment
            caseEntity.status = .active
            var state = caseEntity.state
            state.relatedAdjustmentID = entity.id
            state.relatedInvitationID = invitation.id
            state.candidates = invitation.candidates
            caseEntity.state = state
        }
        do {
            try context.save()
            try refresh()
        } catch {
            context.rollback()
            try? refresh()
            toast = "調整への変更を保存できませんでした"
            return false
        }
        Task {
            await refreshInvitationReminder(invitation)
            await refreshAdjustmentReminder(entity)
        }
        toast = "検討中から調整中へ移したにゃ"
        return true
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

    @discardableResult
    func acceptPending(
        _ invitation: PendingInvitationEntity,
        approvedEvent event: CalendarItemSnapshot,
        reviewContext: ScheduleReviewContext,
        resolution: ImpactResolution,
        chosenRelocationDate: Date? = nil
    ) -> Bool {
        do { try refresh() } catch { return false }
        guard invitation.status == .considering,
              invitation.title == event.title,
              let candidate = invitation.candidates.first,
              candidate.startDate == event.startDate,
              candidate.endDate == event.endDate,
              reviewContext == scheduleReviewContext() else {
            toast = "予定が変わりました。最新の影響を確認してください"
            return false
        }
        let saved = commitAdvisedEvent(
            event,
            impact: previewImpact(for: event),
            resolution: resolution,
            chosenRelocationDate: chosenRelocationDate
        ) {
            invitation.status = .accepted
            if let caseEntity = self.conversationCase(id: invitation.conversationCaseID) {
                caseEntity.kind = .confirmedEvent
                caseEntity.status = .confirmed
                var state = caseEntity.state
                state.relatedItemID = event.id
                state.relatedInvitationID = invitation.id
                state.dateRangeStart = event.startDate
                state.dateRangeEnd = event.endDate
                caseEntity.state = state
            }
        }
        if saved { Task { await refreshInvitationReminder(invitation) } }
        return saved
    }

    @discardableResult
    func markPending(_ invitation: PendingInvitationEntity, as status: InvitationStatus) -> Bool {
        invitation.status = status
        if let caseEntity = conversationCase(id: invitation.conversationCaseID) {
            switch status {
            case .accepted:
                caseEntity.kind = .confirmedEvent
                caseEntity.status = .confirmed
            case .adjustment:
                caseEntity.kind = .adjustment
                caseEntity.status = .active
            case .declined:
                caseEntity.status = .completed
            case .archived:
                caseEntity.status = .archived
            case .considering:
                caseEntity.kind = .invitation
                caseEntity.status = .active
            }
        }
        do {
            try context.save()
            try refresh()
        } catch {
            context.rollback()
            try? refresh()
            toast = "誘いの状態を保存できませんでした"
            return false
        }
        Task { await refreshInvitationReminder(invitation) }
        return true
    }

    @discardableResult
    func declinePending(_ invitation: PendingInvitationEntity) -> Bool {
        guard markPending(invitation, as: .declined) else { return false }
        if let caseEntity = conversationCase(id: invitation.conversationCaseID) {
            caseEntity.appendTurn(role: .assistant, text: "今回は見送ることにしたにゃ", at: now)
            try? context.save()
            try? refresh()
        }
        toast = "今回は見送ることにしたにゃ"
        return true
    }

    func archivePending(_ invitation: PendingInvitationEntity) {
        markPending(invitation, as: .archived)
    }

    @discardableResult
    func cancelAdjustment(_ session: AdjustmentEntity) async -> Bool {
        guard session.status == .draft || session.status == .waiting else { return false }
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
        do {
            try context.save()
            try refresh()
        } catch {
            context.rollback()
            try? refresh()
            toast = "調整の取り消しを保存できませんでした"
            return false
        }
        await NotificationService.shared.cancelAdjustmentReminder(id: session.id)
        toast = "候補日を解放したにゃ"
        return true
    }
}
