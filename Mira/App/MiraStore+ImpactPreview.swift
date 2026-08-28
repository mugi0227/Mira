import Foundation

@MainActor
extension MiraStore {
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
        if let first {
            candidates = scheduler.relocationCandidates(
                for: first,
                month: event.startDate,
                events: sourceItems.filter { $0.kind != .margin } + [event],
                otherMargins: otherMargins,
                baseRules: fetchBaseRules()
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
