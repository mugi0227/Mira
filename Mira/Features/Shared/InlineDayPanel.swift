import SwiftUI

struct InlineDayPanel: View {
    let date: Date
    let items: [CalendarItemSnapshot]
    let palette: MiraThemePalette
    let onAdd: () -> Void
    let onOpenTimeline: () -> Void
    let onSelectItem: (CalendarItemSnapshot) -> Void
    var workDayAccessory: (() -> AnyView)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            .accessibilityIdentifier("inlineDayTimeBar")

            if items.isEmpty {
                Text("予定なし。ゆっくり過ごせる一日です。")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("inlineDayEmpty")
            } else {
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
                                    Text(item.timeDescription + duration(for: item))
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
        }
        .foregroundStyle(palette.primaryText)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(date.japaneseShortDate)の予定")
        .accessibilityIdentifier("inlineDayPanel")
    }

    private func duration(for item: CalendarItemSnapshot) -> String {
        guard !item.isAllDay, item.exactTimeKnown else { return "" }
        let minutes = max(0, Int(item.endDate.timeIntervalSince(item.startDate) / 60))
        return "・\(minutes / 60 > 0 ? "\(minutes / 60)時間" : "")\(minutes % 60 > 0 ? "\(minutes % 60)分" : "")"
    }
}
