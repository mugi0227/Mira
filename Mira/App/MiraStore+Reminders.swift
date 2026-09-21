import Foundation

@MainActor
extension MiraStore {
    @discardableResult
    func markAdjustmentSent(_ session: AdjustmentEntity) async -> Bool {
        guard session.status == .draft, !session.candidates.isEmpty else { return false }
        session.status = .waiting
        if let caseEntity = conversationCase(id: session.conversationCaseID) {
            caseEntity.status = .waiting
            caseEntity.appendTurn(role: .user, text: "相手へ送信済み", at: now)
        }
        do {
            try context.save()
            try refresh()
            await refreshAdjustmentReminder(session)
            toast = "送信済みを記録しました。相手の返事待ちです"
            return true
        } catch {
            context.rollback()
            try? refresh()
            toast = "送信済みの記録を保存できませんでした"
            return false
        }
    }

    @discardableResult
    func markAdjustmentUnsent(_ session: AdjustmentEntity) async -> Bool {
        guard session.status == .waiting else { return false }
        session.status = .draft
        if let caseEntity = conversationCase(id: session.conversationCaseID) {
            caseEntity.status = .active
        }
        do {
            try context.save()
            try refresh()
            await refreshAdjustmentReminder(session)
            toast = "未送信に戻しました"
            return true
        } catch {
            context.rollback()
            try? refresh()
            toast = "状態を保存できませんでした"
            return false
        }
    }

    @discardableResult
    func updateAdjustmentDeadline(_ session: AdjustmentEntity, deadline: Date?) async -> Bool {
        guard session.status == .draft || session.status == .waiting else { return false }
        session.responseDeadline = deadline
        do {
            try context.save()
            try refresh()
            await refreshAdjustmentReminder(session)
            return true
        } catch {
            context.rollback()
            try? refresh()
            toast = "期限を保存できませんでした"
            return false
        }
    }

    func refreshAdjustmentReminder(_ session: AdjustmentEntity) async {
        guard notificationsEnabled, !demoModeEnabled,
              let plan = ReminderPlan.adjustment(
                id: session.id, title: session.title, status: session.status,
                deadline: session.responseDeadline,
                catVoice: characterNotificationsEnabled && theme == .pixelCat
              ) else {
            await NotificationService.shared.cancelAdjustmentReminder(id: session.id)
            return
        }
        await NotificationService.shared.schedule(plan)
    }

    func refreshInvitationReminder(_ invitation: PendingInvitationEntity) async {
        guard notificationsEnabled, !demoModeEnabled,
              let plan = ReminderPlan.invitation(
                id: invitation.id, title: invitation.title, status: invitation.status,
                deadline: invitation.replyDeadline,
                catVoice: characterNotificationsEnabled && theme == .pixelCat
              ) else {
            await NotificationService.shared.cancelInvitationReminder(id: invitation.id)
            return
        }
        await NotificationService.shared.schedule(plan)
    }

    func reconcileReminders() async {
        guard notificationsEnabled, !demoModeEnabled else {
            await NotificationService.shared.reconcile([])
            return
        }
        let catVoice = characterNotificationsEnabled && theme == .pixelCat
        let plans = adjustments.compactMap {
            ReminderPlan.adjustment(id: $0.id, title: $0.title, status: $0.status, deadline: $0.responseDeadline, catVoice: catVoice)
        } + pendingInvitations.compactMap {
            ReminderPlan.invitation(id: $0.id, title: $0.title, status: $0.status, deadline: $0.replyDeadline, catVoice: catVoice)
        }
        await NotificationService.shared.reconcile(plans)
    }
}
