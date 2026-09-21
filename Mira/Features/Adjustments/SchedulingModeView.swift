import SwiftUI

struct SchedulingModeView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    @State private var pendingConflictCandidate: CandidateRecommendation?
    @State private var showDetailedTime = false
    @State private var showDiscardConfirmation = false
    @State private var showSaveReview = false
    @State private var saveConflicts: [String] = []
    @State private var saveReviewContext: ScheduleReviewContext?

    private var calendar: Calendar {
        var value = Calendar.mira
        value.firstWeekday = store.weekStartDay.calendarFirstWeekday
        return value
    }

    var body: some View {
        NavigationStack {
            if let draft = store.activeSchedulingDraft {
                ScrollView {
                    VStack(spacing: MiraSpacing.md) {
                        conditionCard(draft)
                        monthHeader(draft)
                        legend
                        schedulingGrid(draft)
                        selectedSummary(draft)
                    }
                    .padding(.bottom, 120)
                }
                .miraScreenBackground(palette)
                .safeAreaInset(edge: .bottom) {
                    bottomAction(draft)
                }
                .navigationTitle("日程を探す")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("保存して閉じる") {
                            if store.persistDraftArchive() {
                                store.activeSchedulingDraft = nil
                                dismiss()
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("下書きを削除", role: .destructive) { showDiscardConfirmation = true }
                        } label: {
                            Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("下書きの操作")
                    }
                }
                .alert("日程候補の下書きを削除しますか？", isPresented: $showDiscardConfirmation) {
                    Button("削除", role: .destructive) {
                        store.discardSavedDraft(id: draft.id)
                        dismiss()
                    }
                    Button("続ける", role: .cancel) {}
                } message: {
                    Text("仮押さえ済みの候補や確定予定は変わりません。")
                }
                .confirmationDialog(
                    "この候補、ちょっと気になるにゃ",
                    isPresented: Binding(
                        get: { pendingConflictCandidate != nil },
                        set: { if !$0 { pendingConflictCandidate = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("それでも候補に追加") {
                        if let pendingConflictCandidate {
                            store.toggleSchedulingCandidate(pendingConflictCandidate.id, allowConflict: true)
                        }
                        pendingConflictCandidate = nil
                    }
                    Button("別の候補にする", role: .cancel) {
                        pendingConflictCandidate = nil
                    }
                } message: {
                    Text(pendingConflictCandidate?.conflicts.joined(separator: "。") ?? "")
                }
                .confirmationDialog("候補の重なりを確認", isPresented: $showSaveReview, titleVisibility: .visible) {
                    Button("重複を承認して候補を保存") {
                        if store.commitSchedulingDraft(approvedContext: saveReviewContext) { dismiss() }
                    }
                    Button("候補を見直す", role: .cancel) {}
                } message: {
                    Text(saveConflicts.joined(separator: "\n") + "\nこの候補を仮押さえします。確定するときも影響を確認できます。")
                }
            } else {
                ContentUnavailableView("調整内容がありません", systemImage: "calendar.badge.questionmark")
                    .onAppear { dismiss() }
            }
        }
        .tint(palette.accent)
        .interactiveDismissDisabled(store.draftPersistenceIssue != nil)
        .task(id: store.activeSchedulingDraft?.month) {
            if let draft = store.activeSchedulingDraft {
                await store.refreshDeviceHolidays(for: draft.month)
                await store.refreshDeviceCalendar(around: draft.dateRangeStart, through: draft.dateRangeEnd)
                if store.activeSchedulingDraft?.id == draft.id {
                    store.refreshSchedulingRecommendations()
                }
            }
        }
    }

    private func conditionCard(_ draft: SchedulingDraft) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            TextField("予定タイトル", text: titleBinding)
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)
                .textInputAutocapitalization(.never)

            if let person = draft.person, !person.isEmpty {
                Label(person, systemImage: "person.fill")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("所要時間")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                HStack(spacing: 7) {
                    ForEach(DurationBucket.allCases) { duration in
                        conditionChip(
                            title: duration.title,
                            selected: draft.durationBucket == duration,
                            inferred: draft.inferredFields.contains("duration") && draft.durationBucket == duration
                        ) {
                            store.updateSchedulingDraft(duration: duration)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("行ける時間帯（複数選択）")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                FlowLayout(spacing: 7) {
                    ForEach(draft.durationBucket.selectableBands) { band in
                        conditionChip(
                            title: band.title,
                            symbol: band.symbolName,
                            selected: draft.timeBands.contains(band),
                            inferred: draft.inferredFields.contains("timeBands") && draft.timeBands.contains(band)
                        ) {
                            var value = draft.timeBands
                            if value.contains(band) {
                                value.removeAll { $0 == band }
                            } else {
                                value.append(band)
                            }
                            store.updateSchedulingDraft(timeBands: value)
                        }
                    }
                }
            }

            Divider().overlay(palette.primaryText.opacity(0.08))

            HStack {
                Button {
                    store.clearRecommendedSchedulingCandidates()
                } label: {
                    Label("おすすめをすべて外す", systemImage: "sparkles.slash")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 36)
                }
                .foregroundStyle(palette.secondaryText)

                Spacer()

                Button {
                    showDetailedTime.toggle()
                    var value = draft
                    value.detailedTimeEnabled = showDetailedTime
                    if showDetailedTime, value.detailedStartHour == nil {
                        value.detailedStartHour = 19
                        value.detailedStartMinute = 0
                    }
                    store.activeSchedulingDraft = value
                } label: {
                    Label("時間を細かく指定", systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 36)
                }
                .foregroundStyle(palette.accent)
            }

            if draft.detailedTimeEnabled {
                DatePicker(
                    "開始時刻",
                    selection: detailedTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .font(.subheadline)
            }
        }
        .miraCard(palette)
        .padding(.horizontal, MiraSpacing.md)
        .padding(.top, MiraSpacing.sm)
    }

    private func conditionChip(
        title: String,
        symbol: String? = nil,
        selected: Bool,
        inferred: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                if inferred {
                    Text("推定")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(selected ? Color.white.opacity(0.2) : palette.warning.opacity(0.16), in: Capsule())
                }
            }
            .foregroundStyle(selected ? palette.onAccent : palette.primaryText)
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(selected ? palette.accent : palette.surface, in: Capsule())
            .overlay {
                Capsule().stroke(selected ? Color.clear : palette.primaryText.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(MiraPressStyle())
    }

    private func monthHeader(_ draft: SchedulingDraft) -> some View {
        HStack {
            Button {
                store.updateSchedulingDraft(month: draft.month.addingMonths(-1))
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("前の月")

            Spacer()
            VStack(spacing: 2) {
                Text(draft.month.japaneseMonthTitle)
                    .font(.title3.bold())
                    .foregroundStyle(palette.primaryText)
                Text("Miraの案を添削するだけ")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()

            Button {
                store.updateSchedulingDraft(month: draft.month.addingMonths(1))
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("次の月")
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, MiraSpacing.md)
    }

    private var legend: some View {
        HStack(spacing: MiraSpacing.md) {
            legendItem("おすすめ", fill: palette.accent, symbol: "sparkles")
            legendItem("選択可", fill: palette.surface, symbol: "circle")
            legendItem("要確認", fill: palette.warning.opacity(0.18), symbol: "exclamationmark.triangle")
        }
        .padding(.horizontal, MiraSpacing.md)
    }

    private func legendItem(_ title: String, fill: Color, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption2)
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(palette.secondaryText)
    }

    private func schedulingGrid(_ draft: SchedulingDraft) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(store.weekStartDay.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(weekdayColor(for: index))
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(palette.primaryText.opacity(0.10)).frame(height: 0.5)
            }

            let rows = stride(from: 0, to: calendarCells(for: draft.month).count, by: 7).map {
                Array(calendarCells(for: draft.month)[$0..<min($0 + 7, calendarCells(for: draft.month).count)])
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, date in
                        schedulingDayCell(date, draft: draft)
                    }
                }
            }
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: palette.isCatSkin ? palette.cardRadius : 0, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: palette.isCatSkin ? palette.cardRadius : 0, style: .continuous)
                .stroke(palette.isCatSkin ? palette.cardBorder : palette.primaryText.opacity(0.10), lineWidth: palette.isCatSkin ? 1 : 0.5)
        }
        .padding(.horizontal, palette.isCatSkin ? MiraSpacing.sm : 0)
    }

    private func schedulingDayCell(_ date: Date, draft: SchedulingDraft) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: draft.month, toGranularity: .month)
        let dayRecommendations = draft.recommendations.filter {
            calendar.isDate($0.day, inSameDayAs: date) && draft.timeBands.contains($0.timeBand)
        }
        let dayItems = store.items.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
        let holiday = store.deviceHolidays.first { calendar.isDate($0.date, inSameDayAs: date) }

        return VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: date))")
                .font(.caption.weight(isCurrentMonth ? .semibold : .regular))
                .foregroundStyle(isCurrentMonth ? palette.primaryText : palette.secondaryText.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                if let holiday {
                    Text(holiday.title)
                        .foregroundStyle(palette.critical)
                }
                ForEach(dayItems.prefix(2)) { item in
                    Text(item.title)
                        .foregroundStyle(palette.primaryText)
                        .padding(.horizontal, 2)
                        .background(palette.color(for: item).opacity(0.72), in: RoundedRectangle(cornerRadius: 2))
                }
                if dayItems.count > 2 {
                    Text("ほか\(dayItems.count - 2)件")
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .font(.system(size: 7.5, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 25, alignment: .topLeading)

            ForEach(draft.timeBands) { band in
                if let candidate = dayRecommendations.first(where: { $0.timeBand == band }) {
                    candidateButton(candidate, selected: draft.selectedRecommendationIDs.contains(candidate.id))
                } else {
                    Color.clear.frame(height: 24)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .top)
        .opacity(isCurrentMonth ? 1 : 0.4)
        .overlay(alignment: .trailing) {
            Rectangle().fill(palette.primaryText.opacity(0.08)).frame(width: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.primaryText.opacity(0.08)).frame(height: 0.5)
        }
    }

    private func candidateButton(_ candidate: CandidateRecommendation, selected: Bool) -> some View {
        Button {
            if !candidate.conflicts.isEmpty, !selected {
                pendingConflictCandidate = candidate
            } else {
                store.toggleSchedulingCandidate(candidate.id, allowConflict: true)
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: candidate.timeBand.symbolName)
                    .font(.system(size: 8, weight: .bold))
                if candidate.isRecommended {
                    Image(systemName: "sparkles")
                        .font(.system(size: 6, weight: .bold))
                }
                if !candidate.conflicts.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 6, weight: .bold))
                }
            }
            .foregroundStyle(selected ? palette.onAccent : candidate.conflicts.isEmpty ? palette.primaryText : palette.warning)
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(
                selected
                    ? palette.accent
                    : candidate.isRecommended
                        ? palette.accentSoft
                        : candidate.conflicts.isEmpty
                            ? palette.elevatedBackground
                            : palette.warning.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay {
                if candidate.isRecommended && !selected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(palette.accent, lineWidth: 1)
                }
            }
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("\(candidate.day.japaneseShortDate) \(candidate.timeBand.title)" + (candidate.isRecommended ? " おすすめ" : ""))
        .accessibilityValue(selected ? "選択済み" : candidate.conflicts.isEmpty ? "選択可能" : "要確認")
    }

    private func selectedSummary(_ draft: SchedulingDraft) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            HStack {
                Text("選んだ候補")
                    .font(.headline)
                Spacer()
                Text("\(draft.selectedRecommendations.count)件")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(palette.accent)
            }

            if draft.selectedRecommendations.isEmpty {
                Text("カレンダーの時間帯ボタンを押して候補を追加できます。")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(draft.selectedRecommendations.sorted(by: candidateSort)) { candidate in
                    HStack {
                        Image(systemName: candidate.isRecommended ? "sparkles" : "calendar")
                            .foregroundStyle(candidate.isRecommended ? palette.accent : palette.secondaryText)
                        Text("\(candidate.day.japaneseShortDate)  \(candidate.timeBand.title)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if !candidate.conflicts.isEmpty {
                            Text("要確認")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(palette.warning)
                        }
                    }
                }
            }
        }
        .miraCard(palette)
        .padding(.horizontal, MiraSpacing.md)
    }

    private func bottomAction(_ draft: SchedulingDraft) -> some View {
        VStack(spacing: MiraSpacing.xs) {
            if let first = draft.selectedRecommendations.sorted(by: candidateSort).first {
                Text("第一候補：\(first.day.japaneseShortDate) \(first.timeBand.title)")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            PrimaryButton(
                title: "この\(draft.selectedRecommendations.count)候補でOK",
                symbol: "checkmark",
                palette: palette,
                isDisabled: draft.selectedRecommendations.isEmpty
            ) {
                saveConflicts = store.schedulingDraftConflicts()
                if saveConflicts.isEmpty {
                    if store.commitSchedulingDraft() { dismiss() }
                } else {
                    saveReviewContext = store.scheduleReviewContext()
                    showSaveReview = true
                }
            }
        }
        .padding(.horizontal, MiraSpacing.md)
        .padding(.top, MiraSpacing.sm)
        .padding(.bottom, MiraSpacing.xs)
        .background {
            if palette.isCatSkin {
                palette.surface
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { store.activeSchedulingDraft?.title ?? "" },
            set: { newValue in
                guard var draft = store.activeSchedulingDraft else { return }
                draft.title = newValue
                store.activeSchedulingDraft = draft
            }
        )
    }

    private var detailedTimeBinding: Binding<Date> {
        Binding(
            get: {
                let draft = store.activeSchedulingDraft
                return store.now.setting(hour: draft?.detailedStartHour ?? 19, minute: draft?.detailedStartMinute ?? 0)
            },
            set: { value in
                guard var draft = store.activeSchedulingDraft else { return }
                draft.detailedStartHour = calendar.component(.hour, from: value)
                draft.detailedStartMinute = calendar.component(.minute, from: value)
                draft.detailedTimeEnabled = true
                store.activeSchedulingDraft = draft
            }
        )
    }

    private func calendarCells(for month: Date) -> [Date] {
        let first = MonthKey(date: month).firstDay
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let start = first.addingDays(-leading)
        return (0..<42).map { start.addingDays($0) }
    }

    private func candidateSort(_ lhs: CandidateRecommendation, _ rhs: CandidateRecommendation) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        return lhs.timeBand.rawValue < rhs.timeBand.rawValue
    }

    private func weekdayColor(for index: Int) -> Color {
        let weekday = (calendar.firstWeekday - 1 + index) % 7 + 1
        switch weekday {
        case 1: return palette.critical
        case 7: return palette.accent
        default: return palette.secondaryText
        }
    }
}
