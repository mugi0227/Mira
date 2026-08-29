import SwiftUI

struct MonthCalendarGrid: View {
    let month: Date
    @Binding var selectedDate: Date
    let items: [CalendarItemSnapshot]
    let palette: MiraThemePalette
    var referenceDate: Date = .now
    var allowsDragging = true
    var onMoveItem: ((UUID, Date) -> Void)?
    var onSelectDate: ((Date) -> Void)?
    var onSelectItem: ((CalendarItemSnapshot) -> Void)?

    private let calendar = Calendar.mira
    private let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]
    private let cellHeight: CGFloat = 86

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(weekdayColor(for: index))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .overlay(alignment: .trailing) {
                            if index < weekdaySymbols.count - 1 {
                                gridLine.frame(width: 0.5)
                            }
                        }
                }
            }
            .background(palette.background)

            gridLine.frame(height: 0.5)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, date in
                    dayCell(date, index: index)
                }
            }
        }
        .background(palette.surface.opacity(0.42))
        .overlay(alignment: .top) { gridLine.frame(height: 0.5) }
        .overlay(alignment: .bottom) { gridLine.frame(height: 0.5) }
        .accessibilityElement(children: .contain)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 0), count: 7)
    }

    /// A stable six-week grid keeps the month view from jumping and also shows
    /// the neighboring dates that users need when they are planning ahead.
    private var cells: [Date] {
        let first = MonthKey(date: month, calendar: calendar).firstDay
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: first) ?? first
        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    private var gridLine: some View {
        Rectangle().fill(palette.primaryText.opacity(0.11))
    }

    private func weekdayColor(for index: Int) -> Color {
        switch index {
        case 5: palette.accent
        case 6: palette.critical.opacity(0.86)
        default: palette.secondaryText
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date, index: Int) -> some View {
        let dayItems = items
            .filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: referenceDate)
        let isInDisplayedMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
        let column = index % 7

        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Spacer(minLength: 0)
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 27, height: 27)
                    } else if isToday {
                        Circle()
                            .stroke(palette.accent, lineWidth: 1.5)
                            .frame(width: 27, height: 27)
                    }

                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption.weight(isSelected || isToday ? .bold : .medium).monospacedDigit())
                        .foregroundStyle(dateForeground(
                            isSelected: isSelected,
                            isInDisplayedMonth: isInDisplayedMonth,
                            column: column
                        ))
                }
                .frame(height: 28)
                Spacer(minLength: 0)
            }

            VStack(spacing: 2) {
                ForEach(dayItems.prefix(3)) { item in
                    CalendarEventStrip(item: item, palette: palette)
                        .onTapGesture { onSelectItem?(item) }
                        .draggable(allowsDragging ? item.id.uuidString : "")
                }

                if dayItems.count > 3 {
                    Text("ほか \(dayItems.count - 3)件")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
        .padding(.horizontal, 2)
        .padding(.bottom, 3)
        .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight, alignment: .topLeading)
        .background(isSelected ? palette.accentSoft.opacity(0.32) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
            onSelectDate?(date)
        }
        .overlay(alignment: .trailing) {
            if column < 6 { gridLine.frame(width: 0.5) }
        }
        .overlay(alignment: .bottom) { gridLine.frame(height: 0.5) }
        .dropDestination(for: String.self) { payloads, _ in
            guard allowsDragging,
                  let raw = payloads.first,
                  let id = UUID(uuidString: raw) else { return false }
            onMoveItem?(id, date)
            return true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: date, items: dayItems))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "日付を開く") {
            selectedDate = date
            onSelectDate?(date)
        }
    }

    private func dateForeground(
        isSelected: Bool,
        isInDisplayedMonth: Bool,
        column: Int
    ) -> Color {
        if isSelected { return .white }
        if !isInDisplayedMonth { return palette.secondaryText.opacity(0.48) }
        if column == 5 { return palette.accent }
        if column == 6 { return palette.critical.opacity(0.88) }
        return palette.primaryText
    }

    private func accessibilityLabel(for date: Date, items: [CalendarItemSnapshot]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 EEEE"
        let suffix = items.isEmpty ? "予定なし" : items.map(\.title).joined(separator: "、")
        return "\(formatter.string(from: date))、\(suffix)"
    }
}

private struct CalendarEventStrip: View {
    let item: CalendarItemSnapshot
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: 2) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 6.5, weight: .bold))
                    .accessibilityHidden(true)
            }

            Text(item.title)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(palette.primaryText)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
        .background(palette.color(for: item).opacity(item.kind == .margin ? 0.82 : 0.96))
        .overlay {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .stroke(
                    item.kind == .margin ? palette.primaryText.opacity(0.28) : Color.clear,
                    style: StrokeStyle(lineWidth: 0.7, dash: item.kind == .margin ? [2, 1.5] : [])
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
        .accessibilityHidden(true)
    }

    private var symbol: String? {
        if item.kind == .margin { return item.marginKind?.symbolName ?? "leaf.fill" }
        if item.kind == .birthday { return "gift.fill" }
        if item.isImportantTime { return "heart.fill" }
        return nil
    }
}
