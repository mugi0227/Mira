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

    func setWeekStartDay(_ value: WeekStartDay) {
        weekStartDay = value
        settingsEntity?.weekStartRaw = value.rawValue
        settingsEntity?.updatedAt = .now
        try? context.save()
    }

    func setDeviceHolidaysEnabled(_ enabled: Bool) async {
        if enabled {
            guard await deviceHolidayService.requestAccessIfNeeded() else {
                deviceHolidaysEnabled = false
                settingsEntity?.deviceHolidaysEnabled = false
                try? context.save()
                toast = "iPhoneのカレンダーへのアクセスを許可すると祝日を表示できます"
                return
            }
        }

        deviceHolidaysEnabled = enabled
        settingsEntity?.deviceHolidaysEnabled = enabled
        settingsEntity?.updatedAt = .now
        try? context.save()
        await refreshDeviceHolidays(for: selectedMonth)
    }

    func refreshDeviceHolidays(for month: Date) async {
        replaceDeviceHolidays(with: deviceHolidaysEnabled
            ? deviceHolidayService.holidays(around: month)
            : [])
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
        await reconcileReminders()
    }

    func setDemoModeEnabled(_ enabled: Bool) async {
        demoModeEnabled = enabled
        settingsEntity?.demoModeEnabled = enabled
        clock = enabled ? DemoClock.standard : SystemClock()
        selectedMonth = now
        selectedDate = now
        do {
            try context.save()
            if !enabled { ensurePlan(for: now) }
            await refreshDeviceCalendar()
            await reconcileReminders()
        } catch {
            context.rollback()
            demoModeEnabled = settingsEntity?.demoModeEnabled ?? false
            clock = demoModeEnabled ? DemoClock.standard : SystemClock()
            selectedMonth = now
            selectedDate = now
            persistenceIssue = "日時の設定を保存できませんでした。もう一度お試しください。"
        }
    }

    func startEverydayCalendar() async {
        await resetLocalCalendar(demo: false)
    }

    func resetDemo() async {
        await resetLocalCalendar(demo: true)
    }

    private func resetLocalCalendar(demo: Bool) async {
        do {
            try context.delete(model: CalendarItemEntity.self)
            try context.delete(model: MarginGoalEntity.self)
            try context.delete(model: AdjustmentEntity.self)
            try context.delete(model: PendingInvitationEntity.self)
            try context.delete(model: LoadRuleEntity.self)
            try context.delete(model: BaseRuleEntity.self)
            try context.delete(model: ImportantPersonEntity.self)
            try context.delete(model: ConversationCaseEntity.self)
            try context.delete(model: RebalanceProposalEntity.self)
            settingsEntity?.onboardingCompleted = false
            settingsEntity?.themeRaw = AppThemeKind.pixelCat.rawValue
            settingsEntity?.marginComfortRaw = MarginComfortLevel.standard.rawValue
            settingsEntity?.weekStartRaw = WeekStartDay.monday.rawValue
            settingsEntity?.deviceHolidaysEnabled = false
            settingsEntity?.demoModeEnabled = demo
            settingsEntity?.notificationsEnabled = false
            try context.save()
            demoModeEnabled = demo
            notificationsEnabled = false
            deviceCalendarService.enabled = false
            clock = demo ? DemoClock.standard : SystemClock()
            selectedMonth = now
            selectedDate = now
            undoEntry = nil
            clearAllDrafts()
            onboardingCompleted = false
            theme = .pixelCat
            marginComfortLevel = .standard
            weekStartDay = .monday
            deviceHolidaysEnabled = false
            replaceDeviceHolidays(with: [])
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
            if demo { try DemoSeeder.seedBaseline(in: context, clock: DemoClock.standard) }
            try refresh()
            await reconcileReminders()
            toast = demo ? "サンプル状態に戻しました" : "あなたのカレンダーを始めましょう"
        } catch {
            context.rollback()
            try? refresh()
            persistenceIssue = "リセットを完了できませんでした。保存状態を確認して、もう一度お試しください。"
        }
    }
}
