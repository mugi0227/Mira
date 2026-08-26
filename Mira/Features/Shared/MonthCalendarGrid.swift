import SwiftUI

struct MonthCalendarGrid: View {
    let month: Date
    @Binding var selectedDate: Date
    let items: [CalendarItemSnapshot]
    let palette: MiraThemePalette
    var allowsDragging = true
    var onMoveItem: ((UUID, Date) -> Void)?
    var onSelectItem: ((CalendarItemSnapshot) -> Void)?

    private let calendar = Calendar.mira
    private let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        VStack(spacing: MiraSpacing.xs) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 68)
                    }
                }
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 36), spacing: 5), count: 7)
    }

    private var cells: [Date?] {
        let first = MonthKey(date: month, calendar: calendar).firstDay
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday + 5) % 7
        guard let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        var result = Array<Date?>(repeating: nil, count: leading)
        result.append(contentsOf: range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: first)
        })
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let dayItems = items.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: .now)

        Button {
            selectedDate = date
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption.weight(isSelected ? .bold : .medium).monospacedDigit())
                        .foregroundStyle(isSelected ? .white : palette.primaryText)
                    if isToday {
                        Circle()
                            .fill(isSelected ? Color.white : palette.accent)
                            .frame(width: 4, height: 4)
                    }
                    Spacer(minLength: 0)
                }

                VStack(spacing: 3) {
                    ForEach(dayItems.prefix(2)) { item in
                        CalendarMicroBar(item: item, palette: palette)
                            .onTapGesture { onSelectItem?(item) }
                            .draggable(allowsDragging ? item.id.uuidString : "")
                    }
                    if dayItems.count > 2 {
                        Text("+\(dayItems.count - 2)")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? .white.opacity(0.9) : palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
            .background(
                isSelected ? palette.accent : palette.surface.opacity(dayItems.isEmpty ? 0.55 : 0.92),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isSelected ? Color.clear : palette.primaryText.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel(accessibilityLabel(for: date, items: dayItems))
        .dropDestination(for: String.self) { payloads, _ in
            guard allowsDragging,
                  let raw = payloads.first,
                  let id = UUID(uuidString: raw) else { return false }
            onMoveItem?(id, date)
            return true
        }
    }

    private func accessibilityLabel(for date: Date, items: [CalendarItemSnapshot]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 EEEE"
        let suffix = items.isEmpty ? "予定なし" : items.map(\.title).joined(separator: "、")
        return "\(formatter.string(from: date))、\(suffix)"
    }
}

private struct CalendarMicroBar: View {
    let item: CalendarItemSnapshot
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 6, weight: .bold))
                .accessibilityHidden(true)
            Text(item.title)
                .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(Color(hex: 0x352D31))
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: 11, alignment: .leading)
        .background(palette.color(for: item), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
        .accessibilityHidden(true)
    }

    private var symbol: String {
        if item.kind == .margin { return item.marginKind?.symbolName ?? "leaf.fill" }
        if item.kind == .birthday { return "gift.fill" }
        if item.isImportantTime { return "heart.fill" }
        return "circle.fill"
    }
}
