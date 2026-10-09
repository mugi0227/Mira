import Foundation

/// What the app hands to its widgets: the next two weeks of plans and
/// margins, flattened so the widget needs none of the app's models.
struct MiraWidgetSnapshot: Codable, Hashable, Sendable {
    struct Entry: Codable, Hashable, Sendable, Identifiable {
        enum Kind: String, Codable, Sendable { case plan, margin, birthday }

        var id: UUID
        var title: String
        var start: Date
        var end: Date
        var isAllDay: Bool
        var kind: Kind
        var tintHex: UInt32
        var symbol: String
    }

    var generatedAt: Date
    var entries: [Entry]

    static let appGroupID = "group.jp.mugi.mira"
    static let horizonDays = 14

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func load() -> MiraWidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MiraWidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Queries the widget asks

    func today(at date: Date) -> [Entry] {
        entries.filter { MiraWidgetCalendar.calendar.isDate($0.start, inSameDayAs: date) && ($0.isAllDay || $0.end > date) }
    }

    func nextMargin(after date: Date) -> Entry? {
        entries.first { $0.kind == .margin && $0.end > date }
    }

    func nextPlan(after date: Date) -> Entry? {
        entries.first { $0.kind == .plan && !$0.isAllDay && $0.end > date }
    }

    static let placeholder: MiraWidgetSnapshot = {
        let now = Date()
        let calendar = MiraWidgetCalendar.calendar
        let evening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return MiraWidgetSnapshot(generatedAt: now, entries: [
            Entry(id: UUID(), title: "友達とご飯", start: evening, end: evening.addingTimeInterval(7200),
                  isAllDay: false, kind: .plan, tintHex: 0xE8879F, symbol: "calendar"),
            Entry(id: UUID(), title: "休息", start: tomorrow, end: tomorrow.addingTimeInterval(86_400),
                  isAllDay: true, kind: .margin, tintHex: 0x62BE98, symbol: "moon.zzz.fill")
        ])
    }()
}

/// The widget must read time the way the app plans it.
enum MiraWidgetCalendar {
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "ja_JP")
        value.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return value
    }

    static var style: Date.FormatStyle {
        Date.FormatStyle(locale: Locale(identifier: "ja_JP"), calendar: calendar, timeZone: calendar.timeZone)
    }

    static func time(_ date: Date) -> String {
        date.formatted(style.hour().minute())
    }

    static func shortDay(_ date: Date) -> String {
        date.formatted(style.month().day().weekday(.abbreviated))
    }
}
