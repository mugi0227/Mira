import Foundation

// MARK: - Week

struct WeekKey: Hashable, Codable, Sendable {
    let start: Date

    init(containing date: Date, calendar: Calendar = .mira) {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        start = interval?.start ?? calendar.startOfDay(for: date)
    }

    init(start: Date) {
        self.start = start
    }

    func interval(calendar: Calendar = .mira) -> DateInterval {
        DateInterval(start: start, end: start.addingDays(7, calendar: calendar))
    }

    func adding(weeks: Int, calendar: Calendar = .mira) -> WeekKey {
        WeekKey(start: start.addingDays(7 * weeks, calendar: calendar))
    }

    var days: [Date] {
        (0..<7).map { start.addingDays($0) }
    }
}

// MARK: - Intent

enum WeekScope: String, Codable, Sendable {
    case thisWeek
    case nextWeek

    var title: String {
        switch self {
        case .thisWeek: "今週"
        case .nextWeek: "来週"
        }
    }
}

enum PlanningIntent: Hashable, Sendable {
    case increaseSelfTime(scope: WeekScope, kind: MarginKind?)
    case protectEvenings(scope: WeekScope)
    case unknown

    var label: String {
        switch self {
        case .increaseSelfTime(let scope, let kind):
            if let kind { return "\(scope.title)、\(kind.title)を増やす" }
            return "\(scope.title)の自分の時間を増やす"
        case .protectEvenings(let scope):
            return "\(scope.title)の夜を空ける"
        case .unknown:
            return "分からない"
        }
    }
}

// MARK: - Suggestion

enum SuggestionOrigin: String, Codable, Sendable {
    case request
    case proactive
}

enum SuggestionStatus: String, Codable, Sendable {
    case pending
    case applied
    case dismissed
    case undone
}

struct SuggestedMargin: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var kind: MarginKind
    var startDate: Date
    var endDate: Date

    var interval: DateInterval { DateInterval(start: startDate, end: max(endDate, startDate)) }
    var hours: Double { endDate.timeIntervalSince(startDate) / 3600 }

    var timeOfDay: TimeOfDayKind {
        let hour = Calendar.mira.component(.hour, from: startDate)
        switch hour {
        case ..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }

    func calendarItem() -> CalendarItemSnapshot {
        CalendarItemSnapshot(
            id: id,
            title: kind.title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            kind: .margin,
            marginKind: kind,
            loadClass: .light,
            loadReason: "Miraの提案から確保した余白",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )
    }
}

struct Suggestion: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var origin: SuggestionOrigin
    var status: SuggestionStatus = .pending
    var title: String
    var reason: String
    var weekStart: Date
    var margins: [SuggestedMargin]
    var usesTrend: Bool
    var createdAt: Date
    var resolvedAt: Date?

    var addedHours: Double { margins.reduce(0) { $0 + $1.hours } }
    var week: WeekKey { WeekKey(start: weekStart) }
}

// MARK: - Trend

struct TimeTrend: Hashable, Sendable {
    var weekdayScores: [Int: Double]
    var bandScores: [TimeOfDayKind: Double]
    var sampleCount: Int

    static let empty = TimeTrend(weekdayScores: [:], bandScores: [:], sampleCount: 0)

    func bonus(for interval: DateInterval, band: TimeOfDayKind, calendar: Calendar = .mira) -> Double {
        let weekday = calendar.component(.weekday, from: interval.start)
        return (weekdayScores[weekday] ?? 0) * 12 + (bandScores[band] ?? 0) * 8
    }

    var summary: String? {
        guard let best = weekdayScores.filter({ $0.value > 0 }).max(by: { $0.value < $1.value }) else { return nil }
        let names = ["", "日", "月", "火", "水", "木", "金", "土"]
        guard (1...7).contains(best.key) else { return nil }
        return "\(names[best.key])曜の余白をよく採用しています"
    }
}

// MARK: - Reflection

enum Satisfaction: Int, Codable, CaseIterable, Identifiable, Sendable {
    case low = 1
    case okay = 2
    case good = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: "しんどかった"
        case .okay: "まあまあ"
        case .good: "よかった"
        }
    }

    var symbolName: String {
        switch self {
        case .low: "cloud.drizzle.fill"
        case .okay: "cloud.sun.fill"
        case .good: "sun.max.fill"
        }
    }
}

struct WeeklyReviewSummary: Hashable, Sendable {
    var week: WeekKey
    var selfTimeHours: Double
    var targetHours: Double
    var appliedSuggestions: Int
    var dismissedSuggestions: Int
    var satisfaction: Satisfaction?

    var ratio: Double {
        guard targetHours > 0 else { return 1 }
        return min(1, selfTimeHours / targetHours)
    }
}

// MARK: - Sharing

struct AvailabilityShareRule: Hashable, Sendable {
    var startDate: Date
    var days: Int = 14
    var bands: Set<TimeOfDayKind> = [.evening]
    var weekendBands: Set<TimeOfDayKind> = [.afternoon, .evening]
    var minimumHours: Int = 2
}

enum PublicBlockState: String, Hashable, Sendable {
    case free
    case busy

    var label: String {
        switch self {
        case .free: "空き"
        case .busy: "予定あり"
        }
    }
}

struct PublicBlock: Hashable, Sendable {
    var interval: DateInterval
    var state: PublicBlockState
}

struct PublicDay: Hashable, Sendable {
    var date: Date
    var blocks: [PublicBlock]
}
