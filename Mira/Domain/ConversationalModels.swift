import Foundation

// MARK: - Preference and scheduling primitives

enum MarginComfortLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case standard
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "少なめ"
        case .standard: "ふつう"
        case .high: "多め"
        }
    }

    var subtitle: String {
        switch self {
        case .low: "最低限の回復時間を確保"
        case .standard: "予定負荷に合わせた標準量"
        case .high: "予定を詰めやすい人向けに余裕を多めに"
        }
    }

    var multiplier: Double {
        switch self {
        case .low: 0.78
        case .standard: 1.0
        case .high: 1.28
        }
    }
}

enum DurationBucket: String, Codable, CaseIterable, Identifiable, Sendable {
    case short
    case halfDay
    case fullDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short: "1〜2時間"
        case .halfDay: "半日"
        case .fullDay: "終日"
        }
    }

    var representativeMinutes: Int {
        switch self {
        case .short: 120
        case .halfDay: 300
        case .fullDay: 720
        }
    }

    var selectableBands: [SchedulingTimeBand] {
        switch self {
        case .short: [.morning, .midday, .evening]
        case .halfDay: [.firstHalf, .secondHalf]
        case .fullDay: [.allDay]
        }
    }
}

enum SchedulingTimeBand: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning
    case midday
    case evening
    case firstHalf
    case secondHalf
    case allDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "朝"
        case .midday: "昼"
        case .evening: "夜"
        case .firstHalf: "午前"
        case .secondHalf: "午後"
        case .allDay: "終日"
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sunrise.fill"
        case .midday: "sun.max.fill"
        case .evening: "moon.stars.fill"
        case .firstHalf: "sunrise.fill"
        case .secondHalf: "sun.haze.fill"
        case .allDay: "rectangle.grid.1x2.fill"
        }
    }

    var representativeStartHour: Int {
        switch self {
        case .morning: 9
        case .midday: 13
        case .evening: 19
        case .firstHalf: 9
        case .secondHalf: 13
        case .allDay: 9
        }
    }

    var representativeEndHour: Int {
        switch self {
        case .morning: 12
        case .midday: 17
        case .evening: 23
        case .firstHalf: 13
        case .secondHalf: 18
        case .allDay: 21
        }
    }

    var legacyTimeOfDay: TimeOfDayKind {
        switch self {
        case .morning, .firstHalf: .morning
        case .midday, .secondHalf: .afternoon
        case .evening: .evening
        case .allDay: .allDay
        }
    }

    func representativeInterval(on day: Date, duration: DurationBucket, calendar: Calendar = .mira) -> DateInterval {
        let start = day.setting(hour: representativeStartHour, calendar: calendar)
        let bandEnd = day.setting(hour: representativeEndHour, calendar: calendar)
        let durationEnd = start.addingTimeInterval(TimeInterval(duration.representativeMinutes * 60))
        let end = duration == .fullDay ? bandEnd : min(bandEnd, durationEnd)
        return DateInterval(start: start, end: max(start, end))
    }
}

// MARK: - Conversational assistant

enum ConversationIntent: String, Codable, CaseIterable, Sendable {
    case addEvent
    case checkInvitation
    case findDates
    case declineInvitation
    case updateExisting
    case askAboutExisting
    case unknown
}

enum ConversationRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

enum ConversationCaseKind: String, Codable, CaseIterable, Sendable {
    case adjustment
    case invitation
    case confirmedEvent
    case draft

    var title: String {
        switch self {
        case .adjustment: "進行中"
        case .invitation: "検討中"
        case .confirmedEvent: "確定予定"
        case .draft: "下書き"
        }
    }
}

enum ConversationCaseStatus: String, Codable, Sendable {
    case active
    case waiting
    case confirmed
    case completed
    case archived
}

struct ConversationTurnSnapshot: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var role: ConversationRole
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), role: ConversationRole, text: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

