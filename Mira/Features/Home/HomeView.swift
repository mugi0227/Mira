import SwiftUI

struct HomeView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let palette: MiraThemePalette

    @State private var showAddSheet = false
    @State private var selectedItem: CalendarItemSnapshot?
    @State private var selectedDayDestination: DayTimelineDestination?
    @FocusState private var isQuickInputFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: palette.isCatSkin ? MiraSpacing.sm : MiraSpacing.lg) {
                monthHeader
                    .padding(.horizontal, MiraSpacing.md)

                progressSummary
                    .padding(.horizontal, MiraSpacing.md)

                MiraQuickInputBar(palette: palette, isFocused: $isQuickInputFocused)
                    .padding(.horizontal, MiraSpacing.md)

                if store.assistantEnabled {
                    AssistantCard(message: store.currentAssistantMessage, palette: palette) {
                        if store.activeRebalanceProposal != nil {
                            store.isRebalanceProposalPresented = true
                        } else {
                            store.autoPlaceMargins(for: store.selectedMonth)
                        }
                    }
                    .padding(.horizontal, MiraSpacing.md)
                }

                MonthCalendarGrid(
                    month: store.selectedMonth,
                    selectedDate: Binding(
                        get: { store.selectedDate },
                        set: { store.selectedDate = $0 }
                    ),
                    items: monthItems,
                    palette: palette,
                    weekStartDay: store.weekStartDay,
                    holidays: store.deviceHolidays,
                    referenceDate: store.now,
                    onMoveItem: { id, date in store.moveItem(id: id, to: date) },
                    onSelectDate: openDay,
                    onSelectItem: { selectedItem = $0 }
                )
                .padding(.horizontal, palette.isCatSkin ? MiraSpacing.xs : 0)
            }
            .padding(.top, MiraSpacing.sm)
            .padding(.bottom, palette.isCatSkin ? MiraSpacing.md : 104)
            .contentShape(Rectangle())
            .onTapGesture {
                isQuickInputFocused = false
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .miraScreenBackground(palette)
        .navigationTitle("余白")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(palette.isCatSkin ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            if !palette.isCatSkin {
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NewItemSheet(palette: palette, initialDate: store.selectedDate)
        }
        .sheet(item: $selectedItem) { item in
            EventDetailSheet(item: item, palette: palette)
        }
        .navigationDestination(item: $selectedDayDestination) { destination in
            DayTimelineView(date: destination.date, palette: palette)
        }
        .task(id: MonthKey(date: store.selectedMonth)) {
            await store.refreshDeviceHolidays(for: store.selectedMonth)
        }
    }

    private var monthItems: [CalendarItemSnapshot] {
        let interval = MonthKey(date: store.selectedMonth).interval
        return store.items.filter { interval.contains($0.startDate) }
    }

    @ViewBuilder
    private var monthHeader: some View {
        if palette.isCatSkin {
            skyMonthHeader
        } else {
            standardMonthHeader
        }
    }

    private var standardMonthHeader: some View {
        HStack {
            Button {
                withAnimation(MiraMotion.standard) {
                    store.selectedMonth = store.selectedMonth.addingMonths(-1)
                    store.selectedDate = MonthKey(date: store.selectedMonth).firstDay
                    store.updateMarginRecommendation(for: store.selectedMonth)
                    store.recalculateBalance(for: store.selectedMonth)
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
                    store.updateMarginRecommendation(for: store.selectedMonth)
                    store.recalculateBalance(for: store.selectedMonth)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("次の月")
        }
        .foregroundStyle(palette.accent)
    }

    private var skyMonthHeader: some View {
        HStack(spacing: 4) {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .frame(width: 44, height: 44)
                    .background(palette.surface.opacity(0.7), in: Circle())
            }
            .accessibilityLabel("前の月")

            VStack(spacing: 4) {
                Text(store.selectedMonth.japaneseMonthTitle)
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("やさしい毎日を、つくろう")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("次の月")

            addMenu
                .background(alignment: .bottomLeading) {
                    MiraBotanicalAccent(palette: palette)
                        .frame(width: 45, height: 60)
                        .offset(x: -20, y: 8)
                }
        }
        .foregroundStyle(palette.accent)
        .buttonStyle(MiraPressStyle())
        .padding(.vertical, 4)
    }

    private var addMenu: some View {
        Menu {
            Button { showAddSheet = true } label: {
                Label("予定・余白を追加", systemImage: "plus")
            }
            Button { store.startManualScheduling() } label: {
                Label("日程を探す", systemImage: "calendar.badge.clock")
            }
        } label: {
            Image(systemName: "plus")
                .font(palette.isCatSkin ? .system(size: 28, weight: .regular) : .body)
                .foregroundStyle(palette.isCatSkin ? palette.onAccent : palette.accent)
                .frame(width: palette.isCatSkin ? 52 : 44, height: palette.isCatSkin ? 52 : 44)
                .background {
                    if palette.isCatSkin {
                        Circle().fill(palette.actionGradient)
                            .overlay { Circle().strokeBorder(palette.cardBorder, lineWidth: 2) }
                            .shadow(color: palette.shadow, radius: 10, y: 4)
                    }
                }
        }
        .accessibilityLabel("追加メニュー")
    }

    private func changeMonth(by offset: Int) {
        withAnimation(reduceMotion ? nil : MiraMotion.standard) {
            store.selectedMonth = store.selectedMonth.addingMonths(offset)
            store.selectedDate = MonthKey(date: store.selectedMonth).firstDay
            store.ensurePlan(for: store.selectedMonth)
            store.updateMarginRecommendation(for: store.selectedMonth)
            store.recalculateBalance(for: store.selectedMonth)
        }
    }

    @ViewBuilder
    private var progressSummary: some View {
        let visibleGoals = store.currentMonthGoals.filter { [.rest, .reading, .importantPeople].contains($0.kind) }
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
        let values = store.selectedDayItems.filter { $0.kind != .birthday }
        guard let maxLoad = values.map(\.loadClass).max() else { return "今日はまだ余裕があります" }
        switch maxLoad {
        case .light: return "軽めの日"
        case .normal: return "ほどよい予定量"
        case .heavy: return "少し重めの日"
        case .veryHeavy: return "回復時間もほしい日"
        }
    }

    private func openDay(_ date: Date) {
        isQuickInputFocused = false
        store.selectedDate = date
        if !Calendar.mira.isDate(date, equalTo: store.selectedMonth, toGranularity: .month) {
            store.selectedMonth = MonthKey(date: date).firstDay
            store.ensurePlan(for: date)
            store.updateMarginRecommendation(for: date)
            store.recalculateBalance(for: date)
        }
        selectedDayDestination = DayTimelineDestination(date: date)
    }

    private func shortTitle(_ kind: MarginKind) -> String {
        switch kind {
        case .rest: "休息"
        case .reading: "読書・映像"
        case .importantPeople: "大切な時間"
        default: kind.title
        }
    }
}

private struct AssistantCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(MiraStore.self) private var store
    let message: AssistantMessage
    let palette: MiraThemePalette
    let action: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: MiraSpacing.sm)) : AnyLayout(HStackLayout(spacing: MiraSpacing.md))
        layout {
            if store.theme == .pixelCat {
                PixelCatView(mood: message.mood, size: 88)
                    .background(palette.accentSoft.opacity(0.3), in: Circle())
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
                    Button(action: action) {
                        HStack(spacing: 8) {
                            Text(actionTitle)
                                .fixedSize(horizontal: false, vertical: true)
                            if palette.isCatSkin {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, palette.isCatSkin ? 14 : 0)
                        .frame(minHeight: 44)
                        .background(palette.isCatSkin ? palette.accentSoft.opacity(0.85) : .clear, in: Capsule())
                    }
                    .buttonStyle(MiraPressStyle())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, palette.isCatSkin ? 4 : 0)
        .background {
            if palette.isCatSkin { MiraCompanionBackdrop(palette: palette) }
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
                Text(item.timeDescription)
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
        return item.exactTimeKnown ? "calendar" : "clock.badge.questionmark"
    }
}
