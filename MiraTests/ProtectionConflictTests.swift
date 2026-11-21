import XCTest
@testable import Mira

final class ProtectionConflictTests: XCTestCase {
    func testConflictDetailsNameEachKindAndLimitToTwo() {
        let slot = CandidateSlotSnapshot(startDate: TestFixtures.date(day: 12, hour: 13),
            endDate: TestFixtures.date(day: 12, hour: 18), timeOfDay: .afternoon)
        let event = TestFixtures.event(title: "会議", day: 12, hour: 14, duration: 2)
        let margin = TestFixtures.event(title: "読書", day: 12, hour: 13, duration: 2, kind: .margin, marginKind: .reading)
        let hold = CandidateSlotSnapshot(startDate: TestFixtures.date(day: 12, hour: 16),
            endDate: TestFixtures.date(day: 12, hour: 17), timeOfDay: .afternoon)
        let rule = BaseAvailabilityRule(weekday: Calendar.mira.component(.weekday, from: slot.startDate),
            startMinute: 9 * 60, endMinute: 18 * 60)
        let engine = ConflictEngine()
        XCTAssertEqual(engine.conflictDetails(candidate: slot, events: [event], otherCandidates: []),
            ["14:00〜16:00『会議』（確定予定）と重なっています"])
        XCTAssertEqual(engine.conflictDetails(candidate: slot, events: [margin], otherCandidates: []),
            ["13:00〜15:00『読書』（守っている余白）と重なっています"])
        XCTAssertEqual(engine.conflictDetails(candidate: slot, events: [], otherCandidates: [hold], candidateTitles: [hold.id: "ランチの調整"]),
            ["16:00〜17:00『ランチの調整』（仮押さえ）と重なっています"])
        XCTAssertEqual(engine.conflictDetails(candidate: slot, events: [], otherCandidates: [], baseRules: [rule]),
            ["09:00〜18:00『基本時間（予定を入れない時間）』と重なっています"])
        let multiple = engine.conflictDetails(candidate: slot, events: [event, margin], otherCandidates: [hold], baseRules: [rule])
        XCTAssertEqual(multiple.count, 3)
        XCTAssertEqual(multiple.last, "ほか2件")
        XCTAssertTrue(engine.conflictDetails(candidate: slot, events: [], otherCandidates: []).isEmpty)
    }

    func testConflictDetailBoundariesAndUnnamedHold() {
        let slot = CandidateSlotSnapshot(startDate: TestFixtures.date(day: 12, hour: 18),
            endDate: TestFixtures.date(day: 12, hour: 20), timeOfDay: .evening)
        let touching = TestFixtures.event(title: "終了済み", day: 12, hour: 16, duration: 2)
        XCTAssertEqual(ConflictEngine().conflictDetails(candidate: slot, events: [touching], otherCandidates: []).isEmpty,
            ConflictEngine().conflicts(candidate: slot, events: [touching], otherCandidates: []).isEmpty)
        let hold = CandidateSlotSnapshot(startDate: slot.startDate, endDate: slot.endDate, timeOfDay: .evening)
        XCTAssertTrue(ConflictEngine().conflictDetails(candidate: slot, events: [], otherCandidates: [hold]).first?.contains("別の日程調整") == true)
    }
    func testFinalRestTriggersFinalDefense() {
        let margin = TestFixtures.event(
            title: "何もしない・休息",
            day: 10,
            hour: 9,
            duration: 12,
            load: .light,
            kind: .margin,
            marginKind: .rest
        )
        let proposed = TestFixtures.event(title: "友達と遊ぶ", day: 10, hour: 11, duration: 8, load: .heavy)
        let impact = ProtectionEngine(calendar: .mira).analyze(
            proposedEvent: proposed,
            month: TestFixtures.september,
            items: [margin],
            goals: [TestFixtures.goal(.rest, count: 1)],
            relocationCandidates: []
        )
        XCTAssertEqual(impact.protectionLevel, .finalDefense)
        XCTAssertEqual(impact.projectedGoalDeficits[.rest], 1)
    }

    func testConflictEngineFindsConfirmedMarginOtherCandidateAndBaseHours() {
        let candidate = CandidateSlotSnapshot(
            startDate: TestFixtures.date(day: 12, hour: 13),
            endDate: TestFixtures.date(day: 12, hour: 17),
            timeOfDay: .afternoon
        )
        let confirmed = TestFixtures.event(title: "映画", day: 12, hour: 14, duration: 2)
        let margin = TestFixtures.event(
            title: "読書",
            day: 12,
            hour: 13,
            duration: 5,
            load: .light,
            kind: .margin,
            marginKind: .reading
        )
        let other = CandidateSlotSnapshot(
            startDate: TestFixtures.date(day: 12, hour: 13),
            endDate: TestFixtures.date(day: 12, hour: 17),
            timeOfDay: .afternoon
        )
        let weekday = Calendar.mira.component(.weekday, from: candidate.startDate)
        let conflicts = ConflictEngine().conflicts(
            candidate: candidate,
            events: [confirmed, margin],
            otherCandidates: [other],
            baseRules: [BaseAvailabilityRule(
                weekday: weekday,
                startMinute: 9 * 60,
                endMinute: 18 * 60
            )]
        )
        XCTAssertTrue(conflicts.contains("確定予定と重なっています"))
        XCTAssertTrue(conflicts.contains("守っている余白と重なっています"))
        XCTAssertTrue(conflicts.contains("別の日程調整でも候補になっています"))
        XCTAssertTrue(conflicts.contains("基本的に予定を入れない時間と重なっています"))
    }

    func testBaseHoursDoNotBlockAnEveningCandidate() {
        let candidate = CandidateSlotSnapshot(
            startDate: TestFixtures.date(day: 12, hour: 18),
            endDate: TestFixtures.date(day: 12, hour: 22),
            timeOfDay: .evening
        )
        let weekday = Calendar.mira.component(.weekday, from: candidate.startDate)
        let conflicts = ConflictEngine().conflicts(
            candidate: candidate,
            events: [],
            otherCandidates: [],
            baseRules: [BaseAvailabilityRule(
                weekday: weekday,
                startMinute: 9 * 60,
                endMinute: 18 * 60
            )]
        )
        XCTAssertFalse(conflicts.contains("基本的に予定を入れない時間と重なっています"))
    }

    func testFreeEveningCountsLowLoadShortItemAsMostlyFree() {
        let call = TestFixtures.event(title: "電話", day: 9, hour: 19, duration: 1, load: .light)
        let value = FreeEveningEngine(calendar: .mira).value(for: TestFixtures.date(day: 9), items: [call])
        XCTAssertGreaterThanOrEqual(value, 0.5)
    }
}
