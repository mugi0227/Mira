import SwiftUI

struct MainTabView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(palette: palette)
            }
            .tabItem { Label("ホーム", systemImage: "calendar") }

            NavigationStack {
                AdjustmentsView(palette: palette)
            }
            .tabItem { Label("調整", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") }

            NavigationStack {
                MarginsView(palette: palette)
            }
            .tabItem { Label("マイ余白", systemImage: "leaf") }

            NavigationStack {
                SettingsView(palette: palette)
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(palette.accent)
        .sheet(isPresented: schedulingPresented) {
            SchedulingModeView(palette: palette)
        }
        .sheet(isPresented: clarificationPresented) {
            ConversationClarificationSheet(palette: palette)
        }
        .sheet(isPresented: declinePresented) {
            DeclineDraftSheet(palette: palette)
        }
        .sheet(isPresented: changePreviewPresented) {
            ChangePreviewSheet(palette: palette)
        }
        .sheet(isPresented: eventCreationPresented) {
            EventCreationPreviewSheet(palette: palette)
        }
        .sheet(isPresented: rebalancePresented) {
            RebalanceProposalSheet(palette: palette)
        }
    }

    private var schedulingPresented: Binding<Bool> {
        Binding(
            get: { store.activeSchedulingDraft != nil },
            set: { if !$0 { store.activeSchedulingDraft = nil } }
        )
    }

    private var clarificationPresented: Binding<Bool> {
        Binding(
            get: { store.activeClarification != nil },
            set: { if !$0 { store.activeClarification = nil } }
        )
    }

    private var declinePresented: Binding<Bool> {
        Binding(
            get: { store.activeDeclineDraft != nil },
            set: { if !$0 { store.activeDeclineDraft = nil } }
        )
    }

    private var changePreviewPresented: Binding<Bool> {
        Binding(
            get: { store.pendingChangePreview != nil },
            set: { if !$0 { store.pendingChangePreview = nil } }
        )
    }

    private var eventCreationPresented: Binding<Bool> {
        Binding(
            get: { store.pendingEventCreationPreview != nil },
            set: { if !$0 { store.pendingEventCreationPreview = nil } }
        )
    }

    private var rebalancePresented: Binding<Bool> {
        Binding(
            get: { store.activeRebalanceProposal != nil },
            set: { if !$0 { store.activeRebalanceProposal = nil } }
        )
    }
}
