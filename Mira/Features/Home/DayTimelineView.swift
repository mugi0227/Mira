import SwiftUI

struct DayTimelineDestination: Identifiable, Hashable {
    let date: Date

    var id: Date { Calendar.mira.startOfDay(for: date) }
}

struct DayTimelineView: View {
    @Environment(MiraStore.self) private var store

    let date: Date
    let palette: MiraThemePalette

    @State private var selectedItem: CalendarItemSnapshot?

    private let hourHeight: CGFloat = 64
    private let timeLabelWidth: CGFloat = 52

    var body: some View {
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
                .padding(.bottom, 80)
            }
            .miraScreenBackground(palette)
            .onAppear {
                store.selectedDate = date
                DispatchQueue.main.async {
                    proxy.scrollTo(scrollTargetID, anchor: .top)
                }
            }
        }
        .navigationTitle(date.japaneseDayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.presentedEventForm = ManualEventDraft(date: date)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("この日に予定を追加")
            }
        }
        .sheet(item: $selectedItem) { item in
            EventDetailSheet(item: item, palette: palette)
        }
    }

    private var dayItems: [CalendarItemSnapshot] {
        store.items
            .filter { Calendar.mira.isDate($0.startDate, inSameDayAs: date) }
            .sorted {
                if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
                return $0.startDate < $1.startDate
            }
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
                        .offset(y: -7)
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

                    ForEach(timelinePlacements) { placement in
                        let spacing: CGFloat = 4
                        let laneWidth = max(
                            44,
                            (geometry.size.width - spacing * CGFloat(placement.laneCount - 1))
                                / CGFloat(placement.laneCount)
                        )
                        timelineEvent(placement.item, height: placement.height)
                            .frame(width: laneWidth, height: placement.height)
                            .offset(
                                x: CGFloat(placement.lane) * (laneWidth + spacing),
                                y: placement.y
                            )
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
                    .stroke(palette.primaryText.opacity(item.kind == .margin ? 0.20 : 0.08), lineWidth: 1)
            }
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("\(item.title)、\(item.timeDescription)")
        .accessibilityHint("詳細を開く")
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
                    y: min(yOffset(for: item.startDate), hourHeight * 24 - 44),
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
        let end = min(dayEnd, max(item.endDate, item.startDate.addingTimeInterval(30 * 60)))
        let minutes = max(30, end.timeIntervalSince(item.startDate) / 60)
        return max(44, CGFloat(minutes / 60) * hourHeight)
    }

    private var currentY: CGFloat? {
        guard Calendar.mira.isDate(date, inSameDayAs: store.now) else { return nil }
        return yOffset(for: store.now)
    }

    private var scrollTargetID: String {
        let hour: Int
        if Calendar.mira.isDate(date, inSameDayAs: store.now) {
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
