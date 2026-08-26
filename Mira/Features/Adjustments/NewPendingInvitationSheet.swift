import SwiftUI

struct NewPendingInvitationSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    @State private var title = ""
    @State private var contact = ""
    @State private var date = DemoClock.standard.now.addingDays(7)
    @State private var timeOfDay: TimeOfDayKind = .evening
    @State private var hasDeadline = true
    @State private var deadline = DemoClock.standard.now.addingDays(2)

    var body: some View {
        NavigationStack {
            Form {
                Section("誘い") {
                    TextField("例：土曜にご飯", text: $title)
                    TextField("相手（任意）", text: $contact)
                }
                .listRowBackground(palette.surface)

                Section("候補") {
                    DatePicker("候補日", selection: $date, displayedComponents: .date)
                    Picker("時間帯", selection: $timeOfDay) {
                        ForEach(TimeOfDayKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(palette.surface)

                Section {
                    Toggle("返事期限を設定", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("返事期限", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                    }
                } footer: {
                    Text("その場でYESを出さず、一度ここへ置いて余白への影響を確認できます。")
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("検討中に置く")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        store.createPendingInvitation(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            contact: contact,
                            candidateDate: date,
                            timeOfDay: timeOfDay,
                            deadline: hasDeadline ? deadline : nil
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(palette.accent)
    }
}
