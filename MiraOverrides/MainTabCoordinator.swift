import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    let palette: MiraThemePalette

    @State private var selectedTab: MiraTab = .home
    @State private var keyboardIsVisible = false
    @State private var reminderAdjustment: AdjustmentEntity?
    @State private var reminderInvitation: PendingInvitationEntity?
    @AppStorage("mira.ui.pendingReminderDestination") private var pendingReminderRawValue = ""

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
        .onReceive(NotificationCenter.default.publisher(for: .miraOpenReminder)) { _ in
            Task { await receivePendingReminder() }
        }
        .task(id: store.isReady) {
            if store.isReady { await receivePendingReminder() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await receivePendingReminder() } }
        }
        .task(id: "\(pendingReminderRawValue):\(scenePhase == .active):\(store.isReady)") {
            await openPendingReminderWhenAvailable()
        }
        .sheet(item: Binding(
            get: { store.presentedEventForm },
            set: { store.presentedEventForm = $0 }
        )) { draft in
            NewItemSheet(palette: palette, initialDate: draft.date, draft: draft)
        }
        .sheet(item: $reminderAdjustment) { session in
            AdjustmentDetailSheet(session: session, palette: palette)
                .onAppear { acknowledgeReminder(.init(kind: .adjustment, id: session.id)) }
        }
        .sheet(item: $reminderInvitation) { invitation in
            PendingInvitationDetailSheet(invitation: invitation, palette: palette)
                .onAppear { acknowledgeReminder(.init(kind: .invitation, id: invitation.id)) }
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

    @MainActor
    private func receivePendingReminder() async {
        guard store.isReady,
              let destination = await NotificationService.shared.consumePendingDestination() else { return }
        // Keep the route until the destination actually appears, including across a relaunch.
        pendingReminderRawValue = destination.rawValue
    }

    @MainActor
    private func openPendingReminderWhenAvailable() async {
        guard store.isReady, scenePhase == .active,
              let destination = ReminderDestination(rawValue: pendingReminderRawValue) else { return }
        var announcedWait = false
        while isReminderPresentationBlocked {
            if !announcedWait {
                store.toast = "通知を受け取りました。今の画面を閉じると開きます。"
                announcedWait = true
            }
            do { try await Task.sleep(for: .milliseconds(400)) }
            catch { return }
            guard !Task.isCancelled, scenePhase == .active,
                  pendingReminderRawValue == destination.rawValue else { return }
        }
        guard !Task.isCancelled, pendingReminderRawValue == destination.rawValue else { return }
        selectedTab = .adjustments
        switch destination.kind {
        case .adjustment:
            reminderAdjustment = store.adjustments.first { $0.id == destination.id }
            if reminderAdjustment == nil {
                store.toast = "この日程調整は完了または削除されています。"
                acknowledgeReminder(destination)
            }
        case .invitation:
            reminderInvitation = store.pendingInvitations.first { $0.id == destination.id }
            if reminderInvitation == nil {
                store.toast = "この誘いは完了または削除されています。"
                acknowledgeReminder(destination)
            }
        }
    }

    @MainActor
    private var isReminderPresentationBlocked: Bool {
        if store.activeSchedulingDraft != nil || store.activeClarification != nil ||
            store.activeDeclineDraft != nil || store.pendingChangePreview != nil ||
            store.pendingEventCreationPreview != nil || store.presentedEventForm != nil ||
            (store.isRebalanceProposalPresented && store.activeRebalanceProposal != nil) ||
            reminderAdjustment != nil || reminderInvitation != nil { return true }
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .filter({ $0.activationState == .foregroundActive })
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return true }
        return hasPresentedController(root)
    }

    @MainActor
    private func hasPresentedController(_ controller: UIViewController) -> Bool {
        controller.presentedViewController != nil || controller.isBeingDismissed ||
            controller.children.contains(where: { hasPresentedController($0) })
    }

    private func acknowledgeReminder(_ destination: ReminderDestination) {
        if pendingReminderRawValue == destination.rawValue { pendingReminderRawValue = "" }
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
