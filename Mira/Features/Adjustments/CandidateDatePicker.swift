import SwiftUI

struct CandidateDatePicker: View {
    @Environment(MiraStore.self) private var store

    @Binding var month: Date
    @Binding var selectedDates: Set<Date>
    @Binding var timeOfDay: TimeOfDayKind
    let palette: MiraThemePalette
    var excludingSessionID: UUID?

    @State private var pendingOverrideDate: Date?
    @State private var overrideMessage = ""

    private let calendar = Calendar.mira
    private let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        VStack(spacing: MiraSpacing.md) {
            HStack {
                Button {
                    month = month.addingMonths(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("前の月")
                Spacer()
                Text(month.japaneseMonthTitle)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Button {
                    month = month.addingMonths(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("次の月")
            }
            .foregroundStyle(palette.accent)

            Picker("時間帯", selection: $timeOfDay) {
                ForEach(TimeOfDayKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }

            if !selectedDates.isEmpty {
                VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                    Text("選んだ候補日")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                    FlowLayout(spacing: 7) {
                        ForEach(selectedDates.sorted(), id: \.self) { date in
                            Button {
                                selectedDates.remove(date)
                            } label: {
                                Label(date.japaneseShortDate, systemImage: "xmark")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 36)
                                    .background(palette.adjustment, in: Capsule())
                                    .foregroundStyle(palette.primaryText)
                            }
                            .accessibilityLabel("\(date.japaneseShortDate)を候補から外す")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .confirmationDialog("この日、ちょっと気になるにゃ", isPresented: Binding(
            get: { pendingOverrideDate != nil },
            set: { if !$0 { pendingOverrideDate = nil } }
        ), titleVisibility: .visible) {
            Button("それでも候補に追加") {
                if let pendingOverrideDate {
                    selectedDates.insert(pendingOverrideDate)
                }
                pendingOverrideDate = nil
            }
            Button("別の日を選ぶ", role: .cancel) { pendingOverrideDate = nil }
        } message: {
            Text(overrideMessage + "\n候補から外すことをおすすめするけど、最終的には選べるにゃ。")
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 38), spacing: 5), count: 7)
    }

    private var cells: [Date?] {
        let first = MonthKey(date: month).firstDay
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday + 5) % 7
        guard let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        var result = Array<Date?>(repeating: nil, count: leading)
        result.append(contentsOf: range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: first)
        })
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    @ViewBuilder
    private func dayButton(_ date: Date) -> some View {
        let normalized = calendar.startOfDay(for: date)
        let selected = selectedDates.contains(normalized)
        let candidate = makeCandidate(on: normalized)
        let conflicts = store.conflictMessages(for: candidate, excluding: excludingSessionID)
        let hasConfirmedConflict = conflicts.contains("確定予定と重なっています")
        let hasAdjustmentConflict = conflicts.contains("別の日程調整でも候補になっています")
        let hasMarginConflict = conflicts.contains("守っている余白と重なっています")
        let hasBaseRuleConflict = conflicts.contains("基本的に予定を入れない時間と重なっています")
        let needsReview = !conflicts.isEmpty
        let strongConflict = hasConfirmedConflict || hasBaseRuleConflict

        Button {
            if selected {
                selectedDates.remove(normalized)
            } else if needsReview {
                pendingOverrideDate = normalized
                overrideMessage = conflicts.joined(separator: "。") + "。"
            } else {
                selectedDates.insert(normalized)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(selected ? .bold : .medium))
                HStack(spacing: 2) {
                    if hasBaseRuleConflict {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 5.5, weight: .bold))
                            .foregroundStyle(palette.secondaryText)
                    }
                    if hasConfirmedConflict {
                        Circle().fill(palette.critical).frame(width: 4, height: 4)
                    }
                    if hasAdjustmentConflict {
                        Circle().fill(palette.warning).frame(width: 4, height: 4)
                    }
                    if hasMarginConflict {
                        Circle().fill(palette.success).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .foregroundStyle(selected ? Color.white : palette.primaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                selected
                    ? palette.accent
                    : (strongConflict ? palette.critical.opacity(0.06) : palette.surface),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                if needsReview && !selected {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            strongConflict ? palette.critical.opacity(0.72) : palette.warning,
                            style: StrokeStyle(lineWidth: 1, dash: [3, 2])
                        )
                }
            }
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel(accessibilityLabel(date: date, selected: selected, conflicts: conflicts))
        .accessibilityValue(needsReview ? "要確認・選択可能" : "選択可能")
    }

    private func makeCandidate(on date: Date) -> CandidateSlotSnapshot {
        let range: (Int, Int)
        switch timeOfDay {
        case .allDay: range = (9, 21)
        case .morning: range = (9, 12)
        case .afternoon: range = (13, 17)
        case .evening: range = (18, 22)
        }
        return CandidateSlotSnapshot(
            startDate: date.setting(hour: range.0),
            endDate: date.setting(hour: range.1),
            timeOfDay: timeOfDay
        )
    }

    private func accessibilityLabel(date: Date, selected: Bool, conflicts: [String]) -> String {
        var parts = [date.japaneseDayTitle]
        parts.append(selected ? "選択済み" : "未選択")
        parts.append(contentsOf: conflicts)
        if !conflicts.isEmpty {
            parts.append("確認後に選択できます")
        }
        return parts.joined(separator: "、")
    }
}
