import SwiftUI

struct HomeView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let palette: MiraThemePalette

    @State private var selectedItem: CalendarItemSnapshot?
    @State private var selectedDayDestination: DayTimelineDestination?
    @State private var showSavedDrafts = false
    @State private var draftToResume: UUID?
    @State private var showCompanion = false
    @State private var isFriendView = false

    var body: some View {
        ScrollView {
            // The calendar leads; everything else is secondary and sits below
            // it, while talking to Mira lives behind the corner companion.
            VStack(spacing: MiraSpacing.sm) {
                monthHeader
                    .padding(.horizontal, MiraSpacing.md)

                if isFriendView {
                    friendViewBanner
                        .padding(.horizontal, MiraSpacing.md)
                        .transition(.move(edge: .top).combined(with: .opacity))
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
                    allowsDragging: !isFriendView,
                    privacyMode: isFriendView,
                    onMoveItem: { id, date in store.moveItem(id: id, to: date) },
                    onSelectDate: openDay,
                    onSelectItem: { item in if !isFriendView { selectedItem = item } }
                )
                .padding(.horizontal, palette.isCatSkin ? MiraSpacing.xs : 0)

                if !isFriendView {
                    nextStepCard
                        .padding(.horizontal, MiraSpacing.md)
                        .padding(.top, MiraSpacing.xs)

                    progressSummary
                        .padding(.horizontal, MiraSpacing.md)
                }
            }
            .animation(MiraMotion.standard, value: isFriendView)
            .padding(.top, MiraSpacing.xs)
            .padding(.bottom, 96 + floatingTabBarClearance)
        }
        .miraScreenBackground(palette)
        .overlay(alignment: .bottomTrailing) {
            if store.assistantEnabled && !isFriendView {
                MiraCompanionButton(message: store.currentAssistantMessage, palette: palette) {
                    showCompanion = true
                }
                .padding(.trailing, MiraSpacing.md)
                .padding(.bottom, MiraSpacing.sm + floatingTabBarClearance)
            }
        }
        .sheet(isPresented: $showCompanion) {
            MiraChatView(palette: palette)
        }
        .navigationTitle("余白")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(palette.isCatSkin ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            if !palette.isCatSkin {
                ToolbarItem(placement: .topBarLeading) {
                    friendViewButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            EventDetailSheet(item: item, palette: palette)
        }
        .sheet(isPresented: $showSavedDrafts, onDismiss: {
            if let id = draftToResume {
                draftToResume = nil
                store.resumeSavedDraft(id: id)
            }
        }) {
            SavedDraftsSheet(palette: palette) { draftToResume = $0 }
        }
        .navigationDestination(item: $selectedDayDestination) { destination in
            DayTimelineView(date: destination.date, palette: palette)
        }
        .task(id: MonthKey(date: store.selectedMonth)) {
            await store.refreshDeviceHolidays(for: store.selectedMonth)
            await store.refreshDeviceCalendar(around: store.selectedMonth)
        }
    }

    /// The cat skin draws its own floating tab bar over the content instead
    /// of insetting it, so corner controls must lift themselves above it.
    private var floatingTabBarClearance: CGFloat {
        palette.isCatSkin ? 124 : 0
    }

    private var monthItems: [CalendarItemSnapshot] {
        let interval = MonthKey(date: store.selectedMonth).interval
        return store.items.filter { interval.contains($0.startDate) }
    }

    private var nextStepCard: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            if let draft = store.savedDrafts.first {
                HStack {
                    Label("続きからで大丈夫", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                    Spacer()
                    Button("下書き一覧") { showSavedDrafts = true }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }
                Text(draft.content.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(draft.content.nextStep)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                Button {
                    store.resumeSavedDraft(id: draft.id)
                } label: {
                    Label("この続きから", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.small))
                }
                .accessibilityIdentifier("resumeLatestDraft")
            } else if let event = nextEvent {
                Label(event.startDate <= store.now ? "いまの予定" : "次の予定", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                Button {
                    selectedItem = event
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.headline)
                            Text("\(event.startDate.japaneseShortDate) \(event.timeDescription)")
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if event.bufferBeforeMinutes > 0 {
                    Text("支度・移動の余裕：\(event.bufferBeforeMinutes)分")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            } else {
                Label("誘いや思いつきは、右下のMiraへ", systemImage: "leaf")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            if let margin = nextMargin {
                Text("次の余白：\(margin.startDate.japaneseShortDate) \(margin.title)")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .foregroundStyle(palette.primaryText)
        .tint(palette.accent)
        .miraCard(palette, padding: MiraSpacing.sm)
    }

    private var nextEvent: CalendarItemSnapshot? {
        store.items.filter { $0.kind == .confirmed && $0.endDate > store.now }
            .min { $0.startDate < $1.startDate }
    }

    private var nextMargin: CalendarItemSnapshot? {
        store.items.filter { $0.kind == .margin && $0.endDate > store.now }
            .min { $0.startDate < $1.startDate }
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
                friendViewButton
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

    private var friendViewButton: some View {
        Button {
            isFriendView.toggle()
        } label: {
            Label(isFriendView ? "見せる用" : "友だちに見せる", systemImage: isFriendView ? "eye.slash.fill" : "eye")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(isFriendView ? palette.accentSoft : palette.surface.opacity(0.7), in: Capsule())
                .contentShape(Rectangle())
                .frame(minHeight: 44)
        }
        .buttonStyle(MiraPressStyle())
        .foregroundStyle(palette.accent)
        .accessibilityLabel(isFriendView ? "見せる用モードを終える" : "友だちに見せる用の表示にする")
        .accessibilityIdentifier("friendViewToggle")
    }

    private var friendViewBanner: some View {
        HStack(spacing: MiraSpacing.sm) {
            Image(systemName: "eye.slash.fill")
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("見せる用モード")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Text("中身は隠して「予定あり」だけ表示中。空いている日がひと目でわかります。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("戻る") { isFriendView = false }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.accent)
                .frame(minWidth: 44, minHeight: 44)
        }
        .miraCard(palette, padding: MiraSpacing.sm)
    }

    private var addMenu: some View {
        Menu {
            Button { store.presentedEventForm = ManualEventDraft(date: store.selectedDate) } label: {
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
                Button("追加") { store.presentedEventForm = ManualEventDraft(date: store.selectedDate) }
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
        store.selectedDate = date
        // The day timeline shows titles, so friend view stays on the month.
        guard !isFriendView else { return }
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

struct AssistantCard: View {
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
