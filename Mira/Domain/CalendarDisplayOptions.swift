import Foundation

struct CalendarDisplayOptions: Codable, Equatable {
    static let storageKey = "mira.calendar.displayOptions"

    enum LabelStyle: String, Codable, CaseIterable {
        case vivid, ink, color

        var title: String {
            switch self {
            case .vivid: "くっきり"
            case .ink: "黒文字"
            case .color: "カラー文字"
            }
        }
    }

    enum TextWeight: String, Codable, CaseIterable {
        case ultraLight, light, standard, bold

        var title: String {
            switch self {
            case .ultraLight: "極細"
            case .light: "細め"
            case .standard: "標準"
            case .bold: "太め"
            }
        }
    }

    enum TextSize: Int, Codable, CaseIterable {
        case smallest = -2, small, medium, large, largest

        var title: String {
            switch self {
            case .smallest: "極小"
            case .small: "小"
            case .medium: "中"
            case .large: "大"
            case .largest: "特大"
            }
        }
    }

    var showsStartTime = true
    var distinguishesTimedEvents = false
    var labelStyle: LabelStyle = .vivid
    var textWeight: TextWeight = .standard
    var textSize: TextSize = .medium
    var pagesVertically = false
    var alwaysShowsAgenda = false
    var agendaHeight = 4
    var memoLines = 1
    var uses24HourTime = true
    var showsWeekNumbers = false
    var showsRokuyo = false
    var daysOff: Set<Int> = [1]
    var minuteInterval = 1
    var newEventMinutes = 120
    var showsTimeKeyboard = false
    var defaultsToAllDay = false
    var dayStartHour = 0
    var dayEndHour = 24

    static func load(from defaults: UserDefaults) -> Self {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func time(_ date: Date) -> String {
        DateFormatter.mira(uses24HourTime ? "H:mm" : "ah:mm").string(from: date)
    }

    func timeDescription(for item: CalendarItemSnapshot) -> String {
        guard !item.isAllDay, item.exactTimeKnown else { return item.timeDescription }
        return "\(time(item.startDate))–\(time(item.endDate))"
    }

    func startTime(for item: CalendarItemSnapshot) -> String? {
        guard showsStartTime, item.kind == .confirmed, !item.isAllDay, item.exactTimeKnown else { return nil }
        return time(item.startDate)
    }

    static func weekNumber(for date: Date, startingOn weekday: WeekStartDay) -> Int {
        var calendar = Calendar.mira
        calendar.firstWeekday = weekday.calendarFirstWeekday
        calendar.minimumDaysInFirstWeek = 4
        return calendar.component(.weekOfYear, from: date)
    }

    static func rokuyo(for date: Date) -> String? {
        var lunar = Calendar(identifier: .chinese)
        lunar.timeZone = Calendar.mira.timeZone
        let terms = lunar.dateComponents([.month, .day], from: date)
        guard let month = terms.month, let day = terms.day else { return nil }
        return ["大安", "赤口", "先勝", "友引", "先負", "仏滅"][(month + day) % 6]
    }

    static func duplicateIDs(in items: [CalendarItemSnapshot]) -> Set<UUID> {
        var seen: Set<DuplicateEvent> = []
        var duplicates: Set<UUID> = []
        for item in items.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            guard item.kind == .confirmed, item.deviceEvent == nil, item.sourceID == nil,
                  item.conversationCaseID == nil else { continue }
            if !seen.insert(DuplicateEvent(item)).inserted { duplicates.insert(item.id) }
        }
        return duplicates
    }

    func newEventDraft(on date: Date) -> ManualEventDraft {
        var draft = ManualEventDraft(date: date)
        draft.endTime = draft.startTime.addingTimeInterval(TimeInterval(newEventMinutes * 60))
        draft.isAllDay = defaultsToAllDay
        return draft
    }

    func timeEntered(_ input: String, on date: Date) -> Date? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        let hours: Substring
        let minutes: Substring
        if parts.count == 2 {
            hours = parts[0]
            minutes = parts[1]
        } else if parts.count == 1, (3...4).contains(text.count) {
            hours = text.dropLast(2)
            minutes = text.suffix(2)
        } else {
            return nil
        }
        guard (1...2).contains(hours.count), minutes.count == 2,
              (hours + minutes).allSatisfy({ $0.isASCII && $0.isNumber }),
              let hour = Int(hours), let minute = Int(minutes),
              (0..<24).contains(hour), (0..<60).contains(minute),
              minute.isMultiple(of: minuteInterval) else { return nil }
        return date.setting(hour: hour, minute: minute)
    }
}

private struct DuplicateEvent: Hashable {
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let knownTime: Bool
    let important: Bool
    let occupiesTime: Bool
    let color: EventColorTag?
    let load: LoadClass
    let buffers: [Int]
    let band: SchedulingTimeBand?
    let duration: DurationBucket?

    init(_ item: CalendarItemSnapshot) {
        title = item.title
        start = item.startDate
        end = item.endDate
        allDay = item.isAllDay
        knownTime = item.exactTimeKnown
        important = item.isImportantTime
        occupiesTime = item.countsAgainstWhitespace
        color = item.colorTag
        load = item.loadClass
        buffers = [item.bufferBeforeMinutes, item.bufferAfterMinutes]
        band = item.schedulingTimeBand
        duration = item.durationBucket
    }
}
