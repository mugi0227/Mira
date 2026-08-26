import SwiftUI

struct MarginsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var selectedGoal: MarginGoalSnapshot?
    @State private var showAddMargin = false
    @State private var showBaseRulesEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: MiraSpacing.lg) {
                monthPicker
                overviewCard
                goalsSection
                baseRulesCard
                futureMonthCard
            }
            .padding(.horizontal, MiraSpacing.md)
            .padding(.top, MiraSpacing.sm)
            .padding(.bottom, 104)
        }
        .background(palette.background)
        .navigationTitle("マイ余白")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddMargin = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("余白を追加")
            }
        }
        .sheet(item: $selectedGoal) { goal in
            GoalEditorSheet(goal: goal, palette: palette)
        }
        .sheet(isPresented: $showAddMargin) {
            NewItemSheet(palette: palette, initialDate: store.selectedDate)
        }
        .sheet(isPresented: $showBaseRulesEditor) {
            BaseRulesEditorSheet(initialRules: store.fetchBaseRules(), palette: palette)
        }
    }

    private var monthPicker: some View {
        HStack {
            Button {
                store.selectedMonth = store.selectedMonth.addingMonths(-1)
                store.selectedDate = MonthKey(date: store.selectedMonth).firstDay
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("前の月")

            Spacer()
            VStack(spacing: 2) {
                Text(store.selectedMonth.japaneseMonthTitle)
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                Text("この月に残したい時間")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()

            Button {
                store.selectedMonth = store.selectedMonth.addingMonths(1)
                store.selectedDate = MonthKey(date: store.selectedMonth).firstDay
                store.ensurePlan(for: store.selectedMonth)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("次の月")
        }
        .foregroundStyle(palette.accent)
    }

    private var overviewCard: some View {
        HStack(spacing: MiraSpacing.md) {
            if store.theme == .pixelCat {
                PixelCatView(mood: overallMood, size: 72)
            } else {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(palette.accent)
                    .frame(width: 72)
            }

            VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                Text(overallTitle)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                Text(overallMessage)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("おすすめ配置を更新") {
                    store.autoPlaceMargins(for: store.selectedMonth)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(minHeight: 36)
            }
            Spacer(minLength: 0)
        }
        .miraCard(palette)
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            HStack {
                Text("今月の目標")
                    .font(.title3.bold())
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text("優先度順")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            ForEach(store.currentMonthGoals) { goal in
                Button {
                    selectedGoal = goal
                } label: {
                    GoalRow(goal: goal, palette: palette)
                }
                .buttonStyle(MiraPressStyle())
            }
        }
    }

    private var baseRulesCard: some View {
        Button {
            showBaseRulesEditor = true
        } label: {
            HStack(alignment: .top, spacing: MiraSpacing.sm) {
                Image(systemName: "lock.clock.fill")
                    .font(.title3)
                    .foregroundStyle(palette.accent)
                    .frame(width: 44, height: 44)
                    .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.small))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("普段は予定を置かない時間")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text(baseRulesSummary)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("タップして曜日ごとに変更")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(palette.secondaryText)
                    .padding(.top, 14)
                    .accessibilityHidden(true)
            }
            .miraCard(palette)
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("普段は予定を置かない時間。\(baseRulesSummary)")
        .accessibilityHint("曜日ごとの時間を編集")
    }

    private var futureMonthCard: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Label("未来の自分も守る", systemImage: "calendar.badge.clock")
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            Text("予定を1件でも入れた月は、自動で余白管理の対象になります。急いでいるときは前月設定を仮コピーできます。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
            HStack {
                ForEach(1...3, id: \.self) { offset in
                    let month = store.now.addingMonths(offset)
                    Button(month.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "ja_JP")))) {
                        store.selectedMonth = month
                        store.selectedDate = MonthKey(date: month).firstDay
                        store.ensurePlan(for: month)
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.accent)
                    .frame(minHeight: 44)
                }
            }
        }
        .miraCard(palette)
    }

    private var baseRulesSummary: String {
        let rules = store.fetchBaseRules()
        guard !rules.isEmpty else {
            return "設定なし。どの時間にも余白や候補日を提案できます。"
        }

        let weekdays = Set(rules.map(\.weekday))
        let standardWeekdays = Set(2...6)
        let standardHours = rules.allSatisfy { $0.startMinute == 9 * 60 && $0.endMinute == 18 * 60 }
        if weekdays == standardWeekdays && standardHours {
            return "月〜金 9:00–18:00。余白や候補日はこの時間を避けます。"
        }

        let sorted = AvailabilityRuleDraft.orderedWeekdays.compactMap { weekday in
            rules.first(where: { $0.weekday == weekday })
        }
        let details = sorted.prefix(4).map { rule in
            "\(weekdayTitle(rule.weekday)) \(timeText(rule.startMinute))–\(timeText(rule.endMinute))"
        }
        let remaining = max(0, sorted.count - details.count)
        return details.joined(separator: "・") + (remaining > 0 ? "・ほか\(remaining)日" : "")
    }

    private func weekdayTitle(_ weekday: Int) -> String {
        switch weekday {
        case 1: "日"
        case 2: "月"
        case 3: "火"
        case 4: "水"
        case 5: "木"
        case 6: "金"
        case 7: "土"
        default: "?"
        }
    }

    private func timeText(_ minute: Int) -> String {
        String(format: "%d:%02d", minute / 60, minute % 60)
    }

    private var overallMood: CatMood {
        let deficits = store.currentMonthGoals.filter { store.progress(for: $0).current < store.progress(for: $0).target }
        return deficits.isEmpty ? .relaxed : (deficits.count >= 3 ? .thinking : .idle)
    }

    private var overallTitle: String {
        let deficits = store.currentMonthGoals.filter { store.progress(for: $0).current < store.progress(for: $0).target }
        if deficits.isEmpty { return store.theme == .pixelCat ? "ちゃんと守れてるにゃ" : "目標を満たしています" }
        return store.theme == .pixelCat ? "あと少し整えられるにゃ" : "まだ置ける余白があります"
    }

    private var overallMessage: String {
        let missing = store.currentMonthGoals.compactMap { goal -> String? in
            let progress = store.progress(for: goal)
            let difference = max(0, progress.target - progress.current)
            return difference > 0 ? "\(goal.kind.title) \(difference)回" : nil
        }
        if missing.isEmpty { return "予定と自分の時間の両方に、居場所があります。" }
        return "不足：" + missing.prefix(3).joined(separator: "・")
    }
}

