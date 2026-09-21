import SwiftData
import SwiftUI

@main
struct MiraApp: App {
    @State private var modelContainer: ModelContainer
    @State private var store: MiraStore

    init() {
        _ = NotificationService.shared
        let result = Self.makeModelContainer()
        _modelContainer = State(initialValue: result.container)
        _store = State(initialValue: MiraStore(
            container: result.container,
            conversationInterpreter: JevAssistedConversationInterpreter(),
            isEmergencyStorage: result.isEmergency
        ))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .id(ObjectIdentifier(store))
                .environment(store)
                .modelContainer(modelContainer)
                .onReceive(NotificationCenter.default.publisher(for: .miraRetryStorage)) { _ in
                    let result = Self.makeModelContainer()
                    modelContainer = result.container
                    store = MiraStore(container: result.container,
                        conversationInterpreter: JevAssistedConversationInterpreter(),
                        isEmergencyStorage: result.isEmergency)
                }
        }
    }

    private static func makeModelContainer() -> (container: ModelContainer, isEmergency: Bool) {
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
            return (try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            ), false)
        } catch {
            do {
                return (try ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
                ), true)
            } catch {
                fatalError("ModelContainer initialization failed: \(error)")
            }
        }
    }
}
