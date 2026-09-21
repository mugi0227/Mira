import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var selectedTab: MiraTab = .home
    @State private var keyboardIsVisible = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(palette: palette)
            }
            .tabItem { Label("ホーム", systemImage: "calendar") }
            .tag(MiraTab.home)
            .toolbar(palette.isCatSkin ? .hidden : .visible, for: .tabBar)

            NavigationStack {
                AdjustmentsView(palette: palette)
            }
            .tabItem { Label("調整", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") }
            .tag(MiraTab.adjustments)
            .toolbar(palette.isCatSkin ? .hidden : .visible, for: .tabBar)

            NavigationStack {
                MarginsView(palette: palette)
            }
            .tabItem { Label("マイ余白", systemImage: "leaf") }
            .tag(MiraTab.margins)
            .toolbar(palette.isCatSkin ? .hidden : .visible, for: .tabBar)

            NavigationStack {
                SettingsView(palette: palette)
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
            .tag(MiraTab.settings)
            .toolbar(palette.isCatSkin ? .hidden : .visible, for: .tabBar)
        }
        .tint(palette.accent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if palette.isCatSkin && !keyboardIsVisible {
                floatingTabBar
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardIsVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardIsVisible = false
        }
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

    private var floatingTabBar: some View {
        HStack(spacing: 4) {
            ForEach(MiraTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 23, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(tab.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selectedTab == tab ? palette.accent : palette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .padding(.vertical, 2)
                    .background {
                        if selectedTab == tab {
                            Capsule().fill(palette.accentSoft)
                                .overlay { Capsule().strokeBorder(palette.cardBorder, lineWidth: 1) }
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(MiraPressStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                .accessibilityIdentifier("miraTab-\(tab.rawValue)")
            }
        }
        .padding(6)
        .background(palette.elevatedSurface, in: Capsule())
        .overlay { Capsule().strokeBorder(palette.cardBorder, lineWidth: 1.5) }
        .shadow(color: palette.shadow, radius: 20, y: 5)
        .padding(.horizontal, MiraSpacing.md)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            LinearGradient(colors: [palette.background.opacity(0), palette.background], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("miraTabBar")
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
            get: { store.isRebalanceProposalPresented && store.activeRebalanceProposal != nil },
            set: { store.isRebalanceProposalPresented = $0 }
        )
    }
}

private enum MiraTab: String, CaseIterable, Identifiable {
    case home, adjustments, margins, settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: "ホーム"
        case .adjustments: "調整"
        case .margins: "マイ余白"
        case .settings: "設定"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .adjustments: "arrow.trianglehead.2.clockwise.rotate.90"
        case .margins: "leaf.fill"
        case .settings: "gearshape.fill"
        }
    }
}
