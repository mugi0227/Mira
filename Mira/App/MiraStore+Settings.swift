import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func setTheme(_ newTheme: AppThemeKind) {
        theme = newTheme
        settingsEntity?.themeRaw = newTheme.rawValue
        settingsEntity?.updatedAt = .now
        try? context.save()
    }

    func setAssistantEnabled(_ enabled: Bool) {
        assistantEnabled = enabled
        settingsEntity?.assistantEnabled = enabled
        settingsEntity?.updatedAt = .now
        try? context.save()
    }

    func setCharacterNotificationsEnabled(_ enabled: Bool) {
        characterNotificationsEnabled = enabled
        settingsEntity?.characterNotificationsEnabled = enabled
        settingsEntity?.updatedAt = .now
        try? context.save()
    }

    func setMarginComfortLevel(_ level: MarginComfortLevel, applyRecommendation: Bool = true) {
        marginComfortLevel = level
        settingsEntity?.marginComfortRaw = level.rawValue
        settingsEntity?.updatedAt = .now
        try? context.save()
        updateMarginRecommendation(for: selectedMonth)
        if applyRecommendation {
            applyCurrentMarginRecommendation()
        }
    }

    func addImportantPerson(name: String, monthlyTarget: Int?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(ImportantPersonEntity(
            name: trimmed,
            monthlyTarget: monthlyTarget,
            targetEnabled: monthlyTarget != nil
        ))
        try? context.save()
        try? refresh()
        toast = "大切な人を追加したにゃ"
    }

    func removeImportantPerson(id: UUID) {
        guard let person = importantPeople.first(where: { $0.id == id }) else { return }
        context.delete(person)
        try? context.save()
        try? refresh()
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = await NotificationService.shared.requestAuthorization()
            notificationsEnabled = granted
            settingsEntity?.notificationsEnabled = granted
        } else {
            notificationsEnabled = false
            settingsEntity?.notificationsEnabled = false
        }
        try? context.save()
    }

    func resetDemo() async {
        do {
            try context.delete(model: CalendarItemEntity.self)
            try context.delete(model: MarginGoalEntity.self)
            try context.delete(model: AdjustmentEntity.self)
            try context.delete(model: PendingInvitationEntity.self)
            try context.delete(model: LoadRuleEntity.self)
            try context.delete(model: BaseRuleEntity.self)
            try context.delete(model: ConversationCaseEntity.self)
            try context.delete(model: RebalanceProposalEntity.self)
            settingsEntity?.onboardingCompleted = false
            settingsEntity?.themeRaw = AppThemeKind.pixelCat.rawValue
            settingsEntity?.marginComfortRaw = MarginComfortLevel.standard.rawValue
            try context.save()
            onboardingCompleted = false
            theme = .pixelCat
            marginComfortLevel = .standard
            activeSchedulingDraft = nil
            pinnedContext = nil
            pendingInterpretation = nil
            pendingChangePreview = nil
            pendingEventCreationPreview = nil
            activeDeclineDraft = nil
            activeConversationCaseID = nil
            activeClarification = nil
            activeRebalanceProposal = nil
            isRebalanceProposalPresented = false
            try DemoSeeder.seedBaseline(in: context, clock: DemoClock.standard)
            try refresh()
            toast = "最初の状態に戻したにゃ"
        } catch {
            toast = "リセットできませんでした"
        }
    }
}