struct ConversationCaseState: Codable, Hashable, Sendable {
    var relatedItemID: UUID?
    var relatedAdjustmentID: UUID?
    var relatedInvitationID: UUID?
    var person: String?
    var dateRangeStart: Date?
    var dateRangeEnd: Date?
    var durationBucket: DurationBucket?
    var allowedTimeBands: [SchedulingTimeBand]
    var explicitConstraints: [String]
    var candidates: [CandidateSlotSnapshot]
    var lastIntent: ConversationIntent

    init(
        relatedItemID: UUID? = nil,
        relatedAdjustmentID: UUID? = nil,
        relatedInvitationID: UUID? = nil,
        person: String? = nil,
        dateRangeStart: Date? = nil,
        dateRangeEnd: Date? = nil,
        durationBucket: DurationBucket? = nil,
        allowedTimeBands: [SchedulingTimeBand] = [],
        explicitConstraints: [String] = [],
        candidates: [CandidateSlotSnapshot] = [],
        lastIntent: ConversationIntent = .unknown
    ) {
        self.relatedItemID = relatedItemID
        self.relatedAdjustmentID = relatedAdjustmentID
        self.relatedInvitationID = relatedInvitationID
        self.person = person
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.durationBucket = durationBucket
        self.allowedTimeBands = allowedTimeBands
        self.explicitConstraints = explicitConstraints
        self.candidates = candidates
        self.lastIntent = lastIntent
    }
}

struct ContextSearchResult: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: ConversationCaseKind
    var title: String
    var subtitle: String
    var startDate: Date?
    var endDate: Date?
    var relatedCaseID: UUID?
    var relatedItemID: UUID?
    var relatedAdjustmentID: UUID?
    var relatedInvitationID: UUID?
    var score: Double
    var isPast: Bool
}

struct ConversationInterpretation: Codable, Hashable, Sendable {
    var intent: ConversationIntent
    var title: String
    var person: String?
    var candidateDates: [Date]
    var dateRangeStart: Date?
    var dateRangeEnd: Date?
    var durationBucket: DurationBucket?
    var timeBands: [SchedulingTimeBand]
    var exactStartDate: Date?
    var exactEndDate: Date?
    var inferredFields: Set<String>
    var explicitConstraints: [String]
    var needsClarification: Bool
    var clarificationQuestion: String?
    var clarificationOptions: [String]
    var matchedContextID: UUID?
    var confidence: Double
    var source: String

    static func unknown(_ text: String) -> ConversationInterpretation {
        ConversationInterpretation(
            intent: .unknown,
            title: text,
            person: nil,
            candidateDates: [],
            dateRangeStart: nil,
            dateRangeEnd: nil,
            durationBucket: nil,
            timeBands: [],
            exactStartDate: nil,
            exactEndDate: nil,
            inferredFields: [],
            explicitConstraints: [],
            needsClarification: true,
            clarificationQuestion: "どうしたい予定か教えてにゃ",
            clarificationOptions: ["行けそうか見る", "日程を探す", "予定に入れる", "断る文を作る"],
            matchedContextID: nil,
            confidence: 0,
            source: "fallback"
        )
    }
}

// MARK: - Candidate recommendation and preview models

struct CandidateRecommendation: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var day: Date
    var timeBand: SchedulingTimeBand
    var durationBucket: DurationBucket
    var score: Double
    var reasons: [String]
    var conflicts: [String]
    var isRecommended: Bool

    init(
        id: UUID = UUID(),
        day: Date,
        timeBand: SchedulingTimeBand,
        durationBucket: DurationBucket,
        score: Double,
        reasons: [String] = [],
        conflicts: [String] = [],
        isRecommended: Bool = false
    ) {
        self.id = id
        self.day = day.startOfDay()
        self.timeBand = timeBand
        self.durationBucket = durationBucket
        self.score = score
        self.reasons = reasons
        self.conflicts = conflicts
        self.isRecommended = isRecommended
    }

    var representativeInterval: DateInterval {
        timeBand.representativeInterval(on: day, duration: durationBucket)
    }

    var candidateSnapshot: CandidateSlotSnapshot {
        CandidateSlotSnapshot(
            startDate: representativeInterval.start,
            endDate: representativeInterval.end,
            timeOfDay: timeBand.legacyTimeOfDay,
            schedulingTimeBand: timeBand,
            durationBucket: durationBucket,
            exactTimeKnown: false,
            isRecommended: isRecommended,
            recommendationScore: score
        )
    }
}

