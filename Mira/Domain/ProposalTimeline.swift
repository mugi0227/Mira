import Foundation

struct DayTimelineProposal: Identifiable {
    let event: CalendarItemSnapshot
    let conflicts: [ConflictEngine.Detail]

    var id: UUID { event.id }
}

enum ProposalTimeline {
    static func scrollHour(for proposal: DayTimelineProposal, on date: Date, calendar: Calendar = .mira) -> Int {
        let earliest = ([proposal.event.startDate] + proposal.conflicts.map(\.start)).min() ?? proposal.event.startDate
        let start = max(calendar.startOfDay(for: date), earliest)
        return max(0, calendar.component(.hour, from: start) - 1)
    }

    static func overlap(_ lhs: DateInterval, _ rhs: DateInterval) -> DateInterval? {
        let start = max(lhs.start, rhs.start)
        let end = min(lhs.end, rhs.end)
        guard start < end else { return nil }
        return DateInterval(start: start, end: end)
    }

    static func overlappingItems(_ items: [CalendarItemSnapshot], proposal: CalendarItemSnapshot) -> [CalendarItemSnapshot] {
        guard proposal.kind != .confirmed || proposal.countsAgainstWhitespace else { return [] }
        return items.filter {
            $0.id != proposal.id && ($0.countsAgainstWhitespace || $0.kind == .margin)
                && overlap($0.occupiedInterval, proposal.occupiedInterval) != nil
        }
    }
}
