import SwiftData
import XCTest
@testable import Mira

@MainActor
final class EventEntryAdvisoryTests: XCTestCase {
    func testMemoConversionPreservesChangesMadeAfterDetailOpened() throws {
        let store = try makeStore()
        let stale = TestFixtures.event(title: "飲み会", day: 10, kind: .memo)
        let entity = CalendarItemEntity(snapshot: stale)
        store.context.insert(entity)
        try store.context.save()
        try store.refresh()
        var current = stale
        current.title = "オンライン通話"
        current.startDate = TestFixtures.date(day: 11, hour: 14)
        current.endDate = TestFixtures.date(day: 11, hour: 15)
        current.colorTag = .purple
        entity.apply(current)
        try store.context.save()
        try store.refresh()
        let preview = try XCTUnwrap(store.memoConvertedSnapshot(for: stale, enabled: false))
        XCTAssertEqual(preview.title, current.title)
        XCTAssertEqual(preview.startDate, current.startDate)
        XCTAssertEqual(preview.colorTag, .purple)
        XCTAssertTrue(store.setMemo(stale, enabled: false))
        XCTAssertEqual(store.items.first { $0.id == stale.id }, preview)
    }

    func testMemoConversionRejectsMissingAndNonEventItems() throws {
        let store = try makeStore()
        let missing = TestFixtures.event(day: 10, kind: .memo)
        XCTAssertNil(store.memoConvertedSnapshot(for: missing, enabled: false))
        XCTAssertFalse(store.setMemo(missing, enabled: false))
        let margin = TestFixtures.event(day: 10, kind: .margin, marginKind: .rest)
        store.context.insert(CalendarItemEntity(snapshot: margin))
        try store.context.save()
        try store.refresh()
        XCTAssertNil(store.memoConvertedSnapshot(for: margin, enabled: true))
        XCTAssertFalse(store.setMemo(margin, enabled: true))
    }

    func testMemoConversionPreviewIncludesBufferOnlyMargin() throws {
        let store = try makeStore()
        let memo = TestFixtures.event(title: "飲み会", day: 10, hour: 18, kind: .memo)
        let margin = TestFixtures.event(title: "読書", day: 10, hour: 21, kind: .margin, marginKind: .reading)
        store.context.insert(CalendarItemEntity(snapshot: memo))
        store.context.insert(CalendarItemEntity(snapshot: margin))
        try store.context.save()
        try store.refresh()
        let converted = try XCTUnwrap(store.memoConvertedSnapshot(for: memo, enabled: false))
        XCTAssertGreaterThan(converted.bufferAfterMinutes, 0)
        XCTAssertFalse(memo.occupiedInterval.intersects(margin.occupiedInterval))
        let shown = store.previewImpact(for: converted).overlappingMargins
        XCTAssertEqual(shown.map(\.id), [margin.id])
        XCTAssertTrue(store.eventEntryConflicts(for: converted).contains { $0.contains("読書") })
        XCTAssertTrue(store.setMemo(memo, enabled: false))
        XCTAssertFalse(store.items.contains { $0.id == margin.id })
        XCTAssertEqual(store.items.first { $0.id == memo.id }, converted)
    }

    func testMemoCommitPreservesMarginGoalsAndRejectsInvalidEntry() throws {
        let store = try makeStore()
        let margin = TestFixtures.event(day: 10, hour: 18, kind: .margin, marginKind: .rest)
        let goal = TestFixtures.goal(.rest, count: 1)
        store.context.insert(CalendarItemEntity(snapshot: margin))
        store.context.insert(MarginGoalEntity(snapshot: goal))
        try store.context.save()
        try store.refresh()
        var memo = TestFixtures.event(title: "人の予定", day: 10, hour: 18, kind: .memo)
        XCTAssertTrue(store.eventEntryConflicts(for: memo).isEmpty)
        XCTAssertTrue(store.eventEntryConflictDetails(for: memo).isEmpty)
        XCTAssertEqual(store.previewImpact(for: memo), .none)
        XCTAssertTrue(store.worsenedGoalDeficits(afterAdding: memo).isEmpty)
        XCTAssertTrue(store.commitEvent(memo))
        XCTAssertTrue(store.items.contains { $0.id == margin.id })
        XCTAssertEqual(store.progress(for: goal).current, 1)
        XCTAssertFalse(store.commitEvent(memo), "duplicate entry is rejected")
        memo = TestFixtures.event(title: "", day: 11, kind: .memo)
        XCTAssertFalse(store.commitEvent(memo))
    }

    func testChangingConfirmedEventToMemoClearsLoadBuffersAndImportance() throws {
        let store = try makeStore()
        var event = TestFixtures.event(day: 10, load: .veryHeavy)
        event.isImportantTime = true
        event.bufferAfterMinutes = 120
        store.context.insert(CalendarItemEntity(snapshot: event))
        try store.context.save()
        try store.refresh()
        XCTAssertTrue(store.setMemo(event, enabled: true))
        let memo = try XCTUnwrap(store.items.first { $0.id == event.id })
        XCTAssertEqual(memo.kind, .memo)
        XCTAssertFalse(memo.isImportantTime)
        XCTAssertEqual(memo.bufferAfterMinutes, 0)
        XCTAssertTrue(store.eventEntryConflicts(for: memo).isEmpty)
        XCTAssertTrue(store.setMemo(memo, enabled: false))
        XCTAssertEqual(store.items.first { $0.id == event.id }?.kind, .confirmed)
    }

    func testBaseHoursWarnButDoNotPreventExplicitCommit() throws {
        let store = try makeStore()
        let start = date(year: 2026, month: 9, day: 1, hour: 15)
        let event = event(title: "打ち合わせ", start: start, hours: 2)

        store.context.insert(BaseRuleEntity(weekday: 3, startMinute: 9 * 60, endMinute: 18 * 60))
        try store.context.save()
        try store.refresh()

        let conflicts = store.eventEntryConflicts(for: event)
        XCTAssertTrue(conflicts.contains { $0.contains("09:00〜18:00『基本時間（予定を入れない時間）』") })

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
        let start = date(year: 2026, month: 9, day: 1, hour: 15)
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
            ImportantPersonEntity.self,
            ConversationCaseEntity.self,
            RebalanceProposalEntity.self
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
