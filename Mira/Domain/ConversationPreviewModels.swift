import Foundation

struct EventCreationPreview: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var caseID: UUID?
    var event: CalendarItemSnapshot
    var conflicts: [String]
    var impact: ScheduleImpact
}

struct ConversationClarification: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var caseID: UUID?
    var question: String
    var options: [String]
    var originalText: String
}

struct ConversationReply: Identifiable, Hashable, Sendable {
    var id = UUID()
    var caseID: UUID?
    var title: String
    var text: String
    var isCopyable: Bool
}
