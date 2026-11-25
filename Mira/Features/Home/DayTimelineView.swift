import SwiftUI

struct DayTimelineDestination: Identifiable, Hashable {
    let date: Date

    var id: Date { Calendar.mira.startOfDay(for: date) }
}

struct DayTimelineView: View {
    @Environment(MiraStore.self) private var store

    let date: Date
    let palette: MiraThemePalette
    var proposal: DayTimelineProposal? = nil

    @State private var selectedItem: CalendarItemSnapshot?
    @State private var draggingID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var snappedMinutes = 0

    private let hourHeight: CGFloat = 64
    private let timeLabelWidth: CGFloat = 52

    var body: some View {
        let pinnedItems = allDayItems
        GeometryReader { viewport in
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: MiraSpacing.md) {
                    if proposal != nil { dayHeader }

                    if let holiday {
                        Label(holiday, systemImage: "flag.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.critical)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, MiraSpacing.sm)
                            .background(palette.critical.opacity(0.10), in: RoundedRectangle(cornerRadius: MiraRadius.small))
                    }

                    timeline(hasPinnedAllDayItems: !pinnedItems.isEmpty)
                }
                .padding(.horizontal, MiraSpacing.md)
                .padding(.top, MiraSpacing.sm)
                .padding(.bottom, MiraSpacing.md)
            }
            .miraScreenBackground(palette)
            .safeAreaInset(edge: .top, spacing: 0) {
                if proposal == nil {
                    VStack(alignment: .leading, spacing: MiraSpacing.md) {
                        dayHeader
                        WorkDayToggle(date: date, palette: palette)
                    }
                    .padding(MiraSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.background)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !pinnedItems.isEmpty {
                    ViewThatFits(in: .vertical) {
                        allDaySection(pinnedItems)
                            .fixedSize(horizontal: false, vertical: true)
                        ScrollView {
                            allDaySection(pinnedItems)
                        }
                    }
                    .frame(maxHeight: viewport.size.height * 0.25)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MiraSpacing.md)
                    .padding(.vertical, MiraSpacing.sm)
                    .background(palette.background)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(palette.primaryText.opacity(0.10))
                            .frame(height: 0.5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: proposal == nil ? 0 : MiraSpacing.md) {
                if let proposal {
                    ScrollView {
                        conflictSection(proposal)
                            .padding(.horizontal, MiraSpacing.md)
                            .padding(.vertical, MiraSpacing.sm)
                    }
                    .frame(height: min(viewport.size.height * 0.42, CGFloat(max(1, proposal.conflicts.count)) * 76 + 96))
                    .background(palette.background)
                }
            }
            .onAppear {
                if proposal == nil { store.selectedDate = date }
                DispatchQueue.main.async {
                    proxy.scrollTo(scrollTargetID, anchor: .top)
                }
            }
        }
        }
        .navigationTitle(date.japaneseDayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if proposal == nil {
                Button {
                    store.presentedEventForm = store.calendarDisplayOptions.newEventDraft(on: date)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("この日に予定を追加")
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            EventDetailSheet(item: item, palette: palette)
        }
        .sensoryFeedback(.selection, trigger: snappedMinutes)
        .sensoryFeedback(.impact(weight: .medium), trigger: draggingID)
    }

    private var dayItems: [CalendarItemSnapshot] {
        store.items
            .filter { $0.overlapsDay(date) }
            .sorted {
                if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
                return $0.startDate < $1.startDate
            }
    }

    private func conflictSection(_ proposal: DayTimelineProposal) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            Text("重なっている予定").font(.headline)
            if proposal.conflicts.isEmpty {
                Text("重なる予定はありません").foregroundStyle(palette.secondaryText)
            }
            ForEach(proposal.conflicts) { detail in
                if let item = store.items.first(where: { $0.id == detail.itemID }) {
                    Button { selectedItem = item } label: {
                        conflictRow(detail.text, icon: item.kind == .margin ? "leaf" : "calendar", tappable: true)
                    }
                    .accessibilityIdentifier("proposal.conflict.\(item.title)")
                } else {
                    conflictRow(detail.text, icon: detail.baseRuleInterval == nil ? "calendar.badge.clock" : "nosign", tappable: false)
                        .accessibilityIdentifier("proposal.conflict.\(detail.id)")
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(palette.critical)
        .miraCard(palette, padding: MiraSpacing.lg)
    }

    private func conflictRow(_ text: String, icon: String, tappable: Bool) -> some View {
        HStack(alignment: .top, spacing: MiraSpacing.xs) {
            Image(systemName: icon).frame(width: 20).accessibilityHidden(true)
            Text(text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if tappable { Image(systemName: "chevron.right").accessibilityHidden(true) }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var holiday: String? {
        store.visibleHolidayTitle(on: date)
    }

    private var allDayItems: [CalendarItemSnapshot] {
        dayItems.filter { $0.isAllDay || $0.kind == .birthday || ($0.kind == .confirmed && !$0.countsAgainstWhitespace) }
    }

    private var timedItems: [CalendarItemSnapshot] {
        dayItems.filter { !$0.isAllDay && $0.kind != .birthday && ($0.kind != .confirmed || $0.countsAgainstWhitespace) }
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(date.formatted(Date.FormatStyle.mira.year().month().day().weekday(.wide)))
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                Text(daySummary)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: MiraSpacing.sm)
            Image(systemName: dayItems.isEmpty ? "sparkles" : "clock")
                .font(.title3)
                .foregroundStyle(palette.accent)
                .frame(width: 44, height: 44)
                .background(palette.accentSoft, in: Circle())
                .accessibilityHidden(true)
        }
    }

    private var daySummary: String {
        guard !dayItems.isEmpty else { return "予定のない一日です" }
        return "予定と余白が\(dayItems.count)件あります"
    }

    private func allDaySection(_ items: [CalendarItemSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Text("終日・メモ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)

            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    HStack(spacing: MiraSpacing.xs) {
                        Image(systemName: symbol(for: item))
                            .accessibilityHidden(true)
                        Text(item.title)
                            .foregroundStyle((item.kind == .confirmed && !item.countsAgainstWhitespace) ? palette.secondaryText : palette.primaryText)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, MiraSpacing.sm)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(palette.color(for: item), in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
                }
                .buttonStyle(MiraPressStyle())
                .accessibilityLabel("\(item.title)、\(item.timeDescription)\((item.kind == .confirmed && !item.countsAgainstWhitespace) ? "、メモ" : "")")
            }
        }
    }

    private func timeline(hasPinnedAllDayItems: Bool) -> some View {
        HStack(alignment: .top, spacing: MiraSpacing.xs) {
            VStack(spacing: 0) {
                ForEach(timelineHours, id: \.self) { hour in
                    Text(store.calendarDisplayOptions.uses24HourTime
                         ? String(format: "%02d:00", hour)
                         : store.calendarDisplayOptions.time(date.setting(hour: hour)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: timeLabelWidth, height: hourHeight, alignment: .topTrailing)
                        .id("hour-\(hour)")
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(timelineHours, id: \.self) { _ in
                            Rectangle()
                                .fill(palette.primaryText.opacity(0.10))
                                .frame(height: 0.5)
                                .frame(maxHeight: .infinity, alignment: .top)
                                .frame(height: hourHeight)
                        }
                    }

                    if proposal == nil {
                        let intervals = store.workDayResolver.intervals(on: date, rules: store.fetchBaseRules())
                        ForEach(intervals, id: \.self) { interval in
                            if let visible = ProposalTimeline.overlap(interval, timelineInterval) {
                                workBand(visible, original: interval)
                                    .frame(width: geometry.size.width)
                            }
                        }
                    }

                    if let proposal {
                        ForEach(proposal.conflicts.filter { $0.baseRuleInterval != nil }) { detail in
                            if let interval = detail.baseRuleInterval {
                                baseRuleBand(interval)
                                    .frame(width: geometry.size.width)
                            }
                        }
                    }

                    timelineLanes(width: proposal == nil ? geometry.size.width : (geometry.size.width - 4) * 0.55)

                    if let proposal {
                        proposalBlock(proposal.event)
                            .frame(width: (geometry.size.width - 4) * 0.45)
                            .offset(x: (geometry.size.width - 4) * 0.55 + 4,
                                y: yOffset(for: max(Calendar.mira.startOfDay(for: date), proposal.event.startDate)))
                            .zIndex(2)
                    }

                    if let currentY {
                        HStack(spacing: 0) {
                            Circle()
                                .fill(palette.critical)
                                .frame(width: 8, height: 8)
                            Rectangle()
                                .fill(palette.critical)
                                .frame(height: 1.5)
                        }
                        .offset(x: -4, y: currentY - 4)
                        .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: timelineHeight)
        }
        .padding(.trailing, proposal == nil ? 0 : MiraSpacing.md)
        .accessibilityElement(children: .contain)
    }

    private var timelineHours: Range<Int> {
        let options = store.calendarDisplayOptions
        return proposal == nil ? options.dayStartHour..<options.dayEndHour : 0..<24
    }

    private var timelineInterval: DateInterval {
        let start = date.setting(hour: timelineHours.lowerBound)
        let end = timelineHours.upperBound == 24 ? date.startOfDay().addingDays(1) : date.setting(hour: timelineHours.upperBound)
        return DateInterval(start: start, end: end)
    }

    private var timelineHeight: CGFloat { hourHeight * CGFloat(timelineHours.count) }

    @ViewBuilder
    private func timelineLanes(width: CGFloat) -> some View {
        let placements = timelinePlacements
        let contentWidth = TimelinePlacement.contentWidth(for: placements, viewportWidth: width)
        if contentWidth > width {
            ScrollView(.horizontal) {
                timelineCards(placements, viewportWidth: width)
                    .frame(width: contentWidth, height: timelineHeight, alignment: .topLeading)
            }
            .frame(width: width, height: timelineHeight)
        } else {
            timelineCards(placements, viewportWidth: width)
        }
    }

    private func timelineCards(_ placements: [TimelinePlacement], viewportWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(placements) { placement in
                let isDragging = draggingID == placement.item.id
                timelineEvent(placement.item, height: placement.height)
                    .frame(width: placement.laneWidth(in: viewportWidth), height: placement.height)
                    .scaleEffect(isDragging ? 1.03 : 1)
                    .shadow(color: isDragging ? palette.shadow : .clear, radius: 10, y: 4)
                    .overlay(alignment: .topTrailing) {
                        if isDragging {
                            Text(dragTimeLabel(for: placement.item))
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(palette.onAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(palette.accent, in: Capsule())
                                .offset(y: -26)
                        }
                    }
                    .offset(
                        x: placement.laneOffset(in: viewportWidth),
                        y: placement.y + (isDragging ? dragOffset : 0)
                    )
                    .zIndex(isDragging ? 1 : 0)
                    .gesture(timeDragGesture(for: placement.item), including: proposal == nil ? .all : .subviews)
            }
        }
    }

    private func timelineEvent(_ item: CalendarItemSnapshot, height: CGFloat) -> some View {
        Button {
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                            .foregroundStyle((item.kind == .confirmed && !item.countsAgainstWhitespace) ? palette.secondaryText : palette.primaryText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(height >= 62 ? 2 : 1)
                Text(store.calendarDisplayOptions.timeDescription(for: item))
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
                if height >= 82, item.kind == .margin {
                    Label("余白", systemImage: item.marginKind?.symbolName ?? "leaf.fill")
                        .font(.caption2)
                }
            }
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                palette.color(for: item).opacity(item.kind == .margin ? 0.86 : 0.96),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isOverlapping(item) ? palette.critical : palette.primaryText.opacity(item.kind == .margin ? 0.20 : 0.08), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                if let interval = overlap(for: item) {
                    Rectangle()
                        .fill(palette.critical.opacity(0.16))
                        .frame(height: CGFloat(interval.duration / 3600) * hourHeight)
                        .offset(y: CGFloat(interval.start.timeIntervalSince(max(item.startDate, Calendar.mira.startOfDay(for: date))) / 3600) * hourHeight)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("\(item.title)、\(store.calendarDisplayOptions.timeDescription(for: item))")
        .accessibilityHint(proposal == nil ? "詳細を開く。長押ししてドラッグすると時間を変えられます" : "詳細を開く")
        .accessibilityActions {
            if proposal == nil {
                Button("15分早める") { shift(item, minutes: -15) }
                Button("15分遅らせる") { shift(item, minutes: 15) }
            }
        }
    }

    private func isOverlapping(_ item: CalendarItemSnapshot) -> Bool {
        guard let proposal else { return false }
        return !ProposalTimeline.overlappingItems([item], proposal: proposal.event).isEmpty
    }

    private func workBand(_ interval: DateInterval, original: DateInterval) -> some View {
        let options = store.calendarDisplayOptions
        return Rectangle()
            .fill(palette.secondaryText.opacity(0.06))
            .overlay(alignment: .topLeading) {
                Text("仕事  \(options.time(original.start))–\(options.time(original.end))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                    .padding(MiraSpacing.sm)
            }
            .frame(height: CGFloat(interval.duration / 3600) * hourHeight)
            .offset(y: yOffset(for: interval.start))
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("workDayBand")
    }

    private func baseRuleBand(_ interval: DateInterval) -> some View {
        let start = max(Calendar.mira.startOfDay(for: date), interval.start)
        let end = min(Calendar.mira.startOfDay(for: date).addingDays(1), interval.end)
        return Rectangle()
            .fill(palette.secondaryText.opacity(0.08))
            .overlay(alignment: .topLeading) {
                Text("基本時間")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .padding(4)
                    .background(palette.background.opacity(0.90), in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
                    .offset(y: -20)
            }
            .frame(height: max(0, CGFloat(end.timeIntervalSince(start) / 3600) * hourHeight))
            .offset(y: yOffset(for: start))
            .allowsHitTesting(false)
    }

    private func overlap(for item: CalendarItemSnapshot) -> DateInterval? {
        guard let proposal, item.exactTimeKnown, isOverlapping(item) else { return nil }
        let day = DateInterval(start: Calendar.mira.startOfDay(for: date), end: Calendar.mira.startOfDay(for: date).addingDays(1))
        guard let interval = ProposalTimeline.overlap(
            DateInterval(start: item.startDate, end: max(item.startDate, item.endDate)),
            DateInterval(start: proposal.event.startDate, end: max(proposal.event.startDate, proposal.event.endDate))
        ) else { return nil }
        return ProposalTimeline.overlap(interval, day)
    }

    private func proposalBlock(_ event: CalendarItemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Text(event.title).font(.caption.bold())
            Text(store.calendarDisplayOptions.timeDescription(for: event)).font(.caption2.monospacedDigit())
        }
        .foregroundStyle(palette.accent)
        .padding(MiraSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: TimelinePlacement.eventHeight(for: event, in: timelineInterval, hourHeight: hourHeight), alignment: .topLeading)
        .background(palette.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("追加予定 \(event.title)、\(store.calendarDisplayOptions.timeDescription(for: event))")
        .accessibilityIdentifier("proposal.timelineBlock")
        .allowsHitTesting(false)
    }

    /// Long-press then drag, snapping to 15 minutes, so scrolling the day
    /// never moves a plan by accident.
    private func timeDragGesture(for item: CalendarItemSnapshot) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard item.deviceEvent == nil else { return }
                switch value {
                case .first(true):
                    if draggingID != item.id {
                        draggingID = item.id
                        dragOffset = 0
                        snappedMinutes = 0
                    }
                case .second(true, let drag?):
                    draggingID = item.id
                    dragOffset = drag.translation.height
                    let minutes = Int((drag.translation.height / hourHeight * 60 / 15).rounded()) * 15
                    snappedMinutes = clampedMinutes(minutes, for: item)
                default:
                    break
                }
            }
            .onEnded { _ in
                let minutes = snappedMinutes
                draggingID = nil
                dragOffset = 0
                snappedMinutes = 0
                if minutes != 0 { shift(item, minutes: minutes) }
            }
    }

    /// Keeps the plan on this day.
    private func clampedMinutes(_ minutes: Int, for item: CalendarItemSnapshot) -> Int {
        let dayStart = Calendar.mira.startOfDay(for: date)
        let startMinute = Int(item.startDate.timeIntervalSince(dayStart) / 60)
        let length = Int(item.endDate.timeIntervalSince(item.startDate) / 60)
        let lowest = -startMinute
        let highest = max(lowest, 24 * 60 - length - startMinute)
        return min(max(minutes, lowest), highest)
    }

    private func dragTimeLabel(for item: CalendarItemSnapshot) -> String {
        let start = item.startDate.addingTimeInterval(TimeInterval(snappedMinutes * 60))
        return store.calendarDisplayOptions.time(start)
    }

    private func shift(_ item: CalendarItemSnapshot, minutes: Int) {
        store.rescheduleItem(id: item.id, toStart: item.startDate.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    private var timelinePlacements: [TimelinePlacement] {
        TimelinePlacement.layout(timedItems, in: timelineInterval, hourHeight: hourHeight, timelineHeight: timelineHeight)
    }

    private func yOffset(for value: Date) -> CGFloat {
        let components = Calendar.mira.dateComponents([.hour, .minute], from: value)
        let minutes = CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0))
        return (minutes / 60 - CGFloat(timelineHours.lowerBound)) * hourHeight
    }

    private var currentY: CGFloat? {
        guard Calendar.mira.isDate(date, inSameDayAs: store.now) else { return nil }
        guard store.now >= timelineInterval.start, store.now < timelineInterval.end else { return nil }
        return yOffset(for: store.now)
    }

    private var scrollTargetID: String {
        let hour: Int
        if let proposal {
            hour = ProposalTimeline.scrollHour(for: proposal, on: date)
        } else if Calendar.mira.isDate(date, inSameDayAs: store.now) {
            hour = max(0, Calendar.mira.component(.hour, from: store.now) - 1)
        } else if let first = timedItems.first {
            hour = max(0, Calendar.mira.component(.hour, from: first.startDate) - 1)
        } else {
            hour = 8
        }
        return "hour-\(min(max(hour, timelineHours.lowerBound), timelineHours.upperBound - 1))"
    }

    private func symbol(for item: CalendarItemSnapshot) -> String {
        if item.kind == .margin { return item.marginKind?.symbolName ?? "leaf.fill" }
        if item.kind == .confirmed && !item.countsAgainstWhitespace { return "note.text" }
        if item.kind == .birthday { return "gift.fill" }
        if item.isImportantTime { return "heart.fill" }
        return "calendar"
    }
}

struct TimelinePlacement: Identifiable {
    private static let laneSpacing: CGFloat = 4
    private static let minimumLaneWidth: CGFloat = 44

    var id: UUID { item.id }
    let item: CalendarItemSnapshot
    let lane: Int
    let laneCount: Int
    let y: CGFloat
    let height: CGFloat

    func laneWidth(in viewportWidth: CGFloat) -> CGFloat {
        max(Self.minimumLaneWidth, (viewportWidth - Self.laneSpacing * CGFloat(laneCount - 1)) / CGFloat(laneCount))
    }

    func laneOffset(in viewportWidth: CGFloat) -> CGFloat {
        CGFloat(lane) * (laneWidth(in: viewportWidth) + Self.laneSpacing)
    }

    static func contentWidth(for placements: [TimelinePlacement], viewportWidth: CGFloat) -> CGFloat {
        guard let laneCount = placements.map(\.laneCount).max() else { return viewportWidth }
        return max(viewportWidth, minimumLaneWidth * CGFloat(laneCount) + laneSpacing * CGFloat(laneCount - 1))
    }

    private struct Block {
        let item: CalendarItemSnapshot
        let y: CGFloat
        let height: CGFloat
    }

    static func eventHeight(for item: CalendarItemSnapshot, in visible: DateInterval, hourHeight: CGFloat) -> CGFloat {
        let start = max(visible.start, item.startDate)
        let end = min(visible.end, item.endDate)
        return max(44, CGFloat(end.timeIntervalSince(start) / 3600) * hourHeight)
    }

    static func layout(
        _ items: [CalendarItemSnapshot], in visible: DateInterval, hourHeight: CGFloat, timelineHeight: CGFloat
    ) -> [TimelinePlacement] {
        var blocks: [Block] = []
        for item in items where item.startDate < visible.end && item.endDate > visible.start {
            let start = max(visible.start, item.startDate)
            let height = eventHeight(for: item, in: visible, hourHeight: hourHeight)
            let offset = CGFloat(start.timeIntervalSince(visible.start) / 3600) * hourHeight
            blocks.append(Block(item: item, y: min(offset, timelineHeight - height), height: height))
        }
        blocks.sort { $0.y == $1.y ? $0.item.startDate < $1.item.startDate : $0.y < $1.y }
        var placements: [TimelinePlacement] = []
        var group: [(block: Block, lane: Int)] = []
        var laneEnds: [CGFloat] = []

        func appendGroup() {
            placements.append(contentsOf: group.map { block, lane in
                TimelinePlacement(item: block.item, lane: lane, laneCount: laneEnds.count, y: block.y, height: block.height)
            })
            group.removeAll()
            laneEnds.removeAll()
        }

        for block in blocks {
            if let lastEnd = laneEnds.max(), block.y >= lastEnd { appendGroup() }
            let end = block.y + block.height
            let lane = laneEnds.firstIndex(where: { $0 <= block.y }) ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(end) }
            else { laneEnds[lane] = end }
            group.append((block, lane))
        }
        appendGroup()
        return placements
    }
}
