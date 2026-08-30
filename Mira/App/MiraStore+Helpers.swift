import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func applySettings() {
        guard let settingsEntity else { return }
        onboardingCompleted = settingsEntity.onboardingCompleted
        theme = AppThemeKind(rawValue: settingsEntity.themeRaw) ?? .pixelCat
        assistantEnabled = settingsEntity.assistantEnabled
        characterNotificationsEnabled = settingsEntity.characterNotificationsEnabled
        notificationsEnabled = settingsEntity.notificationsEnabled
        demoModeEnabled = settingsEntity.demoModeEnabled
        marginComfortLevel = MarginComfortLevel(rawValue: settingsEntity.marginComfortRaw ?? "") ?? .standard
        weekStartDay = WeekStartDay(rawValue: settingsEntity.weekStartRaw ?? "") ?? .monday
        deviceHolidaysEnabled = settingsEntity.deviceHolidaysEnabled ?? false
    }

    func fetchBaseRules() -> [BaseAvailabilityRule] {
        (try? context.fetch(FetchDescriptor<BaseRuleEntity>()).map(\.snapshot)) ?? []
    }

    func fetchLoadRules() -> [LoadRule] {
        (try? context.fetch(FetchDescriptor<LoadRuleEntity>()).map(\.snapshot)) ?? []
    }

    func entity(id: UUID) throws -> CalendarItemEntity? {
        let targetID = id
        var descriptor = FetchDescriptor<CalendarItemEntity>(predicate: #Predicate { $0.id == targetID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func conversationCase(id: UUID?) -> ConversationCaseEntity? {
        guard let id else { return nil }
        return conversationCases.first(where: { $0.id == id })
    }

    func moveMargin(_ margin: CalendarItemSnapshot, to date: Date) throws {
        guard let entity = try entity(id: margin.id) else { return }
        let duration = entity.endDate.timeIntervalSince(entity.startDate)
        let components = Calendar.mira.dateComponents([.hour, .minute], from: entity.startDate)
        let newStart = date.setting(hour: components.hour ?? 9, minute: components.minute ?? 0)
        entity.startDate = newStart
        entity.endDate = newStart.addingTimeInterval(duration)
        entity.updatedAt = .now
    }

    func candidate(on day: Date, timeOfDay: TimeOfDayKind) -> CandidateSlotSnapshot {
        let range: (Int, Int)
        switch timeOfDay {
        case .allDay: range = (9, 21)
        case .morning: range = (9, 12)
        case .afternoon: range = (13, 17)
        case .evening: range = (18, 22)
        }
        return CandidateSlotSnapshot(
            startDate: day.setting(hour: range.0),
            endDate: day.setting(hour: range.1),
            timeOfDay: timeOfDay
        )
    }

    func candidate(on day: Date, band: SchedulingTimeBand, duration: DurationBucket, recommended: Bool = false, score: Double? = nil) -> CandidateSlotSnapshot {
        let interval = band.representativeInterval(on: day, duration: duration)
        return CandidateSlotSnapshot(
            startDate: interval.start,
            endDate: interval.end,
            timeOfDay: band.legacyTimeOfDay,
            schedulingTimeBand: band,
            durationBucket: duration,
            exactTimeKnown: false,
            isRecommended: recommended,
            recommendationScore: score
        )
    }

    func daysInMonth(_ month: Date) -> [Date] {
        guard let range = Calendar.mira.range(of: .day, in: .month, for: month) else { return [] }
        let start = MonthKey(date: month).firstDay
        return range.compactMap { Calendar.mira.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    func marginKind(for title: String) -> MarginKind? {
        MarginKind.allCases.first(where: { $0.title == title })
    }
}
