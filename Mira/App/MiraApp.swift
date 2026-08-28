import SwiftData
import SwiftUI

@main
struct MiraApp: App {
    private let modelContainer: ModelContainer
    @State private var store: MiraStore

    init() {
        let container = Self.makeModelContainer()
        modelContainer = container
        _store = State(initialValue: MiraStore(container: container))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
                .modelContainer(modelContainer)
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([
            AppSettingsEntity.self,
            CalendarItemEntity.self,
            MarginGoalEntity.self,
            BaseRuleEntity.self,
            AdjustmentEntity.self,
            PendingInvitationEntity.self,
            LoadRuleEntity.self,
            ImportantPersonEntity.self,
            ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        do {
            return try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            )
        } catch {
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
                )
            } catch {
                fatalError("ModelContainer initialization failed: \(error)")
            }
        }
    }
}
