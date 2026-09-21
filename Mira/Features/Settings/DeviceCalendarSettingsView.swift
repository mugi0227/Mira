import EventKit
import EventKitUI
import SwiftUI
import UIKit

struct DeviceCalendarSettingsView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.openURL) private var openURL
    let palette: MiraThemePalette
    @State private var isChangingConnection = false
    @State private var authorizationStatus = EKEventStore.authorizationStatus(for: .event)

    var body: some View {
        Form {
            Section {
                Toggle("iPhoneの予定を確認する", isOn: Binding(
                    get: { store.deviceCalendarService.enabled },
                    set: { value in
                        guard !isChangingConnection else { return }
                        isChangingConnection = true
                        Task {
                            await store.setCalendarConnectionEnabled(value)
                            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                            isChangingConnection = false
                        }
                    }
                ))
                .disabled(isChangingConnection)
                if isChangingConnection { ProgressView("カレンダーの接続を確認中…") }
            } footer: {
                Text("選んだカレンダーを読み込み、余白や重複の確認に使います。クラウドの入力補助へカレンダー全体を送ることはありません。")
            }
            if store.demoModeEnabled {
                Text("デモ中は実際の予定を読み込みません。設定で「日常の日時を使う」に切り替えてください。")
            }
            if authorizationStatus == .denied || authorizationStatus == .restricted || authorizationStatus == .writeOnly {
                Section {
                    Button("設定アプリでカレンダーの権限を確認") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .frame(minHeight: 44)
                } footer: {
                    Text("予定を読み込むには、Miraのカレンダーへのフルアクセスが必要です。")
                }
            }
            if store.deviceCalendarService.enabled && store.deviceCalendarService.hasAccess {
                Section("読み込むカレンダー") {
                    ForEach(store.deviceCalendarService.calendars) { calendar in
                        Toggle(calendar.title, isOn: Binding(
                            get: { store.deviceCalendarService.selectedIDs.contains(calendar.id) },
                            set: { selected in
                                if selected { store.deviceCalendarService.selectedIDs.insert(calendar.id) }
                                else { store.deviceCalendarService.selectedIDs.remove(calendar.id) }
                                Task { await store.refreshDeviceCalendar() }
                            }
                        ))
                    }
                }
                Section {
                    Picker("予定を書き出す先", selection: Binding(
                        get: {
                            let saved = store.deviceCalendarService.destinationID
                            return store.deviceCalendarService.calendars.contains(where: { $0.id == saved && $0.canWrite }) ? saved : ""
                        },
                        set: { store.deviceCalendarService.destinationID = $0 }
                    )) {
                        Text("選んでください").tag("")
                        ForEach(store.deviceCalendarService.calendars.filter(\.canWrite)) { calendar in
                            Text(calendar.title).tag(calendar.id)
                        }
                    }
                } footer: {
                    Text("Miraで作った予定は、詳細画面の「iPhoneカレンダーに保存」で書き出せます。余白や検討中の誘いは書き出しません。外部の予定の編集・削除はiPhoneのカレンダー編集画面で行います。")
                }
                Button("予定を更新") { Task { await store.refreshDeviceCalendar() } }
                    .disabled(store.isSyncingCalendar)
            }
            if let status = store.calendarSyncStatus {
                Text(status).font(.subheadline).foregroundStyle(palette.secondaryText)
            }
        }
        .navigationTitle("カレンダー接続")
        .miraFormStyle(palette)
        .task { await store.refreshDeviceCalendar() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
}

struct DeviceCalendarActionView: View {
    @Environment(MiraStore.self) private var store
    let item: CalendarItemSnapshot
    let palette: MiraThemePalette
    @State private var editingEvent: EKEvent?
    @State private var isEditorPresented = false

    private var current: CalendarItemSnapshot { store.items.first { $0.id == item.id } ?? item }

    var body: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            if let reference = current.deviceEvent {
                Label("iPhoneカレンダーの予定", systemImage: "calendar.badge.checkmark")
                Text("変更と削除はカレンダー編集画面に反映されます。繰り返す予定は変更する範囲をそこで選べます。")
                    .font(.caption).foregroundStyle(palette.secondaryText)
                Button("カレンダーで編集") {
                    editingEvent = store.deviceCalendarService.event(for: reference)
                    if editingEvent != nil { isEditorPresented = true }
                    else { store.toast = "予定を取得できません。カレンダー接続を確認してください。" }
                }
                .frame(minHeight: 44)
            } else if !store.demoModeEnabled && current.kind == .confirmed {
                if store.deviceCalendarService.enabled,
                   store.deviceCalendarService.hasAccess,
                   store.deviceCalendarService.calendars.contains(where: { $0.id == store.deviceCalendarService.destinationID && $0.canWrite }) {
                    Button("iPhoneカレンダーに保存") { store.exportToDeviceCalendar(current) }
                        .frame(minHeight: 44)
                    Text("選んだ保存先へ、この予定を一件登録します。")
                        .font(.caption).foregroundStyle(palette.secondaryText)
                } else {
                    NavigationLink(store.deviceCalendarService.enabled ? "カレンダーの保存先を設定" : "iPhoneのカレンダーを接続") {
                        DeviceCalendarSettingsView(palette: palette)
                    }
                        .frame(minHeight: 44)
                }
            }
        }
        .foregroundStyle(palette.primaryText)
        .sheet(isPresented: $isEditorPresented, onDismiss: {
            Task { await store.refreshDeviceCalendar(around: current.startDate, through: current.endDate) }
        }) {
            if let editingEvent {
                DeviceEventEditor(eventStore: store.deviceCalendarService.eventStore, event: editingEvent)
            }
        }
    }
}

private struct DeviceEventEditor: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let eventStore: EKEventStore
    let event: EKEvent

    func makeCoordinator() -> Coordinator { Coordinator(onDone: { dismiss() }) }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = eventStore
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
