import SwiftData
import XCTest
@testable import Mira

@MainActor
final class EventEntryAdvisoryTests: XCTestCase {
    func testBaseHoursWarnButDoNotPreventExplicitCommit() throws {
        let store = try makeStore()
        let start = date(year: 2026, month: 9, day: 1, hour: 15)
        let event = event(title: "打ち合わせ", start: start, hours: 2)

        store.context.insert(BaseRuleEntity(weekday: 3, startMinute: 9 * 60, endMinute: 18 * 60))
        try store.context.save()
        try store.refresh()

        let conflicts = store.eventEntryConflicts(for: event)
        XCTAssertTrue(conflicts.contains("基本的に予定を入れない時間と重なっています"))

        store.commitAdvisedEvent(event, impact: .none, resolution: .exception)
        XCTAssertTrue(store.items.contains(where: { $0.id == event.id }))
    }

    func testExceptionConsumesOverlappingProtectedMargin() throws {
        let store = try makeStore()
        let month = date(year: 2026, month: 9, day: 1, hour: 0)
        store.selectedMonth = month

        let margin = CalendarItemSnapshot(
            id: UUID(),
            title: MarginKind.rest.title,
            startDate: date(year: 2026, month: 9, day: 10, hour: 9),
            endDate: date(year: 2026, month: 9, day: 10, hour: 21),
            isAllDay: true,
            kind: .margin,
            marginKind: .rest,
            loadClass: .light,
            loadReason: "protected",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )
        let goal = MarginGoalSnapshot(
            id: UUID(),
            year: 2026,
            month: 9,
            kind: .rest,
            targetCount: 1,
            durationHours: 12,
            priority: MarginKind.rest.defaultPriority,
            isEnabled: true
        )
        store.context.insert(CalendarItemEntity(snapshot: margin))
        store.context.insert(MarginGoalEntity(snapshot: goal))
        try store.context.save()
        try store.refresh()

        let proposed = event(
            title: "友達と遊ぶ",
            start: date(year: 2026, month: 9, day: 10, hour: 11),
            hours: 5
        )
        let impact = store.previewImpact(for: proposed)
        XCTAssertEqual(impact.protectionLevel, .finalDefense)

        store.commitAdvisedEvent(proposed, impact: impact, resolution: .exception)

        XCTAssertFalse(store.items.contains(where: { $0.id == margin.id }))
        XCTAssertTrue(store.items.contains(where: { $0.id == proposed.id }))
        XCTAssertEqual(store.progress(for: goal).current, 0)
    }

    func testAlternativeDateAvoidsBaseHoursAtSameClockTime() throws {
        let store = try makeStore()
        let start = date(year: 2026, month: 9, day: 1, hour: 15) // Tuesday
        let proposed = event(title: "打ち合わせ", start: start, hours: 2)

        store.context.insert(BaseRuleEntity(weekday: 3, startMinute: 9 * 60, endMinute: 18 * 60))
        try store.context.save()
        try store.refresh()

        let alternatives = store.alternativeEventStartDates(for: proposed, limit: 1, searchDays: 7)
        XCTAssertEqual(alternatives.count, 1)
        XCTAssertTrue(Calendar.mira.isDate(alternatives[0], inSameDayAs: date(year: 2026, month: 9, day: 2, hour: 15)))
        XCTAssertEqual(Calendar.mira.component(.hour, from: alternatives[0]), 15)
    }

    private func makeStore() throws -> MiraStore {
        let schema = Schema([
            AppSettingsEntity.self,
            CalendarItemEntity.self,
            MarginGoalEntity.self,
            BaseRuleEntity.self,
            AdjustmentEntity.self,
            PendingInvitationEntity.self,
            LoadRuleEntity.self,
            ImportantPersonEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return MiraStore(container: container)
    }

    private func event(title: String, start: Date, hours: Int) -> CalendarItemSnapshot {
        CalendarItemSnapshot(
            id: UUID(),
            title: title,
            startDate: start,
            endDate: Calendar.mira.date(byAdding: .hour, value: hours, to: start) ?? start,
            isAllDay: false,
            kind: .confirmed,
            marginKind: nil,
            loadClass: .normal,
            loadReason: "test",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        Calendar.mira.date(from: DateComponents(
            calendar: Calendar.mira,
            timeZone: Calendar.mira.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )) ?? .now
    }
}
