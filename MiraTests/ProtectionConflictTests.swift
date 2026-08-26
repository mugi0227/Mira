import XCTest
@testable import Mira

final class ProtectionConflictTests: XCTestCase {
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

    func testConflictEngineFindsConfirmedMarginAndOtherCandidate() {
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
        let conflicts = ConflictEngine().conflicts(candidate: candidate, events: [confirmed, margin], otherCandidates: [other])
        XCTAssertTrue(conflicts.contains("確定予定と重なっています"))
        XCTAssertTrue(conflicts.contains("守っている余白と重なっています"))
        XCTAssertTrue(conflicts.contains("別の日程調整でも候補になっています"))
    }

    func testFreeEveningCountsLowLoadShortItemAsMostlyFree() {
        let call = TestFixtures.event(title: "電話", day: 9, hour: 19, duration: 1, load: .light)
        let value = FreeEveningEngine(calendar: .mira).value(for: TestFixtures.date(day: 9), items: [call])
        XCTAssertGreaterThanOrEqual(value, 0.5)
    }
}
