import Foundation

// MARK: - Shared enums

enum AppThemeKind: String, Codable, CaseIterable, Identifiable {
    case softMinimal
    case pixelCat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .softMinimal: "Soft Minimal"
        case .pixelCat: "Pixel Cat"
        }
    }
}

enum WeekStartDay: String, Codable, CaseIterable, Identifiable {
    case monday
    case sunday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monday: "月曜始まり"
        case .sunday: "日曜始まり"
        }
    }

    var calendarFirstWeekday: Int {
        switch self {
        case .monday: 2
        case .sunday: 1
        }
    }

    var weekdaySymbols: [String] {
        switch self {
        case .monday: ["月", "火", "水", "木", "金", "土", "日"]
        case .sunday: ["日", "月", "火", "水", "木", "金", "土"]
        }
    }
}

enum CalendarItemKind: String, Codable, CaseIterable {
    case confirmed
    case margin
    case birthday
}

enum MarginKind: String, Codable, CaseIterable, Identifiable {
    case rest
    case freeEvening
    case reading
    case solo
    case personalProject
    case importantPeople
    case custom

    var id: String { rawValue }

    /// `freeEvening` and `solo` remain decodable so existing installs can be
    /// migrated without losing saved goals or margin items.
    var canonicalKind: MarginKind {
        switch self {
        case .freeEvening, .solo: .rest
        default: self
        }
    }

    var isLegacyRestAlias: Bool {
        self == .freeEvening || self == .solo
    }

    static var userSelectableCases: [MarginKind] {
        allCases.filter { !$0.isLegacyRestAlias }
    }

    var title: String {
        switch self {
        case .rest: "何もしない・休息"
        case .freeEvening: "何もしない・休息"
        case .reading: "読書・映像"
        case .solo: "何もしない・休息"
        case .personalProject: "やりたいこと"
        case .importantPeople: "大切な人との時間"
        case .custom: "自分の余白"
        }
    }

    var symbolName: String {
        switch self {
        case .rest: "moon.zzz.fill"
        case .freeEvening: "moon.zzz.fill"
        case .reading: "books.vertical.fill"
        case .solo: "moon.zzz.fill"
        case .personalProject: "wand.and.stars"
        case .importantPeople: "heart.fill"
        case .custom: "leaf.fill"
        }
    }

    var defaultDurationHours: Int {
        switch self {
        case .rest: 12
        case .freeEvening: 12
        case .reading: 5
        case .solo: 12
        case .personalProject: 5
        case .importantPeople: 5
        case .custom: 4
        }
    }

    var defaultPriority: Int {
        switch self {
        case .rest: 100
        case .freeEvening: 100
        case .solo: 100
        case .reading: 65
        case .personalProject: 60
        case .importantPeople: 55
        case .custom: 50
        }
    }
}

enum LoadClass: String, Codable, CaseIterable, Identifiable, Comparable {
    case light
    case normal
    case heavy
    case veryHeavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "軽め"
        case .normal: "ふつう"
        case .heavy: "重め"
        case .veryHeavy: "かなり重い"
        }
    }

    var score: Int {
        switch self {
        case .light: 15
        case .normal: 45
        case .heavy: 70
        case .veryHeavy: 92
        }
    }

    static func < (lhs: LoadClass, rhs: LoadClass) -> Bool {
        lhs.score < rhs.score
    }

    static func from(score: Int) -> LoadClass {
        switch score {
        case ..<25: .light
        case 25..<60: .normal
        case 60..<85: .heavy
        default: .veryHeavy
        }
    }
}

enum ProtectionLevel: String, Codable {
    case flexible
    case caution
    case strong
    case finalDefense
}

enum AdjustmentStatus: String, Codable {
    case draft
    case waiting
    case confirmed
    case cancelled
}

enum InvitationStatus: String, Codable {
    case considering
    case accepted
    case adjustment
    case declined
    case archived
}

enum CandidateStatus: String, Codable {
    case held
    case confirmed
    case released
}

enum TimeOfDayKind: String, Codable, CaseIterable, Identifiable {
    case allDay
    case morning
    case afternoon
    case evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allDay: "終日"
        case .morning: "午前"
        case .afternoon: "午後"
        case .evening: "夜"
        }
    }
}

enum CatMood: String, Codable {
    case idle
    case relaxed
    case sleeping
    case thinking
    case tired
    case happy
    case warning
    case celebrating
    case inviting
}

// MARK: - Domain snapshots