struct SchedulingDraft: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var conversationCaseID: UUID?
    var title: String
    var person: String?
    var month: Date
    var dateRangeStart: Date
    var dateRangeEnd: Date
    var durationBucket: DurationBucket
    var timeBands: [SchedulingTimeBand]
    var inferredFields: Set<String>
    var recommendations: [CandidateRecommendation]
    var selectedRecommendationIDs: Set<UUID>
    var detailedTimeEnabled: Bool
    var detailedStartHour: Int?
    var detailedStartMinute: Int?

    init(
        id: UUID = UUID(),
        conversationCaseID: UUID? = nil,
        title: String,
        person: String? = nil,
        month: Date,
        dateRangeStart: Date,
        dateRangeEnd: Date,
        durationBucket: DurationBucket,
        timeBands: [SchedulingTimeBand],
        inferredFields: Set<String> = [],
        recommendations: [CandidateRecommendation] = [],
        selectedRecommendationIDs: Set<UUID> = [],
        detailedTimeEnabled: Bool = false,
        detailedStartHour: Int? = nil,
        detailedStartMinute: Int? = nil
    ) {
        self.id = id
        self.conversationCaseID = conversationCaseID
        self.title = title
        self.person = person
        self.month = month
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.durationBucket = durationBucket
        self.timeBands = timeBands
        self.inferredFields = inferredFields
        self.recommendations = recommendations
        self.selectedRecommendationIDs = selectedRecommendationIDs
        self.detailedTimeEnabled = detailedTimeEnabled
        self.detailedStartHour = detailedStartHour
        self.detailedStartMinute = detailedStartMinute
    }

    var selectedRecommendations: [CandidateRecommendation] {
        recommendations.filter { selectedRecommendationIDs.contains($0.id) }
    }
}

struct ChangePreview: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var caseID: UUID?
    var itemID: UUID
    var title: String
    var before: CalendarItemSnapshot
    var after: CalendarItemSnapshot
    var conflicts: [String]
    var impact: ScheduleImpact
}

struct DeclineDraft: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var caseID: UUID?
    var title: String
    var person: String?
    var text: String
    var tone: String
    var audience: DeclineAudience
    var generationIndex: Int
}

enum DeclineAudience: String, Codable, CaseIterable, Identifiable, Sendable {
    case friend
    case coworker
    case supervisor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friend: "友達"
        case .coworker: "会社の人・同期"
        case .supervisor: "上司"
        }
    }

    var toneTitle: String {
        switch self {
        case .friend: "親しみのある言葉"
        case .coworker: "丁寧すぎない敬語"
        case .supervisor: "失礼のない敬語"
        }
    }
}

struct MarginRecommendation: Hashable, Sendable {
    var month: Date
    var comfortLevel: MarginComfortLevel
    var targets: [MarginKind: Int]
    var reasons: [String]
}

struct RebalanceMove: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var marginItemID: UUID
    var title: String
    var from: Date
    var to: Date
    var benefit: String
    var durationSeconds: TimeInterval?
    var marginKind: MarginKind?
    var isAllDay: Bool?

    init(id: UUID = UUID(), marginItemID: UUID, title: String, from: Date, to: Date, benefit: String,
         durationSeconds: TimeInterval? = nil, marginKind: MarginKind? = nil, isAllDay: Bool? = nil) {
        self.id = id
        self.marginItemID = marginItemID
        self.title = title
        self.from = from
        self.to = to
        self.benefit = benefit
        self.durationSeconds = durationSeconds
        self.marginKind = marginKind
        self.isAllDay = isAllDay
    }
}

struct RebalanceProposal: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var month: Date
    var moves: [RebalanceMove]
    var summary: String
    var stateHash: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        month: Date,
        moves: [RebalanceMove],
        summary: String,
        stateHash: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.month = month
        self.moves = moves
        self.summary = summary
        self.stateHash = stateHash
        self.createdAt = createdAt
    }
}
