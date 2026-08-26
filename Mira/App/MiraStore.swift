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

    private(set) var isReady = false
    private(set) var items: [CalendarItemSnapshot] = []
    private(set) var goals: [MarginGoalSnapshot] = []
    private(set) var adjustments: [AdjustmentEntity] = []
    private(set) var pendingInvitations: [PendingInvitationEntity] = []
    private(set) var importantPeople: [ImportantPersonEntity] = []
    private(set) var aiStatus = "確認中"

    var selectedMonth: Date
    var selectedDate: Date
    var theme: AppThemeKind = .pixelCat
    var onboardingCompleted = false
    var assistantEnabled = true
    var characterNotificationsEnabled = true
    var notificationsEnabled = false
    var demoModeEnabled = true
    var presentedAddSheet = false
    var toast: String?

    var settingsEntity: AppSettingsEntity?
    var clock: any MiraClock

    init(container: ModelContainer, classifier: any EventSemanticClassifying = HybridSemanticClassifier()) {
        self.container = container
        self.context = ModelContext(container)
        self.classifier = classifier
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
        assistantEngine.message(
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
            applySettings()
            clock = demoModeEnabled ? DemoClock.standard : SystemClock()
            selectedMonth = clock.now
            selectedDate = clock.now
            try DemoSeeder.seedBaseline(in: context, clock: clock)
            try refresh()
            aiStatus = await classifier.availabilityDescription
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
    }
}
