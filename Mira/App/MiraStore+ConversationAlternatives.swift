import Foundation

@MainActor
extension MiraStore {
    func beginAlternativeScheduling(for preview: EventCreationPreview) {
        let event = preview.event
        let duration = event.durationBucket ?? durationBucket(for: event)
        let band = event.schedulingTimeBand ?? schedulingBandForAlternative(event.startDate)
        let start = Calendar.mira.startOfDay(for: event.startDate)
        let end = start.addingDays(28)
        let caseEntity = conversationCase(id: preview.caseID)

        var draft = SchedulingDraft(
            conversationCaseID: preview.caseID,
            title: event.title,
            person: caseEntity?.state.person,
            month: MonthKey(date: start).firstDay,
            dateRangeStart: start,
            dateRangeEnd: end,
            durationBucket: duration,
            timeBands: [band],
            inferredFields: []
        )

        let held = adjustments
            .filter { $0.status == .draft || $0.status == .waiting }
            .flatMap(\.candidates)
        let recommendations = schedulingRecommendationEngine.recommendations(
            title: event.title,
            dateRange: DateInterval(start: start, end: end),
            duration: duration,
            timeBands: [band],
            items: items,
            heldCandidates: held,
            baseRules: fetchBaseRules(),
            notBefore: now
        )
        draft.recommendations = recommendations
        draft.selectedRecommendationIDs = Set(recommendations.filter(\.isRecommended).map(\.id))

        activeSchedulingIntent = .findDates
        activeSchedulingDraft = draft
        pendingEventCreationPreview = nil
        selectedMonth = draft.month
        selectedDate = start
    }

    private func durationBucket(for event: CalendarItemSnapshot) -> DurationBucket {
        if event.isAllDay { return .fullDay }
        let hours = event.endDate.timeIntervalSince(event.startDate) / 3600
        if hours >= 4 { return .halfDay }
        return .short
    }

    private func schedulingBandForAlternative(_ date: Date) -> SchedulingTimeBand {
        let hour = Calendar.mira.component(.hour, from: date)
        switch hour {
        case ..<12: return .morning
        case 12..<17: return .midday
        default: return .evening
        }
    }
}
