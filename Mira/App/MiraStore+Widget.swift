import Foundation
import WidgetKit

@MainActor
extension MiraStore {
    /// Builds what the widgets show from the calendar as it is now.
    nonisolated static func widgetSnapshot(items: [CalendarItemSnapshot], now: Date) -> MiraWidgetSnapshot {
        let calendar = MiraWidgetCalendar.calendar
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: MiraWidgetSnapshot.horizonDays, to: start) ?? start
        let entries = items
            .filter { $0.endDate > start && $0.startDate < end }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
                return lhs.isAllDay && !rhs.isAllDay
            }
            .map { item -> MiraWidgetSnapshot.Entry in
                let kind: MiraWidgetSnapshot.Entry.Kind = item.kind == .margin ? .margin : (item.kind == .birthday ? .birthday : .plan)
                let title = item.kind == .margin
                    ? (item.marginKind.map { item.title == $0.title ? $0.shortTitle : item.title } ?? item.title)
                    : item.title
                return MiraWidgetSnapshot.Entry(
                    id: item.id,
                    title: title,
                    start: item.startDate,
                    end: item.endDate,
                    isAllDay: item.isAllDay,
                    kind: kind,
                    tintHex: widgetTint(for: item),
                    symbol: widgetSymbol(for: item)
                )
            }
        return MiraWidgetSnapshot(generatedAt: now, entries: entries)
    }

    /// Writes the snapshot only when it changed, then asks widgets to redraw.
    func publishWidgetSnapshot() {
        let snapshot = Self.widgetSnapshot(items: items, now: now)
        let signature = snapshot.entries.hashValue
        guard signature != lastWidgetSignature, MiraWidgetSnapshot.fileURL != nil else { return }
        lastWidgetSignature = signature
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    nonisolated private static func widgetTint(for item: CalendarItemSnapshot) -> UInt32 {
        if let tag = item.colorTag, item.kind != .margin { return tag.barHex }
        switch item.kind {
        case .margin:
            return item.marginKind == .reading ? 0xD9A441 : 0x62BE98
        case .birthday:
            return 0xE8879F
        default:
            return item.isImportantTime ? 0xE8879F : 0x6F8FAF
        }
    }

    nonisolated private static func widgetSymbol(for item: CalendarItemSnapshot) -> String {
        if item.kind == .margin { return item.marginKind?.symbolName ?? "leaf.fill" }
        if item.kind == .birthday { return "gift.fill" }
        if item.isImportantTime { return "heart.fill" }
        return "calendar"
    }
}
