import XCTest
import SwiftData
@testable import Mira

final class WorkDayResolverTests: XCTestCase {
    private let monday = TestFixtures.date(day: 7, hour: 0)
    private let saturday = TestFixtures.date(day: 12, hour: 0)
    private let rules = [BaseAvailabilityRule(weekday: 2, startMinute: 540, endMinute: 1080)]

    func testRuleAndNonRuleWeekdays() {
        let resolver = WorkDayResolver()
        XCTAssertTrue(resolver.isWorkDay(monday, rules: rules))
        XCTAssertFalse(resolver.isWorkDay(saturday, rules: rules))
        XCTAssertTrue(resolver.intervals(on: saturday, rules: rules).isEmpty)
        XCTAssertFalse(resolver.isWorkDay(monday, rules: []))
    }

    func testHolidayFlagAndOverridesTakePrecedence() {
        var resolver = WorkDayResolver(holidays: [monday])
        XCTAssertFalse(resolver.isWorkDay(monday, rules: rules))
        XCTAssertTrue(resolver.intervals(on: monday, rules: rules).isEmpty)
        resolver.excludeHolidays = false
        XCTAssertTrue(resolver.isWorkDay(monday, rules: rules))
        resolver.overrides[monday] = false
        XCTAssertFalse(resolver.isWorkDay(monday, rules: rules))
        resolver.excludeHolidays = true
        resolver.overrides[monday] = true
        XCTAssertTrue(resolver.isWorkDay(monday, rules: rules))
    }

    func testForcedWorkDayUsesFirstMondayOrderedWeekdayAndAllItsRanges() {
        let resolver = WorkDayResolver(overrides: [saturday: true])
        let otherRules = [BaseAvailabilityRule(weekday: 3, startMinute: 600, endMinute: 660)]
            + rules + [BaseAvailabilityRule(weekday: 2, startMinute: 1200, endMinute: 1260)]
        XCTAssertTrue(resolver.isWorkDay(saturday, rules: otherRules))
        let intervals = resolver.intervals(on: saturday, rules: otherRules)
        XCTAssertEqual(intervals.count, 2)
        XCTAssertEqual(intervals.first?.start, TestFixtures.date(day: 12, hour: 9))
        XCTAssertEqual(intervals.first?.end, TestFixtures.date(day: 12, hour: 18))
        XCTAssertTrue(resolver.intervals(on: saturday, rules: []).isEmpty)
    }

    func testOffOverrideFreesWhitespaceAndSingleFreeSlot() {
        let resolver = WorkDayResolver(overrides: [monday: false])
        XCTAssertEqual(DayWhitespace(date: monday, items: [], baseRules: rules, workDays: resolver).availableMinutes, 960)
        XCTAssertEqual(DayFreeSlot(date: monday, items: [], baseRules: rules, workDays: resolver).longestMinutes, 960)
        XCTAssertEqual(DayWhitespace(date: monday, items: [], baseRules: rules).availableMinutes, 420)
        XCTAssertEqual(DayFreeSlot(date: monday, items: [], baseRules: rules).longestMinutes, 300)
    }

    func testInvalidIntervalsAreIgnoredAndClamped() {
        let invalid = [BaseAvailabilityRule(weekday: 2, startMinute: 600, endMinute: 500)]
        XCTAssertTrue(WorkDayResolver().intervals(on: monday, rules: invalid).isEmpty)
        let fullDay = [BaseAvailabilityRule(weekday: 2, startMinute: -60, endMinute: 1500)]
        XCTAssertEqual(WorkDayResolver().intervals(on: monday, rules: fullDay).first?.duration, 86400)
    }

    func testFriendSharingUsesEffectiveWorkHours() {
        let off = WorkDayResolver(overrides: [monday: false])
        XCTAssertEqual(FriendAvailability(date: monday, items: [], baseRules: rules, workDays: off).summary, "終日空き")
        XCTAssertTrue(FriendDayContent(date: monday, items: [], baseRules: rules, level: .busyTimes, workDays: off).lines.isEmpty)
        XCTAssertTrue(FriendAvailabilityText.text(from: monday, days: 1, items: [], baseRules: rules, workDays: off).contains("終日"))
        let on = WorkDayResolver(overrides: [saturday: true])
        XCTAssertTrue(FriendAvailability(date: saturday, items: [], baseRules: rules, workDays: on).bands[0].isBusy)
        XCTAssertFalse(FriendDayContent(date: saturday, items: [], baseRules: rules, level: .busyTimes, workDays: on).lines.isEmpty)
        XCTAssertEqual(FriendAvailability(date: saturday, items: [], baseRules: [], workDays: on).summary, "終日空き")
    }

    func testConflictEngineRespectsOffAndOnOverrides() {
        let candidate = CandidateSlotSnapshot(startDate: monday.addingTimeInterval(36000), endDate: monday.addingTimeInterval(39600), timeOfDay: .morning)
        let off = ConflictEngine(workDays: WorkDayResolver(overrides: [monday: false]))
        XCTAssertTrue(off.conflictDetailEntries(candidate: candidate, events: [], otherCandidates: [], baseRules: rules).isEmpty)
        XCTAssertEqual(ConflictEngine().conflictDetailEntries(candidate: candidate, events: [], otherCandidates: [], baseRules: rules).count, 1)
        let saturdayCandidate = CandidateSlotSnapshot(startDate: saturday.addingTimeInterval(36000), endDate: saturday.addingTimeInterval(39600), timeOfDay: .morning)
        XCTAssertEqual(ConflictEngine(workDays: WorkDayResolver(overrides: [saturday: true])).conflictDetailEntries(candidate: saturdayCandidate, events: [], otherCandidates: [], baseRules: rules).count, 1)
    }

    @MainActor
    func testStorePersistsOverridesAndHolidaySetting() async throws {
        let schema = Schema([
            AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, WorkDayOverrideEntity.self, AdjustmentEntity.self,
            PendingInvitationEntity.self, LoadRuleEntity.self, ImportantPersonEntity.self,
            ConversationCaseEntity.self, RebalanceProposalEntity.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let settings = AppSettingsEntity()
        container.mainContext.insert(settings)
        container.mainContext.insert(BaseRuleEntity(weekday: 2, startMinute: 540, endMinute: 1080))
        try container.mainContext.save()
        let store = MiraStore(container: container, classifier: RuleBasedSemanticClassifier(), conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
        await store.bootstrap()
        XCTAssertTrue(store.excludeHolidaysFromWorkDays)
        store.setWorkDay(monday.addingTimeInterval(43200), false)
        XCTAssertFalse(store.isWorkDay(monday))
        let entries = try store.context.fetch(FetchDescriptor<WorkDayOverrideEntity>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.day, monday)
        store.workDayOverrides = [:]
        store.loadWorkDayOverrides()
        XCTAssertFalse(store.isWorkDay(monday))
        store.setWorkDay(monday, true)
        XCTAssertTrue(try store.context.fetch(FetchDescriptor<WorkDayOverrideEntity>()).isEmpty)
        store.setExcludeHolidaysFromWorkDays(false)
        XCTAssertEqual(store.settingsEntity?.excludeHolidaysFromWorkDays, false)
        store.applySettings()
        XCTAssertFalse(store.excludeHolidaysFromWorkDays)
    }
}
