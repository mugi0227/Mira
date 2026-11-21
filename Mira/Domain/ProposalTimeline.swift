import Foundation

struct DayTimelineProposal: Identifiable {
    let event: CalendarItemSnapshot
    let conflicts: [ConflictEngine.Detail]

    var id: UUID { event.id }
}

enum ProposalTimeline {
    static func overlap(_ lhs: DateInterval, _ rhs: DateInterval) -> DateInterval? {
        let start = max(lhs.start, rhs.start)
        let end = min(lhs.end, rhs.end)
        guard start < end else { return nil }
        return DateInterval(start: start, end: end)
    }

    static func overlappingItems(_ items: [CalendarItemSnapshot], proposal: CalendarItemSnapshot) -> [CalendarItemSnapshot] {
        items.filter {
            $0.id != proposal.id && ($0.kind == .confirmed || $0.kind == .margin)
                && overlap($0.occupiedInterval, proposal.occupiedInterval) != nil
        }
    }
}
