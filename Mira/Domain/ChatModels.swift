import Foundation

/// One bubble in the Mira chat. Assistant messages can carry cards that the
/// person acts on; nothing in the calendar changes until a card is approved.
struct ChatMessage: Identifiable, Hashable, Sendable {
    enum Role: String, Sendable { case user, assistant }

    let id: UUID
    var role: Role
    var text: String
    var activities: [ChatActivity]
    var cards: [ChatCard]
    var isStreaming: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        activities: [ChatActivity] = [],
        cards: [ChatCard] = [],
        isStreaming: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.activities = activities
        self.cards = cards
        self.isStreaming = isStreaming
        self.createdAt = createdAt
    }
}

/// A visible trace of what the agent looked at, so its answer is checkable.
struct ChatActivity: Identifiable, Hashable, Sendable {
    let id = UUID()
    var symbol: String
    var text: String
}

enum ChatCard: Identifiable, Hashable, Sendable {
    case schedule(ChatScheduleSummary)
    case openSlots(ChatOpenSlots)
    case eventProposal(ChatEventProposal)
    case moveProposal(ChatMoveProposal)
    case message(ChatMessageDraft)
    case balance(ChatBalanceSummary)

    var id: UUID {
        switch self {
        case .schedule(let value): value.id
        case .openSlots(let value): value.id
        case .eventProposal(let value): value.id
        case .moveProposal(let value): value.id
        case .message(let value): value.id
        case .balance(let value): value.id
        }
    }
}

struct ChatScheduleSummary: Hashable, Sendable {
    let id = UUID()
    var title: String
    var items: [CalendarItemSnapshot]
}

struct ChatOpenSlot: Identifiable, Hashable, Sendable {
    let id = UUID()
    var start: Date
    var end: Date
    var band: SchedulingTimeBand
    var note: String?
}

struct ChatOpenSlots: Hashable, Sendable {
    let id = UUID()
    var purpose: String
    var slots: [ChatOpenSlot]
}

enum ChatProposalState: Hashable, Sendable {
    case pending
    case applied
    case dismissed
}

struct ChatEventProposal: Hashable, Sendable {
    let id = UUID()
    var event: CalendarItemSnapshot
    var impact: ScheduleImpact
    var conflicts: [String]
    var state: ChatProposalState = .pending

    var needsCare: Bool {
        !conflicts.isEmpty || !impact.overlappingMargins.isEmpty || impact.protectionLevel != .flexible
    }
}

struct ChatMoveProposal: Hashable, Sendable {
    let id = UUID()
    var preview: ChangePreview
    var state: ChatProposalState = .pending

    var needsCare: Bool {
        !preview.conflicts.isEmpty || !preview.impact.overlappingMargins.isEmpty
    }
}

struct ChatMessageDraft: Hashable, Sendable {
    let id = UUID()
    var purpose: String
    var text: String
}

struct ChatBalanceSummary: Hashable, Sendable {
    let id = UUID()
    var month: Date
    var lines: [ChatBalanceLine]
}

struct ChatBalanceLine: Hashable, Sendable {
    var kind: MarginKind
    var current: Int
    var target: Int
}
