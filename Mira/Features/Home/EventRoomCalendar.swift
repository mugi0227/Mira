import SwiftUI

/// Date picker for a new event that lights up the days with one free stretch
/// long enough for it, so "can I fit this?" is answered while choosing.
struct EventRoomCalendar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection

    @Binding var selectedDate: Date
    let durationMinutes: Int?
    let items: [CalendarItemSnapshot]
    let baseRules: [BaseAvailabilityRule]
    let referenceDate: Date
    let weekStartDay: WeekStartDay
    let palette: MiraThemePalette

    @State private var month: Date

    init(
        selectedDate: Binding<Date>,
        durationMinutes: Int?,
        items: [CalendarItemSnapshot],
        baseRules: [BaseAvailabilityRule],
        referenceDate: Date,
        weekStartDay: WeekStartDay,
        palette: MiraThemePalette
    ) {
        _selectedDate = selectedDate
        self.durationMinutes = durationMinutes
        self.items = items
        self.baseRules = baseRules
        self.referenceDate = referenceDate
        self.weekStartDay = weekStartDay
        self.palette = palette
        _month = State(initialValue: selectedDate.wrappedValue)
    }

    private var calendar: Calendar {
        var value = Calendar.mira
        value.firstWeekday = weekStartDay.calendarFirstWeekday
        return value
    }

    var body: some View {
        let slots = freeSlots
        VStack(spacing: MiraSpacing.sm) {
            HStack {
                monthButton(offset: -1, symbol: "chevron.left", label: "前の月")
                Spacer()
                Text(month.japaneseMonthTitle)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                    .contentTransition(.numericText())
                Spacer()
                monthButton(offset: 1, symbol: "chevron.right", label: "次の月")
            }

            LazyVGrid(columns: columns, spacing: MiraSpacing.xxs) {
                ForEach(Array(weekStartDay.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 20)
                }
                ForEach(cells, id: \.self) { date in
                    dayButton(date, slot: slots[date])
                }
            }

            legend(roomyCount: slots.filter { isInMonth($0.key) && fits($0.value) }.count)
        }
        .padding(.vertical, MiraSpacing.xxs)
        .onChange(of: selectedDate) { _, value in
            guard !calendar.isDate(value, equalTo: month, toGranularity: .month) else { return }
            withAnimation(MiraMotion.selection(reduceMotion: reduceMotion)) { month = value }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eventRoomCalendar")
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: MiraSpacing.xxs), count: 7)
    }

    private var cells: [Date] {
        let first = MonthKey(date: month, calendar: calendar).firstDay
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: first) ?? first
        let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let weeks = Int((Double(leading + daysInMonth) / 7).rounded(.up))
        return (0..<(weeks * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// Past days and the part of today already gone have no room to offer.
    private var freeSlots: [Date: DayFreeSlot] {
        guard durationMinutes != nil else { return [:] }
        let today = calendar.startOfDay(for: referenceDate)
        var result: [Date: DayFreeSlot] = [:]
        for date in cells where date >= today {
            let dayRange = DateInterval(start: date, end: date.addingDays(1, calendar: calendar))
            let dayItems = items.filter { $0.occupiedInterval.intersects(dayRange) }
            result[date] = DayFreeSlot(
                date: date,
                items: dayItems,
                baseRules: baseRules,
                notBefore: calendar.isDate(date, inSameDayAs: referenceDate) ? referenceDate : nil,
                calendar: calendar
            )
        }
        return result
    }

    private func fits(_ slot: DayFreeSlot?) -> Bool {
        guard let durationMinutes, let slot else { return false }
        return slot.fits(minutes: durationMinutes)
    }

    private func isInMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    private func monthButton(offset: Int, symbol: String, label: String) -> some View {
        Button {
            withAnimation(MiraMotion.selection(reduceMotion: reduceMotion)) {
                month = month.addingMonths(offset)
            }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel(label)
    }

    private func dayButton(_ date: Date, slot: DayFreeSlot?) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: referenceDate)
        let hasRoom = fits(slot)
        let inMonth = isInMonth(date)
        return Button {
            withAnimation(MiraMotion.selection(reduceMotion: reduceMotion)) {
                selectedDate = date
            }
        } label: {
            ZStack {
                if hasRoom {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.accentSoft)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(palette.accent.opacity(0.35), lineWidth: 1)
                        }
                        .padding(2)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.actionGradient)
                        .padding(2)
                        .matchedGeometryEffect(id: "selected-date", in: selection)
                } else if isToday {
                    Circle()
                        .stroke(palette.accent, lineWidth: 1.5)
                        .frame(width: 30, height: 30)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected || hasRoom || isToday ? .semibold : .regular, design: .rounded).monospacedDigit())
                    .foregroundStyle(dayForeground(isSelected: isSelected, hasRoom: hasRoom, inMonth: inMonth))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .opacity(inMonth ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(MiraPressStyle())
        .animation(MiraMotion.selection(reduceMotion: reduceMotion), value: hasRoom)
        .accessibilityLabel(accessibilityLabel(date, slot: slot, hasRoom: hasRoom))
        .accessibilityValue(hasRoom ? "空きあり" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("room-day-\(DateFormatter.mira("yyyy-MM-dd").string(from: date))")
    }

    private func dayForeground(isSelected: Bool, hasRoom: Bool, inMonth: Bool) -> Color {
        if isSelected { return palette.onAccent }
        if hasRoom { return palette.accent }
        return inMonth ? palette.primaryText : palette.secondaryText
    }

    @ViewBuilder
    private func legend(roomyCount: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: MiraSpacing.xs) {
            if let durationMinutes {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(palette.accentSoft)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(palette.accent.opacity(0.35), lineWidth: 1)
                    }
                    .frame(width: 14, height: 14)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                    .accessibilityHidden(true)
                Text(roomyCount > 0
                     ? "\(Self.durationText(durationMinutes))続けて空いている日（この月 \(roomyCount)日）"
                     : "この月は\(Self.durationText(durationMinutes))続けて空いている日がありません")
            } else {
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
                Text("終日の予定は、空き時間で日付を絞り込みません")
            }
        }
        .font(.caption)
        .foregroundStyle(palette.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MiraSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("eventRoomLegend")
    }

    private func accessibilityLabel(_ date: Date, slot: DayFreeSlot?, hasRoom: Bool) -> String {
        let day = DateFormatter.mira("M月d日 EEEE").string(from: date)
        guard let durationMinutes, let slot else { return day }
        let longest = Self.durationText(slot.longestMinutes)
        return hasRoom
            ? "\(day)、\(Self.durationText(durationMinutes))入る空きあり、最長\(longest)"
            : "\(day)、最長の空き\(longest)"
    }

    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)分" }
        return rest == 0 ? "\(hours)時間" : "\(hours)時間\(rest)分"
    }
}
