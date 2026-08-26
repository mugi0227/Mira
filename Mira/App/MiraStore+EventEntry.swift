import Foundation

@MainActor
extension MiraStore {
    /// Returns advisory conflicts for a proposed confirmed event.
    /// These are intentionally warnings, not hard blockers: the user may still
    /// explicitly choose to add the event after reviewing the impact.
    func eventEntryConflicts(for event: CalendarItemSnapshot) -> [String] {
        let occupied = event.occupiedInterval
        let candidate = CandidateSlotSnapshot(
            startDate: occupied.start,
            endDate: occupied.end,
            timeOfDay: event.isAllDay ? .allDay : timeOfDay(for: event.startDate)
        )
        let heldCandidates = adjustments
            .filter { $0.status == .draft || $0.status == .waiting }
            .flatMap(\.candidates)

        return ConflictEngine(calendar: .mira).conflicts(
            candidate: candidate,
            events: items,
            otherCandidates: heldCandidates,
            baseRules: fetchBaseRules()
        )
    }

    /// Finds nearby slots at the same clock time that avoid confirmed events,
    /// protected margins, base unavailable hours, and other held adjustments.
    func alternativeEventStartDates(
        for event: CalendarItemSnapshot,
        limit: Int = 3,
        searchDays: Int = 28
    ) -> [Date] {
        guard limit > 0, searchDays > 0 else { return [] }

        let calendar = Calendar.mira
        let duration = max(30 * 60, event.endDate.timeIntervalSince(event.startDate))
        let startComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
        let startHour = startComponents.hour ?? 18
        let startMinute = startComponents.minute ?? 0
        let originalDay = event.startDate.startOfDay(calendar: calendar)
        var results: [Date] = []

        for offset in 1...searchDays {
            let day = originalDay.addingDays(offset, calendar: calendar)
            let start = event.isAllDay
                ? day.setting(hour: 9, calendar: calendar)
                : day.setting(hour: startHour, minute: startMinute, calendar: calendar)
            let end = event.isAllDay
                ? day.setting(hour: 21, calendar: calendar)
                : start.addingTimeInterval(duration)

            var moved = event
            moved.startDate = start
            moved.endDate = end

            if eventEntryConflicts(for: moved).isEmpty {
                results.append(start)
            }
            if results.count >= limit { break }
        }
        return results
    }

    private func timeOfDay(for date: Date) -> TimeOfDayKind {
        let hour = Calendar.mira.component(.hour, from: date)
        switch hour {
        case ..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }
}
