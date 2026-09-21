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
    @State private var isReviewing = false
    @State private var preparedEvent: CalendarItemSnapshot?
    @State private var impact: ScheduleImpact = .none
    @State private var liveConflicts: [String] = []
    @State private var projectedGoalDeficits: [MarginKind: Int] = [:]
    @State private var worsenedGoalDeficits: [MarginKind: Int] = [:]
    @State private var alternativeEventDates: [Date] = []
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
            .miraFormStyle(palette)
            .miraScreenBackground(palette)
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
                reviewDialogTitle,
                isPresented: $showImpact,
                titleVisibility: .visible
            ) {
                ForEach(alternativeEventDates.prefix(2), id: \.self) { candidate in
                    Button("予定を \(candidateLabel(candidate)) へずらす") {
                        applyAlternativeDate(candidate)
                    }
                }

                ForEach(impact.relocationCandidates.prefix(2), id: \.self) { candidate in
                    Button("余白を \(candidate.japaneseShortDate) へ移して追加") {
                        selectedRelocationDate = candidate
                        commitPreparedEvent(resolution: .relocate)
                    }
                }

                Button(impact.protectionLevel == .finalDefense ? "今回は例外として追加" : "このまま追加する") {
                    commitPreparedEvent(resolution: .exception)
                }

                if impact.protectionLevel == .finalDefense {
                    Button("今月の目標を見直す") {
                        store.toast = "マイ余白から今月の目標を変更できるにゃ"
                        dismiss()
                    }
                }

                Button("いったん戻る", role: .cancel) {}
            } message: {
                Text(reviewDialogMessage)
            }
            .overlay {
                if isPreparing {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        ProgressView("Miraが予定の影響を確認中…")
                            .padding(MiraSpacing.lg)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MiraRadius.medium))
                    }
                }
            }
        }
        .tint(palette.accent)
        .task(id: secretaryInputKey) {
            guard mode == .event, canSave else {
                resetSecretaryPreview()
                return
            }

            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await refreshSecretaryPreview()
        }
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

            Section {
                secretaryPreview
            } header: {
                Text("Miraの秘書チェック")
            } footer: {
                Text("Miraは予定を一方的に禁止しません。影響と別候補を示したうえで、最後はあなたが決められます。")
            }
            .listRowBackground(palette.surface)
        }
    }

    @ViewBuilder
    private var secretaryPreview: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            HStack(alignment: .top, spacing: MiraSpacing.sm) {
                if store.theme == .pixelCat {
                    PixelCatView(mood: secretaryMood, size: 58)
                } else {
                    Image(systemName: secretarySymbol)
                        .font(.title2)
                        .foregroundStyle(secretaryTint)
                        .frame(width: 58, height: 58)
                        .background(secretaryTint.opacity(0.12), in: RoundedRectangle(cornerRadius: MiraRadius.small))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(secretaryTitle)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text(secretaryBody)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isReviewing {
                HStack(spacing: MiraSpacing.xs) {
                    ProgressView()
                    Text("予定の意味・負荷・余白への影響を見ているにゃ")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                .frame(minHeight: 36)
            } else if preparedEvent != nil {
                if !liveConflicts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(liveConflicts.prefix(3)), id: \.self) { conflict in
                            Label(conflict, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(palette.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(MiraSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: MiraRadius.small))
                }

                if !projectedGoalDeficits.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("この予定を入れた場合の見込み")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)

                        ForEach(projectedGoalDeficits.keys.sorted(by: { $0.defaultPriority > $1.defaultPriority }), id: \.self) { kind in
                            let deficit = projectedGoalDeficits[kind] ?? 0
                            let worsened = worsenedGoalDeficits[kind] != nil
                            HStack(spacing: MiraSpacing.xs) {
                                Image(systemName: kind.symbolName)
                                    .foregroundStyle(worsened ? palette.warning : palette.accent)
                                    .frame(width: 20)
                                Text(kind.title)
                                    .font(.caption)
                                    .foregroundStyle(palette.primaryText)
                                Spacer()
                                Text(worsened ? "この予定で不足 \(deficit)回" : "今月あと \(deficit)回")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(worsened ? palette.warning : palette.secondaryText)
                            }
                        }
                    }
                    .padding(MiraSpacing.sm)
                    .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: MiraRadius.small))
                }

                if let event = preparedEvent {
                    HStack(spacing: MiraSpacing.xs) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(palette.accent)
                        Text("負荷：\(event.loadClass.title)")
                            .font(.caption.weight(.semibold))
                        Text(event.loadReason)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(2)
                    }
                }

                if !alternativeEventDates.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("別候補なら、今の目標を崩しにくいにゃ")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: MiraSpacing.xs) {
                                ForEach(alternativeEventDates, id: \.self) { candidate in
                                    Button {
                                        applyAlternativeDate(candidate)
                                    } label: {
                                        Label(candidateLabel(candidate), systemImage: "sparkles")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .frame(minHeight: 38)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(palette.accent)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var marginFields: some View {
        Group {
            Section("守りたい時間") {
                Picker("種類", selection: $marginKind) {
                    ForEach(MarginKind.userSelectableCases.filter { $0 != .importantPeople }) { kind in
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

    private var secretaryInputKey: String {
        [
            mode.rawValue,
            title,
            String(date.timeIntervalSinceReferenceDate),
            String(startTime.timeIntervalSinceReferenceDate),
            String(endTime.timeIntervalSinceReferenceDate),
            String(isAllDay),
            String(isImportant)
        ].joined(separator: "|")
    }

    private var secretaryTitle: String {
        guard preparedEvent != nil else {
            return "予定を入力すると、一緒に見ておくにゃ"
        }
        if isReviewing { return "ちょっと確認するにゃ" }
        if impact.protectionLevel == .finalDefense {
            return "このままだと大事な余白がなくなるにゃ"
        }
        if liveConflicts.contains(where: { $0.contains("確定予定") }) {
            return "別の予定と重なってるにゃ"
        }
        if liveConflicts.contains(where: { $0.contains("基本的に予定を入れない時間") }) {
            return "いつもの基本時間と重なってるにゃ"
        }
        if !worsenedGoalDeficits.isEmpty {
            return "このままだと目標が遠のきそうだにゃ"
        }
        if liveConflicts.contains(where: { $0.contains("余白") }) {
            return "守ってる余白と重なってるにゃ"
        }
        if !liveConflicts.isEmpty {
            return "この時間、ちょっと気になるにゃ"
        }
        if !projectedGoalDeficits.isEmpty {
            return "今月の目標も一緒に見ておくにゃ"
        }
        return "この予定なら大丈夫そうだにゃ"
    }

    private var secretaryBody: String {
        guard preparedEvent != nil else {
            return "日付や時間を入れると、余白・基本時間・他の予定・月の目標への影響を確認します。"
        }
        if isReviewing {
            return "予定を止めるためではなく、入れた後の生活がどうなるかを見ています。"
        }
        if impact.protectionLevel == .finalDefense {
            return "最後の余白を使います。別日に移す・今回は例外にする・目標を見直す、から選べるにゃ。"
        }
        if !liveConflicts.isEmpty {
            return "重なりはあるけど、追加は禁止しないにゃ。別候補も見つけておいたので、見比べて決めてにゃ。"
        }
        if let first = worsenedGoalDeficits.keys.sorted(by: { $0.defaultPriority > $1.defaultPriority }).first {
            return "\(first.title)が今より不足しそう。別候補なら今の目標を守りやすいにゃ。"
        }
        if !projectedGoalDeficits.isEmpty {
            return "今月はまだ未達の目標があるけど、この予定自体は大きく悪化させなさそうだにゃ。"
        }
        return "今の予定と余白を見た限り、大きな問題はなさそう。楽しんできてにゃ。"
    }

    private var secretaryMood: CatMood {
        if isReviewing { return .thinking }
        if impact.protectionLevel == .finalDefense { return .warning }
        if !liveConflicts.isEmpty || !worsenedGoalDeficits.isEmpty { return .thinking }
        if !projectedGoalDeficits.isEmpty { return .idle }
        return .relaxed
    }

    private var secretarySymbol: String {
        if impact.protectionLevel == .finalDefense { return "exclamationmark.shield.fill" }
        if !liveConflicts.isEmpty || !worsenedGoalDeficits.isEmpty { return "sparkles" }
        return "checkmark.circle.fill"
    }

    private var secretaryTint: Color {
        if impact.protectionLevel == .finalDefense { return palette.critical }
        if !liveConflicts.isEmpty || !worsenedGoalDeficits.isEmpty { return palette.warning }
        return palette.accent
    }

    private var reviewDialogTitle: String {
        if impact.protectionLevel == .finalDefense {
            return "このまま入れると余白がなくなるにゃ"
        }
        if !liveConflicts.isEmpty {
            return "この時間、ちょっと気になるにゃ"
        }
        if !worsenedGoalDeficits.isEmpty {
            return "目標への影響を確認してにゃ"
        }
        return "余白を守りながら追加する？"
    }

    private var reviewDialogMessage: String {
        var messages = Array(liveConflicts.prefix(2))
        if !worsenedGoalDeficits.isEmpty {
            let text = worsenedGoalDeficits.keys
                .sorted(by: { $0.defaultPriority > $1.defaultPriority })
                .prefix(2)
                .map { kind in "\(kind.title)があと\(worsenedGoalDeficits[kind] ?? 0)回不足する見込みです" }
                .joined(separator: "。")
            messages.append(text)
        }
        if !impact.overlappingMargins.isEmpty && !messages.contains(impact.message) {
            messages.append(impact.message)
        }
        if messages.isEmpty {
            messages.append("この予定を追加した場合の影響を確認してください。")
        }
        return messages.joined(separator: "\n")
    }

    @MainActor
    private func refreshSecretaryPreview() async {
        guard let event = await buildDraftEvent() else {
            resetSecretaryPreview()
            return
        }
        guard !Task.isCancelled else { return }

        isReviewing = true
        preparedEvent = event
        let newImpact = store.previewImpact(for: event)
        let newConflicts = store.eventEntryConflicts(for: event)
        let projected = store.projectedGoalDeficits(afterAdding: event)
        let worsened = store.worsenedGoalDeficits(afterAdding: event)
        let alternatives = store.alternativeEventStartDates(for: event)
        guard !Task.isCancelled else { return }

        impact = newImpact
        liveConflicts = newConflicts
        projectedGoalDeficits = projected
        worsenedGoalDeficits = worsened
        alternativeEventDates = alternatives
        isReviewing = false
    }

    @MainActor
    private func save() async {
        if mode == .margin {
            store.addMargin(kind: marginKind, on: date)
            dismiss()
            return
        }

        isPreparing = true
        guard let event = await buildDraftEvent() else {
            isPreparing = false
            return
        }

        preparedEvent = event
        impact = store.previewImpact(for: event)
        liveConflicts = store.eventEntryConflicts(for: event)
        projectedGoalDeficits = store.projectedGoalDeficits(afterAdding: event)
        worsenedGoalDeficits = store.worsenedGoalDeficits(afterAdding: event)
        alternativeEventDates = store.alternativeEventStartDates(for: event)
        isPreparing = false

        let needsExplicitReview = !liveConflicts.isEmpty
            || !impact.overlappingMargins.isEmpty
            || impact.protectionLevel != .flexible
            || !worsenedGoalDeficits.isEmpty

        if needsExplicitReview {
            showImpact = true
        } else {
            store.commitEvent(event)
            dismiss()
        }
    }

    @MainActor
    private func buildDraftEvent() async -> CalendarItemSnapshot? {
        guard mode == .event, canSave else { return nil }

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

        return await store.prepareEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            isImportant: isImportant
        )
    }

    private func applyAlternativeDate(_ candidate: Date) {
        date = candidate
        if !isAllDay {
            let duration = max(30 * 60, endTime.timeIntervalSince(startTime))
            startTime = candidate
            endTime = candidate.addingTimeInterval(duration)
        }
        selectedRelocationDate = nil
    }

    private func candidateLabel(_ candidate: Date) -> String {
        let dateText = candidate.formatted(
            .dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP"))
        )
        if isAllDay { return dateText }
        let timeText = candidate.formatted(
            .dateTime.hour().minute().locale(Locale(identifier: "ja_JP"))
        )
        return "\(dateText) \(timeText)"
    }

    private func resetSecretaryPreview() {
        isReviewing = false
        preparedEvent = nil
        impact = .none
        liveConflicts = []
        projectedGoalDeficits = [:]
        worsenedGoalDeficits = [:]
        alternativeEventDates = []
    }

    private func commitPreparedEvent(resolution: MiraStore.ImpactResolution) {
        guard let preparedEvent else { return }
        store.commitAdvisedEvent(
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