struct CalendarItemSnapshot: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var kind: CalendarItemKind
    var marginKind: MarginKind?
    var loadClass: LoadClass
    var loadReason: String
    var bufferBeforeMinutes: Int
    var bufferAfterMinutes: Int
    var isImportantTime: Bool
    var sourceID: UUID?
    var schedulingTimeBand: SchedulingTimeBand? = nil
    var durationBucket: DurationBucket? = nil
    var exactTimeKnown: Bool = true
    var conversationCaseID: UUID? = nil
    var deviceEvent: DeviceEventReference? = nil

    var occupiedInterval: DateInterval {
        let start = Calendar.mira.date(byAdding: .minute, value: -bufferBeforeMinutes, to: startDate) ?? startDate
        let end = Calendar.mira.date(byAdding: .minute, value: bufferAfterMinutes, to: endDate) ?? endDate
        return DateInterval(start: start, end: max(end, start))
    }

    var timeDescription: String {
        if !exactTimeKnown, let schedulingTimeBand {
            let duration = durationBucket.map { "・\($0.title)" } ?? ""
            return "\(schedulingTimeBand.title)・時間未定\(duration)"
        }
        if isAllDay { return "終日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return "\(formatter.string(from: startDate))–\(formatter.string(from: endDate))"
    }
}

struct MarginGoalSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    var year: Int
    var month: Int
    var kind: MarginKind
    var targetCount: Int
    var durationHours: Int
    var priority: Int
    var isEnabled: Bool
}

struct CandidateSlotSnapshot: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var timeOfDay: TimeOfDayKind
    var status: CandidateStatus
    var overlapOverrideApproved: Bool
    var schedulingTimeBand: SchedulingTimeBand?
    var durationBucket: DurationBucket?
    var exactTimeKnown: Bool?
    var isRecommended: Bool?
    var recommendationScore: Double?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        timeOfDay: TimeOfDayKind,
        status: CandidateStatus = .held,
        overlapOverrideApproved: Bool = false,
        schedulingTimeBand: SchedulingTimeBand? = nil,
        durationBucket: DurationBucket? = nil,
        exactTimeKnown: Bool? = true,
        isRecommended: Bool? = false,
        recommendationScore: Double? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.timeOfDay = timeOfDay
        self.status = status
        self.overlapOverrideApproved = overlapOverrideApproved
        self.schedulingTimeBand = schedulingTimeBand
        self.durationBucket = durationBucket
        self.exactTimeKnown = exactTimeKnown
        self.isRecommended = isRecommended
        self.recommendationScore = recommendationScore
    }

    var interval: DateInterval { DateInterval(start: startDate, end: max(endDate, startDate)) }

    var displayTimeBand: SchedulingTimeBand {
        if let schedulingTimeBand { return schedulingTimeBand }
        switch timeOfDay {
        case .allDay: return .allDay
        case .morning: return .morning
        case .afternoon: return .midday
        case .evening: return .evening
        }
    }

    var displayDuration: DurationBucket {
        durationBucket ?? (timeOfDay == .allDay ? .fullDay : .short)
    }
}

struct LoadEvaluation: Hashable, Sendable {
    var loadClass: LoadClass
    var score: Int
    var reason: String
    var category: String
    var likelyOutsideHome: Bool
    var bufferBeforeMinutes: Int
    var bufferAfterMinutes: Int
    var source: String
}

struct ScheduleImpact: Codable, Hashable, Sendable {
    var overlappingMargins: [CalendarItemSnapshot]
    var freeEveningDelta: Double
    var projectedGoalDeficits: [MarginKind: Int]
    var relocationCandidates: [Date]
    var protectionLevel: ProtectionLevel
    var message: String

    static let none = ScheduleImpact(
        overlappingMargins: [],
        freeEveningDelta: 0,
        projectedGoalDeficits: [:],
        relocationCandidates: [],
        protectionLevel: .flexible,
        message: "この予定を入れても、余白は守れそうです。"
    )
}

struct AssistantMessage: Identifiable, Hashable, Sendable {
    let id = UUID()
    var title: String
    var body: String
    var mood: CatMood
    var severity: Int
    var actionTitle: String?
}

struct MonthKey: Hashable, Sendable {
    let year: Int
    let month: Int

    init(date: Date, calendar: Calendar = .mira) {
        let components = calendar.dateComponents([.year, .month], from: date)
        year = components.year ?? 1970
        month = components.month ?? 1
    }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    var firstDay: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.mira.date(from: components) ?? .now
    }

    var interval: DateInterval {
        let start = firstDay
        let end = Calendar.mira.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }
}

struct BaseAvailabilityRule: Hashable, Sendable {
    var weekday: Int
    var startMinute: Int
    var endMinute: Int
}

struct MarginPlacementProposal: Hashable, Sendable {
    var slots: [CalendarItemSnapshot]
    var unmetGoals: [MarginKind: Int]
    var score: Double
}

struct EventSemanticClassification: Hashable, Sendable {
    var category: String
    var estimatedLoad: LoadClass
    var likelyOutsideHome: Bool
    var estimatedDurationHours: Int
    var confidence: Double
    var shortReason: String
    var source: String
}
