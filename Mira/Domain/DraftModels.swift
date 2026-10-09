import Foundation

/// A saved intention is separate from a confirmed calendar entry.
struct ManualEventDraft: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var title = ""
    var date: Date
    var startTime: Date
    var endTime: Date
    var isAllDay = false
    var isImportant = false
    var marginKind: MarginKind = .rest
    var isMargin = false
    var colorTag: EventColorTag?

    init(date: Date, isMargin: Bool = false) {
        self.date = date
        self.startTime = date.setting(hour: 18)
        self.endTime = date.setting(hour: 20)
        self.isMargin = isMargin
    }
}

enum SavedDraftContent: Codable, Hashable, Sendable {
    case eventForm(ManualEventDraft)
    case scheduling(SchedulingDraft, ConversationIntent)
    case decline(DeclineDraft)
    case change(ChangePreview)
    case eventPreview(EventCreationPreview)
    case clarification(ConversationClarification, ConversationInterpretation?)

    var id: UUID {
        switch self {
        case .eventForm(let value): value.id
        case .scheduling(let value, _): value.id
        case .decline(let value): value.id
        case .change(let value): value.id
        case .eventPreview(let value): value.id
        case .clarification(let value, _): value.id
        }
    }

    var title: String {
        let value: String
        switch self {
        case .eventForm(let draft): value = draft.isMargin ? draft.marginKind.title : draft.title
        case .scheduling(let draft, _): value = draft.title
        case .decline(let draft): value = draft.title
        case .change(let preview): value = preview.title
        case .eventPreview(let preview): value = preview.event.title
        case .clarification(let question, _): value = question.originalText
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "書きかけの予定" : value
    }

    var nextStep: String {
        switch self {
        case .eventForm: "入力した内容から続きを決める"
        case .scheduling: "選んだ日程候補の続きから"
        case .decline: "返信文を確認する"
        case .change: "変更の影響を確認する"
        case .eventPreview: "予定を入れる前の確認から"
        case .clarification(let value, _): value.question
        }
    }

    /// A regenerated suggestion replaces the previous draft for that same case.
    var workflowKey: String? {
        switch self {
        case .eventForm: nil
        case .scheduling(let draft, _): draft.conversationCaseID.map { "scheduling:\($0)" }
        case .decline(let draft): draft.caseID.map { "decline:\($0)" }
        case .change(let draft): draft.caseID.map { "change:\($0)" }
        case .eventPreview(let draft): draft.caseID.map { "event:\($0)" }
        case .clarification(let draft, _): draft.caseID.map { "clarification:\($0)" }
        }
    }
}

struct SavedMiraDraft: Identifiable, Codable, Hashable, Sendable {
    var content: SavedDraftContent
    var updatedAt: Date
    var id: UUID { content.id }
}

struct OnboardingDraft: Codable, Hashable, Sendable {
    struct Rule: Codable, Hashable, Sendable {
        var weekday: Int
        var isEnabled: Bool
        var startMinute: Int
        var endMinute: Int
    }

    var step: Int
    var selections: Set<MarginKind>
    var targets: [MarginKind: Int]
    var automatic: Bool
    var comfort: MarginComfortLevel
    var rules: [Rule]
    var weekStartDay: WeekStartDay
    var useDeviceHolidays: Bool
    var quickStart: Bool? = nil
}

struct DraftArchive: Codable, Hashable, Sendable {
    var version = 1
    var quickInputText = ""
    var drafts: [SavedMiraDraft] = []
    var onboarding: OnboardingDraft?
    var inputContext: ContextSearchResult?

    static let empty = DraftArchive()
}
