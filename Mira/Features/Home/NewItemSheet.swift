import SwiftUI

struct NewItemSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let palette: MiraThemePalette
    let initialDate: Date

    @State private var mode: NewItemMode = .event
    @State private var title = ""
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isAllDay = false
    @State private var isImportant = false
    @State private var marginKind: MarginKind = .rest
    @State private var isPreparing = false
    @State private var preparedEvent: CalendarItemSnapshot?
    @State private var impact: ScheduleImpact = .none
    @State private var showImpact = false
    @State private var selectedRelocationDate: Date?

    init(palette: MiraThemePalette, initialDate: Date) {
        self.palette = palette
        self.initialDate = initialDate
        let start = initialDate.setting(hour: 18)
        _date = State(initialValue: initialDate)
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: start.addingTimeInterval(2 * 3600))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("追加するもの", selection: $mode) {
                    ForEach(NewItemMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(palette.surface)

                if mode == .event {
                    eventFields
                } else {
                    marginFields
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(mode == .event ? "予定を追加" : "余白を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isPreparing)
                }
            }
            .confirmationDialog(
                impact.protectionLevel == .finalDefense ? "最後の余白をどうしますか？" : "余白を守りながら追加しますか？",
                isPresented: $showImpact,
                titleVisibility: .visible
            ) {
                ForEach(impact.relocationCandidates.prefix(3), id: \.self) { candidate in
                    Button("余白を \(candidate.japaneseShortDate) へ移す") {
                        selectedRelocationDate = candidate
                        commitPreparedEvent(resolution: .relocate)
                    }
                }
                Button("今回は例外として追加") {
                    commitPreparedEvent(resolution: .exception)
                }
                if impact.protectionLevel == .finalDefense {
                    Button("目標を見直す") {
                        store.toast = "マイ余白から今月の目標を変更できるにゃ"
                        dismiss()
                    }
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text(impact.message)
            }
            .overlay {
                if isPreparing {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        ProgressView("予定の負荷を確認中…")
                            .padding(MiraSpacing.lg)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MiraRadius.medium))
                    }
                }
            }
        }
        .tint(palette.accent)
    }

    private var eventFields: some View {
        Group {
            Section("予定") {
                TextField("例：友達とご飯", text: $title)
                    .textInputAutocapitalization(.never)
                DatePicker("日付", selection: $date, displayedComponents: .date)
                Toggle("終日", isOn: $isAllDay)
                if !isAllDay {
                    DatePicker("開始", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: $endTime, displayedComponents: .hourAndMinute)
                }
            }
            .listRowBackground(palette.surface)

            Section {
                Toggle("大切な人との時間", isOn: $isImportant)
            } footer: {
                Text("大切さと疲れやすさは別に判定します。")
            }
            .listRowBackground(palette.surface)
        }
    }

    private var marginFields: some View {
        Group {
            Section("守りたい時間") {
                Picker("種類", selection: $marginKind) {
                    ForEach(MarginKind.allCases.filter { $0 != .importantPeople }) { kind in
                        Label(kind.title, systemImage: kind.symbolName).tag(kind)
                    }
                }
                DatePicker("日付", selection: $date, displayedComponents: .date)
            }
            .listRowBackground(palette.surface)

            Section {
                HStack(spacing: MiraSpacing.sm) {
                    Image(systemName: marginKind.symbolName)
                        .font(.title2)
                        .foregroundStyle(palette.accent)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(marginKind.title)
                            .font(.headline)
                        Text("最初は大きめに確保し、必要なときだけ動かします。")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }
            .listRowBackground(palette.surface)
        }
    }

    private var canSave: Bool {
        mode == .margin || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func save() async {
        if mode == .margin {
            store.addMargin(kind: marginKind, on: date)
            dismiss()
            return
        }

        isPreparing = true
        let day = date.startOfDay(calendar: .mira)
        let start: Date
        let end: Date
        if isAllDay {
            start = day.setting(hour: 9)
            end = day.setting(hour: 21)
        } else {
            let startComponents = Calendar.mira.dateComponents([.hour, .minute], from: startTime)
            let endComponents = Calendar.mira.dateComponents([.hour, .minute], from: endTime)
            start = day.setting(hour: startComponents.hour ?? 18, minute: startComponents.minute ?? 0)
            let rawEnd = day.setting(hour: endComponents.hour ?? 20, minute: endComponents.minute ?? 0)
            end = rawEnd > start ? rawEnd : rawEnd.addingTimeInterval(24 * 3600)
        }

        let event = await store.prepareEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            isImportant: isImportant
        )
        preparedEvent = event
        impact = store.previewImpact(for: event)
        isPreparing = false

        if impact.overlappingMargins.isEmpty && impact.protectionLevel == .flexible {
            store.commitEvent(event)
            dismiss()
        } else {
            showImpact = true
        }
    }

    private func commitPreparedEvent(resolution: MiraStore.ImpactResolution) {
        guard let preparedEvent else { return }
        store.commitEvent(
            preparedEvent,
            impact: impact,
            resolution: resolution,
            chosenRelocationDate: selectedRelocationDate
        )
        dismiss()
    }
}

private enum NewItemMode: String, CaseIterable, Identifiable {
    case event
    case margin

    var id: String { rawValue }
    var title: String { self == .event ? "予定" : "余白" }
    var symbol: String { self == .event ? "calendar.badge.plus" : "leaf.fill" }
}
