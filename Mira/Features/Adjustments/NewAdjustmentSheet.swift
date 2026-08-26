import SwiftUI

struct NewAdjustmentSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let palette: MiraThemePalette

    @State private var title = ""
    @State private var contact = ""
    @State private var month: Date
    @State private var selectedDates: Set<Date> = []
    @State private var timeOfDay: TimeOfDayKind = .afternoon
    @State private var hasDeadline = true
    @State private var deadline: Date

    init(palette: MiraThemePalette) {
        self.palette = palette
        let base = DemoClock.standard.now
        _month = State(initialValue: base.addingMonths(1))
        _deadline = State(initialValue: base.addingDays(7))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    VStack(spacing: MiraSpacing.sm) {
                        LabeledTextField(label: "予定名", placeholder: "例：カフェに行く", text: $title, palette: palette)
                        LabeledTextField(label: "相手（任意）", placeholder: "例：友達", text: $contact, palette: palette)
                    }
                    .miraCard(palette)

                    CandidateDatePicker(
                        month: $month,
                        selectedDates: $selectedDates,
                        timeOfDay: $timeOfDay,
                        palette: palette
                    )
                    .miraCard(palette)

                    VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                        Toggle("返事期限を設定", isOn: $hasDeadline)
                        if hasDeadline {
                            DatePicker("返事期限", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                        }
                    }
                    .miraCard(palette)

                    if !selectedDates.isEmpty {
                        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                            Label("共有文のプレビュー", systemImage: "message")
                                .font(.headline)
                            Text(previewMessage)
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                                .textSelection(.enabled)
                        }
                        .miraCard(palette)
                    }
                }
                .padding(MiraSpacing.md)
                .padding(.bottom, MiraSpacing.xl)
            }
            .background(palette.background)
            .navigationTitle("日程を調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        store.createAdjustment(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            contact: contact,
                            dates: Array(selectedDates),
                            timeOfDay: timeOfDay,
                            deadline: hasDeadline ? deadline : nil
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedDates.isEmpty)
                }
            }
        }
        .tint(palette.accent)
    }

    private var previewMessage: String {
        let candidates = selectedDates.sorted().map { date -> CandidateSlotSnapshot in
            let hours: (Int, Int)
            switch timeOfDay {
            case .allDay: hours = (9, 21)
            case .morning: hours = (9, 12)
            case .afternoon: hours = (13, 17)
            case .evening: hours = (18, 22)
            }
            return CandidateSlotSnapshot(startDate: date.setting(hour: hours.0), endDate: date.setting(hour: hours.1), timeOfDay: timeOfDay)
        }
        return DemoSeeder.message(title: title.isEmpty ? "予定" : title, candidates: candidates)
    }
}

struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let palette: MiraThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: MiraRadius.small))
                .overlay {
                    RoundedRectangle(cornerRadius: MiraRadius.small)
                        .stroke(palette.primaryText.opacity(0.08))
                }
        }
    }
}
