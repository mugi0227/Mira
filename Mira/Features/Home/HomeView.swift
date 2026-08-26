import SwiftUI

struct HomeView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var showAddSheet = false
    @State private var selectedItem: CalendarItemSnapshot?

    var body: some View {
        ScrollView {
            VStack(spacing: MiraSpacing.lg) {
                monthHeader
                progressSummary
                if store.assistantEnabled {
                    AssistantCard(message: store.currentAssistantMessage, palette: palette) {
                        store.autoPlaceMargins(for: store.selectedMonth)
                    }
                }
                MonthCalendarGrid(
                    month: store.selectedMonth,
                    selectedDate: Binding(
                        get: { store.selectedDate },
                        set: { store.selectedDate = $0 }
                    ),
                    items: monthItems,
                    palette: palette,
                    onMoveItem: { id, date in store.moveItem(id: id, to: date) },
                    onSelectItem: { selectedItem = $0 }
                )
                .miraCard(palette, padding: MiraSpacing.sm)

                selectedDaySection
            }
            .padding(.horizontal, MiraSpacing.md)
            .padding(.top, MiraSpacing.sm)
            .padding(.bottom, 104)
        }
        .background(palette.background)
        .navigationTitle("余白")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("予定または余白を追加")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NewItemSheet(palette: palette, initialDate: store.selectedDate)
        }
        .sheet(item: $selectedItem) { item in
            EventDetailSheet(item: item, palette: palette)
        }
    }

    private var monthItems: [CalendarItemSnapshot] {
        let interval = MonthKey(date: store.selectedMonth).interval
        return store.items.filter { interval.contains($0.startDate) }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation(MiraMotion.standard) {
                    store.selectedMonth = store.selectedMonth.addingMonths(-1)
                    store.selectedDate = MonthKey(date: store.selectedMonth).firstDay
                }
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
                Text(monthItems.filter { $0.kind == .confirmed }.count.description + "件の予定")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()

            Button {
                withAnimation(MiraMotion.standard) {
                    store.selectedMonth = store.selectedMonth.addingMonths(1)
                    store.selectedDate = MonthKey(date: store.selectedMonth).firstDay
                    store.ensurePlan(for: store.selectedMonth)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("次の月")
        }
        .foregroundStyle(palette.accent)
    }

    @ViewBuilder
    private var progressSummary: some View {
        let visibleGoals = store.currentMonthGoals.filter { [.rest, .freeEvening, .importantPeople].contains($0.kind) }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MiraSpacing.xs) {
                ForEach(visibleGoals) { goal in
                    let progress = store.progress(for: goal)
                    ProgressPill(
                        symbol: goal.kind.symbolName,
                        title: shortTitle(goal.kind),
                        current: progress.current,
                        target: progress.target,
                        palette: palette
                    )
                }
            }
        }
        .scrollClipDisabled()
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedDate.japaneseDayTitle)
                        .font(.title3.bold())
                        .foregroundStyle(palette.primaryText)
                    Text(dayLoadSummary)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Button("追加") { showAddSheet = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(minWidth: 60, minHeight: 44)
            }

            if store.selectedDayItems.isEmpty {
                EmptyStateView(
                    symbol: "sparkles",
                    title: "何も入っていない日",
                    message: "予定を増やす前に、余白として守ることもできます。",
                    palette: palette
                )
                .miraCard(palette)
            } else {
                ForEach(store.selectedDayItems) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        AgendaRow(item: item, palette: palette)
                    }
                    .buttonStyle(MiraPressStyle())
                }
            }
        }
    }

    private var dayLoadSummary: String {
        let items = store.selectedDayItems.filter { $0.kind != .birthday }
        guard let maxLoad = items.map(\.loadClass).max() else { return "今日はまだ余裕があります" }
        switch maxLoad {
        case .light: return "軽めの日"
        case .normal: return "ほどよい予定量"
        case .heavy: return "少し重めの日"
        case .veryHeavy: return "回復時間もほしい日"
        }
    }

    private func shortTitle(_ kind: MarginKind) -> String {
        switch kind {
        case .rest: "休息"
        case .freeEvening: "自由な夜"
        case .importantPeople: "大切な時間"
        default: kind.title
        }
    }
}

private struct AssistantCard: View {
    @Environment(MiraStore.self) private var store
    let message: AssistantMessage
    let palette: MiraThemePalette
    let action: () -> Void

    var body: some View {
        HStack(spacing: MiraSpacing.md) {
            if store.theme == .pixelCat {
                PixelCatView(mood: message.mood, size: 70)
            } else {
                Image(systemName: message.mood == .warning ? "exclamationmark.circle.fill" : "leaf.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(message.mood == .warning ? palette.warning : palette.accent)
                    .frame(width: 70)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(message.title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                Text(message.body)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle = message.actionTitle {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(minHeight: 36)
                }
            }
            Spacer(minLength: 0)
        }
        .miraCard(palette)
        .accessibilityElement(children: .contain)
    }
}

private struct AgendaRow: View {
    let item: CalendarItemSnapshot
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            RoundedRectangle(cornerRadius: 3)
                .fill(palette.color(for: item))
                .frame(width: 5, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    if item.isImportantTime {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(palette.important)
                            .accessibilityLabel("大切な人との時間")
                    }
                }
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer()
            Text(item.loadClass.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.loadClass >= .heavy ? palette.warning : palette.secondaryText)
        }
        .miraCard(palette, padding: MiraSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        if item.kind == .margin { return item.marginKind?.symbolName ?? "leaf.fill" }
        if item.kind == .birthday { return "gift.fill" }
        return "calendar"
    }

    private var timeText: String {
        if item.isAllDay { return "終日" }
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return "\(formatter.string(from: item.startDate))–\(formatter.string(from: item.endDate))"
    }
}
