import SwiftUI

struct InlineDayPanel: View {
    let date: Date
    let items: [CalendarItemSnapshot]
    let palette: MiraThemePalette
    let onAdd: () -> Void
    let onOpenTimeline: () -> Void
    let onSelectItem: (CalendarItemSnapshot) -> Void
    var workIntervals: [DateInterval] = []
    var workDayAccessory: (() -> AnyView)? = nil
    var displayOptions: CalendarDisplayOptions? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(DateFormatter.mira("M月d日(E)").string(from: date))
                    .font(.headline)
                Spacer(minLength: 0)
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("\(date.japaneseShortDate)に予定を追加")
                .accessibilityIdentifier("inlineDayAdd")
            }

            if let workDayAccessory { workDayAccessory() }

            Button(action: onOpenTimeline) {
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.primaryText.opacity(0.06))
                            ForEach(Array(workIntervals.enumerated()), id: \.offset) { _, interval in
                                let start = Calendar.mira.startOfDay(for: date)
                                let end = Calendar.mira.date(byAdding: .day, value: 1, to: start) ?? start
                                let length = end.timeIntervalSince(start)
                                let lower = max(0, min(1, interval.start.timeIntervalSince(start) / length))
                                let upper = max(lower, min(1, interval.end.timeIntervalSince(start) / length))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(palette.secondaryText.opacity(0.3))
                                    .frame(width: geometry.size.width * (upper - lower))
                                    .offset(x: geometry.size.width * lower)
                            }
                            ForEach(items.filter { $0.countsAgainstWhitespace && $0.exactTimeKnown }) { item in
                                let start = Calendar.mira.startOfDay(for: date)
                                let end = Calendar.mira.date(byAdding: .day, value: 1, to: start) ?? start
                                let length = end.timeIntervalSince(start)
                                let lower = max(0, min(1, item.startDate.timeIntervalSince(start) / length))
                                let upper = max(lower, min(1, item.endDate.timeIntervalSince(start) / length))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(item.colorTag == nil ? palette.accent.opacity(0.65) : palette.color(for: item))
                                    .frame(width: max(2, geometry.size.width * (upper - lower)))
                                    .offset(x: geometry.size.width * lower)
                            }
                        }
                    }
                    .frame(height: 16)
                    HStack {
                        Text("0時")
                        Spacer()
                        Text("12時")
                        Spacer()
                        Text("24時")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(date.japaneseShortDate)の時間割を開く、予定\(items.count)件")
            .accessibilityValue(workIntervals.map {
                "仕事 \(workTime($0))"
            }.joined(separator: "、"))
            .accessibilityIdentifier("inlineDayTimeBar")

            ForEach(Array(workIntervals.enumerated()), id: \.offset) { index, interval in
                Text("仕事  \(workTime(interval))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondaryText)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.secondaryText.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("inlineDayWork-\(index)")
            }

            if items.isEmpty && workIntervals.isEmpty {
                Text("予定なし。ゆっくり過ごせる一日です。")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("inlineDayEmpty")
            } else {
                if let limit = displayOptions?.agendaHeight, items.count > limit {
                    ScrollView {
                        eventRows
                    }
                    .frame(maxHeight: CGFloat(limit * 44 + (limit - 1) * 16))
                } else {
                    eventRows
                }
            }
        }
        .foregroundStyle(palette.primaryText)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(date.japaneseShortDate)の予定")
        .accessibilityIdentifier("inlineDayPanel")
    }

    private var eventRows: some View {
        VStack(spacing: 16) {
            ForEach(items) { item in
                Button { onSelectItem(item) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(item.colorTag == nil ? palette.accent.opacity(0.65) : palette.color(for: item))
                            .frame(width: 4)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(item.kind == .confirmed && !item.countsAgainstWhitespace ? displayOptions?.memoLines : nil)
                            Text((displayOptions?.timeDescription(for: item) ?? item.timeDescription) + duration(for: item))
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("inlineDayEvent-\(item.id.uuidString)")
            }
        }
    }

    private func workTime(_ interval: DateInterval) -> String {
        let options = displayOptions ?? CalendarDisplayOptions()
        return "\(options.time(interval.start))–\(options.time(interval.end))"
    }

    private func duration(for item: CalendarItemSnapshot) -> String {
        guard !item.isAllDay, item.exactTimeKnown else { return "" }
        let minutes = max(0, Int(item.endDate.timeIntervalSince(item.startDate) / 60))
        return "・\(minutes / 60 > 0 ? "\(minutes / 60)時間" : "")\(minutes % 60 > 0 ? "\(minutes % 60)分" : "")"
    }
}

struct InlineDayPanelSlot<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let date: Date?
    @ViewBuilder let content: (Date) -> Content
    @State private var previousDate: Date?
    @State private var progress: CGFloat = 0

    var body: some View {
        Group {
            if let displayedDate = date ?? previousDate {
                content(displayedDate)
            }
        }
            .modifier(InlineDayPanelReveal(progress: progress))
            .allowsHitTesting(date != nil)
            .accessibilityHidden(date == nil)
            .onChange(of: date, initial: true) { oldDate, newDate in
                previousDate = newDate ?? oldDate
                withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.78)) {
                    progress = newDate == nil ? 0 : 1
                } completion: {
                    if newDate == nil { previousDate = nil }
                }
            }
    }
}

private struct InlineDayPanelReveal: AnimatableModifier {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        InlineDayPanelRevealLayout(progress: max(0, progress)) {
            content.transaction { $0.animation = nil }
        }
        .clipped()
    }
}

private struct InlineDayPanelRevealLayout: Layout {
    let progress: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let size = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: size.width, height: size.height * progress)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let content = subviews.first else { return }
        let size = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        content.place(at: bounds.origin, anchor: .topLeading,
                      proposal: ProposedViewSize(width: size.width, height: size.height))
    }
}
