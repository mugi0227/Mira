import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class FieldReviewRegressionTests: XCTestCase {
    func testComfortLevelsHaveDistinctCountsEvenForABusyMonth() {
        let engine = MarginRecommendationEngine()
        for items in [[], (1...20).map { TestFixtures.event(day: $0, load: .heavy) }] {
            let low = engine.recommend(month: TestFixtures.september, items: items, comfort: .low)
            let standard = engine.recommend(month: TestFixtures.september, items: items, comfort: .standard)
            let high = engine.recommend(month: TestFixtures.september, items: items, comfort: .high)
            for kind in [MarginKind.rest, .reading, .personalProject, .importantPeople] {
                XCTAssertEqual(low.targets[kind], 1)
                XCTAssertGreaterThan(standard.targets[kind, default: 0], 1)
                XCTAssertGreaterThan(high.targets[kind, default: 0], standard.targets[kind, default: 0])
            }
        }
    }

    func testShortDurationAndIndependentCustomGoalsSurvivePlacementAndRebalance() throws {
        let store = try makeStore()
        XCTAssertTrue(store.addCustomGoal(title: "ギター", target: 1, durationMinutes: 30, month: TestFixtures.september))
        XCTAssertTrue(store.addCustomGoal(title: "ジョギング", target: 1, durationMinutes: 90, month: TestFixtures.september))
        let proposal = try XCTUnwrap(store.activeRebalanceProposal)
        XCTAssertEqual(Set(proposal.moves.map(\.title)), ["ギター", "ジョギング"])
        XCTAssertTrue(store.applyRebalanceProposal(proposal))
        XCTAssertEqual(store.items.count, 2)
        for goal in store.currentMonthGoals {
            let item = try XCTUnwrap(store.items.first { goal.matches($0) })
            XCTAssertEqual(item.endDate.timeIntervalSince(item.startDate), Double(goal.effectiveDurationMinutes * 60))
            XCTAssertEqual(store.progress(for: goal).current, 1)
        }
        store.autoPlaceMargins(for: TestFixtures.september)
        XCTAssertEqual(store.items.count, 2, "Already met custom goals must not be placed again")
        store.ensurePlan(for: TestFixtures.september.addingMonths(1), provisional: false)
        let october = store.goals.filter { $0.month == 10 }
        XCTAssertEqual(Set(october.map(\.title)), ["ギター", "ジョギング"])
        XCTAssertEqual(Set(october.map(\.effectiveDurationMinutes)), [30, 90])
    }

    func testEditedDurationIsPreservedByRecommendationsAndAutomaticPlacement() throws {
        let store = try makeStore()
        let goal = TestFixtures.goal(.rest, count: 1)
        store.context.insert(MarginGoalEntity(snapshot: goal))
        try store.context.save()
        try store.refresh()
        store.updateGoal(goal, target: 1, durationMinutes: 90)
        store.updateMarginRecommendation(for: TestFixtures.september)
        store.applyCurrentMarginRecommendation()
        let saved = try XCTUnwrap(store.goals.first { $0.id == goal.id })
        XCTAssertEqual(saved.effectiveDurationMinutes, 90)
        let rest = store.items.filter { saved.matches($0) }
        XCTAssertFalse(rest.isEmpty)
        XCTAssertTrue(rest.allSatisfy { $0.endDate.timeIntervalSince($0.startDate) == 5400 && !$0.isAllDay })
    }

    func testMultipleCustomGoalDeficitsAreSummedAndAConsumedGoalIsReported() throws {
        let store = try makeStore()
        XCTAssertTrue(store.addCustomGoal(title: "ギター", target: 1, durationMinutes: 30, month: TestFixtures.september))
        XCTAssertTrue(store.addCustomGoal(title: "運動", target: 1, durationMinutes: 90, month: TestFixtures.september))
        let guitar = try XCTUnwrap(store.goals.first { $0.title == "ギター" })
        XCTAssertTrue(store.addMargin(kind: .custom, on: TestFixtures.date(day: 15), goalID: guitar.id))
        let event = TestFixtures.event(day: 15, hour: 13)
        XCTAssertEqual(store.currentGoalDeficits(in: TestFixtures.september)[.custom], 1)
        XCTAssertEqual(store.projectedGoalDeficits(afterAdding: event)[.custom], 2)
        XCTAssertEqual(store.worsenedGoalDeficits(afterAdding: event)[.custom], 1)
    }

    func testManuallyChosenCustomGoalKeepsItsOwnTitleDurationAndProtection() throws {
        let store = try makeStore()
        XCTAssertTrue(store.addCustomGoal(title: "ギター", target: 1, durationMinutes: 30, month: TestFixtures.september))
        XCTAssertTrue(store.addCustomGoal(title: "運動", target: 1, durationMinutes: 90, month: TestFixtures.september))
        let guitar = try XCTUnwrap(store.goals.first { $0.title == "ギター" })
        let sport = try XCTUnwrap(store.goals.first { $0.title == "運動" })
        XCTAssertTrue(store.addMargin(kind: .custom, on: TestFixtures.date(day: 15), goalID: guitar.id))
        XCTAssertTrue(store.addMargin(kind: .custom, on: TestFixtures.date(day: 16), goalID: sport.id))
        let item = try XCTUnwrap(store.items.first { sport.matches($0) })
        XCTAssertEqual(item.title, "運動")
        XCTAssertEqual(item.endDate.timeIntervalSince(item.startDate), 5400)
        let proposed = TestFixtures.event(day: 16, hour: 13)
        let impact = store.protectionEngine.analyze(proposedEvent: proposed, month: TestFixtures.september,
                                                   items: store.items, goals: store.goals, relocationCandidates: [])
        XCTAssertEqual(impact.protectionLevel, .finalDefense)
    }

    func testSelectedMonthCannotPickUpTheLatestProposalFromAnotherMonth() throws {
        let store = try makeStore()
        let october = TestFixtures.september.addingMonths(1)
        let november = october.addingMonths(1)
        let first = RebalanceProposal(month: october, moves: [], summary: "10月の案", stateHash: "october", createdAt: TestFixtures.date(day: 1))
        let second = RebalanceProposal(month: november, moves: [], summary: "11月の案", stateHash: "november", createdAt: TestFixtures.date(day: 2))
        store.context.insert(RebalanceProposalEntity(proposal: first))
        store.context.insert(RebalanceProposalEntity(proposal: second))
        try store.context.save()
        store.selectedMonth = october
        try store.refresh()
        XCTAssertEqual(store.activeRebalanceProposal?.id, first.id)
        store.selectedMonth = november
        XCTAssertEqual(store.activeRebalanceProposal?.id, second.id)
        store.selectedMonth = october
        store.recalculateBalance(for: november)
        XCTAssertEqual(store.activeRebalanceProposal?.id, first.id)
        try store.refresh()
        XCTAssertEqual(store.activeRebalanceProposal?.month, october)
    }

    func testOnePlacedMarginCanChangeDurationAndUndoWithoutChangingItsGoal() async throws {
        let store = try makeStore()
        let goal = TestFixtures.goal(.rest, count: 1)
        store.context.insert(MarginGoalEntity(snapshot: goal))
        try store.context.save()
        try store.refresh()
        XCTAssertTrue(store.addMargin(kind: .rest, on: TestFixtures.date(day: 15)))
        let original = try XCTUnwrap(store.items.first)
        store.rescheduleItem(id: original.id, toStart: original.startDate, durationSeconds: 1800)
        XCTAssertNil(store.pendingChangePreview)
        let shortened = try XCTUnwrap(store.items.first)
        XCTAssertEqual(shortened.id, original.id)
        XCTAssertEqual(shortened.endDate.timeIntervalSince(shortened.startDate), 1800)
        XCTAssertFalse(shortened.isAllDay)
        XCTAssertEqual(store.goals.first?.effectiveDurationMinutes, 720)
        await store.undoLastCalendarMutation()
        XCTAssertEqual(store.items, [original])
    }

    func testExtendingAMarginIntoAnEventNeedsAReviewAndDoesNotSilentlySave() throws {
        let store = try makeStore()
        var margin = TestFixtures.event(day: 15, hour: 13, duration: 1, kind: .margin, marginKind: .reading)
        margin.endDate = margin.startDate.addingTimeInterval(1800)
        let event = TestFixtures.event(day: 15, hour: 14)
        store.context.insert(CalendarItemEntity(snapshot: margin))
        store.context.insert(CalendarItemEntity(snapshot: event))
        try store.context.save()
        try store.refresh()
        store.rescheduleItem(id: margin.id, toStart: margin.startDate, durationSeconds: 7200)
        XCTAssertNotNil(store.pendingChangePreview)
        XCTAssertEqual(store.items.first { $0.id == margin.id }, margin)
    }

    func testImportedCalendarAppearsInThisWeeksChatDayAndWidgetWithoutNextWeeksEvents() async throws {
        let store = try makeStore()
        store.clock = DemoClock(now: TestFixtures.date(day: 16, hour: 10))
        let thisWeek = deviceEvent("iPhoneの面談", start: TestFixtures.date(day: 17, hour: 13))
        let nextWeek = deviceEvent("来週の面談", start: TestFixtures.date(day: 21, hour: 13))
        try store.mergeDeviceCalendarEvents([thisWeek, nextWeek], in: MonthKey(date: TestFixtures.september).interval, selectedIDs: ["phone"])
        store.selectedMonth = TestFixtures.september.addingMonths(4)
        store.selectedDate = thisWeek.start
        XCTAssertTrue(store.selectedDayItems.contains { $0.title == thisWeek.title })
        XCTAssertTrue(MiraStore.widgetSnapshot(items: store.items, now: store.now).entries.contains { $0.title == thisWeek.title })
        await store.sendChat("今週の予定は？")
        let cards = try XCTUnwrap(store.chatMessages.last).cards
        let schedules = cards.compactMap { card -> ChatScheduleSummary? in
            if case .schedule(let schedule) = card { return schedule }
            return nil
        }
        let schedule = try XCTUnwrap(schedules.first)
        XCTAssertTrue(schedule.items.contains { $0.title == thisWeek.title })
        XCTAssertFalse(schedule.items.contains { $0.title == nextWeek.title })
    }

    func testCalendarSyncUpdatesInPlaceRemovesDeletedEventsAndKeepsMiraEvents() throws {
        let store = try makeStore()
        let local = TestFixtures.event(title: "Miraの予定", day: 15)
        store.context.insert(CalendarItemEntity(snapshot: local))
        try store.context.save()
        let imported = deviceEvent("iPhoneの予定", start: TestFixtures.date(day: 16))
        let interval = MonthKey(date: TestFixtures.september).interval
        try store.mergeDeviceCalendarEvents([imported], in: interval, selectedIDs: ["phone"])
        let id = try XCTUnwrap(store.items.first { $0.title == imported.title }).id
        var changed = imported
        changed.title = "変更された予定"
        changed.start = imported.start.addingTimeInterval(3600)
        changed.end = imported.end.addingTimeInterval(3600)
        try store.mergeDeviceCalendarEvents([changed], in: interval, selectedIDs: ["phone"])
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first { $0.id == id }?.title, changed.title)
        try store.mergeDeviceCalendarEvents([], in: interval, selectedIDs: ["phone"])
        XCTAssertEqual(store.items, [local])
    }

    func testFriendViewShowsDaytimeBusyAndEveningFreeWithoutNames() {
        let event = TestFixtures.event(title: "秘密の予定", day: 15, hour: 13)
        let availability = FriendAvailability(date: event.startDate, items: [event])
        XCTAssertEqual(availability.bands.map(\.isBusy), [false, true, false])
        XCTAssertFalse(availability.summary.contains(event.title))
        let work = BaseAvailabilityRule(weekday: Calendar.mira.component(.weekday, from: event.startDate), startMinute: 540, endMinute: 1080)
        let workingDay = FriendAvailability(date: event.startDate, items: [], baseRules: [work])
        XCTAssertEqual(workingDay.bands.map(\.isBusy), [true, true, false])
    }

    func testMultidayAndAllDayEventsAlsoCoverFollowingDaysButNotTheirEndDay() {
        var event = TestFixtures.event(day: 14)
        event.startDate = TestFixtures.date(day: 14, hour: 0)
        event.endDate = TestFixtures.date(day: 16, hour: 0)
        event.isAllDay = true
        XCTAssertTrue(event.overlapsDay(TestFixtures.date(day: 15)))
        XCTAssertFalse(event.overlapsDay(TestFixtures.date(day: 16)))
        XCTAssertEqual(FriendAvailability(date: TestFixtures.date(day: 15), items: [event]).summary, "終日予定")
        XCTAssertEqual(FriendAvailability(date: TestFixtures.date(day: 16), items: [event]).summary, "終日空き")
    }

    func testBulkWeekdayEditPreservesWeekendAndPersistsTheFiveDays() throws {
        let store = try makeStore()
        var rules = AvailabilityRuleDraft.standardWeekdays
        rules[5] = AvailabilityRuleDraft(weekday: 7, isEnabled: true, startMinute: 600, endMinute: 720)
        let template = AvailabilityRuleDraft(weekday: 2, isEnabled: true, startMinute: 480, endMinute: 1020)
        let edited = AvailabilityRuleDraft.applyingWeekdays(template, to: rules)
        XCTAssertEqual(edited[5], rules[5])
        XCTAssertEqual(edited[6], rules[6])
        store.updateBaseRules(edited.compactMap(\.domainRule))
        let saved = store.fetchBaseRules().filter { (2...6).contains($0.weekday) }
        XCTAssertEqual(saved.count, 5)
        XCTAssertTrue(saved.allSatisfy { $0.startMinute == 480 && $0.endMinute == 1020 })
    }

    private func deviceEvent(_ title: String, start: Date) -> DeviceCalendarEvent {
        DeviceCalendarEvent(reference: DeviceEventReference(eventID: title, calendarID: "phone", occurrenceStart: start, isRecurring: false),
                            title: title, start: start, end: start.addingTimeInterval(3600), allDay: false)
    }

    private func makeStore() throws -> MiraStore {
        let schema = Schema([AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
                             BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
                             LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self, RebalanceProposalEntity.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return MiraStore(container: container, classifier: RuleBasedSemanticClassifier(),
                         conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
    }
}
