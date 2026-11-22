import SwiftUI

struct HomeView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let palette: MiraThemePalette

    @State private var selectedItem: CalendarItemSnapshot?
    @State private var selectedDayDestination: DayTimelineDestination?
    @State private var openedDate: Date?
    @State private var showSavedDrafts = false
    @State private var draftToResume: UUID?
    @State private var showCompanion = false
    @State private var isFriendView = false
    @State private var friendShareImage: Image?
    @State private var renderedFriendSignature: Int?
    @State private var friendRecipientID: UUID?
    @State private var showFriendImagePreview = false
    @State private var monthHeaderHeight: CGFloat = 88
    @State private var showWhitespaceExplanation = false
    @State private var topFadeAmount: CGFloat = 0
    private let scrollFadeHeight: CGFloat = MiraSpacing.lg

    private var friendRecipient: ImportantPersonEntity? {
        store.importantPeople.first { $0.id == friendRecipientID }
    }

    private var friendLevel: FriendShareLevel {
        friendRecipient.map { store.friendShareLevel(for: $0) } ?? .freeOnly
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { viewport in
                ScrollView {
                    // The calendar leads; everything else is secondary and sits below
                    // it, while talking to Mira lives behind the corner companion.
                    VStack(spacing: MiraSpacing.lg) {
                        monthHeader
                            .padding(.horizontal, screenInset)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { monthHeaderHeight = $0 }

                        if isFriendView {
                            friendViewBanner
                                .padding(.horizontal, screenInset)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        MonthCalendarGrid(
                            month: store.selectedMonth,
                            selectedDate: Binding(
                                get: { store.selectedDate },
                                set: { store.selectedDate = $0 }
                            ),
                            items: store.items,
                            palette: palette,
                            preferredHeight: palette.isCatSkin
                                ? viewport.size.height - monthHeaderHeight - MiraSpacing.md - MiraSpacing.lg - scrollFadeHeight - MiraSpacing.xs
                                : nil,
                            weekStartDay: store.weekStartDay,
                            holidays: store.deviceHolidays,
                            referenceDate: store.now,
                            allowsDragging: !isFriendView,
                            privacyMode: isFriendView,
                            friendLevel: friendLevel,
                            baseRules: store.fetchBaseRules(),
                            openedDate: isFriendView ? nil : openedDate,
                            onAddEvent: { store.presentedEventForm = ManualEventDraft(date: $0) },
                            onOpenTimeline: { selectedDayDestination = DayTimelineDestination(date: $0) },
                            onMoveItem: { id, date in store.moveItem(id: id, to: date) },
                            onSelectDate: openDay,
                            onSelectItem: { item in if !isFriendView { selectedItem = item } }
                        )
                        .padding(.horizontal, palette.isCatSkin ? screenInset : 0)

                        if !isFriendView {
                            whitespaceSummary
                                .padding(.horizontal, screenInset)

                            nextStepCard
                                .padding(.horizontal, screenInset)

                            progressSummary
                                .padding(.horizontal, screenInset)
                        }
                    }
                    .animation(MiraMotion.selection(reduceMotion: reduceMotion), value: isFriendView)
                    .padding(.top, MiraSpacing.xs)
                    .padding(.bottom, MiraSpacing.lg)
                }
                // Fade inside the viewport, not in the companion's dock. A
                // scroll view's layout frame alone does not contain its drawing.
                .scrollClipDisabled()
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.white.opacity(1 - topFadeAmount), .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: scrollFadeHeight)
                        Color.white
                    }
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    let offset = geometry.contentOffset.y + geometry.contentInsets.top
                    return min(1, max(0, offset / MiraSpacing.lg))
                } action: { _, amount in
                    topFadeAmount = amount
                }
                .accessibilityIdentifier("homeScroll")
            }
            // A separate footer gives Mira a home without covering dates, card
            // corners, or the goal pills at any scroll position.
            if store.assistantEnabled && !isFriendView && !palette.isCatSkin {
                HStack {
                    Spacer(minLength: 0)
                    MiraCompanionButton(message: store.currentAssistantMessage, palette: palette) {
                        showCompanion = true
                    }
                    .anchorPreference(key: MiraOverlayLayoutKey.self, value: .bounds) {
                        MiraOverlayLayout(companionBounds: $0)
                    }
                }
                .padding(.horizontal, screenInset)
                .padding(.vertical, MiraSpacing.xs)
            }
        }
        // Keep both the viewport and the companion within the safe area.
        .clipped()
        .miraScreenBackground(palette)
        .sheet(isPresented: $showCompanion) {
            MiraChatView(palette: palette)
        }
        .sheet(isPresented: $showWhitespaceExplanation) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                        Label("自分に戻れる時間を、ひと目で。", systemImage: "circle.dotted")
                            .font(.title2.weight(.semibold))
                        Text("日ごとのリングは、7:00〜23:00のうち、予定や基本時間で埋まっていない時間の割合です。大きく満ちているほど、余白があります。")
                        Text("重なる予定は一度だけ数えます。休息や読書などの余白、予定前後のゆとり、誕生日、終日メモは減らしません。時間を使わない予定は、詳細の「時間を使う予定」をオフにできます。")
                        Text("今月の合計は、過去の日も含むひと月全体の余白です。睡眠時間の個別設定には未対応のため、現在は7:00〜23:00を目安にしています。")
                            .font(.footnote)
                            .foregroundStyle(palette.secondaryText)
                    }
                    .padding(MiraSpacing.lg)
                }
                .miraScreenBackground(palette)
                .navigationTitle("余白メーターについて")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { showWhitespaceExplanation = false }
                } }
            }
            .tint(palette.accent)
        }
        .fullScreenCover(isPresented: $showFriendImagePreview) {
            if let friendShareImage {
                FriendShareImagePreview(image: friendShareImage)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .miraOpenChat)) { _ in
            showCompanion = true
        }
        .task {
            if UserDefaults.standard.bool(forKey: MiraStore.openChatRequestKey) {
                showCompanion = true
            }
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
        .onChange(of: store.selectedMonth) { _, month in
            if let date = openedDate, !Calendar.mira.isDate(date, equalTo: month, toGranularity: .month) {
                openedDate = nil
            }
        }
        .onChange(of: isFriendView) { _, _ in openedDate = nil }
        .task(id: MonthKey(date: store.selectedMonth)) {
            await store.refreshDeviceHolidays(for: store.selectedMonth)
            await store.refreshDeviceCalendar(around: store.selectedMonth)
        }
    }

    private var monthItems: [CalendarItemSnapshot] {
        let interval = MonthKey(date: store.selectedMonth).interval
        return store.items.filter { $0.startDate < interval.end && $0.endDate > interval.start }
    }

    private var screenInset: CGFloat { MiraSpacing.lg }

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .miraPeekingCatCard(palette, theme: store.theme, padding: MiraSpacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeNextStepCard")
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
                withAnimation(MiraMotion.selection(reduceMotion: reduceMotion)) {
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
            monthHeading
            Spacer()

            Button {
                withAnimation(MiraMotion.selection(reduceMotion: reduceMotion)) {
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

    private var monthHeading: some View {
        VStack(spacing: 2) {
            Text(store.selectedMonth.japaneseMonthTitle)
                .font(.system(.title2, design: .serif, weight: .medium))
            Text(monthItems.filter { $0.kind == .confirmed }.count.description + "件の予定")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .foregroundStyle(palette.primaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.selectedMonth.japaneseMonthTitle + "、" + monthItems.filter { $0.kind == .confirmed }.count.description + "件の予定")
        .accessibilityIdentifier("homeMonthHeading")
    }

    private var skyMonthHeader: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xxs) {
            HStack(alignment: .center, spacing: MiraSpacing.sm) {
                monthHeading
                Spacer(minLength: 0)
                HStack(spacing: MiraSpacing.xs) {
                    Button { changeMonth(by: -1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 48)
                    }
                    .accessibilityLabel("前の月")
                    Button { changeMonth(by: 1) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 48)
                    }
                    .accessibilityLabel("次の月")
                }
                .font(.body.weight(.semibold))
                .background(palette.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(palette.cardBorder, lineWidth: 1.5) }
                .shadow(color: palette.shadow, radius: 8, y: 4)
                addMenu
            }
            HStack(alignment: .center) {
                friendViewButton
                Spacer(minLength: MiraSpacing.sm)
                if store.assistantEnabled && !isFriendView {
                    MiraCompanionButton(message: store.currentAssistantMessage, palette: palette) {
                        showCompanion = true
                    }
                }
            }
        }
        .foregroundStyle(palette.accent)
        .buttonStyle(MiraPressStyle())
        .padding(.vertical, MiraSpacing.xxs)
    }

    private var whitespaceSummary: some View {
        let calendar = Calendar.mira
        let month = MonthKey(date: store.selectedMonth)
        let days = calendar.range(of: .day, in: .month, for: month.firstDay) ?? 1..<31
        let rules = store.fetchBaseRules()
        let minutes = days.reduce(0) { total, day in
            let date = calendar.date(byAdding: .day, value: day - 1, to: month.firstDay) ?? month.firstDay
            return total + DayWhitespace(date: date, items: monthItems, baseRules: rules).availableMinutes
        }
        return Button { showWhitespaceExplanation = true } label: {
            HStack(alignment: .firstTextBaseline, spacing: MiraSpacing.sm) {
                Text("今月の余白")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Text("\(minutes / 60)")
                    .font(.system(.title, design: .serif, weight: .medium))
                    .monospacedDigit()
                Text("時間")
                    .font(.caption)
                Image(systemName: "info.circle")
                    .font(.caption)
            }
            .foregroundStyle(palette.accent)
            .padding(.horizontal, MiraSpacing.lg)
            .padding(.vertical, MiraSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(palette.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(palette.cardBorder, lineWidth: 1.5) }
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("今月の余白、\(minutes / 60)時間。計算方法を見る")
        .accessibilityIdentifier("monthWhitespaceSummary")
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
        VStack(alignment: .leading) {
            FriendShareControls(recipientID: $friendRecipientID, palette: palette)
            if ProcessInfo.processInfo.arguments.contains("-friend-share-image-preview"),
               friendLevel != .hidden, renderedFriendSignature == friendShareSignature, friendShareImage != nil {
                Button("共有画像を確認") { showFriendImagePreview = true }
                    .accessibilityIdentifier("friendShareExactImagePreview")
            }
            HStack(spacing: MiraSpacing.sm) {
                Image(systemName: "eye.slash.fill")
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("見せる用モード")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                    Text(friendLevel.explanation)
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
            .padding(.bottom, 52)
            .overlay(alignment: .bottom) {
                HStack(spacing: MiraSpacing.xs) {
                    if friendLevel != .hidden, renderedFriendSignature == friendShareSignature, let friendShareImage {
                        ShareLink(
                            item: friendShareImage,
                            preview: SharePreview("\(store.selectedMonth.japaneseMonthTitle)の空き", image: friendShareImage)
                        ) {
                            Label("画像で送る", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.onAccent)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(palette.accent, in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
                        }
                        .accessibilityIdentifier("friendShareImage")
                    }
                    if friendLevel != .hidden {
                        ShareLink(item: FriendAvailabilityText.text(from: store.now, items: store.items, baseRules: store.fetchBaseRules(), level: friendLevel)) {
                            Label("文字で送る", systemImage: "text.bubble")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(palette.accent)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
                        }
                        .accessibilityIdentifier("friendShareText")
                    }
                }
            }
        }
        .miraCard(palette, padding: MiraSpacing.sm)
        .task(id: friendShareSignature) {
            let signature = friendShareSignature
            friendShareImage = FriendShareRenderer.image(for: FriendShareCard(
                month: store.selectedMonth,
                items: store.items,
                palette: palette,
                weekStartDay: store.weekStartDay,
                referenceDate: store.now,
                baseRules: store.fetchBaseRules(),
                level: friendLevel,
                recipientName: friendRecipient?.name
            ))
            renderedFriendSignature = signature
        }
    }

    private var friendShareSignature: Int {
        var hasher = Hasher()
        hasher.combine(friendRecipientID)
        hasher.combine(friendRecipient?.name)
        hasher.combine(friendLevel)
        hasher.combine(MonthKey(date: store.selectedMonth))
        hasher.combine(store.items)
        hasher.combine(store.weekStartDay)
        hasher.combine(store.theme)
        for rule in store.fetchBaseRules() {
            hasher.combine(rule.weekday)
            hasher.combine(rule.startMinute)
            hasher.combine(rule.endMinute)
        }
        return hasher.finalize()
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
                .font(palette.isCatSkin ? .system(size: 25, weight: .bold, design: .rounded) : .body)
                .foregroundStyle(palette.isCatSkin ? palette.onAccent : palette.accent)
                .frame(width: palette.isCatSkin ? 52 : 44, height: palette.isCatSkin ? 52 : 44)
                .background {
                    if palette.isCatSkin {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(palette.accent)
                            .shadow(color: palette.accent.opacity(0.16), radius: 0, y: 4)
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
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: MiraSpacing.sm))
            : AnyLayout(FlowLayout(spacing: MiraSpacing.sm))
        layout {
            ForEach(visibleGoals) { goal in
                let progress = store.progress(for: goal)
                ProgressPill(
                    symbol: goal.kind.symbolName,
                    title: shortTitle(goal.kind),
                    current: progress.current,
                    target: progress.target,
                    palette: palette
                )
                .accessibilityIdentifier("homeGoalPill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeGoalSummary")
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
        withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.78)) {
            openedDate = openedDate.map { Calendar.mira.isDate($0, inSameDayAs: date) } == true ? nil : date
        }
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
            if store.theme.isCat {
                MiraCatView(mood: message.mood, size: 88)
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
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(palette.accentSoft.opacity(0.85), in: Capsule())
                    }
                    .buttonStyle(MiraPressStyle())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
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