private struct GoalRow: View {
    @Environment(MiraStore.self) private var store
    let goal: MarginGoalSnapshot
    let palette: MiraThemePalette

    var body: some View {
        let progress = store.progress(for: goal)
        HStack(spacing: MiraSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous)
                    .fill(goalColor)
                    .frame(width: 48, height: 48)
                Image(systemName: goal.kind.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.kind.title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                HStack(spacing: 6) {
                    ProgressView(value: Double(min(progress.current, progress.target)), total: Double(max(progress.target, 1)))
                        .tint(palette.accent)
                    Text("\(progress.current)/\(progress.target)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(palette.secondaryText)
                .accessibilityHidden(true)
        }
        .miraCard(palette, padding: MiraSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityHint("目標回数を編集")
    }

    private var goalColor: Color {
        switch goal.kind {
        case .rest, .freeEvening, .solo: palette.rest
        case .reading: palette.reading
        case .importantPeople: palette.important
        default: palette.accentSoft
        }
    }
}

private struct GoalEditorSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let goal: MarginGoalSnapshot
    let palette: MiraThemePalette

    @State private var target: Int

    init(goal: MarginGoalSnapshot, palette: MiraThemePalette) {
        self.goal = goal
        self.palette = palette
        _target = State(initialValue: goal.targetCount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: MiraSpacing.md) {
                        Image(systemName: goal.kind.symbolName)
                            .font(.system(size: 30))
                            .foregroundStyle(palette.accent)
                            .frame(width: 52, height: 52)
                            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.small))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.kind.title)
                                .font(.headline)
                            Text("最初は大きめに確保し、必要なときだけ動かします。")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                }
                .listRowBackground(palette.surface)

                Section("この月にほしい回数") {
                    Stepper("\(target)回", value: $target, in: 0...20)
                }
                .listRowBackground(palette.surface)

                Section {
                    Text("0回にすると、この月だけ目標から外れます。翌月の設定はそのまま残ります。")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("余白目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.updateGoal(goal, target: target)
                        dismiss()
                    }
                }
            }
        }
        .tint(palette.accent)
    }
}
