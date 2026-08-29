import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MiraStore {
    enum ImpactResolution {
        case relocate
        case exception
    }

    let container: ModelContainer
    let context: ModelContext
    let scheduler = SchedulerEngine()
    let loadEngine = LoadEngine()
    let protectionEngine = ProtectionEngine()
    let assistantEngine = AssistantEngine()
    let classifier: any EventSemanticClassifying
    let conversationInterpreter: any ConversationInterpreting
    let declineGenerator: any DeclineDraftGenerating
    let caseSearchEngine = CaseSearchEngine()
    let schedulingRecommendationEngine = SchedulingRecommendationEngine()
    let marginRecommendationEngine = MarginRecommendationEngine()
    let rebalanceEngine = RebalanceEngine()
    let deviceHolidayService = DeviceHolidayService()

    private(set) var isReady = false
    private(set) var items: [CalendarItemSnapshot] = []
    private(set) var goals: [MarginGoalSnapshot] = []
    private(set) var adjustments: [AdjustmentEntity] = []
    private(set) var pendingInvitations: [PendingInvitationEntity] = []
    private(set) var importantPeople: [ImportantPersonEntity] = []
    private(set) var conversationCases: [ConversationCaseEntity] = []
    private(set) var rebalanceProposalEntities: [RebalanceProposalEntity] = []
    private(set) var deviceHolidays: [DeviceHolidaySnapshot] = []
    private(set) var aiStatus = "確認中"
    var isInterpretingConversation = false

    var selectedMonth: Date
    var selectedDate: Date
    var theme: AppThemeKind = .pixelCat
    var onboardingCompleted = false
    var assistantEnabled = true
    var characterNotificationsEnabled = true
    var notificationsEnabled = false
    var demoModeEnabled = true
    var marginComfortLevel: MarginComfortLevel = .standard
    var weekStartDay: WeekStartDay = .monday
    var deviceHolidaysEnabled = false
    var presentedAddSheet = false
    var toast: String?

    var activeSchedulingDraft: SchedulingDraft?
    var activeSchedulingIntent: ConversationIntent = .findDates
    var pinnedContext: ContextSearchResult?
    var pendingInterpretation: ConversationInterpretation?
    var pendingChangePreview: ChangePreview?
    var pendingEventCreationPreview: EventCreationPreview?
    var activeDeclineDraft: DeclineDraft?
    var activeConversationCaseID: UUID?
    var activeClarification: ConversationClarification?
    var currentMarginRecommendation: MarginRecommendation?
    var activeRebalanceProposal: RebalanceProposal?
    var isRebalanceProposalPresented = false

    var settingsEntity: AppSettingsEntity?
    var clock: any MiraClock

    init(
        container: ModelContainer,
        classifier: any EventSemanticClassifying = HybridSemanticClassifier(),
        conversationInterpreter: any ConversationInterpreting = HybridConversationInterpreter(),
        declineGenerator: any DeclineDraftGenerating = HybridDeclineDraftGenerator()
    ) {
        self.container = container
        self.context = ModelContext(container)
        self.classifier = classifier
        self.conversationInterpreter = conversationInterpreter
        self.declineGenerator = declineGenerator
        self.clock = DemoClock.standard
        self.selectedMonth = DemoClock.standard.now
        self.selectedDate = DemoClock.standard.now
    }

    var now: Date { clock.now }

    var currentMonthGoals: [MarginGoalSnapshot] {
        let key = MonthKey(date: selectedMonth)
        return goals.filter { $0.year == key.year && $0.month == key.month }
            .sorted { $0.priority > $1.priority }
    }

    var selectedDayItems: [CalendarItemSnapshot] {
        items.filter { Calendar.mira.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    var currentAssistantMessage: AssistantMessage {
        if let proposal = activeRebalanceProposal,
           Calendar.mira.isDate(proposal.month, equalTo: selectedMonth, toGranularity: .month) {
            return AssistantMessage(
                title: "今月の余白を組み直せるにゃ",
                body: proposal.summary,
                mood: .thinking,
                severity: 2,
                actionTitle: "完成案を見る"
            )
        }
        return assistantEngine.message(
            theme: theme,
            month: selectedMonth,
            goals: currentMonthGoals,
            items: items
        )
    }

    func bootstrap() async {
        do {
            var descriptor = FetchDescriptor<AppSettingsEntity>()
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                settingsEntity = existing
            } else {
                let settings = AppSettingsEntity()
                context.insert(settings)
                settingsEntity = settings
                try context.save()
            }

            if ProcessInfo.processInfo.arguments.contains("-reset-demo") {
                try resetPersistentTestState()
            }

            applySettings()
            clock = demoModeEnabled ? DemoClock.standard : SystemClock()
            selectedMonth = clock.now
            selectedDate = clock.now
            try DemoSeeder.seedBaseline(in: context, clock: clock)
            try normalizeLegacyMarginKinds()
            try refresh()
            if deviceHolidaysEnabled {
                await refreshDeviceHolidays(for: selectedMonth)
            }
            aiStatus = await classifier.availabilityDescription
            updateMarginRecommendation(for: selectedMonth)
            recalculateBalance(for: selectedMonth)
            isReady = true
        } catch {
            toast = "データを準備できませんでした"
            isReady = true
        }
    }

    func refresh() throws {
        items = try context.fetch(FetchDescriptor<CalendarItemEntity>()).map(\.snapshot)
            .sorted { $0.startDate < $1.startDate }
        goals = try context.fetch(FetchDescriptor<MarginGoalEntity>()).map(\.snapshot)
        adjustments = try context.fetch(FetchDescriptor<AdjustmentEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        pendingInvitations = try context.fetch(FetchDescriptor<PendingInvitationEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        importantPeople = try context.fetch(FetchDescriptor<ImportantPersonEntity>())
        conversationCases = try context.fetch(FetchDescriptor<ConversationCaseEntity>(sortBy: [SortDescriptor(\.lastActivityAt, order: .reverse)]))
        rebalanceProposalEntities = try context.fetch(FetchDescriptor<RebalanceProposalEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        activeRebalanceProposal = rebalanceProposalEntities.first(where: { !$0.isDismissed })?.proposal
    }

    /// Collapses the two historical aliases into the single rest category.
    /// Existing rest goals win, so old overlapping targets are not added
    /// together and do not unexpectedly fill the calendar.
    private func normalizeLegacyMarginKinds() throws {
        let itemEntities = try context.fetch(FetchDescriptor<CalendarItemEntity>())
        for item in itemEntities {
            guard let kind = item.marginKindRaw.flatMap(MarginKind.init(rawValue:)),
                  kind.isLegacyRestAlias else { continue }
            item.marginKindRaw = MarginKind.rest.rawValue
            item.title = MarginKind.rest.title
            item.updatedAt = .now
        }

        let goalEntities = try context.fetch(FetchDescriptor<MarginGoalEntity>())
        let affected = goalEntities.filter {
            guard let kind = MarginKind(rawValue: $0.kindRaw) else { return false }
            return kind == .rest || kind.isLegacyRestAlias
        }
        let grouped = Dictionary(grouping: affected) {
            MonthKey(year: $0.year, month: $0.month)
        }

        for goalsInMonth in grouped.values {
            let legacy = goalsInMonth.filter {
                MarginKind(rawValue: $0.kindRaw)?.isLegacyRestAlias == true
            }
            guard !legacy.isEmpty else { continue }

            if let restGoal = goalsInMonth.first(where: { $0.kindRaw == MarginKind.rest.rawValue }) {
                restGoal.durationHours = MarginKind.rest.defaultDurationHours
                restGoal.priority = MarginKind.rest.defaultPriority
                legacy.forEach { context.delete($0) }
            } else if let keeper = legacy.max(by: { $0.targetCount < $1.targetCount }) {
                keeper.kindRaw = MarginKind.rest.rawValue
                keeper.durationHours = MarginKind.rest.defaultDurationHours
                keeper.priority = MarginKind.rest.defaultPriority
                legacy.filter { $0.id != keeper.id }.forEach { context.delete($0) }
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }

    private func resetPersistentTestState() throws {
        try context.delete(model: CalendarItemEntity.self)
        try context.delete(model: MarginGoalEntity.self)
        try context.delete(model: BaseRuleEntity.self)
        try context.delete(model: AdjustmentEntity.self)
        try context.delete(model: PendingInvitationEntity.self)
        try context.delete(model: LoadRuleEntity.self)
        try context.delete(model: ImportantPersonEntity.self)
        try context.delete(model: ConversationCaseEntity.self)
        try context.delete(model: RebalanceProposalEntity.self)
        settingsEntity?.onboardingCompleted = false
        settingsEntity?.themeRaw = AppThemeKind.pixelCat.rawValue
        settingsEntity?.marginComfortRaw = MarginComfortLevel.standard.rawValue
        settingsEntity?.weekStartRaw = WeekStartDay.monday.rawValue
        settingsEntity?.deviceHolidaysEnabled = false
        settingsEntity?.updatedAt = .now
        try context.save()
    }
}
