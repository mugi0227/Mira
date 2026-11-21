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
        GeometryReader { viewport in
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: MiraSpacing.md) {
                    dayHeader

                    if let holiday {
                        Label(holiday.title, systemImage: "flag.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.critical)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, MiraSpacing.sm)
                            .background(palette.critical.opacity(0.10), in: RoundedRectangle(cornerRadius: MiraRadius.small))
                    }

                    if !allDayItems.isEmpty {
                        allDaySection
                    }

                    timeline
                }
                .padding(.horizontal, MiraSpacing.md)
                .padding(.top, MiraSpacing.sm)
                .padding(.bottom, MiraSpacing.md)
            }
            .miraScreenBackground(palette)
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
                    store.presentedEventForm = ManualEventDraft(date: date)
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

    private var holiday: DeviceHolidaySnapshot? {
        store.deviceHolidays.first { Calendar.mira.isDate($0.date, inSameDayAs: date) }
    }

    private var allDayItems: [CalendarItemSnapshot] {
        dayItems.filter { $0.isAllDay || $0.kind == .birthday }
    }

    private var timedItems: [CalendarItemSnapshot] {
        dayItems.filter { !$0.isAllDay && $0.kind != .birthday }
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

    private var allDaySection: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Text("終日")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)

            ForEach(allDayItems) { item in
                Button {
                    selectedItem = item
                } label: {
                    HStack(spacing: MiraSpacing.xs) {
                        Image(systemName: symbol(for: item))
                            .accessibilityHidden(true)
                        Text(item.title)
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
                .accessibilityLabel("\(item.title)、終日")
            }
        }
    }

    private var timeline: some View {
        HStack(alignment: .top, spacing: MiraSpacing.xs) {
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d:00", hour))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: timeLabelWidth, height: hourHeight, alignment: .topTrailing)
                        .offset(y: proposal == nil ? -7 : 0)
                        .id("hour-\(hour)")
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { _ in
                            Rectangle()
                                .fill(palette.primaryText.opacity(0.10))
                                .frame(height: 0.5)
                                .frame(maxHeight: .infinity, alignment: .top)
                                .frame(height: hourHeight)
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

                    ForEach(timelinePlacements) { placement in
                        let spacing: CGFloat = 4
                        let eventsWidth = proposal == nil ? geometry.size.width : (geometry.size.width - spacing) * 0.55
                        let laneWidth = max(
                            44,
                            (eventsWidth - spacing * CGFloat(placement.laneCount - 1))
                                / CGFloat(placement.laneCount)
                        )
                        let isDragging = draggingID == placement.item.id
                        timelineEvent(placement.item, height: placement.height)
                            .frame(width: laneWidth, height: placement.height)
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
                                x: CGFloat(placement.lane) * (laneWidth + spacing),
                                y: placement.y + (isDragging ? dragOffset : 0)
                            )
                            .zIndex(isDragging ? 1 : 0)
                            .gesture(timeDragGesture(for: placement.item), including: proposal == nil ? .all : .subviews)
                    }

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
            .frame(height: hourHeight * 24)
        }
        .padding(.trailing, proposal == nil ? 0 : MiraSpacing.md)
        .accessibilityElement(children: .contain)
    }

    private func timelineEvent(_ item: CalendarItemSnapshot, height: CGFloat) -> some View {
        Button {
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(height >= 62 ? 2 : 1)
                Text(item.timeDescription)
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
        .accessibilityLabel("\(item.title)、\(item.timeDescription)")
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
            Text(event.timeDescription).font(.caption2.monospacedDigit())
        }
        .foregroundStyle(palette.accent)
        .padding(MiraSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: eventHeight(for: event), alignment: .topLeading)
        .background(palette.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("追加予定 \(event.title)、\(event.timeDescription)")
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
        return start.formatted(Date.FormatStyle.mira.hour().minute())
    }

    private func shift(_ item: CalendarItemSnapshot, minutes: Int) {
        store.rescheduleItem(id: item.id, toStart: item.startDate.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    private var timelinePlacements: [TimelinePlacement] {
        let sorted = timedItems.sorted { $0.startDate < $1.startDate }
        var groups: [[CalendarItemSnapshot]] = []
        var currentGroup: [CalendarItemSnapshot] = []
        var currentGroupEnd = Date.distantPast

        for item in sorted {
            if currentGroup.isEmpty || item.startDate < currentGroupEnd {
                currentGroup.append(item)
                currentGroupEnd = max(currentGroupEnd, item.endDate)
            } else {
                groups.append(currentGroup)
                currentGroup = [item]
                currentGroupEnd = item.endDate
            }
        }
        if !currentGroup.isEmpty { groups.append(currentGroup) }

        var result: [TimelinePlacement] = []
        for group in groups {
            var laneEnds: [Date] = []
            var staged: [(CalendarItemSnapshot, Int)] = []

            for item in group {
                let lane: Int
                if let reusable = laneEnds.firstIndex(where: { $0 <= item.startDate }) {
                    lane = reusable
                    laneEnds[reusable] = item.endDate
                } else {
                    lane = laneEnds.count
                    laneEnds.append(item.endDate)
                }
                staged.append((item, lane))
            }

            let laneCount = max(1, laneEnds.count)
            result.append(contentsOf: staged.map { item, lane in
                TimelinePlacement(
                    item: item,
                    lane: lane,
                    laneCount: laneCount,
                    y: min(yOffset(for: max(Calendar.mira.startOfDay(for: date), item.startDate)), hourHeight * 24 - 44),
                    height: eventHeight(for: item)
                )
            })
        }
        return result
    }

    private func yOffset(for value: Date) -> CGFloat {
        let components = Calendar.mira.dateComponents([.hour, .minute], from: value)
        let minutes = CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0))
        return minutes / 60 * hourHeight
    }

    private func eventHeight(for item: CalendarItemSnapshot) -> CGFloat {
        let dayEnd = Calendar.mira.startOfDay(for: date).addingDays(1)
        let start = max(Calendar.mira.startOfDay(for: date), item.startDate)
        let end = min(dayEnd, max(item.endDate, start.addingTimeInterval(30 * 60)))
        let minutes = max(30, end.timeIntervalSince(start) / 60)
        return max(44, CGFloat(minutes / 60) * hourHeight)
    }

    private var currentY: CGFloat? {
        guard Calendar.mira.isDate(date, inSameDayAs: store.now) else { return nil }
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
        return "hour-\(hour)"
    }

    private func symbol(for item: CalendarItemSnapshot) -> String {
        if item.kind == .margin { return item.marginKind?.symbolName ?? "leaf.fill" }
        if item.kind == .birthday { return "gift.fill" }
        if item.isImportantTime { return "heart.fill" }
        return "calendar"
    }
}

private struct TimelinePlacement: Identifiable {
    var id: UUID { item.id }
    let item: CalendarItemSnapshot
    let lane: Int
    let laneCount: Int
    let y: CGFloat
    let height: CGFloat
}
