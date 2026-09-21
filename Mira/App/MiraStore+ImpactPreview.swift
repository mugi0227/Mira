import Foundation

/// A review is valid only while the calendar and scheduling constraints are unchanged.
struct ScheduleReviewContext: Equatable, Sendable {
    var items: Set<CalendarItemSnapshot>
    var goals: Set<MarginGoalSnapshot>
    var heldCandidates: Set<CandidateSlotSnapshot>
    var baseRules: Set<BaseAvailabilityRule>
}

struct CandidateConfirmationReview: Identifiable, Sendable {
    var id: UUID { event.id }
    var sessionID: UUID
    var sessionCandidates: Set<CandidateSlotSnapshot>
    var candidate: CandidateSlotSnapshot
    var event: CalendarItemSnapshot
    var impact: ScheduleImpact
    var conflicts: [String]
    var goalDeficits: [MarginKind: Int]
    var context: ScheduleReviewContext

    var needsException: Bool {
        !conflicts.isEmpty || !impact.overlappingMargins.isEmpty || !goalDeficits.isEmpty
    }

    var summary: String {
        var lines = conflicts
        if !impact.overlappingMargins.isEmpty { lines.append(impact.message) }
        lines.append(contentsOf: goalDeficits.keys.sorted { $0.rawValue < $1.rawValue }.map {
            "\($0.title)があと\(goalDeficits[$0] ?? 0)回不足する見込みです"
        })
        if lines.isEmpty { lines.append("重複と余白への影響はありません。") }
        lines.append("この日を予定に登録し、ほかの候補を解放します。")
        return lines.joined(separator: "\n")
    }
}

@MainActor
extension MiraStore {
    func scheduleReviewContext(excludingAdjustmentID: UUID? = nil) -> ScheduleReviewContext {
        ScheduleReviewContext(
            items: Set(items),
            goals: Set(goals),
            heldCandidates: Set(heldCandidates(excluding: excludingAdjustmentID)),
            baseRules: Set(fetchBaseRules())
        )
    }

    func previewImpact(
        for event: CalendarItemSnapshot,
        excludingItemID: UUID?
    ) -> ScheduleImpact {
        let sourceItems = items.filter { $0.id != excludingItemID }
        let overlapping = sourceItems.filter {
            $0.kind == .margin && $0.occupiedInterval.intersects(event.occupiedInterval)
        }
        let first = overlapping.first
        let otherMargins = sourceItems.filter { $0.kind == .margin }
        let candidates: [Date]
        // This confirmation UI selects one destination, so it must never send
        // several distinct margins to the same place. Multiple margins may still
        // be consumed together after the explicit exception approval.
        if overlapping.count == 1, let first {
            candidates = scheduler.relocationCandidates(
                for: first,
                month: event.startDate,
                events: sourceItems.filter { $0.kind != .margin } + [event],
                otherMargins: otherMargins,
                baseRules: fetchBaseRules(),
                notBefore: now
            )
        } else {
            candidates = []
        }
        let key = MonthKey(date: event.startDate)
        let monthGoals = goals.filter { $0.year == key.year && $0.month == key.month }
        return protectionEngine.analyze(
            proposedEvent: event,
            month: event.startDate,
            items: sourceItems,
            goals: monthGoals,
            relocationCandidates: candidates
        )
    }
}
