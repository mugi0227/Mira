import Foundation

@MainActor
extension MiraStore {
    /// Returns advisory conflicts for a proposed confirmed event.
    /// These are intentionally warnings, not hard blockers: the user may still
    /// explicitly choose to add the event after reviewing the impact.
    func eventEntryConflicts(
        for event: CalendarItemSnapshot,
        excludingItemID: UUID? = nil
    ) -> [String] {
        let occupied = event.occupiedInterval
        let candidate = CandidateSlotSnapshot(
            startDate: occupied.start,
            endDate: occupied.end,
            timeOfDay: event.isAllDay ? .allDay : timeOfDay(for: event.startDate)
        )
        let heldCandidates = adjustments
            .filter { $0.status == .draft || $0.status == .waiting }
            .flatMap(\.candidates)
        let excludedID = excludingItemID ?? event.id

        return ConflictEngine(calendar: .mira).conflicts(
            candidate: candidate,
            events: items.filter { $0.id != excludedID },
            otherCandidates: heldCandidates,
            baseRules: fetchBaseRules()
        )
    }

    func currentGoalDeficits(in month: Date) -> [MarginKind: Int] {
        goalDeficits(in: month, using: items)
    }

    /// Projects the monthly goals if the user chooses to add the event as-is.
    /// Any protected margin that the event occupies is treated as consumed.
    func projectedGoalDeficits(afterAdding event: CalendarItemSnapshot) -> [MarginKind: Int] {
        let occupiedMarginIDs = Set(
            items.filter {
                $0.kind == .margin && $0.occupiedInterval.intersects(event.occupiedInterval)
            }.map(\.id)
        )
        var hypothetical = items.filter { !occupiedMarginIDs.contains($0.id) && $0.id != event.id }
        hypothetical.append(event)
        return goalDeficits(in: event.startDate, using: hypothetical)
    }

    func worsenedGoalDeficits(afterAdding event: CalendarItemSnapshot) -> [MarginKind: Int] {
        let current = currentGoalDeficits(in: event.startDate)
        let projected = projectedGoalDeficits(afterAdding: event)
        var result: [MarginKind: Int] = [:]
        for (kind, projectedDeficit) in projected {
            if projectedDeficit > (current[kind] ?? 0) {
                result[kind] = projectedDeficit
            }
        }
        return result
    }

    /// Finds nearby slots at the same clock time that avoid confirmed events,
    /// protected margins, base unavailable hours, other held adjustments, and
    /// do not worsen the user's monthly goal deficits.
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
        let baselineDeficits = currentGoalDeficits(in: event.startDate)
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

            let hasConflict = !eventEntryConflicts(for: moved, excludingItemID: event.id).isEmpty
            let projected = projectedGoalDeficits(afterAdding: moved)
            let worsensGoals = projected.contains { kind, deficit in
                deficit > (baselineDeficits[kind] ?? 0)
            }

            if !hasConflict && !worsensGoals {
                results.append(start)
            }
            if results.count >= limit { break }
        }
        return results
    }

    /// Commits a user-reviewed event. Choosing an exception consumes any
    /// protected margin under the event so goal progress reflects reality.
    func commitAdvisedEvent(
        _ event: CalendarItemSnapshot,
        impact: ScheduleImpact,
        resolution: ImpactResolution,
        chosenRelocationDate: Date? = nil
    ) {
        do {
            switch resolution {
            case .relocate:
                if let date = chosenRelocationDate ?? impact.relocationCandidates.first {
                    for margin in impact.overlappingMargins {
                        try moveMargin(margin, to: date)
                    }
                }
            case .exception:
                for margin in impact.overlappingMargins {
                    if let entity = try entity(id: margin.id) {
                        context.delete(entity)
                    }
                }
            }

            context.insert(CalendarItemEntity(snapshot: event))
            try context.save()
            try refresh()
            updateMarginRecommendation(for: event.startDate)
            recalculateBalance(for: event.startDate)
            toast = resolution == .exception && !impact.overlappingMargins.isEmpty
                ? "例外として予定を追加したにゃ"
                : "予定を追加したにゃ"
        } catch {
            toast = "予定を保存できませんでした"
        }
    }

    private func goalDeficits(in month: Date, using sourceItems: [CalendarItemSnapshot]) -> [MarginKind: Int] {
        let key = MonthKey(date: month)
        let monthGoals = goals.filter { $0.year == key.year && $0.month == key.month && $0.isEnabled }
        var deficits: [MarginKind: Int] = [:]

        for goal in monthGoals {
            let current: Int
            switch goal.kind {
            case .importantPeople:
                current = sourceItems.filter {
                    $0.isImportantTime && key.interval.contains($0.startDate)
                }.count
            case .freeEvening:
                let engine = FreeEveningEngine()
                current = Int(daysInMonth(key.firstDay).reduce(0.0) { total, date in
                    let dayItems = sourceItems.filter {
                        Calendar.mira.isDate($0.startDate, inSameDayAs: date)
                    }
                    return total + engine.value(for: date, items: dayItems)
                }.rounded(.down))
            default:
                current = sourceItems.filter {
                    $0.kind == .margin && $0.marginKind == goal.kind && key.interval.contains($0.startDate)
                }.count
            }

            let deficit = max(0, goal.targetCount - current)
            if deficit > 0 {
                deficits[goal.kind] = deficit
            }
        }
        return deficits
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
